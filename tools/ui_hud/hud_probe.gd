extends Node
## SONDA DO HUD/DIÁLOGO/LEGENDA (ferramenta do agente ui-hud; não faz parte do jogo).
## Monta um cenário por execução, tira capturas e imprime linhas `HUDP|...`.
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --rendering-driver opengl3 \
##     --path . --resolution 1280x720 res://tools/ui_hud/HudProbe.tscn -- <cenario> <pasta>
## Cenários: t1 · pause · t10choice · t68choice · t68boss · card · death · toast · hints · pad · dialog_api

func _ready() -> void:
	var w := P.new()
	var a := OS.get_cmdline_user_args()
	w.scenario = a[0] if a.size() > 0 else "t1"
	w.out_dir = a[1] if a.size() > 1 else "user://"
	get_tree().root.add_child.call_deferred(w)


class P extends Node:
	var scenario: String
	var out_dir: String

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		AudioServer.set_bus_mute(0, true)
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func shot(name: String) -> void:
		await RenderingServer.frame_post_draw
		var p := "%s/%s.png" % [out_dir, name]
		get_viewport().get_texture().get_image().save_png(p)
		print("HUDP|SHOT|", p)

	func key(k: Key, hold: float = 0.06) -> void:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = true
		Input.parse_input_event(e)
		await wait(hold)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await wait(0.12)

	func pad(b: JoyButton, hold: float = 0.06) -> void:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = true
		e.pressure = 1.0
		Input.parse_input_event(e)
		await wait(hold)
		var r := e.duplicate()
		r.pressed = false
		r.pressure = 0.0
		Input.parse_input_event(r)
		await wait(0.12)

	func dialogs() -> Array:
		var out := []
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				out.append(c)
		return out

	func skip_dialogs() -> void:
		# Fecha diálogos até ficar 0,8 s sem nenhum (as falas vêm em cadeia).
		var quiet := 0.0
		for i in 400:
			var ds := dialogs()
			if ds.is_empty():
				quiet += 0.05
				if quiet >= 0.8:
					return
				await wait(0.05)
				continue
			quiet = 0.0
			var d: DialogueBox = ds[0]
			if d._in_choices:
				d._on_choice(0)
			else:
				d._finish()
			await wait(0.1)

	func level_at(screen: int, skip: bool = true) -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		for sk in GameContent.characters[0].skills:
			if sk.ring != "":
				Progression.add_ring(sk.ring, sk.id)
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(1.6)
		if skip:
			await skip_dialogs()
			await wait(0.3)

	func hud() -> Node:
		return get_tree().get_first_node_in_group("hud")

	func focus_name() -> String:
		var f := get_viewport().gui_get_focus_owner()
		return f.text if f is Button else str(f)

	func _run() -> void:
		print("HUDP|cenario|", scenario)
		match scenario:
			"t1": await _t1()
			"pause": await _pause()
			"t10choice": await _t10choice()
			"t68choice": await _t68choice()
			"t68boss": await _t68boss()
			"card": await _card()
			"death": await _death()
			"toast": await _toast()
			"hints": await _hints()
			"pad": await _pad()
			"dialog_api": await _dialog_api()
			"feet": await _feet()
		print("HUDP|FIM")
		get_tree().quit()

	# --- cenários -------------------------------------------------------------

	func _t1() -> void:
		await level_at(1)
		Gnosis.caption("A Voz", "Tudo aqui foi feito para que você esqueça. Lembre-se do que arde.")
		await wait(1.6)
		await shot("t1")

	func _pause() -> void:
		await level_at(2)
		Gnosis.caption("A Voz", "Tudo aqui foi feito para que você esqueça. Lembre-se do que arde, e siga.")
		await wait(1.4)
		await shot("pause_0_legenda")
		await key(KEY_ESCAPE)
		await wait(0.5)
		await shot("pause_1_menu")
		var pm: Node = null
		for c in get_tree().root.find_children("*", "", true, false):
			if c.has_method("_open_upgrades"):
				pm = c
		print("HUDP|pause|menu=", pm, " paused=", get_tree().paused, " held=", PauseStack.count())
		if pm != null:
			pm.call("_open_options")
			await wait(0.5)
			await shot("pause_2_opcoes")
			await key(KEY_ESCAPE)
			await wait(0.4)
			pm.call("_open_upgrades")
			await wait(0.5)
			await shot("pause_3_loja")

	func _t10choice() -> void:
		await level_at(10, false)
		# avança as falas até as escolhas, só com teclado
		for i in 60:
			var ds := dialogs()
			if ds.size() > 0 and ds[0]._in_choices:
				break
			await key(KEY_J)
		await wait(0.5)
		await shot("t10_choice")
		var ds2 := dialogs()
		print("HUDP|t10|foco=", focus_name())
		await key(KEY_RIGHT)
		print("HUDP|t10|apos_direita=", focus_name())
		await key(KEY_LEFT)
		print("HUDP|t10|apos_esquerda=", focus_name())
		if ds2.size() > 0:
			var d: DialogueBox = ds2[0]
			d.choice_made.connect(func(i): print("HUDP|t10|escolha=", i))
		await key(KEY_ENTER)
		await wait(0.3)
		print("HUDP|t10|dialogos_abertos=", dialogs().size())

	func _t68choice() -> void:
		await level_at(68)
		for sl in [0, 4]:
			var lines: Array = Narrative.final_lines()
			var d := DialogueBox.play(lines.slice(lines.size() - 1), Narrative.final_choices(sl))
			await wait(0.3)
			for i in 6:
				if d._in_choices:
					break
				await key(KEY_J)
			await wait(0.6)
			await shot("t68_choice_sl%d" % sl)
			var bad := 0
			for b in d._choice_box.get_children():
				var r: Rect2 = b.get_global_rect()
				print("HUDP|t68|sl=%d|botao='%s' x=%d..%d y=%d..%d desab=%s" % [sl, b.text, int(r.position.x), int(r.end.x), int(r.position.y), int(r.end.y), str(b.disabled)])
				if r.position.x < 0 or r.end.x > 640 or r.end.y > 360:
					bad += 1
			print("HUDP|t68|sl=%d|fora_da_tela=%d foco=%s" % [sl, bad, focus_name()])
			await key(KEY_RIGHT)
			await key(KEY_RIGHT)
			print("HUDP|t68|sl=%d|apos_2_direitas=%s" % [sl, focus_name()])
			d._on_choice(0)
			await wait(0.3)

	func _t68boss() -> void:
		await level_at(68)
		await wait(2.6)
		await shot("t68_boss_0")
		var bosses: Array = []
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.is_boss_enemy:
				bosses.append(e)
		print("HUDP|t68boss|chefes=", bosses.map(func(b): return b.type_id))
		var pl := get_tree().get_first_node_in_group("player")
		var rei: Node = null
		var col: Node = null
		for b in bosses:
			if b.type_id == "rei_final":
				rei = b
			elif b.type_id == "colosso":
				col = b
		if rei != null:
			rei._on_hit_received(int(rei.health.max_health * 0.6), pl.global_position, 10.0, false, null)
			await wait(1.4)
			await shot("t68_boss_1_rei_fase2")
			rei._on_hit_received(rei.health.max_health * 2, pl.global_position, 10.0, false, null)
			await wait(1.5)
			await shot("t68_boss_2_rei_caiu")
		if col != null:
			col._on_hit_received(int(col.health.max_health * 0.3), pl.global_position, 10.0, false, null)
			await wait(0.8)
			await shot("t68_boss_3_colosso_dano")

	func _card() -> void:
		await level_at(10)
		Gnosis.caption("A Voz", "Tudo aqui foi feito para que você esqueça. Lembre-se do que arde.")
		await wait(1.0)
		var e: Node = null
		for x in get_tree().get_nodes_in_group("enemy"):
			e = x
		Gnosis.boss_card("arconte_sono", 10)
		await wait(0.7)
		await shot("card_athoth")
		await wait(2.0)
		await shot("card_depois")

	func _death() -> void:
		await level_at(2)
		Gnosis.caption("Sophia", "Uma pedra que fala. Quem escreveu isto sabia que eu viria.")
		await wait(0.8)
		var pl := get_tree().get_first_node_in_group("player")
		pl.health.take_damage(pl.health.max_health * 3)
		await wait(1.0)
		await shot("death")

	func _toast() -> void:
		await level_at(68)
		await wait(2.5)
		get_tree().call_group("hud", "toast", "As duas formas precisam cair juntas.")
		await wait(0.5)
		await shot("toast")

	func _hints() -> void:
		await level_at(1)
		await wait(0.5)
		await shot("hints_0_teclado")
		await key(KEY_SPACE)
		await wait(0.6)
		await shot("hints_1_pulou")
		await pad(JOY_BUTTON_A)
		await wait(0.4)
		await shot("hints_2_controle")

	func _pad() -> void:
		await level_at(10, false)
		for i in 60:
			var ds := dialogs()
			if ds.size() > 0 and ds[0]._in_choices:
				break
			await pad(JOY_BUTTON_A)
		await wait(0.4)
		print("HUDP|pad|foco=", focus_name())
		await pad(JOY_BUTTON_DPAD_RIGHT)
		print("HUDP|pad|apos_direita=", focus_name())
		var ds2 := dialogs()
		if ds2.size() > 0:
			ds2[0].choice_made.connect(func(i): print("HUDP|pad|escolha=", i))
		await pad(JOY_BUTTON_A)
		await wait(0.3)
		print("HUDP|pad|dialogos_abertos=", dialogs().size(), " (A ligado a ui_accept? ", InputMap.action_get_events("ui_accept").any(func(ev): return ev is InputEventJoypadButton), ")")

	func _dialog_api() -> void:
		# Roda bem em --headless (rápido): mede pelo estado, não por relógio de parede.
		await level_at(2)
		var lines := [
			{"speaker": "A Voz", "text": "Primeira fala."},
			{"speaker": "Narrador", "text": "(Silêncio.)", "cue": "wait_2s"},
			{"speaker": "Sophia", "text": "Voz? Você ainda está aí, no escuro?"},
		]
		var d := DialogueBox.play(lines)
		var log: Array = []
		var t0 := Time.get_ticks_msec()
		var fin := [false]
		d.finished.connect(func(): fin[0] = true)
		d.line_shown.connect(func(i, l): log.append("%d@%d:%s:vis=%d" % [i, Time.get_ticks_msec() - t0, String(l.get("cue", "")), d._text.visible_characters]))
		await wait(0.2)
		print("HUDP|api|pausa_aberta held=", PauseStack.count(), " paused=", get_tree().paused)
		while d.idx == 0:
			await key(KEY_J)
		var t_wait := Time.get_ticks_msec()
		var ignored := 0
		while d._waiting():
			var before: int = d.idx
			await key(KEY_J, 0.02)
			if d._waiting() and d.idx == before:
				ignored += 1
		print("HUDP|api|wait_2s: apertos_ignorados=%d idx=%d durou_ms=%d" % [ignored, d.idx, Time.get_ticks_msec() - t_wait])
		await key(KEY_J)
		print("HUDP|api|apos_wait idx=", d.idx)
		d.lock_advance(true)
		for i in 4:
			await key(KEY_J)
		print("HUDP|api|com_trava idx=%d typing=%s" % [d.idx, str(d.is_typing())])
		d.lock_advance(false)
		await key(KEY_J)
		await wait(0.2)
		print("HUDP|api|fechou=%s line_shown=%s held=%d paused=%s" % [str(fin[0]), str(log), PauseStack.count(), str(get_tree().paused)])

	func _feet() -> void:
		for sc in [1, 2, 10, 30, 64, 68]:
			await level_at(sc)
			await wait(0.5)
			var pl: Node2D = get_tree().get_first_node_in_group("player")
			var ys: Array = []
			for k in 3:
				ys.append(int(pl.get_global_transform_with_canvas().origin.y))
				await wait(0.3)
			print("HUDP|feet|tela=%d|pes_tela_y=%s" % [sc, str(ys)])
