extends Control
class_name EndScreen
## Tela de fim. Vitória (um dos três finais) → pintura da Mente ao fundo;
## derrota fora de run (rara: os checkpoints recompõem a Sophia) → pintura do
## Éon onde caiu. Título e texto vêm do GameManager/Narrative; "Crônicas: N/T"
## aparece se o autoload Gnosis expuser a contagem.
## FIM DA DEMO (#27/#52): card "Fim da demo — obrigado por jogar" + botão
## "Lista de desejos" (abre `gnosis/store_url`). Chega aqui pelo sinal
## `GameManager.demo_finished` (gancho `ensure_demo_hook()`, ligado pelo menu e
## pelo pré-jogo) ou pelo fallback do próprio GameManager (end_title).

const STORE_URL_SETTING := "gnosis/store_url"

## Ligado pelo gancho da demo antes de trocar para esta cena.
static var demo_card: bool = false

@onready var _painting: TextureRect = $Painting
@onready var _vbox: VBoxContainer = $Center/Panel/VBox


func _ready() -> void:
	CodexStyle.apply_existing(self)
	if is_demo_end():
		demo_card = false
		_build_demo()
		return
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


## Esta tela é o fim da demo? (gancho do sinal ou fallback do GameManager)
static func is_demo_end() -> bool:
	if demo_card:
		return true
	return "demo" in GameManager and bool(GameManager.get("demo")) and GameManager.end_title == "Fim da demo"


## Liga `GameManager.demo_finished` → esta tela (uma vez por execução; nó na
## raiz, então sobrevive às trocas de cena). Sem demo ou sem o sinal: nada.
static func ensure_demo_hook() -> void:
	if not ("demo" in GameManager and bool(GameManager.get("demo"))) or not GameManager.has_signal("demo_finished"):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root.get_node_or_null("DemoEndHook") != null:
		return
	var hook := _DemoHook.new()
	hook.name = "DemoEndHook"
	tree.root.add_child.call_deferred(hook)


class _DemoHook extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		GameManager.connect("demo_finished", _on_demo_finished)

	func _on_demo_finished() -> void:
		EndScreen.demo_card = true
		PauseStack.clear()
		SceneManager.change_scene("res://scenes/ui/EndScreen.tscn")


static func store_url() -> String:
	return String(ProjectSettings.get_setting(STORE_URL_SETTING, "")).strip_edges()


## Card do fim da demo: sem spoiler do resto da subida.
func _build_demo() -> void:
	_vbox.custom_minimum_size.x = 440
	_painting.texture = PaintedLibrary.background(clampi(RunManager.eon_index(RunManager.FIRST_EON_SCREEN), 0, 8))
	_painting.modulate = Color(0.6, 0.66, 0.72)
	var kicker: Label = $Center/Panel/VBox/Kicker
	kicker.text = "DEMO  ·  O LIMIAR E O TORPOR"
	kicker.add_theme_font_override("font", CodexStyle.display())
	kicker.add_theme_font_size_override("font_size", 9)
	kicker.add_theme_color_override("font_color", CodexStyle.GOLD)
	var title: Label = $Center/Panel/VBox/Title
	title.text = "Fim da demo"
	title.add_theme_font_override("font", CodexStyle.display_font_for(30))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", CodexStyle.PAPER)
	var rule := CodexStyle.Rule.new()
	rule.custom_minimum_size = Vector2(0, 7)
	rule.color = Color(CodexStyle.GOLD, 0.85)
	_vbox.add_child(rule)
	_vbox.move_child(rule, title.get_index() + 1)
	var sub: Label = $Center/Panel/VBox/Subtitle
	sub.text = "Obrigado por jogar.\nA subida continua por mais seis Éons no jogo completo."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size.x = 420
	sub.add_theme_color_override("font_color", Color(CodexStyle.PAPER, 0.85))
	sub.add_theme_font_override("font", CodexStyle.italic())
	sub.add_theme_font_size_override("font_size", 13)
	var chron: Label = $Center/Panel/VBox/Chronicles
	var url := store_url()
	chron.text = "Adicione GNOSIS à sua lista de desejos." if url != "" else ""
	chron.visible = url != ""
	chron.add_theme_font_override("font", CodexStyle.display())
	chron.add_theme_font_size_override("font_size", 8)
	chron.add_theme_color_override("font_color", CodexStyle.GOLD)
	var retry: Button = $Center/Panel/VBox/Buttons/Retry
	var menu: Button = $Center/Panel/VBox/Buttons/Menu
	retry.text = "Lista de desejos"
	retry.visible = url != ""                # sem URL (o João define), sem botão
	retry.tooltip_text = url
	retry.pressed.connect(func():
		if store_url() != "":
			OS.shell_open(store_url()))
	menu.pressed.connect(func():
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn"))
	for b in $Center/Panel/VBox/Buttons.get_children():
		b.custom_minimum_size = Vector2(150, CodexStyle.BTN_H)
	CodexStyle.style_button(retry, true)
	if url != "":
		retry.grab_focus()
	else:
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
