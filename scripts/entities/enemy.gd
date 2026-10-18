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

## GUARD (Onda 6): o comum ergue a guarda por um instante (leve pela frente
## quase não passa; pesado QUEBRA; magia ignora). Fica no fim: os números antigos
## não mudam.
enum EState { CHASE, WINDUP, STRIKE, RECOVER, HURT, STAGGER, DEAD, GUARD }

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
const FLASH_ADD := 0.55           # Onda 6: brilho somado no pico do flash aditivo (× força do Juice)
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
## Onda 6: cor do CAMPEÃO por Éon [giro de matiz (rad), saturação, tinta] — o
## oposto da cor-assinatura do Arconte daquele Éon (o bot é da família dele).
const CHAMPION_GRADE := [
	[2.6, 0.95, Color(1.05, 1.0, 0.9)],     # Torpor: anil de Athoth → âmbar
	[2.4, 0.85, Color(1.0, 1.0, 1.0)],      # Fome: vermelho de Harmas → verde-água
	[0.0, 0.55, Color(1.15, 0.85, 0.6)],    # Corrente: cinza de Galila → bronze
	[2.8, 0.9, Color(1.0, 1.0, 1.0)],       # Silêncio: anil de Yabel → ocre
	[0.0, 0.3, Color(0.6, 0.52, 0.66)],     # Espelho: prata de Astaphaios → obsidiana
	[2.2, 0.95, Color(1.0, 1.0, 1.0)],      # Praga: verde de Belias → violeta
	[3.0, 0.7, Color(0.85, 0.92, 1.1)],     # Coroa: ouro de Armupiel → prata-azul
]
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

# --- Onda 6 (inimigos6): repertório, voo, reflexos, elite e fila de agressão ---
## Repertório (EnemyMoves.for_type): vazio = comportamento antigo por `style`
## (chefes, ecos e a Sombra da Sophia seguem nele).
var moves: Array = []
var role: String = "melee"            # tank / melee / skirm / shooter / flyer
var guard_chance: float = 0.0         # chance de erguer a guarda quando a Sophia golpeia perto
var evade_chance: float = 0.0         # chance de saltar pra trás no mesmo instante
var fly_height: float = 0.0           # >0 = VOADOR: paira essa altura acima do chão
var elite_mod: String = ""            # Elite: escudo / furia / regen (visível na EnemyOverlay)
var barrier: int = 0                  # escudo de elite: absorve antes da vida
var barrier_max: int = 0
var guard_dir: int = 1
var tele_target: Vector2 = Vector2.INF   # alvo do mergulho/investida (linha de aviso)
var used_moves: Dictionary = {}       # id do golpe → vezes (a sonda confere)
var _mv: Dictionary = {}              # golpe em curso
var _mv_cd: Dictionary = {}           # recarga própria por golpe
var _combo_left: int = 0
var _hit_dmg: int = 0                 # dano-base da caixa já escalado pela tela
var _rng := RandomNumberGenerator.new()
var _rng_ready: bool = false
var _react_cd: float = 0.6
var _guard_t: float = 0.0
var _counter: bool = false            # bloqueou um golpe: contra-ataca em seguida
var _downed: float = 0.0              # voador derrubado (cai e fica vulnerável)
var _perched: float = 0.0             # voador pousado depois do mergulho
var _grab_hold: float = -1.0          # agarrão: segurando a Sophia (s até o arremesso)
var _regen_idle: float = 0.0
var _regen_acc: float = 0.0
var _orbit_side: float = 1.0
var _orbit_t: float = 0.0
var _champ_fury: bool = false
var _ground_origin: float = NAN       # y do corpo se estivesse no chão logo abaixo
var _flash_layer: EnemyFlashLayer = null

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
	# Onda 6: repertório próprio dos comuns (chefes ficam no `style`/`kit`).
	var kitdef: Dictionary = {} if is_boss_enemy else EnemyMoves.for_type(type_id)
	if not kitdef.is_empty():
		moves = (kitdef.moves as Array).duplicate(true)
		role = kitdef.role
		guard_chance = kitdef.guard
		evade_chance = kitdef.evade
		fly_height = kitdef.fly

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
		scale = Vector2(1.35, 1.35)
		# Onda 6: repertório de elite (o do bot + brado e onda dupla), lê e
		# reage mais — mini-chefe com a cara do BOT, nunca a do Arconte.
		if not moves.is_empty():
			moves.append_array(EnemyMoves.champion_extras())
			guard_chance = minf(0.6, guard_chance + 0.15)
			evade_chance = minf(0.5, evade_chance + 0.1)
	elif is_elite and not moves.is_empty():
		guard_chance = minf(0.6, guard_chance + 0.1)
		elite_mod = _pick_elite_mod()
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
	# Onda 6 (playtest 2 do João): SEM DANO DE CONTATO. A Sophia tomava dano só
	# por encostar/acertar o inimigo — a dificuldade vinha disso, não dos golpes.
	# Agora só fere o que tem telegrafo (golpes, investidas, mergulhos, zonas).
	contact_hitbox.monitoring = false

	attack_hitbox.team = "enemy"
	attack_hitbox.damage = int(attack_damage * dmg_mult)
	_hit_dmg = attack_hitbox.damage
	_apply_elite_mod()
	attack_hitbox.unblockable = is_elite or behavior == "exploder"
	attack_hitbox.monitoring = false

	if visual and profile != null:
		visual.set_profile(profile)
		_fit_body(profile.height / 44.0)
		if def.has("tint"):
			visual.self_modulate = def.tint               # Onda 6: tinta própria do tipo
		if type_id.begins_with("eco_"):
			visual.self_modulate = Color(1, 1, 1, 0.72)   # eco: translúcido

	# Arte ilustrada opcional por id: se existir o PNG, usa no lugar do procedural
	# (senão mantém o desenho procedural — fallback, sem erro).
	_apply_illustrated_art()
	_setup_readability()
	_setup_layers()
	# Pedido da Encenação: o chefe que nasce junto com o CARD DE CHEFE (mundo
	# pausado no mesmo quadro) não aparecia, porque o CharacterArt só monta a
	# pose no _process. Monta UMA pose agora (desenho não depende de pausa).
	if visual != null and visual.profile != null:
		visual.set_anim("idle")
		visual._process(0.0)

	player = get_tree().get_first_node_in_group("player")
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
		var grade: Array = _body_grade(eon)
		if not grade.is_empty():
			m.shader = load(GRADE_SHADER)
			m.set_shader_parameter("grade_hue", float(grade[0]))
			m.set_shader_parameter("grade_sat", float(grade[1]))
			m.set_shader_parameter("grade_tint", grade[2])
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


const GRADE_SHADER := "res://scripts/entities/enemies/enemy_grade.gdshader"

## Graduação de cor do corpo: Campeão (por Éon) > a do tipo (bots, alado…) > nada.
func _body_grade(eon: int) -> Array:
	if is_boss_enemy:
		return []
	if is_champion:
		var bot := Bestiary.EON_BOTS.find(type_id)
		var i: int = bot if bot >= 0 else clampi(eon, 0, CHAMPION_GRADE.size() - 1)
		return CHAMPION_GRADE[clampi(i, 0, CHAMPION_GRADE.size() - 1)]
	var def := Bestiary.get_type(type_id)
	if String(def.get("id", "")) == type_id and def.has("grade"):
		return def.grade
	return []


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
	if fly_height > 0.0 and not is_nan(_ground_origin):
		_floor_y = _ground_origin
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
	if not is_on_floor() and not _flying():
		velocity.y += GRAVITY * delta
	_tick_onda6(delta)
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
		EState.GUARD:   _process_guard(delta)

	_hover(delta)
	_kit_passive(delta)
	move_and_slide()
	_pin_shadow()
	_sync_anim()
	_fit_hurtbox()
	_animate_orb(delta)


## Efeitos contínuos das assinaturas de chefe.
func _kit_passive(delta: float) -> void:
	if player == null or not is_instance_valid(player) or estate == EState.DEAD:
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
			match _anim_style():
				"slam": visual.set_anim("windup_heavy")
				"ranged": visual.set_anim("windup_cast")
				"charge": visual.set_anim("windup_heavy" if profile_is_beast() else "windup")
				_: visual.set_anim("windup")
		EState.STRIKE:
			visual.pose_progress = clampf(1.0-attack_timer/maxf(strike_time,0.01),0,1)
			match _anim_style():
				"slam": visual.set_anim("attack_heavy")
				"ranged": visual.set_anim("cast")
				"charge": visual.set_anim("charge")
				_: visual.set_anim("attack")
		EState.RECOVER:
			visual.pose_progress = clampf(1.0-attack_timer/maxf(recover_time,0.01),0,1)
			visual.set_anim("recover")
		EState.HURT, EState.STAGGER: visual.set_anim("hurt")
		EState.GUARD:
			visual.pose_progress = 0.35
			visual.set_anim("windup")
		EState.DEAD: visual.set_anim("dead")
		EState.CHASE: visual.set_anim("walk" if absf(velocity.x) > 5.0 else "idle")
		_: visual.set_anim("idle")


func profile_is_beast() -> bool:
	return visual != null and visual.profile != null and visual.profile.body == ArtProfile.Body.BEAST


func _process_chase(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	if player == null or not is_instance_valid(player):
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		return

	if not moves.is_empty():
		_chase_moves(delta)
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
	if kit == "silencio" and phase == 2 and player != null and is_instance_valid(player):
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
	if not _mv.is_empty():
		_windup_track()
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
	if not _mv.is_empty():
		_strike_move()
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
	if not _mv.is_empty():
		_strike_tick(delta)
		return
	if attack_style == "charge":
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
		if not moves.is_empty():
			_end_move()


func _process_stun(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	attack_timer -= delta
	# No ar (lançado), só volta a agir depois de pousar.
	if attack_timer <= 0.0 and (is_on_floor() or _flying()):
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


# --- fases de chefe --------------------------------------------------------

## A 50% de vida: fúria (mais rápido) + a assinatura do kit sobe de nível.
func _enter_phase2() -> void:
	phase = 2
	move_speed *= 1.25
	attack_cooldown *= 0.7
	wind_up *= 0.85
	estate = EState.STAGGER
	attack_timer = 0.9
	attack_hitbox.deactivate()
	_tint_base = Color(1, 1, 1, 1)
	Juice.shake(0.7)
	Juice.hit_stop(0.15)
	Audio.play_sfx("boss_phase2")
	AoeNova.spawn(get_parent(), global_position, 0, 140.0, eye_color)
	VfxLibrary.boss_phase2(get_parent(), global_position + Vector2(0, -24.0 * _art_scale), eye_color)
	_flash(Color(3, 2.5, 2, 1))
	match kit:
		"coroa":
			# A Coroa chama a corte: blindada enquanto os servos viverem.
			_summon("servo", 2)
			armored = true
		"espelho":
			# O Espelho devolve a Sophia contra ela mesma.
			_summon("sombra_sophia", 1)
	get_tree().call_group("hud", "boss_phase", 2)
	# Gancho do Roteiro: legendas da fase 2 (sem pausar a luta).
	if is_boss_enemy and RunManager.run_active and Gnosis.has_method("captions") and Narrative.has_method("archon_phase2"):
		Gnosis.captions(Narrative.archon_phase2(type_id))


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
	# Onda 6: o agarrão pegou (ela tomou o golpe — não aparou/bloqueou/esquivou).
	if not _mv.is_empty() and String(_mv.kind) == "grab" and _grab_hold < 0.0 			and player is Player and player.state == Player.State.HURT:
		_grab_start()
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
	contact_hitbox.monitoring = false     # Onda 6: sem dano de contato
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

	# Onda 6 — GUARDA: leve pela frente quase não passa; pesado QUEBRA a guarda
	# (atordoa); magia/nova (sem atacante) ignora. Depois de bloquear, contra-ataca.
	var guarded := false
	if estate == EState.GUARD and attacker is Player:
		var mvg: ComboData = attacker.current_move
		var front_g: bool = signf(source_position.x - global_position.x) == float(guard_dir)
		if front_g:
			if mvg != null and (mvg.is_heavy() or mvg.launcher):
				_guard_break()
			else:
				guarded = true
				damage = maxi(1, int(damage * 0.15))
				_counter = true
				ImpactBurst.spawn(get_parent(), global_position + Vector2(14.0 * guard_dir, -14.0 * _art_scale), Color(0.75, 0.88, 1.0))
				Audio.play_sfx_at("block", global_position)
	# Onda 6 — ESCUDO de elite: a bolha absorve antes da vida; ao zerar, estoura
	# e o elite fica atordoado (a recompensa de insistir).
	if barrier > 0 and damage > 0:
		var absorb: int = mini(barrier, damage)
		barrier -= absorb
		damage -= absorb
		_regen_idle = 0.0
		if barrier <= 0:
			_barrier_break()
		if damage <= 0:
			_flash(Color(1.6, 1.9, 2.6, 1))
			ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -16.0 * _art_scale), Color(0.6, 0.8, 1.0))
			DamageNumber.spawn(get_parent(), global_position, absorb, Color(0.6, 0.8, 1.0))
			return
	_regen_idle = 0.0

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
	if guarded:
		_flash(Color(1.6, 1.8, 2.6, 1), VIB_LIGHT)
	elif not (died_now and revivable):      # a forma caída: o tween de queda manda na cor
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
	if guarded:
		velocity.x *= 0.35
		velocity.y = 0.0
		return
	# Voador atingido no ar: DERRUBADO — cai (gravidade liga) e fica vulnerável.
	if fly_height > 0.0 and not is_on_floor():
		_downed = maxf(_downed, 1.4)
	_champion_fury_check()

	if is_boss_enemy and phase == 1 and not health.is_dead() and health.current_health <= health.max_health / 2:
		_enter_phase2()
		return
	# Elite e chefe têm armadura durante o telegrafo (não são interrompidos).
	if estate == EState.WINDUP and (is_elite or is_boss_enemy):
		return
	if estate == EState.STRIKE and is_champion:
		return                            # Campeão: o golpe que saiu não é cortado
	attack_hitbox.deactivate()
	_interrupt_move()
	estate = EState.HURT
	attack_timer = 0.25 + _stun_extra
	_stun_extra = 0.0
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
	_interrupt_move()
	if fly_height > 0.0:
		_downed = maxf(_downed, 1.6)     # aparar um voador o derruba
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
	EnemyAggro.release(self)
	tele_target = Vector2.INF
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
	var peak: float = maxf(color.r, maxf(color.g, color.b))
	# Onda 6 (QA2 #8): flash CLARO = camada ADITIVA curta por cima da pintura
	# (como o da Sophia) — o corpo não vira mais silhueta branca chapada.
	if peak > 1.0 and _flash_layer != null and is_instance_valid(_flash_layer) and _flash_layer.usable():
		var hue := Color(color.r / peak, color.g / peak, color.b / peak, 1.0)
		_flash_layer.fire(hue, FLASH_ADD * k * clampf((peak - 1.0) / 2.0, 0.35, 1.0))
	else:
		if peak > 1.0:
			# sem malha pintada (procedural/boneco): clareia pouco, não estoura
			color = Color(1, 1, 1, 1).lerp(color, 0.3)
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
	# a camada do flash copia o corpo já tremido
	if _flash_layer != null and is_instance_valid(_flash_layer):
		_flash_layer.tick(real_dt)


## Desloca só o desenho (hurtbox e colisão ficam paradas). O y-base do visual
## vem do _fit_body (pés no chão): soma/desfaz só o deslocamento da vibração.
func _vib_offset(o: Vector2) -> void:
	visual.position += o - _vib_cur
	_vib_cur = o


# =============================================================================
# ONDA 6 (inimigos6) — repertório por tipo, voadores, reflexos, elite, fila.
# Os chefes NÃO passam por aqui (moves vazio): seguem no `style`/`kit` acima.
# =============================================================================

var _evade_t: float = 0.0
var _stun_extra: float = 0.0


## Voando agora? (derrubado ou pousado = não; aí a gravidade volta)
func _flying() -> bool:
	return fly_height > 0.0 and estate != EState.DEAD and _downed <= 0.0 and _perched <= 0.0


## Contrato com o level6 (Level._is_flyer): voador de verdade (paira alto) nasce
## no ALTO da arena. O Fantasma (flutua a ~24 px) nasce no chão.
func is_flyer() -> bool:
	return fly_height > 40.0


## Voador no chão (derrubado/pousado) — a EnemyOverlay esconde as asas.
func is_downed() -> bool:
	return _downed > 0.0 or _perched > 0.0


## Relógios do repertório, regeneração de elite.
func _tick_onda6(delta: float) -> void:
	if moves.is_empty() or estate == EState.DEAD:
		return
	for k in _mv_cd.keys():
		_mv_cd[k] = maxf(0.0, float(_mv_cd[k]) - delta)
	_react_cd -= delta
	_intent_t -= delta
	_orbit_t += delta
	if _downed > 0.0:
		_downed -= delta
	if _perched > 0.0:
		_perched -= delta
	if elite_mod == "regen" and health != null:
		_regen_idle += delta
		if _regen_idle > 1.5 and health.current_health < health.max_health:
			_regen_acc += float(health.max_health) * 0.03 * delta
			var n := int(_regen_acc)
			if n > 0:
				_regen_acc -= float(n)
				health.heal(n)
				if visual:
					visual.damage_ratio = 1.0 - float(health.current_health) / maxf(1.0, float(health.max_health))


## Voador: paira `fly_height` acima do chão (ou da Sophia, se ela estiver num
## plano mais alto), com um balanço leve. No mergulho/rasante quem manda é o golpe.
func _hover(_delta: float) -> void:
	if fly_height <= 0.0:
		return
	_ground_origin = _ray_floor(global_position)
	if not _flying():
		return
	if estate == EState.STRIKE and String(_mv.get("kind", "")) in ["dive", "glide"]:
		return
	# referência = o chão DA SOPHIA (se ela pisa): sobre uma plataforma o voador
	# não sobe junto com o chão debaixo dele (ficava fora de alcance)
	var ref := _ground_origin
	if player != null and is_instance_valid(player) and player.is_on_floor():
		ref = player.global_position.y
	var target := ref - fly_height + sin(_orbit_t * 2.2) * 5.0
	velocity.y = clampf((target - global_position.y) * 5.0, -180.0, 180.0)


## y que o corpo teria apoiado no chão logo abaixo de `from` (raio no mundo).
func _ray_floor(from: Vector2) -> float:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 700), 1, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return from.y + fly_height
	return float(hit.position.y) - 24.0 * scale.y


## Altura dos pés da Sophia (para zonas, pilares e tiros que caem no chão).
func _player_feet_y() -> float:
	if player == null or not is_instance_valid(player):
		return global_position.y + 24.0
	if player.is_on_floor():
		return player.global_position.y + 24.0
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(player.global_position, player.global_position + Vector2(0, 700), 1)
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else player.global_position.y + 24.0


## Estilo de animação do golpe em curso (a pose de cada tipo de ataque).
func _anim_style() -> String:
	if _mv.is_empty():
		return attack_style
	match String(_mv.kind):
		"slam", "nova": return "slam"
		"shot", "burst", "lob", "pillar", "summon": return "ranged"
		"fissure": return "slam"
		"rush", "dive", "glide", "leap": return "charge"
	return "melee"


## CHASE com repertório: reflexo → escolhe golpe (se a fila deixar) → move pelo papel.
func _chase_moves(delta: float) -> void:
	if not _rng_ready:
		_rng_ready = true
		_rng.seed = hash([type_id, GameManager.current_screen, int(global_position.x)])
		cooldown_timer = _rng.randf_range(0.2, 0.9)   # a wave não ataca toda no mesmo quadro
		_orbit_side = 1.0 if _rng.randf() < 0.5 else -1.0
	var dx := player.global_position.x - global_position.x
	var adx := absf(dx)
	var dyv := player.global_position.y - global_position.y
	if visual and dx != 0.0:
		visual.scale.x = absf(visual.scale.x) * signf(dx)
	if _evade_t > 0.0:
		_evade_t -= delta
		return
	if _react(dx, dyv):
		return
	# atirador com a Sophia colada: quase não espera — empurra/explode e foge
	if role == "shooter" and adx < 70.0:
		cooldown_timer = minf(cooldown_timer, 0.15)
	if cooldown_timer <= 0.0 or _counter:
		# INTENÇÃO: decide o golpe primeiro e só então chega na distância dele
		# (antes ele soltava sempre o que coubesse onde estava — o de meia
		# distância ganhava sempre e o combo de perto quase nunca saía).
		if _intent.is_empty() or _intent_t <= 0.0 or float(_mv_cd.get(_intent.id, 0.0)) > 0.0:
			_intent = _pick_move(adx, dyv, true)
			_intent_t = 2.5
		var mv: Dictionary = _intent if not _intent.is_empty() and _in_range(_intent, adx, dyv) else {}
		if mv.is_empty() and _counter:
			mv = _pick_move(adx, dyv)
		if not mv.is_empty() and EnemyAggro.request(self, is_champion or _counter):
			_counter = false
			_intent = {}
			_start_move(mv)
			return
	if rooted_timer > 0.0:
		velocity.x = 0.0
		return
	var spd := move_speed * (0.5 if slow_timer > 0.0 else 1.0)
	var tx := _desired_x(dx, adx)
	velocity.x = clampf((tx - global_position.x) * 4.0, -spd, spd)
	if fly_height <= 0.0:
		velocity.x += _separation()


## Para onde andar, pelo PAPEL: tanque cola na frente, atirador fica atrás,
## flanqueador dá a volta, voador orbita por cima; quem está sem a vez (fila)
## espera numa "roda" a ~80 px, balançando — e não empilha em cima da Sophia.
func _desired_x(dx: float, adx: float) -> float:
	var px := player.global_position.x
	var side := -signf(dx) if dx != 0.0 else _orbit_side
	match role:
		"flyer":
			if fmod(_orbit_t, 5.5) < get_physics_process_delta_time():
				_orbit_side = -_orbit_side          # troca de lado: passa por cima dela
			return px + _orbit_side * (100.0 + 25.0 * sin(_orbit_t * 0.8))
		"shooter":
			if adx < 120.0:
				return px + side * 175.0
			if adx > 240.0:
				return px + side * 200.0
			return global_position.x
	var waiting: bool = cooldown_timer > 0.0 or (EnemyAggro.count() >= EnemyAggro.MAX_ATTACKERS and not EnemyAggro.holds(self))
	var ring := 34.0 if role == "tank" else 40.0
	if not _intent.is_empty():
		ring = clampf((float(_intent.rmin) + float(_intent.rmax)) * 0.5, 22.0, 140.0)
	if waiting:
		ring = (54.0 if role == "tank" else 80.0) + sin(_orbit_t * 1.7 + float(get_instance_id() % 7)) * 14.0
	if role == "skirm":
		# flanco: se um aliado já ocupa o meu lado, vou pelo outro
		for e in get_tree().get_nodes_in_group("enemy"):
			if e == self or not (e is Enemy) or e.estate == EState.DEAD or e.fly_height > 0.0:
				continue
			var ex: float = e.global_position.x - px
			if signf(ex) == side and absf(ex) < adx and absf(ex) < 90.0:
				side = -side
				break
	return px + side * ring


## Cabe agora? (faixa de distância e de altura do golpe)
func _in_range(m: Dictionary, adx: float, dyv: float) -> bool:
	if adx < float(m.rmin) or adx > float(m.rmax):
		return false
	if bool(m.air):
		return _flying()
	var vmax := 60.0 if String(m.kind) in ["swing", "combo", "grab", "rush", "slam", "nova", "explode", "leap"] else 200.0
	return absf(dyv) <= vmax


## Golpe sorteado pelo peso entre os prontos. `as_intent` = pode estar fora do
## alcance agora (ele anda até lá) — menos para atirador/voador e para os golpes
## de reação (nova/explosão), que só valem se já couberem.
func _pick_move(adx: float, dyv: float, as_intent: bool = false) -> Dictionary:
	var flying := _flying()
	var pool: Array = []
	var total := 0.0
	for m in moves:
		if float(_mv_cd.get(m.id, 0.0)) > 0.0:
			continue
		if bool(m.air) and not flying:
			continue
		var kind := String(m.kind)
		var must_fit: bool = not as_intent or role in ["shooter", "flyer"] or kind in ["nova", "explode"]
		if must_fit and not _in_range(m, adx, dyv):
			continue
		if as_intent and kind in ["nova", "explode"]:
			return m                      # golpe de reação que já cabe: é ele
		if kind == "summon":
			_prune_minions()
			if _minions.size() >= 3:
				continue
		pool.append(m)
		total += _move_weight(m)
	if pool.is_empty():
		return {}
	var r := _rng.randf() * total
	for m in pool:
		r -= _move_weight(m)
		if r <= 0.0:
			return m
	return pool[pool.size() - 1]


## Peso no sorteio: o golpe que acabou de sair pesa 1/3 (não repete à toa —
## "sempre a mesma coisa" era a queixa) e o que ainda não saiu nesta luta, 1,5×.
func _move_weight(m: Dictionary) -> float:
	var w := float(m.w)
	if String(m.id) == _last_mv_id:
		w *= 0.33
	elif not used_moves.has(m.id):
		w *= 1.5
	return w


var _last_mv_id: String = ""
var _intent: Dictionary = {}          # golpe decidido, ainda chegando na distância
var _intent_t: float = 0.0

## Começa o golpe: marca, arma a recarga, aviso (cor/linha) e o telegrafo.
func _start_move(mv: Dictionary) -> void:
	_mv = mv
	_last_mv_id = String(mv.id)
	used_moves[mv.id] = int(used_moves.get(mv.id, 0)) + 1
	_mv_cd[mv.id] = float(mv.cd)
	_combo_left = int(mv.hits) - 1
	var fast: bool = elite_mod == "furia" or _champ_fury
	wind_up = float(mv.wind) * (0.85 if fast else 1.0)
	attack_hitbox.unblockable = is_elite or bool(mv.unb) or behavior == "exploder"
	tele_target = Vector2.INF
	var kind := String(mv.kind)
	if kind == "retreat":
		# RECUO (atirador): salta pra trás, levanta poeira e volta a mirar — sem
		# telegrafo porque não fere; devolve a vez na fila na hora.
		var away := -1.0
		if player != null and is_instance_valid(player):
			away = -signf(player.global_position.x - global_position.x)
		velocity.x = away * 310.0
		if is_on_floor():
			velocity.y = -170.0
		_evade_t = 0.35
		VfxLibrary.dust(get_parent(), global_position + Vector2(0, 22.0 * _art_scale))
		EnemyAggro.release(self)
		_mv = {}
		cooldown_timer = 0.35
		return
	if kind == "blink" and player != null and is_instance_valid(player):
		# aparece ATRÁS da Sophia (do lado oposto ao que ela olha) e golpeia
		_blink_to(player.global_position.x - float(player.facing) * 52.0)
	_begin_windup()
	_windup_track(true)


## No telegrafo: vira pra Sophia e reajusta o alvo ATÉ abrir a janela de aparo
## (GLINT_LEAD); dali em diante o alvo fica travado — dá pra ler e sair.
func _windup_track(force: bool = false) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not force and attack_timer <= GLINT_LEAD:
		return
	var d := signf(player.global_position.x - global_position.x)
	if d != 0.0:
		atk_dir = int(d)
		if visual:
			visual.scale.x = absf(visual.scale.x) * d
	match String(_mv.kind):
		"dive", "leap":
			tele_target = player.global_position + Vector2(0, 6)
		"rush":
			tele_target = global_position + Vector2(atk_dir * float(_mv.speed) * 0.42, 0)
		"glide":
			tele_target = Vector2(player.global_position.x + atk_dir * 90.0, player.global_position.y)


## O golpe sai.
func _strike_move() -> void:
	var kind := String(_mv.kind)
	attack_hitbox.damage = maxi(1, int(_hit_dmg * float(_mv.dmg)))
	attack_hitbox.scale = Vector2.ONE
	attack_hitbox.position = Vector2.ZERO
	var hs := clampf(_art_scale, 0.7, 2.6)
	strike_time = 0.16
	match kind:
		"swing", "combo", "blink":
			var reach := float(_mv.reach)
			attack_hitbox.scale = Vector2(reach, 1.0)
			attack_hitbox.position.x = (18.0 + 12.0 * reach) * atk_dir * maxf(1.0, hs * 0.8)
			attack_hitbox.activate()
			var lunge := float(_mv.lunge)
			if lunge <= 0.0 and kind == "combo":
				lunge = 70.0
			velocity.x = atk_dir * lunge
			strike_time = 0.22 if lunge > 100.0 else (0.13 if kind == "combo" else 0.16)
		"grab":
			attack_hitbox.position.x = 22.0 * atk_dir * maxf(1.0, hs * 0.8)
			attack_hitbox.activate()
			velocity.x = atk_dir * 170.0
			strike_time = 0.24
		"rush":
			attack_hitbox.activate()
			velocity.x = atk_dir * float(_mv.speed)
			strike_time = 0.42
		"leap":
			var ldx: float = atk_dir * 100.0
			if tele_target != Vector2.INF:
				ldx = tele_target.x - global_position.x
			ldx = clampf(ldx, -190.0, 190.0)
			velocity = Vector2(ldx / 0.5, -330.0)
			attack_hitbox.activate()
			strike_time = 0.9
		"slam":
			var rad := 70.0 * maxf(1.0, hs * 0.8)
			AoeNova.spawn(get_parent(), global_position + Vector2(0, 14.0 * _art_scale), 0, rad, eye_color)
			Juice.shake(0.35)
			attack_hitbox.scale = Vector2(2.6, 1.0)
			attack_hitbox.activate()
			if bool(_mv.get("waves", false)):
				_wave_pair()
			strike_time = 0.18
		"nova":
			var nr := float(_mv.get("radius", 64.0)) * maxf(1.0, hs * 0.7)
			var np := global_position + Vector2(0, -8.0 * _art_scale)
			AoeNova.spawn(get_parent(), np, 0, nr, eye_color)
			Juice.shake(0.3)
			if player != null and is_instance_valid(player) and absf(player.global_position.x - np.x) <= nr and absf(player.global_position.y - global_position.y) < 70.0:
				player._on_hit_received(attack_hitbox.damage, np, 260.0, attack_hitbox.unblockable, self)
			strike_time = 0.2
		"shot":
			_fire_shots()
			strike_time = 0.18
		"burst":
			# RAJADA: N setas em sequência, cada uma mirada de novo
			_burst_left = int(_mv.count)
			_burst_t = 0.0
			strike_time = float(_burst_left) * 0.14 + 0.1
		"fissure":
			# FISSURA: lâmina rasteira pelo chão na direção dela (pula-se)
			_ground_spike(atk_dir)
			strike_time = 0.2
		"lob":
			_lob()
			strike_time = 0.2
		"pillar":
			_pillars()
			strike_time = 0.25
		"dive":
			var to := global_position + Vector2(atk_dir * 120.0, 120.0)
			if tele_target != Vector2.INF:
				to = tele_target
			velocity = (to - global_position).normalized() * 440.0
			attack_hitbox.scale = Vector2(1.2, 1.3)
			attack_hitbox.activate()
			strike_time = 0.9
		"glide":
			attack_hitbox.scale = Vector2(1.4, 1.0)
			attack_hitbox.activate()
			velocity.x = atk_dir * 330.0
			strike_time = 0.8
		"summon":
			_summon("larva", 2)
			strike_time = 0.25
		"explode":
			_explode()


## Enquanto o golpe dura (investidas, saltos, mergulho, agarrão).
var _burst_left: int = 0
var _burst_t: float = 0.0

func _strike_tick(delta: float) -> void:
	match String(_mv.kind):
		"burst":
			_burst_t -= delta
			if _burst_left > 0 and _burst_t <= 0.0:
				_burst_left -= 1
				_burst_t = 0.14
				_fire_shots(1)
		"rush":
			velocity.x = atk_dir * float(_mv.speed)
		"glide":
			velocity.x = atk_dir * 330.0
			var gy: float = global_position.y
			if tele_target != Vector2.INF:
				gy = tele_target.y
			velocity.y = clampf((gy - global_position.y) * 6.0, -300.0, 300.0)
		"dive":
			if is_on_floor() or (attack_timer < strike_time - 0.05 and get_slide_collision_count() > 0):
				# POUSO: poeira de choque e fica no chão (janela de castigo)
				_perched = 1.0
				AoeNova.spawn(get_parent(), global_position + Vector2(0, 14.0 * _art_scale), 0, 44.0, eye_color)
				Juice.shake(0.25)
				_finish_strike(1.0)
				return
		"leap":
			if attack_timer < strike_time - 0.12 and is_on_floor():
				if bool(_mv.get("slam", false)):
					AoeNova.spawn(get_parent(), global_position + Vector2(0, 14.0 * _art_scale), 0, 56.0, eye_color)
					Juice.shake(0.3)
					if player != null and is_instance_valid(player) and absf(player.global_position.x - global_position.x) < 56.0 and absf(player.global_position.y - global_position.y) < 50.0:
						player._on_hit_received(attack_hitbox.damage, global_position, 220.0, attack_hitbox.unblockable, self)
				_finish_strike(0.45)
				return
		"grab":
			if _grab_hold >= 0.0:
				velocity.x = 0.0
				_grab_hold -= delta
				if _grab_hold <= 0.0:
					_grab_throw()
					_finish_strike(0.5)
				return
	attack_timer -= delta
	if attack_timer <= 0.0:
		_finish_strike(_recover_for(String(_mv.kind)))


## Fim do golpe: próximo do combo (telegrafo curto) ou recuperação.
func _finish_strike(rec: float) -> void:
	attack_hitbox.deactivate()
	attack_hitbox.scale = Vector2.ONE
	if estate == EState.DEAD:
		return
	if _combo_left > 0:
		_combo_left -= 1
		wind_up = 0.24
		_begin_windup()
		return
	estate = EState.RECOVER
	attack_timer = rec * (0.8 if is_elite else 1.0)


## Recuperação por tipo de golpe (a janela de castigo da Sophia).
func _recover_for(kind: String) -> float:
	match kind:
		"combo", "rush", "nova", "grab": return 0.55
		"slam": return 0.6
		"shot": return 0.35
		"burst": return 0.4
		"fissure": return 0.45
		"lob", "pillar", "glide", "summon": return 0.4
		"leap": return 0.45
		"dive": return 0.8
	return 0.45


## Fim do golpe: devolve a vez na fila e arma a espera pelo papel.
func _end_move() -> void:
	EnemyAggro.release(self)
	_mv = {}
	tele_target = Vector2.INF
	_grab_hold = -1.0
	var cd := 0.85
	match role:
		"shooter": cd = 1.15
		"tank": cd = 1.0
		"flyer": cd = 0.95
		"skirm": cd = 0.7
	if elite_mod == "furia" or _champ_fury:
		cd *= 0.6
	cooldown_timer = cd


## Golpe cortado (tomou dano, aparado): solta a vez e a Sophia (se agarrava).
func _interrupt_move() -> void:
	if moves.is_empty():
		return
	EnemyAggro.release(self)
	if _grab_hold >= 0.0 and player is Player:
		player.root_timer = 0.0
	_mv = {}
	_combo_left = 0
	_grab_hold = -1.0
	tele_target = Vector2.INF
	_guard_t = 0.0


## REFLEXOS: a Sophia golpeia perto e de frente → às vezes ergue a guarda,
## às vezes salta pra trás. Recarga de 1,5 s (não é parede: é leitura).
func _react(dx: float, dyv: float) -> bool:
	if guard_chance + evade_chance <= 0.0 or _react_cd > 0.0:
		return false
	if not (player is Player) or player.state != Player.State.ATTACK:
		return false
	if absf(dx) > 90.0 or absf(dyv) > 50.0 or _flying():
		return false
	if float(player.facing) != signf(-dx):
		return false
	_react_cd = 1.5
	var r := _rng.randf()
	if r < guard_chance:
		estate = EState.GUARD
		_guard_t = 0.6
		guard_dir = int(signf(dx)) if dx != 0.0 else 1
		velocity.x = 0.0
		EnemyAggro.release(self)
		used_moves["_guarda"] = int(used_moves.get("_guarda", 0)) + 1
		return true
	if r < guard_chance + evade_chance:
		velocity.x = -signf(dx) * 300.0
		if is_on_floor():
			velocity.y = -150.0
		_evade_t = 0.28
		VfxLibrary.dust(get_parent(), global_position + Vector2(0, 22.0 * _art_scale))
		used_moves["_esquiva"] = int(used_moves.get("_esquiva", 0)) + 1
		return true
	return false


func _process_guard(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	_guard_t -= delta
	if _guard_t <= 0.0:
		estate = EState.CHASE
		if _counter:
			cooldown_timer = 0.0


## Golpe pesado na guarda: ela quebra (atordoa mais que um golpe comum).
func _guard_break() -> void:
	_guard_t = 0.0
	_counter = false
	_stun_extra = 0.6
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -14.0 * _art_scale), Color(0.75, 0.88, 1.0), true)
	Juice.shake(0.25)


## A bolha do elite estourou: atordoa (recompensa de insistir).
func _barrier_break() -> void:
	attack_hitbox.deactivate()
	_interrupt_move()
	estate = EState.STAGGER
	attack_timer = 0.9
	_stun_extra = 0.6
	AoeNova.spawn(get_parent(), global_position + Vector2(0, -16.0 * _art_scale), 0, 50.0, Color(0.6, 0.8, 1.0))
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -16.0 * _art_scale), Color(0.6, 0.8, 1.0), true)
	Juice.shake(0.3)
	Audio.play_sfx_at("block", global_position)


## Campeão a 50%: SEGUNDO FÔLEGO — fúria (mais rápido, menos espera).
func _champion_fury_check() -> void:
	if not is_champion or _champ_fury or moves.is_empty():
		return
	if health.current_health <= 0 or health.current_health > health.max_health / 2:
		return
	_champ_fury = true
	elite_mod = "furia"
	move_speed *= 1.2
	Juice.shake(0.4)
	VfxLibrary.boss_phase2(get_parent(), global_position + Vector2(0, -24.0 * _art_scale), eye_color)
	_flash(Color(3.0, 2.0, 1.5, 1))


## Modificador do Elite, fixo pela tela e pelo tipo (determinístico).
func _pick_elite_mod() -> String:
	var mods := ["escudo", "furia", "regen"]
	return mods[(GameManager.current_screen + absi(type_id.hash())) % mods.size()]


func _apply_elite_mod() -> void:
	match elite_mod:
		"escudo":
			barrier_max = int(health.max_health * 0.4)
			barrier = barrier_max
		"furia":
			move_speed *= 1.25


## Camadas da Onda 6: flash aditivo (todo inimigo, inclusive chefes) e a
## EnemyOverlay (asas/aura atrás, modificador/guarda/aviso na frente).
func _setup_layers() -> void:
	if visual == null:
		return
	var holder: Node = visual.get_parent()
	_flash_layer = EnemyFlashLayer.new()
	_flash_layer.name = &"FlashLayer"
	_flash_layer.art = visual
	holder.add_child(_flash_layer)
	holder.move_child(_flash_layer, visual.get_index() + 1)
	if moves.is_empty() and not is_elite and not is_champion:
		return
	var body: Node = holder if holder != self else visual
	var back := EnemyOverlay.new()
	back.name = &"OverlayBack"
	back.enemy = self
	back.front = false
	add_child(back)
	move_child(back, body.get_index())
	var front := EnemyOverlay.new()
	front.name = &"OverlayFront"
	front.enemy = self
	add_child(front)


# --- golpes à distância ---------------------------------------------------

## Tiro: 1 ou leque. Voando, MIRA na Sophia (de cima, na diagonal).
func _fire_shots(override_n: int = 0) -> void:
	var n := int(_mv.count) if override_n <= 0 else override_n
	var spread := float(_mv.spread)
	var origin := global_position + Vector2(16.0 * atk_dir, -8.0 * _art_scale)
	var aimed := _flying() or bool(_mv.air) or String(_mv.kind) == "burst"
	var base_dir := Vector2(atk_dir, 0)
	if aimed and player != null and is_instance_valid(player):
		base_dir = (player.global_position + Vector2(0, -4) - origin).normalized()
	var feet := _player_feet_y()
	for i in n:
		var a := (float(i) - float(n - 1) * 0.5) * spread
		var p := Projectile.new()
		p.direction = atk_dir
		p.damage = attack_hitbox.damage
		p.speed = float(_mv.speed)
		p.pierce = false
		p.target_team = "player"
		p.color = eye_color
		p.lifetime = 1.8
		if aimed or spread > 0.0:
			p.aim = base_dir.rotated(a)
		if aimed:
			p.ground_y = feet + 4.0
		p.look = String(_mv.get("look", "bolt" if String(_mv.kind) == "burst" else ""))
		var hom := float(_mv.get("homing", 0.0))
		if hom > 0.0:
			p.homing = hom
			p.homing_target = player
			p.lifetime = 3.6
			if p.aim == Vector2.ZERO:
				p.aim = base_dir
		match String(_mv.status):
			"slow":
				p.slow_time = 1.6
				p.color = Color(0.75, 0.8, 1.0)
			"root":
				p.root_time = 0.8
				p.color = Color(0.8, 0.8, 0.88)
		get_parent().add_child(p)
		p.global_position = origin


## Arremesso em arco: cai onde a Sophia está e deixa a zona (veneno/sono).
func _lob() -> void:
	if player == null or not is_instance_valid(player):
		return
	var g := 700.0
	var t := 0.85
	var origin := global_position + Vector2(10.0 * atk_dir, -14.0 * _art_scale)
	var target := Vector2(player.global_position.x, _player_feet_y())
	var v := Vector2((target.x - origin.x) / t, (target.y - origin.y - 0.5 * g * t * t) / t)
	var p := Projectile.new()
	p.direction = atk_dir
	p.damage = attack_hitbox.damage
	p.aim = v
	p.speed = v.length()
	p.arc_gravity = g
	p.ground_y = target.y
	p.land_kind = String(_mv.zone)
	p.land_radius = 38.0
	p.land_time = 2.6 if p.land_kind == "sleep" else 3.0
	p.look = "seed"
	p.pierce = false
	p.target_team = "player"
	p.color = Color(0.75, 1.0, 0.5) if p.land_kind == "poison" else Color(0.72, 0.78, 1.0)
	p.lifetime = 2.2
	get_parent().add_child(p)
	p.global_position = origin


## Colunas de luz: uma onde a Sophia está (e, com count 2, outra onde ela vai).
func _pillars() -> void:
	if player == null or not is_instance_valid(player):
		return
	var feet := _player_feet_y()
	var xs: Array = [player.global_position.x]
	if int(_mv.count) >= 2:
		xs.append(player.global_position.x + float(player.facing) * 72.0)
	var lv := get_parent()
	for x in xs:
		var px: float = x
		if lv != null and lv.has_method("arena_bounds"):
			var b: Vector2 = lv.arena_bounds()
			px = clampf(px, b.x + 20.0, b.y - 20.0)
		HazardZone.pillar(get_parent(), Vector2(px, feet), 30.0, 0.72, attack_hitbox.damage, eye_color.lerp(Color.WHITE, 0.3))


## Ondas rasteiras pros DOIS lados (pancadas de tanque/Campeão).
func _wave_pair() -> void:
	for dir in [1, -1]:
		var p := Projectile.new()
		p.direction = dir
		p.damage = int(attack_hitbox.damage * 0.6)
		p.speed = 230.0
		p.pierce = false
		p.target_team = "player"
		p.color = eye_color
		p.lifetime = 1.3
		p.look = "spike"
		get_parent().add_child(p)
		p.global_position = global_position + Vector2(30.0 * dir, 14.0 * _art_scale)


## Uma lâmina rasteira só, na direção da Sophia (fissura).
func _ground_spike(dir: int) -> void:
	var p := Projectile.new()
	p.direction = dir
	p.damage = attack_hitbox.damage
	p.speed = 250.0
	p.pierce = false
	p.target_team = "player"
	p.color = eye_color
	p.lifetime = 1.4
	p.look = "spike"
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(26.0 * dir, 14.0 * _art_scale)


# --- agarrão (aparável: amarelo) -----------------------------------------------

## Pegou: a Sophia fica presa e, em 0,7 s, é arremessada. ESQUIVAR solta
## (a esquiva quebra o agarrão e os i-frames dela anulam o arremesso).
func _grab_start() -> void:
	_grab_hold = 0.7
	if player is Player:
		player.root_timer = maxf(player.root_timer, 0.8)
	Audio.play_sfx_at("rooted", global_position)
	ImpactBurst.spawn(get_parent(), player.global_position + Vector2(0, -10), eye_color)


func _grab_throw() -> void:
	if player == null or not is_instance_valid(player):
		return
	if absf(player.global_position.x - global_position.x) > 70.0:
		return                     # ela escapou (esquiva)
	var dmg := int(_hit_dmg * 0.9)
	player._on_hit_received(dmg, global_position, 340.0, true, self)
	Juice.shake(0.35)
	if behavior == "leech":
		health.heal(int(dmg * 0.6))


# --- caixa de dano = corpo DESENHADO (playtest 2: "o cajado atravessa") ---------

## A Hurtbox segue o quadro pintado que está na tela: altura do topo da cabeça
## ao pé (`top`/`foot_y` do JSON do quadro), centrada na pélvis (`pelvis_x`),
## largura ~metade do recorte (sem a arma/o pano solto) — e acompanha a mola do
## corpo (`_body_xform`), o vira-lado e o voo. Sem quadros (procedural/boneco
## antigo): fica a caixa do _fit_body. Suaviza 35 %/quadro (sem tremer).
## API usada (leitura) do CharacterArt: _boss_db.meta, _shown_key, _body_xform —
## pedido à Arte uma função oficial `body_rect()` (docs/pedidos/onda6_inimigos6.md).
var hurt_rect: Rect2 = Rect2()        # última caixa (local do inimigo) — sonda/depuração

func _fit_hurtbox() -> void:
	if visual == null or estate == EState.DEAD or not visual.has_boss_frames():
		return
	var key: String = visual._shown_key
	var cut := key.rfind(":")
	if cut <= 0:
		return
	var meta: Dictionary = visual._boss_db.meta
	var seq: Dictionary = meta.states.get(key.substr(0, cut), {})
	var i := int(key.substr(cut + 1))
	if seq.is_empty() or i < 0 or i >= seq.frames.size():
		return
	var e: Dictionary = seq.frames[i]
	var fr: Dictionary = meta.frames.get(e.f, {})
	if fr.is_empty() or not fr.has("top"):
		return
	var rr: Array = fr.rect
	var anchor := Vector2(e.anchor[0], e.anchor[1])
	var h: float = float(fr.foot_y) - float(fr.top)
	var w: float = clampf(float(rr[2]) * 0.5, h * 0.3, h * 1.0)
	var cx: float = float(fr.get("pelvis_x", float(rr[2]) * 0.5))
	var a: Vector2 = Vector2(cx - w * 0.5, float(fr.top)) - anchor
	var b: Vector2 = Vector2(cx + w * 0.5, float(fr.foot_y)) - anchor
	var xf: Transform2D = visual.transform * visual._body_xform
	var p1 := xf * a
	var p2 := xf * b
	var r := Rect2(p1, Vector2.ZERO).expand(p2)
	if r.size.x < 4.0 or r.size.y < 4.0:
		return
	hurt_rect = r
	var shp: CollisionShape2D = $Hurtbox/HurtShape
	var base: Vector2 = (shp.shape as RectangleShape2D).size
	var want_s := Vector2(r.size.x / base.x, r.size.y / base.y)
	shp.position = shp.position.lerp(r.get_center(), 0.35)
	shp.scale = shp.scale.lerp(want_s, 0.35)
