class_name AttackStyle
extends RefCounted
## LINGUAGEM VISUAL DOS ATAQUES (VFX7). Uma tabela por FAMÍLIA de ataque à
## distância: tamanho do núcleo, halo, raios, rastro, partículas secundárias,
## impacto e dissipação. Quem desenha é o ProjectileFX/ChargeFX/VfxLibrary;
## aqui só mora o "dicionário de estilo".
##
## Regra de leitura (forma além da cor, R5/daltonismo):
##  - LUZ DA SOPHIA = redonda, miolo BRANCO-quente, raios macios, rastro claro;
##  - LUZ CORROMPIDA (Arcontes/criaturas) = miolo ESCURO com borda acesa,
##    coroa PONTIAGUDA girando, rastro com veio escuro.
## Assim um tiro inimigo nunca se confunde com um da Sophia, mesmo na mesma cor.

const SHADER_DIR := "res://assets/shaders/"

## Cores dos 7 Anéis (= paixão de cada Arconte) + Esfera Solar. Iguais às de
## GameContent (skill.color): `ring_of_color` reconhece a magia pela cor.
const RING_COLORS := {
	"m_s1": Color(1.0, 0.85, 0.5),
	"r_torpor": Color(0.72, 0.78, 1.0),
	"r_fome": Color(1.0, 0.55, 0.3),
	"r_corrente": Color(0.85, 0.85, 0.95),
	"r_silencio": Color(0.7, 0.8, 1.0),
	"r_espelho": Color(0.9, 0.95, 1.0),
	"r_praga": Color(0.75, 1.0, 0.55),
	"r_coroa": Color(1.0, 0.9, 0.5),
}

## Família → estilo. Campos:
##  core: escala do quad do núcleo (128 px × core) · dark/spikes/swirl: shader do orbe
##  halo: escala do brilho aditivo · halo_a: alfa · rays: textura de raios ("" = sem)
##  rays_s: escala dos raios · rays_spin: rad/s · squash: escala x,y do núcleo
##  trail_w: largura do rastro (px) · trail_n: pontos · trail_links: elos (corrente)
##  trail_dark: veio escuro · trail_break: recorte do ruído
##  part: textura das partículas · part_n: quantidade · part_add: aditivas?
##  part_up: partículas sobem (névoa/esporos) · ground: px até o chão (decalque)
##  impact: estilo do impacto · charge: estilo da antecipação
const STYLES := {
	# --- Sophia -------------------------------------------------------------
	"light": {"core": 0.15, "dark": 0.0, "spikes": 0.0, "swirl": 1.2, "halo": 0.26, "halo_a": 0.28,
		"rays": "", "rays_s": 0.0, "rays_spin": 0.0, "squash": Vector2(1.15, 1.0),
		"trail_w": 9.0, "trail_n": 12, "trail_links": 0.0, "trail_dark": 0.0, "trail_break": 0.5,
		"part": "spark", "part_n": 8, "part_add": true, "part_up": false, "ground": 30.0,
		"impact": "light", "charge": "light"},
	"solar": {"core": 0.21, "dark": 0.0, "spikes": 0.0, "swirl": 1.6, "halo": 0.42, "halo_a": 0.32,
		"rays": "flare", "rays_s": 0.36, "rays_spin": 2.2, "squash": Vector2(1.1, 1.0),
		"trail_w": 15.0, "trail_n": 14, "trail_links": 0.0, "trail_dark": 0.0, "trail_break": 0.6,
		"part": "flame", "part_n": 12, "part_add": true, "part_up": false, "ground": 30.0,
		"impact": "explosion", "charge": "light"},
	"chain_light": {"core": 0.14, "dark": 0.0, "spikes": 4.0, "swirl": 2.0, "halo": 0.3, "halo_a": 0.5,
		"rays": "star", "rays_s": 0.16, "rays_spin": 7.0, "squash": Vector2(1.0, 1.0),
		"trail_w": 8.0, "trail_n": 16, "trail_links": 7.0, "trail_dark": 0.0, "trail_break": 0.0,
		"part": "spark2", "part_n": 7, "part_add": true, "part_up": false, "ground": 30.0,
		"impact": "chain", "charge": "light"},
	# --- Arcontes / criaturas ------------------------------------------------
	"dark": {"core": 0.17, "dark": 1.0, "spikes": 5.0, "swirl": 1.4, "halo": 0.26, "halo_a": 0.285,
		"rays": "star", "rays_s": 0.2, "rays_spin": -3.0, "squash": Vector2(1.1, 1.0),
		"trail_w": 9.0, "trail_n": 11, "trail_links": 0.0, "trail_dark": 1.0, "trail_break": 0.5,
		"part": "spark2", "part_n": 8, "part_add": true, "part_up": false, "ground": 24.0,
		"impact": "dark", "charge": "dark"},
	"king": {"core": 0.26, "dark": 0.0, "spikes": 7.0, "swirl": 0.9, "halo": 0.5, "halo_a": 0.35,
		"rays": "flare", "rays_s": 0.46, "rays_spin": -1.3, "squash": Vector2(1.0, 1.0),
		"trail_w": 16.0, "trail_n": 16, "trail_links": 0.0, "trail_dark": 1.0, "trail_break": 0.45,
		"part": "star", "part_n": 10, "part_add": true, "part_up": false, "ground": 30.0,
		"impact": "king", "charge": "king"},
	"chain": {"core": 0.15, "dark": 1.0, "spikes": 3.0, "swirl": 2.2, "halo": 0.28, "halo_a": 0.45,
		"rays": "star", "rays_s": 0.18, "rays_spin": 9.0, "squash": Vector2(1.0, 1.0),
		"trail_w": 8.0, "trail_n": 16, "trail_links": 7.0, "trail_dark": 0.0, "trail_break": 0.0,
		"part": "spark2", "part_n": 6, "part_add": true, "part_up": false, "ground": 30.0,
		"impact": "chain", "charge": "dark"},
	"sleep": {"core": 0.2, "dark": 0.0, "spikes": 0.0, "swirl": 0.6, "halo": 0.36, "halo_a": 0.28,
		"rays": "", "rays_s": 0.0, "rays_spin": 0.0, "squash": Vector2(1.0, 1.0),
		"trail_w": 13.0, "trail_n": 14, "trail_links": 0.0, "trail_dark": 0.0, "trail_break": 0.8,
		"part": "circle", "part_n": 9, "part_add": true, "part_up": true, "ground": 24.0,
		"impact": "sleep", "charge": "dark"},
	"wave": {"core": 0.2, "dark": 1.0, "spikes": 6.0, "swirl": 2.4, "halo": 0.36, "halo_a": 0.55,
		"rays": "", "rays_s": 0.0, "rays_spin": 0.0, "squash": Vector2(1.7, 0.6),
		"trail_w": 12.0, "trail_n": 12, "trail_links": 0.0, "trail_dark": 1.0, "trail_break": 0.7,
		"part": "smoke", "part_n": 10, "part_add": false, "part_up": true, "ground": 6.0,
		"impact": "wave", "charge": "dark"},
}


static func get_style(kind: String) -> Dictionary:
	return STYLES.get(kind, STYLES["light"])


## A família do ataque a partir das propriedades do projétil (sem mexer em
## projectile.gd). Ordem: meta "vfx_kind" (quem cria manda) → heurística.
static func kind_for(proj: Node) -> String:
	if proj == null:
		return "light"
	if proj.has_meta("vfx_kind"):
		return String(proj.get_meta("vfx_kind"))
	var team: String = String(proj.get("target_team")) if proj.get("target_team") != null else "enemy"
	var root_t: float = float(proj.get("root_time")) if proj.get("root_time") != null else 0.0
	var slow_t: float = float(proj.get("slow_time")) if proj.get("slow_time") != null else 0.0
	var boom: float = float(proj.get("explode_radius")) if proj.get("explode_radius") != null else 0.0
	var life: float = float(proj.get("lifetime")) if proj.get("lifetime") != null else 1.2
	var col: Color = proj.get("color") if proj.get("color") is Color else Color.WHITE
	if team == "enemy":                 # tiro da Sophia
		if boom > 0.0:
			return "solar"
		if root_t > 0.0:
			return "chain_light"
		return "light"
	if root_t > 0.0:
		return "chain"
	if slow_t > 0.0:
		return "sleep"
	# o orbe do Rei/Demiurgo: dourado e de vida longa (enemy.gd, kit "rei")
	if life >= 2.3 and _near(col, Color(1.0, 0.85, 0.5)):
		return "king"
	# onda rasteira (enemy.gd `_ground_wave`: vida 1,8 s)
	if absf(life - 1.8) < 0.01:
		return "wave"
	return "dark"


## Qual magia da Sophia tem esta cor ("" = nenhuma).
static func ring_of_color(col: Color) -> String:
	for id in RING_COLORS:
		if _near(col, RING_COLORS[id]):
			return id
	return ""


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.03


## Família de luz da Sophia?
static func is_light(kind: String) -> bool:
	return kind in ["light", "solar", "chain_light"]


# --- Materiais (compilados 1× e COMPARTILHADOS: o Godot agrupa o desenho) ----

static var _mats: Dictionary = {}


static func _shader(name: String) -> Shader:
	return load(SHADER_DIR + name + ".gdshader")


## Material do núcleo para uma família (um por família, compartilhado).
static func orb_material(kind: String) -> ShaderMaterial:
	var key := "orb_" + kind
	if not _mats.has(key):
		var st := get_style(kind)
		var m := ShaderMaterial.new()
		m.shader = _shader("vfx_orb")
		m.set_shader_parameter("dark", st.dark)
		m.set_shader_parameter("spikes", st.spikes)
		m.set_shader_parameter("swirl", st.swirl)
		m.set_shader_parameter("core_size", 0.24 if st.dark > 0.5 else 0.17)
		_mats[key] = m
	return _mats[key]


## Material do rastro para uma família.
static func trail_material(kind: String) -> ShaderMaterial:
	var key := "trail_" + kind
	if not _mats.has(key):
		var st := get_style(kind)
		var m := ShaderMaterial.new()
		m.shader = _shader("vfx_trail")
		m.set_shader_parameter("dark", st.trail_dark)
		m.set_shader_parameter("links", st.trail_links)
		m.set_shader_parameter("breakup", st.trail_break)
		m.set_shader_parameter("scroll", 4.0 if is_light(kind) else 2.6)
		_mats[key] = m
	return _mats[key]


## Material de anel de choque (claro ou corrompido).
static func ring_material(dark: bool = false, thickness: float = 0.14) -> ShaderMaterial:
	var key := "ring_%d_%d" % [int(dark), int(thickness * 100.0)]
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = _shader("vfx_ring")
		m.set_shader_parameter("dark", 1.0 if dark else 0.0)
		m.set_shader_parameter("thickness", thickness)
		_mats[key] = m
	return _mats[key]


## Textura branca 1D para o Line2D gerar UV (o shader desenha a fita toda).
static var _strip: GradientTexture2D


static func strip_texture() -> Texture2D:
	if _strip == null:
		_strip = GradientTexture2D.new()
		_strip.width = 16
		_strip.height = 4
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color.WHITE)
		_strip.gradient = g
	return _strip
