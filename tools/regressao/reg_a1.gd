extends "res://tools/regressao/reg_base.gd"
## A1 (QA_UX_BUGS, Alta): loja (UpgradeMenu) sem foco; setas/Enter não fazem
## nada; Esc não fecha. Esperado (só TECLADO, eventos reais): abre com um item
## focado, setas movem o foco dentro da loja, Enter sem faíscas não compra nem
## fecha, Esc fecha SÓ a loja e devolve o foco à pausa.


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
	var f0 := get_viewport().gui_get_focus_owner()
	check("loja_abre_com_foco", f0 != null and shop.is_ancestor_of(f0), "foco=%s" % foco())
	# Com 0 faíscas o foco cai em "Voltar ao jogo" (último); ↑ tem de entrar na lista.
	await tecla(KEY_UP)
	await wait(0.1)
	var f1 := get_viewport().gui_get_focus_owner()
	check("seta_move_foco", f1 != null and f1 != f0 and shop.is_ancestor_of(f1), "antes=%s depois=%s" % [_nome(f0), foco()])
	await tecla(KEY_DOWN)
	await wait(0.1)
	var f1b := get_viewport().gui_get_focus_owner()
	check("seta_baixo_volta", f1b == f0, "esperado=%s obtido=%s" % [_nome(f0), foco()])
	await tecla(KEY_UP)
	await wait(0.1)
	var o0 := Progression.orbs
	await tecla(KEY_ENTER)
	await wait(0.2)
	var ainda_aberta := overlay(lv, "UpgradeMenu.tscn") != null
	check("enter_sem_faiscas_nao_compra", Progression.orbs == o0 and Progression.orbs >= 0 and ainda_aberta, "faiscas %d -> %d loja_aberta=%s foco=%s" % [o0, Progression.orbs, str(ainda_aberta), foco()])
	if not ainda_aberta:
		quebrado("a loja fechou antes do teste do Esc")
		return
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

	# Loja pós-chefe (pending_advance): também abre com foco.
	PauseStack.clear()
	if pm2 != null:
		pm2.queue_free()
	await frames(2)
	RunManager.pending_advance = true
	var shop2 := SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	await wait(0.6)
	var f3 := get_viewport().gui_get_focus_owner()
	check("loja_pos_chefe_abre_com_foco", f3 != null and shop2.is_ancestor_of(f3), "foco=%s" % foco())
	RunManager.pending_advance = false
	shop2.queue_free()


func _nome(c: Control) -> String:
	if c == null:
		return "<nenhum>"
	if c is Button:
		return "Button:'%s'" % (c as Button).text.replace("\n", " ").strip_edges()
	return c.get_class()
