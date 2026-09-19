extends CanvasLayer
class_name MovesScreen
## Tela de GOLPES & CONTROLES (overlay montado por código, sem cena).
## Lista TODOS os combos da Sophia com a sequência de botões (J/K no teclado,
## X/Y no controle), o nome e o nível de arma exigido — os trancados ficam em
## cinza com "Arma Nv. N" — mais os 7 Anéis (nome, Arconte, efeito; trancado
## se ainda não conquistado), a Esfera Solar e a tabela de controles.
## Rola com W/S, setas, analógico esquerdo ou roda do mouse. Fecha com Esc/B.
## Uso: `MovesScreen.open(node_pai)` — funciona com a árvore pausada.

signal closed

const PANEL_POS := Vector2(30, 18)
const PANEL_SIZE := Vector2(580, 324)
const SCROLL_SPEED := 220.0
const LOCKED := Color(0.55, 0.6, 0.62, 0.55)

var _scroll: ScrollContainer
var _list: VBoxContainer
var _back: Button


static func open(parent: Node) -> MovesScreen:
	var m := MovesScreen.new()
	parent.add_child(m)
	return m


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.045, 0.06, 0.86)
	dim.size = Vector2(640, 360)
	add_child(dim)
	var panel := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(CodexStyle.INK, 0.98)
	box.border_color = Color(CodexStyle.GOLD, 0.75)
	box.set_border_width_all(1)
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_size = 12
	panel.add_theme_stylebox_override("panel", box)
	panel.position = PANEL_POS
	panel.size = PANEL_SIZE
	add_child(panel)
	CodexStyle.label(panel, "GOLPES & CONTROLES", Vector2(16, 10), 17, CodexStyle.PAPER, 400, true)
	var lvl := CodexStyle.label(panel, "Arma Nv. %d / %d" % [Progression.weapon_level, Progression.MAX_WEAPON_LEVEL], Vector2(380, 16), 10, CodexStyle.GOLD, 184)
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(16, 40)
	_scroll.size = Vector2(PANEL_SIZE.x - 32, PANEL_SIZE.y - 84)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.focus_mode = Control.FOCUS_NONE
	panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_fill()
	var hint := CodexStyle.label(panel, "W/S · setas · analógico rolam        Esc / B fecham", Vector2(16, PANEL_SIZE.y - 30), 8, CodexStyle.MUTED, 380)
	hint.position.y = PANEL_SIZE.y - 26
	_back = CodexStyle.button(panel, "Voltar", Vector2(PANEL_SIZE.x - 16 - 110, PANEL_SIZE.y - 38), 110, close)
	_back.grab_focus()


# --- conteúdo ---------------------------------------------------------------

func _fill() -> void:
	var ch: CharacterData = GameManager.selected_character
	if ch == null and GameContent.characters.size() > 0:
		ch = GameContent.characters[0]
	var gamepad := Input.get_connected_joypads().size() > 0
	_header("GOLPES DO CAJADO", "sequência  (teclado · controle)" if not gamepad else "sequência  (controle · teclado)")
	if ch != null:
		var ground: Array = []
		var air: Array = []
		for c in ch.combos:
			if c.air:
				air.append(c)
			else:
				ground.append(c)
		ground.sort_custom(func(a, b): return a.required_weapon_level < b.required_weapon_level)
		air.sort_custom(func(a, b): return a.required_weapon_level < b.required_weapon_level)
		for c in ground:
			_combo_row(c, gamepad)
		_sub("NO AR  (durante o salto)")
		for c in air:
			_combo_row(c, gamepad)
	_gap()
	_header("MAGIA INATA", "O  ·  RT")
	if ch != null:
		var innate: SkillData = GameContent.innate_skill(ch)
		if innate != null:
			_row("%s" % innate.display_name, "%d Éter" % innate.mana_cost, innate.description, CodexStyle.PAPER, innate.color)
	_gap()
	_header("OS SETE ANÉIS", "U  ·  RB   (trocar: Q/E, 1–7 · LT)")
	if ch != null:
		var rs: Array = GameContent.ring_skills(ch)
		for i in rs.size():
			var sk: SkillData = rs[i]
			var owned: bool = Progression.rings.has(sk.ring)
			var usable: bool = Progression.ring_usable(sk.ring)
			var archon := _archon_name(sk.ring, i)
			if not owned:
				_row(sk.display_name, "Anel %d" % (i + 1), "Trancado — vença %s" % archon, LOCKED, LOCKED)
			elif not usable:
				_row(sk.display_name, "Anel %d" % (i + 1), "Roubado pelo Rei — recupere o caco no Centro", Color(0.6, 0.55, 0.65), Color(0.5, 0.45, 0.55))
			else:
				_row(sk.display_name, "%d Éter" % sk.mana_cost, "%s  (%s)" % [sk.description, archon], CodexStyle.PAPER, sk.color)
	_gap()
	_header("CONTROLES", "teclado  ·  Xbox  ·  DualShock")
	for c in [
		["Mover", "A / D  (setas)", "analógico esq. / D-pad", "idem"],
		["Pular", "Espaço", "A", "✕"],
		["Golpe leve", "J", "X", "□"],
		["Golpe forte", "K", "Y", "△"],
		["Esquiva (invulnerável)", "L / Shift", "B", "○"],
		["Bloquear / Aparar", "I  (segurar / no tempo)", "LB", "L1"],
		["Anel equipado", "U", "RB", "R1"],
		["Esfera Solar", "O", "RT", "R2"],
		["Trocar Anel", "Q / E  ·  1–7", "LT / Back", "L2 / Share"],
		["Pausa", "Esc / P", "Start", "Options"],
	]:
		_control_row(c[0], c[1], c[2], c[3])
	_gap()
	_note("Telegrafo AMARELO = dá pra aparar (atordoa).   VERMELHO = imparável — só a esquiva salva.")
	_note("Escudeiros só caem com golpe forte ou magia.   A esquiva arrebenta a Corrente da Lei.")


func _combo_row(c: ComboData, gamepad: bool) -> void:
	var unlocked := c.required_weapon_level <= Progression.weapon_level
	var kb := _seq(c.sequence, ["J", "K"])
	var pad := _seq(c.sequence, ["X", "Y"])
	var seq := "%s   ·   %s" % [pad, kb] if gamepad else "%s   ·   %s" % [kb, pad]
	var info := ""
	if not unlocked:
		info = "Arma Nv. %d" % c.required_weapon_level
	else:
		var tags: Array = []
		if c.launcher:
			tags.append("lançador")
		if c.hits > 1:
			tags.append("%d golpes" % c.hits)
		if c.aoe_radius > 0.0:
			tags.append("área")
		tags.append("dano %d" % c.damage)
		info = "  ·  ".join(tags)
	var col := CodexStyle.PAPER if unlocked else LOCKED
	_row(c.display_name, seq, info, col, CodexStyle.GOLD if unlocked else LOCKED)


func _seq(sequence: Array, names: Array) -> String:
	var parts: Array = []
	for s in sequence:
		parts.append(names[1] if s == "heavy" else names[0])
	return " ".join(parts)


func _archon_name(ring: String, index: int) -> String:
	for b in Bestiary.bosses:
		if b.id == ring:
			return b.name
	if index < RunManager.EON_NAMES.size():
		return "o Arconte de %s" % RunManager.EON_NAMES[index]
	return "o Arconte"


# --- linhas -----------------------------------------------------------------

func _header(text: String, right: String) -> void:
	var h := HBoxContainer.new()
	var a := Label.new()
	a.text = text
	a.add_theme_font_size_override("font_size", 10)
	a.add_theme_color_override("font_color", CodexStyle.GOLD)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := Label.new()
	b.text = right
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_color_override("font_color", CodexStyle.MUTED)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	_list.add_child(h)
	var sep := ColorRect.new()
	sep.color = Color(CodexStyle.GOLD, 0.35)
	sep.custom_minimum_size = Vector2(0, 1)
	_list.add_child(sep)


func _sub(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", CodexStyle.MUTED)
	_list.add_child(l)


## Linha padrão: nome (170) · sequência/custo (150) · info (resto).
func _row(name: String, mid: String, info: String, col: Color, mid_col: Color) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var a := Label.new()
	a.text = name
	a.custom_minimum_size.x = 150
	a.add_theme_font_size_override("font_size", 10)
	a.add_theme_color_override("font_color", col)
	h.add_child(a)
	var b := Label.new()
	b.text = mid
	b.custom_minimum_size.x = 150
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", mid_col)
	h.add_child(b)
	var c := Label.new()
	c.text = info
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.clip_text = true
	c.add_theme_font_size_override("font_size", 9)
	c.add_theme_color_override("font_color", Color(col, minf(col.a, 0.8)))
	h.add_child(c)
	_list.add_child(h)


func _control_row(action: String, kb: String, xbox: String, ds: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for pair in [[action, 150, CodexStyle.PAPER], [kb, 150, CodexStyle.GOLD], [xbox, 130, CodexStyle.PAPER], [ds, 0, CodexStyle.MUTED]]:
		var l := Label.new()
		l.text = pair[0]
		l.custom_minimum_size.x = pair[1]
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", pair[2])
		if pair[1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
	_list.add_child(h)


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", CodexStyle.MUTED)
	_list.add_child(l)


func _gap() -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 8)
	_list.add_child(c)


# --- entrada ----------------------------------------------------------------

func _process(delta: float) -> void:
	var dir := 0.0
	if Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down"):
		dir += 1.0
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"):
		dir -= 1.0
	if dir != 0.0:
		_scroll.scroll_vertical = int(_scroll.scroll_vertical + dir * SCROLL_SPEED * delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()   # o foco fica no "Voltar"; a rolagem é nossa
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll.scroll_vertical += 40
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll.scroll_vertical -= 40


func close() -> void:
	Audio.play_sfx("ui_back")
	closed.emit()
	queue_free()
