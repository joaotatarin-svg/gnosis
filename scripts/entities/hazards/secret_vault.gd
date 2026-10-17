extends Node2D
class_name SecretVault
## SALA SECRETA — a câmara lá no alto (plataforma em Y3, ~176 px acima do chão)
## e a PORTA SELADA embaixo, no chão: correntes e um selo de asas. A porta não
## abre — o caminho é por cima: a saliência de PULO DUPLO ao lado leva à câmara.
## Só desenho (as plataformas e os baús são montados pelo LayoutBuilder).

var room_w: float = 260.0
var room_y: float = -170.0         # topo da câmara em relação ao chão (local)
var hazard_kind: String = "sala secreta"
var _t: float = 0.0


func _enter_tree() -> void:
	add_to_group("lv6_objective")


func _ready() -> void:
	z_index = -2


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var hw := room_w * 0.5
	var stone := Color(0.1, 0.1, 0.13, 0.85)
	var gold := Color(1.0, 0.85, 0.45)
	# a câmara: fundo escuro em arco por trás da plataforma alta
	var arch := PackedVector2Array([Vector2(-hw, room_y + 4.0), Vector2(-hw, room_y - 70.0)])
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		arch.append(Vector2(cos(a) * hw, room_y - 70.0 + sin(a) * 34.0))
	arch.append(Vector2(hw, room_y + 4.0))
	draw_colored_polygon(arch, stone)
	draw_polyline(arch, Color(gold, 0.35), 1.2, true)
	# brilho do tesouro lá dentro
	draw_circle(Vector2(0, room_y - 30.0), 46.0, Color(gold, 0.05 + 0.03 * sin(_t * 2.0)))
	# a porta selada no chão: arco fechado com correntes em X e o selo de asas
	var dw := 30.0
	draw_rect(Rect2(-dw, -78.0, dw * 2.0, 78.0), Color(0.06, 0.06, 0.08, 0.95))
	draw_rect(Rect2(-dw, -78.0, dw * 2.0, 78.0), Color(gold, 0.25), false, 1.2)
	var chain := Color(0.6, 0.6, 0.68)
	draw_line(Vector2(-dw, -74), Vector2(dw, -4), chain, 2.0)
	draw_line(Vector2(dw, -74), Vector2(-dw, -4), chain, 2.0)
	var seal := Vector2(0, -40)
	draw_circle(seal, 9.0, Color(0.15, 0.12, 0.08))
	draw_arc(seal, 9.0, 0, TAU, 20, Color(gold, 0.7), 1.2, true)
	for sx in [-1.0, 1.0]:
		draw_polyline(PackedVector2Array([seal + Vector2(sx * 2, 0), seal + Vector2(sx * 7, -4), seal + Vector2(sx * 6, 2)]), Color(gold, 0.8), 1.0, true)
