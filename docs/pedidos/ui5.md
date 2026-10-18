# Pedidos da UI5 (Onda 5) a outros donos

## 1. narrativa6 (dono de `scripts/fx/cinematic.gd` na Onda 6) — QA2 #13
O rodapé dos cards (prólogo/epílogo/Crônicas) ainda é texto fixo de teclado:
`_hint.text = "qualquer tecla avança  ·  Esc pula"` (`_build_cards`). A UI já deixou pronto
`InputGlyphs.card_hint()` (ícones do dispositivo em uso, troca sozinho teclado ↔ controle,
traduzido: "avança"/"pula" → *continue*/*skip* no lote `12_ui5.tsv`). Troca sugerida:
```gdscript
	# no lugar do Label _hint (o _set_alpha continua valendo se _hint for Control)
	_hint = InputGlyphs.card_hint()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -240.0
	_hint.offset_top = -24.0
	_hint.offset_right = -14.0
	_hint.offset_bottom = -8.0
	add_child(_hint)
```
(`var _hint: Label` vira `var _hint: Control`.) Qualquer tecla/botão continua avançando —
o ícone mostra Enter/A como exemplo e Esc/≡ para pular.

## 2. narrativa6 — `caption_bar.gd` mudou de dono
Últimas mudanças da UI (commit `5c19d00`): corpo da legenda sem o `+1` (13 px no M), aperta 1 px
para caber em 1 linha (`_lines_for`, `MIN_FS` 11), e a legenda some/congela com cena no ar
(`_scene_on()` → `HUD.scene_active()`). `shown_lines()`/`band_rect()` são usados pela sonda
`tools/UxShots5`. Daqui em diante não mexo mais nele.

## 3. Dono das ferramentas de QA (estab5) — GnoseQA instável no "card de chefe" (tela 10)
`gnose_qa.gd goto_screen()` espera 0,5 s e chama `skip_all()` UMA vez. Em headless, com a máquina
carregada, a caixa da tentação do Athoth abre ~0,9–1,6 s depois do `change_scene` (medido: base
1001/919 ms, ui5 1068/1573 ms) — o `skip_all` passa antes dela, a caixa fica aberta, o gatilho
não dispara e falham "card de chefe congela…" e "…liberou o jogo". Acontece na base
`37ea6f5` também (2 de 3 rodadas aqui). Sugestão: em `goto_screen`, esperar a caixa ou ~2 s:
```gdscript
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2500:
			await get_tree().process_frame
			var box := false
			for c in get_tree().root.get_children():
				box = box or c is DialogueBox
			if box:
				break
		await skip_all()
```
Com essa espera as 4 rodadas (base e ui5) deram `QA RESULT: 0 falhas`.

## 4. Encenação/arte — QA2 #6 (não é UI)
A fala do Cego pequeno ("...mãe? eu não queria ser cego") usa falante `Yaldabaoth` + mood
`quebrado` → retrato `rei_quebrado` (máscara rachada). Precisa de falante próprio (ex.:
"O Pequeno") e, se quiserem retrato, um `cego_pequeno.png` em `assets/ui/portraits/`; o
`DialogueBox.speaker_id()` aceita um id novo em 1 linha — me peçam.
