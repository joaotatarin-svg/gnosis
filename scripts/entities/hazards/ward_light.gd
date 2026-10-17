extends Node2D
class_name WardLight
## OBJETIVO "PROTEGER" — a LUZ DE UM ADORMECIDO na zona: uma lamparina que os
## Arcontes querem apagar. Inimigos perto dela (≤ 70 px) a drenam; a luta
## longe dela a preserva. Se a zona acabar com a luz acesa: faíscas, cura e o
## Adormecido agradece. Apagou: nada se perde além do prêmio (sem falha dura).
## A jogada: puxar a briga pra longe da luz (posição, não só dano).

const DRAIN := 7.0            # luz/s por inimigo perto
const NEAR := 70.0

var hazard_kind: String = "ward"
var screen: int = 1
var light: float = 100.0
var _armed: bool = false
var _done: bool = false
var _t: float = 0.0
var _drain_now: bool = false


func _enter_tree() -> void:
	add_to_group("lv6_objective")


func arm() -> void:
	_armed = true


## A zona acabou: luz acesa = prêmio.
func finish() -> void:
	if _done:
		return
	_done = true
	_armed = false
	if light > 0.0:
		var gold := Color(1.0, 0.92, 0.55)
		Progression.add_orbs(10 + int(screen * 1.5))
		var p := get_tree().get_first_node_in_group("player")
		if p != null and p.get("health") != null:
			p.health.heal(int(p.health.max_health * 0.15))
		AoeNova.spawn(get_parent(), global_position + Vector2(0, -20), 0, 70.0, gold)
		Audio.play_sfx_at("sleeper_wake", global_position, 0.05)
		get_tree().call_group("hud", "toast", "A luz resistiu: o Adormecido te devolve forças.")
	else:
		get_tree().call_group("hud", "toast", "A luz se apagou.")


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	_drain_now = false
	if not _armed or _done or light <= 0.0 or GameManager.state != GameManager.State.PLAYING:
		return
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and is_instance_valid(e) and e.estate != Enemy.EState.DEAD:
			if (e as Node2D).global_position.distance_to(global_position + Vector2(0, -10)) < NEAR:
				n += 1
	if n > 0:
		_drain_now = true
		light = maxf(0.0, light - DRAIN * float(n) * delta)
		if light <= 0.0:
			Audio.play_sfx_at("cast_fail", global_position, 0.05)
			ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -30), Color(0.4, 0.4, 0.5))


func _draw() -> void:
	var gold := Color(1.0, 0.88, 0.5)
	var k := light / 100.0
	# alcance da drenagem (lê "não deixe chegarem aqui")
	if _armed and light > 0.0:
		draw_set_transform(Vector2(0, 2), 0, Vector2(1, 0.25))
		draw_arc(Vector2.ZERO, NEAR, 0, TAU, 32, Color(gold, 0.25 + (0.35 if _drain_now else 0.0)), 1.5, true)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# pedestal + lamparina
	draw_rect(Rect2(-7, -18, 14, 18), LevelHazard.INK)
	draw_rect(Rect2(-5, -17, 10, 16), Color(0.25, 0.22, 0.2))
	draw_rect(Rect2(-9, -34, 18, 16), LevelHazard.INK)
	draw_rect(Rect2(-7, -32, 14, 12), Color(0.15, 0.12, 0.1))
	if light > 0.0:
		var flick := 0.85 + 0.15 * sin(_t * 13.0) + (0.25 * sin(_t * 40.0) if _drain_now else 0.0)
		draw_circle(Vector2(0, -27), (14.0 + 8.0 * k) * flick, Color(gold, 0.10 * k + 0.04))
		draw_circle(Vector2(0, -27), 4.0 + 2.0 * k * flick, Color(gold, 0.95))
	# barra da luz
	draw_rect(Rect2(-16, -46, 32, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-16, -46, 32.0 * k, 3), Color(gold, 0.9))
