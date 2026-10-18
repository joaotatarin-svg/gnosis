extends CanvasLayer
## Santuário de Ascensão = a loja estilo God of War.
## Gasta faíscas para: subir a arma (libera combos), subir magias, +Vida/+Éter, cura.
## Cada item é uma linha: nome e efeito à esquerda, PREÇO com o ícone de faísca
## à direita. Indisponível = linha apagada; sem faíscas, a faixa de aviso diz
## "Faíscas insuficientes · faltam N" ao focar o item. Abre com o foco no 1º
## item; setas/D-pad andam, Enter/A compra, Esc/B fecha. Depois de comprar, o
## foco fica no mesmo item (dá para comprar em série no controle).
## Pausa o mundo pela `PauseStack` (por cima da pausa, fechar volta para ela).
## Economia (Onda 6 — números e regras no Progression, docs/onda2/PROGRESSAO6.md):
## preços crescentes; o nível máximo de cada trilha é SELADO pelo progresso
## (Arcontes vencidos no run) — a linha selada aparece apagada com "selado ·
## vença <Arconte>"; relíquias (uma em uso, troca de graça); a Restauração (cura
## cheia) só no santuário e no pós-chefe (`RunManager.pending_advance`).

## Atalhos para quem lia daqui (QA/ferramentas): a fonte é o Progression.
const _PROG := preload("res://scripts/autoload/progression_manager.gd")
const HP_STEP := _PROG.HP_STEP
const HP_BASE_COST := _PROG.HP_BASE_COST
const HP_MAX_BUYS := _PROG.HP_MAX_BUYS
const HEAL_COST := _PROG.HEAL_BASE_COST
const SOTER_HP := _PROG.SOTER_HP

@onready var spark_label: Label = $Center/Panel/VBox/SparkLabel
@onready var list: VBoxContainer = $Center/Panel/VBox/List

const ROW_W := 420.0

var _focus_index: int = 0
var _status: Label                 # "Faíscas insuficientes · faltam N"
var _close_button: Button


func _ready() -> void:
	CodexStyle.apply_existing(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseStack.push(self)
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
	# Faixa de aviso (altura fixa: o painel não pula quando ela acende/apaga).
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(ROW_W, 13)
	_status.add_theme_font_override("font", CodexStyle.italic())
	_status.add_theme_font_size_override("font_size", 10)
	_status.add_theme_color_override("font_color", CodexStyle.EMBER)
	vbox.add_child(_status)
	vbox.move_child(_status, row.get_index() + 1)
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
	close_button.focus_entered.connect(_update_status.bind(null))
	CodexStyle._wire(close_button, "ui_back")
	vbox.add_child(close_button)
	_close_button = close_button
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
		var title := "Arma Nv. %d → %d" % [Progression.weapon_level, Progression.weapon_level + 1]
		if Progression.weapon_sealed():
			_add_sealed(title, Progression.weapon_next_tier(), cost)
		else:
			_add(title, sub, cost, Progression.can_upgrade_weapon(), _buy_weapon)
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
				var title := "%s  ·  Nv. %d → %d" % [skill.display_name, lvl, lvl + 1]
				if Progression.skill_sealed(skill.id):
					_add_sealed(title, Progression.skill_next_tier(skill.id), cost, skill.color)
				else:
					_add(title, "", cost, Progression.orbs >= cost, _buy_skill.bind(skill), skill.color)

	# Vida / Éter máximos: preço crescente; o teto sobe com os Arcontes.
	var n := hp_buys()
	var hp_title := "+20 de vida máx.  ·  %d / %d" % [n, HP_MAX_BUYS]
	if n >= HP_MAX_BUYS:
		_add(hp_title, "no máximo", -1, false, Callable(), CodexStyle.LIFE_HI)
	elif n >= Progression.hp_buy_cap():
		_add_sealed(hp_title, n - Progression.HP_FREE_BUYS + 1, hp_cost_for(n), CodexStyle.LIFE_HI)
	else:
		var hp_cost := hp_cost_for(n)
		_add(hp_title, "", hp_cost, Progression.orbs >= hp_cost, _buy_hp, CodexStyle.LIFE_HI)
	var m := Progression.mp_buys()
	var mp_title := "+15 de Éter máx.  ·  %d / %d" % [m, Progression.MP_MAX_BUYS]
	if m >= Progression.MP_MAX_BUYS:
		_add(mp_title, "no máximo", -1, false, Callable(), CodexStyle.ETHER_HI)
	elif m >= Progression.mp_buy_cap():
		_add_sealed(mp_title, m - Progression.MP_FREE_BUYS + 1, Progression.mp_cost_for(m), CodexStyle.ETHER_HI)
	else:
		var mp_cost := Progression.mp_cost_for(m)
		_add(mp_title, "", mp_cost, Progression.orbs >= mp_cost, _buy_mp, CodexStyle.ETHER_HI)

	# Relíquias: compra = já põe em uso; as compradas trocam de graça.
	var worn := Progression.equipped_relic()
	for r in GameContent.relics:
		var rid: String = r.get("id", "")
		var rname: String = r.get("name", "")
		var rcol: Color = r.get("color", CodexStyle.GOLD)
		var rdesc: String = r.get("desc", "")
		if Progression.has_relic(rid):
			if rid == worn:
				_add("%s  ·  em uso" % rname, rdesc, -1, false, Callable(), rcol)
			else:
				_add("%s  ·  usar" % rname, rdesc, -1, true, _equip_relic.bind(rid), rcol)
		elif Progression.relic_sealed(rid):
			_add_sealed("Relíquia  ·  %s" % rname, int(r.get("tier", 0)), int(r.get("cost", 0)), rcol)
		else:
			var rcost: int = int(r.get("cost", 0))
			_add("Relíquia  ·  %s" % rname, rdesc, rcost, Progression.orbs >= rcost, _buy_relic.bind(rid), rcol)

	var pl := get_tree().get_first_node_in_group("player")
	var hurt: bool = pl != null and pl.health != null and pl.health.current_health < pl.health.max_health
	var heal_cost := Progression.heal_cost()
	if heal_allowed():
		_add("Restauração  ·  cura completa", "" if hurt else "a vida já está cheia", heal_cost, hurt and Progression.orbs >= heal_cost, _buy_heal)
	else:
		_add("Restauração  ·  cura completa", "só no santuário e depois do Arconte", -1, false, Callable())

	# Foco: o 1º item ao abrir; depois de comprar, o mesmo item de antes
	# (trancado também recebe foco — lê-se o preço e o aviso).
	var rows := list.get_children()
	if rows.is_empty():
		if _close_button != null:
			_close_button.grab_focus.call_deferred()
		return
	var target: Button = rows[clampi(_focus_index, 0, rows.size() - 1)]
	target.grab_focus.call_deferred()
	_update_status(target)


## Faixa de aviso: item focado sem faíscas → "faltam N"; no "Voltar" (ou sem
## item), avisa se NADA dá para comprar por falta de faíscas.
func _update_status(row: Button) -> void:
	if _status == null:
		return
	var text := ""
	if row != null and row.has_meta("seal"):
		# Selado pelo progresso: diz QUEM abre (o preço já aparece apagado).
		text = "Selado  ·  vença %s para abrir" % Progression.tier_gate_name(int(row.get_meta("seal")))
	elif row != null and row.has_meta("cost"):
		var cost: int = row.get_meta("cost")
		if cost >= 0 and Progression.orbs < cost:
			text = "Faíscas insuficientes  ·  faltam %d" % (cost - Progression.orbs)
	else:
		var any_ok := false
		var any_short := false
		for r in list.get_children():
			if r.is_queued_for_deletion() or not r.has_meta("cost"):
				continue
			var c: int = r.get_meta("cost")
			if r.has_meta("seal"):
				continue
			if not r.disabled:
				any_ok = true
			elif c >= 0 and Progression.orbs < c:
				any_short = true
		if any_short and not any_ok:
			text = "Faíscas insuficientes para as melhorias"
	_status.text = text


## Linha SELADA pelo progresso: apagada, preço visível, subtítulo "selado ·
## vença <Arconte>" e, no foco, a faixa diz quem abre.
func _add_sealed(text: String, tier: int, cost: int, accent: Color = CodexStyle.GOLD) -> void:
	_add(text, "selado  ·  vença %s" % Progression.tier_gate_name(tier), cost, false, Callable(), accent)
	var rows := list.get_children()
	if not rows.is_empty():
		rows[rows.size() - 1].set_meta("seal", tier)


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
	b.set_meta("cost", cost)
	b.focus_entered.connect(func():
		_focus_index = idx
		_update_status(b))
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
		b.text = text + "\n "             # espaço para o subtítulo desenhado embaixo
	if not enabled:
		# Apagado de verdade (QA M3): texto e preço recuam; o foco ainda acende a moldura.
		b.add_theme_color_override("font_disabled_color", Color(CodexStyle.MUTED, 0.5))
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
	_buy_sfx(Progression.buy_health_upgrade())
	_rebuild()


## Preço da (n+1)-ésima compra de vida (fonte: Progression).
static func hp_cost_for(n: int) -> int:
	return Progression.hp_cost_for(n)


## Quantas vezes a vida máx. já foi comprada NESTE run (fonte: Progression,
## que guarda o contador no run e deduz do bônus em save antigo).
static func hp_buys() -> int:
	return Progression.hp_buys()


static func hp_buys_from_bonus(bonus: int) -> int:
	return Progression.hp_buys_from_bonus(bonus)


## A cura cheia só é vendida fora da luta: santuário/pós-chefe (loja que avança
## ao fechar) ou fora do run (Provação e testes).
static func heal_allowed() -> bool:
	return RunManager.pending_advance or not RunManager.run_active


func _buy_mp() -> void:
	_buy_sfx(Progression.buy_mana_upgrade())
	_rebuild()


func _buy_relic(id: String) -> void:
	_buy_sfx(Progression.buy_relic(id))
	_rebuild()


func _equip_relic(id: String) -> void:
	Progression.equip_relic(id)
	Audio.play_sfx("shop_buy")
	_rebuild()


func _buy_heal() -> void:
	if not heal_allowed() or not Progression.spend_orbs(Progression.heal_cost()):
		Audio.play_sfx("shop_fail")
		return
	Audio.play_sfx("shop_buy")
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.health != null:
		pl.health.heal(pl.health.max_health)
	_rebuild()


func _close() -> void:
	if RunManager.pending_advance:
		# Loja pós-chefe: avança para a próxima tela (troca de cena: zera a pilha).
		RunManager.pending_advance = false
		PauseStack.clear()
		RunManager.advance_and_reload()
	elif RunManager.run_active:
		# Aberta pela pausa durante o run: fecha e volta para o menu de pausa
		# (que continua segurando o mundo); sem pausa por baixo, despausa.
		PauseStack.pop(self)
		queue_free()
	else:
		# Modo teste/menu.
		PauseStack.clear()
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")


func _exit_tree() -> void:
	PauseStack.pop(self)


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
		draw_line(Vector2(5, 6), Vector2(5, size.y - 6), Color(accent, 0.85 if affordable else 0.22), 1.2, true)
		if cost >= 0:
			var font := CodexStyle.body_bold()
			var s := str(cost)
			var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var x := size.x - 12.0 - w
			var y := size.y * 0.5
			var col := CodexStyle.SPARK if affordable else Color(CodexStyle.MUTED, 0.45)
			CodexStyle.draw_spark(self, Vector2(x - 9.0, y), 4.2, col)
			draw_string(font, Vector2(x, y + 4.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		if sub != "":
			draw_string(CodexStyle.italic(), Vector2(12, size.y - 7.0), I18n.t(sub), HORIZONTAL_ALIGNMENT_LEFT, size.x - 90.0, 10, Color(CodexStyle.GOLD, 0.9) if affordable else Color(CodexStyle.MUTED, 0.5))


class _SparkIcon extends Control:
	func _draw() -> void:
		CodexStyle.draw_spark(self, size * 0.5, 5.5)
