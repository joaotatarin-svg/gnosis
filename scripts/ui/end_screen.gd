extends Control
## Tela de fim. Vitória (um dos três finais) → pintura da Mente ao fundo;
## derrota fora de run (rara: os checkpoints recompõem a Sophia) → pintura do
## Éon onde caiu. Título e texto vêm do GameManager/Narrative; "Crônicas: N/T"
## aparece se o autoload Gnosis expuser a contagem.

@onready var _painting: TextureRect = $Painting
@onready var _vbox: VBoxContainer = $Center/Panel/VBox


func _ready() -> void:
	CodexStyle.apply_existing(self)
	var won := Narrative.ending != ""
	_vbox.custom_minimum_size.x = 440
	# Fundo: pintura da Mente na vitória; do Éon da queda na derrota.
	var eon := 8 if won else clampi(RunManager.eon_index(GameManager.current_screen), 0, 8)
	_painting.texture = PaintedLibrary.background(eon)
	_painting.modulate = Color(0.7, 0.75, 0.8) if won else Color(0.45, 0.42, 0.5)
	var kicker: Label = $Center/Panel/VBox/Kicker
	kicker.text = "A TRAVESSIA TERMINOU" if won else "A FAÍSCA SE APAGOU"
	kicker.add_theme_font_override("font", CodexStyle.display())
	kicker.add_theme_font_size_override("font_size", 9)
	kicker.add_theme_color_override("font_color", CodexStyle.GOLD)
	var title: Label = $Center/Panel/VBox/Title
	title.text = GameManager.end_title if GameManager.end_title != "" else ("Fim" if not won else "GNOSIS")
	title.add_theme_font_override("font", CodexStyle.display_font_for(30))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", CodexStyle.PAPER if won else Color("d9c7c0"))
	var rule := CodexStyle.Rule.new()
	rule.custom_minimum_size = Vector2(0, 7)
	rule.color = Color(CodexStyle.GOLD if won else CodexStyle.EMBER, 0.85)
	_vbox.add_child(rule)
	_vbox.move_child(rule, title.get_index() + 1)
	var sub: Label = $Center/Panel/VBox/Subtitle
	sub.text = GameManager.end_subtitle
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 420
	sub.add_theme_color_override("font_color", Color(CodexStyle.PAPER, 0.85))
	sub.add_theme_font_override("font", CodexStyle.italic())
	sub.add_theme_font_size_override("font_size", 13)
	var chron: Label = $Center/Panel/VBox/Chronicles
	chron.add_theme_font_override("font", CodexStyle.display())
	chron.add_theme_font_size_override("font_size", 8)
	chron.add_theme_color_override("font_color", CodexStyle.GOLD)
	if Gnosis.has_method("chronicles_count") and Gnosis.has_method("chronicles_total"):
		var seen: int = int(Gnosis.call("chronicles_count"))
		var total: int = int(Gnosis.call("chronicles_total"))
		var finals := RunManager.endings_seen.size()
		chron.text = "Crônicas  %d / %d      ·      Finais vistos  %d / 3" % [seen, total, finals]
	else:
		chron.text = "Finais vistos: %d/3" % RunManager.endings_seen.size() if won else ""
		chron.visible = won
	var retry: Button = $Center/Panel/VBox/Buttons/Retry
	var menu: Button = $Center/Panel/VBox/Buttons/Menu
	retry.text = "Jogar de novo" if won else "Tentar de novo"
	retry.pressed.connect(_retry)
	menu.pressed.connect(func():
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn"))
	# Vitória: os créditos ficam a um botão (atribuição das músicas incluída).
	if won:
		var cred := Button.new()
		cred.text = "Créditos"
		CodexStyle.style_button(cred)
		CodexStyle._wire(cred)
		cred.pressed.connect(func():
			Credits.return_to = "res://scenes/ui/MainMenu.tscn"
			SceneManager.change_scene("res://scenes/ui/Credits.tscn"))
		$Center/Panel/VBox/Buttons.add_child(cred)
		$Center/Panel/VBox/Buttons.move_child(cred, 1)
	for b in $Center/Panel/VBox/Buttons.get_children():
		b.custom_minimum_size = Vector2(120, CodexStyle.BTN_H)
	CodexStyle.style_button(retry, won)
	menu.grab_focus()
	CodexStyle.pop_in($Center/Panel, "")


func _retry() -> void:
	Progression.reset_run()
	RunManager.begin()
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
