extends Node
## FERRAMENTA QA7: tela do Soter (17/35/53). Um ShotWorker SEM o "anda até a
## próxima zona" (senão a Sophia é teleportada por cima do Soter) e um
## motorista que, a partir do quadro QA7_SOTER (padrão 40), limpa a zona 0,
## solta a Sophia 200 px antes do Soter e ANDA até ele (encontro de verdade);
## quando o DEGRAU DE LUZ aparece, corre até ele e faz o PULO DUPLO (2º pulo
## QA7_GAP quadros depois do 1º; padrão 16). Imprime a linha do tempo.
## Uso: igual ao tools/shot.gd: -- <tela> <saida.png> <frames> [seq=N every=K] [dialog]

const ShotScript = preload("res://tools/shot.gd")


class NoWalkWorker extends ShotScript.ShotWorker:
	func _walk_ahead(_cs: Node) -> void:
		pass


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var w := NoWalkWorker.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1: w.screen = int(args[0])
	if args.size() >= 2: w.out = args[1]
	if args.size() >= 3: w.frames = int(args[2])
	for i in range(3, args.size()):
		var kv := String(args[i]).split("=", true, 1)
		match kv[0]:
			"seq": w.seq_count = maxi(0, int(kv[1]))
			"every": w.seq_every = maxi(1, int(kv[1]))
			"dialog": w.keep_dialog = true
			"hold": w.hold = true
	get_tree().root.add_child.call_deferred(w)
	get_tree().root.add_child.call_deferred(SoterDriver.new())


class SoterDriver extends Node:
	var _f: int = 0
	var _go: int = 40
	var _gap: int = 16
	var _soter: Node2D
	var _ledge_f: int = -1
	var _held: Dictionary = {}
	var _last: String = ""
	var _j1: int = 9999
	var _walking: bool = false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var e := OS.get_environment("QA7_SOTER")
		if e != "": _go = int(e)
		var g := OS.get_environment("QA7_GAP")
		if g != "": _gap = int(g)

	func _physics_process(_d: float) -> void:
		for a in _held.keys():
			_held[a] -= 1
			if _held[a] <= 0:
				Input.action_release(a)
				_held.erase(a)
		if get_tree().paused:
			return
		_f += 1
		var pl := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if pl == null:
			return
		if _soter == null:
			for n in get_tree().get_nodes_in_group("_none_"):
				pass
			_soter = _find_soter(get_tree().current_scene)
		# 1) a partir de _go: limpa a zona (mata tudo, a zona destrava sozinha)
		var lv = get_tree().current_scene
		if _f == _go and lv is Level and lv.zone_index < 0:
			_press("move_right", 90)       # entra na zona 0 (dispara a luta)
		if _f >= _go and not _walking and _f % 20 == 0:
			var alive := 0
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and e.estate != Enemy.EState.DEAD and e.health != null:
					e.health.take_damage(99999)
					alive += 1
			if alive == 0 and lv is Level and lv.zone_index >= 0 and not lv.zone_active and _soter != null:
				# 2) solta a Sophia 200 px antes do Soter e ANDA até ele (encontro de verdade)
				_walking = true
				pl.global_position = Vector2(_soter.global_position.x - 200.0, pl.global_position.y)
				_press("move_right", 400)
				print("QA7SOTER f=%d zona limpa; anda até o Soter x=%.0f" % [_f, _soter.global_position.x])
		if _walking and _soter != null and is_instance_valid(_soter) and bool(_soter.triggered) and Input.is_action_pressed("move_right") and _ledge_f < 0:
			Input.action_release("move_right")
			_held.erase("move_right")
			print("QA7SOTER f=%d encontro disparou" % _f)
		var ledge = _soter.get("_ledge") if _soter != null and is_instance_valid(_soter) else null
		if ledge != null and is_instance_valid(ledge) and _ledge_f < 0:
			_ledge_f = _f
			print("QA7SOTER f=%d degrau em (%.0f,%.0f) Sophia (%.0f,%.0f) dj=%s" % [_f, ledge.global_position.x, ledge.global_position.y, pl.global_position.x, pl.global_position.y, str(Progression.has_double_jump())])
		if _ledge_f > 0:
			var t := _f - _ledge_f
			var dx: float = ledge.global_position.x - pl.global_position.x if ledge != null and is_instance_valid(ledge) else 0.0
			var dir := "move_right" if dx > 0 else "move_left"
			if t == 30:
				_press(dir, 40)
				_j1 = 30 + int(maxf(0.0, absf(dx) - 30.0) / 3.0)
			if t == _j1:
				_press("jump", 4)
				_press(dir, 30)
				print("QA7SOTER f=%d 1º pulo dx=%.0f" % [_f, dx])
			if t == _j1 + _gap:
				_press("jump", 4)
				print("QA7SOTER f=%d 2º pulo" % _f)
		var s := "chao" if pl.is_on_floor() else "ar"
		if s != _last or _f % 30 == 0:
			_last = s
			print("QA7SOTER f=%d y=%.0f x=%.0f %s" % [_f, pl.global_position.y, pl.global_position.x, s])

	func _press(a: String, n: int) -> void:
		Input.action_press(a)
		_held[a] = n

	func _find_soter(root: Node) -> Node2D:
		if root == null:
			return null
		for c in root.get_children():
			if c is NpcEncounter and String(c.kind) == "soter":
				return c
		return null
