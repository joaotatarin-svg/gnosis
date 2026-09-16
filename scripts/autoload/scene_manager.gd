extends Node
## Troca de cenas com FADE + helper de overlay. Autoload `SceneManager`.

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.02, 0.06, 1.0)
	_fade.anchors_preset = Control.PRESET_FULL_RECT
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.22)
	await t.finished
	get_tree().change_scene_to_file(path)
	var t2 := create_tween()
	t2.tween_property(_fade, "modulate:a", 0.0, 0.28)
	await t2.finished
	_busy = false


## Instancia uma cena por cima da cena atual (ex.: pausa, loja).
func instance_overlay(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Cena não encontrada: " + path)
		return null
	var inst := packed.instantiate()
	get_tree().current_scene.add_child(inst)
	return inst
