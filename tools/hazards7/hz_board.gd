extends Node
## FERRAMENTA (não faz parte do jogo): PRANCHA DOS PERIGOS PINTADOS (Onda 7).
##
## probe (headless): monta todos os nós do mapa (como a LayoutQA) e lista em
##   que tela/nó aparece cada tipo de perigo → `hz_probe.txt`.
##   godot --headless --audio-driver Dummy --path . res://tools/hazards7/HzBoard.tscn -- probe <saida.txt>
##
## shots: monta a TELA REAL num SubViewport 1280x720 (fora da janela, que pode
##   ser 320x180 fora da vista), põe a câmera no perigo, a Sophia ao lado (escala)
##   e fotografa cada ESTADO (mexendo só no relógio/estado do perigo). Com `code`
##   força o desenho antigo (HazardArt.force_code) — a prancha "antes".
##   godot --audio-driver Dummy --path . --resolution 320x180 --position 4000,4000 \
##     res://tools/hazards7/HzBoard.tscn -- shots <pasta> <code|paint> <tipo>:<tela>:<nó> [...]
##   Saída: <pasta>/<tipo>_<code|paint>_<estado>.png (640x360 de mundo, 2x).
##
## seq: igual a shots, mas grava N quadros seguidos de um perigo (GIF):
##   ... -- seq <pasta> <tipo>:<tela>:<nó> <quadros>

const KINDS := {
	"pendulum": "Pendulum", "bell": "Pendulum", "guillotine": "Guillotine", "spears": "SpearTrap",
	"shackles": "SpearTrap", "maw": "Maw", "spores": "SporePod", "totem": "SummonTotem",
	"sinking": "SinkingPlatform", "mirror": "MirrorPlatform", "shards": "ShardFall",
	"tide": "DarkTide", "vault": "SecretVault", "altar": "SanctuaryAltar", "ward": "WardLight",
}

var _args: PackedStringArray


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	SaveManager.persist_enabled = false
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _setup_run() -> void:
	GameManager.selected_character = GameContent.characters[0]
	Progression.reset_run()
	RunManager.begin()
	Narrative.once("prologue")
	Gnosis.persist_enabled = false


func _run() -> void:
	_setup_run()
	var mode: String = _args[0] if _args.size() > 0 else "probe"
	if mode == "probe":
		await _probe(_args[1] if _args.size() > 1 else "user://hz_probe.txt")
	elif mode == "shots":
		HazardArt.force_code = _args[2] == "code"
		for i in range(3, _args.size()):
			await _shots(_args[1], _args[2], _args[i])
	elif mode == "seq":
		await _seq(_args[1], _args[2], int(_args[3]) if _args.size() > 3 else 60)
	get_tree().quit(0)


# --- probe ----------------------------------------------------------------

func _kind_of(n: Node) -> String:
	var k = n.get("hazard_kind")
	if k == null:
		return ""
	var ks := String(k)
	if n is SpearTrap:
		return String(n.get("style"))
	if n is Pendulum:
		return "bell" if String(n.get("style")) == "bell" else "pendulum"
	return ks


func _probe(out: String) -> void:
	var scene: PackedScene = load("res://scenes/levels/Level01.tscn")
	var jobs: Array = []
	for eon in 7:
		for layer in 8:
			var ids: Array = EonMap.layer_ids(eon, layer)
			if ids.is_empty():
				jobs.append([EonMap.screen_of(eon, layer), ""])
			for id in ids:
				jobs.append([EonMap.screen_of(eon, layer), String(id)])
	for s in [RunManager.CENTER_FIRST, RunManager.CENTER_FIRST + 1, RunManager.CENTER_FIRST + 2]:
		jobs.append([s, ""])
	var lines: PackedStringArray = []
	for j in jobs:
		RunManager.current_screen = int(j[0])
		GameManager.current_screen = int(j[0])
		RunManager.current_node = String(j[1])
		GameManager.set_state(GameManager.State.PLAYING)
		var lv: Level = scene.instantiate()
		get_tree().root.add_child(lv)
		await get_tree().process_frame
		var found: Dictionary = {}
		for c in lv.get_children():
			var k := _kind_of(c)
			if k != "" and KINDS.has(k):
				found[k] = int(found.get(k, 0)) + 1
		lines.append("%d\t%s\t%s\t%s" % [int(j[0]), String(j[1]), String(lv.layout.get("kind", "?")), JSON.stringify(found)])
		lv.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("HZ probe: %d telas -> %s" % [jobs.size(), out])


# --- tela real num SubViewport ------------------------------------------------

var _vp: SubViewport
var _lv: Level
var _cam: Camera2D


func _open(screen: int, node_id: String) -> void:
	if _vp == null:
		_vp = SubViewport.new()
		_vp.size = Vector2i(1280, 720)
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vp.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_vp)
	if _lv != null:
		_lv.queue_free()
		await get_tree().process_frame
	RunManager.current_screen = screen
	GameManager.current_screen = screen
	RunManager.current_node = node_id
	GameManager.set_state(GameManager.State.PLAYING)
	_lv = load("res://scenes/levels/Level01.tscn").instantiate()
	_vp.add_child(_lv)
	for i in 30:
		await _frame()
	# sem HUD/legendas (dentro e fora da fase)
	# só o HUD da fase (o fundo/parallax também são CanvasLayers)
	for cl in _lv.find_children("*", "CanvasLayer", true, false):
		if (cl as CanvasLayer).layer > 0 or cl.name.begins_with("HUD"):
			(cl as CanvasLayer).visible = false
	for n in get_tree().get_nodes_in_group("hud"):
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	for r in get_tree().root.get_children():
		if r == self:
			continue
		for cl in r.find_children("*", "CanvasLayer", true, false):
			(cl as CanvasLayer).visible = false
		if r is CanvasLayer:
			(r as CanvasLayer).visible = false
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	_cam.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	_lv.add_child(_cam)


## Um quadro: pula diálogos, tira inimigos, mantém a câmera e o estado de jogo.
func _frame() -> void:
	for c in get_tree().root.get_children():
		if c is DialogueBox:
			if c.choices.size() > 0:
				c._on_choice(0)
			else:
				c._finish()
	get_tree().paused = false
	if GameManager.state != GameManager.State.PLAYING:
		GameManager.set_state(GameManager.State.PLAYING)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and is_instance_valid(e) and not e.is_queued_for_deletion():
			e.queue_free()
	if _cam != null:
		_cam.make_current()
	await get_tree().process_frame


func _find(kind: String) -> Node2D:
	var p := _lv.get_tree().get_first_node_in_group("player") as Node2D
	var best: Node2D = null
	var bd := INF
	for c in _lv.get_children():
		if _kind_of(c) == kind:
			var d: float = absf((c as Node2D).global_position.x - (p.global_position.x if p != null else 0.0))
			if kind == "tide":
				d = 0.0
			if best == null or d < bd:
				best = c
				bd = d
	return best


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.save_png(path)


## Estados de cada perigo: [nome, Callable que põe o perigo no estado].
func _states(kind: String, h: Node2D) -> Array:
	var cyc := func(c: float) -> void:
		h.set("phase", c - float(h.get("_t")))
	match kind:
		"pendulum", "bell":
			var per: float = float(h.get("period"))
			return [["esq", cyc.bind(per * 0.75)], ["baixo", cyc.bind(0.0)], ["dir", cyc.bind(per * 0.25)]]
		"guillotine":
			return [["parada", cyc.bind(1.0)], ["aviso", cyc.bind(2.45)], ["caindo", cyc.bind(2.66)], ["cravada", cyc.bind(2.85)]]
		"spears", "shackles":
			return [["fechada", cyc.bind(1.0)], ["aviso", cyc.bind(2.7)], ["saindo", cyc.bind(3.36)], ["estendida", cyc.bind(3.0)]]
		"maw":
			return [["fechada", cyc.bind(1.0)], ["aviso", cyc.bind(2.4)], ["abrindo", cyc.bind(2.85)], ["mordendo", cyc.bind(3.1)]]
		"spores":
			return [["fechado", cyc.bind(1.0)], ["inchando", cyc.bind(3.05)], ["estouro", cyc.bind(3.35)]]
		"totem":
			return [["aceso", func() -> void: h.set("_armed", false)],
				["pulsando", func() -> void: h.set("_armed", true); h.set("_timer", 0.6)],
				["quebrado", func() -> void: h.set("_armed", false); h.set("_dead", true)]]
		"sinking":
			return [["inteira", func() -> void: h.set("_state", "rest"); h.set("_stand", 0.0)],
				["rachando", func() -> void: h.set("_state", "rest"); h.set("_stand", 0.4)],
				["afundando", func() -> void: h.set("_state", "sinking"); h.get("_body").position.y = 18.0]]
		"mirror":
			return [["firme", func() -> void: h.set("_t", 0.5 + (2.4 if h.get("group_b") else 0.0))],
				["aviso", func() -> void: h.set("_t", 2.2 + (2.4 if h.get("group_b") else 0.0))],
				["reflexo", func() -> void: h.set("_t", 3.0 + (2.4 if h.get("group_b") else 0.0))]]
		"shards":
			return [["sombra", func() -> void: h.set("_drops", [{"x": 40.0, "t": 0.5}]); h.set("_next", 99.0)],
				["caindo", func() -> void: h.set("_drops", [{"x": 40.0, "t": 0.92}]); h.set("_next", 99.0)]]
		"tide":
			return [["maré", func() -> void:
				h.set("_running", true)
				var p := _lv.get_tree().get_first_node_in_group("player") as Node2D
				h.set("_front", p.global_position.x - 40.0)]]
		"vault":
			return [["selada", func() -> void: pass]]
		"altar":
			return [["aceso", func() -> void: h.set("used", false)], ["dormindo", func() -> void: h.set("used", true); h.set("_glow", 0.0)]]
		"ward":
			return [["forte", func() -> void: h.set("_armed", true); h.set("light", 90.0)],
				["fragil", func() -> void: h.set("_armed", true); h.set("light", 30.0)],
				["apagada", func() -> void: h.set("_armed", false); h.set("light", 0.0)]]
	return [["estado", func() -> void: pass]]


func _parse(job: String) -> Array:
	var p := job.split(":")
	return [p[0], int(p[1]) if p.size() > 1 else 2, p[2] if p.size() > 2 else ""]


func _place(kind: String, h: Node2D) -> void:
	var p := _lv.get_tree().get_first_node_in_group("player") as Node2D
	var hx := h.global_position.x
	var dx := -90.0
	if kind in ["pendulum", "bell"]:
		dx = -250.0
	elif kind == "tide":
		dx = 0.0
		hx = p.global_position.x
	elif kind in ["sinking", "mirror"]:
		dx = -110.0
	if p != null and kind != "tide":
		p.global_position = Vector2(hx + dx, 310.0)
		p.set("velocity", Vector2.ZERO)
	var cy := 180.0
	if kind in ["sinking", "mirror"]:
		cy = h.global_position.y + 20.0
	_cam.global_position = Vector2(hx + (dx * 0.35 if kind != "tide" else 60.0), cy)


func _shots(dir: String, tag: String, job: String) -> void:
	var j := _parse(job)
	var kind: String = j[0]
	await _open(int(j[1]), String(j[2]))
	var h := _find(kind)
	if h == null:
		print("HZ: '%s' não achado na tela %d %s" % [kind, int(j[1]), j[2]])
		return
	for i in 8:
		_place(kind, h)
		await _frame()
	for st in _states(kind, h):
		for i in 3:
			_place(kind, h)
			(st[1] as Callable).call()
			await _frame()
		_place(kind, h)
		(st[1] as Callable).call()
		await _frame()
		var path := "%s/%s_%s_%s.png" % [dir, kind, tag, st[0]]
		await _snap(path)
		print("HZ salvo ", path)


func _seq(dir: String, job: String, n: int) -> void:
	var j := _parse(job)
	var kind: String = j[0]
	await _open(int(j[1]), String(j[2]))
	var h := _find(kind)
	if h == null:
		print("HZ: '%s' não achado" % kind)
		return
	if kind in ["spears", "shackles", "maw", "guillotine", "spores"]:
		h.set("phase", 1.6 - float(h.get("_t")))
	for i in n:
		_place(kind, h)
		await _frame()
		await _snap("%s/%s_seq_%03d.png" % [dir, kind, i])
	print("HZ seq %d quadros" % n)
