extends Node
## FERRAMENTA (não faz parte do jogo): percorre TODAS as telas de UX e salva um
## PNG de cada uma pra IA VER (menu com e sem save, confirmação, pré-jogo,
## golpes, opções, Ateliê, Bestiário, Crônicas, Créditos, fim de jogo, HUD,
## diálogo/legenda, pausa e seus overlays, loja, chefe fase 1/2, Provação).
## Também testa a NAVEGAÇÃO: em cada menu simula o D-pad do controle e a seta
## do teclado e confere que o foco existe e anda — imprime "NAV OK/FALHA".
## Uso: godot --path . --resolution 1280x720 --position 4000,4000 res://tools/UxShots.tscn -- [pasta_saida]
##      (sem pasta: res://shots/ — os arquivos saem como ux_<nome>.png)

func _ready() -> void:
	var w := Worker.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.out_dir = args[0]
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var out_dir: String = "res://shots"
	var auto_finish: bool = true     # pula diálogos (menos quando fotografamos a caixa)
	var nav_ok: int = 0
	var nav_fail: int = 0
	var chk_ok: int = 0
	var chk_fail: int = 0

	## Conferência pontual (Onda 3): imprime e conta.
	func _check(ok: bool, what: String) -> void:
		if ok:
			chk_ok += 1
		else:
			chk_fail += 1
		print("UX CHECK %s: %s" % ["OK" if ok else "FALHA", what])

	func _caption_bar() -> Node:
		for c in Gnosis.get_children():
			if c is CaptionBar:
				return c
		return null

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		DirAccess.make_dir_recursive_absolute(out_dir)
		_run.call_deferred()

	func wait(seconds: float = 0.5) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func shot(name: String) -> void:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join("ux_" + name + ".png"))
		print("UX SHOT: ", name)

	func _process(_d: float) -> void:
		if not auto_finish:
			return
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)     # escolha padrão (ex.: "Recusar")
				else:
					c._finish()

	## Simula um aperto (controle OU teclado) de uma ação de UI.
	func press(action: String, pad: bool = true) -> void:
		var ev: InputEvent
		if pad:
			var jb := InputEventJoypadButton.new()
			jb.button_index = {"ui_down": JOY_BUTTON_DPAD_DOWN, "ui_up": JOY_BUTTON_DPAD_UP,
				"ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT,
				"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B}.get(action, JOY_BUTTON_A)
			jb.pressed = true
			ev = jb
		else:
			var k := InputEventKey.new()
			k.keycode = {"ui_down": KEY_DOWN, "ui_up": KEY_UP, "ui_left": KEY_LEFT,
				"ui_right": KEY_RIGHT, "ui_accept": KEY_ENTER, "ui_cancel": KEY_ESCAPE}.get(action, KEY_ENTER)
			k.physical_keycode = k.keycode
			k.pressed = true
			ev = k
		Input.parse_input_event(ev)
		await get_tree().process_frame
		var up = ev.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await get_tree().process_frame
		await get_tree().process_frame

	## Confere foco + que o D-pad (controle) e a seta (teclado) movem o foco.
	func nav_check(screen: String, dir: String = "ui_down") -> void:
		await wait(0.15)
		var vp := get_viewport()
		var a: Control = vp.gui_get_focus_owner()
		if a == null:
			nav_fail += 1
			print("NAV FALHA: ", screen, " — sem foco ao abrir")
			return
		# ida pelo D-pad do controle, volta pela seta oposta do teclado
		await press(dir, true)
		var b: Control = vp.gui_get_focus_owner()
		var back: String = {"ui_down": "ui_up", "ui_right": "ui_left", "ui_left": "ui_right", "ui_up": "ui_down"}[dir]
		await press(back, false)
		var c: Control = vp.gui_get_focus_owner()
		if b != null and b != a and c == a:
			nav_ok += 1
			print("NAV OK: ", screen, "  [", _txt(a), " -> pad -> ", _txt(b), " -> teclado -> ", _txt(c), "]")
		else:
			nav_fail += 1
			print("NAV FALHA: ", screen, "  [", _txt(a), " -> pad -> ", _txt(b), " -> teclado -> ", _txt(c), "]")

	func _txt(c: Control) -> String:
		if c == null:
			return "(nada)"
		if c is Button:
			return "'%s'" % c.text
		return String(c.name)

	func _run() -> void:
		# 1. Menu sem save
		RunManager.saved_run = {}
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		await wait(2.6)                      # 1ª tela: deixa a entrada escalonada terminar
		await shot("menu_sem_save")
		await nav_check("menu")
		# 2. Menu com save + aviso de save antigo descartado
		RunManager.saved_run = {"screen": 29, "difficulty": 1}
		SaveManager.notice = "Um progresso de versão anterior foi descartado (o mapa mudou). Faíscas totais, finais e opções foram preservados."
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		await wait(1.4)
		await shot("menu_com_save")
		# 3. Confirmação de nova campanha
		var menu = get_tree().current_scene
		menu._on_new_campaign()
		await wait(0.5)
		await shot("menu_confirma")
		await nav_check("confirmacao", "ui_left")
		# 4. Pré-jogo
		get_tree().change_scene_to_file("res://scenes/ui/PreGame.tscn")
		await wait(1.0)
		await shot("pregame")
		await nav_check("pregame")
		# 5. Golpes a partir do pré-jogo (arma nível 1 = quase tudo trancado)
		var pg = get_tree().current_scene
		pg._open_moves()
		await wait(0.5)
		await shot("moves_nv1")
		# 6. Opções (tela cheia)
		get_tree().change_scene_to_file("res://scenes/ui/OptionsMenu.tscn")
		await wait(1.0)
		await shot("options")
		await nav_check("opcoes")
		# 7. Ateliê
		get_tree().change_scene_to_file("res://scenes/ui/CharacterAtelier.tscn")
		await wait(1.0)
		await shot("atelie")
		await nav_check("atelie")
		# 8. Bestiário
		get_tree().change_scene_to_file("res://scenes/ui/Gallery.tscn")
		await wait(1.0)
		await shot("bestiario")
		# 9. Crônicas (com 3 lidas + a mais longa, nag_hammadi)
		for e in Gnosis.entries().slice(0, 3):
			if not Gnosis.is_unlocked(String(e.id)):
				Gnosis.unlocked.append(String(e.id))
		if not Gnosis.is_unlocked("nag_hammadi"):
			Gnosis.unlocked.append("nag_hammadi")
		get_tree().change_scene_to_file("res://scenes/ui/Chronicles.tscn")
		await wait(1.0)
		await shot("cronicas")
		var chr = get_tree().current_scene
		if chr != null and chr.has_method("_move"):
			for k in 9:
				chr._move(1)
			await wait(0.3)
			await shot("cronicas_longa")
			chr._move(1)
			await wait(0.2)
			await shot("cronicas_trancada")
		# 9b. Painel de leitura da Estela com o afresco (Onda 3): curta e a mais longa.
		for sid in ["monada", "nag_hammadi"]:
			var ent: Dictionary = {}
			for e in Gnosis.STELAS:
				if String(e.id) == sid:
					ent = e
			var sp := Stela.StelaPanel.new()
			sp.entry = ent
			get_tree().root.add_child(sp)
			await wait(0.4)
			await shot("estela_" + sid)
			_check(Stela.art_for(sid) != null, "Estela %s tem afresco" % sid)
			PauseStack.pop(sp)
			sp.queue_free()
			await wait(0.1)
		# 10. Créditos (se existir)
		if ResourceLoader.exists("res://scenes/ui/Credits.tscn"):
			get_tree().change_scene_to_file("res://scenes/ui/Credits.tscn")
			await wait(1.2)
			await shot("creditos")
			var cr = get_tree().current_scene
			cr._y = -420.0
			cr._hold = 30.0
			await wait(0.3)
			await shot("creditos_atribuicao")
		# 11. Fim de jogo — vitória
		GameManager.end_title = "ASCENSÃO"
		GameManager.end_subtitle = "Sophia atravessa o véu. O Kenoma fica pra trás — e a luz que ela carregava volta pra Fonte, inteira."
		Narrative.ending = "ascensao"
		GameManager.current_screen = 68
		get_tree().change_scene_to_file("res://scenes/ui/EndScreen.tscn")
		await wait(1.2)
		await shot("end_vitoria")
		await nav_check("fim", "ui_left")
		# 12. Fim de jogo — derrota fora de run (rara)
		Narrative.ending = ""
		GameManager.end_title = "Você caiu no Kenoma"
		GameManager.end_subtitle = "Chegou até a Tela 23."
		GameManager.current_screen = 23
		get_tree().change_scene_to_file("res://scenes/ui/EndScreen.tscn")
		await wait(1.2)
		await shot("end_derrota")
		# 13. HUD numa travessia (tela 12 = Fome · Travessia I) com arma 3 e 2 Anéis
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		RunManager.current_screen = 12
		GameManager.current_screen = 12
		Progression.weapon_level = 3
		Progression.orbs = 245
		var rs: Array = GameContent.ring_skills(GameContent.characters[0])
		Progression.add_ring(rs[0].ring, rs[0].id)
		Progression.add_ring(rs[1].ring, rs[1].id)
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(1.6)
		await shot("hud")
		# 13b. Dano na Sophia (barra fantasma visível logo após o golpe)
		var pl := get_tree().get_first_node_in_group("player")
		if pl != null and pl.health != null:
			pl.health.take_damage(int(pl.health.max_health * 0.35))
			await wait(0.15)
			await shot("hud_dano")
		# 14. Diálogo (máquina de escrever no meio, depois completo)
		auto_finish = false
		var d := DialogueBox.play(Narrative.intro())
		await wait(0.4)
		await shot("dialogo_digitando")
		if d.has_method("reveal_all"):
			d.reveal_all()
		await wait(0.25)
		await shot("dialogo")
		# C2 (Onda 3): com a caixa aberta, a dica de controle do HUD some.
		var hud_d := get_tree().get_first_node_in_group("hud")
		if hud_d != null and hud_d.has_method("hint_alpha"):
			await wait(0.3)
			var ha: float = hud_d.hint_alpha()
			_check(ha < 0.05, "C2 dica escondida com diálogo (alpha %.2f)" % ha)
		await press("ui_accept", true)       # avança (texto já completo)
		await wait(0.2)
		if is_instance_valid(d):
			d._finish()
		# 14a. Retratos por emoção (Onda 3): campo `mood` da fala.
		var moods := [["Sophia", "choque", "...Não."], ["Yaldabaoth", "revelado", "Agora vês o que eu sou."],
			["Soter", "triste", "Eu também esqueci, um dia."], ["Velkar", "arrependido", "Eu servi a mentira."]]
		for mi in moods.size():
			var md := DialogueBox.play([{"speaker": moods[mi][0], "text": moods[mi][2], "mood": moods[mi][1]}])
			await wait(0.3)
			md.reveal_all()
			await wait(0.15)
			var want: String = DialogueBox.portrait_for(moods[mi][0], moods[mi][1]).resource_path
			_check(md._portrait != null and md._portrait.resource_path == want and want.contains(String(moods[mi][1])),
				"mood %s/%s → %s" % [moods[mi][0], moods[mi][1], want])
			if mi == 0 or mi == 1:
				await shot("dialogo_mood_%d" % mi)
			md._finish()
			await wait(0.2)
		var neutral: Texture2D = DialogueBox.portrait_for("Sophia")
		_check(neutral != null and neutral.resource_path.ends_with("sophia_neutra.png"), "sem mood → neutra")
		# 14b. Diálogo com escolha
		var dc := DialogueBox.play([{"speaker": "Yaldabaoth", "text": "Curve-se, e eu te devolvo o sono."}], ["Recusar", "Ceder"])
		await wait(0.3)
		if dc.has_method("reveal_all"):
			dc.reveal_all()
		await wait(0.1)
		await press("ui_accept", true)
		await wait(0.3)
		await shot("dialogo_escolha")
		await nav_check("escolha", "ui_right")
		if is_instance_valid(dc):
			dc._finish()
		auto_finish = true
		await wait(0.3)
		# 15. Legenda de caminhada
		Gnosis.caption("A Voz", "Tudo aqui foi feito para que você esqueça. Lembre-se do que arde.")
		await wait(1.2)
		await shot("legenda")
		# 16. Pausa
		var lv = get_tree().current_scene
		var pause = SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		GameManager.set_state(GameManager.State.PAUSED)
		await wait(0.5)
		await shot("pause")
		await nav_check("pausa")
		# 17. Pausa → Golpes (arma 3, 2 Anéis)
		pause._open_moves()
		await wait(0.5)
		await shot("moves_nv3")
		for c in pause.get_children():
			if c is MovesScreen:
				c._scroll.scroll_vertical = 100000
				await wait(0.2)
				await shot("moves_fim")
				c.close()
		await wait(0.3)
		# 18. Pausa → Opções (overlay)
		pause._open_options()
		await wait(0.5)
		await shot("pause_options")
		for c in pause.get_children():
			if c.has_method("_back") and "overlay" in c:
				c._back()
		await wait(0.3)
		# 19. Pausa → Melhorias (loja)
		Progression.add_orbs(37)             # H2: faíscas mudam com a árvore pausada
		pause._open_upgrades()
		await wait(0.5)
		await shot("pause_loja")
		var hud_l := get_tree().get_first_node_in_group("hud")
		if hud_l != null:
			_check(int(round(hud_l.sparks_shown)) == Progression.orbs, "H2 faíscas do HUD atrás da loja = %d (HUD %d)" % [Progression.orbs, int(round(hud_l.sparks_shown))])
		await nav_check("loja")
		for c in lv.get_children():
			if c is CanvasLayer and c.has_method("_close") and c != pause:
				c._close()
		await wait(0.3)
		# 20. Pausa → Abandonar (confirmação)
		pause._ask_quit()
		await wait(0.5)
		await shot("pause_abandonar")
		# 21. HUD com os Anéis ROUBADOS (tela 52, depois do Rei) — 1 caco devolvido
		get_tree().paused = false
		pause.queue_free()
		for i in range(2, rs.size()):
			Progression.add_ring(rs[i].ring, rs[i].id)
		Progression.steal_rings()
		Progression.restore_ring(rs[0].ring)
		Progression.weapon_level = 5
		RunManager.current_screen = 52
		GameManager.current_screen = 52
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(1.6)
		await shot("hud_roubados")
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("detach_ring"):
			Progression.rings_stolen = false
			Progression.rings_changed.emit()
			await wait(0.3)
			hud.detach_ring(3)
			await wait(0.3)
			await shot("hud_anel_saindo")
		# 22. HUD do Arconte (tela 10) — fase 1 e fase 2
		Progression.reset_run()
		RunManager.current_screen = 10
		GameManager.current_screen = 10
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		var boss: Node = null
		for _i in 40:                        # leva a Sophia até a arena e espera o Arconte
			await wait(0.15)
			var lvb = get_tree().current_scene
			if lvb is Level and lvb.player != null and not lvb.zone_active and lvb.zones.size() > 0:
				lvb.player.global_position = Vector2(lvb.zone_center(0) - Level.ZONE_TRIGGER + 8.0, 250.0)
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.is_boss_enemy:
					boss = e
			if boss != null:
				break
		await wait(4.5)                      # deixa a apresentação do Arconte terminar
		await shot("hud_arconte")
		var plb := get_tree().get_first_node_in_group("player")
		if boss != null and plb != null:
			boss._on_hit_received(int(boss.health.max_health * 0.55), plb.global_position, 10.0, false, null)
		await wait(0.35)
		await shot("hud_arconte_fase2")
		await wait(1.4)
		await shot("hud_arconte_fase2b")
		# M1 (Onda 3): legenda durante a luta de chefe — fica no topo, longe dos pés.
		Gnosis.caption("Sophia", "Ele lê o que eu vou fazer antes de mim. Então não pense: lembre.")
		await wait(1.4)
		await shot("hud_arconte_legenda")
		var cb := _caption_bar()
		if cb != null and cb.has_method("band_rect"):
			var br: Rect2 = cb.band_rect()
			_check(br.end.y < 150.0, "M1 legenda no topo (faixa %s)" % str(br))
		var hud_t := get_tree().get_first_node_in_group("hud")
		if hud_t != null:
			hud_t.toast("Crônica desbloqueada: A Mônada, o Inefável  (1/18)")
			await wait(0.6)
			await shot("legenda_toast")
			# Toast de conquista (Achievements.unlocked) entra na FILA atrás da Crônica.
			var ach := get_node_or_null("/root/Achievements")
			if ach != null and AchievementData.LIST.size() > 0:
				var aid := String(AchievementData.LIST[0].id)
				ach.emit_signal("unlocked", aid)
				await wait(3.2)
				await shot("toast_conquista")
				_check(String(hud_t._toast_label.text).begins_with("Conquista"), "toast de conquista [%s]" % hud_t._toast_label.text)
			# Vinheta de vida baixa + batimento (Audio.low_health_pulse)
			var plv := get_tree().get_first_node_in_group("player")
			if plv != null and plv.health != null:
				plv.health.take_damage(int(plv.health.current_health - plv.health.max_health * 0.12))
				await wait(1.4)
				await shot("hud_vida_baixa")
				_check(hud_t._low_beat >= 0, "vinheta de vida baixa bate o coração (pulso %d)" % hud_t._low_beat)
		# 23. Provação: resultado final (vitória no 3º encontro)
		CodexSession.start_demo()
		await wait(2.5)
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)
		await wait(0.2)
		await shot("hud_provacao")
		# P3 (Onda 3): último input do controle → faixa com os botões do controle.
		InputGlyphs.set_device(InputGlyphs.Device.XBOX)
		await wait(0.2)
		await shot("hud_provacao_pad")
		var trp = get_tree().current_scene
		if trp != null and "hint_label" in trp and trp.hint_label != null:
			var ht: String = trp.hint_label.text
			_check(ht.contains("LB") or ht.contains("RB"), "P3 Provação com controle [%s]" % ht)
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)
		CodexSession.stage = 2
		var trial = get_tree().current_scene
		trial.completed = true
		trial._show_result(true)
		await wait(0.5)
		await shot("provacao_final")
		get_tree().paused = false
		print("UX NAV: %d ok, %d falha(s)" % [nav_ok, nav_fail])
		print("UX CHECK: %d ok, %d falha(s)" % [chk_ok, chk_fail])
		print("UX SHOTS: fim")
		get_tree().quit()
