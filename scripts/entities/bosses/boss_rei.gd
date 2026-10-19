extends BossBrain
## O REI (tela 1) — o duelo-TUTORIAL. A mentira de máscara branca ensina a
## ler a luta, uma lição por fase, com golpes lentos e janelas largas. TUDO
## sai na altura da Sophia (o orbe-olho lá no alto NÃO atira: ele é o PONTO
## FRACO e desce depois dos golpes grandes).
## Fase 1 (aparar e pular) — Leque de orbes (amarelo), Gesto (empurrão
##   amarelo; aparar abre o contra-ataque), Raio do olho (feixe rasteiro que
##   corre pelo chão: PULE), Mão que esmaga (coluna vermelha onde ela está, com
##   onda para os dois lados).
## Fase 2 (+ ler o chão) — Anéis-serra (rolam pelo chão e voltam da parede:
##   pule), Convocação de larvas, combo Leque→Raio.
## Fase 3 (rolar) — Teleporte com golpe pelas costas, Mão dupla, tudo mais
##   rápido.
## PONTO FRACO: depois da Mão, do Raio e dos combos ele se ajoelha e o
## OLHO DESCE até a altura do cajado — bater no olho dói 1,5× (e o corpo,
## exposto, sente 1,6×).

const LIGHT := Color(1.0, 0.85, 0.5)
const ORB_LOW := 132.0          # px que o olho desce (fica na altura do peito)
const EYE_MULT := 1.3

var _rig: Node2D = null
var _eye_box: Hurtbox = null
var _low: bool = false
var _summons_cd: float = 0.0


func _on_setup() -> void:
	dmg_scale = 0.7
	keep_dist = Vector2(100.0, 210.0)
	gap_by_phase = [1.0, 0.9, 0.8]
	escape_hits = 5
	_setup_eye()


func _build_moves() -> Dictionary:
	var leque := {"id": "leque", "kind": "shot", "anim": "ranged", "wind": 0.85, "strike": 0.55, "recover": 0.7,
		"offs": [0.0, 0.0, 0.0], "stagger": 0.26, "speed": 200.0, "dmg": 0.55, "color": LIGHT, "life": 2.6,
		"rmin": 80.0, "rmax": 9999.0, "w": 1.4, "cd": 2.0, "aa": true}
	var gesto := {"id": "gesto", "kind": "melee", "anim": "melee", "wind": 0.8, "strike": 0.22, "recover": 0.9,
		"off": 34.0, "sx": 2.2, "sy": 1.5, "dmg": 0.9, "kb": 260.0, "rmax": 100.0, "w": 2.0, "cd": 1.0}
	var raio := {"id": "raio", "kind": "cast", "anim": "ranged", "wind": 0.9, "strike": 0.4, "recover": 1.3,
		"unblock": true, "expose": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.2, "cd": 4.0}
	var mao := {"id": "mao", "kind": "cast", "anim": "slam", "wind": 0.8, "strike": 0.5, "recover": 1.5,
		"unblock": true, "expose": true, "n": 1, "rmin": 0.0, "rmax": 9999.0, "w": 1.2, "cd": 4.0, "aa": true}
	var aneis := {"id": "aneis", "kind": "cast", "anim": "ranged", "wind": 0.8, "strike": 0.3, "recover": 0.7,
		"unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.1, "cd": 6.0}
	var larvas := {"id": "larvas", "tell": false, "kind": "cast", "anim": "ranged", "wind": 0.9, "strike": 0.3, "recover": 0.8,
		"rmin": 0.0, "rmax": 9999.0, "w": 0.8, "cd": 14.0}
	var combo := leque.duplicate()
	combo.id = "combo"
	combo.recover = 0.25
	combo.chain = ["raio_b"]
	combo.w = 1.1
	combo.cd = 5.0
	var raio_b := raio.duplicate()
	raio_b.id = "raio_b"
	raio_b.wind = 0.6
	raio_b.w = 0.0
	raio_b.cd = 0.0
	var teleporte := {"id": "teleporte", "tell": false, "kind": "cast", "anim": "ranged", "wind": 0.4, "strike": 0.12, "recover": 0.15,
		"rmin": 0.0, "rmax": 9999.0, "w": 1.0, "cd": 5.0, "chain": ["gesto_b"]}
	var gesto_b := gesto.duplicate()
	gesto_b.id = "gesto_b"
	gesto_b.wind = 0.55
	gesto_b.rmax = 9999.0
	gesto_b.w = 0.0
	gesto_b.cd = 0.0
	gesto_b.recover = 1.2
	gesto_b.expose = true
	var mao2 := mao.duplicate()
	mao2.id = "mao2"
	mao2.n = 2
	return {
		1: [leque, gesto, raio, mao],
		2: [leque, gesto, raio, mao, aneis, larvas, combo, raio_b],
		3: [leque, gesto, mao2, aneis, larvas, combo, raio_b, teleporte, gesto_b],
	}


# --- o olho (ponto fraco) ----------------------------------------------------

func _setup_eye() -> void:
	if e._orb == null:
		return
	_rig = Node2D.new()
	_rig.name = "OrbRig"
	e.add_child(_rig)
	e._orb.reparent(_rig, false)
	_eye_box = Hurtbox.new()
	_eye_box.team = "enemy"
	_eye_box.collision_layer = e.hurtbox.collision_layer
	_eye_box.collision_mask = e.hurtbox.collision_mask
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 20.0
	cs.shape = circ
	_eye_box.add_child(cs)
	_rig.add_child(_eye_box)
	_eye_box.owner = e
	_eye_box.monitorable = false
	_eye_box.hit_received.connect(_on_eye_hit)


func _process(_d: float) -> void:
	if _eye_box != null and e._orb != null and is_instance_valid(e._orb):
		_eye_box.position = e._orb.position


func _set_low(v: bool) -> void:
	if _rig == null or v == _low:
		return
	_low = v
	var t := _rig.create_tween()
	t.tween_property(_rig, "position:y", ORB_LOW if v else 0.0, 0.35 if v else 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if v else Tween.EASE_IN_OUT)
	_eye_box.set_deferred("monitorable", v)
	if v:
		ImpactBurst.spawn(e.get_parent(), e._orb.global_position + Vector2(0, ORB_LOW), LIGHT)


func _on_eye_hit(dmg: int, src: Vector2, kb: float, unb: bool, attacker: Node) -> void:
	if not _low:
		return
	e._on_hit_received(int(round(float(dmg) * EYE_MULT)), src, kb * 0.3, unb, attacker)
	VfxLibrary.hit(e.get_parent(), e._orb.global_position, true, LIGHT)


func _signature(delta: float) -> void:
	_summons_cd = maxf(0.0, _summons_cd - delta)
	var exposed: bool = (e.estate == Enemy.EState.RECOVER and bool(mv.get("expose", false))) \
		or (e.estate == Enemy.EState.STAGGER and _roar_t <= 0.0 and _dying < 0)
	_set_low(exposed)


# --- golpes ------------------------------------------------------------------

func _on_windup(m: Dictionary) -> void:
	var pl := _player()
	if pl == null:
		return
	match String(m.id):
		"raio", "raio_b":
			# feixe rasteiro do olho: nasce nele e corre pelo chão até a parede
			var b := arena_bounds()
			var dir := e.atk_dir
			var h := hazard(e.global_position.x + dir * 40.0, "band", 20.0, m.wind, 0.8, LIGHT)
			h.height = 28.0
			h.hit_air = false
			h.active = 2.2
			h.vel_x = dir * 300.0
			h.min_x = b.x
			h.max_x = b.y
		"mao", "mao2":
			var n: int = int(m.n)
			for i in n:
				var x: float = pl.global_position.x + (float(i) - float(n - 1) * 0.5) * 120.0
				var c := hazard(x, "column", 34.0, m.wind + 0.4 + 0.25 * float(i), 1.0, LIGHT)
				if n == 1:
					c.follow = pl
					c.lock_at = 0.5
				c.struck.connect(_hand_waves.bind(c))


func _hand_waves(c: BossHazard) -> void:
	if _dead or not is_instance_valid(c):
		return
	for d in [-1, 1]:
		var w := ground_wave(d, 0.5, 210.0)
		w.global_position = Vector2(c.global_position.x + 36.0 * d, ground_y() - 12.0)


func _on_strike(m: Dictionary) -> void:
	var pl := _player()
	match String(m.id):
		"aneis":
			var b := arena_bounds()
			for d in [-1, 1]:
				var s := hazard(e.global_position.x + d * 30.0, "band", 15.0, 0.35, 0.6, LIGHT)
				s.look = "saw"
				s.height = 30.0
				s.hit_air = false
				s.active = 4.5
				s.tick = 0.8
				s.vel_x = d * 230.0
				s.min_x = b.x + 20.0
				s.max_x = b.y - 20.0
				s.bounce = true
				s.silent = true
		"larvas":
			if _summons_cd <= 0.0:
				_summons_cd = 18.0
				e._prune_minions()
				if e._minions.size() < 2:
					e._summon("larva", 2)
		"teleporte":
			if pl != null:
				e._blink_to(pl.global_position.x - float(pl.get("facing")) * 50.0)


func _on_defeated(x) -> void:
	_set_low(false)
	for m in e._minions:
		if is_instance_valid(m) and m.estate != Enemy.EState.DEAD:
			m._on_hit_received(m.health.max_health + 9999, e.global_position, 10.0, false, null)
	super._on_defeated(x)
