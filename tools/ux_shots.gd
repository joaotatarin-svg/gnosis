extends Node
## FERRAMENTA (não faz parte do jogo): percorre as telas de UX e salva um PNG
## de cada uma em shots/ux_*.png pra IA VER (menu com e sem save, confirmação,
## pré-jogo, golpes, opções, fim de jogo, HUD, pausa e seus overlays).
## Uso: godot --path . --resolution 1280x720 --position 4000,4000 res://tools/UxShots.tscn

func _ready() -> void:
	var w := Worker.new()
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		_run.call_deferred()

	func wait(seconds: float = 0.5) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func shot(name: String) -> void:
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://shots/ux_" + name + ".png")
		print("UX SHOT: ", name)

	func _process(_d: float) -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				c._finish()

	func _run() -> void:
		# 1. Menu sem save
		RunManager.saved_run = {}
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		await wait(0.9)
		await shot("menu_sem_save")
		# 2. Menu com save + aviso de save antigo descartado
		RunManager.saved_run = {"screen": 29, "difficulty": 1}
		SaveManager.notice = "Um progresso de versão anterior foi descartado (o mapa mudou). Faíscas totais, finais e opções foram preservados."
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		await wait(0.9)
		await shot("menu_com_save")
		# 3. Confirmação de nova campanha
		var menu = get_tree().current_scene
		menu._on_new_campaign()
		await wait(0.4)
		await shot("menu_confirma")
		# 4. Pré-jogo
		get_tree().change_scene_to_file("res://scenes/ui/PreGame.tscn")
		await wait(0.9)
		await shot("pregame")
		# 5. Golpes a partir do pré-jogo (arma nível 1 = quase tudo trancado)
		var pg = get_tree().current_scene
		pg._open_moves()
		await wait(0.4)
		await shot("moves_nv1")
		# 6. Opções (tela cheia)
		get_tree().change_scene_to_file("res://scenes/ui/OptionsMenu.tscn")
		await wait(0.9)
		await shot("options")
		# 7. Fim de jogo — vitória
		GameManager.end_title = "ASCENSÃO"
		GameManager.end_subtitle = "Sophia atravessa o véu. O Kenoma fica pra trás — e a luz que ela carregava volta pra Fonte, inteira."
		Narrative.ending = "ascensao"
		GameManager.current_screen = 68
		get_tree().change_scene_to_file("res://scenes/ui/EndScreen.tscn")
		await wait(0.9)
		await shot("end_vitoria")
		# 8. Fim de jogo — derrota fora de run (rara)
		Narrative.ending = ""
		GameManager.end_title = "Você caiu no Kenoma"
		GameManager.end_subtitle = "Chegou até a Tela 23."
		GameManager.current_screen = 23
		get_tree().change_scene_to_file("res://scenes/ui/EndScreen.tscn")
		await wait(0.9)
		await shot("end_derrota")
		# 9. HUD numa travessia (tela 12 = Fome · Travessia I) com arma 3 e 2 Anéis
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		RunManager.current_screen = 12
		GameManager.current_screen = 12
		Progression.weapon_level = 3
		var rs: Array = GameContent.ring_skills(GameContent.characters[0])
		Progression.add_ring(rs[0].ring, rs[0].id)
		Progression.add_ring(rs[1].ring, rs[1].id)
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(1.6)
		await shot("hud")
		# 10. Pausa
		var lv = get_tree().current_scene
		var pause = SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		GameManager.set_state(GameManager.State.PAUSED)
		await wait(0.4)
		await shot("pause")
		# 11. Pausa → Golpes (arma 3, 2 Anéis)
		pause._open_moves()
		await wait(0.4)
		await shot("moves_nv3")
		for c in pause.get_children():
			if c is MovesScreen:
				c._scroll.scroll_vertical = 100000
				await wait(0.2)
				await shot("moves_fim")
				c.close()
		await wait(0.3)
		# 12. Pausa → Opções (overlay)
		pause._open_options()
		await wait(0.4)
		await shot("pause_options")
		for c in pause.get_children():
			if c.has_method("_back") and "overlay" in c:
				c._back()
		await wait(0.3)
		# 13. Pausa → Melhorias (loja)
		pause._open_upgrades()
		await wait(0.4)
		await shot("pause_loja")
		for c in lv.get_children():
			if c is CanvasLayer and c.has_method("_close") and c != pause:
				c._close()
		await wait(0.3)
		# 14. Pausa → Abandonar (confirmação)
		pause._ask_quit()
		await wait(0.4)
		await shot("pause_abandonar")
		# 15. HUD do Arconte (tela 10) e do Centro (65)
		get_tree().paused = false
		pause.queue_free()
		RunManager.current_screen = 10
		GameManager.current_screen = 10
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(1.6)
		await shot("hud_arconte")
		# 16. Provação: resultado final (vitória no 3º encontro)
		CodexSession.start_demo()
		await wait(1.2)
		CodexSession.stage = 2
		var trial = get_tree().current_scene
		trial.completed = true
		trial._show_result(true)
		await wait(0.4)
		await shot("provacao_final")
		get_tree().paused = false
		print("UX SHOTS: fim")
		get_tree().quit()
