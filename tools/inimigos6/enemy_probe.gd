extends Node
## FERRAMENTA (Inimigos6, Onda 6): SONDA DO REPERTÓRIO. Abre uma tela do run,
## tira as waves e, para cada tipo comum (+ um Campeão e um Elite), põe UM
## inimigo diante da Sophia e a teleporta por faixas de distância (perto, meio,
## longe) até o inimigo usar TODOS os golpes do repertório (EnemyMoves). A
## Sophia não morre (cura todo quadro) e golpeia de vez em quando (provoca guarda
## e esquiva). Também confere: voador fica no ar, Elite tem modificador, Campeão
## tem os golpes extras, alado/fantasma/cornudo NÃO usam a pintura do Arconte e
## a fila de agressão nunca deixa mais de 2 comuns atacando juntos.
##
## godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/inimigos6/EnemyProbe.tscn
##   [-- only=espectro,alado] [screen=40] [out=<pasta>]  (out = salva quadros; precisa de janela)
## Saída: "EPROBE|tipo|golpe=vezes ..." por tipo + "QA PASS/FAIL" + código 0/1.

const ENEMY_SCENE := "res://scenes/entities/Enemy.tscn"
const BANDS := [190.0, 130.0, 75.0, 30.0, 250.0, 60.0, 160.0, 100.0]
const MAX_T := 40.0               # s de jogo por tipo

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)   # ferramenta NUNCA toca som
	var w := P.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			w.only = a.trim_prefix("only=").split(",")
		elif a.begins_with("screen="):
			w.screen = int(a.trim_prefix("screen="))
		elif a.begins_with("out="):
			w.out = a.trim_prefix("out=")
		elif a.begins_with("frames="):
			w.cap_frames = int(a.trim_prefix("frames="))
	get_tree().root.add_child.call_deferred(w)


class P extends Node:
	var errors: int = 0
	var only: PackedStringArray = []
	var screen: int = 40
	var out: String = ""
	var cap_frames: int = 150
	var level: Node = null
	var player: Node2D = null
	var max_attackers: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, false).timeout

	func check(ok: bool, msg: String) -> void:
		if ok:
			print("QA PASS: ", msg)
		else:
			errors += 1
			printerr("QA FAIL: " + msg)

	func _skip_dialogs() -> void:
		for i in 60:
			var d: Node = null
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					d = c
			if d == null:
				return
			var e := InputEventKey.new()
			e.keycode = KEY_ENTER if d._in_choices else KEY_J
			e.physical_keycode = e.keycode
			e.pressed = true
			Input.parse_input_event(e)
			await wait(0.05)
			e = e.duplicate()
			e.pressed = false
			Input.parse_input_event(e)
			await wait(0.12)

	func _run() -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(0.8)
		await _skip_dialogs()
		await wait(0.3)
		get_tree().paused = false
		level = get_tree().current_scene
		player = get_tree().get_first_node_in_group("player")
		check(level != null and player != null, "tela %d carregou com a Sophia" % screen)
		if player == null:
			_finish()
			return
		# a tela não pode soltar waves/zonas enquanto a sonda teleporta a Sophia
		level.set_physics_process(false)
		level.set_process(false)
		_clear_enemies()
		_art_checks()
		var ids: Array = []
		for t in Bestiary.wave_types:
			if String(t.id) == "sombra_sophia":
				continue
			if EnemyMoves.for_type(t.id).is_empty():
				continue
			ids.append(String(t.id))
		var cases: Array = []
		for id in ids:
			cases.append({"id": id})
		cases.append({"id": "glutao", "champion": true})
		cases.append({"id": "servo", "elite": true})
		for c in cases:
			if not only.is_empty() and not only.has(String(c.id)):
				continue
			await _probe(c)
		await _queue_check()
		_finish()

	func _finish() -> void:
		print("EPROBE|fim|erros=%d" % errors)
		get_tree().quit(1 if errors > 0 else 0)

	func _clear_enemies() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e):
				e.remove_from_group("enemy")
				e.queue_free()

	## Pintura: alado/fantasma/cornudo/espectro não podem cair na família de um Arconte.
	func _art_checks() -> void:
		for id in ["alado", "fantasma", "cornudo", "espectro"]:
			var t: Dictionary = Bestiary.get_type(id)
			var d: Dictionary = PaintedLibrary.character(t.profile)
			check(String(d.get("sheet", "")) != "archons" and not bool(d.get("family", false)),
				"%s não usa a pintura de Arconte (folha %s, quadros %s)" % [id, d.get("sheet", ""), d.get("frames", "")])

	func _spawn(c: Dictionary, x: float) -> Enemy:
		var scn: PackedScene = load(ENEMY_SCENE)
		var e: Enemy = scn.instantiate()
		e.type_id = String(c.id)
		e.is_champion = bool(c.get("champion", false))
		e.is_elite = bool(c.get("elite", false))
		level.add_child(e)
		e.global_position = Vector2(x, player.global_position.y - 10.0)
		e.reset_physics_interpolation()
		return e

	func _probe(c: Dictionary) -> void:
		var id := String(c.id)
		var tag := id + (" (Campeão)" if c.get("champion", false) else (" (Elite)" if c.get("elite", false) else ""))
		var px: float = clampf(player.global_position.x, 300.0, 900.0)
		player.global_position.x = px
		var e := _spawn(c, px + 140.0)
		await get_tree().physics_frame
		e.health.setup(999999)
		var want: Array = []
		for m in e.moves:
			want.append(String(m.id))
		var t := 0.0
		var k := 0
		var next_tp := 1.0
		var next_atk := 0.7
		var flew := false
		var cap := 0
		var cap_dir := ""
		var used: Dictionary = {}
		var mod_seen := ""
		if out != "" and DisplayServer.get_name() != "headless":
			cap_dir = out.path_join(id + ("_campeao" if c.get("champion", false) else ("_elite" if c.get("elite", false) else "")))
			DirAccess.make_dir_recursive_absolute(cap_dir)
		while t < MAX_T:
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			t += dt
			if not is_instance_valid(e) or e.estate == Enemy.EState.DEAD:
				break
			used = e.used_moves.duplicate()
			if e.elite_mod != "":
				mod_seen = e.elite_mod
			_heal_player()
			max_attackers = maxi(max_attackers, EnemyAggro.count())
			if e.fly_height > 0.0 and e._flying() and player.global_position.y - e.global_position.y > e.fly_height * 0.6:
				flew = true
			if cap_dir != "" and cap < cap_frames and Engine.get_physics_frames() % 2 == 0:
				await _save_frame(cap_dir.path_join("f_%03d.png" % cap), e)
				cap += 1
			# teleporta a Sophia pelas faixas de distância (só fora de golpe)
			if t >= next_tp and e.estate == Enemy.EState.CHASE:
				next_tp = t + 1.4
				var band: float = BANDS[k % BANDS.size()]
				var side := -1.0 if (k / BANDS.size()) % 2 == 0 else 1.0
				k += 1
				var nx := clampf(e.global_position.x + side * band, 150.0, 1150.0)
				player.global_position.x = nx
				player.reset_physics_interpolation()
			# golpe leve de vez em quando (provoca guarda/esquiva)
			if t >= next_atk:
				next_atk = t + 1.1
				if player.has_method("_attack_input") and player.is_on_floor() and player.state in [Player.State.IDLE, Player.State.RUN]:
					var dxp: float = e.global_position.x - player.global_position.x
					if dxp != 0.0:
						player.facing = int(signf(dxp))
					player._attack_input("light")
			var done := true
			for w in want:
				if not used.has(w):
					done = false
					break
			if done and t > 3.0 and (cap_dir == "" or cap >= cap_frames):
				break
		var parts: Array = []
		var missing: Array = []
		for w in want:
			parts.append("%s=%d" % [w, int(used.get(w, 0))])
			if not used.has(w):
				missing.append(w)
		for r in ["_guarda", "_esquiva"]:
			if used.has(r):
				parts.append("%s=%d" % [r, int(used[r])])
		print("EPROBE|%s|%s|t=%.1fs" % [tag, " ".join(parts), t])
		check(want.size() >= 2, "%s tem 2+ golpes (%d)" % [tag, want.size()])
		check(missing.is_empty(), "%s usou todos os golpes (faltou: %s)" % [tag, ", ".join(missing)])
		var fh: float = float(EnemyMoves.for_type(id).get("fly", 0.0))
		if fh > 40.0:
			check(flew, "%s voou acima da Sophia" % tag)
		if c.get("elite", false):
			check(mod_seen != "", "%s tem modificador visível (%s)" % [tag, mod_seen])
		if c.get("champion", false):
			check(used.has("brado") and used.has("onda_dupla"), "%s usou os golpes de Campeão" % tag)
			check(is_instance_valid(e) and e.has_node("OverlayFront"), "%s tem aura/diadema" % tag)
		if is_instance_valid(e):
			e.queue_free()
		_clear_enemies()
		for n in level.get_children():
			if n is Projectile or n is HazardZone:
				n.queue_free()
		player.root_timer = 0.0
		await wait(0.2)

	## Fila: 5 servos ao redor da Sophia — no máximo 2 golpeiam ao mesmo tempo.
	func _queue_check() -> void:
		if not only.is_empty():
			return
		_clear_enemies()
		var px: float = clampf(player.global_position.x, 400.0, 800.0)
		player.global_position.x = px
		var es: Array = []
		for i in 5:
			var e := _spawn({"id": "servo"}, px + (-120.0 if i % 2 == 0 else 120.0) + float(i) * 8.0)
			es.append(e)
		await get_tree().physics_frame
		for e in es:
			e.health.setup(999999)
		var peak := 0
		var t := 0.0
		while t < 12.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			_heal_player()
			var n := 0
			for e in es:
				if is_instance_valid(e) and e.estate in [Enemy.EState.WINDUP, Enemy.EState.STRIKE]:
					n += 1
			peak = maxi(peak, n)
		print("EPROBE|fila|pico_atacando=%d" % peak)
		check(peak >= 1 and peak <= EnemyAggro.MAX_ATTACKERS, "fila de agressão: pico de %d atacando juntos (máx %d)" % [peak, EnemyAggro.MAX_ATTACKERS])
		_clear_enemies()

	func _heal_player() -> void:
		var h = player.get("health")
		if h is HealthComponent:
			h.current_health = h.max_health
		if player.state == Player.State.DEAD:
			player.state = Player.State.IDLE

	## Captura por um SubViewport que enxerga o MESMO mundo em 960×540 (a janela
	## do jogo fica mínima e fora da tela — regra do dono) e recorta 480×270 em
	## volta da luta. Sem as camadas de fundo/HUD (CanvasLayer): fundo escuro.
	var _sv: SubViewport = null

	func _save_frame(path: String, e: Node2D) -> void:
		if _sv == null:
			_sv = SubViewport.new()
			_sv.size = Vector2i(960, 540)
			_sv.world_2d = get_viewport().world_2d
			_sv.transparent_bg = false
			_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(_sv)
		var mid: Vector2 = (player.global_position + e.global_position) * 0.5 + Vector2(0, -40)
		_sv.canvas_transform = Transform2D(0.0, Vector2(2.0, 2.0), 0.0, Vector2(480, 270) - mid * 2.0)
		await RenderingServer.frame_post_draw
		var img := _sv.get_texture().get_image()
		img.get_region(Rect2i(0, 0, 960, 540)).save_png(path)
