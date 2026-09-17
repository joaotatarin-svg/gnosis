extends Control
## Entrada da edição isolada. Campanha e demonstração usam o combate existente.

func _ready() -> void:
	CodexSession.leave_demo()
	RunManager.end_run()
	Progression.reset_run()
	GameManager.set_state(GameManager.State.MENU)
	var backdrop = load("res://scripts/fx/codex_sanctum.gd").new()
	backdrop.menu = true
	add_child(backdrop)
	var painting := TextureRect.new()
	painting.texture = PaintedLibrary.background(0)
	painting.position = Vector2(265,0)
	painting.size = Vector2(540,360)
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painting.modulate = Color(0.55,0.65,0.7)
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
	CodexStyle.label(self, "C O D E X   /   E D I Ç Ã O   I S O L A D A", Vector2(34, 25), 8, CodexStyle.MUTED)
	CodexStyle.label(self, "GNOSIS", Vector2(30, 54), 53, CodexStyle.PAPER, 330, true)
	CodexStyle.label(self, "O DESPERTAR DA FAÍSCA", Vector2(35, 122), 9, CodexStyle.GOLD)
	CodexStyle.label(self, "Sete anéis. Uma prisão.\nA luz ainda se lembra de você.", Vector2(35, 145), 12, CodexStyle.MUTED)
	var play := CodexStyle.button(self, "ENTRAR NO DESAFIO     →", Vector2(35, 193), 222, func(): CodexSession.start_demo(), true)
	CodexStyle.button(self, "ATELIÊ DE PERSONAGENS", Vector2(35, 228), 222, func(): SceneManager.change_scene("res://scenes/ui/CharacterAtelier.tscn"))
	CodexStyle.button(self, "Campanha", Vector2(35, 263), 108, func(): SceneManager.change_scene("res://scenes/ui/PreGame.tscn"))
	CodexStyle.button(self, "Continuar" if RunManager.has_saved_run() else "Crônicas", Vector2(149, 263), 108, func():
		if RunManager.has_saved_run(): RunManager.continue_run()
		else: SceneManager.change_scene("res://scenes/ui/Gallery.tscn"))
	CodexStyle.button(self, "Opções", Vector2(35, 298), 108, func(): SceneManager.change_scene("res://scenes/ui/OptionsMenu.tscn"))
	CodexStyle.button(self, "Sair", Vector2(149, 298), 108, func(): get_tree().quit())
	CodexStyle.label(self, "S O P H I A", Vector2(426, 310), 10, CodexStyle.GOLD)
	CodexStyle.label(self, "A centelha que não se curva", Vector2(388, 327), 9, CodexStyle.MUTED)
	play.grab_focus()
