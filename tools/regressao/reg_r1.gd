extends "res://tools/regressao/reg_base.gd"
## REVISAO #1 (Alta): a Sophia morre e o Arconte cai logo depois (ou no mesmo
## quadro) → o Anel é dado, a loja pós-chefe abre, o diálogo de morte abre POR
## CIMA dela e, ao fechar, ela volta ao INÍCIO do Éon (tela 2) com o Anel no
## bolso (refaz 9 telas e enfrenta de novo um Arconte já vencido).
## Esperado: UM desfecho coerente por tela — ou vitória (Anel + segue para a 11)
## ou morte (sem Anel, volta ao checkpoint); nunca os dois; e nunca o diálogo
## de morte por cima da loja.
## Cenários: a = Sophia morre, chefe cai 20 quadros depois; b = mesmo quadro.

const TELA := 10


func rodar() -> void:
	await _cenario("a")
	await _cenario("b")


func _cenario(modo: String) -> void:
	var lv := await level_at(TELA)
	var boss_id := RunManager.boss_id_for(TELA)
	ir_para_zona(lv, 0)
	var boss: Enemy = null
	for i in 600:
		await frames(1)
		pular_dialogos()
		var cs := chefes_vivos()
		if not cs.is_empty():
			boss = cs[0]
			break
	if boss == null:
		quebrado("[%s] o Arconte da tela %d não apareceu" % [modo, TELA])
		return
	await wait(2.0)
	pular_dialogos()
	var pl: Player = lv.player
	if modo == "b":
		bater(boss, boss.health.max_health * 3 + 999)
		pl.health.take_damage(99999)
	else:
		pl.health.take_damage(99999)
		await frames(20)
		bater(boss, boss.health.max_health * 3 + 999)
	info("[%s] Sophia morta e %s caído" % [modo, boss_id])
	# Joga como um jogador: lê a loja ~3,3 s antes de fechar; fecha diálogos.
	var sobreposto := false
	var loja_t := -1
	var estavel := 0
	var ultimo := ""
	for f in 1800:
		await frames(1)
		var cena := get_tree().current_scene
		var shop: Node = overlay(cena, "UpgradeMenu.tscn") if cena != null else null
		var dlg := dialogos_abertos()
		if shop != null and not dlg.is_empty():
			sobreposto = true
		if not dlg.is_empty():
			pular_dialogos()
		if shop != null:
			if loja_t < 0:
				loja_t = f
				info("[%s] loja pós-chefe aberta (f=%d, pending_advance=%s)" % [modo, f, str(RunManager.pending_advance)])
			elif f - loja_t >= 200:
				shop.call("_close")
				loja_t = -9999
		var est := "tela_run=%d cena_level=%s aneis=%s pending=%s" % [RunManager.current_screen, str((cena as Level).screen) if cena is Level else "-", str(Progression.rings), str(RunManager.pending_advance)]
		if est != ultimo:
			info("[%s] f=%d %s" % [modo, f, est])
			ultimo = est
			estavel = 0
		else:
			estavel += 1
		if estavel > 240 and shop == null and dlg.is_empty() and cena is Level and (cena as Level)._ready_done:
			break
	var com_anel := Progression.rings.has(boss_id)
	var voltou := RunManager.current_screen < TELA
	check("%s_nao_volta_ao_checkpoint_com_o_anel" % modo, not (com_anel and voltou), "tela_final=%d anel_%s=%s" % [RunManager.current_screen, boss_id, str(com_anel)])
	check("%s_desfecho_coerente" % modo, (com_anel and RunManager.current_screen > TELA) or (not com_anel and voltou), "vitória exige Anel + tela>%d; morte exige sem Anel + checkpoint (tela_final=%d anel=%s)" % [TELA, RunManager.current_screen, str(com_anel)])
	check("%s_dialogo_de_morte_nao_abre_sobre_a_loja" % modo, not sobreposto, "diálogo com a loja aberta=%s" % str(sobreposto))
	PauseStack.clear()
