extends Control
## TELA DE MAPA (Onda 6, diretor de mapa) — aparece entre duas telas do Éon
## quando a próxima camada tem mais de uma saída. Mostra o GRAFO do Éon (nós
## com ícone por tipo), a rota já feita, a recompensa do nó que acabou de cair e
## as saídas à escolha. Setas / D-pad / analógico escolhem; confirmar segue
## (RunManager.choose_node carrega a tela). Mouse também: clicar no nó.
##
## Fora de um run (captura com tools/Shot.tscn, vitrine) ela monta uma PRÉVIA:
## Éon de GNOSIS_MAP_EON (padrão 1), rota padrão até a camada GNOSIS_MAP_LAYER
## (padrão 3) — nada no RunManager é tocado.

const GRAPH_X0 := 52.0            # x da camada 0
const GRAPH_DX := 67.0            # passo entre camadas
const ROW_Y := [112.0, 160.0, 208.0]
const NODE_R := 13.0
const SECRET_COL := Color("b48ce0")

## Cor de cada tipo de nó (borda e ícone).
const KIND_COL := {
	"arrival": Color("c5a56a"), "combat": Color("e0743a"), "hazard": Color("c9475b"),
	"platform": Color("4f9ad0"), "sanctuary": Color("ecd498"), "challenge": Color("f08a8f"),
	"secret": Color("b48ce0"), "trial": Color("c5a56a"), "antechamber": Color("c5a56a"),
	"archon": Color("ecd498"),
}

var _eon: int = 0
var _layer: int = 1               # camada que está sendo escolhida
var _from: String = ""            # nó vencido (origem das saídas)
var _options: Array = []          # ids das saídas (inclui trancadas)
var _sel: int = 0                 # índice em _options
var _visited: Array = []          # rota do Éon (ids)
var _reward: Dictionary = {}      # recompensa do nó vencido
var _preview: bool = false
var _done: bool = false
var _t: float = 0.0
var _graph: Dictionary = {}

var _canvas: Control
var _title: Label
var _sub: Label
var _sel_name: Label
var _sel_desc: Label
var _sel_reward: Label
var _sel_req: Label
var _won: Label


func _ready() -> void:
	CodexStyle.apply_existing(self, true)
	_load_state()
	_graph = EonMap.graph(_eon)
	_build_ui()
	_pick_first()
	_refresh_info()
	CodexStyle.pop_in(_canvas, "ui_open", 0.98)


## Estado: do RunManager (run ativo) ou uma prévia montada aqui.
func _load_state() -> void:
	if RunManager.run_active and RunManager.current_screen >= RunManager.FIRST_EON_SCREEN \
			and RunManager.current_screen <= RunManager.LAST_ARCHON_SCREEN:
		var s := RunManager.current_screen
		_eon = RunManager.eon_index(s)
		_layer = RunManager.eon_offset(s)
		_from = RunManager.last_node
		_options = RunManager.options_after(_from, s)
		_visited = RunManager.path_in_eon(_eon)
		_reward = RunManager.last_reward
		return
	_preview = true
	var ev := OS.get_environment("GNOSIS_MAP_EON")
	_eon = clampi(ev.to_int() if ev != "" else 1, 0, 6)
	var lv := OS.get_environment("GNOSIS_MAP_LAYER")
	_layer = clampi(lv.to_int() if lv != "" else 3, 1, EonMap.LAYERS - 1)
	# Rota de exemplo: a trilha alta até onde der (mostra cruzamentos e trancas).
	_visited = []
	var cur := EonMap.default_id(_eon, 0)
	_visited.append(cur)
	for l in range(1, _layer):
		var nxt: Array = EonMap.find(cur).next
		var pick: String = String(nxt[0])
		for id in nxt:
			if String(EonMap.find(String(id)).requires) == "":
				pick = String(id)
				break
		cur = pick
		_visited.append(cur)
	_from = cur
	_options = (EonMap.find(cur).next as Array).duplicate()
	_reward = EonMap.find(cur).get("reward", {})


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = CodexStyle.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	_title = CodexStyle.label(self, RunManager.EON_NAMES[_eon].to_upper(), Vector2(22, 10), 22, CodexStyle.GOLD_HI, 400, true)
	_sub = CodexStyle.label(self, _subtitle(), Vector2(22, 40), 11, CodexStyle.MUTED, 420)
	_sub.add_theme_font_override("font", CodexStyle.italic())
	_won = CodexStyle.label(self, "", Vector2(330, 14), 11, CodexStyle.SPARK, 290)
	_won.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_won.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _reward.is_empty():
		var kind := String(EonMap.find(_from).get("kind", ""))
		_won.text = "%s — %s" % [I18n.t(EonMap.kind_name(kind)), EonMap.reward_text(_reward)]

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.draw.connect(_draw_graph)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)

	# Painel do nó selecionado (embaixo).
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 246)
	panel.size = Vector2(596, 84)
	panel.add_theme_stylebox_override("panel", CodexStyle.panel_frame(0.92))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_sel_name = CodexStyle.label(self, "", Vector2(36, 254), 15, CodexStyle.GOLD_HI, 360, true)
	_sel_reward = CodexStyle.label(self, "", Vector2(330, 258), 11, CodexStyle.SPARK, 276)
	_sel_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sel_desc = CodexStyle.label(self, "", Vector2(36, 278), 12, CodexStyle.PAPER, 568)
	_sel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sel_req = CodexStyle.label(self, "", Vector2(36, 297), 11, SECRET_COL, 568)
	_sel_req.add_theme_font_override("font", CodexStyle.italic())

	# O grafo (e a legenda, no pé do painel) desenha POR CIMA do painel.
	move_child(_canvas, get_child_count() - 1)
	var hint := InputGlyphs.Hint.new()
	hint.pairs = [["@nav", "escolhem o caminho"], ["ui_accept", "segue"]]
	hint.position = Vector2(22, 338)
	hint.size = Vector2(596, 16)
	hint.align = 0
	add_child(hint)


func _subtitle() -> String:
	if _preview:
		return I18n.t("Prévia do mapa — o caminho do Éon")
	return I18n.t("O caminho se divide. Escolha por onde subir.")


func _process(delta: float) -> void:
	_t += delta
	if _canvas != null:
		_canvas.queue_redraw()


# --- seleção ------------------------------------------------------------------

## Opções selecionáveis em ordem de trilha (alta → baixa).
func _ordered() -> Array:
	var o := _options.duplicate()
	o.sort_custom(func(a, b): return int(EonMap.find(String(a)).row) < int(EonMap.find(String(b)).row))
	return o


func _available(id: String) -> bool:
	if _preview:
		return String(EonMap.find(id).requires) == ""
	return RunManager.node_available(id)


func _pick_first() -> void:
	var o := _ordered()
	_options = o
	_sel = 0
	# Começa no nó do meio (ou no primeiro livre).
	for i in o.size():
		if int(EonMap.find(String(o[i])).row) == 1 and _available(String(o[i])):
			_sel = i
			return
	for i in o.size():
		if _available(String(o[i])):
			_sel = i
			return


func _move(dir: int) -> void:
	if _options.is_empty():
		return
	_sel = (_sel + dir + _options.size()) % _options.size()
	Audio.play_sfx("ui_move")
	_refresh_info()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_move(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_move(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_confirm()
		get_viewport().set_input_as_handled()


func _on_canvas_input(event: InputEvent) -> void:
	if _done or not (event is InputEventMouseButton) or not event.pressed:
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	for i in _options.size():
		if _node_pos(String(_options[i])).distance_to(event.position) <= NODE_R + 6.0:
			if _sel == i:
				_confirm()
			else:
				_sel = i
				Audio.play_sfx("ui_move")
				_refresh_info()
			return


func _confirm() -> void:
	if _options.is_empty():
		return
	var id := String(_options[_sel])
	if not _available(id):
		Audio.play_sfx("ui_back")
		_sel_req.modulate = Color(1.6, 1.6, 1.6)
		create_tween().tween_property(_sel_req, "modulate", Color.WHITE, 0.35)
		return
	if _preview:
		Audio.play_sfx("ui_confirm")
		return
	_done = true
	Audio.play_sfx("ui_confirm")
	if not RunManager.choose_node(id):
		_done = false


func _refresh_info() -> void:
	if _options.is_empty():
		return
	var id := String(_options[_sel])
	var n := EonMap.find(id)
	var kind := String(n.kind)
	_sel_name.text = EonMap.kind_name(kind)
	_sel_desc.text = EonMap.kind_desc(kind)
	var rw: Dictionary = n.get("reward", {})
	_sel_reward.text = (I18n.t("Recompensa: %s") % EonMap.reward_text(rw)) if not rw.is_empty() else ""
	_sel_req.add_theme_color_override("font_color", SECRET_COL if String(n.requires) != "" else CodexStyle.MUTED)
	if not _available(id):
		_sel_req.text = "Selado: exige o pulo duplo. Quem dá asas não luta."
	elif String(n.requires) == "double_jump":
		_sel_req.text = "O pulo duplo abre esta passagem."
	else:
		var st: Dictionary = Gnosis.stela_for_screen(int(n.screen))
		_sel_req.text = "Há uma Estela nesta camada, em qualquer caminho." if not st.is_empty() else ""


# --- desenho do grafo -------------------------------------------------------------

func _node_pos(id: String) -> Vector2:
	var n := EonMap.find(id)
	return Vector2(GRAPH_X0 + float(n.layer) * GRAPH_DX, float(ROW_Y[int(n.row)]))


func _draw_graph() -> void:
	var c := _canvas
	var nodes: Dictionary = _graph.nodes
	var font: Font = CodexStyle.body()
	var on_path := {}
	for id in _visited:
		on_path[String(id)] = true
	# 1) arestas: apagadas · rota feita (ouro) · saídas atuais (pulsando)
	var pulse := 0.55 + 0.45 * sin(_t * 4.0)
	for id in nodes:
		var a := _node_pos(String(id))
		for nid in nodes[id].next:
			var b := _node_pos(String(nid))
			var col := Color(CodexStyle.GOLD_LO, 0.55)
			var w := 1.5
			if on_path.has(String(id)) and on_path.has(String(nid)):
				col = CodexStyle.GOLD
				w = 3.0
			elif String(id) == _from and _options.has(nid):
				var sel := _options.find(nid) == _sel
				col = Color(CodexStyle.GOLD_HI, (0.95 if sel else 0.45) * pulse + 0.2)
				w = 3.0 if sel else 2.0
			c.draw_line(a + (b - a).normalized() * NODE_R, b - (b - a).normalized() * NODE_R, col, w, true)
	# 2) Estela da camada (marca acima da coluna) e nº da camada
	for layer in EonMap.LAYERS:
		var x := GRAPH_X0 + float(layer) * GRAPH_DX
		var sc := EonMap.screen_of(_eon, layer)
		if not Gnosis.stela_for_screen(sc).is_empty():
			_icon_stela(c, Vector2(x, 68.0), CodexStyle.MUTED)
	_draw_legend(c, font)
	# 3) nós
	for id in nodes:
		var n: Dictionary = nodes[id]
		var p := _node_pos(String(id))
		var kind := String(n.kind)
		var kc: Color = KIND_COL.get(kind, CodexStyle.GOLD)
		var is_opt := _options.has(id)
		var is_sel := is_opt and _options.find(id) == _sel
		var locked := not _available(String(id)) and String(n.requires) != ""
		var visited := on_path.has(String(id))
		var past := int(n.layer) < _layer and not visited
		var r := NODE_R * (1.25 if is_sel else 1.0)
		var fill := CodexStyle.NIGHT
		var alpha := 1.0
		if past:
			alpha = 0.35
		elif not is_opt and not visited and int(n.layer) > _layer:
			alpha = 0.7
		if visited:
			fill = Color(kc, 0.35).blend(Color(CodexStyle.INK, 0.4))
		if is_sel:
			c.draw_circle(p, r + 6.0, Color(CodexStyle.GOLD_HI, 0.18 + 0.12 * pulse))
		c.draw_circle(p, r, Color(fill, alpha))
		var ring := kc
		if locked:
			ring = Color(SECRET_COL, 0.5)
		c.draw_arc(p, r, 0.0, TAU, 32, Color(ring, alpha), 2.5 if (is_opt or visited) else 1.5, true)
		if is_opt and not is_sel:
			c.draw_arc(p, r + 3.0, 0.0, TAU, 32, Color(CodexStyle.GOLD_HI, 0.35 * pulse), 1.0, true)
		_icon(c, kind, p, Color(kc, alpha) if not locked else Color(SECRET_COL, 0.55))
		if locked:
			_icon_lock(c, p + Vector2(9, 9), Color(CodexStyle.PAPER, 0.85))
		if String(id) == _from:
			# Onde a Sophia está: uma faísca sobre o nó vencido.
			CodexStyle.draw_spark(c, p + Vector2(0, -r - 8.0), 4.0 + pulse, CodexStyle.SPARK)
		if is_opt:
			var nm := I18n.t(EonMap.kind_name(kind))
			var fs := 9
			var tw := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			c.draw_string(font, p + Vector2(-tw * 0.5, r + 13.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				CodexStyle.GOLD_HI if is_sel else Color(CodexStyle.PAPER, 0.75))


## Legenda no pé do painel: ícone + nome de cada tipo de caminho e a Estela.
const LEGEND := ["combat", "hazard", "platform", "sanctuary", "challenge", "secret"]


func _draw_legend(c: CanvasItem, font: Font) -> void:
	var x := 40.0
	var y := 320.0
	for kind in LEGEND:
		var kc: Color = KIND_COL.get(kind, CodexStyle.GOLD)
		c.draw_circle(Vector2(x, y), 7.0, CodexStyle.NIGHT)
		_icon(c, kind, Vector2(x, y), kc)
		var nm := I18n.t(EonMap.kind_name(kind))
		c.draw_string(font, Vector2(x + 11.0, y + 3.5), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(CodexStyle.PAPER, 0.7))
		x += 26.0 + font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	_icon_stela(c, Vector2(x, y), CodexStyle.MUTED)
	c.draw_string(font, Vector2(x + 9.0, y + 3.5), I18n.t("Estela"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(CodexStyle.PAPER, 0.7))


# --- ícones (desenhados por código, ~10 px) --------------------------------------

func _icon(c: CanvasItem, kind: String, p: Vector2, col: Color) -> void:
	match kind:
		"arrival":       # arco de porta
			c.draw_arc(p + Vector2(0, -1), 5.0, PI, TAU, 12, col, 1.6, true)
			c.draw_line(p + Vector2(-5, -1), p + Vector2(-5, 6), col, 1.6)
			c.draw_line(p + Vector2(5, -1), p + Vector2(5, 6), col, 1.6)
		"combat":        # espadas cruzadas
			c.draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), col, 1.8, true)
			c.draw_line(p + Vector2(6, 6), p + Vector2(-6, -6), col, 1.8, true)
			c.draw_line(p + Vector2(-5, 2), p + Vector2(-2, 5), col, 1.6)
			c.draw_line(p + Vector2(5, 2), p + Vector2(2, 5), col, 1.6)
		"hazard":        # espinhos
			for i in 3:
				var x := -6.0 + 6.0 * float(i)
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(x - 3, 6), p + Vector2(x, -5), p + Vector2(x + 3, 6)]), col)
		"platform":      # degraus
			c.draw_polyline(PackedVector2Array([p + Vector2(-7, 6), p + Vector2(-3, 6), p + Vector2(-3, 1),
				p + Vector2(1, 1), p + Vector2(1, -4), p + Vector2(6, -4)]), col, 1.8, true)
			c.draw_line(p + Vector2(4, -7), p + Vector2(6, -4), col, 1.4)
		"sanctuary":     # chama
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(4, 0), p + Vector2(3, 5),
				p + Vector2(0, 6), p + Vector2(-3, 5), p + Vector2(-4, 0)]), col)
			c.draw_circle(p + Vector2(0, 3), 1.6, CodexStyle.INK)
		"challenge":     # caveira (a Arena)
			c.draw_circle(p + Vector2(0, -1), 5.5, col)
			c.draw_rect(Rect2(p + Vector2(-3, 3), Vector2(6, 4)), col)
			c.draw_circle(p + Vector2(-2, -1), 1.5, CodexStyle.INK)
			c.draw_circle(p + Vector2(2, -1), 1.5, CodexStyle.INK)
		"secret":        # olho
			c.draw_arc(p + Vector2(0, 4), 7.0, PI + 0.6, TAU - 0.6, 12, col, 1.5, true)
			c.draw_arc(p + Vector2(0, -4), 7.0, 0.6, PI - 0.6, 12, col, 1.5, true)
			c.draw_circle(p, 2.2, col)
		"trial":         # estrela do Campeão
			var pts := PackedVector2Array()
			for i in 10:
				var rr := 7.0 if i % 2 == 0 else 3.0
				var ang := -PI / 2.0 + float(i) * PI / 5.0
				pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
			c.draw_colored_polygon(pts, col)
		"antechamber":   # portal de colunas
			c.draw_rect(Rect2(p + Vector2(-6, -5), Vector2(12, 2)), col)
			c.draw_rect(Rect2(p + Vector2(-5, -3), Vector2(2, 9)), col)
			c.draw_rect(Rect2(p + Vector2(3, -3), Vector2(2, 9)), col)
		"archon":        # coroa
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 5), p + Vector2(-7, -4), p + Vector2(-3, 0),
				p + Vector2(0, -6), p + Vector2(3, 0), p + Vector2(7, -4), p + Vector2(7, 5)]), col)
		_:
			c.draw_circle(p, 3.0, col)


func _icon_lock(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_rect(Rect2(p + Vector2(-3.5, -1), Vector2(7, 6)), col)
	c.draw_arc(p + Vector2(0, -1), 2.6, PI, TAU, 8, col, 1.4)


func _icon_stela(c: CanvasItem, p: Vector2, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 6), p + Vector2(-4, -3), p + Vector2(0, -7),
		p + Vector2(4, -3), p + Vector2(4, 6)]), Color(col, 0.8))
	c.draw_line(p + Vector2(-2, -1), p + Vector2(2, -1), CodexStyle.INK, 1.0)
	c.draw_line(p + Vector2(-2, 2), p + Vector2(2, 2), CodexStyle.INK, 1.0)
