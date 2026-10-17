extends Node2D
## FERRAMENTA (Combate): confere o VfxLibrary.prewarm(parent).
## godot --headless --audio-driver Dummy --path . res://tools/combate/PrewarmProbe.tscn
## Saída: "PREWARM ms=.. tremores=.. sobrou=.. " + "QA PASS/FAIL".

var _shakes: int = 0


func _ready() -> void:
	Juice.shake_requested.connect(func(_t: float) -> void: _shakes += 1)
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	VfxLibrary.prewarm(self)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var made: bool = get_node_or_null("VfxPrewarm") != null
	await get_tree().create_timer(0.8, true, false, true).timeout
	await get_tree().process_frame     # (um quadro longo pode soltar os dois timers juntos)
	var left: bool = get_node_or_null("VfxPrewarm") != null
	print("PREWARM ms=%.1f tremores=%d criou=%s sobrou=%s" % [ms, _shakes, made, left])
	if made and not left and _shakes == 0:
		print("QA PASS: prewarm cria, não treme e se desfaz")
	else:
		push_error("QA FAIL: prewarm (criou=%s sobrou=%s tremores=%d)" % [made, left, _shakes])
	get_tree().quit()
