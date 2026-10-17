extends Node
## FERRAMENTA (não faz parte do jogo): LayoutQA — confere o LAYOUT de TODOS os
## nós do mapa (7 Éons × camadas × trilhas) + Centro, headless e sem jogar:
##  - monta cada tela (Level01) e lê o que o LayoutBuilder criou;
##  - ALCANCE: grafo de superfícies (chão + plataformas) com pulo simples
##    (sobe ≤ 66 px, vão ≤ 60) e com pulo duplo (sobe ≤ 135);
##    · baú de torre/escalada: alcançável com pulo SIMPLES;
##    · baú de saliência/sala secreta: NÃO alcançável com simples, SIM com duplo;
##    · fenda no alto (escalada): alcançável com pulo simples;
##  - SPAWNS: nenhum ponto de nascimento no chão embaixo de plataforma baixa;
##  - perigo/torre em cima de Estela/baú/Adormecido/Selos/encontro: falha.
## Uso: godot --headless --audio-driver Dummy --path . res://tools/level6/LayoutQA.tscn
## Sai com 0 (QA PASS) ou 1 (QA FAIL).

const RISE_1 := 66.0
const RISE_2 := 135.0
const GAP := 60.0

var _fails: int = 0
var _checks: int = 0
var _kinds: Dictionary = {}


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	SaveManager.persist_enabled = false
	_run.call_deferred()


func _run() -> void:
	GameManager.selected_character = GameContent.characters[0]
	Progression.reset_run()
	RunManager.begin()
	Gnosis.persist_enabled = false
	var scene: PackedScene = load("res://scenes/levels/Level01.tscn")
	var jobs: Array = []        # [tela, id do nó]
	for eon in 7:
		for layer in 8:
			var ids: Array = EonMap.layer_ids(eon, layer)
			if ids.is_empty():
				jobs.append([EonMap.screen_of(eon, layer), ""])
			for id in ids:
				jobs.append([EonMap.screen_of(eon, layer), String(id)])
	for s in [RunManager.CENTER_FIRST, RunManager.CENTER_FIRST + 1, RunManager.CENTER_FIRST + 2]:
		jobs.append([s, ""])
	for j in jobs:
		await _check_screen(scene, int(j[0]), String(j[1]))
	print("LAYOUTQA tipos: ", _kinds)
	if _fails == 0:
		print("QA PASS layout_qa: %d verificações em %d telas" % [_checks, jobs.size()])
	else:
		print("QA FAIL layout_qa: %d falhas (%d verificações)" % [_fails, _checks])
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("LAYOUTQA FALHA: ", what)


func _check_screen(scene: PackedScene, screen: int, node_id: String) -> void:
	RunManager.current_screen = screen
	GameManager.current_screen = screen
	RunManager.current_node = node_id
	GameManager.set_state(GameManager.State.PLAYING)
	var lv: Level = scene.instantiate()
	get_tree().root.add_child(lv)
	await get_tree().process_frame
	var kind := String(lv.layout.get("kind", "?"))
	_kinds[kind] = int(_kinds.get(kind, 0)) + 1
	var tag := "tela %d %s (%s)" % [screen, node_id, kind]
	# --- superfícies: [x0, x1, topo] ---
	var surf: Array = [[Level.WALL_LEFT, float(lv.get("_end_x")), 310.0]]
	for n in lv.find_children("*", "StaticBody2D", true, false):
		for ch in n.get_children():
			if ch is CollisionShape2D and ch.one_way_collision and ch.shape is RectangleShape2D:
				var sz: Vector2 = (ch.shape as RectangleShape2D).size
				var p: Vector2 = (ch as Node2D).global_position
				surf.append([p.x - sz.x * 0.5, p.x + sz.x * 0.5, p.y - sz.y * 0.5])
	var r1 := _reach(surf, RISE_1)
	var r2 := _reach(surf, RISE_2)
	# --- baús secretos ---
	var n_secret := 0
	for c in lv.get_children():
		if c is Chest and c.secret:
			n_secret += 1
			var top_y: float = c.global_position.y + LayoutBuilder.CHEST_LIFT
			var k := _surface_under(surf, c.global_position.x, top_y)
			if k < 0:
				_check(false, "%s: baú secreto em x=%.0f não está sobre plataforma" % [tag, c.global_position.x])
				continue
			var dj_only := _near_mark(lv, c.global_position.x) or _in_vault(lv, c.global_position.x)
			if dj_only:
				_check(not r1.has(k), "%s: baú de PULO DUPLO em x=%.0f alcançável com pulo simples (superfícies perto: %s)" % [tag, c.global_position.x, str(surf.filter(func(sv): return absf(float(sv[0]) - c.global_position.x) < 260.0 and float(sv[2]) < 309.0))])
				_check(r2.has(k), "%s: baú de pulo duplo em x=%.0f inalcançável mesmo com pulo duplo" % [tag, c.global_position.x])
			else:
				_check(r1.has(k), "%s: baú de torre em x=%.0f inalcançável com pulo simples" % [tag, c.global_position.x])
	# --- fenda no alto ---
	if lv._layout_res.has("exit_top"):
		var et: Vector2 = lv._layout_res.exit_top
		var ke := _surface_under(surf, et.x, et.y)
		_check(ke >= 0 and r1.has(ke), "%s: fenda no alto inalcançável com pulo simples" % tag)
	# --- spawns fora de baixo das plataformas baixas ---
	for zi in lv.zones.size():
		var c := lv.zone_center(zi)
		lv._place_spawns(c)
		for sp in lv.spawns.get_children():
			var x: float = (sp as Node2D).global_position.x
			var under := false
			for s in surf:
				if float(s[2]) < 309.0 and float(s[2]) > 230.0 and x > float(s[0]) - 12.0 and x < float(s[1]) + 12.0:
					under = true
			_check(not under, "%s: spawn em x=%.0f embaixo de plataforma baixa (zona %d)" % [tag, x, zi])
	# --- perigos em cima do conteúdo reservado ---
	var reserved: Array = lv.reserved_spans()
	var n_hz := 0
	for h in lv.get_children():
		if h is LevelHazard and not (h is MirrorPlatform or h is SinkingPlatform or h is DarkTide):
			n_hz += 1
			var hx: float = (h as Node2D).global_position.x
			var inside_zone := false
			for zi in lv.zones.size():
				if absf(hx - lv.zone_center(zi)) <= Level.ZONE_HALF:
					inside_zone = true
			if inside_zone:
				continue          # guarda de arena: não divide espaço com Estela/baú
			for r in reserved:
				_check(not (hx > float(r[0]) and hx < float(r[1])), "%s: perigo %s em x=%.0f em cima de conteúdo reservado [%.0f, %.0f]" % [tag, String(h.hazard_kind), hx, float(r[0]), float(r[1])])
	print("LAYOUTQA %s zonas=%d perigos=%d segredos=%d plataformas=%d fim=%.0f" % [tag, lv.zones.size(), n_hz, n_secret, surf.size() - 1, float(lv.get("_end_x"))])
	# limpa: caixas de diálogo abertas pelos beats e a fase
	for c in get_tree().root.get_children():
		if c is DialogueBox:
			c.queue_free()
	lv.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


## Superfície (índice) cujo topo está em `top_y` (±4) e cobre `x`.
func _surface_under(surf: Array, x: float, top_y: float) -> int:
	for i in surf.size():
		var s: Array = surf[i]
		if absf(float(s[2]) - top_y) <= 4.0 and x >= float(s[0]) - 2.0 and x <= float(s[1]) + 2.0:
			return i
	return -1


## Alcance a partir do chão (índice 0): sobe ≤ rise com vão ≤ GAP; desce sempre
## (vão ≤ 150).
func _reach(surf: Array, rise: float) -> Dictionary:
	var seen := {0: true}
	var queue: Array = [0]
	while not queue.is_empty():
		var a: int = queue.pop_front()
		var sa: Array = surf[a]
		for b in surf.size():
			if seen.has(b):
				continue
			var sb: Array = surf[b]
			var gap: float = maxf(0.0, maxf(float(sb[0]) - float(sa[1]), float(sa[0]) - float(sb[1])))
			var up: float = float(sa[2]) - float(sb[2])
			var ok := false
			if up > 0.0:
				ok = up <= rise and gap <= GAP
			else:
				ok = gap <= 150.0
			if ok:
				seen[b] = true
				queue.append(b)
	return seen


func _near_mark(lv: Level, x: float) -> bool:
	for c in lv.get_children():
		if c is SecretMark and absf((c as Node2D).global_position.x - x) < 10.0:
			return true
	return false


func _in_vault(lv: Level, x: float) -> bool:
	for c in lv.get_children():
		if c is SecretVault and absf((c as Node2D).global_position.x - x) < c.room_w * 0.5:
			return true
	return false
