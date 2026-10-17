extends Node
## FERRAMENTA (Combate): o hitstop/slow-mo do Juice contam PASSOS (determinístico).
## godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/combate/HitstopProbe.tscn
## Esperado a 60 fps: hit_stop(0.1) ≈ 6 quadros; igual em toda rodada.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames_while(cond: Callable, limit: int = 2000) -> int:
	var n: int = 0
	while cond.call() and n < limit:
		await get_tree().process_frame
		n += 1
	return n


func _run() -> void:
	await get_tree().process_frame
	Juice.hit_stop(0.1)
	var a: int = await _frames_while(func() -> bool: return Juice.hitstop_active())
	await get_tree().process_frame
	Juice.hit_stop(0.05)
	await get_tree().process_frame
	await get_tree().process_frame
	Juice.hit_stop(0.1)            # estende: faltam 0,1 s a partir daqui (≈ 6 quadros)
	var b: int = await _frames_while(func() -> bool: return Juice.hitstop_active())
	var done := [false]
	Juice.slowmo_changed.connect(func(on: bool, _s: float) -> void:
		if not on: done[0] = true)
	Juice.slow_mo(0.25, 0.6)
	var c: int = await _frames_while(func() -> bool: return not done[0])
	print("HSPROBE hit_stop(0.1)=%d quadros  estendido(0.05→+0.1 após 2q)=%d  slow_mo(0.25,0.6)+rampa=%d  escala_final=%.2f" % [a, b, c, Engine.time_scale])
	var ok: bool = absi(a - 6) <= 1 and absi(b - 6) <= 1 and is_equal_approx(Engine.time_scale, 1.0)
	if ok:
		print("QA PASS: hitstop em passos (0,1 s ≈ 6 quadros a 60 fps)")
	else:
		push_error("QA FAIL: hitstop em passos (a=%d b=%d)" % [a, b])
	get_tree().quit()
