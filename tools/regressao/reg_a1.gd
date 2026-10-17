extends "res://tools/regressao/reg_base.gd"
## A1 (QA_UX_BUGS, Alta): loja (UpgradeMenu) sem foco; setas/Enter não fazem
## nada; Esc não fecha. Especificação (brief ui-menus, A1): loja abre com foco
## no 1º ITEM (mesmo trancado, para ler o preço), setas navegam, ui_accept
## compra, ui_cancel fecha SÓ a loja (volta à pausa com foco). Tudo por
## TECLADO com eventos reais.
## "1º item" = o 1º botão da loja em ordem de árvore (a lista vem antes do
## botão de fechar), sem depender de nomes internos.


func rodar() -> void:
	var lv := await level_at(4)
	Progression.orbs = 0
	GameManager.set_state(GameManager.State.PLAYING)
	await tecla(KEY_ESCAPE)
	await wait(0.4)
	var pm := overlay(lv, "PauseMenu.tscn")
	if pm == null:
		quebrado("Esc não abriu a pausa")
		return
	# Pausa → Melhorias (pelo teclado: foco no botão + Enter).
	(pm.get("_upgrades") as Button).grab_focus()
	await tecla(KEY_ENTER)
	await wait(0.6)
	var shop := overlay(lv, "UpgradeMenu.tscn")
	if shop == null:
		quebrado("Enter em Melhorias não abriu a loja")
		return
	var itens := _itens(shop)
	if itens.size() < 2:
		quebrado("loja com menos de 2 itens (%d)" % itens.size())
		return
	# 1) Abre com foco no 1º item (0 faíscas: todos trancados).
	check("loja_abre_com_foco_no_1o_item", get_viewport().gui_get_focus_owner() == itens[0], "1º item=%s foco=%s" % [_nome(itens[0]), foco()])
	# 2) Setas: a partir do 1º item, ↓ vai ao 2º e ↑ volta ao 1º.
	itens[0].grab_focus()
	await frames(2)
	await tecla(KEY_DOWN)
	await wait(0.1)
	check("seta_baixo_vai_ao_2o_item", get_viewport().gui_get_focus_owner() == itens[1], "esperado=%s foco=%s" % [_nome(itens[1]), foco()])
	await tecla(KEY_UP)
	await wait(0.1)
	check("seta_cima_volta_ao_1o_item", get_viewport().gui_get_focus_owner() == itens[0], "esperado=%s foco=%s" % [_nome(itens[0]), foco()])
	# 3) Enter num item trancado (0 faíscas): não compra e não fecha.
	var o0 := Progression.orbs
	await tecla(KEY_ENTER)
	await wait(0.2)
	var ainda_aberta := overlay(lv, "UpgradeMenu.tscn") != null
	check("enter_sem_faiscas_nao_compra_nem_fecha", Progression.orbs == o0 and ainda_aberta, "faiscas %d -> %d loja_aberta=%s foco=%s" % [o0, Progression.orbs, str(ainda_aberta), foco()])
	if not ainda_aberta:
		quebrado("a loja fechou antes do teste do Esc")
		return
	# 4) Esc fecha SÓ a loja; a pausa volta com foco.
	await tecla(KEY_ESCAPE)
	await wait(0.5)
	var aberta := overlay(lv, "UpgradeMenu.tscn") != null
	check("esc_fecha_loja", not aberta, "loja_aberta=%s" % str(aberta))
	if aberta:
		overlay(lv, "UpgradeMenu.tscn").call("_close")
		await wait(0.3)
	var pm2 := overlay(lv, "PauseMenu.tscn")
	var f2 := get_viewport().gui_get_focus_owner()
	check("esc_volta_para_pausa_com_foco", pm2 != null and get_tree().paused and f2 != null and pm2.is_ancestor_of(f2), "pausa=%s paused=%s foco=%s" % [str(pm2 != null), str(get_tree().paused), foco()])

	# 5) Com faíscas: Enter no 1º item compra.
	if pm2 != null:
		Progression.orbs = 99999
		(pm2.get("_upgrades") as Button).grab_focus()
		await tecla(KEY_ENTER)
		await wait(0.6)
		var shop2 := overlay(lv, "UpgradeMenu.tscn")
		if shop2 == null:
			check("enter_com_faiscas_compra", false, "a loja não reabriu")
		else:
			var it2 := _itens(shop2)
			it2[0].grab_focus()
			await frames(2)
			var o1 := Progression.orbs
			var nome_item := _nome(it2[0])      # a compra reconstrói a lista (o botão é liberado)
			await tecla(KEY_ENTER)
			await wait(0.3)
			check("enter_com_faiscas_compra", Progression.orbs < o1, "item=%s faiscas %d -> %d" % [nome_item, o1, Progression.orbs])
			if overlay(lv, "UpgradeMenu.tscn") != null:
				overlay(lv, "UpgradeMenu.tscn").queue_free()
		Progression.orbs = 0

	# 6) Loja pós-chefe (pending_advance): também abre com foco no 1º item.
	PauseStack.clear()
	pm2 = overlay(lv, "PauseMenu.tscn")
	if pm2 != null:
		pm2.queue_free()
	await frames(2)
	RunManager.pending_advance = true
	var shop3 := SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	await wait(0.6)
	var it3 := _itens(shop3)
	check("loja_pos_chefe_abre_com_foco_no_1o_item", not it3.is_empty() and get_viewport().gui_get_focus_owner() == it3[0], "1º item=%s foco=%s" % [_nome(it3[0]) if not it3.is_empty() else "-", foco()])
	RunManager.pending_advance = false
	shop3.queue_free()


## Botões da loja em ordem de árvore, menos o último (fechar/seguir).
func _itens(shop: Node) -> Array:
	var r: Array = []
	for b in shop.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			r.append(b)
	if not r.is_empty():
		r.pop_back()
	return r


func _nome(c: Control) -> String:
	if c == null:
		return "<nenhum>"
	if c is Button:
		return "Button:'%s'" % (c as Button).text.replace("\n", " ").strip_edges()
	return c.get_class()
