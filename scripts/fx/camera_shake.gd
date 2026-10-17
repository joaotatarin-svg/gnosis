extends Camera2D
## Câmera da Sophia: enquadramento, antecipação (look-ahead), tremor por trauma
## (ruído contínuo) e "chute" direcional dos golpes. Escuta o autoload Juice.
##
## Por que assim (docs/COMBATE.md §2): no Godot 4 o `offset` da Camera2D é somado
## DEPOIS do clamp de `limit_*`. Antes, o look-ahead (±90 px) e o enquadramento
## iam no `offset` e escapavam dos limites: com a zona recém-trancada e a Sophia
## perto da parede, ela saía do quadro (QA_UX A5). Agora o look-ahead e o
## enquadramento vão no ALVO da câmera (que respeita os limites) e o `offset`
## fica só para o tremor e o chute (poucos px).
##
## A câmera é `top_level` e segue o corpo por código no `_physics_process` (com a
## interpolação de física ligada, o Godot interpola a câmera junto do corpo).
## Tremor e chute correm no `_process` em tempo REAL (não travam no slow-mo).
## Os limites pedidos pela fase (`limit_*`) entram deslizando: a zona que tranca
## não dá tranco de câmera.

const ZOOM := 1.2                 # presença da Sophia (1.0 = antigo). Faixa testada: 1,15–1,25.
const LOOK_AHEAD := 64.0          # px de mundo à frente de onde ela olha
const LOOK_SPEED := 160.0         # px/s mudando o look-ahead na mesma direção
const LOOK_TURN_SPEED := 480.0    # px/s quando ela VIRA (volta rápido para o lado certo)
const FOLLOW_SPEED := 7.0         # suavização exponencial (1/s); maior = mais colado
const LIMIT_GLIDE := 5.0          # suavização dos limites novos (zona trancou/destrancou)
const SAFE_MARGIN := 72.0         # px de MUNDO: distância mínima da Sophia à borda da vista
const FEET_SCREEN := 0.76         # pés a 76 % da altura da tela (antes ~74 %)
const FEET_BELOW_ORIGIN := 12.0   # pés pintados ≈ 12 px abaixo da origem do corpo
const NOISE_HZ := 15.0            # R3: frequência do ruído do tremor (12–18 Hz)
const KICK_RETURN := 0.11         # R3: o chute direcional volta em ~110 ms

@export var max_offset := Vector2(9, 7)
@export var decay := 1.4          # quão rápido o tremor some (por segundo real)
## Enquadramento vertical relativo ao corpo (px de mundo). Telas que fixam a vista
## (Provação) zeram isto; o padrão é calculado de FEET_SCREEN e ZOOM no _ready.
@export var base_offset := Vector2(0, -66)

var trauma := 0.0
var _look_ahead: float = 0.0
var _cam_pos: Vector2 = Vector2.ZERO
var _smooth: bool = true
var _noise := FastNoiseLite.new()
var _noise_t: float = 0.0
var _kick: Vector2 = Vector2.ZERO
var _frame_trauma: float = 0.0     # R3: maior pedido NESTE quadro (não soma)
# Limites: pedido pela fase × efetivo (deslizando) × o que foi escrito no nó.
var _req := PackedFloat32Array([0, 0, 0, 0])     # esquerda, cima, direita, baixo
var _eff := PackedFloat32Array([0, 0, 0, 0])
var _wrote := PackedInt32Array([0, 0, 0, 0])
var _ticks: int = 0


func _ready() -> void:
	Juice.shake_requested.connect(_add_trauma)
	if Juice.has_signal("kick_requested"):
		Juice.kick_requested.connect(_add_kick)
	zoom = Vector2(ZOOM, ZOOM)
	# Pés a FEET_SCREEN da altura visível.
	var view_h: float = 360.0 / ZOOM
	base_offset.y = FEET_BELOW_ORIGIN - (FEET_SCREEN - 0.5) * view_h
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_noise.seed = 7
	# A suavização é nossa; a do Camera2D somaria atraso em dobro.
	_smooth = position_smoothing_enabled
	position_smoothing_enabled = false
	top_level = true                 # posição global própria (segue por código)
	_sync_limits(true)
	_cam_pos = _target()
	global_position = _cam_pos


func _add_trauma(amount: float) -> void:
	_frame_trauma = maxf(_frame_trauma, amount)


func _add_kick(dir: Vector2) -> void:
	_kick = dir


func _body() -> Node2D:
	return get_parent() as Node2D


func _half_view() -> Vector2:
	return get_viewport_rect().size * 0.5 / zoom


## Alvo da câmera: corpo + enquadramento + look-ahead, DENTRO dos limites.
func _target() -> Vector2:
	var b := _body()
	if b == null:
		return global_position
	return _clamp_to_limits(b.global_position + base_offset + Vector2(_look_ahead, 0.0))


func _clamp_to_limits(p: Vector2) -> Vector2:
	var h := _half_view()
	var lo := Vector2(_eff[0] + h.x, _eff[1] + h.y)
	var hi := Vector2(_eff[2] - h.x, _eff[3] - h.y)
	p.x = clampf(p.x, lo.x, hi.x) if lo.x <= hi.x else (lo.x + hi.x) * 0.5
	p.y = clampf(p.y, lo.y, hi.y) if lo.y <= hi.y else (lo.y + hi.y) * 0.5
	return p


## Lê pedidos novos de `limit_*` (a fase escreve direto no nó) e desliza os
## limites efetivos até eles. O que a câmera escreve fica em `_wrote`: valor
## diferente no nó = pedido novo. `snap` = aplica seco (início, teleporte).
func _sync_limits(snap: bool, delta: float = 0.0) -> void:
	var cur := PackedInt32Array([limit_left, limit_top, limit_right, limit_bottom])
	var h := _half_view()
	var view_lo := global_position - h
	var view_hi := global_position + h
	for i in 4:
		if snap or cur[i] != _wrote[i]:
			var novo := float(cur[i])
			if snap or _ticks < 3:
				_eff[i] = novo
			else:
				# Começa de onde a vista está hoje (sem tranco) e desliza até o pedido.
				match i:
					0: _eff[i] = minf(novo, view_lo.x)
					1: _eff[i] = minf(novo, view_lo.y)
					2: _eff[i] = maxf(novo, view_hi.x)
					3: _eff[i] = maxf(novo, view_hi.y)
			_req[i] = novo
		elif _eff[i] != _req[i]:
			_eff[i] = lerpf(_eff[i], _req[i], 1.0 - exp(-LIMIT_GLIDE * delta))
			if absf(_eff[i] - _req[i]) < 0.5:
				_eff[i] = _req[i]
	limit_left = int(round(_eff[0]))
	limit_top = int(round(_eff[1]))
	limit_right = int(round(_eff[2]))
	limit_bottom = int(round(_eff[3]))
	_wrote = PackedInt32Array([limit_left, limit_top, limit_right, limit_bottom])


func _physics_process(delta: float) -> void:
	var b := _body()
	if b == null:
		return
	_ticks += 1
	_sync_limits(false, delta)
	# 1) Look-ahead: vira rápido, anda devagar. Provação (vista fixa) não usa.
	var aim: float = 0.0
	if not CodexSession.active and b is Player:
		aim = float(b.facing) * LOOK_AHEAD
	var turning: bool = signf(aim) != signf(_look_ahead) and absf(_look_ahead) > 1.0
	_look_ahead = move_toward(_look_ahead, aim, delta * (LOOK_TURN_SPEED if turning else LOOK_SPEED))
	# 2) Segue o alvo (suave), com trava: a Sophia nunca sai da faixa segura.
	var tgt := _target()
	if _smooth and not CodexSession.active:
		_cam_pos = _cam_pos.lerp(tgt, 1.0 - exp(-FOLLOW_SPEED * delta))
	else:
		_cam_pos = tgt
	var h := _half_view()
	var reach: float = maxf(0.0, h.x - SAFE_MARGIN)
	_cam_pos.x = clampf(_cam_pos.x, b.global_position.x - reach, b.global_position.x + reach)
	_cam_pos = _clamp_to_limits(_cam_pos)
	global_position = _cam_pos


func _process(delta: float) -> void:
	# 3) Tremor (trauma², ruído contínuo) + chute direcional, em tempo REAL;
	# congelados durante o hitstop (a vibração fica na vítima, R1).
	if _frame_trauma > 0.0:
		trauma = clampf(trauma + _frame_trauma, 0.0, 1.0)
		_frame_trauma = 0.0
	var real_dt: float = delta / maxf(Engine.time_scale, 0.001)
	var frozen: bool = Juice.has_method("hitstop_active") and Juice.hitstop_active()
	if not frozen:
		trauma = maxf(trauma - decay * real_dt, 0.0)
		_noise_t += real_dt * NOISE_HZ
		_kick = _kick.move_toward(Vector2.ZERO, _kick.length() * real_dt / KICK_RETURN + 0.5 * real_dt)
	var amount := trauma * trauma
	var shake := Vector2(
		max_offset.x * amount * _noise.get_noise_2d(_noise_t, 0.0),
		max_offset.y * amount * _noise.get_noise_2d(0.0, _noise_t + 100.0))
	offset = shake + _kick


## Teleporte do corpo (renascer, resgate do vazio, Provação): a câmera pula junto.
func snap() -> void:
	var b := _body()
	_look_ahead = float(b.facing) * LOOK_AHEAD if b is Player and not CodexSession.active else 0.0
	_sync_limits(true)
	_cam_pos = _target()
	global_position = _cam_pos
	reset_physics_interpolation()
