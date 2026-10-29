extends LevelHazard
class_name MirrorBeam
## ESPELHO — dois cacos de espelho fincados no chão trocam um FEIXE de luz rente
## ao piso. Ritmo de 3 s: apagado → AVISO 0,5 s (fio fino piscando) → feixe
## aceso 1,2 s. Passe apagado, pule por cima (o feixe é baixo) ou esquive. Corta
## inimigos também.

const PERIOD := 3.0
const WARN_AT := 1.3
const ON_AT := 1.8
const BEAM_Y := -16.0         # altura do feixe (local; o chão é 0)

var width: float = 180.0
var _cd: float = 0.0
var _warned: bool = false


func _ready() -> void:
	hazard_kind = "beam"
	z_index = 4


func _state() -> int:
	var c := _cycle(PERIOD)
	if c >= ON_AT:
		return 2
	if c >= WARN_AT:
		return 1
	return 0


func _tick(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	var st := _state()
	if st == 1 and not _warned:
		_warned = true
		var p0 := _player()
		if p0 != null and absf(p0.global_position.x - global_position.x) < 300.0:
			Audio.play_sfx_at("tell_unblock", global_position, 0.05)
	elif st == 0:
		_warned = false
	if st != 2 or _cd > 0.0:
		return
	var y := global_position.y + BEAM_Y
	var area := Rect2(global_position.x - width * 0.5, y - 40.0, width, 46.0)
	if hurt_enemies_in(area, hazard_damage(4) * 2, global_position + Vector2(0, BEAM_Y), 120.0) > 0:
		_cd = 0.5
	var p := _player()
	if _live() and absf(p.global_position.x - global_position.x) < width * 0.5 and p.global_position.y + 12.0 > y - 3.0 and p.global_position.y < y + 20.0:
		hurt_player(hazard_damage(4), Vector2(p.global_position.x - signf(p.velocity.x + 0.01) * 20.0, y), 150.0, true)
		_cd = 0.6


func _draw() -> void:
	var hw := width * 0.5
	var glass := Color(0.75, 0.95, 1.0)
	# os dois cacos (silhueta escura + fio claro)
	for sx in [-1.0, 1.0]:
		var bx: float = sx * hw
		var shard := PackedVector2Array([Vector2(bx - 7, 0), Vector2(bx - 2, -42), Vector2(bx + 6, -30), Vector2(bx + 8, 0)])
		draw_colored_polygon(shard, INK)
		draw_polyline(PackedVector2Array([Vector2(bx - 2, -40), Vector2(bx + 5, -29), Vector2(bx + 7, -2)]), Color(glass, 0.7), 1.2, true)
		draw_circle(Vector2(bx, BEAM_Y), 3.0, Color(glass, 0.6))
	var st := _state()
	if st == 1:
		# AVISO (Onda 7): linha com sublinhado escuro pulsando a 2 Hz (antes:
		# fio de 1 px piscando a ~6 Hz — R10/R18) + brilho nos dois cacos (forma)
		var pk := HazardArt.pulse(_t)
		warn_line(Vector2(-hw, BEAM_Y), Vector2(hw, BEAM_Y), Color(WARN_COL, 0.45 + 0.4 * pk), 1.6)
		for sx in [-1.0, 1.0]:
			draw_circle(Vector2(sx * hw, BEAM_Y), 4.0 + 3.0 * pk, Color(WARN_COL, 0.35 + 0.3 * pk))
	elif st == 2:
		draw_line(Vector2(-hw, BEAM_Y), Vector2(hw, BEAM_Y), Color(glass, 0.25), 12.0, true)
		draw_line(Vector2(-hw, BEAM_Y), Vector2(hw, BEAM_Y), Color(glass, 0.6), 5.0, true)
		draw_line(Vector2(-hw, BEAM_Y), Vector2(hw, BEAM_Y), Color(1, 1, 1, 0.95), 1.6, true)
		# reflexo no chão
		draw_line(Vector2(-hw, 3), Vector2(hw, 3), Color(glass, 0.12), 4.0, true)
