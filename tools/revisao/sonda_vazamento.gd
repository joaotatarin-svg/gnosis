extends Node
## SONDA DE REVISÃO (não faz parte do jogo): atravessa N telas do run
## matando tudo e andando até a fenda; a cada tela nova registra objetos,
## nós, órfãos, filhos do root e tempo de script — vazamento cresce tela a tela.
## Uso: godot --headless --fixed-fps 60 --audio-driver Dummy --path . res://tools/revisao/SondaVazamento.tscn -- <tela_inicial> <n_telas>

func _ready() -> void:
	var w := Worker.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1: w.start = int(args[0])
	if args.size() >= 2: w.count = int(args[1])
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var start: int = 2
	var count: int = 12
	var _last_id: int = 0
	var _visited: int = 0
	var _f: int = 0
	var _since: int = 0
	var _proc_sum: float = 0.0
	var _phys_sum: float = 0.0
	var _frames_lvl: int = 0
	var _max_nodes: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = start
		GameManager.current_screen = start
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_d: float) -> void:
		_f += 1
		_since += 1
		for c in get_tree().root.get_children():
			if c is DialogueBox and c.is_node_ready():
				if c.choices.size() > 0: c._on_choice(0)
				else: c._finish()
		var lv := get_tree().current_scene as Level
		if lv == null:
			return
		_proc_sum += Performance.get_monitor(Performance.TIME_PROCESS)
		_phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		_frames_lvl += 1
		_max_nodes = maxi(_max_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		if lv.get_instance_id() != _last_id:
			if true:
				print("VAZ tela=%d objetos=%d nos=%d orfaos=%d root_filhos=%d recursos=%d | tela anterior: proc_med=%.2fms fis_med=%.2fms pico_nos=%d" % [
					lv.screen, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
					Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), get_tree().root.get_child_count(),
					Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
					1000.0 * _proc_sum / maxf(1.0, _frames_lvl), 1000.0 * _phys_sum / maxf(1.0, _frames_lvl), _max_nodes])
			_last_id = lv.get_instance_id()
			_visited += 1
			_proc_sum = 0.0
			_phys_sum = 0.0
			_frames_lvl = 0
			_max_nodes = 0
			if _visited > count:
				get_tree().quit()
				return
		if not lv._ready_done or lv.player == null:
			return
		# Cada 45 frames: mata o que estiver vivo (golpe pesado — gera gibs/vfx).
		if _since % 45 == 0:
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and e.estate != Enemy.EState.DEAD:
					e._on_hit_received(e.health.max_health + 999, lv.player.global_position, 60.0, false, null)
		# Loja pós-chefe: fecha.
		for c in lv.get_children():
			if c is CanvasLayer and c.has_method("_buy_heal") and _since % 60 == 0:
				c._close()
		if lv.zone_active:
			return
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.estate != Enemy.EState.DEAD:
				return
		for c in lv.get_children():
			if c is ExitPortal:
				lv.player.global_position = c.global_position + Vector2(0, -10)
				return
		var nxt: int = lv.zone_index + 1
		if nxt < lv.zones.size():
			lv.player.global_position = Vector2(lv.zone_center(nxt) - Level.ZONE_TRIGGER + 8.0, 250.0)
		if _f > 60 * 60 * 15:
			print("VAZ TIMEOUT")
			get_tree().quit()
