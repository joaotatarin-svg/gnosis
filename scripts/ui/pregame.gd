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
	"A travessia como foi pensada. Checkpoints a cada Éon.",
	"Inimigos com 50% mais vida e dano.",
	"Mais que o dobro. Pra quem já leu o vermelho e o amarelo.",
	"3,5×. Só apare o que for preciso — e não erre.",
]

@onready var diff_box: HBoxContainer = $Center/VBox/DiffBox
@onready var desc: Label = $Center/VBox/Desc
@onready var diff_desc: Label = $Center/VBox/DiffDesc


func _ready() -> void:
	CodexSession.leave_demo()           # veio da Provação? encerra o sandbox
	CodexStyle.apply_existing(self, true)
	var hero: CharacterData = GameContent.characters[0] if GameContent.characters.size() > 0 else null
	if hero:
		desc.text = "%s — %s" % [hero.display_name, hero.description]
	desc.add_theme_color_override("font_color", CodexStyle.MUTED)
	var info: Label = $Center/VBox/Info
	info.text = "%d telas  ·  sete Éons  ·  sete Arcontes  ·  o Centro  ·  a Mente" % RunManager.MAX_SCREEN
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", CodexStyle.GOLD)
	diff_desc.add_theme_font_size_override("font_size", 10)
	diff_desc.add_theme_color_override("font_color", CodexStyle.MUTED)
	$Center/VBox.custom_minimum_size.x = 470
	_build_diffs()
	$Center/VBox/Start.pressed.connect(_start)
	$Center/VBox/Moves.pressed.connect(_open_moves)
	$Center/VBox/Back.pressed.connect(func():
		Audio.play_sfx("ui_back")
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn"))
	$Center/VBox/Start.grab_focus()


func _build_diffs() -> void:
	for i in DIFFS.size():
		var b := Button.new()
		b.text = DIFF_NAMES[i]
		b.pressed.connect(_select_diff.bind(DIFFS[i]))
		b.pressed.connect(func(): Audio.play_sfx("ui"))
		diff_box.add_child(b)
		diff_buttons.append(b)
	_select_diff(GameManager.Difficulty.NORMAL)


func _select_diff(d: int) -> void:
	chosen_diff = d
	for i in diff_buttons.size():
		var sel: bool = DIFFS[i] == d
		diff_buttons[i].add_theme_color_override("font_color", CodexStyle.GOLD if sel else CodexStyle.PAPER)
		diff_buttons[i].text = ("◆ " if sel else "") + DIFF_NAMES[i]
	diff_desc.text = DIFF_DESCS[clampi(DIFFS.find(d), 0, DIFF_DESCS.size() - 1)]


func _open_moves() -> void:
	Audio.play_sfx("ui")
	var m := MovesScreen.open(self)
	m.closed.connect(func(): $Center/VBox/Moves.grab_focus())


func _start() -> void:
	Audio.play_sfx("ui_confirm")
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
