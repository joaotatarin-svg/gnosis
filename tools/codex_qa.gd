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

	## REVISAO #2/#4/#6/#7: o preset leva licenças e o banco de controles, deixa
	## ferramentas/arte bruta de fora, e nada do jogo aponta para elas; patches
	## só da versão do projeto.
	## Espera o SceneManager terminar (transições + fila), com teto de 10 s —
	## máquina lenta não pode virar falso negativo.
	## Espera `cond` virar verdade por até `max_frames` quadros (padrão ~3 s).
	func _until(cond: Callable, max_frames: int = 180) -> bool:
		var n: int = 0
		while not cond.call() and n < max_frames:
			n += 1
			await get_tree().process_frame
		return cond.call()

	func _until_idle() -> void:
		await get_tree().process_frame
		var t0 := Time.get_ticks_msec()
		while SceneManager.is_busy() and Time.get_ticks_msec() - t0 < 10000:
			await get_tree().process_frame
		await wait(0.2)

	func _check_build_and_patches() -> void:
		var cfg := ConfigFile.new()
		var ok := cfg.load("res://export_presets.cfg") == OK
		var inc := String(cfg.get_value("preset.0", "include_filter", "")) if ok else ""
		var exc := String(cfg.get_value("preset.0", "exclude_filter", "")) if ok else ""
		var inc_ok := true
		for want in ["assets/LICENSES.md", "assets/fonts/*/OFL.txt", "assets/input/*.txt"]:
			inc_ok = inc_ok and want in inc
		var exc_ok := true
		for want in ["tools/*", "artes/*", "docs/*", "assets/_packs/*", "shots/*"]:
			exc_ok = exc_ok and want in exc
		check(ok and inc_ok, "export inclui LICENSES.md, OFL das fontes e assets/input/*.txt")
		check(ok and exc_ok, "export exclui tools/artes/docs/_packs/shots")
		var iss := FileAccess.get_file_as_string("res://installer/gnosis.iss")
		# A versão do instalador acompanha a do projeto (config/version).
		var ver := String(ProjectSettings.get_setting("application/config/version", ""))
		check(FileAccess.file_exists("res://LICENSE_godot.txt") and FileAccess.get_file_as_string("res://LICENSE_godot.txt").contains("Permission is hereby granted")
			and iss.contains("assets\\LICENSES.md") and iss.contains("LICENSE_godot.txt") and ver != "" and iss.contains("#define AppVersion \"%s\"" % ver),
			"instalador copia LICENSES.md e LICENSE_godot.txt (versão %s = projeto)" % ver)
		var refs: Array[String] = []
		for root in ["res://scripts", "res://scenes", "res://assets"]:
			_scan_dev_refs(root, refs)
		check(refs.is_empty(), "nada do jogo carrega res://tools, artes ou docs em runtime %s" % [refs])
		var got := GameManager.patch_files_for(PackedStringArray(["patch_1.1.0_02.pck", "patch_01.pck", "patch_1.0.0_a.pck",
			"patch_1.1.0_.pck", "patch_1.1.01_x.pck", "patch_1.1.0_01.pck", "outro.pck", "patch_1.1.0_03.txt"]), "1.1.0")
		check(got == ["patch_1.1.0_01.pck", "patch_1.1.0_02.pck"], "patches: só patch_<versão>_*.pck, em ordem (%s)" % [got])
		check(GameManager.patch_files_for(PackedStringArray(["patch_1.1.0_01.pck"]), "").is_empty(), "patches: sem versão no projeto, nenhum entra")

	func _scan_dev_refs(path: String, out: Array[String]) -> void:
		var d := DirAccess.open(path)
		if d == null or path.begins_with("res://assets/_packs"):
			return
		for f in d.get_files():
			if not (f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres")):
				continue
			var txt := FileAccess.get_file_as_string(path.path_join(f))
			for bad in ["res://tools/", "res://artes/", "res://docs/", "res://shots/"]:
				if txt.contains(bad):
					out.append(path.path_join(f))
		for sub in d.get_directories():
			_scan_dev_refs(path.path_join(sub), out)

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
		_check_build_and_patches()
		check(typeof(GameManager.SETTINGS_DEFAULT.get("reduce_flashes")) == TYPE_BOOL and GameManager.SETTINGS_DEFAULT.reduce_flashes == false, "opção reduce_flashes existe (bool, desligada)")
		check(CodexSession.screen_for(0, 0) == 2 and CodexSession.screen_for(1, 1) == 11 and CodexSession.screen_for(1, 2) == 19 and CodexSession.screen_for(6, 2) == RunManager.LAST_ARCHON_SCREEN, "Provação: tela do encontro segue o mapa de 9 telas por Éon")
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
		await _until_idle()
		check(not SaveManager.persist_run and not SaveManager.persist_enabled, "desafio não escreve progresso")
		for stage in 3:
			# Espera a fase do encontro estar no ar (troca de cena por estado, não por tempo).
			await _until(func(): return get_tree().current_scene is Level and CodexSession.stage == stage, 600)
			var level = get_tree().current_scene
			check(level is Level and CodexSession.stage == stage, "entrada no encontro %d" % (stage + 1))
			check(level is Level and RunManager.current_screen == CodexSession.screen_for(CodexSession.boss_index, stage) and RunManager.current_screen == level.screen, "encontro %d na tela do Éon certo (%d)" % [stage + 1, RunManager.current_screen])
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
			# Resultado: até ~3 s em quadros (sob carga o tempo fixo falhava).
			var shown: bool = await _until(func(): return get_tree().paused and is_instance_valid(level) and level.result_layer != null)
			check(shown, "resultado e pausa do encontro %d" % (stage + 1))
			if stage < 2 and shown:
				for c in level.result_layer.get_children():
					if c is Button and c.text.begins_with("Próximo"):
						c.pressed.emit()
						break
				await _until_idle()
		await shot("victory")
		get_tree().paused = false
		CodexSession.start_demo()
		await _until_idle()
		await _until(func(): return get_tree().current_scene is Level, 600)
		var level = get_tree().current_scene
		level.player.health.take_damage(99999)
		var dead_shown: bool = await _until(func(): return is_instance_valid(level) and level.completed and get_tree().paused and level.result_layer != null, 300)
		check(dead_shown, "morte abre resultado recuperável")
		if dead_shown:
			for c in level.result_layer.get_children():
				if c is Button and c.text == "Tentar novamente":
					c.pressed.emit()
					break
		await _until_idle()
		await _until(func(): return not get_tree().paused and get_tree().get_first_node_in_group("player") != null)
		check(not get_tree().paused and get_tree().get_first_node_in_group("player").health.current_health > 0, "tentar novamente restaura a jogabilidade")
		# REVISAO #12: pedido no meio do fade não se perde. (a) véu descendo: o
		# último pedido vira o destino; (b) véu abrindo: roda logo depois. A pilha
		# de pausa é zerada na troca.
		var holder := Node.new()
		get_tree().current_scene.add_child(holder)
		PauseStack.push(holder)
		SceneManager.change_scene("res://scenes/ui/Chronicles.tscn")
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
		await _until_idle()
		check(get_tree().current_scene.scene_file_path == "res://scenes/ui/MainMenu.tscn" and not SceneManager.is_busy(), "troca: pedido com o véu descendo vira o destino")
		check(PauseStack.count() == 0 and not get_tree().paused, "troca de cena zera a pilha de pausa")
		check(not CodexSession.active, "menu encerra sandbox")
		SceneManager.change_scene("res://scenes/ui/Chronicles.tscn")
		# Espera a cena nova entrar (véu ainda abrindo) e pede outra na hora.
		var guard_f: int = 0
		while (get_tree().current_scene == null or get_tree().current_scene.scene_file_path != "res://scenes/ui/Chronicles.tscn") and guard_f < 600:
			guard_f += 1
			await get_tree().process_frame
		var mid_swap: bool = SceneManager.is_busy()
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
		await _until_idle()
		check(mid_swap and get_tree().current_scene.scene_file_path == "res://scenes/ui/MainMenu.tscn" and not SceneManager.is_busy(), "troca: pedido com o véu abrindo roda em seguida")
		check(RunManager.saved_run.get("test", "") == "preservar", "checkpoint anterior preservado")
		check(not SaveManager.persist_enabled, "preferência anterior de persistência restaurada")
		print("QA RESULT: ", errors, " falhas")
		get_tree().quit(0 if errors == 0 else 1)
