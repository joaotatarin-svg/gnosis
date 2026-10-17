extends RefCounted
class_name LayoutBuilder
## MONTA o plano de ScreenLayouts dentro do Level: plataformas das arenas,
## perigos das passagens e das arenas (guarda), segredos no alto (torres e
## saliências de pulo duplo), escalada sobre chão perigoso, a torre da saída
## no alto e os objetos de objetivo (totem / luz a proteger).
## Tudo nasce como filho do Level, em coordenadas de mundo, no _ready da tela.

const FLOOR := 310.0          # topo da colisão do chão (linha dos pés)
const CHEST_LIFT := 12.0      # o baú no chão fica com a origem 12 px acima do piso


## Monta tudo. Devolve {objectives: {zona: nó}, spans: [[x0, x1, y], ...]}.
static func build(level: Level, plan: Dictionary) -> Dictionary:
	var res := {"objectives": {}, "spans": []}
	if String(plan.get("kind", "")) == "chefe":
		return res
	var reserved: Array = level.reserved_spans()
	var rng := RunManager.screen_rng(level.screen, 62)
	var zones: Array = plan.get("zones", [])
	# --- arenas ---
	for i in zones.size():
		var z: Dictionary = zones[i]
		var c: float = level.zone_center(i)
		var mirror := false
		for g in z.get("guard", []):
			mirror = mirror or String(g.t) == "mirror_set"
		var k := 0
		for p in z.get("plats", []):
			var at := Vector2(c + float(p[0]), float(p[1]))
			if mirror and k % 2 == 1:
				_mirror_platform(level, at, float(p[2]), k % 4 == 3, res)
			else:
				_platform(level, at, float(p[2]), res)
			k += 1
		for g in z.get("guard", []):
			if String(g.t) == "mirror_set":
				continue
			_hazard(level, String(g.t), c + float(g.get("dx", 0.0)), g, rng)
		match String(z.get("objective", "ondas")):
			"totem":
				var tt := SummonTotem.new()
				tt.screen = level.screen
				tt.pool = _pool(level)
				level.add_child(tt)
				# do lado oposto da entrada: é preciso atravessar a luta pra chegar
				tt.global_position = Vector2(_clear_x(c + 330.0, res.spans, c), FLOOR)
				res.objectives[i] = tt
			"proteger":
				var wl := WardLight.new()
				wl.screen = level.screen
				level.add_child(wl)
				wl.global_position = Vector2(_clear_x(c - 60.0, res.spans, c), FLOOR)
				res.objectives[i] = wl
	# --- passagens ---
	var passages: Array = plan.get("passages", [])
	for i in passages.size():
		var x0: float = level.passage_start(i)
		var x1: float = level.zone_center(i) - Level.ZONE_HALF
		for it in passages[i].get("items", []):
			var t := String(it.t)
			var lx := float(it.get("x", 0.0))
			var w := _item_width(t)
			var wx := _avoid(x0 + lx, w, reserved, x0 + 20.0, x1 - 20.0)
			if is_nan(wx) and t in ["mist", "beam"]:
				# perigos de largura variável encolhem para caber entre Estela e Selos
				w *= 0.6
				wx = _avoid(x0 + lx, w, reserved, x0 + 20.0, x1 - 20.0)
				it = it.duplicate()
				it["w"] = w
			if is_nan(wx):
				continue
			match t:
				"dj_cache":
					_dj_cache(level, wx, res)
				"tower_cache":
					_tower_cache(level, wx, res)
				"vault":
					_vault(level, wx, res)
				"altar":
					var al := SanctuaryAltar.new()
					level.add_child(al)
					al.global_position = Vector2(wx, FLOOR)
				"climb":
					_climb(level, wx, String(it.get("hz", "")), String(it.get("live", "")), rng, res, reserved)
				"perch":
					_platform(level, Vector2(wx - 50.0, ScreenLayouts.Y1), 110.0, res)
					_platform(level, Vector2(wx + 40.0, ScreenLayouts.Y2), 100.0, res)
				"tide":
					var tide := DarkTide.new()
					tide.start_x = x0 - 60.0
					tide.end_x = level.zone_center(i) - Level.ZONE_TRIGGER - 40.0
					level.add_child(tide)
					tide.global_position = Vector2(x0, FLOOR)
				_:
					_hazard(level, t, wx, it, rng)
	# --- saída no alto ---
	if bool(plan.get("exit_top", false)) and not zones.is_empty():
		var cl: float = level.zone_center(zones.size() - 1)
		_platform(level, Vector2(cl + Level.ZONE_HALF + 60.0, ScreenLayouts.Y1), 110.0, res)
		_platform(level, Vector2(cl + Level.ZONE_HALF + 150.0, ScreenLayouts.Y2), 110.0, res)
		_platform(level, Vector2(cl + Level.ZONE_HALF + 95.0, ScreenLayouts.Y3), 180.0, res)
		res["exit_top"] = Vector2(cl + Level.ZONE_HALF + 150.0, ScreenLayouts.Y3 - 6.0)
	return res


# --- peças ------------------------------------------------------------------

static func _platform(level: Level, at: Vector2, w: float, res: Dictionary) -> void:
	level.add_child(level.make_platform(at, w))
	res.spans.append([at.x - w * 0.5, at.x + w * 0.5, at.y])


static func _mirror_platform(level: Level, at: Vector2, w: float, group_b: bool, res: Dictionary) -> void:
	var mp := MirrorPlatform.new()
	mp.width = w
	mp.group_b = group_b
	level.add_child(mp)
	mp.global_position = at
	res.spans.append([at.x - w * 0.5, at.x + w * 0.5, at.y])


static func _sinking_platform(level: Level, at: Vector2, w: float, res: Dictionary) -> void:
	var sp := SinkingPlatform.new()
	sp.width = w
	level.add_child(sp)
	sp.global_position = at
	res.spans.append([at.x - w * 0.5, at.x + w * 0.5, at.y])


## Baú secreto em cima de uma plataforma (y = centro da plataforma).
static func _secret_chest(level: Level, x: float, plat_y: float) -> void:
	var ch := Chest.new()
	ch.screen = level.screen
	ch.secret = true
	level.add_child(ch)
	ch.global_position = Vector2(x, plat_y - 6.0 - CHEST_LIFT)


## Saliência de PULO DUPLO: isolada, 116 px acima do chão (o pulo simples sobe
## ~77). Marca no chão embaixo (duas setas) avisa que tem algo lá em cima.
static func _dj_cache(level: Level, x: float, res: Dictionary) -> void:
	_platform(level, Vector2(x, ScreenLayouts.YDJ), 90.0, res)
	_secret_chest(level, x, ScreenLayouts.YDJ)
	var mark := SecretMark.new()
	level.add_child(mark)
	mark.global_position = Vector2(x, FLOOR)


## SALA SECRETA (nó "secret" do mapa): saliência de PULO DUPLO em `x` e, logo
## à direita, a câmara em Y3 (176 px acima do chão: sem o pulo duplo não se
## chega) com dois baús secretos. Embaixo, a porta selada (só desenho).
static func _vault(level: Level, x: float, res: Dictionary) -> void:
	_platform(level, Vector2(x, ScreenLayouts.YDJ), 90.0, res)
	var mark := SecretMark.new()
	level.add_child(mark)
	mark.global_position = Vector2(x, FLOOR)
	var rx := x + 200.0
	_platform(level, Vector2(rx, ScreenLayouts.Y3), 260.0, res)
	_secret_chest(level, rx - 60.0, ScreenLayouts.Y3)
	_secret_chest(level, rx + 60.0, ScreenLayouts.Y3)
	var v := SecretVault.new()
	v.room_w = 280.0
	v.room_y = ScreenLayouts.Y3 - 6.0 - FLOOR
	level.add_child(v)
	v.global_position = Vector2(rx, FLOOR)


## Torre de um pulo por degrau, com baú secreto no topo (Y3).
static func _tower_cache(level: Level, x: float, res: Dictionary) -> void:
	_platform(level, Vector2(x, ScreenLayouts.Y1), 120.0, res)
	_platform(level, Vector2(x + 100.0, ScreenLayouts.Y2), 110.0, res)
	_platform(level, Vector2(x, ScreenLayouts.Y3), 110.0, res)
	_secret_chest(level, x, ScreenLayouts.Y3)


## ESCALADA sobre chão perigoso: Y1 → Y2 → ponte em Y3 → Y2 → Y1. Por cima é
## seguro (e tem baú); por baixo, dois perigos de chão do Éon (o bot passa
## por baixo e paga). Plataformas vivas do Éon na ponte (afundam/alternam).
static func _climb(level: Level, x: float, floor_hz: String, live: String, rng: RandomNumberGenerator, res: Dictionary, reserved: Array = []) -> void:
	_platform(level, Vector2(x, ScreenLayouts.Y1), 120.0, res)
	_platform(level, Vector2(x + 110.0, ScreenLayouts.Y2), 110.0, res)
	var b1 := Vector2(x + 240.0, ScreenLayouts.Y3)
	var b2 := Vector2(x + 400.0, ScreenLayouts.Y3)
	match live:
		"sinking":
			_sinking_platform(level, b1, 160.0, res)
			_sinking_platform(level, b2, 160.0, res)
		"mirror":
			_mirror_platform(level, b1, 160.0, false, res)
			_mirror_platform(level, b2, 160.0, true, res)
		_:
			_platform(level, b1, 160.0, res)
			_platform(level, b2, 160.0, res)
	_platform(level, Vector2(x + 530.0, ScreenLayouts.Y2), 110.0, res)
	_platform(level, Vector2(x + 640.0, ScreenLayouts.Y1), 120.0, res)
	# baú no meio da ponte (só na versão firme: na viva, o prêmio é atravessar)
	if live == "":
		_secret_chest(level, x + 320.0, ScreenLayouts.Y3)
	if floor_hz != "":
		# perigos no chão embaixo da ponte (fora de Estela/baú/Selos)
		var fw := minf(_item_width(floor_hz), 130.0)
		for hx in [x + 230.0, x + 420.0]:
			var ax := _avoid(hx, fw, reserved, x + 120.0, x + 560.0)
			if not is_nan(ax):
				_hazard(level, floor_hz, ax, {"w": fw}, rng)


## Um perigo do Éon no chão em `x`.
static func _hazard(level: Level, t: String, x: float, it: Dictionary, rng: RandomNumberGenerator) -> void:
	var h: LevelHazard = null
	match t:
		"mist":
			var mp := MistPatch.new()
			mp.width = float(it.get("w", 220.0))
			h = mp
		"maw":
			h = Maw.new()
		"pendulum", "bell":
			var pd := Pendulum.new()
			pd.style = "bell" if t == "bell" else "chain"
			if level.zone_active or it.has("dx"):
				pd.length = 190.0            # guarda de arena: arco curto, centro livre
				pd.period = 3.4
			h = pd
		"beam":
			var mb := MirrorBeam.new()
			mb.width = float(it.get("w", 180.0))
			h = mb
		"spores":
			h = SporePod.new()
		"guillotine":
			h = Guillotine.new()
		"spears", "shackles":
			var sp := SpearTrap.new()
			sp.style = t
			h = sp
		"shards":
			var sf := ShardFall.new()
			sf.width = float(it.get("w", 520.0))
			h = sf
		"silence":
			var sl := SilenceField.new()
			sl.width = float(it.get("w", 160.0))
			h = sl
	if h == null:
		return
	h.phase = rng.randf_range(0.0, 4.0)
	if it.has("dx"):
		h.dmg_mult = 0.7            # guarda de ARENA: a luta já cobra; o cenário só tempera
	level.add_child(h)
	h.global_position = Vector2(x, FLOOR)


## Largura ocupada por um item de passagem (para não cair em cima de Estela/baú).
static func _item_width(t: String) -> float:
	match t:
		"climb": return 0.0           # a escalada é estrutura grande: não se move
		"tide": return 0.0
		"tower_cache": return 220.0
		"dj_cache": return 100.0
		"vault": return 0.0
		"altar": return 80.0
		"perch": return 200.0
		"mist": return 220.0
		"pendulum", "bell": return 120.0
		"maw": return 80.0
		"spears", "shackles": return 120.0
		"beam": return 180.0
	return 90.0


## Empurra o item para fora dos trechos reservados (Estela, baú, Adormecido,
## Selos, encontros). Tenta à direita, depois à esquerda; NAN = não cabe.
static func _avoid(x: float, w: float, reserved: Array, lo: float, hi: float) -> float:
	if w <= 0.0:
		return x
	var cand := [x]
	for r in reserved:
		cand.append(float(r[1]) + w * 0.5 + 10.0)
		cand.append(float(r[0]) - w * 0.5 - 10.0)
	var best := NAN
	var best_d := INF
	for cx in cand:
		var c: float = cx
		if c - w * 0.5 < lo or c + w * 0.5 > hi:
			continue
		var ok := true
		for r in reserved:
			if c + w * 0.5 > float(r[0]) and c - w * 0.5 < float(r[1]):
				ok = false
				break
		if ok and absf(c - x) < best_d:
			best_d = absf(c - x)
			best = c
	return best


## X livre de plataformas BAIXAS (um nó no chão não fica embaixo de um degrau).
static func _clear_x(x: float, spans: Array, c: float) -> float:
	for s in spans:
		if float(s[2]) > 230.0 and x > float(s[0]) - 24.0 and x < float(s[1]) + 24.0:
			var left: float = float(s[0]) - 30.0
			var right: float = float(s[1]) + 30.0
			x = left if absf(left - c) < absf(right - c) else right
	return x


## Tipos de bicho da tela (o totem invoca destes).
static func _pool(level: Level) -> Array:
	var ids: Array = Bestiary.types_for_screen(level.screen)
	if ids.is_empty():
		ids = ["servo"]
	return ids
