extends "res://tools/regressao/reg_base.gd"
## A6 (QA_UX_BUGS, Alta): na escolha FINAL (tela 68, 3 opções) a caixa estoura
## a borda direita, "Semente" sai cortado e, desabilitado, não diz o motivo (a
## dica só existe como tooltip de mouse). Esperado: os 3 botões inteiros
## dentro da tela (e do painel do diálogo), texto sem corte, e o motivo do
## bloqueio visível sem mouse quando "Semente" está trancado.

const BORDA := 2.0


func rodar() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await wait(0.6)
	# Caso realista: caminho sem os 4 Adormecidos → "Semente" trancado.
	var escolhas: Array = Narrative.final_choices(0)
	var linhas: Array = Narrative.final_lines()
	var d := DialogueBox.play([linhas.back() if linhas.size() > 0 else {"speaker": "Sophia", "text": "..."}], escolhas)
	await frames(3)
	d.idx = d.lines.size()
	d._show_line()
	await wait(0.8)
	var vis := tela()
	var btns: Array = []
	for b in d.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			btns.append(b)
	if btns.size() != escolhas.size():
		quebrado("esperava %d botões de escolha, achei %d" % [escolhas.size(), btns.size()])
		return
	var painel: Rect2 = DialogueBox.PANEL
	var fora: Array = []
	var cortados: Array = []
	for b in btns:
		var bt: Button = b
		var r := bt.get_global_rect()
		info("botão '%s' rect=%s disabled=%s" % [bt.text, str(r), str(bt.disabled)])
		if r.position.x < vis.position.x + BORDA or r.end.x > vis.end.x - BORDA or r.position.y < vis.position.y or r.end.y > vis.end.y:
			fora.append(bt.text)
		elif r.position.x < painel.position.x - BORDA or r.end.x > painel.end.x + BORDA:
			fora.append(bt.text + " (fora do painel)")
		# texto cabe no botão? (largura do texto + margens do estilo)
		var font := bt.get_theme_font("font")
		var fs := bt.get_theme_font_size("font_size")
		var sb := bt.get_theme_stylebox("normal")
		var margem := (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)) if sb != null else 0.0
		var w := font.get_string_size(bt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + margem
		if bt.clip_text and w > r.size.x + 0.5:
			cortados.append("%s (texto %.0f > botão %.0f)" % [bt.text, w, r.size.x])
	check("tres_botoes_dentro_da_tela_e_do_painel", fora.is_empty(), "fora=%s tela=%s painel=%s" % [str(fora), str(vis), str(painel)])
	check("texto_dos_botoes_sem_corte", cortados.is_empty(), str(cortados))

	# Motivo do bloqueio visível sem mouse (texto na tela, não só tooltip).
	var semente: Dictionary = {}
	for c in escolhas:
		if c is Dictionary and not bool(c.get("enabled", true)):
			semente = c
	if semente.is_empty():
		info("nenhuma opção trancada com 0 Adormecidos (motivo não se aplica)")
	else:
		var dica := String(semente.get("hint", ""))
		var visivel := _texto_visivel_contem(d, dica, "Adormecid")
		check("motivo_do_bloqueio_visivel_sem_mouse", visivel, "dica='%s' (procurei em Labels/Buttons visíveis do diálogo)" % dica)
	d._finish()


## Algum texto VISÍVEL do diálogo (Label/Button/RichTextLabel) mostra o motivo?
func _texto_visivel_contem(raiz: Node, dica: String, palavra: String) -> bool:
	for n in raiz.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree():
			continue
		var t := ""
		if c is Label:
			t = (c as Label).text
		elif c is Button:
			t = (c as Button).text
		elif c is RichTextLabel:
			t = (c as RichTextLabel).get_parsed_text()
		if t == "":
			continue
		if (dica != "" and t.contains(dica)) or t.to_lower().contains(palavra.to_lower()):
			return true
	return false
