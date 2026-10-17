extends Node
## FERRAMENTA (Combate2): limpeza dos destroços (backlog #23).
## godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/combate/GibProbe.tscn
## Confere: no máximo 30 peças vivas mesmo com 12 mortes seguidas; nenhuma passa
## da parede da arena; tudo some em ≤ 4 s; `clear_all` limpa na hora.
## Saída: "GIBPROBE|..." + "QA PASS/FAIL".

const LO := 100.0
const HI := 700.0


func _ready() -> void:
	_run.call_deferred()


class FakeLevel extends Node2D:
	## Imita a fase: paredes da zona trancada.
	func arena_bounds() -> Vector2:
		return Vector2(100.0, 700.0)


var errors: int = 0


func check(ok: bool, msg: String) -> void:
	if ok:
		print("QA PASS: ", msg)
	else:
		errors += 1
		push_error("QA FAIL: " + msg)


func _parts() -> Array:
	var poly := PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)])
	var parts: Array = []
	for i in 8:                      # 8 peças por corpo (cabeça, braços, pernas, cacos)
		var off := Vector2(randf_range(-10, 10), randf_range(-30, 0))
		var p := PackedVector2Array()
		for q in poly:
			p.append(q + off)
		parts.append({"pts": p, "col": Color(0.5, 0.4, 0.3)})
	return parts


func _run() -> void:
	seed(7)
	var lv := FakeLevel.new()
	add_child(lv)
	var max_live := 0
	var out_of_bounds := 0
	# 12 mortes em 1,2 s, perto das duas paredes e com chute forte para fora.
	for k in 12:
		var x := LO + 20.0 if k % 2 == 0 else HI - 20.0
		var kick := Vector2(-900.0 if k % 2 == 0 else 900.0, -300.0)
		Gib.burst(lv, Vector2(x, 260.0), _parts(), 1.0, 300.0, kick, Color(1, 0.9, 0.5), Color(0.1, 0.1, 0.1))
		for f in 6:
			await get_tree().physics_frame
			max_live = maxi(max_live, Gib.live_pieces())
			for g in get_tree().get_nodes_in_group("gib"):
				if (g as Node2D).global_position.x < LO - 1.0 or (g as Node2D).global_position.x > HI + 1.0:
					out_of_bounds += 1
	print("GIBPROBE|pico_pecas=%d|gotas=%d|fora=%d" % [max_live, Gib.live_drops(), out_of_bounds])
	check(max_live <= Gib.MAX_PIECES, "no máximo %d peças vivas (pico %d)" % [Gib.MAX_PIECES, max_live])
	check(out_of_bounds == 0, "nenhum destroço passa da parede da arena (%d quadros fora)" % out_of_bounds)
	# Tudo some em ≤ 4 s de jogo depois da última morte.
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while get_tree().get_nodes_in_group("gib").size() > 0 and frames < 400:
		await get_tree().physics_frame
		frames += 1
	var secs := float(frames) / float(Engine.physics_ticks_per_second)
	print("GIBPROBE|sumiram_em=%.2fs (%d quadros, %d ms reais)" % [secs, frames, Time.get_ticks_msec() - t0])
	check(frames < 400 and secs <= 4.0, "todos os destroços somem em ≤ 4 s (%.2f s)" % secs)
	# clear_all limpa na hora
	Gib.burst(lv, Vector2(400, 260), _parts(), 1.0, 300.0, Vector2.ZERO, Color(1, 0.9, 0.5), Color(0.1, 0.1, 0.1))
	await get_tree().process_frame
	Gib.clear_all()
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("gib").is_empty(), "Gib.clear_all() apaga tudo")
	print("GIBPROBE|fim|falhas=%d" % errors)
	get_tree().quit(1 if errors > 0 else 0)
