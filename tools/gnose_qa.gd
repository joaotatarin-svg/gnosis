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

	## Espera `n` quadros processados (o mundo pode estar pausado: o Worker é ALWAYS).
	func frames(n: int) -> void:
		for _i in n:
			await get_tree().process_frame

	## ESTABILIDADE (Onda 5): espera `cond` virar verdade quadro a quadro. Só
	## desiste quando passaram AO MESMO TEMPO `min_frames` quadros E `min_secs`
	## de relógio: sem carga (quadros voam) vale o relógio; com a máquina
	## engasgada (quadros de 300 ms) vale a contagem de quadros. O relógio só
	## serve de TETO para desistir — nunca decide se passou.
	func until(cond: Callable, min_frames: int = 600, min_secs: float = 20.0) -> bool:
		var n: int = 0
		var t0: int = Time.get_ticks_msec()
		while not cond.call():
			if n >= min_frames and Time.get_ticks_msec() - t0 >= int(min_secs * 1000.0):
				return false
			n += 1
			await get_tree().process_frame
		return true

	## Há caixa de diálogo ou cinemática aberta na raiz?
	func overlay_open() -> bool:
		for c in get_tree().root.get_children():
			if (c is DialogueBox or c is Cinematic) and not c.is_queued_for_deletion():
				return true
		return false

	## O card de chefe na raiz (Cinematic em modo chefe), ou null.
	func boss_card_node() -> Cinematic:
		for c in get_tree().root.get_children():
			if c is Cinematic and not (c as Cinematic).boss.is_empty() and c.is_inside_tree():
				return c
		return null

	## Estado do nível para o log quando uma espera estoura.
	func level_state(lv) -> String:
		if lv == null or not is_instance_valid(lv):
			return "nível=nulo"
		return "tela=%d ready_done=%s zone_active=%s zona=%d state=%d paused=%s pausas=%d sobreposição=%s px=%.0f" % [
			int(lv.screen), str(lv._ready_done), str(lv.zone_active), int(lv.zone_index), int(GameManager.state),
			str(get_tree().paused), PauseStack.count(), str(overlay_open()),
			lv.player.global_position.x if lv.player != null else -1.0]

	func shot(name: String) -> void:
		if DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/" + name + ".png")
		print("SHOT salvo: shots/" + name + ".png")

	## Fecha diálogos abertos (escolha padrão) e cinemáticas (pula) até não
	## sobrar nenhum — por estado, quadro a quadro (a cinemática pulada ainda
	## faz o fade de saída antes de sair da árvore).
	func skip_all() -> void:
		await until(func() -> bool:
			_close_overlays()
			return not overlay_open())

	## Troca para a tela `s` e espera, POR ESTADO, o nível ficar jogável: o
	## Level novo terminou os bicos narrativos (`_ready_done` só vira true depois
	## da intro do Éon / tentação / recusa), nada de caixa ou cinemática aberta,
	## mundo solto e estado PLAYING. Vai fechando os diálogos que aparecerem.
	## (Antes: 0,5 s + skip_all + 0,3 s de relógio. Sob carga o timer criado no
	## quadro da carga disparava NESSE quadro; skip_all não via caixa nenhuma e
	## saía, a tentação da tela 10 abria DEPOIS e segurava o gatilho do chefe.)
	func goto_screen(s: int) -> Level:
		var old: Node = get_tree().current_scene
		RunManager.current_screen = s
		GameManager.current_screen = s
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		var ready := func() -> bool:
			_close_overlays()
			var cs: Node = get_tree().current_scene
			return cs is Level and cs != old and (cs as Level).screen == s and (cs as Level)._ready_done \
				and not overlay_open() and not get_tree().paused and GameManager.state == GameManager.State.PLAYING
		var ok: bool = await until(ready, 1800, 60.0)
		var lv = get_tree().current_scene
		if not ok:
			push_error("QA FAIL: tela %d não ficou jogável (%s)" % [s, level_state(lv if lv is Level else null)])
			errors += 1
		# Dois quadros de folga: o player e a câmera assentam.
		await frames(2)
		return lv if lv is Level else null

	## Fecha, num quadro, o que houver de diálogo (escolha 0) e cinemática (pula).
	func _close_overlays() -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion() and c.is_inside_tree():
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
			elif c is Cinematic and not c._done:
				c._skip_all = true
				c._advance = true

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
		for e in 7:
			groups.append(Narrative.sanctuary(e))
		for i in 3:
			groups.append(Narrative.ending_lines(i))
		for i in 2:
			groups.append(Narrative.velkar_farewell(i))
		groups.append_array(pre_theft_deaths())
		# Centro: falas por cacos recuperados (0, 1–2, 3–4, 5–6).
		var saved: Array = Progression.restored_rings.duplicate()
		for k in [0, 1, 3, 5]:
			Progression.restored_rings.clear()
			for j in k:
				Progression.restored_rings.append("x%d" % j)
			groups.append(Narrative.death_revive(RunManager.CENTER_FIRST, 1, 1))
		Progression.restored_rings.assign(saved)
		# Mente: contador próprio (1ª, 2ª, 3ª, 4ª+).
		Narrative.final_deaths = 0
		for i in 4:
			groups.append(Narrative.death_revive(RunManager.MAX_SCREEN, 1, 0))
		Narrative.final_deaths = 0
		for g in groups:
			out.append_array(g)
		Narrative.refusals = 0
		Narrative.concessions = 0
		return out

	## As falas de morte antes do roubo: todas as faixas (1–14 quedas) e a 1ª
	## queda diante de um Arconte. Não deixa rastro em Narrative.seen.
	func pre_theft_deaths() -> Array:
		var groups: Array = []
		for d in 14:
			groups.append(Narrative.death_revive(20, d + 1, 137))
		var key := "morte_arconte_%d" % RunManager.LAST_ARCHON_SCREEN
		var had: bool = Narrative.seen.has(key)
		groups.append(Narrative.death_revive(RunManager.LAST_ARCHON_SCREEN, 1, 0))
		if not had:
			Narrative.seen.erase(key)
		return groups

	## Legendas de gatilho (não dependem de tela/zona): fase 2 dos Arcontes,
	## lembranças dos ecos, 7º Anel, Adormecidos e a Voz depois de Soter.
	## Cada item: {screen (quando toca, p/ a regra de ouro), line}.
	func trigger_captions() -> Array:
		var out: Array = []
		for i in 7:
			var id := String(Bestiary.bosses[i].id)
			var archon_screen := RunManager.FIRST_EON_SCREEN + i * RunManager.EON_LEN + RunManager.EON_LEN - 1
			for l in Narrative.archon_phase2(id):
				out.append({"screen": archon_screen, "line": l})
			for l in Narrative.echo_memory(id):
				out.append({"screen": RunManager.CENTER_FIRST, "line": l})
		for l in Narrative.seventh_ring():
			out.append({"screen": RunManager.MAX_SCREEN, "line": l})
		for s in Narrative.SLEEPER_ORDER:
			for l in Narrative.sleeper_line(int(s)):
				out.append({"screen": int(s), "line": l})
		for n in 3:
			for l in Narrative.after_soter(n):
				out.append({"screen": [17, 35, 53][n], "line": l})
		return out

	## Legendas: [{screen, zone(-1 = chegada), line}] na ordem em que tocam no run,
	## mais as legendas de gatilho (zone -2).
	func all_captions() -> Array:
		var out: Array = []
		for s in range(1, RunManager.MAX_SCREEN + 1):
			for l in Narrative.walk_arrival(s):
				out.append({"screen": s, "zone": -1, "line": l})
			for z in RunManager.zone_count(s):
				for l in Narrative.walk_cleared(s, z):
					out.append({"screen": s, "zone": z, "line": l})
		for c in trigger_captions():
			out.append({"screen": int(c.screen), "zone": -2, "line": c.line})
		return out

	func check_text() -> void:
		var dialog: Array = all_dialog_lines()
		var caps: Array = all_captions()
		print("TEXTO: ", dialog.size(), " falas de diálogo · ", caps.size(), " legendas · ",
			Gnosis.STELAS.size(), " Estelas")

		# (a) caixa de diálogo: ≤ 2 linhas a 13 px (M) e ≤ 3 a 16 px (G)
		# Uma caixa nova por tamanho de legenda (a DialogueBox lê o tamanho no _ready).
		var bad: Array = []
		var max_lines: Dictionary = {}
		var old_cap: int = int(GameManager.settings.get("caption_size", 1))
		for opt in [1, 2]:
			GameManager.settings["caption_size"] = opt
			var size: int = GameManager.caption_font_size()
			var d := DialogueBox.play([{"speaker": "QA", "text": "..."}])
			await until(func() -> bool: return d.is_inside_tree())
			await frames(2)
			var lim: int = 2 if opt == 1 else 3
			for l in dialog:
				d._text.text = String(l.text)
				var n: int = d._text.get_line_count()
				max_lines[size] = maxi(int(max_lines.get(size, 0)), n)
				if n > lim:
					bad.append("%dpx %d linhas: %s" % [size, n, String(l.text).left(70)])
			# Autoteste da medição: 200 caracteres têm de dar ≥ 3 linhas.
			d._text.text = "palavra ".repeat(25)
			print("  autoteste %d px: 200 caracteres = %d linhas (largura %d px)" % [size, d._text.get_line_count(), int(d._text.size.x)])
			d._finish()
			await frames(2)
		GameManager.settings["caption_size"] = old_cap
		# Os 3 botões do final e os 3 de Soter cabem numa linha da caixa?
		for ch in [Narrative.final_choices(4), Narrative.soter_blessings(), Narrative.velkar_choices()]:
			var dc := DialogueBox.play([], ch)
			await until(func() -> bool: return dc.is_inside_tree())
			await frames(2)
			var w: float = dc._choice_box.get_combined_minimum_size().x
			if w > 500.0:
				bad.append("botões com %d px: %s" % [int(w), str(ch).left(60)])
			dc._finish()
			await frames(2)
		print("  maior fala: ", max_lines.get(13, 0), " linhas a 13 px · ", max_lines.get(16, 0), " a 16 px")
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
		# O prólogo avulso medido acima foi pulado: espera ele sair de verdade.
		await until(func() -> bool: return not is_instance_valid(pro) or pro._done)
		await frames(2)

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
			# "você" vale no diegético desde 29/10 (decisão do chefe: PT-BR); só a aspa simples segue proibida.
			if t.contains("'"):
				gloss.append("registro/aspas: " + t.left(60))
		for e in Gnosis.STELAS:
			for t in e.lines:
				for w in forbidden:
					if String(t).contains(w):
						gloss.append("'%s' na Estela %s" % [w, e.id])
		for b in gloss.slice(0, 12):
			print("  GLOSSÁRIO: ", b)
		check(gloss.is_empty(), "glossário e respeito (sem nomes proibidos, sem aspa simples no diegético)")
		var spoil: Array = []
		for c in caps:
			if int(c.screen) < RunManager.LAST_ARCHON_SCREEN:
				var t := String(c.line.text)
				if t.contains("Yaldabaoth") or t.contains("Demiurgo") or String(c.line.speaker) == "Yaldabaoth":
					spoil.append("tela %d: %s" % [int(c.screen), t.left(60)])
		# Tudo o que toca ANTES do roubo (caixa de diálogo).
		var pre: Array = [Narrative.intro(), Narrative.king_intro(), Narrative.king_fall(),
			Narrative.velkar_meeting(), Narrative.velkar_farewell(0), Narrative.velkar_farewell(1)]
		for e in 7:
			pre.append(Narrative.eon_intro(e))
			pre.append(Narrative.sanctuary(e))
			var id := String(Bestiary.bosses[e].id)
			pre.append(Narrative.temptation(id))
			pre.append(Narrative.ring_gained(id, "X", e + 1))
		for n in 3:
			pre.append(Narrative.soter_meeting(n))
		pre.append_array(pre_theft_deaths())
		for g in pre:
			for l in g:
				var t := String(l.text)
				if t.contains("Yaldabaoth") or t.contains("Demiurgo") or t.contains("meu corpo") \
						or String(l.speaker) == "Yaldabaoth":
					spoil.append(t.left(60))
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
		var lv = await goto_screen(15)
		var stela: Stela = find_child_of(lv, Stela) if lv != null else null
		check(stela != null, "Estela instanciada na tela 15")
		if stela != null:
			print("Estela em ", stela.global_position, " · player em ", lv.player.global_position)
			lv.player.global_position = stela.global_position + Vector2(44, -30)
			await until(func() -> bool: return stela._near)
			check(stela._near, "prompt de leitura ao chegar perto")
			await shot("gnose_stela")
			var before: int = Gnosis.chronicles_count()
			stela.open()
			var panel_up := func() -> bool:
				return get_tree().paused and find_child_of(get_tree().root, Stela.StelaPanel) != null
			await until(panel_up)
			check(get_tree().paused, "painel da Estela pausa o mundo")
			check(Gnosis.chronicles_count() == before + 1, "Crônica desbloqueada ao ler")
			await shot("gnose_stela_panel")
			for c in get_tree().root.get_children():
				if c is Stela.StelaPanel:
					get_tree().paused = false
					c.finished.emit()
					c.queue_free()
			await until(func() -> bool: return not get_tree().paused and find_child_of(get_tree().root, Stela.StelaPanel) == null)
			check(not get_tree().paused, "painel fechou e o jogo voltou")

		# 2. Card de chefe (tela 10: o jogador cruza o gatilho e Athoth nasce)
		#    ESTABILIDADE (Onda 5): tudo por ESTADO. Espera o card NASCER
		#    (Cinematic de chefe na árvore), confere a pausa, e espera o card
		#    TERMINAR (`_done`/fora da árvore) para conferir que soltou. O relógio
		#    só é teto para desistir (until) e piso da duração: carga só alonga
		#    o card, nunca o encurta.
		lv = await goto_screen(10)
		var cin: Cinematic = null
		var card_seen := false
		if lv != null:
			lv.player.global_position = Vector2(lv.zone_center(0) - Level.ZONE_TRIGGER + 8.0, 250.0)
			var f0: int = Engine.get_process_frames()
			await until(func() -> bool: return boss_card_node() != null)
			cin = boss_card_node()
			card_seen = cin != null
			if cin == null:
				print("  card não nasceu em %d quadros: %s" % [Engine.get_process_frames() - f0, level_state(lv)])
			else:
				print("  card nasceu %d quadro(s) depois do gatilho" % (Engine.get_process_frames() - f0))
		var t_card: int = Time.get_ticks_msec()
		check(card_seen and get_tree().paused, "card de chefe congela ao nascer o Arconte")
		await shot("gnose_boss_card")
		if card_seen:
			var held := [true]
			var gone := func() -> bool:
				if not get_tree().paused and is_instance_valid(cin) and not cin._done:
					held[0] = false       # soltou o mundo com o card ainda na tela
				return not is_instance_valid(cin) or cin._done
			await until(gone, 1800, 60.0)
			var card_ms: int = Time.get_ticks_msec() - t_card
			check(held[0], "card de chefe segura a pausa até acabar")
			check(card_ms >= 1500, "card de chefe dura ~1,8 s (%d ms; carga só alonga)" % card_ms)
		await frames(3)
		# (cin já foi liberado aqui: objeto liberado compara igual a null — usa card_seen.)
		check(card_seen and not get_tree().paused and not overlay_open(), "card de chefe liberou o jogo")
		if get_tree().paused or overlay_open():
			print("  depois do card: ", level_state(lv))

		# 3. Prólogo (avulso) e epílogo (avulso)
		var pro := Cinematic.prologue()
		await until(func() -> bool: return is_instance_valid(pro) and pro.is_inside_tree() and get_tree().paused)
		check(is_instance_valid(pro) and get_tree().paused, "prólogo pausa e mostra o card")
		await shot("gnose_prologue")
		await skip_all()
		await until(func() -> bool: return not get_tree().paused and not overlay_open())
		check(not get_tree().paused, "prólogo pulável")
		GameManager.end_title = "SEMENTE"
		GameManager.end_subtitle = "Recusaste o trono e a porta. Desceste de volta, de faísca em faísca."
		var epi := Cinematic.epilogue("semente", Gnosis.chronicles_count(), Gnosis.chronicles_total())
		await until(func() -> bool: return is_instance_valid(epi) and epi.is_inside_tree() and get_tree().paused)
		check(is_instance_valid(epi) and get_tree().paused, "epílogo pausa e mostra o card")
		await shot("gnose_epilogue")
		await skip_all()
		await until(func() -> bool: return not overlay_open())

		# 4. Crônicas
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/Chronicles.tscn")
		await until(func() -> bool:
			var cs: Node = get_tree().current_scene
			return cs != null and cs.scene_file_path == "res://scenes/ui/Chronicles.tscn" and cs.is_node_ready())
		await frames(2)
		var ch = get_tree().current_scene
		check(ch != null and ch.get_script() != null and ch._entries.size() == 18, "Crônicas lista 18 entradas")
		ch._move(1)
		await frames(3)
		await shot("gnose_chronicles")

		print("QA RESULT: ", errors, " falhas (", Engine.get_process_frames(), " quadros)")
		get_tree().quit(0 if errors == 0 else 1)
