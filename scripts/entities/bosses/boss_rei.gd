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
## A MENTIRA DO REI (29/10, Narrativa §3.2 + Guardião): o card diz "Um rei jamais
## se curva." — e ele se curva (o ajoelhar acima: olho desce + "dong"). O 1º golpe
## no OLHO enquanto ele está ajoelhado é o DESMENTIDO: a máscara racha, sinal
## `lie_exposed("rei")`, e por 8 s ele fica PARADO, ajoelhado e SEM ATACAR (não
## escolhe golpe, sem telégrafo, sem "sai de cima", sem troca de fase no meio; as
## janelas ×1,3 olho / ×1,35 corpo valem). 1 vez por luta. Errar não custa nada;
## quem ignora luta a MESMA luta e a mentira cai na queda (`lie_was_exposed` false).
## Só no Rei da tela 1 (o Rei-Mentira da final herda este script e NÃO tem isso).

signal king_kneel_start
signal king_kneel_end

const LIE_TIME := 8.0                 # s parado, sem guarda, depois do Desmentido
const HINT2_AFTER := 45.0             # degrau 2 da dica: ≥ 45 s de luta…
const HINT2_KNEELS := 2               # …ou 2 ajoelhares sem o Desmentido

var lie_was_exposed: bool = false
var _lie_t: float = 0.0
var _kneel_count: int = 0
var _kneels_without: int = 0
var _hint2_sent: bool = false
var _hint1_sent: bool = false

const LIGHT := Color(1.0, 0.85, 0.5)
const ORB_LOW := 132.0          # px que o olho desce (fica na altura do peito)
const EYE_MULT := 1.3

var _rig: Node2D = null
var _push: Node2D = null            # desce o olho quando ele entraria na área do HUD
## Área do medalhão/vida do HUD na tela base 640×360 (QA7 #24): nada de chefe ali.
const HUD_ZONE := Vector2(230.0, 70.0)
var _eye_box: Hurtbox = null
var _low: bool = false
var _summons_cd: float = 0.0
## Caixa de dano do MANTO desenhado (playtest 28/10: "a Sophia atravessa o manto").
const BODY_TABLE := preload("res://scripts/entities/bosses/rei_body_data.gd")
var _body: BossBodyBox = null


func _on_setup() -> void:
	dmg_scale = 0.55
	keep_dist = Vector2(100.0, 210.0)
	gap_by_phase = [1.0, 0.9, 0.8]
	escape_hits = 5
	wall_margin = 120.0
	_setup_eye()
	if e.hurtbox != null:
		_body = BossBodyBox.attach(e, BODY_TABLE)


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
		2: [leque, gesto, raio, mao, aneis, combo, raio_b],
		3: [leque, gesto, mao2, aneis, larvas, combo, raio_b, teleporte, gesto_b],
	}


# --- o olho (ponto fraco) ----------------------------------------------------

func _setup_eye() -> void:
	if e._orb == null:
		return
	_rig = Node2D.new()
	_rig.name = "OrbRig"
	e.add_child(_rig)
	_push = Node2D.new()
	_push.name = "HudPush"
	_rig.add_child(_push)
	e._orb.reparent(_push, false)
	_eye_box = Hurtbox.new()
	_eye_box.team = "enemy"
	_eye_box.collision_layer = e.hurtbox.collision_layer
	_eye_box.collision_mask = e.hurtbox.collision_mask
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 20.0
	cs.shape = circ
	_eye_box.add_child(cs)
	_push.add_child(_eye_box)
	_eye_box.owner = e
	_eye_box.monitorable = false
	_eye_box.hit_received.connect(_on_eye_hit)


func _process(d: float) -> void:
	if _eye_box != null and e._orb != null and is_instance_valid(e._orb):
		_eye_box.position = e._orb.position
	# QA7 #24: o olho não passa por trás do medalhão do HUD (canto de cima à esquerda)
	if _push != null and e._orb != null and is_instance_valid(e._orb):
		var ct := get_viewport().get_canvas_transform()
		var base_pos: Vector2 = e._orb.global_position - Vector2(0, _push.position.y)
		var sp: Vector2 = ct * base_pos
		var need := 0.0
		if sp.x < HUD_ZONE.x + 20.0 and sp.y < HUD_ZONE.y + 16.0:
			need = (HUD_ZONE.y + 16.0 - sp.y) / maxf(0.01, ct.get_scale().y)
		_push.position.y = move_toward(_push.position.y, need, 220.0 * d)
	# 8 s da mentira exposta: a pintura da MÁSCARA RACHADA (o Enemy pede "idle"/"recover"
	# no passo de física; aqui, depois dele, o quadro do desmentido manda)
	if e.visual != null and e.visual.has_method("has_boss_frames") and e.visual.has_boss_frames() and _lie_on():
		if _lie_t > 0.0:
			e.visual.set_anim("mask_crack")
		elif _low and _has_state("kneel") and e.estate != Enemy.EState.DEAD:
			# AJOELHADO desenhado: entra sozinho quando a Arte publicar o estado "kneel"
			# (pedido em docs/pedidos/chefes6.md); até lá, a curva é o olho descendo + o "dong"
			e.visual.set_anim("kneel")


func _set_low(v: bool) -> void:
	if _rig == null or v == _low:
		return
	_low = v
	var t := _rig.create_tween()
	t.tween_property(_rig, "position:y", ORB_LOW if v else 0.0, 0.35 if v else 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if v else Tween.EASE_IN_OUT)
	_eye_box.set_deferred("monitorable", v)
	if v:
		ImpactBurst.spawn(e.get_parent(), e._orb.global_position + Vector2(0, ORB_LOW), LIGHT)
	if not _lie_on():
		return
	if v:
		# a CURVA (pista 2): o "dong" de joelho na pedra junto do olho descendo (forma + som)
		_kneel_count += 1
		sfx("king_step", e.global_position)
		king_kneel_start.emit()
		# degrau 2 da dica: só DURANTE um ajoelhar (janela segura, sem telégrafo), 1 vez
		if not lie_was_exposed and not _hint2_sent and _hints_on() and (_t >= HINT2_AFTER or _kneels_without >= HINT2_KNEELS):
			_hint2_sent = true
			lie_hint_step.emit(2)
	else:
		if not lie_was_exposed:
			_kneels_without += 1
		king_kneel_end.emit()


func _has_state(st: String) -> bool:
	var db = e.visual.get("_boss_db")
	return db is Dictionary and db.has("meta") and (db.meta.get("states", {}) as Dictionary).has(st)


## Mentira só no Rei da tela 1 (o Rei-Mentira da final herda o script).
func _lie_on() -> bool:
	return e != null and e.type_id == "rei"


## Degrau 2 desligável (Opções → "Dicas"): respeita a opção se ela existir (UI).
func _hints_on() -> bool:
	var v = GameManager.get("lie_hints")
	return v == null or bool(v)


func _on_eye_hit(dmg: int, src: Vector2, kb: float, unb: bool, attacker: Node) -> void:
	if not _low:
		return
	# o DESMENTIDO vem antes do dano: o golpe que prova a mentira já conta na janela
	# (e não troca de fase no meio dos 8 s)
	if _lie_on() and not lie_was_exposed and _dying < 0 and _roar_t <= 0.0:
		_expose_lie()
	e._on_hit_received(int(round(float(dmg) * EYE_MULT)), src, kb * 0.3, unb, attacker)
	VfxLibrary.hit(e.get_parent(), e._orb.global_position, true, LIGHT)


## A máscara racha: 8 s parado, ajoelhado e sem atacar (1 vez por luta).
func _expose_lie() -> void:
	lie_was_exposed = true
	_lie_t = LIE_TIME
	_chain.clear()
	e.set_meta("lie_exposed", true)
	e._flash(Color(2.6, 2.4, 2.0, 1), Enemy.VIB_HEAVY)
	ImpactBurst.spawn(e.get_parent(), e._orb.global_position, Color(1, 1, 1))
	sfx("mask_light", e.global_position)
	# aviso mínimo no HUD (a UI faz a barrinha de 8 s — pedido em docs/pedidos/chefes6.md)
	get_tree().call_group("hud", "toast", "Mentira exposta · o Rei fica 8 s sem guarda")
	lie_exposed.emit("rei")


## Os 8 s sem guarda: ele não escolhe golpe, não foge, não anda.
func chase(delta: float) -> bool:
	if _lie_on() and not _hint1_sent:
		# a luta começou: degrau 1 (card + fala da Voz) e 3 (Bestiário) já valem
		_hint1_sent = true
		lie_hint_step.emit(1)
		lie_hint_step.emit(3)
	if _lie_t > 0.0:
		e.velocity.x = 0.0
		return true
	return super.chase(delta)


## Sem fase nova no meio dos 8 s (o rugido o deixaria intocável): troca quando acabar.
func check_phase() -> bool:
	if _lie_t > 0.0:
		return false
	return super.check_phase()


## Nos 8 s o corpo inteiro vale a janela de EXPOSTO (×1,35), como no ajoelhar.
func filter_damage(dmg: int, attacker: Node) -> int:
	if _lie_t > 0.0 and _roar_t <= 0.0 and _dying < 0 and e.can_process():
		return maxi(1, int(round(float(dmg) * EXPOSED_MULT)))
	return super.filter_damage(dmg, attacker)


func _signature(delta: float) -> void:
	_summons_cd = maxf(0.0, _summons_cd - delta)
	if _lie_t > 0.0:
		# PARADO de verdade: os golpes não o empurram pela arena (antes ia parar na borda da câmera)
		e.velocity.x = 0.0
		_lie_t = maxf(0.0, _lie_t - delta)
		if _lie_t <= 0.0:
			# levanta: um respiro antes do próximo golpe (a luta segue na fase em que estava)
			_gap_t = maxf(_gap_t, 0.9)
			e._flash(Color(1.8, 1.7, 1.5, 1), Enemy.VIB_LIGHT)
	var exposed: bool = (e.estate == Enemy.EState.RECOVER and bool(mv.get("expose", false))) \
		or (e.estate == Enemy.EState.STAGGER and _roar_t <= 0.0 and _dying < 0) \
		or _lie_t > 0.0
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
			h.look = "beam"          # orbe de luz rente ao chão (era uma faixa chapada: "quadrado")
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
				# o manto é largo: nunca cola na parede (não fica cortado na borda)
				var b2 := arena_bounds()
				e._blink_to(clampf(pl.global_position.x - float(pl.get("facing")) * 50.0, b2.x + 150.0, b2.y - 150.0))


func _on_defeated(x) -> void:
	_set_low(false)
	for m in e._minions:
		if is_instance_valid(m) and m.estate != Enemy.EState.DEAD:
			m._on_hit_received(m.health.max_health + 9999, e.global_position, 10.0, false, null)
	super._on_defeated(x)
