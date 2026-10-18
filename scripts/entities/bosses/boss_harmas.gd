extends BossBrain
## HARMAS, Arconte da FOME (tela 19). O filho que nunca provou nada que fosse
## dele. Gigante lento, golpes pesados, uma BOCA no torso.
## ASSINATURA — SUCÇÃO e CHÃO QUE DEVORA: na Sucção (preparação longa, boca
## acesa) ele PUXA a Sophia; a boca engole os golpes de frente (bater na boca
## não fere — saia, ou passe para as costas); no fim, a MORDIDA (vermelha).
## Fase 2: o chão abre bocas onde ela pisa (aviso de 1,2 s; presa um instante).
## Fase 3: as bordas da arena viram goela (o chão encolhe) e ele ainda SOPRA
## para empurrá-la até lá.
## FOME DE VERDADE: se a Mordida pega, ele COME — recupera um pouco de vida
## (clarão verde). Não o alimente.
## Janelas: depois da Mordida ele MASTIGA (1,6 s parado); o Punho (amarelo)
## aparado atordoa; a investida termina com ele cambaleando.

const MAW := Color(1.0, 0.45, 0.25)

var _maw_t: float = 6.0
var _pl_hp: int = 0
const FEED_HEAL := 0.05     # fração da vida que ele recupera ao morder
var _edges: Array = []


func _on_setup() -> void:
	dmg_scale = 0.55
	keep_dist = Vector2(30.0, 80.0)
	gap_by_phase = [0.85, 0.75, 0.65]
	escape_hits = 3
	escape_id = "salto"
	var pl := _player()
	if pl != null and pl.get("health") != null:
		pl.health.health_changed.connect(_on_player_hp)
	_pl_hp = pl.health.current_health if pl != null and pl.get("health") != null else 0


func _build_moves() -> Dictionary:
	var punhos := {"id": "punhos", "kind": "slam", "anim": "slam", "wind": 0.85, "strike": 0.22, "recover": 0.9,
		"off": 26.0, "sx": 3.0, "sy": 1.3, "nova": 110.0, "dmg": 1.0, "rmax": 120.0, "w": 2.0, "cd": 1.0}
	var succao := {"id": "succao", "kind": "melee", "anim": "slam", "wind": 1.5, "strike": 0.25, "recover": 1.6,
		"unblock": true, "off": 30.0, "sx": 2.4, "sy": 1.6, "dmg": 1.2, "kb": 260.0, "pull": 125.0,
		"rmin": 60.0, "rmax": 300.0, "w": 1.3, "cd": 5.0, "aa": true}
	var investida := {"id": "investida", "kind": "charge", "anim": "charge", "wind": 0.75, "strike": 0.55,
		"recover": 1.0, "unblock": true, "speed": 360.0, "dmg": 1.1, "rmin": 150.0, "rmax": 999.0, "w": 1.0, "cd": 4.0}
	# fase 2
	var succao2 := succao.duplicate()
	succao2.id = "succao2"
	succao2.pull = 165.0
	succao2.wind = 1.3
	var punhos2 := punhos.duplicate()
	punhos2.id = "punhos2"
	punhos2.waves = 2
	punhos2.chain = ["punhos2b"]
	punhos2.recover = 0.35
	var punhos2b := punhos.duplicate()
	punhos2b.id = "punhos2b"
	punhos2b.wind = 0.6
	punhos2b.waves = 2
	punhos2b.recover = 1.1
	punhos2b.w = 0.0
	punhos2b.rmax = 9999.0
	var boca := {"id": "boca", "kind": "cast", "anim": "slam", "wind": 0.8, "strike": 0.25, "recover": 0.8,
		"unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.2, "cd": 6.0, "aa": true}
	# fase 3
	var sopro := {"id": "sopro", "kind": "cast", "anim": "ranged", "wind": 0.9, "strike": 1.3, "recover": 0.7,
		"unblock": true, "rmin": 0.0, "rmax": 9999.0, "w": 1.0, "cd": 8.0, "aa": true}
	var banquete := punhos.duplicate()
	banquete.id = "banquete"
	banquete.chain = ["banquete_b", "banquete_c"]
	banquete.recover = 0.3
	banquete.w = 1.2
	banquete.cd = 6.0
	var banquete_b := punhos2b.duplicate()
	banquete_b.id = "banquete_b"
	banquete_b.recover = 0.3
	var banquete_c := succao.duplicate()
	banquete_c.id = "banquete_c"
	banquete_c.wind = 0.9
	banquete_c.pull = 200.0
	banquete_c.w = 0.0
	banquete_c.rmin = 0.0
	banquete_c.rmax = 9999.0
	banquete_c.cd = 0.0
	# SALTO FAMINTO: some para o alto, a sombra persegue, cai em cima. Também
	# é a resposta a quem cola nele (escape).
	var salto := {"id": "salto", "kind": "leap", "anim": "slam", "wind": 0.7, "strike": 1.5, "recover": 1.2,
		"unblock": true, "dmg": 0.9, "land_r": 64.0, "waves": 0, "rmin": 0.0, "rmax": 9999.0, "w": 1.0, "cd": 5.5, "aa": true}
	var salto2 := salto.duplicate()
	salto2.id = "salto2"
	salto2.waves = 2
	salto2.strike = 1.3
	return {
		1: [punhos, succao, investida, salto],
		2: [punhos, succao2, punhos2, punhos2b, boca, investida, salto2],
		3: [succao2, punhos2, punhos2b, boca, sopro, banquete, banquete_b, banquete_c, investida, salto2],
	}


## A boca no torso engole golpe DE FRENTE durante a sucção.
func _filter(dmg: int, attacker: Node) -> int:
	if e.estate == Enemy.EState.WINDUP and String(mv.get("id", "")).begins_with("succao") or String(mv.get("id", "")) == "banquete_c" and e.estate == Enemy.EState.WINDUP:
		if attacker != null and is_instance_valid(attacker) and attacker is Node2D:
			var front: bool = signf((attacker as Node2D).global_position.x - e.global_position.x) == float(e.atk_dir)
			if front:
				ImpactBurst.spawn(e.get_parent(), e.global_position + Vector2(18.0 * e.atk_dir, -16.0 * e._art_scale), MAW)
				return 0
	return dmg


func _on_windup(m: Dictionary) -> void:
	if m.id == "boca":
		var pl := _player()
		if pl == null:
			return
		var b := arena_bounds()
		for dx in [0.0, -110.0, 110.0]:
			var x: float = clampf(pl.global_position.x + dx, b.x + 40.0, b.y - 40.0)
			_maw(x, 1.1 + absf(dx) / 400.0, dx == 0.0)


func _on_strike(m: Dictionary) -> void:
	if m.id == "investida":
		Juice.shake(0.3)


func _maw(x: float, delay: float, follow_pl: bool) -> void:
	var h := hazard(x, "circle", 40.0, delay, 0.8, MAW)
	h.active = 0.35
	h.effect = "root"
	h.effect_time = 0.6
	h.knockback = 60.0
	if follow_pl:
		h.follow = _player()
		h.lock_at = 0.45


func _on_phase(n: int) -> void:
	_maw_t = 3.0
	if n == 3:
		# a goela nas bordas: o chão encolhe (aviso longo, depois fica)
		var b := arena_bounds()
		for side in [-1, 1]:
			var x: float = b.x + 55.0 if side < 0 else b.y - 55.0
			var h := hazard(x, "band", 60.0, 2.0, 0.3, MAW)
			h.height = 40.0
			h.active = 9999.0
			h.tick = 0.6
			h.hit_air = false
			h.knockback = 220.0
			_edges.append(h)


func _signature(delta: float) -> void:
	var pl := _player()
	if pl == null:
		return
	var id := String(mv.get("id", ""))
	# SUCÇÃO: puxa durante a preparação (rolar escapa; andar contra quase empata)
	if e.estate == Enemy.EState.WINDUP and mv.has("pull"):
		if pl.get("state") != Player.State.DODGE:
			var dx := e.global_position.x - pl.global_position.x
			if absf(dx) > 34.0:
				pl.global_position.x += signf(dx) * float(mv.pull) * delta
	# SOPRO: empurra para as bordas (fase 3)
	if id == "sopro" and e.estate == Enemy.EState.STRIKE:
		if pl.get("state") != Player.State.DODGE:
			pl.global_position.x += signf(pl.global_position.x - e.global_position.x) * 150.0 * delta
	# fase 2+: o chão abre uma boca sob ela de tempos em tempos
	if phase >= 2:
		_maw_t -= delta
		if _maw_t <= 0.0:
			_maw_t = 7.5 if phase == 2 else 6.0
			if pl.get("is_on_floor") != null and (pl as CharacterBody2D).is_on_floor():
				_maw(pl.global_position.x, 1.25, true)


## A Mordida pegou: ele come (cura um pouco).
func _on_player_hp(cur: int, _mx: int) -> void:
	var bit: bool = cur < _pl_hp and e.estate == Enemy.EState.STRIKE and (String(mv.get("id", "")).begins_with("succao") or String(mv.get("id", "")) == "banquete_c")
	_pl_hp = cur
	if bit and not _dead:
		e.health.heal(int(e.health.max_health * FEED_HEAL))
		e._flash(Color(1.2, 2.4, 1.2, 1))
