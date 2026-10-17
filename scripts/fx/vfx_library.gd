class_name VfxLibrary
extends RefCounted
## BIBLIOTECA DE EFEITOS VISUAIS (partículas). Funções estáticas que criam
## CPUParticles2D (funciona no gl_compatibility) com os sprites CC0 do Kenney
## Particle Pack em `assets/vfx/` e as pendura em `parent`. Tudo se auto-remove
## (one-shot → `finished` → queue_free; segurança extra por timer) e existe um
## teto de instâncias simultâneas (`MAX_LIVE`) — passou do teto, os efeitos
## pequenos (hit) são pulados, os grandes (chefe) sempre tocam.
##
## Uso:  VfxLibrary.hit(get_parent(), pos, heavy, cor)
##       VfxLibrary.ambient(scenery, eon_index)
## Onde cada função toca: docs/VFX.md.

const DIR := "res://assets/vfx/"
const MAX_LIVE := 40            # nós de partícula vivos ao mesmo tempo
const GROUP := "vfx_live"
const Z := 32                   # acima dos personagens (gibs ficam em 6, HUD em CanvasLayer)

static var _tex: Dictionary = {}          # nome -> Texture2D (cache)
static var _add_mat: CanvasItemMaterial   # material aditivo (luz)


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := DIR + name + ".png"
		var t = load(path) if ResourceLoader.exists(path) else null
		_tex[name] = t
	return _tex[name]


static func _additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


static func _live(parent: Node) -> int:
	var tree := parent.get_tree()
	return tree.get_nodes_in_group(GROUP).size() if tree != null else 0


static func _ok(parent: Node, essential: bool) -> bool:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return false
	return essential or _live(parent) < MAX_LIVE


## Cria um emissor one-shot já configurado com o básico. Quem chama ajusta o resto.
static func _burst(parent: Node, pos: Vector2, texture: String, amount: int, life: float, additive: bool = true) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex(texture)
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.z_index = Z
	if additive:
		p.material = _additive()
	p.add_to_group(GROUP)
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	# segurança: se `finished` não vier (nó pausado, etc.), some mesmo assim.
	# Conecta direto no método do nó: se ele já foi liberado, a conexão morre
	# junto (sem lambda capturando referência morta).
	parent.get_tree().create_timer(life * 2.0 + 1.0, false).timeout.connect(p.queue_free)
	return p


## Rampa alfa/cor padrão: nasce forte, morre transparente.
static func _ramp(a: Color, b: Color = Color(0, 0, 0, 0)) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


## Curva de escala: cresce rápido e encolhe até zero.
static func _scale_curve(peak_at: float = 0.15) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(peak_at, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


## Curva de escala só encolhendo (fumaça cresce, luz encolhe).
static func _shrink_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


static func _grow_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.5))
	c.add_point(Vector2(1.0, 1.0))
	return c


## Sprite de luz que aparece, cresce e some (o "clarão" de um impacto).
static func _flash_sprite(parent: Node, pos: Vector2, texture: String, col: Color, from: float, to: float, dur: float, additive: bool = true, rot_speed: float = 0.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(texture)
	s.modulate = col
	s.scale = Vector2.ONE * from
	s.z_index = Z
	if additive:
		s.material = _additive()
	s.add_to_group(GROUP)
	parent.add_child(s)
	s.global_position = pos
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * to, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	if rot_speed != 0.0:
		tw.tween_property(s, "rotation", rot_speed * dur, dur)
	tw.chain().tween_callback(s.queue_free)
	return s


## Clarão de tela inteira (CanvasLayer acima do jogo, abaixo do HUD=layer 10+).
static func screen_flash(parent: Node, col: Color = Color(1, 1, 1, 0.55), dur: float = 0.35) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	# R10: "Reduzir flashes" corta o clarão de tela para 35 %.
	if Juice.reduce_flashes:
		col.a *= 0.35
	var layer := CanvasLayer.new()
	layer.layer = 5
	var rect := ColorRect.new()
	rect.color = col
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	parent.get_tree().root.add_child(layer)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)


# ===========================================================================
# GOLPES
# ===========================================================================

## Golpe acerta: fagulhas + clarão. `heavy` = mais fagulhas, corte e fumaça.
static func hit(parent: Node, pos: Vector2, heavy: bool = false, col: Color = Color(1.0, 0.9, 0.55)) -> void:
	if not _ok(parent, heavy):
		return
	var n := 16 if heavy else 9
	var p := _burst(parent, pos, "spark", n, 0.38 if heavy else 0.28)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 520.0)
	p.initial_velocity_min = 110.0 if heavy else 70.0
	p.initial_velocity_max = 260.0 if heavy else 170.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.11 if heavy else 0.08
	p.scale_amount_curve = _shrink_curve()
	p.color_ramp = _ramp(Color(1, 1, 1, 1), Color(col.r, col.g, col.b, 0.0))
	p.color = col.lightened(0.35)
	p.angle_min = 0.0
	p.angle_max = 360.0
	# clarão
	_flash_sprite(parent, pos, "glow", Color(col.r, col.g, col.b, 0.85), 0.1, 0.36 if heavy else 0.22, 0.16)
	if heavy:
		# talho de luz atravessando o alvo
		var s := _flash_sprite(parent, pos, "slash", Color(1, 1, 1, 0.95), 0.25, 0.7, 0.2)
		s.rotation = randf_range(-0.7, 0.7)
		# poeira do impacto
		var d := _burst(parent, pos + Vector2(0, 6), "smoke", 5, 0.5, false)
		d.direction = Vector2(0, -1)
		d.spread = 70.0
		d.initial_velocity_min = 30.0
		d.initial_velocity_max = 70.0
		d.scale_amount_min = 0.08
		d.scale_amount_max = 0.16
		d.scale_amount_curve = _grow_curve()
		d.color_ramp = _ramp(Color(0.35, 0.3, 0.3, 0.55))


## R5: brilho de aviso do golpe inimigo, 180 ms antes do impacto (= quando a
## janela de parry abre). FORMA além da cor (daltonismo): aparável = estrela
## REDONDA amarela; imparável = estrela PONTIAGUDA (losango) vermelha, maior.
## Fica acima de todo VFX de impacto (nunca coberto por fagulha). Sempre toca
## (é informação, não enfeite) e não é cortado por "Reduzir flashes".
static func tell_glint(parent: Node, pos: Vector2, unblockable: bool) -> void:
	if not _ok(parent, true):
		return
	if unblockable:
		var s := _flash_sprite(parent, pos, "star", Color(1.0, 0.32, 0.25, 1.0), 0.12, 0.42, 0.14, true)
		s.rotation = PI * 0.25                       # losango
		s.z_index = Z + 8
		var c := _flash_sprite(parent, pos, "glow", Color(1.0, 0.25, 0.2, 0.7), 0.08, 0.22, 0.14, true)
		c.z_index = Z + 7
	else:
		var r := _flash_sprite(parent, pos, "star2", Color(1.0, 0.9, 0.35, 1.0), 0.1, 0.32, 0.12, true)
		r.z_index = Z + 8
		var c2 := _flash_sprite(parent, pos, "circle", Color(1.0, 0.92, 0.5, 0.55), 0.05, 0.2, 0.12, true)
		c2.z_index = Z + 7


## Parry: anel branco-azulado + fagulhas geladas.
static func parry(parent: Node, pos: Vector2) -> void:
	if not _ok(parent, true):
		return
	var col := Color(0.8, 0.9, 1.0)
	_flash_sprite(parent, pos, "halo", Color(col.r, col.g, col.b, 1.0), 0.1, 0.6, 0.3)
	_flash_sprite(parent, pos, "star", Color(1, 1, 1, 1), 0.2, 0.7, 0.25, true, 2.0)
	var p := _burst(parent, pos, "spark2", 14, 0.4)
	p.spread = 180.0
	p.gravity = Vector2(0, 260.0)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	p.scale_amount_curve = _shrink_curve()
	p.color = col


## Esquiva perfeita: rastro fantasma azul que dispersa + brilho.
static func dodge_perfect(parent: Node, pos: Vector2) -> void:
	if not _ok(parent, true):
		return
	var col := Color(0.7, 0.8, 1.0)
	_flash_sprite(parent, pos, "glow", Color(col.r, col.g, col.b, 0.7), 0.2, 0.55, 0.35)
	var p := _burst(parent, pos, "magic2", 10, 0.55)
	p.direction = Vector2(0, -1)
	p.spread = 90.0
	p.gravity = Vector2(0, -60.0)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.16
	p.scale_amount_curve = _shrink_curve()
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.color = col


# ===========================================================================
# MORTES
# ===========================================================================

## Criatura comum morre: a faísca escapa (luz), o corpo vira fumaça escura.
static func enemy_death(parent: Node, pos: Vector2, col: Color = Color(1.0, 0.85, 0.5)) -> void:
	if not _ok(parent, true):
		return
	_flash_sprite(parent, pos, "glow", Color(col.r, col.g, col.b, 0.85), 0.15, 0.5, 0.3)
	var s := _burst(parent, pos, "spark", 14, 0.55)
	s.spread = 180.0
	s.gravity = Vector2(0, 380.0)
	s.initial_velocity_min = 60.0
	s.initial_velocity_max = 190.0
	s.scale_amount_min = 0.05
	s.scale_amount_max = 0.1
	s.scale_amount_curve = _shrink_curve()
	s.color = col.lightened(0.3)
	var k := _burst(parent, pos, "smoke2", 7, 0.8, false)
	k.direction = Vector2(0, -1)
	k.spread = 80.0
	k.gravity = Vector2(0, -40.0)
	k.initial_velocity_min = 25.0
	k.initial_velocity_max = 60.0
	k.scale_amount_min = 0.1
	k.scale_amount_max = 0.2
	k.scale_amount_curve = _grow_curve()
	k.angular_velocity_min = -60.0
	k.angular_velocity_max = 60.0
	k.color_ramp = _ramp(Color(0.25, 0.2, 0.25, 0.6))


## Elite morre: como a comum, mais anel de choque e mais luz.
static func elite_death(parent: Node, pos: Vector2, col: Color = Color(1.0, 0.85, 0.5)) -> void:
	if not _ok(parent, true):
		return
	enemy_death(parent, pos, col)
	_flash_sprite(parent, pos, "halo", Color(col.r, col.g, col.b, 0.9), 0.15, 0.95, 0.4)
	var s := _burst(parent, pos, "star", 8, 0.7)
	s.spread = 180.0
	s.gravity = Vector2(0, 200.0)
	s.initial_velocity_min = 80.0
	s.initial_velocity_max = 200.0
	s.scale_amount_min = 0.06
	s.scale_amount_max = 0.12
	s.scale_amount_curve = _shrink_curve()
	s.angular_velocity_min = -240.0
	s.angular_velocity_max = 240.0
	s.color = Color(1, 1, 1)


## Arconte cai: explosão em DOIS estágios (luz e fagulhas → fumaça, chamas e
## anel gigante), clarão de tela e tremor forte.
static func boss_death(parent: Node, pos: Vector2, col: Color = Color(1.0, 0.85, 0.5)) -> void:
	if not _ok(parent, true):
		return
	# estágio 1: implosão de luz + fagulhas
	_flash_sprite(parent, pos, "glow", Color(1, 1, 1, 0.9), 0.9, 0.15, 0.3)
	var s := _burst(parent, pos, "spark", 28, 0.7)
	s.spread = 180.0
	s.gravity = Vector2(0, 300.0)
	s.initial_velocity_min = 120.0
	s.initial_velocity_max = 320.0
	s.scale_amount_min = 0.06
	s.scale_amount_max = 0.13
	s.scale_amount_curve = _shrink_curve()
	s.color = col.lightened(0.4)
	Juice.shake(0.9)
	# estágio 2 (0,35 s depois): a explosão de verdade. O Timer é FILHO do pai:
	# se a tela for trocada antes, ele morre junto e o lambda nunca roda.
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 0.35
	t.autostart = true
	parent.add_child(t)
	t.timeout.connect(func() -> void:
		t.queue_free()
		if not is_instance_valid(parent) or not parent.is_inside_tree():
			return
		screen_flash(parent, Color(col.r, col.g, col.b, 0.6), 0.5)
		Juice.shake(1.0)                 # (o trauma satura em 1 de qualquer jeito)
		_flash_sprite(parent, pos, "halo", Color(col.r, col.g, col.b, 1.0), 0.2, 2.4, 0.7)
		_flash_sprite(parent, pos, "halo", Color(1, 1, 1, 0.8), 0.1, 1.4, 0.45)
		_flash_sprite(parent, pos, "glow", Color(1, 1, 1, 0.8), 0.3, 1.1, 0.4)
		var f := _burst(parent, pos, "flame", 22, 0.8)
		f.direction = Vector2(0, -1)
		f.spread = 180.0
		f.gravity = Vector2(0, -120.0)
		f.initial_velocity_min = 60.0
		f.initial_velocity_max = 220.0
		f.scale_amount_min = 0.15
		f.scale_amount_max = 0.35
		f.scale_amount_curve = _shrink_curve()
		f.angular_velocity_min = -90.0
		f.angular_velocity_max = 90.0
		f.color_ramp = _ramp(col.lightened(0.5), Color(col.r, col.g, col.b, 0.0))
		var k := _burst(parent, pos, "smoke", 18, 1.6, false)
		k.direction = Vector2(0, -1)
		k.spread = 180.0
		k.gravity = Vector2(0, -50.0)
		k.initial_velocity_min = 30.0
		k.initial_velocity_max = 120.0
		k.scale_amount_min = 0.25
		k.scale_amount_max = 0.5
		k.scale_amount_curve = _grow_curve()
		k.angular_velocity_min = -40.0
		k.angular_velocity_max = 40.0
		k.color_ramp = _ramp(Color(0.2, 0.15, 0.2, 0.75))
		var st := _burst(parent, pos, "star", 16, 1.1)
		st.spread = 180.0
		st.gravity = Vector2(0, 160.0)
		st.initial_velocity_min = 100.0
		st.initial_velocity_max = 300.0
		st.scale_amount_min = 0.08
		st.scale_amount_max = 0.16
		st.scale_amount_curve = _shrink_curve()
		st.angular_velocity_min = -300.0
		st.angular_velocity_max = 300.0
		st.color = Color(1, 1, 1))


## Chefe entra na fase 2: onda de choque, chamas subindo e clarão curto.
static func boss_phase2(parent: Node, pos: Vector2, col: Color = Color(1.0, 0.6, 0.4)) -> void:
	if not _ok(parent, true):
		return
	screen_flash(parent, Color(col.r, col.g, col.b, 0.35), 0.3)
	_flash_sprite(parent, pos, "halo", Color(col.r, col.g, col.b, 1.0), 0.2, 1.8, 0.5)
	_flash_sprite(parent, pos, "twirl", Color(col.r, col.g, col.b, 0.9), 0.3, 1.1, 0.6, true, 6.0)
	var f := _burst(parent, pos, "flame2", 18, 0.7)
	f.direction = Vector2(0, -1)
	f.spread = 60.0
	f.gravity = Vector2(0, -200.0)
	f.initial_velocity_min = 60.0
	f.initial_velocity_max = 180.0
	f.scale_amount_min = 0.12
	f.scale_amount_max = 0.28
	f.scale_amount_curve = _shrink_curve()
	f.color_ramp = _ramp(col.lightened(0.5), Color(col.r, col.g, col.b, 0.0))
	var s := _burst(parent, pos, "spark", 20, 0.6)
	s.spread = 180.0
	s.gravity = Vector2(0, 200.0)
	s.initial_velocity_min = 100.0
	s.initial_velocity_max = 260.0
	s.scale_amount_min = 0.05
	s.scale_amount_max = 0.1
	s.scale_amount_curve = _shrink_curve()
	s.color = col.lightened(0.3)


## Chefe / Rei aparece: coluna de luz descendo + poeira no chão.
static func boss_appear(parent: Node, pos: Vector2, col: Color = Color(1.0, 0.85, 0.5)) -> void:
	if not _ok(parent, true):
		return
	_flash_sprite(parent, pos, "glow", Color(col.r, col.g, col.b, 0.8), 0.3, 1.0, 0.8)
	_flash_sprite(parent, pos, "halo", Color(col.r, col.g, col.b, 0.9), 0.1, 1.3, 0.8)
	var d := _burst(parent, pos + Vector2(0, 14), "smoke", 10, 1.0, false)
	d.direction = Vector2(1, 0)
	d.spread = 180.0
	d.gravity = Vector2(0, -20.0)
	d.initial_velocity_min = 40.0
	d.initial_velocity_max = 110.0
	d.scale_amount_min = 0.12
	d.scale_amount_max = 0.25
	d.scale_amount_curve = _grow_curve()
	d.color_ramp = _ramp(Color(0.3, 0.28, 0.3, 0.6))


# ===========================================================================
# MAGIAS / ÁREA / PROJÉTEIS / COLETA / PORTAL
# ===========================================================================

## Conjuração: runas da cor do Anel sobem girando + brilho no cajado.
static func cast(parent: Node, pos: Vector2, ring_color: Color = Color(1.0, 0.95, 0.7)) -> void:
	if not _ok(parent, false):
		return
	_flash_sprite(parent, pos, "symbol", Color(ring_color.r, ring_color.g, ring_color.b, 0.95), 0.15, 0.5, 0.45, true, 3.0)
	var p := _burst(parent, pos, "magic", 12, 0.6)
	p.direction = Vector2(0, -1)
	p.spread = 50.0
	p.gravity = Vector2(0, -160.0)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 10.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	p.scale_amount_curve = _scale_curve(0.2)
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.color = ring_color


## Anel de choque: halo que cresce até `radius` + fagulhas na borda.
static func nova_ring(parent: Node, pos: Vector2, radius: float, col: Color = Color(0.6, 0.8, 1.0)) -> void:
	if not _ok(parent, true):
		return
	var target := radius * 2.0 / 128.0        # o halo tem 128 px; escala = diâmetro
	_flash_sprite(parent, pos, "halo", Color(col.r, col.g, col.b, 1.0), target * 0.15, target, 0.45)
	_flash_sprite(parent, pos, "glow", Color(1, 1, 1, 0.7), 0.1, target * 0.35, 0.25)
	var p := _burst(parent, pos, "spark", int(clampf(radius / 6.0, 10.0, 30.0)), 0.5)
	p.spread = 180.0
	p.gravity = Vector2(0, 120.0)
	p.initial_velocity_min = radius * 1.6
	p.initial_velocity_max = radius * 2.4
	p.damping_min = radius * 2.0
	p.damping_max = radius * 3.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	p.scale_amount_curve = _shrink_curve()
	p.color = col.lightened(0.3)


## Rastro contínuo pra um projétil (filho do próprio projétil, morre com ele).
static func projectile_trail(proj: Node2D, col: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex("glow")
	p.amount = 14
	p.lifetime = 0.35
	p.local_coords = false
	p.material = _additive()
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 10.0
	p.spread = 180.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.14
	p.scale_amount_curve = _shrink_curve()
	p.color_ramp = _ramp(Color(col.r, col.g, col.b, 0.7), Color(col.r, col.g, col.b, 0.0))
	p.z_index = -1
	proj.add_child(p)
	return p


## Poeira pequena (pedaço quicando, pouso). Pulada quando o teto está cheio.
static func dust(parent: Node, pos: Vector2) -> void:
	if not _ok(parent, false):
		return
	var d := _burst(parent, pos, "smoke", 3, 0.4, false)
	d.direction = Vector2(0, -1)
	d.spread = 60.0
	d.initial_velocity_min = 15.0
	d.initial_velocity_max = 40.0
	d.scale_amount_min = 0.05
	d.scale_amount_max = 0.1
	d.scale_amount_curve = _grow_curve()
	d.color_ramp = _ramp(Color(0.4, 0.35, 0.35, 0.5))


## Faísca coletada: estrelinha estourando.
static func spark_pickup(parent: Node, pos: Vector2, col: Color = Color(1.0, 0.9, 0.5)) -> void:
	if not _ok(parent, false):
		return
	_flash_sprite(parent, pos, "star2", Color(1, 1, 1, 1), 0.05, 0.3, 0.2, true, 3.0)
	var p := _burst(parent, pos, "spark2", 6, 0.3)
	p.spread = 180.0
	p.gravity = Vector2(0, 100.0)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.07
	p.scale_amount_curve = _shrink_curve()
	p.color = col


## Portal: espiral girando + motes de luz subindo, por `duration` s (0 = fica
## até o pai sumir). Devolve o nó pra quem quiser parar antes.
static func portal(parent: Node, pos: Vector2, col: Color = Color(0.8, 0.9, 1.0), duration: float = 0.0) -> Node2D:
	var root := Node2D.new()
	root.z_index = Z - 2
	root.add_to_group(GROUP)
	parent.add_child(root)
	root.global_position = pos
	var swirl := Sprite2D.new()
	swirl.texture = tex("twirl")
	swirl.material = _additive()
	swirl.modulate = Color(col.r, col.g, col.b, 0.85)
	swirl.scale = Vector2(0.55, 0.9)
	root.add_child(swirl)
	var glow := Sprite2D.new()
	glow.texture = tex("glow")
	glow.material = _additive()
	glow.modulate = Color(col.r, col.g, col.b, 0.5)
	glow.scale = Vector2(0.6, 1.0)
	root.add_child(glow)
	var tw := swirl.create_tween().set_loops()
	tw.tween_property(swirl, "rotation", TAU, 2.2).from(0.0)
	var p := CPUParticles2D.new()
	p.texture = tex("magic2")
	p.amount = 16
	p.lifetime = 1.4
	p.local_coords = false
	p.material = _additive()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(14.0, 40.0)
	p.direction = Vector2(0, -1)
	p.spread = 20.0
	p.gravity = Vector2(0, -50.0)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	p.scale_amount_curve = _scale_curve(0.3)
	p.color = col
	root.add_child(p)
	if duration > 0.0:
		parent.get_tree().create_timer(duration, false).timeout.connect(root.queue_free)
	return root


# ===========================================================================
# AMBIENTE POR ÉON (uma chamada por tela; vive com o cenário)
# ===========================================================================

## Partículas de fundo do Éon, em coordenadas de TELA (o pai é o
## ParallaxBackground do cenário, que é um CanvasLayer). Idempotente: se já
## existe um "VfxAmbient" no pai, não duplica.
static func ambient(parent: Node, eon_index: int, size: Vector2 = Vector2(640, 360)) -> CPUParticles2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var old := parent.get_node_or_null("VfxAmbient")
	if old != null:
		old.queue_free()
	var p := CPUParticles2D.new()
	p.name = "VfxAmbient"
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = size * 0.55
	p.position = size * 0.5
	p.preprocess = 6.0             # já nasce cheio (sem "chuva começando")
	p.material = _additive()
	p.spread = 180.0
	match clampi(eon_index, 0, 8):
		0:  # Torpor: motes azuis lentos subindo, como poeira num quarto escuro
			_amb(p, "glow", 34, 7.0, Color(0.55, 0.8, 1.0, 0.55), Vector2(0, -1), 30.0, 4.0, 12.0, Vector2(0, -3), 0.05, 0.1)
		1:  # Fome: brasas subindo depressa e tremendo
			_amb(p, "spark2", 40, 3.0, Color(1.0, 0.55, 0.25, 0.9), Vector2(0, -1), 40.0, 30.0, 80.0, Vector2(0, -60), 0.03, 0.07)
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
		2:  # Corrente: faíscas de forja caindo, prateadas, curtas
			_amb(p, "spark", 26, 1.6, Color(0.9, 0.9, 1.0, 0.9), Vector2(0, 1), 40.0, 40.0, 110.0, Vector2(0, 160), 0.03, 0.06)
		3:  # Silêncio: poeira pálida quase parada
			_amb(p, "circle", 30, 9.0, Color(0.75, 0.7, 0.95, 0.35), Vector2(1, 0), 180.0, 2.0, 6.0, Vector2.ZERO, 0.02, 0.05)
		4:  # Espelho: cacos prateados girando, caindo devagar
			_amb(p, "star", 22, 6.0, Color(0.95, 0.97, 1.0, 0.8), Vector2(0, 1), 30.0, 6.0, 16.0, Vector2(0, 8), 0.04, 0.09)
			p.angular_velocity_min = -120.0
			p.angular_velocity_max = 120.0
		5:  # Praga: esporos verdes flutuando
			_amb(p, "circle", 36, 6.0, Color(0.6, 1.0, 0.45, 0.6), Vector2(0, -1), 180.0, 4.0, 14.0, Vector2(6, -6), 0.03, 0.08)
		6:  # Coroa: cinzas douradas caindo como neve falsa
			_amb(p, "dirt", 34, 6.0, Color(1.0, 0.85, 0.4, 0.75), Vector2(0, 1), 40.0, 8.0, 22.0, Vector2(-4, 12), 0.03, 0.07)
			p.angular_velocity_min = -60.0
			p.angular_velocity_max = 60.0
		7:  # Centro: orbes de memória, mornos, flutuando
			_amb(p, "glow", 24, 8.0, Color(1.0, 0.8, 0.5, 0.6), Vector2(0, -1), 180.0, 2.0, 8.0, Vector2.ZERO, 0.08, 0.16)
		8:  # Mente: o vazio — poucos farrapos escuros-rosados à deriva
			p.material = null
			_amb(p, "smoke2", 12, 10.0, Color(0.5, 0.2, 0.35, 0.28), Vector2(1, 0), 180.0, 3.0, 8.0, Vector2.ZERO, 0.25, 0.45)
			p.angular_velocity_min = -15.0
			p.angular_velocity_max = 15.0
	parent.add_child(p)
	p.emitting = true
	return p


static func _amb(p: CPUParticles2D, texture: String, amount: int, life: float, col: Color, dir: Vector2, spread: float, v0: float, v1: float, grav: Vector2, s0: float, s1: float) -> void:
	p.texture = tex(texture)
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = grav
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	p.scale_amount_curve = _scale_curve(0.3)
	p.color = col
	p.lifetime_randomness = 0.5


# ===========================================================================
# PRÉ-AQUECIMENTO
# ===========================================================================

## Pré-aquece efeitos, shaders, texturas e a fonte dos números de dano para o
## 1º golpe não engasgar (ONDA2: até 193 ms). Cria UMA vez cada efeito de
## combate dentro de um nó quase transparente no centro da vista (precisa ser
## DESENHADO para o shader compilar) e descarta tudo em ~0,4 s. Sem som, sem
## tremor. Chamar uma vez quando a fase carrega: `VfxLibrary.prewarm(level)`.
static func prewarm(parent: Node) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var holder := Node2D.new()
	holder.name = "VfxPrewarm"
	holder.modulate = Color(1, 1, 1, 0.004)          # invisível na prática, mas desenhado
	parent.add_child(holder)
	var cam := parent.get_viewport().get_camera_2d()
	var p: Vector2 = cam.get_screen_center_position() if cam != null else Vector2(320, 180)
	holder.global_position = Vector2.ZERO
	# texturas usadas pelos efeitos de combate
	for n in ["spark", "spark2", "glow", "halo", "slash", "smoke", "smoke2", "star", "star2", "circle", "flame", "flame2", "magic", "magic2", "twirl", "symbol", "light", "trace"]:
		tex(n)
	# partículas/sprites (multimesh + aditivo + normal)
	hit(holder, p, false)
	hit(holder, p, true)
	parry(holder, p)
	dodge_perfect(holder, p)
	enemy_death(holder, p)
	elite_death(holder, p)
	cast(holder, p)
	nova_ring(holder, p, 60.0)
	spark_pickup(holder, p)
	dust(holder, p)
	tell_glint(holder, p, false)
	tell_glint(holder, p, true)
	ImpactBurst.spawn(holder, p, Color(1, 0.9, 0.7))
	DamageNumber.spawn(holder, p, 1234567890, Color(1, 0.9, 0.6), true)   # glifos 0–9
	# desmembramento: peça vetorial, peça pintada (shader limpo) e gotas de luz
	var poly := PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	var parts: Array = [{"pts": poly, "col": Color(0.5, 0.5, 0.5)}]
	var t: Texture2D = tex("glow")
	if t != null:
		parts.append({"pts": poly, "col": Color.WHITE, "tex": t, "size": Vector2(8, 8), "flip": 1.0})
	Gib.burst(holder, p, parts, 1.0, p.y + 400.0, Vector2.ZERO, Color(1, 0.9, 0.5), Color(0.1, 0.1, 0.1))
	# shaders da pintura (afterimage/curvatura) num sprite de 8 px
	for path in ["res://assets/shaders/painted_ghost.gdshader", "res://assets/shaders/painted_flex.gdshader"]:
		if ResourceLoader.exists(path):
			var sp := Sprite2D.new()
			sp.texture = t
			sp.scale = Vector2.ONE * 0.06
			var m := ShaderMaterial.new()
			m.shader = load(path)
			sp.material = m
			holder.add_child(sp)
			sp.global_position = p
	var sp2 := Sprite2D.new()
	sp2.texture = t
	sp2.scale = Vector2.ONE * 0.06
	sp2.material = PaintedLibrary.material()
	holder.add_child(sp2)
	sp2.global_position = p
	# some com tudo depois de alguns quadros desenhados (tempo REAL)
	parent.get_tree().create_timer(0.4, true, false, true).timeout.connect(holder.queue_free)
