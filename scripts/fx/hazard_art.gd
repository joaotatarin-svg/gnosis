extends RefCounted
class_name HazardArt
## PERIGOS PINTADOS (Onda 7) — catálogo das peças recortadas das folhas do GPT
## (hz_1..hz_7) e ajudantes de desenho para os `_draw` dos perigos.
##
## As peças saem de `tools/hazards7/cut_hazards.py` → `assets/painted/hazards/`
## (PNG com alfa real + `_sil` = silhueta branca) e o catálogo
## `hazards_data.gd` (tamanho e âncora em pixels de MUNDO). Cada perigo
## desenha a pintura e, POR CIMA, o aviso por código (contorno pulsante,
## sombra, brilho) — o telegrafo nunca fica escondido pela arte.
## Sem a textura (ou com `force_code`), o perigo cai no `_draw` antigo.

const DATA_PATH := "res://assets/painted/hazards/hazards_data.gd"
## Pulso do aviso: 2 Hz (abaixo de 3 flashes/s — NEURO_SATISFACAO R10).
const WARN_HZ := 2.0

## Ferramenta de prancha (antes/depois): força o desenho antigo por código.
static var force_code: bool = false
static var _data: Dictionary = {}
static var _loaded: bool = false
static var _tex: Dictionary = {}


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if ResourceLoader.exists(DATA_PATH):
			var scr = load(DATA_PATH)
			if scr != null:
				var d = scr.get("DATA")
				if d == null and scr is GDScript:
					d = (scr as GDScript).get_script_constant_map().get("DATA", {})
				if d is Dictionary:
					_data = d
	return _data


## A peça existe (catálogo + textura) e a pintura está ligada?
static func has(piece: String) -> bool:
	if force_code:
		return false
	return data().has(piece) and tex(piece, 0) != null


static func info(piece: String) -> Dictionary:
	return data().get(piece, {})


static func frames(piece: String) -> int:
	return (info(piece).get("frames", []) as Array).size()


static func size(piece: String) -> Vector2:
	var s: Array = info(piece).get("size", [0, 0])
	return Vector2(float(s[0]), float(s[1]))


static func anchor(piece: String) -> Vector2:
	var a: Array = info(piece).get("anchor", [0, 0])
	return Vector2(float(a[0]), float(a[1]))


## Ponto extra do catálogo (ex.: "center", "eye", "flame") em mundo.
static func point(piece: String, key: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var p = info(piece).get(key, null)
	if p is Array and (p as Array).size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	return fallback


static func num(piece: String, key: String, fallback: float = 0.0) -> float:
	var v = info(piece).get(key, null)
	return float(v) if v != null else fallback


static func _load(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func tex(piece: String, frame: int = 0) -> Texture2D:
	var fr: Array = info(piece).get("frames", [])
	if fr.is_empty():
		return null
	return _load(String(fr[clampi(frame, 0, fr.size() - 1)]))


static func sil(piece: String, frame: int = 0) -> Texture2D:
	var fr: Array = info(piece).get("sil", [])
	if fr.is_empty():
		return null
	return _load(String(fr[clampi(frame, 0, fr.size() - 1)]))


## Prepara o nó que desenha pintura: filtro com mipmaps (como o resto da arte
## pintada — sem borrão nem serrilhado na escala do jogo).
static func setup(ci: CanvasItem) -> void:
	ci.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## Desenha o quadro com a ÂNCORA em `at` (coordenadas locais do `ci`).
static func draw(ci: CanvasItem, piece: String, frame: int, at: Vector2, rot: float = 0.0,
		scl: Vector2 = Vector2.ONE, mod: Color = Color.WHITE) -> bool:
	var t := tex(piece, frame)
	if t == null:
		return false
	ci.draw_set_transform(at, rot, scl)
	ci.draw_texture_rect(t, Rect2(-anchor(piece), size(piece)), false, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


## Só uma faixa do quadro (`src` em fração 0..1 da textura) num retângulo do
## mundo (local, sem âncora). Lanças subindo da fenda, por exemplo.
static func draw_part(ci: CanvasItem, piece: String, frame: int, src: Rect2, dst: Rect2,
		mod: Color = Color.WHITE) -> bool:
	var t := tex(piece, frame)
	if t == null or src.size.x <= 0.0 or src.size.y <= 0.0:
		return false
	var ts := Vector2(t.get_width(), t.get_height())
	ci.draw_texture_rect_region(t, dst, Rect2(src.position * ts, src.size * ts), mod)
	return true


## Corrente LADRILHADA de `from` até `to` (elos repetidos, último cortado).
static func draw_chain(ci: CanvasItem, piece: String, from: Vector2, to: Vector2, mod: Color = Color.WHITE) -> bool:
	var t := tex(piece, 0)
	if t == null:
		return false
	var sz := size(piece)
	var an := anchor(piece)
	var d := to - from
	var total := d.length()
	if total < 1.0 or sz.y <= 0.0:
		return true
	var rot := d.angle() - PI * 0.5        # o elo da folha é vertical (desce em +y)
	ci.draw_set_transform(from, rot, Vector2.ONE)
	var y := 0.0
	while y < total:
		var h := minf(sz.y, total - y)
		var fr := h / sz.y
		ci.draw_texture_rect_region(t, Rect2(-an.x, y, sz.x, h), Rect2(0, 0, t.get_width(), t.get_height() * fr), mod)
		y += sz.y
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


## CONTORNO DE AVISO: a silhueta da peça em `col`, deslocada em 8 direções
## (`width` px de mundo) — desenhe ANTES da pintura para virar uma borda.
static func draw_outline(ci: CanvasItem, piece: String, frame: int, at: Vector2, col: Color,
		width: float = 1.5, rot: float = 0.0, scl: Vector2 = Vector2.ONE) -> void:
	var t := sil(piece, frame)
	if t == null or col.a <= 0.01:
		return
	var r := Rect2(-anchor(piece), size(piece))
	for k in 8:
		var d := Vector2.RIGHT.rotated(TAU * float(k) / 8.0) * width
		ci.draw_set_transform(at + d, rot, scl)
		ci.draw_texture_rect(t, r, false, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## VÉU de cor sobre a pintura (silhueta translúcida): o "acende" do aviso
## sem escurecer a arte (tingir por multiplicação escurece — R5).
static func draw_wash(ci: CanvasItem, piece: String, frame: int, at: Vector2, col: Color,
		rot: float = 0.0, scl: Vector2 = Vector2.ONE) -> void:
	var t := sil(piece, frame)
	if t == null or col.a <= 0.01:
		return
	ci.draw_set_transform(at, rot, scl)
	ci.draw_texture_rect(t, Rect2(-anchor(piece), size(piece)), false, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Pulso do aviso 0..1 a 2 Hz (`t` = relógio do perigo).
static func pulse(t: float) -> float:
	return 0.5 + 0.5 * sin(t * TAU * WARN_HZ)


## Fator dos brilhos com a opção "Reduzir flashes" (R10): metade.
static func flash_k() -> float:
	var j = Engine.get_main_loop().root.get_node_or_null("Juice") if Engine.get_main_loop() is SceneTree else null
	if j != null and bool(j.get("reduce_flashes")):
		return 0.5
	return 1.0


## CAMADA DE TRÁS: nó filho desenhado ATRÁS dos lutadores (z absoluto `z`),
## pelo `cb(layer)` do dono. A moldura da guilhotina fica atrás da Sophia e a
## lâmina, na frente. O dono chama `layer.queue_redraw()` quando muda.
static func back_layer(owner: Node2D, cb: Callable, z: int = -1) -> Node2D:
	var n := Node2D.new()
	n.name = "ArtBack"
	n.z_as_relative = false
	n.z_index = z
	setup(n)
	n.draw.connect(cb.bind(n))
	owner.add_child(n)
	return n
