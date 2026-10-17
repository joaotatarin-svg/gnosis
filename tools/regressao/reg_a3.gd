extends "res://tools/regressao/reg_base.gd"
## A3 (QA_UX_BUGS, Alta): batalha final (tela 68) com DUAS formas (Rei e
## Colosso) e UMA barra só: o nome é o do Colosso, bater no Rei baixa essa
## barra e a FASE II vai para o chefe errado; quando o Rei cai a barra some
## com o Colosso vivo. Esperado: cada barra mostrada corresponde ao chefe certo
## (nome, vida e fase do PRÓPRIO chefe), as duas formas têm barra, e a que
## sobra viva continua com barra.
##
## Como o teste lê as barras: SÓ pelo contrato do HUD (ui-hud, Onda 2)
##   hud.boss_bars() -> Array de {node, ratio, phase}   (barras visíveis agora)
## HUD sem `boss_bars()` = contrato ausente = falha (sem ler campos internos).

const TOL := 0.04


func rodar() -> void:
	var lv := await level_at(68)
	var formas: Array = []
	for i in 300:
		await frames(1)
		pular_dialogos()
		formas = chefes_vivos()
		if formas.size() >= 2:
			break
	if formas.size() < 2:
		quebrado("a batalha final não criou as duas formas (chefes vivos=%d)" % formas.size())
		return
	await wait(1.0)
	pular_dialogos()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		quebrado("sem HUD")
		return
	var rei: Enemy = null
	var col: Enemy = null
	for f in formas:
		if String(f.type_id) == "colosso":
			col = f
		else:
			rei = f
	if rei == null or col == null:
		quebrado("formas inesperadas: %s" % str(formas.map(func(e): return e.type_id)))
		return
	info("formas: %s (%s) e %s (%s)" % [rei.type_id, rei.display_name, col.type_id, col.display_name])

	check("hud_tem_contrato_boss_bars", hud.has_method("boss_bars"), "hud.boss_bars() existe=%s" % str(hud.has_method("boss_bars")))
	# 1) Início: as duas formas têm barra; cada barra bate com o próprio chefe.
	var bars := _barras(hud)
	check("inicio_rei_tem_barra", _barra_de(bars, rei) != null, _desc(bars))
	check("inicio_colosso_tem_barra", _barra_de(bars, col) != null, _desc(bars))
	check("inicio_barras_coerentes", _coerentes(bars), _desc(bars))

	# 2) Bater SÓ no Rei até ~55% (ainda fase I): a barra do Colosso não pode mexer.
	bater(rei, int(rei.health.max_health * 0.45))
	await wait(0.5)
	bars = _barras(hud)
	check("dano_no_rei_barras_coerentes", _coerentes(bars), _desc(bars))
	var br = _barra_de(bars, rei)
	check("dano_no_rei_aparece_na_barra_do_rei", br != null and absf(float(br.ratio) - _vida(rei)) <= TOL, _desc(bars))

	# 3) Rei passa da metade → FASE II dele (não do Colosso).
	bater(rei, int(rei.health.max_health * 0.15))
	await wait(0.6)
	pular_dialogos()
	bars = _barras(hud)
	info("fases: rei=%d colosso=%d" % [rei.phase, col.phase])
	check("fase2_no_chefe_certo", _coerentes(bars) and _barra_de(bars, rei) != null and int(_barra_de(bars, rei).phase) == rei.phase, _desc(bars))

	# 4) Rei cai, Colosso vivo e cheio: o Colosso continua com barra visível.
	bater(rei, rei.health.max_health * 2)
	await wait(0.8)
	pular_dialogos()
	bars = _barras(hud)
	var vivo := is_instance_valid(col) and col.estate != Enemy.EState.DEAD
	check("rei_caiu_colosso_segue_com_barra", vivo and _barra_de(bars, col) != null, "colosso_vivo=%s %s" % [str(vivo), _desc(bars)])
	check("rei_caiu_barras_coerentes", _coerentes(bars), _desc(bars))


## Barras que o HUD mostra agora: Array de {node, ratio, phase} (contrato boss_bars()).
func _barras(hud: Node) -> Array:
	var r: Array = []
	if not hud.has_method("boss_bars"):
		return r
	for b in hud.call("boss_bars"):
		if b is Dictionary and b.get("node") != null:
			r.append(b)
	return r


func _barra_de(bars: Array, e: Enemy):
	for b in bars:
		if b.node == e:
			return b
	return null


func _vida(e: Enemy) -> float:
	return float(e.health.current_health) / maxf(1.0, float(e.health.max_health))


## Cada barra mostra a vida e a fase do PRÓPRIO chefe.
func _coerentes(bars: Array) -> bool:
	for b in bars:
		var e = b.node
		if not is_instance_valid(e):
			return false
		if absf(float(b.ratio) - _vida(e)) > TOL:
			return false
		if int(b.phase) != int(e.phase):
			return false
	return true


func _desc(bars: Array) -> String:
	var r: Array = []
	for b in bars:
		var e = b.node
		if is_instance_valid(e):
			r.append("[%s barra=%.2f vida=%.2f fase_barra=%d fase=%d]" % [e.type_id, float(b.ratio), _vida(e), int(b.phase), e.phase])
		else:
			r.append("[<chefe liberado>]")
	return "barras=%d %s" % [bars.size(), " ".join(r)]
