extends BossBrain
## ARMUPIEL, Arconte da COROA (tela 64). O filho que é rei de uma corte que
## nunca vem. Armadura dourada, espadão, a luta mais longa dos Arcontes.
## ASSINATURA — CORTE BLINDADA e ONDA RASTEIRA: o Espadão (amarelo) racha o
## chão e solta uma onda que corre rente (PULE); a Varredura é baixa e
## vermelha (PULE). Fase 2: ele chama a CORTE — Pretorianos de escudo; enquanto
## algum estiver de pé, ele fica BLINDADO (o golpe quase não entra). Derrube
## a corte primeiro. Fase 3: a COROAÇÃO — um feixe de luz da coroa varre a
## arena de ponta a ponta (role através dele ou corra na frente) e o Triplo
## (três pancadas com ondas para os dois lados).
## Janelas: depois do Triplo o espadão fica cravado (1,8 s); o Espadão aparado
## atordoa; o Decreto (coluna na Sophia) deixa ele parado apontando.
## JUÍZO DA COROA (29/10, chefes6 — resposta a quem só martela): ele CRAVA o
## espadão de pé à frente e a coroa acende (lâmina dourada vertical + meia-cúpula
## de luz virada para a Sophia + 3 pontas sobre a cabeça + som de luz). Enquanto
## a postura dura, todo golpe que chega é DEFENDIDO (faísca dourada, sem dano) —
## e bater nela pede a RÉPLICA: corte largo vermelho (imparável) que joga a
## Sophia longe (fase 3: + ondas rasteiras para os dois lados). Quem ESPERA a
## postura acabar ganha a janela boa: ele arranca o espadão do chão e fica
## EXPOSTO (1,1 s). Vem no repertório e como RESPOSTA À PRESSÃO: 3 golpes dados
## nele fora das janelas (no neutro ou no meio do golpe dele) e a próxima
## escolha é o Juízo.

const GOLD := Color(1.0, 0.88, 0.45)
## Golpes "fora da janela" (neutro/armado) até ele responder com o Juízo.
const PRESSURE_MAX := 3

var _court_cd: float = 0.0
var _pressure: int = 0
var _riposte_armed: bool = false
var _stance_fx: JudgeStance = null


func _on_setup() -> void:
	dmg_scale = 0.38          # 28/10: curva da Progressão (~370 de vida na tela 64)
	keep_dist = Vector2(40.0, 100.0)
	gap_by_phase = [0.8, 0.7, 0.6]
	escape_hits = 4
	escape_id = "juizo"       # 29/10: quem cola e martela encontra o JUÍZO (não mais o empurrão)
	# guarda alta (QA7 3.1: caía em ~40 s com quem só martela) — ver BossBrain.guard_up
	guard_up(0.55, 0.35, 1.5)


func _build_moves() -> Dictionary:
	var espadao := {"id": "espadao", "kind": "slam", "anim": "slam", "wind": 0.85, "strike": 0.25, "recover": 1.25,
		"off": 34.0, "sx": 2.6, "sy": 1.4, "nova": 100.0, "waves": 1, "wave_dmg": 0.4, "wave_speed": 210.0,
		"dmg": 1.1, "rmax": 140.0, "w": 2.0, "cd": 1.0}
	var varredura := {"id": "varredura", "kind": "cast", "anim": "melee", "wind": 0.75, "strike": 0.25, "recover": 0.8,
		"unblock": true, "rmax": 150.0, "w": 1.4, "cd": 2.5}
	var decreto := {"id": "decreto", "kind": "cast", "anim": "ranged", "wind": 0.8, "strike": 0.6, "recover": 0.9,
		"unblock": true, "rmin": 120.0, "rmax": 9999.0, "w": 1.2, "cd": 4.0, "aa": true}
	var investida := {"id": "investida", "kind": "charge", "anim": "charge", "wind": 0.8, "strike": 0.55,
		"recover": 1.0, "unblock": true, "speed": 360.0, "dmg": 1.1, "rmin": 160.0, "rmax": 9999.0, "w": 1.0, "cd": 4.0}
	var corte_real := {"id": "corte_real", "tell": false, "kind": "cast", "anim": "ranged", "wind": 0.9, "strike": 0.4, "recover": 0.8,
		"rmin": 0.0, "rmax": 9999.0, "w": 3.0, "cd": 18.0}
	# JUÍZO: wind = cravar o espadão (a postura já defende); strike = postura;
	# recover = arranca o espadão, EXPOSTO (a janela de quem esperou)
	var juizo := {"id": "juizo", "tell": false, "kind": "cast", "anim": "slam", "wind": 0.35, "strike": 1.5,
		"recover": 1.1, "expose": true, "rmin": 0.0, "rmax": 150.0, "w": 0.8, "cd": 6.0}
	# RÉPLICA: só nasce de golpe dado na postura (peso 0 — nunca é sorteada)
	var replica := {"id": "replica", "kind": "slam", "anim": "slam", "wind": 0.32, "strike": 0.25, "recover": 0.7,
		"unblock": true, "guard_rec": true, "off": 30.0, "sx": 3.4, "sy": 1.6, "nova": 120.0, "dmg": 1.0, "kb": 460.0,
		"rmax": 9999.0, "w": 0.0, "cd": 0.0}
	# a 1ª Réplica volta à postura UMA vez (quem insiste leva a 2ª); a 2ª não volta
	replica.chain = ["juizo_b"]
	var juizo_b := juizo.duplicate()
	juizo_b.id = "juizo_b"
	juizo_b.wind = 0.3
	juizo_b.strike = 1.0
	juizo_b.w = 0.0
	juizo_b.cd = 0.0
	var replica_b := replica.duplicate()
	replica_b.id = "replica_b"
	replica_b.chain = []
	var replica3 := replica.duplicate()
	replica3.id = "replica3"
	replica3.waves = 2
	replica3.wave_dmg = 0.45
	replica3.wave_speed = 230.0
	var juizo3 := juizo.duplicate()
	juizo3.id = "juizo3"
	juizo3.w = 1.1
	juizo3.cd = 4.5
	var dupla := espadao.duplicate()
	dupla.id = "dupla"
	dupla.chain = ["dupla_b"]
	dupla.recover = 0.35
	dupla.w = 1.3
	dupla.cd = 3.0
	var dupla_b := espadao.duplicate()
	dupla_b.id = "dupla_b"
	dupla_b.wind = 0.7
	dupla_b.rmax = 9999.0
	dupla_b.w = 0.0
	dupla_b.cd = 0.0
	var coroacao := {"id": "coroacao", "kind": "cast", "anim": "ranged", "wind": 1.0, "strike": 0.5, "recover": 1.0,
		"unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.2, "cd": 8.0, "aa": true}
	var triplo := espadao.duplicate()
	triplo.id = "triplo"
	triplo.waves = 2
	triplo.chain = ["triplo_b", "triplo_c"]
	triplo.recover = 0.3
	triplo.w = 1.3
	triplo.cd = 7.0
	var triplo_b := triplo.duplicate()
	triplo_b.id = "triplo_b"
	triplo_b.chain = []
	triplo_b.wind = 0.5
	triplo_b.rmax = 9999.0
	triplo_b.w = 0.0
	triplo_b.cd = 0.0
	var triplo_c := triplo_b.duplicate()
	triplo_c.id = "triplo_c"
	triplo_c.unblock = true
	triplo_c.wind = 0.7
	triplo_c.recover = 1.8
	return {
		1: [espadao, varredura, decreto, investida, juizo, replica, juizo_b, replica_b],
		2: [espadao, dupla, dupla_b, varredura, decreto, corte_real, juizo, replica, juizo_b, replica_b],
		3: [dupla, dupla_b, varredura, decreto, coroacao, triplo, triplo_b, triplo_c, juizo3, replica3, juizo_b, replica_b],
	}


func _pick(dist: float, high: float) -> Dictionary:
	# a corte só é chamada se não houver servo de pé
	e._prune_minions()
	if not e._minions.is_empty() or _court_cd > 0.0:
		_cd["corte_real"] = maxf(float(_cd.get("corte_real", 0.0)), 1.0)
	# CORTE DE PÉ: o rei recua e só COMANDA (Decreto, devagar) — a luta é com
	# os Pretorianos; derrubados, a armadura cai e ele volta ao espadão.
	if not e._minions.is_empty():
		_gap_t = 1.6
		if float(_cd.get("decreto", 0.0)) > 0.0:
			return {}
		var d := _find("decreto")
		return d
	# RESPOSTA À PRESSÃO: quem bate fora das janelas encontra o Juízo (perto, no chão)
	if _pressure >= PRESSURE_MAX and dist <= 150.0 and high <= 50.0:
		var j := _find("juizo3" if phase >= 3 else "juizo")
		if not j.is_empty():
			return j
	return super._pick(dist, high)


## Postura do Juízo de pé (cravando ou firme): defende e arma a Réplica.
func _in_stance() -> bool:
	return String(mv.get("id", "")).begins_with("juizo") and e.estate in [Enemy.EState.WINDUP, Enemy.EState.STRIKE]


func no_touch() -> bool:
	return _in_stance() or super.no_touch()


func _filter(dmg: int, attacker: Node) -> int:
	if _in_stance():
		# defendido: faísca DOURADA no espadão (forma diferente da azul do "armado")
		var fx_pos := e.global_position + Vector2(18.0 * e.atk_dir * e._art_scale, -20.0 * e._art_scale)
		ImpactBurst.spawn(e.get_parent(), fx_pos, GOLD)
		sfx("block", e.global_position)
		if not _riposte_armed and attacker != null and is_instance_valid(attacker) and attacker is Node2D \
				and absf((attacker as Node2D).global_position.x - e.global_position.x) < 170.0:
			_riposte_armed = true
			_replica.call_deferred()      # fora do sinal de acerto
		return 0
	# golpe fora da janela (neutro / no meio do golpe dele) enche a PRESSÃO
	if e.estate in [Enemy.EState.CHASE, Enemy.EState.WINDUP, Enemy.EState.STRIKE] and not e.armored:
		_pressure += 1
	return dmg


## A Réplica: a postura vira um corte largo imparável já (o aviso foi a postura).
func _replica() -> void:
	if _dead or not is_instance_valid(e) or e.estate == Enemy.EState.DEAD:
		return
	var cur: String = String(mv.get("id", ""))
	var r := _find("replica_b" if cur == "juizo_b" else ("replica3" if phase >= 3 else "replica"))
	if r.is_empty():
		return
	_chain.clear()
	_hide_stance()
	_start(r)


func _on_windup(m: Dictionary) -> void:
	var pl := _player()
	if pl == null:
		return
	match m.id:
		"juizo", "juizo3", "juizo_b":
			_pressure = 0
			_riposte_armed = false
			_show_stance(float(m.wind) + float(m.strike))
			sfx("mask_light", e.global_position)
		"varredura":
			# baixa e larga, à frente: só pulando
			var h := hazard(e.global_position.x + e.atk_dir * 70.0, "band", 85.0, m.wind, 0.7, GOLD)
			h.height = 30.0
			h.hit_air = false
			h.active = 0.15
			h.knockback = 220.0
		"decreto":
			var c := hazard(pl.global_position.x, "column", 30.0, m.wind + 0.35, 1.0, GOLD)
			c.follow = pl
			c.lock_at = 0.45
		"coroacao":
			# o feixe nasce numa parede e varre até a outra
			var b := arena_bounds()
			var from_left: bool = pl.global_position.x > (b.x + b.y) * 0.5
			var x0: float = b.x + 20.0 if from_left else b.y - 20.0
			var f := hazard(x0, "column", 26.0, 1.1, 0.9, GOLD)
			f.active = (b.y - b.x) / 190.0
			f.tick = 0.6
			f.vel_x = 190.0 if from_left else -190.0
			f.min_x = b.x
			f.max_x = b.y


func _show_stance(t: float) -> void:
	if _stance_fx == null or not is_instance_valid(_stance_fx):
		_stance_fx = JudgeStance.new()
		e.add_child(_stance_fx)
		_stance_fx.z_index = 5
	_stance_fx.position = Vector2(0, -22.0 * e._art_scale)
	_stance_fx.size = 34.0 * e._art_scale
	_stance_fx.dir = float(e.atk_dir)
	_stance_fx.show_for(t)


func _hide_stance() -> void:
	if _stance_fx != null and is_instance_valid(_stance_fx):
		_stance_fx.show_for(0.0)


func _on_strike(m: Dictionary) -> void:
	if m.id == "corte_real":
		var n := 1
		var before: Array = e._minions.duplicate()
		e._summon("pretoriano", n)
		# a guarda tem vida de ~6 golpes cada (não um segundo chefe)
		for g in e._minions:
			if g in before or not is_instance_valid(g):
				continue
			g.health.setup(maxi(30, int(BossTuning.expected_hit(BossTuning.expected_weapon_level(screen)) * 4.0)))
			g.spark_reward = 0
			g.attack_hitbox.damage = maxi(1, g.attack_hitbox.damage / 2)   # guarda que segura, não que mata
			g.contact_hitbox.damage = maxi(1, g.contact_hitbox.damage / 2)
		e.armored = true
		_court_cd = 9999.0          # a corte vem UMA vez por fase (a fase 3 rearma)
		AoeNova.spawn(e.get_parent(), e.global_position, 0, 160.0, GOLD)


func _on_phase(_n: int) -> void:
	_court_cd = 0.0
	_cd["corte_real"] = 0.0
	_pressure = 0
	_hide_stance()


func _signature(delta: float) -> void:
	_court_cd = maxf(0.0, _court_cd - delta)
	keep_dist = Vector2(170.0, 260.0) if e.armored else Vector2(40.0, 100.0)
	if e.armored:
		e._prune_minions()
		if e._minions.is_empty():
			e.armored = false
			e._flash(Color(2.5, 2.2, 1.4, 1), Enemy.VIB_HEAVY)   # a armadura cai
	# a postura caiu (aparo, postura quebrada, fase): a luz apaga junto
	if _stance_fx != null and is_instance_valid(_stance_fx) and _stance_fx.visible and not _in_stance():
		_hide_stance()


func hold_death() -> bool:
	_hide_stance()
	return super.hold_death()


func _on_defeated(x) -> void:
	_hide_stance()
	for m in e._minions:
		if is_instance_valid(m) and m.estate != Enemy.EState.DEAD:
			m._on_hit_received(m.health.max_health + 9999, e.global_position, 10.0, false, null)
	super._on_defeated(x)


## Desenho da POSTURA DO JUÍZO: lâmina dourada de pé à frente, meia-cúpula de luz
## virada para a Sophia (o lado que defende) e 3 pontas de coroa sobre a cabeça.
## Forma própria (não é o anel do Espelho nem o contorno de telegrafo).
class JudgeStance extends Node2D:
	var size := 34.0
	var dir := 1.0
	var _left := 0.0
	var _t := 0.0
	func show_for(t: float) -> void:
		_left = t
		_t = 0.0
		visible = t > 0.0
		queue_redraw()
	func _process(d: float) -> void:
		if _left <= 0.0:
			if visible:
				visible = false
			return
		_t += d
		_left -= d
		visible = _left > 0.0
		queue_redraw()
	func _draw() -> void:
		if _left <= 0.0:
			return
		var grow: float = clampf(_t / 0.3, 0.0, 1.0)          # acende em 0,3 s (cravando)
		var pulse: float = 0.75 + 0.25 * sin(_t * 9.0)
		var c := Color(1.0, 0.88, 0.45, 0.9 * grow)
		# meia-cúpula na frente (o lado que defende)
		var a0: float = -PI * 0.5 if dir > 0.0 else PI * 0.5
		var r: float = size * (0.8 + 0.2 * grow)
		draw_arc(Vector2(dir * size * 0.25, 0), r, a0, a0 + PI * dir, 24, Color(c, 0.55 * pulse * grow), 4.0, true)
		draw_arc(Vector2(dir * size * 0.25, 0), r * 0.82, a0, a0 + PI * dir, 20, Color(c, 0.25 * grow), 2.0, true)
		# lâmina cravada de pé, à frente
		var bx: float = dir * size * 0.62
		var top := Vector2(bx, -size * 0.9)
		var bot := Vector2(bx, size * 0.75)
		draw_line(top, bot, Color(1.0, 0.97, 0.8, 0.95 * grow), 3.0, true)
		draw_line(Vector2(bx - 7.0, -size * 0.45), Vector2(bx + 7.0, -size * 0.45), Color(c, 0.95 * grow), 3.0, true)
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, -6), top + Vector2(3, 0), top + Vector2(-3, 0)]), Color(1, 1, 0.9, grow))
		# 3 pontas de coroa sobre a cabeça
		var cy: float = -size * 1.25
		for k in 3:
			var x: float = (float(k) - 1.0) * 9.0
			var h: float = 9.0 if k == 1 else 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4.0, cy), Vector2(x + 4.0, cy), Vector2(x, cy - h * pulse)]), c)
		draw_line(Vector2(-14.0, cy), Vector2(14.0, cy), c, 2.0, true)
