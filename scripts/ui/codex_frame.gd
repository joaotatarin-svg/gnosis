extends StyleBox
class_name CodexFrame
## Moldura do Códex desenhada por código (StyleBox com `_draw`): cantos
## chanfrados, preenchimento em degradê vertical, filete dourado, filete
## interno opcional e ornamentos (losangos laterais = foco de botão;
## cantoneiras = painel). Serve pra botões, painéis, caixas de diálogo.
## Unidades na base 640×360 — a janela 1280×720 desenha tudo em 2×, então
## larguras de 0.5 viram o "fio de cabelo" de 1 px real.

enum Marks { NONE, SIDES, CORNERS }

var fill_top: Color = Color("12252e")
var fill_bottom: Color = Color("0a151c")
var border: Color = Color(0.77, 0.65, 0.42, 0.45)
var border_width: float = 1.0
var inner: Color = Color(0, 0, 0, 0)        # filete interno (alfa 0 = sem)
var inner_inset: float = 2.5
var chamfer: float = 4.0
var marks: int = Marks.NONE
var mark_color: Color = Color("e8cf94")
var glow: Color = Color(0, 0, 0, 0)         # halo externo (foco)
var shadow: float = 0.0                     # sombra projetada (painéis)


func _draw(ci: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	if shadow > 0.0:
		for i in 3:
			var g := shadow * (1.0 - float(i) / 3.0)
			var gr := rect.grow(g)
			gr.position.y += shadow * 0.35
			var sp := _chamfered(gr, chamfer + g)
			rs.canvas_item_add_polygon(ci, sp, PackedColorArray([Color(0, 0, 0, 0.13)]))
	if glow.a > 0.0:
		# Halo em anéis (contorno), não preenchido: o estilo de FOCO é desenhado
		# por cima do botão e não pode velar o fundo.
		for k in [[3.0, 1.2, 0.22], [1.6, 1.2, 0.5]]:
			var gp := _chamfered(rect.grow(k[0]), chamfer + k[0])
			gp.append(gp[0])
			rs.canvas_item_add_polyline(ci, gp, PackedColorArray([Color(glow, glow.a * k[2])]), k[1], true)
	var pts := _chamfered(rect, chamfer)
	if fill_top.a > 0.0 or fill_bottom.a > 0.0:
		var cols := PackedColorArray()
		for p in pts:
			var t := clampf((p.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)
			cols.append(fill_top.lerp(fill_bottom, t))
		rs.canvas_item_add_polygon(ci, pts, cols)
	if border.a > 0.0 and border_width > 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		rs.canvas_item_add_polyline(ci, loop, PackedColorArray([border]), border_width, true)
	if inner.a > 0.0 and rect.size.x > inner_inset * 4.0 and rect.size.y > inner_inset * 4.0:
		var ip := _chamfered(rect.grow(-inner_inset), maxf(1.0, chamfer - inner_inset * 0.5))
		ip.append(ip[0])
		rs.canvas_item_add_polyline(ci, ip, PackedColorArray([inner]), 0.5, true)
	match marks:
		Marks.SIDES:
			var cy := rect.position.y + rect.size.y * 0.5
			_diamond(ci, Vector2(rect.position.x, cy), 3.2, mark_color)
			_diamond(ci, Vector2(rect.end.x, cy), 3.2, mark_color)
		Marks.CORNERS:
			_corners(ci, rect)


## Retângulo com os quatro cantos cortados em 45°.
static func _chamfered(r: Rect2, c: float) -> PackedVector2Array:
	c = minf(c, minf(r.size.x, r.size.y) * 0.5)
	var a := r.position
	var b := r.end
	return PackedVector2Array([
		Vector2(a.x + c, a.y), Vector2(b.x - c, a.y), Vector2(b.x, a.y + c), Vector2(b.x, b.y - c),
		Vector2(b.x - c, b.y), Vector2(a.x + c, b.y), Vector2(a.x, b.y - c), Vector2(a.x, a.y + c),
	])


static func _diamond(ci: RID, c: Vector2, s: float, col: Color) -> void:
	RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)]),
		PackedColorArray([col]))


## Cantoneiras: um "L" dourado em cada canto + um losango pequeno na ponta.
func _corners(ci: RID, r: Rect2) -> void:
	var L := minf(14.0, minf(r.size.x, r.size.y) * 0.25)
	var o := 3.0
	var col := PackedColorArray([mark_color])
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var sx := 1.0 if corner.x == 0.0 else -1.0
		var sy := 1.0 if corner.y == 0.0 else -1.0
		var p := Vector2(r.position.x + r.size.x * corner.x + o * sx, r.position.y + r.size.y * corner.y + o * sy)
		RenderingServer.canvas_item_add_polyline(ci, PackedVector2Array([
			p + Vector2(L * sx, 0), p + Vector2(chamfer * 0.6 * sx, 0), p + Vector2(0, chamfer * 0.6 * sy), p + Vector2(0, L * sy)]),
			col, 1.0, true)
		_diamond(ci, p + Vector2(L * sx + 2.5 * sx, 0), 1.6, mark_color)
		_diamond(ci, p + Vector2(0, L * sy + 2.5 * sy), 1.6, mark_color)
