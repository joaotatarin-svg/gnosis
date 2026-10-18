extends Node
## FERRAMENTA (não faz parte do jogo) — UI Onda 6: fotografa e CONFERE os pedidos
## dos outros diretores à UI:
##   chefe3     barra de chefe com um marcador por limiar (`phase_marks`) e "FASE III"
##   dica       show_hint_now (narrativa): fura a fila, não encurta ao apertar
##   reliquia   emblema da relíquia em uso no HUD + linha na pausa (progressao6)
##   selo       "Selo aberto · …" quando um Arconte cai e o grau sobe (progressao6)
##   objetivo   ícone do objetivo da zona (level6: totem / proteger / maré)
##   titulo     tipo do nó do mapa no título da tela (mapa6: "Fome · Arena")
##   mapa       botão Mapa na pausa → WorldMap em modo leitura; navegação da pausa
##   retratos   O Cego (4 humores) e o Rei revelado na DialogueBox
## Uso: godot --path . --audio-driver Dummy --resolution 1280x720 --position 4000,4000 \
##        res://tools/UxShots6.tscn -- <pasta_saida> [caso ...]
## Headless (só as conferências): godot --headless --audio-driver Dummy --path . res://tools/UxShots6.tscn -- <pasta>
## Imprime "UX6 CHECK OK/FALHA" e "UX6 RESULT: N ok, M falha(s)". Código antigo
## (capturas "antes"): tudo novo é via has_method/get — as conferências falham, as fotos saem.

func _ready() -> void:
	var w := Worker.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.out_dir = args[0]
	for i in range(1, args.size()):
		w.cases.append(String(args[i]))
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var out_dir: String = "res://shots"
	var cases: Array = []
	var ok_n: int = 0
	var fail_n: int = 0
	var auto_finish: bool = true

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		AudioServer.set_bus_mute(0, true)
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		DirAccess.make_dir_recursive_absolute(out_dir)
		_run.call_deferred()

	func _want(c: String) -> bool:
		return cases.is_empty() or cases.has(c)

	func _check(ok: bool, what: String) -> void:
		if ok:
			ok_n += 1
		else:
			fail_n += 1
		print("UX6 CHECK %s: %s" % ["OK" if ok else "FALHA", what])

	func wait(seconds: float = 0.5) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func shot(name: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join("ux6_" + name + ".png"))
		print("UX6 SHOT: ", name)

	func _process(_d: float) -> void:
		if not auto_finish:
			return
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()

	func _hud() -> Node:
		return get_tree().get_first_node_in_group("hud")

	## RunLabels (Onda 6) sem citar a classe: a ferramenta compila na base antiga.
	func _rl():
		var p := "res://scripts/ui/run_labels.gd"
		return load(p) if ResourceLoader.exists(p) else null

	func _q(n: Object, m: String, args: Array = []) -> Variant:
		if n == null or not n.has_method(m):
			return null
		return n.callv(m, args)

	func _focus() -> Control:
		return get_viewport().gui_get_focus_owner()

	func act(action: String) -> void:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = true
		Input.parse_input_event(e)
		await frames(2)
		var r := InputEventAction.new()
		r.action = action
		r.pressed = false
		Input.parse_input_event(r)
		await frames(2)

	func pad(btn: JoyButton) -> void:
		var e := InputEventJoypadButton.new()
		e.button_index = btn
		e.pressed = true
		Input.parse_input_event(e)
		await frames(2)
		var r := InputEventJoypadButton.new()
		r.button_index = btn
		r.pressed = false
		Input.parse_input_event(r)
		await frames(2)

	func _start_screen(sc: int, rings: int = 0) -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		if "map_route_seed" in RunManager:
			RunManager.set("map_route_seed", 0)     # rota do meio, sem tela de mapa
		RunManager.current_screen = sc
		GameManager.current_screen = sc
		Progression.weapon_level = 3
		var rs: Array = GameContent.ring_skills(GameContent.characters[0])
		for i in mini(rings, rs.size()):
			Progression.add_ring(rs[i].ring, rs[i].id)
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")

	func _clear_enemies() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()

	func _run() -> void:
		_start_screen(12, 1)
		await wait(1.2)
		_clear_enemies()
		if _want("titulo"):
			await _case_titulo()
		if _want("chefe3"):
			await _case_chefe3()
		if _want("dica"):
			await _case_dica()
		if _want("reliquia"):
			await _case_reliquia()
		if _want("objetivo"):
			await _case_objetivo()
		if _want("selo"):
			await _case_selo()
		if _want("mapa"):
			await _case_mapa()
		if _want("retratos"):
			await _case_retratos()
		get_tree().paused = false
		PauseStack.clear()
		print("UX6 RESULT: %d ok, %d falha(s)" % [ok_n, fail_n])
		get_tree().quit()

	# --- mapa6: tipo do nó no título ------------------------------------------------
	func _case_titulo() -> void:
		var h := _hud()
		var found := 0
		if RunManager.has_method("node_kind"):
			for s in range(RunManager.FIRST_EON_SCREEN, RunManager.LAST_ARCHON_SCREEN + 1):
				var k := String(RunManager.call("node_kind", s))
				if k in ["hazard", "platform", "sanctuary", "challenge", "secret"]:
					var want := String(RunManager.call("node_title", s))
					var got := String(_rl().role_title(s)) if _rl() != null else ""
					found += 1
					if found <= 2:
						_check(got.ends_with(want) and got.contains(RunManager.eon_name(s)), "título da tela %d (%s) = \"%s\"" % [s, k, got])
		_check(found > 0, "rota do meio tem nós com tipo próprio (%d)" % found)
		var s12 := String(h.call("screen_title")) if h != null else ""
		print("UX6 INFO: título da tela 12 = \"%s\" (tipo %s)" % [s12, String(RunManager.call("node_kind", 12)) if RunManager.has_method("node_kind") else "?"])

	# --- chefes6: 3 fases -------------------------------------------------------------
	func _fake_boss() -> Node2D:
		var scr := GDScript.new()
		scr.source_code = "extends Node2D\nvar phase_marks: Array = [0.66, 0.33]\nvar phase: int = 1\nvar display_name: String = \"Athoth, o Sono que Pesa\"\nvar health: HealthComponent\nvar revivable: bool = false\n"
		scr.reload()
		var b: Node2D = Node2D.new()
		b.set_script(scr)
		var hc := HealthComponent.new()
		b.add_child(hc)
		b.set("health", hc)
		hc.max_health = 1000
		hc.current_health = 1000
		get_tree().current_scene.add_child(b)
		return b

	func _case_chefe3() -> void:
		var h := _hud()
		var b := _fake_boss()
		await frames(2)
		h.call("show_boss", b)
		await wait(0.6)
		var bars: Array = h.call("boss_bars")
		await shot("chefe_fase1")
		var marks: Array = bars[0].get("marks", []) if bars.size() > 0 else []
		_check(marks.size() == 2 and is_equal_approx(float(marks[0]), 0.66), "barra lê phase_marks [0.66, 0.33] (%s)" % str(marks))
		var hc: HealthComponent = b.get("health")
		hc.current_health = 600
		hc.health_changed.emit(600, 1000)
		b.set("phase", 2)
		h.call("boss_phase", 2, b)
		await wait(0.9)
		await shot("chefe_fase2")
		hc.current_health = 250
		hc.health_changed.emit(250, 1000)
		b.set("phase", 3)
		h.call("boss_phase", 3, b)
		await wait(0.3)
		bars = h.call("boss_bars")
		_check(bars.size() > 0 and int(bars[0].phase) == 3, "barra na FASE III (%s)" % (str(bars[0].phase) if bars.size() > 0 else "-"))
		await wait(0.9)
		await shot("chefe_fase3")
		b.queue_free()
		await wait(0.8)

	# --- narrativa6: show_hint_now --------------------------------------------------
	func _case_dica() -> void:
		var h := _hud()
		_check(h.has_method("show_hint_now"), "HUD tem show_hint_now")
		if not h.has_method("show_hint_now"):
			return
		h.set("hints", [])
		h.set("_hint", [])
		h.set("_hint_gap", 0.0)
		h.call("show_hint", [{"keys": ["skill1"], "text": "usar o Anel equipado (gasta Éter)"}])
		await wait(0.4)
		h.call("show_hint_now", [{"keys": ["jump", "jump"], "text": "no ar, pule de novo"}])
		await frames(2)
		var st: Dictionary = h.call("hint_state")
		_check(bool(st.get("forced", false)) and String((st.segs[0] as Dictionary).text) == "no ar, pule de novo", "dica de ensino entra na hora")
		_check((h.get("hints") as Array).size() == 1, "a dica interrompida volta para a fila")
		var t0 := float(st.t)
		await act("jump")
		await wait(0.3)
		st = h.call("hint_state")
		_check(not st.is_empty() and float(st.t) < float(st.dur) - 1.5, "apertar a tecla NÃO encurta a dica de ensino (t %.2f→%.2f de %.1f)" % [t0, float(st.get("t", 0)), float(st.get("dur", 0))])
		await wait(0.4)
		await shot("dica_agora")
		# forma (texto, teclas)
		h.call("show_hint_now", "contra-ataque logo depois de aparar", ["attack_light"])
		await frames(2)
		st = h.call("hint_state")
		_check(String((st.segs[0] as Dictionary).text).begins_with("contra-ataque") and (st.segs[0].keys as Array) == ["attack_light"], "show_hint_now(texto, teclas)")
		h.set("_hint", [])
		h.set("hints", [])

	# --- progressao6: relíquia ------------------------------------------------------
	func _case_reliquia() -> void:
		Progression.orbs = 2000
		var ok := false
		if Progression.has_method("buy_relic"):
			ok = bool(Progression.call("buy_relic", "brasa"))
		_check(ok and (_rl().relic_id() if _rl() != null else "") == "brasa", "relíquia Brasa comprada e em uso")
		var h := _hud()
		await wait(0.2)
		_check(h.get("_relic_pulse") != null and float(h.get("_relic_pulse")) > 0.3, "HUD acende a relíquia ao trocar")
		h.call("spark_orb_arrived", 1)
		await wait(0.1)
		await shot("reliquia_hud")
		var pm := SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		await wait(0.5)
		var rl = pm.find_child("Relic", true, false)
		_check(rl is Label and String(rl.text).contains("Brasa"), "pausa mostra a relíquia em uso (%s)" % (String(rl.text) if rl is Label else "-"))
		var role: Label = pm.find_child("Role", true, false)
		print("UX6 INFO: papel na pausa = \"%s\"" % (role.text if role else "-"))
		await shot("reliquia_pausa")
		pm.call("_resume_game")
		await wait(0.3)

	# --- level6: objetivo -----------------------------------------------------------
	func _case_objetivo() -> void:
		var h := _hud()
		var lv = get_tree().current_scene
		var real: bool = lv != null and lv.has_method("zone_objective")
		print("UX6 INFO: Level.zone_objective %s" % ("existe (level6)" if real else "AUSENTE nesta base — ícone forçado só para a foto"))
		for kind in ["totem", "proteger", "mare"]:
			h.set("_obj_kind", kind)
			h.set("_obj_k", 1.0)
			# sem zona de verdade, o _process apaga devagar: a foto sai logo
			await frames(1)
			await shot("objetivo_" + kind)
		_check(_rl() != null and _rl().objective_text("totem") != "" and _rl().objective_text("ondas") == "", "texto do objetivo por tipo (ondas = nenhum)")
		h.set("_obj_k", 0.0)

	# --- progressao6: selo aberto ---------------------------------------------------
	func _case_selo() -> void:
		var h := _hud()
		var rs: Array = GameContent.ring_skills(GameContent.characters[0])
		var before := int(h.get("_tier_seen")) if h.get("_tier_seen") != null else -1
		Progression.add_ring(rs[1].ring, rs[1].id)        # 2º Arconte cai → grau 2
		await frames(2)
		var q: Array = h.get("_toast_queue")
		var st: Array = h.call("toast_state")
		var all := str(q) + " " + String(st[0])
		await wait(0.6)
		_check(all.contains("Selo aberto"), "aviso \"Selo aberto\" ao subir o grau (%d → %s): %s" % [before, str(h.get("_tier_seen")), all])
		await wait(0.6)
		await shot("selo_aberto")
		await wait(3.0)

	# --- mapa6: Mapa na pausa (modo leitura) + navegação ----------------------------
	func _case_mapa() -> void:
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)
		var screen0 := RunManager.current_screen
		var scene0 = get_tree().current_scene
		var pm := SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		await wait(0.5)
		var mb: Button = pm.find_child("Map", true, false)
		_check(mb != null and mb.visible, "pausa tem o botão Mapa (tela %d)" % screen0)
		if mb == null:
			pm.call("_resume_game")
			return
		# navegação: Melhorias ↓ Mapa ↓ Opções (D-pad) e ↑ volta (teclado)
		var up: Button = pm.find_child("Upgrades", true, false)
		up.disabled = false
		up.grab_focus()
		await frames(2)
		await pad(JOY_BUTTON_DPAD_DOWN)
		_check(_focus() == mb, "pausa: D-pad ↓ de Melhorias vai ao Mapa [%s]" % (_focus().name if _focus() else "-"))
		await pad(JOY_BUTTON_DPAD_DOWN)
		_check(_focus() != null and _focus().name == "Options", "pausa: D-pad ↓ do Mapa vai a Opções [%s]" % (_focus().name if _focus() else "-"))
		await act("ui_up")
		_check(_focus() == mb, "pausa: seta ↑ volta ao Mapa")
		await act("ui_accept")
		await wait(0.6)
		_check(_q(pm, "map_open") == true, "Mapa abre o WorldMap em modo leitura")
		await shot("mapa_leitura")
		await act("ui_down")
		await act("ui_accept")
		await wait(0.4)
		_check(RunManager.current_screen == screen0 and get_tree().current_scene == scene0 and _q(pm, "map_open") == true, "confirmar no mapa NÃO escolhe caminho (tela %d)" % RunManager.current_screen)
		await pad(JOY_BUTTON_B)
		await wait(0.3)
		_check(_q(pm, "map_open") == false and _focus() == mb, "B fecha o mapa e o foco volta ao botão Mapa")
		await shot("mapa_fechado_pausa")
		await act("ui_cancel")
		await wait(0.3)
		_check(not is_instance_valid(pm) or pm.is_queued_for_deletion(), "Esc fecha a pausa depois do mapa")
		await wait(0.2)

	# --- encenação/narrativa: retratos ---------------------------------------------
	func _case_retratos() -> void:
		for m in ["olhando", "assustado", "sereno", "aninhado"]:
			var tex := DialogueBox.portrait_for("O Cego", m)
			_check(tex != null and tex.resource_path.ends_with("cego_%s.png" % m), "retrato O Cego/%s (%s)" % [m, tex.resource_path if tex else "null"])
		var tc := DialogueBox.portrait_for("O Cego", "")
		_check(tc != null and tc.resource_path.ends_with("cego_olhando.png"), "O Cego sem humor = olhando")
		var tr := DialogueBox.portrait_for("Yaldabaoth", "revelado")
		_check(tr != null and tr.resource_path.ends_with("rei_revelado.png"), "Yaldabaoth revelado")
		auto_finish = false
		var d := DialogueBox.play([{"speaker": "O Cego", "text": "...mãe? eu não queria ser cego. eu só queria que alguém olhasse para mim.", "mood": "olhando"}])
		await wait(2.2)
		await shot("retrato_cego")
		d._finish()
		await wait(0.4)
		d = DialogueBox.play([{"speaker": "Yaldabaoth", "text": "Agora você me vê.", "mood": "revelado"}])
		await wait(1.4)
		await shot("retrato_rei_revelado")
		d._finish()
		auto_finish = true
		await wait(0.4)
