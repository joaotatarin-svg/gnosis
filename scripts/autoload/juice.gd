extends Node
## "Juice" = feedback que dá peso ao combate: hitstop, screen shake e câmera
## lenta (finisher / esquiva perfeita). Autoload acessível como `Juice`.

signal shake_requested(trauma: float)

var _hitstop_active := false
var _base_scale := 1.0          # escala "de fundo" (speed_mult ou a do slow-mo ativo)
var _slow_token := 0

## Velocidade global do jogo (1.0 normal; >1 só em ferramentas — bot de balance).
var speed_mult := 1.0:
	set(v):
		speed_mult = v
		_base_scale = v
		Engine.time_scale = v


## Micro-congelamento no impacto. Usa timer em tempo real (ignora time_scale)
## pra funcionar mesmo com o jogo "parado". Ao soltar, volta pra escala de fundo
## (respeita um slow-mo em andamento).
func hit_stop(duration: float = 0.06) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.05
	# create_timer(tempo, process_always, process_in_physics, ignore_time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = _base_scale
	_hitstop_active = false


## Câmera lenta por `duration` segundos REAIS (finisher, esquiva perfeita).
## Um slow-mo novo substitui o anterior.
func slow_mo(scale: float = 0.25, duration: float = 0.6) -> void:
	_slow_token += 1
	var my := _slow_token
	_base_scale = scale
	if not _hitstop_active:
		Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if my != _slow_token:
		return                       # outro slow-mo assumiu
	_base_scale = speed_mult
	if not _hitstop_active:
		Engine.time_scale = speed_mult


## Pede tremor de câmera (a Camera2D com camera_shake.gd escuta).
func shake(trauma: float = 0.4) -> void:
	shake_requested.emit(trauma)


## Vibração do controle (Xbox/DualShock/genérico com rumble). Curta e discreta —
## só nos momentos que o corpo sente: dano, parry, esquiva perfeita, chefe caindo.
## weak = motor fino (agudo) · strong = motor grosso (grave) · dur em segundos.
func rumble(weak: float, strong: float, dur: float) -> void:
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, weak, strong, dur)
