extends CanvasLayer
## Menu de pausa (overlay). Pausa a árvore; segue processando a si mesmo.
## Continuar · Golpes & Controles · Melhorias (a loja) · Opções (overlay que
## volta PRA CÁ, não pro menu) · Abandonar run (confirma; o checkpoint salvo
## permanece). Mostra o papel da tela ("Torpor · Travessia II").

@onready var _vbox: VBoxContainer = $Center/Panel/VBox
@onready var _resume: Button = $Center/Panel/VBox/Resume
@onready var _moves: Button = $Center/Panel/VBox/Moves
@onready var _upgrades: Button = $Center/Panel/VBox/Upgrades
@onready var _options: Button = $Center/Panel/VBox/Options
@onready var _quit: Button = $Center/Panel/VBox/Quit

var _sub_open: bool = false     # um overlay (golpes/opções/loja) está aberto


func _ready() -> void:
	CodexStyle.apply_existing(self)
	_vbox.custom_minimum_size.x = 300
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var role: Label = $Center/Panel/VBox/Role
	role.text = _role_text()
	role.add_theme_font_size_override("font_size", 10)
	role.add_theme_color_override("font_color", CodexStyle.GOLD)
	_resume.pressed.connect(_resume_game)
	_moves.pressed.connect(_open_moves)
	_upgrades.pressed.connect(_open_upgrades)
	_options.pressed.connect(_open_options)
	_quit.pressed.connect(_ask_quit)
	for b in [_resume, _moves, _upgrades, _options, _quit]:
		b.pressed.connect(func(): Audio.play_sfx("ui"))
	_resume.grab_focus()


## "Torpor · Travessia II" — ou o encontro da Provação.
func _role_text() -> String:
	if CodexSession.active:
		return "Provação  ·  encontro %d / 3" % (CodexSession.stage + 1)
	return GameManager.screen_title(RunManager.current_screen)


func _resume_game() -> void:
	get_tree().paused = false
	GameManager.set_state(GameManager.State.PLAYING)
	queue_free()


func _open_moves() -> void:
	_sub_open = true
	$Center.visible = false
	var m := MovesScreen.open(self)
	m.closed.connect(func():
		_sub_open = false
		$Center.visible = true
		_moves.grab_focus())


func _open_upgrades() -> void:
	# A loja é uma cena própria (fecha sozinha e volta pra cá com run ativo).
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
	var body := "Volta pro menu. O checkpoint salvo permanece: %s (Tela %d)." % [RunManager.eon_name(sc), sc]
	if CodexSession.active:
		body = "Volta pro menu. A Provação não grava progresso."
	CodexStyle.confirm(self, "Abandonar a run?", body, "Abandonar", _quit_now, "Voltar", func():
		_sub_open = false
		$Center.visible = true
		_quit.grab_focus())


func _quit_now() -> void:
	# Guarda o checkpoint em memória antes de encerrar o run: o menu mostra
	# "Continuar" na hora e um save de opções não apaga o run do disco.
	if RunManager.run_active and not CodexSession.active:
		RunManager.saved_run = RunManager.run_snapshot()
	get_tree().paused = false
	Audio.play_sfx("ui_back")
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _sub_open:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume_game()
