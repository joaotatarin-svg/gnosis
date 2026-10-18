extends Control
## Menu principal de versão final. Fundo = a ilustração do menu (Onda 3,
## assets/menu/menu_bg.jpg: a Sophia de costas à direita, numa ponte em ruínas,
## olhando a cidade e os Anéis no céu; metade esquerda escura e calma), viva:
## deriva lenta + poeira de luz subindo. À esquerda o logotipo e as ações, numa
## sombra em degradê para o contraste. Sem a ilustração, volta a pintura do
## Limiar com a Sophia desenhada (fallback antigo). Ações, por importância:
## Continuar (se houver checkpoint) · Nova campanha · Provação (treino de 3
## encontros; com Arcontes vencidos, escolhe-se contra quem) · Galeria &
## Bestiário | Crônicas · Opções | Créditos | Sair.
## Navegável por teclado e controle (foco = moldura acesa com losangos).

const COL_X := 34.0
const COL_W := 240.0
const ROW_PITCH := 30.0
const MENU_BG := "res://assets/menu/menu_bg.jpg"
## Ilustração 1536×1024 desenhada a 680×453 (sobra p/ a deriva); topo em −44
## deixa os Anéis cortados no alto e a Sophia inteira na ponte.
const BG_SIZE := Vector2(680, 453)
const BG_POS_A := Vector2(-28, -44)
const BG_POS_B := Vector2(-12, -34)

var _first_focus: Button
var _painting: TextureRect
var _buttons: Array = []
var _title_items: Array = []


func _ready() -> void:
	CodexSession.leave_demo()
	EndScreen.ensure_demo_hook()
	RunManager.end_run()
	Progression.reset_run()
	GameManager.set_state(GameManager.State.MENU)
	_build_backdrop()
	_build_title()
	_build_actions()
	_build_notice()
	CodexStyle.stagger_in(_title_items, -10.0, 0.07, 0.05)
	CodexStyle.stagger_in(_buttons, -16.0, 0.045, 0.25)
	if _first_focus != null:
		_first_focus.grab_focus()


func _build_backdrop() -> void:
	if ResourceLoader.exists(MENU_BG):
		_build_illustrated()
		return
	_build_legacy_backdrop()


## Fundo novo: a ilustração inteira na tela, em deriva lenta, com poeira de luz
## sobre a metade direita e a sombra da coluna de botões à esquerda.
func _build_illustrated() -> void:
	var bg := ColorRect.new()
	bg.color = CodexStyle.INK_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_painting = TextureRect.new()
	_painting.texture = load(MENU_BG)
	# expand_mode ANTES do size: senão o tamanho mínimo (a textura, 1536×1024) vence.
	_painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_painting.stretch_mode = TextureRect.STRETCH_SCALE
	_painting.position = BG_POS_A
	_painting.size = BG_SIZE
	_painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_painting)
	# Deriva lenta (parallax "respirando"), em laço: 16 px em 18 s.
	var drift := create_tween().set_loops()
	drift.tween_property(_painting, "position", BG_POS_B, 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(_painting, "position", BG_POS_A, 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var motes := CodexStyle.Motes.new()
	motes.area = Rect2(230, 0, 410, 360)
	motes.count = 36
	add_child(motes)
	# Sombra da coluna de botões: escura atrás do logotipo/botões, some antes da cidade.
	var shade := Polygon2D.new()
	shade.polygon = PackedVector2Array([Vector2(0, 0), Vector2(300, 0), Vector2(380, 0), Vector2(380, 360), Vector2(300, 360), Vector2(0, 360)])
	var dark := Color(0.024, 0.05, 0.07, 0.78)
	var mid := Color(0.024, 0.05, 0.07, 0.55)
	var clear := Color(0.024, 0.05, 0.07, 0.0)
	shade.vertex_colors = PackedColorArray([dark, mid, clear, clear, mid, dark])
	add_child(shade)
	# Pé da tela um pouco mais escuro (a ponte vira chão, não compete com os botões).
	var foot := Polygon2D.new()
	foot.polygon = PackedVector2Array([Vector2(0, 300), Vector2(640, 300), Vector2(640, 360), Vector2(0, 360)])
	foot.vertex_colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.01, 0.02, 0.03, 0.5), Color(0.01, 0.02, 0.03, 0.5)])
	add_child(foot)


## Fundo antigo (sem a ilustração do menu): pintura do Limiar + Sophia desenhada.
func _build_legacy_backdrop() -> void:
	var backdrop = load("res://scripts/fx/codex_sanctum.gd").new()
	backdrop.menu = true
	add_child(backdrop)
	_painting = TextureRect.new()
	_painting.texture = PaintedLibrary.background(0)
	_painting.position = Vector2(255, -6)
	_painting.size = Vector2(560, 373)
	_painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_painting.modulate = Color(0.55, 0.65, 0.7)
	_painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_painting)
	var drift := create_tween().set_loops()
	drift.tween_property(_painting, "position", Vector2(240, -2), 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(_painting, "position", Vector2(255, -6), 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var motes := CodexStyle.Motes.new()
	motes.area = Rect2(250, 0, 390, 360)
	motes.count = 40
	add_child(motes)
	var art := CharacterArt.new()
	art.set_profile(Bestiary.player_profile(GameContent.characters[0], 4, []))
	art.position = Vector2(452, 209)
	art.scale = Vector2.ONE * 3.5
	add_child(art)
	var shade := Polygon2D.new()
	shade.polygon = PackedVector2Array([Vector2(0, 0), Vector2(350, 0), Vector2(390, 360), Vector2(0, 360)])
	shade.vertex_colors = PackedColorArray([Color("09141c"), Color(0.035, 0.078, 0.11, 0.85), Color(0.035, 0.078, 0.11, 0), Color("09141c")])
	add_child(shade)
	var nm := CodexStyle.label(self, "SOPHIA", Vector2(372, 306), 11, CodexStyle.GOLD, 160, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CodexStyle.rule(self, Vector2(392, 323), 120, Color(CodexStyle.GOLD, 0.7))
	var tag := CodexStyle.label(self, "a faísca que não se curva", Vector2(352, 330), 11, CodexStyle.MUTED, 200)
	tag.add_theme_font_override("font", CodexStyle.italic())
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_title() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", "1.0"))
	var kicker := CodexStyle.label(self, "O DESPERTAR   ·   v%s" % version, Vector2(COL_X + 2, 22), 8, CodexStyle.MUTED, 300, true)
	var logo := CodexStyle.label(self, "GNOSIS", Vector2(COL_X - 4, 34), 50, CodexStyle.PAPER, 340)
	logo.add_theme_font_override("font", CodexStyle.logo())
	logo.add_theme_color_override("font_shadow_color", Color(CodexStyle.GOLD, 0.22))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 1)
	logo.add_theme_constant_override("shadow_outline_size", 6)
	var rule := CodexStyle.rule(self, Vector2(COL_X, 104), COL_W, Color(CodexStyle.GOLD, 0.85))
	var sub := CodexStyle.label(self, "O DESPERTAR DA FAÍSCA", Vector2(COL_X, 114), 9, CodexStyle.GOLD, COL_W, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tag := CodexStyle.label(self, "Sete Éons. Sete Arcontes. Uma faísca que ainda se lembra.", Vector2(COL_X, 131), 11, CodexStyle.MUTED, COL_W)
	tag.add_theme_font_override("font", CodexStyle.italic())
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_items = [kicker, logo, rule, sub, tag]


func _build_actions() -> void:
	var has_save := RunManager.has_saved_run()
	var y: float = 162.0 if has_save else 177.0
	# --- Continuar (só com checkpoint salvo) ---
	if has_save:
		var sc := clampi(int(RunManager.saved_run.get("screen", 1)), 1, RunManager.MAX_SCREEN)
		var cont := CodexStyle.button(self, "Continuar  ·  %s" % GameManager.screen_title(sc), Vector2(COL_X, y), COL_W, func():
			RunManager.continue_run(), true)
		_first_focus = cont
		_buttons.append(cont)
		y += ROW_PITCH
	# --- Nova campanha ---
	var new_run := CodexStyle.button(self, "Nova campanha", Vector2(COL_X, y), COL_W, _on_new_campaign, not has_save, "")
	_buttons.append(new_run)
	if _first_focus == null:
		_first_focus = new_run
	y += ROW_PITCH
	# --- Provação (o antigo "desafio": 3 encontros, treino) ---
	_buttons.append(CodexStyle.button(self, "Provação  ·  treino de 3 encontros", Vector2(COL_X, y), COL_W, _open_trial))
	y += ROW_PITCH
	# --- Ateliê & Bestiário | Crônicas ---
	var left_w := 140.0
	var right_w := COL_W - left_w - 6.0
	_buttons.append(CodexStyle.button(self, "Galeria & Bestiário", Vector2(COL_X, y), left_w, func():
		SceneManager.change_scene("res://scenes/ui/CharacterAtelier.tscn")))
	_buttons.append(CodexStyle.button(self, "Crônicas", Vector2(COL_X + left_w + 6, y), right_w, _open_chronicles))
	y += ROW_PITCH
	# --- Opções | Créditos | Sair ---
	var w3 := (COL_W - 12.0) / 3.0
	_buttons.append(CodexStyle.button(self, "Opções", Vector2(COL_X, y), w3, func():
		SceneManager.change_scene("res://scenes/ui/OptionsMenu.tscn")))
	_buttons.append(CodexStyle.button(self, "Créditos", Vector2(COL_X + w3 + 6, y), w3, func():
		SceneManager.change_scene("res://scenes/ui/Credits.tscn")))
	_buttons.append(CodexStyle.button(self, "Sair", Vector2(COL_X + (w3 + 6) * 2, y), w3, func(): get_tree().quit(), false, "ui_back"))
	_link_focus()


## Vizinhos explícitos: cima/baixo andam pelas LINHAS (a busca automática do
## Godot pulava colunas na grade 1-1-1-2-3); esquerda/direita, dentro da linha.
func _link_focus() -> void:
	var rows: Array = []
	for b in _buttons:
		var placed := false
		for r in rows:
			if absf(r[0].position.y - b.position.y) < 1.0:
				r.append(b)
				placed = true
		if not placed:
			rows.append([b])
	for ri in rows.size():
		var row: Array = rows[ri]
		var up: Array = rows[ri - 1] if ri > 0 else rows[rows.size() - 1]
		var down: Array = rows[ri + 1] if ri < rows.size() - 1 else rows[0]
		for ci in row.size():
			var b: Button = row[ci]
			b.focus_neighbor_top = b.get_path_to(up[mini(ci, up.size() - 1)])
			b.focus_neighbor_bottom = b.get_path_to(down[mini(ci, down.size() - 1)])
			b.focus_neighbor_left = b.get_path_to(row[ci - 1] if ci > 0 else row[row.size() - 1])
			b.focus_neighbor_right = b.get_path_to(row[(ci + 1) % row.size()])


## Nova campanha: com checkpoint salvo, confirma antes (apaga o progresso do run).
func _on_new_campaign() -> void:
	if not RunManager.has_saved_run():
		Audio.play_sfx("ui_confirm")
		SceneManager.change_scene("res://scenes/ui/PreGame.tscn")
		return
	var sc := clampi(int(RunManager.saved_run.get("screen", 1)), 1, RunManager.MAX_SCREEN)
	CodexStyle.confirm(self, "Começar de novo?",
		"Isso apaga o progresso salvo — %s — e as faíscas e melhorias desta jornada.\nFinais vistos e opções ficam." % GameManager.screen_title(sc),
		"Apagar e começar", func():
			RunManager.saved_run = {}
			SaveManager.save_game()
			SceneManager.change_scene("res://scenes/ui/PreGame.tscn"),
		"Voltar", func():
			if _first_focus != null: _first_focus.grab_focus())


## Provação: o Athoth é o treino de sempre; os outros Arcontes entram na lista
## depois de VENCIDOS na campanha (#26). Só o Athoth → começa direto.
func _open_trial() -> void:
	var open: Array[int] = BestiaryLore.trial_bosses()
	if not open.has(0):
		open.push_front(0)
	if open.size() <= 1:
		Audio.play_sfx("ui_confirm")
		CodexSession.start_demo(0)
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.045, 0.06, 0.8)
	dim.size = Vector2(640, 360)
	layer.add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", CodexStyle.panel_frame(0.98))
	panel.position = Vector2(190, 34)
	panel.size = Vector2(260, 292)
	layer.add_child(panel)
	var t := CodexStyle.label(panel, "Provação", Vector2(20, 14), 15, CodexStyle.GOLD_HI, 220, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := CodexStyle.label(panel, "Escolha o Arconte do 3º encontro", Vector2(20, 36), 10, CodexStyle.MUTED, 220)
	sub.add_theme_font_override("font", CodexStyle.italic())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rows: Array[Button] = []
	for i in Bestiary.bosses.size():
		var ok := open.has(i)
		var nm: String = String(Bestiary.bosses[i].name).split(",")[0] if ok else "? ? ?"
		var b := CodexStyle.button(panel, "%s  ·  %s" % [nm, RunManager.EON_NAMES[i]] if ok else nm, Vector2(30, 58 + i * 29), 200, func():
			layer.queue_free()
			CodexSession.start_demo(i))
		b.disabled = not ok
		b.focus_mode = Control.FOCUS_ALL if ok else Control.FOCUS_NONE
		rows.append(b)
	var foot := InputGlyphs.Hint.new()
	foot.pairs = [["ui_accept", "escolher"], ["ui_cancel", "voltar"]]
	foot.position = Vector2(10, 266)
	foot.size = Vector2(240, 14)
	foot.font_size = 9
	foot.icon_h = 12.0
	panel.add_child(foot)
	var catcher := _TrialCancel.new()
	catcher.on_cancel = func():
		layer.queue_free()
		if _buttons.size() > 2: (_buttons[2] if RunManager.has_saved_run() else _buttons[1]).grab_focus()
	layer.add_child(catcher)
	rows[0].grab_focus()
	CodexStyle.pop_in(panel)


## Esc / B fecham a escolha da Provação.
class _TrialCancel extends Node:
	var on_cancel: Callable
	func _input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			Audio.play_sfx("ui_back")
			if on_cancel.is_valid():
				on_cancel.call()
			queue_free()


## Crônicas (caderno de lore). Se a cena ainda não existir, abre a Galeria.
func _open_chronicles() -> void:
	if ResourceLoader.exists("res://scenes/ui/Chronicles.tscn"):
		SceneManager.change_scene("res://scenes/ui/Chronicles.tscn")
	else:
		SceneManager.change_scene("res://scenes/ui/Gallery.tscn")


## Aviso discreto (save de versão anterior descartado): canto superior direito,
## some sozinho.
func _build_notice() -> void:
	var msg := SaveManager.take_notice()
	if msg.is_empty():
		return
	# Placa escura atrás do aviso (QA2: o texto amarelo ficava direto sobre a
	# pintura do menu) — some junto com ele.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.025, 0.035, 0.78)
	sb.border_color = Color(CodexStyle.GOLD, 0.45)
	sb.border_width_right = 1
	sb.set_corner_radius_all(2)
	plate.add_theme_stylebox_override("panel", sb)
	holder.add_child(plate)
	var l := CodexStyle.wrap_label(CodexStyle.label(holder, msg, Vector2(330, 8), 10, CodexStyle.GOLD_HI, 296), 296)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	var font: Font = l.get_theme_font("font")
	var tsz := font.get_multiline_string_size(I18n.t(l.text), HORIZONTAL_ALIGNMENT_RIGHT, 296.0, 10)   # i18n: mede o texto exibido
	var pw := minf(296.0, tsz.x) + 14.0
	plate.position = Vector2(330.0 + 296.0 - pw + 7.0, 4.0)
	plate.size = Vector2(pw, tsz.y + 8.0)
	var t := create_tween()
	t.tween_interval(8.0)
	t.tween_property(holder, "modulate:a", 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Foco perdido (clique no vazio) → volta pro primeiro botão ao mexer no controle.
	if get_viewport().gui_get_focus_owner() == null and _first_focus != null and (
			event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")):
		_first_focus.grab_focus()
