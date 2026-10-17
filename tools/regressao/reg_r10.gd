extends "res://tools/regressao/reg_base.gd"
## REVISAO #10 (Média): pausa como booleano global — quem fecha despausa TUDO
## (diálogo, Estela, loja, pausa fazem `paused = false` incondicional) — e o
## timer de morte (`create_timer(1.5)`, process_always) corre mesmo pausado.
## Esperado (contrato PauseStack): o mundo só volta quando o ÚLTIMO dono larga
## a pausa; o fluxo de morte espera a pausa acabar.


func rodar() -> void:
	# 1) Loja aberta + diálogo por cima: fechar o diálogo não solta o mundo.
	var lv := await level_at(4)
	var shop := SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	await wait(0.3)
	check("loja_pausa_o_mundo", get_tree().paused, "paused=%s" % str(get_tree().paused))
	var d := DialogueBox.play([{"speaker": "A Voz", "text": "Teste."}])
	await wait(0.3)
	d._finish()
	await wait(0.3)
	var loja_aberta := shop != null and is_instance_valid(shop) and not shop.is_queued_for_deletion()
	check("dialogo_fecha_e_loja_segue_pausando", loja_aberta and get_tree().paused, "loja_aberta=%s paused=%s" % [str(loja_aberta), str(get_tree().paused)])
	if loja_aberta:
		shop.queue_free()
	PauseStack.clear()
	await frames(2)

	# 2) Pausa (Esc) + diálogo que nasce e fecha: a pausa continua valendo.
	lv = await level_at(4)
	GameManager.set_state(GameManager.State.PLAYING)
	await tecla(KEY_ESCAPE)
	await wait(0.3)
	var pm := overlay(lv, "PauseMenu.tscn")
	if pm == null:
		quebrado("Esc não abriu a pausa")
		return
	var d2 := DialogueBox.play([{"speaker": "A Voz", "text": "Teste."}])
	await wait(0.3)
	d2._finish()
	await wait(0.3)
	var pm_ok := overlay(lv, "PauseMenu.tscn") != null
	check("dialogo_fecha_e_pausa_segue", pm_ok and get_tree().paused, "pausa_aberta=%s paused=%s" % [str(pm_ok), str(get_tree().paused)])
	if pm_ok:
		overlay(lv, "PauseMenu.tscn").queue_free()
	PauseStack.clear()
	await frames(2)

	# 3) Morte com o mundo pausado por outro dono: o diálogo de morte espera.
	lv = await level_at(4)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await wait(0.3)
	var tela0 := RunManager.current_screen
	lv.player.health.take_damage(99999)
	PauseStack.push(self)              # algo pausa o mundo no mesmo quadro (card, Estela…)
	var cedo := false
	for i in 180:                       # 3 s de relógio com o mundo pausado
		await frames(1)
		if not dialogos_abertos().is_empty():
			cedo = true
			break
	check("morte_espera_a_pausa", not cedo and RunManager.current_screen == tela0, "diálogo_de_morte_durante_a_pausa=%s tela=%d" % [str(cedo), RunManager.current_screen])
	pular_dialogos()
	PauseStack.pop(self)
	# Depois que a pausa acaba, a morte segue (não pode sumir).
	var veio := cedo
	for i in 240:
		await frames(1)
		if not dialogos_abertos().is_empty():
			veio = true
			break
	check("morte_segue_depois_da_pausa", veio, "diálogo de morte apareceu=%s" % str(veio))
	pular_dialogos()
