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
				# a largada desenhada (S18) toca antes do ciclo: confere o ciclo de verdade
				var cyc_name: String = seq_name
				if seq_name == "start_run":
					cyc_name = "rund" if meta.states.has("rund") else "run"
				var cyc: Dictionary = meta.states[cyc_name]
				var drawn: bool = true
				for fe in cyc.frames:
					if String(fe.f).begins_with("rinb."):
						drawn = false
				check(drawn and cyc.frames.size() >= 8, "Corrida com quadros do RIFE ou ciclo curto: " + cyc_name)
				# Fila 9: largada, freada e pulo duplo desenhados
				for act in ["start_run", "stop_run", "double_jump"]:
					check(art.has_action(act), "Sem a ação desenhada: " + act)
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
		# PARADA 3D (Lab3D l25) + ANDAR 3D (pose de encenação): a parada de jogo é o 3D
		# (a pintada fica em idle_pintado); walk3d é só play_action, persiste e anda por distância
		for s3 in ["idle_pintado", "walk3d"]:
			check(db.meta.states.has(s3), "Atlas sem o estado: " + s3)
		check(String(db.meta.states.idle.frames[0].f).begins_with("s20."), "Parada não é a 3D (s20)")
		check(db.meta.states.idle.frames.size() >= 12, "Parada 3D sem os 12 quadros")
		var w3 := CharacterArt.new()
		add_child(w3)
		w3.set_profile(p)
		w3.set_process(false)
		w3.play_action("walk3d")
		for f in 240:
			w3._tick_visual(1.0 / 60.0)
		check(w3._hero_seq(db.meta.states) == "walk3d", "Andar 3D não persiste (devia valer até stop_action)")
		var i0: int = w3._seq_index(db.meta.states.walk3d, "walk3d")
		w3.motion_distance += 20.0
		check(w3._seq_index(db.meta.states.walk3d, "walk3d") != i0, "Andar 3D não troca de quadro pela distância")
		w3.stop_action()
		check(w3._hero_seq(db.meta.states) != "walk3d", "stop_action não encerra o andar 3D")
		w3.visible = false
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
		# GEOMETRIA POR QUADRO (Onda 6): todo quadro tem caixa do corpo; quadro com
		# ponta de cristal tem eixo do cajado; frame_geometry leva tudo pelo
		# transform do corpo (a ponta cai no cristal e fora da caixa no golpe esticado)
		var no_body: int = 0
		var no_staff: int = 0
		for fname in db.meta.frames:
			var ff: Dictionary = db.meta.frames[fname]
			if not ff.has("body"):
				no_body += 1
			if ff.get("tip") != null and not ff.has("staff"):
				no_staff += 1
		check(no_body == 0 and no_staff == 0, "Geometria faltando no atlas: %d sem corpo, %d sem cajado" % [no_body, no_staff])
		var g := CharacterArt.new()
		add_child(g)
		g.set_profile(p)
		g.set_process(false)
		var hit: Dictionary = db.meta.states.attack3.frames[-1]
		g._geo_fr = db.meta.frames[hit.f]
		g._geo_anchor = Vector2(hit.anchor[0], hit.anchor[1])
		g._body_xform = Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2(0, 30))
		var geo: Dictionary = g.frame_geometry()
		check(geo.has("body") and geo.has("staff"), "frame_geometry sem corpo/cajado na estocada")
		if geo.has("staff"):
			var ff2: Dictionary = db.meta.frames[hit.f]
			var tip_exp: Vector2 = g._body_xform * (Vector2(ff2.tip[0], ff2.tip[1]) - g._geo_anchor)
			check(geo.tip.distance_to(tip_exp) < 1.0, "Ponta do cajado fora do cristal")
			check(not geo.body.has_point(geo.tip), "Na estocada a ponta deveria estar FORA do corpo")
			check(geo.staff[0].distance_to(geo.staff[1]) > geo.body.size.y * 0.3, "Cajado curto demais na estocada")
		g.visible = false
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/hero.png")
	print("HERO QA: ", failures, " falhas; ", cells.size(), " células")
	get_tree().quit(0 if failures == 0 else 1)
