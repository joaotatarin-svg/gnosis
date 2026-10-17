extends Node
## SONDA DE QA-UX (não faz parte do jogo): navega os MENUS como um jogador de
## teclado/controle — eventos de tecla e de botão de gamepad reais injetados
## via Input.parse_input_event (nada de chamar métodos internos, salvo onde
## anotado). Registra o foco a cada passo e fotografa cada tela.
## Uso:
##   godot --audio-driver Dummy --path . --resolution 1280x720 --position 4000,4000 \
##     res://tools/qa_ux/UiProbe.tscn -- <pasta_saida>
## Saída: linhas "UI|<passo>|<detalhe>" e "UI|BUG?|<tipo>|<detalhe>".

func _ready() -> void:
	var w := Pilot.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.out_dir = args[0]
	get_tree().root.add_child.call_deferred(w)


class Pilot extends Node:
	var out_dir: String = "user://qa_ui"
	var _n: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		DirAccess.make_dir_recursive_absolute(out_dir)
		_run.call_deferred()

	func log_ui(step: String, detail: String = "") -> void:
		print("UI|%s|%s" % [step, detail])

	func bug(kind: String, detail: String) -> void:
		print("UI|BUG?|%s|%s" % [kind, detail])

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func shot(name: String) -> void:
		await RenderingServer.frame_post_draw
		_n += 1
		var p := "%s/ui%02d_%s.png" % [out_dir, _n, name]
		get_viewport().get_texture().get_image().save_png(p)
		log_ui("SHOT", p)

	func key(k: Key) -> void:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = true
		Input.parse_input_event(e)
		await wait(0.06)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await wait(0.12)

	func pad(b: JoyButton) -> void:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = true
		e.device = 0
		Input.parse_input_event(e)
		await wait(0.06)
		var r := InputEventJoypadButton.new()
		r.button_index = b
		r.pressed = false
		r.device = 0
		Input.parse_input_event(r)
		await wait(0.12)

	func focus() -> String:
		var f := get_viewport().gui_get_focus_owner()
		if f == null:
			return "<nenhum>"
		if f is Button:
			return "Button:'%s'" % f.text
		return "%s:%s" % [f.get_class(), f.name]

	func scene() -> String:
		var cs := get_tree().current_scene
		return cs.scene_file_path.get_file() if cs != null else "<nulo>"

	func _skip_dialogs(max_presses: int = 40) -> int:
		var n := 0
		for i in max_presses:
			var any := false
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					any = true
					if c._in_choices:
						await key(KEY_ENTER)    # escolha focada (1ª)
					else:
						await key(KEY_J)        # avança fala com o botão de ataque
					n += 1
			if not any:
				break
		return n

	func _run() -> void:
		for a in ["ui_cancel", "ui_accept", "pause", "dodge"]:
			var evs := []
			for ev in InputMap.action_get_events(a):
				evs.append(ev.as_text())
			log_ui("inputmap." + a, ", ".join(evs))
		# ============ 1. MENU PRINCIPAL (sem save) ============
		RunManager.saved_run = {}
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		await wait(1.0)
		await shot("menu")
		log_ui("menu.foco_inicial", focus())
		var seen := []
		for i in 8:
			await key(KEY_DOWN)
			seen.append(focus())
		log_ui("menu.setas_baixo", " > ".join(seen))
		seen.clear()
		for i in 3:
			await pad(JOY_BUTTON_DPAD_UP)
			seen.append(focus())
		log_ui("menu.dpad_cima", " > ".join(seen))
		# direita/esquerda entre Ateliê|Crônicas e Opções|Sair
		seen.clear()
		await key(KEY_DOWN)
		await key(KEY_DOWN)
		for k in [KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP]:
			await key(k)
			seen.append(focus())
		log_ui("menu.lados", " > ".join(seen))

		# ============ 2. NOVA CAMPANHA → PRÉ-JOGO ============
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		await wait(0.8)
		log_ui("menu.foco", focus())
		await key(KEY_ENTER)
		await wait(1.0)
		log_ui("pregame.cena", scene())
		await shot("pregame")
		log_ui("pregame.foco", focus())
		# Golpes no pré-jogo e Esc (deve fechar SÓ o painel, não voltar ao menu)
		var pg := get_tree().current_scene
		if pg != null and pg.has_method("_open_moves"):
			for i in 6:
				await key(KEY_DOWN)
				if focus().contains("Golpes") or focus().contains("golpes"):
					break
			log_ui("pregame.foco_golpes?", focus())
			await key(KEY_ENTER)
			await wait(0.5)
			await shot("pregame_golpes")
			await key(KEY_ESCAPE)
			await wait(0.8)
			log_ui("pregame.apos_esc_no_golpes", "cena=%s foco=%s" % [scene(), focus()])
			if scene() != "PreGame.tscn":
				bug("esc_golpes_sai_do_pregame", "Esc no painel de Golpes do pré-jogo levou a %s" % scene())
		if scene() != "PreGame.tscn":
			get_tree().change_scene_to_file("res://scenes/ui/PreGame.tscn")
			await wait(0.8)
		# começa pelo botão focado inicial (Começar)
		get_tree().current_scene.get_node("Center/VBox/Start").grab_focus()
		await key(KEY_ENTER)
		await wait(1.2)
		log_ui("jogo.cena", "%s tela=%d" % [scene(), RunManager.current_screen])

		# ============ 3. PRÓLOGO (cards) ============
		var t0 := Time.get_ticks_msec()
		await shot("prologo_card1")
		var presses := 0
		for i in 30:
			var cine := false
			for c in get_tree().root.get_children():
				if c is Cinematic:
					cine = true
			if not cine:
				break
			await key(KEY_J)
			presses += 1
			await wait(0.3)
			if i == 2:
				await shot("prologo_card3")
		log_ui("prologo.teclas_ate_sair", "%d (%.1f s)" % [presses, (Time.get_ticks_msec() - t0) / 1000.0])
		await wait(0.4)
		await shot("intro_dialogo")
		var nd := await _skip_dialogs()
		log_ui("intro.falas_puladas", str(nd))
		await wait(1.0)
		await shot("rei_inicio")

		# ============ 4. PAUSA ============
		await key(KEY_ESCAPE)
		await wait(0.4)
		log_ui("pausa.aberta", "paused=%s foco=%s" % [str(get_tree().paused), focus()])
		await shot("pausa")
		await key(KEY_ESCAPE)
		await wait(0.4)
		log_ui("pausa.esc_fecha", "paused=%s estado=%d" % [str(get_tree().paused), GameManager.state])
		if get_tree().paused:
			bug("pausa_nao_fecha_com_esc", "")
		# Pausa pelo START do controle
		await pad(JOY_BUTTON_START)
		await wait(0.4)
		log_ui("pausa.start_abre", "paused=%s foco=%s" % [str(get_tree().paused), focus()])
		await pad(JOY_BUTTON_START)
		await wait(0.4)
		log_ui("pausa.start_fecha", "paused=%s" % str(get_tree().paused))
		# Pausa → Melhorias (loja) com 0 faíscas
		Progression.orbs = 0
		await key(KEY_ESCAPE)
		await wait(0.3)
		var order := []
		for i in 6:
			order.append(focus())
			await key(KEY_DOWN)
		log_ui("pausa.ordem_foco", " > ".join(order))
		var lv := get_tree().current_scene
		var pm: Node = null
		for c in lv.get_children():
			if c.scene_file_path.ends_with("PauseMenu.tscn"):
				pm = c
		if pm != null:
			pm._upgrades.grab_focus()
			await key(KEY_ENTER)
			await wait(0.5)
			await shot("loja_pela_pausa")
			log_ui("loja.foco", focus())
			if focus() == "<nenhum>":
				bug("loja_sem_foco", "UpgradeMenu abre sem botão focado: teclado/gamepad não navegam")
			await key(KEY_DOWN)
			await pad(JOY_BUTTON_DPAD_DOWN)
			log_ui("loja.foco_apos_baixo", focus())
			var o0 := Progression.orbs
			await key(KEY_ENTER)
			log_ui("loja.enter_com_0_faiscas", "faiscas %d -> %d" % [o0, Progression.orbs])
			if Progression.orbs < 0:
				bug("loja_faiscas_negativas", str(Progression.orbs))
			await key(KEY_ESCAPE)
			await wait(0.4)
			var shop_open := false
			for c in lv.get_children():
				if c.scene_file_path.ends_with("UpgradeMenu.tscn"):
					shop_open = true
			log_ui("loja.esc_fecha?", "loja_aberta=%s" % str(shop_open))
			if shop_open:
				bug("loja_nao_fecha_com_esc", "Esc/B não fecha a loja (só o botão)")
				for c in lv.get_children():
					if c.scene_file_path.ends_with("UpgradeMenu.tscn"):
						c._close()      # (método interno: fechar pra seguir)
				await wait(0.4)
			log_ui("pausa.apos_loja", "pausa_visivel=%s foco=%s" % [str(pm.get_node("Center").visible), focus()])
			# Pausa → Opções → Esc volta pra pausa
			pm._options.grab_focus()
			await key(KEY_ENTER)
			await wait(0.5)
			await shot("opcoes_pela_pausa")
			log_ui("opcoes.foco", focus())
			await key(KEY_ESCAPE)
			await wait(0.5)
			log_ui("opcoes.esc", "cena=%s pausa_visivel=%s paused=%s foco=%s" % [scene(), str(pm.get_node("Center").visible) if is_instance_valid(pm) else "-", str(get_tree().paused), focus()])
			# Pausa → Golpes → Esc
			pm._moves.grab_focus()
			await key(KEY_ENTER)
			await wait(0.5)
			await shot("golpes_pela_pausa")
			await key(KEY_ESCAPE)
			await wait(0.4)
			log_ui("golpes.esc", "pausa_visivel=%s paused=%s foco=%s" % [str(pm.get_node("Center").visible), str(get_tree().paused), focus()])
			# Pausa → Abandonar → confirmar
			pm._quit.grab_focus()
			await key(KEY_ENTER)
			await wait(0.4)
			await shot("abandonar_confirma")
			log_ui("abandonar.foco", focus())
			# foco padrão é "Voltar" (seguro); vai pra esquerda = Abandonar
			await key(KEY_LEFT)
			log_ui("abandonar.foco_esq", focus())
			await key(KEY_ENTER)
			await wait(1.2)
			log_ui("abandonar.cena", "%s saved=%s" % [scene(), str(RunManager.saved_run.get("screen", -1))])
			await shot("menu_com_continuar")
			log_ui("menu.foco_com_save", focus())
			# Continuar
			await key(KEY_ENTER)
			await wait(1.5)
			log_ui("continuar.cena", "%s tela=%d run_ativo=%s" % [scene(), RunManager.current_screen, str(RunManager.run_active)])
			await _skip_dialogs()
			await wait(0.6)
			await shot("continuar_tela")

		# ============ 5. MORTE → CHECKPOINT (tela 4 → 2) ============
		RunManager.current_screen = 4
		GameManager.current_screen = 4
		RunManager.run_active = true
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(1.0)
		await _skip_dialogs()
		await wait(0.5)
		var pl := get_tree().get_first_node_in_group("player")
		Progression.orbs = 100
		if pl != null:
			pl.health.take_damage(99999)
		await wait(1.0)
		await shot("morte")
		await wait(1.0)
		await shot("morte_dialogo")
		var dn := await _skip_dialogs()
		await wait(1.5)
		var pl2 := get_tree().get_first_node_in_group("player")
		log_ui("morte.checkpoint", "falas=%d tela=%d faiscas=%d hp=%s" % [dn, RunManager.current_screen, Progression.orbs, ("%d/%d" % [pl2.health.current_health, pl2.health.max_health]) if pl2 != null else "-"])
		if RunManager.current_screen != 2:
			bug("checkpoint_errado", "morreu na 4, voltou na %d (esperado 2)" % RunManager.current_screen)
		await _skip_dialogs()
		await wait(0.5)
		await shot("apos_checkpoint")

		# ============ 6. TELAS DO MENU ============
		for spec in [["Chronicles.tscn", "res://scenes/ui/Chronicles.tscn"], ["CharacterAtelier.tscn", "res://scenes/ui/CharacterAtelier.tscn"], ["OptionsMenu.tscn", "res://scenes/ui/OptionsMenu.tscn"], ["Gallery.tscn", "res://scenes/ui/Gallery.tscn"]]:
			RunManager.end_run()
			get_tree().paused = false
			get_tree().change_scene_to_file(spec[1])
			await wait(1.0)
			await shot(spec[0].get_basename())
			log_ui(spec[0] + ".foco", focus())
			var fs := []
			for i in 4:
				await key(KEY_DOWN)
				fs.append(focus())
			log_ui(spec[0] + ".baixo", " > ".join(fs))
			await shot(spec[0].get_basename() + "_navegado")
			await pad(JOY_BUTTON_B)
			await wait(0.8)
			log_ui(spec[0] + ".B_volta", scene())
			if scene() == spec[0]:
				bug("b_nao_volta", spec[0])
				await key(KEY_ESCAPE)
				await wait(0.8)
				log_ui(spec[0] + ".Esc_volta", scene())
				if scene() == spec[0]:
					bug("esc_nao_volta", spec[0])

		# ============ 7. PROVAÇÃO ============
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		await wait(0.8)
		CodexSession.start_demo()
		await wait(2.5)
		await shot("provacao")
		await key(KEY_ESCAPE)
		await wait(0.4)
		await shot("provacao_pausa")
		log_ui("provacao.pausa", "paused=%s foco=%s" % [str(get_tree().paused), focus()])
		await key(KEY_ESCAPE)
		await wait(0.3)
		log_ui("FIM", "")
		get_tree().quit()
