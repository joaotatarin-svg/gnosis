extends Node
## FERRAMENTA (não faz parte do jogo): sonda da CALMA das legendas (Narrativa 6).
## Tela 3: a Sophia entra na zona (inimigos nascem); uma legenda comum e uma
## `urgent` entram na fila. Confere: a comum ESPERA enquanto há inimigo vivo
## perto; a urgente passa; a comum aparece depois que a zona cai.
## Imprime "CALMA|<item>|PASS/FAIL|detalhe". Headless serve (não fotografa).
## Uso: godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/encenacao/CalmProbe.tscn

func _ready() -> void:
	get_tree().root.add_child.call_deferred(W.new())


class W extends Node:
	var _fails: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		AudioServer.set_bus_mute(0, true)
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func check(ok: bool, item: String, det: String = "") -> void:
		print("CALMA|%s|%s|%s" % [item, "PASS" if ok else "FAIL", det])
		if not ok:
			_fails += 1

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func _skip() -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				c._finish()

	func _run() -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = 3
		GameManager.current_screen = 3
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		var lv: Level = null
		for i in 300:
			await get_tree().process_frame
			_skip()
			var cs := get_tree().current_scene
			if cs is Level and (cs as Level).player != null and bool(cs.get("_ready_done")):
				lv = cs
				break
		await wait(0.5)
		var cap: CaptionBar = Gnosis.get("_caption")
		cap.clear()
		# Entra na zona 0: as waves nascem.
		lv.player.global_position.x = lv.zone_center(0) - Level.ZONE_TRIGGER + 10.0
		await wait(1.2)
		var alive := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.estate != Enemy.EState.DEAD:
				alive += 1
		check(alive > 0, "zona_com_inimigos", "%d vivos" % alive)
		cap.say_lines([{"speaker": "A Voz", "text": "Fala comum de teste."}])
		await wait(2.0)
		check(cap.is_holding() and not bool(cap.get("_showing")), "comum_espera_no_combate", "")
		cap.say_lines([{"speaker": "Athoth", "text": "Fala urgente.", "urgent": true}])
		await wait(1.5)
		var cur: Dictionary = cap.get("_current")
		check(bool(cap.get("_showing")) and String(cur.get("text", "")) == "Fala urgente.", "urgente_passa", String(cur.get("text", "")))
		# A zona cai (mata tudo, várias vezes: waves seguintes).
		for k in 40:
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and e.estate != Enemy.EState.DEAD:
					e._on_hit_received(e.health.max_health + 999, lv.player.global_position, 60.0, false, null)
			await wait(0.25)
			_skip()
			if not lv.zone_active:
				break
		var shown := false
		for k in 60:
			await wait(0.25)
			cur = cap.get("_current")
			if bool(cap.get("_showing")) and String(cur.get("text", "")) == "Fala comum de teste.":
				shown = true
				break
		check(shown, "comum_sai_na_calma", "")
		print("CALMA|RESULT|%d falhas" % _fails)
		get_tree().quit(1 if _fails > 0 else 0)
