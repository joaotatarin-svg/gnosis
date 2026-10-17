extends RefCounted
class_name CodexStyle
## SISTEMA VISUAL do GNOSIS (detalhes em docs/UI.md): azul-noite, marfim, ouro
## velho e a luz da faísca. Fontes próprias embutidas (OFL, assets/fonts/):
##   Cinzel            → títulos, botões, nomes (versalete gravado em pedra)
##   Cinzel Decorative → só o logotipo GNOSIS
##   Alegreya          → texto corrido, falas, números do HUD (algarismos alinhados)
## Tudo por código: `install_global()` (chamado pelo SceneManager) põe o tema no
## tema padrão do motor, então TODO Control do jogo já nasce com a cara do Códex.

# --- paleta -------------------------------------------------------------------
const INK := Color("0a151c")          # azul-noite (fundo)
const INK_DEEP := Color("060d12")
const NIGHT := Color("12252e")        # azul-noite claro (painéis)
const PAPER := Color("eee4cd")        # marfim (texto)
const GOLD := Color("c5a56a")         # ouro velho
const GOLD_HI := Color("ecd498")      # ouro aceso (foco, destaques)
const GOLD_LO := Color("6f5a35")      # ouro apagado (filetes)
const MUTED := Color("8caaa9")        # verdete (texto secundário)
const SPARK := Color("fff0bf")        # luz de faísca
const EMBER := Color("e0743a")        # brasa (fase II, perigo)
const LIFE := Color("c9475b")         # vida (carmim)
const LIFE_HI := Color("f08a8f")
const ETHER := Color("4f9ad0")        # Éter (azul-celeste)
const ETHER_HI := Color("a6e1f5")

const BTN_H := 26.0

# --- fontes (cache) -----------------------------------------------------------
static var _fonts: Dictionary = {}


static func _file(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path)
	return _fonts[path]


static func _variant(key: String, path: String, wght: int, lining: bool = false) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = _file(path)
	fv.variation_opentype = {"wght": wght}
	if lining:
		fv.opentype_features = {"lnum": 1}    # algarismos alinhados (HUD, preços)
	_fonts[key] = fv
	# Cinzel não tem setas/losangos: cai na Alegreya (e depois no sistema).
	if path.contains("cinzel"):
		fv.fallbacks = [body()]
	return fv


## Cinzel semi-negrito: títulos, botões, nomes de falante e de chefe.
static func display() -> Font:
	return _variant("display", "res://assets/fonts/cinzel/Cinzel-VF.ttf", 600)


static func display_bold() -> Font:
	return _variant("display_bold", "res://assets/fonts/cinzel/Cinzel-VF.ttf", 800)


## Logotipo (só o título GNOSIS).
static func logo() -> Font:
	return _file("res://assets/fonts/cinzel_decorative/CinzelDecorative-Bold.ttf")


## Alegreya: corpo de texto, falas e descrições.
static func body() -> Font:
	return _variant("body", "res://assets/fonts/alegreya/Alegreya-VF.ttf", 500, true)


static func body_bold() -> Font:
	return _variant("body_bold", "res://assets/fonts/alegreya/Alegreya-VF.ttf", 750, true)


static func italic() -> Font:
	return _variant("italic", "res://assets/fonts/alegreya/Alegreya-Italic-VF.ttf", 500, true)


## Compatibilidade (cinemáticas, Estelas): a serifa de LEITURA do jogo.
static func serif() -> Font:
	return body()


# --- molduras ------------------------------------------------------------------

## Moldura de botão por estado ("normal", "hover", "pressed", "focus", "disabled").
static func button_frame(state: String, primary: bool = false) -> CodexFrame:
	var f := CodexFrame.new()
	f.chamfer = 5.0
	f.content_margin_left = 12
	f.content_margin_right = 12
	f.content_margin_top = 4
	f.content_margin_bottom = 5
	match state:
		"normal":
			f.fill_top = Color(0.075, 0.15, 0.18, 0.92)
			f.fill_bottom = Color(0.035, 0.075, 0.095, 0.92)
			f.border = Color(GOLD, 0.38)
		"hover":
			f.fill_top = Color(0.11, 0.2, 0.23, 0.96)
			f.fill_bottom = Color(0.05, 0.1, 0.125, 0.96)
			f.border = Color(GOLD, 0.8)
		"pressed":
			f.fill_top = Color(0.03, 0.06, 0.08, 0.98)
			f.fill_bottom = Color(0.08, 0.15, 0.17, 0.98)
			f.border = GOLD_HI
		"disabled":
			f.fill_top = Color(0.05, 0.09, 0.11, 0.55)
			f.fill_bottom = Color(0.03, 0.06, 0.08, 0.55)
			f.border = Color(MUTED, 0.16)
		"focus":
			# Desenhada POR CIMA do estado atual: só contorno, losangos e halo.
			f.fill_top = Color(0, 0, 0, 0)
			f.fill_bottom = Color(0, 0, 0, 0)
			f.border = GOLD_HI
			f.border_width = 1.0
			f.inner = Color(GOLD_HI, 0.35)
			f.marks = CodexFrame.Marks.SIDES
			f.mark_color = GOLD_HI
			f.glow = Color(GOLD, 0.9)
	if primary and state != "focus":
		match state:
			"disabled":
				pass
			"pressed":
				f.fill_top = Color("a8884f")
				f.fill_bottom = Color("d9bc80")
			_:
				f.fill_top = Color("e3c78c") if state == "hover" else Color("d6b97c")
				f.fill_bottom = Color("a0804a")
		if state != "disabled":
			f.border = GOLD_HI
			f.inner = Color(1, 0.97, 0.85, 0.35)
	return f


## Moldura de painel (diálogo, pausa, loja): filete duplo + cantoneiras.
static func panel_frame(alpha: float = 0.97) -> CodexFrame:
	var f := CodexFrame.new()
	f.fill_top = Color(0.07, 0.14, 0.17, alpha)
	f.fill_bottom = Color(0.025, 0.055, 0.075, alpha)
	f.border = Color(GOLD, 0.75)
	f.inner = Color(GOLD, 0.28)
	f.inner_inset = 3.0
	f.chamfer = 7.0
	f.marks = CodexFrame.Marks.CORNERS
	f.mark_color = Color(GOLD_HI, 0.9)
	f.shadow = 6.0
	f.set_content_margin_all(16)
	return f


# --- tema -----------------------------------------------------------------------

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body()
	t.default_font_size = 11
	t.set_color("font_color", "Label", PAPER)
	# Botões
	t.set_font("font", "Button", display())
	t.set_font_size("font_size", "Button", 10)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color("fff6e0"))
	t.set_color("font_focus_color", "Button", Color("fff6e0"))
	t.set_color("font_pressed_color", "Button", GOLD_HI)
	t.set_color("font_hover_pressed_color", "Button", GOLD_HI)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.55))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", button_frame(state))
	t.set_stylebox("hover_pressed", "Button", button_frame("pressed"))
	# Painéis
	t.set_stylebox("panel", "PanelContainer", panel_frame())
	t.set_stylebox("panel", "Panel", panel_frame())
	t.set_stylebox("panel", "TooltipPanel", panel_frame(0.98))
	t.set_font("font", "TooltipLabel", body())
	t.set_font_size("font_size", "TooltipLabel", 10)
	t.set_color("font_color", "TooltipLabel", PAPER)
	# Slider: trilho fino + preenchimento dourado + losango de pegar
	var track := StyleBoxFlat.new()
	track.bg_color = Color("1c3138")
	track.border_color = Color(GOLD, 0.25)
	track.set_border_width_all(1)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var filled := StyleBoxFlat.new()
	filled.bg_color = GOLD
	filled.content_margin_top = 2
	filled.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", filled)
	var filled_hi: StyleBoxFlat = filled.duplicate()
	filled_hi.bg_color = GOLD_HI
	t.set_stylebox("grabber_area_highlight", "HSlider", filled_hi)
	t.set_icon("grabber", "HSlider", _diamond_icon(GOLD, PAPER))
	t.set_icon("grabber_highlight", "HSlider", _diamond_icon(GOLD_HI, Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", _diamond_icon(GOLD_LO, MUTED))
	var sfocus := StyleBoxEmpty.new()
	t.set_stylebox("focus", "HSlider", sfocus)
	# Barra de rolagem fina, dourada
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.13, 0.15, 0.6)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(GOLD, 0.55)
	grab.set_corner_radius_all(2)
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	var grab_hi: StyleBoxFlat = grab.duplicate()
	grab_hi.bg_color = GOLD_HI
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	# Separador
	var line := StyleBoxLine.new()
	line.color = Color(GOLD, 0.3)
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 6)
	_theme = t
	return t


## Ícone de losango (pegador do slider), gerado em memória.
static func _diamond_icon(fill: Color, edge: Color) -> ImageTexture:
	var n := 11
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := absf(x - c) + absf(y - c)
			if d <= c - 1.0:
				img.set_pixel(x, y, fill.lerp(edge, clampf(0.6 - float(y) / float(n), 0.0, 0.6)))
			elif d <= c:
				img.set_pixel(x, y, Color(INK_DEEP, 0.9))
	return ImageTexture.create_from_image(img)


## Instala o tema no motor inteiro (todo Control sem tema próprio herda).
## Chamado UMA vez pelo autoload SceneManager.
static func install_global(tree: SceneTree) -> void:
	var t := theme()
	ThemeDB.get_default_theme().merge_with(t)
	ThemeDB.fallback_font = body()
	ThemeDB.fallback_font_size = 11
	tree.root.theme = t


## Solta os caches estáticos (fontes/tema) ao fechar o jogo — sem isso o
## Godot avisa "resources still in use at exit".
static func release(tree: SceneTree) -> void:
	if tree != null and tree.root != null:
		tree.root.theme = null
	ThemeDB.fallback_font = null
	# O tema padrão do motor guarda as nossas molduras/fontes (merge_with):
	# limpa ao sair pra elas não ficarem "em uso" no encerramento.
	ThemeDB.get_default_theme().clear()
	_theme = null
	_fonts.clear()


# --- fábrica de rótulos/botões -------------------------------------------------------

static func label(parent: Node, text: String, pos: Vector2, size: int, color: Color = PAPER, width: float = 400.0, display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size.x = width
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if display:
		l.add_theme_font_override("font", display_font_for(size))
	parent.add_child(l)
	return l


## Títulos grandes ganham o peso mais leve (o Cinzel pesado embola em corpo grande).
static func display_font_for(size: int) -> Font:
	if size >= 30:
		return _variant("display_light", "res://assets/fonts/cinzel/Cinzel-VF.ttf", 500)
	return display()


## Liga a quebra de linha num Label criado por `label()` mantendo a largura
## (o tamanho tem de ser reposto DEPOIS do autowrap, senão fica na linha única).
static func wrap_label(l: Label, width: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.size = Vector2(width, 0)
	return l


## Botão do Códex. `sfx` = som ao apertar ("" = nenhum; "ui_back" pra Voltar).
## O som de MOVER o foco é global (SceneManager) — não precisa ligar aqui.
static func button(parent: Node, text: String, pos: Vector2, width: float, action: Callable, primary: bool = false, sfx: String = "ui_confirm") -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true                     # a largura pedida é lei: nunca cresce
	b.position = pos
	b.size = Vector2(width, BTN_H)
	style_button(b, primary)
	b.pressed.connect(action)
	_wire(b, sfx)
	parent.add_child(b)
	return b


## Aplica o visual do Códex num botão já existente (cenas .tscn).
static func style_button(b: Button, primary: bool = false) -> void:
	b.add_theme_font_override("font", display())
	b.add_theme_font_size_override("font_size", 10)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, button_frame(state, primary))
	b.add_theme_stylebox_override("hover_pressed", button_frame("pressed", primary))
	if primary:
		for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, INK)
	b.focus_mode = Control.FOCUS_ALL


## Som de apertar + mouse que passa por cima toma o foco (mouse e controle
## mostram a MESMA seleção).
static func _wire(b: Button, sfx: String = "ui_confirm") -> void:
	if b.has_meta("codex_wired"):
		return
	b.set_meta("codex_wired", true)
	if sfx != "":
		b.pressed.connect(func(): Audio.play_sfx(sfx))
	b.mouse_entered.connect(func():
		if b.is_inside_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())


## Liga som/hover em todos os botões de uma cena .tscn (Voltar/Menu → ui_back).
static func wire_buttons(root: Node) -> void:
	for n in root.find_children("*", "Button", true, false):
		var b: Button = n
		var back := b.text.begins_with("Voltar") or b.text == "Menu" or b.name in ["Back", "Menu"]
		_wire(b, "ui_back" if back else "ui_confirm")


# --- ornamentos ------------------------------------------------------------------------

## Filete ornamental: linha dourada que some nas pontas + losango no centro.
static func rule(parent: Node, pos: Vector2, width: float, color: Color = GOLD) -> Control:
	var r := Rule.new()
	r.color = color
	r.position = pos
	r.size = Vector2(width, 7)
	r.custom_minimum_size = Vector2(0, 7)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


class Rule extends Control:
	var color: Color = Color("c5a56a")
	func _draw() -> void:
		var y := size.y * 0.5
		var c := size.x * 0.5
		var arm := c - 9.0
		var steps := 12
		for i in steps:
			var a := float(i) / steps
			var b := float(i + 1) / steps
			var col := Color(color, color.a * (0.08 + 0.8 * b))
			draw_line(Vector2(c - 9.0 - arm * (1.0 - a), y), Vector2(c - 9.0 - arm * (1.0 - b), y), col, 0.6, true)
			draw_line(Vector2(c + 9.0 + arm * (1.0 - a), y), Vector2(c + 9.0 + arm * (1.0 - b), y), col, 0.6, true)
		CodexStyle.draw_diamond(self, Vector2(c, y), 3.0, color)
		CodexStyle.draw_diamond(self, Vector2(c - 6.0, y), 1.4, Color(color, 0.7))
		CodexStyle.draw_diamond(self, Vector2(c + 6.0, y), 1.4, Color(color, 0.7))


## Desenha um losango (centro, meia-altura) num CanvasItem qualquer.
static func draw_diamond(ci: CanvasItem, c: Vector2, s: float, col: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)])
	ci.draw_colored_polygon(pts, col)
	if outline.a > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, outline, 0.6, true)


## Faísca: estrela de quatro pontas com halo (ícone de moeda, marcador).
static func draw_spark(ci: CanvasItem, c: Vector2, r: float, col: Color = SPARK) -> void:
	ci.draw_circle(c, r * 1.25, Color(GOLD, 0.16))
	ci.draw_circle(c, r * 0.7, Color(GOLD_HI, 0.28))
	var k := r * 0.24
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(k, -k), c + Vector2(r, 0), c + Vector2(k, k),
		c + Vector2(0, r), c + Vector2(-k, k), c + Vector2(-r, 0), c + Vector2(-k, -k)]), col)
	ci.draw_circle(c, r * 0.22, Color.WHITE)


# --- animação de entrada --------------------------------------------------------------

## Abre um painel/overlay: sobe de 0 → 1 de opacidade com leve "assentar" de
## escala. `sfx` = "ui_open" por padrão. Funciona com a árvore pausada.
static func pop_in(node: CanvasItem, sfx: String = "ui_open", from_scale: float = 0.96) -> void:
	if node == null:
		return
	if sfx != "":
		Audio.play_sfx(sfx)
	node.modulate.a = 0.0
	if node is Control:
		var c: Control = node
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2.ONE * from_scale
	var t := node.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(node, "modulate:a", 1.0, 0.18)
	if node is Control:
		t.tween_property(node, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Entrada escalonada (menus): cada item desliza `dx` px e acende, um após o outro.
static func stagger_in(nodes: Array, dx: float = -14.0, delay: float = 0.05, start: float = 0.0) -> void:
	var i := 0
	for n in nodes:
		if not (n is CanvasItem) or not is_instance_valid(n):
			continue
		var ci: CanvasItem = n
		var final_a := ci.modulate.a
		ci.modulate.a = 0.0
		var t := ci.create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		var d := start + delay * i
		if ci is Control and not (ci.get_parent() is Container):
			var c: Control = ci
			var p := c.position
			c.position = p + Vector2(dx, 0)
			t.tween_property(c, "position", p, 0.32).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(ci, "modulate:a", final_a, 0.26).set_delay(d)
		i += 1


# --- cenas existentes (.tscn) ----------------------------------------------------------

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
			node.add_theme_font_override("font", display())
			node.add_theme_font_size_override("font_size", 20)
			node.add_theme_color_override("font_color", GOLD_HI)
	wire_buttons(root)
	if root.has_node("Dim"):
		root.get_node("Dim").color = Color(0.02, 0.045, 0.06, 0.84)
	if backdrop and root.has_node("Bg"):
		root.get_node("Bg").color = INK
		var architecture = load("res://scripts/fx/codex_sanctum.gd").new()
		architecture.menu = true
		architecture.medallion = 0.25          # telas de texto: sem "cursores" sobre títulos/sliders (P1)
		architecture.modulate = Color(0.4, 0.48, 0.48)
		root.add_child(architecture)
		root.move_child(architecture, 1)
		var motes := Motes.new()
		root.add_child(motes)
		root.move_child(motes, 2)


## Poeira de luz que sobe devagar (fundo "vivo" dos menus). Determinística.
class Motes extends Node2D:
	var count: int = 34
	var area: Rect2 = Rect2(0, 0, 640, 360)
	var tint: Color = Color("ecd498")
	var _t: float = 0.0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		for i in count:
			var h1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
			var h2 := fposmod(sin(i * 78.233) * 12543.123, 1.0)
			var h3 := fposmod(sin(i * 39.425) * 9631.77, 1.0)
			var speed := 4.0 + h2 * 9.0
			var y := area.end.y - fposmod(h1 * area.size.y + _t * speed, area.size.y + 20.0) + 10.0
			var x := area.position.x + h3 * area.size.x + sin(_t * (0.3 + h1 * 0.5) + i) * 6.0
			var tw := 0.5 + 0.5 * sin(_t * (1.2 + h2 * 2.0) + i * 1.7)
			var r := 0.5 + h2 * 0.9
			var col := Color(tint, (0.12 + 0.45 * tw) * (0.4 + 0.6 * h3))
			draw_circle(Vector2(x, y), r * 2.4, Color(col, col.a * 0.18))
			draw_circle(Vector2(x, y), r, col)


## Caixa de confirmação modal (menu "Nova campanha", pausa "Abandonar").
## Cria uma CanvasLayer acima de tudo; `on_yes`/`on_no` fecham a caixa antes
## de rodar. Devolve a camada (quem chama pode ignorar). Roda com a árvore pausada.
static func confirm(parent: Node, title: String, body_text: String, yes_text: String, on_yes: Callable, no_text: String = "Voltar", on_no: Callable = Callable()) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.045, 0.06, 0.78)
	dim.size = Vector2(640, 360)
	layer.add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", panel_frame(0.98))
	panel.position = Vector2(150, 92)
	panel.size = Vector2(340, 176)
	layer.add_child(panel)
	var t := label(panel, title, Vector2(20, 18), 15, GOLD_HI, 300, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule(panel, Vector2(70, 42), 200, Color(GOLD, 0.8))
	var b := wrap_label(label(panel, body_text, Vector2(24, 56), 11, Color(PAPER, 0.88), 292), 292)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var yes := button(panel, yes_text, Vector2(22, 132), 143, func():
		layer.queue_free()
		if on_yes.is_valid(): on_yes.call(), true, "ui_confirm")
	var no := button(panel, no_text, Vector2(175, 132), 143, func():
		layer.queue_free()
		if on_no.is_valid(): on_no.call(), false, "ui_back")
	yes.focus_neighbor_right = yes.get_path_to(no)
	no.focus_neighbor_left = no.get_path_to(yes)
	yes.focus_neighbor_left = yes.get_path_to(yes)
	no.focus_neighbor_right = no.get_path_to(no)
	for x in [yes, no]:
		x.focus_neighbor_top = x.get_path_to(x)
		x.focus_neighbor_bottom = x.get_path_to(x)
	# Esc / B do controle = "Voltar".
	var catcher := _CancelCatcher.new()
	catcher.on_cancel = func():
		layer.queue_free()
		if on_no.is_valid(): on_no.call()
	layer.add_child(catcher)
	no.grab_focus()
	pop_in(panel)
	return layer


## Escuta "cancelar" (Esc / B) por uma caixa modal.
class _CancelCatcher extends Node:
	var on_cancel: Callable
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			Audio.play_sfx("ui_back")
			if on_cancel.is_valid():
				on_cancel.call()
