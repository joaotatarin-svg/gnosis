extends Control
## CRÔNICAS — o caderno das Estelas lidas. Lista as 18 entradas (trancadas
## mostram "???" e a dica de onde ficam); persistem entre runs (Gnosis).
## W/S, setas ou gamepad navegam; Esc / Voltar → menu principal.

const LIST_X := 22.0
const LIST_Y := 64.0
const ROW_H := 15.0

var _entries: Array = []
var _sel: int = 0
var _rows: Array = []               # Labels da lista
var _head: Label
var _title: Label
var _body: Label
var _source: Label
var _hint_locked: Label
var _repeat: float = 0.0


func _ready() -> void:
	CodexStyle.apply_existing(self, true)
	_entries = Gnosis.entries()
	var hud := CanvasLayer.new()
	add_child(hud)

	CodexStyle.label(hud, "CRÔNICAS", Vector2(LIST_X, 12), 22, CodexStyle.PAPER, 300, true)
	_head = CodexStyle.label(hud, "", Vector2(LIST_X, 40), 10, CodexStyle.MUTED, 320)
	CodexStyle.button(hud, "Voltar", Vector2(541, 11), 80, _back)
	CodexStyle.label(hud, "W/S · setas · gamepad navegam   ·   Esc volta", Vector2(LIST_X, 342), 9, CodexStyle.MUTED, 400)

	# Lista (esquerda)
	for i in _entries.size():
		var l := CodexStyle.label(hud, "", Vector2(LIST_X, LIST_Y + float(i) * ROW_H), 10, CodexStyle.PAPER, 215)
		l.clip_text = true
		_rows.append(l)

	# Painel de leitura (direita)
	var panel := PanelContainer.new()
	panel.theme = CodexStyle.theme()
	panel.position = Vector2(248, LIST_Y - 6)
	panel.size = Vector2(372, 272)
	hud.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", CodexStyle.GOLD)
	_title.add_theme_font_override("font", CodexStyle.serif())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title)
	var rule := ColorRect.new()
	rule.color = Color(CodexStyle.GOLD, 0.5)
	rule.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(rule)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 10)
	_body.add_theme_color_override("font_color", CodexStyle.PAPER)
	_body.add_theme_constant_override("line_spacing", 1)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(_body)
	_hint_locked = Label.new()
	_hint_locked.add_theme_font_size_override("font_size", 10)
	_hint_locked.add_theme_color_override("font_color", CodexStyle.MUTED)
	_hint_locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_hint_locked)
	_source = Label.new()
	_source.add_theme_font_size_override("font_size", 8)
	_source.add_theme_color_override("font_color", CodexStyle.MUTED)
	_source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_source)

	# Começa na primeira entrada lida, se houver.
	for i in _entries.size():
		if Gnosis.is_unlocked(String(_entries[i].id)):
			_sel = i
			break
	_refresh()


func _refresh() -> void:
	_head.text = "%d de %d Estelas lidas — o ensino dos antigos, pedra a pedra" % [Gnosis.chronicles_count(), Gnosis.chronicles_total()]
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var open := Gnosis.is_unlocked(String(e.id))
		var l: Label = _rows[i]
		var mark := "▸ " if i == _sel else "  "
		l.text = "%s%02d  %s" % [mark, i + 1, String(e.title) if open else "???"]
		l.add_theme_color_override("font_color",
			CodexStyle.GOLD if i == _sel else (CodexStyle.PAPER if open else CodexStyle.MUTED))
	var cur: Dictionary = _entries[_sel]
	if Gnosis.is_unlocked(String(cur.id)):
		_title.text = "%s  ·  %s" % [String(cur.title), String(cur.eon)]
		_body.text = "\n".join(PackedStringArray(cur.lines))
		_body.visible = true
		_hint_locked.text = ""
		_source.text = "Fonte: %s" % String(cur.source)
	else:
		_title.text = "???  ·  %s" % String(cur.eon)
		_body.text = ""
		_body.visible = true
		_hint_locked.text = "Estela ainda não lida.\nOnde: %s\nChegue perto e aperte o golpe leve (J / X) para ler." % String(cur.hint)
		_source.text = ""


func _move(dir: int) -> void:
	_sel = wrapi(_sel + dir, 0, _entries.size())
	Audio.play_sfx("ui_move")
	_refresh()


func _process(delta: float) -> void:
	_repeat = maxf(0.0, _repeat - delta)
	var dir := 0
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
		dir = -1
	elif Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_down"):
		dir = 1
	elif _repeat <= 0.0:
		# Segurar o eixo do gamepad / a tecla rola devagar.
		var axis := Input.get_axis("move_up", "move_down")
		if absf(axis) > 0.6:
			dir = 1 if axis > 0.0 else -1
			_repeat = 0.18
	if dir != 0:
		if _repeat <= 0.0:
			_repeat = 0.18
		_move(dir)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_back()


func _back() -> void:
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
