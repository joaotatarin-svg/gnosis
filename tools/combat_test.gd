extends Node
## FERRAMENTA (não faz parte do jogo): BOT de combate. Abre uma tela do run e
## injeta uma sequência de inputs (anda, ataca, pula, esquiva) com timestamps,
## imprimindo o que o herói fez (golpe, estado) e o que aconteceu com os inimigos.
## Serve pra validar combos/lançador/aéreo/esquiva sem o usuário jogar, e salva
## um PNG no fim. Uso:
##   godot --path . res://tools/CombatTest.tscn -- <tela> <saida.png> [nivel_arma]

func _ready() -> void:
	var b := Bot.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		b.screen = int(args[0])
	if args.size() >= 2:
		b.out = args[1]
	if args.size() >= 3:
		b.weapon_level = int(args[2])
	get_tree().root.add_child.call_deferred(b)


class Bot extends Node:
	var screen: int = 3
	var out: String = "user://combat.png"
	var weapon_level: int = 5
	var _t: float = 0.0
	var _step: int = 0
	var _started: bool = false
	var _log: Array[String] = []
	var _last_move: String = ""
	var _last_state: int = -1

	# [tempo, ação, "press"/"release"/"tap"] — ritmo do Combate 6: cada string
	# espera a recuperação do final (o fim do combo compromete).
	var actions: Array = [
		[0.3, "move_right", "press"],
		[1.6, "move_right", "release"],
		[1.7, "attack_light", "tap"], [1.95, "attack_light", "tap"], [2.2, "attack_light", "tap"],   # L L L
		[3.4, "attack_light", "tap"], [3.65, "attack_light", "tap"], [3.9, "attack_heavy", "tap"],   # L L H (lançador)
		[5.3, "attack_light", "tap"], [5.55, "attack_heavy", "tap"],                                 # L H (corte ascendente)
		[6.6, "jump", "tap"], [6.85, "attack_light", "tap"],                                         # aéreo: giro
		[7.8, "jump", "tap"], [8.0, "attack_heavy", "tap"], [8.1, "attack_heavy", "tap"],            # aéreo: queda (2º aperto NÃO sai)
		[9.6, "attack_heavy", "tap"], [10.2, "attack_heavy", "tap"], [10.8, "attack_heavy", "tap"],  # H H H
		[12.4, "attack_light", "tap"], [12.65, "attack_light", "tap"], [12.9, "attack_light", "tap"], [13.15, "attack_heavy", "tap"],  # L L L H (fúria)
		[14.6, "dodge", "tap"],
		[15.2, "attack_light", "tap"], [15.45, "attack_light", "tap"], [15.7, "attack_light", "tap"], [15.95, "attack_light", "tap"], # L L L L
		[17.0, "jump", "tap"], [17.3, "jump", "tap"], [17.5, "attack_heavy", "tap"],                 # pulo duplo (flag forçada) + queda
		[18.4, "jump", "tap"], [18.7, "jump", "tap"],                                                # pulo duplo de novo, sem golpe
	]
	var _started_moves: Dictionary = {}    # id -> quantas vezes começou
	var _double_jumps: int = 0
	var _air_left_prev: int = -1


	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false   # ferramenta não suja o save real
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		Progression.weapon_level = weapon_level
		for sk in GameContent.characters[0].skills:
			if sk.ring != "":
				Progression.add_ring(sk.ring, sk.id)
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")


	func _process(delta: float) -> void:
		# pula diálogos
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
				return
		var pl: Player = get_tree().get_first_node_in_group("player")
		if pl == null:
			return
		if not _started:
			_started = true
			_say("Golpes liberados (arma nv.%d): %s" % [weapon_level, ", ".join(Progression.unlocked_combos(pl.data).map(func(m): return m.id))])
		_t += delta
		# os inimigos apanham mas não interrompem o roteiro (dano = ruído no teste)
		pl.invuln_timer = maxf(pl.invuln_timer, 0.1)
		if _t >= 16.9:
			pl.set("debug_double_jump", true)
		var al = pl.get("_air_jumps_left")
		if al != null:
			if _air_left_prev == 1 and int(al) == 0 and not pl.is_on_floor():
				_double_jumps += 1
				_say("t=%.2f PULO DUPLO" % _t)
			_air_left_prev = int(al)
		while _step < actions.size() and _t >= float(actions[_step][0]):
			var a: String = actions[_step][1]
			var kind: String = actions[_step][2]
			match kind:
				"press": Input.action_press(a)
				"release": Input.action_release(a)
				"tap":
					Input.action_press(a)
					_release_later(a)
			_step += 1
		# observa o herói
		var mv := pl.current_move.id if pl.current_move != null else "-"
		if pl.state == Player.State.ATTACK and (mv != _last_move or _last_state != Player.State.ATTACK):
			_started_moves[mv] = int(_started_moves.get(mv, 0)) + 1
		if mv != _last_move or pl.state != _last_state:
			_last_move = mv
			_last_state = pl.state
			var airborne := "" if pl.is_on_floor() else " (NO AR)"
			_say("t=%.2f estado=%s golpe=%s%s" % [_t, Player.State.keys()[pl.state], mv, airborne])
		if _t > 19.8:
			_finish(pl)


	func _release_later(a: String) -> void:
		await get_tree().create_timer(0.06, true, false, true).timeout
		Input.action_release(a)


	func _say(s: String) -> void:
		_log.append(s)
		print("BOT ", s)


	func _finish(pl: Player) -> void:
		set_process(false)
		var alive := 0
		var airborne := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.estate != Enemy.EState.DEAD:
				alive += 1
				if not e.is_on_floor():
					airborne += 1
		_say("golpes: %s · pulos duplos: %d" % [str(_started_moves), _double_jumps])
		var fails: Array[String] = []
		for need in ["m_LLL", "m_LLH", "m_LH", "a_L", "a_H", "m_HHH", "m_LLLH", "m_LLLL"]:
			if weapon_level >= 5 and not _started_moves.has(need):
				fails.append("faltou " + need)
		if int(_started_moves.get("a_H", 0)) > 2:
			fails.append("Queda Estelar saiu %d vezes (máx. 2: 1 por pulo)" % int(_started_moves.get("a_H", 0)))
		if pl.get("_air_jumps_left") != null and _double_jumps < 2:
			fails.append("pulo duplo saiu %d vezes (esperado 2)" % _double_jumps)
		if fails.is_empty():
			print("QA PASS: CombatTest (strings, aéreos 1 por pulo, pulo duplo)")
		else:
			print("QA FAIL: CombatTest — " + "; ".join(fails))
		_say("FIM: vida=%d/%d éter=%d inimigos vivos=%d no ar=%d faíscas=%d" % [pl.health.current_health, pl.health.max_health, int(pl.mana), alive, airborne, Progression.orbs])
		var img := get_viewport().get_texture().get_image() if DisplayServer.get_name() != "headless" else null
		if img != null:
			img.save_png(out)
			print("SHOT salvo: ", out)
		get_tree().quit()
