extends Node2D
class_name Gib
## DESMEMBRAMENTO: uma peça do corpo (cabeça, braço, perna, caco de torso) que
## voa com física própria, gira, quica no chão e some. Desenhada por código com
## a cor do personagem + gota de luz (a faísca vazando). Sem RigidBody: física
## manual barata (dezenas por tela sem custo).

const GRAV := 950.0

var painted_texture: Texture2D
var painted_size: Vector2
var painted_flip: float = 1.0
var pts: PackedVector2Array
var col: Color = Color(0.5, 0.5, 0.5)
var ink: Color = Color(0.1, 0.1, 0.1)
var glow: Color = Color(1, 0.9, 0.5)
var vel: Vector2 = Vector2.ZERO
var ang_vel: float = 0.0
var ground_y: float = 0.0
var life: float = 2.4
var is_drop: bool = false        # gota de luz (círculo, sem contorno)
var drop_r: float = 2.0

var _t: float = 0.0
var _radius: float = 4.0
var _rest: bool = false
var _bounced: bool = false       # só o primeiro quique soa
static var _last_bounce_ms: int = 0   # rate-limit global (dezenas de peças por morte)


## Espalha as peças de `parts` (de CharacterArt.gib_parts) a partir de `origin`.
## `facing` = sinal do scale.x do visual · `kick` = impulso do golpe (px/s).
static func burst(parent: Node, origin: Vector2, parts: Array, facing: float, ground: float, kick: Vector2, eye: Color, ink_col: Color) -> void:
	for part in parts:
		var src: PackedVector2Array = part.pts
		if src.size() < 3:
			continue
		var c := Vector2.ZERO
		for p in src:
			c += p
		c /= float(src.size())
		var local := PackedVector2Array()
		var rad := 2.0
		for p in src:
			var q: Vector2 = p - c
			q.x *= facing
			local.append(q)
			rad = maxf(rad, q.length())
		var g := Gib.new()
		if part.has("tex"):
			g.painted_texture = part.tex
			g.painted_size = part.size
			g.painted_flip = part.flip*facing
			g.material = PaintedLibrary.material()
		g.pts = local
		g.col = part.col
		g.ink = ink_col
		g.glow = eye
		g._radius = rad * 0.6
		g.ground_y = ground
		g.z_index = 6
		var away := Vector2(c.x * facing, c.y - 4.0).normalized()
		g.vel = kick * randf_range(0.55, 1.15) + away * randf_range(50.0, 150.0) + Vector2(0, -randf_range(140.0, 300.0))
		g.ang_vel = randf_range(-10.0, 10.0)
		g.life = randf_range(2.0, 2.8)
		parent.add_child(g)
		g.global_position = origin + Vector2(c.x * facing, c.y)
	# gotas de luz
	for i in 7:
		var d := Gib.new()
		d.is_drop = true
		d.drop_r = randf_range(1.4, 3.0)
		d.glow = eye
		d.col = eye
		d.ground_y = ground
		d.z_index = 6
		d.vel = kick * randf_range(0.3, 0.9) + Vector2(randf_range(-120.0, 120.0), -randf_range(120.0, 320.0))
		d.life = randf_range(1.0, 1.8)
		d._radius = d.drop_r
		parent.add_child(d)
		d.global_position = origin + Vector2(randf_range(-8.0, 8.0), randf_range(-24.0, -4.0))


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	if not _rest:
		vel.y += GRAV * delta
		global_position += vel * delta
		rotation += ang_vel * delta
		if global_position.y + _radius > ground_y:
			global_position.y = ground_y - _radius
			if absf(vel.y) < 40.0:
				_rest = true
				vel = Vector2.ZERO
				ang_vel = 0.0
			else:
				vel.y *= -0.38
				vel.x *= 0.55
				ang_vel *= 0.45
				if not _bounced and not is_drop:
					_bounced = true
					var now := Time.get_ticks_msec()
					if now - _last_bounce_ms >= 70:
						_last_bounce_ms = now
						Audio.play_sfx_at("gib_bounce", global_position, 0.12)
						VfxLibrary.dust(get_parent(), Vector2(global_position.x, ground_y))
	queue_redraw()


func _draw() -> void:
	var fade := 1.0
	var tail := life - 0.6
	if _t > tail:
		fade = clampf(1.0 - (_t - tail) / 0.6, 0.0, 1.0)
	if is_drop:
		draw_circle(Vector2.ZERO, drop_r * 1.8, Color(glow.r, glow.g, glow.b, 0.25 * fade))
		draw_circle(Vector2.ZERO, drop_r, Color(glow.r, glow.g, glow.b, fade))
		draw_circle(Vector2.ZERO, drop_r * 0.45, Color(1, 1, 1, 0.9 * fade))
		return
	if painted_texture != null:
		draw_set_transform(Vector2.ZERO,0,Vector2(painted_flip,1))
		draw_texture_rect(painted_texture,Rect2(-painted_size*0.5,painted_size),false,Color(1,1,1,fade))
		return
	var c := Color(col.r, col.g, col.b, fade)
	draw_colored_polygon(pts, c)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(ink.r, ink.g, ink.b, fade), 1.2, true)
	# ferida de luz na borda do corte (o lado "arrancado" brilha)
	draw_circle(pts[0], 2.2, Color(glow.r, glow.g, glow.b, 0.7 * fade))
