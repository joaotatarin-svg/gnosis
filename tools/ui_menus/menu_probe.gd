extends Node
## FERRAMENTA (não faz parte do jogo) — sonda dos MENUS da Onda 2 (agente ui-menus).
## Fotografa e TESTA por input simulado: loja (foco, setas, compra, B fecha,
## sem faíscas), pausa em combate (Melhorias trancada), pilha de pausa,
## B/ui_cancel em todos os menus, repetição das Crônicas, opção "Reduzir
## flashes", Estela × combate (M7), dicas da Provação por dispositivo e Créditos.
## Uso (com janela, para as capturas):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --rendering-driver opengl3 \
##     --path . --resolution 1280x720 res://tools/ui_menus/MenuProbe.tscn -- <pasta_saida> [seção ...]
## Sem capturas (testes de tempo confiáveis — a janela no llvmpipe roda a poucos fps):
##   godot --headless --audio-driver Dummy --path . res://tools/ui_menus/MenuProbe.tscn -- <pasta> [seção ...]
## Seções: glifos loja pausa pilha voltar cronicas opcoes controles estela provacao creditos bestiario demo (padrão: todas)
## + opcoes_provacao (só quando pedida: confere a REVISAO #13, que é do SaveManager/Técnico)
## Imprime "UIM OK: ..." / "UIM FALHA: ..." e no fim "UIM RESULT: N ok, M falha(s)".
## O B do controle em `ui_cancel` (e o A em `ui_accept`) é mapeado AQUI se o
## InputMap ainda não tiver (simula o pedido ao Técnico) — o código dos menus
## só conhece as ações.


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var w := Worker.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.out_dir = args[0]
	for i in range(1, args.size()):
		w.only.append(args[i])
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var out_dir: String = "user://menu_probe"
	var only: Array = []
	var ok: int = 0
	var fail: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		DirAccess.make_dir_recursive_absolute(out_dir)
		_map_pad()
		_run.call_deferred()

	# --- utilidades --------------------------------------------------------------

	func _map_pad() -> void:
		for pair in [["ui_cancel", JOY_BUTTON_B], ["ui_accept", JOY_BUTTON_A]]:
			var has := false
			for ev in InputMap.action_get_events(pair[0]):
				if ev is InputEventJoypadButton and ev.button_index == pair[1]:
					has = true
			if not has:
				var jb := InputEventJoypadButton.new()
				jb.button_index = pair[1]
				InputMap.action_add_event(pair[0], jb)
				print("UIM nota: %s sem botão de controle no InputMap — mapeado só nesta sonda" % pair[0])

	func want(s: String) -> bool:
		return only.is_empty() or only.has(s)

	func check(cond: bool, what: String) -> void:
		if cond:
			ok += 1
			print("UIM OK: ", what)
		else:
			fail += 1
			print("UIM FALHA: ", what)

	func wait(seconds: float = 0.5) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func shot(name: String) -> void:
		if DisplayServer.get_name() == "headless":
			return                  # sem janela: só os testes (rápido; o llvmpipe deixa a janela a ~5 fps)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join(name + ".png"))
		print("UIM SHOT: ", name)

	func frames(n: int = 2) -> void:
		for _i in n:
			await get_tree().process_frame

	## Botão do controle (aperta e solta).
	func pad(button: int) -> void:
		var jb := InputEventJoypadButton.new()
		jb.button_index = button
		jb.pressed = true
		Input.parse_input_event(jb)
		await frames(1)
		var up := jb.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await frames(2)

	func key(code: int) -> void:
		var k := InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.pressed = true
		Input.parse_input_event(k)
		await frames(1)
		var up := k.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		await frames(2)

	func action(name: String, pressed: bool) -> void:
		var a := InputEventAction.new()
		a.action = name
		a.pressed = pressed
		Input.parse_input_event(a)

	func focus() -> Control:
		return get_viewport().gui_get_focus_owner()

	func txt(c: Control) -> String:
		if c == null:
			return "(nada)"
		if c is Button:
			return "'%s'" % String(c.text).replace("\n", " ").strip_edges()
		return String(c.name)

	func scene_path() -> String:
		var s := get_tree().current_scene
		return s.scene_file_path if s != null else ""

	func go(path: String, secs: float = 1.0) -> void:
		PauseStack.clear()
		get_tree().change_scene_to_file(path)
		await wait(secs)

	func level_at(screen: int) -> Level:
		PauseStack.clear()
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(1.0)
		await skip_dialogs()
		await wait(0.3)
		return get_tree().current_scene as Level

	func skip_dialogs() -> void:
		for _i in 30:
			var found := false
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					found = true
					if c.choices.size() > 0:
						c._on_choice(0)
					else:
						c._finish()
			if not found:
				return
			await wait(0.15)

	func living_enemies() -> Array:
		var out: Array = []
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.get("health") != null and not e.health.is_dead():
				out.append(e)
		return out

	func overlay_of(path_part: String) -> Node:
		var cs := get_tree().current_scene
		if cs == null:
			return null
		for c in cs.get_children():
			if c.scene_file_path.contains(path_part):
				return c
		return null

	func labels_text(root: Node) -> String:
		var parts: PackedStringArray = []
		for n in root.find_children("*", "Label", true, false):
			parts.append(String(n.text))
		return "\n".join(parts)

	# --- roteiro -----------------------------------------------------------------

	func _run() -> void:
		if want("glifos"):
			await _glyphs()
		if want("loja"):
			await _shop()
		if want("pausa"):
			await _pause_combat()
		if want("pilha"):
			await _pause_stack()
		if want("voltar"):
			await _back_everywhere()
		if want("cronicas"):
			await _chronicles()
		if want("opcoes"):
			await _options()
		if want("controles"):
			await _controls()
		if want("estela"):
			await _stela()
		if want("provacao"):
			await _trial()
		if only.has("opcoes_provacao"):    # só a pedido: depende do SaveManager do Técnico
			await _options_in_trial()
		if want("creditos"):
			await _credits()
		if want("bestiario"):
			await _bestiary()
		if want("demo"):
			await _demo_end()
		PauseStack.clear()
		print("UIM RESULT: %d ok, %d falha(s)" % [ok, fail])
		get_tree().quit()

	## #33: InputGlyphs — tipo do controle pelo nome, rótulos por dispositivo,
	## troca pelo último evento (teclado × controle) e sinal de mudança.
	func _glyphs() -> void:
		var G = InputGlyphs
		check(G.kind_from_name("DualSense Wireless Controller") == G.Device.PLAYSTATION, "glifos: DualSense → PlayStation")
		check(G.kind_from_name("PS4 Controller") == G.Device.PLAYSTATION, "glifos: PS4 → PlayStation")
		check(G.kind_from_name("Wireless Controller", 0x054C) == G.Device.PLAYSTATION, "glifos: vendor Sony → PlayStation")
		check(G.kind_from_name("Xbox Series Controller") == G.Device.XBOX, "glifos: Xbox → Xbox")
		check(G.kind_from_name("Steam Deck") == G.Device.DECK, "glifos: Steam Deck")
		check(G.kind_from_name("Nintendo Switch Pro Controller") == G.Device.NINTENDO, "glifos: Switch → Nintendo")
		check(G.kind_from_name("Generic USB Joystick") == G.Device.XBOX, "glifos: genérico → letras do Xbox")
		G.set_device(G.Device.KEYBOARD)
		check(G.label("attack_light") == "J" and G.label("jump") == "Espaço", "glifos: teclado J / Espaço [%s / %s]" % [G.label("attack_light"), G.label("jump")])
		check(G.label("attack_light", G.Device.XBOX) == "X" and G.label("block", G.Device.XBOX) == "LB" and G.label("skill2", G.Device.XBOX) == "RT", "glifos: Xbox X / LB / RT")
		var ps_light: String = G.label("attack_light", G.Device.PLAYSTATION)
		check(ps_light in ["□", "Quadrado"] and G.label("block", G.Device.PLAYSTATION) == "L1" and G.label("skill2", G.Device.PLAYSTATION) == "R2", "glifos: PlayStation %s / L1 / R2" % ps_light)
		check(G.label("jump", G.Device.NINTENDO) == "B", "glifos: Switch pula com B (posição de baixo)")
		check(G.hint([["ui_accept", "confirmar"], ["ui_cancel", "voltar"]], G.Device.XBOX) == "A confirmar  ·  B voltar", "glifos: hint Xbox [%s]" % G.hint([["ui_accept", "confirmar"], ["ui_cancel", "voltar"]], G.Device.XBOX))
		await frames(2)
		var changes: Array = []
		var l: Node = G.listener()
		check(l != null and l.is_inside_tree(), "glifos: ouvinte na árvore")
		var cb := func(d: int): changes.append(d)
		l.connect("device_changed", cb)
		await pad(JOY_BUTTON_X)
		check(G.is_pad(), "glifos: botão do controle → is_pad() [%s]" % G.device_name())
		await key(KEY_J)
		check(not G.is_pad() and changes.size() >= 2, "glifos: tecla volta para teclado (sinal %d vez(es))" % changes.size())
		var jm := InputEventJoypadMotion.new()
		jm.axis = JOY_AXIS_LEFT_X
		jm.axis_value = 0.2
		Input.parse_input_event(jm)
		await frames(2)
		check(not G.is_pad(), "glifos: drift do analógico (0,2) não troca")
		l.disconnect("device_changed", cb)
		G.set_device(G.Device.KEYBOARD)

	## A1 / M3: loja com 0 faíscas e com faíscas; foco, setas, compra, B fecha.
	func _shop() -> void:
		var lv := await level_at(2)
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		Progression.orbs = 0
		var shop := SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
		await wait(0.6)
		await shot("loja_0faiscas")
		var f := focus()
		check(f != null, "loja (0 faíscas): há foco ao abrir [%s]" % txt(f))
		check(labels_text(shop).contains("insuficientes") or _buttons_text(shop).contains("insuficientes"), "loja (0 faíscas): aviso 'faíscas insuficientes'")
		shop.queue_free()
		PauseStack.clear()
		await wait(0.2)
		Progression.orbs = 245
		shop = SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
		await wait(0.6)
		f = focus()
		var list: Node = shop.get("list")
		check(f != null and list != null and f.get_parent() == list and f.get_index() == 0, "loja: foco no 1º item [%s]" % txt(f))
		await pad(JOY_BUTTON_DPAD_DOWN)
		var f2 := focus()
		check(f2 != null and f2 != f, "loja: D-pad ↓ anda [%s → %s]" % [txt(f), txt(f2)])
		await key(KEY_UP)
		check(focus() == f, "loja: seta ↑ volta [%s]" % txt(focus()))
		var before := Progression.orbs
		await pad(JOY_BUTTON_A)
		await wait(0.1)
		check(Progression.orbs < before, "loja: A compra (%d → %d faíscas)" % [before, Progression.orbs])
		await shot("loja_com_faiscas")
		await pad(JOY_BUTTON_B)
		await wait(0.2)
		check(not is_instance_valid(shop) or shop.is_queued_for_deletion(), "loja: B fecha")
		await wait(0.1)
		check(not get_tree().paused, "loja: ao fechar (sem pausa por baixo) o mundo despausa")
		# Balance P1/P2: vida máx. 60×(n+1) até 10; Restauração só no santuário/pós-chefe.
		var U = load("res://scripts/ui/upgrade_menu.gd")
		check(U.hp_cost_for(0) == 60 and U.hp_cost_for(1) == 120 and U.hp_cost_for(9) == 600, "loja P1: preço 60/120/…/600")
		check(U.hp_buys_from_bonus(0) == 0 and U.hp_buys_from_bonus(25) == 0 and U.hp_buys_from_bonus(45) == 1 and U.hp_buys_from_bonus(75 + 60) == 3, "loja P1: compras deduzidas do bônus (com dons do Soter)")
		Progression.orbs = 99999
		Progression.bonus_max_health = 0
		RunManager.pending_advance = false
		shop = SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
		await wait(0.5)
		var hp_row: Button = null
		var heal_row: Button = null
		for b in shop.list.get_children():
			if String(b.text).begins_with("+20 de vida"):
				hp_row = b
			if String(b.text).begins_with("Restauração"):
				heal_row = b
		check(heal_row != null and heal_row.disabled, "loja P2: Restauração trancada no meio do run (pausa)")
		var bought := 0
		for i in 12:
			if hp_row == null or hp_row.disabled:
				break
			var o := Progression.orbs
			hp_row.emit_signal("pressed")
			await frames(2)
			if Progression.orbs < o:
				bought += 1
			hp_row = null
			for b in shop.list.get_children():
				if String(b.text).begins_with("+20 de vida") and not b.is_queued_for_deletion():
					hp_row = b
		check(bought == 10 and Progression.bonus_max_health == 200, "loja P1: no máximo 10 compras (%d, bônus %d)" % [bought, Progression.bonus_max_health])
		check(99999 - Progression.orbs == 60 * 55, "loja P1: total pago 60×(1+…+10) = 3300 (%d)" % (99999 - Progression.orbs))
		await shot("loja_teto")
		shop.queue_free()
		PauseStack.clear()
		await wait(0.2)
		RunManager.pending_advance = true
		shop = SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
		await wait(0.5)
		heal_row = null
		for b in shop.list.get_children():
			if String(b.text).begins_with("Restauração"):
				heal_row = b
		check(heal_row != null and String(heal_row.text).contains("cura"), "loja P2: Restauração aparece no santuário/pós-chefe")
		RunManager.pending_advance = false
		shop.queue_free()
		PauseStack.clear()
		Progression.bonus_max_health = 0
		await wait(0.2)
		if lv != null:
			pass

	func _buttons_text(root: Node) -> String:
		var parts: PackedStringArray = []
		for n in root.find_children("*", "Button", true, false):
			parts.append(String(n.text))
		return "\n".join(parts)

	## M6: na pausa, "Melhorias" trancada durante o combate.
	func _pause_combat() -> void:
		var lv := await level_at(2)
		if lv == null:
			check(false, "pausa: nível não carregou")
			return
		lv.player.global_position = Vector2(lv.zone_center(0) - Level.ZONE_TRIGGER + 8.0, 250.0)
		for _i in 30:
			await wait(0.15)
			if lv.zone_active and living_enemies().size() > 0:
				break
		await skip_dialogs()
		check(living_enemies().size() > 0, "pausa: zona trancada com inimigos vivos (%d)" % living_enemies().size())
		var pm := SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		GameManager.set_state(GameManager.State.PAUSED)
		await wait(0.5)
		var up: Button = pm.get_node("Center/Panel/VBox/Upgrades")
		check(up.disabled, "pausa em combate: Melhorias desabilitada")
		check(_buttons_text(pm).contains("fora de combate") or labels_text(pm).contains("fora de combate"), "pausa em combate: texto 'Disponível fora de combate'")
		await shot("pausa_em_combate")
		await pad(JOY_BUTTON_DPAD_DOWN)
		await pad(JOY_BUTTON_DPAD_DOWN)
		await shot("pausa_em_combate_foco_melhorias")
		await pad(JOY_BUTTON_B)
		await wait(0.2)
		check(not is_instance_valid(pm) or pm.is_queued_for_deletion(), "pausa: B fecha")
		check(not get_tree().paused, "pausa: B despausa")
		# limpa a zona e confere de novo
		for e in living_enemies():
			e.health.take_damage(99999)
		for _i in 40:
			await wait(0.15)
			await skip_dialogs()
			if not lv.zone_active and living_enemies().is_empty():
				break
		await wait(0.3)
		pm = SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		GameManager.set_state(GameManager.State.PAUSED)
		await wait(0.5)
		up = pm.get_node("Center/Panel/VBox/Upgrades")
		check(not up.disabled, "pausa fora de combate: Melhorias liberada (zona=%s vivos=%d)" % [lv.zone_active, living_enemies().size()])
		await shot("pausa_fora_de_combate")
		pm._resume_game()
		await wait(0.2)

	## REVISAO #10: pausa → loja → fechar loja mantém a pausa; continuar despausa.
	func _pause_stack() -> void:
		var lv := await level_at(2)
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		await wait(0.2)
		var pm := SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		GameManager.set_state(GameManager.State.PAUSED)
		await wait(0.4)
		check(get_tree().paused and PauseStack.count() >= 1, "pilha: pausa segura o mundo (donos=%d)" % PauseStack.count())
		pm._open_upgrades()
		await wait(0.5)
		check(PauseStack.count() >= 2, "pilha: loja por cima da pausa (donos=%d)" % PauseStack.count())
		await pad(JOY_BUTTON_B)
		await wait(0.3)
		check(get_tree().paused, "pilha: fechar a loja NÃO despausa (a pausa continua aberta)")
		var f := focus()
		check(f != null and txt(f).contains("Melhorias"), "pilha: foco volta em Melhorias [%s]" % txt(f))
		pm._open_options()
		await wait(0.4)
		await pad(JOY_BUTTON_B)
		await wait(0.2)
		check(get_tree().paused and is_instance_valid(pm), "pilha: B nas Opções volta à pausa")
		pm._open_moves()
		await wait(0.4)
		await pad(JOY_BUTTON_B)
		await wait(0.2)
		check(get_tree().paused and is_instance_valid(pm) and pm.get_node("Center").visible, "pilha: B nos Golpes volta à pausa")
		await pad(JOY_BUTTON_B)
		await wait(0.2)
		check(not get_tree().paused and PauseStack.count() == 0, "pilha: B na pausa despausa (donos=%d)" % PauseStack.count())
		if lv != null:
			pass

	## B (ui_cancel pelo botão do controle) em todos os menus de tela cheia.
	func _back_everywhere() -> void:
		for pair in [
			["res://scenes/ui/OptionsMenu.tscn", "MainMenu"],
			["res://scenes/ui/Chronicles.tscn", "MainMenu"],
			["res://scenes/ui/CharacterAtelier.tscn", "MainMenu"],
			["res://scenes/ui/Gallery.tscn", "CharacterAtelier"],
			["res://scenes/ui/Credits.tscn", "MainMenu"],
			["res://scenes/ui/PreGame.tscn", "MainMenu"],
		]:
			await go(pair[0], 1.0)
			await pad(JOY_BUTTON_B)
			await wait(1.0)
			check(scene_path().contains(pair[1]), "B em %s → %s [%s]" % [pair[0].get_file(), pair[1], scene_path().get_file()])
		# Golpes aberto no pré-jogo
		await go("res://scenes/ui/PreGame.tscn", 1.0)
		get_tree().current_scene._open_moves()
		await wait(0.4)
		await pad(JOY_BUTTON_B)
		await wait(0.3)
		var still := false
		for c in get_tree().current_scene.get_children():
			if c is MovesScreen and not c.is_queued_for_deletion():
				still = true
		check(not still and scene_path().contains("PreGame"), "B nos Golpes (pré-jogo) fecha só os Golpes")
		await shot("pregame")

	## L3: segurar ↓ nas Crônicas — atraso inicial ~0,35 s, depois ~0,08 s.
	## (Medido em tempo real: com a máquina carregada um quadro longo come parte
	## do segurar, então a janela de aceitação é larga; o que importa é: 0,25 s
	## = 1 passo só (há atraso) e 1,0 s = vários passos (há repetição).)
	func _chronicles() -> void:
		await go("res://scenes/ui/Chronicles.tscn", 1.0)
		var ch := get_tree().current_scene
		var s0: int = ch._sel
		var t0 := Time.get_ticks_msec()
		action("ui_down", true)
		await wait(0.25)
		var s1: int = ch._sel
		await wait(0.75)               # total 1,0 s segurando
		var s2: int = ch._sel
		var held := (Time.get_ticks_msec() - t0) / 1000.0
		action("ui_down", false)
		await wait(0.2)
		var s3: int = ch._sel
		print("UIM crônicas: inicio=%d 0.25s=%d 1.0s=%d solto=%d (segurou %.2f s)" % [s0, s1, s2, s3, held])
		check(s1 - s0 == 1, "crônicas: 0,25 s segurando = 1 passo (%d)" % (s1 - s0))
		check(s2 - s0 >= 4 and s2 - s0 <= 11, "crônicas: 1,0 s segurando = 4–11 passos (%d; ideal ≈ 10)" % (s2 - s0))
		check(s3 == s2, "crônicas: soltou, parou")
		# toque único pelo controle = 1 passo
		var a: int = ch._sel
		await pad(JOY_BUTTON_DPAD_DOWN)
		await wait(0.1)
		check(ch._sel == a + 1, "crônicas: 1 toque no D-pad = 1 passo (%d)" % (ch._sel - a))
		await key(KEY_S)
		await wait(0.1)
		check(ch._sel == a + 2, "crônicas: tecla S = 1 passo (%d)" % (ch._sel - a - 1))
		await shot("cronicas")

	## Opção "Reduzir flashes".
	func _options() -> void:
		await go("res://scenes/ui/OptionsMenu.tscn", 1.0)
		var om := get_tree().current_scene
		var btn: Button = null
		for b in om.find_children("*", "Button", true, false):
			if b.has_meta("key") and b.get_meta("key") == "reduce_flashes":
				btn = b
		check(btn != null, "opções: existe 'Reduzir flashes'")
		await shot("opcoes")
		if btn == null:
			return
		var was := bool(GameManager.settings.get("reduce_flashes", false))
		check(not was, "opções: 'Reduzir flashes' começa desligada")
		btn.grab_focus()
		await pad(JOY_BUTTON_A)
		await wait(0.1)
		check(bool(GameManager.settings.get("reduce_flashes", false)) == not was, "opções: A liga 'Reduzir flashes' (settings=%s)" % GameManager.settings.get("reduce_flashes"))
		if "reduce_flashes" in Juice:
			check(bool(Juice.get("reduce_flashes")) == bool(GameManager.settings["reduce_flashes"]), "opções: espelhado no Juice")
		await shot("opcoes_flash_ligado")
		await pad(JOY_BUTTON_A)
		await wait(0.1)
		check(bool(GameManager.settings.get("reduce_flashes", false)) == was, "opções: A desliga de novo")
		# #34: velocidade do texto, números de dano, modo de janela
		var ts: Button = om.get("_text_speed")
		var seen_speeds: Array = []
		for i in 4:
			ts.grab_focus()
			await pad(JOY_BUTTON_A)
			await wait(0.05)
			seen_speeds.append(float(GameManager.settings.get("text_speed", -1.0)))
		seen_speeds.sort()
		check(seen_speeds == [0.0, 0.5, 1.0, 2.0], "opções: velocidade do texto passa por 0,5/1/2/instantâneo %s" % str(seen_speeds))
		var dn: Button = null
		for b in om.find_children("*", "Button", true, false):
			if b.has_meta("key") and b.get_meta("key") == "damage_numbers":
				dn = b
		var dn0 := bool(GameManager.settings.get("damage_numbers", true))
		dn.grab_focus()
		await pad(JOY_BUTTON_A)
		await wait(0.05)
		check(bool(GameManager.settings.get("damage_numbers", true)) == not dn0, "opções: números de dano alterna")
		await pad(JOY_BUTTON_A)
		var wb: Button = om.get("_window")
		var modes: Array = []
		for i in 3:
			wb.grab_focus()
			await pad(JOY_BUTTON_A)
			await wait(0.1)
			modes.append(int(GameManager.settings.get("window_mode", -1)))
		modes.sort()
		check(modes == [0, 1, 2], "opções: modo de janela passa por janela/tela cheia/sem bordas %s" % str(modes))
		check(bool(GameManager.settings.get("fullscreen", false)) == (int(GameManager.settings.get("window_mode", 0)) != 0), "opções: 'fullscreen' acompanha o modo de janela")
		await shot("opcoes_novas")

	## #34: tela Controles — captura, troca com conflito, recusa, padrão; JSON.
	func _controls() -> void:
		await go("res://scenes/ui/OptionsMenu.tscn", 1.0)
		var om := get_tree().current_scene
		GameManager.settings["bindings"] = {}
		InputRebind.reset()
		var cb: Button = om.get("_controls")
		cb.grab_focus()
		await key(KEY_ENTER)
		await wait(0.4)
		var cm: ControlsMenu = null
		for c in om.get_children():
			if c is ControlsMenu:
				cm = c
		check(cm != null, "controles: abre pelas Opções")
		if cm == null:
			return
		await shot("controles")
		var rows: Array = cm.get("_rows")
		check(rows.size() == InputRebind.ACTIONS.size() and focus() == rows[0].kb, "controles: %d ações, foco na 1ª" % rows.size())
		# Golpe leve (J) ← K: troca com Golpe forte
		rows[0].kb.grab_focus()
		await key(KEY_ENTER)
		await wait(0.2)
		check(cm.get("_capturing") != null, "controles: Enter inicia a captura")
		await shot("controles_captura")
		await key(KEY_K)
		await wait(0.1)
		var light := InputGlyphs.label("attack_light", InputGlyphs.Device.KEYBOARD)
		var heavy := InputGlyphs.label("attack_heavy", InputGlyphs.Device.KEYBOARD)
		check(light == "K" and heavy == "J", "controles: K no golpe leve troca com o forte [%s / %s]" % [light, heavy])
		var bd: Dictionary = GameManager.settings.get("bindings", {})
		check(bd.has("attack_light") and bd.has("attack_heavy"), "controles: gravado em settings.bindings %s" % str(bd.keys()))
		# Esc recusado (é cancelar) e tecla de Anel fixa recusada
		rows[2].kb.grab_focus()
		await key(KEY_ENTER)
		await wait(0.2)
		await key(KEY_1)
		check(cm.get("_capturing") != null and String(cm.get("_status").text).contains("fixo"), "controles: tecla 1 (Anel) recusada [%s]" % cm.get("_status").text)
		await key(KEY_ESCAPE)
		await wait(0.05)
		check(cm.get("_capturing") == null and InputGlyphs.label("jump", InputGlyphs.Device.KEYBOARD) == "Espaço", "controles: Esc cancela sem mudar")
		# Controle: Golpe leve ← RB (botão) — troca com Anel (magia)
		rows[0].pad.grab_focus()
		await key(KEY_ENTER)
		await wait(0.2)
		await pad(JOY_BUTTON_RIGHT_SHOULDER)
		await wait(0.1)
		check(InputGlyphs.label("attack_light", InputGlyphs.Device.XBOX) == "RB" and InputGlyphs.label("skill1", InputGlyphs.Device.XBOX) == "X", "controles: RB no golpe leve troca com o Anel")
		# JSON: ida e volta pelo save (números viram float no JSON)
		var json: Dictionary = JSON.parse_string(JSON.stringify(GameManager.settings["bindings"]))
		InputRebind.reset()
		check(InputGlyphs.label("attack_light", InputGlyphs.Device.KEYBOARD) == "J", "controles: reset volta ao J")
		InputRebind.new().apply_bindings(json)
		check(InputGlyphs.label("attack_light", InputGlyphs.Device.KEYBOARD) == "K" and InputGlyphs.label("attack_light", InputGlyphs.Device.XBOX) == "RB", "controles: apply_bindings(JSON) reaplica")
		check(InputRebind.deserialize({"k": "x"}) == null or InputRebind.deserialize({"b": 999}) == null, "controles: evento inválido do save é ignorado")
		# Restaurar padrão (botão)
		cm.get("_reset_btn").emit_signal("pressed")
		await wait(0.05)
		check((GameManager.settings["bindings"] as Dictionary).is_empty() and InputGlyphs.label("attack_heavy", InputGlyphs.Device.KEYBOARD) == "K", "controles: Restaurar padrão")
		await pad(JOY_BUTTON_B)
		await wait(0.2)
		check(not is_instance_valid(cm) or cm.is_queued_for_deletion(), "controles: B fecha a tela")
		check(get_tree().current_scene == om, "controles: B fecha só os Controles (Opções continuam)")
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)

	## M7: a Estela só abre com o golpe leve fora de combate.
	func _stela() -> void:
		var lv := await level_at(3)
		if lv == null:
			check(false, "estela: nível não carregou")
			return
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		var st: Stela = null
		for c in lv.get_children():
			if c is Stela:
				st = c
		if st == null:
			check(false, "estela: nenhuma Estela na tela 3")
			return
		lv.player.global_position = st.global_position + Vector2(-40, -10)
		lv.player.velocity = Vector2.ZERO
		await wait(0.8)
		# Teleportar até a pedra pode trancar a zona seguinte: com zona ativa a
		# Estela NÃO abre (combate). Confere isso e depois limpa a zona.
		if lv.zone_active:
			await key(KEY_J)
			await wait(0.4)
			check(_stela_panel() == null, "estela: com a zona trancada, J é só golpe")
			var p0 := _stela_panel()
			if p0 != null:
				p0.queue_free()
				PauseStack.clear()
			for e in living_enemies():
				e.health.take_damage(99999)
			for _i in 40:
				await wait(0.15)
				await skip_dialogs()
				if not lv.zone_active and living_enemies().is_empty():
					break
			lv.player.global_position = st.global_position + Vector2(-40, -10)
			lv.player.velocity = Vector2.ZERO
			lv.player.combo_sequence.clear()
			await wait(1.2)
		await shot("estela_prompt")
		print("UIM estela: zona=%s vivos=%d inimigo_perto=%s pode_ler=%s" % [lv.zone_active, living_enemies().size(), st._enemy_near(), st.can_read()])
		check(st._prompt.text == "J / X · ler a Estela", "estela: prompt '%s'" % st._prompt.text)
		# 1) sem inimigo, sem combo → abre
		await key(KEY_J)
		await wait(0.4)
		check(_stela_panel() != null, "estela: J sem inimigo abre o painel")
		await shot("estela_painel")
		await pad(JOY_BUTTON_B)
		await wait(0.4)
		check(_stela_panel() == null and not get_tree().paused, "estela: B fecha e despausa")
		await wait(1.0)
		# 2) inimigo vivo perto → não abre
		var en: Node = lv.enemy_scene.instantiate()
		en.type_id = "servo"
		lv.add_child(en)
		en.global_position = st.global_position + Vector2(120, 0)
		en.set_physics_process(false)
		en.set_process(false)
		await wait(0.3)
		lv.player.global_position = st.global_position + Vector2(-40, -10)
		await wait(0.6)
		await key(KEY_J)
		await wait(0.4)
		check(_stela_panel() == null, "estela: com inimigo vivo perto, J é só golpe")
		var p := _stela_panel()
		if p != null:
			p.queue_free()
			PauseStack.clear()
		en.queue_free()
		await wait(1.2)
		# 3) no meio do combo → não abre
		lv.player.combo_sequence.clear()
		lv.player.combo_sequence.append("light")
		lv.player.combo_reset_timer = 1.0
		await key(KEY_J)
		await wait(0.3)
		check(_stela_panel() == null, "estela: no meio do combo, J é só golpe")
		p = _stela_panel()
		if p != null:
			p.queue_free()
			PauseStack.clear()

	func _stela_panel() -> Node:
		for c in get_tree().root.get_children():
			if c is Stela.StelaPanel and not c.is_queued_for_deletion():
				return c
		return null

	## P3: faixa de dicas da Provação segue o dispositivo em uso.
	func _trial() -> void:
		PauseStack.clear()
		CodexSession.start_demo()
		await wait(2.5)
		var tr := get_tree().current_scene
		var hints: Label = tr.get("hint_label") if "hint_label" in tr else null
		check(hints != null, "provação: faixa de dicas existe")
		if hints == null:
			return
		var mv := InputEventJoypadMotion.new()
		mv.axis = JOY_AXIS_RIGHT_Y
		mv.axis_value = 0.9
		Input.parse_input_event(mv)
		await frames(2)
		mv = mv.duplicate()
		mv.axis_value = 0.0
		Input.parse_input_event(mv)
		await wait(0.2)
		var pad_txt := hints.text
		check(pad_txt.contains("LB") and pad_txt.contains("RB"), "provação: controle → dicas Xbox [%s]" % pad_txt)
		await shot("provacao_controle")
		await key(KEY_F12)
		await wait(0.2)
		check(hints.text.contains("ESPAÇO") or hints.text.contains("Espaço"), "provação: teclado → dicas de teclado [%s]" % hints.text)
		await shot("provacao_teclado")
		CodexSession.stage = 2
		tr.completed = true
		tr._show_result(true)
		await wait(0.5)
		await shot("provacao_final")
		check(get_tree().paused and PauseStack.count() >= 1, "provação: resultado pausa pela pilha")
		CodexSession.leave_demo()
		PauseStack.clear()

	## REVISAO #13: opção mudada dentro da Provação chega ao save (só as opções).
	## Usa o user:// do worktree (override.cfg) e devolve o save como estava.
	func _options_in_trial() -> void:
		var path: String = SaveManager.SAVE_PATH
		var had := FileAccess.file_exists(path)
		var backup := FileAccess.get_file_as_string(path) if had else ""
		var flash_before := bool(GameManager.settings.get("reduce_flashes", false))
		SaveManager.persist_enabled = true
		PauseStack.clear()
		CodexSession.start_demo()
		await wait(2.0)
		check(not SaveManager.persist_enabled, "opções na Provação: save do run desligado")
		var packed: PackedScene = load("res://scenes/ui/OptionsMenu.tscn")
		var om = packed.instantiate()
		om.overlay = true
		get_tree().current_scene.add_child(om)
		await wait(0.3)
		var btn: Button = null
		for b in om.find_children("*", "Button", true, false):
			if b.has_meta("key") and b.get_meta("key") == "reduce_flashes":
				btn = b
		if btn != null:
			btn.emit_signal("pressed")
		await wait(0.1)
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		var saved = parsed.get("settings", {}).get("reduce_flashes", null) if typeof(parsed) == TYPE_DICTIONARY else null
		check(saved != null and bool(saved) == not flash_before, "opções na Provação: 'Reduzir flashes' gravado no save (%s)" % str(saved))
		om.queue_free()
		CodexSession.leave_demo()
		GameManager.settings["reduce_flashes"] = flash_before
		if had:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(backup)
			f.close()
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		SaveManager.persist_enabled = false
		PauseStack.clear()
		await wait(0.5)

	## Créditos: atribuições CC-BY sempre (com e sem o LICENSES.md).
	func _credits() -> void:
		for missing in [false, true]:
			if missing:
				Credits.licenses_path = "res://nao_existe/LICENSES.md"
			await go("res://scenes/ui/Credits.tscn", 0.8)
			var cr := get_tree().current_scene
			var all := labels_text(cr)
			var tag := "sem LICENSES.md" if missing else "com LICENSES.md"
			check(all.contains("Kevin MacLeod"), "créditos (%s): Kevin MacLeod" % tag)
			check(all.contains("Little Robot Sound Factory"), "créditos (%s): Little Robot Sound Factory" % tag)
			check(all.contains("Godot Engine") and all.contains("MIT"), "créditos (%s): Godot Engine (MIT)" % tag)
			check(all.contains("Cinzel") and all.contains("Alegreya") and all.contains("Open Font License"), "créditos (%s): fontes OFL" % tag)
			if not missing:
				check(all.contains("Lord of the Land"), "créditos: lê o bloco CRÉDITOS (lista de faixas)")
				for y in [-300.0, -700.0, -1100.0]:
					cr._y = y
					cr._hold = 30.0
					await wait(0.25)
					await shot("creditos_%d" % int(-y))
		Credits.licenses_path = "res://assets/LICENSES.md"

	## L2: nomes do Bestiário cabem nas células.
	## #52/#27: pré-jogo sem spoiler; card de fim da demo + "Lista de desejos".
	func _demo_end() -> void:
		await go("res://scenes/ui/PreGame.tscn", 1.0)
		var info: String = get_tree().current_scene.get_node("Center/VBox/Info").text
		check(not info.contains("Centro") and not info.contains("Mente") and not info.contains("telas"), "pré-jogo: sem 'Centro'/'Mente'/'telas' [%s]" % info)
		check(info.contains("~2–3 horas") or info.contains("Demo"), "pré-jogo: duração estimada [%s]" % info)
		await shot("pregame_info")
		ProjectSettings.set_setting("gnosis/store_url", "https://store.steampowered.com/app/0/GNOSIS/")
		EndScreen.demo_card = true
		await go("res://scenes/ui/EndScreen.tscn", 1.0)
		var es := get_tree().current_scene
		var all := labels_text(es)
		check(all.contains("Fim da demo") and all.contains("Obrigado por jogar"), "demo: card 'Fim da demo — obrigado por jogar'")
		var wl: Button = es.get_node("Center/Panel/VBox/Buttons/Retry")
		check(wl.text == "Lista de desejos" and not wl.disabled and focus() == wl, "demo: botão 'Lista de desejos' com foco (URL configurada)")
		check(not EndScreen.demo_card, "demo: o card é de uma vez só")
		await shot("demo_fim")
		ProjectSettings.set_setting("gnosis/store_url", "")
		EndScreen.demo_card = true
		await go("res://scenes/ui/EndScreen.tscn", 1.0)
		wl = get_tree().current_scene.get_node("Center/Panel/VBox/Buttons/Retry")
		check(wl.disabled, "demo: sem URL o botão fica desligado")
		if GameManager.has_signal("demo_finished") and "demo" in GameManager:
			GameManager.set("demo", true)
			EndScreen.ensure_demo_hook()
			await wait(0.2)
			await go("res://scenes/ui/MainMenu.tscn", 0.8)
			GameManager.emit_signal("demo_finished")
			await wait(1.2)
			check(scene_path().contains("EndScreen") and labels_text(get_tree().current_scene).contains("Fim da demo"), "demo: sinal demo_finished abre o card [%s]" % scene_path())
			GameManager.set("demo", false)
		else:
			print("UIM nota: GameManager.demo_finished ainda não existe (Técnico2) — só o card foi testado")

	## #35/#26: Bestiário com ficha (lore + dica), nomes cabem, trancados "???".
	func _bestiary() -> void:
		await go("res://scenes/ui/Gallery.tscn", 1.2)
		var g := get_tree().current_scene
		var bad: Array = []
		var cards: Array = g.get("cards")
		for b in cards:
			var lab: Label = b.get_meta("name_label")
			var font: Font = lab.get_theme_font("font")
			var fs: int = lab.get_theme_font_size("font_size")
			for line in String(lab.text).split("\n"):
				var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if w > lab.size.x - 2.0:
					bad.append("%s (%d > %d)" % [line, int(w), int(lab.size.x)])
			if lab.get_line_count() > 2:
				bad.append("%s (linhas %d)" % [lab.text, lab.get_line_count()])
		check(bad.is_empty(), "bestiário: nomes cabem %s" % str(bad))
		var missing: Array = []
		for e in g.get("entries"):
			var id := String(e.id)
			if not BestiaryLore.has_entry(id) or BestiaryLore.lore(id).size() != 2 or BestiaryLore.tip(id) == "":
				missing.append(id)
		check(missing.is_empty(), "bestiário: toda entrada tem 2 linhas de lore + dica %s" % str(missing))
		var seen: Array = g.get("_seen")
		var locked := seen.count(false)
		check(locked > 0 or BestiaryLore.all_unlocked(), "bestiário: save novo tem entradas trancadas (%d de %d)" % [locked, seen.size()])
		check(focus() != null and cards.has(focus()), "bestiário: foco na grade ao abrir [%s]" % txt(focus()))
		await shot("bestiario_topo")
		await key(KEY_RIGHT)
		await key(KEY_DOWN)
		var sel: int = g.get("_selected")
		check(sel == 5, "bestiário: → ↓ andam na grade (ficha %d)" % sel)
		var lore_l: Label = g.get("_lore")
		var tip_l: Label = g.get("_tip")
		if seen[sel]:
			check(lore_l.text != "" and tip_l.text != "", "bestiário: ficha mostra lore e dica")
		else:
			check(String(g.get("_name").text) == "???" and tip_l.text == "", "bestiário: ficha trancada não revela nome nem dica")
		await shot("bestiario_ficha")
		# Ficha longa: medir lore e dica no painel (≤ 4 + 3 linhas).
		var over: Array = []
		for e in g.get("entries"):
			var id := String(e.id)
			lore_l.text = "\n".join(BestiaryLore.lore(id))
			tip_l.text = BestiaryLore.tip(id)
			if lore_l.get_line_count() > 4 or tip_l.get_line_count() > 3:
				over.append("%s (%d/%d)" % [id, lore_l.get_line_count(), tip_l.get_line_count()])
		check(over.is_empty(), "bestiário: lore ≤ 4 linhas e dica ≤ 3 no painel %s" % str(over))
		for i in 30:
			await key(KEY_DOWN)
		await shot("bestiario_fim")
