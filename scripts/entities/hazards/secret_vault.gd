extends Node2D
class_name SecretVault
## SALA SECRETA — a câmara lá no alto (plataforma em Y3, ~176 px acima do chão)
## e a PORTA SELADA embaixo, no chão: correntes e um selo de asas. A porta não
## abre — o caminho é por cima: a saliência de PULO DUPLO ao lado leva à câmara.
## Só desenho (as plataformas e os baús são montados pelo LayoutBuilder).

var room_w: float = 260.0
var room_y: float = -170.0         # topo da câmara em relação ao chão (local)
var hazard_kind: String = "vault"
var _t: float = 0.0
var _door: int = -1           # quadro da porta (0 selada, 1 reage, 2 aberta)
var _door_cd: float = 0.0


func _enter_tree() -> void:
	add_to_group("lv6_objective")


func _ready() -> void:
	z_index = -2
	HazardArt.setup(self)


func _process(delta: float) -> void:
	_t += delta
	_door_cd -= delta
	if _door_cd <= 0.0:
		_door_cd = 0.25
		var f := _door_frame()
		if f == 2 and _door >= 0 and _door < 2:
			Audio.play_sfx_at("hz_secret_open", global_position, 0.05)
		_door = f
	queue_redraw()


func _door_frame() -> int:
	var lv := get_parent()
	if lv != null:
		var total := 0
		var open := 0
		for c in lv.get_children():
			if c is Chest and c.secret:
				total += 1
				if c.opened:
					open += 1
		if total > 0 and open >= total:
			return 2
	if Progression.has_method("has_double_jump") and bool(Progression.call("has_double_jump")):
		return 1
	return 0


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
	# a porta selada no chão (pintura, Onda 7): selada → o selo REAGE quando a
	# Sophia já tem o pulo duplo (o caminho por cima existe) → ABERTA quando os
	# baús secretos da tela foram abertos (só desenho: a porta não é passagem)
	if HazardArt.has("vault_door"):
		HazardArt.draw(self, "vault_door", maxi(0, _door), Vector2.ZERO)
		return
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
