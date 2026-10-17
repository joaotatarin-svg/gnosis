extends Control
## CRÔNICAS — o caderno das Estelas lidas. Lista as 18 entradas (trancadas
## mostram "???" e a dica de onde ficam); persistem entre runs (Gnosis).
## Cada entrada é um botão-linha FOCÁVEL: setas, W/S, D-pad e analógico andam
## (o foco do Godot faz o trabalho); Esc / B / Voltar → menu principal.

const LIST_X := 22.0
const LIST_Y := 66.0
const ROW_H := 15.0
const LIST_W := 214.0

var _entries: Array = []
var _sel: int = 0
var _rows: Array[Button] = []
var _head: Label
var _title: Label
var _eon: Label
var _body: Label
var _source: Label
var _hint_locked: Label
var _back: Button


func _ready() -> void:
	CodexStyle.apply_existing(self, true)
	_entries = Gnosis.entries()
	var hud := CanvasLayer.new()
	add_child(hud)

	CodexStyle.label(hud, "Crônicas", Vector2(LIST_X, 10), 22, CodexStyle.GOLD_HI, 300, true)
	_head = CodexStyle.label(hud, "", Vector2(LIST_X, 40), 11, CodexStyle.MUTED, 360)
	_head.add_theme_font_override("font", CodexStyle.italic())
	_back = CodexStyle.button(hud, "Voltar", Vector2(536, 12), 84, _leave, false, "ui_back")
	CodexStyle.label(hud, "W/S · setas · D-pad escolhem   ·   Esc / B volta", Vector2(LIST_X, 340), 10, Color(CodexStyle.MUTED, 0.85), 400)

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
	panel.size = Vector2(372, 274)
	hud.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	_eon = Label.new()
	_eon.add_theme_font_override("font", CodexStyle.display())
	_eon.add_theme_font_size_override("font_size", 8)
	_eon.add_theme_color_override("font_color", CodexStyle.MUTED)
	vbox.add_child(_eon)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", CodexStyle.GOLD_HI)
	_title.add_theme_font_override("font", CodexStyle.display())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title)
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
	if Gnosis.is_unlocked(String(cur.id)):
		_title.text = String(cur.title)
		_body.text = "\n".join(PackedStringArray(cur.lines))
		_body.visible = true
		_hint_locked.text = ""
		_source.text = "Fonte: %s" % String(cur.source)
	else:
		_title.text = "???"
		_body.text = ""
		_body.visible = false          # a dica sobe pra logo abaixo do título
		_hint_locked.text = "Estela ainda não lida.\nOnde: %s\nChegue perto e aperte o golpe leve (J / X) para ler." % String(cur.hint)
		_source.text = ""


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


func _leave() -> void:
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
