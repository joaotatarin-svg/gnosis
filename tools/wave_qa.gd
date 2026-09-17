extends Node2D
## Prancha das criaturas comuns (sem boneco): 6 bases × 5 estados, renderizada
## pelo próprio jogo. Verifica que o movimento procedural muda o corpo em cada
## estado e salva shots/waves.png pra inspeção visual.
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	SaveManager.persist_enabled = false
	GameManager.set_state(GameManager.State.MENU)
	RenderingServer.set_default_clear_color(Color("11171d"))
	await get_tree().process_frame
	var ids := ["larva", "servo", "espinho", "canino", "escudeiro", "invocador"]
	var states := ["idle", "walk", "windup", "attack", "hurt"]
	for row in ids.size():
		var type: Dictionary = Bestiary.get_type(ids[row])
		check(not type.is_empty(), "Tipo ausente: " + ids[row])
		var p: ArtProfile = type.profile
		for col in states.size():
			var art := CharacterArt.new()
			add_child(art)
			art.set_profile(p)
			art.set_process(false)
			var h: float = p.height * 1.3
			art.scale = Vector2.ONE * 88.0 / h
			art.position = Vector2(100 + col * 118, 96 + row * 112)
			art.set_anim(states[col])
			# Tempo fixo no meio da ação, pra pose ficar legível na prancha.
			art.anim_time = 0.09 if states[col] == "hurt" else 0.4
			art.pose_progress = 0.85 if states[col] == "windup" else (0.35 if states[col] == "attack" else -1.0)
			art.motion_stride = 1.0
			var m: Array = art._painted_motion()
			if states[col] != "idle":
				check(absf(m[0]) > 0.01 or absf(m[1]) > 0.01 or absf(m[2] - 1.0) > 0.01, "Sem movimento: " + ids[row] + "/" + states[col])
			if states[col] == "windup":
				check(m[0] < 0.0, "Preparar não recua: " + ids[row])
			if states[col] == "attack":
				check(m[0] > 0.0, "Golpe não avança: " + ids[row])
			art.queue_redraw()
			var label := Label.new()
			label.position = Vector2(col * 118 + 62, row * 112 + 2)
			label.add_theme_font_size_override("font_size", 9)
			label.text = ids[row] + " · " + states[col]
			add_child(label)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/waves.png")
	print("WAVE QA: ", failures, " falhas; seis bases, cinco estados")
	get_tree().quit(0 if failures == 0 else 1)
