extends BossBrain
## BELIAS, Arconte da PRAGA (tela 55). O filho cansado, que só quer que pare
## de doer — e espalha a podridão onde passa. Fera de quatro patas, rápida.
## ASSINATURA — POÇAS E ESPOROS: o Bote deixa rastro de veneno; os Esporos
## caem (sombra no chão primeiro) e viram poças que CRESCEM devagar. O chão vai
## sendo tomado — e APARAR (ou quebrar a postura dele) faz as poças secarem:
## a esperança limpa. Fase 2: nuvem de esporos que persegue e duas fendas
## que arrotam veneno em coluna. Fase 3: ele se ENTERRA e irrompe sob a
## Sophia (o chão estufa e segue; trava antes de romper); poças crescem mais.
## Janelas: depois do Bote ele derrapa (1,0 s); ao sair da terra fica meio
## enterrado (1,4 s); a Mordida (amarela) aparada atordoa.

const ROT := Color(0.7, 1.0, 0.5)
const POOL_TICK := 0.7

var _pools: Array = []
var _pool_t: float = 0.0
var _vent_t: float = 4.0
var _vents: Array = []
var _was_stag: bool = false


func _on_setup() -> void:
	dmg_scale = 0.45
	keep_dist = Vector2(60.0, 160.0)
	gap_by_phase = [0.9, 0.8, 0.7]
	escape_hits = 3
	escape_id = "enterrar"


func _build_moves() -> Dictionary:
	var bote := {"id": "bote", "kind": "charge", "anim": "charge", "wind": 0.7, "strike": 0.5, "recover": 1.0,
		"unblock": true, "speed": 380.0, "dmg": 1.0, "sx": 1.6, "rmin": 90.0, "rmax": 9999.0, "w": 1.3, "cd": 3.0}
	var mordida := {"id": "mordida", "kind": "melee", "anim": "melee", "wind": 0.55, "strike": 0.2, "recover": 0.7,
		"off": 40.0, "sx": 2.0, "sy": 1.3, "dmg": 1.0, "rmax": 95.0, "w": 2.0, "cd": 0.8}
	var esporos := {"id": "esporos", "kind": "cast", "anim": "ranged", "wind": 0.75, "strike": 0.3, "recover": 0.7,
		"unblock": true, "n": 3, "rmin": 0.0, "rmax": 9999.0, "w": 1.1, "cd": 4.5, "aa": true}
	var enterrar := {"id": "enterrar", "kind": "leap", "anim": "charge", "burrow": true, "wind": 0.6, "strike": 1.7,
		"recover": 1.4, "unblock": true, "dmg": 0.9, "land_r": 40.0, "rmin": 0.0, "rmax": 9999.0, "w": 0.6,
		"cd": 8.0, "aa": true}
	var nuvem := {"id": "nuvem", "kind": "cast", "anim": "ranged", "wind": 0.8, "strike": 0.3, "recover": 0.7,
		"unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.0, "cd": 7.0, "aa": true}
	var esporos5 := esporos.duplicate()
	esporos5.id = "esporos5"
	esporos5.n = 5
	var mordida2 := mordida.duplicate()
	mordida2.id = "mordida2"
	mordida2.chain = ["mordida_b"]
	mordida2.recover = 0.3
	var mordida_b := mordida.duplicate()
	mordida_b.id = "mordida_b"
	mordida_b.wind = 0.42
	mordida_b.rmax = 9999.0
	mordida_b.w = 0.0
	mordida_b.cd = 0.0
	var enterrar3 := enterrar.duplicate()
	enterrar3.id = "enterrar3"
	enterrar3.w = 1.2
	enterrar3.cd = 6.0
	enterrar3.chain = ["mordida_b"]
	enterrar3.recover = 0.4
	return {
		1: [bote, mordida, esporos, enterrar],
		2: [bote, mordida2, mordida_b, esporos5, nuvem, enterrar],
		3: [bote, mordida2, mordida_b, esporos5, nuvem, enterrar3],
	}


func _on_windup(m: Dictionary) -> void:
	var pl := _player()
	if pl == null:
		return
	match m.id:
		"esporos", "esporos5":
			var b := arena_bounds()
			var n: int = int(m.n)
			for i in n:
				var off: float = (float(i) - float(n - 1) * 0.5) * 75.0
				var x: float = clampf(pl.global_position.x + off + rng.randf_range(-15.0, 15.0), b.x + 30.0, b.y - 30.0)
				var h := hazard(x, "circle", 26.0, 1.0 + 0.12 * float(i), 0.6, ROT)
				h.active = 0.15
				h.struck.connect(_pool_at.bind(x, 30.0))
		"nuvem":
			var c := hazard(e.global_position.x + e.atk_dir * 40.0, "circle", 44.0, 0.6, 0.35, ROT)
			c.active = 5.0
			c.tick = POOL_TICK
			c.effect = "poison"
			c.vel_x = signf(pl.global_position.x - e.global_position.x) * 70.0
			var b2 := arena_bounds()
			c.min_x = b2.x
			c.max_x = b2.y
			c.silent = true


func _on_strike(m: Dictionary) -> void:
	if m.id == "bote":
		_pool_t = 0.0


func _strike_tick(m: Dictionary, delta: float) -> void:
	# o Bote deixa rastro de veneno
	if m.id == "bote":
		_pool_t -= delta
		if _pool_t <= 0.0:
			_pool_t = 0.14
			_pool_at(e.global_position.x, 24.0, 3.0)


func _on_land(m: Dictionary) -> void:
	if m.id.begins_with("enterrar"):
		_pool_at(e.global_position.x, 40.0, 4.0)


## Poça de veneno que cresce devagar (imparável; tique leve).
func _pool_at(x: float, r: float, life: float = 0.0) -> void:
	if _dead:
		return
	var lf: float = life if life > 0.0 else (6.0 if phase < 3 else 7.0)
	var h := hazard(x, "circle", r, 0.05, 0.12, ROT)
	h.active = lf
	h.tick = POOL_TICK
	h.silent = true
	h.knockback = 30.0
	h.grow = 0.0 if life > 0.0 else (3.0 if phase < 3 else 5.0)
	h.max_w = r * 1.8
	_pools = _pools.filter(func(p): return is_instance_valid(p))
	_pools.append(h)
	# no máximo 9 poças vivas: a mais velha seca
	while _pools.size() > 7:
		remove_node(_pools.pop_front())


func _on_phase(n: int) -> void:
	if n == 2:
		var b := arena_bounds()
		_vents = [b.x + (b.y - b.x) * 0.25, b.x + (b.y - b.x) * 0.75]
		_vent_t = 3.0


func _signature(delta: float) -> void:
	# APARAR (ou quebrar a postura) SECA as poças: a esperança limpa
	var stag: bool = e.estate == Enemy.EState.STAGGER and _roar_t <= 0.0 and _dying < 0
	if stag and not _was_stag:
		for p in _pools:
			remove_node(p)
		_pools.clear()
	_was_stag = stag
	if phase < 2 or _vents.is_empty():
		return
	_vent_t -= delta
	if _vent_t <= 0.0:
		_vent_t = 6.0 if phase == 2 else 4.5
		for x in _vents:
			var h := hazard(float(x), "column", 30.0, 1.2, 0.7, ROT)
			h.effect = "poison"
