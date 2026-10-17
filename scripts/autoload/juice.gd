extends Node
## "Juice" = feedback que dá peso ao combate: hitstop, tremor, chute de câmera,
## câmera lenta e limite de flashes. Autoload `Juice`.
## Números: docs/handoff/NEURO_SATISFACAO.md (R2, R3, R8, R10) e docs/COMBATE.md §3.
## Tudo em constantes nomeadas aqui no topo: o ajuste fino é no playtest do João.

signal shake_requested(trauma: float)
signal kick_requested(dir: Vector2)                  ## R3: empurrão direcional da câmera
signal hitstop_started(duration: float)              ## R1: flash/vibração da vítima em tempo real
signal hitstop_ended()
signal slowmo_changed(active: bool, scale: float)    ## R8: o Áudio abafa (passa-baixas) na lentidão

# --- R2: hitstop por peso (segundos REAIS) ---
const HITSTOP_SCALE := 0.05
const HS_LIGHT := 0.050          # leve 1º/2º da string
const HS_FINISHER := 0.090       # leve final da string / lançador (83–100 ms)
const HS_HEAVY := 0.108          # pesado (100–117 ms)
const HS_KILL_BONUS := 0.033     # golpe que mata (+2 quadros)
const HS_CROWD_BONUS := 0.017    # pegou 3+ alvos (+1 quadro, uma vez só)
const HS_MULTI_TICK := 0.025     # ticks intermediários do multi-hit (Giro)
const HS_PLAYER_HURT := 0.075    # Sophia tomando dano
const HS_DIVE := 0.100           # Queda Estelar batendo no chão
const HS_MAX := 0.200            # teto absoluto
# --- R3: tremor/chute ---
const KICK_LIGHT := 2.0          # px no sentido do golpe
const KICK_HEAVY := 4.0
const TRAUMA_HEAVY := 0.30       # leve = 0 (só chute)
const TRAUMA_HURT := 0.35        # Sophia tomando dano
# --- R8: câmera lenta ---
const SLOWMO_RAMP := 0.18        # volta em rampa (150–200 ms reais), não degrau
# --- R10: fotossensibilidade ---
const FLASH_MIN_INTERVAL := 0.333   # ≤ 3 flashes cheios/s por alvo
const FLASH_HALF := 0.47            # força relativa do flash "do meio" (≈1,4 de 3,0)
const FLASH_BOSS_CAP := 2.0         # chefe: flash cheio 2,0 (não 3,0)
const FLASH_REDUCED := 0.5          # "Reduzir flashes": flash de sprite × 0,5
const FLASH_PRUNE_MS := 5000        # poda dos ids mortos do registro de flashes

# Hitstop em tempo de PASSO (não relógio de parede): um SceneTreeTimer que
# ignora o time_scale anda 1 passo por quadro (1/60 s com --fixed-fps 60) —
# determinístico no bot/sondas e igual ao tempo real no jogo.
var _hs_timer: SceneTreeTimer = null
var _hs_total: float = 0.0
var _hitstop_running := false
var _base_scale := 1.0          # escala "de fundo" (speed_mult ou a do slow-mo ativo)
var _slow_token := 0
var _ramp_tween: Tween
var _flash_ms: Dictionary = {}      # instance_id -> último flash cheio (ms)
var _flash_pruned_ms: int = 0

## Preferências do jogador (Opções): intensidade do tremor de câmera (0..1) e
## vibração do controle ligada/desligada. O menu de opções grava aqui.
var shake_mult := 1.0
var rumble_enabled := true
## R10: "Reduzir flashes" (Opções). O Técnico/UI espelha a opção do menu aqui.
var reduce_flashes: bool = false

## Velocidade global do jogo (1.0 normal; >1 só em ferramentas — bot de balance).
var speed_mult := 1.0:
	set(v):
		speed_mult = v
		_base_scale = v
		Engine.time_scale = v


func hitstop_active() -> bool:
	return _hitstop_running


## Fração restante do hitstop atual (1 = acabou de começar, 0 = acabou). R1:
## a vibração da vítima encolhe com isto.
func hitstop_left() -> float:
	if not _hitstop_running or _hs_timer == null or _hs_total <= 0.0:
		return 0.0
	return clampf(float(_hs_timer.time_left) / _hs_total, 0.0, 1.0)


## R2: micro-congelamento no impacto, medido em PASSOS sem escala (timer que
## ignora o time_scale): 0,1 s = 6 quadros a 60 fps, sempre o mesmo. Sobreposição:
## vale o MAIOR fim (estende, até HS_MAX desde o início), nunca descarta o pedido
## novo. Ao soltar, volta para a escala de fundo (respeita um slow-mo em andamento).
func hit_stop(duration: float = HS_LIGHT) -> void:
	duration = clampf(duration, 0.0, HS_MAX)
	if duration <= 0.0:
		return
	if _hitstop_running and _hs_timer != null:
		var elapsed: float = _hs_total - float(_hs_timer.time_left)
		var total: float = maxf(_hs_total, minf(elapsed + duration, HS_MAX))
		if total > _hs_total:
			_hs_timer.time_left = float(_hs_timer.time_left) + (total - _hs_total)
			_hs_total = total
		return
	_hitstop_running = true
	_hs_total = duration
	Engine.time_scale = HITSTOP_SCALE
	hitstop_started.emit(duration)
	# create_timer(tempo, process_always, process_in_physics, ignore_time_scale)
	_hs_timer = get_tree().create_timer(duration, true, false, true)
	await _hs_timer.timeout
	_hs_timer = null
	_hitstop_running = false
	Engine.time_scale = _base_scale
	hitstop_ended.emit()


## R2: duração por peso. O Hitbox chama uma vez por golpe (não por alvo).
## `ComboData.hitstop` (se existir e > 0) manda no lugar do automático.
func hitstop_for(heavy: bool, finisher: bool, kills: bool, targets: int) -> float:
	var d := HS_HEAVY if heavy else (HS_FINISHER if finisher else HS_LIGHT)
	if kills:
		d += HS_KILL_BONUS
	if targets >= 3:
		d += HS_CROWD_BONUS
	return minf(d, HS_MAX)


## R8: câmera lenta por `duration` s REAIS; sai em rampa (ease-in) de SLOWMO_RAMP.
## Um slow-mo novo substitui o anterior.
func slow_mo(scale: float = 0.25, duration: float = 0.6) -> void:
	_slow_token += 1
	var my := _slow_token
	if _ramp_tween != null and _ramp_tween.is_valid():
		_ramp_tween.kill()
	_base_scale = scale * speed_mult
	if not _hitstop_running:
		Engine.time_scale = _base_scale
	slowmo_changed.emit(true, scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	if my != _slow_token:
		return                       # outro slow-mo assumiu
	_ramp_tween = create_tween().set_ignore_time_scale(true)
	_ramp_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_ramp_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_ramp_tween.tween_method(_set_base_scale, _base_scale, speed_mult, SLOWMO_RAMP)
	# Espera por timer (um tween morto não emite `finished`).
	await get_tree().create_timer(SLOWMO_RAMP, true, false, true).timeout
	if my == _slow_token:
		_set_base_scale(speed_mult)
		slowmo_changed.emit(false, 1.0)


func _set_base_scale(v: float) -> void:
	_base_scale = v
	if not _hitstop_running:
		Engine.time_scale = v


func slowmo_active() -> bool:
	return _base_scale < speed_mult * 0.99


## R3: tremor por trauma (a câmera fica com o MAIOR pedido do quadro, não a soma).
func shake(trauma: float = 0.4) -> void:
	if shake_mult <= 0.001:
		return
	shake_requested.emit(trauma * shake_mult)


## R3: empurrão direcional da câmera (golpe da Sophia). `dir_x` = lado do golpe.
func kick(dir_x: float, heavy: bool = false) -> void:
	if shake_mult <= 0.001 or dir_x == 0.0:
		return
	var px := (KICK_HEAVY if heavy else KICK_LIGHT) * shake_mult
	kick_requested.emit(Vector2(signf(dir_x) * px, 0.0))


## R10: força do flash permitida agora para `target` (0..1 sobre a cor cheia).
## Cheio no máximo a cada 333 ms por alvo; no meio, meia força. Chefe: teto 2,0.
## Uso: var k := Juice.flash_strength(self, is_boss_enemy)
##      modulate = Color(1,1,1).lerp(Color(3,3,3), k)
func flash_strength(target: Object, is_big: bool = false) -> float:
	var now := Time.get_ticks_msec()
	if now - _flash_pruned_ms > FLASH_PRUNE_MS:
		_flash_pruned_ms = now
		for id in _flash_ms.keys():
			if not is_instance_id_valid(id):
				_flash_ms.erase(id)
	var k := 1.0
	if target != null:
		var id := target.get_instance_id()
		if now - int(_flash_ms.get(id, -100000)) < int(FLASH_MIN_INTERVAL * 1000.0):
			k = FLASH_HALF
		else:
			_flash_ms[id] = now
	if is_big:
		k *= (FLASH_BOSS_CAP - 1.0) / 2.0        # 3,0 → 2,0
	if reduce_flashes:
		k *= FLASH_REDUCED
	return k


## Vibração do controle (Xbox/DualShock/genérico com rumble). Curta e discreta —
## só nos momentos que o corpo sente: dano, parry, esquiva perfeita, chefe caindo.
## weak = motor fino (agudo) · strong = motor grosso (grave) · dur em segundos.
func rumble(weak: float, strong: float, dur: float) -> void:
	if not rumble_enabled:
		return
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, weak, strong, dur)
