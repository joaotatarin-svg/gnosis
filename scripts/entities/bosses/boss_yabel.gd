extends BossBrain
## YABEL, Arconte do SILÊNCIO (tela 37). O filho que perguntou em voz alta e
## teve a boca costurada. Espectro alado: atira de longe, voa, e cala.
## ASSINATURA — ZONAS MUDAS: perto dele as magias não saem (aura). Fase 2:
## círculos pálidos de silêncio pousam no chão — DENTRO deles não há magia nem
## voo (não dá pra pular). E o GRITO COSTURADO (preparação longa, losango
## vermelho) varre a arena inteira... menos as zonas mudas: o abrigo é o
## silêncio. Fase 3: as zonas trocam de lugar mais rápido, ele pisca para as
## costas da Sophia e o grito vem mais vezes.
## Janelas: depois do Grito ele cai de joelhos (1,8 s); o golpe de Asas
## (amarelo) aparado atordoa; o Mergulho termina com ele no chão.

const PALE := Color(0.72, 0.8, 1.0)
const AURA_R := 120.0

var _zones: Array = []
var _zone_t: float = 0.0


func _on_setup() -> void:
	dmg_scale = 0.8
	keep_dist = Vector2(110.0, 200.0)
	gap_by_phase = [1.0, 0.85, 0.7]
	escape_hits = 3
	escape_id = "mergulho"


func _build_moves() -> Dictionary:
	var sopro := {"id": "sopro", "kind": "shot", "anim": "ranged", "wind": 0.7, "strike": 0.4, "recover": 0.6,
		"offs": [0.0, 0.0], "stagger": 0.25, "speed": 230.0, "dmg": 0.55, "color": PALE,
		"rmin": 90.0, "rmax": 9999.0, "w": 1.2, "cd": 1.8, "aa": true}
	var asas := {"id": "asas", "kind": "melee", "anim": "melee", "wind": 0.65, "strike": 0.22, "recover": 0.75,
		"off": 34.0, "sx": 2.4, "sy": 1.6, "dmg": 1.0, "rmax": 100.0, "w": 2.0, "cd": 0.8}
	var pergaminhos := {"id": "pergaminhos", "kind": "cast", "anim": "ranged", "wind": 0.8, "strike": 0.3,
		"recover": 0.8, "unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.1, "cd": 4.5, "aa": true}
	var mergulho := {"id": "mergulho", "kind": "leap", "anim": "charge", "wind": 0.5, "strike": 1.7, "recover": 1.2,
		"unblock": true, "dmg": 1.0, "land_r": 56.0, "rmin": 0.0, "rmax": 9999.0, "w": 0.7, "cd": 7.0, "aa": true}
	var grito := {"id": "grito", "kind": "cast", "anim": "ranged", "wind": 1.6, "strike": 0.4, "recover": 1.8,
		"unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.4, "cd": 9.0, "aa": true}
	var laminas := {"id": "laminas", "kind": "shot", "anim": "ranged", "wind": 0.75, "strike": 0.6, "recover": 0.6,
		"offs": [0.0, -30.0, 0.0, -30.0], "stagger": 0.2, "speed": 260.0, "dmg": 0.5, "color": PALE,
		"rmin": 80.0, "rmax": 9999.0, "w": 1.0, "cd": 3.0, "aa": true}
	var pisca := {"id": "pisca", "kind": "cast", "anim": "ranged", "wind": 0.35, "strike": 0.12, "recover": 0.1,
		"rmin": 0.0, "rmax": 9999.0, "w": 0.9, "cd": 5.0, "chain": ["asas_b"]}
	var asas_b := asas.duplicate()
	asas_b.id = "asas_b"
	asas_b.wind = 0.5
	asas_b.rmax = 9999.0
	asas_b.w = 0.0
	asas_b.cd = 0.0
	var grito3 := grito.duplicate()
	grito3.id = "grito3"
	grito3.cd = 7.0
	grito3.wind = 1.4
	return {
		1: [sopro, asas, pergaminhos, mergulho],
		2: [sopro, asas, pergaminhos, mergulho, grito],
		3: [laminas, asas, pisca, asas_b, pergaminhos, mergulho, grito3],
	}


func _on_windup(m: Dictionary) -> void:
	var pl := _player()
	if pl == null:
		return
	match m.id:
		"pergaminhos":
			var b := arena_bounds()
			var xs := [0.0, -80.0, 80.0]
			for i in xs.size():
				var x: float = clampf(pl.global_position.x + float(xs[i]), b.x + 30.0, b.y - 30.0)
				var h := hazard(x, "column", 24.0, 1.0 + 0.25 * float(i), 0.8, PALE)
				if i == 0:
					h.follow = pl
					h.lock_at = 0.4
		"grito", "grito3":
			# o abrigo é o silêncio: tudo menos as zonas mudas
			var b2 := arena_bounds()
			var h2 := hazard((b2.x + b2.y) * 0.5, "arena", (b2.y - b2.x) * 0.5, m.wind + 0.02, 1.1, PALE)
			h2.height = 400.0
			h2.active = 0.25
			h2.holes = _zones.filter(func(z): return is_instance_valid(z))
			h2.knockback = 120.0
			h2.struck.connect(func() -> void: Juice.shake(0.7))


func _on_strike(m: Dictionary) -> void:
	if m.id == "pisca":
		var pl := _player()
		if pl != null:
			e._blink_to(pl.global_position.x - float(pl.get("facing")) * 48.0)


func _on_phase(n: int) -> void:
	_zone_t = 0.0      # posiciona as zonas já
	if n == 3:
		gap_by_phase[2] = 0.7


func _signature(delta: float) -> void:
	var pl := _player()
	if pl == null:
		return
	# aura: perto dele, magia não sai
	if e.global_position.distance_to(pl.global_position) < AURA_R:
		pl.set("silenced_timer", maxf(float(pl.get("silenced_timer")), 0.3))
	if phase < 2:
		return
	# zonas mudas: dentro, sem magia e sem voo
	for z in _zones:
		if is_instance_valid(z) and z.contains(pl.global_position):
			pl.set("silenced_timer", maxf(float(pl.get("silenced_timer")), 0.3))
			BossHazard.ground_player(pl)
	_zone_t -= delta
	if _zone_t <= 0.0 and not (e.estate == Enemy.EState.WINDUP and String(mv.get("id", "")).begins_with("grito")):
		_zone_t = 11.0 if phase == 2 else 7.0
		_place_zones()


func _place_zones() -> void:
	for z in _zones:
		remove_node(z)
	_zones.clear()
	var b := arena_bounds()
	var w := b.y - b.x
	var n := 2
	var picks: Array = [0.2, 0.5, 0.8]
	var skip := rng.randi() % 3
	for i in 3:
		if i == skip or _zones.size() >= n:
			continue
		var x: float = b.x + w * float(picks[i]) + rng.randf_range(-40.0, 40.0)
		var z := hazard(x, "circle", 48.0, 0.8, 0.0, PALE)
		z.safe = true
		z.silent = true
		z.active = 9999.0
		_zones.append(z)
