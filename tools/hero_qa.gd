extends Node2D
## Prancha da Sophia: os estados do combate em pontos legíveis do tempo,
## renderizada pelo próprio jogo. Verifica que `_hero_motion` tira o corpo do
## neutro na esquiva, no dano e no bloqueio e salva shots/hero.png pra inspeção.
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
	var p: ArtProfile = Bestiary.player_profile(GameContent.characters[0], 3, [])
	check(p != null, "Perfil da Sophia ausente")
	# [estado, anim_time] — o tempo escolhe o ponto mais legível de cada ação.
	# Duas fileiras; a morte fica por último com folga (o corpo deita pra trás).
	var rows := [
		[["idle", 0.4], ["walk", 0.06], ["jump", 0.2], ["fall", 0.2], ["dodge", 0.06], ["dodge", 0.18], ["dodge", 0.29]],
		[["block", 0.5], ["hurt", 0.03], ["attack_air", 0.25], ["attack_dive", 0.2], ["cast", 0.28], ["dead", 0.75]],
	]
	var cells: Array = []
	for row in rows.size():
		for col in rows[row].size():
			cells.append([rows[row][col][0], rows[row][col][1], row, col, rows[row].size()])
	for i in cells.size():
		var state: String = cells[i][0]
		var time: float = cells[i][1]
		var row: int = cells[i][2]
		var col: int = cells[i][3]
		var spacing: float = 640.0 / float(cells[i][4])
		var art := CharacterArt.new()
		add_child(art)
		art.set_profile(p)
		art.set_process(false)
		art.scale = Vector2.ONE * 78.0 / (p.height * 1.19)
		art.position = Vector2(spacing * (float(col) + 0.5), 128 + row * 176)
		art.set_anim(state)
		art.anim_time = time
		var m: Array = art._hero_motion()
		check(m.size() == 5, "Formato do movimento: " + state)
		var moved: bool = absf(m[0]) > 0.01 or absf(m[1]) > 0.01 or absf(m[2] - 1.0) > 0.01 or absf(m[3] - 1.0) > 0.01
		if state in ["dodge", "hurt", "block", "dead", "cast", "attack_air", "attack_dive", "jump", "fall"]:
			check(moved, "Sem movimento: %s (t=%.2f)" % [state, time])
		if state == "dodge":
			check(m[1] > 0.2 and m[3] < 0.9, "Esquiva não mergulha: t=%.2f" % time)
		if state == "hurt":
			check(m[0] < 0.0 and m[1] < 0.0, "Dano não recua")
		if state == "block":
			check(m[3] < 1.0 and m[1] < 0.0, "Bloqueio não agacha")
		if state == "dead":
			check(m[1] < -1.0, "Morte não tomba")
		if state in ["idle", "walk"]:
			check(not moved, "Estado com quadro próprio ganhou movimento extra: " + state)
		art.queue_redraw()
		# linha do chão da célula
		var floor_line := Line2D.new()
		floor_line.width = 1.0
		floor_line.default_color = Color(0.4, 0.5, 0.55, 0.5)
		floor_line.add_point(art.position + Vector2(-spacing * 0.45, 0))
		floor_line.add_point(art.position + Vector2(spacing * 0.45, 0))
		add_child(floor_line)
		var label := Label.new()
		label.position = Vector2(spacing * float(col) + 6, row * 176 + 4)
		label.add_theme_font_size_override("font_size", 9)
		label.text = "%s\nt=%.2f" % [state, time]
		add_child(label)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/hero.png")
	print("HERO QA: ", failures, " falhas; ", cells.size(), " células")
	get_tree().quit(0 if failures == 0 else 1)
