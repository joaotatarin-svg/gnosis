extends RefCounted
class_name CodexStyle
## Linguagem compartilhada: obsidiana, marfim e ouro envelhecido.

const INK := Color("0a151c")
const PAPER := Color("eee4cd")
const GOLD := Color("c5a56a")
const MUTED := Color("8caaa9")

static func serif() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
	return f

static func label(parent: Node, text: String, pos: Vector2, size: int, color: Color = PAPER, width: float = 400.0, display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size.x = width
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display:
		l.add_theme_font_override("font", serif())
	parent.add_child(l)
	return l

static func button(parent: Node, text: String, pos: Vector2, width: float, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(width, 29)
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", INK if primary else PAPER)
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_focus_color", PAPER)
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = GOLD if primary and state == "normal" else Color("183139")
		if not primary and state == "normal":
			box.bg_color = Color(0.04, 0.09, 0.12, 0.8)
		box.border_color = GOLD if state != "normal" else Color("425453")
		box.set_border_width_all(1)
		box.set_content_margin_all(5)
		b.add_theme_stylebox_override(state, box)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", PAPER)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = Color("122a32") if state in ["hover", "focus"] else INK
		b.border_color = GOLD if state in ["hover", "focus", "disabled"] else Color("3e5556")
		b.set_border_width_all(1)
		b.content_margin_left = 12
		b.content_margin_right = 12
		b.content_margin_top = 7
		b.content_margin_bottom = 7
		t.set_stylebox(state, "Button", b)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(INK, 0.98)
	panel.border_color = Color(GOLD, 0.7)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(16)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 12
	t.set_stylebox("panel", "PanelContainer", panel)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("253d42")
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = track.duplicate()
	filled.bg_color = GOLD
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	# Ícone vetorial em memória: não depende dos círculos padrão do editor.
	var grad := Gradient.new()
	grad.set_color(0, GOLD)
	grad.set_color(1, PAPER)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 7
	tex.height = 14
	t.set_icon("grabber", "HSlider", tex)
	t.set_icon("grabber_highlight", "HSlider", tex)
	return t

static func apply_existing(root: Node, backdrop: bool = false) -> void:
	var t := theme()
	if root is Control:
		root.theme = t
	else:
		for child in root.get_children():
			if child is Control:
				child.theme = t
	for node in root.find_children("*", "Label", true, false):
		if node.name == "Title":
			node.add_theme_font_override("font", serif())
			node.add_theme_font_size_override("font_size", 26)
			node.add_theme_color_override("font_color", PAPER)
	if root.has_node("Dim"):
		root.get_node("Dim").color = Color(0.02, 0.045, 0.06, 0.84)
	if backdrop and root.has_node("Bg"):
		root.get_node("Bg").color = INK
		var architecture = load("res://scripts/fx/codex_sanctum.gd").new()
		architecture.menu = true
		architecture.modulate = Color(0.4, 0.48, 0.48)
		root.add_child(architecture)
		root.move_child(architecture, 1)
