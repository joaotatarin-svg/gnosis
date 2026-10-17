extends Node
## FERRAMENTA (não faz parte do jogo) — UI Onda 5: fotografa e CONFERE os achados
## de UI do QA visual 2 (#4, #5, #10, #13):
##   card68      toast/legenda NÃO aparecem sob o card do chefe (tela 68) e o
##               aviso "As duas formas…" vem DEPOIS do card (não queima escondido)
##   cena        com cena no ar (caixa de diálogo): barras dos chefes somem e o toast
##               de conquista espera a cena acabar
##   topo        topo da travessia: dica + legenda (hierarquia: legenda 1 linha
##               quando cabe; dica já aprendida não volta)
##   estela      painel da Estela com teclado e com controle (rodapé com glifos)
##   card_pad    card do prólogo com o controle (rodapé com glifos)
## Uso: godot --path . --audio-driver Dummy --resolution 1280x720 --position 1200,600 \
##        res://tools/UxShots5.tscn -- <pasta_saida> [caso ...]
## Sem casos: todos. Imprime "UX5 CHECK OK/FALHA" e "UX5 RESULT: N ok, M falha(s)".
## Funciona também no código ANTIGO (capturas "antes"): tudo novo é via has_method.

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
	var auto_finish: bool = true
	var ok_n: int = 0
	var fail_n: int = 0

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
		print("UX5 CHECK %s: %s" % ["OK" if ok else "FALHA", what])

	func wait(seconds: float = 0.5) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func shot(name: String) -> void:
		if DisplayServer.get_name() == "headless":
			return                   # headless: só as conferências
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join("ux5_" + name + ".png"))
		print("UX5 SHOT: ", name)

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

	func _caption() -> Node:
		for c in Gnosis.get_children():
			if c is CaptionBar:
				return c
		return null

	func _cinematic() -> Node:
		for c in get_tree().root.get_children():
			if c is Cinematic and not c.is_queued_for_deletion():
				return c
		return null

	## Toast visível de verdade agora? (texto, alpha efetivo)
	func _toast_state() -> Array:
		var h := _hud()
		if h == null or h.get("_toast") == null:
			return ["", 0.0]
		var t: Control = h.get("_toast")
		var a := t.modulate.a if t.is_visible_in_tree() else 0.0
		return [String((h.get("_toast_label") as Label).text), a]

	## Por que o toast está segurando? (diagnóstico impresso)
	func _diag(tag: String) -> void:
		var h := _hud()
		if h == null:
			return
		var st := ""
		var lv = get_tree().current_scene
		if lv != null:
			for c in lv.get_children():
				if c is Staging:
					st = "staging(scene=%s desc=%s art=%s)" % [str(c.get("_scene")), str(c.get("_descending")), str(c.call("_art_on")) if c.has_method("_art_on") else "?"]
		var roots := []
		for c in get_tree().root.get_children():
			if c is DialogueBox or c is Cinematic:
				roots.append(c.get_class() + ":" + str(c.name))
		print("UX5 DIAG %s: paused=%s held=%s recede=%.2f scene=%s %s roots=%s" % [tag, get_tree().paused, PauseStack.is_held(), float(h.get("_recede")), h.call("scene_active"), st, str(roots)])
		var tq = h.get("_toast_queue")
		var tt = h.get("_toast")
		print("UX5 DIAG   toast: fila=%s wait=%s busy=%s mod=%s vis=%s ts=%.2f" % [str(tq), str(h.get("_toast_wait")), str(h.call("_toast_busy")) if h.has_method("_toast_busy") else "?", str(tt.modulate) if tt else "-", str(tt.is_visible_in_tree()) if tt else "-", Engine.time_scale])

	func _caption_alpha() -> float:
		var cb := _caption()
		if cb == null:
			return 0.0
		var r: Control = cb.get("_root")
		return r.modulate.a if r.visible else 0.0

	func _start_screen(sc: int, rings: int = 0) -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		RunManager.current_screen = sc
		GameManager.current_screen = sc
		Progression.weapon_level = 3
		var rs: Array = GameContent.ring_skills(GameContent.characters[0])
		for i in mini(rings, rs.size()):
			Progression.add_ring(rs[i].ring, rs[i].id)
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")

	## Leva a Sophia ao gatilho da 1ª zona até nascer um chefe (ou estourar o tempo).
	func _walk_to_boss(max_s: float = 9.0) -> Node:
		var t := 0.0
		while t < max_s:
			await get_tree().process_frame
			t += get_process_delta_time()
			var lv = get_tree().current_scene
			if lv is Level and is_instance_valid(lv.player) and lv.player != null and not lv.zone_active and lv.zones.size() > 0 and not get_tree().paused:
				lv.player.global_position = Vector2(lv.zone_center(0) - Level.ZONE_TRIGGER + 8.0, 250.0)
			# o card nasce junto com o chefe: chegou o card, chegou a luta
			if _cinematic() != null:
				var any: Node = null
				for e in get_tree().get_nodes_in_group("enemy"):
					any = e
				return any
		return null

	func _run() -> void:
		if _want("topo"):
			await _case_topo()
		if _want("card68"):
			await _case_card68()
		if _want("estela"):
			await _case_estela()
		if _want("card_pad"):
			await _case_card_pad()
		get_tree().paused = false
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)
		print("UX5 RESULT: %d ok, %d falha(s)" % [ok_n, fail_n])
		get_tree().quit()

	# --- #10: topo da travessia ------------------------------------------------------
	func _case_topo() -> void:
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)
		_start_screen(12, 1)
		await wait(1.0)
		var cb := _caption()
		if cb != null:
			cb.clear()
		var h := _hud()
		# a dica do Anel (a que mais aparece) + uma legenda curta da Voz
		h.set("hints", [])
		h.set("_hint", [])
		h.set("_hint_gap", 0.0)
		h.show_hint([{"keys": ["skill1"], "text": "usar o Anel equipado (gasta Éter)"}])
		Gnosis.caption("A Voz", "Dizem que um tal Soter anda por estas bandas. Eu nunca o vi.")
		await wait(1.6)
		await shot("topo_travessia")
		if cb != null and cb.has_method("band_rect"):
			var br: Rect2 = cb.band_rect()
			print("UX5 INFO: faixa da legenda %s" % str(br))
			_check(br.size.y <= 40.0, "#10 legenda curta em 1 linha (altura %.0f)" % br.size.y)
		# Legenda longa: ainda cabe (≤ 2 linhas)
		cb.clear()
		await wait(0.2)
		Gnosis.caption("Sophia", "Ele lê o que eu vou fazer antes de mim. Então não pense: lembre. Lembre do que arde.")
		await wait(1.6)
		await shot("topo_legenda_longa")
		if cb != null and cb.has_method("band_rect"):
			var br2: Rect2 = cb.band_rect()
			_check(br2.end.y <= 120.0, "#10 legenda longa contida no topo (faixa %s)" % str(br2))
		# Dica já aprendida: usar o Anel ANTES de a dica aparecer → ela não volta.
		cb.clear()
		h.set("hints", [])
		h.set("_hint", [])
		h.set("_hint_gap", 0.0)
		var ev := InputEventAction.new()
		ev.action = "skill1"
		ev.pressed = true
		Input.parse_input_event(ev)
		await frames(3)
		var ev2 := InputEventAction.new()
		ev2.action = "skill1"
		ev2.pressed = false
		Input.parse_input_event(ev2)
		await wait(0.3)
		h.show_hint([{"keys": ["skill1"], "text": "usar o Anel equipado (gasta Éter)"}])
		await wait(1.2)
		var ha: float = h.hint_alpha()
		_check(ha < 0.05, "#10 dica já aprendida não aparece (alpha %.2f)" % ha)
		await shot("topo_dica_aprendida")
		# Dica nova (nunca usada) aparece, e some sozinha em poucos segundos
		h.show_hint([{"keys": ["ring_prev", "ring_next"], "text": "trocar de Anel"}])
		await wait(1.0)
		var ha2: float = h.hint_alpha()
		_check(ha2 > 0.5, "#10 dica nova aparece (alpha %.2f)" % ha2)
		await wait(4.5)
		_check(h.hint_alpha() < 0.05, "#10 dica some sozinha (alpha %.2f)" % h.hint_alpha())

	# --- #4/#5: card do chefe e cena na tela 68 ---------------------------------------
	func _case_card68() -> void:
		auto_finish = true
		_start_screen(68, 7)
		# a batalha dupla começa logo que a cena carrega: vigia o card desde já
		var boss := await _walk_to_boss(20.0)
		_check(boss != null, "68: chefe nasceu")
		# espera o card aparecer
		var t := 0.0
		while _cinematic() == null and t < 3.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		_check(_cinematic() != null, "68: card de chefe na tela")
		_diag("card?")
		await frames(4)
		await shot("card68_inicio")
		var ts: Array = _toast_state()
		_check(float(ts[1]) < 0.05, "#4 toast escondido sob o card (início) [%s a=%.2f]" % [ts[0], ts[1]])
		_check(_caption_alpha() < 0.05, "#4 legenda escondida sob o card (a=%.2f)" % _caption_alpha())
		await wait(0.6)
		await shot("card68_meio")
		ts = _toast_state()
		_check(float(ts[1]) < 0.05, "#4 toast escondido sob o card (meio) [%s a=%.2f]" % [ts[0], ts[1]])
		# fim do card → o aviso aparece inteiro DEPOIS
		t = 0.0
		while _cinematic() != null and t < 4.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		_diag("fim do card")
		if OS.has_environment("UX5_DIAG"):
			for i in 40:
				await get_tree().process_frame
				var hh := _hud()
				print("UX5 DIAG f%d dt=%.4f ts=%.2f held=%s paused=%s ps=%s rec=%.2f sc=%s wait=%s" % [i, get_process_delta_time(), Engine.time_scale, hh.call("toast_held"), get_tree().paused, PauseStack.is_held(), float(hh.get("_recede")), hh.call("scene_active"), str(hh.get("_toast_wait"))])
		await wait(1.0)
		_diag("card +1 s")
		await shot("card68_depois")
		ts = _toast_state()
		_check(String(ts[0]).contains("formas") and float(ts[1]) > 0.5, "#4 aviso das duas formas aparece depois do card [%s a=%.2f]" % [ts[0], ts[1]])
		await wait(3.5)
		# #5: cena no ar (caixa de diálogo) durante a luta: barras somem; conquista espera
		auto_finish = false
		var d := DialogueBox.play([{"speaker": "Narrador", "text": "As duas formas caem juntas. Os sete Anéis param no ar… e voltam para ti, um por um."}])
		await wait(0.3)
		if d.has_method("reveal_all"):
			d.reveal_all()
		var ach := get_node_or_null("/root/Achievements")
		var aid := ""
		if ach != null and AchievementData.LIST.size() > 0:
			aid = String(AchievementData.LIST[1].id)
			ach.emit_signal("unlocked", aid)
		await wait(0.6)
		await shot("cena_barras_toast")
		var h := _hud()
		if h != null and h.has_method("boss_bar_alpha"):
			_check(float(h.boss_bar_alpha()) < 0.05, "#5 barras dos chefes ocultas na cena (a=%.2f)" % float(h.boss_bar_alpha()))
		else:
			_check(false, "#5 barras dos chefes ocultas na cena (sem boss_bar_alpha)")
		ts = _toast_state()
		_check(float(ts[1]) < 0.05, "#5 conquista não aparece no meio da cena [%s a=%.2f]" % [ts[0], ts[1]])
		if is_instance_valid(d):
			d._finish()
		auto_finish = true
		# depois da cena a fila anda: o aviso que estava no ar volta e a conquista vem atrás
		var seen := false
		t = 0.0
		while t < 8.0 and not seen:
			await wait(0.1)
			t += 0.1
			ts = _toast_state()
			seen = String(ts[0]).begins_with("Conquista") and float(ts[1]) > 0.5
		await shot("cena_depois")
		_check(seen, "#5 conquista aparece depois da cena (%.1f s) [%s a=%.2f]" % [t, ts[0], ts[1]])
		if h != null and h.has_method("boss_bar_alpha"):
			_check(float(h.boss_bar_alpha()) > 0.9, "#5 barras voltam depois da cena (a=%.2f)" % float(h.boss_bar_alpha()))

	# --- #13: painel da Estela -------------------------------------------------------
	func _case_estela() -> void:
		auto_finish = true
		_start_screen(12, 0)
		await wait(1.2)
		var entry: Dictionary = {}
		for s in Gnosis.STELAS:
			entry = s
			break
		for dev in [InputGlyphs.Device.KEYBOARD, InputGlyphs.Device.XBOX]:
			InputGlyphs.set_device(dev)
			var p := Stela.StelaPanel.new()
			p.entry = entry
			p.fresh = true
			get_tree().root.add_child(p)
			await wait(0.5)
			await shot("estela_%s" % ("teclado" if dev == InputGlyphs.Device.KEYBOARD else "xbox"))
			# corpo exibido = linhas traduzidas (no inglês saía em português)
			var first := I18n.t(String((entry.get("lines", [""]) as Array)[0]))
			var found := false
			for l in p.find_children("*", "Label", true, false):
				if (l as Label).text.begins_with(first) and (l as Label).text.length() > first.length():
					found = true
			_check(found, "Estela: corpo exibido no idioma atual [%s…]" % first.left(30))
			p.queue_free()
			await wait(0.2)
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)
		get_tree().paused = false

	# --- #13: card do prólogo com o controle -------------------------------------------
	func _case_card_pad() -> void:
		InputGlyphs.set_device(InputGlyphs.Device.XBOX)
		var c := Cinematic.prologue()
		await wait(1.6)
		await shot("card_prologo_xbox")
		if is_instance_valid(c):
			c._finish()
		InputGlyphs.set_device(InputGlyphs.Device.KEYBOARD)
		await wait(0.3)
