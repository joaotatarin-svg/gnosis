extends Node
## FERRAMENTA (não faz parte do jogo): QA da GNOSE — Estela (prompt, painel,
## Crônica), card de chefe, prólogo, epílogo e a tela Crônicas. Com janela,
## salva capturas em shots/gnose_*.png; headless só valida.
## Uso: godot --path . res://tools/GnoseQA.tscn  (--headless pra só validar)

func _ready() -> void:
	var w := Worker.new()
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var errors: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run.call_deferred()

	func check(cond: bool, msg: String) -> void:
		if cond:
			print("QA PASS: ", msg)
		else:
			errors += 1
			push_error("QA FAIL: " + msg)

	func wait(seconds: float = 0.6) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func shot(name: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/" + name + ".png")
		print("SHOT salvo: shots/" + name + ".png")

	## Fecha diálogos abertos (escolha padrão) e cinemáticas (pula).
	func skip_all() -> void:
		for _i in 30:
			var had := false
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					if c.choices.size() > 0:
						c._on_choice(0)
					else:
						c._finish()
					had = true
				elif c is Cinematic:
					c._skip_all = true
					c._advance = true
					had = true
			if not had:
				return
			await wait(0.15)

	func goto_screen(s: int) -> void:
		RunManager.current_screen = s
		GameManager.current_screen = s
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(0.5)
		await skip_all()
		await wait(0.3)

	func find_child_of(node: Node, type) -> Node:
		for c in node.get_children():
			if is_instance_of(c, type):
				return c
		return null

	# --- TEXTO (docs/ESTILO_TEXTO.md §5–6) ------------------------------------
	# Mede cada fala com as fontes e larguras REAIS (DialogueBox, CaptionBar,
	# painel da Estela, cards do Cinematic). Imprime só o resumo e as falhas.

	## Todas as falas de caixa de diálogo do run (sem as legendas).
	func all_dialog_lines() -> Array:
		var out: Array = []
		var groups: Array = [Narrative.intro(), Narrative.king_intro(), Narrative.king_fall(),
			Narrative.refusal_response(), Narrative.concession_response(), Narrative.velkar_meeting(),
			Narrative.theft(), Narrative.center_intro(), Narrative.final_pre(), Narrative.final_lines()]
		for e in 7:
			groups.append(Narrative.eon_intro(e))
		for b in Bestiary.bosses:
			groups.append(Narrative.temptation(String(b.id)))
		for i in 7:
			var b: Dictionary = Bestiary.bosses[i]
			groups.append(Narrative.ring_gained(String(b.id), "Coroa Partida", i + 1))
		for n in 3:
			groups.append(Narrative.soter_meeting(n))
		for d in 4:
			groups.append(Narrative.death_revive(20, d + 1, 137))
		groups.append(Narrative.death_revive(RunManager.CENTER_FIRST, 1, 1))
		groups.append(Narrative.death_revive(RunManager.MAX_SCREEN, 1, 0))
		for g in groups:
			out.append_array(g)
		Narrative.refusals = 0
		Narrative.concessions = 0
		return out

	## Legendas: [{screen, zone(-1 = chegada), line}] na ordem em que tocam no run.
	func all_captions() -> Array:
		var out: Array = []
		for s in range(1, RunManager.MAX_SCREEN + 1):
			for l in Narrative.walk_arrival(s):
				out.append({"screen": s, "zone": -1, "line": l})
			for z in RunManager.zone_count(s):
				for l in Narrative.walk_cleared(s, z):
					out.append({"screen": s, "zone": z, "line": l})
		return out

	func check_text() -> void:
		var dialog: Array = all_dialog_lines()
		var caps: Array = all_captions()
		print("TEXTO: ", dialog.size(), " falas de diálogo · ", caps.size(), " legendas · ",
			Gnosis.STELAS.size(), " Estelas")

		# (a) caixa de diálogo: ≤ 2 linhas a 13 px (M) e ≤ 3 a 16 px (G)
		var d := DialogueBox.play([{"speaker": "QA", "text": "..."}])
		await wait(0.2)
		print("  caixa: largura do texto ", int(d._text.size.x), " px (viewport ", get_viewport().get_visible_rect().size, ")")
		var bad: Array = []
		var max_lines: Dictionary = {}
		for size in [13, 16]:
			d._text.add_theme_font_size_override("font_size", size)
			await get_tree().process_frame
			var lim: int = 2 if size == 13 else 3
			for l in dialog:
				d._text.text = String(l.text)
				var n: int = d._text.get_line_count()
				max_lines[size] = maxi(int(max_lines.get(size, 0)), n)
				if n > lim:
					bad.append("%dpx %d linhas: %s" % [size, n, String(l.text).left(70)])
		d._finish()
		print("  maior fala: ", max_lines.get(13, 0), " linhas a 13 px · ", max_lines.get(16, 0), " a 16 px")
		await wait(0.1)
		for b in bad.slice(0, 12):
			print("  CAIXA: ", b)
		check(bad.is_empty(), "todas as falas cabem na caixa (M ≤ 2 linhas, G ≤ 3)")

		# (b) legendas: ≤ 2 linhas na faixa (11 px) + nenhuma repete no run
		var cap_lbl: Label = Gnosis._caption._text
		var long: Array = []
		var seen_t: Dictionary = {}
		var dup: Array = []
		for c in caps:
			var t := String(c.line.text)
			cap_lbl.text = t
			if cap_lbl.get_line_count() > 2:
				long.append("tela %d: %s" % [int(c.screen), t.left(70)])
			if seen_t.has(t):
				dup.append("tela %d: %s" % [int(c.screen), t.left(60)])
			seen_t[t] = true
		cap_lbl.text = ""
		print("  legendas: ", long.size(), " longas · ", dup.size(), " repetidas")
		for b in long.slice(0, 12):
			print("  LEGENDA: ", b)
		for b in dup.slice(0, 12):
			print("  REPETIDA: ", b)
		check(long.is_empty(), "todas as legendas cabem em 2 linhas")
		check(dup.is_empty(), "nenhuma legenda repete no run")

		# (c) painel da Estela ≤ 330 px de altura (viewport 360)
		var tall: Array = []
		for e in Gnosis.STELAS:
			var p := Stela.StelaPanel.new()
			p.entry = e
			get_tree().root.add_child(p)
			await get_tree().process_frame
			await get_tree().process_frame
			var pc: Control = p.get_child(1).get_child(0)
			if String(e.id) == "arcontes" or String(e.id) == "gnose":
				print("  estela ", e.id, ": ", pc.size)
			if pc.size.y > 330.0:
				tall.append("%s: %d px" % [String(e.id), int(pc.size.y)])
			p.queue_free()
			get_tree().paused = false
		for b in tall:
			print("  ESTELA ALTA: ", b)
		check(tall.is_empty(), "os 18 painéis de Estela cabem na tela")

		# (d) cards de prólogo/epílogo: ≤ 6 linhas na coluna de 470 px
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size = Vector2(Cinematic.TEXT_W, 10)
		lbl.add_theme_font_override("font", CodexStyle.serif())
		lbl.add_theme_font_size_override("font_size", 13)
		var holder := CanvasLayer.new()
		get_tree().root.add_child(holder)
		holder.add_child(lbl)
		var texts: Array = []
		var pro := Cinematic.prologue()
		for c in pro.cards:
			texts.append(String(c.text))
		pro._skip_all = true
		for i in 3:
			Narrative.apply_ending(i)
			texts.append(GameManager.end_subtitle)
			texts.append_array(Narrative.epilogue_cards(Narrative.ending))
		Narrative.ending = ""
		RunManager.endings_seen.clear()
		var cards_bad: Array = []
		for t in texts:
			lbl.text = t
			if lbl.get_line_count() > 6:
				cards_bad.append(String(t).left(60))
		holder.queue_free()
		for b in cards_bad:
			print("  CARD LONGO: ", b)
		check(cards_bad.is_empty(), "cards de prólogo/epílogo cabem (≤ 6 linhas)")
		await wait(0.6)

		# (e) glossário, respeito e regra de ouro
		var forbidden := ["Sabaoth", "Adonai", "Adonaios", "Eloai", "Sofia", "centelha", "…"]
		var diegetic: Array = []
		for l in dialog:
			diegetic.append(String(l.text))
		for c in caps:
			diegetic.append(String(c.line.text))
		var gloss: Array = []
		for t in diegetic:
			for w in forbidden:
				if t.contains(w):
					gloss.append("'%s' em: %s" % [w, t.left(60)])
			if t.contains("você") or t.contains("'"):
				gloss.append("registro/aspas: " + t.left(60))
		for e in Gnosis.STELAS:
			for t in e.lines:
				for w in forbidden:
					if String(t).contains(w):
						gloss.append("'%s' na Estela %s" % [w, e.id])
		for b in gloss.slice(0, 12):
			print("  GLOSSÁRIO: ", b)
		check(gloss.is_empty(), "glossário e respeito (sem nomes proibidos, sem 'você' no diegético)")
		var spoil: Array = []
		for c in caps:
			if int(c.screen) < RunManager.LAST_ARCHON_SCREEN:
				var t := String(c.line.text)
				if t.contains("Yaldabaoth") or t.contains("Demiurgo") or String(c.line.speaker) == "Yaldabaoth":
					spoil.append("tela %d: %s" % [int(c.screen), t.left(60)])
		for g in [Narrative.intro(), Narrative.king_intro(), Narrative.king_fall(), Narrative.velkar_meeting()]:
			for l in g:
				if String(l.text).contains("Yaldabaoth") or String(l.speaker) == "Yaldabaoth":
					spoil.append(String(l.text).left(60))
		for b in spoil:
			print("  SPOILER: ", b)
		check(spoil.is_empty(), "regra de ouro: ninguém diz Yaldabaoth/Demiurgo antes do roubo")

	func _run() -> void:
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		Gnosis.unlocked.clear()
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		for sk in GameContent.characters[0].skills:
			if sk.ring != "":
				Progression.add_ring(sk.ring, sk.id)

		# 0. TEXTO: cabe na caixa, nada repete, glossário e regra de ouro.
		await check_text()

		# 1. Estela + legenda de chegada (tela 15, uma zona: Estela à direita do descanso 0)
		Narrative.once("prologue")
		await goto_screen(15)
		await wait(1.0)
		var lv = get_tree().current_scene
		var stela: Stela = find_child_of(lv, Stela)
		check(stela != null, "Estela instanciada na tela 15")
		if stela != null:
			print("Estela em ", stela.global_position, " · player em ", lv.player.global_position)
			lv.player.global_position = stela.global_position + Vector2(44, -30)
			await wait(0.7)
			check(stela._near, "prompt de leitura ao chegar perto")
			await shot("gnose_stela")
			var before: int = Gnosis.chronicles_count()
			stela.open()
			await wait(0.6)
			check(get_tree().paused, "painel da Estela pausa o mundo")
			check(Gnosis.chronicles_count() == before + 1, "Crônica desbloqueada ao ler")
			await shot("gnose_stela_panel")
			for c in get_tree().root.get_children():
				if c is Stela.StelaPanel:
					get_tree().paused = false
					c.finished.emit()
					c.queue_free()
			await wait(0.5)
			check(not get_tree().paused, "painel fechou e o jogo voltou")

		# 2. Card de chefe (tela 10: o jogador cruza o gatilho e Athoth nasce)
		await goto_screen(10)
		lv = get_tree().current_scene
		lv.player.global_position = Vector2(lv.zone_center(0) - Level.ZONE_TRIGGER + 8.0, 250.0)
		await wait(0.5)
		var cin: Cinematic = find_child_of(get_tree().root, Cinematic)
		check(cin != null and get_tree().paused, "card de chefe congela ao nascer o Arconte")
		await shot("gnose_boss_card")
		await wait(2.6)
		check(not get_tree().paused, "card de chefe liberou o jogo")

		# 3. Prólogo (avulso) e epílogo (avulso)
		var pro := Cinematic.prologue()
		await wait(1.2)
		check(is_instance_valid(pro) and get_tree().paused, "prólogo pausa e mostra o card")
		await shot("gnose_prologue")
		await skip_all()
		await wait(0.8)
		check(not get_tree().paused, "prólogo pulável")
		GameManager.end_title = "SEMENTE"
		GameManager.end_subtitle = "Recusaste o trono e a porta. Desceste de volta, de faísca em faísca."
		var epi := Cinematic.epilogue("semente", Gnosis.chronicles_count(), Gnosis.chronicles_total())
		await wait(1.2)
		check(is_instance_valid(epi) and get_tree().paused, "epílogo pausa e mostra o card")
		await shot("gnose_epilogue")
		await skip_all()
		await wait(0.8)

		# 4. Crônicas
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/Chronicles.tscn")
		await wait(0.7)
		var ch = get_tree().current_scene
		check(ch != null and ch.get_script() != null and ch._entries.size() == 18, "Crônicas lista 18 entradas")
		ch._move(1)
		await wait(0.2)
		await shot("gnose_chronicles")

		print("QA RESULT: ", errors, " falhas")
		get_tree().quit(0 if errors == 0 else 1)
