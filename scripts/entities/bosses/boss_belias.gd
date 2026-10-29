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
## PÚSTULAS (29/10, chefes6 — resposta a quem só martela): golpe dado nele FORA
## das janelas (no neutro ou no meio do golpe dele) faz brotar uma bolha verde
## nas costas (dá pra CONTAR: 1, 2, 3, 4 — a 4ª pulsa rápido). Cheio, ele se
## encolhe (losango vermelho + contorno no chão) e ESTOURA: nuvem de peste em
## volta de si que fere e envenena. Quem bate nas janelas não enche nada; quem
## sai do contorno volta a tempo de pegar ele MURCHO (exposto, 1,3 s).
## Bolhas CHEIAS: encostar nelas estoura na hora (sem janela depois, e a peste fica
## em volta dele 1,4 s). RECUO (quem cola e martela 3 golpes em 2,5 s): ele salta para
## trás rente ao chão, deixa uma poça onde estava e emenda o Bote (vermelho).
## JORRO (fases 2–3): cospe bile à frente — 3 respingos no chão, um depois do outro
## (vermelhos) — saia da frente.

const ROT := Color(0.7, 1.0, 0.5)
const POOL_TICK := 0.7
## Bolhas até o Estouro.
const PUS_MAX := 4

var _pus: int = 0
var _blisters: PusBlisters = null

var _pools: Array = []
var _pool_t: float = 0.0
var _vent_t: float = 4.0
var _vents: Array = []
var _was_stag: bool = false


func _on_setup() -> void:
	dmg_scale = 0.55          # 28/10: curva da Progressão (~330 de vida na tela 55)
	keep_dist = Vector2(60.0, 160.0)
	wall_margin = 120.0       # fera larga: não encosta na borda da câmera
	gap_by_phase = [0.9, 0.8, 0.7]
	escape_hits = 3
	escape_id = "recuo"       # 29/10: acuado, ele SALTA PARA TRÁS e dá o Bote (era se enterrar)
	# guarda alta (QA7 3.1: caía em ~40 s com quem só martela) — ver BossBrain.guard_up
	guard_up(0.55, 0.35, 1.5)   # 29/10: igual à Coroa (fim do jogo coerente: neutro/armado pagam pouco)


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
	# ESTOURO: só nasce das bolhas cheias (peso 0); recover = MURCHO, exposto
	var estouro := {"id": "estouro", "kind": "cast", "anim": "slam", "wind": 0.65, "strike": 0.2, "recover": 1.3,
		"unblock": true, "expose": true, "rmin": 0.0, "rmax": 9999.0, "w": 0.0, "cd": 0.0}
	# tocou nas bolhas cheias: estoura já (o aviso foram as 4 bolhas) — sem MURCHO depois
	var estouro_toque := estouro.duplicate()
	estouro_toque.id = "estouro_toque"
	estouro_toque.wind = 0.45
	estouro_toque.recover = 0.5
	estouro_toque.expose = false
	estouro_toque.guard_rec = true
	estouro_toque.cloud = true
	# RECUO (resposta a quem cola): salto para trás, rente ao chão, deixando uma poça onde
	# estava — e emenda o Bote (vermelho, avisado). Utilitário: sem telegrafo próprio.
	var recuo := {"id": "recuo", "tell": false, "kind": "cast", "anim": "charge", "wind": 0.15, "strike": 0.35,
		"recover": 0.1, "guard_rec": true, "rmin": 0.0, "rmax": 9999.0, "w": 0.0, "cd": 0.0, "chain": ["bote_b"]}
	var bote_b := bote.duplicate()
	bote_b.id = "bote_b"
	bote_b.rmin = 0.0
	bote_b.w = 0.0
	bote_b.cd = 0.0
	var jorro := {"id": "jorro", "kind": "cast", "anim": "ranged", "wind": 0.7, "strike": 0.7, "recover": 0.9,
		"unblock": true, "rmin": 0.0, "rmax": 170.0, "w": 1.1, "cd": 5.0}
	return {
		1: [bote, mordida, esporos, enterrar, estouro, estouro_toque, recuo, bote_b],
		2: [bote, mordida2, mordida_b, esporos5, nuvem, enterrar, jorro, estouro, estouro_toque, recuo, bote_b],
		3: [bote, mordida2, mordida_b, esporos5, nuvem, enterrar3, jorro, estouro, estouro_toque, recuo, bote_b],
	}


func _pick(dist: float, high: float) -> Dictionary:
	# bolhas cheias: a próxima escolha é o Estouro (perto ou longe — ele estoura onde está)
	if _pus >= PUS_MAX:
		var s := _find("estouro")
		if not s.is_empty():
			return s
	return super._pick(dist, high)


## Golpe FORA das janelas (neutro / meio do golpe dele) faz brotar uma bolha; as
## janelas (recuperação, atordoado, murcho) não enchem nada. Cheio, tocar nele
## ESTOURA na hora (sem janela depois).
func _filter(dmg: int, _attacker: Node) -> int:
	var cur: String = String(mv.get("id", ""))
	if cur.begins_with("estouro") and e.estate in [Enemy.EState.WINDUP, Enemy.EState.STRIKE]:
		# inchado: o golpe bate nas bolhas e escorrega (respingo verde, sem dano)
		ImpactBurst.spawn(e.get_parent(), e.global_position + Vector2(0, -16.0 * e._art_scale), ROT)
		return 0
	if e.estate in [Enemy.EState.STAGGER, Enemy.EState.RECOVER, Enemy.EState.HURT]:
		return dmg
	if _pus >= PUS_MAX:
		_burst_on_touch.call_deferred()      # fora do sinal de acerto
		return dmg
	_pus += 1
	_show_blisters()
	return dmg


## Bolhas cheias = não encoste (a sonda e o jogador que lê respeitam).
func no_touch() -> bool:
	return _pus >= PUS_MAX or super.no_touch()


func _burst_on_touch() -> void:
	if _dead or not is_instance_valid(e) or e.estate == Enemy.EState.DEAD or _airborne:
		return
	if String(mv.get("id", "")).begins_with("estouro") and e.estate in [Enemy.EState.WINDUP, Enemy.EState.STRIKE]:
		return
	var s := _find("estouro_toque")
	if s.is_empty():
		return
	_chain.clear()
	_start(s)


func _show_blisters() -> void:
	if _blisters == null or not is_instance_valid(_blisters):
		_blisters = PusBlisters.new()
		e.add_child(_blisters)
		_blisters.z_index = 5
	_blisters.position = Vector2(0, -16.0 * e._art_scale)
	_blisters.size = 30.0 * e._art_scale
	_blisters.count = _pus
	_blisters.full = _pus >= PUS_MAX
	_blisters.dir = float(e.atk_dir)
	_blisters.queue_redraw()


func _on_windup(m: Dictionary) -> void:
	var pl := _player()
	if pl == null:
		return
	match m.id:
		"estouro", "estouro_toque":
			# encolhe e incha: o contorno do estouro em volta dele (sair dele = salvo)
			var s := hazard(e.global_position.x, "circle", 100.0, m.wind, 0.9, ROT)
			s.active = 0.15
			s.knockback = 320.0
			s.effect = "poison"
			if _blisters != null and is_instance_valid(_blisters):
				_blisters.swell = true
		"jorro":
			# bile à frente: 3 respingos no chão, do focinho até ~170 px, um depois do
			# outro (forma de cuspe, não um bloco — lição do Raio do Rei)
			for i in 3:
				var j := hazard(e.global_position.x + e.atk_dir * (48.0 + 58.0 * float(i)), "circle", 32.0, float(m.wind) + 0.1 * float(i), 0.45, ROT)
				j.active = float(m.strike) - 0.1 * float(i)
				j.tick = 0.35
				j.effect = "poison"
				j.knockback = 120.0
				j.silent = i > 0          # um aviso sonoro por golpe (R4)
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
	if String(m.id).begins_with("bote"):
		_pool_t = 0.0
	elif m.id == "recuo":
		# a poça fica onde ele estava (onde a Sophia colou)
		_pool_at(e.global_position.x, 28.0, 3.0)
	elif String(m.id).begins_with("estouro"):
		# as bolhas estouram (o dano vem do contorno, que fere agora)
		_pus = 0
		for k in 3:
			ImpactBurst.spawn(e.get_parent(), e.global_position + Vector2((float(k) - 1.0) * 26.0, -14.0 * e._art_scale), ROT)
		AoeNova.spawn(e.get_parent(), e.global_position + Vector2(0, 14), 0, 100.0, ROT)
		if bool(m.get("cloud", false)):
			# estourou NA CARA de quem tocou: a peste fica em volta dele um pouco
			var c := hazard(e.global_position.x, "circle", 64.0, 0.45, 0.3, ROT)
			c.active = 1.4
			c.tick = 0.45
			c.effect = "poison"
			c.silent = true
		if _blisters != null and is_instance_valid(_blisters):
			_blisters.swell = false
			_blisters.count = 0
			_blisters.full = false
			_blisters.queue_redraw()


func _strike_tick(m: Dictionary, delta: float) -> void:
	# salto para trás: rente ao chão, para na parede
	if m.id == "recuo":
		var b := arena_bounds()
		var vx: float = -float(e.atk_dir) * 460.0
		# fera larga: para antes da borda da câmera (não fica cortada)
		if (vx < 0.0 and e.global_position.x < b.x + 140.0) or (vx > 0.0 and e.global_position.x > b.y - 140.0):
			vx = 0.0
		e.velocity.x = vx
	# o Bote deixa rastro de veneno
	if String(m.id).begins_with("bote"):
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
	# estouro interrompido (aparo, postura, fase): as bolhas desincham, mas continuam lá
	if _blisters != null and is_instance_valid(_blisters):
		if _blisters.swell and not (String(mv.get("id", "")).begins_with("estouro") and e.estate == Enemy.EState.WINDUP):
			_blisters.swell = false
		_blisters.dir = float(e.atk_dir)
	if phase < 2 or _vents.is_empty():
		return
	_vent_t -= delta
	if _vent_t <= 0.0:
		_vent_t = 6.0 if phase == 2 else 4.5
		for x in _vents:
			var h := hazard(float(x), "column", 30.0, 1.2, 0.7, ROT)
			h.effect = "poison"


func hold_death() -> bool:
	if _blisters != null and is_instance_valid(_blisters):
		_blisters.visible = false
	return super.hold_death()


## Desenho das PÚSTULAS: bolhas verdes nas costas (lado oposto à Sophia), uma
## por golpe fora da janela — CONTÁVEIS. Cheias (4), pulsam rápido; no preparo
## do Estouro incham. Forma própria (bolha), além da cor.
class PusBlisters extends Node2D:
	var size := 30.0
	var count := 0
	var full := false
	var swell := false
	var dir := 1.0
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		if count > 0:
			queue_redraw()
	func _draw() -> void:
		if count <= 0:
			return
		var spd: float = 14.0 if (full or swell) else 5.0
		for k in count:
			# arco nas costas: da anca ao ombro, do lado oposto à Sophia
			# fileira ao longo do dorso: da cernelha à anca, do lado oposto à Sophia
			var f: float = float(k) / 3.0
			var p := Vector2(-dir * size * lerpf(-0.1, 0.75, f), -size * (0.32 + 0.08 * sin(f * PI)))
			var r: float = 4.0 + 1.2 * float(k)
			r *= 1.0 + 0.12 * sin(_t * spd + float(k))
			if swell:
				r *= 1.45
			draw_circle(p, r + 1.5, Color(0.2, 0.35, 0.1, 0.85))
			draw_circle(p, r, Color(0.7, 1.0, 0.5, 0.95))
			draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.3, Color(1, 1, 0.9, 0.9))