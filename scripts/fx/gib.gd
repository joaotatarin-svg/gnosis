extends Node2D
class_name Gib
## DESMEMBRAMENTO: uma peça do corpo (cabeça, braço, perna, caco de torso) que
## voa com física própria, gira, quica no chão e some. Desenhada por código com
## a cor do personagem + gota de luz (a faísca vazando). Sem RigidBody: física
## manual barata (dezenas por tela sem custo).

const GRAV := 950.0
## Limpeza (backlog #23 do crítico): destroços somem em 3–4 s, no máximo
## MAX_PIECES peças vivas (as mais velhas apagam rápido para dar lugar), nunca
## saem da arena (quicam na parede da zona) e nunca passam de uma tela para a
## outra (são filhos da fase; `clear_all` existe para quem trocar de tela sem
## trocar de cena).
const MAX_PIECES := 30
const MAX_DROPS := 30
const LIFE_MIN := 3.0             # vida em tempo de jogo (s)…
const LIFE_MAX := 3.6
const FADE := 0.7                 # …os últimos 0,7 s são o apagar
const HARD_MS := 4000             # teto em tempo REAL: câmera lenta não segura destroço
const EXPIRE := 0.25              # apagar rápido de quem foi despejado pelo teto
const MAX_VX := 360.0             # nada atravessa a tela num pulo só

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
var _born_ms: int = 0
var _fade_len: float = FADE      # duração do apagar (encurta quando despejado)
var _x_lo: float = -INF          # paredes da arena no nascimento
var _x_hi: float = INF
static var _last_bounce_ms: int = 0   # rate-limit global (dezenas de peças por morte)
static var _pieces: Array = []        # peças vivas, da mais velha para a mais nova
static var _drops: Array = []


## Quantas peças (sem as gotas) estão vivas agora — para sondas/QA.
static func live_pieces() -> int:
	_prune()
	return _pieces.size()


static func live_drops() -> int:
	_prune()
	return _drops.size()


## Apaga todos os destroços já (troca de tela sem troca de cena, cutscene…).
static func clear_all() -> void:
	for g in _pieces + _drops:
		if is_instance_valid(g):
			g.queue_free()
	_pieces.clear()
	_drops.clear()


static func _prune() -> void:
	_pieces = _pieces.filter(func(g): return is_instance_valid(g) and not g.is_queued_for_deletion())
	_drops = _drops.filter(func(g): return is_instance_valid(g) and not g.is_queued_for_deletion())


## Registra uma peça nova; se passou do teto, a mais velha apaga em 0,25 s.
static func _register(g: Gib) -> void:
	var list: Array = _drops if g.is_drop else _pieces
	var cap: int = MAX_DROPS if g.is_drop else MAX_PIECES
	list.append(g)
	var i := 0
	while list.size() > cap and i < list.size():
		var old: Gib = list[0]
		list.remove_at(0)
		if is_instance_valid(old):
			old._expire()
		i += 1


## Some em EXPIRE s (apagando), sem esperar a vida toda.
func _expire() -> void:
	if life - _t > FADE:              # já apagando? deixa terminar (≤ 0,7 s)
		_fade_len = EXPIRE
		life = _t + EXPIRE


## Espalha as peças de `parts` (de CharacterArt.gib_parts) a partir de `origin`.
## `facing` = sinal do scale.x do visual · `kick` = impulso do golpe (px/s).
static func burst(parent: Node, origin: Vector2, parts: Array, facing: float, ground: float, kick: Vector2, eye: Color, ink_col: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	_prune()
	# Paredes: a zona trancada (ou a arena inteira) da fase, se ela disser.
	var lo := -INF
	var hi := INF
	if parent.has_method("arena_bounds"):
		var b: Vector2 = parent.arena_bounds()
		lo = b.x + 6.0
		hi = b.y - 6.0
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
		g.vel.x = clampf(g.vel.x, -MAX_VX, MAX_VX)
		g.ang_vel = randf_range(-10.0, 10.0)
		g.life = randf_range(LIFE_MIN, LIFE_MAX)
		g._x_lo = lo
		g._x_hi = hi
		parent.add_child(g)
		g.global_position = origin + Vector2(c.x * facing, c.y)
		_register(g)
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
		d.vel.x = clampf(d.vel.x, -MAX_VX, MAX_VX)
		d.life = randf_range(1.0, 1.8)
		d._radius = d.drop_r
		d._x_lo = lo
		d._x_hi = hi
		parent.add_child(d)
		d.global_position = origin + Vector2(randf_range(-8.0, 8.0), randf_range(-24.0, -4.0))
		_register(d)


func _ready() -> void:
	add_to_group("gib")
	_born_ms = Time.get_ticks_msec()


func _process(delta: float) -> void:
	_t += delta
	# Teto em tempo real: em câmera lenta longa o destroço apaga mesmo assim.
	if Time.get_ticks_msec() - _born_ms > HARD_MS - int(FADE * 1000.0) and life - _t > FADE:
		life = _t + FADE
	if _t >= life:
		queue_free()
		return
	if not _rest:
		vel.y += GRAV * delta
		global_position += vel * delta
		rotation += ang_vel * delta
		# Parede da arena: quica de volta (nunca sai da zona nem da tela).
		if global_position.x < _x_lo + _radius and vel.x < 0.0:
			global_position.x = _x_lo + _radius
			vel.x *= -0.4
		elif global_position.x > _x_hi - _radius and vel.x > 0.0:
			global_position.x = _x_hi - _radius
			vel.x *= -0.4
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
	var span := minf(_fade_len, life)
	var tail := life - span
	if _t > tail:
		fade = clampf(1.0 - (_t - tail) / span, 0.0, 1.0)
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
