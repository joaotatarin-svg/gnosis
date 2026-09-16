extends CanvasLayer
## Contador de FPS no canto. Liga/desliga com F3. Autoload `FpsOverlay`.

var _label: Label
var _shown: bool = false


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(560, 8)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	_label.visible = false
	add_child(_label)


func _process(_delta: float) -> void:
	if _shown:
		_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_shown = not _shown
		_label.visible = _shown
