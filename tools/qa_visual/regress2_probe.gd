extends Node
## SONDA QA-VISUAL 2 (não faz parte do jogo): regressões da integração Ondas 1–3.
## Um caso por processo. Salva PNGs <pasta>/r2_<caso>_<tag>.png e imprime "R2|<caso>|<detalhe>".
##  arma=N   tela 3, Sophia sozinha com a arma no nível N: parada, pesado, leve (crop pela meta).
##  npc=T    tela T (17/35/53 Soter, 61 Velkar): leva a Sophia ao NPC e fotografa CADA fala.
##  estela   tela 1: leva a Sophia à Estela, mostra o "ler" e abre o painel.
##  epi=X    epílogo X (ascensao|ruptura|semente) avulso: um quadro a cada 1,5 s até acabar.
##  prologo  prólogo avulso: um quadro a cada 1,5 s até acabar.
## Uso: godot --audio-driver Dummy --fixed-fps 60 --path . --resolution 1280x720 --position 1200,600 \
##        res://tools/qa_visual/Regress2Probe.tscn -- <pasta> <caso>

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)   # ferramenta NUNCA toca som
	var w := R.new()
	var a := OS.get_cmdline_user_args()
	w.out_dir = a[0] if a.size() > 0 else "user://"
	w.case_arg = a[1] if a.size() > 1 else "arma=5"
	get_tree().root.add_child.call_deferred(w)


class R extends Node:
	var out_dir: String
	var case_arg: String
	var _case: String = ""
	var _val: String = ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		var kv := case_arg.split("=", true, 1)
		_case = kv[0]
		_val = kv[1] if kv.size() > 1 else ""
		_run.call_deferred()

	func log_r(d: String) -> void:
		print("R2|%s|%s" % [case_arg, d])

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func shot(tag: String) -> void:
		await RenderingServer.frame_post_draw
		var p := "%s/r2_%s_%s.png" % [out_dir, case_arg.replace("=", ""), tag]
		get_viewport().get_texture().get_image().save_png(p)
		log_r("SHOT " + p)

	func _start_level(screen: int, weapon: int = 1) -> Level:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		Progression.weapon_level = weapon
		Progression.weapon_level_changed.emit(weapon)
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		for i in 120:
			await get_tree().process_frame
			_skip_dialogs()
			if get_tree().current_scene is Level and (get_tree().current_scene as Level).player != null:
				break
		await wait(0.6)
		return get_tree().current_scene as Level

	func _skip_dialogs() -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()

	func _box() -> DialogueBox:
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				return c
		return null

	func _hide_enemies() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			e.visible = false
			e.process_mode = Node.PROCESS_MODE_DISABLED

	func _kill_alive(pl: Node2D) -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.estate != Enemy.EState.DEAD:
				e._on_hit_received(e.health.max_health + 999, pl.global_position, 60.0, false, null)

	func _player_screen_pos(pl: Node2D) -> Vector2:
		return pl.get_global_transform_with_canvas().origin

	func _run() -> void:
		match _case:
			"arma": await _arma(int(_val))
			"npc": await _npc(int(_val))
			"estela": await _estela()
			"epi": await _cine(_val)
			"prologo": await _cine("")
			_: log_r("caso desconhecido")
		await wait(0.3)
		get_tree().quit()

	# --- arma por nível ------------------------------------------------------
	func _arma(n: int) -> void:
		var lv := await _start_level(3, n)
		var pl: Node2D = lv.player
		for i in 30:
			_hide_enemies()
			await get_tree().process_frame
		log_r("nivel=%d weapon_level=%d pos_tela=%s" % [n, Progression.weapon_level, str(_player_screen_pos(pl))])
		await shot("parada")
		Input.action_press("attack_heavy")
		await wait(0.08)
		Input.action_release("attack_heavy")
		await wait(0.18)
		await shot("pesado")
		await wait(0.9)
		Input.action_press("attack_light")
		await wait(0.06)
		Input.action_release("attack_light")
		await wait(0.12)
		await shot("leve")
		await wait(0.6)
		Input.action_press("move_right")
		await wait(0.5)
		await shot("andando")
		Input.action_release("move_right")

	# --- NPCs ------------------------------------------------------------------
	func _npc(screen: int) -> void:
		var lv := await _start_level(screen)
		var npc: Node2D = null
		for c in lv.get_children():
			if c is NpcEncounter:
				npc = c
		if npc == null:
			log_r("SEM NPC na tela %d" % screen)
			await shot("sem_npc")
			return
		# Chega como um jogador: anda para a direita e as zonas caem (mata quem nasce).
		var pl: Node2D = lv.player
		Input.action_press("move_right")
		var t := 0.0
		var shot_antes := false
		while _box() == null and t < 90.0:
			await wait(0.1)
			t += 0.1
			_kill_alive(pl)
			if not shot_antes and absf(pl.global_position.x - npc.global_position.x) < 220.0:
				shot_antes = true
				await shot("antes")
		Input.action_release("move_right")
		log_r("chegou em %.1f s" % t)
		if _box() == null:
			log_r("caixa NÃO abriu em 6 s (npc em %s, sophia em %s)" % [str(npc.global_position), str(pl.global_position)])
			await shot("sem_caixa")
			return
		var line := -1
		var n := 0
		var guard := 0
		while guard < 80:
			guard += 1
			var b := _box()
			if b == null:
				break
			if b.get("_in_choices"):
				await wait(0.8)
				await shot("escolha_%02d" % n)
				b._on_choice(0)
				await wait(0.4)
				continue
			if b.idx != line:
				line = b.idx
				await wait(1.4)
				if b.is_typing():
					b.reveal_all()
				await wait(0.2)
				var spk: String = String(b.lines[line].get("speaker", b.lines[line].get("name", ""))) if line < b.lines.size() else ""
				var mood: String = String(b.lines[line].get("mood", "")) if line < b.lines.size() else ""
				log_r("fala %d speaker=%s mood=%s npc_vis=%s npc_tela=%s" % [line, spk, mood, str(npc.visible), str(npc.get_global_transform_with_canvas().origin)])
				await shot("fala_%02d" % n)
				n += 1
			var ev := InputEventAction.new()
			ev.action = "ui_accept"
			ev.pressed = true
			Input.parse_input_event(ev)
			await wait(0.35)
		await wait(1.5)
		await shot("depois")
		await wait(2.0)
		await shot("depois2")

	# --- Estela ----------------------------------------------------------------
	func _estela() -> void:
		var lv := await _start_level(1)
		var st: Node2D = null
		for c in lv.get_children():
			if c is Stela:
				st = c
		if st == null:
			log_r("SEM ESTELA na tela 1")
			return
		var pl: Node2D = lv.player
		pl.global_position = Vector2(st.global_position.x - 10.0, pl.global_position.y)
		await wait(0.8)
		_skip_dialogs()
		await shot("perto")
		st.open()
		await wait(1.2)
		await shot("painel")
		await wait(2.0)
		await shot("painel2")

	# --- cinemáticas avulsas ---------------------------------------------------
	func _cine(ending: String) -> void:
		var cin: Node = null
		if ending == "":
			cin = Cinematic.prologue()
		else:
			Narrative.ending = ending
			GameManager.end_title = ending.to_upper()
			cin = Cinematic.epilogue(ending, Gnosis.chronicles_count(), Gnosis.chronicles_total())
		var k := 0
		var t := 0.0
		while is_instance_valid(cin) and t < 90.0:
			await wait(1.5)
			t += 1.5
			if is_instance_valid(cin):
				await shot("q%02d" % k)
				k += 1
		log_r("fim em %.1f s, %d quadros" % [t, k])
