extends LevelHazard
class_name DarkTide
## FUGA — a ESCURIDÃO que persegue. Quando a Sophia sai da zona anterior, uma
## parede de breu com olhos acorda atrás dela e avança (110 → 150 px/s; a Sophia
## corre a 185). Quem fica pra trás é corroído (dano a cada 0,45 s). A maré para
## e se desfaz na borda da próxima zona: a fuga é um respiro com urgência, não
## uma armadilha. Parar pra quebrar um casulo, ler uma Estela... custa.

const SPEED0 := 110.0
const SPEED1 := 150.0
const ACCEL_TIME := 4.0
const TICK := 0.45

var start_x: float = 0.0       # de onde a maré nasce (mundo)
var end_x: float = 600.0       # onde ela morre (mundo)
var _front: float = 0.0        # x da frente da maré (mundo)
var _running: bool = false
var _done: bool = false
var _run_t: float = 0.0
var _tick_cd: float = 0.0
var _fade: float = 1.0


func _ready() -> void:
	hazard_kind = "tide"
	z_index = 26                   # na frente dos lutadores (é uma parede)
	z_as_relative = false
	_front = start_x


func _tick(delta: float) -> void:
	var p := _player()
	if p == null:
		return
	var lv := get_parent()
	var locked: bool = lv != null and "zone_active" in lv and bool(lv.get("zone_active"))
	if not _running and not _done:
		# acorda quando ela passa do ponto de partida (sem zona trancada)
		if not locked and p.global_position.x > start_x + 140.0:
			_running = true
			Audio.play_sfx_at("fog_swell", p.global_position, 0.05)
		return
	if _done:
		_fade = maxf(0.0, _fade - delta * 1.5)
		if _fade <= 0.0:
			queue_free()
		return
	if GameManager.state != GameManager.State.PLAYING:
		return
	_run_t += delta
	var spd := lerpf(SPEED0, SPEED1, clampf(_run_t / ACCEL_TIME, 0.0, 1.0))
	_front = minf(end_x, _front + spd * delta)
	if _front >= end_x or locked:
		_done = true
		return
	_tick_cd = maxf(0.0, _tick_cd - delta)
	if _tick_cd <= 0.0 and _live() and p.global_position.x < _front:
		_tick_cd = TICK
		hurt_player(hazard_damage(3), Vector2(_front - 40.0, p.global_position.y), 160.0, true)


func _draw() -> void:
	if not _running and not _done:
		return
	var fx := _front - global_position.x
	var dark := Color(0.03, 0.02, 0.06, 0.94 * _fade)
	# corpo da maré: retângulo até a frente, com borda em tentáculos
	draw_rect(Rect2(fx - 1400.0, -420.0, 1400.0, 520.0), dark)
	var pts := PackedVector2Array()
	pts.append(Vector2(fx, -420.0))
	for i in 24:
		var y := -420.0 + float(i) * 22.0
		var wob := sin(_t * 3.0 + float(i) * 0.9) * 10.0 + sin(_t * 7.0 + float(i) * 2.3) * 4.0
		pts.append(Vector2(fx + 18.0 + wob, y))
	pts.append(Vector2(fx, 100.0))
	draw_colored_polygon(pts, dark)
	# olhos na escuridão
	for i in 4:
		var ey := -40.0 - float(i) * 56.0 + sin(_t + i) * 6.0
		var ex := fx - 14.0 - float(i % 2) * 24.0
		var blink := 1.0 if fmod(_t * 0.7 + float(i) * 0.31, 2.6) > 0.1 else 0.0
		for sx in [-3.0, 3.0]:
			draw_circle(Vector2(ex + sx, ey), 1.6, Color(0.9, 0.4, 1.0, 0.9 * blink * _fade))
	# névoa na frente
	draw_rect(Rect2(fx + 10.0, -420.0, 60.0, 520.0), Color(0.08, 0.04, 0.12, 0.25 * _fade))
