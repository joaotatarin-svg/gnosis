extends Node2D
class_name AoeNova
## Nova de área: anel de luz que expande e fere todos os Arcontes no raio.
## Usada por AoE (Nova de Éter, Armadilha) e como finisher visual.

var radius: float = 110.0
var damage: int = 40
var knockback: float = 260.0
var color: Color = Color(0.6, 0.8, 1.0)
var duration: float = 0.45

var _time: float = 0.0
var _hit_done: bool = false


static func spawn(parent: Node, pos: Vector2, dmg: int, rad: float, col: Color) -> void:
	var n := AoeNova.new()
	n.damage = dmg
	n.radius = rad
	n.color = col
	parent.add_child(n)
	n.global_position = pos


func _ready() -> void:
	Juice.shake(0.45)


func _process(delta: float) -> void:
	_time += delta
	if not _hit_done and _time >= 0.06:
		_hit_done = true
		if damage > 0:      # damage 0 = onda puramente visual (slam de Arconte)
			_damage_area()
	queue_redraw()
	if _time >= duration:
		queue_free()


func _damage_area() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d: Vector2 = e.global_position - global_position
		if d.length() <= radius and e.has_method("apply_damage"):
			e.apply_damage(damage, global_position, knockback)


func _draw() -> void:
	var t := _time / duration
	var r := radius * ease(t, 0.4)
	var fade := 1.0 - t
	# anel principal + eco + clarão central
	draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(color.r, color.g, color.b, 0.85 * fade), 2.0 * (1.0 - t * 0.5))
	draw_arc(Vector2.ZERO, r * 0.72, 0, TAU, 64, Color(color.r, color.g, color.b, 0.35 * fade), 2.0)
	draw_circle(Vector2.ZERO, r * 0.3 * (1.0 - t), Color(1, 1, 1, 0.24 * fade))
