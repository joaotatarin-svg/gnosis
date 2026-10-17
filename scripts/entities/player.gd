extends CharacterBody2D
class_name Player
## Personagem jogável (portador de faísca). Sistema de ação estilo God of War:
## ataque leve/forte com strings de combo, esquiva com i-frames, defesa e parry.
## Visual: arte procedural animada (CharacterArt), evolui com a arma/itens.
## Status impostos pelos Arcontes: raiz (Corrente), lentidão (Torpor), silêncio.

signal died()
signal mana_changed(current: int, maximum: int)

enum State { IDLE, RUN, JUMP, FALL, ATTACK, DODGE, BLOCK, HURT, DEAD }

@export var character_id: String = "sophia"

const GRAVITY := 1200.0
const COYOTE_TIME := 0.10
# (buffer de pulo/ataque, curvas de movimento, ritmo e dano: SophiaTuning)
const DODGE_TIME := 0.30
const DODGE_IFRAMES := 0.24
const PARRY_WINDOW := 0.18       # aparar = apertar bloqueio pouco antes do golpe
const BLOCK_CHIP := 0.25         # fração do dano que passa ao bloquear (não aparar)
const RIG_HEIGHT := 68.0         # altura da Sophia ilustrada (px de mundo)
# --- feedback (NEURO_SATISFACAO R1/R10; docs/COMBATE.md §7) ---
const FLASH_FADE := 0.11         # R1: flash ESCURO (modulate) some em 110 ms REAIS
# F1 (QA visual): o flash claro NÃO pinta mais a Sophia (o modulate > 1 sobre a
# pintura virava silhueta laranja CHAPADA). Agora é uma camada ADITIVA por cima
# do corpo (FlashLayer): a pintura continua legível e só "acende".
const FLASH_TIME := 0.10         # F1: o flash inteiro dura ≤ 100 ms REAIS
const FLASH_HOLD := 0.035        # cheio nos primeiros 35 ms, depois apaga
const FLASH_ADD := 0.6           # brilho somado no pico (0..1, × força do Juice)
const VIB_AMP := 1.5             # R1: vibração da vítima (px) durante o hitstop
const VIB_STEP_MS := 33          # troca de lado a cada ~33 ms reais
const HURT_TINT := Color(2.2, 1.95, 1.85, 1) # F1: dano = branco quente (antes 2,2/0,9/0,9 → laranja chapado)
# Contra-ataque (aparo perfeito → janela curta → golpe forte; quadros "riposte").
const RIPOSTE_WINDOW := 0.4      # s depois do aparo em que o ataque vira contra-ataque
const RIPOSTE_DMG := 1.5         # × o dano do pesado simples
const RIPOSTE_WINDUP := 0.06     # sai quase na hora (o inimigo está atordoado)
const RIPOSTE_REACH := 26.0      # px: distância de contato do golpe (hitbox em x=20, ±17)
const RIPOSTE_DASH := 560.0      # teto do avanço (px/s)
const DEAD_DECEL := 600.0        # morta: freia o deslize até parar

var data: CharacterData
var state: State = State.IDLE
var facing: int = 1

var health: HealthComponent
var max_mana_total: int = 40
var mana: float = 40.0
var mana_regen: float = 6.0

# --- combo (strings de leve/forte) ---
var combo_sequence: Array[String] = []
var current_move: ComboData
var chain_open: bool = false
var buffered_btn: String = ""
var combo_reset_timer: float = 0.0
var windup_timer: float = 0.0
var hit_started: bool = false
var pending_dmg: int = 0
var attack_cd: float = 0.0      # recuperação: bloqueia reatacar (comprometimento)
var hits_left: int = 0          # multi-hit: quantas religadas da hitbox faltam
var hit_timer: float = 0.0
var dive_landed: bool = false   # Queda Estelar já bateu no chão?

# contador de combo (golpes encadeados que acertaram)
signal combo_changed(count: int)
var combo_count: int = 0
var combo_show_timer: float = 0.0

# --- timers ---
var action_timer: float = 0.0
var invuln_timer: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var dodge_dir: int = 1
var block_time: float = 0.0
var skill_cooldowns: Dictionary = {}    # skill_id -> restante (s)

# --- status impostos por chefes ---
var root_timer: float = 0.0        # preso no lugar (Corrente); esquivar quebra
var status_slow: float = 0.0       # dentro da névoa do sono (Torpor)
var silenced_timer: float = 0.0    # magias caladas (Silêncio)
var cast_anim_timer: float = 0.0   # pose de conjurar (visual)
var reflect_timer: float = 0.0     # Anel do Espelho: devolve golpes recebidos

# --- áudio (passos e pouso) ---
var _step_timer: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0       # velocidade vertical do frame anterior (pouso)

# R1: flash instantâneo mantido no hitstop e apagado em tempo real; vibração.
var _flash_col: Color = Color(1, 1, 1, 1)
var _flash_t: float = -1.0       # <0 = sem flash ativo
var _vib_amp: float = 0.0
var _vib_until_ms: int = 0
var _vib_seen: bool = false
var _flash_layer: FlashLayer = null   # F1: camada aditiva por cima do corpo
var _riposte_t: float = 0.0          # >0 = janela do contra-ataque aberta
var _riposte_target: Node = null
var riposting: bool = false          # o golpe atual é o contra-ataque

# --- Combate 6: aéreo forte com regra, buffers, pulo duplo ---
## Ferramentas/sondas: libera o pulo duplo sem a flag da progressão.
var debug_double_jump: bool = false
var _air_heavy_used: bool = false    # Queda Estelar já saiu neste pulo
var _air_heavy_cd: float = 0.0       # recarga da Queda (conta do pouso)
var _air_lights: int = 0             # Giros Celestes neste pulo
var _air_jumps_left: int = 0         # 2º pulo disponível neste pulo
var _atk_buffer_btn: String = ""     # ataque apertado na recuperação
var _atk_buffer_t: float = 0.0
var _windup_total: float = 0.0       # preparo do golpe atual (s)
var _dive_lock: bool = false         # Queda: presa no chão depois da onda
var _spin_tween: Tween = null        # pirueta do pulo duplo

@onready var visual: CharacterArt = $Visual
@onready var hitbox: Hitbox = $Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	add_to_group("player")

	data = GameManager.selected_character
	if data == null:
		data = GameContent.get_character(character_id)
	character_id = data.id

	health = HealthComponent.new()
	add_child(health)
	health.setup(data.max_health + Progression.bonus_max_health)
	health.died.connect(_on_died)
	# Misericórdia oculta (§4): só um brilho frio discreto, sem texto.
	health.mercy_spared.connect(func() -> void: _flash(Color(1.6, 1.6, 2.0, 1)))
	# HP carregado da tela anterior (run em andamento) + a faísca se recompõe
	# um pouco entre as fendas (30% do que falta — balance 2026-09-11: sem
	# NENHUMA cura no run, o dano só acumulava e matava por atrito).
	if RunManager.run_active and RunManager.carry_health >= 0:
		# (mínimo 1: o heal não revive morto — REVISAO #11 — e um carry 0 não
		# pode fazer a Sophia nascer "morta sem morrer")
		health.current_health = clampi(RunManager.carry_health, 1, health.max_health)
		health.heal(int((health.max_health - health.current_health) * 0.3))
		health.health_changed.emit(health.current_health, health.max_health)

	max_mana_total = data.max_mana + Progression.bonus_max_mana
	mana = max_mana_total
	mana_changed.emit(int(mana), max_mana_total)

	hurtbox.team = "player"
	hurtbox.hit_received.connect(_on_hit_received)
	hitbox.team = "player"
	hitbox.deactivate()

	_refresh_look()
	var aura = load("res://scripts/fx/codex_combat_aura.gd").new()
	add_child(aura)
	# O herói fica mais "foda" conforme a arma/itens evoluem.
	Progression.weapon_level_changed.connect(func(_lvl): _refresh_look())
	Progression.stats_changed.connect(_refresh_look)
	# Regra de travessia do Éon (#41): névoa do Torpor, correntes da Corrente.
	_attach_eon_rule.call_deferred()


## Liga a regra de travessia da tela (se houver) — depois que a fase montou.
func _attach_eon_rule() -> void:
	EonRule.attach(self)


func _physics_process(delta: float) -> void:
	# Resgate do vazio: caiu fora do mundo → volta pro chão da arena.
	if global_position.y > 700.0:
		global_position = Vector2(clampf(global_position.x, -600.0, 1600.0), 200.0)
		velocity = Vector2.ZERO
		reset_physics_interpolation()
		var cam := get_node_or_null("Camera2D")
		if cam != null and cam.has_method("snap"):
			cam.snap()
	if state == State.DEAD:
		# A4: morta no ar (ou de pé) CAI até o chão e toca a pose de morte —
		# antes congelava no ar no último quadro (QA_UX_BUGS A4).
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, DEAD_DECEL * delta)
		move_and_slide()
		_sync_anim()
		return
	_tick_timers(delta)
	match state:
		State.ATTACK: _process_attack(delta)
		State.DODGE:  _process_dodge(delta)
		State.BLOCK:  _process_block(delta)
		State.HURT:   _process_hurt(delta)
		_:            _process_free(delta)
	move_and_slide()
	_sfx_landing()
	_update_facing()
	_sync_anim()


## Som de pouso: estava no ar, caiu com velocidade e agora pisa o chão.
func _sfx_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and _fall_speed > 140.0:
		Audio.play_sfx("land")
	_was_on_floor = on_floor
	_fall_speed = velocity.y


func _sync_anim() -> void:
	if visual == null:
		return
	if cast_anim_timer > 0.0 and state != State.HURT and state != State.DEAD:
		visual.set_anim("cast")
		return
	match state:
		State.ATTACK:
			# golpe leve 1/2/3 do combo escolhe os quadros desenhados
			visual.combo_step = clampi(current_move.sequence.size(), 1, 3) if current_move != null and not current_move.is_heavy() else 0
			if current_move == null:
				visual.set_anim("attack")
			elif current_move.air:
				if current_move.is_heavy():
					# Queda Estelar: carrega pairando (pose de preparo do pesado), depois mergulha
					visual.set_anim("windup_heavy" if windup_timer > 0.0 else "attack_dive")
				else:
					visual.set_anim("attack_air")
			elif current_move.launcher:
				visual.set_anim("attack_up")
			elif current_move.is_heavy():
				visual.set_anim("windup_heavy" if windup_timer > 0.0 else "attack_heavy")
			else:
				# antecipação curta (o wind-up do leve) no quadro de preparo, e
				# troca SECA pro golpe — o smear do cajado nasce na troca
				visual.set_anim("windup" if windup_timer > 0.0 else "attack")
		State.HURT: visual.set_anim("hurt")
		State.DODGE:
			visual.dodge_back = dodge_dir != facing
			visual.set_anim("dodge")
		State.BLOCK: visual.set_anim("block")
		State.RUN: visual.set_anim("walk")
		State.JUMP: visual.set_anim("jump")
		State.FALL: visual.set_anim("fall")
		State.DEAD: visual.set_anim("dead")
		_: visual.set_anim("idle")


func _tick_timers(delta: float) -> void:
	if invuln_timer > 0.0:
		invuln_timer -= delta
	for k in skill_cooldowns:
		skill_cooldowns[k] = maxf(0.0, skill_cooldowns[k] - delta)
	if attack_cd > 0.0:
		attack_cd -= delta
	if root_timer > 0.0:
		root_timer -= delta
	if status_slow > 0.0:
		status_slow -= delta
	if silenced_timer > 0.0:
		silenced_timer -= delta
	if cast_anim_timer > 0.0:
		cast_anim_timer -= delta
	if reflect_timer > 0.0:
		reflect_timer -= delta
		# Cintilação prateada enquanto o Reflexo protege.
		if visual:
			var sh := 1.0 + 0.25 * absf(sin(reflect_timer * 10.0))
			visual.modulate = Color(sh, sh, sh * 1.1, 1)
			if reflect_timer <= 0.0:
				visual.modulate = Color(1, 1, 1, 1)
	if _perfect_cd > 0.0:
		_perfect_cd -= delta
	if _riposte_t > 0.0:
		_riposte_t -= delta
	if riposting and state != State.ATTACK:
		riposting = false

	# Contador de combo esfria se você parar de acertar.
	if combo_show_timer > 0.0:
		combo_show_timer -= delta
		if combo_show_timer <= 0.0 and combo_count > 0:
			combo_count = 0
			combo_changed.emit(0)

	if is_on_floor():
		coyote = COYOTE_TIME
		_air_lights = 0
		_air_jumps_left = 1 if _double_jump_unlocked() else 0
		if not (state == State.ATTACK and current_move != null and current_move.air and current_move.is_heavy()):
			_air_heavy_used = false
		if _spin_tween != null:
			_stop_spin()
	elif coyote > 0.0:
		coyote -= delta
	if jump_buffer > 0.0:
		jump_buffer -= delta
	# Buffer de pulo em QUALQUER estado (atacando, esquivando, tomando dano):
	# sai no 1º quadro livre. Antes só contava parada/andando.
	if Input.is_action_just_pressed("jump"):
		jump_buffer = SophiaTuning.JUMP_BUFFER
	# Buffer de ataque (ATTACK_BUFFER, em qualquer estado): o botão vale por
	# 0,18 s — sai se a Sophia ficar livre nesse tempo; amassar antes não adianta.
	if _atk_buffer_t > 0.0:
		_atk_buffer_t -= delta
		if _atk_buffer_t <= 0.0:
			_atk_buffer_btn = ""
	if Input.is_action_just_pressed("attack_light"):
		_atk_buffer_btn = "light"
		_atk_buffer_t = SophiaTuning.ATTACK_BUFFER
	elif Input.is_action_just_pressed("attack_heavy"):
		_atk_buffer_btn = "heavy"
		_atk_buffer_t = SophiaTuning.ATTACK_BUFFER
	if _air_heavy_cd > 0.0:
		_air_heavy_cd -= delta

	# Reseta o combo se ficar tempo demais sem encadear.
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0 and state != State.ATTACK:
			combo_sequence.clear()
			current_move = null


# --- Estados livres (IDLE / RUN / JUMP / FALL) -------------------------

func _process_free(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var dir := Input.get_axis("move_left", "move_right")
	var spd := data.move_speed * (0.45 if status_slow > 0.0 else 1.0)
	_move_curve(dir * spd, spd, delta)
	if root_timer > 0.0:
		velocity.x = 0.0            # acorrentado: não anda nem pula (esquiva quebra)

	if jump_buffer > 0.0 and coyote > 0.0 and root_timer <= 0.0:
		velocity.y = data.jump_velocity
		jump_buffer = 0.0
		coyote = 0.0
		Audio.play_sfx("jump")
	elif jump_buffer > 0.0 and not is_on_floor() and coyote <= 0.0 and _air_jumps_left > 0 and root_timer <= 0.0:
		_double_jump()

	if Input.is_action_just_pressed("dodge"):
		_start_dodge()
		return
	if _riposte_input():
		return
	if Input.is_action_pressed("block"):
		_enter_block()
		return
	# Só pode atacar se a recuperação do golpe anterior já passou. Apertou
	# pouco antes (ATTACK_BUFFER)? Sai no 1º quadro livre — antes o botão
	# apertado na recuperação "sumia" (sensação de travado).
	if attack_cd <= 0.0 and _atk_buffer_btn != "":
		var btn := _atk_buffer_btn
		_atk_buffer_btn = ""
		_atk_buffer_t = 0.0
		if _attack_input(btn):
			return
	# Magias: U/X = o Anel equipado · O/Y = Esfera Solar (inata).
	if Input.is_action_just_pressed("skill1"):
		var ring_sk: SkillData = _selected_ring_skill()
		if ring_sk != null:
			_cast_skill(ring_sk)
	if Input.is_action_just_pressed("skill2"):
		var innate: SkillData = GameContent.innate_skill(data)
		if innate != null:
			_cast_skill(innate)
	_ring_selection_input()

	if mana < max_mana_total:
		mana = min(float(max_mana_total), mana + mana_regen * delta)
		mana_changed.emit(int(mana), max_mana_total)

	if not is_on_floor():
		state = State.JUMP if velocity.y < 0.0 else State.FALL
	elif absf(velocity.x) > 1.0:
		state = State.RUN
	else:
		state = State.IDLE

	# Passos: o CharacterArt toca "step" no quadro de apoio do pé da corrida
	# (fase pela distância) — sem timer aqui, pra som e desenho baterem.


# --- Movimento liso (Combate 6) ----------------------------------------

## Curva de velocidade horizontal: arranca no 1º quadro mas sem degrau seco,
## assenta na velocidade; freia em curva; ao virar, freia e acelera do outro
## lado (o giro tem 2–3 quadros de deslize). No ar, controle um pouco menor.
func _move_curve(target: float, spd: float, delta: float) -> void:
	var t: float
	var ground := is_on_floor()
	if absf(target) < 0.01:
		t = SophiaTuning.DECEL_TIME if ground else SophiaTuning.AIR_DECEL_TIME
	elif velocity.x != 0.0 and signf(target) != signf(velocity.x):
		t = SophiaTuning.TURN_TIME if ground else SophiaTuning.AIR_ACCEL_TIME
	else:
		t = SophiaTuning.ACCEL_TIME if ground else SophiaTuning.AIR_ACCEL_TIME
	# acima da velocidade (saindo da esquiva/empurrão): assenta pela freada
	if absf(velocity.x) > absf(target) and signf(velocity.x) == signf(target):
		t = SophiaTuning.DECEL_TIME if ground else SophiaTuning.AIR_DECEL_TIME
	velocity.x = SophiaTuning.approach(velocity.x, target, maxf(spd, 1.0), t, delta)


# --- Pulo duplo (Combate 6) ---------------------------------------------

## O 2º pulo só existe depois que o Soter o concede (Progression). Até a API
## `has_double_jump()` existir, lê a propriedade `double_jump` (falso se não houver).
func _double_jump_unlocked() -> bool:
	if debug_double_jump:
		return true
	if Progression.has_method("has_double_jump"):
		return bool(Progression.call("has_double_jump"))
	var v = Progression.get("double_jump")
	return v is bool and v


## Segundo pulo no ar: mais baixo (DOUBLE_JUMP_MULT), pirueta curta e um anel
## de luz nos pés. Não devolve a Queda Estelar nem os Giros do pulo.
func _double_jump() -> void:
	_air_jumps_left -= 1
	jump_buffer = 0.0
	velocity.y = data.jump_velocity * SophiaTuning.DOUBLE_JUMP_MULT
	var d := Input.get_axis("move_left", "move_right")
	if d != 0.0:
		velocity.x = d * data.move_speed * (0.45 if status_slow > 0.0 else 1.0)
	Audio.play_sfx("jump")
	var col := data.sprite_color.lerp(Color(1.0, 0.95, 0.75), 0.6)
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, 20), col, false)
	_squash(Vector2(facing * 0.9, 1.12))
	_stop_spin()
	if visual:
		_spin_tween = create_tween()
		_spin_tween.tween_property(visual, "rotation", TAU * float(facing), SophiaTuning.DOUBLE_JUMP_SPIN) 				.from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_spin_tween.tween_callback(_stop_spin)


## Interrompe a pirueta (golpe, esquiva, dano, pouso) e endireita o corpo.
func _stop_spin() -> void:
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_spin_tween = null
	if visual:
		visual.rotation = 0.0


# --- Combo (leve/forte) ------------------------------------------------

## Processa um botão de ataque, casando com a sequência de combo. Devolve se
## um golpe saiu. `chaining` = veio da janela de encadear: aí só CONTINUA a
## string (recomeçar do zero espera a recuperação — o fim do combo compromete).
## No AR, só existem os golpes aéreos (Giro Celeste / Queda Estelar), com regra:
## Queda Estelar 1 por pulo + recarga; Giro Celeste até 2 por pulo.
func _attack_input(btn: String, chaining: bool = false) -> bool:
	if not is_on_floor():
		var am := _find_move([btn] as Array[String], true)
		if am == null:
			return false
		if am.is_heavy():
			if _air_heavy_used or _air_heavy_cd > 0.0:
				return false
			_air_heavy_used = true
		else:
			if _air_lights >= SophiaTuning.AIR_LIGHTS_PER_JUMP:
				return false
			_air_lights += 1
		combo_sequence.clear()          # o aéreo não continua em combo de chão
		_do_move(am)
		return true
	var trial := combo_sequence.duplicate()
	trial.append(btn)
	var move := _find_move(trial, false)
	if move != null:
		combo_sequence = trial
		_do_move(move)
		return true
	if chaining:
		return false
	# Sequência não existe: recomeça o combo com o botão sozinho.
	var single := _find_move([btn] as Array[String], false)
	if single != null:
		combo_sequence = [btn]
		_do_move(single)
		return true
	return false


func _find_move(seq: Array, air: bool) -> ComboData:
	for move in Progression.unlocked_combos(data):
		if move.air == air and _seq_equals(move.sequence, seq):
			return move
	return null


func _seq_equals(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _do_move(move: ComboData) -> void:
	current_move = move
	riposting = false
	_stop_spin()
	# Golpe no chão sai para onde o direcional aponta (no deslize do giro a
	# Sophia ainda olha para trás por 2–3 quadros — o golpe não pode sair errado).
	if not move.air:
		var d := Input.get_axis("move_left", "move_right")
		if d != 0.0 and int(signf(d)) != facing:
			facing = int(signf(d))
			if visual:
				visual.scale.x = facing * absf(visual.scale.x)
	state = State.ATTACK
	_atk_buffer_btn = ""                   # o botão guardado virou este golpe
	_atk_buffer_t = 0.0
	windup_timer = SophiaTuning.windup(move)   # carrega antes de conectar (pesado = mais)
	_windup_total = windup_timer
	action_timer = move.duration
	chain_open = false
	hit_started = false
	buffered_btn = ""
	_dive_lock = false
	combo_reset_timer = windup_timer + move.duration + move.chain_time

	var heavy := move.is_heavy()
	if move.air:
		Audio.play_sfx("dive" if heavy else "swing_air")   # golpes aéreos soam ao sair
	velocity.x = facing * move.lunge * (1.35 if heavy else 1.0)
	pending_dmg = move_damage(move)
	hitbox.position.x = 20.0 * facing
	hitbox.knockback = move.knockback
	hitbox.unblockable = false
	hitbox.deactivate()                    # só ativa depois do wind-up
	hits_left = move.hits - 1
	hit_timer = move.duration / float(maxi(1, move.hits))
	dive_landed = false
	if move.air:
		if heavy:
			# Queda Estelar: primeiro PAIRA e carrega (o inimigo vê e reage),
			# depois mergulha. Antes mergulhava no mesmo quadro.
			velocity.y = minf(velocity.y, -40.0)
			velocity.x = facing * 30.0
			action_timer = 1.6             # dura até tocar o chão (teto de segurança)
		else:
			# Giro Celeste: só o 1º do pulo dá o sopro pra cima e paira.
			if _air_lights <= 1:
				velocity.y = minf(velocity.y, -90.0)
	elif move.launcher:
		velocity.y = -120.0                # pequeno pulo junto com o lançador

	_squash(Vector2(facing * (1.32 if heavy else 1.18), 0.8 if heavy else 0.86))


## Dano do golpe no nível de arma atual (SophiaTuning: base × 0,65 × +17 %/nível).
func move_damage(move: ComboData) -> int:
	return SophiaTuning.move_damage(move.damage, Progression.weapon_level)


## Queda Estelar: dano do contato no mergulho e da onda do pouso.
func dive_contact_damage(dmg: int) -> int:
	return maxi(1, roundi(dmg * SophiaTuning.DIVE_CONTACT))


func dive_nova_damage(dmg: int) -> int:
	return maxi(1, roundi(dmg * SophiaTuning.DIVE_NOVA))


func _is_dive() -> bool:
	return current_move != null and current_move.air and current_move.is_heavy()


func _process_attack(delta: float) -> void:
	var air_move := current_move != null and current_move.air
	var dive := _is_dive()

	if Input.is_action_just_pressed("attack_light"):
		buffered_btn = "light"
	elif Input.is_action_just_pressed("attack_heavy"):
		buffered_btn = "heavy"

	# Cancelar SÓ em janelas (esquiva; defesa/aparo na janela de encadear).
	if Input.is_action_just_pressed("dodge") and _cancel_open():
		_start_dodge()
		return
	if chain_open and not dive and Input.is_action_pressed("block") and is_on_floor():
		hitbox.deactivate()
		buffered_btn = ""
		_enter_block()
		return

	# Fase de wind-up: "carregando" o golpe (freia mais no pesado).
	if windup_timer > 0.0:
		windup_timer -= delta
		if dive:
			# paira: quase sem gravidade, freando a subida
			velocity.y = move_toward(velocity.y, 25.0, 900.0 * delta)
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		else:
			if not is_on_floor():
				velocity.y += GRAVITY * delta
			if not air_move:
				velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if windup_timer <= 0.0:
			# o golpe conecta agora (a Queda só "raspa" no mergulho; a onda é o golpe)
			hitbox.activate(dive_contact_damage(pending_dmg) if dive else pending_dmg)
			hit_started = true
			if not air_move:
				Audio.play_sfx(_swing_sfx())   # o corte sai do wind-up
				velocity.x = facing * current_move.lunge * (1.35 if current_move.is_heavy() else 1.0)
			if dive:
				velocity.y = 760.0
				velocity.x = facing * 140.0
			if riposting:
				velocity.x = facing * _riposte_lunge()
			# (R3: o tremor do pesado sai do Hitbox SÓ se acertar)
			# Golpe de área no chão (Fúria da Mônada / Colapso).
			if current_move.aoe_radius > 0.0 and not air_move:
				var col := data.sprite_color.lerp(Color(1.0, 0.95, 0.7), 0.55)
				AoeNova.spawn(get_parent(), global_position + Vector2(30.0 * facing, 0), int(pending_dmg * 0.8), current_move.aoe_radius, col)
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Golpes aéreos: o Giro flutua; a Queda mergulha e explode ao pousar.
	if dive:
		if not dive_landed:
			velocity.y = 760.0
			if is_on_floor():
				dive_landed = true
				_dive_lock = true
				hitbox.deactivate()
				var col := data.sprite_color.lerp(Color(1.0, 0.95, 0.7), 0.55)
				AoeNova.spawn(get_parent(), global_position + Vector2(0, 8), dive_nova_damage(pending_dmg), current_move.aoe_radius, col)
				Juice.shake(0.5)
				Juice.hit_stop(Juice.HS_DIVE)
				_squash(Vector2(facing * 1.4, 0.7))
				action_timer = SophiaTuning.DIVE_LAND_LOCK
				_air_heavy_cd = SophiaTuning.AIR_HEAVY_CD
				combo_sequence.clear()
		else:
			velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	elif air_move:
		if _air_lights <= 1:
			velocity.y = clampf(velocity.y, -90.0, 70.0)      # paira durante o 1º giro
		velocity.x = move_toward(velocity.x, facing * 60.0, 300.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)

	# Multi-hit: religa a hitbox em intervalos (cada religada acerta de novo).
	if hits_left > 0:
		hit_timer -= delta
		if hit_timer <= 0.0:
			hits_left -= 1
			hit_timer = current_move.duration / float(maxi(1, current_move.hits))
			hitbox.deactivate()
			hitbox.activate(pending_dmg)
			_squash(Vector2(facing * 1.15, 0.9))

	action_timer -= delta

	# Janela de encadear: abre depois de CHAIN_AT do golpe (leve 55 %, pesado
	# 68 %); a Queda não encadeia. Multi-hit mantém a hitbox até o último toque.
	if not dive and not chain_open and hits_left <= 0 \
			and action_timer <= current_move.duration * (1.0 - SophiaTuning.chain_at(current_move)):
		hitbox.deactivate()
		chain_open = true

	if chain_open and buffered_btn != "":
		var b := buffered_btn
		buffered_btn = ""
		if _attack_input(b, true):
			return
		# não continua a string: só vale se apertar de novo perto do fim da
		# recuperação (buffer de 0,18 s) — o final do combo compromete

	if action_timer <= 0.0:
		hitbox.deactivate()
		state = State.IDLE
		_dive_lock = false
		# Recuperação: você fica comprometido antes de poder atacar de novo.
		if current_move:
			attack_cd = SophiaTuning.recovery(current_move)
		buffered_btn = ""


## Pode cancelar o golpe numa esquiva agora? (só em janelas — Combate 6)
##   leve (chão/ar): depois que o golpe saiu · pesado: no começo do preparo
##   (finta) ou na janela de encadear · Queda: nunca no ar; presa no chão,
##   só depois de DIVE_CANCEL_AFTER.
func _cancel_open() -> bool:
	if current_move == null:
		return true
	if _is_dive():
		return _dive_lock and action_timer <= SophiaTuning.DIVE_LAND_LOCK - SophiaTuning.DIVE_CANCEL_AFTER
	if current_move.is_heavy():
		if windup_timer > 0.0:
			return windup_timer >= _windup_total * (1.0 - SophiaTuning.HEAVY_FEINT)
		return chain_open
	return hit_started


## Contra-ataque: avança o bastante para alcançar quem foi aparado (o aparo
## empurra o inimigo atordoado para longe), com teto RIPOSTE_DASH px/s.
func _riposte_lunge() -> float:
	var base: float = current_move.lunge * 1.35
	var tgt := _riposte_target
	_riposte_target = null
	if tgt == null or not is_instance_valid(tgt) or not (tgt is Node2D):
		return base
	var gap: float = absf((tgt as Node2D).global_position.x - global_position.x) - RIPOSTE_REACH
	return clampf(gap / 0.16, base, RIPOSTE_DASH)


## Chamado pelo Hitbox quando um golpe do herói acerta — alimenta o combo.
## (R4: o som e o VFX do impacto saem UMA vez no Hitbox, no ponto de contato.)
func register_hit() -> void:
	combo_count += 1
	combo_show_timer = 1.4
	combo_changed.emit(combo_count)


# --- Esquiva (i-frames) ------------------------------------------------

func _start_dodge() -> void:
	_stop_spin()
	if root_timer > 0.0:
		root_timer = 0.0            # arrebenta a corrente
		_flash(Color(2, 2, 3, 1))
	state = State.DODGE
	action_timer = DODGE_TIME
	invuln_timer = DODGE_IFRAMES
	hitbox.deactivate()
	var dir := Input.get_axis("move_left", "move_right")
	dodge_dir = int(signf(dir)) if dir != 0.0 else facing
	velocity.x = dodge_dir * data.move_speed * 2.4
	_squash(Vector2(dodge_dir * 0.8, 1.18))
	Audio.play_sfx("dodge")


func _process_dodge(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	action_timer -= delta
	if action_timer <= 0.0:
		state = State.IDLE


# --- Defesa / Parry ----------------------------------------------------

func _enter_block() -> void:
	if state != State.BLOCK:
		state = State.BLOCK
		block_time = 0.0


func _process_block(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	block_time += delta
	if _riposte_input():
		return
	if not Input.is_action_pressed("block"):
		state = State.IDLE


func _parry(attacker: Node) -> void:
	invuln_timer = 0.30
	Juice.hit_stop(0.12)
	Juice.shake(0.35)
	Juice.rumble(0.6, 0.3, 0.18)
	Audio.play_sfx("parry")
	VfxLibrary.parry(get_parent(), global_position + Vector2(16.0 * facing, -16.0))
	_flash(Color(3, 3, 4, 1))
	# quadros desenhados do aparo (Pedido 6 da Arte) — antes o CharacterArt
	# "adivinhava" o aparo pelo flash azul (modulate.b > 3,5), que não existe mais
	visual.play_action("parry")
	if attacker != null and attacker.has_method("stagger"):
		attacker.stagger()
	# abre a janela do contra-ataque
	_riposte_t = RIPOSTE_WINDOW
	_riposte_target = attacker


## Ataque apertado com a janela do contra-ataque aberta → contra-ataque.
func _riposte_input() -> bool:
	if _riposte_t <= 0.0 or not is_on_floor():
		return false
	if not (Input.is_action_just_pressed("attack_light") or Input.is_action_just_pressed("attack_heavy")):
		return false
	_start_riposte()
	return true


## CONTRA-ATAQUE: o pesado simples, mais rápido e ×RIPOSTE_DMG, virado para quem
## foi aparado, com os quadros "riposte" (estocada, giro, follow). O combo
## continua a partir do pesado.
func _start_riposte() -> void:
	_riposte_t = 0.0
	var move := _find_move(["heavy"] as Array[String], false)
	if move == null:
		move = _find_move(["light"] as Array[String], false)
	if move == null:
		return
	if _riposte_target != null and is_instance_valid(_riposte_target) and _riposte_target is Node2D:
		var dx: float = (_riposte_target as Node2D).global_position.x - global_position.x
		if dx != 0.0:
			facing = int(signf(dx))
			if visual:
				visual.scale.x = facing * absf(visual.scale.x)
	combo_sequence = [move.sequence[0]] as Array[String]
	_do_move(move)
	riposting = true
	windup_timer = minf(windup_timer, RIPOSTE_WINDUP)
	pending_dmg = int(round(pending_dmg * RIPOSTE_DMG))
	Juice.kick(float(facing), true)
	visual.play_action("riposte")


func _blocked(damage: int, source_position: Vector2) -> void:
	health.take_damage(maxi(1, int(damage * BLOCK_CHIP)))
	invuln_timer = 0.20
	var kb := signf(global_position.x - source_position.x)
	if kb == 0.0:
		kb = -float(facing)
	velocity.x = kb * 120.0
	Juice.shake(0.15)
	Audio.play_sfx("block")
	_flash(Color(2, 2, 3, 1))


# --- Magias (a Esfera inata + os 7 Anéis) -------------------------------

## O Anel equipado (Progression.selected_ring), se já foi ganho e está utilizável.
func _selected_ring_skill() -> SkillData:
	var rs: Array = GameContent.ring_skills(data)
	if rs.is_empty():
		return null
	var idx := clampi(Progression.selected_ring, 0, rs.size() - 1)
	var skill: SkillData = rs[idx]
	if not Progression.ring_usable(skill.ring):
		return null
	return skill


## Troca o Anel equipado: Q/E (ou L2/Back) cicla, 1–7 escolhe direto.
func _ring_selection_input() -> void:
	var rs: Array = GameContent.ring_skills(data)
	if rs.is_empty():
		return
	var n := rs.size()
	var changed := false
	if Input.is_action_just_pressed("ring_next"):
		Progression.selected_ring = (Progression.selected_ring + 1) % n
		changed = true
	elif Input.is_action_just_pressed("ring_prev"):
		Progression.selected_ring = (Progression.selected_ring - 1 + n) % n
		changed = true
	for i in n:
		if Input.is_action_just_pressed("ring_%d" % (i + 1)):
			Progression.selected_ring = i
			changed = true
	if changed:
		Progression.rings_changed.emit()


func _cast_skill(skill: SkillData) -> void:
	if not Progression.is_skill_unlocked(skill.id):
		return                     # magia ainda não adquirida
	if skill.ring != "" and not Progression.ring_usable(skill.ring):
		return                     # Anel roubado (o caco ainda não voltou)
	if silenced_timer > 0.0:
		_flash(Color(0.6, 0.6, 0.8, 1))   # calada pelo Arconte do Silêncio
		Audio.play_sfx("cast_fail")
		return
	if skill_cooldowns.get(skill.id, 0.0) > 0.0:
		return
	if mana < skill.mana_cost:
		Audio.play_sfx("cast_fail")       # sem Éter
		return
	mana -= skill.mana_cost
	mana_changed.emit(int(mana), max_mana_total)
	skill_cooldowns[skill.id] = skill.cooldown
	Audio.play_sfx(_cast_sfx(skill))
	cast_anim_timer = 0.3
	VfxLibrary.cast(get_parent(), global_position + Vector2(14.0 * facing, -18.0), skill.color)

	var total := skill.base_damage + (Progression.skill_level(skill.id) - 1) * 12   # r2: 8→12
	var col := skill.color
	var ground := global_position + Vector2(0, 2)

	# Cada Anel é a paixão do Arconte virada contra o Kenoma.
	match skill.id:
		"m_s1":
			# Esfera Solar (inata): projétil que explode em área.
			var p := Projectile.new()
			p.direction = facing
			p.damage = total
			p.color = col
			p.pierce = false
			p.explode_radius = 70.0
			p.speed = 340.0
			get_parent().add_child(p)
			p.global_position = global_position + Vector2(18.0 * facing, -6.0)
			Juice.shake(0.2)
		"r_torpor":
			# Névoa do Sono: nuvem no chão que deixa os inimigos LENTOS.
			HazardZone.spawn(get_parent(), ground + Vector2(90.0 * facing, 0), "sleep", 120.0, 6.0, col, "enemy", 0)
			AoeNova.spawn(get_parent(), ground + Vector2(90.0 * facing, -10), total, 110.0, col)
		"r_fome":
			# Boca Voraz: suga os inimigos até você e morde.
			for e in get_tree().get_nodes_in_group("enemy"):
				if not is_instance_valid(e) or not e is Enemy or e.estate == Enemy.EState.DEAD:
					continue
				var dx: float = e.global_position.x - global_position.x
				if absf(dx) < 260.0 and absf(e.global_position.y - global_position.y) < 90.0:
					e.global_position.x -= signf(dx) * minf(absf(dx) - 40.0, 150.0)
					e.reset_physics_interpolation()     # puxão de até 150 px: sem rastro interpolado
			AoeNova.spawn(get_parent(), global_position + Vector2(40.0 * facing, -6), total, 90.0, col)
			Juice.shake(0.35)
		"r_corrente":
			# Corrente da Lei: prende o alvo no lugar (a corrente deles, na tua mão).
			var c := Projectile.new()
			c.direction = facing
			c.damage = total
			c.color = col
			c.pierce = false
			c.speed = 430.0
			c.root_time = 1.8
			get_parent().add_child(c)
			c.global_position = global_position + Vector2(18.0 * facing, -6.0)
		"r_silencio":
			# Grito Mudo: atordoa todo golpe em preparo ao redor.
			for e in get_tree().get_nodes_in_group("enemy"):
				if not is_instance_valid(e) or not e is Enemy or e.estate == Enemy.EState.DEAD:
					continue
				if e.global_position.distance_to(global_position) < 170.0:
					if e.has_method("stagger"):
						e.stagger()
					e.apply_damage(total, global_position, 60.0)
			AoeNova.spawn(get_parent(), global_position + Vector2(0, -12), 0, 170.0, col)
			Juice.shake(0.3)
		"r_espelho":
			# Reflexo: por 5 s, todo golpe que te acerta volta pra quem deu.
			reflect_timer = 5.0
			ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -22), col)
		"r_praga":
			# Flor Podre: canteiro de veneno que fere quem pisa.
			HazardZone.spawn(get_parent(), ground + Vector2(90.0 * facing, 0), "poison", 110.0, 6.0, col, "enemy", maxi(2, int(total * 0.5)))
		"r_coroa":
			# Coroa da Mônada: a nova da Fonte — dano enorme em área.
			AoeNova.spawn(get_parent(), global_position, total, 210.0, col)
			Juice.slow_mo(0.35, 0.4)
			Juice.shake(0.6)
		_:
			# Fallback genérico por tipo (magias futuras).
			match skill.type:
				SkillData.SkillType.PROJECTILE:
					var q := Projectile.new()
					q.direction = facing
					q.damage = total
					q.color = col
					get_parent().add_child(q)
					q.global_position = global_position + Vector2(18.0 * facing, -6.0)
				_:
					AoeNova.spawn(get_parent(), global_position + Vector2(80.0 * facing, 0), total, 110.0, col)
	_squash(Vector2(facing * 1.18, 0.86))


# --- Receber dano ------------------------------------------------------

func _on_hit_received(damage: int, source_position: Vector2, knockback: float, unblockable: bool = false, attacker: Node = null) -> void:
	if state == State.DEAD:
		return
	if invuln_timer > 0.0:
		# ESQUIVA PERFEITA: o golpe passou por você durante o rolamento.
		# Recompensa: câmera lenta curta, recupera Éter e zera a recuperação.
		if state == State.DODGE and attacker != null:
			_perfect_dodge()
		return

	# Anel do Espelho: o golpe volta pra quem deu (e não te fere).
	if reflect_timer > 0.0:
		if attacker != null and is_instance_valid(attacker) and attacker.has_method("apply_damage"):
			attacker.apply_damage(damage, global_position, 220.0)
			DamageNumber.spawn(get_parent(), attacker.global_position, damage, Color(0.9, 0.95, 1.0))
		invuln_timer = maxf(invuln_timer, 0.25)
		Juice.hit_stop(0.06)
		_flash(Color(2.2, 2.4, 3.0, 1))
		return

	# Defesa / Parry (golpes imparáveis ignoram o bloqueio — só dá pra desviar).
	if state == State.BLOCK and not unblockable:
		if block_time <= PARRY_WINDOW:
			_parry(attacker)
		else:
			_blocked(damage, source_position)
		return

	# Tomou dano. Hitstop/tremor de dano aqui (vale para Hitbox, projétil, veneno
	# e explosão); o Juice fica com o MAIOR pedido, não soma.
	var hp_before := health.current_health
	health.take_damage(damage)
	if health.current_health < hp_before:
		Juice.hit_stop(Juice.HS_PLAYER_HURT)
		Juice.shake(Juice.TRAUMA_HURT)
	if health.is_dead():
		_flash(HURT_TINT, VIB_AMP)
		return                     # _on_died já pôs o estado em DEAD — não voltar pra IDLE
	Audio.play_sfx("player_hurt")
	Juice.rumble(0.0, 0.6, 0.22)
	DamageNumber.spawn(get_parent(), global_position, damage, Color(1.0, 0.4, 0.35))
	invuln_timer = 0.6
	var kb_dir := signf(global_position.x - source_position.x)
	if kb_dir == 0.0:
		kb_dir = -float(facing)
	velocity.x = kb_dir * knockback
	velocity.y = -150.0
	state = State.HURT
	action_timer = 0.3
	hitbox.deactivate()
	_stop_spin()
	_flash(HURT_TINT, VIB_AMP)


var _perfect_cd: float = 0.0

func _perfect_dodge() -> void:
	if _perfect_cd > 0.0:
		return
	_perfect_cd = 0.8
	invuln_timer = maxf(invuln_timer, 0.45)
	Juice.rumble(0.5, 0.0, 0.15)
	attack_cd = 0.0
	mana = minf(float(max_mana_total), mana + 12.0)
	mana_changed.emit(int(mana), max_mana_total)
	Juice.slow_mo(0.3, 0.35)
	Juice.kick(float(dodge_dir), false)
	_flash(Color(2.0, 2.2, 3.0, 1))
	VfxLibrary.dodge_perfect(get_parent(), global_position + Vector2(0, -20))
	Audio.play_sfx("dodge_perfect")


## Corrente do Arconte: prende no lugar por `t` segundos (bloqueio/i-frames ignoram).
func apply_root(t: float) -> void:
	if invuln_timer > 0.0 or state == State.BLOCK or state == State.DEAD:
		return
	root_timer = maxf(root_timer, t)
	Audio.play_sfx("rooted")
	_flash(Color(0.7, 0.7, 1.6, 1))


func _process_hurt(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	action_timer -= delta
	if action_timer <= 0.0:
		state = State.IDLE


func _on_died() -> void:
	_stop_spin()
	state = State.DEAD
	velocity.x = 0.0                 # cai reto (A4); a gravidade cuida do y
	velocity.y = maxf(velocity.y, 0.0)
	hitbox.deactivate()
	cast_anim_timer = 0.0
	Audio.play_sfx("player_die")
	died.emit()


func _update_facing() -> void:
	if state == State.ATTACK or state == State.DODGE or state == State.BLOCK:
		return
	if velocity.x > 1.0:
		facing = 1
	elif velocity.x < -1.0:
		facing = -1
	if visual:
		visual.scale.x = facing * absf(visual.scale.x)


# --- aparência (evolui com a progressão) -------------------------------

func _refresh_look() -> void:
	if not visual:
		return
	# Cópia Codex: a instrução da sessão escolhe Sophia procedural.
	visual.rig.clear()
	visual.set_profile(Bestiary.player_profile(data, Progression.weapon_level, Progression.item_features()))


# --- áudio ---------------------------------------------------------------

## Nome do som do golpe atual (chão): lançador, pesado ou leve.
func _swing_sfx() -> String:
	if current_move == null:
		return "swing_light"
	if current_move.launcher:
		return "launcher"
	return "swing_heavy" if current_move.is_heavy() else "swing_light"


## Cada Anel tem voz própria: "r_torpor" → cast_torpor; a Esfera inata → cast_solar.
func _cast_sfx(skill: SkillData) -> String:
	if skill.id.begins_with("r_"):
		return "cast_" + skill.id.trim_prefix("r_")
	return "cast_solar"


# --- feedback visual ---------------------------------------------------

func _squash(target: Vector2) -> void:
	if visual == null:
		return
	# Squash limitado a ±7% e sempre do lado pra onde ela olha (pintura
	# esticada/virada vira "foto"; a deformação forte fica no shader).
	var sx: float = 1.0 + clampf(absf(target.x) - 1.0, -0.07, 0.07)
	var sy: float = 1.0 + clampf(target.y - 1.0, -0.07, 0.07)
	target = Vector2(facing * sx, sy)
	var t := create_tween()
	t.tween_property(visual, "scale", target, 0.06)
	t.tween_property(visual, "scale", Vector2(facing, 1.0), 0.16)


## R1/R10 + F1: flash INSTANTÂNEO (no mesmo quadro), ≤ FLASH_TIME s REAIS
## (cheio por FLASH_HOLD, depois apaga), força limitada pelo Juice (≤ 3 cheios/s,
## "Reduzir flashes" × 0,5). Cor CLARA (algum canal > 1) = camada ADITIVA por
## cima do corpo na matiz da cor — a pintura não vira silhueta chapada. Cor
## ESCURA (todos ≤ 1, ex.: calada pelo Silêncio) = tinge o modulate e volta.
## `vibrate` > 0 = a vítima treme no hitstop.
func _flash(color: Color, vibrate: float = 0.0) -> void:
	if visual == null:
		return
	var k: float = Juice.flash_strength(self, false)
	var peak: float = maxf(color.r, maxf(color.g, color.b))
	if peak > 1.0:
		var hue := Color(color.r / peak, color.g / peak, color.b / peak, 1.0)
		var amount: float = FLASH_ADD * k * clampf((peak - 1.0) / 2.0, 0.35, 1.0)
		_flash_overlay().fire(hue, amount)
	else:
		_flash_col = Color(1, 1, 1, 1).lerp(color, k)
		_flash_col.a = 1.0
		_flash_t = 0.0
		visual.modulate = _flash_col
	if vibrate > 0.0:
		_vib_amp = vibrate
		_vib_until_ms = Time.get_ticks_msec() + 250
		_vib_seen = false


## A camada do flash claro (criada na 1ª vez, irmã do Visual, logo depois dele).
func _flash_overlay() -> FlashLayer:
	if _flash_layer == null or not is_instance_valid(_flash_layer):
		_flash_layer = FlashLayer.new()
		_flash_layer.name = "FlashLayer"
		_flash_layer.art = visual
		add_child(_flash_layer)
		move_child(_flash_layer, visual.get_index() + 1)
	return _flash_layer


## Flash e vibração correm em tempo REAL (o hitstop deixa o jogo a 5 %).
func _process(delta: float) -> void:
	if visual == null:
		return
	var real_dt: float = delta / maxf(Engine.time_scale, 0.001)
	var frozen: bool = Juice.hitstop_active()
	if _flash_t >= 0.0:
		if not frozen:
			_flash_t += real_dt
		var k := 1.0 - clampf(_flash_t / FLASH_FADE, 0.0, 1.0)
		visual.modulate = Color(1, 1, 1, 1).lerp(_flash_col, k)
		if k <= 0.0:
			_flash_t = -1.0
	if _vib_amp > 0.0:
		var now := Time.get_ticks_msec()
		if frozen:
			_vib_seen = true
			var side := 1.0 if (now / VIB_STEP_MS) % 2 == 0 else -1.0
			var a := _vib_amp * Juice.hitstop_left() * side
			if is_on_floor():
				visual.position = Vector2(a, 0.0)
			else:
				visual.position = Vector2(0.0, a)
		elif _vib_seen or now > _vib_until_ms:
			_vib_amp = 0.0
			visual.position = Vector2.ZERO
	# depois da vibração: a camada copia a posição já tremida do corpo
	if _flash_layer != null and is_instance_valid(_flash_layer):
		_flash_layer.tick(real_dt)


## F1: FLASH ADITIVO da Sophia. Redesenha a malha do corpo (a mesma que o
## CharacterArt acabou de desenhar: `_body_mesh`/`_body_xform`/`_body_tex`) com
## um shader de soma (VfxLibrary.flash_add_shader) na matiz do flash. A pintura
## por baixo continua com textura — só clareia — e a camada some em ≤ 100 ms.
## Copia a curvatura (bend/body_h) do material do corpo para casar a silhueta.
class FlashLayer extends Node2D:
	var art: CharacterArt
	var hue: Color = Color.WHITE
	var peak: float = 0.0
	var t: float = -1.0               # s REAIS desde o disparo (<0 = apagado)
	var _mat: ShaderMaterial
	# No quadro do golpe o CharacterArt ainda não redesenhou a pose nova (a malha
	# guardada é a da pose anterior → "fantasma" deslocado): a camada só aparece
	# a partir do quadro seguinte.
	var _hold_frames: int = 0

	func _ready() -> void:
		_mat = ShaderMaterial.new()
		_mat.shader = VfxLibrary.flash_add_shader()
		material = _mat
		visible = false

	func fire(p_hue: Color, amount: float) -> void:
		hue = p_hue
		peak = maxf(amount, peak if t >= 0.0 and t < Player.FLASH_HOLD else 0.0)
		t = 0.0
		_hold_frames = 1
		_sync()

	func tick(real_dt: float) -> void:
		if t < 0.0:
			return
		t += real_dt
		_hold_frames -= 1
		if t >= Player.FLASH_TIME or art == null or not is_instance_valid(art):
			t = -1.0
			visible = false
			return
		_sync()

	func _sync() -> void:
		var a: float = peak
		if t > Player.FLASH_HOLD:
			a = peak * (1.0 - (t - Player.FLASH_HOLD) / (Player.FLASH_TIME - Player.FLASH_HOLD))
		visible = _hold_frames <= 0
		transform = art.transform
		z_index = art.z_index
		texture_filter = art.texture_filter
		_mat.set_shader_parameter("flash", Color(hue.r, hue.g, hue.b, clampf(a, 0.0, 1.0) * art.modulate.a))
		var src := art.material as ShaderMaterial
		if src != null:
			_mat.set_shader_parameter("bend", src.get_shader_parameter("bend"))
			_mat.set_shader_parameter("body_h", src.get_shader_parameter("body_h"))
		queue_redraw()

	func _draw() -> void:
		if art == null or not is_instance_valid(art) or art._body_mesh.is_empty() or art._body_tex == null or not art.visible:
			return
		CharacterArt.draw_grid(get_canvas_item(), art._body_mesh, art._body_xform, art._body_tex, Color.WHITE)
