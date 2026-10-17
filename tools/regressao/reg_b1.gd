extends "res://tools/regressao/reg_base.gd"
## B1 (QA_UX_BUGS, Bloqueante): só com CONTROLE, A não confirma e B não volta
## (ui_accept/ui_cancel sem botão de controle) → softlock na 1ª tentação.
## Esperado: A confirma e B volta em menu, diálogo com escolha e loja.


func rodar() -> void:
	# 1) Mapa de entrada: A em ui_accept, B em ui_cancel.
	check("inputmap_ui_accept_tem_A", _tem_botao("ui_accept", JOY_BUTTON_A), _lista("ui_accept"))
	check("inputmap_ui_cancel_tem_B", _tem_botao("ui_cancel", JOY_BUTTON_B), _lista("ui_cancel"))

	# 2) Menu principal: foco num botão, apertar A → o botão dispara.
	RunManager.saved_run = {}
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await wait(1.2)
	var f := get_viewport().gui_get_focus_owner()
	if f is Button:
		var disparou := [false]
		(f as Button).pressed.connect(func(): disparou[0] = true)
		var nome := (f as Button).text
		await botao(JOY_BUTTON_A)
		await frames(2)
		check("menu_A_confirma", disparou[0], "foco='%s' disparou=%s" % [nome, str(disparou[0])])
	else:
		check("menu_A_confirma", false, "menu sem foco inicial (%s)" % foco())

	# 3) Tentação (tela 10): caixa com Recusar/Ceder, apertar A → escolhe e fecha.
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await wait(0.6)
	var d := DialogueBox.play([{"speaker": "A Voz", "text": "Escolhe."}], ["Recusar", "Ceder"])
	await frames(3)
	d.idx = d.lines.size()
	d._show_line()
	await wait(0.6)
	var escolha := [-1]
	d.choice_made.connect(func(i: int): escolha[0] = i)
	info("tentacao foco=%s" % foco())
	await botao(JOY_BUTTON_A)
	await frames(3)
	var aberta := is_instance_valid(d) and not d.is_queued_for_deletion()
	check("tentacao_A_escolhe", escolha[0] >= 0 and not aberta, "escolha=%d caixa_aberta=%s paused=%s" % [escolha[0], str(aberta), str(get_tree().paused)])
	if aberta:
		d._finish()
	await frames(2)

	# 4) Loja (santuário/pós-chefe): apertar B → fecha.
	var lv := await level_at(6)
	var shop := SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	await wait(0.6)
	await botao(JOY_BUTTON_B)
	await wait(0.4)
	var ainda := shop != null and is_instance_valid(shop) and not shop.is_queued_for_deletion()
	check("loja_B_fecha", not ainda, "loja_aberta=%s" % str(ainda))
	if ainda:
		shop._close()
	await frames(2)

	# 5) Pausa: B fecha (volta ao jogo).
	PauseStack.clear()
	GameManager.set_state(GameManager.State.PLAYING)
	await botao(JOY_BUTTON_START)
	await wait(0.4)
	var pm := overlay(lv, "PauseMenu.tscn")
	if pm == null:
		check("pausa_B_fecha", false, "Start não abriu a pausa")
	else:
		await botao(JOY_BUTTON_B)
		await wait(0.4)
		var pm2 := overlay(lv, "PauseMenu.tscn")
		check("pausa_B_fecha", pm2 == null and not get_tree().paused, "pausa_aberta=%s paused=%s" % [str(pm2 != null), str(get_tree().paused)])


func _tem_botao(acao: String, b: JoyButton) -> bool:
	for ev in InputMap.action_get_events(acao):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == b:
			return true
	return false


func _lista(acao: String) -> String:
	var r: Array = []
	for ev in InputMap.action_get_events(acao):
		r.append(ev.as_text())
	return ", ".join(r)


## Autoteste: o conserto óbvio (A/B nas ações de UI) deve fazer o teste passar.
func simular_correcao() -> void:
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	InputMap.action_add_event("ui_accept", a)
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	InputMap.action_add_event("ui_cancel", b)
