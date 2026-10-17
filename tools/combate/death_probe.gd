extends Node
## FERRAMENTA (Combate): misericórdia oculta (§4) e morte no ar (QA_UX A4).
## godot --headless --audio-driver Dummy --path . res://tools/combate/DeathProbe.tscn
## Saída: "DEATHPROBE|..." + "QA PASS/FAIL".

func _ready() -> void:
	var w := P.new()
	get_tree().root.add_child.call_deferred(w)


class P extends Node:
	var errors: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func check(ok: bool, msg: String) -> void:
		if ok:
			print("QA PASS: ", msg)
		else:
			errors += 1
			push_error("QA FAIL: " + msg)

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
		await wait(0.15)

	func skip_dialogs() -> void:
		for i in 40:
			var d: DialogueBox = null
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					d = c
			if d == null:
				return
			await key(KEY_ENTER if d._in_choices else KEY_J)

	func level_at(screen: int) -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(0.8)
		await skip_dialogs()
		await wait(0.3)

	func _run() -> void:
		await level_at(2)
		var pl: Player = get_tree().current_scene.player
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		await wait(0.3)
		# --- misericórdia: golpe fatal com vida cheia → fica com 1; o segundo mata ---
		var hc: HealthComponent = pl.health
		hc.current_health = hc.max_health
		hc.take_damage(hc.max_health + 50)
		check(hc.current_health == 1 and not hc.is_dead(), "misericórdia segura o 1º golpe fatal (vida=%d)" % hc.current_health)
		hc.heal(hc.max_health)
		hc.take_damage(hc.max_health + 50)
		check(hc.is_dead(), "misericórdia só uma vez por luta")
		hc.heal(10)
		check(hc.is_dead(), "heal não revive (REVISAO #11)")
		# volta a viver para o teste A4 (cena nova)
		await wait(2.0)
		await level_at(2)
		pl = get_tree().current_scene.player
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		await wait(0.3)
		var hp0: int = pl.health.current_health
		pl.health.take_damage(-30)
		check(pl.health.current_health == hp0, "dano negativo não cura")
		pl.health.reset_mercy()
		pl.health.current_health = 5          # abaixo de 10 %: sem misericórdia
		# --- A4: pula e morre no ar ---
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.physical_keycode = KEY_SPACE
		e.pressed = true
		Input.parse_input_event(e)
		await wait(0.22)
		var y_air := pl.global_position.y
		pl.health.take_damage(50)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await wait(1.2)
		var anim: String = str(pl.visual.get("anim_state"))
		print("DEATHPROBE|morte_no_ar|y_no_golpe=%.0f y_1.2s=%.0f no_chao=%s estado=%d anim=%s" % [y_air, pl.global_position.y, str(pl.is_on_floor()), pl.state, anim])
		check(pl.is_on_floor() and pl.state == Player.State.DEAD and anim == "dead", "morta no ar cai até o chão e faz a pose dead (A4)")
		print("QA RESULT: ", errors, " falhas")
		get_tree().quit()
