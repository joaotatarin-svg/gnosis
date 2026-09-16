extends CanvasLayer
## Menu de pausa (overlay). Pausa a árvore; segue processando a si mesmo.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	$Center/Panel/VBox/Resume.pressed.connect(_resume)
	$Center/Panel/VBox/Upgrades.pressed.connect(_open_upgrades)
	$Center/Panel/VBox/Quit.pressed.connect(_quit)


func _resume() -> void:
	get_tree().paused = false
	GameManager.set_state(GameManager.State.PLAYING)
	queue_free()


func _open_upgrades() -> void:
	SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")


func _quit() -> void:
	get_tree().paused = false
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_resume()
