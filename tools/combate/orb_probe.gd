extends Node
## FERRAMENTA (Combate, R6): mede o espaçamento das chegadas dos orbes de faísca.
## godot --headless --audio-driver Dummy --path . res://tools/combate/OrbProbe.tscn  (sem --fixed-fps: tempo real)
## Saída: "ORBPROBE dist=.. n=.. chegadas_ms=[..] passos_ms=[..]"

var _arrivals: Array = []
var _t0: int = 0   # ms REAIS do burst (rodar SEM --fixed-fps)
var _cases: Array = [[40.0, 9], [80.0, 9], [140.0, 9], [60.0, 3], [60.0, 5]]
var _player: Node2D


func _ready() -> void:
	_player = Node2D.new()
	_player.add_to_group("player")
	add_child(_player)
	_run_next.call_deferred()


func _run_next() -> void:
	if _cases.is_empty():
		get_tree().quit()
		return
	var c: Array = _cases.pop_front()
	_arrivals.clear()
	_player.global_position = Vector2(300.0 + c[0], 286.0)
	var origin := Vector2(300.0, 276.0)
	SparkOrb.burst(self, origin, int(c[1]))
	_t0 = Time.get_ticks_msec()
	for o in get_children():
		if o is SparkOrb:
			o.tree_exiting.connect(_on_orb_gone.bind(o))
	await get_tree().create_timer(3.0).timeout
	var steps: Array = []
	for i in range(1, _arrivals.size()):
		steps.append(_arrivals[i][1] - _arrivals[i - 1][1])
	print("ORBPROBE dist=%d n=%d chegadas(idx,ms)=%s passos_ms=%s" % [int(c[0]), int(c[1]), str(_arrivals), str(steps)])
	_run_next()


func _on_orb_gone(o: SparkOrb) -> void:
	if o.delivered:
		_arrivals.append([o.index, Time.get_ticks_msec() - _t0])
