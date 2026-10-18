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
static var _rim_shader: Shader            # contorno de leitura (R18), compilado 1×
static var _flash_shader: Shader          # F1: flash aditivo da Sophia, compilado 1×

## R18 (NEURO_SATISFACAO): cor do contorno de leitura por Éon — a mesma luz
## das partículas de ambiente (0 Torpor … 6 Coroa, 7 Centro, 8 Mente).
const EON_RIM := [Color(0.55, 0.8, 1.0), Color(1.0, 0.6, 0.3), Color(0.85, 0.88, 1.0),
	Color(0.78, 0.72, 1.0), Color(0.95, 0.97, 1.0), Color(0.62, 1.0, 0.5), Color(1.0, 0.85, 0.42),
	Color(1.0, 0.8, 0.5), Color(0.95, 0.5, 0.7)]


static func eon_rim_color(eon_index: int) -> Color:
	return EON_RIM[clampi(eon_index, 0, EON_RIM.size() - 1)]


## Shader do CanvasGroup que desenha o personagem com um contorno externo de
## ~1 px da base 640×360 (cor do Éon, α ≈ 0,5) — separa a silhueta pintada de
## fundos escuros sem mexer na pintura (o CharacterArt fica intocado).
## `rim_strength` 0 = desliga (morte/dissolução).
static func rim_shader() -> Shader:
	if _rim_shader == null:
		_rim_shader = Shader.new()
		_rim_shader.code = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 rim_color : source_color = vec4(0.55, 0.8, 1.0, 0.5);
uniform float rim_strength = 1.0;
uniform float rim_px = 1.0;   // largura em px da base 640x360

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	// px da tela por px da base (360 de altura): o contorno não afina em 1080p
	float k = max(1.0, (1.0 / SCREEN_PIXEL_SIZE.y) / 360.0) * rim_px;
	vec2 d = SCREEN_PIXEL_SIZE * k;
	float n = 0.0;
	n = max(n, textureLod(screen_texture, SCREEN_UV + vec2(d.x, 0.0), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV - vec2(d.x, 0.0), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV + vec2(0.0, d.y), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV - vec2(0.0, d.y), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV + d * 0.7, 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV - d * 0.7, 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV + vec2(d.x, -d.y) * 0.7, 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV + vec2(-d.x, d.y) * 0.7, 0.0).a);
	// só FORA da silhueta (onde o próprio pixel é transparente)
	float edge = clamp(n - c.a, 0.0, 1.0) * rim_color.a * rim_strength;
	vec4 body = COLOR * c;
	vec4 rim = vec4(rim_color.rgb, edge * COLOR.a);
	float oa = body.a + rim.a * (1.0 - body.a);
	vec3 orgb = oa > 0.0001 ? (body.rgb * body.a + rim.rgb * rim.a * (1.0 - body.a)) / oa : vec3(0.0);
	COLOR = vec4(orgb, oa);
}
"""
	return _rim_shader


## F1 (QA visual): flash ADITIVO por cima da pintura (Player.FlashLayer). Soma
## `flash.rgb × flash.a` só onde o corpo tem alfa — a pintura clareia sem virar
## silhueta chapada. O vertex repete a curvatura do painted_flex (bend/body_h)
## para a camada casar com o corpo dobrado.
static func flash_add_shader() -> Shader:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float body_h = 256.0;
uniform float bend = 0.0;
uniform vec4 flash = vec4(1.0, 1.0, 1.0, 0.0);

void vertex() {
	float h = clamp(-VERTEX.y / body_h, 0.0, 1.6);
	VERTEX.x += bend * h * h;
}

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(flash.rgb, a * flash.a);
}
"""
	return _flash_shader


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
	if _claimed(pos):
		return                 # VFX7: o impacto premium deste ponto já tocou (R4)
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
	_ring_signature(parent, pos, ring_color)


## VFX7: a ASSINATURA de cada magia no instante da conjuração (reconhecida pela
## cor do Anel = skill.color). Cada Anel é a paixão de um Arconte virada luz.
static func _ring_signature(parent: Node, pos: Vector2, col: Color) -> void:
	match AttackStyle.ring_of_color(col):
		"m_s1":
			# Esfera Solar: um disco de sol se abre na mão.
			_flash_sprite(parent, pos, "flare", Color(col.r, col.g, col.b, 0.9), 0.1, 0.5, 0.3, true, 3.0)
			_flash_sprite(parent, pos, "light", Color(1, 1, 1, 0.8), 0.08, 0.32, 0.14)
		"r_torpor":
			# Névoa do Sono: bafejo de névoa azul e bolhas lentas.
			var m := _burst(parent, pos, "smoke2", 6, 0.9)
			m.direction = Vector2(0, -1)
			m.spread = 120.0
			m.initial_velocity_min = 10.0
			m.initial_velocity_max = 35.0
			m.scale_amount_min = 0.1
			m.scale_amount_max = 0.2
			m.scale_amount_curve = _grow_curve()
			m.color_ramp = _ramp(Color(col.r, col.g, col.b, 0.45))
			var b := _burst(parent, pos, "circle", 8, 1.0)
			b.spread = 180.0
			b.gravity = Vector2(0, -40.0)
			b.initial_velocity_min = 10.0
			b.initial_velocity_max = 40.0
			b.scale_amount_min = 0.02
			b.scale_amount_max = 0.05
			b.scale_amount_curve = _scale_curve(0.3)
			b.color = col.lightened(0.3)
		"r_fome":
			# Boca Voraz: um redemoinho que SUGA (grande → pequeno).
			_flash_sprite(parent, pos, "twirl", Color(col.r, col.g, col.b, 0.9), 0.9, 0.08, 0.38, true, -9.0)
			var v := _burst(parent, pos, "spark", 14, 0.35)
			v.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
			v.emission_sphere_radius = 46.0
			v.gravity = Vector2.ZERO
			v.radial_accel_min = -700.0
			v.radial_accel_max = -500.0
			v.scale_amount_min = 0.04
			v.scale_amount_max = 0.08
			v.color = col.lightened(0.2)
		"r_corrente":
			# Corrente da Lei: o elo se forma — estrela fria e faíscas de forja.
			_flash_sprite(parent, pos, "star", Color(1, 1, 1, 0.9), 0.08, 0.36, 0.18, true, 6.0)
			_spray(parent, pos, col, 8, -1.0, "spark2", 0.6)
		"r_silencio":
			# Grito Mudo: o som é ENGOLIDO — anéis que se fecham para dentro.
			_flash_sprite(parent, pos, "halo", Color(col.r, col.g, col.b, 0.85), 1.1, 0.05, 0.32)
			_flash_sprite(parent, pos, "halo", Color(1, 1, 1, 0.6), 0.7, 0.03, 0.24)
		"r_espelho":
			# Reflexo: cacos de espelho se espalham e orbitam a Sophia por 5 s.
			_flash_sprite(parent, pos, "star", Color(1, 1, 1, 0.95), 0.1, 0.5, 0.22, true, 5.0)
			var c := _burst(parent, pos, "star", 10, 0.5)
			c.spread = 180.0
			c.gravity = Vector2(0, 120.0)
			c.initial_velocity_min = 60.0
			c.initial_velocity_max = 150.0
			c.scale_amount_min = 0.03
			c.scale_amount_max = 0.07
			c.angular_velocity_min = -400.0
			c.angular_velocity_max = 400.0
			c.color = col
			var pl := parent.get_tree().get_first_node_in_group("player") if parent.get_tree() != null else null
			if pl is Node2D and (pl as Node2D).global_position.distance_to(pos) < 80.0:
				aura(pl, col, 5.0)
		"r_praga":
			# Flor Podre: esporos verdes sobem da mão.
			var e := _burst(parent, pos, "circle", 12, 0.9)
			e.direction = Vector2(0, -1)
			e.spread = 70.0
			e.gravity = Vector2(0, -30.0)
			e.initial_velocity_min = 20.0
			e.initial_velocity_max = 70.0
			e.scale_amount_min = 0.02
			e.scale_amount_max = 0.06
			e.scale_amount_curve = _scale_curve(0.3)
			e.color = col
			var g := _burst(parent, pos, "smoke", 4, 0.8, false)
			g.spread = 180.0
			g.initial_velocity_min = 8.0
			g.initial_velocity_max = 25.0
			g.scale_amount_min = 0.08
			g.scale_amount_max = 0.14
			g.scale_amount_curve = _grow_curve()
			g.color_ramp = _ramp(Color(0.35, 0.5, 0.2, 0.45))
		"r_coroa":
			# Coroa Partida: uma coroa de raios se ergue antes da nova.
			var fb := flash_budget()
			_flash_sprite(parent, pos, "flare", Color(col.r, col.g, col.b, 0.95 * fb), 0.2, 0.9, 0.4, true, 2.0)
			for i in 5:
				var ray := Sprite2D.new()
				ray.texture = tex("light")
				ray.material = _additive()
				ray.modulate = Color(col.r, col.g, col.b, 0.8)
				ray.z_index = Z
				ray.add_to_group(GROUP)
				parent.add_child(ray)
				ray.global_position = pos
				ray.rotation = (float(i) - 2.0) * 0.35
				ray.offset = Vector2(0, -64)
				ray.scale = Vector2(0.08, 0.1)
				var tw := ray.create_tween().set_parallel(true)
				tw.tween_property(ray, "scale", Vector2(0.12, 0.9), 0.3).set_ease(Tween.EASE_OUT)
				tw.tween_property(ray, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
				tw.chain().tween_callback(ray.queue_free)


## Anel de choque: halo que cresce até `radius` + fagulhas na borda.
static func nova_ring(parent: Node, pos: Vector2, radius: float, col: Color = Color(0.6, 0.8, 1.0)) -> void:
	if not _ok(parent, true):
		return
	# VFX7: frente quente fina (branca) correndo na frente do corpo colorido,
	# clarão no centro (no orçamento de flashes se a nova é grande), luz que
	# escorre pelo chão e, nas novas enormes, um pilar de luz.
	var big := radius >= 140.0
	var fb := flash_budget() if big else 1.0
	shock_ring(parent, pos, radius, Color(1, 0.98, 0.92, 0.6), 0.3, false, 1.0, 0.05)
	shock_ring(parent, pos, radius * 0.94, Color(col.r, col.g, col.b, 0.8), 0.5, false, 1.0, 0.2)
	_flash_sprite(parent, pos, "glow", Color(1, 1, 1, 0.7 * fb), 0.1, radius * 2.0 / 128.0 * 0.35, 0.25)
	ground_decal(parent, pos + Vector2(0, minf(radius * 0.12, 18.0)), col, radius * 2.2, true, 0.55)
	if big:
		var pil := Sprite2D.new()
		pil.texture = tex("light")
		pil.material = _additive()
		pil.modulate = Color(col.r, col.g, col.b, 0.85 * fb)
		pil.z_index = Z
		pil.add_to_group(GROUP)
		parent.add_child(pil)
		pil.global_position = pos + Vector2(0, -40)
		pil.scale = Vector2(0.5, 0.4)
		var tw := pil.create_tween().set_parallel(true)
		tw.tween_property(pil, "scale", Vector2(0.18, 2.6), 0.4).set_ease(Tween.EASE_OUT)
		tw.tween_property(pil, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(pil.queue_free)
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
	# motes subindo do chão varrido
	var m := _burst(parent, pos, "magic2", int(clampf(radius / 12.0, 6.0, 16.0)), 0.8)
	m.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	m.emission_rect_extents = Vector2(radius * 0.8, 6.0)
	m.direction = Vector2(0, -1)
	m.spread = 20.0
	m.gravity = Vector2(0, -80.0)
	m.initial_velocity_min = 20.0
	m.initial_velocity_max = 70.0
	m.scale_amount_min = 0.04
	m.scale_amount_max = 0.08
	m.scale_amount_curve = _scale_curve(0.2)
	m.color = col.lightened(0.2)


## Rastro de projétil — desde o VFX7 pendura o visual PREMIUM inteiro
## (ProjectileFX: núcleo de plasma, halo, coroa, fita, partículas, impacto e
## dissipação). O Projectile chama isto no _ready; a família vem das
## propriedades dele (AttackStyle.kind_for) ou da meta "vfx_kind".
static func projectile_trail(proj: Node2D, col: Color) -> Node2D:
	return ProjectileFX.attach(proj, "", col)


## API dos donos de ataque (VFX7): visual premium de projétil por família.
## kind: "light" · "solar" · "chain_light" (Sophia) · "dark" · "king" · "chain"
## · "sleep" · "wave" (Arcontes/criaturas) · "" = deduz. Idempotente.
## Devolve true se o visual premium foi pendurado (o projectile.gd compara o
## retorno com `false`, por isso bool — quem quiser o NÓ usa ProjectileFX.attach).
## `kind` aceita a FORMA do Projectile ("orb", "bolt", "wisp", "seed", "page",
## "spike") ou a FAMÍLIA; a família vem de AttackStyle.kind_for quando não dada.
static func projectile_look(proj: Node2D, kind: String = "", col = null) -> bool:
	return ProjectileFX.attach(proj, kind, col) != null


## API (VFX7): ANTECIPAÇÃO — a luz se junta em `host` + `offset` por `duration`
## segundos e estala no fim (chame no início do wind-up/conjuração).
## style: "light" (Sophia) · "dark" (Arcontes/criaturas) · "king" (Rei/Demiurgo).
static func charge_up(host: Node2D, offset: Vector2, col: Color, duration: float = 0.3, style: String = "dark") -> ChargeFX:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return null
	var c := ChargeFX.new()
	c.color = col
	c.duration = duration
	c.style = style
	c.position = offset
	host.add_child(c)
	return c


# --- VFX7: orçamento de clarões (R10: ≤ 3 por segundo, WCAG 2.3.1) ----------
const FLASHES_PER_SEC := 3
static var _flash_log: Array[int] = []


## Fator de força de um clarão FORTE: os 3 primeiros do último segundo saem
## inteiros; os seguintes saem a 30 % (não contam como flash). "Reduzir flashes"
## corta tudo pela metade.
static func flash_budget() -> float:
	var now := Time.get_ticks_msec()
	while not _flash_log.is_empty() and now - _flash_log[0] > 1000:
		_flash_log.pop_front()
	var k := 1.0
	if _flash_log.size() >= FLASHES_PER_SEC:
		k = 0.3
	else:
		_flash_log.append(now)
	if Juice.reduce_flashes:
		k *= 0.5
	return k


# --- VFX7: um acerto = um evento (R4) ---------------------------------------
static var _claim_pos: Vector2 = Vector2.INF
static var _claim_ms: int = -1000


## O impacto premium "reserva" o ponto: o `hit` genérico do mesmo quadro e do
## mesmo lugar (ex.: explosão da Esfera) não empilha outro clarão por cima.
static func _claim(pos: Vector2) -> void:
	_claim_pos = pos
	_claim_ms = Time.get_ticks_msec()


static func _claimed(pos: Vector2) -> bool:
	return Time.get_ticks_msec() - _claim_ms < 34 and pos.distance_squared_to(_claim_pos) < 4.0


## Anel de choque macio (shader vfx_ring) que cresce até `radius` e apaga.
## `squash` < 1 achata (anel deitado no chão).
static func shock_ring(parent: Node, pos: Vector2, radius: float, col: Color, dur: float = 0.3, dark: bool = false, squash: float = 1.0, thickness: float = 0.14) -> Sprite2D:
	if not _ok(parent, true):
		return null
	var s := Sprite2D.new()
	s.texture = tex("circle")
	s.material = AttackStyle.ring_material(dark, thickness)
	s.modulate = col                            # o alfa da cor = força do anel
	s.z_index = Z
	s.add_to_group(GROUP)
	parent.add_child(s)
	s.global_position = pos
	var to := radius / 64.0                    # quad de 128 px: escala = raio/64
	s.scale = Vector2(1.0, squash) * to * 0.2
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(1.0, squash) * to, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(s.queue_free)
	return s


## Decalque breve no chão (elipse em perspectiva): luz que escorre (aditiva) ou
## chamuscado escuro. Some em `dur`.
static func ground_decal(parent: Node, pos: Vector2, col: Color, width: float, light: bool = true, dur: float = 0.6) -> void:
	if not _ok(parent, false):
		return
	var s := Sprite2D.new()
	s.texture = tex("light" if light else "scorch")
	if light:
		s.material = _additive()
		s.modulate = Color(col.r, col.g, col.b, 0.75)
	else:
		s.modulate = Color(0.08, 0.05, 0.08, 0.55)
	s.z_index = 2                              # no chão: atrás dos personagens
	s.add_to_group(GROUP)
	parent.add_child(s)
	s.global_position = pos
	var w := width / 128.0
	s.scale = Vector2(w * 0.6, w * 0.16)
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2(w, w * 0.22), dur * 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(s.queue_free)


## Faíscas DIRECIONAIS (R15): saem para trás do golpe (contra `dirx`) e para cima.
static func _spray(parent: Node, pos: Vector2, col: Color, n: int, dirx: float, texture: String = "spark", speed: float = 1.0) -> CPUParticles2D:
	var p := _burst(parent, pos, texture, n, 0.42)
	p.direction = Vector2(-dirx, -0.55).normalized()
	p.spread = 62.0
	p.gravity = Vector2(0, 480.0)
	p.initial_velocity_min = 110.0 * speed
	p.initial_velocity_max = 270.0 * speed
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.1
	p.scale_amount_curve = _shrink_curve()
	p.color_ramp = _ramp(Color(1, 1, 1, 1), Color(col.r, col.g, col.b, 0.0))
	p.color = col.lightened(0.3)
	p.angle_min = 0.0
	p.angle_max = 360.0
	return p


## IMPACTO PREMIUM de ataque à distância (VFX7): clarão (no orçamento de
## flashes), anel de choque, faíscas direcionais, decalque no chão e o tempero
## da família. `style` = AttackStyle.STYLES[*].impact.
static func attack_impact(parent: Node, pos: Vector2, col: Color, style: String = "light", dirx: float = 1.0, ground_y: float = NAN) -> void:
	if not _ok(parent, true):
		return
	_claim(pos)
	if is_nan(ground_y):
		ground_y = pos.y + 26.0
	var fb := flash_budget()
	var ground := Vector2(pos.x, ground_y)
	match style:
		"explosion":
			# Esfera Solar: o sol estoura. (O AoeNova do projétil desenha a onda.)
			_flash_sprite(parent, pos, "light", Color(1, 1, 1, 0.95 * fb), 0.2, 0.95, 0.16)
			_flash_sprite(parent, pos, "flare", Color(col.r, col.g, col.b, 0.9 * fb), 0.2, 0.8, 0.28, true, 2.5)
			shock_ring(parent, pos, 34.0, Color(1, 0.97, 0.85), 0.2, false, 1.0, 0.1)
			var f := _burst(parent, pos, "flame", 16, 0.55)
			f.spread = 180.0
			f.gravity = Vector2(0, -160.0)
			f.initial_velocity_min = 60.0
			f.initial_velocity_max = 190.0
			f.damping_min = 120.0
			f.damping_max = 220.0
			f.scale_amount_min = 0.12
			f.scale_amount_max = 0.26
			f.scale_amount_curve = _scale_curve(0.12)
			f.angle_min = 0.0
			f.angle_max = 360.0
			f.color_ramp = _ramp(Color(1, 0.95, 0.8, 1), Color(col.r, col.g * 0.6, col.b * 0.3, 0.0))
			_spray(parent, pos, col, 14, dirx, "spark", 1.3)
			var k := _burst(parent, pos, "smoke2", 6, 0.9, false)
			k.direction = Vector2(0, -1)
			k.spread = 90.0
			k.gravity = Vector2(0, -50.0)
			k.initial_velocity_min = 20.0
			k.initial_velocity_max = 60.0
			k.scale_amount_min = 0.14
			k.scale_amount_max = 0.26
			k.scale_amount_curve = _grow_curve()
			k.color_ramp = _ramp(Color(0.3, 0.22, 0.2, 0.5))
			ground_decal(parent, ground, col, 120.0, true, 0.7)
			ground_decal(parent, ground, col, 80.0, false, 1.1)
		"king":
			# Orbe do Rei: clarão dourado com coroa de raios + estrelas.
			_flash_sprite(parent, pos, "light", Color(1, 0.97, 0.85, 0.9 * fb), 0.2, 0.85, 0.14)
			_flash_sprite(parent, pos, "flare", Color(col.r, col.g, col.b, 0.85 * fb), 0.3, 0.9, 0.3, true, -2.0)
			shock_ring(parent, pos, 46.0, col, 0.3, false, 1.0, 0.12)
			shock_ring(parent, pos, 30.0, Color(0.5, 0.15, 0.1), 0.36, true, 1.0, 0.2)
			_spray(parent, pos, col, 12, dirx, "star", 1.1)
			ground_decal(parent, ground, col, 110.0, true, 0.6)
			ground_decal(parent, ground, col, 70.0, false, 1.0)
		"chain":
			# Corrente: estalo metálico — estrela fria + elos de luz voando.
			_flash_sprite(parent, pos, "star", Color(1, 1, 1, 0.95 * fb), 0.1, 0.42, 0.14, true, 4.0)
			shock_ring(parent, pos, 22.0, col.lightened(0.3), 0.22, false, 1.0, 0.1)
			_spray(parent, pos, Color(0.9, 0.92, 1.0), 12, dirx, "spark2", 1.2)
			var l := _burst(parent, pos, "trace", 5, 0.5)
			l.spread = 180.0
			l.gravity = Vector2(0, 420.0)
			l.initial_velocity_min = 80.0
			l.initial_velocity_max = 170.0
			l.scale_amount_min = 0.05
			l.scale_amount_max = 0.08
			l.angular_velocity_min = -500.0
			l.angular_velocity_max = 500.0
			l.color = col.lightened(0.3)
			ground_decal(parent, ground, col, 50.0, true, 0.4)
		"dark":
			# Luz corrompida: espinho de luz na cor do Arconte + borrifo escuro.
			_flash_sprite(parent, pos, "star", Color(col.r, col.g, col.b, 0.95 * fb), 0.12, 0.5, 0.16, true, -3.0)
			_flash_sprite(parent, pos, "light", Color(1, 1, 1, 0.6 * fb), 0.1, 0.4, 0.1)
			shock_ring(parent, pos, 26.0, col, 0.24, true, 1.0, 0.16)
			_spray(parent, pos, col, 10, dirx, "spark", 1.0)
			var k2 := _burst(parent, pos, "smoke2", 5, 0.55, false)
			k2.spread = 180.0
			k2.gravity = Vector2(0, -30.0)
			k2.initial_velocity_min = 20.0
			k2.initial_velocity_max = 60.0
			k2.scale_amount_min = 0.08
			k2.scale_amount_max = 0.15
			k2.scale_amount_curve = _grow_curve()
			k2.color_ramp = _ramp(Color(0.12, 0.04, 0.14, 0.7))
			ground_decal(parent, ground, col, 60.0, false, 0.8)
		"sleep":
			# Sono: bolhas estourando e uma névoa que se desfaz (sem clarão forte).
			_flash_sprite(parent, pos, "glow", Color(col.r, col.g, col.b, 0.7), 0.2, 0.6, 0.3)
			shock_ring(parent, pos, 28.0, col, 0.4, false, 1.0, 0.22)
			var b := _burst(parent, pos, "circle", 12, 0.7)
			b.spread = 180.0
			b.gravity = Vector2(0, -70.0)
			b.initial_velocity_min = 30.0
			b.initial_velocity_max = 90.0
			b.scale_amount_min = 0.03
			b.scale_amount_max = 0.08
			b.scale_amount_curve = _scale_curve(0.3)
			b.color = col.lightened(0.3)
			var m := _burst(parent, pos, "smoke2", 5, 0.9)
			m.spread = 180.0
			m.initial_velocity_min = 10.0
			m.initial_velocity_max = 40.0
			m.scale_amount_min = 0.12
			m.scale_amount_max = 0.22
			m.scale_amount_curve = _grow_curve()
			m.color_ramp = _ramp(Color(col.r, col.g, col.b, 0.35))
		"wave":
			# Onda rasteira: estoura no chão — poeira, terra e faíscas subindo.
			_flash_sprite(parent, pos, "light", Color(col.r, col.g, col.b, 0.8 * fb), 0.15, 0.5, 0.14)
			shock_ring(parent, Vector2(pos.x, ground_y - 2.0), 40.0, col, 0.3, true, 0.32, 0.16)
			var u := _spray(parent, pos, col, 10, dirx, "spark", 0.9)
			u.direction = Vector2(0, -1)
			var d := _burst(parent, pos, "smoke", 8, 0.7, false)
			d.direction = Vector2(0, -1)
			d.spread = 70.0
			d.initial_velocity_min = 30.0
			d.initial_velocity_max = 90.0
			d.scale_amount_min = 0.1
			d.scale_amount_max = 0.2
			d.scale_amount_curve = _grow_curve()
			d.color_ramp = _ramp(Color(0.32, 0.27, 0.27, 0.6))
			ground_decal(parent, Vector2(pos.x, ground_y), col, 70.0, false, 0.9)
		_:
			# Luz da Sophia: estrela branca curta, anel e faíscas na cor do Anel.
			_flash_sprite(parent, pos, "light", Color(1, 1, 1, 0.9 * fb), 0.12, 0.5, 0.12)
			_flash_sprite(parent, pos, "glow", Color(col.r, col.g, col.b, 0.7), 0.15, 0.45, 0.22)
			shock_ring(parent, pos, 22.0, col.lightened(0.2), 0.22, false, 1.0, 0.12)
			_spray(parent, pos, col, 10, dirx, "spark", 1.0)
			ground_decal(parent, ground, col, 56.0, true, 0.45)


## A vida do projétil acabou no ar: o núcleo implode, motes se desfazem.
static func attack_fizzle(parent: Node, pos: Vector2, col: Color, kind: String = "light") -> void:
	if not _ok(parent, false):
		return
	var dark := not AttackStyle.is_light(kind) and kind != "king"
	_flash_sprite(parent, pos, "glow", Color(col.r, col.g, col.b, 0.8), 0.35, 0.02, 0.22)
	shock_ring(parent, pos, 14.0, col, 0.2, dark, 1.0, 0.18)
	var p := _burst(parent, pos, "magic2" if not dark else "spark2", 6, 0.5)
	p.spread = 180.0
	p.gravity = Vector2(0, -40.0)
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 50.0
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.08
	p.scale_amount_curve = _shrink_curve()
	p.color = col.lightened(0.2)


## Aura de magia que segue `host` por `dur` s (ex.: Reflexo do Espelho):
## cacos de luz orbitando + brilho pulsando. Devolve o nó.
static func aura(host: Node2D, col: Color, dur: float, offset: Vector2 = Vector2(0, -22)) -> Node2D:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return null
	var old := host.get_node_or_null("VfxAura")
	if old != null:
		old.queue_free()
	var root := Node2D.new()
	root.name = "VfxAura"
	root.position = offset
	root.z_index = 2
	host.add_child(root)
	var g := Sprite2D.new()
	g.texture = tex("glow")
	g.material = _additive()
	g.modulate = Color(col.r, col.g, col.b, 0.35)
	g.scale = Vector2(0.45, 0.7)
	root.add_child(g)
	var tw := g.create_tween().set_loops()
	tw.tween_property(g, "modulate:a", 0.15, 0.35)
	tw.tween_property(g, "modulate:a", 0.4, 0.35)
	var p := CPUParticles2D.new()
	p.texture = tex("star")
	p.material = _additive()
	p.amount = 10
	p.lifetime = 0.9
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 24.0
	p.gravity = Vector2.ZERO
	p.tangential_accel_min = 120.0
	p.tangential_accel_max = 160.0
	p.radial_accel_min = -20.0
	p.radial_accel_max = -10.0
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.06
	p.scale_amount_curve = _scale_curve(0.3)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.color = col
	root.add_child(p)
	p.emitting = true
	host.get_tree().create_timer(dur, false).timeout.connect(root.queue_free)
	return root


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
# PRÉ-AQUECIMENTO (agente de Desempenho, Onda 2 — docs/onda2/PERF.md)
# ===========================================================================
## Chamado 1x no load da fase (Level._ready). Desenha por 3 quadros, sobre a
## Sophia e QUASE TRANSPARENTE (alfa 0,01 em escala 0,25), o visual real
## das criaturas da tela, os gibs, o afterimage, o esqueleto e os efeitos do
## combate, e carrega (segurando a referência) as texturas da 1ª criatura/efeito.
## O driver compila as variantes de shader e sobe as texturas AGORA, e não no
## 1º golpe/1ª morte/1ª esquiva. Sem som, sem tremor, fora dos grupos do jogo.
## Medido: um SubViewport invisível NÃO serve (as variantes de lá não valem
## para a tela); alfa < 0,007 é descartado pelo Godot antes de desenhar.

## Texturas de VFX que o combate carrega sob demanda (assets/vfx/*.png, 128 px).
const PREWARM_TEX := ["circle", "dirt", "flame", "flame2", "flare", "glow", "halo", "light",
	"magic", "magic2", "scorch", "slash", "smoke", "smoke2", "spark", "spark2", "star",
	"star2", "symbol", "trace", "twirl", "window"]
## Folhas pintadas que as criaturas e os gibs usam (carregadas no 1º desenho).
const PREWARM_SHEETS := ["inhabitants", "archons"]
const PREWARM_ALPHA := 0.01      # >= 0,007 (abaixo disso o Godot nem desenha)
const PREWARM_FRAMES := 3

## Referências seguradas até a próxima fase (o cache de recursos do Godot solta
## o que ninguém segura; sem isto o load() seguinte relê do disco).
static var _warm_refs: Array = []


static func prewarm(level: Node) -> void:
	if level == null or not level.is_inside_tree():
		return
	_warm_refs.clear()
	# 1) Disco → memória → GPU: texturas de VFX, folhas das criaturas e o
	#    boneco articulado da variante do Éon (família do Arconte).
	for n in PREWARM_TEX:
		tex(n)
	var screen: int = RunManager.current_screen if RunManager.run_active else 0
	var sheets: Array = PREWARM_SHEETS.duplicate()
	if RunManager.run_active and (RunManager.is_king_screen(screen) or RunManager.is_final(screen)):
		sheets.append("yaldabaoth")
	for sh in sheets:
		_warm_refs.append(PaintedLibrary.sheet(sh))
	var eon: int = RunManager.eon_index(screen) if RunManager.run_active else -1
	var puppet_tex: Texture2D = null
	if eon >= 0 and eon < 7 and not RunManager.is_king_screen(screen):
		if ResourceLoader.exists(BossPuppet.BAKE_PATH):
			_warm_refs.append(load(BossPuppet.BAKE_PATH))
		for layer in ["body", "parts", "arm_l", "arm_r"]:
			var path: String = BossPuppet.DERIVED + BossPuppet.NAMES[eon] + "_" + layer + ".png"
			if ResourceLoader.exists(path):
				var t = load(path)
				_warm_refs.append(t)
				if puppet_tex == null:
					puppet_tex = t
	# 2) Compilar as variantes: um palco quase transparente no centro da câmera.
	var stage := Node2D.new()
	stage.name = "PrewarmStage"
	stage.modulate = Color(1, 1, 1, PREWARM_ALPHA)
	stage.scale = Vector2.ONE * 0.25
	# o diálogo de abertura PAUSA a árvore: sem isto o boneco não é montado nem
	# as partículas emitem, e nada disso chega a ser desenhado (medido)
	stage.process_mode = Node.PROCESS_MODE_ALWAYS
	level.add_child(stage)
	# Em cima da Sophia (a câmera a segue). NÃO usar o centro da câmera: no
	# `_ready` da fase a câmera ainda não foi posicionada e o palco caía fora da
	# tela (medido: o que fica fora da tela não é desenhado e não compila nada).
	var pl = level.get("player")
	var cam := level.get_viewport().get_camera_2d()
	if pl is Node2D and (pl as Node2D).is_inside_tree():
		stage.global_position = (pl as Node2D).global_position + Vector2(0, -30)
	elif cam != null:
		stage.global_position = cam.get_screen_center_position()
	else:
		stage.global_position = Vector2(320, 180)
	var at := stage.global_position
	var col := Color(1.0, 0.85, 0.5)
	# 2a) folhas pintadas com o material das pinturas (rect + painted_clean),
	#     pequenas (só sobem e amarram a textura; o visual real das criaturas,
	#     abaixo, é que amostra os mesmos mipmaps do jogo)
	for t in _warm_refs:
		if t is Texture2D:
			var spr := Sprite2D.new()
			spr.texture = t
			spr.material = PaintedLibrary.material()
			spr.scale = Vector2.ONE * 0.1
			stage.add_child(spr)
	# 2b) as criaturas desta tela: o VISUAL real (CharacterArt, sem Enemy: fora
	#     do grupo "enemy", sem física/IA) — material próprio, folha, e o boneco
	#     articulado da variante do Éon — e o 1º desmembramento de cada uma
	#     (gibs reais, recortes da folha + painted_clean).
	var types: Array = []
	for id in Bestiary.types_for_screen(screen):
		if not id in types:
			types.append(id)
	for id in types:
		var prof = Bestiary.get_type(id).get("profile", null)
		if prof == null:
			continue
		var art := CharacterArt.new()
		stage.add_child(art)
		art.set_profile(prof)
		var parts: Array = art.gib_parts()
		if not parts.is_empty():
			Gib.burst(stage, at, parts, 1.0, at.y + 9999.0, Vector2.ZERO, col, Color.BLACK)
	# 2b') contorno de leitura dos inimigos (R18, combate2): CanvasGroup com o
	#      shader do contorno — variante própria (backbuffer + screen_texture).
	var rim := CanvasGroup.new()
	rim.fit_margin = 6.0
	rim.clear_margin = 6.0
	var rim_m := ShaderMaterial.new()
	rim_m.shader = rim_shader()
	rim.material = rim_m
	stage.add_child(rim)
	var rim_spr := Sprite2D.new()
	rim_spr.texture = tex("glow")
	rim_spr.scale = Vector2.ONE * 0.1
	rim.add_child(rim_spr)
	# 2b'') flash aditivo da Sophia (F1): a variante compila agora, não no 1º dano
	var fl := Sprite2D.new()
	fl.texture = tex("glow")
	fl.scale = Vector2.ONE * 0.1
	var fl_m := ShaderMaterial.new()
	fl_m.shader = flash_add_shader()
	fl_m.set_shader_parameter("flash", Color(1, 1, 1, 0.5))
	fl.material = fl_m
	stage.add_child(fl)
	# 2c) afterimage da esquiva (painted_ghost em malha de triângulos, sobre o
	#     atlas da Sophia). A camada é top_level (coordenadas de MUNDO): o alfa
	#     vai na cor da cópia.
	var ghosts := CharacterArt.AfterimageLayer.new()
	stage.add_child(ghosts)
	var db: Dictionary = CharacterArt.frame_db("sophia")
	var tex: Texture2D = db.atlas if not db.is_empty() else PaintedLibrary.sheet("inhabitants")
	var mesh: Dictionary = CharacterArt.grid_mesh("prewarm", Rect2(0, 0, 64, 64), Vector2(32, 64), Vector2(tex.get_width(), tex.get_height()))
	ghosts.add(Transform2D(0.0, Vector2(0.25, 0.25), 0.0, at), mesh, tex, Color(0.55, 0.85, 1.0, PREWARM_ALPHA * 2.0), 0.5)
	# 2d) boneco articulado (Skeleton2D deforma Polygon2D: shader de esqueleto)
	var sk := Skeleton2D.new()
	sk.name = "Sk"
	var bone := Bone2D.new()
	bone.name = "B"
	bone.rest = Transform2D.IDENTITY
	bone.set_autocalculate_length_and_angle(false)
	bone.set_length(8.0)
	sk.add_child(bone)
	stage.add_child(sk)
	var poly := Polygon2D.new()
	poly.texture = puppet_tex if puppet_tex != null else PaintedLibrary.sheet("inhabitants")
	poly.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])
	poly.uv = PackedVector2Array([Vector2(0, 0), Vector2(32, 0), Vector2(32, 32), Vector2(0, 32)])
	stage.add_child(poly)
	poly.skeleton = poly.get_path_to(sk)
	poly.add_bone(NodePath("B"), PackedFloat32Array([1.0, 1.0, 1.0, 1.0]))
	# 2e) os efeitos do combate, pelas funções reais
	#     (boss_death fica de fora: sacode a câmera; os nós dele já estão cobertos)
	hit(stage, at, false, col)
	hit(stage, at, true, col)
	parry(stage, at)
	dodge_perfect(stage, at)
	cast(stage, at)
	nova_ring(stage, at, 10.0)
	dust(stage, at)
	spark_pickup(stage, at)
	enemy_death(stage, at, col)
	elite_death(stage, at, col)
	boss_appear(stage, at, col)
	boss_phase2(stage, at, col)
	tell_glint(stage, at, false)
	tell_glint(stage, at, true)
	portal(stage, at, Color(0.8, 0.9, 1.0), 0.1)
	# VFX7: as famílias de projétil (núcleo/rastro/anel = shaders próprios), os
	# impactos, a dissipação, a antecipação e a aura — compilam agora.
	for k in AttackStyle.STYLES:
		var h := Node2D.new()
		stage.add_child(h)
		ProjectileFX.attach(h, k, col)
	for imp in ["light", "explosion", "chain", "dark", "king", "sleep", "wave"]:
		attack_impact(stage, at, col, imp, 1.0, at.y + 20.0)
	attack_fizzle(stage, at, col, "dark")
	shock_ring(stage, at, 10.0, col, 0.1, true)
	ground_decal(stage, at, col, 20.0, false, 0.1)
	for cs in ["light", "dark", "king"]:
		var ch := ChargeFX.new()
		ch.silent = true
		ch.style = cs
		ch.duration = 0.1
		stage.add_child(ch)
	aura(stage, col, 0.1)
	_flash_log.clear()                 # o pré-aquecimento não gasta o orçamento de flashes
	ImpactBurst.spawn(stage, at, col)
	DamageNumber.spawn(stage, at, 1234567890, col, true)   # todos os glifos 0–9 da fonte (ignora a opção)
	# 3) Some depois de PREWARM_FRAMES quadros DESENHADOS (compila no desenho).
	var left := [PREWARM_FRAMES]
	var done := func() -> void:
		left[0] -= 1
		if left[0] == 0 and is_instance_valid(stage):
			stage.queue_free()
	RenderingServer.frame_post_draw.connect(done)
	stage.tree_exited.connect(func(): RenderingServer.frame_post_draw.disconnect(done), CONNECT_ONE_SHOT)
	# Sem janela (headless: bot de balance, QAs) não há quadro desenhado e o
	# frame_post_draw nunca vem — o palco ficaria para sempre rodando (ALWAYS).
	if DisplayServer.get_name() == "headless":
		level.get_tree().create_timer(0.5, true, false, true).timeout.connect(stage.queue_free)
