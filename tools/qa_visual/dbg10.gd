extends Node
func _ready() -> void:
	get_tree().root.add_child.call_deferred(W.new())
class W extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()
	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout
	func dump(tag: String) -> void:
		var names: Array = []
		for c in get_tree().root.get_children():
			names.append(c.get_class() + ":" + c.name + (" Q" if c.is_queued_for_deletion() else ""))
		print(tag, " paused=", get_tree().paused, " ", names.slice(14))
		var lv = get_tree().current_scene
		if lv is Level:
			print("   ready_done=", lv.get("_ready_done"), " zone=", lv.zone_index, " px=", lv.player.global_position, " state=", GameManager.state, " st=", lv.player.state)
	func _run() -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = 10
		GameManager.current_screen = 10
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(0.5)
		for _i in 30:
			var had := false
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					dump("box idx=%d ch=%d" % [c.idx, c.choices.size()])
					if c.choices.size() > 0:
						c._on_choice(0)
					else:
						c._finish()
					had = true
			if not had:
				break
			await wait(0.15)
		await wait(0.3)
		dump("pos-skip")
		var lv = get_tree().current_scene
		lv.player.global_position = Vector2(lv.zone_center(0) - Level.ZONE_TRIGGER + 8.0, 250.0)
		for k in 8:
			await wait(0.5)
			dump("t%d" % k)
		get_tree().quit()
