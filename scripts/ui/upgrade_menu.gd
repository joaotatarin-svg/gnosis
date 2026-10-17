extends CanvasLayer
## Santuário de Ascensão = a loja estilo God of War.
## Gasta faíscas pra: subir a arma (libera combos), subir magias, +Vida/+Éter, cura.
## Cada item é uma linha: nome e efeito à esquerda, PREÇO com o ícone de faísca
## à direita (cinza quando não dá pra pagar). Depois de comprar, o foco fica no
## mesmo item (dá pra comprar em série no controle). Esc/B fecha.

@onready var spark_label: Label = $Center/Panel/VBox/SparkLabel
@onready var list: VBoxContainer = $Center/Panel/VBox/List

const ROW_W := 420.0

var _focus_index: int = 0


func _ready() -> void:
	CodexStyle.apply_existing(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	$Dim.color = Color(0.01, 0.03, 0.045, 0.78)
	var vbox: VBoxContainer = $Center/Panel/VBox
	vbox.custom_minimum_size.x = ROW_W + 16
	vbox.add_theme_constant_override("separation", 6)
	var title: Label = $Center/Panel/VBox/Title
	title.text = "Santuário de Ascensão"
	var rule := CodexStyle.Rule.new()
	rule.custom_minimum_size = Vector2(0, 7)
	rule.color = Color(CodexStyle.GOLD, 0.85)
	vbox.add_child(rule)
	vbox.move_child(rule, 1)
	# Total de faíscas: ícone desenhado + número.
	spark_label.add_theme_font_override("font", CodexStyle.body_bold())
	spark_label.add_theme_font_size_override("font_size", 14)
	spark_label.add_theme_color_override("font_color", CodexStyle.SPARK)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)
	vbox.move_child(row, spark_label.get_index())
	var icon := _SparkIcon.new()
	icon.custom_minimum_size = Vector2(14, 20)
	row.add_child(icon)
	spark_label.reparent(row)
	spark_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ROW_W + 16, 196)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	list.reparent(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	var close_button := Button.new()
	close_button.text = "Voltar ao jogo" if not RunManager.pending_advance else "Seguir caminho"
	close_button.custom_minimum_size.y = CodexStyle.BTN_H
	close_button.pressed.connect(_close)
	CodexStyle._wire(close_button, "ui_back")
	vbox.add_child(close_button)
	_rebuild()
	CodexStyle.pop_in($Center/Panel)


func _rebuild() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	spark_label.text = "%d" % Progression.orbs

	# Arma (desbloqueia combos).
	if Progression.weapon_level < Progression.MAX_WEAPON_LEVEL:
		var cost := Progression.weapon_upgrade_cost()
		# O que o próximo nível ABRE (a progressão precisa ser legível).
		var opens: Array = []
		var ch0: CharacterData = GameManager.selected_character
		if ch0 == null and GameContent.characters.size() > 0:
			ch0 = GameContent.characters[0]
		if ch0 != null:
			for c in ch0.combos:
				if c.required_weapon_level == Progression.weapon_level + 1:
					opens.append(c.display_name)
		var sub := ("abre: " + ", ".join(opens)) if not opens.is_empty() else ""
		_add("Arma Nv. %d → %d" % [Progression.weapon_level, Progression.weapon_level + 1], sub, cost,
			Progression.can_upgrade_weapon(), _buy_weapon)
	else:
		_add("Arma no nível máximo", "", -1, false, Callable())

	# Magias do personagem escolhido.
	var ch: CharacterData = GameManager.selected_character
	if ch:
		for skill in ch.skills:
			if not Progression.is_skill_unlocked(skill.id):
				continue                     # Anel ainda não conquistado
			var lvl := Progression.skill_level(skill.id)
			if lvl >= skill.max_level:
				_add("%s  ·  Nv. %d (máx.)" % [skill.display_name, lvl], "", -1, false, Callable(), skill.color)
			else:
				var cost := Progression.skill_upgrade_cost(skill.id)
				_add("%s  ·  Nv. %d → %d" % [skill.display_name, lvl, lvl + 1], "", cost,
					Progression.orbs >= cost, _buy_skill.bind(skill), skill.color)

	# Vida / Éter máximos e cura.
	_add("+20 de vida máx.", "", 60, Progression.orbs >= 60, _buy_hp, CodexStyle.LIFE_HI)
	_add("+15 de Éter máx.", "", 60, Progression.orbs >= 60, _buy_mp, CodexStyle.ETHER_HI)
	var pl := get_tree().get_first_node_in_group("player")
	var hurt: bool = pl != null and pl.health != null and pl.health.current_health < pl.health.max_health
	_add("Restauração  ·  cura completa", "" if hurt else "a vida já está cheia", 50, hurt and Progression.orbs >= 50, _buy_heal)

	# Foco: o mesmo item de antes (ou o primeiro que dá pra comprar).
	var rows := list.get_children()
	if rows.is_empty():
		return
	var target: Button = rows[clampi(_focus_index, 0, rows.size() - 1)]
	if target.disabled:
		for r in rows:
			if not r.disabled:
				target = r
				break
	if target.disabled:
		var close: Button = $Center/Panel/VBox.get_child($Center/Panel/VBox.get_child_count() - 1)
		close.grab_focus.call_deferred()
	else:
		target.grab_focus.call_deferred()


## Uma linha da loja: nome (+ subtítulo), preço com faísca à direita.
func _add(text: String, sub: String, cost: int, enabled: bool, cb: Callable, accent: Color = CodexStyle.GOLD) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_ALL          # trancado também recebe foco (lê-se o preço)
	b.custom_minimum_size = Vector2(ROW_W, 34 if sub != "" else CodexStyle.BTN_H)
	b.add_theme_font_override("font", CodexStyle.display())
	b.add_theme_font_size_override("font_size", 10)
	var idx := list.get_child_count()
	b.focus_entered.connect(func(): _focus_index = idx)
	if cb.is_valid():
		b.pressed.connect(cb)
	CodexStyle._wire(b, "")
	var deco := _RowDeco.new()
	deco.accent = accent
	deco.cost = cost
	deco.affordable = enabled
	deco.sub = sub
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(deco)
	if sub != "":
		b.text = text + "\n "             # espaço pro subtítulo desenhado embaixo
	list.add_child(b)
	# Comprar algo trancado: som de "não dá".
	if not enabled and cost >= 0:
		b.gui_input.connect(func(ev: InputEvent):
			if ev.is_action_pressed("ui_accept"):
				Audio.play_sfx("shop_fail"))


func _buy_weapon() -> void:
	_buy_sfx(Progression.upgrade_weapon())
	_rebuild()


func _buy_skill(skill: SkillData) -> void:
	_buy_sfx(Progression.upgrade_skill(skill))
	_rebuild()


func _buy_hp() -> void:
	_buy_sfx(Progression.buy_max_health(20, 60))
	_rebuild()


func _buy_mp() -> void:
	_buy_sfx(Progression.buy_max_mana(15, 60))
	_rebuild()


func _buy_heal() -> void:
	if not Progression.spend_orbs(50):
		Audio.play_sfx("shop_fail")
		return
	Audio.play_sfx("shop_buy")
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.health != null:
		pl.health.heal(pl.health.max_health)
	_rebuild()


func _close() -> void:
	if RunManager.pending_advance:
		# Loja pós-chefe: avança pra próxima tela.
		RunManager.pending_advance = false
		get_tree().paused = false
		RunManager.advance_and_reload()
	elif RunManager.run_active:
		# Aberta pela pausa durante o run: fecha e volta pro menu de pausa.
		queue_free()
	else:
		# Modo teste/menu.
		get_tree().paused = false
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		_close()


## Som da compra: comprou → "shop_buy"; sem faíscas → "shop_fail".
func _buy_sfx(ok: bool) -> void:
	Audio.play_sfx("shop_buy" if ok else "shop_fail")


## Preço (faísca + número) à direita, filete de cor da magia à esquerda e
## subtítulo ("abre: …") embaixo do nome.
class _RowDeco extends Control:
	var accent: Color = Color("c5a56a")
	var cost: int = -1
	var affordable: bool = true
	var sub: String = ""
	func _draw() -> void:
		draw_line(Vector2(5, 6), Vector2(5, size.y - 6), Color(accent, 0.85 if affordable else 0.35), 1.2, true)
		if cost >= 0:
			var font := CodexStyle.body_bold()
			var s := str(cost)
			var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var x := size.x - 12.0 - w
			var y := size.y * 0.5
			var col := CodexStyle.SPARK if affordable else Color(CodexStyle.MUTED, 0.6)
			CodexStyle.draw_spark(self, Vector2(x - 9.0, y), 4.2, col)
			draw_string(font, Vector2(x, y + 4.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		if sub != "":
			draw_string(CodexStyle.italic(), Vector2(12, size.y - 7.0), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 90.0, 10, Color(CodexStyle.GOLD, 0.9 if affordable else 0.5))


class _SparkIcon extends Control:
	func _draw() -> void:
		CodexStyle.draw_spark(self, size * 0.5, 5.5)
