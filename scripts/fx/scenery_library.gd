extends RefCounted
class_name SceneryLibrary
## CATÁLOGO DO CENÁRIO (Diretor de Cenário). Texturas das camadas de paralaxe
## por Éon (geradas offline por `tools/scenery/build_backgrounds.py` a partir de
## `assets/painted/eons.png`), shaders do cenário e a direção de luz de cada Éon
## (de onde vêm os raios, quanto o chão reflete, cor da névoa).
## Só leitura/estático: quem monta a cena é `scripts/levels/scenery.gd`.

const DIR := "res://assets/backgrounds/"
const SHADERS := "res://assets/shaders/"

# >>> GERADO
## DADOS GERADOS por tools/scenery/build_backgrounds.py — não editar à mão.
## Por Éon: tamanho do far (px), altura do chão pintado, asas (px), início da faixa near (px),
## cor da névoa e do céu (médias da pintura).
const LAYERS := [
	{"size": Vector2(1521, 789), "floor_h": 219, "wings": Vector2(210, 1365), "near_y": 580, "haze": Color(0.395, 0.580, 0.660), "sky": Color(0.123, 0.195, 0.239)},
	{"size": Vector2(1518, 789), "floor_h": 219, "wings": Vector2(135, 1410), "near_y": 644, "haze": Color(0.477, 0.253, 0.241), "sky": Color(0.131, 0.054, 0.059)},
	{"size": Vector2(1521, 789), "floor_h": 219, "wings": Vector2(255, 1365), "near_y": 721, "haze": Color(0.422, 0.474, 0.542), "sky": Color(0.150, 0.173, 0.208)},
	{"size": Vector2(1521, 726), "floor_h": 216, "wings": Vector2(240, 1320), "near_y": 536, "haze": Color(0.380, 0.402, 0.602), "sky": Color(0.117, 0.139, 0.220)},
	{"size": Vector2(1518, 726), "floor_h": 216, "wings": Vector2(180, 1335), "near_y": 614, "haze": Color(0.805, 0.732, 0.802), "sky": Color(0.326, 0.291, 0.347)},
	{"size": Vector2(1521, 726), "floor_h": 216, "wings": Vector2(225, 1290), "near_y": 611, "haze": Color(0.453, 0.526, 0.505), "sky": Color(0.239, 0.280, 0.261)},
	{"size": Vector2(1521, 732), "floor_h": 345, "wings": Vector2(150, 1260), "near_y": 526, "haze": Color(0.826, 0.700, 0.486), "sky": Color(0.469, 0.358, 0.258)},
	{"size": Vector2(1518, 732), "floor_h": 345, "wings": Vector2(180, 1365), "near_y": 550, "haze": Color(0.420, 0.391, 0.522), "sky": Color(0.144, 0.130, 0.175)},
	{"size": Vector2(1521, 732), "floor_h": 345, "wings": Vector2(255, 1335), "near_y": 542, "haze": Color(0.552, 0.326, 0.391), "sky": Color(0.201, 0.127, 0.181)},
]
# <<< GERADO

# >>> GERADO HD
## DADOS GERADOS por tools/cenario7/build_hd.py — não editar à mão.
## Por Éon com arte HD: s = escala (px lógicos por px da imagem) do Éon; por camada:
## tex, w×h da textura, y0 = 1ª linha da imagem original na textura, line = linha
## do chão MEDIDA (px da imagem original), far.s = escala própria do far, far.astro =
## foco de luz (px da imagem original).
const HD := {
	0: {"s": 0.39326, "far": {"tex": "eon_0_far", "w": 1536, "h": 813, "y0": 0, "line": 712, "s": 0.39326, "astro": Vector2(1074.0000, 176.0000)}, "mid": [{"tex": "eon_0_mid_a", "w": 1536, "h": 601, "y0": 167, "line": 738}], "wings": [{"tex": "eon_0_wings_a", "w": 1536, "h": 716, "y0": 0, "line": 712}], "floor": {"tex": "eon_0_floor", "w": 1536, "h": 306}},
	1: {"s": 0.36601, "far": {"tex": "eon_1_far", "w": 1536, "h": 804, "y0": 0, "line": 702, "s": 0.39031, "astro": Vector2(951.0000, 354.0000)}, "mid": [{"tex": "eon_1_mid_a", "w": 1536, "h": 749, "y0": 0, "line": 717}], "wings": [{"tex": "eon_1_wings_a", "w": 1536, "h": 769, "y0": 0, "line": 765}], "floor": {"tex": "eon_1_floor", "w": 1536, "h": 253}},
	2: {"s": 0.39216, "far": {"tex": "eon_2_far", "w": 1536, "h": 820, "y0": 0, "line": 718, "s": 0.39216, "astro": Vector2(1004.0000, 156.0000)}, "mid": [{"tex": "eon_2_mid_a", "w": 1536, "h": 755, "y0": 0, "line": 725}], "wings": [{"tex": "eon_2_wings_a", "w": 1536, "h": 718, "y0": 0, "line": 714}], "floor": {"tex": "eon_2_floor", "w": 1536, "h": 304}},
	3: {"s": 0.35806, "far": {"tex": "eon_3_far", "w": 1536, "h": 829, "y0": 0, "line": 724, "s": 0.37845, "astro": Vector2(1049.0000, 307.0000)}, "mid": [{"tex": "eon_3_mid_a", "w": 1536, "h": 744, "y0": 0, "line": 711}], "wings": [{"tex": "eon_3_wings_a", "w": 1536, "h": 786, "y0": 0, "line": 782}], "floor": {"tex": "eon_3_floor", "w": 1536, "h": 236}},
	4: {"s": 0.35354, "far": {"tex": "eon_4_far", "w": 1536, "h": 755, "y0": 0, "line": 659, "s": 0.41578, "astro": Vector2(1112.0000, 236.0000)}, "mid": [{"tex": "eon_4_mid_a", "w": 1536, "h": 758, "y0": 25, "line": 750}], "wings": [{"tex": "eon_4_wings_a", "w": 1536, "h": 796, "y0": 0, "line": 792}], "floor": {"tex": "eon_4_floor", "w": 1536, "h": 226}},
	5: {"s": 0.38781, "far": {"tex": "eon_5_far", "w": 1536, "h": 765, "y0": 0, "line": 668, "s": 0.41018, "astro": Vector2(1163.0000, 54.0000)}, "mid": [{"tex": "eon_5_mid_a", "w": 1536, "h": 755, "y0": 0, "line": 725}], "wings": [{"tex": "eon_5_wings_a", "w": 1536, "h": 726, "y0": 0, "line": 722}], "floor": {"tex": "eon_5_floor", "w": 1536, "h": 296}},
	6: {"s": 0.36988, "far": {"tex": "eon_6_far", "w": 1536, "h": 755, "y0": 0, "line": 659, "s": 0.41578, "astro": Vector2(1232.0000, 190.0000)}, "mid": [{"tex": "eon_6_mid_a", "w": 1536, "h": 548, "y0": 182, "line": 698}], "wings": [{"tex": "eon_6_wings_a", "w": 1536, "h": 761, "y0": 0, "line": 757}], "floor": {"tex": "eon_6_floor", "w": 1536, "h": 261}},
	7: {"s": 0.39106, "far": {"tex": "eon_7_far", "w": 1536, "h": 778, "y0": 0, "line": 679, "s": 0.40353, "astro": Vector2(1149.0000, 206.0000)}, "mid": [{"tex": "eon_7_mid_a", "w": 1536, "h": 692, "y0": 81, "line": 743}], "wings": [{"tex": "eon_7_wings_a", "w": 1536, "h": 720, "y0": 0, "line": 716}], "floor": {"tex": "eon_7_floor", "w": 1536, "h": 302}},
	8: {"s": 0.38251, "far": {"tex": "eon_8_far", "w": 1536, "h": 744, "y0": 0, "line": 650, "s": 0.42154, "astro": Vector2(1091.0000, 436.0000)}, "mid": [{"tex": "eon_8_mid_a", "w": 1536, "h": 759, "y0": 0, "line": 728}], "wings": [{"tex": "eon_8_wings_a", "w": 1536, "h": 736, "y0": 0, "line": 732}], "floor": {"tex": "eon_8_floor", "w": 1536, "h": 286}},
}
# <<< GERADO HD

## Direção de luz por Éon (à mão). Coordenadas `ray` em fração da pintura
## (acima do chão): x 0..1 da esquerda, y 0..1 do topo. `ray_dark` = raios de
## VAZIO (escurecem em vez de clarear — a Mente). `ray_hd` = com o far HD, o foco
## dos raios é o astro MEDIDO na pintura nova (senão, `ray` vale para ela também). `crack` (opcional, padrão 1,1)
## = brilho do Éon nas rachaduras do chão; menor onde a luz do Éon é quase branca.
const LOOK := [
	# 0 Torpor: a lua no rosácea; chão alagado reflete bem.
	{"ray": Vector2(0.60, 0.16), "ray_hd": true, "ray_col": Color(0.62, 0.86, 1.0), "ray_amt": 0.30, "ray_spread": 0.55, "reflect": 0.34, "mist": 0.55, "glow": Color("98cece"), "light": Color(0.80, 0.90, 1.0)},
	# 1 Fome: brasa vermelha atrás da janela.
	{"ray": Vector2(0.52, 0.22), "ray_col": Color(1.0, 0.50, 0.34), "ray_amt": 0.24, "ray_spread": 0.45, "reflect": 0.16, "mist": 0.40, "glow": Color(1.0, 0.55, 0.3), "light": Color(1.0, 0.78, 0.66)},
	# 2 Corrente: luz cinza de cima, entre as correntes.
	{"ray": Vector2(0.64, -0.10), "ray_col": Color(0.86, 0.92, 1.0), "ray_amt": 0.30, "ray_spread": 0.40, "reflect": 0.16, "mist": 0.65, "glow": Color(0.85, 0.85, 0.95), "light": Color(0.86, 0.88, 0.95)},
	# 3 Silêncio: o sol negro só tem halo (raios fracos, frios).
	{"ray": Vector2(0.66, 0.20), "ray_col": Color(0.70, 0.66, 1.0), "ray_amt": 0.18, "ray_spread": 0.70, "reflect": 0.22, "mist": 0.50, "glow": Color(0.7, 0.75, 1.0), "light": Color(0.80, 0.80, 1.0)},
	# 4 Espelho: claridade forte; o chão é quase espelho.
	{"ray": Vector2(0.62, 0.02), "ray_col": Color(0.96, 0.92, 1.0), "ray_amt": 0.32, "ray_spread": 0.50, "reflect": 0.50, "crack": 0.4, "mist": 0.45, "glow": Color(0.95, 0.97, 1.0), "light": Color(1.0, 0.98, 1.0)},
	# 5 Praga: luz verde coada pelas arcadas; chão úmido.
	{"ray": Vector2(0.72, -0.05), "ray_col": Color(0.72, 1.0, 0.60), "ray_amt": 0.28, "ray_spread": 0.45, "reflect": 0.26, "mist": 0.75, "glow": Color(0.7, 1.0, 0.5), "light": Color(0.84, 1.0, 0.80)},
	# 6 Coroa: ouro diagonal; mármore polido.
	{"ray": Vector2(0.64, -0.02), "ray_col": Color(1.0, 0.86, 0.52), "ray_amt": 0.34, "ray_spread": 0.55, "reflect": 0.36, "crack": 0.7, "mist": 0.40, "glow": Color(1.0, 0.85, 0.4), "light": Color(1.0, 0.92, 0.75)},
	# 7 Centro: a esfera da máquina irradia (e tem faíscas em órbita).
	{"ray": Vector2(0.62, 0.36), "ray_col": Color(0.82, 0.72, 1.0), "ray_amt": 0.24, "ray_spread": 1.0, "reflect": 0.18, "mist": 0.55, "glow": Color(1.0, 0.8, 0.45), "light": Color(0.88, 0.82, 1.0)},
	# 8 Mente: o olho cego irradia VAZIO.
	{"ray": Vector2(0.72, 0.18), "ray_col": Color(0.10, 0.02, 0.08), "ray_amt": 0.40, "ray_spread": 1.0, "ray_dark": true, "reflect": 0.30, "mist": 0.50, "glow": Color(1.0, 0.6, 0.7), "light": Color(1.0, 0.82, 0.88)},
]

static var _tex: Dictionary = {}
static var _shaders: Dictionary = {}


## Textura de uma camada do Éon: "far", "mid", "near", "floor", "fgcol".
## Nula se o pipeline não gerou (o cenário cai no fallback).
static func layer(eon: int, kind: String) -> Texture2D:
	return texture("eon_%d_%s" % [clampi(eon, 0, 8), kind])


static func texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := DIR + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


static func has_layers(eon: int) -> bool:
	return eon >= 0 and eon < LAYERS.size() and layer(eon, "far") != null


## FUNDOS HD (Cenário 7): camadas em resolução cheia geradas por
## `tools/cenario7/build_hd.py` em `assets/backgrounds/hd/`. Vazio = o Éon não
## tem arte nova (usa as camadas antigas). Um Éon pode ter só o far novo.
static func hd(eon: int) -> Dictionary:
	return HD.get(eon, {})


static var _hd_eon: int = -1

## Textura HD por nome. Só o Éon atual fica na memória: ao trocar de Éon as
## texturas HD do anterior saem do cache (cada Éon tem ~25 MB de VRAM em HD).
static func hd_texture(eon: int, name: String) -> Texture2D:
	if eon != _hd_eon:
		for k in _tex.keys():
			if String(k).begins_with("hd/"):
				_tex.erase(k)
		_hd_eon = eon
	return texture("hd/" + name)


## Dados gerados (tamanho, chão, asas, névoa) do Éon.
static func data(eon: int) -> Dictionary:
	if LAYERS.is_empty():
		return {}
	return LAYERS[clampi(eon, 0, LAYERS.size() - 1)]


static func look(eon: int) -> Dictionary:
	return LOOK[clampi(eon, 0, LOOK.size() - 1)]


## Shader do cenário por nome curto: "floor", "rays", "fog", "prop".
static func shader(name: String) -> Shader:
	if not _shaders.has(name):
		_shaders[name] = load(SHADERS + "scenery_" + name + ".gdshader")
	return _shaders[name]


static func material(name: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(name)
	return m


## Material de prop pintado integrado ao Éon: recorta o magenta, puxa pra cor
## da névoa conforme a distância, acende a borda de cima com a luz do Éon e
## recolore chamas ciano pra cor do Éon.
static func prop_material(eon: int, haze_amt: float, darken: float = 0.0, rim: float = 0.6) -> ShaderMaterial:
	var m := material("prop")
	var d := data(eon)
	var lk := look(eon)
	m.set_shader_parameter("haze", d.get("haze", Color(0.5, 0.5, 0.6)))
	m.set_shader_parameter("haze_amt", haze_amt)
	m.set_shader_parameter("ambient", Color(lk.light).darkened(darken))
	m.set_shader_parameter("rim_col", lk.glow)
	m.set_shader_parameter("rim_amt", rim)
	m.set_shader_parameter("flame_col", lk.glow)
	m.set_shader_parameter("flame_amt", 0.0 if eon == 0 else 1.0)
	return m
