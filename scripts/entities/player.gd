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
const JUMP_BUFFER := 0.10
const DODGE_TIME := 0.30
const DODGE_IFRAMES := 0.24
const PARRY_WINDOW := 0.18       # aparar = apertar bloqueio pouco antes do golpe
const BLOCK_CHIP := 0.25         # fração do dano que passa ao bloquear (não aparar)
const RIG_HEIGHT := 68.0         # altura da Sophia ilustrada (px de mundo)

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
	# HP carregado da tela anterior (run em andamento) + a faísca se recompõe
	# um pouco entre as fendas (30% do que falta — balance 2026-09-11: sem
	# NENHUMA cura no run, o dano só acumulava e matava por atrito).
	if RunManager.run_active and RunManager.carry_health >= 0:
		health.current_health = mini(health.max_health, RunManager.carry_health)
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


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	# Resgate do vazio: caiu fora do mundo → volta pro chão da arena.
	if global_position.y > 700.0:
		global_position = Vector2(clampf(global_position.x, -600.0, 1600.0), 200.0)
		velocity = Vector2.ZERO
	_tick_timers(delta)
	match state:
		State.ATTACK: _process_attack(delta)
		State.DODGE:  _process_dodge(delta)
		State.BLOCK:  _process_block(delta)
		State.HURT:   _process_hurt(delta)
		_:            _process_free(delta)
	move_and_slide()
	_update_facing()
	_sync_anim()


func _sync_anim() -> void:
	if visual == null:
		return
	if cast_anim_timer > 0.0 and state != State.HURT and state != State.DEAD:
		visual.set_anim("cast")
		return
	match state:
		State.ATTACK:
			if current_move == null:
				visual.set_anim("attack")
			elif current_move.air:
				visual.set_anim("attack_dive" if current_move.is_heavy() else "attack_air")
			elif current_move.launcher:
				visual.set_anim("attack_up")
			elif current_move.is_heavy():
				visual.set_anim("windup_heavy" if windup_timer > 0.0 else "attack_heavy")
			else:
				visual.set_anim("attack")
		State.HURT: visual.set_anim("hurt")
		State.DODGE: visual.set_anim("dodge")
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

	# Contador de combo esfria se você parar de acertar.
	if combo_show_timer > 0.0:
		combo_show_timer -= delta
		if combo_show_timer <= 0.0 and combo_count > 0:
			combo_count = 0
			combo_changed.emit(0)

	if is_on_floor():
		coyote = COYOTE_TIME
	elif coyote > 0.0:
		coyote -= delta
	if jump_buffer > 0.0:
		jump_buffer -= delta

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
	velocity.x = dir * spd
	if root_timer > 0.0:
		velocity.x = 0.0            # acorrentado: não anda nem pula (esquiva quebra)

	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER
	if jump_buffer > 0.0 and coyote > 0.0 and root_timer <= 0.0:
		velocity.y = data.jump_velocity
		jump_buffer = 0.0
		coyote = 0.0

	if Input.is_action_just_pressed("dodge"):
		_start_dodge()
		return
	if Input.is_action_pressed("block"):
		_enter_block()
		return
	# Só pode atacar se a recuperação do golpe anterior já passou.
	if attack_cd <= 0.0:
		if Input.is_action_just_pressed("attack_light"):
			_attack_input("light")
			return
		if Input.is_action_just_pressed("attack_heavy"):
			_attack_input("heavy")
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


# --- Combo (leve/forte) ------------------------------------------------

## Processa um botão de ataque, casando com a sequência de combo.
## No AR, só existem os golpes aéreos (Giro Celeste / Queda Estelar).
func _attack_input(btn: String) -> void:
	if not is_on_floor():
		var am := _find_move([btn] as Array[String], true)
		if am != null:
			combo_sequence = [btn]
			_do_move(am)
		return
	var trial := combo_sequence.duplicate()
	trial.append(btn)
	var move := _find_move(trial, false)
	if move != null:
		combo_sequence = trial
		_do_move(move)
		return
	# Sequência não existe: recomeça o combo com o botão sozinho.
	var single := _find_move([btn] as Array[String], false)
	if single != null:
		combo_sequence = [btn]
		_do_move(single)


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
	state = State.ATTACK
	windup_timer = move.windup_time()      # carrega antes de conectar (pesado = mais)
	action_timer = move.duration
	chain_open = false
	hit_started = false
	buffered_btn = ""
	combo_reset_timer = move.windup_time() + move.duration + move.chain_time

	var heavy := move.is_heavy()
	velocity.x = facing * move.lunge * (1.35 if heavy else 1.0)
	pending_dmg = move.damage + (Progression.weapon_level - 1) * 6   # r2: 3→6 (a arma tinha que valer)
	hitbox.position.x = 20.0 * facing
	hitbox.knockback = move.knockback
	hitbox.unblockable = false
	hitbox.deactivate()                    # só ativa depois do wind-up
	hits_left = move.hits - 1
	hit_timer = move.duration / float(maxi(1, move.hits))
	dive_landed = false
	if move.air:
		if heavy:
			velocity.y = 760.0             # Queda Estelar: mergulha
			velocity.x = facing * 140.0
		else:
			velocity.y = minf(velocity.y, -90.0)   # Giro Celeste: dá um sopro pra cima
	elif move.launcher:
		velocity.y = -120.0                # pequeno pulo junto com o lançador

	_squash(Vector2(facing * (1.32 if heavy else 1.18), 0.8 if heavy else 0.86))


func _process_attack(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var air_move := current_move != null and current_move.air

	# Fase de wind-up: "carregando" o golpe (freia mais no pesado).
	if windup_timer > 0.0:
		windup_timer -= delta
		if not air_move:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		if windup_timer <= 0.0:
			hitbox.activate(pending_dmg)   # o golpe conecta agora
			hit_started = true
			if not air_move:
				velocity.x = facing * current_move.lunge * (1.35 if current_move.is_heavy() else 1.0)
			if current_move.is_heavy():
				Juice.shake(0.4)           # peso do golpe forte
			# Golpe de área no chão (Fúria da Mônada / Colapso).
			if current_move.aoe_radius > 0.0 and not air_move:
				var col := data.sprite_color.lerp(Color(1.0, 0.95, 0.7), 0.55)
				AoeNova.spawn(get_parent(), global_position + Vector2(30.0 * facing, 0), int(pending_dmg * 0.8), current_move.aoe_radius, col)
		return

	# Golpes aéreos: o Giro flutua; a Queda mergulha e explode ao pousar.
	if air_move:
		if current_move.is_heavy():
			velocity.y = 760.0
			if is_on_floor() and not dive_landed:
				dive_landed = true
				var col := data.sprite_color.lerp(Color(1.0, 0.95, 0.7), 0.55)
				AoeNova.spawn(get_parent(), global_position + Vector2(0, 8), pending_dmg, current_move.aoe_radius, col)
				Juice.shake(0.7)
				Juice.hit_stop(0.08)
				_squash(Vector2(facing * 1.4, 0.7))
				action_timer = minf(action_timer, 0.18)
		else:
			velocity.y = clampf(velocity.y, -90.0, 70.0)      # paira durante o giro
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

	if Input.is_action_just_pressed("attack_light"):
		buffered_btn = "light"
	elif Input.is_action_just_pressed("attack_heavy"):
		buffered_btn = "heavy"

	if Input.is_action_just_pressed("dodge"):
		_start_dodge()
		return

	# Metade final: desliga hitbox e abre a janela de encadeamento
	# (multi-hit mantém a hitbox até o último toque).
	if action_timer <= current_move.duration * 0.5 and not chain_open and hits_left <= 0:
		hitbox.deactivate()
		chain_open = true

	if chain_open and buffered_btn != "":
		var b := buffered_btn
		buffered_btn = ""
		_attack_input(b)
		return

	if action_timer <= 0.0:
		hitbox.deactivate()
		state = State.IDLE
		# Recuperação: você fica comprometido antes de poder atacar de novo.
		if current_move:
			attack_cd = current_move.recovery_time()


## Chamado pelo Hitbox quando um golpe do herói acerta — alimenta o combo.
func register_hit() -> void:
	combo_count += 1
	combo_show_timer = 1.4
	combo_changed.emit(combo_count)


# --- Esquiva (i-frames) ------------------------------------------------

func _start_dodge() -> void:
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
	if not Input.is_action_pressed("block"):
		state = State.IDLE


func _parry(attacker: Node) -> void:
	invuln_timer = 0.30
	Juice.hit_stop(0.12)
	Juice.shake(0.6)
	Juice.rumble(0.6, 0.3, 0.18)
	Audio.play_sfx("parry")
	_flash(Color(3, 3, 4, 1))
	if attacker != null and attacker.has_method("stagger"):
		attacker.stagger()


func _blocked(damage: int, source_position: Vector2) -> void:
	health.take_damage(maxi(1, int(damage * BLOCK_CHIP)))
	invuln_timer = 0.20
	var kb := signf(global_position.x - source_position.x)
	if kb == 0.0:
		kb = -float(facing)
	velocity.x = kb * 120.0
	Juice.shake(0.15)
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
		return
	if skill_cooldowns.get(skill.id, 0.0) > 0.0:
		return
	if mana < skill.mana_cost:
		return
	mana -= skill.mana_cost
	mana_changed.emit(int(mana), max_mana_total)
	skill_cooldowns[skill.id] = skill.cooldown
	Audio.play_sfx("cast")
	cast_anim_timer = 0.3

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
			Juice.shake(0.8)
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

	# Tomou dano.
	health.take_damage(damage)
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
	_flash(Color(4, 1, 1, 1))


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
	Juice.shake(0.25)
	_flash(Color(2.0, 2.2, 3.0, 1))
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -20), Color(0.8, 0.85, 1.0))
	Audio.play_sfx("parry")


## Corrente do Arconte: prende no lugar por `t` segundos (bloqueio/i-frames ignoram).
func apply_root(t: float) -> void:
	if invuln_timer > 0.0 or state == State.BLOCK or state == State.DEAD:
		return
	root_timer = maxf(root_timer, t)
	_flash(Color(0.7, 0.7, 1.6, 1))


func _process_hurt(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	action_timer -= delta
	if action_timer <= 0.0:
		state = State.IDLE


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
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


# --- feedback visual ---------------------------------------------------

func _squash(target: Vector2) -> void:
	if visual == null:
		return
	var t := create_tween()
	t.tween_property(visual, "scale", target, 0.06)
	t.tween_property(visual, "scale", Vector2(facing, 1.0), 0.16)


func _flash(color: Color) -> void:
	if visual == null:
		return
	var t := create_tween()
	t.tween_property(visual, "modulate", color, 0.03)
	t.tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.14)
