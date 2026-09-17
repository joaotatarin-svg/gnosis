extends ParallaxBackground
class_name Scenery
## CENÁRIO PROCEDURAL POR ÉON (v2). Monta em runtime as camadas de parallax:
##   Sky (fixo: gradiente + astro do Éon + estrelas) · Far (skyline) · Mid (props
##   grandes) · Near (props pequenos/entulho) · Fog (névoa animada) — e ainda
##   oferece `build_ground(parent)` (relevo do chão em coords de mundo),
##   `build_foreground(parent)` (silhuetas à frente, parallax > 1 por código) e
##   `build_vignette(parent)` (vinheta em CanvasLayer).
## Se existir `assets/backgrounds/eon_<i>.png`, usa a arte do usuário no lugar.
## Tudo determinístico: a mesma tela sempre gera o mesmo cenário.

const W := 1800.0          # largura do padrão repetido (mirroring)
const GROUND := 316.0      # linha do chão nas camadas (bate com o Level)

## Paleta por Éon: 0..6 = Torpor..Coroa · 7 = Centro · 8 = Mente (final).
const PAL := [
	{"sky_top": Color("08131d"), "sky_bot": Color("27464e"), "far": Color("152e3a"), "mid": Color("102631"), "near": Color("0a1c25"), "fog": Color("6babad"), "ground": Color("233b40"), "ground_dark": Color("08151c"), "glow": Color("98cece")},
	{"sky_top": Color(0.12, 0.04, 0.05), "sky_bot": Color(0.45, 0.16, 0.12), "far": Color(0.22, 0.09, 0.09), "mid": Color(0.16, 0.07, 0.07), "near": Color(0.10, 0.04, 0.05), "fog": Color(0.7, 0.35, 0.25), "ground": Color(0.28, 0.16, 0.14), "ground_dark": Color(0.10, 0.05, 0.05), "glow": Color(1.0, 0.55, 0.3)},
	{"sky_top": Color(0.05, 0.07, 0.12), "sky_bot": Color(0.28, 0.32, 0.42), "far": Color(0.13, 0.15, 0.22), "mid": Color(0.10, 0.12, 0.18), "near": Color(0.06, 0.07, 0.11), "fog": Color(0.5, 0.55, 0.65), "ground": Color(0.20, 0.22, 0.28), "ground_dark": Color(0.07, 0.08, 0.11), "glow": Color(0.85, 0.85, 0.95)},
	{"sky_top": Color(0.03, 0.02, 0.07), "sky_bot": Color(0.14, 0.10, 0.26), "far": Color(0.09, 0.07, 0.17), "mid": Color(0.07, 0.05, 0.13), "near": Color(0.04, 0.03, 0.08), "fog": Color(0.45, 0.4, 0.65), "ground": Color(0.16, 0.13, 0.24), "ground_dark": Color(0.05, 0.04, 0.09), "glow": Color(0.7, 0.75, 1.0)},
	{"sky_top": Color(0.16, 0.17, 0.24), "sky_bot": Color(0.55, 0.58, 0.72), "far": Color(0.32, 0.34, 0.46), "mid": Color(0.24, 0.26, 0.38), "near": Color(0.14, 0.15, 0.24), "fog": Color(0.8, 0.85, 1.0), "ground": Color(0.36, 0.38, 0.5), "ground_dark": Color(0.12, 0.13, 0.2), "glow": Color(0.95, 0.97, 1.0)},
	{"sky_top": Color(0.05, 0.09, 0.06), "sky_bot": Color(0.22, 0.34, 0.20), "far": Color(0.11, 0.18, 0.11), "mid": Color(0.08, 0.13, 0.08), "near": Color(0.04, 0.08, 0.05), "fog": Color(0.45, 0.65, 0.35), "ground": Color(0.17, 0.24, 0.15), "ground_dark": Color(0.05, 0.08, 0.05), "glow": Color(0.7, 1.0, 0.5)},
	{"sky_top": Color(0.08, 0.05, 0.03), "sky_bot": Color(0.42, 0.28, 0.10), "far": Color(0.24, 0.16, 0.06), "mid": Color(0.17, 0.11, 0.04), "near": Color(0.10, 0.07, 0.03), "fog": Color(0.85, 0.65, 0.3), "ground": Color(0.30, 0.22, 0.10), "ground_dark": Color(0.10, 0.07, 0.03), "glow": Color(1.0, 0.85, 0.4)},
	{"sky_top": Color(0.02, 0.02, 0.04), "sky_bot": Color(0.12, 0.10, 0.16), "far": Color(0.10, 0.08, 0.14), "mid": Color(0.08, 0.06, 0.11), "near": Color(0.05, 0.04, 0.07), "fog": Color(0.5, 0.45, 0.6), "ground": Color(0.15, 0.13, 0.19), "ground_dark": Color(0.04, 0.03, 0.06), "glow": Color(1.0, 0.8, 0.45)},
	{"sky_top": Color(0.02, 0.01, 0.03), "sky_bot": Color(0.20, 0.06, 0.14), "far": Color(0.12, 0.05, 0.10), "mid": Color(0.09, 0.04, 0.08), "near": Color(0.05, 0.02, 0.05), "fog": Color(0.7, 0.3, 0.5), "ground": Color(0.18, 0.08, 0.14), "ground_dark": Color(0.05, 0.02, 0.04), "glow": Color(1.0, 0.6, 0.7)},
]

var eon: int = 0
var seed_screen: int = 1
var _built: bool = false
var _fog_nodes: Array = []
var _t: float = 0.0


func _ready() -> void:
	if not _built:
		var e := 0
		var sc := 1
		if RunManager.run_active:
			sc = RunManager.current_screen
			e = RunManager.eon_index(sc)
		build(e, sc)


func pal() -> Dictionary:
	return PAL[clampi(eon, 0, PAL.size() - 1)]


## Monta (ou remonta) o cenário do Éon. Retorna true se usou PNG do usuário.
func build(p_eon: int, screen: int = 1) -> bool:
	eon = p_eon
	seed_screen = screen
	_built = true
	for c in get_children():
		c.queue_free()
	_fog_nodes.clear()
	var png := "res://assets/backgrounds/eon_%d.png" % eon
	if ResourceLoader.exists(png):
		var tex = load(png)
		var layer := _layer(Vector2.ZERO, 0.0)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.scale = Vector2((640.0 / 0.75) / float(tex.get_width()), (360.0 / 0.75) / float(tex.get_height()))
		layer.add_child(spr)
		return true
	_build_sky()
	var painted_layer := _layer(Vector2(0.18,1.0),768.0)
	for i in 1:
		var backdrop := Sprite2D.new()
		backdrop.texture = PaintedLibrary.background(clampi(eon,0,8))
		backdrop.centered = false
		backdrop.position = Vector2(i*768,0)
		backdrop.scale = Vector2(768.0/backdrop.texture.get_width(),400.0/backdrop.texture.get_height())
		backdrop.modulate = Color(0.68,0.73,0.77)
		painted_layer.add_child(backdrop)
	_build_architecture()
	_build_fog()
	return false


## Arquitetura pintada (pilares, obeliscos, entulho, braseiros) em duas camadas
## de parallax. Determinística por tela: escolha, posição, altura, espelho e
## tinta saem do rng da tela — duas telas do mesmo Éon nunca ficam iguais.
## Telas de chefe ficam mais vazias (arena limpa pra leitura do combate).
func _build_architecture() -> void:
	var p := pal()
	var boss: bool = RunManager.run_active and RunManager.is_boss_screen(seed_screen)
	var tint_mid: Color = Color(0.40, 0.48, 0.52).lerp(p.fog, 0.30)
	var tint_near: Color = Color(0.30, 0.36, 0.40).lerp(p.fog, 0.22)
	# Camada do meio: pilares (0) e obeliscos (2) grandes.
	var mid := _layer(Vector2(0.64, 1.0), W)
	var r := _rng(3)
	var x := r.randf_range(20.0, 160.0)
	while x < W - 80.0:
		var kind: int = 0 if r.randf() < 0.62 else 2
		var h: float = r.randf_range(190.0, 265.0) if kind == 0 else r.randf_range(150.0, 215.0)
		var s := PaintedLibrary.sprite(kind, h)
		s.position = Vector2(x, GROUND + r.randf_range(0.0, 4.0))
		s.modulate = tint_mid.darkened(r.randf_range(0.0, 0.18))
		if r.randf() < 0.5:
			s.scale.x = -s.scale.x
		mid.add_child(s)
		x += r.randf_range(520.0, 760.0) if boss else r.randf_range(330.0, 560.0)
	# Camada próxima: entulho (3) e braseiros (4) pequenos.
	var near := _layer(Vector2(0.78, 1.0), W)
	var r2 := _rng(4)
	x = r2.randf_range(60.0, 240.0)
	while x < W - 40.0:
		var brazier: bool = r2.randf() < 0.42
		var h2: float = r2.randf_range(38.0, 50.0) if brazier else r2.randf_range(48.0, 88.0)
		var s2 := PaintedLibrary.sprite(4 if brazier else 3, h2)
		s2.position = Vector2(x, GROUND + 2.0)
		if not brazier:
			s2.modulate = tint_near.darkened(r2.randf_range(0.0, 0.2))
			if r2.randf() < 0.5:
				s2.scale.x = -s2.scale.x
		near.add_child(s2)
		x += r2.randf_range(260.0, 520.0)


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


func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	return p


# --- céu ---------------------------------------------------------------------

func _build_sky() -> void:
	var p := pal()
	var l := _layer(Vector2.ZERO, 0.0)
	var sky := Polygon2D.new()
	sky.polygon = PackedVector2Array([Vector2(-400, -400), Vector2(1400, -400), Vector2(1400, 900), Vector2(-400, 900)])
	sky.vertex_colors = PackedColorArray([p.sky_top, p.sky_top, p.sky_bot, p.sky_bot])
	l.add_child(sky)
	# faixa de horizonte (luz difusa perto do chão)
	var hz := Polygon2D.new()
	hz.polygon = PackedVector2Array([Vector2(-400, 150), Vector2(1400, 150), Vector2(1400, 330), Vector2(-400, 330)])
	var g: Color = p.glow
	hz.vertex_colors = PackedColorArray([Color(g.r, g.g, g.b, 0.0), Color(g.r, g.g, g.b, 0.0), Color(g.r, g.g, g.b, 0.10), Color(g.r, g.g, g.b, 0.10)])
	l.add_child(hz)
	# estrelas (Éons escuros)
	if eon in [0, 2, 3, 6, 7, 8]:
		var r := _rng(1)
		for i in 70:
			var s := Polygon2D.new()
			var x := r.randf_range(-100.0, 950.0)
			var y := r.randf_range(-40.0, 200.0)
			var sz := r.randf_range(0.8, 2.2)
			s.polygon = PackedVector2Array([Vector2(x, y - sz), Vector2(x + sz, y), Vector2(x, y + sz), Vector2(x - sz, y)])
			s.color = Color(1, 1, 1, r.randf_range(0.25, 0.7))
			l.add_child(s)
	var body := CelestialBody.new()
	body.eon = eon
	body.glow = p.glow
	body.position = Vector2(640, 80)
	l.add_child(body)


## O astro de cada Éon (desenhado por código).
class CelestialBody extends Node2D:
	var eon: int = 0
	var glow: Color = Color(1, 1, 1)
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var g := glow
		match eon:
			0:  # Torpor: lua pálida enorme, meio coberta (pálpebra)
				draw_circle(Vector2.ZERO, 70.0, Color(g.r, g.g, g.b, 0.08))
				draw_circle(Vector2.ZERO, 46.0, Color(0.82, 0.84, 0.92, 0.9))
				draw_circle(Vector2(-8, -6), 40.0, Color(0.72, 0.75, 0.85, 0.5))
				draw_colored_polygon(_arc_cap(46.0, -0.35), Color(0.12, 0.12, 0.2, 0.95))
			1:  # Fome: sol vermelho inchado, pulsando
				var pulse := 1.0 + sin(_t * 1.2) * 0.03
				draw_circle(Vector2.ZERO, 80.0 * pulse, Color(1.0, 0.3, 0.15, 0.10))
				draw_circle(Vector2.ZERO, 58.0 * pulse, Color(0.85, 0.22, 0.12, 0.95))
				draw_circle(Vector2(0, 10), 40.0 * pulse, Color(1.0, 0.45, 0.2, 0.55))
			2:  # Corrente: sol atrás de grades
				draw_circle(Vector2.ZERO, 62.0, Color(g.r, g.g, g.b, 0.10))
				draw_circle(Vector2.ZERO, 44.0, Color(0.85, 0.82, 0.7, 0.9))
				for k in 5:
					var x := -36.0 + float(k) * 18.0
					draw_line(Vector2(x, -60), Vector2(x, 60), Color(0.08, 0.08, 0.12, 0.95), 6.0)
				draw_line(Vector2(-60, -8), Vector2(60, -8), Color(0.08, 0.08, 0.12, 0.95), 5.0)
			3:  # Silêncio: buraco no céu (vazio) com anel fraco
				draw_circle(Vector2.ZERO, 50.0, Color(0.01, 0.01, 0.03, 1.0))
				draw_arc(Vector2.ZERO, 54.0, 0, TAU, 48, Color(g.r, g.g, g.b, 0.35), 2.0)
				draw_arc(Vector2.ZERO, 70.0, 0, TAU, 48, Color(g.r, g.g, g.b, 0.12), 1.5)
			4:  # Espelho: duas luas gêmeas, uma invertida
				for sx in [-1.0, 1.0]:
					var c := Vector2(70.0 * sx, 0)
					draw_circle(c, 44.0, Color(g.r, g.g, g.b, 0.08))
					draw_circle(c, 30.0, Color(0.92, 0.94, 1.0, 0.9))
					draw_circle(c + Vector2(6 * sx, -5), 24.0, Color(0.78, 0.82, 0.95, 0.6))
				draw_line(Vector2(0, -80), Vector2(0, 80), Color(1, 1, 1, 0.12), 1.5)
			5:  # Praga: sol doente atrás de bruma verde
				draw_circle(Vector2.ZERO, 90.0, Color(0.5, 0.8, 0.3, 0.06))
				draw_circle(Vector2.ZERO, 50.0, Color(0.62, 0.72, 0.35, 0.7))
				draw_circle(Vector2(-6, 4), 36.0, Color(0.45, 0.55, 0.22, 0.6))
			6:  # Coroa: sol negro com coroa de raios
				for k in 16:
					var a := TAU * float(k) / 16.0 + _t * 0.05
					var len := 110.0 if k % 2 == 0 else 80.0
					draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * len, Color(g.r, g.g, g.b, 0.22), 3.0)
				draw_circle(Vector2.ZERO, 66.0, Color(g.r, g.g, g.b, 0.55))
				draw_circle(Vector2.ZERO, 52.0, Color(0.03, 0.02, 0.02, 1.0))
			7:  # Centro: anéis concêntricos girando (a máquina)
				for k in 4:
					var rr := 30.0 + float(k) * 22.0
					draw_arc(Vector2.ZERO, rr, _t * (0.3 + 0.1 * k), _t * (0.3 + 0.1 * k) + 4.8, 40, Color(g.r, g.g, g.b, 0.35 - 0.06 * k), 3.0)
				draw_circle(Vector2.ZERO, 14.0, Color(0.02, 0.02, 0.03))
			_:  # Mente: olho cego enorme
				draw_circle(Vector2.ZERO, 120.0, Color(g.r, g.g, g.b, 0.06))
				draw_colored_polygon(_eye_shape(150.0, 60.0), Color(0.9, 0.85, 0.9, 0.35))
				draw_circle(Vector2.ZERO, 46.0, Color(0.05, 0.02, 0.05, 1.0))
				draw_circle(Vector2.ZERO, 30.0, Color(g.r, g.g, g.b, 0.25))

	func _arc_cap(r: float, cut: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 25:
			var a := PI + PI * float(i) / 24.0
			pts.append(Vector2(cos(a) * r, sin(a) * r * 1.02 + cut * r))
		return pts

	func _eye_shape(w: float, h: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 24:
			var t := float(i) / 24.0
			var x := -w + 2.0 * w * t
			pts.append(Vector2(x, -sin(t * PI) * h))
		for i in 24:
			var t := float(i) / 24.0
			var x := w - 2.0 * w * t
			pts.append(Vector2(x, sin(t * PI) * h))
		return pts


# --- skyline longe ---------------------------------------------------------------

func _build_far() -> void:
	var p := pal()
	var l := _layer(Vector2(0.15, 1.0), W)
	var r := _rng(2)
	var col: Color = p.far
	var base := GROUND + 30.0
	var x := 0.0
	while x < W:
		var w := r.randf_range(70.0, 160.0)
		var h := r.randf_range(90.0, 230.0)
		var pts := PackedVector2Array()
		match eon:
			0:  # cúpulas e agulhas de catacumba
				pts = PackedVector2Array([Vector2(x, base), Vector2(x, base - h * 0.6), Vector2(x + w * 0.5, base - h), Vector2(x + w, base - h * 0.6), Vector2(x + w, base)])
			1:  # torres de mercado com toldos
				pts = PackedVector2Array([Vector2(x, base), Vector2(x, base - h), Vector2(x + w * 0.3, base - h - 20), Vector2(x + w, base - h), Vector2(x + w, base)])
			2:  # muralhas e ameias
				pts = PackedVector2Array([Vector2(x, base), Vector2(x, base - h)])
				var k := 0.0
				while k < w:
					pts.append(Vector2(x + k, base - h - (12.0 if int(k / 14.0) % 2 == 0 else 0.0)))
					k += 14.0
				pts.append(Vector2(x + w, base - h))
				pts.append(Vector2(x + w, base))
			3:  # estantes gigantes
				pts = PackedVector2Array([Vector2(x, base), Vector2(x, base - h * 1.3), Vector2(x + w, base - h * 1.3), Vector2(x + w, base)])
			4:  # molduras espelhadas em pé
				pts = PackedVector2Array([Vector2(x, base), Vector2(x + w * 0.1, base - h), Vector2(x + w * 0.5, base - h - 30), Vector2(x + w * 0.9, base - h), Vector2(x + w, base)])
			5:  # árvores mortas ao longe
				pts = PackedVector2Array([Vector2(x + w * 0.4, base), Vector2(x + w * 0.45, base - h), Vector2(x + w * 0.2, base - h - 30), Vector2(x + w * 0.5, base - h + 10), Vector2(x + w * 0.8, base - h - 40), Vector2(x + w * 0.55, base - h), Vector2(x + w * 0.6, base)])
			6:  # palácio: colunas e cúpulas douradas
				pts = PackedVector2Array([Vector2(x, base), Vector2(x, base - h), Vector2(x + w * 0.5, base - h - 50), Vector2(x + w, base - h), Vector2(x + w, base)])
			_:  # centro/mente: engrenagens e fatias
				pts = PackedVector2Array([Vector2(x, base), Vector2(x + w * 0.2, base - h), Vector2(x + w * 0.8, base - h * 0.7), Vector2(x + w, base)])
		l.add_child(_poly(pts, col))
		# janelas acesas (poucas) — a cidade que dorme
		if eon in [0, 1, 3, 6] and r.randf() < 0.6:
			for k in r.randi_range(1, 4):
				var win := _poly(PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5, 8), Vector2(0, 8)]), Color(p.glow.r, p.glow.g, p.glow.b, r.randf_range(0.15, 0.45)))
				win.position = Vector2(x + r.randf_range(8.0, w - 12.0), base - r.randf_range(20.0, h * 0.5))
				l.add_child(win)
		x += w + r.randf_range(-10.0, 40.0)


# --- props do meio ---------------------------------------------------------------

func _build_mid() -> void:
	var p := pal()
	var l := _layer(Vector2(0.42, 1.0), W)
	var r := _rng(3)
	var x := r.randf_range(40.0, 120.0)
	while x < W - 60.0:
		var n := _make_prop(eon, r, p.mid, p.mid.lightened(0.18), p.glow)
		n.position = Vector2(x, GROUND + 6.0)
		l.add_child(n)
		x += r.randf_range(260.0, 420.0)


## Um prop grande do Éon (raiz no chão, y=0 = chão). Variedade por rng.
func _make_prop(e: int, r: RandomNumberGenerator, c: Color, c2: Color, glow: Color) -> Node2D:
	var n := Node2D.new()
	var v := r.randi_range(0, 2)
	match e:
		0:  # Torpor: arcos de catacumba / lápides / urnas
			if v == 0:
				n.add_child(_poly(PackedVector2Array([Vector2(-34, 0), Vector2(-34, -150), Vector2(-20, -185), Vector2(0, -196), Vector2(20, -185), Vector2(34, -150), Vector2(34, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-20, 0), Vector2(-20, -140), Vector2(0, -160), Vector2(20, -140), Vector2(20, 0)]), c.darkened(0.35)))
			elif v == 1:
				n.add_child(_poly(PackedVector2Array([Vector2(-22, 0), Vector2(-22, -70), Vector2(-14, -90), Vector2(14, -90), Vector2(22, -70), Vector2(22, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-6, -40), Vector2(6, -40), Vector2(6, -60), Vector2(-6, -60)]), c2))
			else:
				n.add_child(_poly(PackedVector2Array([Vector2(-16, 0), Vector2(-24, -60), Vector2(-14, -110), Vector2(14, -110), Vector2(24, -60), Vector2(16, 0)]), c))
		1:  # Fome: barracas com toldo / lampiões / mesas com pratos
			if v == 0:
				n.add_child(_poly(PackedVector2Array([Vector2(-40, 0), Vector2(-40, -110), Vector2(40, -110), Vector2(40, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-56, -110), Vector2(0, -160), Vector2(56, -110)]), c2))
				for k in 3:
					n.add_child(_poly(PackedVector2Array([Vector2(-48 + k * 32, -110), Vector2(-40 + k * 32, -110), Vector2(-44 + k * 32, -96)]), c.darkened(0.2)))
			elif v == 1:
				n.add_child(_poly(PackedVector2Array([Vector2(-4, 0), Vector2(-4, -170), Vector2(4, -170), Vector2(4, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(4, -170), Vector2(40, -170), Vector2(40, -164), Vector2(4, -164)]), c))
				var lamp := _poly(PackedVector2Array([Vector2(-8, -164), Vector2(8, -164), Vector2(6, -140), Vector2(-6, -140)]), Color(glow.r, glow.g, glow.b, 0.5))
				lamp.position = Vector2(36, 0)
				n.add_child(lamp)
			else:
				n.add_child(_poly(PackedVector2Array([Vector2(-50, -50), Vector2(50, -50), Vector2(50, -40), Vector2(-50, -40)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-40, -40), Vector2(-32, -40), Vector2(-32, 0), Vector2(-40, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(32, -40), Vector2(40, -40), Vector2(40, 0), Vector2(32, 0)]), c))
		2:  # Corrente: grades / pilar com correntes / cadafalso
			if v == 0:
				for bx in [-24, -12, 0, 12, 24]:
					n.add_child(_poly(PackedVector2Array([Vector2(bx - 2, 0), Vector2(bx - 2, -150), Vector2(bx + 2, -150), Vector2(bx + 2, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-30, -150), Vector2(30, -150), Vector2(30, -140), Vector2(-30, -140)]), c2))
				n.add_child(_poly(PackedVector2Array([Vector2(-30, -80), Vector2(30, -80), Vector2(30, -74), Vector2(-30, -74)]), c2))
			elif v == 1:
				n.add_child(_poly(PackedVector2Array([Vector2(-16, 0), Vector2(-14, -180), Vector2(14, -180), Vector2(16, 0)]), c))
				for k in 8:
					var link := Polygon2D.new()
					link.polygon = _ring(5.0, 3.0)
					link.color = c2
					link.position = Vector2(20 + (k % 2) * 3, -170 + k * 11)
					n.add_child(link)
			else:
				n.add_child(_poly(PackedVector2Array([Vector2(-40, 0), Vector2(-40, -30), Vector2(40, -30), Vector2(40, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-34, -30), Vector2(-34, -160), Vector2(-26, -160), Vector2(-26, -30)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-34, -160), Vector2(30, -160), Vector2(30, -152), Vector2(-34, -152)]), c))
		3:  # Silêncio: estantes altíssimas / pilha de livros / atril
			if v == 0 or v == 1:
				n.add_child(_poly(PackedVector2Array([Vector2(-34, 0), Vector2(-34, -230), Vector2(34, -230), Vector2(34, 0)]), c))
				for k in 7:
					var sy := -20 - k * 30
					n.add_child(_poly(PackedVector2Array([Vector2(-30, sy), Vector2(30, sy), Vector2(30, sy + 4), Vector2(-30, sy + 4)]), c2))
					var bx := -28
					while bx < 26:
						var bw := r.randi_range(4, 9)
						var bh := r.randi_range(14, 24)
						n.add_child(_poly(PackedVector2Array([Vector2(bx, sy), Vector2(bx + bw, sy), Vector2(bx + bw, sy - bh), Vector2(bx, sy - bh)]), c2.lerp(c, r.randf_range(0.2, 0.7))))
						bx += bw + 1
			else:
				for k in 6:
					var bw := 30 - k * 2
					n.add_child(_poly(PackedVector2Array([Vector2(-bw / 2 + k, -k * 9), Vector2(bw / 2 + k, -k * 9), Vector2(bw / 2 + k, -k * 9 - 8), Vector2(-bw / 2 + k, -k * 9 - 8)]), c2.lerp(c, float(k) / 6.0)))
		4:  # Espelho: molduras com reflexo / cacos em pé
			if v == 0 or v == 1:
				n.add_child(_poly(PackedVector2Array([Vector2(-30, 0), Vector2(-30, -170), Vector2(-16, -195), Vector2(16, -195), Vector2(30, -170), Vector2(30, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-20, -8), Vector2(-20, -166), Vector2(0, -180), Vector2(20, -166), Vector2(20, -8)]), Color(glow.r, glow.g, glow.b, 0.22)))
				n.add_child(_poly(PackedVector2Array([Vector2(-16, -20), Vector2(-8, -150), Vector2(-2, -150), Vector2(-10, -20)]), Color(1, 1, 1, 0.14)))
			else:
				n.add_child(_poly(PackedVector2Array([Vector2(-20, 0), Vector2(-6, -120), Vector2(10, -80), Vector2(22, 0)]), Color(glow.r, glow.g, glow.b, 0.35)))
				n.add_child(_poly(PackedVector2Array([Vector2(26, 0), Vector2(34, -70), Vector2(48, 0)]), Color(glow.r, glow.g, glow.b, 0.25)))
		5:  # Praga: árvore morta com musgo / cogumelos / ossada
			if v == 0 or v == 1:
				n.add_child(_poly(PackedVector2Array([Vector2(-10, 0), Vector2(-8, -140), Vector2(8, -140), Vector2(10, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-6, -100), Vector2(-50, -150), Vector2(-42, -156), Vector2(-4, -110)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(6, -120), Vector2(46, -170), Vector2(38, -176), Vector2(4, -128)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(2, -140), Vector2(10, -200), Vector2(4, -200), Vector2(-4, -140)]), c))
				for k in 3:
					var moss := _poly(PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(4, 30 + k * 8), Vector2(1, 30 + k * 8)]), c2.darkened(0.2))
					moss.position = Vector2(-40 + k * 14, -150 + k * 4)
					n.add_child(moss)
			else:
				for k in 3:
					var cap := _poly(PackedVector2Array([Vector2(-14, -20), Vector2(14, -20), Vector2(8, -34), Vector2(-8, -34)]), Color(0.45, 0.25, 0.4))
					cap.position = Vector2(-20 + k * 20, -k * 6)
					n.add_child(cap)
					var stem := _poly(PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(3, -20), Vector2(-3, -20)]), c2)
					stem.position = Vector2(-20 + k * 20, -k * 6)
					n.add_child(stem)
		6:  # Coroa: coluna com capitel / estandarte / trono vazio
			if v == 0:
				n.add_child(_poly(PackedVector2Array([Vector2(-18, 0), Vector2(-14, -200), Vector2(14, -200), Vector2(18, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-26, -200), Vector2(26, -200), Vector2(22, -214), Vector2(-22, -214)]), c2))
				n.add_child(_poly(PackedVector2Array([Vector2(-26, 0), Vector2(26, 0), Vector2(22, -12), Vector2(-22, -12)]), c2))
			elif v == 1:
				n.add_child(_poly(PackedVector2Array([Vector2(-3, 0), Vector2(-3, -190), Vector2(3, -190), Vector2(3, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(3, -186), Vector2(40, -186), Vector2(40, -100), Vector2(22, -116), Vector2(3, -100)]), Color(glow.r, glow.g, glow.b, 0.35)))
			else:
				n.add_child(_poly(PackedVector2Array([Vector2(-30, 0), Vector2(-30, -60), Vector2(30, -60), Vector2(30, 0)]), c))
				n.add_child(_poly(PackedVector2Array([Vector2(-30, -60), Vector2(-30, -150), Vector2(-10, -160), Vector2(0, -175), Vector2(10, -160), Vector2(30, -150), Vector2(30, -60)]), c2))
		7:  # Centro: engrenagens / pistões
			n.add_child(_poly(_ring(60.0, 44.0), c2))
			n.add_child(_poly(PackedVector2Array([Vector2(-8, 0), Vector2(-8, -120), Vector2(8, -120), Vector2(8, 0)]), c))
		_:  # Mente: colunas de vidro quebrado / olhos
			n.add_child(_poly(PackedVector2Array([Vector2(-14, 0), Vector2(-20, -160), Vector2(0, -200), Vector2(20, -160), Vector2(14, 0)]), Color(glow.r, glow.g, glow.b, 0.2)))
	return n


func _ring(ro: float, ri: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * ro)
	for i in 17:
		var a := -TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * ri)
	return pts


# --- props perto (pequenos, escuros) ---------------------------------------------

func _build_near() -> void:
	var p := pal()
	var l := _layer(Vector2(0.72, 1.0), W)
	var r := _rng(4)
	var x := r.randf_range(0.0, 200.0)
	var c: Color = p.near
	while x < W:
		var n := Node2D.new()
		var v := r.randi_range(0, 2)
		match eon:
			0: n.add_child(_poly(PackedVector2Array([Vector2(-10, 0), Vector2(-10, -30), Vector2(-5, -40), Vector2(5, -40), Vector2(10, -30), Vector2(10, 0)]), c))
			1: n.add_child(_poly(PackedVector2Array([Vector2(-18, 0), Vector2(-14, -22), Vector2(14, -22), Vector2(18, 0)]), c))
			2:
				for k in 4:
					var link := _poly(_ring(4.0, 2.0), c.lightened(0.3))
					link.position = Vector2(k * 7, -k * 5)
					n.add_child(link)
			3: n.add_child(_poly(PackedVector2Array([Vector2(-12, 0), Vector2(-12, -6), Vector2(12, -8), Vector2(12, 0)]), c))
			4: n.add_child(_poly(PackedVector2Array([Vector2(-8, 0), Vector2(0, -38), Vector2(10, 0)]), Color(p.glow.r, p.glow.g, p.glow.b, 0.2)))
			5: n.add_child(_poly(PackedVector2Array([Vector2(-26, 0), Vector2(-14, -8), Vector2(14, -8), Vector2(26, 0)]), c.lightened(0.1)))
			6: n.add_child(_poly(PackedVector2Array([Vector2(-14, 0), Vector2(-12, -18), Vector2(12, -18), Vector2(14, 0)]), c))
			_: n.add_child(_poly(PackedVector2Array([Vector2(-8, 0), Vector2(-4, -26), Vector2(4, -26), Vector2(8, 0)]), c))
		if v == 2:
			n.scale = Vector2(1.6, 1.6)
		n.position = Vector2(x, GROUND + 4.0)
		l.add_child(n)
		x += r.randf_range(120.0, 300.0)


# --- névoa -----------------------------------------------------------------------

func _build_fog() -> void:
	var p := pal()
	var l := _layer(Vector2(0.9, 1.0), W)
	var r := _rng(5)
	var strength := 1.0
	if eon in [0, 3, 5, 7, 8]:
		strength = 1.5
	for i in 9:
		var f := FogPuff.new()
		f.color = p.fog
		f.radius = r.randf_range(90.0, 180.0)
		f.alpha = r.randf_range(0.05, 0.11) * strength
		f.speed = r.randf_range(4.0, 12.0)
		f.position = Vector2(r.randf_range(0.0, W), GROUND - r.randf_range(-10.0, 40.0))
		f.width = W
		l.add_child(f)
		_fog_nodes.append(f)


class FogPuff extends Node2D:
	var color: Color = Color(0.6, 0.6, 0.7)
	var radius: float = 120.0
	var alpha: float = 0.08
	var speed: float = 8.0
	var width: float = 1800.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		position.x = fmod(position.x + speed * delta + width, width)
		queue_redraw()

	func _draw() -> void:
		var breathe := 1.0 + sin(_t * 0.7) * 0.08
		# várias elipses achatadas, cada uma bem fraca: borda macia (sem "disco")
		for k in 6:
			var rr := radius * (1.0 - 0.14 * float(k)) * breathe
			draw_colored_polygon(_ellipse(rr, rr * 0.16), Color(color.r, color.g, color.b, alpha * 0.45))

	func _ellipse(rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		return pts


# --- chão (coords de mundo, filho do Level) --------------------------------------

## Relevo do chão: superfície com lajes/rachaduras e borda de luz. y=0 = topo do chão.
func build_ground(parent: Node2D, ground_top_y: float) -> void:
	var g := GroundDetail.new()
	g.eon = eon
	g.pal = pal()
	g.position = Vector2(0, ground_top_y)
	g.z_index = -1
	parent.add_child(g)


class GroundDetail extends Node2D:
	var eon: int = 0
	var pal: Dictionary = {}
	# Faixa do chão: cobre a travessia inteira (até 3 zonas: parede em x≈3620)
	# com folga — a câmera nunca vê o chão acabar.
	const LEFT := -2400.0
	const RIGHT := 6800.0

	func _draw() -> void:
		var top: Color = pal.ground
		var dark: Color = pal.ground_dark
		var glow: Color = pal.glow
		# chão inteiro (gradiente)
		draw_polygon(PackedVector2Array([Vector2(LEFT, 0), Vector2(RIGHT, 0), Vector2(RIGHT, 420), Vector2(LEFT, 420)]),
			PackedColorArray([top, top, dark, dark]))
		var floor_tex: Texture2D = PaintedLibrary.background(eon)
		for tile in range(-5,14):
			draw_texture_rect_region(floor_tex,Rect2(tile*512,0,512,160),Rect2(0,floor_tex.get_height()*0.82,512,floor_tex.get_height()*0.18),Color(0.75,0.79,0.83))
		draw_line(Vector2(LEFT,1),Vector2(RIGHT,1),Color(glow,0.18),1.0,true)

	func _ell(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * float(i) / 20.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts


# --- primeiro plano (parallax > 1, por código; filho do Level) -------------------

func build_foreground(parent: Node2D) -> void:
	var f := Foreground.new()
	f.eon = eon
	f.pal = pal()
	f.rng = _rng(6)
	f.z_index = 30
	parent.add_child(f)


class Foreground extends Node2D:
	var eon: int = 0
	var pal: Dictionary = {}
	var rng: RandomNumberGenerator
	const SPEED := 1.3       # > 1 = passa mais rápido que o mundo (está à frente)
	const SPAN := 6800.0     # até onde vai o entulho (cobre a travessia de 3 zonas)

	func _process(_delta: float) -> void:
		var cam := get_viewport().get_camera_2d()
		if cam == null:
			return
		var cx := cam.get_screen_center_position().x
		position.x = cx * (1.0 - SPEED)
		queue_redraw()

	## Entulho à frente da câmera: posição, tamanho e espelho por tela.
	func _ready() -> void:
		if rng == null:
			rng = RandomNumberGenerator.new()
		var x: float = -300.0 + rng.randf_range(0.0, 400.0)
		while x < SPAN:
			var rubble := PaintedLibrary.sprite(3, rng.randf_range(56.0, 88.0))
			rubble.position = Vector2(x, 428)
			rubble.modulate = Color(0.20, 0.26, 0.30, 0.85)
			if rng.randf() < 0.5:
				rubble.scale.x = -rubble.scale.x
			add_child(rubble)
			x += rng.randf_range(620.0, 1050.0)


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
