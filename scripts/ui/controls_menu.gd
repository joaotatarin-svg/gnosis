extends CanvasLayer
class_name ControlsMenu
## Tela CONTROLES (backlog #34): remapear tecla e botão de cada ação.
## Uma linha por ação: nome · TECLADO · CONTROLE. Enter/A numa vaga → "aperte a
## nova tecla/botão" (Esc ou Start cancelam; 6 s sem nada também). Se o atalho
## já for de outra ação, as duas trocam. Grava em `settings["bindings"]` pelo
## SaveManager (`InputRebind` faz a troca no InputMap). "Restaurar padrão" volta
## ao layout de fábrica. Funciona com a árvore pausada (aberta pelas Opções).
## Uso: `ControlsMenu.open(node_pai)`.

signal closed

const PANEL_POS := Vector2(30, 14)
const PANEL_SIZE := Vector2(580, 332)
const NAME_W := 250.0
const SLOT_W := 136.0
const CAPTURE_TIME := 6.0

var _rows: Array = []                 # [{id, kb: Button, pad: Button}]
var _status: Label
var _pad_title: Label
var _capturing: Button = null
var _cap_action: String = ""
var _cap_pad: bool = false
var _cap_t: float = 0.0
var _reset_btn: Button
var _back: Button


static func open(parent: Node) -> ControlsMenu:
	var m := ControlsMenu.new()
	parent.add_child(m)
	return m


func _ready() -> void:
	layer = 58
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputRebind.capture_factory()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.045, 0.06, 0.9)
	dim.size = Vector2(640, 360)
	add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", CodexStyle.panel_frame(0.98))
	panel.position = PANEL_POS
	panel.size = PANEL_SIZE
	add_child(panel)
	CodexStyle.label(panel, "Controles", Vector2(18, 9), 17, CodexStyle.GOLD_HI, 300, true)
	var x_kb := 18.0 + NAME_W + 8.0
	var x_pad := x_kb + SLOT_W + 8.0
	_head(panel, "AÇÃO", Vector2(18, 38), NAME_W, HORIZONTAL_ALIGNMENT_LEFT)
	_head(panel, "TECLADO", Vector2(x_kb, 38), SLOT_W, HORIZONTAL_ALIGNMENT_CENTER)
	_pad_title = _head(panel, "", Vector2(x_pad, 38), SLOT_W, HORIZONTAL_ALIGNMENT_CENTER)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 52)
	scroll.size = Vector2(PANEL_SIZE.x - 28, 214)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)
	for a in InputRebind.ACTIONS:
		_add_row(list, a)
	_status = CodexStyle.label(panel, "", Vector2(18, 272), 10, CodexStyle.GOLD_HI, PANEL_SIZE.x - 36)
	_status.add_theme_font_override("font", CodexStyle.italic())
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var foot := InputGlyphs.Hint.new()
	foot.pairs = [["ui_accept", "trocar"], ["ui_cancel", "voltar"]]
	foot.position = Vector2(18, 300)
	foot.size = Vector2(250, 16)
	foot.font_size = 9
	foot.icon_h = 12.0
	foot.align = 0
	panel.add_child(foot)
	_reset_btn = CodexStyle.button(panel, "Restaurar padrão", Vector2(PANEL_SIZE.x - 18 - 110 - 8 - 140, 294), 140, _reset, false, "ui_confirm")
	_back = CodexStyle.button(panel, "Voltar", Vector2(PANEL_SIZE.x - 18 - 110, 294), 110, close, false, "")
	var l := InputGlyphs.listener()
	if l != null:
		l.connect("device_changed", _on_device_changed)
	_refresh()
	if not _rows.is_empty():
		_rows[0].kb.grab_focus()
	CodexStyle.pop_in(panel)


func _head(parent: Node, text: String, pos: Vector2, w: float, align: int) -> Label:
	var l := CodexStyle.label(parent, text, pos, 8, CodexStyle.GOLD, w, true)
	l.horizontal_alignment = align
	return l


func _add_row(list: VBoxContainer, a: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	list.add_child(row)
	var name_l := Label.new()
	name_l.text = a[1]
	name_l.custom_minimum_size = Vector2(NAME_W, 22)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_override("font", CodexStyle.display())
	name_l.add_theme_font_size_override("font_size", 10)
	row.add_child(name_l)
	var kb := _slot_button(row)
	var pad := _slot_button(row)
	kb.pressed.connect(_begin.bind(kb, String(a[0]), false))
	if a[3]:
		pad.pressed.connect(_begin.bind(pad, String(a[0]), true))
	else:
		pad.disabled = true
		pad.focus_mode = Control.FOCUS_NONE
	kb.focus_entered.connect(func(): name_l.add_theme_color_override("font_color", CodexStyle.GOLD_HI))
	kb.focus_exited.connect(func(): name_l.remove_theme_color_override("font_color"))
	pad.focus_entered.connect(func(): name_l.add_theme_color_override("font_color", CodexStyle.GOLD_HI))
	pad.focus_exited.connect(func(): name_l.remove_theme_color_override("font_color"))
	_rows.append({"id": String(a[0]), "kb": kb, "pad": pad, "pad_ok": bool(a[3])})


func _slot_button(row: HBoxContainer) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SLOT_W, 22)
	b.add_theme_font_override("font", CodexStyle.body_bold())
	b.add_theme_font_size_override("font_size", 11)
	CodexStyle._wire(b, "")
	row.add_child(b)
	return b


func _on_device_changed(_d: int) -> void:
	_refresh()


func _refresh() -> void:
	var pk := InputGlyphs.pad_kind()
	_pad_title.text = "CONTROLE  ·  %s" % InputGlyphs.device_name(pk).to_upper()
	for r in _rows:
		if r.kb == _capturing or r.pad == _capturing:
			continue
		var kev := InputRebind.slot_event(r.id, false)
		r.kb.text = InputGlyphs.event_label(kev, InputGlyphs.Device.KEYBOARD) if kev != null else "—"
		if r.pad_ok:
			var pev := InputRebind.slot_event(r.id, true)
			r.pad.text = InputGlyphs.event_label(pev, pk) if pev != null else "—"
		else:
			r.pad.text = "Analógico / D-pad"


# --- captura ------------------------------------------------------------------------

func _begin(b: Button, action: String, pad: bool) -> void:
	if _capturing != null:
		return
	_capturing = b
	_cap_action = action
	_cap_pad = pad
	_cap_t = 0.0
	b.text = "…"
	var nm := ""
	for a in InputRebind.ACTIONS:
		if a[0] == action:
			nm = a[1]
	if pad:
		_status.text = "Aperte o novo botão para “%s”  ·  %s cancela" % [nm, InputGlyphs.pad_button_name(JOY_BUTTON_START, InputGlyphs.pad_kind())]
	else:
		_status.text = "Aperte a nova tecla para “%s”  ·  Esc cancela" % nm
	Audio.play_sfx("ui_open")


func _end(msg: String = "") -> void:
	var b := _capturing
	_capturing = null
	_status.text = msg
	_refresh()
	if b != null:
		b.grab_focus()


func _process(delta: float) -> void:
	if _capturing == null:
		return
	_cap_t += delta
	if _cap_t > CAPTURE_TIME:
		_end("Nada mudou.")


func _input(event: InputEvent) -> void:
	if _capturing == null:
		return
	get_viewport().set_input_as_handled()
	if _cap_t < 0.12:
		return                                   # o próprio Enter/A que abriu a captura
	var ev: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE or (event as InputEventKey).keycode == KEY_ESCAPE:
			Audio.play_sfx("ui_back")
			_end("Nada mudou.")
			return
		if _cap_pad:
			_status.text = "Aperte um botão do controle (ou Esc para cancelar)."
			return
		ev = event
	elif event is InputEventJoypadButton and event.pressed:
		if (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
			Audio.play_sfx("ui_back")
			_end("Nada mudou.")
			return
		if not _cap_pad:
			_status.text = "Aperte uma tecla (ou Start para cancelar)."
			return
		ev = event
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		if not _cap_pad:
			return
		ev = event
	if ev == null:
		return
	var why := InputRebind.refusal(ev)
	if why != "":
		Audio.play_sfx("shop_fail")
		_status.text = why
		return
	var before: Dictionary = _bindings()
	var after := InputRebind.rebind(before, _cap_action, ev)
	GameManager.settings["bindings"] = after
	SaveManager.save_game()
	Audio.play_sfx("ui_confirm")
	var swapped := ""
	for k in after:
		if k != _cap_action and str(after[k]) != str(before.get(k, null)):
			swapped = k
	_end(("Trocado com “%s”." % _name_of(swapped)) if swapped != "" else "Salvo.")


func _bindings() -> Dictionary:
	var b = GameManager.settings.get("bindings", {})
	return (b as Dictionary).duplicate(true) if typeof(b) == TYPE_DICTIONARY else {}


func _name_of(action: String) -> String:
	for a in InputRebind.ACTIONS:
		if a[0] == action:
			return a[1]
	return action


func _reset() -> void:
	GameManager.settings["bindings"] = InputRebind.reset()
	SaveManager.save_game()
	_refresh()
	_status.text = "Layout de fábrica restaurado."


func close() -> void:
	if _capturing != null:
		return
	Audio.play_sfx("ui_back")
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _capturing != null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
