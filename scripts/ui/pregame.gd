extends Control
## Pré-jogo: só a dificuldade (a provação). A personagem é única = Sophia.

var chosen_diff: int = GameManager.Difficulty.NORMAL
var diff_buttons: Array[Button] = []

const DIFFS := [
	GameManager.Difficulty.NORMAL,
	GameManager.Difficulty.HARD,
	GameManager.Difficulty.VERY_HARD,
	GameManager.Difficulty.CHAMPION,
]
const DIFF_NAMES := ["Normal", "Difícil", "Muito Difícil", "Campeão"]

@onready var diff_box: HBoxContainer = $Center/VBox/DiffBox
@onready var desc: Label = $Center/VBox/Desc


func _ready() -> void:
	CodexStyle.apply_existing(self, true)
	var hero: CharacterData = GameContent.characters[0] if GameContent.characters.size() > 0 else null
	if hero:
		desc.text = "%s — %s" % [hero.display_name, hero.description]
	$Center/VBox/Title.text = "A travessia começa"
	$Center/VBox.custom_minimum_size.x = 470
	_build_diffs()
	$Center/VBox/Start.pressed.connect(_start)
	$Center/VBox/Back.pressed.connect(func(): SceneManager.change_scene("res://scenes/ui/MainMenu.tscn"))


func _build_diffs() -> void:
	for i in DIFFS.size():
		var b := Button.new()
		b.text = DIFF_NAMES[i]
		b.pressed.connect(_select_diff.bind(DIFFS[i]))
		diff_box.add_child(b)
		diff_buttons.append(b)
	_select_diff(GameManager.Difficulty.NORMAL)


func _select_diff(d: int) -> void:
	chosen_diff = d
	for i in diff_buttons.size():
		diff_buttons[i].disabled = (DIFFS[i] == d)


func _start() -> void:
	if GameContent.characters.size() > 0:
		GameManager.selected_character = GameContent.characters[0]
	GameManager.difficulty = chosen_diff
	Progression.reset_run()
	RunManager.begin()
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")
