extends Node2D
class_name ProjectileFX
## VISUAL PREMIUM DE PROJÉTIL (VFX7). Nó plugável: pendure num projétil (ou em
## qualquer Node2D que voa) e ele ganha núcleo de plasma (shader), halo aditivo,
## coroa/raios girando, rastro em fita com gradiente e afinamento, partículas
## secundárias, clarão de saída, IMPACTO por família e dissipação no fim da vida.
##
## Uso (quem cria o projétil):
##   ProjectileFX.attach(proj)                 # família deduzida (AttackStyle.kind_for)
##   ProjectileFX.attach(proj, "king")         # família explícita
##   VfxLibrary.projectile_look(proj, "chain") # o mesmo, pela biblioteca
## O Projectile atual já chama `VfxLibrary.projectile_trail` no _ready — que
## agora pendura este nó. O desenho vetorial antigo do Projectile é escondido
## (`self_modulate.a = 0` só afeta o próprio _draw dele, não os filhos).
##
## Impacto: o Projectile chama `ImpactBurst.spawn(pos)` ao acertar; o
## ImpactBurst pergunta `ProjectileFX.find_at(pos)` e, se for deste projétil,
## delega o impacto premium (um acerto = um evento, R4).

const TRAIL_STEP := 4.0            # px entre pontos do rastro
static var live: Array = []          # projéteis com visual premium vivos (busca do impacto)

var kind: String = "light"
var color: Color = Color(1.0, 0.9, 0.55)
var host: Node2D
var st: Dictionary = {}

var _core: Sprite2D
var _halo: Sprite2D
var _rays: Sprite2D
var _trail: Line2D
var _parts: CPUParticles2D
var _t: float = 0.0
var _started: bool = false
var _done: bool = false
var _impacted: bool = false
var _last: Vector2 = Vector2.ZERO
var _vel: Vector2 = Vector2.ZERO
var _ground_y: float = 0.0
var _seed: float = 0.0
var look: String = ""               # forma do Projectile (bolt/wisp/seed/page/spike…)
var _explicit: bool = false         # família dada por quem criou (não re-deduz)


## Pendura (ou reaproveita) o visual premium num projétil. `kind` "" = deduz.
## `col` null = usa `proj.color` (se existir).
static func attach(proj: Node2D, p_kind: String = "", col = null) -> ProjectileFX:
	if proj == null or not is_instance_valid(proj):
		return null
	var fx: ProjectileFX = null
	for c in proj.get_children():
		if c is ProjectileFX:
			fx = c
			break
	if fx == null:
		fx = ProjectileFX.new()
		fx.name = "ProjectileFX"
		fx.host = proj
		proj.add_child(fx)
	if col is Color:
		fx.color = col
	elif proj.get("color") is Color:
		fx.color = proj.get("color")
	# `p_kind` pode ser uma FAMÍLIA ("king", "chain"…) ou uma FORMA do
	# Projectile ("orb", "bolt", "wisp", "seed", "page", "spike")
	var fam := p_kind
	if AttackStyle.LOOKS.has(p_kind):
		fx.look = p_kind
		fam = ""
	elif proj.get("look") is String:
		fx.look = String(proj.get("look"))
	fx._explicit = AttackStyle.STYLES.has(fam)
	fx.set_kind(fam if fx._explicit else AttackStyle.kind_for(proj))
	return fx


## O projétil que está EXATAMENTE em `pos` (o ImpactBurst usa para delegar).
static func find_at(pos: Vector2) -> ProjectileFX:
	for fx in live:
		if is_instance_valid(fx) and is_instance_valid(fx.host) and not fx._done:
			if fx.host.global_position.distance_squared_to(pos) < 1.0:
				return fx
	return null


func _enter_tree() -> void:
	if not live.has(self):
		live.append(self)


func _exit_tree() -> void:
	live.erase(self)


func set_kind(k: String) -> void:
	kind = k
	st = AttackStyle.get_style(k, look)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_seed = randf() * TAU
	z_index = 1                       # relativo ao projétil (z 29): acima do desenho dele
	if host != null:
		host.self_modulate.a = 0.0    # esconde o orbe vetorial antigo (só o _draw do host)
	var light := AttackStyle.is_light(kind)
	# rastro (coordenadas de MUNDO; desenha atrás do núcleo)
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.z_as_relative = false
	_trail.z_index = 29               # mesmo plano do projétil (acima da névoa do Torpor)
	_trail.width = st.trail_w
	_trail.texture = AttackStyle.strip_texture()
	_trail.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_trail.material = AttackStyle.trail_material(kind)
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 1.0))
	wc.add_point(Vector2(0.35, 0.7))
	wc.add_point(Vector2(1.0, 0.0))
	_trail.width_curve = wc
	var g := Gradient.new()
	var head: Color = color.lightened(0.2) if light else color
	g.set_color(0, Color(head.r, head.g, head.b, 1.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.add_point(0.35, Color(color.r, color.g, color.b, 0.85))
	_trail.gradient = g
	add_child(_trail)
	# partículas secundárias (soltas no mundo: ficam pra trás)
	_parts = CPUParticles2D.new()
	_parts.texture = VfxLibrary.tex(st.part)
	_parts.amount = st.part_n
	_parts.lifetime = 0.42
	_parts.local_coords = false
	_parts.z_index = -1
	if st.part_add:
		_parts.material = VfxLibrary._additive()
	_parts.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_parts.emission_sphere_radius = 3.0 + st.core * 10.0
	_parts.spread = 40.0
	_parts.initial_velocity_min = 20.0
	_parts.initial_velocity_max = 70.0
	_parts.scale_amount_min = 0.04
	_parts.scale_amount_max = 0.09 if st.part != "flame" else 0.16
	_parts.scale_amount_curve = VfxLibrary._shrink_curve()
	_parts.angle_min = 0.0
	_parts.angle_max = 360.0
	_parts.angular_velocity_min = -180.0
	_parts.angular_velocity_max = 180.0
	if st.part_up:
		_parts.gravity = Vector2(0, -60.0)
	else:
		_parts.gravity = Vector2(0, 90.0 if light else 40.0)
	if st.part_add:
		_parts.color_ramp = VfxLibrary._ramp(Color(1, 1, 1, 1), Color(color.r, color.g, color.b, 0.0))
		_parts.color = color.lightened(0.25)
	else:
		_parts.color_ramp = VfxLibrary._ramp(Color(color.r * 0.5, color.g * 0.45, color.b * 0.5, 0.5))
	add_child(_parts)
	# halo aditivo
	_halo = Sprite2D.new()
	_halo.texture = VfxLibrary.tex("glow")
	_halo.material = VfxLibrary._additive()
	_halo.modulate = Color(color.r, color.g, color.b, st.halo_a)
	_halo.scale = Vector2.ONE * st.halo * Vector2(st.squash.x, st.squash.y)
	add_child(_halo)
	# coroa / raios
	if st.rays != "":
		_rays = Sprite2D.new()
		_rays.texture = VfxLibrary.tex(st.rays)
		_rays.material = VfxLibrary._additive()
		var rc: Color = color.lightened(0.4) if light or kind == "king" else color
		_rays.modulate = Color(rc.r, rc.g, rc.b, 0.85)
		_rays.scale = Vector2.ONE * st.rays_s
		add_child(_rays)
	else:
		_rays = null
	# núcleo de plasma (shader)
	_core = Sprite2D.new()
	_core.texture = VfxLibrary.tex("circle")
	_core.material = AttackStyle.orb_material(kind)
	_core.modulate = Color(color.r, color.g, color.b, 1.0)
	_core.scale = Vector2(st.squash.x, st.squash.y) * st.core
	add_child(_core)


func _process(delta: float) -> void:
	if host == null or not is_instance_valid(host):
		queue_free()
		return
	var pos := host.global_position
	if not _started:
		_started = true
		# quem criou pode ter mudado cor/forma/status DEPOIS do add_child: deduz de novo
		if not _explicit:
			if host.get("look") is String and String(host.get("look")) != "":
				look = String(host.get("look"))
			if host.get("color") is Color:
				color = host.get("color")
			var k2 := AttackStyle.kind_for(host)
			if k2 != kind or AttackStyle.get_style(k2, look) != st:
				set_kind(k2)
		_last = pos
		_ground_y = float(host.get_meta("ground_y")) if host.has_meta("ground_y") else pos.y + float(st.ground)
		_muzzle(pos)
	_t += delta
	if delta > 0.0:
		_vel = _vel.lerp((pos - _last) / delta, 0.5)
	_last = pos
	var dirx: float = signf(_vel.x) if absf(_vel.x) > 1.0 else float(host.get("direction") if host.get("direction") != null else 1)
	var fly: Vector2 = _vel.normalized() if _vel.length() > 1.0 else Vector2(dirx, 0.0)
	# rastro: cabeça no projétil; pontos novos a cada ~3 px
	if not _done:
		# ponto 0 = cabeça (segue o projétil todo quadro); um ponto novo fica
		# para trás a cada TRAIL_STEP px percorridos
		if _trail.get_point_count() < 2:
			_trail.add_point(pos, 0)
		else:
			_trail.set_point_position(0, pos)
			if pos.distance_to(_trail.get_point_position(1)) > TRAIL_STEP:
				_trail.add_point(pos, 0)
				while _trail.get_point_count() > int(st.trail_n):
					_trail.remove_point(_trail.get_point_count() - 1)
		if (kind == "sleep" or st.get("wobble", false)) and _trail.get_point_count() > 1:
			# fita ondulante (sono, chama): a cabeça oscila de lado
			_trail.set_point_position(0, pos + fly.orthogonal() * sin(_t * 9.0 + _seed) * 3.0)
		_parts.direction = Vector2(0, -1) if st.part_up else (-fly + Vector2(0, -0.3)).normalized()
	# vida: pulso do núcleo e do halo, raios girando
	var pulse := 1.0 + sin(_t * 16.0 + _seed) * 0.08
	_core.scale = Vector2(st.squash.x, st.squash.y) * st.core * pulse
	if st.get("orient", false):
		_core.rotation = fly.angle()           # seta: aponta para onde voa
		_halo.rotation = _core.rotation
	elif st.has("spin"):
		_core.rotation += float(st.spin) * delta
	else:
		_core.flip_h = dirx < 0.0
	_halo.scale = Vector2(st.squash.x, st.squash.y) * st.halo * (1.0 + sin(_t * 9.0 + _seed) * 0.12)
	if _rays != null:
		_rays.rotation += float(st.rays_spin) * delta
		_rays.scale = Vector2.ONE * st.rays_s * (1.0 + sin(_t * 11.0) * 0.1)
	# acabou (acertou ou a vida expirou)? o Projectile desliga a física no _vanish
	if not _done and host.has_method("is_physics_processing") and not host.is_physics_processing() and _t > 0.0:
		_done = true
		if not _impacted:
			_fizzle(pos)
		_release_trail()


## Clarão de saída (boca do tiro) — pequeno, não conta como flash.
func _muzzle(pos: Vector2) -> void:
	var par := host.get_parent()
	if par == null:
		return
	var s: float = 0.22 + st.core * 0.8
	VfxLibrary._flash_sprite(par, pos, "light", Color(color.r, color.g, color.b, 0.75), s * 0.3, s, 0.14)
	VfxLibrary.shock_ring(par, pos, 4.0 + st.core * 28.0, Color(color.r, color.g, color.b, 0.55), 0.16, not AttackStyle.is_light(kind), 1.0, 0.08)


## Acertou (o ImpactBurst delegou): impacto premium da família.
func impact(pos: Vector2) -> void:
	_impacted = true
	var par := host.get_parent() if host != null and is_instance_valid(host) else get_parent()
	var dirx: float = signf(_vel.x) if absf(_vel.x) > 1.0 else 1.0
	VfxLibrary.attack_impact(par, pos, color, String(st.impact), dirx, _ground_y)


## A vida acabou no ar: o núcleo implode e solta motes (não "some" seco).
func _fizzle(pos: Vector2) -> void:
	var par := host.get_parent()
	if par == null:
		return
	VfxLibrary.attack_fizzle(par, pos, color, kind)


## Solta o rastro e as partículas no mundo: a fita recolhe em 0,2 s em vez de
## sumir junto com o projétil.
func _release_trail() -> void:
	var par := host.get_parent()
	if par == null or not is_instance_valid(par):
		return
	var tr := _trail
	var pp := _parts
	_trail = null                     # _done: o _process não mexe mais neles
	_parts = null
	tr.reparent(par, true)
	pp.reparent(par, true)
	pp.emitting = false
	par.get_tree().create_timer(pp.lifetime + 0.1, false).timeout.connect(pp.queue_free)
	var tw := tr.create_tween().set_parallel(true)
	tw.tween_property(tr, "modulate:a", 0.0, 0.22)
	tw.tween_property(tr, "width", 0.0, 0.22)
	tw.chain().tween_callback(tr.queue_free)
