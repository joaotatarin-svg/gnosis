extends Node
## FERRAMENTA (não faz parte do jogo): sonda da cena SOTER → PULO DUPLO (Narrativa 6).
## Tela 17 (1º encontro): leva a Sophia ao Soter, escolhe a 1ª bênção, passa as
## falas da LEVEZA fotografando cada uma, confere o pulo duplo concedido e o
## DEGRAU DE LUZ no alto; depois põe a Sophia em cima do degrau (o player desta
## base pode não ter o pulo duplo — a mecânica é do combate6) e confere que o
## Soter reconhece, paga e parte. Imprime "SOTER|<item>|PASS/FAIL|detalhe".
## Uso: godot --audio-driver Dummy --fixed-fps 60 --path . --resolution 320x180 --position 4000,4000 \
##        res://tools/encenacao/SoterProbe.tscn -- <pasta_saida>

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var w := W.new()
	var a := OS.get_cmdline_user_args()
	w.out_dir = a[0] if a.size() > 0 else "user://"
	get_tree().root.add_child.call_deferred(w)


class W extends Node:
	var out_dir: String
	var _fails: int = 0
	var _n: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func check(ok: bool, item: String, det: String = "") -> void:
		print("SOTER|%s|%s|%s" % [item, "PASS" if ok else "FAIL", det])
		if not ok:
			_fails += 1

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func shot(tag: String) -> void:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/soter_%02d_%s.png" % [out_dir, _n, tag])
		_n += 1

	func _box() -> DialogueBox:
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				return c
		return null

	func _run() -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = 17
		GameManager.current_screen = 17
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		var lv: Level = null
		for i in 240:
			await get_tree().process_frame
			var cs := get_tree().current_scene
			if cs is Level and (cs as Level).player != null:
				lv = cs
				break
		await wait(1.0)
		# caixas de chegada, se houver
		for i in 20:
			var b := _box()
			if b == null:
				break
			b._finish()
			await wait(0.2)
		var npc: NpcEncounter = null
		for c in lv.get_children():
			if c is NpcEncounter:
				npc = c
		check(npc != null and npc.kind == "soter" and npc.meeting == 0, "soter_na_tela", "")
		if npc == null:
			get_tree().quit(1)
			return
		# Anda como um jogador (as zonas trancam e caem: mata quem nasce) até o
		# encontro abrir — teleportar pula o gatilho das zonas e a câmera trava
		# na zona errada.
		Input.action_press("move_right")
		for i in 900:
			await wait(0.1)
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and e.estate != Enemy.EState.DEAD:
					e._on_hit_received(e.health.max_health + 999, lv.player.global_position, 60.0, false, null)
			if _box() != null:
				break
		Input.action_release("move_right")
		var line := -1
		var box_id := 0
		var guard := 0
		while guard < 120:
			guard += 1
			var b := _box()
			if b == null:
				await wait(0.3)
				if _box() == null:
					break
				continue
			if b.get_instance_id() != box_id:
				box_id = b.get_instance_id()
				line = -1
			if b.get("_in_choices"):
				await wait(0.6)
				b._on_choice(0)
				await wait(0.8)
				continue
			if b.idx != line:
				line = b.idx
				await wait(1.2)
				if b.is_typing():
					b.reveal_all()
				var txt := String(b.lines[line].get("text", "")) if line < b.lines.size() else ""
				await shot("fala_%s" % txt.left(10).replace(" ", "_").replace("(", "").replace("?", "").replace(":", ""))
			b.reveal_all()
			b.idx += 1
			b._show_line()
			await wait(0.2)
		await wait(0.5)
		var dj: bool = Progression.has_method("has_double_jump") and bool(Progression.call("has_double_jump")) \
			or ("double_jump" in Progression and bool(Progression.get("double_jump")))
		check(dj or not (Progression.has_method("grant_double_jump") or "double_jump" in Progression), "pulo_duplo_concedido",
			"sem API de progressão nesta base" if not (Progression.has_method("grant_double_jump") or "double_jump" in Progression) else "")
		var ledge: Node2D = null
		for c in lv.get_children():
			if c is StaticBody2D and c.has_method("reward"):
				ledge = c
		check(ledge != null, "degrau_de_luz", str(ledge.global_position) if ledge != null else "")
		check(ledge == null or absf((Level.GROUND_Y - ledge.global_position.y) - 116.0) < 1.0, "degrau_altura", "")
		check(is_instance_valid(npc) and npc.modulate.a > 0.9, "soter_espera", "")
		await shot("degrau")
		if ledge != null:
			# Em cima do degrau (pés na laje): o Soter reconhece e parte.
			lv.player.global_position = ledge.global_position + Vector2(0, -40)
			lv.player.velocity = Vector2.ZERO
			var gone := false
			for i in 120:
				await wait(0.05)
				if not is_instance_valid(npc) or npc.modulate.a < 0.5:
					gone = true
					break
			print("SOTER|dbg|-|player=%s chao=%s npc_a=%s" % [str(lv.player.global_position), str(lv.player.is_on_floor()), str(npc.modulate.a) if is_instance_valid(npc) else "livre"])
			await shot("no_degrau")
			check(gone, "soter_parte_ao_subir", "")
		print("SOTER|RESULT|%d falhas" % _fails)
		await wait(0.5)
		get_tree().quit(1 if _fails > 0 else 0)
