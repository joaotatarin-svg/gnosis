extends Node
## QA da PROGRESSÃO (Onda 6, headless): selos por Arconte, preços crescentes,
## tetos de vida/Éter, relíquias, pulo duplo (por run, no save) e tolerância a
## save antigo. Não grava nada em disco (o save do run é testado por JSON em
## memória + RunManager.continue_run).
## Uso: godot --headless --audio-driver Dummy --path . res://tools/progressao6/ProgQA.tscn

var errors: int = 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("QA PASS: ", msg)
	else:
		errors += 1
		push_error("QA FAIL: " + msg)


func _ready() -> void:
	SaveManager.persist_enabled = false
	Gnosis.persist_enabled = false
	await get_tree().process_frame          # a raiz termina de montar (add_child da loja)
	GameManager.selected_character = GameContent.characters[0]
	_cases_gates()
	_cases_tracks()
	_cases_relics()
	await _cases_shop_ui()
	await _cases_double_jump_save()
	print("QA RESULT: ", errors, " falhas")
	get_tree().quit(0 if errors == 0 else 1)


func _new_run() -> void:
	RunManager.begin()
	Progression.reset_run()
	Progression.orbs = 99999


func _cases_gates() -> void:
	# Fora do run nada é selado (Provação/testes).
	RunManager.run_active = false
	check(Progression.progress_tier() == Progression.MAX_TIER, "fora do run: grau 7 (nada selado)")
	_new_run()
	check(Progression.progress_tier() == 0, "run novo: grau 0")
	check(Progression.weapon_upgrade_cost() == 200 and Progression.can_upgrade_weapon(), "arma Nv.2: 200 e livre no grau 0")
	check(Progression.upgrade_weapon() and Progression.weapon_level == 2, "comprou arma Nv.2")
	check(Progression.weapon_sealed() and not Progression.upgrade_weapon(), "arma Nv.3 selada antes de Athoth")
	check(not Progression.gift_weapon_level() and Progression.weapon_level == 2, "presente do Soter respeita o selo")
	Progression.add_ring("arconte_sono", "r_torpor")
	check(Progression.progress_tier() == 1 and Progression.tier_gate_name(1) == "Athoth", "Athoth vencido: grau 1 (nome curto)")
	check(Progression.weapon_upgrade_cost() == 450 and Progression.upgrade_weapon() and Progression.weapon_level == 3, "arma Nv.3: 450 depois de Athoth")
	check(Progression.weapon_next_tier() == 3 and Progression.weapon_sealed(), "arma Nv.4 pede 3 Arcontes")
	Progression.steal_rings()
	check(Progression.progress_tier() == 1, "o roubo não tira o grau")


func _cases_tracks() -> void:
	_new_run()
	var o0 := Progression.orbs
	var bought := 0
	for i in 5:
		if Progression.buy_health_upgrade():
			bought += 1
	check(bought == 3 and Progression.hp_buys() == 3 and Progression.bonus_max_health == 60, "vida: 3 compras no grau 0 (%d)" % bought)
	check(o0 - Progression.orbs == 90 + 180 + 270, "vida: preço 90/180/270 (%d)" % (o0 - Progression.orbs))
	check(Progression.mp_buy_cap() == 1 and Progression.buy_mana_upgrade() and not Progression.buy_mana_upgrade(), "Éter: 1 compra no grau 0")
	# Magia inata: Nv.2 livre (150), Nv.3 selado até 2 Arcontes.
	var sol: SkillData = GameContent.innate_skill(GameManager.selected_character)
	check(Progression.skill_upgrade_cost(sol.id) == 150 and Progression.upgrade_skill(sol), "Esfera Nv.2: 150")
	check(Progression.skill_sealed(sol.id) and not Progression.upgrade_skill(sol), "Esfera Nv.3 selada no grau 0")
	Progression.add_ring("arconte_sono", "r_torpor")
	Progression.add_ring("arconte_fome", "r_fome")
	check(Progression.skill_upgrade_cost(sol.id) == 400 and Progression.upgrade_skill(sol), "Esfera Nv.3: 400 com 2 Arcontes")
	check(Progression.skill_ring_index("r_fome") == 2 and Progression.skill_upgrade_cost("r_fome") == 230, "Boca Voraz (Anel 2) Nv.2: 230")
	check(Progression.skill_next_tier("r_fome") == 2, "Anel 2 Nv.2 sai junto com o Anel")
	check(Progression.hp_buy_cap() == 5 and Progression.mp_buy_cap() == 3, "tetos sobem com o grau (vida 5, Éter 3)")
	check(Progression.heal_cost() == 50 + 15 * 2, "Restauração escala com o grau (80)")
	# Presentes (mapa +4/+6/+8, Soter +25) não contam como compra num run novo.
	_new_run()
	Progression.buy_max_health(6, 0)
	Progression.buy_max_health(8, 0)
	Progression.bonus_max_health += 25
	Progression.buy_max_mana(4, 0)
	check(Progression.hp_buys() == 0 and Progression.mp_buys() == 0 and Progression.hp_buy_cap() == 3, "presentes do mapa/Soter não gastam compras da loja")
	# Save antigo: sem contador "#vida" → deduz do bônus (20 + dom de 25 do Soter).
	Progression.items.clear()
	Progression.bonus_max_health = 45
	Progression.bonus_max_mana = 30
	check(Progression.hp_buys() == 1 and Progression.mp_buys() == 2, "save antigo: compras deduzidas do bônus")


func _cases_relics() -> void:
	_new_run()
	check(Progression.relic_sealed("brasa") and not Progression.buy_relic("brasa"), "Brasa selada no grau 0")
	Progression.add_ring("arconte_sono", "r_torpor")
	check(Progression.buy_relic("brasa") and Progression.equipped_relic() == "brasa", "Brasa comprada e em uso")
	check(not Progression.buy_relic("brasa"), "não compra duas vezes")
	check(Progression.relic_sealed("perola"), "Pérola selada até 3 Arcontes")
	Progression.add_ring("arconte_fome", "r_fome")
	Progression.add_ring("arconte_corrente", "r_corrente")
	var before := Progression.orbs
	check(Progression.buy_relic("perola") and before - Progression.orbs == 500, "Pérola: 500")
	check(Progression.equipped_relic() == "perola" and Progression.has_relic("brasa"), "comprar troca a em uso; a antiga continua sua")
	var o := Progression.orbs
	Progression.add_orbs(100)
	check(Progression.orbs - o == 125, "Pérola: +25%% no ganho (%d)" % (Progression.orbs - o))
	o = Progression.orbs
	Progression.add_orbs(-40)
	check(o - Progression.orbs == 40, "Pérola não mexe em perdas")
	check(Progression.equip_relic("brasa") and Progression.equipped_relic() == "brasa", "troca de graça para a Brasa")
	check(not Progression.equip_relic("lampada"), "não usa relíquia que não tem")
	check(not Progression.item_features().has("#reliquias=brasa,perola") and Progression.item_features().is_empty(), "arte não vê as entradas '#'")


func _cases_shop_ui() -> void:
	_new_run()
	Progression.orbs = 5000
	var shop: Node = load("res://scenes/ui/UpgradeMenu.tscn").instantiate()
	get_tree().root.add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame
	var rows: Array = shop.get("list").get_children()
	var sealed := 0
	var texts: Array[String] = []
	for b in rows:
		texts.append(String(b.text).split("\n")[0])
		if b.has_meta("seal"):
			sealed += 1
	check(not rows.is_empty() and not rows[0].disabled and String(rows[0].text).begins_with("Arma Nv. 1"), "loja: 1º item = arma, comprável [%s]" % (texts[0] if not texts.is_empty() else "-"))
	check(sealed >= 3, "loja no grau 0: linhas seladas (%d) — %s" % [sealed, ", ".join(texts)])
	# Arma comprada: a linha seguinte vira selada e a faixa diz quem abre.
	shop.call("_buy_weapon")
	await get_tree().process_frame
	rows = shop.get("list").get_children()
	var w: Button = null
	for b in rows:
		if not b.is_queued_for_deletion() and String(b.text).begins_with("Arma Nv. 2"):
			w = b
	check(w != null and w.disabled and w.has_meta("seal"), "loja: arma Nv.3 aparece selada")
	if w != null:
		shop.call("_update_status", w)
		var st: Label = shop.get("_status")
		check(st != null and st.text.contains("Athoth"), "faixa: 'vença Athoth' [%s]" % (st.text if st else "-"))
	PauseStack.clear()
	shop.queue_free()
	await get_tree().process_frame


func _cases_double_jump_save() -> void:
	_new_run()
	var got := [false]
	var cb := func() -> void: got[0] = true
	Progression.double_jump_granted.connect(cb)
	check(not Progression.has_double_jump(), "run novo: sem pulo duplo")
	Progression.grant_double_jump()
	Progression.grant_double_jump()
	check(Progression.has_double_jump() and got[0], "pulo duplo concedido (sinal emitido)")
	Progression.double_jump_granted.disconnect(cb)
	Progression.buy_health_upgrade()
	Progression.add_ring("arconte_sono", "r_torpor")
	Progression.buy_relic("brasa")
	# Ida e volta pelo save do run (JSON, como no disco).
	var snap: Dictionary = JSON.parse_string(JSON.stringify(RunManager.run_snapshot()))
	RunManager.saved_run = snap
	Progression.reset_run()
	check(not Progression.has_double_jump(), "reset_run tira o pulo duplo (é por run)")
	RunManager.continue_run()
	check(Progression.has_double_jump() and Progression.hp_buys() == 1 and Progression.equipped_relic() == "brasa", "Continuar: pulo duplo, compras e relíquia voltam")
	# Save antigo (sem as entradas '#'): padrão, sem erro.
	var old := snap.duplicate(true)
	old["items"] = ["helmet"]
	old["bonus_hp"] = 20
	RunManager.saved_run = old
	RunManager.continue_run()
	check(not Progression.has_double_jump() and Progression.hp_buys() == 1 and Progression.equipped_relic() == "" and Progression.item_features().size() == 1 and Progression.item_features()[0] == "helmet", "save antigo: sem pulo duplo, compras deduzidas, gear intacto")
	# Tipo errado no items → padrão (conversor tolerante).
	var bad := snap.duplicate(true)
	bad["items"] = "#pulo_duplo=1"
	RunManager.saved_run = bad
	RunManager.continue_run()
	check(not Progression.has_double_jump(), "items quebrado no save: sem pulo duplo, sem erro")
	for i in 4:
		await get_tree().process_frame
	RunManager.run_active = false
