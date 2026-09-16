extends Node2D
class_name SparkOrb
## Faísca libertada: orbe de luz que explode do Arconte morto e VOA até o
## herói (a assinatura do God of War). Puramente visual — as faíscas já foram
## creditadas na morte.

var _vel: Vector2
var _time: float = 0.0
var _homing: float = 0.0
var color := Color(1.0, 0.9, 0.5)


static func burst(parent: Node, pos: Vector2, count: int) -> void:
	for i in count:
		var o := SparkOrb.new()
		parent.add_child(o)
		o.global_position = pos
		var a := randf() * TAU
		o._vel = Vector2(cos(a), sin(a) - 0.6) * randf_range(90.0, 200.0)
		o.z_index = 40


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		# primeiro espalha, depois é "sugada" pelo herói com força crescente
		_homing = minf(_homing + delta * 3.2, 1.0)
		var to: Vector2 = (player.global_position + Vector2(0, -10)) - global_position
		var pull := to.normalized() * (700.0 * _homing * _homing)
		_vel = _vel.lerp(pull, minf(1.0, delta * 6.0))
		global_position += _vel * delta
		if to.length() < 16.0 and _time > 0.15:
			ImpactBurst.spawn(get_parent(), global_position, color)
			queue_free()
			return
	else:
		global_position += _vel * delta
	if _time > 2.5:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(_time * 20.0) * 0.2
	draw_circle(Vector2.ZERO, 5.0 * pulse, Color(color.r, color.g, color.b, 0.25))
	draw_circle(Vector2.ZERO, 2.6, color)
	draw_circle(Vector2.ZERO, 1.1, Color(1, 1, 1, 0.95))
