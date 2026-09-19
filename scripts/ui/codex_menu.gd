extends Control
## Menu principal de versão final. A pintura do Limiar e a Sophia grande à
## direita; à esquerda o título e as ações, em ordem de importância:
## Continuar (se houver checkpoint) · Nova campanha · Provação (treino de 3
## encontros) · Ateliê & Bestiário · Crônicas · Opções · Sair.
## Navegável por teclado e controle (foco visível, borda dourada dupla).

const COL_X := 35.0
const COL_W := 222.0
const ROW_H := 29.0
const ROW_PITCH := 34.0

var _first_focus: Button


func _ready() -> void:
	CodexSession.leave_demo()
	RunManager.end_run()
	Progression.reset_run()
	GameManager.set_state(GameManager.State.MENU)
	_build_backdrop()
	_build_title()
	_build_actions()
	_build_notice()
	if _first_focus != null:
		_first_focus.grab_focus()


func _build_backdrop() -> void:
	var backdrop = load("res://scripts/fx/codex_sanctum.gd").new()
	backdrop.menu = true
	add_child(backdrop)
	var painting := TextureRect.new()
	painting.texture = PaintedLibrary.background(0)
	painting.position = Vector2(265, 0)
	painting.size = Vector2(540, 360)
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painting.modulate = Color(0.55, 0.65, 0.7)
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painting)
	var art := CharacterArt.new()
	art.set_profile(Bestiary.player_profile(GameContent.characters[0], 4, []))
	art.position = Vector2(448, 209)
	art.scale = Vector2.ONE * 3.5
	add_child(art)
	var shade := Polygon2D.new()
	shade.polygon = PackedVector2Array([Vector2(0, 0), Vector2(350, 0), Vector2(385, 360), Vector2(0, 360)])
	shade.vertex_colors = PackedColorArray([Color("09141c"), Color(0.035, 0.078, 0.11, 0.85), Color(0.035, 0.078, 0.11, 0), Color("09141c")])
	add_child(shade)
	CodexStyle.label(self, "S O P H I A", Vector2(426, 310), 10, CodexStyle.GOLD)
	CodexStyle.label(self, "A centelha que não se curva", Vector2(388, 327), 9, CodexStyle.MUTED)


func _build_title() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", "1.0"))
	CodexStyle.label(self, "O   D E S P E R T A R      ·      v%s" % version, Vector2(34, 25), 8, CodexStyle.MUTED)
	CodexStyle.label(self, "GNOSIS", Vector2(30, 54), 53, CodexStyle.PAPER, 330, true)
	CodexStyle.label(self, "O DESPERTAR DA FAÍSCA", Vector2(35, 122), 9, CodexStyle.GOLD)
	CodexStyle.label(self, "Sete anéis. Uma prisão. A luz ainda se lembra de você.", Vector2(35, 141), 10, CodexStyle.MUTED, 300)


func _build_actions() -> void:
	var has_save := RunManager.has_saved_run()
	var y: float = 170.0 if has_save else 187.0
	# --- Continuar (só com checkpoint salvo) ---
	if has_save:
		var sc := clampi(int(RunManager.saved_run.get("screen", 1)), 1, RunManager.MAX_SCREEN)
		var cont := CodexStyle.button(self, "Continuar · %s (Tela %d)" % [RunManager.eon_name(sc), sc], Vector2(COL_X, y), COL_W, func():
			Audio.play_sfx("ui_confirm")
			RunManager.continue_run(), true)
		_first_focus = cont
		y += ROW_PITCH
	# --- Nova campanha ---
	var new_run := CodexStyle.button(self, "Nova campanha", Vector2(COL_X, y), COL_W, _on_new_campaign, not has_save)
	if _first_focus == null:
		_first_focus = new_run
	y += ROW_PITCH
	# --- Provação (o antigo "desafio": 3 encontros, treino) ---
	CodexStyle.button(self, "Provação  —  treino de 3 encontros", Vector2(COL_X, y), COL_W, func():
		Audio.play_sfx("ui_confirm")
		CodexSession.start_demo())
	y += ROW_PITCH
	# --- Ateliê & Bestiário | Crônicas (coluna esquerda mais larga: o nome é longo) ---
	var left_w := 132.0
	var right_w := COL_W - left_w - 6.0
	CodexStyle.button(self, "Ateliê & Bestiário", Vector2(COL_X, y), left_w, func():
		SceneManager.change_scene("res://scenes/ui/CharacterAtelier.tscn"))
	CodexStyle.button(self, "Crônicas", Vector2(COL_X + left_w + 6, y), right_w, _open_chronicles)
	y += ROW_PITCH
	# --- Opções | Sair ---
	CodexStyle.button(self, "Opções", Vector2(COL_X, y), left_w, func():
		SceneManager.change_scene("res://scenes/ui/OptionsMenu.tscn"))
	CodexStyle.button(self, "Sair", Vector2(COL_X + left_w + 6, y), right_w, func(): get_tree().quit())


## Nova campanha: com checkpoint salvo, confirma antes (apaga o progresso do run).
func _on_new_campaign() -> void:
	if not RunManager.has_saved_run():
		Audio.play_sfx("ui_confirm")
		SceneManager.change_scene("res://scenes/ui/PreGame.tscn")
		return
	var sc := clampi(int(RunManager.saved_run.get("screen", 1)), 1, RunManager.MAX_SCREEN)
	CodexStyle.confirm(self, "Começar de novo?",
		"Isso apaga o progresso salvo — %s (Tela %d), faíscas e melhorias do run.\nFinais vistos e opções ficam." % [RunManager.eon_name(sc), sc],
		"Apagar e começar", func():
			Audio.play_sfx("ui_confirm")
			RunManager.saved_run = {}
			SaveManager.save_game()
			SceneManager.change_scene("res://scenes/ui/PreGame.tscn"),
		"Voltar", func():
			if _first_focus != null: _first_focus.grab_focus())


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
	var l := CodexStyle.wrap_label(CodexStyle.label(self, msg, Vector2(300, 8), 8, CodexStyle.GOLD, 320), 320)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	var t := create_tween()
	t.tween_interval(8.0)
	t.tween_property(l, "modulate:a", 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Foco perdido (clique no vazio) → volta pro primeiro botão ao mexer no controle.
	if get_viewport().gui_get_focus_owner() == null and _first_focus != null and (
			event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")):
		_first_focus.grab_focus()
