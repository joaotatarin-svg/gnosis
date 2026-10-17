extends BossBrain
## ASTAPHAIOS, Arconte do ESPELHO (tela 46). O filho que nunca teve rosto e
## vive do rosto dos outros. Luta como ela: estocada, cacos, cajado-espelho.
## ASSINATURA — REFLEXOS: a GUARDA DO ESPELHO (anel prateado girando em volta
## dele, som de vidro) DEVOLVE todo golpe a quem bateu — espere o anel sumir.
## Fase 2: ele se desdobra em REFLEXOS (cópias menores, translúcidas e SEM
## SOMBRA no chão — o verdadeiro tem sombra). Quebrar um reflexo espirra cacos
## em quem bateu. Ele troca de lugar com um reflexo. Fase 3: SALA DE ESPELHOS —
## os cacos batem na parede e voltam; a guarda vem mais vezes.
## Janelas: depois da Guarda o espelho TRINCA (1,3 s aberto); a Estocada
## (amarela) aparada atordoa.

const GLASS := Color(0.9, 0.95, 1.0)
const REFLECT_K := 0.6

var _ring: Node2D = null
var _clones: Array = []


func _on_setup() -> void:
	dmg_scale = 0.8
	keep_dist = Vector2(50.0, 110.0)
	gap_by_phase = [0.9, 0.8, 0.7]
	escape_hits = 4
	escape_id = "guarda"


func _build_moves() -> Dictionary:
	var estocada := {"id": "estocada", "kind": "charge", "anim": "charge", "wind": 0.6, "strike": 0.28, "recover": 0.9,
		"speed": 320.0, "dmg": 1.0, "sx": 1.6, "rmin": 50.0, "rmax": 220.0, "w": 1.5, "cd": 1.5}
	var corte := {"id": "corte", "kind": "melee", "anim": "melee", "wind": 0.55, "strike": 0.2, "recover": 0.6,
		"off": 34.0, "sx": 2.1, "sy": 1.5, "dmg": 0.9, "rmax": 90.0, "w": 1.6, "cd": 0.8}
	var cacos := {"id": "cacos", "kind": "shot", "anim": "ranged", "wind": 0.65, "strike": 0.45, "recover": 0.6,
		"offs": [0.0, 0.0, 0.0], "stagger": 0.15, "speed": 280.0, "dmg": 0.45, "color": GLASS,
		"rmin": 100.0, "rmax": 9999.0, "w": 1.1, "cd": 2.5, "aa": true}
	# GUARDA DO ESPELHO: strike = tempo da guarda; recover = espelho trincado
	var guarda := {"id": "guarda", "kind": "cast", "anim": "ranged", "wind": 0.4, "strike": 1.7, "recover": 1.3,
		"rmin": 0.0, "rmax": 9999.0, "w": 1.0, "cd": 6.0}
	var reflexos := {"id": "reflexos", "kind": "cast", "anim": "ranged", "wind": 0.8, "strike": 0.3, "recover": 0.6,
		"rmin": 0.0, "rmax": 9999.0, "w": 1.2, "cd": 9.0}
	var troca := {"id": "troca", "kind": "cast", "anim": "ranged", "wind": 0.35, "strike": 0.15, "recover": 0.3,
		"rmin": 0.0, "rmax": 9999.0, "w": 0.9, "cd": 5.0, "chain": ["estocada_b"]}
	var estocada_b := estocada.duplicate()
	estocada_b.id = "estocada_b"
	estocada_b.wind = 0.5
	estocada_b.rmin = 0.0
	estocada_b.rmax = 9999.0
	estocada_b.w = 0.0
	estocada_b.cd = 0.0
	var cacos3 := cacos.duplicate()
	cacos3.id = "cacos3"
	cacos3.offs = [0.0, 0.0, 0.0, 0.0]
	cacos3.life = 1.6
	var guarda3 := guarda.duplicate()
	guarda3.id = "guarda3"
	guarda3.cd = 4.5
	guarda3.w = 1.3
	return {
		1: [estocada, corte, cacos, guarda],
		2: [estocada, corte, cacos, guarda, reflexos, troca, estocada_b],
		3: [estocada, corte, cacos3, guarda3, reflexos, troca, estocada_b],
	}


func _guarding() -> bool:
	return e.estate == Enemy.EState.STRIKE and String(mv.get("id", "")).begins_with("guarda")


func no_touch() -> bool:
	return _guarding() or super.no_touch()


## Na guarda, o golpe volta para quem bateu.
func _filter(dmg: int, attacker: Node) -> int:
	if _guarding():
		if attacker != null and is_instance_valid(attacker) and attacker.has_method("_on_hit_received"):
			attacker._on_hit_received(maxi(1, int(dmg * REFLECT_K)), e.global_position, 200.0, true, e)
		ImpactBurst.spawn(e.get_parent(), e.global_position + Vector2(0, -20.0 * e._art_scale), GLASS)
		sfx("glass", e.global_position)
		return 0
	return dmg


func _on_strike(m: Dictionary) -> void:
	var pl := _player()
	match m.id:
		"guarda", "guarda3":
			_show_ring(m.strike)
		"reflexos":
			_spawn_clones(2 if phase == 2 else 3)
		"troca":
			_swap_with_clone()
		"cacos3":
			# sala de espelhos: cada caco volta da parede
			_later(0.9, _bounce_volley)


func _show_ring(t: float) -> void:
	if _ring == null or not is_instance_valid(_ring):
		_ring = MirrorRing.new()
		e.add_child(_ring)
		_ring.position = Vector2(0, -22.0)
		_ring.radius = 34.0 * e._art_scale
	_ring.show_for(t)
	sfx("glass", e.global_position)


func _spawn_clones(n: int) -> void:
	_clones = _clones.filter(func(c): return is_instance_valid(c) and c.estate != Enemy.EState.DEAD)
	var want := n - _clones.size()
	if want <= 0:
		return
	var before: Array = e._minions.duplicate()
	e._summon("eco_arconte_espelho", want)
	for m in e._minions:
		if m in before or not is_instance_valid(m):
			continue
		m.health.setup(maxi(1, int(BossTuning.expected_hit(BossTuning.expected_weapon_level(screen)) * 1.5)))
		if m.has_node("Shadow"):
			m.get_node("Shadow").visible = false     # o reflexo não tem sombra
		m.spark_reward = 0
		m.defeated.connect(_on_clone_broken)
		_clones.append(m)


## Quebrar um reflexo espirra cacos em volta (não é de graça adivinhar).
func _on_clone_broken(c) -> void:
	if _dead or not is_instance_valid(c):
		return
	var pl := _player()
	ImpactBurst.spawn(e.get_parent(), c.global_position + Vector2(0, -16), GLASS)
	if pl != null and pl.global_position.distance_to(c.global_position) < 70.0:
		pl._on_hit_received(int(_base_dmg * 0.35), c.global_position, 160.0, true, e)


func _swap_with_clone() -> void:
	_clones = _clones.filter(func(c): return is_instance_valid(c) and c.estate != Enemy.EState.DEAD)
	if _clones.is_empty():
		var pl := _player()
		if pl != null:
			e._blink_to(pl.global_position.x - float(pl.get("facing")) * 60.0)
		return
	var c: Node2D = _clones[rng.randi() % _clones.size()]
	var a := e.global_position.x
	e._blink_to(c.global_position.x)
	c.global_position.x = a
	c.reset_physics_interpolation()


func _bounce_volley() -> void:
	var b := arena_bounds()
	for i in 3:
		var p := Projectile.new()
		var from_left: bool = i % 2 == 0
		p.direction = 1 if from_left else -1
		p.damage = int(_base_dmg * 0.4)
		p.speed = 240.0
		p.pierce = false
		p.target_team = "player"
		p.color = GLASS
		p.lifetime = 2.6
		e.get_parent().add_child(p)
		p.global_position = Vector2((b.x + 20.0) if from_left else (b.y - 20.0), e.global_position.y - 10.0 - 24.0 * float(i % 2))


func _on_phase(n: int) -> void:
	if n == 3:
		# a Sombra da Sophia entra uma vez (ela contra ela mesma)
		e._summon("sombra_sophia", 1)


func _signature(_delta: float) -> void:
	pass


func _on_defeated(x) -> void:
	for c in _clones:
		if is_instance_valid(c) and c.estate != Enemy.EState.DEAD:
			c._on_hit_received(c.health.max_health + 9999, e.global_position, 10.0, false, null)
	super._on_defeated(x)


## Anel de espelho girando em volta dele durante a guarda.
class MirrorRing extends Node2D:
	var radius := 34.0
	var _left := 0.0
	var _t := 0.0
	func show_for(t: float) -> void:
		_left = t
		visible = true
	func _process(d: float) -> void:
		_t += d
		_left -= d
		visible = _left > 0.0
		queue_redraw()
	func _draw() -> void:
		if _left <= 0.0:
			return
		var c := Color(0.9, 0.95, 1.0, 0.85)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(c, 0.35), 3.0, true)
		for k in 6:
			var a := _t * 2.4 + TAU * float(k) / 6.0
			var p := Vector2(cos(a) * radius, sin(a) * radius * 0.6)
			var s := 5.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.6, 0), p + Vector2(0, s), p + Vector2(-s * 0.6, 0)]), c)
