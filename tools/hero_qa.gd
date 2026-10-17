extends Node2D
## Prancha da Sophia (QA): cada estado do combate num ponto legível do tempo,
## renderizada pelo próprio jogo. Com os QUADROS DESENHADOS (atlas
## sophia_frames, docs/ANIMACAO.md) verifica:
##  - todo estado resolve uma sequência com quadro válido (retângulo dentro do
##    atlas, âncora finita, pé na linha do chão);
##  - o corpo NÃO gira como cartão: rotação ≤ 0,12 rad, squash ≤ ±7%;
##  - o movimento de reforço tem o sentido certo (esquiva inclina pra frente,
##    dano recua e curva pra trás, morte termina no quadro deitado);
##  - corrida não ganha empurrões extras (o quadro é que anima).
## Salva shots/hero.png pra inspeção.
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
	var db: Dictionary = CharacterArt.frame_db("sophia")
	check(not db.is_empty(), "Atlas de quadros da Sophia ausente (rode tools/anim/build_frames.py)")
	var rows := [
		[["idle", 0.4], ["walk", 0.06], ["jump", 0.2], ["fall", 0.2], ["dodge", 0.06], ["dodge", 0.18], ["dodge_back", 0.15]],
		[["block", 0.5], ["hurt", 0.03], ["attack_air", 0.25], ["attack_dive", 0.2], ["cast", 0.28], ["attack_heavy", 0.06], ["dead", 0.75]],
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
		art.dodge_back = state == "dodge_back"
		art.set_anim("dodge" if state == "dodge_back" else state)
		art.anim_time = time
		var m: Array = art._hero_motion()
		check(m.size() == 6, "Formato do movimento: " + state)
		check(absf(m[1]) <= CharacterArt.MAX_ROT + 0.001, "Cartão girando demais: %s rot=%.2f" % [state, m[1]])
		check(absf(m[2] - 1.0) <= 0.0701 and absf(m[3] - 1.0) <= 0.0701, "Squash acima de 7%%: %s" % state)
		if not db.is_empty():
			var meta: Dictionary = db.meta
			var seq_name: String = art._hero_seq(meta.states)
			check(meta.states.has(seq_name), "Estado sem sequência: " + state)
			var seq: Dictionary = meta.states[seq_name]
			var idx: int = art._seq_index(seq, seq_name)
			check(idx >= 0 and idx < seq.frames.size(), "Índice de quadro inválido: " + state)
			var e: Dictionary = seq.frames[idx]
			var fr: Dictionary = meta.frames[e.f]
			var r: Array = fr.rect
			check(r[0] >= 0 and r[1] >= 0 and r[0] + r[2] <= db.atlas.get_width() and r[1] + r[3] <= db.atlas.get_height(), "Quadro fora do atlas: " + e.f)
			check(is_finite(float(e.anchor[0])) and is_finite(float(e.anchor[1])) and float(e.anchor[1]) > 0.0, "Âncora inválida: " + e.f)
			if state == "dead":
				# deitada = último quadro da sequência e mais largo que alto
				check(idx == seq.frames.size() - 1 and float(r[2]) > float(r[3]) * 1.3, "Morte não termina deitada: " + e.f)
				# transição desenhada (S12): atingida → cambaleia → joelho → mão → tomba → deitada
				check(seq.frames.size() >= 5, "Morte sem a transição antes do deitado (%d quadros)" % seq.frames.size())
			if state == "walk":
				# corrida = ciclo todo DESENHADO (sem os meios borrados do RIFE)
				var drawn: bool = true
				for fe in seq.frames:
					if String(fe.f).begins_with("rinb."):
						drawn = false
				check(drawn and seq.frames.size() >= 8, "Corrida com quadros do RIFE ou ciclo curto: " + seq_name)
			if state == "dodge_back":
				check(seq_name == "dodge_back", "Esquiva pra trás sem quadro próprio")
		if state == "dodge":
			check(m[5] > 0.5, "Esquiva não inclina pra frente: t=%.2f" % time)
		if state == "hurt":
			check(m[0] < 0.0 and m[5] < 0.0, "Dano não recua")
		if state == "block":
			check(m[3] < 1.0, "Bloqueio não assenta")
		if state == "walk":
			check(absf(m[0]) < 0.01 and absf(m[1]) < 0.01, "Corrida ganhou empurrão extra")
		art.queue_redraw()
		var floor_line := Line2D.new()
		floor_line.width = 1.0
		floor_line.default_color = Color(0.4, 0.5, 0.55, 0.5)
		var gy: float = CharacterArt.GROUND_Y * p.height / 44.0 * art.scale.y
		floor_line.add_point(art.position + Vector2(-spacing * 0.45, gy))
		floor_line.add_point(art.position + Vector2(spacing * 0.45, gy))
		add_child(floor_line)
		var label := Label.new()
		label.position = Vector2(spacing * float(col) + 6, row * 176 + 4)
		label.add_theme_font_size_override("font_size", 9)
		label.text = "%s\nt=%.2f" % [state, time]
		add_child(label)
	# APARO e CONTRA-ATAQUE (S14): estados no atlas; o flash do _parry na guarda
	# dispara o "parry"; play_action("riposte") toca o contra-ataque e termina.
	if not db.is_empty():
		for s in ["block", "parry", "riposte"]:
			check(db.meta.states.has(s), "Atlas sem o estado: " + s)
		var pa := CharacterArt.new()
		add_child(pa)
		pa.set_profile(p)
		pa.set_process(false)
		pa.set_anim("block")
		pa.modulate = Color(3, 3, 4, 1)          # flash do Player._parry
		pa._tick_visual(1.0 / 60.0)
		check(pa._hero_seq(db.meta.states) == "parry", "Aparo na guarda não toca o quadro de aparo")
		pa.modulate = Color.WHITE
		pa.play_action("riposte")
		check(pa._hero_seq(db.meta.states) == "riposte", "Contra-ataque não toca")
		for f in 60:
			pa._tick_visual(1.0 / 60.0)
		check(pa._hero_seq(db.meta.states) != "riposte", "Contra-ataque não termina")
		pa.visible = false
		# FLUIDEZ (S15/S16): parado = respiração de 8 quadros; voltando do 3º
		# golpe leve pro parado toca a recuperação desenhada e ela termina
		if db.meta.states.has("rec_light3"):
			check(db.meta.states.idle.frames.size() >= 8, "Parado sem a respiração de 8 quadros (S16)")
			var rc := CharacterArt.new()
			add_child(rc)
			rc.set_profile(p)
			rc.set_process(false)
			rc.combo_step = 3
			rc.set_anim("attack")
			rc.set_anim("idle")
			check(rc._hero_seq(db.meta.states) == "rec_light3", "Recuperação do 3º golpe não toca (S15)")
			for f in 40:
				rc._tick_visual(1.0 / 60.0)
			check(rc._hero_seq(db.meta.states) != "rec_light3", "Recuperação não termina")
			rc.set_anim("attack")
			rc.combo_step = 1
			rc.set_anim("idle")
			check(rc._hero_seq(db.meta.states) != "rec_light1", "rec_light1 (descartada) voltou a tocar")
			rc.visible = false
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/hero.png")
	print("HERO QA: ", failures, " falhas; ", cells.size(), " células")
	get_tree().quit(0 if failures == 0 else 1)
