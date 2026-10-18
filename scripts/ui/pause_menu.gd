extends CanvasLayer
## Menu de pausa (overlay). Pausa a árvore pela `PauseStack`; segue processando
## a si mesmo. Continuar · Golpes & Controles · Melhorias (a loja; TRANCADA em
## combate — "Disponível fora de combate") · Opções (overlay que volta PARA CÁ,
## não para o menu) · Abandonar run (confirma; o checkpoint salvo permanece).
## Mostra o papel da tela ("Torpor · Travessia II", "Torpor · Arena") e a
## relíquia em uso. Mapa (Onda 6): abre o WorldMap em MODO LEITURA (só olhar a
## rota do Éon; confirmar não escolhe nada). Esc/B/Start = Continuar.

@onready var _vbox: VBoxContainer = $Center/Panel/VBox
@onready var _resume: Button = $Center/Panel/VBox/Resume
@onready var _moves: Button = $Center/Panel/VBox/Moves
@onready var _upgrades: Button = $Center/Panel/VBox/Upgrades
@onready var _map: Button = $Center/Panel/VBox/Map
@onready var _options: Button = $Center/Panel/VBox/Options
@onready var _quit: Button = $Center/Panel/VBox/Quit

var _sub_open: bool = false     # um overlay (golpes/opções/loja/mapa) está aberto
var _map_view: Control = null    # WorldMap aberto em modo leitura


func _ready() -> void:
	CodexStyle.apply_existing(self)
	_vbox.custom_minimum_size.x = 260
	$Dim.color = Color(0.01, 0.03, 0.045, 0.7)
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseStack.push(self)
	var role: Label = $Center/Panel/VBox/Role
	role.text = _role_text()
	role.add_theme_font_override("font", CodexStyle.italic())
	role.add_theme_font_size_override("font_size", 12)
	role.add_theme_color_override("font_color", CodexStyle.MUTED)
	var rule := CodexStyle.Rule.new()
	rule.custom_minimum_size = Vector2(0, 7)
	rule.color = Color(CodexStyle.GOLD, 0.8)
	_vbox.add_child(rule)
	_vbox.move_child(rule, role.get_index() + 1)
	# Relíquia em uso (progressao6), logo abaixo do papel da tela.
	var rl := RunLabels.relic_line()
	if rl != "" and not CodexSession.active:
		var relic := Label.new()
		relic.name = "Relic"
		relic.text = rl
		relic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		relic.add_theme_font_override("font", CodexStyle.italic())
		relic.add_theme_font_size_override("font_size", 10)
		var rc = RunLabels.relic_data(RunLabels.relic_id()).get("color", CodexStyle.GOLD_HI)
		relic.add_theme_color_override("font_color", (rc as Color).lerp(CodexStyle.PAPER, 0.4))
		relic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(relic)
		_vbox.move_child(relic, role.get_index() + 1)
	_resume.pressed.connect(_resume_game)
	_moves.pressed.connect(_open_moves)
	_upgrades.pressed.connect(_open_upgrades)
	_options.pressed.connect(_open_options)
	_quit.pressed.connect(_ask_quit)
	_map.pressed.connect(_open_map)
	_map.visible = map_available()
	for b in [_resume, _moves, _upgrades, _map, _options, _quit]:
		b.custom_minimum_size.y = CodexStyle.BTN_H
	_lock_upgrades_in_combat()
	# cima/baixo circulam (do último volta ao primeiro)
	_resume.focus_neighbor_top = _resume.get_path_to(_quit)
	_quit.focus_neighbor_bottom = _quit.get_path_to(_resume)
	_resume.grab_focus()
	CodexStyle.pop_in($Center/Panel)


## "Torpor · Travessia II" — ou o encontro da Provação.
func _role_text() -> String:
	if CodexSession.active:
		return "Provação  ·  encontro %d / 3" % (CodexSession.stage + 1)
	return RunLabels.role_title(RunManager.current_screen)


## O mapa só existe dentro dos Éons de um run (o Limiar, o Centro e a Mente não
## têm grafo) e com a tela de mapa do mapa6 no projeto.
static func map_available() -> bool:
	if CodexSession.active or not RunManager.run_active:
		return false
	if not ResourceLoader.exists(MAP_SCENE):
		return false
	var s := RunManager.current_screen
	var first = RunManager.get("FIRST_EON_SCREEN")
	var last = RunManager.get("LAST_ARCHON_SCREEN")
	if first == null or last == null:
		return false
	return s >= int(first) and s <= int(last)


const MAP_SCENE := "res://scenes/ui/WorldMap.tscn"


## Abre o WorldMap por cima da pausa, só para LER: setas/D-pad passeiam pelas
## saídas e mostram o que cada uma dá; confirmar não escolhe (a pausa come o
## aceitar antes do mapa); Esc/B/Start ou "Mapa" de novo fecham.
func _open_map() -> void:
	if _map_view != null or not map_available():
		return
	var packed = load(MAP_SCENE)
	if packed == null:
		return
	var wm: Control = packed.instantiate()
	# Contrato com o mapa6: se a tela ganhar um modo leitura oficial, ele vale.
	if "read_only" in wm:
		wm.set("read_only", true)
	_sub_open = true
	$Center.visible = false
	$Dim.visible = false
	_map_view = wm
	add_child(wm)
	# Clique no nó não pode escolher caminho: o grafo deixa de ouvir o mouse.
	var canvas = wm.get("_canvas")
	if canvas is Control:
		(canvas as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sub = wm.get("_sub")
	if sub is Label:
		(sub as Label).text = I18n.t("O caminho do Éon até aqui. Só para olhar.")
	for c in wm.get_children():
		if c is InputGlyphs.Hint:
			(c as InputGlyphs.Hint).pairs = [["@nav", "passeiam pelas saídas"], ["ui_cancel", "voltar"]]


func _close_map() -> void:
	if _map_view == null:
		return
	_map_view.queue_free()
	_map_view = null
	_sub_open = false
	$Center.visible = true
	$Dim.visible = true
	Audio.play_sfx("ui_back")
	_map.grab_focus()


## O mapa em modo leitura: aceitar é engolido aqui (antes do _unhandled_input
## do WorldMap, que escolheria o caminho) e voltar fecha.
func _input(event: InputEvent) -> void:
	if _map_view == null:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_map()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()


## Mapa aberto em modo leitura? (QA/sonda)
func map_open() -> bool:
	return _map_view != null


## Melhorias só fora de combate (QA M6): curar no meio de um Arconte quebrava a
## tensão. O botão continua focável (o jogador lê o porquê) mas não abre.
func _lock_upgrades_in_combat() -> void:
	if not in_combat(get_tree()):
		return
	_upgrades.disabled = true
	_upgrades.tooltip_text = "Disponível fora de combate"
	# O porquê, logo abaixo do botão (centrado como os botões; não briga com o nome).
	var why := Label.new()
	why.name = "Why"
	why.text = "Disponível fora de combate"
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.add_theme_font_override("font", CodexStyle.italic())
	why.add_theme_font_size_override("font_size", 10)
	why.add_theme_color_override("font_color", Color(CodexStyle.MUTED, 0.95))
	why.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(why)
	_vbox.move_child(why, _upgrades.get_index() + 1)
	# Apertar o trancado: som de "não dá" (o pressed não dispara em desabilitado).
	_upgrades.gui_input.connect(func(ev: InputEvent):
		if _upgrades.disabled and ev.is_action_pressed("ui_accept"):
			Audio.play_sfx("shop_fail"))


## Há combate em curso? Zona trancada ou algum inimigo vivo na cena (chefe,
## wave, Provação). Fora de um Level (menus/ferramentas) nunca.
static func in_combat(tree: SceneTree) -> bool:
	var lv := tree.current_scene
	if lv != null and "zone_active" in lv and bool(lv.get("zone_active")):
		return true
	for e in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var h = e.get("health")
		if h != null and h.has_method("is_dead") and not h.is_dead():
			return true
	return false


func _resume_game() -> void:
	PauseStack.pop(self)
	GameManager.set_state(GameManager.State.PLAYING)
	queue_free()


func _exit_tree() -> void:
	PauseStack.pop(self)


func _open_moves() -> void:
	_sub_open = true
	$Center.visible = false
	var m := MovesScreen.open(self)
	m.closed.connect(func():
		_sub_open = false
		$Center.visible = true
		_moves.grab_focus())


func _open_upgrades() -> void:
	# A loja é uma cena própria (fecha sozinha e volta para cá com run ativo).
	if _upgrades.disabled:
		return
	_sub_open = true
	$Center.visible = false
	var shop := SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	if shop == null:
		_sub_open = false
		$Center.visible = true
		return
	shop.tree_exited.connect(func():
		if not is_inside_tree():
			return
		_sub_open = false
		$Center.visible = true
		_upgrades.grab_focus())


func _open_options() -> void:
	var packed: PackedScene = load("res://scenes/ui/OptionsMenu.tscn")
	if packed == null:
		return
	_sub_open = true
	$Center.visible = false
	var opt := packed.instantiate()
	opt.overlay = true
	add_child(opt)
	opt.closed.connect(func():
		_sub_open = false
		$Center.visible = true
		_options.grab_focus())


func _ask_quit() -> void:
	_sub_open = true
	$Center.visible = false
	var sc := RunManager.checkpoint_for(RunManager.current_screen)
	var body := "Você volta ao menu. O ponto de retorno salvo permanece: %s, tela %d." % [RunManager.eon_name(sc), sc]
	if CodexSession.active:
		body = "Você volta ao menu. A Provação não grava progresso."
	CodexStyle.confirm(self, "Abandonar a jornada?", body, "Abandonar", _quit_now, "Voltar", func():
		_sub_open = false
		$Center.visible = true
		_quit.grab_focus())


func _quit_now() -> void:
	# Guarda o checkpoint em memória antes de encerrar o run: o menu mostra
	# "Continuar" na hora e um save de opções não apaga o run do disco.
	if RunManager.run_active and not CodexSession.active:
		RunManager.saved_run = RunManager.run_snapshot()
	PauseStack.clear()                 # volta ao menu: ninguém mais segura o mundo
	Audio.play_sfx("ui_back")
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _sub_open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume_game()
