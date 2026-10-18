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

const GOLD := Color(1.0, 0.88, 0.45)

var _court_cd: float = 0.0


func _on_setup() -> void:
	dmg_scale = 0.5
	keep_dist = Vector2(40.0, 100.0)
	gap_by_phase = [0.8, 0.7, 0.6]
	escape_hits = 4


func _build_moves() -> Dictionary:
	var espadao := {"id": "espadao", "kind": "slam", "anim": "slam", "wind": 0.9, "strike": 0.25, "recover": 1.0,
		"off": 34.0, "sx": 2.6, "sy": 1.4, "nova": 100.0, "waves": 1, "wave_dmg": 0.55, "wave_speed": 250.0,
		"dmg": 1.1, "rmax": 140.0, "w": 2.0, "cd": 1.0}
	var varredura := {"id": "varredura", "kind": "cast", "anim": "melee", "wind": 0.75, "strike": 0.25, "recover": 0.8,
		"unblock": true, "rmax": 150.0, "w": 1.4, "cd": 2.5}
	var decreto := {"id": "decreto", "kind": "cast", "anim": "ranged", "wind": 0.8, "strike": 0.6, "recover": 0.9,
		"unblock": true, "rmin": 120.0, "rmax": 9999.0, "w": 1.2, "cd": 4.0, "aa": true}
	var investida := {"id": "investida", "kind": "charge", "anim": "charge", "wind": 0.8, "strike": 0.55,
		"recover": 1.0, "unblock": true, "speed": 360.0, "dmg": 1.1, "rmin": 160.0, "rmax": 9999.0, "w": 1.0, "cd": 4.0}
	var corte_real := {"id": "corte_real", "kind": "cast", "anim": "ranged", "wind": 0.9, "strike": 0.4, "recover": 0.8,
		"rmin": 0.0, "rmax": 9999.0, "w": 3.0, "cd": 18.0}
	var dupla := espadao.duplicate()
	dupla.id = "dupla"
	dupla.chain = ["dupla_b"]
	dupla.recover = 0.35
	dupla.w = 1.3
	dupla.cd = 3.0
	var dupla_b := espadao.duplicate()
	dupla_b.id = "dupla_b"
	dupla_b.wind = 0.55
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
		1: [espadao, varredura, decreto, investida],
		2: [espadao, dupla, dupla_b, varredura, decreto, corte_real],
		3: [dupla, dupla_b, varredura, decreto, coroacao, triplo, triplo_b, triplo_c, corte_real],
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
	return super._pick(dist, high)


func _on_windup(m: Dictionary) -> void:
	var pl := _player()
	if pl == null:
		return
	match m.id:
		"varredura":
			# baixa e larga, à frente: só pulando
			var h := hazard(e.global_position.x + e.atk_dir * 70.0, "band", 85.0, m.wind, 0.9, GOLD)
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


func _on_strike(m: Dictionary) -> void:
	if m.id == "corte_real":
		var n := 2 if phase == 2 else 1
		var before: Array = e._minions.duplicate()
		e._summon("pretoriano", n)
		# a guarda tem vida de ~6 golpes cada (não um segundo chefe)
		for m in e._minions:
			if m in before or not is_instance_valid(m):
				continue
			m.health.setup(maxi(30, int(BossTuning.expected_hit(BossTuning.expected_weapon_level(screen)) * 6.0)))
			m.spark_reward = 0
		e.armored = true
		_court_cd = 22.0
		AoeNova.spawn(e.get_parent(), e.global_position, 0, 160.0, GOLD)


func _signature(delta: float) -> void:
	_court_cd = maxf(0.0, _court_cd - delta)
	keep_dist = Vector2(170.0, 260.0) if e.armored else Vector2(40.0, 100.0)
	if e.armored:
		e._prune_minions()
		if e._minions.is_empty():
			e.armored = false
			e._flash(Color(2.5, 2.2, 1.4, 1), Enemy.VIB_HEAVY)   # a armadura cai


func _on_defeated(x) -> void:
	for m in e._minions:
		if is_instance_valid(m) and m.estate != Enemy.EState.DEAD:
			m._on_hit_received(m.health.max_health + 9999, e.global_position, 10.0, false, null)
	super._on_defeated(x)
