extends Control
## Tela de fim (game over ou vitória). Texto vem do GameManager.

func _ready() -> void:
	CodexStyle.apply_existing(self, true)
	$Center/VBox.custom_minimum_size.x = 480
	$Center/VBox/Subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Center/VBox/Subtitle.custom_minimum_size.x = 480
	$Center/VBox/Title.text = GameManager.end_title
	$Center/VBox/Subtitle.text = GameManager.end_subtitle
	$Center/VBox/Best.text = "Melhor progresso: Tela %d" % RunManager.best_screen
	$Center/VBox/Retry.pressed.connect(_retry)
	$Center/VBox/Menu.pressed.connect(func(): SceneManager.change_scene("res://scenes/ui/MainMenu.tscn"))


func _retry() -> void:
	Progression.reset_run()
	RunManager.begin()
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")
