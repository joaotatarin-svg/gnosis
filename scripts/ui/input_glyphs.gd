class_name InputGlyphs
extends RefCounted
## GLIFOS DE BOTÃO (backlog #33): o texto e o ícone de cada AÇÃO seguem o
## ÚLTIMO dispositivo usado — teclado, controle Xbox, PlayStation, Nintendo ou
## Steam Deck (pelo nome/fabricante do joypad). Necessário para o Deck Verified.
##
## Uso (tudo estático, sem autoload):
##   InputGlyphs.label("attack_light")         → "J" · "X" · "□" · "Y" (Switch)
##   InputGlyphs.hint([["ui_accept", "confirmar"], ["ui_cancel", "voltar"]])
##                                               → "Enter confirmar  ·  Esc voltar"
##   InputGlyphs.is_pad() / device() / device_name()
##   InputGlyphs.listener().device_changed.connect(cb)   # troca de dispositivo
##   InputGlyphs.draw_icon(ci, centro, "jump", 14.0)     # ícone desenhado por código
##   InputGlyphs.Hint (Control): rodapé "ícone + texto" que se atualiza sozinho.
## Pseudoações: "@move" (andar), "@nav" (navegar nos menus), "@scroll" (rolar).
##
## A detecção é feita por um nó ouvinte (`listener()`), criado na 1ª consulta e
## pendurado na raiz da árvore (PROCESS_MODE_ALWAYS: funciona com o jogo pausado).
## Quem já tem `_input` pode chamar `note_event(event)` direto (idempotente).

enum Device { KEYBOARD, XBOX, PLAYSTATION, NINTENDO, DECK }

const DEVICE_NAMES := ["Teclado", "Xbox", "PlayStation", "Nintendo", "Steam Deck"]

## Cores dos botões de face (tons do Códex, não as cores berrantes de fábrica).
const XBOX_COLORS := {
	JOY_BUTTON_A: Color("6fae5c"), JOY_BUTTON_B: Color("c9554f"),
	JOY_BUTTON_X: Color("4f86c6"), JOY_BUTTON_Y: Color("d8b44a"),
}
const PS_COLORS := {
	JOY_BUTTON_A: Color("8fb3e8"), JOY_BUTTON_B: Color("e07a7a"),
	JOY_BUTTON_X: Color("d79ac8"), JOY_BUTTON_Y: Color("5fc7a6"),
}
const KEYCAP_FILL := Color("12252e")
const KEYCAP_EDGE := Color("c5a56a")
const GLYPH_TEXT := Color("eee4cd")

static var _device: int = Device.KEYBOARD
static var _detected: bool = false
static var _pad_kind: int = Device.XBOX          # tipo do último controle visto
static var _listener: Node = null
static var _ps_text: int = -1                     # -1 = não testado; 0/1 = a fonte tem ✕○□△?


# --- dispositivo -----------------------------------------------------------------

## Dispositivo em uso (Device). Antes do 1º evento: controle se houver um ligado.
static func device() -> int:
	listener()
	if not _detected:
		_detected = true
		var pads := Input.get_connected_joypads()
		if not pads.is_empty():
			_pad_kind = kind_for_joypad(pads[0])
			_device = _pad_kind
	return _device


static func is_pad(dev: int = -1) -> bool:
	return (device() if dev < 0 else dev) != Device.KEYBOARD


## Tipo do último CONTROLE visto (vale mesmo com o teclado em uso): para mostrar
## a coluna "Controle" da tela de Controles com os nomes certos.
static func pad_kind() -> int:
	device()
	return _pad_kind


static func device_name(dev: int = -1) -> String:
	return DEVICE_NAMES[clampi(device() if dev < 0 else dev, 0, DEVICE_NAMES.size() - 1)]


## Força o dispositivo (sondas/testes e quem souber melhor). Avisa os ouvintes.
static func set_device(dev: int) -> void:
	_detected = true
	if dev != Device.KEYBOARD:
		_pad_kind = dev
	if dev != _device:
		_device = dev
		var l := listener()
		if l != null:
			l.emit_signal("device_changed", dev)


## Atualiza o dispositivo pelo evento (teclado/mouse × controle). Analógico só
## conta acima de 0,5 (drift do stick não troca os ícones no meio da leitura).
static func note_event(event: InputEvent) -> void:
	var dev := -1
	if event is InputEventKey and (event as InputEventKey).pressed:
		dev = Device.KEYBOARD
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		dev = Device.KEYBOARD
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		dev = kind_for_joypad(event.device)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		dev = kind_for_joypad(event.device)
	if dev >= 0:
		set_device(dev)


## Tipo do controle pelo nome e pelo fabricante (USB vendor id) que o SDL informa.
static func kind_for_joypad(joy_id: int) -> int:
	if not Input.get_connected_joypads().has(joy_id):
		return _pad_kind                                # evento sintético / controle já desligado
	var info: Dictionary = Input.get_joy_info(joy_id)
	var vendor := int(info.get("vendor_id", 0))
	return kind_from_name(Input.get_joy_name(joy_id), vendor)


## Função pura (testável): nome do joypad (+ vendor opcional) → Device.
static func kind_from_name(joy_name: String, vendor: int = 0) -> int:
	var n := joy_name.to_lower()
	if n.contains("steam deck") or n.contains("valve"):
		return Device.DECK
	if vendor == 0x054C or n.contains("playstation") or n.contains("dualsense") or n.contains("dualshock") \
			or n.contains("ps3") or n.contains("ps4") or n.contains("ps5") or n.contains("sony"):
		return Device.PLAYSTATION
	if vendor == 0x057E or n.contains("nintendo") or n.contains("switch") or n.contains("joy-con"):
		return Device.NINTENDO
	return Device.XBOX                                  # XInput e genéricos: letras do Xbox


## Nó ouvinte (cria na 1ª chamada). Tem o sinal `device_changed(device: int)`.
static func listener() -> Node:
	if _listener != null and is_instance_valid(_listener):
		return _listener
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var existing := tree.root.get_node_or_null("InputGlyphsListener")
	if existing != null:
		_listener = existing
		return _listener
	_listener = Listener.new()
	_listener.name = "InputGlyphsListener"
	tree.root.add_child.call_deferred(_listener)
	return _listener


class Listener extends Node:
	signal device_changed(device: int)

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		InputGlyphs.note_event(event)


# --- texto -----------------------------------------------------------------------

## Rótulo curto da tecla/botão de `action` no dispositivo em uso (ou `dev`).
static func label(action: String, dev: int = -1) -> String:
	var d := device() if dev < 0 else dev
	match action:
		"@move":
			if d != Device.KEYBOARD:
				return "Analógico"
			return "%s %s" % [label("move_left", d), label("move_right", d)]
		"@nav":
			return "Setas" if d == Device.KEYBOARD else "D-pad"
		"@scroll":
			return "%s %s" % [label("move_up", d), label("move_down", d)] if d == Device.KEYBOARD else "Analógico"
	var ev := event_for(action, d)
	if ev == null:
		return "—"
	return event_label(ev, d)


## O evento do InputMap que representa `action` no dispositivo (o 1º do tipo).
## Para o controle, botão antes de eixo; para o teclado, tecla antes de mouse.
static func event_for(action: String, dev: int = -1) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var d := device() if dev < 0 else dev
	var evs := InputMap.action_get_events(action)
	if d != Device.KEYBOARD:
		for e in evs:
			if e is InputEventJoypadButton:
				return e
		for e in evs:
			if e is InputEventJoypadMotion:
				return e
		return null
	for e in evs:
		if e is InputEventKey:
			return e
	for e in evs:
		if e is InputEventMouseButton:
			return e
	return null


## Texto de um evento qualquer (tecla, botão, eixo, mouse).
static func event_label(ev: InputEvent, dev: int = -1) -> String:
	var d := device() if dev < 0 else dev
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: Key = k.keycode
		if k.physical_keycode != KEY_NONE:
			code = k.physical_keycode
			# Mostra a tecla do layout do jogador (AZERTY etc.), não a do QWERTY.
			if DisplayServer.get_name() != "headless":
				var local := DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
				if local != KEY_NONE:
					code = local
		return key_name(code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Mouse esq."
			MOUSE_BUTTON_RIGHT: return "Mouse dir."
			MOUSE_BUTTON_MIDDLE: return "Mouse meio"
		return "Mouse %d" % int((ev as InputEventMouseButton).button_index)
	if ev is InputEventJoypadButton:
		return pad_button_name((ev as InputEventJoypadButton).button_index, _pad_dev(d))
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		return pad_axis_name(m.axis, m.axis_value, _pad_dev(d))
	return "—"


static func _pad_dev(d: int) -> int:
	return _pad_kind if d == Device.KEYBOARD else d


static func key_name(code: Key) -> String:
	match code:
		KEY_SPACE: return "Espaço"
		KEY_ESCAPE: return "Esc"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_TAB: return "Tab"
		KEY_ENTER, KEY_KP_ENTER: return "Enter"
		KEY_BACKSPACE: return "Backspace"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_NONE: return "—"
	return OS.get_keycode_string(code)


## Nome do botão no controle `dev` (pela POSIÇÃO: o Godot chama de A o botão de
## baixo em qualquer controle; no Switch ele está escrito "B").
static func pad_button_name(b: int, dev: int = Device.XBOX) -> String:
	var ps := dev == Device.PLAYSTATION
	var nin := dev == Device.NINTENDO
	var deck := dev == Device.DECK
	match b:
		JOY_BUTTON_A: return _ps_face(0) if ps else ("B" if nin else "A")
		JOY_BUTTON_B: return _ps_face(1) if ps else ("A" if nin else "B")
		JOY_BUTTON_X: return _ps_face(2) if ps else ("Y" if nin else "X")
		JOY_BUTTON_Y: return _ps_face(3) if ps else ("X" if nin else "Y")
		JOY_BUTTON_LEFT_SHOULDER: return "L1" if (ps or deck) else ("L" if nin else "LB")
		JOY_BUTTON_RIGHT_SHOULDER: return "R1" if (ps or deck) else ("R" if nin else "RB")
		JOY_BUTTON_LEFT_STICK: return "L3" if (ps or deck) else "LS"
		JOY_BUTTON_RIGHT_STICK: return "R3" if (ps or deck) else "RS"
		JOY_BUTTON_BACK: return "Create" if ps else ("−" if nin else "View")
		JOY_BUTTON_START: return "Options" if ps else ("+" if nin else "Menu")
		JOY_BUTTON_GUIDE: return "PS" if ps else ("Home" if nin else "Guia")
		JOY_BUTTON_DPAD_LEFT: return "D-pad ←"
		JOY_BUTTON_DPAD_RIGHT: return "D-pad →"
		JOY_BUTTON_DPAD_UP: return "D-pad ↑"
		JOY_BUTTON_DPAD_DOWN: return "D-pad ↓"
		JOY_BUTTON_MISC1: return "Share" if not ps else "Mic"
	return "Botão %d" % b


static func pad_axis_name(axis: int, value: float = 1.0, dev: int = Device.XBOX) -> String:
	var ps := dev == Device.PLAYSTATION or dev == Device.DECK
	var nin := dev == Device.NINTENDO
	match axis:
		JOY_AXIS_TRIGGER_LEFT: return "L2" if ps else ("ZL" if nin else "LT")
		JOY_AXIS_TRIGGER_RIGHT: return "R2" if ps else ("ZR" if nin else "RT")
		JOY_AXIS_LEFT_X: return "Analógico ←" if value < 0.0 else "Analógico →"
		JOY_AXIS_LEFT_Y: return "Analógico ↑" if value < 0.0 else "Analógico ↓"
		JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "Analógico dir."
	return "Eixo %d" % axis


## Face do PlayStation: símbolo se a fonte do jogo tiver, senão o nome.
static func _ps_face(i: int) -> String:
	if _ps_text < 0:
		var f: Font = CodexStyle.body()
		_ps_text = 1 if (f != null and f.has_char(0x2715) and f.has_char(0x25CB) and f.has_char(0x25A1) and f.has_char(0x25B3)) else 0
	if _ps_text == 1:
		return ["✕", "○", "□", "△"][i]
	return ["Cruz", "Círculo", "Quadrado", "Triângulo"][i]


## Linha de dicas: [[ação, texto], ...] → "J atacar  ·  K forte". Uma ação pode
## ser um Array de ações (mostra as teclas juntas: ["ui_up", "ui_down"]).
static func hint(pairs: Array, dev: int = -1, sep: String = "  ·  ") -> String:
	var parts := PackedStringArray()
	for p in pairs:
		var acts = p[0]
		var keys := PackedStringArray()
		if acts is Array:
			for a in acts:
				keys.append(label(String(a), dev))
		else:
			keys.append(label(String(acts), dev))
		parts.append("%s %s" % ["/".join(keys), I18n.t(String(p[1]))])
	return sep.join(parts)


## Rodapé pronto dos CARDS da Cinemática (prólogo/epílogo/Crônicas — QA2 #13):
## "[Enter] avança  ·  [Esc] pula" no teclado, "[A] avança  ·  [≡] pula" no
## controle; troca sozinho com o dispositivo. Alinhado à direita, corpo 9 px.
## Uso (cinematic.gd, no lugar do Label "qualquer tecla avança · Esc pula"):
##   var h := InputGlyphs.card_hint()
##   h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
##   h.offset_left = -240.0; h.offset_top = -24.0; h.offset_right = -14.0; h.offset_bottom = -8.0
##   add_child(h)
static func card_hint(color: Color = CodexStyle.MUTED) -> Hint:
	var h := Hint.new()
	h.pairs = [["ui_accept", "avança"], ["pause", "pula"]]
	h.font_size = 9
	h.icon_h = 11.0
	h.align = 2
	h.color = color
	return h


# --- ícones (desenhados por código) ----------------------------------------------

## Largura do ícone de `action` na altura `h` (para alinhar antes de desenhar).
static func icon_width(action: String, h: float, font: Font = null, dev: int = -1) -> float:
	var d := device() if dev < 0 else dev
	var ev := event_for(action, d) if not action.begins_with("@") else null
	var shape := _shape(ev, action, d)
	if shape == "face" or shape == "stick" or shape == "dpad":
		return h
	var f: Font = font if font != null else CodexStyle.body_bold()
	var fs := _icon_font_size(h)
	var tw := f.get_string_size(I18n.t(_icon_text(ev, action, d)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return maxf(h, tw + h * 0.7)


## Desenha o ícone de `action` centrado em `center` (altura `h`) em qualquer
## CanvasItem (chame dentro do `_draw` dele). Devolve a largura usada.
##   teclado → tecla (retângulo arredondado com a letra)
##   face    → círculo com letra (Xbox/Deck/Switch) ou forma (PlayStation)
##   ombro/gatilho → pílula com "LB"/"L1"/"ZL"; D-pad → cruz; analógico → anel
static func draw_icon(ci: CanvasItem, center: Vector2, action: String, h: float, font: Font = null, dev: int = -1, alpha: float = 1.0) -> float:
	var d := device() if dev < 0 else dev
	var ev := event_for(action, d) if not action.begins_with("@") else null
	var shape := _shape(ev, action, d)
	var f: Font = font if font != null else CodexStyle.body_bold()
	var w := icon_width(action, h, f, d)
	var r := h * 0.5
	var edge := Color(KEYCAP_EDGE, 0.9 * alpha)
	var fill := Color(KEYCAP_FILL, 0.92 * alpha)
	match shape:
		"face":
			var b := (ev as InputEventJoypadButton).button_index
			var pd := _pad_dev(d)
			var col: Color = (PS_COLORS if pd == Device.PLAYSTATION else XBOX_COLORS).get(b, GLYPH_TEXT)
			ci.draw_circle(center, r, fill)
			ci.draw_arc(center, r - 0.5, 0.0, TAU, 24, Color(col, alpha), 1.2, true)
			if pd == Device.PLAYSTATION:
				_draw_ps_shape(ci, center, r * 0.5, b, Color(col, alpha))
			else:
				_text_centered(ci, center, pad_button_name(b, pd), f, _icon_font_size(h), Color(col.lightened(0.25), alpha))
		"dpad":
			var t := h * 0.3
			var col2 := Color(GLYPH_TEXT, 0.85 * alpha)
			ci.draw_rect(Rect2(center - Vector2(r * 0.9, t * 0.5), Vector2(r * 1.8, t)), fill)
			ci.draw_rect(Rect2(center - Vector2(t * 0.5, r * 0.9), Vector2(t, r * 1.8)), fill)
			ci.draw_rect(Rect2(center - Vector2(r * 0.9, t * 0.5), Vector2(r * 1.8, t)), edge, false, 1.0)
			ci.draw_rect(Rect2(center - Vector2(t * 0.5, r * 0.9), Vector2(t, r * 1.8)), edge, false, 1.0)
			var dir := _dpad_dir(ev, action)
			if dir != Vector2.ZERO:
				ci.draw_rect(Rect2(center + dir * r * 0.55 - Vector2(t, t) * 0.4, Vector2(t, t) * 0.8), col2)
		"stick":
			ci.draw_circle(center, r, fill)
			ci.draw_arc(center, r - 0.5, 0.0, TAU, 24, edge, 1.2, true)
			ci.draw_arc(center, r * 0.5, 0.0, TAU, 18, Color(GLYPH_TEXT, 0.7 * alpha), 1.0, true)
			var sdir := _stick_dir(ev, action)
			if sdir != Vector2.ZERO:
				ci.draw_circle(center + sdir * r * 0.55, r * 0.18, Color(GLYPH_TEXT, 0.9 * alpha))
		_:
			# tecla, ombro, gatilho, mouse: caixa arredondada com o texto.
			var rect := Rect2(center - Vector2(w * 0.5, r), Vector2(w, h))
			var sb := StyleBoxFlat.new()
			sb.bg_color = fill
			sb.border_color = edge
			sb.set_border_width_all(1)
			var rad := int(r) if shape == "pill" else int(maxf(2.0, h * 0.18))
			sb.set_corner_radius_all(rad)
			sb.anti_aliasing = true
			sb.draw(ci.get_canvas_item(), rect)
			if shape == "key":
				# borda de baixo mais grossa: lê como tecla
				ci.draw_line(rect.position + Vector2(rad, h - 1.0), rect.position + Vector2(w - rad, h - 1.0), edge, 1.0)
			_text_centered(ci, center, _icon_text(ev, action, d), f, _icon_font_size(h), Color(GLYPH_TEXT, alpha))
	return w


static func _icon_font_size(h: float) -> int:
	return maxi(6, int(round(h * 0.62)))


static func _shape(ev: InputEvent, action: String, d: int) -> String:
	if action == "@move" or action == "@scroll":
		return "stick" if d != Device.KEYBOARD else "key"
	if action == "@nav":
		return "dpad" if d != Device.KEYBOARD else "key"
	if ev is InputEventJoypadButton:
		var b := (ev as InputEventJoypadButton).button_index
		if b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
			return "face"
		if b in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			return "dpad"
		return "pill"
	if ev is InputEventJoypadMotion:
		var a := (ev as InputEventJoypadMotion).axis
		if a == JOY_AXIS_TRIGGER_LEFT or a == JOY_AXIS_TRIGGER_RIGHT:
			return "pill"
		return "stick"
	return "key"


static func _icon_text(ev: InputEvent, action: String, d: int) -> String:
	if action.begins_with("@"):
		return label(action, d)
	if ev == null:
		return "—"
	return event_label(ev, d)


static func _dpad_dir(ev: InputEvent, action: String) -> Vector2:
	if ev is InputEventJoypadButton:
		match (ev as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_LEFT: return Vector2.LEFT
			JOY_BUTTON_DPAD_RIGHT: return Vector2.RIGHT
			JOY_BUTTON_DPAD_UP: return Vector2.UP
			JOY_BUTTON_DPAD_DOWN: return Vector2.DOWN
	return Vector2.ZERO


static func _stick_dir(ev: InputEvent, _action: String) -> Vector2:
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		if m.axis == JOY_AXIS_LEFT_X or m.axis == JOY_AXIS_RIGHT_X:
			return Vector2(signf(m.axis_value), 0.0)
		if m.axis == JOY_AXIS_LEFT_Y or m.axis == JOY_AXIS_RIGHT_Y:
			return Vector2(0.0, signf(m.axis_value))
	return Vector2.ZERO


static func _draw_ps_shape(ci: CanvasItem, c: Vector2, s: float, b: int, col: Color) -> void:
	match b:
		JOY_BUTTON_A:      # cruz
			ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, 1.4, true)
			ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 1.4, true)
		JOY_BUTTON_B:      # círculo
			ci.draw_arc(c, s, 0.0, TAU, 20, col, 1.3, true)
		JOY_BUTTON_X:      # quadrado
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), col, false, 1.3)
		JOY_BUTTON_Y:      # triângulo
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.95, s * 0.7), c + Vector2(-s * 0.95, s * 0.7), c + Vector2(0, -s)])
			ci.draw_polyline(pts, col, 1.3, true)


static func _text_centered(ci: CanvasItem, c: Vector2, text: String, f: Font, fs: int, col: Color) -> void:
	text = I18n.t(text)
	var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var base := c + Vector2(-sz.x * 0.5, (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	ci.draw_string(f, base.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# --- rodapé pronto -----------------------------------------------------------------

## Rodapé "ícone texto · ícone texto" que se redesenha quando o dispositivo muda.
##   var h := InputGlyphs.Hint.new()
##   h.pairs = [["ui_accept", "confirmar"], ["ui_cancel", "voltar"]]
##   parent.add_child(h)   # posição/âncoras como qualquer Control
## `align` = 0 esquerda, 1 centro, 2 direita (dentro do `size` do Control).
class Hint extends Control:
	var pairs: Array = []:
		set(v):
			pairs = v
			_relayout()
	var font_size: int = 10
	var icon_h: float = 13.0
	var color: Color = Color("8caaa9")
	var align: int = 1
	var gap: float = 14.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := InputGlyphs.listener()
		if l != null and not l.is_connected("device_changed", _on_device):
			l.connect("device_changed", _on_device)
		_relayout()

	func _on_device(_d: int) -> void:
		_relayout()

	func content_width() -> float:
		var f: Font = CodexStyle.italic()
		var w := 0.0
		for i in pairs.size():
			var p: Array = pairs[i]
			for a in _acts(p[0]):
				w += InputGlyphs.icon_width(a, icon_h) + 2.0
			w += 3.0 + f.get_string_size(I18n.t(String(p[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if i < pairs.size() - 1:
				w += gap
		return w

	func _relayout() -> void:
		custom_minimum_size = Vector2(content_width(), maxf(icon_h, float(font_size) + 4.0))
		queue_redraw()

	func _acts(a) -> Array:
		return a if a is Array else [a]

	func _draw() -> void:
		var f: Font = CodexStyle.italic()
		var total := content_width()
		var x := 0.0
		if align == 1:
			x = (size.x - total) * 0.5
		elif align == 2:
			x = size.x - total
		var cy := size.y * 0.5 if size.y > 0.0 else icon_h * 0.5
		for i in pairs.size():
			var p: Array = pairs[i]
			for a in _acts(p[0]):
				var iw := InputGlyphs.icon_width(a, icon_h)
				InputGlyphs.draw_icon(self, Vector2(x + iw * 0.5, cy), a, icon_h)
				x += iw + 2.0
			x += 3.0
			var t := I18n.t(String(p[1]))
			draw_string(f, Vector2(x, cy + (f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5).round(), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			x += f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if i < pairs.size() - 1:
				x += gap
