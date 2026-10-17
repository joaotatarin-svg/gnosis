extends BossBrain
## ATHOTH, Arconte do TORPOR (tela 10). O filho que só quer que a dor pare —
## e dorme para não sentir. Luta de LONGE e faz a Sophia querer deitar.
## ASSINATURA — SONOLÊNCIA: a névoa dele não fere muito; ela ADORMECE. Cada
## segundo dentro dela enche a meia-lua azul sobre a cabeça da Sophia; cheia,
## ela cochila (presa ~1,2 s — ROLAR acorda). Fase 2: plataformas sobem e a
## MARÉ DE SONO cobre metade do chão; fase 3: o SONO PROFUNDO cobre o chão
## inteiro — só em cima das plataformas se fica acordada.
## NÉVOA: enquanto conjura o sono (Bocejo, Canção, Chuva) ele vira névoa —
## translúcido, o cajado passa por ele (quase sem dano). Bater nele é DEPOIS.
## Quem cola e bate muito leva a FUGA: ele se desfaz e reaparece longe, já
## atirando. Janelas: depois da Canção de Ninar e da Chuva de Sono ele boceja
## (recuperação longa); o Toque (amarelo) aparado abre o contra-ataque.

const DROWSY_FULL := 1.6       # s dentro da névoa até cochilar
const DROWSY_DECAY := 0.6      # por s, fora da névoa
const NAP_TIME := 1.2
const MIST := Color(0.62, 0.68, 1.0)

var _mark: Node2D = null
var _tide_t: float = 6.0
var _tide_side: int = 1
var _plats: Array = []
var _misty: bool = false
const MIST_CASTS := ["bocejo", "bocejo2", "cancao", "chuva"]


func _on_setup() -> void:
	dmg_scale = 0.7
	keep_dist = Vector2(130.0, 230.0)
	gap_by_phase = [1.25, 1.0, 0.8]
	escape_id = "fuga"
	escape_hits = 3


func _build_moves() -> Dictionary:
	var orbes := {"id": "orbes", "kind": "shot", "anim": "ranged", "wind": 0.85, "strike": 0.5, "recover": 0.6,
		"offs": [0.0, 0.0, 0.0], "stagger": 0.22, "speed": 190.0, "slow": 1.0, "dmg": 0.55,
		"rmin": 80.0, "rmax": 999.0, "w": 1.0, "cd": 2.0, "aa": true, "color": MIST}
	var bocejo := {"id": "bocejo", "kind": "cast", "anim": "ranged", "wind": 0.7, "strike": 0.3, "recover": 0.7,
		"unblock": true, "rmin": 0.0, "rmax": 999.0, "w": 1.0, "cd": 4.0, "aa": true}
	var toque := {"id": "toque", "kind": "melee", "anim": "melee", "wind": 0.7, "strike": 0.22, "recover": 0.75,
		"off": 34.0, "sx": 2.0, "sy": 1.5, "dmg": 1.0, "rmin": 0.0, "rmax": 90.0, "w": 2.0, "cd": 1.0}
	var deslize := {"id": "deslize", "kind": "cast", "anim": "ranged", "wind": 0.45, "strike": 0.15, "recover": 0.3,
		"rmin": 0.0, "rmax": 85.0, "w": 0.8, "cd": 6.0}
	var cancao := {"id": "cancao", "kind": "cast", "anim": "ranged", "wind": 1.0, "strike": 0.3, "recover": 1.4,
		"unblock": true, "rmin": 0.0, "rmax": 999.0, "w": 1.2, "cd": 6.0}
	var orbes5 := orbes.duplicate()
	orbes5.id = "orbes5"
	orbes5.offs = [0.0, 0.0, 0.0, 0.0, 0.0]
	orbes5.stagger = 0.17
	orbes5.speed = 215.0
	var bocejo2 := bocejo.duplicate()
	bocejo2.id = "bocejo2"
	var toque2 := toque.duplicate()
	toque2.id = "toque2"
	toque2.chain = ["toque_b"]
	var toque_b := toque.duplicate()
	toque_b.id = "toque_b"
	toque_b.wind = 0.45
	toque_b.recover = 0.9
	toque_b.w = 0.0          # só em cadeia
	var chuva := {"id": "chuva", "kind": "cast", "anim": "ranged", "wind": 0.9, "strike": 0.3, "recover": 1.2,
		"unblock": true, "rmin": 0.0, "rmax": 999.0, "w": 1.3, "cd": 5.0, "aa": true}
	var deslize3 := deslize.duplicate()
	deslize3.id = "deslize3"
	deslize3.rmax = 999.0
	deslize3.cd = 7.0
	deslize3.chain = ["toque_c"]
	var toque_c := toque.duplicate()
	toque_c.id = "toque_c"
	toque_c.wind = 0.55
	toque_c.rmax = 999.0
	toque_c.w = 0.0
	# FUGA (resposta a quem cola): some e reaparece longe — e já atira
	var fuga := deslize.duplicate()
	fuga.id = "fuga"
	fuga.w = 0.0
	fuga.rmax = 9999.0
	fuga.cd = 0.0
	fuga.chain = ["orbes_f"]
	var orbes_f := orbes.duplicate()
	orbes_f.id = "orbes_f"
	orbes_f.w = 0.0
	orbes_f.cd = 0.0
	orbes_f.wind = 0.6
	return {
		1: [orbes, bocejo, toque, deslize, fuga, orbes_f],
		2: [orbes5, bocejo2, toque2, toque_b, cancao, deslize, fuga, orbes_f],
		3: [orbes5, chuva, cancao, deslize3, toque_c, toque2, toque_b, fuga, orbes_f],
	}


func no_touch() -> bool:
	return _misty or super.no_touch()


func _filter(dmg: int, _attacker: Node) -> int:
	if _misty:
		ImpactBurst.spawn(e.get_parent(), e.global_position + Vector2(0, -20.0 * e._art_scale), MIST)
		return maxi(1, dmg / 5)
	return dmg


func _on_windup(m: Dictionary) -> void:
	_set_misty(m.id in MIST_CASTS)
	var pl := _player()
	if pl == null:
		return
	match m.id:
		"bocejo", "bocejo2":
			# a nuvem de sono cai ONDE a Sophia está (segue até 0,4 s antes)
			_cloud(pl, 1.15)
			if m.id == "bocejo2":
				_later(0.5, func() -> void: _cloud(pl, 1.0, 120.0))
		"chuva":
			# 4 colunas de sono em volta dela, uma depois da outra
			var b := arena_bounds()
			var xs := [-110.0, -40.0, 40.0, 110.0]
			if rng.randf() < 0.5:
				xs.reverse()
			for i in xs.size():
				var x: float = clampf(pl.global_position.x + float(xs[i]), b.x + 30.0, b.y - 30.0)
				var h := hazard(x, "column", 26.0, 1.0 + 0.22 * float(i), 0.9, MIST)
				h.effect = "sleep"


func _on_strike(m: Dictionary) -> void:
	match m.id:
		"deslize", "deslize3", "fuga":
			var pl := _player()
			if pl == null:
				return
			var b := arena_bounds()
			var x: float
			if m.id == "deslize3":
				x = pl.global_position.x - float(pl.get("facing")) * 60.0     # atrás dela
			else:
				x = b.y - 70.0 if pl.global_position.x < (b.x + b.y) * 0.5 else b.x + 70.0
			e._blink_to(x)
		"cancao":
			# CANÇÃO DE NINAR: um muro baixo de névoa corre pelo chão — PULE
			var b2 := arena_bounds()
			var h := hazard(e.global_position.x + 30.0 * e.atk_dir, "band", 22.0, 0.05, 0.45, MIST)
			h.height = 40.0
			h.active = 4.0
			h.tick = 0.5
			h.effect = "sleep"
			h.hit_air = false
			h.silent = true
			h.vel_x = 170.0 * e.atk_dir
			h.min_x = b2.x
			h.max_x = b2.y


func _cloud(pl: Node2D, delay: float, dx: float = 0.0) -> void:
	var h := hazard(pl.global_position.x + dx, "circle", 58.0, delay, 0.0, MIST)
	if dx == 0.0:
		h.follow = pl
		h.lock_at = 0.4
	h.active = 3.2
	h.tick = 0.2
	h.effect = "sleep"


func _on_phase(n: int) -> void:
	var b := arena_bounds()
	var c := (b.x + b.y) * 0.5
	var gy := ground_y()
	if n == 2:
		_plats.append(platform(Vector2(c - 170.0, gy - 62.0), 120.0))
		_plats.append(platform(Vector2(c + 170.0, gy - 62.0), 120.0))
		_tide_t = 3.0
	elif n == 3:
		_plats.append(platform(Vector2(c, gy - 118.0), 110.0))
		_tide_t = 3.0


func _signature(delta: float) -> void:
	var pl := _player()
	if pl == null:
		return
	_drowsy(pl, delta)
	if _misty and e.estate in [Enemy.EState.CHASE, Enemy.EState.STAGGER, Enemy.EState.HURT]:
		_set_misty(false)
	if phase < 2:
		return
	_tide_t -= delta
	if _tide_t > 0.0:
		return
	var b := arena_bounds()
	var c := (b.x + b.y) * 0.5
	var half := (b.y - b.x) * 0.5
	if phase == 2:
		# MARÉ DE SONO: metade do chão (alterna o lado), 1,5 s de aviso, 4 s
		_tide_t = 9.0
		_tide_side = -_tide_side
		var h := hazard(c + _tide_side * half * 0.5, "band", half * 0.5, 1.5, 0.0, MIST)
		h.height = 40.0
		h.active = 4.0
		h.tick = 0.25
		h.effect = "sleep"
		h.hit_air = false
	else:
		# SONO PROFUNDO: o chão inteiro; só as plataformas salvam
		_tide_t = 8.0
		var h2 := hazard(c, "arena", half, 1.6, 0.25, MIST)
		h2.height = 40.0
		h2.active = 3.0
		h2.tick = 0.5
		h2.effect = "sleep"
		h2.hit_air = false


func _set_misty(v: bool) -> void:
	_misty = v
	if e.visual:
		e.visual.modulate.a = 0.45 if v else 1.0


## Meia-lua de sono sobre a Sophia; cheia, ela cochila (rolar acorda).
func _drowsy(pl: Node2D, delta: float) -> void:
	var d: float = float(pl.get_meta("boss_drowsy", 0.0))
	d = maxf(0.0, d - DROWSY_DECAY * delta * (0.0 if float(pl.get("status_slow")) > 0.0 else 1.0))
	if d >= DROWSY_FULL:
		d = 0.0
		if pl.has_method("apply_root"):
			pl.apply_root(NAP_TIME)
		ImpactBurst.spawn(e.get_parent(), pl.global_position + Vector2(0, -30), MIST)
	pl.set_meta("boss_drowsy", d)
	if _mark == null:
		_mark = DrowsyMark.new()
		e.get_parent().add_child(_mark)
		_spawned.append(_mark)
	_mark.target = pl
	_mark.k = d / DROWSY_FULL


func _on_defeated(x) -> void:
	var pl := _player()
	if pl != null:
		pl.set_meta("boss_drowsy", 0.0)
	super._on_defeated(x)


## Meia-lua azul que enche sobre a cabeça da Sophia (sonolência).
class DrowsyMark extends Node2D:
	var target: Node2D = null
	var k: float = 0.0
	func _ready() -> void:
		z_index = 40
	func _process(_d: float) -> void:
		if target == null or not is_instance_valid(target):
			return
		global_position = target.global_position + Vector2(0, -46)
		queue_redraw()
	func _draw() -> void:
		if k <= 0.02:
			return
		var c := Color(0.62, 0.68, 1.0, 0.35 + 0.6 * k)
		draw_arc(Vector2.ZERO, 7.0, PI * 0.5, PI * 0.5 + TAU * k, 20, c, 2.5, true)
		draw_arc(Vector2.ZERO, 7.0, 0, TAU, 20, Color(c, 0.2), 1.0, true)
		if k > 0.7:
			draw_string(ThemeDB.fallback_font, Vector2(8, -6), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, k))
