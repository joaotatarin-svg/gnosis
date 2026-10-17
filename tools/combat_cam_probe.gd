extends Node
## FERRAMENTA (não faz parte do jogo): SONDA DA CÂMERA. Abre uma tela do run,
## pula diálogos e, quadro a quadro, mede onde a Sophia aparece NA TELA
## (x/y em pixels do viewport 640×360), os limites da câmera e o estado.
## Roda um roteiro "vira + esquiva" (o caso em que ela saía do quadro) e
## imprime quantos quadros ela passou fora / perto da borda.
## Uso (headless serve — mede pela transformação do canvas):
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/CombatCamProbe.tscn -- <tela> [log.csv]
## Saída: "CAMPROBE fora=N borda=M minx=.. maxx=.. miny=.. maxy=.." e o CSV opcional.

func _ready() -> void:
	var w := Worker.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.screen = int(args[0])
	if args.size() >= 2:
		w.csv = args[1]
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var screen: int = 3
	var csv: String = ""
	var _t: int = -1
	var _wait: int = 0
	var _rows: PackedStringArray = []
	var _out: int = 0
	var _edge: int = 0
	var _minx: float = 9999.0
	var _maxx: float = -9999.0
	var _miny: float = 9999.0
	var _maxy: float = -9999.0
	# [frame, ação, "press"/"release"/"tap"] — corre pra direita, vira, esquiva
	# pra esquerda, vira de novo e esquiva pra direita (o pior caso).
	var script_acts: Array = [
		[0, "move_right", "press"],
		[50, "move_right", "release"],
		[50, "move_left", "press"],
		[53, "dodge", "tap"],
		[75, "dodge", "tap"],
		[100, "move_left", "release"],
		[100, "move_right", "press"],
		[102, "dodge", "tap"],
		[125, "move_right", "release"],
		[140, "move_left", "press"],
		[142, "dodge", "tap"],
		[170, "move_left", "release"],
		[171, "attack_heavy", "tap"],
		[200, "move_right", "press"],
		[202, "dodge", "tap"],
		[240, "move_right", "release"],
	]
	var _taps: Dictionary = {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _physics_process(_delta: float) -> void:
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
		# Inimigos congelados e invisíveis: medimos só a câmera.
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Node2D and e.process_mode != Node.PROCESS_MODE_DISABLED:
				e.process_mode = Node.PROCESS_MODE_DISABLED
				e.visible = false
		_wait += 1
		if _wait < 90:
			return
		_t += 1
		for a in script_acts:
			if int(a[0]) == _t:
				match a[2]:
					"press": Input.action_press(a[1])
					"release": Input.action_release(a[1])
					"tap":
						Input.action_press(a[1])
						_taps[a[1]] = 3
		for k in _taps.keys():
			_taps[k] -= 1
			if _taps[k] <= 0:
				Input.action_release(k)
				_taps.erase(k)
		var p: Vector2 = pl.get_global_transform_with_canvas().origin
		var cam: Camera2D = pl.get_node("Camera2D")
		_minx = minf(_minx, p.x)
		_maxx = maxf(_maxx, p.x)
		_miny = minf(_miny, p.y)
		_maxy = maxf(_maxy, p.y)
		# Fora = o centro dela passou da borda; borda = a menos de 24 px (meio corpo).
		if p.x < 0.0 or p.x > 640.0:
			_out += 1
		elif p.x < 24.0 or p.x > 616.0:
			_edge += 1
		_rows.append("%d,%.1f,%.1f,%.1f,%s,%d,%d" % [_t, p.x, p.y, pl.global_position.x, Player.State.keys()[pl.state], cam.limit_left, cam.limit_right])
		if _t >= 260:
			print("CAMPROBE tela=%d fora=%d borda=%d minx=%.0f maxx=%.0f miny=%.0f maxy=%.0f zoom=%.2f" % [screen, _out, _edge, _minx, _maxx, _miny, _maxy, cam.zoom.x])
			if csv != "":
				var f := FileAccess.open(csv, FileAccess.WRITE)
				if f != null:
					f.store_string("t,sx,sy,wx,state,limL,limR\n" + "\n".join(_rows))
					f.close()
			get_tree().quit()
