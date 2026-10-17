extends Node2D
class_name SecretMark
## Marca no chão embaixo de uma saliência de PULO DUPLO: duas setas gastas
## apontando pra cima. Sem pulo duplo, ficam apagadas (um "volte depois" mudo);
## com o pulo duplo (Soter), acendem douradas — a recompensa lembra de você.

var _t: float = 0.0
var _has_dj: bool = false


func _enter_tree() -> void:
	add_to_group("lv6_objective")


func _ready() -> void:
	z_index = -1
	_has_dj = Progression.has_method("has_double_jump") and bool(Progression.call("has_double_jump"))


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 2.0) % 2 == 0:
		_has_dj = Progression.has_method("has_double_jump") and bool(Progression.call("has_double_jump"))
	queue_redraw()


func _draw() -> void:
	var gold := Color(1.0, 0.85, 0.45)
	var a := 0.55 + 0.3 * sin(_t * 3.0) if _has_dj else 0.16
	for k in 2:
		var y := -6.0 - float(k) * 7.0
		draw_polyline(PackedVector2Array([Vector2(-6, y + 4), Vector2(0, y - 1), Vector2(6, y + 4)]), Color(gold, a), 1.6, true)
	draw_set_transform(Vector2(0, 1), 0, Vector2(1, 0.25))
	draw_arc(Vector2.ZERO, 14.0, 0, TAU, 20, Color(gold, a * 0.6), 1.2, true)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
