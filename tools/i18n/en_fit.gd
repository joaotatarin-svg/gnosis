extends Node
## FERRAMENTA (não faz parte do jogo): o inglês CABE? Mede cada tradução de
## assets/i18n/strings.csv com as fontes e larguras REAIS do jogo — a mesma régua
## do GnoseQA (docs/ESTILO_TEXTO.md §5), sem ligar a tradução no jogo:
##  - fala de caixa: DialogueBox._text, ≤ 2 linhas a 13 px (M) e ≤ 3 a 16 px (G);
##  - legenda de caminhada: CaptionBar._text, ≤ 2 linhas;
##  - painel de Estela inteiro em inglês (StelaPanel) ≤ 330 px de altura;
##  - cards de prólogo/epílogo: coluna Cinematic.TEXT_W a 13 px, ≤ 6 linhas;
##  - card de chefe: nome (30 px) e título (12 px) cabem em 600 px;
##  - botões de escolha (final, Soter, Velkar) ≤ 500 px na caixa;
##  - toast do HUD: uma linha de 500 px a 13 px;
##  - UI em geral: largura do inglês vs. do português na fonte do corpo — só AVISO
##    (o tamanho real de cada rótulo depende do layout; revisar nas capturas).
## Uso:  godot --headless --audio-driver Dummy --path . res://tools/i18n/EnFit.tscn
## Com janela (xvfb) e um diretório depois de `--`, salva capturas de amostra:
##   ... res://tools/i18n/EnFit.tscn -- /home/user/caps/i18n
## Sai com o número de falhas (0 = tudo cabe).

const CSV := "res://assets/i18n/strings.csv"


func _ready() -> void:
	var w := Worker.new()
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var errors: int = 0
	var warnings: int = 0
	var rows: Array = []            # {id, pt, en, kind, speaker}
	var en_of: Dictionary = {}      # pt -> en
	var caps_dir: String = ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var args := OS.get_cmdline_user_args()
		if args.size() > 0 and DisplayServer.get_name() != "headless":
			caps_dir = String(args[0])
		_run.call_deferred()

	func check(cond: bool, msg: String) -> void:
		if cond:
			print("EN PASS: ", msg)
		else:
			errors += 1
			printerr("EN FAIL: ", msg)

	func wait(seconds: float = 0.3) -> void:
		await get_tree().create_timer(seconds, true, false, true).timeout

	func tr_en(pt: String) -> String:
		return String(en_of.get(pt, pt))

	## Lê o CSV (campos com aspas e quebras de linha: get_csv_line cuida).
	func load_csv() -> bool:
		var f := FileAccess.open(CSV, FileAccess.READ)
		if f == null:
			printerr("EN FAIL: não abriu ", CSV)
			return false
		var head := f.get_csv_line()
		var idx := {}
		for i in head.size():
			idx[head[i]] = i
		while not f.eof_reached():
			var c := f.get_csv_line()
			if c.size() < head.size():
				continue
			var r := {"id": c[idx["id"]], "pt": c[idx["pt"]], "en": c[idx["en"]],
				"kind": c[idx["kind"]], "speaker": c[idx["speaker"]]}
			rows.append(r)
			if String(r.en) != "":
				en_of[r.pt] = r.en
		f.close()
		return true

	func of_kind(kinds: Array) -> Array:
		var out: Array = []
		for r in rows:
			if kinds.has(String(r.kind)) and String(r.en) != "":
				out.append(r)
		return out

	func shot(name: String) -> void:
		if caps_dir == "":
			return
		await RenderingServer.frame_post_draw
		var path := caps_dir.path_join(name + ".png")
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT: ", path)

	# --- medições ---------------------------------------------------------------

	func fit_dialog() -> void:
		var lines := of_kind(["dialogo", "narrativa"])
		var bad: Array = []
		var old_cap: int = int(GameManager.settings.get("caption_size", 1))
		var worst := {}
		for opt in [1, 2]:
			GameManager.settings["caption_size"] = opt
			var size: int = GameManager.caption_font_size()
			var d := DialogueBox.play([{"speaker": "QA", "text": "..."}])
			await wait(0.2)
			var lim: int = 2 if opt == 1 else 3
			# A caixa "digita" com visible_characters = 0, e o Label só molda os
			# caracteres visíveis (VC_CHARS_BEFORE_SHAPING): sem -1 tudo dá 1 linha.
			d._text.visible_characters = -1
			var pt_over := 0
			for r in lines:
				d._text.text = String(r.pt)
				d._text.visible_characters = -1
				if d._text.get_line_count() > lim:
					pt_over += 1
				d._text.text = String(r.en)
				d._text.visible_characters = -1
				var n: int = d._text.get_line_count()
				worst[size] = maxi(int(worst.get(size, 0)), n)
				if n > lim:
					bad.append("%dpx %d linhas: %s  [%s]" % [size, n, String(r.en).left(70), r.id])
			print("  (referência: %d falas do português passam de %d linhas a %d px)" % [pt_over, lim, size])
			d._text.text = "word ".repeat(40)
			d._text.visible_characters = -1
			print("  autoteste %d px: 200 caracteres = %d linhas (largura %d px)" % [size, d._text.get_line_count(), int(d._text.size.x)])
			d._finish()
			await wait(0.1)
		GameManager.settings["caption_size"] = old_cap
		print("  falas: ", lines.size(), " · maior: ", worst.get(13, 0), " linhas a 13 px, ", worst.get(16, 0), " a 16 px")
		for b in bad.slice(0, 15):
			print("  CAIXA: ", b)
		check(bad.is_empty(), "falas de caixa em inglês cabem (M ≤ 2 linhas, G ≤ 3) — %d falhas" % bad.size())

	func fit_choices() -> void:
		var bad: Array = []
		for group in [Narrative.final_choices(4), Narrative.soter_blessings(), Narrative.velkar_choices()]:
			var ch: Array = []
			for c in group:
				if c is String:
					ch.append(tr_en(c))
				else:
					var cc: Dictionary = c.duplicate()
					cc["text"] = tr_en(String(c.get("text", "")))
					if cc.has("hint"):
						cc["hint"] = tr_en(String(cc.hint))
					ch.append(cc)
			var dc := DialogueBox.play([], ch)
			await wait(0.2)
			var w: float = dc._choice_box.get_combined_minimum_size().x
			print("  botões %d px: %s" % [int(w), str(ch).left(80)])
			if w > 500.0:
				bad.append("%d px: %s" % [int(w), str(ch).left(60)])
			dc._finish()
			await wait(0.1)
		check(bad.is_empty(), "botões de escolha em inglês ≤ 500 px")

	func fit_captions() -> void:
		var caps := of_kind(["legenda"])
		var lbl: Label = Gnosis._caption._text
		var long: Array = []
		for r in caps:
			lbl.text = String(r.en)
			lbl.visible_characters = -1
			if lbl.get_line_count() > 2:
				long.append("%s  [%s]" % [String(r.en).left(70), r.id])
		lbl.text = "word ".repeat(40)
		lbl.visible_characters = -1
		print("  autoteste legenda: 200 caracteres = %d linhas (largura %d px)" % [lbl.get_line_count(), int(lbl.size.x)])
		lbl.text = ""
		print("  legendas: ", caps.size(), " · longas: ", long.size())
		for b in long.slice(0, 15):
			print("  LEGENDA: ", b)
		check(long.is_empty(), "legendas em inglês cabem em 2 linhas — %d falhas" % long.size())

	## A Estela inteira traduzida, campo a campo.
	func stela_en(e: Dictionary) -> Dictionary:
		var t: Dictionary = e.duplicate(true)
		for k in ["title", "source", "hint", "eon"]:
			if t.has(k):
				t[k] = tr_en(String(t[k]))
		var ls: Array = []
		for l in e.lines:
			ls.append(tr_en(String(l)))
		t["lines"] = ls
		return t

	func fit_stelae() -> void:
		var tall: Array = []
		var biggest := 0
		for e in Gnosis.STELAS:
			var p := Stela.StelaPanel.new()
			p.entry = stela_en(e)
			get_tree().root.add_child(p)
			await get_tree().process_frame
			await get_tree().process_frame
			var pc: Control = p.get_child(1).get_child(0)
			biggest = maxi(biggest, int(pc.size.y))
			if pc.size.y > 330.0:
				tall.append("%s: %d px" % [String(e.id), int(pc.size.y)])
			if String(e.id) == "arcontes":
				await shot("en_estela_arcontes")
			p.queue_free()
			# Só ferramenta: o painel pausa a árvore direto; despausa como o GnoseQA.
			get_tree().paused = false
		print("  Estelas: maior painel ", biggest, " px")
		for b in tall:
			print("  ESTELA ALTA: ", b)
		check(tall.is_empty(), "os 18 painéis de Estela em inglês cabem (≤ 330 px)")

	func fit_cards() -> void:
		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size = Vector2(Cinematic.TEXT_W, 10)
		lbl.add_theme_font_override("font", CodexStyle.serif())
		lbl.add_theme_font_size_override("font_size", 13)
		var holder := CanvasLayer.new()
		get_tree().root.add_child(holder)
		holder.add_child(lbl)
		await get_tree().process_frame
		var bad: Array = []
		var cards := of_kind(["card_cinema"])
		var worst := 0
		for r in cards:
			lbl.text = String(r.pt)
			var n_pt := lbl.get_line_count()
			lbl.text = String(r.en)
			var n := lbl.get_line_count()
			worst = maxi(worst, n)
			# o card de créditos já passa de 6 no português (é bloco de créditos, não card do mito)
			if n > maxi(6, n_pt):
				bad.append("%d linhas: %s  [%s]" % [n, String(r.en).left(60), r.id])
		holder.queue_free()
		print("  cards: ", cards.size(), " · maior: ", worst, " linhas")
		for b in bad:
			print("  CARD LONGO: ", b)
		check(bad.is_empty(), "cards de prólogo/epílogo em inglês ≤ 6 linhas")

	func fit_boss_and_toasts() -> void:
		var title_font: Font = Cinematic.title_font()
		var bad: Array = []
		for r in of_kind(["card_chefe_nome"]):
			var w := title_font.get_string_size(String(r.en), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			if w > 600.0:
				bad.append("nome %d px: %s" % [int(w), r.en])
		for r in of_kind(["card_chefe_titulo"]):
			var w := title_font.get_string_size(String(r.en), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			if w > 600.0:
				bad.append("título %d px: %s" % [int(w), r.en])
		for b in bad:
			print("  CARD DE CHEFE: ", b)
		check(bad.is_empty(), "cards de chefe em inglês cabem em 600 px")
		var disp: Font = CodexStyle.display()
		var tb: Array = []
		for r in of_kind(["toast"]):
			var t := String(r.en).replace("%s", "Hollow Colossus").replace("%d", "7")
			var w := disp.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			if w > 500.0:
				tb.append("%d px: %s" % [int(w), t])
		for b in tb:
			print("  TOAST: ", b)
		check(tb.is_empty(), "toasts em inglês cabem numa linha de 500 px")

	## UI: o inglês pode crescer até 15% (+6 px) sobre o português sem aviso.
	func compare_ui() -> void:
		var body: Font = CodexStyle.body()
		var grow: Array = []
		var n := 0
		for r in rows:
			var k := String(r.kind)
			if String(r.en) == "" or not (k.begins_with("ui") or k in ["golpe_magia", "bestiario", "nome", "eon_nome", "falante", "escolha"]):
				continue
			n += 1
			var wp := body.get_multiline_string_size(String(r.pt), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var we := body.get_multiline_string_size(String(r.en), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			if we > wp * 1.15 + 6.0:
				grow.append("+%d%% (%d→%d px) %s  [%s]" % [int(round((we / maxf(wp, 1.0) - 1.0) * 100.0)), int(wp), int(we), String(r.en).left(50), r.id])
		warnings += grow.size()
		print("  UI: ", n, " textos · ", grow.size(), " crescem > 15% (revisar no layout real)")
		for b in grow:
			print("  AVISO UI: ", b)

	func sample_shots() -> void:
		if caps_dir == "":
			return
		var d := DialogueBox.play([
			{"speaker": "A Voz", "text": tr_en("Chama-me Voz. Sobe comigo: cada faísca que libertares vai lembrar o que tu és.")},
		])
		await wait(2.5)
		d.reveal_all()
		await wait(0.3)
		await shot("en_dialogo")
		d._finish()
		await wait(0.3)
		Gnosis._caption.say("Sophia", tr_en("Chamam este mundo de Kenoma, o vazio. Mas está cheio até a borda."))
		await wait(3.0)
		await shot("en_legenda")
		Gnosis._caption.clear()
		var c := Cinematic.boss_card(tr_en("ARMUPIEL"), tr_en("Arconte da Coroa  ·  Sétima Esfera"))
		await wait(0.9)
		await shot("en_card_chefe")
		if is_instance_valid(c):
			c._skip_all = true
			c._advance = true
		await wait(1.0)
		get_tree().paused = false

	func _run() -> void:
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		if not load_csv():
			get_tree().quit(1)
			return
		var done := 0
		for r in rows:
			if String(r.en) != "":
				done += 1
		print("EN: ", rows.size(), " textos no CSV, ", done, " traduzidos")
		check(done == rows.size(), "todo texto visível tem inglês (%d/%d)" % [done, rows.size()])
		await fit_dialog()
		await fit_choices()
		await fit_captions()
		await fit_stelae()
		await fit_cards()
		await fit_boss_and_toasts()
		compare_ui()
		await sample_shots()
		print("EN RESUMO: %d falha(s), %d aviso(s) de UI" % [errors, warnings])
		get_tree().quit(errors)
