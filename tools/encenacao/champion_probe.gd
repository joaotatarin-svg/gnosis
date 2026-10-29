extends Node
## FERRAMENTA (não faz parte do jogo): sonda do CAMPEÃO (QA7 #12). Tela do Desafio
## (6 = Torpor): a Sophia anda e derruba as waves até o Campeão nascer. Confere
## que ele nasce DENTRO do quadro e que o card só sai com ele visível.
## Imprime "CAMPEAO|<item>|PASS/FAIL|detalhe". Headless serve.
## Uso: godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/encenacao/ChampionProbe.tscn -- [tela]

func _ready() -> void:
	var w := W.new()
	var a := OS.get_cmdline_user_args()
	w.screen = int(a[0]) if a.size() > 0 else 6
	get_tree().root.add_child.call_deferred(w)


class W extends Node:
	var screen: int = 6
	var _fails: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		AudioServer.set_bus_mute(0, true)
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func check(ok: bool, item: String, det: String = "") -> void:
		print("CAMPEAO|%s|%s|%s" % [item, "PASS" if ok else "FAIL", det])
		if not ok:
			_fails += 1

	func _champ() -> Node2D:
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.is_champion:
				return e
		return null

	func _card() -> bool:
		for c in get_tree().root.get_children():
			if c is Cinematic and not c.is_queued_for_deletion():
				return true
		return false

	func _skip() -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()

	func _run() -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		var lv: Level = null
		for i in 600:
			await get_tree().process_frame
			_skip()
			var cs := get_tree().current_scene
			if cs is Level and (cs as Level).player != null and bool(cs.get("_ready_done")):
				lv = cs
				break
		Input.action_press("move_right")
		var champ: Node2D = null
		var f := 0
		while f < 60 * 60 and champ == null:
			await get_tree().process_frame
			f += 1
			_skip()
			champ = _champ()
			if champ != null:
				break
			if f % 6 == 0:
				for e in get_tree().get_nodes_in_group("enemy"):
					if e is Enemy and e.estate != Enemy.EState.DEAD and not e.is_champion:
						e._on_hit_received(e.health.max_health + 999, lv.player.global_position, 60.0, false, null)
		Input.action_release("move_right")
		check(champ != null, "campeao_nasceu", "quadro %d" % f)
		if champ == null:
			get_tree().quit(1)
			return
		var vr := get_viewport().get_visible_rect()
		await get_tree().process_frame
		var sp: Vector2 = champ.get_global_transform_with_canvas().origin
		check(vr.has_point(sp), "nasce_no_quadro", "tela=%s mundo=%s sophia=%s" % [str(sp), str(champ.global_position), str(lv.player.global_position)])
		check(not _card(), "card_nao_no_mesmo_quadro", "")
		var t := 0.0
		var vis_at_card := false
		while t < 4.0:
			await get_tree().process_frame
			t += 1.0 / 60.0
			if _card():
				if is_instance_valid(champ):
					vis_at_card = vr.has_point(champ.get_global_transform_with_canvas().origin)
				break
		check(_card() or t < 4.0, "card_saiu", "%.2f s depois do nascimento" % t)
		check(vis_at_card, "campeao_visivel_no_card", "")
		print("CAMPEAO|RESULT|%d falhas" % _fails)
		get_tree().quit(1 if _fails > 0 else 0)
