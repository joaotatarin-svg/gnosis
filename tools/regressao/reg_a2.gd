extends "res://tools/regressao/reg_base.gd"
## A2 (QA_UX_BUGS, Alta): a faixa de legenda (CaptionBar, layer 60) ficava POR
## CIMA da pausa, da loja, das Opções e da tela de Golpes. Esperado: com um
## menu aberto, a legenda não é desenhada por cima dele (some, ou fica numa
## camada abaixo). Também vale para o diálogo (DialogueBox).


func rodar() -> void:
	var lv := await level_at(2)
	var bar := _caption()
	if bar == null:
		quebrado("CaptionBar não encontrada no Gnosis")
		return
	# Legenda longa ativa (como a da Voz logo após a intro).
	Gnosis.caption("A Voz", "O Éon do Torpor. Aqui os mortos não sabem que morreram, e os vivos também não.")
	for i in 120:
		await frames(1)
		if _desenhada(bar):
			break
	if not _desenhada(bar):
		quebrado("a legenda não apareceu (estado=%s)" % _estado(bar))
		return
	info("legenda ativa: %s" % _estado(bar))
	GameManager.set_state(GameManager.State.PLAYING)
	# 1) Pausa (Esc).
	await tecla(KEY_ESCAPE)
	await wait(0.3)
	var pm := overlay(lv, "PauseMenu.tscn")
	if pm == null:
		quebrado("Esc não abriu a pausa")
		return
	await _verifica("pausa", bar, pm)
	# 2) Melhorias (loja) pela pausa.
	pm.call("_open_upgrades")
	await wait(0.4)
	var shop := overlay(lv, "UpgradeMenu.tscn")
	if shop != null:
		await _verifica("loja_pela_pausa", bar, shop)
		shop.call("_close")
		await wait(0.3)
	else:
		check("loja_pela_pausa", false, "loja não abriu")
	# 3) Opções pela pausa.
	pm.call("_open_options")
	await wait(0.4)
	var opt: Node = null
	for c in pm.get_children():
		if c.scene_file_path.ends_with("OptionsMenu.tscn"):
			opt = c
	if opt != null:
		await _verifica("opcoes_pela_pausa", bar, opt)
		if opt.has_method("_back"):
			opt.call("_back")
		await wait(0.3)
	else:
		check("opcoes_pela_pausa", false, "Opções não abriram")
	# 4) Golpes pela pausa.
	pm.call("_open_moves")
	await wait(0.4)
	var mv: Node = null
	for c in pm.get_children():
		if c is MovesScreen:
			mv = c
	if mv != null:
		await _verifica("golpes_pela_pausa", bar, mv)
	else:
		check("golpes_pela_pausa", false, "Golpes não abriu")


func _caption() -> CanvasLayer:
	for c in Gnosis.get_children():
		if c is CaptionBar:
			return c
	return null


## A legenda está sendo desenhada (visível de fato na tela)?
func _desenhada(bar: CanvasLayer) -> bool:
	if not bar.visible:
		return false
	var root: Control = bar.get("_root")
	if root == null:
		return false
	return root.is_visible_in_tree() and root.modulate.a > 0.05


func _estado(bar: CanvasLayer) -> String:
	var root: Control = bar.get("_root")
	return "layer=%d visivel=%s alpha=%.2f mostrando=%s" % [bar.layer, str(root.is_visible_in_tree() if root else false), root.modulate.a if root else 0.0, str(bar.get("_showing"))]


## Camada efetiva de um menu (o CanvasLayer dele ou do ancestral mais próximo).
func _camada(n: Node) -> int:
	var p: Node = n
	while p != null:
		if p is CanvasLayer:
			return (p as CanvasLayer).layer
		p = p.get_parent()
	return 0


func _verifica(nome: String, bar: CanvasLayer, menu: Node) -> void:
	await frames(2)
	var cobre := _desenhada(bar) and bar.layer >= _camada(menu)
	check(nome + "_sem_legenda_por_cima", not cobre, "legenda %s · menu layer=%d" % [_estado(bar), _camada(menu)])
