extends ParallaxBackground
class_name Scenery
## CENÁRIO POR ÉON (v3 — Diretor de Cenário). Monta em runtime, a partir das
## camadas PINTADAS geradas offline (`tools/scenery/build_backgrounds.py` →
## `assets/backgrounds/eon_<i>_{far,mid,near,floor,fgcol}.png`, catálogo em
## `SceneryLibrary`), um palco 2.5D em profundidade:
##   céu (gradiente) · FAR (distância, quase parada) · raios de luz · névoa
##   longe · MID (as asas: pilares/estantes) · névoa perto · NEAR (entulho do
##   horizonte) · props pintados (pilares/obeliscos/braseiros integrados à luz)
## e, em coords de mundo (filhos do Level, pelos ganchos que o Level já chama):
##   `build_ground`    → chão 2.5D (shader: perspectiva, reflexo, luz, sombra),
##                       névoa rasteira, arena simétrica de chefe e integração
##                       das plataformas (sombra, borda acesa, poeira, luz);
##   `build_foreground`→ silhuetas desfocadas à frente (parallax > 1) e bokeh;
##   `build_vignette`  → vinheta.
## Tudo determinístico: a mesma tela sempre gera o mesmo cenário.
## Se existir `assets/backgrounds/eon_<i>.png` (arte única do usuário), ela
## manda e o resto é ignorado (comportamento antigo).

const W := 1800.0          # período dos props pintados (mirroring)
const FLOOR_Y := 292.0     # horizonte do chão: onde a pintura encontra o chão
const FEET_Y := 310.0      # linha dos pés (topo da colisão do Level)
const PAINT_H := 280.0     # altura lógica da pintura acima do chão
const CAM_TOP := 44.0      # topo da câmera com a Sophia em pé (enquadramento)
const CAM_LEFT0 := -110.0  # borda esquerda da câmera no início da tela
const VIEW := Vector2(640.0, 360.0)

## Cor de base por Éon (fallback sem as camadas geradas).
const FALLBACK := [Color("27464e"), Color(0.45, 0.16, 0.12), Color(0.28, 0.32, 0.42), Color(0.14, 0.10, 0.26), Color(0.55, 0.58, 0.72), Color(0.22, 0.34, 0.20), Color(0.42, 0.28, 0.10), Color(0.12, 0.10, 0.16), Color(0.20, 0.06, 0.14)]

## Ferramentas (HdShot oldbg): desliga os fundos HD e usa as camadas antigas.
static var hd_disabled: bool = false

var eon: int = 0
var seed_screen: int = 1
var _built: bool = false
var _tile_w: float = 560.0                 # largura lógica de um ladrilho pintado
var _far: ParallaxLayer = null
var _rays: ColorRect = null
var _ray_pt: Vector2 = Vector2.ZERO        # foco dos raios no ladrilho (coords da camada)
var _far_sprite: Sprite2D = null           # o quad do far (p/ achar o astro na TELA)
var _ray_tex: Vector2 = Vector2.ZERO       # foco dos raios em px da textura do far
var _fogs: Array = []                      # [{rect, ms, y}]


func _ready() -> void:
	if not _built:
		var e := 0
		var sc := 1
		if RunManager.run_active:
			sc = RunManager.current_screen
			e = RunManager.eon_index(sc)
		build(e, sc)


func look() -> Dictionary:
	return SceneryLibrary.look(eon)


func haze() -> Color:
	return SceneryLibrary.data(eon).get("haze", FALLBACK[clampi(eon, 0, 8)])


func is_boss() -> bool:
	return RunManager.run_active and RunManager.is_boss_screen(seed_screen)


## Monta (ou remonta) o cenário do Éon. Retorna true se usou o PNG único do
## usuário (aí o Level não pede chão/primeiro plano).
func build(p_eon: int, screen: int = 1) -> bool:
	if _built and p_eon == eon and screen == seed_screen and get_child_count() > 0:
		return false                      # o Level pede de novo o que o _ready já montou
	eon = p_eon
	seed_screen = screen
	_built = true
	for c in get_children():
		c.queue_free()
	_fogs.clear()
	_far = null
	_rays = null
	var png := "res://assets/backgrounds/eon_%d.png" % eon
	if ResourceLoader.exists(png):
		var tex = load(png)
		var layer := _layer(Vector2.ZERO, 0.0)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.scale = Vector2((640.0 / 0.75) / float(tex.get_width()), (360.0 / 0.75) / float(tex.get_height()))
		layer.add_child(spr)
		VfxLibrary.ambient(self, eon)
		return true
	if SceneryLibrary.has_layers(eon):
		_build_painted()
	else:
		_build_fallback()
	if not is_boss():
		_build_architecture()
	VfxLibrary.ambient(self, eon)     # partículas do Éon (motes, brasas, cacos…)
	return false


func _layer(scale: Vector2, mirror_w: float) -> ParallaxLayer:
	var l := ParallaxLayer.new()
	l.motion_scale = scale
	if mirror_w > 0.0:
		l.motion_mirroring = Vector2(mirror_w, 0)
	add_child(l)
	return l


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("eon%d_s%d_%d" % [eon, seed_screen, salt])
	return r


## Deslocamento que alinha uma camada (motion `ms`) no início da tela: o miolo
## do ladrilho no centro da tela e o chão da pintura em FLOOR_Y.
func _align(ms: Vector2, tw: float = -1.0) -> Vector2:
	if tw <= 0.0:
		tw = _tile_w
	return Vector2(VIEW.x * 0.5 - tw * 0.5 + CAM_LEFT0 * ms.x, CAM_TOP * (ms.y - 1.0))


# --- camadas pintadas -------------------------------------------------------------

func _build_painted() -> void:
	var d := SceneryLibrary.data(eon)
	var size: Vector2 = d.size
	var s: float = PAINT_H / size.y
	_tile_w = size.x * s
	var lk := look()
	var h := {} if hd_disabled else SceneryLibrary.hd(eon)
	_build_sky(d.sky, d.haze)
	var far_top := FLOOR_Y - PAINT_H
	if h.has("far"):
		# FAR HD (Cenário 7): pintura nova em resolução cheia, horizonte MEDIDO em FLOOR_Y.
		var fd: Dictionary = h.far
		_tile_w = float(fd.w) * float(fd.s)
		far_top = _hd_top(fd, float(fd.s))
		_far = _hd_layer(fd, float(fd.s), MS_FAR, 0.0, Color(1, 1, 1), 0.0)
	else:
		# FAR: distância quase parada (anda 3% da câmera).
		_far = _painted_layer("far", Vector2(0.03, 0.9), 0.0, s, Color(1, 1, 1))
	_sky_fade(_far, d.sky, far_top)
	if eon == 7:
		_orbit_sparks(_far, s)
	_far_motes(d.haze)
	# Raios: foco no astro da pintura (coords da camada far).
	_ray_pt = Vector2(lk.ray.x * _tile_w, FLOOR_Y - PAINT_H + lk.ray.y * PAINT_H)
	_far_sprite = _far.get_child(0) as Sprite2D
	var far_s: float = _far_sprite.scale.x
	_ray_tex = Vector2(_ray_pt.x, _ray_pt.y - far_top) / far_s
	if h.has("far") and bool(lk.get("ray_hd", false)):
		var fdr: Dictionary = h.far
		_ray_tex = fdr.astro                          # astro MEDIDO na pintura nova (px)
	_rays = _screen_rect("rays")
	_rays.material.set_shader_parameter("col", lk.ray_col)
	_rays.material.set_shader_parameter("amt", lk.ray_amt)
	_rays.material.set_shader_parameter("spread", lk.ray_spread)
	_rays.material.set_shader_parameter("dark", lk.get("ray_dark", false))
	# Névoa longe (entre o far e as asas).
	_add_fog(Vector2(0.08, 0.92), FLOOR_Y - 150.0, FLOOR_Y - 40.0, FLOOR_Y + 4.0, d.haze, 0.30 * lk.mist, 0.004, 4.0, 1.0)
	var r := _rng(11)
	if h.has("mid") and not (h.mid as Array).is_empty():
		# MID HD: estruturas do meio (variante e fase sorteadas por tela).
		_hd_variant(h.mid, float(h.s), MS_MID, r, MID_TINT, MID_SINK)
	else:
		# MID: as asas (pilares das bordas), um pouco mais escuras que o fundo.
		_tile_w = size.x * s
		_painted_layer("mid", Vector2(0.14, 0.95), 0.0, s, Color(0.80, 0.80, 0.84))
	# Névoa perto do horizonte.
	_add_fog(Vector2(0.22, 0.97), FLOOR_Y - 80.0, FLOOR_Y - 14.0, FLOOR_Y + 6.0, Color(d.haze).lightened(0.1), 0.38 * lk.mist, 0.007, 7.0, 2.0)
	if h.has("wings") and not (h.wings as Array).is_empty():
		# ASAS HD: pilares das bordas + entulho, a camada pintada mais rápida.
		_hd_variant(h.wings, float(h.s), MS_WINGS, r, WINGS_TINT, 0.0)
	else:
		_tile_w = size.x * s
		if h.has("mid"):
			# Éon com mid HD mas sem as asas novas (ainda não chegaram): as asas
			# ANTIGAS (pilares das bordas da pintura 3×) vêm NA FRENTE do mid novo,
			# no ritmo das asas (mais rápidas que o mid — parallax coerente).
			_painted_layer("mid", Vector2(0.30, 0.97), 0.0, s, Color(0.74, 0.74, 0.78))
		# NEAR: a faixa de entulho/velas do horizonte.
		_painted_layer("near", Vector2(0.32, 1.0), float(d.get("near_y", 0)) * s, s, Color(0.70, 0.70, 0.76))
	if h.has("far"):
		_tile_w = float((h.far as Dictionary).w) * float((h.far as Dictionary).s)   # os raios usam o período do far


# --- camadas HD (Cenário 7) ---------------------------------------------------------
## PARALLAX REAL das camadas HD: far lento, mid médio, asas rápidas (o chão anda
## 1:1 na linha dos pés). y < 1: nos pulos altos o fundo sobe menos que o mundo.
const MS_FAR := Vector2(0.04, 0.88)
const MS_MID := Vector2(0.18, 0.94)
const MS_WINGS := Vector2(0.40, 0.98)
## Variação de tom por tela (multiplica a cor; determinística): [mín, máx] do brilho.
const MID_TINT := Vector2(0.90, 1.0)
const WINGS_TINT := Vector2(0.88, 1.0)
## A base MEDIDA do mid afunda isto (px lógicos) abaixo do horizonte: a borda de
## baixo some na névoa do chão em vez de virar uma linha reta.
const MID_SINK := -5.0


## Topo (y lógico) de uma camada HD posta com a linha do chão MEDIDA em FLOOR_Y.
func _hd_top(ld: Dictionary, sc: float) -> float:
	return FLOOR_Y - (float(ld.line) - float(ld.y0)) * sc


## Uma camada HD espelhada sem emenda (mesmo quad do `_mirror_strip`), com a
## linha do chão dela em FLOOR_Y − lift e a fase (px lógicos, 0..2·ladrilho;
## passar de 1 ladrilho = começa espelhada) que varia por tela.
func _hd_layer(ld: Dictionary, sc: float, ms: Vector2, phase: float, mod: Color, lift: float) -> ParallaxLayer:
	var tw := float(ld.w) * sc
	var l := _layer(ms, tw * 2.0 * PERIODS)
	l.motion_offset = _align(ms, tw) - Vector2(phase, 0.0)
	l.add_child(_mirror_strip(SceneryLibrary.hd_texture(eon, String(ld.tex)), sc, _hd_top(ld, sc) - lift, mod))
	return l


## Sorteia (por tela) a variante, a fase e o tom de uma camada HD.
func _hd_variant(list: Array, sc: float, ms: Vector2, r: RandomNumberGenerator, tint: Vector2, lift: float) -> ParallaxLayer:
	var ld: Dictionary = list[r.randi() % list.size()]
	var tw := float(ld.w) * sc
	var phase := r.randf_range(0.0, tw * 2.0)
	var k := r.randf_range(tint.x, tint.y)
	return _hd_layer(ld, sc, ms, phase, Color(k, k, k * 1.02), lift)


## Uma camada pintada espelhada: [ladrilho][ladrilho invertido], período 2×.
## SEM EMENDA POR CONSTRUÇÃO (M5): é UM só quad (Sprite2D com região larga e
## repetição em ESPELHO na amostragem), cobrindo PERIODS períodos a partir de
## um período à esquerda — a câmera nunca chega numa junção entre quads. (Dois
## sprites lado a lado em posição fracionária podiam deixar 1 px de fresta ou
## de borda filtrada na junção.) O espelhamento da camada fica só de reserva.
const PERIODS := 5
func _painted_layer(kind: String, ms: Vector2, y_off: float, s: float, mod: Color) -> ParallaxLayer:
	var l := _layer(ms, _tile_w * 2.0 * PERIODS)
	l.motion_offset = _align(ms)
	l.add_child(_mirror_strip(SceneryLibrary.layer(eon, kind), s, FLOOR_Y - PAINT_H + y_off, mod))
	return l


## Faixa pintada sem emenda: um quad com a textura repetida em espelho,
## de x = -2·ladrilho até (PERIODS-1)·2·ladrilho (coords da camada).
func _mirror_strip(tex: Texture2D, s: float, y: float, mod: Color) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	sp.region_enabled = true
	var tw := float(tex.get_width())
	sp.region_rect = Rect2(-2.0 * tw, 0.0, 2.0 * tw * PERIODS, float(tex.get_height()))
	sp.scale = Vector2(s, s)
	sp.position = Vector2(-2.0 * tw * s, y)
	sp.modulate = mod
	return sp


## Céu fixo atrás de tudo (só aparece em pulos altos acima da pintura).
func _build_sky(sky: Color, hz: Color) -> void:
	var l := _layer(Vector2.ZERO, 0.0)
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([Vector2(-100, -200), Vector2(740, -200), Vector2(740, 460), Vector2(-100, 460)])
	var top := sky.darkened(0.35)
	var bot := sky.lerp(hz, 0.35)
	p.vertex_colors = PackedColorArray([top, top, bot, bot])
	l.add_child(p)


## Funde o topo da pintura no céu (sem borda dura quando a Sophia pula alto).
func _sky_fade(l: ParallaxLayer, sky: Color, top: float = FLOOR_Y - PAINT_H) -> void:
	var p := Polygon2D.new()
	var c0 := sky.darkened(0.35)
	var c1 := Color(sky.r, sky.g, sky.b, 0.0)
	var x0 := -_tile_w * 2.0
	var x1 := _tile_w * 2.0 * float(PERIODS - 1)
	p.polygon = PackedVector2Array([Vector2(x0, top - 400), Vector2(x1, top - 400), Vector2(x1, top + 34), Vector2(x0, top + 34)])
	p.vertex_colors = PackedColorArray([c0, c0, c1, c1])
	l.add_child(p)


## Retângulo fixo na tela com shader do cenário (raios/névoa).
func _screen_rect(shader_name: String) -> ColorRect:
	var l := _layer(Vector2.ZERO, 0.0)
	var r := ColorRect.new()
	r.position = Vector2(-40, -40)
	r.size = VIEW + Vector2(80, 80)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = SceneryLibrary.material(shader_name)
	l.add_child(r)
	return r


## Faixa de névoa: retângulo fixo na tela que acompanha o y da câmera no ritmo
## `ms` e escorre em x pelo offset (profundidade = ritmo).
func _add_fog(ms: Vector2, y_top: float, y_peak: float, y_bot: float, col: Color, dens: float, sc: float, speed: float, seed_v: float) -> void:
	var r := _screen_rect("fog")
	r.size = Vector2(VIEW.x + 80.0, y_bot - y_top + 20.0)
	var m: ShaderMaterial = r.material
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("density", dens)
	m.set_shader_parameter("y_top", 0.0)
	m.set_shader_parameter("y_peak", y_peak - y_top)
	m.set_shader_parameter("y_bot", y_bot - y_top)
	m.set_shader_parameter("scale", sc)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("seed", seed_v + float(eon))
	_fogs.append({"rect": r, "ms": ms, "y": y_top})


## PROFUNDIDADE (VFX.md falta 4): poeira LONGE — pontinhos pequenos e apagados
## numa camada que anda 15% da câmera (as partículas do Éon, em VfxLibrary,
## ficam paradas na tela; a poeira PERTO do chão fica no Foreground). Camada
## espelhada a cada 720 px: a poeira cobre a travessia inteira.
func _far_motes(hz: Color) -> void:
	var l := _layer(Vector2(0.15, 0.9), 720.0)
	var p := CPUParticles2D.new()
	p.texture = VfxLibrary.tex("circle")
	p.local_coords = true
	p.position = Vector2(360.0, FLOOR_Y - 130.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(360.0, 120.0)
	p.amount = 22
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.direction = Vector2(1, -0.4)
	p.spread = 50.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.scale_amount_min = 0.010
	p.scale_amount_max = 0.022
	var dark := bool(look().get("ray_dark", false))
	var c := Color(0.08, 0.0, 0.05) if dark else hz.lightened(0.35)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(c, 0.0))
	ramp.set_color(1, Color(c, 0.0))
	ramp.add_point(0.5, Color(c, 0.45 if dark else 0.35))
	p.color_ramp = ramp
	l.add_child(p)
	p.emitting = true


## Centro: faíscas em órbita em volta da esfera da máquina (nas duas metades).
func _orbit_sparks(l: ParallaxLayer, s: float) -> void:
	var lk := look()
	for k in 2:
		var p := CPUParticles2D.new()
		var x: float = lk.ray.x * _tile_w
		if k == 1:
			x = _tile_w * 2.0 - x
		p.position = Vector2(x, FLOOR_Y - PAINT_H + lk.ray.y * PAINT_H)
		p.texture = VfxLibrary.tex("spark")
		p.material = VfxLibrary._additive()
		p.amount = 28
		p.lifetime = 5.0
		p.preprocess = 5.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
		p.emission_sphere_radius = 34.0 * s * 3.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 2.0
		p.orbit_velocity_min = 0.05
		p.orbit_velocity_max = 0.12
		p.scale_amount_min = 0.02
		p.scale_amount_max = 0.05
		p.color = Color(1.0, 0.82, 0.5, 0.85)
		p.local_coords = true
		l.add_child(p)
		p.emitting = true


func _process(_delta: float) -> void:
	if _rays == null and _fogs.is_empty():
		return
	var ct := get_viewport().get_canvas_transform()
	var cam := -ct.origin                     # canto superior esquerdo da câmera (mundo)
	if _rays != null and _far_sprite != null and is_instance_valid(_far_sprite):
		# Cenário 7: o astro vai pra tela pela transformação REAL do quad do far
		# (inclui o zoom 1,2 da câmera que o ParallaxBackground aplica; a conta
		# antiga em px de camada errava o foco em dezenas de px). Dois focos: o
		# astro do ladrilho direto e o do espelhado, cada um no período mais
		# perto do centro da tela.
		var to_screen := _far_sprite.get_global_transform_with_canvas()
		var to_rect := (_rays as CanvasItem).get_global_transform_with_canvas().affine_inverse()
		var tw := float(_far_sprite.texture.get_width())
		var a := _nearest_src(to_screen, 2.0 * tw + _ray_tex.x, tw)
		var b := _nearest_src(to_screen, 4.0 * tw - _ray_tex.x, tw)
		var m: ShaderMaterial = _rays.material
		m.set_shader_parameter("src_a", to_rect * a)
		m.set_shader_parameter("src_b", to_rect * b)
		m.set_shader_parameter("w_a", _ray_weight(a.x))
		m.set_shader_parameter("w_b", _ray_weight(b.x))
	for f in _fogs:
		var r: ColorRect = f.rect
		var ms: Vector2 = f.ms
		r.position.y = float(f.y) - cam.y * ms.y + CAM_TOP * (ms.y - 1.0)
		r.material.set_shader_parameter("offset", cam.x * ms.x)


## Foco na tela (coords lógicas do viewport) mais perto do centro, entre as
## repetições (período 2·tw em px de textura) do ponto local (x0, _ray_tex.y).
func _nearest_src(to_screen: Transform2D, x0: float, tw: float) -> Vector2:
	var best := Vector2(INF, 0.0)
	for k in range(-1, PERIODS):
		var p := to_screen * Vector2(x0 + 2.0 * tw * float(k), _ray_tex.y)
		if absf(p.x - VIEW.x * 0.5) < absf(best.x - VIEW.x * 0.5):
			best = p
	return best


## Peso dos raios de um foco em x (tela): 1 dentro do quadro, cai até 0,3 a
## 260 px fora dele (astro que não se vê ilumina pouco — R18/§4: luz sem motivo
## em cima da luta só cansa).
static func _ray_weight(x: float) -> float:
	var out := maxf(0.0, maxf(-x, x - VIEW.x))
	return clampf(1.0 - out / 260.0 * 0.7, 0.3, 1.0)


# --- fallback (sem camadas geradas) -----------------------------------------------

func _build_fallback() -> void:
	var c: Color = FALLBACK[clampi(eon, 0, 8)]
	_build_sky(c.darkened(0.5), c)
	# A v2 repetia a pintura SEM espelhar a cada 768 px: emenda dura (M5).
	# Aqui: [pintura][pintura invertida] (a textura é recorte de atlas, então
	# não dá para usar repetição em espelho na amostragem).
	var tex := PaintedLibrary.background(clampi(eon, 0, 8))
	var sc := Vector2(768.0 / tex.get_width(), 400.0 / tex.get_height())
	var l := _layer(Vector2(0.18, 1.0), 768.0 * 2.0)
	for k in 2:
		var backdrop := Sprite2D.new()
		backdrop.texture = tex
		backdrop.centered = false
		backdrop.scale = sc
		backdrop.flip_h = k == 1
		backdrop.position.x = 768.0 * float(k)
		backdrop.modulate = Color(0.68, 0.73, 0.77)
		l.add_child(backdrop)


# --- props pintados (entre o horizonte e a faixa de luta) ---------------------------

## Arquitetura pintada (pilares, obeliscos, entulho, braseiros) em duas camadas
## de parallax, integrada à luz do Éon (shader prop: névoa por distância, borda
## acesa, chama na cor do Éon) e com sombra de contato. Determinística por tela.
func _build_architecture() -> void:
	var mid := _layer(Vector2(0.55, 1.0), W)
	var r := _rng(3)
	var mat_mid := SceneryLibrary.prop_material(eon, 0.30, 0.30, 0.45)
	var x := r.randf_range(20.0, 160.0)
	# Com o MID HD (estátuas/arcadas pintadas em resolução cheia) os pilares e
	# obeliscos genéricos daqui sobram: mais baixa resolução e o quadro fica
	# entulhado (NEURO_SATISFACAO §4/R21: respiro). Fica só a fila de perto.
	var hd := {} if hd_disabled else SceneryLibrary.hd(eon)
	if hd.has("mid") and not (hd.mid as Array).is_empty():
		x = W
	while x < W - 80.0:
		var kind: int = 0 if r.randf() < 0.62 else 2
		var h: float = r.randf_range(170.0, 240.0) if kind == 0 else r.randf_range(140.0, 200.0)
		_contact_shadow(mid, Vector2(x, FLOOR_Y + 1.0), h * 0.42)
		var s := PaintedLibrary.sprite(kind, h)
		s.material = mat_mid
		s.position = Vector2(x, FLOOR_Y + 3.0)
		s.modulate = Color(1, 1, 1).darkened(r.randf_range(0.0, 0.15))
		if r.randf() < 0.5:
			s.scale.x = -s.scale.x
		mid.add_child(s)
		x += r.randf_range(380.0, 620.0)
	var near := _layer(Vector2(0.75, 1.0), W)
	var r2 := _rng(4)
	var mat_near := SceneryLibrary.prop_material(eon, 0.14, 0.18, 0.6)
	x = r2.randf_range(60.0, 240.0)
	while x < W - 40.0:
		var brazier: bool = r2.randf() < 0.42
		var h2: float = r2.randf_range(34.0, 44.0) if brazier else r2.randf_range(44.0, 80.0)
		_contact_shadow(near, Vector2(x, FLOOR_Y + 2.0), h2 * 0.8)
		var s2 := PaintedLibrary.sprite(4 if brazier else 3, h2)
		s2.material = mat_near
		s2.position = Vector2(x, FLOOR_Y + 4.0)
		if brazier:
			near.add_child(s2)
			_flame_light(near, Vector2(x, FLOOR_Y + 4.0 - h2 * 0.95), 0.6)
		else:
			if r2.randf() < 0.5:
				s2.scale.x = -s2.scale.x
			near.add_child(s2)
		x += r2.randf_range(260.0, 520.0)


## Sombra de contato (elipse escura e macia) na base de um prop.
func _contact_shadow(parent: Node, pos: Vector2, half_w: float, alpha: float = 0.55) -> Sprite2D:
	var sh := Sprite2D.new()
	sh.texture = _blob_texture()
	sh.position = pos
	sh.scale = Vector2(half_w * 2.0 / 64.0, half_w * 0.36 / 64.0)
	sh.modulate = Color(0, 0, 0, alpha)
	parent.add_child(sh)
	return sh


static var _blob: GradientTexture2D = null

## Disco radial macio (branco → transparente; tingido por modulate), 64 px.
static func _blob_texture() -> GradientTexture2D:
	if _blob == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.6))
		_blob = GradientTexture2D.new()
		_blob.gradient = g
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 64
		_blob.height = 64
	return _blob


## Luz de chama: halo aditivo na cor do Éon que tremula, + brasas subindo.
func _flame_light(parent: Node, pos: Vector2, size: float) -> void:
	var lk := look()
	var g: Color = lk.glow
	var fl := Flicker.new()
	fl.texture = VfxLibrary.tex("light")
	fl.material = VfxLibrary._additive()
	fl.position = pos
	fl.base_scale = 0.32 * size
	fl.modulate = Color(g.r, g.g, g.b, 0.55)
	fl.phase = pos.x * 0.37
	parent.add_child(fl)
	var e := CPUParticles2D.new()
	e.position = pos
	e.texture = VfxLibrary.tex("spark2")
	e.material = VfxLibrary._additive()
	e.amount = 6
	e.lifetime = 1.6
	e.preprocess = 2.0
	e.direction = Vector2(0, -1)
	e.spread = 20.0
	e.initial_velocity_min = 12.0
	e.initial_velocity_max = 26.0
	e.gravity = Vector2(0, -8)
	e.scale_amount_min = 0.015 * size
	e.scale_amount_max = 0.035 * size
	e.color = Color(g.r, g.g, g.b, 0.8)
	e.local_coords = false
	parent.add_child(e)
	e.emitting = true


## Halo que respira (chama/brasa): a escala oscila devagar.
class Flicker extends Sprite2D:
	var base_scale: float = 0.3
	var phase: float = 0.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		var f := 1.0 + sin(_t * 7.3 + phase) * 0.06 + sin(_t * 13.1 + phase * 2.0) * 0.04
		scale = Vector2.ONE * base_scale * f


# --- chão (coords de mundo, filho do Level) --------------------------------------

## Chão 2.5D + névoa rasteira + arena de chefe + plataformas integradas.
## `ground_top_y` = topo da colisão do chão (linha dos pés).
func build_ground(parent: Node2D, ground_top_y: float) -> void:
	var fb := FloorBand.new()
	fb.setup(eon, ground_top_y)
	fb.z_index = -2
	parent.add_child(fb)
	# névoa rasteira: passa por cima dos pés (z acima dos lutadores, bem fraca)
	var gf := GroundFog.new()
	gf.setup(haze().lightened(0.15), 0.22 * float(look().mist), ground_top_y)
	gf.z_index = 6
	parent.add_child(gf)
	if is_boss():
		_build_boss_arena(parent, ground_top_y)
	# entulho espalhado no chão À FRENTE da faixa de luta, em perspectiva
	var dec := FloorDecor.new()
	dec.setup(eon, ground_top_y, _rng(7), is_boss())
	dec.z_index = 20
	parent.add_child(dec)
	_integrate_platforms.call_deferred(parent)
	# limites da arena legíveis (P2): véu nas paredes da zona + pilar nas fixas
	var ab := ArenaBounds.new()
	ab.eon = eon
	ab.feet = ground_top_y
	ab.glow = look().glow
	ab.dark_veil = bool(look().get("ray_dark", false))
	parent.add_child(ab)
	_build_end_walls.call_deferred(parent, ground_top_y)


## LIMITE FIXO DA ARENA (P2): nas paredes fixas (esquerda e direita da tela)
## fica um pilar pintado no plano da luta, meio fora da câmera, com entulho
## na base — a Sophia esbarra numa coisa que SE VÊ, não no ar. Roda no fim do
## quadro (o Level já calculou `_end_x`).
func _build_end_walls(level: Node, feet_y: float) -> void:
	if level == null or not is_instance_valid(level) or not level.has_method("arena_bounds"):
		return
	var right = level.get("_end_x")
	if right == null:
		right = (level.call("arena_bounds") as Vector2).y
	var walls := [Vector2(Level.WALL_LEFT, -1.0), Vector2(float(right), 1.0)]
	var mat := SceneryLibrary.prop_material(eon, 0.04, 0.30, 0.9)
	var node := Node2D.new()
	node.name = "EndWalls"
	node.z_index = -1                   # atrás dos lutadores, à frente do chão
	level.add_child(node)
	var dark := haze().darkened(0.88)
	for wv in walls:
		var wx: float = wv.x
		var side: float = wv.y            # -1 = parede esquerda
		# Além da parede o mundo se apaga: a antecipação da câmera (offset de
		# 90 px) passa do limite, então esse trecho aparece — escuro, não chão.
		var face: float = wx - side * 20.0
		var x1: float = face + side * 26.0
		var x2: float = face + side * 160.0
		node.add_child(_hquad(face, x1, Color(dark, 0.0), Color(dark, 0.7)))
		node.add_child(_hquad(x1, x2, Color(dark, 0.7), Color(dark, 0.96)))
		var pil := PaintedLibrary.sprite(0, 262.0)
		var pw: float = pil.texture.get_width() * pil.scale.x
		# ~46 px do pilar ficam dentro da área jogável (a parede tem 20 px de meia-largura)
		var px: float = wx - side * (46.0 + 20.0 - pw * 0.5)
		_contact_shadow(node, Vector2(px, feet_y + 1.0), pw * 0.55, 0.65)
		pil.material = mat
		pil.position = Vector2(px, feet_y + 4.0)
		if side > 0.0:
			pil.scale.x = -pil.scale.x
		node.add_child(pil)
		# entulho na base, do lado de dentro
		var rb := PaintedLibrary.sprite(3, 34.0)
		rb.material = mat
		rb.position = Vector2(wx - side * (20.0 + 46.0 + 4.0), feet_y + 6.0)
		if side > 0.0:
			rb.scale.x = -rb.scale.x
		node.add_child(rb)


## Quad vertical alto (y -420..520) com degradê horizontal de cor (xa → xb).
func _hquad(xa: float, xb: float, ca: Color, cb: Color) -> Polygon2D:
	var q := Polygon2D.new()
	q.polygon = PackedVector2Array([Vector2(xa, -420), Vector2(xb, -420), Vector2(xb, 520), Vector2(xa, 520)])
	q.vertex_colors = PackedColorArray([ca, cb, cb, ca])
	return q


class ArenaBounds extends Node2D:
	## LIMITE DA ZONA LEGÍVEL (P2): quando o Level tranca uma zona, nasce um véu
	## de luz na cor do Éon em cada parede móvel (com clarão de entrada); some
	## devagar quando a zona é liberada. Só lê o Level (`zone_active`,
	## `arena_bounds()`); não mexe na colisão.
	var eon: int = 0
	var feet: float = 310.0
	var glow: Color = Color(0.8, 0.9, 1.0)
	var dark_veil: bool = false        # Mente: o "brilho" do Éon é vazio — véu rosado apagado
	var _level: Node = null
	var _veils: Array = []
	var _amt: float = 0.0
	var _pulse: float = 0.0
	var _was: bool = false
	const HALF_WALL := 20.0             # meia-largura da parede de colisão do Level
	const H := 300.0

	func _ready() -> void:
		_level = get_parent()
		z_index = 4                        # à frente dos lutadores (fica na borda da tela)
		var c := glow
		if dark_veil:
			c = Color(0.85, 0.45, 0.6)
		for side in [-1.0, 1.0]:
			var v := VeilStrip.new()
			v.h = H
			var m := SceneryLibrary.material("veil")
			m.set_shader_parameter("col", c)
			m.set_shader_parameter("side", side)
			m.set_shader_parameter("height", H)
			m.set_shader_parameter("amt", 0.0)
			v.material = m
			v.position = Vector2(0.0, feet)
			v.visible = false
			add_child(v)
			_veils.append(v)

	func _process(delta: float) -> void:
		if _level == null or not is_instance_valid(_level) or not _level.has_method("arena_bounds"):
			return
		var active := bool(_level.get("zone_active"))
		if active:
			var b: Vector2 = _level.call("arena_bounds")
			(_veils[0] as Node2D).position.x = b.x + HALF_WALL
			(_veils[1] as Node2D).position.x = b.y - HALF_WALL
			if not _was:
				_pulse = 1.0                   # clarão ao trancar
		_was = active
		_amt = move_toward(_amt, 1.0 if active else 0.0, delta * (4.0 if active else 1.4))
		_pulse = maxf(0.0, _pulse - delta * 1.8)
		var a := _amt + _pulse * _pulse * 1.4
		for v in _veils:
			var n: Node2D = v
			n.visible = a > 0.01
			if n.visible:
				(n.material as ShaderMaterial).set_shader_parameter("amt", a)


class VeilStrip extends Node2D:
	## Retângulo do véu (o shader desenha tudo); x = 0 na parede, y = 0 nos pés.
	var h: float = 300.0

	func _draw() -> void:
		draw_rect(Rect2(-56.0, -h, 112.0, h + 16.0), Color.WHITE)

	func _ready() -> void:
		queue_redraw()


class FloorDecor extends Node2D:
	## Pedras e entulho pintados espalhados no chão entre os pés e a câmera.
	## Cada peça anda no ritmo da perspectiva do chão na sua profundidade
	## (mesma conta do shader do chão) — o chão vira um plano 2.5D de verdade.
	var _items: Array = []          # [{node, x, y}]
	var _feet: float = 310.0
	const BAND := 136.0
	const PERSP := 0.45

	func setup(e: int, feet_y: float, r: RandomNumberGenerator, boss: bool) -> void:
		_feet = feet_y
		var mat := SceneryLibrary.prop_material(e, 0.0, 0.35, 0.5)
		var x := -900.0 + r.randf_range(0.0, 200.0)
		var span := 1800.0 if boss else 5200.0
		while x < span:
			var t := r.randf()                       # 0 = rente à luta, 1 = colado na câmera
			var y := feet_y + 14.0 + t * 78.0
			var h := lerpf(12.0, 34.0, t) * r.randf_range(0.8, 1.25)
			var holder := Node2D.new()
			var sh := Sprite2D.new()
			sh.texture = Scenery._blob_texture()
			sh.scale = Vector2(h * 1.4 / 64.0, h * 0.3 / 64.0)
			sh.modulate = Color(0, 0, 0, 0.5)
			holder.add_child(sh)
			var s := PaintedLibrary.sprite(3, h)
			s.material = mat
			s.position.y = 2.0
			s.modulate = Color(1, 1, 1).darkened(t * 0.45)
			if r.randf() < 0.5:
				s.scale.x = -s.scale.x
			holder.add_child(s)
			holder.position = Vector2(x, y)
			add_child(holder)
			_items.append({"node": holder, "x": x, "y": y})
			x += r.randf_range(170.0, 360.0) if not boss else r.randf_range(260.0, 480.0)

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		if cam == null:
			return
		var cx := cam.get_screen_center_position().x
		for it in _items:
			var s := maxf(0.55, 1.0 + (float(it.y) - _feet) / BAND * PERSP)
			var n: Node2D = it.node
			n.position.x = cx + (float(it.x) - cx) * s
			n.scale = Vector2.ONE * s


class FloorBand extends Node2D:
	## Faixa do chão que segue a câmera em x; o shader faz o resto (sem atraso).
	var _mat: ShaderMaterial

	func setup(e: int, feet_y: float) -> void:
		var d := SceneryLibrary.data(e)
		var lk := SceneryLibrary.look(e)
		_mat = SceneryLibrary.material("floor")
		var tex := SceneryLibrary.layer(e, "floor")
		var h := {} if Scenery.hd_disabled else SceneryLibrary.hd(e)
		if h.has("floor"):
			# chão HD (Cenário 7): a parte de baixo das asas novas, luz achatada
			var fl: Dictionary = h.floor
			_mat.set_shader_parameter("floor_tex", SceneryLibrary.hd_texture(e, String(fl.tex)))
			_mat.set_shader_parameter("tile_w", float(fl.w) * float(h.s))
			_mat.set_shader_parameter("haze", d.haze)
		elif tex != null and not d.is_empty():
			var sz: Vector2 = d.size
			_mat.set_shader_parameter("floor_tex", tex)
			_mat.set_shader_parameter("tile_w", sz.x * Scenery.PAINT_H / sz.y)
			_mat.set_shader_parameter("haze", d.haze)
		else:
			_mat.set_shader_parameter("has_tex", 0.0)
		_mat.set_shader_parameter("floor_y", Scenery.FLOOR_Y)
		_mat.set_shader_parameter("feet_y", feet_y)
		_mat.set_shader_parameter("band_h", 136.0)
		_mat.set_shader_parameter("reflect_amt", lk.reflect)
		_mat.set_shader_parameter("glow", lk.glow)
		_mat.set_shader_parameter("crack_amt", float(lk.get("crack", 1.1)))
		material = _mat

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		if cam == null:
			return
		position.x = roundf(cam.get_screen_center_position().x)
		_mat.set_shader_parameter("node_x", position.x)

	func _draw() -> void:
		# um retângulo largo (folga p/ tremida e atraso da câmera)
		draw_rect(Rect2(-520.0, Scenery.FLOOR_Y - 4.0, 1040.0, 340.0), Color.WHITE)

	func _ready() -> void:
		queue_redraw()


class GroundFog extends Node2D:
	## Névoa rasteira: faixa fina sobre a linha dos pés, que segue a câmera.
	var _mat: ShaderMaterial
	var _feet: float = 310.0

	func setup(col: Color, dens: float, feet_y: float) -> void:
		_feet = feet_y
		_mat = SceneryLibrary.material("fog")
		_mat.set_shader_parameter("col", col)
		_mat.set_shader_parameter("density", dens)
		_mat.set_shader_parameter("y_top", feet_y - 26.0)
		_mat.set_shader_parameter("y_peak", feet_y - 4.0)
		_mat.set_shader_parameter("y_bot", feet_y + 16.0)
		_mat.set_shader_parameter("scale", 0.012)
		_mat.set_shader_parameter("speed", 10.0)
		_mat.set_shader_parameter("seed", 5.0)
		material = _mat

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		if cam == null:
			return
		position.x = roundf(cam.get_screen_center_position().x)
		_mat.set_shader_parameter("offset", position.x)

	func _draw() -> void:
		draw_rect(Rect2(-520.0, _feet - 26.0, 1040.0, 42.0), Color.WHITE)

	func _ready() -> void:
		queue_redraw()


## ARENA DE CHEFE: cenografia simétrica em volta do centro da arena —
## obeliscos nas bordas e braseiros acesos na cor do Éon, com luz no chão.
func _build_boss_arena(parent: Node2D, feet_y: float) -> void:
	var c := Level.ZONE_FIRST_X
	var set_node := ArenaSet.new()
	set_node.name = "ArenaSet"
	set_node.z_index = -1
	parent.add_child(set_node)
	var mat := SceneryLibrary.prop_material(eon, 0.06, 0.12, 0.7)
	var base_y := feet_y - 7.0
	var g: Color = look().glow
	for side in [-1.0, 1.0]:
		# obelisco (com o cristal) nas bordas
		# (na borda da arena, junto do véu da parede: emoldura a luta em vez de
		# ficar atrás do chefe; com a câmera ainda fora do centro, só acende
		# quando a zona tranca — ver ArenaSet)
		var ox: float = c + side * 418.0
		_contact_shadow(set_node, Vector2(ox, base_y), 30.0, 0.6)
		var ob := PaintedLibrary.sprite(2, 168.0)
		ob.material = mat
		ob.position = Vector2(ox, base_y + 2.0)
		if side > 0.0:
			ob.scale.x = -ob.scale.x
		set_node.add_child(ob)
		# braseiro aceso mais pra dentro
		var bx: float = c + side * 352.0
		_contact_shadow(set_node, Vector2(bx, base_y + 1.0), 22.0, 0.6)
		var br := PaintedLibrary.sprite(4, 46.0)
		br.material = mat
		br.position = Vector2(bx, base_y + 2.0)
		set_node.add_child(br)
		_flame_light(set_node, Vector2(bx, base_y - 40.0), 1.0)
		# poça de luz no chão debaixo do braseiro
		var pool := Sprite2D.new()
		pool.texture = _blob_texture()
		pool.material = VfxLibrary._additive()
		pool.position = Vector2(bx, base_y + 6.0)
		pool.scale = Vector2(1.6, 0.35)
		pool.modulate = Color(g.r, g.g, g.b, 0.22)
		set_node.add_child(pool)


class ArenaSet extends Node2D:
	## Cenografia da arena do chefe que ACENDE quando a zona tranca (sobe da
	## névoa em ~0,9 s): no começo da tela a câmera ainda não está centrada na
	## arena e o obelisco apareceria no meio do quadro. Sem zona (ou se ela
	## demorar), aparece sozinha depois de FALLBACK s.
	const FALLBACK := 6.0
	var _t: float = 0.0
	var _on: bool = false

	func _ready() -> void:
		modulate.a = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if not _on:
			var lv := get_parent()
			if (lv != null and bool(lv.get("zone_active"))) or _t >= FALLBACK:
				_on = true
		if _on:
			modulate.a = move_toward(modulate.a, 1.0, delta / 0.9)
			if modulate.a >= 1.0:
				set_process(false)


## PLATAFORMAS integradas (chamado no fim do quadro, depois que o Level as
## criou): penumbra macia embaixo, sombra no chão, borda de cima acesa na cor
## do Éon e poeira caindo. Só visual.
func _integrate_platforms(level: Node) -> void:
	if level == null or not is_instance_valid(level):
		return
	var plat_tex := PaintedLibrary.prop(5)
	var g: Color = look().glow
	var mat := SceneryLibrary.prop_material(eon, 0.0, 0.08, 1.1)
	for body in level.get_children():
		if not body is StaticBody2D:
			continue
		var spr: Sprite2D = null
		for ch in body.get_children():
			if ch is Sprite2D and ch.texture == plat_tex:
				spr = ch
		if spr == null:
			continue
		var w: float = spr.texture.get_width() * absf(spr.scale.x)
		var h_above: float = FEET_Y - body.position.y
		spr.material = mat
		# QA7 #22 (R18): a sombra projetada (silhueta esticada da pedra) e a coluna
		# de luz embaixo eram retângulos translúcidos de borda dura — um "fantasma"
		# da plataforma. Troca: só uma penumbra MACIA logo abaixo da pedra (elipse
		# radial, sem borda) + a sombra no chão. Nada de forma reta no fundo.
		var under := Sprite2D.new()
		under.texture = _blob_texture()
		under.position = spr.position + Vector2(0.0, 12.0)
		under.scale = Vector2(w * 1.05 / 64.0, 34.0 / 64.0)
		under.modulate = Color(0.0, 0.0, 0.0, 0.34)
		under.z_index = -1
		body.add_child(under)
		body.move_child(under, 0)
		# sombra no chão (mais alta = mais larga e mais fraca)
		var fsh := _contact_shadow(body, Vector2(0.0, h_above + 1.0), w * 0.42 * (1.0 + h_above / 260.0), clampf(0.5 - h_above / 300.0, 0.18, 0.45))
		fsh.z_index = -1
		# halo da borda de cima
		var rim := Polygon2D.new()
		rim.polygon = PackedVector2Array([Vector2(-w * 0.48, -7), Vector2(w * 0.48, -7), Vector2(w * 0.48, -1), Vector2(-w * 0.48, -1)])
		rim.vertex_colors = PackedColorArray([Color(g.r, g.g, g.b, 0.0), Color(g.r, g.g, g.b, 0.0), Color(g.r, g.g, g.b, 0.22), Color(g.r, g.g, g.b, 0.22)])
		rim.material = VfxLibrary._additive()
		body.add_child(rim)
		# poeira caindo da pedra
		var dust := CPUParticles2D.new()
		dust.position = Vector2(0, 14)
		dust.texture = VfxLibrary.tex("circle")
		dust.amount = 5
		dust.lifetime = 2.6
		dust.preprocess = 3.0
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		dust.emission_rect_extents = Vector2(w * 0.38, 2)
		dust.direction = Vector2(0, 1)
		dust.spread = 10.0
		dust.initial_velocity_min = 4.0
		dust.initial_velocity_max = 10.0
		dust.gravity = Vector2(0, 14)
		dust.scale_amount_min = 0.006
		dust.scale_amount_max = 0.014
		var dc := haze().lightened(0.2)
		dust.color = Color(dc.r, dc.g, dc.b, 0.5)
		dust.z_index = -1
		body.add_child(dust)
		dust.emitting = true


# --- primeiro plano (parallax > 1, por código; filho do Level) -------------------

func build_foreground(parent: Node2D) -> void:
	var f := Foreground.new()
	f.eon = eon
	f.rng = _rng(6)
	f.tint = haze().darkened(0.9)
	f.boss = is_boss()
	f.screen = seed_screen
	f.name = "Foreground"
	if "rest_points" in parent:
		f.anchors = parent.rest_points.duplicate()
	f.z_index = 30
	parent.add_child(f)


class Foreground extends Node2D:
	## Silhuetas escuras e desfocadas passando NA FRENTE da câmera (parallax 1,35):
	## entulho embaixo, colunas finas da própria pintura perto dos descansos e
	## bokeh de partículas — a profundidade de primeiro plano.
	##
	## REGRA DO PRIMEIRO PLANO (Onda 5, QA2 #3): uma coluna NUNCA tapa um NPC,
	## Estela, Selo, baú, Adormecido ou a fenda. Como ela anda só 0,35× mais rápido
	## que o mundo, uma coluna "ancorada" perto de um NPC fica em cima dele por
	## ~600 px de câmera — era o Soter da tela 17. Por isso:
	##  1) a coluna é FINA (COL_W px na tela) e o entulho de baixo é baixo: o
	##     primeiro plano cobre ≤ 10% do quadro em qualquer câmera
	##     (medido por `tools/scenery/FgAudit.tscn`, que usa `audit_at`);
	##  2) a posição é escolhida DEPOIS que o Level pôs os extras (fim do quadro):
	##     longe o bastante de todo ponto protegido para nunca cruzá-lo enquanto
	##     ele estiver no quadro (conta em `_min_gap`), e fora do quadro enquanto
	##     uma zona está trancada (a luta não fica atrás de pilar). Sem lugar
	##     seguro, o descanso fica sem coluna;
	##  3) rede de segurança: se mesmo assim uma coluna passar sobre um ponto
	##     protegido, ela some; sobre a Sophia, fica translúcida.
	var eon: int = 0
	var screen: int = 1
	var rng: RandomNumberGenerator
	var tint: Color = Color(0.02, 0.02, 0.03)
	var boss: bool = false
	var anchors: Array = []
	var _bokeh: CPUParticles2D
	var _dust: CPUParticles2D
	var _cols: Array = []            # [{node: Sprite2D, x: float (âncora de mundo)}]
	var _guards: Array = []          # nós protegidos vivos (NPC, Estela, Selos...)
	var _guard_scan: float = 0.0
	var _col_rng_seed: int = 0
	const SPEED := 1.35      # > 1 = passa mais rápido que o mundo (está à frente)
	const SPAN := 6800.0     # até onde vai o entulho (cobre a travessia de 3 zonas)
	const COL_W := 52.0      # largura da fatia da coluna na tela (px) — ~6% do quadro coberto
	const COL_H := 460.0     # altura da coluna (passa do quadro em cima e embaixo)
	const COL_ALPHA := 0.97
	const GUARD := 80.0      # faixa livre ao redor de um ponto protegido (px de mundo)
	const VIEW_HALF := 320.0
	const RUBBLE_H := Vector2(64.0, 92.0)   # altura do entulho de baixo (era 90–140)

	func _process(delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		if cam == null:
			return
		var c := cam.get_screen_center_position()
		position.x = c.x * (1.0 - SPEED)
		if _bokeh != null:
			_bokeh.position = Vector2(c.x * SPEED, c.y)
		if _dust != null:
			_dust.position = Vector2(c.x * SPEED, c.y + 140.0)
		if not _cols.is_empty():
			_fade_columns(c.x, delta)

	## Centro (x de mundo, na tela) de uma coluna ancorada em `ax` com a câmera em `cx`.
	static func col_world_x(ax: float, cx: float) -> float:
		return cx + SPEED * (ax - cx)

	## Distância mínima (px de mundo) entre a âncora de uma coluna e um ponto
	## protegido de meia-largura `hw` para que ela nunca o cubra enquanto ele
	## estiver no quadro. Distância na tela entre coluna e ponto =
	## SPEED·D + (SPEED−1)·s, com s = posição do ponto na tela (|s| ≤ VIEW_HALF+hw).
	static func _min_gap(hw: float) -> float:
		return (COL_W * 0.5 + hw + (SPEED - 1.0) * (VIEW_HALF + hw)) / SPEED

	## Pontos protegidos [x, meia-largura] lidos do Level (sem mexer nele): os
	## nós de NPC/Estela/Selos/baú/Adormecido/fenda que já existem, a Estela que o
	## Gnosis vai pôr depois das falas de chegada e o lugar da fenda.
	##
	## CONTRATO COM O LEVEL DESIGN (level6 e quem vier): além das classes acima,
	##  · qualquer Node2D no grupo `fg_guard` é protegido (meia-largura em
	##    `get_meta("fg_half")`, padrão GUARD = 80 px) — p.ex. segredo, alavanca,
	##    plataforma alta com item, perigo que precisa ser lido;
	##  · a variável `fg_forbidden: Array` no Level (se existir), com Vector2(x0, x1)
	##    em x de mundo = faixas inteiras onde coluna de primeiro plano não pode
	##    cobrir nada (p.ex. um trecho vertical de plataformas).
	## Os dois são lidos no fim do quadro em que o Level termina o `_ready` síncrono
	## (o layout tem de estar montado até lá) e de novo a cada 0,5 s pela rede de
	## segurança (o que nascer depois só faz a coluna sumir, não a move).
	func _protected_points() -> Array:
		var pts: Array = []
		var lv := get_parent()
		if lv == null:
			return pts
		for g in _guard_nodes(lv):
			pts.append(Vector2((g[0] as Node2D).global_position.x, float(g[1])))
		var bands = lv.get("fg_forbidden")
		if bands is Array:
			for b in bands:
				if b is Vector2:
					var bv: Vector2 = b
					pts.append(Vector2((bv.x + bv.y) * 0.5, absf(bv.y - bv.x) * 0.5))
		if RunManager.run_active and not anchors.is_empty() and Gnosis.has_method("stela_for_screen") \
				and Gnosis.has_method("_stela_pos") and not (Gnosis.stela_for_screen(screen) as Dictionary).is_empty():
			var sp: Vector2 = Gnosis.call("_stela_pos", screen, anchors)
			pts.append(Vector2(sp.x, GUARD))
		var ex = lv.get("_end_x")
		if ex != null:
			pts.append(Vector2(float(ex) - 200.0, GUARD + 20.0))   # a fenda de saída
		return pts

	## Meia-largura protegida de um nó do Level (0 = não protegido).
	static func _guard_half(n: Node) -> float:
		if not (n is Node2D):
			return 0.0
		if n.is_in_group("fg_guard"):
			return float(n.get_meta("fg_half", GUARD))
		if n is SealPuzzle:
			return GUARD + 105.0          # três pilares em −90/0/+90
		if n is NpcEncounter or n is Stela or n is Chest or n is Sleeper or n is ExitPortal:
			return GUARD
		return 0.0

	## [nó, meia-largura] de tudo que é protegido: filhos diretos do Level das
	## classes conhecidas + qualquer nó do grupo `fg_guard` (em qualquer lugar).
	func _guard_nodes(lv: Node) -> Array:
		var out: Array = []
		var seen: Dictionary = {}
		for n in lv.get_children():
			var hw := _guard_half(n)
			if hw > 0.0:
				out.append([n, hw])
				seen[n] = true
		if is_inside_tree():
			for n in get_tree().get_nodes_in_group("fg_guard"):
				if not seen.has(n) and _guard_half(n) > 0.0:
					out.append([n, _guard_half(n)])
		return out

	## Escolhe as âncoras das colunas (no fim do quadro: o Level já pôs os extras).
	func _place_columns() -> void:
		var colt := SceneryLibrary.layer(eon, "fgcol")
		if colt == null or boss or not is_inside_tree():
			return
		var crng := RandomNumberGenerator.new()
		crng.seed = _col_rng_seed
		var pts := _protected_points()
		# Zonas de luta: com a zona trancada a câmera anda em c ± (ZONE_HALF − VIEW_HALF);
		# a coluna precisa ficar fora do quadro nesse trecho todo.
		var lock_free: float = (Level.ZONE_HALF - VIEW_HALF + 10.0) + (VIEW_HALF + COL_W * 0.5) / SPEED
		var zone_c: Array = []
		for z in anchors.size():
			zone_c.append(Level.ZONE_FIRST_X + float(z) * Level.ZONE_STEP)
		for i in range(1, anchors.size()):
			var r: float = Vector2(anchors[i]).x
			var pref: float = r + crng.randf_range(-60.0, 60.0)
			var best: float = INF
			var best_score: float = -INF
			var x: float = r - 420.0
			while x <= r + 420.0:
				var ok := true
				for c in zone_c:
					if absf(x - float(c)) < lock_free:
						ok = false
						break
				var clear: float = INF
				if ok:
					for p in pts:
						var gap: float = absf(x - p.x) - _min_gap(p.y)
						clear = minf(clear, gap)
						if gap < 0.0:
							ok = false
							break
				if ok:
					# perto do descanso (o desenho original) e com folga dos pontos
					var score: float = minf(clear, 120.0) - absf(x - pref) * 0.25
					if score > best_score:
						best_score = score
						best = x
				x += 4.0
			if best != INF:
				_add_column(colt, best, crng.randf() < 0.5)

	## Só para a auditoria medir o ANTES: a colunona inteira em cada descanso
	## (como era até a Onda 4). O jogo nunca liga isto.
	static var legacy: bool = false

	func _legacy_columns() -> void:
		var colt := SceneryLibrary.layer(eon, "fgcol")
		if colt == null or boss:
			return
		var crng := RandomNumberGenerator.new()
		crng.seed = _col_rng_seed
		for i in range(1, anchors.size()):
			var ax: float = Vector2(anchors[i]).x + crng.randf_range(-60.0, 60.0)
			var cs := Sprite2D.new()
			cs.texture = colt
			cs.centered = false
			var sc := COL_H / colt.get_height()
			cs.scale = Vector2(sc, sc)
			cs.position = Vector2(ax * SPEED - colt.get_width() * sc * 0.5, -60.0)
			cs.modulate = Color(1, 1, 1, COL_ALPHA)
			cs.set_meta("col", true)
			add_child(cs)

	func _add_column(colt: Texture2D, ax: float, flip: bool) -> void:
		var cs := Sprite2D.new()
		cs.texture = colt
		cs.centered = false
		var sc := COL_H / colt.get_height()
		cs.scale = Vector2(sc, sc)
		# uma fatia de COL_W px da asa: a mais perto da borda de dentro (o perfil
		# recortado) que ainda seja ≥ 72% opaca — senão vira só a "baía" vazia
		var cw: float = minf(COL_W / sc, colt.get_width())
		cs.region_enabled = true
		cs.region_rect = Rect2(_crop_x(colt, cw), 0.0, cw, colt.get_height())
		cs.flip_h = flip
		cs.position = Vector2(ax * SPEED - cw * sc * 0.5, -60.0)
		cs.modulate = Color(1, 1, 1, COL_ALPHA)
		cs.name = "FgColumn%d" % _cols.size()
		cs.set_meta("col", true)
		add_child(cs)
		_cols.append({"node": cs, "x": ax})

	static var _crops: Dictionary = {}

	## x do recorte (px da textura) para uma fatia de largura `cw`: da borda de
	## dentro para fora, a primeira com ≥ 72% dos pixels opacos (amostra 1:4).
	static func _crop_x(t: Texture2D, cw: float) -> float:
		var key := "%s:%d" % [t.resource_path, int(cw)]
		if _crops.has(key):
			return _crops[key]
		var w := t.get_width()
		var x0: float = float(w) - cw
		var img := _alpha_image(t)
		if img != null:
			var h := img.get_height()
			var icw := int(cw)
			var x := w - icw
			while x >= 0:
				var tot := 0
				var op := 0
				for yy in range(0, h, 4):
					for xx in range(x, x + icw, 4):
						tot += 1
						if img.get_pixel(xx, yy).a > 0.5:
							op += 1
				if tot > 0 and float(op) / float(tot) >= 0.72:
					x0 = float(x)
					break
				x -= 4
		_crops[key] = x0
		return x0

	## Rede de segurança: coluna sobre ponto protegido some; sobre a Sophia, translúcida.
	func _fade_columns(cx: float, delta: float) -> void:
		_guard_scan -= delta
		if _guard_scan <= 0.0:
			_guard_scan = 0.5
			_guards.clear()
			var lv := get_parent()
			if lv != null:
				_guards = _guard_nodes(lv)
		var lv2 := get_parent()
		var pl: Node2D = lv2.get("player") if lv2 != null and "player" in lv2 else null
		for cd in _cols:
			var gx := col_world_x(float(cd.x), cx)
			var want := COL_ALPHA
			if pl != null and is_instance_valid(pl) and absf(pl.global_position.x - gx) < COL_W * 0.5 + 26.0:
				want = 0.45
			for g in _guards:
				# corpo do ponto (a meia-largura sem a folga GUARD) + 34 px
				var body: float = maxf(34.0, float(g[1]) - GUARD + 34.0)
				if is_instance_valid(g[0]) and absf((g[0] as Node2D).global_position.x - gx) < COL_W * 0.5 + body:
					want = 0.0
			var n: Sprite2D = cd.node
			n.modulate.a = move_toward(n.modulate.a, want, delta * 3.0)

	## AUDITORIA (ferramenta): põe o primeiro plano como estaria com a câmera em
	## (cx, cy) e mede no quadro 640×360 (grade de 4 px) a fração coberta por
	## silhueta (alfa ≥ 0,5, sem o fade de segurança) e a fração de cada faixa
	## protegida coberta por coluna. Retorna {cover, hits: [[x, frac]]}.
	func audit_at(cx: float, cy: float, prot: Array) -> Dictionary:
		position.x = cx * (1.0 - SPEED)
		var gw := 160
		var gh := 90
		var mask := PackedByteArray()
		mask.resize(gw * gh)
		var colmask := PackedByteArray()
		colmask.resize(gw * gh)
		var x0 := cx - VIEW_HALF
		var y0 := cy - 180.0
		for ch in get_children():
			if not (ch is Sprite2D):
				continue
			var s: Sprite2D = ch
			var img := _alpha_image(s.texture)
			if img == null:
				continue
			var is_col := s.has_meta("col")
			var reg := s.region_rect if s.region_enabled else Rect2(Vector2.ZERO, Vector2(img.get_size()))
			var xf := s.get_global_transform()
			var inv := xf.affine_inverse()
			# só as células da grade dentro da caixa do sprite (rápido: quase todo
			# entulho está fora do quadro)
			var lr := Rect2(s.offset - (reg.size * 0.5 if s.centered else Vector2.ZERO), reg.size)
			var wr := xf * lr
			var gx0 := maxi(0, int(floor((wr.position.x - x0) / 4.0)))
			var gx1 := mini(gw, int(ceil((wr.end.x - x0) / 4.0)))
			var gy0 := maxi(0, int(floor((wr.position.y - y0) / 4.0)))
			var gy1 := mini(gh, int(ceil((wr.end.y - y0) / 4.0)))
			for gy in range(gy0, gy1):
				for gx in range(gx0, gx1):
					var wp := Vector2(x0 + gx * 4.0 + 2.0, y0 + gy * 4.0 + 2.0)
					var lp := inv * wp
					# local → pixel da textura (centered/offset/flip)
					var pxl := lp - s.offset
					if s.centered:
						pxl += reg.size * 0.5
					if pxl.x < 0.0 or pxl.y < 0.0 or pxl.x >= reg.size.x or pxl.y >= reg.size.y:
						continue
					if s.flip_h:
						pxl.x = reg.size.x - 1.0 - pxl.x
					var tp := reg.position + pxl
					var a := img.get_pixel(int(tp.x), int(tp.y)).a * (COL_ALPHA if is_col else s.modulate.a)
					if a >= 0.5:
						mask[gy * gw + gx] = 1
						if is_col:
							colmask[gy * gw + gx] = 1
		var covered := 0
		for v in mask:
			covered += v
		var hits: Array = []
		for p in prot:
			# faixa do ponto: x ± meia-largura (sem a folga), dos pés até 90 px acima
			var hw: float = maxf(20.0, float(p.y) - GUARD + 30.0)
			var fx0 := int(floor((p.x - hw - x0) / 4.0))
			var fx1 := int(ceil((p.x + hw - x0) / 4.0))
			var fy0 := int(floor((Level.GROUND_Y - 90.0 - y0) / 4.0))
			var fy1 := int(ceil((Level.GROUND_Y - y0) / 4.0))
			var tot := 0
			var hit := 0
			for gy in range(maxi(0, fy0), mini(gh, fy1)):
				for gx in range(maxi(0, fx0), mini(gw, fx1)):
					tot += 1
					hit += colmask[gy * gw + gx]
			if tot > 0 and hit > 0:
				hits.append([p.x, float(hit) / float(tot)])
		var colcov := 0
		for v in colmask:
			colcov += v
		return {"cover": float(covered) / float(gw * gh), "col": float(colcov) / float(gw * gh), "hits": hits}

	static var _imgs: Dictionary = {}

	static func _alpha_image(t: Texture2D) -> Image:
		if t == null:
			return null
		var key := t.resource_path
		if _imgs.has(key):
			return _imgs[key]
		var img: Image = null
		# no projeto o PNG está no disco (rápido e funciona headless); exportado só
		# existe o .ctex importado → lê da própria textura
		if key != "" and FileAccess.file_exists(key):
			img = Image.load_from_file(ProjectSettings.globalize_path(key))
		if img == null:
			img = t.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_imgs[key] = img
		return img

	func _ready() -> void:
		if rng == null:
			rng = RandomNumberGenerator.new()
		var rubble := SceneryLibrary.texture("fg_rubble")
		var col := Color(tint.r, tint.g, tint.b, 0.96)
		# entulho desfocado na base da tela
		if rubble != null:
			var x: float = -300.0 + rng.randf_range(0.0, 400.0)
			while x < SPAN * SPEED:
				var sp := Sprite2D.new()
				sp.texture = rubble
				var hgt := rng.randf_range(90.0, 140.0) if legacy else rng.randf_range(RUBBLE_H.x, RUBBLE_H.y)
				sp.scale = Vector2.ONE * hgt / rubble.get_height()
				sp.offset.y = -rubble.get_height() * 0.5
				sp.position = Vector2(x, 452.0 + rng.randf_range(0.0, 18.0))
				sp.modulate = col
				sp.flip_h = rng.randf() < 0.5
				add_child(sp)
				x += rng.randf_range(560.0, 980.0)
		# colunas da pintura (asa escurecida): escolhidas no fim do quadro, quando
		# o Level já pôs NPC/baú/Selos (ver REGRA DO PRIMEIRO PLANO acima)
		_col_rng_seed = rng.randi()
		if legacy:
			_legacy_columns()
		else:
			_place_columns.call_deferred()
		# bokeh: poucos pontos grandes e desfocados flutuando na frente da câmera
		var lk := SceneryLibrary.look(eon)
		var g: Color = lk.glow
		_bokeh = CPUParticles2D.new()
		_bokeh.texture = VfxLibrary.tex("light")
		_bokeh.material = VfxLibrary._additive()
		_bokeh.amount = 7
		_bokeh.lifetime = 9.0
		_bokeh.preprocess = 9.0
		_bokeh.local_coords = true
		_bokeh.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_bokeh.emission_rect_extents = Vector2(340, 190)
		_bokeh.direction = Vector2(1, -0.3)
		_bokeh.spread = 60.0
		_bokeh.initial_velocity_min = 3.0
		_bokeh.initial_velocity_max = 9.0
		_bokeh.gravity = Vector2.ZERO
		_bokeh.scale_amount_min = 0.12
		_bokeh.scale_amount_max = 0.30
		var ramp := Gradient.new()
		ramp.set_color(0, Color(g.r, g.g, g.b, 0.0))
		ramp.set_color(1, Color(g.r, g.g, g.b, 0.0))
		ramp.add_point(0.5, Color(g.r, g.g, g.b, 0.10))
		if lk.get("ray_dark", false):
			# na Mente o "bokeh" é sombra (vazio), não luz
			_bokeh.material = null
			ramp = Gradient.new()
			ramp.set_color(0, Color(0.05, 0.0, 0.03, 0.0))
			ramp.set_color(1, Color(0.05, 0.0, 0.03, 0.0))
			ramp.add_point(0.5, Color(0.05, 0.0, 0.03, 0.35))
		_bokeh.color_ramp = ramp
		add_child(_bokeh)
		_bokeh.emitting = true
		# poeira PERTO (faixa de baixo, P2/VFX 4): grãos maiores e lentos passando
		# rente ao chão na frente da câmera — vida sem cruzar a faixa de luta.
		_dust = CPUParticles2D.new()
		_dust.texture = VfxLibrary.tex("light")
		_dust.local_coords = true
		_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_dust.emission_rect_extents = Vector2(360, 26)
		_dust.amount = 9
		_dust.lifetime = 8.0
		_dust.preprocess = 8.0
		_dust.direction = Vector2(1, -0.1)
		_dust.spread = 25.0
		_dust.gravity = Vector2.ZERO
		_dust.initial_velocity_min = 5.0
		_dust.initial_velocity_max = 12.0
		_dust.scale_amount_min = 0.03
		_dust.scale_amount_max = 0.07
		var dc: Color = Color(g).lerp(Color(0.8, 0.8, 0.85), 0.5)
		var dr := Gradient.new()
		dr.set_color(0, Color(dc, 0.0))
		dr.set_color(1, Color(dc, 0.0))
		dr.add_point(0.5, Color(dc, 0.16))
		if lk.get("ray_dark", false):
			dr = Gradient.new()
			dr.set_color(0, Color(0.06, 0.0, 0.04, 0.0))
			dr.set_color(1, Color(0.06, 0.0, 0.04, 0.0))
			dr.add_point(0.5, Color(0.06, 0.0, 0.04, 0.3))
		else:
			_dust.material = VfxLibrary._additive()
		_dust.color_ramp = dr
		add_child(_dust)
		_dust.emitting = true


# --- vinheta (CanvasLayer abaixo do HUD) ------------------------------------------

func build_vignette(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	var tr := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.55))
	grad.add_point(0.55, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.05)
	tex.width = 256
	tex.height = 144
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate = Color(1, 1, 1, 0.9)
	layer.add_child(tr)
	parent.add_child(layer)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
