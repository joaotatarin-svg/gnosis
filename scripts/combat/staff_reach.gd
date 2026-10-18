extends RefCounted
class_name StaffReach
## Combate 6 (playtest 2 do João: "o cajado atravessa"): a caixa de acerto da
## Sophia segue o CAJADO DESENHADO no quadro que está na tela. O atlas
## (`assets/painted/derived/sophia_frames.json`, lido pelo CharacterArt) mede por
## quadro a ponta do cajado (`tip`), a frente e o centro do corpo, o topo e os
## pés. Daqui sai, em coordenadas locais do Visual (x = para a frente):
##   - mão (estimada: entre o centro e a frente do corpo, na altura do peito)
##   - ponta do cajado
##   - no quadro de "arrasto" (smear_at), a ponta do quadro anterior (o arco)
## A caixa = retângulo que cobre mão→ponta (+arco) com uma folga pequena
## (PAD_X/PAD_Y): o alcance é o do desenho, nem mais (apelão) nem menos.
## Quadro de IMPACTO = cajado à frente da mão; senão a caixa fica desligada.
## Só leitura do atlas e do estado do CharacterArt (pedido à Arte: getter público).

const PAD_X := 4.0           # px de mundo: espessura do cajado + orbe
const PAD_Y := 9.0
const HAND_FWD := 0.6        # mão = centro → frente do corpo
const HAND_H := 0.38         # mão = 38 % do corpo abaixo do topo
const BEHIND_OK := ["attack_air"]   # o Giro Celeste gira: acerta atrás também
const MIN_X := -4.0          # (golpes de frente) a caixa não começa atrás disto
## Varredura mínima: no quadro de impacto a caixa chega pelo menos MIN_SWEEP px
## além do pé da frente (o cajado em movimento varre o espaço logo à frente do
## corpo — ex.: o 2º leve desenhado bate atrás do pé da frente).
const MIN_SWEEP := 10.0
## Quadro anterior de onde vem o ARCO (smear) quando o impacto é o 1º quadro.
const PREV_SEQ := {"attack1": "windup1", "attack2": "windup2", "attack3": "windup3",
		"attack": "windup", "attack_heavy": "windup_heavy"}


## Geometria do quadro que o Visual está desenhando AGORA. {} = sem quadros
## desenhados (reserva procedural) → o Player usa a caixa antiga.
static func current(art: CharacterArt) -> Dictionary:
	if art == null or not is_instance_valid(art) or art.profile == null:
		return {}
	if not art.painted.get("hero", false):
		return {}
	var db: Dictionary = CharacterArt.frame_db("sophia")
	if db.is_empty():
		return {}
	var states: Dictionary = db.meta.states
	var seq_name: String = art._hero_seq(states)
	if not states.has(seq_name):
		return {}
	var i: int = art._seq_index(states[seq_name], seq_name)
	return frame_geometry(art.profile.height, seq_name, i)


## Geometria de um quadro de uma sequência (`height` = altura do perfil).
static func frame_geometry(height: float, seq_name: String, i: int) -> Dictionary:
	var db: Dictionary = CharacterArt.frame_db("sophia")
	if db.is_empty() or not db.meta.states.has(seq_name):
		return {}
	var meta: Dictionary = db.meta
	var seq: Dictionary = meta.states[seq_name]
	var n: int = seq.frames.size()
	i = clampi(i, 0, n - 1)
	var out := {"seq": seq_name, "i": i, "impact": false}
	var tip_now = _tip_at(meta, seq, i, height)
	if tip_now == null:
		return out
	var e: Dictionary = seq.frames[i]
	var fr: Dictionary = meta.frames[e.f]
	var k: float = height * 1.19 / float(meta.body_px)
	var foot := Vector2(0.0, CharacterArt.GROUND_Y * height / 44.0)
	var anchor := Vector2(e.anchor[0], e.anchor[1])
	var body_h: float = float(fr.foot_y) - float(fr.top)
	var hand_px := Vector2(lerpf(float(fr.center_x), float(fr.front_x), HAND_FWD), float(fr.top) + body_h * HAND_H)
	var hand: Vector2 = foot + (hand_px - anchor) * k
	var tip: Vector2 = tip_now
	var pts: Array[Vector2] = [hand, tip]
	var smear: Array = CharacterArt._int_list(seq.get("smear_at", []))
	var prev = null
	if i in smear:
		if i > 0:
			prev = _tip_at(meta, seq, i - 1, height)
		elif PREV_SEQ.has(seq_name) and meta.states.has(PREV_SEQ[seq_name]):
			var ps: Dictionary = meta.states[PREV_SEQ[seq_name]]
			prev = _tip_at(meta, ps, ps.frames.size() - 1, height)
	if prev != null:
		pts.append(prev)
	var front: float = (foot + (Vector2(float(fr.front_x), 0.0) - anchor) * k).x
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	lo -= Vector2(PAD_X, PAD_Y)
	hi += Vector2(PAD_X, PAD_Y)
	var behind: bool = seq_name in BEHIND_OK
	# impacto: quadro marcado com arrasto (smear_at), o mergulho inteiro, ou o
	# cajado claramente à frente do corpo (estocada)
	var impact: bool = behind or seq_name == "attack_dive" or i in smear or tip.x >= front + 4.0
	if not behind:
		lo.x = maxf(lo.x, MIN_X)
		if impact:
			hi.x = maxf(hi.x, front + MIN_SWEEP)
	out["hand"] = hand
	out["tip"] = tip
	out["prev"] = prev
	out["front"] = front
	out["rect"] = Rect2(lo, hi - lo)
	out["impact"] = impact
	return out


## Ponta do cajado do quadro `i` (coords do Visual) ou null.
static func _tip_at(meta: Dictionary, seq: Dictionary, i: int, height: float):
	var e: Dictionary = seq.frames[i]
	var fr: Dictionary = meta.frames[e.f]
	if fr.get("tip") == null:
		return null
	var k: float = height * 1.19 / float(meta.body_px)
	var foot := Vector2(0.0, CharacterArt.GROUND_Y * height / 44.0)
	return foot + (Vector2(fr.tip[0], fr.tip[1]) - Vector2(e.anchor[0], e.anchor[1])) * k
