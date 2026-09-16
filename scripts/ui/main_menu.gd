extends Control
## Menu principal cinematográfico: parallax do Kenoma ao fundo, o herói
## parado na luz e o título pulsando. Tudo procedural, montado por código.

var _title: Label


func _ready() -> void:
	Progression.reset_run()
	GameManager.set_state(GameManager.State.MENU)
	_build_backdrop()
	_style_ui()
	_build_continue()
	$Center/VBox/Play.pressed.connect(_on_play)
	$Center/VBox/Gallery.pressed.connect(func(): SceneManager.change_scene("res://scenes/ui/Gallery.tscn"))
	$Center/VBox/Options.pressed.connect(func(): SceneManager.change_scene("res://scenes/ui/OptionsMenu.tscn"))
	$Center/VBox/Quit.pressed.connect(func(): get_tree().quit())
	Audio.play_music("theme")


func _build_backdrop() -> void:
	# Fundo em parallax (estático aqui, mas com as camadas dando profundidade).
	var bg: Node = load("res://scenes/levels/Background.tscn").instantiate()
	add_child(bg)
	move_child(bg, 1)      # acima do ColorRect Bg, abaixo da UI

	var world := Node2D.new()
	add_child(world)
	move_child(world, 2)

	# Chão
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2(0, 300), Vector2(640, 300), Vector2(640, 360), Vector2(0, 360)])
	ground.vertex_colors = PackedColorArray([
		Color(0.22, 0.18, 0.29), Color(0.22, 0.18, 0.29),
		Color(0.09, 0.07, 0.13), Color(0.09, 0.07, 0.13),
	])
	world.add_child(ground)

	# Facho de luz vindo de cima (a Mônada chamando)
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([Vector2(455, 0), Vector2(525, 0), Vector2(510, 300), Vector2(470, 300)])
	beam.color = Color(1.0, 0.92, 0.6, 0.06)
	world.add_child(beam)

	# Sombra + herói respirando na luz (à direita, menu à esquerda/centro)
	var shadow := Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.position = Vector2(490, 300)
	shadow.polygon = PackedVector2Array([
		Vector2(26, 0), Vector2(20, 5), Vector2(0, 8), Vector2(-20, 5),
		Vector2(-26, 0), Vector2(-20, -5), Vector2(0, -8), Vector2(20, -5)
	])
	world.add_child(shadow)

	var hero := CharacterArt.new()
	hero.set_profile(Bestiary.player_profile(GameContent.get_character("sophia"), 1, []))
	hero.set_rig("res://assets/characters/sophia/rig.json", Player.RIG_HEIGHT)   # ilustrada
	hero.set_anim("idle")
	hero.position = Vector2(490, 252)
	hero.scale = Vector2(2.0, 2.0)
	world.add_child(hero)


func _style_ui() -> void:
	_title = $Center/VBox/Title
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	$Center/VBox/Subtitle.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85))
	# Título pulsa devagar (a faísca respirando)
	var t := create_tween().set_loops()
	t.tween_property(_title, "modulate", Color(1.15, 1.1, 1.0), 1.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(_title, "modulate", Color(0.9, 0.88, 0.85), 1.6).set_trans(Tween.TRANS_SINE)
	# Menu ancorado mais à esquerda (herói ocupa a direita)
	$Center.anchor_right = 0.62
	for b in [$Center/VBox/Play, $Center/VBox/Gallery, $Center/VBox/Options, $Center/VBox/Quit]:
		b.custom_minimum_size = Vector2(180, 0)


## Run salvo no disco → botão "Continuar" acima de "Jogar" (retoma do checkpoint).
func _build_continue() -> void:
	if not RunManager.has_saved_run():
		return
	var sc := clampi(int(RunManager.saved_run.get("screen", 1)), 1, RunManager.MAX_SCREEN)
	var c := Button.new()
	c.text = "Continuar — %s (Tela %d)" % [RunManager.eon_name(sc), sc]
	c.custom_minimum_size = Vector2(180, 0)
	var vbox: VBoxContainer = $Center/VBox
	vbox.add_child(c)
	vbox.move_child(c, ($Center/VBox/Play as Control).get_index())
	c.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	c.pressed.connect(func(): RunManager.continue_run())


func _on_play() -> void:
	SceneManager.change_scene("res://scenes/ui/PreGame.tscn")
