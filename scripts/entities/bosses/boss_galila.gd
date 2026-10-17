extends BossBrain
## GALILA, Arconte da CORRENTE (tela 28). O filho que obedece porque tem medo
## de cair. Espadão e correntes: luta de média distância, prende e puxa.
## ASSINATURA — CORRENTES E PÊNDULOS: a Corrente (tiro de elo) PRENDE a
## Sophia no lugar (rolar quebra); o Puxão (laço vermelho à frente) a arrasta
## até ele e emenda um corte (amarelo: dá pra aparar). Fase 2: duas gaiolas-
## pêndulo balançam pela arena (passe por baixo no alto do balanço, pule, ou
## role); ele SOBE na corrente e despenca onde ela estiver. Fase 3: três
## pêndulos mais rápidos, Prisão (colunas de corrente) e o Giro (vermelho).
## Janelas: a Estocada termina com a espada cravada (1,2 s); o Corte e a
## Estocada (amarelos) aparados atordoam.

const STEEL := Color(0.85, 0.85, 0.95)

var _pends: Array = []


func _on_setup() -> void:
	dmg_scale = 0.8
	keep_dist = Vector2(60.0, 140.0)
	gap_by_phase = [0.95, 0.8, 0.7]
	escape_hits = 3
	escape_id = "queda"


func _build_moves() -> Dictionary:
	var corrente := {"id": "corrente", "kind": "shot", "anim": "ranged", "wind": 0.7, "strike": 0.3, "recover": 0.6,
		"offs": [0.0], "speed": 280.0, "root": 1.1, "dmg": 0.5, "color": STEEL,
		"rmin": 110.0, "rmax": 9999.0, "w": 1.2, "cd": 3.0}
	var estocada := {"id": "estocada", "kind": "charge", "anim": "charge", "wind": 0.75, "strike": 0.32,
		"recover": 1.2, "speed": 400.0, "dmg": 1.1, "sx": 1.8, "rmin": 70.0, "rmax": 260.0, "w": 1.3, "cd": 2.5}
	var corte := {"id": "corte", "kind": "melee", "anim": "melee", "wind": 0.6, "strike": 0.2, "recover": 0.7,
		"off": 38.0, "sx": 2.3, "sy": 1.5, "dmg": 1.0, "rmax": 100.0, "w": 2.0, "cd": 0.8}
	var corte_b := corte.duplicate()
	corte_b.id = "corte_b"
	corte_b.wind = 0.45
	corte_b.rmax = 9999.0
	corte_b.w = 0.0
	corte_b.cd = 0.0
	var puxao := {"id": "puxao", "kind": "cast", "anim": "ranged", "wind": 0.8, "strike": 0.25, "recover": 0.2,
		"unblock": true, "rmin": 90.0, "rmax": 230.0, "w": 1.3, "cd": 5.0, "chain": ["corte_b"]}
	var queda := {"id": "queda", "kind": "leap", "anim": "slam", "wind": 0.6, "strike": 1.6, "recover": 1.1,
		"unblock": true, "dmg": 1.1, "land_r": 52.0, "rmin": 0.0, "rmax": 9999.0, "w": 0.7, "cd": 8.0, "aa": true}
	var estocada2 := estocada.duplicate()
	estocada2.id = "estocada2"
	estocada2.recover = 0.25
	estocada2.chain = ["estocada2b"]
	var estocada2b := estocada.duplicate()
	estocada2b.id = "estocada2b"
	estocada2b.wind = 0.5
	estocada2b.rmin = 0.0
	estocada2b.rmax = 9999.0
	estocada2b.w = 0.0
	estocada2b.cd = 0.0
	var prisao := {"id": "prisao", "kind": "cast", "anim": "ranged", "wind": 0.9, "strike": 0.3, "recover": 1.0,
		"unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.1, "cd": 6.0, "aa": true}
	var giro := {"id": "giro", "kind": "slam", "anim": "slam", "wind": 0.85, "strike": 0.35, "recover": 1.1,
		"unblock": true, "sx": 3.6, "sy": 1.6, "nova": 125.0, "dmg": 1.2, "kb": 360.0, "rmax": 130.0, "w": 1.2, "cd": 4.0}
	var queda3 := queda.duplicate()
	queda3.id = "queda3"
	queda3.waves = 2
	queda3.strike = 1.4
	return {
		1: [corrente, estocada, corte, corte_b, queda],
		2: [corrente, estocada2, estocada2b, corte, corte_b, puxao, queda],
		3: [corrente, estocada2, estocada2b, corte_b, puxao, prisao, giro, queda3],
	}


func _on_windup(m: Dictionary) -> void:
	var pl := _player()
	if pl == null:
		return
	match m.id:
		"puxao":
			# laço de corrente à frente: faixa vermelha que sai dele
			var dir := e.atk_dir
			var h := hazard(e.global_position.x + dir * 125.0, "band", 105.0, m.wind, 0.35, STEEL)
			h.height = 60.0
			h.active = 0.12
			h.effect = "root"
			h.effect_time = 0.5
			h.knockback = 0.0
			h.struck.connect(_drag_check.bind(h))
		"prisao":
			var b := arena_bounds()
			var xs := [-90.0, 0.0, 90.0]
			for i in xs.size():
				var x: float = clampf(pl.global_position.x + float(xs[i]), b.x + 30.0, b.y - 30.0)
				var c := hazard(x, "column", 24.0, 1.0 + 0.25 * float(i), 0.8, STEEL)
				c.effect = "root"
				c.effect_time = 0.9


## Puxão: se o laço pegou, a corrente arrasta a Sophia até a frente dele.
func _drag_check(h: BossHazard) -> void:
	var pl := _player()
	if pl == null or not is_instance_valid(h):
		return
	if not h.contains(pl.global_position) or pl.get("state") == Player.State.DODGE:
		return
	var to := e.global_position.x + e.atk_dir * 46.0
	var t := pl.create_tween()
	t.tween_property(pl, "global_position:x", to, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sfx("chain", pl.global_position)


func _on_phase(n: int) -> void:
	var b := arena_bounds()
	var c := (b.x + b.y) * 0.5
	for p in _pends:
		remove_node(p)
	_pends.clear()
	var gy := ground_y()
	if n == 2:
		_pends.append(_pendulum(Vector2(c - 160.0, gy - 250.0), 0.0, 3.4))
		_pends.append(_pendulum(Vector2(c + 160.0, gy - 250.0), PI, 3.4))
	elif n == 3:
		_pends.append(_pendulum(Vector2(c - 220.0, gy - 250.0), 0.0, 2.8))
		_pends.append(_pendulum(Vector2(c, gy - 250.0), PI * 0.5, 2.8))
		_pends.append(_pendulum(Vector2(c + 220.0, gy - 250.0), PI, 2.8))


func _pendulum(anchor: Vector2, ph: float, period: float) -> Node2D:
	var p := Pendulum.new()
	p.anchor = anchor
	p.length = 222.0           # a gaiola passa a ~28 px do chão (altura do corpo)
	p.phase = ph
	p.period = period
	p.damage = int(_base_dmg * 0.8)
	p.owner_enemy = e
	p.color = STEEL
	e.get_parent().add_child(p)
	_spawned.append(p)
	return p


## Gaiola-pêndulo: balança numa corrente presa no alto. Fere ao tocar (imparável,
## 1 vez por passagem). Aparece descendo (1,2 s) antes de ferir.
class Pendulum extends Node2D:
	var anchor := Vector2.ZERO
	var length := 220.0
	var amp := 0.95            # rad
	var period := 3.2
	var phase := 0.0
	var damage := 10
	var owner_enemy: Node = null
	var color := Color(0.85, 0.85, 0.95)
	var _t := 0.0
	var _cd := 0.0
	var _in := 0.0             # 0..1 descendo

	func _ready() -> void:
		z_index = 15
		add_to_group("boss_hazard")

	func bob() -> Vector2:
		var a: float = amp * sin(TAU * _t / period + phase)
		var L: float = length * _in
		return anchor + Vector2(sin(a) * L, cos(a) * L)

	func _physics_process(delta: float) -> void:
		_t += delta
		_in = minf(1.0, _in + delta / 1.2)
		_cd = maxf(0.0, _cd - delta)
		queue_redraw()
		if _in < 1.0 or _cd > 0.0:
			return
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		if pl == null:
			return
		if pl.global_position.distance_to(bob()) < 30.0:
			_cd = 0.9
			pl._on_hit_received(damage, bob(), 260.0, true, owner_enemy)

	## SONDA: perigo se a gaiola vem perto na altura do corpo.
	func contains(pt: Vector2) -> bool:
		return pt.distance_to(bob()) < 30.0
	func threat_at(pt: Vector2) -> float:
		return 1.0 if pt.distance_to(bob()) < 70.0 else 0.0
	func escape_dir(pt: Vector2) -> String:
		return "dodge"

	func _draw() -> void:
		var b := to_local(bob())
		var a := to_local(anchor)
		draw_line(a, b, Color(color, 0.85), 2.0)
		for i in 8:
			var q := a.lerp(b, float(i) / 8.0)
			draw_circle(q, 2.2, Color(color, 0.9))
		draw_circle(b, 18.0, Color(0.15, 0.15, 0.2, 0.9))
		draw_arc(b, 18.0, 0, TAU, 20, Color(color, 1.0), 2.5)
		for k in 4:
			var xx := -12.0 + 8.0 * float(k)
			draw_line(b + Vector2(xx, -15), b + Vector2(xx, 15), Color(color, 0.8), 1.5)
		draw_circle(b, 5.0, Color(1.0, 0.75, 0.5, 0.9))
