extends Control
## Pré-jogo da NOVA CAMPANHA: dificuldade + atalho pra tela de golpes.
## A personagem é única = Sophia. Daqui vai pra tela 1 (o Limiar).

var chosen_diff: int = GameManager.Difficulty.NORMAL
var diff_buttons: Array[Button] = []

const DIFFS := [
	GameManager.Difficulty.NORMAL,
	GameManager.Difficulty.HARD,
	GameManager.Difficulty.VERY_HARD,
	GameManager.Difficulty.CHAMPION,
]
const DIFF_NAMES := ["Normal", "Difícil", "Muito Difícil", "Campeão"]
const DIFF_DESCS := [
	"A travessia como foi pensada. Pontos de retorno a cada Éon.",
	"Inimigos com 50% a mais de vida e dano.",
	"Mais que o dobro. Para quem já lê o vermelho e o amarelo.",
	"Vida e dano ×3,5. Apare só o necessário — e não erre.",
]

@onready var diff_box: HBoxContainer = $Center/VBox/DiffBox
@onready var desc: Label = $Center/VBox/Desc
@onready var diff_desc: Label = $Center/VBox/DiffDesc


func _ready() -> void:
	CodexSession.leave_demo()           # veio da Provação? encerra o sandbox
	EndScreen.ensure_demo_hook()        # demo: o fim do Athoth abre o card de fim
	CodexStyle.apply_existing(self, true)
	var hero: CharacterData = GameContent.characters[0] if GameContent.characters.size() > 0 else null
	if hero:
		desc.text = "%s — %s" % [hero.display_name, hero.description]
	desc.add_theme_color_override("font_color", CodexStyle.MUTED)
	desc.add_theme_font_override("font", CodexStyle.italic())
	desc.add_theme_font_size_override("font_size", 12)
	var dl: Label = $Center/VBox/DiffLabel
	dl.text = "DIFICULDADE"
	dl.add_theme_font_override("font", CodexStyle.display())
	dl.add_theme_font_size_override("font_size", 9)
	dl.add_theme_color_override("font_color", CodexStyle.GOLD)
	var rule := CodexStyle.Rule.new()
	rule.custom_minimum_size = Vector2(0, 7)
	rule.color = Color(CodexStyle.GOLD, 0.85)
	$Center/VBox.add_child(rule)
	$Center/VBox.move_child(rule, 1)
	var info: Label = $Center/VBox/Info
	# Sem spoiler da estrutura (#52): nada de "o Centro"/"a Mente" nem "68 telas".
	info.text = info_text()
	info.add_theme_font_override("font", CodexStyle.display())
	info.add_theme_font_size_override("font_size", 8)
	info.add_theme_color_override("font_color", CodexStyle.GOLD)
	diff_desc.add_theme_font_size_override("font_size", 12)
	diff_desc.custom_minimum_size.y = 18
	CodexStyle.style_button($Center/VBox/Start, true)
	for b in [$Center/VBox/Start, $Center/VBox/Moves, $Center/VBox/Back]:
		b.custom_minimum_size.y = CodexStyle.BTN_H
	diff_desc.add_theme_color_override("font_color", CodexStyle.MUTED)
	$Center/VBox.custom_minimum_size.x = 470
	_build_diffs()
	$Center/VBox/Start.pressed.connect(_start)
	$Center/VBox/Moves.pressed.connect(_open_moves)
	$Center/VBox/Back.pressed.connect(func():
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn"))
	diff_box.add_theme_constant_override("separation", 8)
	$Center/VBox/Start.grab_focus()
	CodexStyle.stagger_in([$Center/VBox], 0.0, 0.0)


static func info_text() -> String:
	if "demo" in GameManager and bool(GameManager.get("demo")):
		return "Demo  ·  o Limiar e o Torpor  ·  ~20 minutos"
	return "Sete Éons  ·  Sete Arcontes  ·  ~2–3 horas"


func _build_diffs() -> void:
	for i in DIFFS.size():
		var b := Button.new()
		b.text = DIFF_NAMES[i]
		b.pressed.connect(_select_diff.bind(DIFFS[i]))
		b.custom_minimum_size = Vector2(108, CodexStyle.BTN_H)
		diff_box.add_child(b)
		diff_buttons.append(b)
	_select_diff(GameManager.Difficulty.NORMAL)


func _select_diff(d: int) -> void:
	chosen_diff = d
	for i in diff_buttons.size():
		var sel: bool = DIFFS[i] == d
		diff_buttons[i].add_theme_color_override("font_color", CodexStyle.GOLD_HI if sel else Color(CodexStyle.PAPER, 0.75))
		diff_buttons[i].add_theme_stylebox_override("normal", CodexStyle.button_frame("hover" if sel else "normal"))
		diff_buttons[i].text = DIFF_NAMES[i]
	diff_desc.text = DIFF_DESCS[clampi(DIFFS.find(d), 0, DIFF_DESCS.size() - 1)]


func _open_moves() -> void:
	var m := MovesScreen.open(self)
	m.closed.connect(func(): $Center/VBox/Moves.grab_focus())


func _start() -> void:
	if GameContent.characters.size() > 0:
		GameManager.selected_character = GameContent.characters[0]
	GameManager.difficulty = chosen_diff
	Progression.reset_run()
	RunManager.begin()
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
