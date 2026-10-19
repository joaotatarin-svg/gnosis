extends Node2D
class_name ImpactBurst
## Explosão de impacto: fagulhas vetoriais que voam e somem. Barata, sem
## partículas de engine — só _draw. Auto-remove.

var color: Color = Color(1.0, 0.9, 0.5)
var _time: float = 0.0
var _dirs: Array[Vector2] = []

const LIFE := 0.32


## `heavy` = o golpe pesado ganha as partículas grandes (talho + poeira) NESTE
## mesmo ponto — R4: um acerto = um evento de impacto, não dois empilhados.
static func spawn(parent: Node, pos: Vector2, col: Color, heavy: bool = false) -> void:
	# VFX7: se quem acertou foi um projétil com visual premium, o impacto é
	# dele (por família: clarão, anel, faíscas direcionais, decalque) — um
	# acerto = um evento (R4).
	var fx := ProjectileFX.find_at(pos)
	if fx != null:
		fx.impact(pos)
		return
	# golpe corpo a corpo de INIMIGO na Sophia (hitbox.gd pinta com esta cor):
	# garras de luz + borrifo escuro, no padrão dos impactos premium
	if col.is_equal_approx(VfxLibrary.ENEMY_HIT_COLOR):
		var b0 := ImpactBurst.new()
		b0.color = col
		parent.add_child(b0)
		b0.global_position = pos
		VfxLibrary.claw_impact(parent, pos, heavy)
		return
	var b := ImpactBurst.new()
	b.color = col
	parent.add_child(b)
	b.global_position = pos
	# partículas por cima do desenho vetorial
	VfxLibrary.hit(parent, pos, heavy, col)


func _ready() -> void:
	for i in 7:
		var a := randf() * TAU
		_dirs.append(Vector2(cos(a), sin(a)) * randf_range(40.0, 110.0))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= LIFE:
		queue_free()


func _draw() -> void:
	var t := _time / LIFE
	var fade := 1.0 - t
	for d in _dirs:
		var p := d * ease(t, 0.35)
		draw_line(p - d.normalized() * 8.0 * fade, p, Color(color, fade * 0.6), maxf(0.5, fade), true)
		draw_circle(p, 2.0 * fade, Color(color.r, color.g, color.b, fade))
		draw_circle(p, 1.2 * fade, Color(1, 1, 1, fade))
	draw_arc(Vector2.ZERO, 4.0 + t * 20.0, 0, TAU, 32, Color(color, fade * 0.45), 0.8, true)
	draw_circle(Vector2.ZERO, 10.0 * (1.0 - t), Color(1, 1, 1, 0.4 * fade))
