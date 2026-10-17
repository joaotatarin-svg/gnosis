extends Node
## SONDA DE QA-UX (não faz parte do jogo): casos pontuais de fluxo/feedback.
##  A) Crônicas: 1 toque de seta = 1 linha?
##  B) Estela: prompt e painel (tela 3), abrir com J e fechar com J.
##  C) Morte no ar: a Sophia cai até o chão e faz a pose de queda?
##  D) Pausa (Esc) apertada durante o card de chefe (tela 10).
##  E) Batalha final (68): qual chefe a barra mostra; bater só no Rei.
##  F) Fim de jogo: EndScreen depois do fade.
## Uso: godot --audio-driver Dummy --path . --resolution 1280x720 --position 4000,4000 \
##        res://tools/qa_ux/MiscProbe.tscn -- <pasta>

func _ready() -> void:
	var w := M.new()
	var a := OS.get_cmdline_user_args()
	w.out_dir = a[0] if a.size() > 0 else "user://"
	get_tree().root.add_child.call_deferred(w)


class M extends Node:
	var out_dir: String

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func shot(name: String) -> void:
		# headless (Linux/nuvem): sem imagem, só registra.
		if DisplayServer.get_name() == "headless":
			print("MISC|SHOT|(headless) ", name)
			return
		await RenderingServer.frame_post_draw
		var p := "%s/misc_%s.png" % [out_dir, name]
		get_viewport().get_texture().get_image().save_png(p)
		print("MISC|SHOT|", p)

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

	func dialogs_open() -> Array:
		var out := []
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				out.append(c)
		return out

	func skip_dialogs() -> void:
		for i in 40:
			var ds := dialogs_open()
			if ds.is_empty():
				return
			var d: DialogueBox = ds[0]
			if d._in_choices:
				await key(KEY_ENTER)
			else:
				await key(KEY_J)

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
		# ---- H) Legenda tamanho G com fala longa (tela 4) ----
		GameManager.settings["caption_size"] = 2
		await level_at(4)
		Gnosis.caption("Sophia", "A pedra dizia que antes de tudo havia um Silêncio inteiro. Por que isso me parece... uma lembrança? E por que a Voz se cala quando eu pergunto?")
		await wait(1.0)
		await shot("legenda_G")
		GameManager.settings["caption_size"] = 1
		# ---- A) Crônicas ----
		get_tree().change_scene_to_file("res://scenes/ui/Chronicles.tscn")
		await wait(0.8)
		var ch := get_tree().current_scene
		var s0: int = ch._sel
		await key(KEY_DOWN)
		var s1: int = ch._sel
		await key(KEY_DOWN, 0.25)
		var s2: int = ch._sel
		await key(KEY_S)
		var s3: int = ch._sel
		print("MISC|cronicas_sel|inicio=%d 1toque=%d toque_0.25s=%d tecla_S=%d" % [s0, s1, s2, s3])

		# ---- B) Estela (tela 3) ----
		await level_at(3)
		var lv: Level = get_tree().current_scene
		var stela: Node2D = null
		for c in lv.get_children():
			if c is Stela:
				stela = c
		if stela != null:
			lv.player.global_position = stela.global_position + Vector2(-40, -10)
			await wait(0.8)
			await shot("estela_prompt")
			await key(KEY_J)
			await wait(0.5)
			await shot("estela_painel")
			print("MISC|estela_painel_pausa|paused=", get_tree().paused)
			await key(KEY_J)
			await wait(0.6)
			print("MISC|estela_fecha_J|paused=", get_tree().paused)
			await shot("estela_depois")
		else:
			print("MISC|estela|nenhuma estela na tela 3")

		# ---- C) Morte no ar ----
		await level_at(2)
		lv = get_tree().current_scene
		var pl: Player = lv.player
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		await wait(0.3)
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.physical_keycode = KEY_SPACE
		e.pressed = true
		Input.parse_input_event(e)
		await wait(0.22)
		var y_air := pl.global_position.y
		pl.health.take_damage(99999)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await wait(1.2)
		await shot("morte_no_ar")
		print("MISC|morte_no_ar|y_no_golpe=%.0f y_1.2s=%.0f no_chao=%s estado=%d anim=%s" % [y_air, pl.global_position.y, str(pl.is_on_floor()), pl.state, str(pl.visual.get("anim_state"))])
		await wait(1.0)
		await skip_dialogs()
		await wait(1.0)

		# ---- D) Esc durante o card de chefe (tela 10) ----
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = 10
		GameManager.current_screen = 10
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(0.8)
		await skip_dialogs()
		lv = get_tree().current_scene
		var saw_card := false
		for i in 60:
			for c in get_tree().root.get_children():
				if c is Cinematic:
					saw_card = true
			if saw_card:
				break
			Input.action_press("move_right")
			await wait(0.05)
		Input.action_release("move_right")
		await wait(0.3)
		await key(KEY_ESCAPE)
		await wait(2.5)
		var pause_open := false
		for c in lv.get_children():
			if c.scene_file_path.ends_with("PauseMenu.tscn"):
				pause_open = true
		print("MISC|esc_no_card|card_visto=%s pausa_aberta=%s paused=%s gm_state=%d" % [str(saw_card), str(pause_open), str(get_tree().paused), GameManager.state])
		await shot("esc_no_card")
		var plc: Player = lv.player
		var cam: Camera2D = plc.get_node("Camera2D")
		var vis_rect := get_viewport().get_visible_rect()
		var scr := plc.get_global_transform_with_canvas().origin
		print("MISC|esc_no_card_player|pos=(%.0f,%.0f) tela_px=(%.0f,%.0f) viewport=%s cam_center=%s limites=[%d,%d] visivel=%s modulate=%s z=%d" % [plc.global_position.x, plc.global_position.y, scr.x, scr.y, str(vis_rect.size), str(cam.get_screen_center_position()), cam.limit_left, cam.limit_right, str(plc.visible and plc.visual.visible), str(plc.visual.modulate), plc.z_index])
		if pause_open:
			await key(KEY_ESCAPE)
		get_tree().paused = false

		# ---- G) Câmera na parede esquerda da arena olhando pra esquerda (tela 4, antes da zona) ----
		await level_at(5)
		lv = get_tree().current_scene
		for en in get_tree().get_nodes_in_group("enemy"):
			en.queue_free()
		lv.zone_active = false
		lv._unlock_zone()
		lv.zones = []
		lv.player.global_position = Vector2(Level.WALL_LEFT + 60.0, 280.0)
		Input.action_press("move_left")
		await wait(1.5)
		Input.action_release("move_left")
		await wait(1.2)
		var cam2: Camera2D = lv.player.get_node("Camera2D")
		var cc := cam2.get_screen_center_position()
		print("MISC|camera_parede_esq|player_x=%.0f centro=%.0f borda_esq_visivel=%.0f parede=%.0f (mostra %.0f px alem da parede)" % [lv.player.global_position.x, cc.x, cc.x - 320.0, Level.WALL_LEFT, Level.WALL_LEFT - (cc.x - 320.0)])
		await shot("camera_parede_esq")

		# ---- E) Batalha final: barra de chefe ----
		await level_at(68)
		await wait(2.5)
		lv = get_tree().current_scene
		var bosses := []
		for en in get_tree().get_nodes_in_group("enemy"):
			if en is Enemy and en.is_boss_enemy:
				bosses.append(en)
		var hud = get_tree().get_first_node_in_group("hud")
		print("MISC|final_chefes|", ", ".join(bosses.map(func(b): return "%s(%s) hp=%d/%d" % [b.display_name, b.type_id, b.health.current_health, b.health.max_health])), " | ", _barra(hud))
		# bate SÓ no primeiro (o Rei?) 60% da vida
		if bosses.size() >= 2:
			var b0: Enemy = bosses[0]
			b0._on_hit_received(int(b0.health.max_health * 0.6), lv.player.global_position, 10.0, false, null)
			await wait(0.4)
			print("MISC|final_apos_bater_em_%s|%s" % [b0.display_name, _barra(hud)])
			await shot("final_barra")
			# mata o primeiro: a barra some mesmo com o outro vivo?
			b0._on_hit_received(b0.health.max_health + 999, lv.player.global_position, 10.0, false, null)
			await wait(0.6)
			print("MISC|final_um_caiu|%s outro_vivo=%s" % [_barra(hud), str(bosses[1].estate != Enemy.EState.DEAD)])
			await shot("final_um_caiu")
		print("MISC|FIM")
		get_tree().quit()

	## Barra(s) de chefe do HUD em texto (HUD da onda 1: uma barra em `boss`; antigo: _boss_box).
	func _barra(hud) -> String:
		if hud == null:
			return "sem HUD"
		if hud.has_method("boss_bars"):
			return "barras=%s" % str(hud.call("boss_bars"))
		if "_boss_box" in hud:
			return "barra='%s' visivel=%s" % [hud._boss_name.text, str(hud._boss_box.visible)]
		var b = hud.get("boss")
		if b == null or not is_instance_valid(b):
			return "barra_visivel=false"
		var fase := " — FASE II" if int(hud.get("boss_phase_n")) >= 2 else ""
		return "barra='%s%s' visivel=true largura=%.0f%%" % [b.display_name, fase, float(hud.get("boss_ratio")) * 100.0]
