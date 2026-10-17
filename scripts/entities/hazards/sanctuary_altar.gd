extends Node2D
class_name SanctuaryAltar
## SANTUÁRIO — o ALTAR de repouso: uma bacia de luz da Mônada no meio da
## passagem calma. Passar por ele cura 25 % da vida (uma vez) e acende a luz.
## A cura inteira do santuário é paga pelo mapa na tela seguinte; este é o
## lugar VISÍVEL do repouso (o respiro entre as lutas).

const RADIUS := 40.0

var used: bool = false
var hazard_kind: String = "altar"
var _t: float = 0.0
var _glow: float = 0.0


func _enter_tree() -> void:
	add_to_group("lv6_objective")


func _ready() -> void:
	z_index = -1


func _physics_process(delta: float) -> void:
	_t += delta
	_glow = maxf(0.0, _glow - delta * 0.5)
	queue_redraw()
	if used or GameManager.state != GameManager.State.PLAYING:
		return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.health == null or p.health.is_dead():
		return
	if absf(p.global_position.x - global_position.x) < RADIUS and p.global_position.y > 240.0:
		used = true
		_glow = 1.0
		p.health.heal(int(p.health.max_health * 0.25))
		AoeNova.spawn(get_parent(), global_position + Vector2(0, -20), 0, 60.0, Color(1.0, 0.95, 0.75))
		Audio.play_sfx_at("sleeper_wake", global_position, 0.05)
		get_tree().call_group("hud", "toast", "O altar te acalma.")


func _draw() -> void:
	var gold := Color(1.0, 0.92, 0.65)
	var stone := Color(0.2, 0.2, 0.24)
	# coluna de luz (forte antes de usar; brasa depois)
	var a := 0.12 if not used else 0.04 + 0.2 * _glow
	draw_rect(Rect2(-10, -150, 20, 150), Color(gold, a * 0.6))
	draw_rect(Rect2(-4, -150, 8, 150), Color(gold, a))
	# altar: base, haste e bacia (contorno escuro + pedra)
	draw_rect(Rect2(-22, -8, 44, 8), LevelHazard.INK)
	draw_rect(Rect2(-20, -7, 40, 6), stone)
	draw_rect(Rect2(-7, -30, 14, 23), LevelHazard.INK)
	draw_rect(Rect2(-5, -29, 10, 22), stone.lightened(0.1))
	var bowl := PackedVector2Array([Vector2(-20, -38), Vector2(20, -38), Vector2(13, -28), Vector2(-13, -28)])
	draw_colored_polygon(bowl, LevelHazard.INK)
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -37), Vector2(18, -37), Vector2(12, -29), Vector2(-12, -29)]), stone.lightened(0.15))
	# a água de luz na bacia
	var lum := 0.9 if not used else 0.35
	draw_line(Vector2(-16, -37), Vector2(16, -37), Color(gold, lum), 2.0, true)
	for i in 4:
		var ph := fposmod(_t * 0.35 + float(i) * 0.25, 1.0)
		draw_circle(Vector2(sin(float(i) * 1.9 + _t) * 9.0, -40.0 - ph * 40.0), 1.3, Color(gold, (1.0 - ph) * lum))
