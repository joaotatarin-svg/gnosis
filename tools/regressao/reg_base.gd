extends Node

## BASE DAS QAs DE REGRESSÃO (não faz parte do jogo). Cada teste é um script
## que estende esta classe e implementa `rodar()` (corrotina). O resultado sai
## no stdout, uma linha por verificação, prefixo "REG|" para grep:
##   REG|<ID>|CHECK|<nome>|OK|<detalhe>     ·   REG|<ID>|CHECK|<nome>|FALHA|<detalhe>
##   REG|<ID>|PASS|<n verificações>         ·   REG|<ID>|FAIL|<n falhas>/<n>
## Código de saída: 0 = PASS, 1 = FAIL, 3 = teste quebrado (sem veredito).
## Rodar sempre com --headless --audio-driver Dummy --fixed-fps 60 (ver run_all.sh).
## Os testes descrevem o COMPORTAMENTO esperado (não a implementação): quem
## consertar o bug pode escolher o jeito; o teste só olha o que o jogador vê/sofre.

var id: String = "?"
## Autoteste (`-- <ID> autoteste`): o próprio teste simula a correção (quando
## sabe fazer isso sem tocar no jogo) para provar que ele PASSA com o bug consertado.
var autoteste: bool = false
var _checks: int = 0
var _fails: int = 0
var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Nunca suja o save (os testes de save religam explicitamente, em user:// isolado).
	SaveManager.persist_enabled = false
	Gnosis.persist_enabled = false
	_main.call_deferred()


func _main() -> void:
	if autoteste:
		if has_method("simular_correcao"):
			info("AUTOTESTE: simulando a correção antes de rodar")
			await call("simular_correcao")
		else:
			quebrado("autoteste não suportado neste teste")
			return
	await rodar()
	terminar()


## Implementar no teste (corrotina).
func rodar() -> void:
	pass


# --- veredito ----------------------------------------------------------------

func check(nome: String, ok: bool, detalhe: String = "") -> bool:
	_checks += 1
	if not ok:
		_fails += 1
	print("REG|%s|CHECK|%s|%s|%s" % [id, nome, "OK" if ok else "FALHA", detalhe])
	return ok


func info(msg: String) -> void:
	print("REG|%s|INFO|%s" % [id, msg])


## Teste não conseguiu montar o cenário (não é veredito sobre o bug).
func quebrado(motivo: String) -> void:
	if _done:
		return
	_done = true
	print("REG|%s|BROKEN|%s" % [id, motivo])
	PauseStack.clear()
	get_tree().quit(3)


func terminar() -> void:
	if _done:
		return
	_done = true
	if _checks == 0:
		print("REG|%s|BROKEN|nenhuma verificação rodou" % id)
		get_tree().quit(3)
		return
	if _fails == 0:
		print("REG|%s|PASS|%d" % [id, _checks])
	else:
		print("REG|%s|FAIL|%d/%d" % [id, _fails, _checks])
	PauseStack.clear()
	get_tree().quit(0 if _fails == 0 else 1)


# --- tempo ---------------------------------------------------------------------

## Espera `s` segundos de jogo CONTADOS EM QUADROS (os testes rodam com
## --fixed-fps 60: 1 quadro = 1/60 s de jogo), mesmo com a árvore pausada.
## Não usa relógio real nem timer: o jogo pode trocar relógio por delta sem
## mudar o teste.
const QPS := 60
func wait(s: float) -> void:
	await frames(maxi(1, int(ceil(s * QPS))))


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- cenário ---------------------------------------------------------------------

## Monta um run na tela `screen` (Anéis coerentes, como a RunProbe) e espera o Level ficar pronto.
## `pular_falas`: fecha diálogos/cinemáticas de entrada sozinho.
func level_at(screen: int, pular_falas: bool = true) -> Level:
	PauseStack.clear()
	GameManager.selected_character = GameContent.characters[0]
	Progression.reset_run()
	RunManager.begin()
	Narrative.once("prologue")
	RunManager.current_screen = screen
	GameManager.current_screen = screen
	for sk in GameContent.characters[0].skills:
		if sk.ring == "":
			continue
		var n: int = Bestiary.bosses.map(func(b): return b.id).find(sk.ring)
		var archon_screen: int = RunManager.FIRST_EON_SCREEN + (n + 1) * RunManager.EON_LEN - 1
		if n >= 0 and archon_screen < screen:
			Progression.add_ring(sk.ring, sk.id)
	if screen >= RunManager.CENTER_FIRST:
		Progression.steal_rings()
	get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
	var lv: Level = null
	for i in 600:
		await get_tree().process_frame
		if pular_falas:
			pular_dialogos()
		var cs := get_tree().current_scene
		if cs is Level and (cs as Level)._ready_done:
			lv = cs
			break
	if lv == null:
		quebrado("Level da tela %d não ficou pronto" % screen)
		while true:
			await get_tree().process_frame             # nunca segue (o quit já foi pedido)
	return lv


## Fecha diálogos abertos (1ª escolha) e cinemáticas. Devolve quantos fechou.
func pular_dialogos() -> int:
	var n := 0
	for c in get_tree().root.get_children():
		if c is DialogueBox and c.is_node_ready() and not c.is_queued_for_deletion():
			n += 1
			if c.choices.size() > 0:
				if c._in_choices:
					c._on_choice(0)
				else:
					c.idx = c.lines.size()
					c._show_line()
			else:
				c._finish()
		elif c is Cinematic and c.is_node_ready() and not c.is_queued_for_deletion():
			n += 1
			if c.has_method("skip"):
				c.call("skip")
			elif c.has_signal("finished"):
				c.emit_signal("finished")
				c.queue_free()
	return n


func dialogos_abertos() -> Array:
	var r: Array = []
	for c in get_tree().root.get_children():
		if c is DialogueBox and not c.is_queued_for_deletion():
			r.append(c)
	return r


## Leva a Sophia ao gatilho da zona `i` (como se tivesse andado até lá).
func ir_para_zona(lv: Level, i: int) -> void:
	lv.player.global_position = Vector2(lv.zone_center(i) - Level.ZONE_TRIGGER + 8.0, 250.0)


func inimigos_vivos() -> Array:
	var r: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.estate != Enemy.EState.DEAD:
			r.append(e)
	return r


func chefes_vivos() -> Array:
	var r: Array = []
	for e in inimigos_vivos():
		if e.is_boss_enemy:
			r.append(e)
	return r


## Golpe direto no inimigo (como a magia: sem atacante), ignora hitbox.
func bater(e: Enemy, dano: int) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	var pos: Vector2 = pl.global_position if pl != null else e.global_position - Vector2(40, 0)
	e._on_hit_received(dano, pos, 0.0, false, null)


## Evento de tecla/botão REAL (passa pelo InputMap, como o jogador).
func tecla(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await frames(3)
	var r := e.duplicate()
	r.pressed = false
	Input.parse_input_event(r)
	await frames(3)


func botao(b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	e.pressure = 1.0
	e.device = 0
	Input.parse_input_event(e)
	await frames(3)
	var r := InputEventJoypadButton.new()
	r.button_index = b
	r.pressed = false
	r.device = 0
	Input.parse_input_event(r)
	await frames(3)


func foco() -> String:
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return "<nenhum>"
	if f is Button:
		return "Button:'%s'" % (f as Button).text
	return "%s:%s" % [f.get_class(), f.name]


## Retângulo visível da tela (base 640×360).
func tela() -> Rect2:
	return get_viewport().get_visible_rect()


## Overlay (loja/pausa) aberto como filho do Level.
func overlay(lv: Node, cena: String) -> Node:
	if lv == null or not is_instance_valid(lv):
		return null
	for c in lv.get_children():
		if c.scene_file_path.ends_with(cena) and not c.is_queued_for_deletion():
			return c
	return null
