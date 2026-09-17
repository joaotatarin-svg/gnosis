extends CanvasLayer
## Santuário de Ascensão = a loja estilo God of War.
## Gasta faíscas pra: subir a arma (libera combos), subir magias, +HP/+Éter.

@onready var spark_label: Label = $Center/Panel/VBox/SparkLabel
@onready var list: VBoxContainer = $Center/Panel/VBox/List


func _ready() -> void:
	CodexStyle.apply_existing(self)
	$Center/Panel/VBox.custom_minimum_size.x = 340
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(450, 206)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$Center/Panel/VBox.add_child(scroll)
	list.reparent(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button := Button.new()
	close_button.text = "Voltar ao jogo"
	close_button.pressed.connect(_close)
	$Center/Panel/VBox.add_child(close_button)
	_rebuild()


func _rebuild() -> void:
	for c in list.get_children():
		c.queue_free()
	spark_label.text = "Faíscas: %d" % Progression.orbs

	# Arma (desbloqueia combos).
	if Progression.weapon_level < Progression.MAX_WEAPON_LEVEL:
		var cost := Progression.weapon_upgrade_cost()
		_add("Arma Nv.%d → %d   (%d faíscas)" % [Progression.weapon_level, Progression.weapon_level + 1, cost],
			Progression.can_upgrade_weapon(), _buy_weapon)
	else:
		_add("Arma no nível máximo", false, Callable())

	# Magias do personagem escolhido.
	var ch: CharacterData = GameManager.selected_character
	if ch:
		for skill in ch.skills:
			if not Progression.is_skill_unlocked(skill.id):
				continue                     # Anel ainda não conquistado
			var lvl := Progression.skill_level(skill.id)
			if lvl >= skill.max_level:
				_add("%s Nv.%d (MÁX)" % [skill.display_name, lvl], false, Callable())
			else:
				var cost := Progression.skill_upgrade_cost(skill.id)
				_add("%s Nv.%d → %d   (%d faíscas)" % [skill.display_name, lvl, lvl + 1, cost],
					Progression.orbs >= cost, _buy_skill.bind(skill))

	# HP / Éter máximo.
	_add("+20 Vida máx   (60 faíscas)", Progression.orbs >= 60, _buy_hp)
	_add("+15 Éter máx   (60 faíscas)", Progression.orbs >= 60, _buy_mp)
	# Cura (balance 2026-09-11: o run precisava de UMA fonte de cura comprável).
	var pl := get_tree().get_first_node_in_group("player")
	var hurt: bool = pl != null and pl.health != null and pl.health.current_health < pl.health.max_health
	_add("Restauração — cura cheia   (50 faíscas)", hurt and Progression.orbs >= 50, _buy_heal)

	list.add_child(HSeparator.new())
	_add("Continuar", true, _close)


func _add(text: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	if cb.is_valid():
		b.pressed.connect(cb)
	list.add_child(b)


func _buy_weapon() -> void:
	Progression.upgrade_weapon()
	_rebuild()


func _buy_skill(skill: SkillData) -> void:
	Progression.upgrade_skill(skill)
	_rebuild()


func _buy_hp() -> void:
	Progression.buy_max_health(20, 60)
	_rebuild()


func _buy_mp() -> void:
	Progression.buy_max_mana(15, 60)
	_rebuild()


func _buy_heal() -> void:
	if not Progression.spend_orbs(50):
		return
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
