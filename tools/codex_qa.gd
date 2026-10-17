extends Node
## QA de integração: navegação, perfis, fases, morte e isolamento do save.
## O fluxo usa dano sintético; a validação de combate real é outro teste.

func _ready() -> void:
	var worker := Worker.new()
	get_tree().root.add_child.call_deferred(worker)

class Worker extends Node:
	var errors: int = 0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run.call_deferred()

	func check(condition: bool, message: String) -> void:
		if condition:
			print("QA PASS: ", message)
		else:
			errors += 1
			push_error("QA FAIL: " + message)

	func wait(seconds: float = 0.65) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func shot(name: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/codex-" + name + ".png")

	func _has_pad(action: StringName, button: int) -> bool:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton and ev.button_index == button:
				return true
		return false

	func _has_axis(action: StringName, axis: int, sign_value: float) -> bool:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion and ev.axis == axis and signf(ev.axis_value) == signf(sign_value):
				return true
		return false

	func _has_key(action: StringName, key: int) -> bool:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and (ev.keycode == key or ev.physical_keycode == key):
				return true
		return false

	func _run() -> void:
		SaveManager.persist_enabled = false
		# Save isolado: o jogo usa a SUA pasta (GNOSIS-Codex) — ou, num worktree de
		# dev, a do override.cfg (GNOSIS-WT-<cargo>) — e nunca o user:// genérico
		# (app_userdata/<nome>) nem o de outro projeto. A pasta real tem que bater
		# com o nome configurado (prova que o motor está usando a configuração).
		var udir_name := String(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
		var udir := ProjectSettings.globalize_path("user://").trim_suffix("/")
		check(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
			and (udir_name == "GNOSIS-Codex" or udir_name.begins_with("GNOSIS-WT-"))
			and udir.get_file() == udir_name, "diretório de save independente (%s)" % udir.get_file())
		# QA_UX B1: só de controle o jogador precisa confirmar (A) e voltar (B) em
		# todo menu; as teclas de fábrica continuam.
		check(_has_pad(&"ui_accept", JOY_BUTTON_A) and _has_key(&"ui_accept", KEY_ENTER), "controle: A confirma (ui_accept) e Enter continua")
		check(_has_pad(&"ui_cancel", JOY_BUTTON_B) and _has_key(&"ui_cancel", KEY_ESCAPE), "controle: B volta (ui_cancel) e Esc continua")
		for dir in [[&"ui_up", JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0], [&"ui_down", JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0],
				[&"ui_left", JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0], [&"ui_right", JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0]]:
			check(_has_pad(dir[0], dir[1]) and _has_axis(dir[0], dir[2], dir[3]), "controle: %s com D-pad e analógico" % dir[0])
		get_tree().change_scene_to_file("res://scenes/ui/CharacterAtelier.tscn")
		await wait()
		var atelier = get_tree().current_scene
		for i in 8:
			atelier._select(i)
			for pose in atelier.POSES.size():
				atelier._set_pose(1)
				await get_tree().process_frame
			check(atelier.art.profile != null and not atelier.art.painted.is_empty(), "perfil ilustrado %d e 10 modos" % i)
			check(atelier.art.get_child_count() == (0 if i == 0 else 1),"troca de perfil libera o boneco anterior")
		atelier._select(1)
		atelier.art.set_anim("walk")
		await wait(0.1)
		atelier.frozen = true
		atelier.art.set_process(false)
		var frozen_angle: float = atelier.art.boss_puppet.bones.arm_l.rotation
		await wait(0.1)
		check(is_equal_approx(frozen_angle,atelier.art.boss_puppet.bones.arm_l.rotation),"pausa congela as articulações")
		atelier.frozen = false
		atelier.art.set_process(true)
		await wait(0.2)
		await shot("athoth")
		RunManager.saved_run = {"screen": 22, "test": "preservar"}
		CodexSession.start_demo()
		await wait(1.0)
		check(not SaveManager.persist_enabled, "desafio não escreve progresso")
		for stage in 3:
			var level = get_tree().current_scene
			check(level is Level and CodexSession.stage == stage, "entrada no encontro %d" % (stage + 1))
			if stage == 2:
				await shot("boss")
			var guard: int = 0
			while not level.completed and guard < 10:
				guard += 1
				for e in get_tree().get_nodes_in_group("enemy"):
					if e is Enemy and e.estate != Enemy.EState.DEAD:
						e._on_hit_received(99999, level.player.global_position, 10.0, false, null)
				await wait(1.1)
			check(level.completed, "limpeza do encontro %d" % (stage + 1))
			await wait()
			check(get_tree().paused and level.result_layer != null, "resultado e pausa do encontro %d" % (stage + 1))
			if stage < 2:
				for c in level.result_layer.get_children():
					if c is Button and c.text.begins_with("Próximo"):
						c.pressed.emit()
						break
				await wait(1.0)
		await shot("victory")
		get_tree().paused = false
		CodexSession.start_demo()
		await wait(1.0)
		var level = get_tree().current_scene
		level.player.health.take_damage(99999)
		await wait(1.2)
		check(level.completed and get_tree().paused, "morte abre resultado recuperável")
		for c in level.result_layer.get_children():
			if c is Button and c.text == "Tentar novamente":
				c.pressed.emit()
				break
		await wait(1.0)
		check(not get_tree().paused and get_tree().get_first_node_in_group("player").health.current_health > 0, "tentar novamente restaura a jogabilidade")
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
		await wait(1.0)
		check(not CodexSession.active, "menu encerra sandbox")
		check(RunManager.saved_run.get("test", "") == "preservar", "checkpoint anterior preservado")
		check(not SaveManager.persist_enabled, "preferência anterior de persistência restaurada")
		print("QA RESULT: ", errors, " falhas")
		get_tree().quit(0 if errors == 0 else 1)
