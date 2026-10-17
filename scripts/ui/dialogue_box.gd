extends CanvasLayer
class_name DialogueBox
## Caixa de diálogo do jogo. Pausa o mundo, mostra falas com MÁQUINA DE
## ESCREVER (1º aperto mostra a fala inteira, 2º avança) e, opcionalmente,
## termina numa escolha com botões. Moldura do Códex, placa com o nome do
## falante e retrato pintado quando houver (assets/ui/portraits/).
## Cada 2 letras toca um "blip" de voz do falante (Audio.play_sfx — se o som
## não existir, fica mudo): blip_voz · blip_rei · blip_sophia · blip_estela · blip_npc.
## Uso:  var d := DialogueBox.play([{speaker,text},...], ["Op A","Op B"])
##       await d.finished           (ou: var i = await d.choice_made)

signal finished
signal choice_made(index: int)

const CPS := 46.0                 # letras por segundo
const PANEL := Rect2(36, 250, 568, 98)
const PORTRAIT_C := Vector2(80, 299)
const PORTRAIT_R := 30.0

var lines: Array = []
var choices: Array = []      # String ou {text: String, enabled: bool}
var idx: int = 0

var _root: Control
var _panel: Panel
var _deco: _Deco
var _plate: Panel
var _speaker: Label
var _text: Label
var _choice_box: HBoxContainer
var _in_choices: bool = false
var _typing: bool = false
var _shown: float = 0.0           # letras visíveis (fracionário)
var _pause: float = 0.0           # respiro de pontuação
var _blip_count: int = 0
var _blip: String = "blip_npc"
var _t: float = 0.0
var _portrait: Texture2D


static func play(p_lines: Array, p_choices: Array = []) -> DialogueBox:
	var d: DialogueBox = DialogueBox.new()
	d.lines = p_lines
	d.choices = p_choices
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.call_deferred("add_child", d)
	return d


## Retrato pintado do falante (null = sem retrato: A Voz, Estelas, desconhecidos).
static func portrait_for(speaker: String) -> Texture2D:
	var s := speaker.to_lower()
	var id := ""
	for k in ["sophia", "athoth", "harmas", "galila", "yabel", "astaphaios", "belias", "armupiel", "soter", "velkar"]:
		if s.contains(k):
			id = k
			break
	if id == "" and (s.contains("rei") or s.contains("yaldabaoth")):
		id = "rei"
	if id == "":
		return null
	var path := "res://assets/ui/portraits/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


## Som de "voz" (blip) por falante.
static func blip_for(speaker: String) -> String:
	var s := speaker.to_lower()
	if s.contains("voz"):
		return "blip_voz"
	if s.contains("sophia"):
		return "blip_sophia"
	if s.contains("estela"):
		return "blip_estela"
	if s.contains("rei") or s.contains("yaldabaoth") or s.contains("???"):
		return "blip_rei"
	for k in ["athoth", "harmas", "galila", "yabel", "astaphaios", "belias", "armupiel", "arconte"]:
		if s.contains(k):
			return "blip_rei"
	return "blip_npc"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	layer = 90

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = CodexStyle.theme()
	add_child(_root)

	# Véu leve na base (o texto assenta sobre o cenário).
	var veil := _Veil.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", CodexStyle.panel_frame(0.95))
	_panel.position = PANEL.position
	_panel.size = PANEL.size
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	_deco = _Deco.new()
	_deco.box = self
	_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_deco)

	# Placa do nome: aba sobre a borda de cima do painel.
	_plate = Panel.new()
	var pf := CodexStyle.button_frame("normal")
	pf.fill_top = Color(0.09, 0.17, 0.2, 0.98)
	pf.fill_bottom = Color(0.04, 0.08, 0.1, 0.98)
	pf.border = Color(CodexStyle.GOLD, 0.9)
	pf.inner = Color(CodexStyle.GOLD, 0.25)
	pf.chamfer = 4.0
	_plate.add_theme_stylebox_override("panel", pf)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_plate)
	_speaker = Label.new()
	_speaker.add_theme_font_override("font", CodexStyle.display())
	_speaker.add_theme_font_size_override("font_size", 10)
	_speaker.add_theme_color_override("font_color", CodexStyle.GOLD_HI)
	_speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_speaker)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Tamanho da legenda vem das Opções (P/M/G); a Alegreya pede +1 pra
	# render o mesmo "olho" da fonte antiga.
	_text.add_theme_font_size_override("font_size", GameManager.caption_font_size() + 1)
	_text.add_theme_color_override("font_color", CodexStyle.PAPER)
	_text.add_theme_constant_override("line_spacing", 1)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_text)

	_choice_box = HBoxContainer.new()
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.add_theme_constant_override("separation", 14)
	_choice_box.visible = false
	_choice_box.position = Vector2(PANEL.position.x + 110, PANEL.end.y - 34)
	_choice_box.size = Vector2(PANEL.size.x - 140, CodexStyle.BTN_H)
	_root.add_child(_choice_box)

	# Entrada: sobe 10 px e acende.
	_root.modulate.a = 0.0
	_root.position.y = 10
	var t := create_tween().set_parallel(true)
	t.tween_property(_root, "modulate:a", 1.0, 0.18)
	t.tween_property(_root, "position:y", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_line()


func _show_line() -> void:
	if idx >= lines.size():
		if choices.is_empty():
			_finish()
		else:
			_show_choices()
		return
	var l: Dictionary = lines[idx]
	var who := String(l.get("speaker", ""))
	_portrait = portrait_for(who)
	_blip = blip_for(who)
	_speaker.text = who
	_plate.visible = who != ""
	# Com retrato, o texto começa depois do medalhão.
	var x0 := PANEL.position.x + (88.0 if _portrait != null else 22.0)
	var font: Font = CodexStyle.display()
	var w := font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 30.0
	_plate.position = Vector2(x0 - 6.0, PANEL.position.y - 10.0)
	_plate.size = Vector2(maxf(70.0, w), 19)
	_speaker.position = Vector2.ZERO
	_speaker.size = _plate.size
	_text.position = Vector2(x0, PANEL.position.y + 16.0)
	_text.size = Vector2(PANEL.end.x - 22.0 - x0, PANEL.size.y - 30.0)
	_text.text = String(l.get("text", ""))
	_text.visible_characters = 0
	_shown = 0.0
	_pause = 0.0
	_blip_count = 0
	_typing = true
	_deco.queue_redraw()


## Mostra a fala inteira (1º aperto durante a digitação).
func reveal_all() -> void:
	_typing = false
	_text.visible_characters = -1


func is_typing() -> bool:
	return _typing


func _process(delta: float) -> void:
	_t += delta
	_deco.queue_redraw()
	if not _typing:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var total := _text.get_total_character_count()
	var before := int(_shown)
	_shown += delta * CPS
	var now := mini(int(_shown), total)
	var txt := _text.text
	for i in range(before, now):
		var ch := txt[i] if i < txt.length() else ""
		if ch != " " and ch != "\n":
			_blip_count += 1
			if _blip_count % 2 == 1:
				Audio.play_sfx(_blip)
		# respiro na pontuação
		if ch in [".", "!", "?", "…"]:
			_pause = 0.2
			_shown = float(i + 1)
			now = i + 1
			break
		elif ch in [",", ";", ":", "—"]:
			_pause = 0.08
			_shown = float(i + 1)
			now = i + 1
			break
	_text.visible_characters = now
	if now >= total:
		_typing = false
		_text.visible_characters = -1


func _show_choices() -> void:
	_in_choices = true
	_choice_box.visible = true
	var first_btn: Button = null
	var btns: Array = []
	for i in choices.size():
		var c = choices[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, CodexStyle.BTN_H)
		if c is String:
			btn.text = c
		else:
			btn.text = c.get("text", "?")
			btn.disabled = not c.get("enabled", true)
			if btn.disabled and c.has("hint"):
				btn.tooltip_text = c.hint
		CodexStyle.style_button(btn)
		CodexStyle._wire(btn, "")
		btn.pressed.connect(_on_choice.bind(i))
		_choice_box.add_child(btn)
		btns.append(btn)
		if first_btn == null and not btn.disabled:
			first_btn = btn
	# Esquerda/direita circulam; cima/baixo ficam (não fogem pro nada).
	for b in btns:
		var bb: Button = b
		bb.focus_neighbor_top = bb.get_path_to(bb)
		bb.focus_neighbor_bottom = bb.get_path_to(bb)
	CodexStyle.stagger_in(btns, 0.0, 0.06)
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
		if _typing:
			reveal_all()           # 1º aperto: a fala inteira
			return
		Audio.play_sfx("ui_advance")
		idx += 1
		_show_line()


## Véu escuro em degradê na base da tela.
class _Veil extends Control:
	func _draw() -> void:
		var top := 200.0
		var pts := PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, size.y), Vector2(0, size.y)])
		draw_polygon(pts, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.0, 0.02, 0.03, 0.55), Color(0.0, 0.02, 0.03, 0.55)]))


## Retrato em medalhão + indicador de "continuar" (losango que respira).
class _Deco extends Control:
	var box
	func _draw() -> void:
		var c: Vector2 = PORTRAIT_C
		var r: float = PORTRAIT_R
		if box._portrait != null:
			draw_circle(c + Vector2(0, 1.5), r + 4.0, Color(0, 0, 0, 0.45))
			draw_circle(c, r + 2.5, CodexStyle.INK_DEEP)
			draw_texture_rect(box._portrait, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
			draw_arc(c, r + 0.8, 0.0, TAU, 56, CodexStyle.GOLD, 1.6, true)
			draw_arc(c, r + 2.8, 0.0, TAU, 56, Color(CodexStyle.GOLD_LO, 0.9), 0.6, true)
			draw_arc(c, r - 1.0, 0.0, TAU, 56, Color(CodexStyle.GOLD_HI, 0.3), 0.5, true)
			for k in 4:
				var a := k * PI * 0.5
				CodexStyle.draw_diamond(self, c + Vector2(cos(a), sin(a)) * (r + 2.8), 2.0, CodexStyle.GOLD_HI)
		# "continuar": losango respirando no canto, só com a fala completa
		if not box._typing and not box._in_choices:
			var p := Vector2(PANEL.end.x - 18.0, PANEL.end.y - 12.0 + sin(box._t * 5.0) * 1.5)
			CodexStyle.draw_diamond(self, p, 3.4, CodexStyle.GOLD_HI, Color(0, 0, 0, 0.6))
			draw_string(CodexStyle.display(), Vector2(PANEL.end.x - 140.0, PANEL.end.y - 9.0), "continuar", HORIZONTAL_ALIGNMENT_RIGHT, 112.0, 7, Color(CodexStyle.MUTED, 0.8))
