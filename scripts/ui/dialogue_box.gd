extends CanvasLayer
class_name DialogueBox
## Caixa de diálogo do jogo. Pausa o mundo, mostra falas (avança com
## Espaço/ataque) e, opcionalmente, termina numa escolha com botões.
## Uso:  var d := DialogueBox.play([{speaker,text},...], ["Op A","Op B"])
##       await d.finished           (ou: var i = await d.choice_made)

signal finished
signal choice_made(index: int)

var lines: Array = []
var choices: Array = []      # String ou {text: String, enabled: bool}
var idx: int = 0

var _speaker: Label
var _text: Label
var _hint: Label
var _choice_box: HBoxContainer
var _in_choices: bool = false


static func play(p_lines: Array, p_choices: Array = []) -> DialogueBox:
	var d: DialogueBox = DialogueBox.new()
	d.lines = p_lines
	d.choices = p_choices
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.call_deferred("add_child", d)
	return d


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	layer = 90

	var panel := PanelContainer.new()
	panel.theme = CodexStyle.theme()
	# `anchors_preset` por código NÃO aplica as âncoras (só no editor) — o painel
	# encolhia pra largura do conteúdo e o texto quebrava palavra por palavra.
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = -130
	panel.offset_bottom = -14
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	_speaker = Label.new()
	_speaker.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_speaker.add_theme_font_size_override("font_size", 14)
	_speaker.add_theme_font_override("font", CodexStyle.serif())
	vbox.add_child(_speaker)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 40)
	# Tamanho da legenda vem das Opções (P/M/G).
	_text.add_theme_font_size_override("font_size", GameManager.caption_font_size())
	vbox.add_child(_text)

	_hint = Label.new()
	_hint.text = "▸ continuar"
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", CodexStyle.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_hint)

	_choice_box = HBoxContainer.new()
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.add_theme_constant_override("separation", 14)
	_choice_box.visible = false
	vbox.add_child(_choice_box)

	_show_line()


func _show_line() -> void:
	if idx >= lines.size():
		if choices.is_empty():
			_finish()
		else:
			_show_choices()
		return
	var l: Dictionary = lines[idx]
	_speaker.text = l.get("speaker", "")
	_text.text = l.get("text", "")


func _show_choices() -> void:
	_in_choices = true
	_hint.visible = false
	_choice_box.visible = true
	var first_btn: Button = null
	for i in choices.size():
		var c = choices[i]
		var btn := Button.new()
		if c is String:
			btn.text = c
		else:
			btn.text = c.get("text", "?")
			btn.disabled = not c.get("enabled", true)
			if btn.disabled and c.has("hint"):
				btn.tooltip_text = c.hint
		btn.pressed.connect(_on_choice.bind(i))
		_choice_box.add_child(btn)
		if first_btn == null and not btn.disabled:
			first_btn = btn
	if first_btn:
		first_btn.grab_focus()


func _on_choice(i: int) -> void:
	Audio.play_sfx("ui_choice")
	choice_made.emit(i)
	_finish()


func _finish() -> void:
	get_tree().paused = false
	finished.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _in_choices:
		return
	if event.is_action_pressed("attack_light") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_advance")
		idx += 1
		_show_line()
