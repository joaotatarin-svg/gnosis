extends Node2D
class_name SparkOrb
## Faísca libertada: orbe de luz que explode do Arconte morto e VOA até o
## herói (a assinatura do God of War). As faíscas já foram creditadas na morte;
## o orbe é a "entrega" sensorial (R6, NEURO_SATISFACAO):
##  - as chegadas saem espaçadas (~55 ms, ordem do índice), formando um arpejo;
##  - ao CHEGAR, toca "spark" (o Áudio sobe a escala pentatônica em sequência)
##    e avisa o HUD (`spark_orb_arrived`) para o contador subir 1 a 1.

const ARRIVAL_STEP := 0.055      # s entre chegadas (40–70 ms; o anti-spam do Áudio é 40)
const HOMING_RATE := 3.2         # quão rápido a atração cresce (1/s)
const SPREAD_SPEED := 150.0      # px/s do leque inicial
const ARRIVE_DIST := 16.0
const TURN_GAIN := 14.0          # quanto a curva aperta com a atração (anti-órbita)
const MAX_FLIGHT := 2.2          # s de jogo: passou disto, entrega na marra

var _vel: Vector2
var _time: float = 0.0
var _homing: float = 0.0
var index: int = 0               # ordem no burst (0..count-1)
var count: int = 1
var _delay: float = 0.0          # atraso da atração (espaça as chegadas)
var color := Color(1.0, 0.9, 0.5)
var _group: _Burst                # fila de chegada compartilhada pelo burst
var delivered: bool = false       # chegou na Sophia (as sondas leem)


## Fila de chegadas de um burst: nenhum orbe "entrega" antes de ARRIVAL_STEP
## (tempo REAL) depois do anterior — o arpejo não embola e o anti-spam do
## Áudio (40 ms) nunca engole uma nota.
class _Burst extends RefCounted:
	var next_ms: int = 0


static func burst(parent: Node, pos: Vector2, n: int) -> void:
	var g := _Burst.new()
	for i in n:
		var o := SparkOrb.new()
		o._group = g
		o.index = i
		o.count = n
		o._delay = float(i) * ARRIVAL_STEP
		parent.add_child(o)
		o.global_position = pos
		# Leque para cima, simétrico, com um pouco de vida (não é sorteio de
		# recompensa: a quantidade é sempre a mesma por inimigo).
		var a := -PI * 0.5 + (float(i) - float(n - 1) * 0.5) * 0.42 + randf_range(-0.08, 0.08)
		o._vel = Vector2(cos(a), sin(a)) * SPREAD_SPEED * randf_range(0.92, 1.08)
		o.z_index = 40


func _process(delta: float) -> void:
	_time += delta
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		# primeiro espalha, depois é "sugada" pelo herói com força crescente
		if _time > _delay:
			_homing = minf(_homing + delta * HOMING_RATE, 1.0)
		var to: Vector2 = (player.global_position + Vector2(0, -10)) - global_position
		var pull := to.normalized() * (700.0 * _homing * _homing)
		if _homing > 0.0:
			# vira cada vez mais firme conforme a atração cresce: sem órbita em
			# volta dela (antes uns orbes rodavam e sumiam sem chegar)
			_vel = _vel.lerp(pull, minf(1.0, delta * (6.0 + TURN_GAIN * _homing)))
		else:
			_vel = _vel.move_toward(Vector2.ZERO, 260.0 * delta)   # paira no leque
		var step: float = _vel.length() * delta
		global_position += _vel * delta
		# chegou (ou o passo deste quadro a atravessaria), ou o tempo acabou:
		# todo orbe ENTREGA — o HUD conta 1 a 1 e não pode perder nenhum
		var arrived: bool = to.length() < maxf(ARRIVE_DIST, step * 1.2) and _time > 0.15
		if arrived or _time > MAX_FLIGHT:
			var now := Time.get_ticks_msec()
			if _group == null or now >= _group.next_ms or _time > MAX_FLIGHT + 0.5:
				if _group != null:
					_group.next_ms = now + int(ARRIVAL_STEP * 1000.0)
				_arrive()
				return
			# na fila: gruda nela até a vez dele (dura no máximo uns 50 ms)
			global_position = player.global_position + Vector2(0, -10) - to.normalized() * 6.0
			_vel = Vector2.ZERO
	else:
		global_position += _vel * delta
	if _time > MAX_FLIGHT + 1.0:      # sem Sophia na tela: some
		queue_free()
		return
	queue_redraw()


## Chegou na Sophia: brilho + som + HUD conta 1.
func _arrive() -> void:
	delivered = true
	ImpactBurst.spawn(get_parent(), global_position, color)
	Audio.play_sfx("spark")
	for h in get_tree().get_nodes_in_group("hud"):
		if h.has_method("spark_orb_arrived"):
			h.spark_orb_arrived()
	queue_free()


func _draw() -> void:
	var pulse := 1.0 + sin(_time * 20.0) * 0.2
	draw_circle(Vector2.ZERO, 5.0 * pulse, Color(color.r, color.g, color.b, 0.25))
	draw_circle(Vector2.ZERO, 2.6, color)
	draw_circle(Vector2.ZERO, 1.1, Color(1, 1, 1, 0.95))
