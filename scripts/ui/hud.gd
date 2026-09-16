extends CanvasLayer
## HUD: barras de vida/Éter, faíscas, nível de arma, contador de combo —
## e a barra do CHEFE (nome + vida + fase), na base da tela, centralizada.
## A barra do chefe é desenhada com ColorRects (tamanho exato, sem tema).

@onready var screen_label: Label = $Margin/VBox/ScreenLabel
@onready var hp_bar: ProgressBar = $Margin/VBox/HPBar
@onready var mp_bar: ProgressBar = $Margin/VBox/MPBar
@onready var spark_label: Label = $Margin/VBox/SparkLabel
@onready var weapon_label: Label = $Margin/VBox/WeaponLabel
@onready var combo_label: Label = $ComboLabel

var _boss_box: Control
var _boss_fill: ColorRect
var _boss_name: Label
var _boss: Node = null
const BOSS_BAR_W := 300.0

# HUD dos 7 Anéis (dots coloridos; o equipado ganha moldura e nome).
var _ring_row: HBoxContainer
var _ring_dots: Array = []
var _ring_name: Label
var _toast_label: Label


func _ready() -> void:
	add_to_group("hud")
	_style_bar(hp_bar, Color(0.80, 0.22, 0.24), Color(0.22, 0.08, 0.10))
	_style_bar(mp_bar, Color(0.46, 0.50, 0.95), Color(0.10, 0.10, 0.26))
	_build_boss_bar()
	_build_rings()
	Progression.rings_changed.connect(_refresh_rings)
	_refresh_rings()

	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.health:
			player.health.health_changed.connect(_on_hp)
			_on_hp(player.health.current_health, player.health.max_health)
		player.mana_changed.connect(_on_mp)
		_on_mp(int(player.mana), player.max_mana_total)
		player.combo_changed.connect(_on_combo)
	Progression.orbs_changed.connect(_on_sparks)
	Progression.weapon_level_changed.connect(_on_weapon)
	_on_sparks(Progression.orbs)
	_on_weapon(Progression.weapon_level)
	_update_screen_label()
	RunManager.screen_changed.connect(func(_s): _update_screen_label())


## Barra com cor própria (preenchimento + fundo), sem o tema cinza padrão.
func _style_bar(bar: ProgressBar, fill: Color, back: Color) -> void:
	var f := StyleBoxFlat.new()
	f.bg_color = fill
	f.set_corner_radius_all(3)
	f.set_content_margin_all(0)
	var b := StyleBoxFlat.new()
	b.bg_color = back
	b.set_corner_radius_all(3)
	b.set_content_margin_all(0)
	b.border_color = fill.darkened(0.35)
	b.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", f)
	bar.add_theme_stylebox_override("background", b)
	bar.show_percentage = false


func _build_boss_bar() -> void:
	_boss_box = Control.new()
	# Base da tela, centralizada (estilo GoW): não briga com a vida do herói.
	_boss_box.anchor_left = 0.5
	_boss_box.anchor_right = 0.5
	_boss_box.anchor_top = 1.0
	_boss_box.anchor_bottom = 1.0
	_boss_box.offset_left = -150
	_boss_box.offset_right = 150
	_boss_box.offset_top = -48
	_boss_box.offset_bottom = -16
	_boss_box.visible = false
	add_child(_boss_box)

	_boss_name = Label.new()
	_boss_name.size = Vector2(300, 16)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 11)
	_boss_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_boss_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_boss_name.add_theme_constant_override("outline_size", 4)
	_boss_box.add_child(_boss_name)

	var back := ColorRect.new()
	back.color = Color(0.14, 0.10, 0.08, 0.95)
	back.position = Vector2(-1, 17)
	back.size = Vector2(BOSS_BAR_W + 2, 9)
	_boss_box.add_child(back)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.95, 0.80, 0.40)
	_boss_fill.position = Vector2(0, 18)
	_boss_fill.size = Vector2(BOSS_BAR_W, 7)
	_boss_box.add_child(_boss_fill)


## Fileira dos 7 Anéis, abaixo dos contadores (esquerda). Cada Anel é um "◆"
## na cor da magia; apagado = ainda não ganho; cinza = roubado (caco não voltou).
func _build_rings() -> void:
	_ring_row = HBoxContainer.new()
	_ring_row.add_theme_constant_override("separation", 3)
	$Margin/VBox.add_child(_ring_row)
	var ch: CharacterData = GameManager.selected_character
	if ch == null and GameContent.characters.size() > 0:
		ch = GameContent.characters[0]
	var rs: Array = GameContent.ring_skills(ch) if ch != null else []
	for i in rs.size():
		var d := Label.new()
		d.text = "◆"
		d.add_theme_font_size_override("font_size", 14)
		d.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		d.add_theme_constant_override("outline_size", 3)
		_ring_row.add_child(d)
		_ring_dots.append({"label": d, "skill": rs[i]})
	_ring_name = Label.new()
	_ring_name.add_theme_font_size_override("font_size", 10)
	_ring_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_ring_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_ring_name.add_theme_constant_override("outline_size", 3)
	_ring_row.add_child(_ring_name)


func _refresh_rings() -> void:
	if _ring_dots.is_empty():
		return
	var sel := clampi(Progression.selected_ring, 0, _ring_dots.size() - 1)
	var any := false
	for i in _ring_dots.size():
		var d: Label = _ring_dots[i].label
		var sk: SkillData = _ring_dots[i].skill
		var owned: bool = Progression.rings.has(sk.ring)
		var usable: bool = Progression.ring_usable(sk.ring)
		if not owned:
			d.add_theme_color_override("font_color", Color(1, 1, 1, 0.12))
		elif not usable:
			d.add_theme_color_override("font_color", Color(0.45, 0.42, 0.5, 0.7))   # roubado
		else:
			d.add_theme_color_override("font_color", sk.color)
			any = true
		d.text = "❖" if i == sel and usable else "◆"
	_ring_row.visible = any or Progression.rings.size() > 0
	var sk_sel: SkillData = _ring_dots[sel].skill
	if Progression.ring_usable(sk_sel.ring):
		_ring_name.text = " " + sk_sel.display_name
	elif Progression.rings.has(sk_sel.ring):
		_ring_name.text = " (roubado)"
	else:
		_ring_name.text = ""


## Aviso curto no centro da tela (cacos de memória, quedas na batalha final).
func toast(msg: String) -> void:
	if _toast_label == null:
		_toast_label = Label.new()
		_toast_label.anchor_left = 0.5
		_toast_label.anchor_right = 0.5
		_toast_label.anchor_top = 0.22
		_toast_label.anchor_bottom = 0.22
		_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.add_theme_font_size_override("font_size", 15)
		_toast_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
		_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_toast_label.add_theme_constant_override("outline_size", 5)
		add_child(_toast_label)
	_toast_label.text = msg
	_toast_label.modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(_toast_label, "modulate", Color(1, 1, 1, 1), 0.2)
	t.tween_interval(2.2)
	t.tween_property(_toast_label, "modulate", Color(1, 1, 1, 0), 0.5)


## Chamado (via grupo "hud") pelo chefe ao nascer.
func show_boss(e: Node) -> void:
	_boss = e
	_boss_name.text = e.display_name
	_set_boss_ratio(float(e.health.current_health) / maxf(1.0, float(e.health.max_health)))
	_boss_box.visible = true
	e.health.health_changed.connect(func(c, m):
		_set_boss_ratio(float(c) / maxf(1.0, float(m))))
	e.health.died.connect(func(): _boss_box.visible = false)


func _set_boss_ratio(r: float) -> void:
	_boss_fill.size.x = BOSS_BAR_W * clampf(r, 0.0, 1.0)
	# Abaixo da metade a barra esquenta (fase 2).
	_boss_fill.color = Color(0.95, 0.80, 0.40) if r > 0.5 else Color(0.95, 0.55, 0.30)


## Chamado pelo chefe ao entrar na fase 2.
func boss_phase(n: int) -> void:
	if _boss == null:
		return
	_boss_name.text = "%s  —  FASE %s" % [_boss.display_name, "II" if n == 2 else str(n)]
	_boss_box.pivot_offset = Vector2(150, 16)
	_boss_box.scale = Vector2(1.25, 1.25)
	var t := create_tween()
	t.tween_property(_boss_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_combo(count: int) -> void:
	if count < 2:
		combo_label.text = ""
		return
	combo_label.text = "%d  COMBO" % count
	combo_label.scale = Vector2(1.35, 1.35)
	combo_label.pivot_offset = combo_label.size * 0.5
	var t := create_tween()
	t.tween_property(combo_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_screen_label() -> void:
	var s := RunManager.current_screen
	if not RunManager.run_active:
		screen_label.text = "Tela %d" % s
	elif RunManager.is_final(s):
		screen_label.text = "A MENTE DO CEGO"
	elif RunManager.is_king_screen(s):
		screen_label.text = "O Limiar"
	elif RunManager.is_center(s):
		screen_label.text = "O Centro — Tela %d" % s
	elif RunManager.is_archon_screen(s):
		screen_label.text = "Éon %s — O ARCONTE" % RunManager.eon_name(s)
	else:
		screen_label.text = "Éon %s — Tela %d" % [RunManager.eon_name(s), s]


func _on_hp(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current


func _on_mp(current: int, maximum: int) -> void:
	mp_bar.max_value = maximum
	mp_bar.value = current


func _on_sparks(total: int) -> void:
	spark_label.text = "Faíscas: %d" % total


func _on_weapon(level: int) -> void:
	weapon_label.text = "Arma Nv. %d" % level
