extends Node
## Bot sem cura ou dano artificial. Exercita os inputs reais do desafio padrão.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Pilot.new())

class Pilot extends Node:
	var attack_clock: float = 0.0
	var cast_clock: float = 0.0
	var dodge_clock: float = 0.0
	var attack_index: int = 0
	var time: float = 0.0
	var transitioning: bool = false
	var last_stage: int = -1
	var captured: bool = false
	var got_damage: bool = false
	var seen_phase2: bool = false
	var finished: bool = false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		CodexSession.start_demo()

	func tap(action: String) -> void:
		Input.action_press(action)
		await get_tree().create_timer(0.035, true, false, true).timeout
		Input.action_release(action)

	func _physics_process(delta: float) -> void:
		if finished:
			return
		time += delta
		if time > 180.0:
			print("PLAYTEST FAIL: limite de 180 segundos")
			get_tree().quit(1)
			return
		var level = get_tree().current_scene
		if level == null or not level.has_method("_show_result") or transitioning:
			return
		if level.result_layer != null:
			Input.action_release("move_left")
			Input.action_release("move_right")
			if level.player.health.current_health <= 0:
				print("PLAYTEST FAIL: derrota na etapa ", CodexSession.stage + 1)
				get_tree().quit(1)
				return
			if CodexSession.stage == 2:
				finished = true
				print("PLAYTEST PASS: três encontros vencidos por inputs; tempo=%.1f combo=%d dano_real=%s fase2=%s" % [CodexSession.elapsed, CodexSession.best_combo, got_damage, seen_phase2])
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("res://shots/codex-playtest-win.png")
				get_tree().quit()
				return
			transitioning = true
			print("PLAYTEST etapa ", CodexSession.stage + 1, " vencida; hp=", level.player.health.current_health)
			get_tree().paused = false
			CodexSession.next_stage()
			await get_tree().create_timer(0.8, true, false, true).timeout
			transitioning = false
			return
		if level.completed or GameManager.state != GameManager.State.PLAYING:
			return
		var pl: Player = level.player
		if pl.health.current_health < pl.health.max_health:
			got_damage = true
		if CodexSession.stage != last_stage:
			last_stage = CodexSession.stage
			print("PLAYTEST etapa ", last_stage + 1, " começou")
		var target: Enemy
		var distance: float = INF
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.estate != Enemy.EState.DEAD:
				if e.is_boss_enemy and e.phase == 2:
					seen_phase2 = true
				var d: float = absf(e.position.x - pl.position.x)
				if d < distance:
					distance = d
					target = e
		if target == null:
			Input.action_release("move_left")
			Input.action_release("move_right")
			return
		var dx: float = target.position.x - pl.position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if distance > 37.0 or (signf(dx) != pl.facing and distance > 3.0):
			Input.action_press("move_right" if dx > 0 else "move_left")
		attack_clock += delta
		cast_clock += delta
		dodge_clock -= delta
		if target.estate == Enemy.EState.WINDUP and target.attack_timer < 0.18 and distance < 115 and dodge_clock <= 0:
			tap("dodge")
			dodge_clock = 1.1
		if cast_clock > 3.2:
			tap("skill2")
			cast_clock = 0
		if distance < 85 and attack_clock > 0.29:
			attack_clock = 0
			attack_index += 1
			tap("attack_heavy" if attack_index % 3 == 0 else "attack_light")
		if not captured and CodexSession.stage == 2 and seen_phase2 and pl.state == Player.State.ATTACK and DisplayServer.get_name() != "headless":
			captured = true
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://shots/codex-combat.png")
