extends RefCounted
class_name StaffReach
## Combate 6 (playtest 2 do João: "o cajado atravessa"): a caixa de acerto da
## Sophia segue o CAJADO DESENHADO no quadro que está na tela.
## Polimento 7: a fonte é a API oficial da Arte — `CharacterArt.frame_geometry()`
## (`staff` = [cabo, ponta] do eixo VISÍVEL, medido na silhueta de cada quadro e
## levado pelo transform do corpo: tranco, escala, mola). O atlas
## (`assets/painted/derived/sophia_frames.json`) ainda dá a PREVISÃO do quadro
## que o Visual vai desenhar (no passo em que a pose troca, a API ainda descreve o
## quadro anterior), a ponta do quadro anterior (arco do arrasto) e a frente do pé.
## Em coordenadas locais do Visual (x = para a frente):
##   - cabo e ponta do cajado (API) — ou mão estimada → ponta (previsão do atlas)
##   - no quadro de "arrasto" (smear_at), a ponta do quadro anterior (o arco)
##   - ACOMPANHAMENTO: golpe de cima para baixo cuja ponta para atrás do pé da
##     frente (ex.: 2º leve, `s4.light2_hit`): o eixo do cajado continua até o
##     chão (o cajado em movimento varre o espaço logo à frente do pé), no máximo
##     FOLLOW_MAX px — no lugar da varredura mínima fixa de antes (MIN_SWEEP 10 px).
## A caixa = retângulo que cobre esses pontos com uma folga pequena
## (PAD_X/PAD_Y): o alcance é o do desenho, nem mais (apelão) nem menos.
## Quadro de IMPACTO = arrasto, mergulho, giro aéreo ou cajado à frente do pé;
## senão a caixa fica desligada.

const PAD_X := 4.0           # px de mundo: espessura do cajado + orbe
const PAD_Y := 9.0
const HAND_FWD := 0.6        # (previsão do atlas) mão = centro → frente do corpo
const HAND_H := 0.38         # mão = 38 % do corpo abaixo do topo
const BEHIND_OK := ["attack_air"]   # o Giro Celeste gira: acerta atrás também
const MIN_X := -4.0          # (golpes de frente) a caixa não começa atrás disto
## Acompanhamento do golpe descendente (px de mundo além da ponta, ao longo do
## eixo, até a linha do chão).
const FOLLOW_MAX := 16.0
## Quadro anterior de onde vem o ARCO (smear) quando o impacto é o 1º quadro.
const PREV_SEQ := {"attack1": "windup1", "attack2": "windup2", "attack3": "windup3",
		"attack": "windup", "attack_heavy": "windup_heavy"}


## Geometria do quadro que o Visual está desenhando AGORA. {} = sem quadros
## desenhados (reserva procedural) → o Player usa a caixa antiga.
## Chaves: seq, i, impact, rect, hand, tip, prev, follow, front, source
## ("api" = eixo da Arte; "atlas" = previsão no passo da troca de pose).
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
	var out: Dictionary = frame_geometry(art.profile.height, seq_name, i)
	out["source"] = "atlas"
	# a API vale quando o último _draw já mostrou ESTE quadro
	if out.has("tip") and art.has_method("frame_geometry") and String(art.get("_shown_key")) == "%s:%d" % [seq_name, i]:
		var g: Dictionary = art.frame_geometry()
		if g.has("staff"):
			_apply_api(out, g)
	return out


## Troca a mão/ponta estimadas pelo eixo do cajado da API e refaz a caixa. O
## arco (ponta do quadro anterior) e a frente do pé vêm do atlas, deslocados
## junto com a ponta (o mesmo tranco/mola do corpo).
static func _apply_api(out: Dictionary, g: Dictionary) -> void:
	var staff: PackedVector2Array = g.staff
	var tip: Vector2 = g.tip
	var shift: Vector2 = tip - Vector2(out.tip)
	var prev = null
	if out.get("prev") != null:
		prev = Vector2(out.prev) + shift
	var front: float = float(out.front) + shift.x
	var floor_y: float = float(out.floor_y) + shift.y
	var b: Dictionary = _box(staff[0], tip, prev, front, floor_y, String(out.seq), bool(out.smear))
	out["hand"] = staff[0]
	out["tip"] = tip
	out["prev"] = prev
	out["front"] = front
	out["floor_y"] = floor_y
	out["follow"] = b.follow
	out["rect"] = b.rect
	out["impact"] = b.impact
	out["source"] = "api"
	out["staff_estimated"] = bool(g.get("staff_estimated", false))


## Geometria de um quadro de uma sequência pelo atlas (`height` = altura do perfil).
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
	var smear_at: Array = CharacterArt._int_list(seq.get("smear_at", []))
	var smear: bool = i in smear_at
	var prev = null
	if smear:
		if i > 0:
			prev = _tip_at(meta, seq, i - 1, height)
		elif PREV_SEQ.has(seq_name) and meta.states.has(PREV_SEQ[seq_name]):
			var ps: Dictionary = meta.states[PREV_SEQ[seq_name]]
			prev = _tip_at(meta, ps, ps.frames.size() - 1, height)
	var front: float = (foot + (Vector2(float(fr.front_x), 0.0) - anchor) * k).x
	var b: Dictionary = _box(hand, tip, prev, front, foot.y, seq_name, smear)
	out["hand"] = hand
	out["tip"] = tip
	out["prev"] = prev
	out["front"] = front
	out["floor_y"] = foot.y
	out["smear"] = smear
	out["follow"] = b.follow
	out["rect"] = b.rect
	out["impact"] = b.impact
	return out


## Caixa de acerto de um quadro: cobre cabo/mão → ponta (+ arco, + acompanhamento).
static func _box(hand: Vector2, tip: Vector2, prev, front: float, floor_y: float, seq_name: String, smear: bool) -> Dictionary:
	var behind: bool = seq_name in BEHIND_OK
	var pts: Array[Vector2] = [hand, tip]
	if prev != null:
		pts.append(prev)
	var follow = null
	if not behind:
		follow = _follow_through(hand, tip, front, floor_y)
		if follow != null:
			pts.append(follow)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	lo -= Vector2(PAD_X, PAD_Y)
	hi += Vector2(PAD_X, PAD_Y)
	if not behind:
		lo.x = maxf(lo.x, MIN_X)
	# impacto: quadro marcado com arrasto (smear_at), o mergulho inteiro, o giro,
	# ou o cajado claramente à frente do corpo (estocada)
	var impact: bool = behind or seq_name == "attack_dive" or smear or tip.x >= front + 4.0
	return {"rect": Rect2(lo, hi - lo), "impact": impact, "follow": follow}


## Golpe DESCENDENTE (eixo para a frente e para baixo) cuja ponta para atrás do
## pé da frente: o ponto onde o eixo do cajado, prolongado além da ponta, chega
## à linha do chão (no máx. FOLLOW_MAX px). null nos outros casos.
static func _follow_through(hand: Vector2, tip: Vector2, front: float, floor_y: float):
	var d: Vector2 = tip - hand
	if tip.x >= front or d.x <= 0.0 or d.y <= 0.0 or tip.y >= floor_y:
		return null
	var dir: Vector2 = d.normalized()
	var t: float = minf((floor_y - tip.y) / dir.y, FOLLOW_MAX)
	return tip + dir * t


## Ponta do cajado do quadro `i` (coords do Visual) ou null.
static func _tip_at(meta: Dictionary, seq: Dictionary, i: int, height: float):
	var e: Dictionary = seq.frames[i]
	var fr: Dictionary = meta.frames[e.f]
	if fr.get("tip") == null:
		return null
	var k: float = height * 1.19 / float(meta.body_px)
	var foot := Vector2(0.0, CharacterArt.GROUND_Y * height / 44.0)
	return foot + (Vector2(fr.tip[0], fr.tip[1]) - Vector2(e.anchor[0], e.anchor[1])) * k
