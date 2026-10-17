extends Control
## CRÔNICAS — o caderno das Estelas lidas. Lista as 18 entradas (trancadas
## mostram "???" e a dica de onde ficam); persistem entre runs (Gnosis).
## Miniatura do afresco da Estela (Onda 3) no canto do painel de leitura, ao
## lado do Éon e do título; trancada = pedra escura (sem spoiler).
## Cada entrada é um botão-linha FOCÁVEL: setas, W/S, D-pad e analógico andam
## (o foco do Godot faz o trabalho); Esc / B / Voltar → menu principal.
## Segurar ↑/↓ repete com atraso (QA L3): 1 passo no aperto, ~0,35 s parado,
## depois um passo a cada ~0,08 s. O "eco" do teclado do sistema é ignorado
## para a velocidade ser a mesma em todo PC e no controle.

const LIST_X := 22.0
const LIST_Y := 66.0
const ROW_H := 15.0
const LIST_W := 214.0
const PANEL_SIZE := Vector2(372, 292)   # painel de leitura (direita; vai até y 350)
const REPEAT_DELAY := 0.35        # s segurando antes de começar a repetir
const REPEAT_RATE := 0.08         # s entre passos repetidos

var _entries: Array = []
var _sel: int = 0
var _rows: Array[Button] = []
var _head: Label
var _title: Label
var _eon: Label
var _body: Label
var _source: Label
var _thumb: Stela.ArtFrame
var _panel: PanelContainer
var _vbox: VBoxContainer
var _hint_locked: Label
var _back: Button
var _hold_dir: int = 0            # direção segurada (-1 sobe, 1 desce, 0 nada)
var _hold_t: float = 0.0
var _next_rep: float = REPEAT_DELAY


func _ready() -> void:
	CodexStyle.apply_existing(self, true)
	_entries = Gnosis.entries()
	var hud := CanvasLayer.new()
	add_child(hud)

	CodexStyle.label(hud, "Crônicas", Vector2(LIST_X, 10), 22, CodexStyle.GOLD_HI, 300, true)
	_head = CodexStyle.label(hud, "", Vector2(LIST_X, 40), 11, CodexStyle.MUTED, 360)
	_head.add_theme_font_override("font", CodexStyle.italic())
	_back = CodexStyle.button(hud, "Voltar", Vector2(536, 12), 84, _leave, false, "ui_back")
	var hint := InputGlyphs.Hint.new()     # segue o dispositivo em uso (#33)
	hint.pairs = [["@nav", "escolhem"], ["ui_cancel", "volta"]]
	hint.position = Vector2(LIST_X, 338)
	hint.size = Vector2(300, 16)
	hint.align = 0
	hud.add_child(hint)

	# Lista (esquerda): linhas focáveis com estilo de "marcador de página".
	for i in _entries.size():
		var b := Button.new()
		b.position = Vector2(LIST_X - 6, LIST_Y + float(i) * ROW_H)
		b.size = Vector2(LIST_W, ROW_H)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_override("font", CodexStyle.body())
		b.add_theme_font_size_override("font_size", 11)
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 14
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, empty)
		var f := CodexFrame.new()
		f.fill_top = Color(CodexStyle.GOLD, 0.16)
		f.fill_bottom = Color(CodexStyle.GOLD, 0.04)
		f.border = Color(CodexStyle.GOLD_HI, 0.7)
		f.border_width = 0.6
		f.chamfer = 3.0
		f.content_margin_left = 14
		b.add_theme_stylebox_override("focus", f)
		var idx := i
		b.focus_entered.connect(func():
			_sel = idx
			_refresh())
		b.mouse_entered.connect(func(): b.grab_focus())
		hud.add_child(b)
		_rows.append(b)
	for i in _rows.size():
		var b := _rows[i]
		b.focus_neighbor_top = b.get_path_to(_rows[i - 1] if i > 0 else _back)
		b.focus_neighbor_bottom = b.get_path_to(_rows[i + 1] if i < _rows.size() - 1 else _rows[0])
		b.focus_neighbor_right = b.get_path_to(_back)
		b.focus_neighbor_left = b.get_path_to(b)
	_back.focus_neighbor_bottom = _back.get_path_to(_rows[0])
	_back.focus_neighbor_left = _back.get_path_to(_rows[0])
	_back.focus_neighbor_top = _back.get_path_to(_rows[_rows.size() - 1])

	# Painel de leitura (direita)
	var panel := PanelContainer.new()
	panel.theme = CodexStyle.theme()
	panel.position = Vector2(250, LIST_Y - 8)
	panel.size = PANEL_SIZE
	panel.clip_contents = true
	hud.add_child(panel)
	_panel = panel
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	_vbox = vbox
	# Cabeçalho: miniatura do afresco + Éon e título.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 9)
	vbox.add_child(top)
	_thumb = Stela.ArtFrame.new()
	_thumb.custom_minimum_size = Vector2(42, 40)
	_thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_thumb)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(tv)
	_eon = Label.new()
	_eon.add_theme_font_override("font", CodexStyle.display())
	_eon.add_theme_font_size_override("font_size", 8)
	_eon.add_theme_color_override("font_color", CodexStyle.MUTED)
	tv.add_child(_eon)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", CodexStyle.GOLD_HI)
	_title.add_theme_font_override("font", CodexStyle.display())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(_title)
	var rule := CodexStyle.Rule.new()
	rule.custom_minimum_size = Vector2(0, 7)
	rule.color = Color(CodexStyle.GOLD, 0.7)
	vbox.add_child(rule)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 12)
	_body.add_theme_color_override("font_color", CodexStyle.PAPER)
	_body.add_theme_constant_override("line_spacing", 0)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(_body)
	_hint_locked = Label.new()
	_hint_locked.add_theme_font_override("font", CodexStyle.italic())
	_hint_locked.add_theme_font_size_override("font_size", 12)
	_hint_locked.add_theme_color_override("font_color", CodexStyle.MUTED)
	_hint_locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_hint_locked)
	_source = Label.new()
	_source.add_theme_font_override("font", CodexStyle.italic())
	_source.add_theme_font_size_override("font_size", 10)
	_source.add_theme_color_override("font_color", CodexStyle.MUTED)
	_source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_source)

	# Começa na primeira entrada lida, se houver.
	for i in _entries.size():
		if Gnosis.is_unlocked(String(_entries[i].id)):
			_sel = i
			break
	_refresh()
	_rows[_sel].grab_focus()
	CodexStyle.stagger_in(_rows, -8.0, 0.015, 0.05)
	CodexStyle.pop_in(panel, "")


func _refresh() -> void:
	_head.text = "%d de %d Estelas lidas — o ensino dos antigos, pedra a pedra" % [Gnosis.chronicles_count(), Gnosis.chronicles_total()]
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var open := Gnosis.is_unlocked(String(e.id))
		var b: Button = _rows[i]
		b.text = "%02d   %s" % [i + 1, String(e.title) if open else "???"]
		var col := CodexStyle.GOLD_HI if i == _sel else (CodexStyle.PAPER if open else Color(CodexStyle.MUTED, 0.75))
		for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			b.add_theme_color_override(k, col)
	var cur: Dictionary = _entries[_sel]
	_eon.text = String(cur.eon).to_upper()
	var open_cur := Gnosis.is_unlocked(String(cur.id))
	_thumb.locked = not open_cur
	_thumb.texture = Stela.art_for(String(cur.id)) if open_cur else null
	if open_cur:
		_title.text = String(cur.title)
		_body.text = "\n".join(PackedStringArray(cur.lines))
		_body.visible = true
		_hint_locked.text = ""
		_hint_locked.visible = false
		_source.text = "Fonte: %s" % String(cur.source)
		_fit_body.call_deferred()
	else:
		_title.text = "???"
		_body.add_theme_font_size_override("font_size", 12)
		_body.text = ""
		_body.visible = false          # a dica sobe pra logo abaixo do título
		_panel.size = PANEL_SIZE
		_hint_locked.visible = true
		_hint_locked.text = "Estela ainda não lida.\nOnde: %s\nChegue perto e aperte o golpe leve (J / X) para ler." % String(cur.hint)
		_source.text = ""


## Texto longo (Estelas de ~650 letras) não pode vazar do painel: a fonte do
## corpo desce de 12 até 10 até o conteúdo caber (medido depois do layout).
func _fit_body() -> void:
	if _panel == null or not _body.visible:
		return
	var sb := _panel.get_theme_stylebox("panel")
	var inner := PANEL_SIZE - (sb.get_minimum_size() if sb != null else Vector2.ZERO)
	var w := inner.x
	var sep := float(_vbox.get_theme_constant("separation"))
	# Label com quebra automática não informa a altura quebrada no tamanho
	# mínimo: mede pela fonte (cabeçalho + filete + corpo + fonte histórica).
	var fixed := 40.0 + 7.0 + sep * 3.0
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	for fs in [12, 11, 10]:
		var sfs := 10 if fs >= 11 else 9
		var bf: Font = _body.get_theme_font("font")
		var sf: Font = _source.get_theme_font("font")
		var bh := bf.get_multiline_string_size(_body.text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, flags).y
		var shh := sf.get_multiline_string_size(_source.text, HORIZONTAL_ALIGNMENT_LEFT, w, sfs, -1, flags).y
		_body.add_theme_font_size_override("font_size", fs)
		_source.add_theme_font_size_override("font_size", sfs)
		if fixed + bh + shh + 10.0 <= inner.y:
			break
	_panel.size = PANEL_SIZE


## Repetição própria ao segurar (ver cabeçalho). O 1º passo vem do aperto.
func _process(delta: float) -> void:
	var dir := 0
	if Input.is_action_pressed("ui_down") or (InputMap.has_action("move_down") and Input.is_action_pressed("move_down")):
		dir = 1
	elif Input.is_action_pressed("ui_up") or (InputMap.has_action("move_up") and Input.is_action_pressed("move_up")):
		dir = -1
	# Só repete com o foco na lista (no "Voltar" o aperto já basta).
	var on_list := _rows.has(get_viewport().gui_get_focus_owner())
	if dir == 0 or dir != _hold_dir or not on_list:
		_hold_dir = dir
		_hold_t = 0.0
		_next_rep = REPEAT_DELAY
		return
	_hold_t += delta
	while _hold_t >= _next_rep:
		_move(dir)
		_next_rep += REPEAT_RATE


## O eco do teclado (repetição do sistema) não anda na lista: quem repete é o _process.
func _input(event: InputEvent) -> void:
	if event.is_echo() and (event.is_action("ui_up") or event.is_action("ui_down") \
			or event.is_action("move_up") or event.is_action("move_down")):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		_leave()
	# W/S (fora do ui_up/ui_down) também andam pela lista.
	elif event.is_action_pressed("move_up") and not event.is_action("ui_up"):
		_rows[wrapi(_sel - 1, 0, _rows.size())].grab_focus()
	elif event.is_action_pressed("move_down") and not event.is_action("ui_down"):
		_rows[wrapi(_sel + 1, 0, _rows.size())].grab_focus()


## Anda `dir` entradas (usado por ferramentas de QA; o jogador usa o foco).
func _move(dir: int) -> void:
	_rows[wrapi(_sel + dir, 0, _rows.size())].grab_focus()


func _leave() -> void:
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
