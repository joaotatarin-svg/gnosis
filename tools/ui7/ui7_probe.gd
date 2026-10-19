extends Node
## SONDA DO UI7 (não faz parte do jogo): reproduz e fotografa os bugs de UI/idioma
## do QA7 (#4 #6 #7 #14 #16 #17 #23 #24 #27 #30) e confere o que dá para medir.
## Captura SEM janela grande: a raiz passa a renderizar em 640×360 (modo viewport)
## numa janela mínima de 320×180 fora do monitor; a foto sai na resolução base.
## Uso (idioma pelo ambiente — GNOSIS_LANG=en|pt):
##   GNOSIS_LANG=en godot --audio-driver Dummy --path . --resolution 320x180 --position 4000,4000 \
##       res://tools/ui7/UI7Probe.tscn -- <pasta> [casos] --bestiario-tudo
##   casos: lista com vírgula (gallery,moves,seal,shop,credits,dialog,stela,card,hud) — padrão: todos.
## Saída: linhas "UI7|..." no console; "UI7|FALHA" quando uma checagem não passa.

func _ready() -> void:
	var w := P.new()
	var a := OS.get_cmdline_user_args()
	w.out_dir = a[0] if a.size() > 0 else "user://"
	if a.size() > 1 and not String(a[1]).begins_with("--"):
		w.only = String(a[1]).split(",")
	get_tree().root.add_child.call_deferred(w)


class P extends Node:
	var out_dir: String
	var only: PackedStringArray = []
	var fails: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		var win := get_tree().root
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		win.content_scale_size = Vector2i(640, 360)
		_run.call_deferred()

	func want(c: String) -> bool:
		return only.is_empty() or only.has(c)

	func check(ok: bool, what: String) -> void:
		print("UI7|", "OK  " if ok else "FALHA ", what)
		if not ok:
			fails += 1

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func lang() -> String:
		return "en" if I18n.is_en() else "pt"

	func shot(name: String) -> void:
		if DisplayServer.get_name() == "headless":
			print("UI7|SHOT|(headless) ", name)
			return
		await RenderingServer.frame_post_draw
		var p := "%s/%s_%s.png" % [out_dir, lang(), name]
		get_viewport().get_texture().get_image().save_png(p)
		print("UI7|SHOT|", p)

	func dialogs() -> Array:
		var out := []
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				out.append(c)
		return out

	func skip_dialogs() -> void:
		for i in 60:
			var ds := dialogs()
			if ds.is_empty():
				return
			(ds[0] as DialogueBox)._finish()
			await wait(0.1)

	func level_at(screen: int) -> Level:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(0.9)
		await skip_dialogs()
		await wait(0.3)
		await skip_dialogs()
		return get_tree().current_scene as Level

	func open_scene(path: String) -> Node:
		get_tree().change_scene_to_file(path)
		await wait(0.7)
		return get_tree().current_scene

	func kill_enemies() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e):
				e.queue_free()

	func _run() -> void:
		print("UI7|lang=", lang(), " locale=", TranslationServer.get_locale())
		if want("gallery"):
			await _gallery()
		if want("moves"):
			await _moves()
		if want("shop"):
			await _shop()
		if want("credits"):
			await _credits()
		if want("dialog"):
			await _dialog()
		if want("seal"):
			await _seal()
		if want("stela"):
			await _stela()
		if want("card"):
			await _card()
		if want("hud"):
			await _hud()
		if want("numbers"):
			await _numbers()
		print("UI7|FIM falhas=", fails)
		get_tree().quit(0 if fails == 0 else 1)

	# --- #4 bestiário: lore traduzido -----------------------------------------------
	func _gallery() -> void:
		var g = await open_scene("res://scenes/ui/Gallery.tscn")
		var idx := -1
		for i in g.entries.size():
			var id := String(g.entries[i].id)
			if id != "sophia" and BestiaryLore.lore(id).size() >= 2:
				idx = i
				break
		g._selected = -1
		g._show(idx)
		await wait(0.2)
		var lore := String(g._lore.text)
		print("UI7|gallery|id=", g.entries[idx].id, " lore=", lore.replace("\n", " / "))
		if I18n.is_en():
			var pt0 := String(BestiaryLore.lore(String(g.entries[idx].id))[0])
			check(not lore.contains(pt0), "#4 bestiário EN sem a linha em português")
		await shot("gallery")

	# --- #7 golpes & controles: glifos sem mistura --------------------------------------
	func _moves() -> void:
		await level_at(4)
		InputGlyphs.set_device(InputGlyphs.Device.PLAYSTATION)
		Progression.weapon_level = 5
		PauseStack.push(self)            # como no jogo: aberta pela pausa
		var m := MovesScreen.open(get_tree().root)
		await wait(0.5)
		var mixed := false
		for l in m.find_children("*", "Label", true, false):
			var t := String((l as Label).text)
			var shown := t if (l as Label).auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED else I18n.t(t)
			if I18n.is_en() and (shown.contains("Quadrado") or shown.contains("Triângulo")):
				mixed = true
				print("UI7|moves|misturado: ", shown)
		check(not mixed, "#7 Golpes & Controles sem glifo em português no inglês")
		await shot("moves")
		m.queue_free()
		PauseStack.pop(self)
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)
		await wait(0.2)

	# --- #16 loja: "abre:" traduzido --------------------------------------------------
	func _shop() -> void:
		await level_at(4)
		Progression.orbs = 999
		var shop := SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
		await wait(0.6)
		await shot("shop")
		if shop != null and is_instance_valid(shop):
			shop.queue_free()
		PauseStack.clear()
		await wait(0.2)

	# --- #16 créditos: sem trechos em português no inglês ---------------------------------
	func _credits() -> void:
		var c = await open_scene("res://scenes/ui/Credits.tscn")
		var pt_left := []
		for l in c._roll.get_children():
			if l is Label:
				var t := String((l as Label).text)
				for w in ["autores", "feitas para", "anônimo", "multi-licença", "Ambiências", "colaboradores"]:
					if t.contains(w):
						pt_left.append(t)
		if I18n.is_en():
			check(pt_left.is_empty(), "#16 Créditos EN sem trecho em português %s" % [pt_left])
		for y in [-330.0, -560.0]:
			c._y = y
			c._hold = 99.0
			c._roll.position.y = y
			await wait(0.2)
			await shot("credits_%d" % int(-y))

	# --- #14 caixa de diálogo não sobrevive à troca de cena --------------------------------
	func _dialog() -> void:
		await level_at(4)
		DialogueBox.play([{"speaker": "A Voz", "text": "O Éon do Torpor. Aqui os mortos não sabem que morreram."}])
		await wait(0.6)
		check(dialogs().size() == 1, "#14 caixa aberta na tela 4")
		get_tree().change_scene_to_file("res://scenes/ui/Chronicles.tscn")
		await wait(0.8)
		check(dialogs().is_empty(), "#14 caixa fechou com a troca de cena (Crônicas)")
		check(not get_tree().paused, "#14 mundo despausado depois da troca")
		await shot("dialog_cronicas")
		await level_at(4)
		DialogueBox.play([{"speaker": "A Voz", "text": "Teste da Galeria."}])
		await wait(0.5)
		get_tree().change_scene_to_file("res://scenes/ui/Gallery.tscn")
		await wait(0.8)
		check(dialogs().is_empty(), "#14 caixa fechou com a troca de cena (Galeria)")
		await shot("dialog_galeria")

	# --- #6 placa dos Selos --------------------------------------------------------------
	func _seal() -> void:
		var lv := await level_at(3)
		kill_enemies()
		var sp: SealPuzzle = null
		for c in lv.get_children():
			if c is SealPuzzle:
				sp = c
		if sp == null:
			sp = SealPuzzle.new()
			sp.screen = 3
			lv.add_child(sp)
			sp.global_position = lv.player.global_position + Vector2(160, 0)
		lv.player.global_position = sp.global_position + Vector2(-150, 0)
		await wait(0.6)
		var shown := I18n.t(String(sp._hint.text))
		print("UI7|seal|placa=", shown.replace("\n", " / "))
		if I18n.is_en():
			check(not shown.contains("golpeie"), "#6 placa dos Selos traduzida")
		await shot("seal")

	# --- #30 Estela: pausa e não empilha no centro -------------------------------------------
	func _stela() -> void:
		var lv := await level_at(3)
		kill_enemies()
		await wait(0.3)
		var st: Stela = null
		for c in lv.get_children():
			if c is Stela:
				st = c
		if st == null:
			check(false, "#30 tela 3 sem Estela")
			return
		lv.player.global_position = st.global_position + Vector2(-40, -10)
		await wait(0.5)
		# o pior caso do QA: legenda + zona limpa ("Siga em frente") + convite da Estela
		Gnosis.caption("A Voz", "Vês? Os que dormem não sofrem. Quem acorda, sim. Mas só quem acorda sobe.")
		get_tree().call_group("hud", "toast", "Siga em frente  →")
		await wait(0.9)
		await shot("stela_pilha")
		var hud = get_tree().get_first_node_in_group("hud")
		var tst: Array = hud.toast_state()
		check(not (String(tst[0]).begins_with("Siga") and float(tst[1]) > 0.1), "#30 'Siga em frente' não é toast no centro")
		check(hud.has_method("go_alpha") and hud.go_alpha() > 0.1, "#30 seta 'Siga em frente' na borda direita")
		# painel: pausa o mundo pelo PauseStack
		var pl := lv.player
		st.open()
		await wait(0.4)
		check(get_tree().paused and PauseStack.is_held(), "#30 painel da Estela pausa o mundo (PauseStack)")
		var p0: Vector2 = pl.global_position
		pl.velocity = Vector2(300, 0)
		await wait(0.5)
		check(pl.global_position.distance_to(p0) < 0.5, "#30 Sophia parada com o painel aberto")
		await shot("stela_painel")
		var ev := InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = true
		Input.parse_input_event(ev)
		await wait(0.4)
		check(not get_tree().paused, "#30 painel fechado despausa")

	# --- #17/#23 card de chefe legível ------------------------------------------------------
	func _card() -> void:
		var lv := await level_at(68)
		await wait(0.8)
		await skip_dialogs()
		for c in get_tree().root.get_children():
			if c is Cinematic:
				c.queue_free()
		await wait(0.3)
		Cinematic.boss_card("YALDABAOTH", String(Gnosis.BOSS_TITLES["demiurgo"].title))
		await wait(0.75)
		await shot("card_68")
		await wait(2.0)
		await skip_dialogs()
		lv = await level_at(15)
		await skip_dialogs()
		for c in get_tree().root.get_children():
			if c is Cinematic:
				c.queue_free()
		await wait(0.3)
		Gnosis.boss_card("campeao", 15)
		await wait(0.75)
		await shot("card_campeao_15")
		await wait(2.0)

	# --- #24 HUD com chefe; #27 dica com o controle ---------------------------------------------
	func _hud() -> void:
		var lv := await level_at(68)
		for i in 8:
			await skip_dialogs()
			for c in get_tree().root.get_children():
				if c is Cinematic:
					c._finish()
			await wait(0.4)
		await wait(1.0)
		await shot("hud_68")
		var hud = get_tree().get_first_node_in_group("hud")
		InputGlyphs.set_device(InputGlyphs.Device.PLAYSTATION)
		hud.show_hint_now([{"keys": ["ring_prev", "ring_next"], "text": "trocar de Anel"}])
		await wait(0.6)
		await shot("hud_dica_ps")
		InputGlyphs.set_device(InputGlyphs.Device.XBOX)
		hud.show_hint_now([{"keys": [], "text": "telégrafo amarelo:"}, {"keys": ["block"], "text": "apara"}, {"keys": ["ring_prev"], "text": "anel"}])
		await wait(0.6)
		await shot("hud_dica_xbox")
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)

	# --- R16 números de dano: soma no mesmo alvo, teto de 6, pop ------------------------------
	func _numbers() -> void:
		var lv := await level_at(4)
		kill_enemies()
		await wait(0.3)
		var at: Vector2 = lv.player.global_position + Vector2(80, 0)
		for i in 5:
			DamageNumber.spawn(lv, at + Vector2(i * 4, 0), 12, Color(1.0, 0.92, 0.6))
			await wait(0.05)
		var ns := get_tree().get_nodes_in_group("damage_number").filter(func(n): return not n.is_queued_for_deletion())
		check(ns.size() == 1 and int(ns[0].value) == 60, "R16 5 acertos rápidos no mesmo alvo = 1 número (%d nós, valor %s)" % [ns.size(), str(ns[0].value) if ns.size() > 0 else "-"])
		await shot("numeros_soma")
		await wait(1.0)
		for i in 10:
			DamageNumber.spawn(lv, at + Vector2(-200 + i * 45, 0), 20, Color(1.0, 0.92, 0.6))
		await wait(0.05)
		ns = get_tree().get_nodes_in_group("damage_number").filter(func(n): return not n.is_queued_for_deletion())
		check(ns.size() <= 6, "R16 no máximo 6 números vivos (%d)" % ns.size())
		await shot("numeros_teto")
