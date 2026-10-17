extends CharacterBody2D
class_name Enemy
## Arconte (inimigo). Tipo e stats vêm do Bestiary por `type_id`, escalados
## de forma determinística pela tela atual (+ dificuldade). Ataques telegrafados:
## comum = amarelo (aparável), elite = vermelho (imparável, estilo GoW).
##
## Além do `style` (melee/ranged/charge/slam), um inimigo pode ter:
##  - `behavior` (waves): shield (só pesado/magia fere) · teleport (pisca pra
##    trás da Sophia) · exploder (corre e explode) · summoner (chama larvas)
##  - `kit` (chefes): torpor / fome / corrente / silencio / espelho / praga / coroa
## Chefes têm 2 FASES: a 50% de vida entram em fúria (mais rápidos) e a
## habilidade assinatura do kit fica mais forte.

signal defeated(enemy)
signal minion_spawned(minion)
## O dano do golpe SAI agora (hitbox ligou / projétil nasceu). Para o boneco do
## chefe acertar o estalo no impacto (pedido da Animação-Chefes).
signal attack_impact()

enum EState { CHASE, WINDUP, STRIKE, RECOVER, HURT, STAGGER, DEAD }

@export var type_id: String = "servo"     # id no Bestiary
@export var is_elite: bool = false
## CAMPEÃO do Éon (tela de desafio): elite + 1.7x vida, 1.15x dano, maior,
## nome e barra no HUD, faíscas em dobro.
@export var is_champion: bool = false

# Preenchidos a partir do Bestiary em _ready.
var display_name: String = "Arconte"
var move_speed: float = 70.0
var attack_damage: int = 12
var contact_damage: int = 6
var spark_reward: int = 5

# Parâmetros do ataque telegrafado
@export var attack_range: float = 52.0
@export var wind_up: float = 0.55
@export var strike_time: float = 0.16
@export var recover_time: float = 0.45
@export var attack_cooldown: float = 1.0

const GRAVITY := 1200.0
const TELEGRAPH_PARRYABLE := Color(1.0, 0.85, 0.2, 1.0)
const TELEGRAPH_UNBLOCKABLE := Color(1.0, 0.25, 0.25, 1.0)
const CHARGE_SPEED := 340.0
const ENEMY_SCENE := "res://scenes/entities/Enemy.tscn"
const SEPARATION := 30.0          # distância mínima entre inimigos (IA de grupo)
# --- feedback (NEURO_SATISFACAO R1/R4/R5/R8/R10; docs/COMBATE.md §7) ---
const TELEGRAPH_TINT := 0.45      # R5: tinge 45 % em direção à cor (não multiplica 100 %)
const TELEGRAPH_PULSE := 0.05     # pulso de ±5 % no tingimento…
const TELEGRAPH_PULSE_HZ := 2.0   # …a 2 Hz (abaixo de 3 Hz, R10)
const GLINT_LEAD := 0.18          # R5: brilho de aviso 180 ms antes do golpe (= janela de parry)
const GLINT_BOOST := 0.35         # o brilho clareia o tingimento por um instante
const GLINT_TIME := 0.12          # duração do brilho no corpo (s de jogo)
const FLASH_FADE := 0.11          # R1: o flash some em 110 ms REAIS depois do hitstop
const TELEGRAPH_RIM_A := 0.9      # contorno do telegrafo nos chefes por quadros (Pedido 2 da Arte)
const DEATH_POSE_TIME := 0.4      # chefe: segura o quadro "death" antes de se partir (s REAIS; Pedido 4 da Arte)
const VIB_LIGHT := 1.5            # R1: vibração da vítima (px), golpe leve
const VIB_HEAVY := 3.0            # golpe pesado / lançador / magia
const VIB_STEP_MS := 33           # troca de lado a cada ~33 ms reais
const HURT_VOICE_MS := 250        # R4: "enemy_hurt" no máximo 1 a cada 250 ms por inimigo
const PRAGA_POOL_TIME := 3.0      # Balance P3: poça de Belias (era 5,0 s)
const PRAGA_POOL_R2 := 40.0       # Balance P3: raio na fase 2 (era 48; fase 1 = 34)
## #42 (crítico): todo Arconte ≥ ~1,8× a altura da Sophia (Espelho é exceção de
## propósito). Medido por `tools/combate/BossSizeProbe.tscn` (alfa > 0,25, pose
## parada): Belias 1,76× e Athoth 1,95× — ambos sobem para ~2,0× (folga para a
## pose agachada do wind-up). Escala o CORPO todo (desenho + caixas), como o Elite.
## Onda 3: Belias (arconte_praga) SAIU — com 1,15× o bot piorou a tela 55
## (1062 → 1319 de dano): o corpo maior cobre mais chão junto com as poças.
const BOSS_PRESENCE := {"arconte_sono": 1.08}
# R18 — leitura (contorno + sombra de contato); ver _setup_readability().
const RIM_ENABLED := true
const RIM_ALPHA := 0.5
const SHADOW_ALPHA := 0.45        # era 0,3
const SHADOW_WIDEN := 1.25

var estate: EState = EState.CHASE
var health: HealthComponent
var player: Node2D
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var atk_dir: int = 1
var _reward_mult: float = 1.0
var attack_style: String = "melee"   # melee / ranged / charge / slam
var behavior: String = ""            # shield / teleport / exploder / summoner
var kit: String = ""                 # assinatura de chefe
var phase: int = 1
var armored: bool = false            # Coroa: blindado enquanto os servos vivem
var eye_color: Color = Color(1, 0.8, 0.4)
var is_boss_enemy: bool = false
var _charge_speed: float = CHARGE_SPEED
var _art_scale: float = 1.0
var _special_timer: float = 1.5      # teleporte / invocação
var _pool_timer: float = 0.0         # poças de veneno na investida
var _minions: Array = []
var _last_hit_heavy: bool = false    # o último golpe recebido foi pesado/magia? (desmembra)
var _last_kick: Vector2 = Vector2.ZERO
var force_dismember: bool = false    # finisher: sempre desmembra
var slow_timer: float = 0.0          # Névoa do Sono da Sophia: anda na metade
var rooted_timer: float = 0.0        # Corrente da Lei: preso no lugar
var revivable: bool = false          # batalha final: cai mas pode se refazer
# Telegrafo (R5) e flash/vibração (R1) em tempo real.
var _tint_base: Color = Color(1, 1, 1, 1)   # cor-base do estado (telegrafo no WINDUP)
var _glint_done: bool = false
var _glint_t: float = -1.0
var _flash_col: Color = Color(1, 1, 1, 1)
var _flash_t: float = -1.0
var _vib_amp: float = 0.0
var _vib_until_ms: int = 0
var _vib_seen: bool = false
var _vib_cur: Vector2 = Vector2.ZERO
var _last_hurt_voice_ms: int = -100000
## Pedido da Animação-Chefes: onde o dano sai no STRIKE (0..1 do progresso) e a
## força do último dano (0..1). Também vão como metadado no `visual`.
var impact_at: float = 0.0
var hurt_power: float = 0.0
var _art_id: String = ""             # id do PNG ilustrado (def "art")
var _rim_mat: ShaderMaterial = null  # contorno de leitura (R18)
var _floor_y: float = NAN            # último y no chão (sombra de contato)
var _shadow_base: Vector2 = Vector2(0, 22)
var _shadow_scale: Vector2 = Vector2.ONE

# Arte ilustrada (opcional) + orbe-olho flutuante (chefes com PNG).
const ORB_HOME := Vector2(78.0, -168.0)   # repouso do orbe (px, local ao chefe)
var _orb: Sprite2D = null
var _orb_t: float = 0.0

@onready var visual: CharacterArt = $Visual
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact_hitbox: Hitbox = $ContactHitbox
@onready var attack_hitbox: Hitbox = $AttackHitbox


func _ready() -> void:
	add_to_group("enemy")

	var def := Bestiary.get_type(type_id)
	var profile: ArtProfile = def.get("profile", null)
	display_name = def.get("name", "Arconte")
	move_speed = def.get("move_speed", 70.0)
	attack_damage = def.get("base_damage", 12)
	contact_damage = maxi(3, int(attack_damage * 0.5))
	spark_reward = def.get("spark", 5)
	var base_health: int = def.get("base_health", 30)
	attack_style = def.get("style", "melee")
	behavior = def.get("behavior", "")
	kit = def.get("kit", "")
	_art_id = def.get("art", type_id)
	is_boss_enemy = Bestiary.is_boss_id(type_id)
	_charge_speed = CHARGE_SPEED * (1.4 if is_boss_enemy else 1.0)
	if profile != null:
		eye_color = profile.eye

	# Alcance e timing por estilo de ataque.
	match attack_style:
		"ranged":
			attack_range = 240.0
			wind_up = 0.5
		"charge":
			attack_range = 170.0
			wind_up = 0.6
			strike_time = 0.42
		"slam":
			attack_range = 62.0
			wind_up = 0.7
			recover_time = 0.6
	match behavior:
		"exploder":
			attack_range = 46.0
			wind_up = 0.7
		"summoner":
			attack_range = 260.0
			wind_up = 0.6
		"chainshot":
			attack_range = 200.0
			wind_up = 0.55
	if kit == "rei":
		attack_range = 300.0
		wind_up = 0.9 if type_id == "rei" else 0.6
		attack_cooldown = 1.6 if type_id == "rei" else 1.0

	# Elite: maior, mais forte e imparável. (Campeão implica elite.)
	if is_champion:
		is_elite = true
	if is_elite:
		display_name = "%s (Elite)" % display_name
		base_health = int(base_health * 2.2)
		attack_damage += 8
		spark_reward *= 3
		scale = Vector2(1.2, 1.2)
		if profile != null:
			profile = profile.duplicate_with(["horns"])
	# Campeão do Éon: o bot temático crescido — o "mini-chefe" do meio do Éon.
	if is_champion:
		display_name = "Campeão %s" % _eon_title(GameManager.current_screen)
		base_health = int(base_health * 1.7)
		attack_damage = int(attack_damage * 1.15)
		spark_reward *= 2
		scale = Vector2(1.25, 1.25)
	# Presença dos Arcontes (#42): só os que ficavam abaixo de ~2× a Sophia.
	if BOSS_PRESENCE.has(type_id):
		var k: float = BOSS_PRESENCE[type_id]
		scale = Vector2(k, k)

	# Escala determinística por tela + dificuldade (r2: vida e dano crescem em
	# curvas separadas — vida +2%/tela, dano +1.2%/tela).
	var diff := GameManager.difficulty_multiplier()
	var hp_mult := Bestiary.screen_multiplier(GameManager.current_screen) * diff
	var dmg_mult := Bestiary.damage_multiplier(GameManager.current_screen) * diff
	_reward_mult = hp_mult

	health = HealthComponent.new()
	add_child(health)
	health.setup(int(base_health * hp_mult))
	health.died.connect(_on_died)

	hurtbox.team = "enemy"
	hurtbox.hit_received.connect(_on_hit_received)

	contact_hitbox.team = "enemy"
	contact_hitbox.damage = int(contact_damage * dmg_mult)
	contact_hitbox.unblockable = false
	contact_hitbox.monitoring = true

	attack_hitbox.team = "enemy"
	attack_hitbox.damage = int(attack_damage * dmg_mult)
	attack_hitbox.unblockable = is_elite or behavior == "exploder"
	attack_hitbox.monitoring = false

	if visual and profile != null:
		visual.set_profile(profile)
		_fit_body(profile.height / 44.0)
		if type_id.begins_with("eco_"):
			visual.self_modulate = Color(1, 1, 1, 0.72)   # eco: translúcido

	# Arte ilustrada opcional por id: se existir o PNG, usa no lugar do procedural
	# (senão mantém o desenho procedural — fallback, sem erro).
	_apply_illustrated_art()
	_setup_readability()
	# Pedido da Encenação: o chefe que nasce junto com o CARD DE CHEFE (mundo
	# pausado no mesmo quadro) não aparecia, porque o CharacterArt só monta a
	# pose no _process. Monta UMA pose agora (desenho não depende de pausa).
	if visual != null and visual.profile != null:
		visual.set_anim("idle")
		visual._process(0.0)

	player = get_tree().get_first_node_in_group("player")
	_boss_setup()   # chefes6: cérebro de chefe (scripts/entities/bosses/)
	if is_boss_enemy or is_champion:
		get_tree().call_group("hud", "show_boss", self)
		_boss_intro_fx.call_deferred()


## Chefe/Campeão entra em cena: stinger + coluna de luz (deferred: a posição
## só está certa depois do add_child do Level).
func _boss_intro_fx() -> void:
	if not is_inside_tree():
		return
	Audio.play_sfx("boss_appear")
	VfxLibrary.boss_appear(get_parent(), global_position + Vector2(0, -20.0 * _art_scale), eye_color)


## "do Torpor" / "da Fome": o nome do Éon com o artigo certo (pro Campeão).
func _eon_title(screen: int) -> String:
	var n := RunManager.eon_name(screen)
	var fem := n in ["Fome", "Corrente", "Praga", "Coroa"]
	return ("da " if fem else "do ") + n


## Ajusta colisões e sombra ao tamanho do desenho, mantendo os pés no chão.
## (O desenho é escalado por `height/44`; as caixas crescem pra cima.)
func _fit_body(s: float) -> void:
	_art_scale = s
	visual.position.y = 24.0 * (1.0 - s)
	var hs := clampf(s, 0.7, 2.6)
	for path in ["Collision", "Hurtbox/HurtShape", "ContactHitbox/ContactShape", "AttackHitbox/AttackShape"]:
		var shp: CollisionShape2D = get_node(path)
		shp.scale = Vector2(hs, hs)
		shp.position.y = -(hs - 1.0) * 22.0
	if has_node("Shadow"):
		$Shadow.scale = Vector2(hs, hs)


## LEITURA (#30 do crítico / NEURO R18): inimigo escuro some no fundo escuro.
## Sem tocar no CharacterArt: (1) o desenho passa a morar num CanvasGroup
## ("Rim") cujo shader põe um contorno externo de ~1 px na cor do Éon (α 0,5);
## (2) a sombra de contato fica mais densa, um pouco mais larga e PRESA AO
## CHÃO (no ar ela fica no piso e encolhe — mostra onde o inimigo vai cair).
func _setup_readability() -> void:
	if visual == null:
		return
	if RIM_ENABLED:
		var g := CanvasGroup.new()
		g.name = "Rim"
		g.fit_margin = 6.0
		g.clear_margin = 6.0
		var m := ShaderMaterial.new()
		m.shader = VfxLibrary.rim_shader()
		var eon := RunManager.eon_index(GameManager.current_screen)
		var rc: Color = VfxLibrary.eon_rim_color(eon)
		m.set_shader_parameter("rim_color", Color(rc.r, rc.g, rc.b, RIM_ALPHA))
		m.set_shader_parameter("rim_px", 1.0)
		g.material = m
		_rim_mat = m
		var idx := visual.get_index()
		add_child(g)
		move_child(g, idx)
		visual.reparent(g, false)
	if has_node("Shadow"):
		var sh: Polygon2D = $Shadow
		sh.color = Color(0, 0, 0, SHADOW_ALPHA)
		sh.scale = sh.scale * Vector2(SHADOW_WIDEN, 1.0)
		_shadow_base = sh.position
		_shadow_scale = sh.scale


## Sombra de contato presa ao chão: no ar, fica no piso e encolhe com a altura.
func _pin_shadow() -> void:
	if not has_node("Shadow"):
		return
	var sh: Polygon2D = $Shadow
	if is_on_floor() or estate == EState.DEAD:
		_floor_y = global_position.y
		sh.position = _shadow_base
		sh.scale = _shadow_scale
		sh.modulate.a = 1.0
		return
	if is_nan(_floor_y):
		return
	var up: float = maxf(0.0, _floor_y - global_position.y)
	var k: float = clampf(1.0 - up / 220.0, 0.45, 1.0)
	sh.global_position = Vector2(global_position.x, _floor_y + _shadow_base.y * scale.y)
	sh.scale = _shadow_scale * k
	sh.modulate.a = k


## Arte ilustrada por id (rota híbrida — chefes). Se existir
## `assets/characters/<id>.png`, desenha o sprite no lugar do procedural.
## `<id>_orb.png` (opcional) vira um orbe-olho que flutua acima e brilha no tell.
func _apply_illustrated_art() -> void:
	if visual == null:
		return
	if not _art_id in ["rei", "rei_final", "demiurgo"]:
		return
	_orb = Sprite2D.new()
	_orb.texture = PaintedLibrary.region("yaldabaoth",Rect2(1065,155,400,550))
	_orb.material = PaintedLibrary.material()
	_orb.position = ORB_HOME
	_orb.scale = Vector2.ONE * 72.0 / 550.0
	add_child(_orb)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if slow_timer > 0.0:
		slow_timer -= delta
	if rooted_timer > 0.0:
		rooted_timer -= delta

	# ANTI-SOFTLOCK: inimigo que caiu pra fora da arena (empurrado por
	# knockback/teleporte) volta pro meio — senão a wave nunca fecha. Os
	# limites vêm da ZONA trancada (Level.arena_bounds), não de um x fixo:
	# a travessia vai até x≈4300 e a zona 3 nasce longe do 640.
	if estate != EState.DEAD:
		var lo := -800.0
		var hi := 1800.0
		var mid := 640.0
		var lv := get_parent()
		if lv != null and lv.has_method("arena_bounds"):
			var b: Vector2 = lv.arena_bounds()
			lo = b.x - 60.0
			hi = b.y + 60.0
			mid = (b.x + b.y) * 0.5
		if global_position.y > 560.0 or global_position.x < lo or global_position.x > hi:
			global_position = Vector2(mid, 200.0)
			velocity = Vector2.ZERO
			reset_physics_interpolation()

	match estate:
		EState.CHASE:   _process_chase(delta)
		EState.WINDUP:  _process_windup(delta)
		EState.STRIKE:  _process_strike(delta)
		EState.RECOVER: _process_recover(delta)
		EState.HURT:    _process_stun(delta)
		EState.STAGGER: _process_stun(delta)
		EState.DEAD:    velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)

	_kit_passive(delta)
	move_and_slide()
	_pin_shadow()
	_sync_anim()
	_animate_orb(delta)


## Efeitos contínuos das assinaturas de chefe. Com cérebro (chefes6), a
## assinatura mora no script do chefe; o `match` abaixo é o legado (sem cérebro).
func _kit_passive(delta: float) -> void:
	if player == null or not is_instance_valid(player) or estate == EState.DEAD:
		return
	if brain != null:
		brain.passive(delta)
		return
	match kit:
		"silencio":
			# Aura de silêncio: perto dele, as magias da Sophia não saem.
			var r := 150.0 * (1.3 if phase == 2 else 1.0)
			if global_position.distance_to(player.global_position) < r:
				player.silenced_timer = 0.3
		"fome":
			# Sucção: durante o wind-up, a boca sem fim puxa a Sophia.
			if estate == EState.WINDUP:
				var pull := 150.0 if phase == 1 else 260.0
				player.global_position.x += signf(global_position.x - player.global_position.x) * pull * delta
	# Bibliotecário Mudo: aura curta que cala as magias.
	if behavior == "silencer" and global_position.distance_to(player.global_position) < 95.0:
		player.silenced_timer = 0.3


## Orbe-olho: flutua (sin), gira de leve e brilha mais forte no wind-up (tell).
func _animate_orb(delta: float) -> void:
	if _orb == null:
		return
	_orb_t += delta
	_orb.position = ORB_HOME + Vector2(sin(_orb_t * 1.3) * 6.0, sin(_orb_t * 0.9) * 11.0)
	_orb.rotation = sin(_orb_t * 0.5) * 0.14
	var glow: float = 1.7 if estate == EState.WINDUP else 1.0
	_orb.modulate = Color(glow, glow, glow, 1.0)


func _sync_anim() -> void:
	if visual == null:
		return
	visual.pose_progress = -1.0
	visual.motion_stride = clampf(absf(velocity.x) / maxf(move_speed,1.0),0.0,1.5)
	visual.motion_fury = 1.18 if phase == 2 else 1.0
	match estate:
		EState.WINDUP:
			visual.pose_progress = clampf(1.0-attack_timer/maxf(wind_up,0.01),0,1)
			# O telegrafo é a pose: braço puxado (melee), arma erguida (slam),
			# cajado carregando (atirador), corpo agachado (investida).
			match attack_style:
				"slam": visual.set_anim("windup_heavy")
				"ranged": visual.set_anim("windup_cast")
				"charge": visual.set_anim("windup_heavy" if profile_is_beast() else "windup")
				_: visual.set_anim("windup")
		EState.STRIKE:
			visual.pose_progress = clampf(1.0-attack_timer/maxf(strike_time,0.01),0,1)
			match attack_style:
				"slam": visual.set_anim("attack_heavy")
				"ranged": visual.set_anim("cast")
				"charge": visual.set_anim("charge")
				_: visual.set_anim("attack")
		EState.RECOVER:
			visual.pose_progress = clampf(1.0-attack_timer/maxf(recover_time,0.01),0,1)
			visual.set_anim("recover")
		EState.HURT, EState.STAGGER: visual.set_anim("hurt")
		EState.DEAD: visual.set_anim("dead")
		EState.CHASE: visual.set_anim("walk" if absf(velocity.x) > 5.0 else "idle")
		_: visual.set_anim("idle")


func profile_is_beast() -> bool:
	return visual != null and visual.profile != null and visual.profile.body == ArtProfile.Body.BEAST


func _process_chase(delta: float) -> void:
	if brain != null and brain.chase(delta):   # chefes6: o chefe decide
		return
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if player == null or not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		return

	var dx := player.global_position.x - global_position.x
	var dy := absf(player.global_position.y - global_position.y)

	# Comportamentos especiais de wave.
	_special_timer -= delta
	match behavior:
		"teleport":
			# Fantasma: some e reaparece do OUTRO lado da Sophia.
			if _special_timer <= 0.0 and absf(dx) > 110.0:
				_special_timer = 2.6
				_blink_to(player.global_position.x + signf(dx) * 56.0)
				return
		"summoner":
			if _special_timer <= 0.0:
				_special_timer = 6.0
				_prune_minions()
				if _minions.size() < 3:
					_summon("larva", 2)
		"dodger":
			# Reflexo: no instante em que a Sophia golpeia perto, ele recua num salto.
			if _special_timer <= 0.0 and absf(dx) < 80.0 and player is Player and player.state == Player.State.ATTACK:
				_special_timer = 1.6
				velocity.x = -signf(dx) * 320.0
				velocity.y = -140.0
				_flash(Color(1.8, 1.9, 2.4, 1))
				return

	# Preso pela Corrente da Lei: não anda (mas ainda ataca se estiver perto).
	if rooted_timer > 0.0:
		velocity.x = 0.0
		if absf(dx) <= attack_range and dy < 60.0 and cooldown_timer <= 0.0:
			_begin_windup()
		return

	if absf(dx) <= attack_range and dy < 60.0 and cooldown_timer <= 0.0:
		_begin_windup()
		return

	var dir := signf(dx)
	# Atirador/invocador mantém distância: recua se o player chegar perto demais.
	if (attack_style == "ranged" or behavior == "summoner") and absf(dx) < 130.0:
		dir = -dir
	var spd := move_speed * (0.5 if slow_timer > 0.0 else 1.0)
	velocity.x = dir * spd + _separation()
	if visual and dx != 0.0:
		visual.scale.x = absf(visual.scale.x) * signf(dx)


## IA de grupo: empurra pra longe de outros inimigos em cima (cercam, não empilham).
func _separation() -> float:
	var push := 0.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e):
			continue
		var d: float = global_position.x - e.global_position.x
		if absf(d) < SEPARATION and absf(global_position.y - e.global_position.y) < 40.0:
			var side := 1.0
			if d < 0.0:
				side = -1.0
			elif d == 0.0 and get_instance_id() < e.get_instance_id():
				side = -1.0
			push += side * (SEPARATION - absf(d)) * 2.5
	return clampf(push, -60.0, 60.0)


## Teleporte curto com clarão nas duas pontas.
func _blink_to(x: float) -> void:
	# Nunca pisca pra fora da zona trancada (ficaria preso atrás da parede).
	var lv := get_parent()
	if lv != null and lv.has_method("arena_bounds"):
		var b: Vector2 = lv.arena_bounds()
		x = clampf(x, b.x + 30.0, b.y - 30.0)
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -14), eye_color)
	global_position.x = x
	reset_physics_interpolation()       # teleporte: não interpola o caminho
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -14), eye_color)
	_flash(Color(2.5, 2.5, 3.0, 1))
	if visual and player != null and is_instance_valid(player):
		visual.scale.x = absf(visual.scale.x) * signf(player.global_position.x - global_position.x)


func _begin_windup() -> void:
	estate = EState.WINDUP
	attack_timer = wind_up
	velocity.x = 0.0
	# Silêncio, fase 2: pisca pra trás da Sophia antes de atacar.
	if kit == "silencio" and phase == 2 and brain == null and player != null and is_instance_valid(player):
		_blink_to(player.global_position.x - float(player.facing) * 44.0)
	atk_dir = 1
	if player != null and is_instance_valid(player):
		atk_dir = int(signf(player.global_position.x - global_position.x))
		if atk_dir == 0:
			atk_dir = 1
	# R5: tinge 45 % (a arte pintada não escurece) e guarda como cor-base: um
	# flash de dano no meio do telegrafo volta para ELA, não para branco.
	var tell := TELEGRAPH_UNBLOCKABLE if attack_hitbox.unblockable else TELEGRAPH_PARRYABLE
	if _framed():
		# Pedido 2 da Arte: chefe por quadros = CONTORNO pulsante na cor do aviso
		# (o CharacterArt desenha); a pintura do quadro de preparação fica intacta.
		visual.telegraph_color = Color(tell.r, tell.g, tell.b, TELEGRAPH_RIM_A)
		_tint_base = Color(1, 1, 1, 1)
	else:
		_tint_base = Color(1, 1, 1, 1).lerp(tell, TELEGRAPH_TINT)
	_glint_done = attack_timer <= GLINT_LEAD
	_glint_t = -1.0
	if visual and _flash_t < 0.0:
		visual.modulate = _tint_base


func _process_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	attack_timer -= delta
	# R5: brilho de aviso quando a janela de parry abre (180 ms antes do golpe).
	if not _glint_done and attack_timer <= GLINT_LEAD:
		_glint_done = true
		_tell_glint()
	if attack_timer <= 0.0:
		_begin_strike()


## Brilho de aviso (R5): estrela no ponto da arma — REDONDA e amarela =
## aparável, LOSANGO vermelho = imparável (forma + som, não só cor) — e o
## corpo clareia um instante. Som: "tell_parry"/"tell_unblock" (do Áudio2) —
## só toca se o nome já estiver no CATÁLOGO (sem ele, o aviso segue mudo e o
## AudioQA não reprova: o nome vai numa variável, não literal).
func _tell_glint() -> void:
	_glint_t = 0.0
	var unb: bool = attack_hitbox.unblockable
	var pos := global_position + Vector2(18.0 * atk_dir * _art_scale, -18.0 * _art_scale)
	if _orb != null:
		pos = _orb.global_position
	VfxLibrary.tell_glint(get_parent(), pos, unb)
	_tell_sound("tell_unblock" if unb else "tell_parry", pos)


## Toca o som do telegrafo se ele existir no catálogo do Áudio.
func _tell_sound(snd: String, pos: Vector2) -> void:
	var cat = Audio.get("CATALOG")
	if not (cat is Dictionary):
		return
	var sfx = cat.get("sfx", [])
	if sfx is Array and sfx.has(snd):
		Audio.play_sfx_at(snd, pos)


func _begin_strike() -> void:
	estate = EState.STRIKE
	attack_timer = strike_time
	_tint_base = Color(1, 1, 1, 1)
	if _framed():
		visual.telegraph_color.a = 0.0   # o golpe saiu: o contorno apaga já
	_glint_t = -1.0
	if visual and _flash_t < 0.0:
		visual.modulate = Color(1, 1, 1, 1)
	# o dano sai no começo do STRIKE (hitbox/projétil/explosão): impact_at = 0
	impact_at = 0.0
	if visual:
		visual.set_meta("impact_at", impact_at)
	attack_impact.emit()
	if brain != null and brain.strike():   # chefes6: golpe do chefe
		return
	if behavior == "exploder":
		_explode()
		return
	match attack_style:
		"ranged":
			# Comum: 1 projétil. CHEFE: uma salva de 3 (leque vertical).
			var offs: Array = [-16.0, 0.0, 16.0] if is_boss_enemy else [0.0]
			if kit == "rei" and type_id == "rei":
				offs = [0.0]                       # o Rei-tutorial atira 1 orbe lento
			for oy in offs:
				var p := Projectile.new()
				p.direction = atk_dir
				# Salva de chefe: cada projétil fere 65% (a salva CHEIA tirava
				# ~70% da vida — balance 2026-09-11, dados do bot).
				p.damage = int(attack_hitbox.damage * 0.65) if offs.size() > 1 else attack_hitbox.damage
				p.speed = 300.0
				p.pierce = false
				p.target_team = "player"
				p.color = eye_color
				p.lifetime = 1.6
				match behavior:
					"slowshot":
						p.slow_time = 1.6
						p.speed = 220.0
						p.color = Color(0.75, 0.8, 1.0)
					"chainshot":
						p.root_time = 0.8
						p.speed = 260.0
						p.color = Color(0.8, 0.8, 0.88)
				if kit == "rei":
					p.speed = 200.0 if type_id == "rei" else 280.0
					p.lifetime = 2.4
					p.color = Color(1.0, 0.85, 0.5)
				get_parent().add_child(p)
				var origin := global_position + Vector2(16.0 * atk_dir, -8.0 * _art_scale + oy)
				if _orb != null:
					origin = _orb.global_position + Vector2(0, oy)   # sai do orbe-olho
				p.global_position = origin
		"charge":
			# Investida. CHEFE: mais rápida + deixa um rastro de choque na saída.
			if is_boss_enemy:
				AoeNova.spawn(get_parent(), global_position + Vector2(0, 14), 0, 80.0, eye_color)
			attack_hitbox.position.x = 0.0
			attack_hitbox.activate()
			velocity.x = atk_dir * _charge_speed
			_pool_timer = 0.0
		"slam":
			# Pancada no chão. CHEFE: onda MUITO maior e golpe mais largo.
			var rad: float = 120.0 if is_boss_enemy else 70.0
			AoeNova.spawn(get_parent(), global_position + Vector2(0, 14), 0, rad, eye_color)
			Juice.shake(0.5 if is_boss_enemy else 0.35)
			attack_hitbox.position.x = 0.0
			attack_hitbox.scale = Vector2(3.8 if is_boss_enemy else 2.6, 1.0)
			attack_hitbox.activate()
		_:
			# Corpo a corpo. CHEFE: alcance maior.
			attack_hitbox.position.x = 28.0 * atk_dir
			if is_boss_enemy:
				attack_hitbox.scale = Vector2(1.7, 1.4)
			attack_hitbox.activate()
	_kit_strike()


## Extra de chefe no instante do golpe (a assinatura de cada Arconte).
func _kit_strike() -> void:
	if player == null or not is_instance_valid(player):
		return
	match kit:
		"torpor":
			# Névoa do sono cai onde a Sophia está: dentro dela, ela anda devagar.
			var r := 55.0 if phase == 1 else 85.0
			HazardZone.spawn(get_parent(), Vector2(player.global_position.x, global_position.y + 14.0), "sleep", r, 4.0, eye_color)
		"corrente":
			# Corrente: projétil que PRENDE a Sophia no lugar (esquivar quebra).
			var p := Projectile.new()
			p.direction = atk_dir
			p.damage = int(attack_hitbox.damage * 0.5)
			p.speed = 260.0
			p.pierce = false
			p.target_team = "player"
			p.color = Color(0.78, 0.78, 0.85)
			p.lifetime = 1.4
			p.root_time = 1.1 if phase == 1 else 1.6
			get_parent().add_child(p)
			p.global_position = global_position + Vector2(20.0 * atk_dir, -20.0 * _art_scale)
		"espelho":
			# Espelho: avança como a Sophia avança (lunge do golpe).
			velocity.x = atk_dir * 260.0
		"coroa":
			# Coroa, fase 2: a pancada solta uma onda rasteira pelo chão.
			if phase == 2:
				_ground_wave(atk_dir, 0.6)
		"rei":
			# O Rei, fase 2: além do orbe, uma onda rasteira que obriga a pular.
			if phase == 2:
				_ground_wave(atk_dir, 0.5)
		"colosso":
			# O Colosso: a pancada manda ondas pros DOIS lados (fase 2: mais rápidas).
			_ground_wave(1, 0.5)
			_ground_wave(-1, 0.5)


## Onda rasteira pelo chão (projétil baixo).
func _ground_wave(dir: int, dmg_mult: float) -> void:
	var p := Projectile.new()
	p.direction = dir
	p.damage = int(attack_hitbox.damage * dmg_mult)
	p.speed = 220.0 if phase == 1 else 300.0
	p.pierce = false
	p.target_team = "player"
	p.color = eye_color
	p.lifetime = 1.8
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(30.0 * dir, 12.0)


## Larva Ardente: explode (dano em área imparável) e morre.
func _explode() -> void:
	var r := 90.0
	var pos := global_position + Vector2(0, -8)
	AoeNova.spawn(get_parent(), pos, 0, r, Color(1.0, 0.55, 0.25))
	ImpactBurst.spawn(get_parent(), pos, Color(1.0, 0.6, 0.3))
	Juice.shake(0.45)
	if player != null and is_instance_valid(player) and player.global_position.distance_to(pos) <= r:
		player._on_hit_received(attack_hitbox.damage, pos, 260.0, true, self)
	health.take_damage(health.max_health)


func _process_strike(delta: float) -> void:
	if brain != null:
		brain.strike_tick(delta)   # chefes6
	elif attack_style == "charge":
		velocity.x = atk_dir * _charge_speed     # mantém a arrancada
		if kit == "praga":
			# Praga: a investida deixa poças de veneno pelo caminho.
			_pool_timer -= delta
			if _pool_timer <= 0.0:
				_pool_timer = 0.11
				# Balance P3 (docs/onda2/BALANCE.md): poças 5,0→3,0 s e raio da fase 2
				# 48→40 — a poça de Belias era o pico de dano do run inteiro.
				var r := 34.0 if phase == 1 else PRAGA_POOL_R2
				HazardZone.spawn(get_parent(), global_position + Vector2(0, 14), "poison", r, PRAGA_POOL_TIME, eye_color)
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_hitbox.deactivate()
		attack_hitbox.scale = Vector2.ONE
		estate = EState.RECOVER
		attack_timer = recover_time


func _process_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	attack_timer -= delta
	if attack_timer <= 0.0:
		estate = EState.CHASE
		cooldown_timer = attack_cooldown


func _process_stun(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	attack_timer -= delta
	# No ar (lançado), só volta a agir depois de pousar.
	if attack_timer <= 0.0 and is_on_floor():
		estate = EState.CHASE


# --- invocações -----------------------------------------------------------

func _summon(id: String, count: int) -> void:
	var scn = load(ENEMY_SCENE)
	if scn == null:
		return
	for i in count:
		var m = scn.instantiate()
		m.type_id = id
		get_parent().add_child(m)
		var ox := (float(i) - float(count - 1) * 0.5) * 120.0
		m.global_position = global_position + Vector2(ox, -20.0)
		m.reset_physics_interpolation()     # nasce já no lugar (sem rastro desde a origem)
		ImpactBurst.spawn(get_parent(), m.global_position, eye_color)
		_minions.append(m)
		minion_spawned.emit(m)


func _prune_minions() -> void:
	var alive: Array = []
	for m in _minions:
		if is_instance_valid(m) and m.estate != EState.DEAD:
			alive.append(m)
	_minions = alive


# --- fases de chefe (chefes6) ----------------------------------------------

## Cérebro do chefe (scripts/entities/bosses/*): decide golpes, fases e arena.
## null = inimigo comum (ou chefe sem script: cai no legado de 2 fases).
var brain: BossBrain = null
## Limiares de fase (fração da vida) — o HUD pode desenhar os marcadores.
var phase_marks: Array = [0.5]


## Monta o cérebro do chefe (se houver script para ele). A vida passa a vir de
## BossTuning (golpes-alvo × golpe médio da Sophia na tela).
func _boss_setup() -> void:
	if not is_boss_enemy or type_id.begins_with("eco_"):
		return
	var path := BossBrain.script_for(type_id, kit)
	if path == "":
		return
	var scr = load(path)
	if scr == null:
		return
	var b = scr.new()
	if not (b is BossBrain):
		return
	brain = b
	add_child(brain)
	brain.setup(self)
	phase_marks = brain.marks.duplicate()


## Confere se o dano levou o chefe à próxima fase. true = mudou de fase.
func _boss_phase_check() -> bool:
	if brain != null:
		return brain.check_phase()
	if phase == 1 and health.current_health <= health.max_health / 2:
		_enter_phase2()
		return true
	return false


## Legado (chefe sem cérebro): fase 2 a 50 %.
func _enter_phase2() -> void:
	_enter_phase(2)


## Nova FASE: rugido (atordoado e intocável ~1,3 s), tremor, clarão, nova,
## a barra do HUD pisca e a fala da fase entra como legenda (sem pausar).
## Com cérebro, o resto (golpes novos, arena) é do script do chefe.
func _enter_phase(n: int) -> void:
	phase = n
	estate = EState.STAGGER
	attack_timer = 0.9 if brain == null else BossBrain.PHASE_ROAR
	attack_hitbox.deactivate()
	attack_hitbox.scale = Vector2.ONE
	_tint_base = Color(1, 1, 1, 1)
	Juice.shake(0.7 + 0.15 * float(n - 2))
	Juice.hit_stop(0.15)
	Audio.play_sfx("boss_phase2")
	Audio.duck_music(0.8, -8.0)
	AoeNova.spawn(get_parent(), global_position, 0, 140.0 + 40.0 * float(n - 2), eye_color)
	VfxLibrary.boss_phase2(get_parent(), global_position + Vector2(0, -24.0 * _art_scale), eye_color)
	_flash(Color(3, 2.5, 2, 1))
	if brain == null:
		move_speed *= 1.25
		attack_cooldown *= 0.7
		wind_up *= 0.85
		match kit:
			"coroa":
				# A Coroa chama a corte: blindada enquanto os servos viverem.
				_summon("servo", 2)
				armored = true
			"espelho":
				# O Espelho devolve a Sophia contra ela mesma.
				_summon("sombra_sophia", 1)
	else:
		move_speed *= 1.1
	get_tree().call_group("hud", "boss_phase", n)
	# Gancho do Roteiro: legendas da fase (sem pausar a luta). Fase 3 só se a
	# Narrativa tiver as falas (pedido em docs/pedidos/onda6_chefes6.md).
	if is_boss_enemy and RunManager.run_active and Gnosis.has_method("captions"):
		if n == 2 and Narrative.has_method("archon_phase2"):
			Gnosis.captions(Narrative.archon_phase2(type_id))
		elif n == 3 and Narrative.has_method("archon_phase3"):
			Gnosis.captions(Narrative.call("archon_phase3", type_id))


# --- dano ------------------------------------------------------------------

## Chamado por magias/efeitos que ignoram hitbox (dano direto).
func apply_damage(amount: int, source_position: Vector2, knockback: float) -> void:
	_on_hit_received(amount, source_position, knockback, false, null)


## Névoa do Sono (magia da Sophia): anda na metade da velocidade.
func apply_slow(t: float) -> void:
	slow_timer = maxf(slow_timer, t)


## Corrente da Lei (magia da Sophia): preso no lugar (chefes: metade do tempo).
func apply_root(t: float) -> void:
	rooted_timer = maxf(rooted_timer, t * (0.5 if is_boss_enemy else 1.0))
	_flash(Color(1.6, 1.6, 2.2, 1))


## Glutão: cada golpe que acerta cura uma parte do dano.
func on_hit_landed(dmg: int) -> void:
	if behavior == "leech" and estate != EState.DEAD:
		health.heal(int(dmg * 0.6))
		_flash(Color(1.2, 2.2, 1.2, 1))


## Batalha final: a forma caída se refaz com `ratio` da vida.
func revive(ratio: float) -> void:
	if estate != EState.DEAD:
		return
	health.current_health = int(health.max_health * ratio)
	health.health_changed.emit(health.current_health, health.max_health)
	estate = EState.STAGGER
	attack_timer = 1.0
	phase = 1
	contact_hitbox.monitoring = true
	hurtbox.monitoring = true
	_flash_t = -1.0
	_tint_base = Color(1, 1, 1, 1)
	if visual:
		visual.modulate = Color(1, 1, 1, 1)
		visual.damage_ratio = 1.0 - ratio
	if _orb != null:
		_orb.visible = true
	_set_rim(1.0)
	Audio.play_sfx("form_revive")
	AoeNova.spawn(get_parent(), global_position, 0, 150.0, eye_color)
	VfxLibrary.boss_phase2(get_parent(), global_position + Vector2(0, -24.0 * _art_scale), eye_color)
	get_tree().call_group("hud", "show_boss", self)


func _on_hit_received(damage: int, source_position: Vector2, knockback: float, _unblockable: bool = false, attacker: Node = null) -> void:
	if estate == EState.DEAD:
		return
	var kb_dir := signf(global_position.x - source_position.x)
	if kb_dir == 0.0:
		kb_dir = 1.0

	# Escudeiro: golpe LEVE bate no escudo. Só pesado ou magia passam.
	if behavior == "shield" and attacker is Player and estate != EState.HURT and estate != EState.STAGGER:
		var mv: ComboData = attacker.current_move
		if mv == null or not mv.is_heavy():
			_flash(Color(2.2, 2.2, 3.0, 1))
			ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -12), Color(0.8, 0.85, 1.0))
			velocity.x = kb_dir * knockback * 0.25
			return

	# Pretoriano: golpe leve pela FRENTE bate no broquel (metade do dano).
	if behavior == "guard" and attacker is Player:
		var mv2: ComboData = attacker.current_move
		var from_front := signf(source_position.x - global_position.x) == signf(visual.scale.x) if visual else true
		if from_front and (mv2 == null or not mv2.is_heavy()):
			damage = maxi(1, damage / 2)
			_flash(Color(2.0, 1.9, 1.4, 1))

	if brain != null:
		damage = brain.filter_damage(damage, attacker)   # chefes6
		if damage <= 0:
			_flash(Color(1.6, 1.6, 2.0, 1))
			return
	# Coroa: enquanto os servos vivem, o Arconte é blindado.
	if armored:
		_prune_minions()
		if _minions.is_empty():
			armored = false
		else:
			damage = maxi(1, int(damage * 0.25))

	# Registra o tipo do golpe (decide se a morte desmembra) e o impulso.
	_last_hit_heavy = false
	var launcher_hit := false
	if attacker is Player:
		var mv: ComboData = attacker.current_move
		_last_hit_heavy = mv != null and (mv.is_heavy() or mv.launcher)
		launcher_hit = mv != null and mv.launcher
	elif attacker == null:
		_last_hit_heavy = true          # magias / novas
	_last_kick = Vector2(kb_dir * knockback * 0.9, -knockback * 0.4)

	# FINISHER: o golpe que mata o último inimigo vivo sempre desmembra. A câmera
	# lenta é RACIONADA (R8): chefe sempre; comum só no fim da TELA ou se o golpe
	# final foi pesado, aéreo ou lançador — senão o +33 ms de morte do Hitbox
	# basta. Magia/nova (attacker null) não entra: a Coroa já tem o seu slow-mo.
	if damage >= health.current_health and attacker is Player:
		if is_boss_enemy:
			Juice.slow_mo(0.15, 1.1)
		elif _alive_enemies() <= 1:
			force_dismember = true
			var mvf: ComboData = attacker.current_move
			var big_blow: bool = mvf != null and (mvf.is_heavy() or mvf.air or mvf.launcher)
			if big_blow or _is_screen_end():
				Juice.slow_mo(0.22, 0.55)

	health.take_damage(damage)
	# Este golpe matou: o _on_died já pôs DEAD e cuidou da morte (inclusive a
	# forma "caída" da batalha final, que precisa FICAR em DEAD para o revive).
	# Daqui para baixo nada pode mexer no estado (antes virava HURT com vida 0 e
	# a forma revivível nunca mais morria — bug bloqueante da tela 68).
	var died_now: bool = estate == EState.DEAD
	hurt_power = clampf(float(damage) / maxf(1.0, float(health.max_health)) * 4.0 + knockback / 600.0, 0.0, 1.0)
	if visual:
		visual.set_meta("hurt_power", hurt_power)
	if not (died_now and revivable):      # a forma caída: o tween de queda manda na cor
		_flash(Color(3, 3, 3, 1), VIB_HEAVY if _last_hit_heavy else VIB_LIGHT)
	# R4: a voz de dor cansa antes do impacto — no máximo 1 a cada 250 ms.
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_hurt_voice_ms >= HURT_VOICE_MS:
		_last_hurt_voice_ms = now_ms
		Audio.play_sfx_at("enemy_hurt", global_position)
	if attacker == null:
		# magia/nova (sem Hitbox): o impacto grande nasce aqui; golpe do Hitbox
		# já ganhou o seu VFX no ponto de contato (R4: um só por acerto).
		VfxLibrary.hit(get_parent(), global_position + Vector2(0, -12.0 * _art_scale), true, eye_color)
	DamageNumber.spawn(get_parent(), global_position, damage, Color(1.0, 0.92, 0.6))
	if visual:
		visual.damage_ratio = 1.0 - float(health.current_health) / maxf(1.0, float(health.max_health))
	if died_now or estate == EState.DEAD:
		return

	# Gigantes quase não recuam.
	velocity.x = kb_dir * knockback / maxf(1.0, _art_scale)
	velocity.y = -120.0 / maxf(1.0, _art_scale)

	if is_boss_enemy and not health.is_dead() and _boss_phase_check():   # chefes6
		return
	if brain != null and not brain.flinch(damage, launcher_hit):   # chefes6: postura
		return
	# Elite e chefe têm armadura durante o telegrafo (não são interrompidos).
	if estate == EState.WINDUP and (is_elite or is_boss_enemy):
		return
	attack_hitbox.deactivate()
	estate = EState.HURT
	attack_timer = 0.25
	if health.is_dead():
		return
	# LANÇADOR: joga o inimigo pro alto (chefes não sobem; gigantes sobem pouco).
	if launcher_hit and not is_boss_enemy:
		velocity.y = -420.0 / maxf(1.0, _art_scale * 0.8)
		velocity.x = kb_dir * 40.0
		attack_timer = 0.9
	# JUGGLE: acertar no ar mantém no ar (pop) — a pancada fica em cadeia.
	elif not is_on_floor() and not is_boss_enemy:
		velocity.y = minf(velocity.y, -190.0 / maxf(1.0, _art_scale))
		attack_timer = 0.5


## Quantos inimigos ainda vivos na tela (pra detectar o finisher).
func _alive_enemies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.estate != EState.DEAD:
			n += 1
	return n


## Este é o fim da TELA? (última wave da última zona) — R8: só aí o comum
## ganha câmera lenta de finalização.
func _is_screen_end() -> bool:
	var lv := get_parent()
	if lv == null or not lv.has_method("arena_bounds"):
		return true
	var zs = lv.get("zones")
	var ws = lv.get("waves")
	if not (zs is Array and ws is Array):
		return true
	return int(lv.get("zone_index")) >= zs.size() - 1 and int(lv.get("wave_index")) >= ws.size() - 1


## Chamado quando o player apara (parry) um golpe deste inimigo.
func stagger() -> void:
	if estate == EState.DEAD:
		return
	attack_hitbox.deactivate()
	estate = EState.STAGGER
	attack_timer = 0.7
	_tint_base = Color(1, 1, 1, 1)
	if visual and _flash_t < 0.0:
		visual.modulate = Color(1, 1, 1, 1)
	var kb := 1.0
	if player != null and is_instance_valid(player):
		kb = signf(global_position.x - player.global_position.x)
		if kb == 0.0:
			kb = 1.0
	velocity.x = kb * 170.0 / maxf(1.0, _art_scale)
	velocity.y = -110.0 / maxf(1.0, _art_scale)
	_flash(Color(3, 3, 3, 1), VIB_HEAVY)


func _on_died() -> void:
	if estate == EState.DEAD:
		return
	estate = EState.DEAD
	_tint_base = Color(1, 1, 1, 1)
	_set_rim(0.0)
	contact_hitbox.monitoring = false
	attack_hitbox.monitoring = false
	# som e explosão de morte por porte
	var death_pos := global_position + Vector2(0, -12.0 * _art_scale)
	if is_boss_enemy:
		Audio.play_sfx("boss_die")
		VfxLibrary.boss_death(get_parent(), death_pos, eye_color)
	elif is_champion:
		Audio.play_sfx("champion_die")
		VfxLibrary.elite_death(get_parent(), death_pos, eye_color)
	elif is_elite:
		Audio.play_sfx("elite_die")
		VfxLibrary.elite_death(get_parent(), death_pos, eye_color)
	else:
		Audio.play_sfx("enemy_die")
		VfxLibrary.enemy_death(get_parent(), death_pos, eye_color)

	Progression.add_orbs(int(spark_reward * _reward_mult))
	# A faísca se liberta e voa até o herói (assinatura GoW).
	SparkOrb.burst(get_parent(), global_position + Vector2(0, -10), clampi(spark_reward / 2, 3, 9))
	if is_boss_enemy:
		Juice.rumble(0.5, 0.9, 0.5)   # o trono cai — o controle sente
	# Portador de Esporos: deixa uma poça de veneno onde cai.
	if behavior == "spores":
		HazardZone.spawn(get_parent(), global_position + Vector2(0, 24.0 * _art_scale), "poison", 60.0, 5.0, eye_color)
	defeated.emit(self)

	if visual == null:
		queue_free()
		return
	# Batalha final: a forma cai mas fica (pode se refazer).
	if revivable:
		_flash_t = -1.0                     # o tween de "forma caída" manda no modulate
		hurtbox.set_deferred("monitoring", false)
		visual.dissolve_max = 0.55          # desfaz só em parte: pode se refazer
		visual.set_anim("dead")
		var tr := create_tween()
		tr.tween_property(visual, "modulate", Color(0.6, 0.6, 0.7, 0.25), 0.6)
		if _orb != null:
			_orb.visible = false
		return
	# DESMEMBRAMENTO: golpe pesado/magia/finisher (ou chefe) arranca o corpo em
	# peças que voam e quicam. Golpe leve: o corpo cai e apaga.
	var dismember := force_dismember or _last_hit_heavy or is_boss_enemy or behavior == "exploder"
	var parts: Array = visual.gib_parts()
	if dismember and not parts.is_empty():
		if is_boss_enemy:
			# Pedido 4 da Arte: o quadro de morte desenhado aparece ~0,4 s (pose
			# "dead" + começo da dissolução) e SÓ ENTÃO o corpo se parte.
			Juice.hit_stop(0.18)
			_death_pose_then_burst()
		else:
			_burst_gibs(parts)
	else:
		# MORTE POR DISSOLUÇÃO: o shader desfaz a pintura em ruído com borda
		# luminosa (CharacterArt._dissolve_amount, ~0,9 s); o cartão não tomba.
		visual.set_anim("dead")
		var t := create_tween()
		t.tween_interval(0.95)
		t.tween_property(visual, "modulate:a", 0.0, 0.12)
		t.tween_callback(queue_free)


## Chefe: pose de morte por DEATH_POSE_TIME s REAIS (ignora câmera lenta e
## pausa — a cena que começa logo depois não pode segurar o corpo em pé) e
## depois desmembra. Se a árvore estiver pausada nessa hora (diálogo/cena), não
## espalha gibs congelados no ar: o corpo só some.
func _death_pose_then_burst() -> void:
	velocity = Vector2.ZERO
	hurtbox.set_deferred("monitoring", false)
	visual.set_anim("dead")
	var t := create_tween().set_ignore_time_scale(true)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_interval(DEATH_POSE_TIME)
	t.tween_callback(func() -> void:
		if get_tree().paused:
			visual.visible = false
			if _orb != null:
				_orb.visible = false
			queue_free()
			return
		var parts: Array = visual.gib_parts()   # do quadro de morte já desenhado
		if parts.is_empty():
			queue_free()
			return
		Juice.shake(0.9)
		_burst_gibs(parts))


## Desmembramento: peças que voam e quicam + estouro; o corpo some.
func _burst_gibs(parts: Array) -> void:
	var facing := signf(visual.scale.x)
	if facing == 0.0:
		facing = 1.0
	var ground := global_position.y + 24.0 * _art_scale
	var kick := _last_kick
	if is_boss_enemy:
		kick *= 1.6
	Gib.burst(get_parent(), visual.global_position, parts, facing, ground, kick, eye_color, visual._ink())
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -12.0 * _art_scale), eye_color)
	visual.visible = false
	if _orb != null:
		_orb.visible = false
	queue_free()


## Chefe que toca quadros desenhados (contorno no telegrafo, quadro de morte).
func _framed() -> bool:
	return visual != null and visual.has_method("has_boss_frames") and visual.has_boss_frames()


## Liga/desliga o contorno de leitura (0..1).
func _set_rim(v: float) -> void:
	if _rim_mat != null:
		_rim_mat.set_shader_parameter("rim_strength", v)


## R1/R10: flash INSTANTÂNEO (no mesmo quadro), mantido enquanto durar o
## hitstop e apagado em FLASH_FADE s REAIS de volta para a cor-base do estado
## (o telegrafo, se estiver no WINDUP — antes voltava para branco e apagava o
## aviso: bug do R5). Força limitada pelo Juice: cheio ≤ 3/s por inimigo, chefe
## com teto 2,0, "Reduzir flashes". `vibrate` > 0 = treme no hitstop (R1).
func _flash(color: Color, vibrate: float = 0.0) -> void:
	if visual == null:
		return
	var k: float = Juice.flash_strength(self, is_boss_enemy)
	_flash_col = Color(1, 1, 1, 1).lerp(color, k)
	_flash_col.a = 1.0
	_flash_t = 0.0
	visual.modulate = Color(_flash_col.r, _flash_col.g, _flash_col.b, visual.modulate.a)
	if vibrate > 0.0:
		_vib_amp = vibrate / maxf(1.0, _art_scale * 0.7)   # gigante treme menos
		_vib_until_ms = Time.get_ticks_msec() + 250
		_vib_seen = false


## Cor-base agora: telegrafo (com pulso de 2 Hz e o brilho de aviso) no
## WINDUP, branco no resto.
func _base_tint() -> Color:
	if estate != EState.WINDUP:
		return Color(1, 1, 1, 1)
	var t := float(Time.get_ticks_msec()) / 1000.0
	var pulse := 1.0 + sin(t * TAU * TELEGRAPH_PULSE_HZ) * TELEGRAPH_PULSE / TELEGRAPH_TINT
	var c := Color(1, 1, 1, 1).lerp(_tint_base, clampf(pulse, 0.0, 2.0))
	if _glint_t >= 0.0 and _glint_t < GLINT_TIME:
		c = c.lerp(Color(1.6, 1.6, 1.6, 1), GLINT_BOOST * (1.0 - _glint_t / GLINT_TIME))
	c.a = 1.0
	return c


## Flash, telegrafo e vibração correm em tempo REAL (o hitstop deixa o jogo a 5 %).
func _process(delta: float) -> void:
	if visual == null:
		return
	var real_dt: float = delta / maxf(Engine.time_scale, 0.001)
	var frozen: bool = Juice.hitstop_active()
	if _glint_t >= 0.0:
		_glint_t += delta
	var alpha: float = visual.modulate.a   # a dissolução/morte mexe no alfa: preserva
	if _flash_t >= 0.0:
		if not frozen:
			_flash_t += real_dt
		var k := 1.0 - clampf(_flash_t / FLASH_FADE, 0.0, 1.0)
		var c := _base_tint().lerp(_flash_col, k)
		visual.modulate = Color(c.r, c.g, c.b, alpha)
		if k <= 0.0:
			_flash_t = -1.0
	elif estate == EState.WINDUP:
		var b := _base_tint()
		visual.modulate = Color(b.r, b.g, b.b, alpha)
	if _vib_amp > 0.0:
		var now := Time.get_ticks_msec()
		if frozen:
			_vib_seen = true
			var side := 1.0 if (now / VIB_STEP_MS) % 2 == 0 else -1.0
			var a := _vib_amp * Juice.hitstop_left() * side
			_vib_offset(Vector2(a, 0.0) if is_on_floor() else Vector2(0.0, a))
		elif _vib_seen or now > _vib_until_ms:
			_vib_amp = 0.0
			_vib_offset(Vector2.ZERO)


## Desloca só o desenho (hurtbox e colisão ficam paradas). O y-base do visual
## vem do _fit_body (pés no chão): soma/desfaz só o deslocamento da vibração.
func _vib_offset(o: Vector2) -> void:
	visual.position += o - _vib_cur
	_vib_cur = o
