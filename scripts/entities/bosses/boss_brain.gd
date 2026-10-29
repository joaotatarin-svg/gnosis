extends Node
class_name BossBrain
## CÉREBRO DE CHEFE (Onda 6, chefes6). Mora como filho do Enemy do chefe e
## decide a luta: QUAL golpe, QUANDO, de que DISTÂNCIA, e o que muda em cada
## uma das 3 FASES (a 66 % e a 33 % da vida). O Enemy continua dono do corpo
## (física, estados WINDUP→STRIKE→RECOVER, dano, quadros desenhados); o
## cérebro só escolhe e executa os golpes. Cada Arconte é um script filho
## (boss_athoth.gd, …) que descreve os golpes por fase e a ASSINATURA dele.
##
## Regras de justiça (NEURO_SATISFACAO): todo golpe tem telegrafo de FORMA e
## SOM (círculo amarelo = aparável, losango vermelho = imparável — o Enemy faz
## no WINDUP; os perigos de chão fazem o deles); depois de golpes grandes vem
## um RESPIRO (recuperação longa = janela de punição); nada de sorteio sem
## leitura: o sorteio só escolhe ENTRE golpes legíveis, semeado pela tela.
##
## Golpe = Dictionary:
##   id, kind ("melee"|"slam"|"charge"|"shot"|"cast"), anim ("melee"|"slam"|
##   "ranged"|"charge" — escolhe o quadro de preparação/golpe), wind, strike,
##   recover (s), unblock (bool), rmin/rmax (distância em x pra usar), w (peso),
##   cd (s de espera até repetir), dmg (× dano base), aa (serve contra a Sophia
##   no alto), chain (Array de ids: golpes que vêm colados, sem respiro)
##   + parâmetros do tipo (off, sx, sy, waves, speed, count, …).

var e: Enemy = null
var phase: int = 1
var marks: Array = BossTuning.PHASE_MARKS
var moves: Dictionary = {}            # fase (int) -> Array[Dictionary]
var mv: Dictionary = {}               # golpe em curso
var rng := RandomNumberGenerator.new()
var screen: int = 1
## Faixa de distância preferida (x): abaixo de x recua, acima de y avança.
var keep_dist := Vector2(40.0, 70.0)
## Pausa entre golpes por fase (o "respiro" onde a Sophia pune).
var gap_by_phase: Array = [1.1, 0.85, 0.65]
## POSTURA: o chefe não recua a cada cutucada. Só depois de POISE_HITS golpes
## seguidos (sem 3 s de folga) ele quebra a guarda e fica atordoado.
const POISE_HITS := 12.0
const POISE_REST := 3.0
const BREAK_STAGGER := 1.5            # s atordoado ao quebrar a postura (punição)
const PARRY_STAGGER := 1.1            # s atordoado depois de um APARO
const PHASE_ROAR := 1.3               # s da transição de fase (invulnerável)
## SAI DE CIMA: quem cola e bate ESCAPE_HITS vezes em ESCAPE_WINDOW s leva o
## golpe de repulsão (vermelho, curto) — o chefe não é saco de pancada; a
## leitura é "3–4 golpes e sai". Cada chefe pode trocar o `escape_id`.
## Multiplicador de dano por estado do chefe (as JANELAS de punição).
var window_mult := {
	Enemy.EState.WINDUP: 0.5, Enemy.EState.STRIKE: 0.5, Enemy.EState.CHASE: 0.85,
	Enemy.EState.RECOVER: 1.1, Enemy.EState.STAGGER: 1.3, Enemy.EState.HURT: 1.0,
}
## GUARDA ALTA (re-teste QA7 da 3.1, 28/10): nos chefes do fim, quem só martela
## no neutro e no meio do golpe dele fica batendo no "armado" (faísca azul, dano
## baixo) e não quebra a postura tão fácil; a punição de verdade sai nas JANELAS
## (recuperação, golpe exposto, atordoado, aparo) — que continuam iguais. Mexe na
## LEITURA, não na vida: o jogador médio que espera a hora sente pouco; o que
## aperta sem parar sente muito.
var _armed_sfx_t: float = -9.0


func guard_up(k_chase: float, k_armed: float, poise_k: float) -> void:
	window_mult[Enemy.EState.CHASE] = k_chase
	window_mult[Enemy.EState.WINDUP] = k_armed
	window_mult[Enemy.EState.STRIKE] = k_armed
	_poise_max *= poise_k
	_poise = _poise_max


## Escala do dano de TODOS os golpes deste chefe (balance por chefe).
var dmg_scale: float = 1.0
## Distância mínima da parede ao andar (px de mundo).
var wall_margin: float = 50.0
## Golpe com `expose`: na recuperação ele fica EXPOSTO (ajoelha, o ponto fraco
## desce) e sente muito mais.
const EXPOSED_MULT := 1.35
var escape_hits: int = 4
var escape_window: float = 2.5
var escape_id: String = "repelir"
var _hit_times: Array = []

var _cd: Dictionary = {}
var _hist: Array = []
var _gap_t: float = 1.4
var _chain: Array = []
var _base_dmg: int = 10
var _poise: float = 1.0
var _poise_max: float = 1.0
var _poise_idle: float = 0.0
var _prev_estate: int = -1
var _self_stagger: bool = false
var _roar_t: float = 0.0
var _t: float = 0.0
var _spawned: Array = []
var _dead: bool = false
var _airborne: bool = false          # SALTO/MERGULHO: fora do alcance
var _leap_y0: float = 0.0
const LEAP_HIDE := 520.0
var _dying: int = -1                  # -1 vivo · 0..3 na sequência · 4 = liberou a morte
## Tempos da sequência de morte (s REAIS): impacto, cambaleio, colapso, pausa.
const DEATH_STEPS := [0.35, 0.55, 0.95, 0.6]


## Fábrica: o script de cada chefe (por type_id; senão pelo kit).
static func script_for(type_id: String, kit: String) -> String:
	var by_id := {
		"rei": "boss_rei", "rei_final": "boss_rei_final", "colosso": "boss_colosso",
		"arconte_sono": "boss_athoth", "arconte_fome": "boss_harmas",
		"arconte_corrente": "boss_galila", "arconte_silencio": "boss_yabel",
		"arconte_espelho": "boss_astaphaios", "arconte_praga": "boss_belias",
		"arconte_coroa": "boss_armupiel",
	}
	var n: String = by_id.get(type_id, "")
	if n == "":
		return ""
	var p := "res://scripts/entities/bosses/%s.gd" % n
	return p if ResourceLoader.exists(p) else ""


func setup(enemy: Enemy) -> void:
	e = enemy
	name = "BossBrain"
	screen = GameManager.current_screen
	rng.seed = hash("%s-%d" % [e.type_id, screen])
	var hp := BossTuning.boss_health(e.type_id, screen)
	e.health.setup(hp)
	e.attack_cooldown = 0.0
	_poise_max = BossTuning.expected_hit(BossTuning.expected_weapon_level(screen)) * POISE_HITS
	_poise = _poise_max
	moves = _build_moves()
	_on_setup()
	_add_default_escape()
	_base_dmg = maxi(1, int(round(float(e.attack_hitbox.damage) * dmg_scale)))
	e.contact_hitbox.damage = maxi(1, int(round(float(e.contact_hitbox.damage) * dmg_scale * 0.7)))
	e.defeated.connect(_on_defeated)


# --- ganchos para os chefes (sobrescrever) ---------------------------------

## {1: [golpes], 2: [...], 3: [...]}
func _build_moves() -> Dictionary:
	return {1: [], 2: [], 3: []}

func _on_setup() -> void:
	pass

## Entrou na fase n (arena muda aqui).
func _on_phase(_n: int) -> void:
	pass

## Começo da preparação do golpe (perigos de chão nascem aqui, alinhados).
func _on_windup(_m: Dictionary) -> void:
	pass

## O golpe saiu. Golpes "cast" são inteiros daqui.
func _on_strike(_m: Dictionary) -> void:
	pass

## A cada passo de física durante o STRIKE.
func _strike_tick(_m: Dictionary, _delta: float) -> void:
	pass

## Assinatura contínua do chefe (a cada passo de física, vivo).
func _signature(_delta: float) -> void:
	pass

## true = bater agora é ruim (guarda do espelho, névoa…) — a SONDA respeita.
func no_touch() -> bool:
	return _airborne


## Filtro de dano do chefe (reflexo, armadura…). Devolve o dano final.
func _filter(dmg: int, _attacker: Node) -> int:
	return dmg


# --- chamados pelo Enemy (ganchos mínimos em enemy.gd) ----------------------

## CHASE: anda até a distância preferida e escolhe o próximo golpe.
func chase(delta: float) -> bool:
	var pl := _player()
	if pl == null:
		return false
	_tick_cds(delta)
	var dx := pl.global_position.x - e.global_position.x
	var dist := absf(dx)
	if e.visual and dx != 0.0:
		e.visual.scale.x = absf(e.visual.scale.x) * signf(dx)
	if not _chain.is_empty():
		var nxt: Dictionary = _find(_chain.pop_front())
		if not nxt.is_empty():
			_start(nxt)
			return true
	if _crowded():
		var esc: Dictionary = _find(escape_id)
		if not esc.is_empty():
			_hit_times.clear()
			_start(esc)
			return true
	_gap_t -= delta
	var dir := 0.0
	if dist > keep_dist.y:
		dir = signf(dx)
	elif dist < keep_dist.x:
		dir = -signf(dx)
	if e.rooted_timer > 0.0:
		dir = 0.0
	# não recua até colar na parede (arte larga fica cortada na borda da câmera)
	var wb := arena_bounds()
	if (dir < 0.0 and e.global_position.x < wb.x + wall_margin) or (dir > 0.0 and e.global_position.x > wb.y - wall_margin):
		dir = 0.0
	# colado na parede (depois de uma investida/empurrão): sai dela andando para o
	# meio — arte larga cortada na borda da câmera (QA7 3.1: Colosso na tela 68)
	# (preso pela Corrente da Lei, fica: o root da Sophia vale — Guardião)
	if e.rooted_timer <= 0.0:
		if e.global_position.x < wb.x + wall_margin - 12.0:
			dir = 1.0
		elif e.global_position.x > wb.y - wall_margin + 12.0:
			dir = -1.0
	var spd: float = e.move_speed * (0.5 if e.slow_timer > 0.0 else 1.0)
	e.velocity.x = dir * spd + e._separation()
	if _gap_t <= 0.0 and not _partner_busy():
		var m := _pick(dist, _player_height(pl))
		if not m.is_empty():
			_start(m)
	return true


## STRIKE começou: executa o golpe em curso. true = tratado (o Enemy não faz o genérico).
func strike() -> bool:
	if mv.is_empty():
		return false
	var dir: int = e.atk_dir
	e.attack_hitbox.damage = int(_base_dmg * float(mv.get("dmg", 1.0)))
	e.attack_hitbox.knockback = float(mv.get("kb", 160.0))
	match String(mv.get("kind", "melee")):
		"melee":
			e.attack_hitbox.position.x = float(mv.get("off", 30.0)) * dir
			e.attack_hitbox.scale = Vector2(float(mv.get("sx", 1.7)), float(mv.get("sy", 1.4)))
			e.attack_hitbox.activate()
		"slam":
			var rad: float = float(mv.get("nova", 120.0))
			AoeNova.spawn(e.get_parent(), e.global_position + Vector2(0, 14), 0, rad, e.eye_color)
			Juice.shake(0.35)
			e.attack_hitbox.position.x = float(mv.get("off", 0.0)) * dir
			e.attack_hitbox.scale = Vector2(float(mv.get("sx", 3.6)), float(mv.get("sy", 1.0)))
			e.attack_hitbox.activate()
			var waves: int = int(mv.get("waves", 0))
			if waves == 1:
				ground_wave(dir, float(mv.get("wave_dmg", 0.6)), float(mv.get("wave_speed", 240.0)))
			elif waves == 2:
				ground_wave(1, float(mv.get("wave_dmg", 0.6)), float(mv.get("wave_speed", 240.0)))
				ground_wave(-1, float(mv.get("wave_dmg", 0.6)), float(mv.get("wave_speed", 240.0)))
		"charge":
			AoeNova.spawn(e.get_parent(), e.global_position + Vector2(0, 14), 0, 70.0, e.eye_color)
			e.attack_hitbox.position.x = 10.0 * dir
			e.attack_hitbox.scale = Vector2(float(mv.get("sx", 1.4)), float(mv.get("sy", 1.3)))
			e.attack_hitbox.activate()
			e.velocity.x = dir * float(mv.get("speed", 420.0))
		"shot":
			var offs: Array = mv.get("offs", [0.0])
			var stagger_t: float = float(mv.get("stagger", 0.0))
			var i := 0
			for oy in offs:
				if stagger_t > 0.0 and i > 0:
					_later(stagger_t * i, _fire.bind(dir, float(oy)))
				else:
					_fire(dir, float(oy))
				i += 1
		"leap":
			_leap_start()
		"cast":
			pass
	_on_strike(mv)
	return true


func strike_tick(delta: float) -> void:
	if _airborne:
		e.velocity = Vector2.ZERO
		e.global_position.y = _leap_y0 - LEAP_HIDE
	if mv.is_empty():
		return
	if String(mv.get("kind", "")) == "charge":
		e.velocity.x = e.atk_dir * float(mv.get("speed", 420.0))
		var b := arena_bounds()
		var past: float = 0.0
		var pl := _player()
		if pl != null:
			past = (e.global_position.x - pl.global_position.x) * float(e.atk_dir)
		# para na parede OU logo depois de passar por ela (fica no quadro da câmera)
		if (e.atk_dir > 0 and e.global_position.x > b.y - 40.0) or (e.atk_dir < 0 and e.global_position.x < b.x + 40.0) or past > 130.0:
			e.velocity.x = 0.0
			e.attack_timer = minf(e.attack_timer, 0.0)
	_strike_tick(mv, delta)


## Dano que chega: filtro do chefe + invulnerável no rugido de fase.
func filter_damage(dmg: int, attacker: Node) -> int:
	if _roar_t > 0.0 or _dying >= 0 or _airborne:
		return 0
	# Arconte ENCENADO (tentação: congelado até a Sophia cruzar o gatilho) é
	# intocável — senão um tiro de longe (ou o `hurt` do Shot) troca a fase com ele
	# parado fora da luta: as gaiolas da fase 2 descem e a Galila fica congelada
	# fora do quadro (QA7 #11).
	if not e.can_process():
		return 0
	dmg = _filter(dmg, attacker)
	if dmg <= 0:
		return dmg
	# JANELAS: armado (preparando/golpeando) ele aguenta; aberto (recuperando,
	# atordoado) ele sente. O jogo recompensa ESPERAR a hora e punir.
	var k: float = float(window_mult.get(e.estate, 1.0))
	if e.estate == Enemy.EState.RECOVER and bool(mv.get("expose", false)):
		k = EXPOSED_MULT
	# golpe-RESPOSTA (Réplica do Juízo, estouro por toque): volta já em guarda —
	# não é janela; a janela é de quem esperou (29/10)
	elif e.estate == Enemy.EState.RECOVER and bool(mv.get("guard_rec", false)):
		k = minf(k, float(window_mult.get(Enemy.EState.CHASE, 0.85)))
	if k < 1.0:
		ImpactBurst.spawn(e.get_parent(), e.global_position + Vector2(0, -18.0 * e._art_scale), Color(0.85, 0.9, 1.0))
		# 2º sinal do "armado" (Guardião, R5/R11: forma + SOM, não só cor): um "block"
		# metálico curto, no máximo 1 a cada 0,25 s (combo rápido não vira metralhadora)
		if _t - _armed_sfx_t >= 0.25:
			_armed_sfx_t = _t
			sfx("block", e.global_position)
	return maxi(1, int(round(float(dmg) * k)))


## POSTURA: false = não recua (o Enemy segue o golpe). Quebrar a postura =
## atordoado longo (a janela de punição "ganha").
func flinch(dmg: int, _launcher: bool) -> bool:
	if e.estate == Enemy.EState.STAGGER:
		return false
	_poise -= float(dmg)
	_poise_idle = 0.0
	_hit_times.append(_t)
	if _poise <= 0.0:
		_poise = _poise_max * (1.0 + 0.2 * float(phase - 1))
		stun(BREAK_STAGGER)
		VfxLibrary.boss_phase2(e.get_parent(), e.global_position + Vector2(0, -24.0 * e._art_scale), Color(1, 1, 1))
		Juice.shake(0.4)
	return false


## Fase: confere os limiares. true = mudou (o Enemy para de processar o golpe).
func check_phase() -> bool:
	if phase > marks.size() or e.health.is_dead():
		return false
	var ratio := float(e.health.current_health) / maxf(1.0, float(e.health.max_health))
	if ratio > float(marks[phase - 1]):
		return false
	set_phase(phase + 1)
	return true


func set_phase(n: int) -> void:
	phase = n
	_chain.clear()
	mv = {}
	_roar_t = PHASE_ROAR
	_gap_t = 0.6
	_poise = _poise_max * (1.0 + 0.2 * float(phase - 1))
	e._enter_phase(n)
	_self_stagger = true
	e.attack_timer = PHASE_ROAR
	Audio.set_music_pitch(1.0 + 0.035 * float(n - 1), 1.2)
	_on_phase.call_deferred(n)   # fora do sinal de física (plataformas, nós novos)


func passive(delta: float) -> void:
	if _dead or e.estate == Enemy.EState.DEAD:
		return
	_t += delta
	_roar_t = maxf(0.0, _roar_t - delta)
	_poise_idle += delta
	if _poise_idle > POISE_REST:
		_poise = _poise_max * (1.0 + 0.2 * float(phase - 1))
	# APARO: o Enemy.stagger() deixa 0,7 s; o chefe fica mais (janela do contra-ataque).
	if e.estate == Enemy.EState.STAGGER and _prev_estate != Enemy.EState.STAGGER:
		if not _self_stagger:
			e.attack_timer = maxf(e.attack_timer, PARRY_STAGGER)
			_poise -= _poise_max * 0.35
			_chain.clear()
		_self_stagger = false
	if e.estate == Enemy.EState.CHASE and _prev_estate != Enemy.EState.CHASE:
		mv = {}
	# tiro interrompido (aparo, postura, fase, morte): a carga apaga
	if _charge != null and is_instance_valid(_charge) and e.estate in [Enemy.EState.STAGGER, Enemy.EState.HURT, Enemy.EState.DEAD]:
		if _charge.has_method("cancel"):
			_charge.cancel()
		_charge = null
	_prev_estate = e.estate
	# SEM DANO DE CONTATO no corpo: só nas investidas (golpe explícito)
	var touch: bool = e.estate == Enemy.EState.STRIKE and String(mv.get("kind", "")) == "charge"
	if e.contact_hitbox.monitoring != touch:
		e.contact_hitbox.set_deferred("monitoring", touch)
	_signature(delta)


# --- utilidades para os chefes ---------------------------------------------

func _player() -> Node2D:
	var pl = e.player
	if pl == null or not is_instance_valid(pl):
		return null
	return pl


## Quanto a Sophia está acima do chão do chefe (px; 0 = no chão).
func _player_height(pl: Node2D) -> float:
	return maxf(0.0, e.global_position.y - pl.global_position.y)


func _find(id: String) -> Dictionary:
	for m in moves.get(phase, []):
		if m.id == id:
			return m
	for p in moves.keys():
		for m in moves[p]:
			if m.id == id:
				return m
	return {}


func _tick_cds(delta: float) -> void:
	for k in _cd.keys():
		_cd[k] = float(_cd[k]) - delta


## Sorteio PONDERADO entre os golpes que cabem na distância (e na altura).
## Não repete o mesmo golpe 3 vezes seguidas.
func _pick(dist: float, high: float) -> Dictionary:
	var cands: Array = []
	var tot := 0.0
	for m in moves.get(phase, []):
		if float(_cd.get(m.id, 0.0)) > 0.0:
			continue
		if dist < float(m.get("rmin", 0.0)) or dist > float(m.get("rmax", 9999.0)):
			continue
		if high > 50.0 and not bool(m.get("aa", false)):
			continue
		var w: float = float(m.get("w", 1.0))
		if _hist.size() >= 2 and _hist[0] == m.id and _hist[1] == m.id:
			continue
		if not _hist.is_empty() and _hist[0] == m.id:
			w *= 0.4
		cands.append([m, w])
		tot += w
	if cands.is_empty():
		return {}
	var r := rng.randf() * tot
	for c in cands:
		r -= float(c[1])
		if r <= 0.0:
			return c[0]
	return cands[cands.size() - 1][0]


func _start(m: Dictionary) -> void:
	mv = m
	_cd[m.id] = float(m.get("cd", 0.0))
	_hist.push_front(m.id)
	if _hist.size() > 4:
		_hist.pop_back()
	var ch: Array = m.get("chain", [])
	if not ch.is_empty():
		_chain = ch.duplicate()
	e.wind_up = float(m.get("wind", 0.7))
	e.strike_time = float(m.get("strike", 0.2))
	e.recover_time = float(m.get("recover", 0.5))
	e.attack_style = String(m.get("anim", "melee"))
	e.attack_hitbox.unblockable = bool(m.get("unblock", false))
	_gap_t = float(gap_by_phase[clampi(phase - 1, 0, gap_by_phase.size() - 1)]) * float(m.get("gap", 1.0))
	e._begin_windup()
	if not bool(m.get("tell", true)):
		# golpe utilitário (piscar, guarda, chamar a corte): NADA para aparar ou
		# rolar — sem tinta/contorno/brilho/som de telegrafo (R5: amarelo = aparável).
		e._tint_base = Color(1, 1, 1, 1)
		e._glint_done = true
		if e.visual:
			e.visual.modulate = Color(1, 1, 1, e.visual.modulate.a)
			e.visual.set("telegraph_color", Color(0, 0, 0, 0))
	if String(m.get("kind", "")) == "shot":
		# VFX7: a luz se junta onde o tiro vai sair (cancela se for interrompido)
		var col: Color = m.get("color", e.eye_color)
		var off := Vector2(24.0 * e.atk_dir * e._art_scale, ground_y() - e.global_position.y - 34.0)
		_charge = _charge_fx(off, col, e.wind_up, e.kit == "rei")
	_on_windup(m)


## SALTO (kind "leap"): some para o alto (ou para baixo da terra, se
## `burrow`), uma sombra/marca SEGUE a Sophia e trava 0,45 s antes; ele cai
## ali com pancada e ondas. Intocável no ar. strike = tempo no ar.
func _leap_start() -> void:
	var pl := _player()
	_leap_y0 = e.global_position.y
	_airborne = true
	var burrow: bool = bool(mv.get("burrow", false))
	ImpactBurst.spawn(e.get_parent(), e.global_position + Vector2(0, 10), e.eye_color)
	AoeNova.spawn(e.get_parent(), e.global_position + Vector2(0, 14), 0, 70.0, e.eye_color)
	Juice.shake(0.3)
	e.global_position.y = _leap_y0 - LEAP_HIDE
	e.reset_physics_interpolation()
	var x0: float = pl.global_position.x if pl != null else e.global_position.x
	var h := hazard(x0, "circle", float(mv.get("land_r", 70.0)), maxf(0.3, e.strike_time - 0.02), float(mv.get("dmg", 1.2)))
	if burrow:
		h.shape = "column"
		h.half_w = float(mv.get("land_r", 46.0))
	h.follow = pl
	h.lock_at = 0.45
	h.knockback = 300.0
	h.strike_sound = false          # o pouso já soa (bs_land, pelo Áudio)
	h.struck.connect(_leap_land.bind(h))


func _leap_land(h: BossHazard) -> void:
	if not is_instance_valid(e) or _dead:
		_airborne = false
		return
	_airborne = false
	var b := arena_bounds()
	e.global_position = Vector2(clampf(h.global_position.x, b.x + 40.0, b.y - 40.0), _leap_y0)
	e.reset_physics_interpolation()
	e.velocity = Vector2.ZERO
	AoeNova.spawn(e.get_parent(), e.global_position + Vector2(0, 14), 0, 130.0, e.eye_color)
	Juice.shake(0.6)
	var waves: int = int(mv.get("waves", 0))
	if waves > 0:
		ground_wave(1, float(mv.get("wave_dmg", 0.6)), float(mv.get("wave_speed", 240.0)))
		ground_wave(-1, float(mv.get("wave_dmg", 0.6)), float(mv.get("wave_speed", 240.0)))
	_on_land(mv)


## O salto pousou (extras do chefe).
func _on_land(_m: Dictionary) -> void:
	pass


## Batalha dupla: a outra forma (FinalBattle liga). Uma ataca de cada vez —
## justiça: a Sophia nunca lê dois telegrafos ao mesmo tempo.
var partner: BossBrain = null
var _charge = null
var _wave_sfx_ms: int = -100000                    # antecipação visual (VFX7) do tiro em preparo


## Carga do tiro (VFX7 ChargeFX) com SOM PRÓPRIO (R11: não é o mesmo
## "proj_fire" do disparo): "charge_king" no Rei, "charge_dark" nos Arcontes.
func _charge_fx(off: Vector2, col: Color, dur: float, king: bool) -> Node:
	var c := ChargeFX.new()
	c.color = col
	c.duration = dur
	c.style = "king" if king else "dark"
	c.position = off
	c.silent = true
	e.add_child(c)
	sfx("charge_king" if king else "charge_dark", e.global_position + off)
	return c


## Chama a API visual do VFX7 se existir (sem ela, nada — não quebra).
static var _vfx_methods: Dictionary = {}
func _vfx(fn: String, args: Array):
	if _vfx_methods.is_empty():
		for m in (VfxLibrary as Script).get_script_method_list():
			_vfx_methods[String(m.name)] = true
		_vfx_methods["_ok"] = true
	if not _vfx_methods.has(fn):
		return null
	return (VfxLibrary as Script).callv(fn, args)


## Batalha final: a forma se refez (`me`) ou a outra se refez — fase da luta.
func revived(n: int, me: bool) -> void:
	if me:
		_dead = false
		_dying = -1
		_airborne = false
		mv = {}
		_chain.clear()
		_hit_times.clear()
	if n > phase and not _dead:
		set_phase(n)
	else:
		e.phase = phase


func busy() -> bool:
	return e != null and is_instance_valid(e) and e.estate in [Enemy.EState.WINDUP, Enemy.EState.STRIKE]


func _partner_busy() -> bool:
	return partner != null and is_instance_valid(partner) and partner.busy()


## Golpe de repulsão padrão (quem não definiu o seu): pancada em volta de si.
func _add_default_escape() -> void:
	if not _find(escape_id).is_empty():
		return
	var rep := {"id": escape_id, "kind": "slam", "anim": "slam", "wind": 0.5, "strike": 0.2, "recover": 0.55,
		"unblock": true, "sx": 2.6, "sy": 1.5, "nova": 95.0, "dmg": 0.6, "kb": 420.0, "w": 0.0, "gap": 0.6}
	for p in moves.keys():
		moves[p].append(rep)


## A Sophia está colada batendo sem parar?
func _crowded() -> bool:
	while not _hit_times.is_empty() and _t - float(_hit_times[0]) > escape_window:
		_hit_times.pop_front()
	return _hit_times.size() >= escape_hits


## Atordoa o chefe por t s (janela de punição; não conta como aparo).
func stun(t: float) -> void:
	_self_stagger = true
	_chain.clear()
	e.attack_hitbox.call_deferred("deactivate")
	e.attack_hitbox.scale = Vector2.ONE
	e.estate = Enemy.EState.STAGGER
	e.attack_timer = t
	e._tint_base = Color(1, 1, 1, 1)
	e._flash(Color(2.6, 2.6, 2.6, 1), Enemy.VIB_HEAVY)


func _fire(dir: int, oy: float) -> void:
	if _dead or not is_instance_valid(e):
		return
	var p := Projectile.new()
	p.direction = dir
	p.damage = int(_base_dmg * float(mv.get("dmg", 0.7)))
	p.speed = float(mv.get("speed", 260.0))
	p.pierce = false
	p.target_team = "player"
	p.color = mv.get("color", e.eye_color)
	p.lifetime = float(mv.get("life", 2.2))
	p.slow_time = float(mv.get("slow", 0.0))
	p.root_time = float(mv.get("root", 0.0))
	e.get_parent().add_child(p)
	# sai na ALTURA DO PEITO da Sophia (nunca do olho lá no alto — fora do alcance)
	p.global_position = Vector2(e.global_position.x + 24.0 * dir * e._art_scale, ground_y() - 34.0 + oy)


## Onda rasteira pelo chão (projétil baixo: pular por cima).
func ground_wave(dir: int, dmg_mult: float, speed: float = 240.0) -> Projectile:
	var p := Projectile.new()
	p.direction = dir
	p.damage = int(_base_dmg * dmg_mult)
	p.speed = speed
	p.pierce = false
	p.target_team = "player"
	p.color = e.eye_color
	p.lifetime = 2.2
	p.set("look", "spike")          # VFX7: lâmina rasteira (lê-se como "pule")
	# um som por evento (R4): duas ondas no mesmo golpe soam uma vez só
	var now := Time.get_ticks_msec()
	if now - _wave_sfx_ms > 120:
		_wave_sfx_ms = now
		sfx("atk_wave", e.global_position)
	e.get_parent().add_child(p)
	p.global_position = e.global_position + Vector2(30.0 * dir, 12.0)
	return p


## Perigo telegrafado no chão/céu (ver BossHazard).
func hazard(x: float, shape: String, half_w: float, delay: float, dmg_mult: float, col: Color = Color(0, 0, 0, 0)) -> BossHazard:
	var c: Color = col if col.a > 0.0 else e.eye_color
	var h := BossHazard.make(e.get_parent(), Vector2(x, ground_y()), shape, half_w, delay, int(_base_dmg * dmg_mult), c)
	h.owner_enemy = e
	_spawned.append(h)
	return h


## Plataforma de um lado só (pular por baixo, ficar em cima). Some com o chefe.
func platform(center: Vector2, w: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 12)
	col.shape = rect
	col.one_way_collision = true
	body.add_child(col)
	var vis := Sprite2D.new()
	vis.texture = PaintedLibrary.prop(5)
	vis.material = PaintedLibrary.material()
	vis.scale = Vector2(w / vis.texture.get_width(), 22.0 / vis.texture.get_height())
	vis.position.y = 5.0
	vis.modulate = Color(1, 1, 1, 0)
	body.add_child(vis)
	e.get_parent().add_child(body)
	body.global_position = center
	body.add_to_group("boss_platform")
	var t := vis.create_tween()
	t.tween_property(vis, "modulate", Color(1.3, 1.3, 1.4, 1), 0.5)
	ImpactBurst.spawn(e.get_parent(), center, e.eye_color)
	_spawned.append(body)
	return body


func remove_node(n) -> void:
	if n == null or not is_instance_valid(n):
		_spawned.erase(n)
		return
	_spawned.erase(n)
	if n is StaticBody2D:
		for c in n.get_children():
			if c is CollisionShape2D:
				(c as CollisionShape2D).set_deferred("disabled", true)
		var t: Tween = n.create_tween()
		t.tween_property(n, "modulate:a", 0.0, 0.4)
		t.tween_callback(n.queue_free)
	else:
		n.queue_free()


## Limites da arena trancada (x mín, x máx).
func arena_bounds() -> Vector2:
	var lv := e.get_parent()
	if lv != null and lv.has_method("arena_bounds"):
		return lv.arena_bounds()
	return Vector2(e.global_position.x - 470.0, e.global_position.x + 470.0)


## y dos pés no chão (onde os perigos de chão nascem).
func ground_y() -> float:
	if e.get_parent() is Level:
		return Level.GROUND_Y
	return e.global_position.y + 22.0 * e.scale.y


## Toca um som só se ele existir no catálogo do Áudio (sem aviso no log).
func sfx(snd: String, pos: Vector2) -> void:
	var cat = Audio.get("CATALOG")
	if cat is Dictionary:
		var l = cat.get("sfx", [])
		if l is Array and l.has(snd):
			Audio.play_sfx_at(snd, pos)


func _later(t: float, cb: Callable) -> void:
	var tm := get_tree().create_timer(t, false, true)
	tm.timeout.connect(func() -> void:
		if not _dead and is_instance_valid(self):
			cb.call())


## Morte = MOMENTO. Chamado pelo Enemy._on_died: true = segura a morte (a
## sequência roda e depois chama _on_died de novo, que segue o caminho normal).
func hold_death() -> bool:
	if _dying >= 4:
		return false
	if _dying >= 0:
		return true
	_dying = 0
	_dead = true
	_chain.clear()
	mv = {}
	for n in _spawned.duplicate():
		if is_instance_valid(n) and n is BossHazard:
			remove_node(n)
	e.attack_hitbox.call_deferred("deactivate")
	e.attack_hitbox.scale = Vector2.ONE
	e.contact_hitbox.set_deferred("monitoring", false)
	e.hurtbox.set_deferred("monitoring", false)
	e.estate = Enemy.EState.STAGGER
	e.attack_timer = 999.0
	e.velocity = Vector2(-e.atk_dir * 120.0, -80.0)
	_death_sequence()
	return true


func _death_sequence() -> void:
	var v = e.visual
	var art: bool = v != null and v.has_method("play_boss_death") and v.has_method("has_boss_frames") and v.has_boss_frames()
	# 0 — IMPACTO: o golpe final pesa. É o ÚNICO tremor grande da morte (R3/§4.1);
	# as etapas seguintes só têm micro-tremor.
	e.estate = Enemy.EState.DEAD
	e.boss_dying.emit(0)
	Juice.hit_stop(0.2)
	Juice.slow_mo(0.3, 0.8)
	Juice.shake(0.8)
	Juice.rumble(0.6, 0.8, 0.4)
	e._flash(Color(3.2, 3.2, 3.2, 1), Enemy.VIB_HEAVY)
	Audio.duck_music(3.0, -14.0)
	if art:
		# a ARTE conduz a linha do tempo (cambaleio 0,34 · queda 0,62 · estilhaço
		# 1,08 · fim 1,9 s); o cérebro só marca as etapas e espera o fim
		v.play_boss_death(e.eye_color)
		await _until_death_t(v, 0.34)
		_dying = 1
		e.boss_dying.emit(1)
		await _until_death_t(v, 0.62)
		_dying = 2
		e.boss_dying.emit(2)
		Juice.shake(0.15)
		await _until_death_t(v, 1.08)
		_dying = 3
		e.boss_dying.emit(3)
		if e._orb != null:
			e._orb.visible = false
		if is_inside_tree() and is_instance_valid(v) and v.is_dying():
			await v.death_finished
	else:
		await _real_wait(DEATH_STEPS[0])
		_dying = 1
		e.boss_dying.emit(1)
		e._flash(Color(2.2, 2.0, 1.8, 1), Enemy.VIB_HEAVY)
		await _real_wait(DEATH_STEPS[1])
		_dying = 2
		e.boss_dying.emit(2)
		Juice.shake(0.15)
		await _real_wait(DEATH_STEPS[2])
		_dying = 3
		e.boss_dying.emit(3)
		await _real_wait(DEATH_STEPS[3])
	# 4 — FIM: libera a morte normal (recompensa, defeated); com a arte, o corpo
	# já estilhaçou — o Enemy não faz o segundo final (is_dying)
	_dying = 4
	if not is_inside_tree() or not is_instance_valid(e):
		return                      # a cena trocou no meio (ferramenta/saída)
	e.boss_dying.emit(4)
	if is_instance_valid(e):
		e.estate = Enemy.EState.STAGGER
		e._on_died()


## Espera o relógio da morte desenhada chegar em t (s), com teto de segurança.
func _until_death_t(v, t: float) -> void:
	var guard := 0
	while is_inside_tree() and is_instance_valid(v) and v.is_dying() and float(v.get("_death_t")) < t and guard < 600:
		guard += 1
		await get_tree().process_frame


## Espera em tempo REAL (ignora câmera lenta e hitstop; corre com o jogo pausado).
func _real_wait(t: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(t, true, false, true).timeout


func _on_defeated(_x) -> void:
	_dead = true
	Audio.set_music_pitch(1.0, 1.0)
	for n in _spawned.duplicate():
		remove_node(n)
	_spawned.clear()
