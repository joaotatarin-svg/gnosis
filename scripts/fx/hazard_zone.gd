extends Node2D
class_name HazardZone
## Zona de perigo no chão, desenhada por código. Usada pelos Arcontes:
##  - "sleep"  (Torpor): dentro dela a Sophia anda devagar (névoa do sono).
##  - "poison" (Praga): dano contínuo enquanto ficar em cima.
##  - "pillar" (Onda 6, inimigos): AVISO no chão (anel que enche por `warn` s) e
##    depois uma coluna de luz que fere UMA vez quem estiver dentro (qualquer
##    altura). Ataque de área de conjuradores e voadores: lê-se e sai-se dele.
## Some sozinha após `duration`.

var kind: String = "sleep"
var radius: float = 60.0
var duration: float = 4.0
var color: Color = Color(0.6, 0.55, 0.9)
var hostile_to: String = "player"   # "player" (zona de Arconte) ou "enemy" (magia da Sophia)
var damage: int = 0                 # dano por tick quando hostil a inimigos

var warn: float = 0.8               # pillar: tempo de aviso antes da coluna
var _t: float = 0.0
var _tick: float = 0.0
var _struck: bool = false


static func spawn(parent: Node, pos: Vector2, p_kind: String, p_radius: float, p_duration: float, p_color: Color, p_hostile_to: String = "player", p_damage: int = 0) -> void:
	var z := HazardZone.new()
	z.kind = p_kind
	z.radius = p_radius
	z.duration = p_duration
	z.color = p_color
	z.hostile_to = p_hostile_to
	z.damage = p_damage
	z.z_index = -1          # fica atrás dos personagens (é chão)
	parent.add_child(z)
	z.global_position = pos


## VFX7: visual premium — névoa/bolhas por partículas, chão com luz macia em
## camadas, borda que cintila e, na coluna, aviso que enche + pilar de luz
## aditivo com anel e faíscas. Montado no 1º quadro (o spawn põe a posição
## depois do add_child).
var _fx_ready: bool = false


func _build_fx() -> void:
	_fx_ready = true
	var par := get_parent()
	if kind == "pillar":
		VfxLibrary.shock_ring(par, global_position, radius, Color(color.r, color.g, color.b, 0.5), maxf(0.2, warn), false, 0.32, 0.1)
		return
	VfxLibrary.shock_ring(par, global_position, radius * 1.1, Color(color.r, color.g, color.b, 0.75), 0.35, kind == "poison", 0.32, 0.12)
	var n := int(clampf(radius / 5.0, 8.0, 26.0))
	if kind == "sleep":
		var m := _zone_particles("smoke2", n, 2.4, true)
		m.gravity = Vector2(0, -5.0)
		m.initial_velocity_min = 3.0
		m.initial_velocity_max = 10.0
		m.scale_amount_min = radius / 128.0 * 0.5
		m.scale_amount_max = radius / 128.0 * 0.85
		m.scale_amount_curve = VfxLibrary._grow_curve()
		m.color_ramp = _ramp3(Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 0.5), Color(color.r, color.g, color.b, 0.0))
		var b := _zone_particles("circle", maxi(4, n / 3), 2.0, true)
		b.gravity = Vector2(0, -14.0)
		b.initial_velocity_min = 4.0
		b.initial_velocity_max = 12.0
		b.scale_amount_min = 0.035
		b.scale_amount_max = 0.07
		b.color_ramp = _ramp3(Color(1, 1, 1, 0.0), Color(color.r, color.g, color.b, 0.8), Color(color.r, color.g, color.b, 0.0))
	else:
		var b2 := _zone_particles("circle", n, 0.9, true)
		b2.gravity = Vector2(0, -30.0)
		b2.initial_velocity_min = 8.0
		b2.initial_velocity_max = 26.0
		b2.scale_amount_min = 0.04
		b2.scale_amount_max = 0.09
		b2.scale_amount_curve = VfxLibrary._scale_curve(0.7)
		b2.color_ramp = _ramp3(Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 0.9), Color(1, 1, 1, 0.0))
		var f := _zone_particles("smoke", maxi(4, n / 3), 1.8, false)
		f.gravity = Vector2(0, -8.0)
		f.initial_velocity_min = 4.0
		f.initial_velocity_max = 12.0
		f.scale_amount_min = radius / 128.0 * 0.25
		f.scale_amount_max = radius / 128.0 * 0.45
		f.scale_amount_curve = VfxLibrary._grow_curve()
		f.color_ramp = _ramp3(Color(color.r * 0.55, color.g * 0.65, color.b * 0.4, 0.0), Color(color.r * 0.55, color.g * 0.65, color.b * 0.4, 0.55), Color(0, 0, 0, 0))


func _zone_particles(tex_name: String, amount: int, life: float, additive: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = VfxLibrary.tex(tex_name)
	p.amount = amount
	p.lifetime = life
	p.preprocess = life * 0.6
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(radius * 0.85, radius * 0.12)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.lifetime_randomness = 0.4
	if additive:
		p.material = VfxLibrary._additive()
	add_child(p)
	p.emitting = true
	return p


static func _ramp3(a: Color, b: Color, c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, c)
	g.add_point(0.35, b)
	return g


## A coluna de luz desce (premium): pilar aditivo, anel deitado, faíscas subindo.
func _pillar_strike_fx() -> void:
	var par := get_parent()
	var fb := VfxLibrary.flash_budget()
	var s := Sprite2D.new()
	s.texture = VfxLibrary.tex("light")
	s.material = VfxLibrary._additive()
	s.modulate = Color(color.r, color.g, color.b, 0.95 * fb)
	s.offset = Vector2(0, -64)
	s.scale = Vector2(radius / 64.0 * 1.5, 0.2)
	s.z_index = VfxLibrary.Z
	par.add_child(s)
	s.global_position = global_position
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(radius / 64.0 * 0.9, 2.4), 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.4).set_delay(0.08).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(s.queue_free)
	VfxLibrary.shock_ring(par, global_position, radius * 1.4, color, 0.35, false, 0.32, 0.12)
	VfxLibrary.ground_decal(par, global_position, color, radius * 2.4, true, 0.5)
	var sp := VfxLibrary._burst(par, global_position, "spark", 12, 0.6)
	sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sp.emission_rect_extents = Vector2(radius * 0.6, 4.0)
	sp.direction = Vector2(0, -1)
	sp.spread = 12.0
	sp.gravity = Vector2(0, 120.0)
	sp.initial_velocity_min = 120.0
	sp.initial_velocity_max = 260.0
	sp.scale_amount_min = 0.04
	sp.scale_amount_max = 0.08
	sp.color = color.lightened(0.4)


func _physics_process(delta: float) -> void:
	if not _fx_ready:
		_build_fx()
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()
	if hostile_to == "enemy":
		# Magia da Sophia: inimigos dentro tomam dano (praga) ou ficam lentos (sono).
		_tick -= delta
		if _tick > 0.0:
			return
		_tick = 0.6
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e):
				continue
			if absf(e.global_position.x - global_position.x) <= radius and absf(e.global_position.y - global_position.y) < 70.0:
				if kind == "sleep":
					if e.has_method("apply_slow"):
						e.apply_slow(0.8)
				elif e.has_method("apply_damage"):
					e.apply_damage(damage, global_position, 30.0)
		return
	var p := get_tree().get_first_node_in_group("player")
	if kind == "pillar":
		if not _struck and _t >= warn:
			_struck = true
			_pillar_strike_fx()
			Juice.shake(0.18)
			if p != null and is_instance_valid(p) and absf(p.global_position.x - global_position.x) <= radius 					and p.global_position.y > global_position.y - 260.0 and p.global_position.y < global_position.y + 20.0:
				p._on_hit_received(damage, global_position + Vector2(0, -40), 150.0, false, null)
		return
	if p != null and is_instance_valid(p):
		var inside := absf(p.global_position.x - global_position.x) <= radius \
			and absf(p.global_position.y - global_position.y) < 60.0
		if inside:
			if kind == "sleep":
				p.status_slow = 0.25
			else:
				_tick -= delta
				if _tick <= 0.0:
					_tick = 0.7
					var dmg := 3 + int(GameManager.current_screen / 10)
					p._on_hit_received(dmg, global_position, 40.0, true, null)


func _draw() -> void:
	if kind == "pillar":
		_draw_pillar()
		return
	var life := 1.0 - _t / duration
	var fade := minf(1.0, life * 3.0) * minf(1.0, _t * 5.0)    # acende rápido, apaga suave
	var pulse := 0.5 + sin(_t * 4.0) * 0.5
	var ry := radius * 0.32
	# chão: 3 elipses concêntricas (luz macia no meio, some na borda)
	for layer in 3:
		var k := 1.0 - float(layer) * 0.28
		draw_colored_polygon(_ellipse(radius * k, ry * k), Color(color.r, color.g, color.b, (0.1 + 0.05 * pulse) * fade))
	# borda que cintila: segmentos com brilho correndo em volta
	var seg := 32
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var shine := 0.5 + 0.5 * sin(a0 * 3.0 - _t * (2.0 if kind == "sleep" else 5.0))
		draw_line(Vector2(cos(a0) * radius, sin(a0) * ry), Vector2(cos(a1) * radius, sin(a1) * ry),
			Color(color.r, color.g, color.b, (0.25 + 0.5 * shine) * fade), 1.5, true)
	# runas da Sophia (zona dela, hostil aos inimigos): 6 pontos de luz girando
	if hostile_to == "enemy":
		for i in 6:
			var a := TAU * float(i) / 6.0 + _t * 0.6
			draw_circle(Vector2(cos(a) * radius * 0.8, sin(a) * ry * 0.8), 1.6, Color(1, 1, 1, 0.6 * fade))


func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Coluna de luz: aviso (anel + enchimento que cresce + fio de luz) → golpe.
func _draw_pillar() -> void:
	var ry := radius * 0.32
	var pts := _ellipse(radius, ry)
	if not _struck:
		var k := clampf(_t / maxf(warn, 0.01), 0.0, 1.0)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(color.r, color.g, color.b, 0.85), 1.5, true)
		draw_colored_polygon(_ellipse(radius * k, ry * k), Color(color.r, color.g, color.b, 0.22 + 0.25 * k))
		# fio de luz que engrossa (o céu vai cair aqui)
		draw_line(Vector2(0, 0), Vector2(0, -240), Color(color.r, color.g, color.b, 0.12 + 0.3 * k), 1.0 + 3.0 * k)
		return
	var f := clampf(1.0 - (_t - warn) / maxf(duration - warn, 0.01), 0.0, 1.0)
	draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.4 * f))


## Atalho do pilar: aviso de `p_warn` s e dano `dmg` uma vez.
static func pillar(parent: Node, pos: Vector2, p_radius: float, p_warn: float, dmg: int, p_color: Color) -> void:
	var z := HazardZone.new()
	z.kind = "pillar"
	z.radius = p_radius
	z.warn = p_warn
	z.duration = p_warn + 0.35
	z.color = p_color
	z.damage = dmg
	z.z_index = -1
	parent.add_child(z)
	z.global_position = pos
