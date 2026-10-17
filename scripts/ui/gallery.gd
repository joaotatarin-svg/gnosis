extends Control
## BESTIÁRIO (backlog #35/#26): à esquerda a grade de fichas (o roster real do
## jogo, desenhado pelo motor de arte), à direita a FICHA da selecionada — nome,
## categoria, 2 linhas de lore e 1 dica tática (`BestiaryLore`). Só abre o que
## já foi ENCONTRADO na campanha; o resto aparece como silhueta "???".
## Setas/D-pad/analógico andam (a grade rola sozinha); Esc/B volta à Galeria.

const COLS := 4
const CARD := Vector2(74, 86)
const GAP := 5
const GRID_POS := Vector2(12, 54)
const GRID_SIZE := Vector2(318, 268)      # 3 linhas inteiras de fichas
const PANEL_X := 342.0
const PANEL_W := 284.0
const NAME_W := 70.0

var entries: Array = []          # [{id, n, p}]
var cards: Array[Button] = []
var _seen: Array[bool] = []
var _detail_art: CharacterArt
var _name: Label
var _cat: Label
var _lore: Label
var _tip_head: Label
var _tip: Label
var _count: Label
var _selected: int = -1


func _ready() -> void:
	var bg = load("res://scripts/fx/codex_sanctum.gd").new()
	bg.menu = true
	bg.medallion = 0.25
	bg.modulate = Color(0.55, 0.55, 0.55)
	add_child(bg)
	_collect()
	_build_header()
	_build_grid()
	_build_panel()
	var foot := InputGlyphs.Hint.new()
	foot.pairs = [["@nav", "navegar"], ["ui_cancel", "voltar"]]
	foot.position = Vector2(12, 332)
	foot.size = Vector2(GRID_SIZE.x, 16)
	foot.font_size = 9
	foot.icon_h = 12.0
	add_child(foot)
	if not cards.is_empty():
		cards[0].grab_focus()
		_show(0)


## Lista na ordem do encontro: Sophia, o Rei, criaturas, guardiões dos Éons,
## Arcontes, aliados e, por último, o que só existe depois da virada.
func _collect() -> void:
	var hero := GameContent.get_character("sophia")
	entries.append({"id": "sophia", "n": "Sophia", "p": Bestiary.player_profile(hero, 3, [])})
	entries.append({"id": "rei", "n": "O Rei", "p": Bestiary.specials[0].profile})
	for t in Bestiary.wave_types:
		entries.append({"id": t.id, "n": t.name, "p": t.profile})
	for b in Bestiary.bosses:
		entries.append({"id": b.id, "n": String(b.name).split(",")[0], "p": b.profile})
	entries.append({"id": "soter", "n": "Soter", "p": Bestiary.soter_profile()})
	entries.append({"id": "velkar", "n": "Velkar", "p": Bestiary.velkar_profile()})
	for s in Bestiary.specials:
		if s.id != "rei":
			entries.append({"id": s.id, "n": String(s.name), "p": s.profile})
	entries.append({"id": Bestiary.demiurge.id, "n": Bestiary.demiurge.name, "p": Bestiary.demiurge.profile})
	for e in entries:
		_seen.append(BestiaryLore.is_seen(String(e.id)))


func _build_header() -> void:
	CodexStyle.label(self, "Bestiário", Vector2(20, 8), 18, CodexStyle.GOLD_HI, 300, true)
	var n := 0
	for s in _seen:
		if s:
			n += 1
	_count = CodexStyle.label(self, "Encontrados  %d / %d" % [n, entries.size()], Vector2(20, 32), 9, CodexStyle.MUTED, 300)
	_count.add_theme_font_override("font", CodexStyle.italic())
	var back := CodexStyle.button(self, "Voltar", Vector2(541, 12), 80, _leave, false, "ui_back")
	back.focus_mode = Control.FOCUS_NONE        # o foco fica na grade; Esc/B voltam
	CodexStyle.rule(self, Vector2(0, 46), 640, Color(CodexStyle.GOLD, 0.5))


func _build_grid() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = GRID_POS
	scroll.size = GRID_SIZE
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	scroll.add_child(grid)
	for i in entries.size():
		var b := Button.new()
		b.custom_minimum_size = CARD
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("normal", _card_frame())
		b.focus_entered.connect(_show.bind(i))
		b.mouse_entered.connect(func(): b.grab_focus())
		CodexStyle._wire(b, "")
		grid.add_child(b)
		cards.append(b)
		var art := _make_art(entries[i].p, 40.0)
		art.position = _art_pos(art, entries[i].p, Vector2(CARD.x * 0.5, 58.0))
		if not _seen[i]:
			art.modulate = Color(0.0, 0.0, 0.0, 0.8)
			art.set_process(false)
		b.add_child(art)
		var l := Label.new()
		l.text = _fit_name(String(entries[i].n), NAME_W, 8) if _seen[i] else "???"
		l.position = Vector2(2, 62)
		l.size = Vector2(CARD.x - 4, 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.max_lines_visible = 2
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_constant_override("line_spacing", -2)
		l.add_theme_color_override("font_color", CodexStyle.PAPER if _seen[i] else CodexStyle.MUTED)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		b.set_meta("name_label", l)


## Moldura leve da ficha na grade (o foco do tema acende por cima).
func _card_frame() -> StyleBox:
	var f := CodexStyle.panel_frame(0.5)
	f.marks = CodexFrame.Marks.NONE
	f.border = Color(CodexStyle.GOLD, 0.3)
	f.inner = Color(0, 0, 0, 0)
	f.shadow = 0.0
	return f


func _build_panel() -> void:
	var frame := Panel.new()
	frame.position = Vector2(PANEL_X - 6, 54)
	frame.size = Vector2(PANEL_W + 12, GRID_SIZE.y)
	frame.add_theme_stylebox_override("panel", CodexStyle.panel_frame(0.82))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_name = CodexStyle.label(self, "", Vector2(PANEL_X, 156), 16, CodexStyle.PAPER, PANEL_W, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cat = CodexStyle.label(self, "", Vector2(PANEL_X, 179), 8, CodexStyle.GOLD, PANEL_W, true)
	_cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CodexStyle.rule(self, Vector2(PANEL_X + 52, 193), PANEL_W - 104, Color(CodexStyle.GOLD, 0.6))
	_lore = CodexStyle.wrap_label(CodexStyle.label(self, "", Vector2(PANEL_X + 6, 200), 11, CodexStyle.MUTED, PANEL_W - 12), PANEL_W - 12)
	_lore.add_theme_font_override("font", CodexStyle.italic())
	_lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_head = CodexStyle.label(self, "DICA", Vector2(PANEL_X, 262), 7, CodexStyle.GOLD, PANEL_W, true)
	_tip_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip = CodexStyle.wrap_label(CodexStyle.label(self, "", Vector2(PANEL_X + 6, 274), 11, CodexStyle.PAPER, PANEL_W - 12), PANEL_W - 12)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Ficha da entrada `i` (chamada no foco).
func _show(i: int) -> void:
	if i == _selected or i < 0 or i >= entries.size():
		return
	_selected = i
	var e: Dictionary = entries[i]
	var id := String(e.id)
	if _detail_art != null:
		_detail_art.queue_free()
	_detail_art = _make_art(e.p, 88.0)
	_detail_art.position = _art_pos(_detail_art, e.p, Vector2(PANEL_X + PANEL_W * 0.5, 150.0))
	add_child(_detail_art)
	if not _seen[i]:
		_detail_art.modulate = Color(0.0, 0.0, 0.0, 0.85)
		_detail_art.set_process(false)
		_name.text = "???"
		_cat.text = "AINDA NÃO ENCONTRADO"
		_lore.text = "Continue a subida."
		_tip_head.visible = false
		_tip.text = ""
		return
	_name.text = String(e.n)
	_cat.text = BestiaryLore.category(id).to_upper()
	_lore.text = "\n".join(BestiaryLore.lore(id))
	var tip := BestiaryLore.tip(id)
	_tip_head.visible = tip != ""
	_tip.text = tip


func _make_art(p: ArtProfile, height_px: float) -> CharacterArt:
	var art := CharacterArt.new()
	art.set_profile(p)
	var hgt: float = p.height
	var sc: float = height_px / (190.0 if art.painted.get("sheet", "") == "yaldabaoth" else hgt * 1.3)
	art.scale = Vector2(sc, sc)
	return art


## Posição do nó da arte para os PÉS ficarem em `feet` (mesma conta do Ateliê).
func _art_pos(art: CharacterArt, p: ArtProfile, feet: Vector2) -> Vector2:
	return Vector2(feet.x, feet.y - 24.0 * p.height / 44.0 * art.scale.y)


## Nome que cabe em `width` px: uma linha se couber; senão quebra no espaço que
## deixa as duas linhas mais parelhas (medido na fonte real — QA L2).
func _fit_name(text: String, width: float, fs: int = 9) -> String:
	text = I18n.t(text)      # i18n: quebra o nome EXIBIDO (o Label não retraduz o inglês)
	var font: Font = CodexStyle.body()
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return text
	var best := text
	var best_w := INF
	var words := text.split(" ")
	for k in range(1, words.size()):
		var a := " ".join(words.slice(0, k))
		var b := " ".join(words.slice(k))
		var w := maxf(font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		if w < best_w:
			best_w = w
			best = a + "\n" + b
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		_leave()


## Volta para a Galeria (de onde o Bestiário é aberto) — botão e Esc/B iguais.
func _leave() -> void:
	SceneManager.change_scene("res://scenes/ui/CharacterAtelier.tscn")
