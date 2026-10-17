extends Level
## Desafio de três encontros. Usa Player, Enemy e HUD reais, sem simular combate.

var completed: bool = false
var result_layer: CanvasLayer
var phase_label: Label
## Faixa de dicas de controle: segue o dispositivo em uso e o remapeamento
## (QA P3 · #33, via `InputGlyphs`). `hint_bar` desenha os ÍCONES (tecla,
## botões Xbox/PlayStation/Switch/Deck) e se redesenha sozinho quando o último
## input troca de dispositivo; `hint_label` guarda o mesmo conteúdo em texto
## (invisível — contrato da sonda de menus e leitura em log).
var hint_label: Label
var hint_bar: InputGlyphs.Hint

const HINTS := [["@move", "mover"], ["jump", "saltar"], [["attack_light", "attack_heavy"], "golpes"], ["dodge", "esquiva"], ["block", "aparar"], ["skill1", "anel"], ["skill2", "esfera"]]

func _ready() -> void:
	# A entrada direta serve às ferramentas de QA.
	if not CodexSession.active:
		CodexSession.start_demo()
		return
	screen = RunManager.FIRST_EON_SCREEN + CodexSession.boss_index * RunManager.EON_LEN
	GameManager.current_screen = screen
	GameManager.set_state(GameManager.State.PLAYING)
	player.died.connect(_on_player_died)
	player.combo_changed.connect(func(count: int): CodexSession.best_combo = maxi(CodexSession.best_combo, count))
	player.position = Vector2(160, 270)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.position_smoothing_enabled = false
	cam.base_offset = Vector2.ZERO
	cam.limit_left = 0
	cam.limit_right = 840
	cam.limit_top = 50
	cam.limit_bottom = 410
	_build_eon_scenery()
	# Arena compacta, o objetivo nunca fica escondido fora de tela.
	for wx in [-20, 860]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(wx, 170)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 600)
		shape.shape = rect
		wall.add_child(shape)
		add_child(wall)
	$Spawns/Spawn1.position = Vector2(430, 270)
	$Spawns/Spawn2.position = Vector2(570, 270)
	$Spawns/Spawn3.position = Vector2(720, 270)
	match CodexSession.stage:
		0: waves = [["servo", "servo"], ["servo", Bestiary.EON_BOTS[CodexSession.boss_index]]]
		1: waves = [["escudeiro", "servo"], [Bestiary.EON_BOTS[CodexSession.boss_index], "servo"]]
		_: waves = [[Bestiary.bosses[CodexSession.boss_index].id]]
	var layer := CanvasLayer.new()
	add_child(layer)
	phase_label = CodexStyle.label(layer, "", Vector2(390, 13), 10, CodexStyle.GOLD, 230)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label = CodexStyle.label(layer, "", Vector2(18, 341), 8, CodexStyle.MUTED, 615)
	hint_label.visible = false
	# Placa escura que se dissolve nas pontas (legível sobre qualquer chão).
	var plate := _HintPlate.new()
	plate.position = Vector2(0, 334)
	plate.size = Vector2(640, 22)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(plate)
	hint_bar = InputGlyphs.Hint.new()
	hint_bar.icon_h = 11.0
	hint_bar.font_size = 8
	hint_bar.gap = 11.0
	hint_bar.color = Color(CodexStyle.PAPER, 0.82)
	hint_bar.position = Vector2(10, 338)
	hint_bar.size = Vector2(620, 14)
	hint_bar.pairs = HINTS
	layer.add_child(hint_bar)
	var l := InputGlyphs.listener()
	if l != null:
		l.connect("device_changed", _on_device_changed)
	_refresh_hints()
	_start_wave()
	get_tree().call_group("hud", "toast", ["I  ·  A FAÍSCA DESPERTA", "II  ·  QUEBRE A GUARDA", "III  ·  ENCARE O ARCONTE"][CodexSession.stage])

## Troca a faixa de dicas quando o último dispositivo usado muda.
func _on_device_changed(_d: int) -> void:
	_refresh_hints()


func _refresh_hints() -> void:
	if hint_label != null:
		hint_label.text = InputGlyphs.hint(HINTS, -1, "   ")
	if hint_bar != null:
		hint_bar.queue_redraw()


func _process(delta: float) -> void:
	if not completed and GameManager.state == GameManager.State.PLAYING:
		CodexSession.elapsed += delta
	if phase_label != null:
		phase_label.text = "PROVAÇÃO  %d / 3   ·   %02d:%02d" % [CodexSession.stage + 1, int(CodexSession.elapsed) / 60, int(CodexSession.elapsed) % 60]

func _start_wave() -> void:
	GameManager.current_screen = RunManager.FIRST_EON_SCREEN
	if CodexSession.stage == 2:
		screen = RunManager.FIRST_EON_SCREEN + CodexSession.boss_index * RunManager.EON_LEN + RunManager.EON_LEN - 1
	super._start_wave()
	# Os números da campanha permanecem intactos. O desafio usa o início da curva.
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.is_boss_enemy:
			e.health.setup(270)
			e.attack_damage = 9

func _on_screen_cleared() -> void:
	if completed:
		return
	completed = true
	await get_tree().create_timer(0.8).timeout
	_show_result(true)

func _on_player_died() -> void:
	if completed:
		return
	completed = true
	await get_tree().create_timer(0.9).timeout
	_show_result(false)

func _show_result(won: bool) -> void:
	GameManager.set_state(GameManager.State.PAUSED)
	PauseStack.push(self)
	Audio.play_sfx("ui_open")
	result_layer = CanvasLayer.new()
	result_layer.layer = 30
	result_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(result_layer)
	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.055, 0.075, 0.96)
	panel.size = Vector2(640, 360)
	result_layer.add_child(panel)
	var final: bool = won and CodexSession.stage == 2
	CodexStyle.label(result_layer, "GNOSIS  /  PROVAÇÃO  (treino)", Vector2(170, 52), 10, CodexStyle.GOLD)
	CodexStyle.label(result_layer, "A luz permanece." if final else ("O selo cedeu." if won else "A faísca resiste."), Vector2(170, 80), 31, CodexStyle.PAPER, 440, true)
	CodexStyle.label(result_layer, "Tempo  %02d:%02d    ·    Melhor combo  %d" % [int(CodexSession.elapsed) / 60, int(CodexSession.elapsed) % 60, CodexSession.best_combo], Vector2(170, 132), 12, CodexStyle.MUTED)
	if final:
		# Deixar CLARO: isto foi só o treino. A campanha é o jogo.
		CodexStyle.wrap_label(CodexStyle.label(result_layer, "Isto foi a Provação (treino). A Campanha tem %d telas e sete Arcontes — no menu, em \"Nova campanha\"." % RunManager.MAX_SCREEN, Vector2(170, 158), 11, CodexStyle.PAPER, 310), 310)
	else:
		CodexStyle.label(result_layer, "Respire. Sua vida será restaurada." if won else "Esquive do vermelho. Apare o dourado.", Vector2(170, 158), 12, CodexStyle.MUTED)
	var y := 222.0
	var first: Button
	if final:
		first = CodexStyle.button(result_layer, "Ir para a Campanha  →", Vector2(170, y), 285, func():
			PauseStack.clear()
			Audio.play_sfx("ui_confirm")
			SceneManager.change_scene("res://scenes/ui/PreGame.tscn"), true)
		y += 36
		CodexStyle.button(result_layer, "Repetir a Provação", Vector2(170, y), 285, func():
			PauseStack.clear()
			CodexSession.start_demo(CodexSession.boss_index))
	else:
		first = CodexStyle.button(result_layer, "Próximo encontro  →" if won else "Tentar novamente", Vector2(170, y), 285, func():
			PauseStack.clear()
			if won: CodexSession.next_stage()
			else: CodexSession.start_demo(CodexSession.boss_index), true)
	y += 36
	CodexStyle.button(result_layer, "Voltar ao menu", Vector2(170, y), 285, func():
		PauseStack.clear()
		Audio.play_sfx("ui_back")
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn"))
	first.grab_focus()


## Fundo da faixa de dicas: azul-noite que se dissolve nas pontas.
class _HintPlate extends Control:
	func _draw() -> void:
		var steps := 12
		for i in steps:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			var c0 := Color(0.01, 0.025, 0.035, 0.6 * sin(t0 * PI))
			var c1 := Color(0.01, 0.025, 0.035, 0.6 * sin(t1 * PI))
			draw_polygon(PackedVector2Array([Vector2(size.x * t0, 0), Vector2(size.x * t1, 0), Vector2(size.x * t1, size.y), Vector2(size.x * t0, size.y)]),
				PackedColorArray([c0, c1, c1, c0]))

