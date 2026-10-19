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
## `dir` (VFX7, R15) = direção do GOLPE no acerto (quem bate → quem apanha):
## as fagulhas saem num cone de ±50° nesse sentido (+20 % em 360°) e o talho do
## pesado se alinha a ela (±15°). Sem `dir`, ela é deduzida pela posição da
## Sophia (golpe dela: dela → contato; golpe nela: contato → corpo dela).
static func spawn(parent: Node, pos: Vector2, col: Color, heavy: bool = false, dir: Vector2 = Vector2.ZERO) -> void:
	# VFX7: se quem acertou foi um projétil com visual premium, o impacto é
	# dele (por família: clarão, anel, faíscas direcionais, decalque) — um
	# acerto = um evento (R4).
	var fx := ProjectileFX.find_at(pos)
	if fx != null:
		fx.impact(pos)
		return
	var enemy_hit: bool = col.is_equal_approx(VfxLibrary.ENEMY_HIT_COLOR)
	if dir == Vector2.ZERO:
		dir = _guess_dir(parent, pos, enemy_hit)
	var b := ImpactBurst.new()
	b.color = col
	b.aim = dir
	parent.add_child(b)
	b.global_position = pos
	# golpe corpo a corpo de INIMIGO na Sophia (hitbox.gd pinta com esta cor):
	# garras de luz + borrifo escuro, no padrão dos impactos premium
	if enemy_hit:
		VfxLibrary.claw_impact(parent, pos, heavy, dir)
		return
	# partículas por cima do desenho vetorial
	VfxLibrary.hit(parent, pos, heavy, col, dir)


## Direção provável do golpe pela posição da Sophia (só eixo x; ZERO se não dá).
static func _guess_dir(parent: Node, pos: Vector2, on_sophia: bool) -> Vector2:
	if parent == null or not parent.is_inside_tree():
		return Vector2.ZERO
	var pl := parent.get_tree().get_first_node_in_group("player")
	if not (pl is Node2D):
		return Vector2.ZERO
	var dx: float = (pl as Node2D).global_position.x - pos.x
	if absf(dx) < 2.0:
		return Vector2.ZERO
	# golpe NELA: do contato para dentro do corpo dela; golpe DELA: dela para fora
	return Vector2(signf(dx) if on_sophia else -signf(dx), 0.0)


var aim: Vector2 = Vector2.ZERO


func _ready() -> void:
	# R15: com direção, 6 riscos no cone de ±50° do golpe e 1 solto
	var base: float = aim.angle() if aim != Vector2.ZERO else 0.0
	for i in 7:
		var a := randf() * TAU
		if aim != Vector2.ZERO and i < 6:
			a = base + randf_range(-0.87, 0.87) - 0.2 * signf(aim.x)
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
