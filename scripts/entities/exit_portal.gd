extends Area2D
class_name ExitPortal
## Fenda de luz que abre à direita quando a tela é limpa. O jogador ANDA até ela
## pra avançar (em vez de pular de tela sozinho). Desenhada por código.

signal entered

var _t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2            # detecta o corpo do player (layer 2)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 96)
	shape.shape = rect
	shape.position = Vector2(0, -44)
	add_child(shape)
	body_entered.connect(func(b):
		if b.is_in_group("player"):
			entered.emit())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var glow := 0.55 + sin(_t * 4.0) * 0.3
	var col := Color(1.0, 0.9, 0.5)
	# fenda de luz
	draw_rect(Rect2(-16, -92, 32, 92), Color(col.r, col.g, col.b, 0.14 * glow))
	draw_line(Vector2(-16, -92), Vector2(-16, 0), Color(col.r, col.g, col.b, 0.8), 2.0)
	draw_line(Vector2(16, -92), Vector2(16, 0), Color(col.r, col.g, col.b, 0.8), 2.0)
	draw_line(Vector2(-16, -92), Vector2(16, -92), Color(col.r, col.g, col.b, 0.8), 2.0)
	# setas pulsando pra direita (dica de avançar)
	for i in 3:
		var x := -2.0 + i * 9.0
		var a := clampf(glow - i * 0.18, 0.15, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, -54), Vector2(x + 7, -46), Vector2(x, -38)]), Color(col.r, col.g, col.b, a))
