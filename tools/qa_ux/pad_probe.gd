extends Node
## SONDA DE QA-UX: só CONTROLE (gamepad). Testa se A confirma, B volta e se o
## foco lateral do menu alcança Crônicas e Sair. Eventos injetados (sem joystick físico).
## Uso: godot --audio-driver Dummy --path . --position 4000,4000 res://tools/qa_ux/PadProbe.tscn -- <pasta>

func _ready() -> void:
	var w := P.new()
	var a := OS.get_cmdline_user_args()
	w.out_dir = a[0] if a.size() > 0 else "user://"
	get_tree().root.add_child.call_deferred(w)


class P extends Node:
	var out_dir: String

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func pad(b: JoyButton) -> void:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = true
		Input.parse_input_event(e)
		await wait(0.06)
		var r := InputEventJoypadButton.new()
		r.button_index = b
		Input.parse_input_event(r)
		await wait(0.15)

	func key(k: Key) -> void:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = true
		Input.parse_input_event(e)
		await wait(0.06)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await wait(0.15)

	func focus() -> String:
		var f := get_viewport().gui_get_focus_owner()
		return "<nenhum>" if f == null else ("'%s'" % f.text if f is Button else f.get_class())

	func scene() -> String:
		var cs := get_tree().current_scene
		return cs.scene_file_path.get_file() if cs else "-"

	func _btn(text_part: String) -> Button:
		for b in get_tree().current_scene.find_children("*", "Button", true, false):
			if b.text.contains(text_part):
				return b
		return null

	func _run() -> void:
		RunManager.saved_run = {}
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		await wait(0.9)
		# lateral
		_btn("Ateliê").grab_focus()
		await key(KEY_RIGHT)
		print("PAD|menu.direita_de_Atelie|", focus())
		_btn("Opções").grab_focus()
		await key(KEY_RIGHT)
		print("PAD|menu.direita_de_Opcoes|", focus())
		await pad(JOY_BUTTON_DPAD_RIGHT)
		print("PAD|menu.dpad_direita|", focus())
		# A confirma?
		_btn("Nova campanha").grab_focus()
		await pad(JOY_BUTTON_A)
		await wait(1.0)
		print("PAD|A_em_Nova_campanha|cena=", scene())
		if scene() == "MainMenu.tscn":
			print("PAD|BUG?|A_nao_confirma|botão A do controle não aciona botões de menu")
		# Pré-jogo via teclado se A falhou
		if scene() == "MainMenu.tscn":
			await key(KEY_ENTER)
			await wait(1.0)
		print("PAD|pregame|", scene(), " foco=", focus())
		await pad(JOY_BUTTON_B)
		await wait(0.9)
		print("PAD|B_no_pregame|cena=", scene())
		# Diálogo: A avança? (A = pular; diálogo aceita jump)
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = 2
		GameManager.current_screen = 2
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(1.0)
		var dlg: DialogueBox = null
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				dlg = c
		if dlg != null:
			var i0 := dlg.idx
			await pad(JOY_BUTTON_A)
			print("PAD|dialogo_A_avanca|idx %d -> %d" % [i0, dlg.idx if is_instance_valid(dlg) else -1])
			await pad(JOY_BUTTON_X)
			print("PAD|dialogo_X_avanca|idx -> %d" % [dlg.idx if is_instance_valid(dlg) else -1])
			for k in 10:
				if is_instance_valid(dlg):
					await pad(JOY_BUTTON_A)
		await wait(0.5)
		# Pausa pelo Start → B fecha?
		await pad(JOY_BUTTON_START)
		await wait(0.3)
		print("PAD|start_pausa|paused=", get_tree().paused, " foco=", focus())
		await pad(JOY_BUTTON_A)    # "Continuar" focado
		await wait(0.3)
		print("PAD|A_em_Continuar_da_pausa|paused=", get_tree().paused)
		if get_tree().paused:
			await pad(JOY_BUTTON_B)
			await wait(0.3)
			print("PAD|B_na_pausa|paused=", get_tree().paused)
		get_tree().paused = false
		# Tentação do Arconte (escolha com botões): A escolhe?
		RunManager.current_screen = 10
		GameManager.current_screen = 10
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(1.0)
		for k in 12:
			var d: DialogueBox = null
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					d = c
			if d == null:
				break
			if d._in_choices:
				print("PAD|tentacao_escolhas|foco=", focus())
				get_viewport().get_texture().get_image().save_png(out_dir + "/pad_tentacao_escolha.png")
				await pad(JOY_BUTTON_A)
				await wait(0.3)
				var still := false
				for c in get_tree().root.get_children():
					if c is DialogueBox and c == d:
						still = true
				print("PAD|tentacao_A_escolhe|caixa_ainda_aberta=", still)
				if still:
					await key(KEY_ENTER)
				break
			await pad(JOY_BUTTON_A)
		print("PAD|FIM")
		get_tree().quit()
