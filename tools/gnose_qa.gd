extends Node
## FERRAMENTA (não faz parte do jogo): QA da GNOSE — Estela (prompt, painel,
## Crônica), card de chefe, prólogo, epílogo e a tela Crônicas. Com janela,
## salva capturas em shots/gnose_*.png; headless só valida.
## Uso: godot --path . res://tools/GnoseQA.tscn  (--headless pra só validar)

func _ready() -> void:
	var w := Worker.new()
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var errors: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run.call_deferred()

	func check(cond: bool, msg: String) -> void:
		if cond:
			print("QA PASS: ", msg)
		else:
			errors += 1
			push_error("QA FAIL: " + msg)

	func wait(seconds: float = 0.6) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func shot(name: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/" + name + ".png")
		print("SHOT salvo: shots/" + name + ".png")

	## Fecha diálogos abertos (escolha padrão) e cinemáticas (pula).
	func skip_all() -> void:
		for _i in 30:
			var had := false
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					if c.choices.size() > 0:
						c._on_choice(0)
					else:
						c._finish()
					had = true
				elif c is Cinematic:
					c._skip_all = true
					c._advance = true
					had = true
			if not had:
				return
			await wait(0.15)

	func goto_screen(s: int) -> void:
		RunManager.current_screen = s
		GameManager.current_screen = s
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(0.5)
		await skip_all()
		await wait(0.3)

	func find_child_of(node: Node, type) -> Node:
		for c in node.get_children():
			if is_instance_of(c, type):
				return c
		return null

	func _run() -> void:
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		Gnosis.unlocked.clear()
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		for sk in GameContent.characters[0].skills:
			if sk.ring != "":
				Progression.add_ring(sk.ring, sk.id)

		# 1. Estela + legenda de chegada (tela 15, uma zona: Estela à direita do descanso 0)
		Narrative.once("prologue")
		await goto_screen(15)
		await wait(1.0)
		var lv = get_tree().current_scene
		var stela: Stela = find_child_of(lv, Stela)
		check(stela != null, "Estela instanciada na tela 15")
		if stela != null:
			print("Estela em ", stela.global_position, " · player em ", lv.player.global_position)
			lv.player.global_position = stela.global_position + Vector2(44, -30)
			await wait(0.7)
			check(stela._near, "prompt de leitura ao chegar perto")
			await shot("gnose_stela")
			var before: int = Gnosis.chronicles_count()
			stela.open()
			await wait(0.6)
			check(get_tree().paused, "painel da Estela pausa o mundo")
			check(Gnosis.chronicles_count() == before + 1, "Crônica desbloqueada ao ler")
			await shot("gnose_stela_panel")
			for c in get_tree().root.get_children():
				if c is Stela.StelaPanel:
					get_tree().paused = false
					c.finished.emit()
					c.queue_free()
			await wait(0.5)
			check(not get_tree().paused, "painel fechou e o jogo voltou")

		# 2. Card de chefe (tela 10: o jogador cruza o gatilho e Athoth nasce)
		await goto_screen(10)
		lv = get_tree().current_scene
		lv.player.global_position = Vector2(lv.zone_center(0) - Level.ZONE_TRIGGER + 8.0, 250.0)
		await wait(0.5)
		var cin: Cinematic = find_child_of(get_tree().root, Cinematic)
		check(cin != null and get_tree().paused, "card de chefe congela ao nascer o Arconte")
		await shot("gnose_boss_card")
		await wait(2.6)
		check(not get_tree().paused, "card de chefe liberou o jogo")

		# 3. Prólogo (avulso) e epílogo (avulso)
		var pro := Cinematic.prologue()
		await wait(1.2)
		check(is_instance_valid(pro) and get_tree().paused, "prólogo pausa e mostra o card")
		await shot("gnose_prologue")
		await skip_all()
		await wait(0.8)
		check(not get_tree().paused, "prólogo pulável")
		GameManager.end_title = "SEMENTE"
		GameManager.end_subtitle = "Recusaste o trono e a porta. Desceste de volta, de faísca em faísca."
		var epi := Cinematic.epilogue("semente", Gnosis.chronicles_count(), Gnosis.chronicles_total())
		await wait(1.2)
		check(is_instance_valid(epi) and get_tree().paused, "epílogo pausa e mostra o card")
		await shot("gnose_epilogue")
		await skip_all()
		await wait(0.8)

		# 4. Crônicas
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/Chronicles.tscn")
		await wait(0.7)
		var ch = get_tree().current_scene
		check(ch != null and ch.get_script() != null and ch._entries.size() == 18, "Crônicas lista 18 entradas")
		ch._move(1)
		await wait(0.2)
		await shot("gnose_chronicles")

		print("QA RESULT: ", errors, " falhas")
		get_tree().quit(0 if errors == 0 else 1)
