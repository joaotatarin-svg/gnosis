extends Node
## QA do MAPA DOS ÉONS (Onda 6, diretor de mapa) — headless.
##  1. Grafo: 7 Éons × 9 camadas; camadas 0/4/7/8 com nó único; telas certas;
##     todo nó alcançável; sempre há caminho SEM pulo duplo até o Arconte e
##     nenhum beco (todo nó livre tem saída livre).
##  2. Planos: todo nó de todo Éon tem plano de zonas válido (2 zonas nos tipos
##     do mapa; ids existentes no Bestiário).
##  3. Fluxo real: chegada → tela de mapa → escolha → tela do tipo escolhido;
##     escolha inválida/trancada recusada; recompensa paga; morte volta ao
##     checkpoint com a rota cortada; snapshot/continuar com rota; save ANTIGO
##     (sem bloco de mapa) migra; rota automática determinística (bot).
## Saída: "QA PASS"/"QA FAIL"; exit 0/1. Nada grava em disco (persist off).
## Uso: godot --headless --audio-driver Dummy --path . res://tools/map6/MapQA.tscn

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
	_graph_checks()
	_plan_checks()
	# O fluxo troca de cena: o trabalho segue num nó filho do ROOT.
	# (a cena da QA morre na 1ª troca: o Flow leva só a contagem de erros)
	var w := Flow.new()
	w.errors = errors
	get_tree().root.add_child.call_deferred(w)


# --- 1. grafo ------------------------------------------------------------------

func _graph_checks() -> void:
	var problems: Array = []
	for eon in 7:
		var g := EonMap.graph(eon)
		var layers: Array = g.layers
		if layers.size() != 9:
			problems.append("e%d: %d camadas" % [eon, layers.size()])
			continue
		for layer in 9:
			var ids: Array = layers[layer]
			if ids.is_empty():
				problems.append("e%d.L%d vazia" % [eon, layer])
			if layer in EonMap.CONVERGE and ids.size() != 1:
				problems.append("e%d.L%d devia ter 1 nó" % [eon, layer])
			if not (layer in EonMap.CONVERGE) and ids.size() < 2:
				problems.append("e%d.L%d sem escolha" % [eon, layer])
			for id in ids:
				var n := EonMap.find(String(id))
				if int(n.screen) != RunManager.FIRST_EON_SCREEN + eon * RunManager.EON_LEN + layer:
					problems.append("%s tela %d" % [id, int(n.screen)])
				if RunManager.eon_offset(int(n.screen)) != layer:
					problems.append("%s offset" % id)
				if layer < 8 and (n.next as Array).is_empty():
					problems.append("%s sem saída" % id)
				for nx in n.next:
					if int(EonMap.find(String(nx)).layer) != layer + 1:
						problems.append("%s→%s pula camada" % [id, nx])
		# Alcance: com pulo duplo, todo nó; sem pulo duplo, o Arconte, sem beco.
		var all_reach := _reach(g, true)
		for layer in 9:
			for id in layers[layer]:
				if not all_reach.has(id):
					problems.append("%s inalcançável" % id)
		var free_reach := _reach(g, false)
		if not free_reach.has(EonMap.node_id(eon, 8, 1)):
			problems.append("e%d: Arconte só com pulo duplo" % eon)
		for id in free_reach:
			var n := EonMap.find(String(id))
			if int(n.layer) >= 8:
				continue
			var ok := false
			for nx in n.next:
				if String(EonMap.find(String(nx)).requires) == "":
					ok = true
			if not ok:
				problems.append("%s: beco sem pulo duplo" % id)
	check(problems.is_empty(), "grafo dos 7 Éons consistente %s" % str(problems))
	# Variedade: cada Éon tem pelo menos 4 tipos de escolha, 1 Arena e 1 segredo.
	var poor: Array = []
	for eon in 7:
		var kinds := {}
		for id in EonMap.graph(eon).nodes:
			kinds[String(EonMap.find(String(id)).kind)] = true
		if kinds.size() < 8 or not kinds.has("challenge") or not kinds.has("secret"):
			poor.append("e%d=%s" % [eon, str(kinds.keys())])
	check(poor.is_empty(), "todo Éon tem combate/perigo/escalada/santuário/Arena/segredo %s" % str(poor))
	# Compatibilidade dos beats: slot ↔ tela legada.
	var bad_slot: Array = []
	for s in range(1, RunManager.MAX_SCREEN + 1):
		if RunManager.screen_for_slot(RunManager.beat_slot(s)) != s:
			bad_slot.append(s)
	check(bad_slot.is_empty() and RunManager.beat_slot(17) == "e1.L6", "tabela de compatibilidade de beats (slot ↔ tela) %s" % str(bad_slot))


func _reach(g: Dictionary, with_dj: bool) -> Dictionary:
	var seen := {}
	var start := String((g.layers as Array)[0][0])
	var stack: Array = [start]
	while not stack.is_empty():
		var id := String(stack.pop_back())
		if seen.has(id):
			continue
		seen[id] = true
		for nx in EonMap.find(id).next:
			if with_dj or String(EonMap.find(String(nx)).requires) == "":
				stack.append(String(nx))
	return seen


# --- 2. planos --------------------------------------------------------------------

func _plan_checks() -> void:
	RunManager.begin()
	RunManager.run_active = true
	var bad: Array = []
	var kinds_seen := {}
	for eon in 7:
		for id in EonMap.graph(eon).nodes:
			var n := EonMap.find(String(id))
			RunManager.current_screen = int(n.screen)
			RunManager.current_node = String(id)
			var kind := RunManager.node_kind()
			kinds_seen[kind] = true
			if kind != String(n.kind):
				bad.append("%s kind=%s" % [id, kind])
			var plan: Array = RunManager.zone_plan(int(n.screen))
			if plan.is_empty():
				bad.append("%s sem plano" % id)
				continue
			if kind in ["hazard", "platform", "sanctuary", "challenge", "secret"] and plan.size() != 2:
				bad.append("%s %d zonas" % [id, plan.size()])
			for zone in plan:
				if (zone as Array).is_empty():
					bad.append("%s zona vazia" % id)
				for wave in zone:
					if (wave as Array).is_empty():
						bad.append("%s wave vazia" % id)
					for t in wave:
						if String(Bestiary.get_type(String(t)).get("id", "")) != String(t):
							bad.append("%s tipo %s" % [id, t])
			# O papel legado não muda (narrativa/HUD/regras por papel seguem).
			var legacy := String(EonMap.KINDS[String(n.kind)].role)
			if RunManager.screen_role(int(n.screen)) != legacy:
				bad.append("%s papel %s" % [id, RunManager.screen_role(int(n.screen))])
	check(bad.is_empty(), "planos de zona válidos em todos os nós (%d tipos)" % kinds_seen.size() + (" %s" % str(bad.slice(0, 8)) if not bad.is_empty() else ""))
	# Nó padrão = plano legado (rota do meio = jogo de antes).
	RunManager.current_node = ""
	RunManager.current_screen = 1
	var same := true
	for s in [3, 5, 12, 33, 59]:
		var leg: Array = RunManager.zone_plan(s)
		RunManager.current_screen = s
		RunManager.current_node = EonMap.default_id(RunManager.eon_index(s), RunManager.eon_offset(s))
		if str(RunManager.zone_plan(s)) != str(leg):
			same = false
		RunManager.current_node = ""
		RunManager.current_screen = 1
	check(same, "nó padrão (combate) = plano legado da tela")
	RunManager.end_run()


# --- 3. fluxo real (troca de cena) ---------------------------------------------------

class Flow extends Node:
	var errors: int = 0

	func check(c: bool, m: String) -> void:
		if c:
			print("QA PASS: ", m)
		else:
			errors += 1
			push_error("QA FAIL: " + m)

	func frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func scene_is(path_end: String, max_frames: int = 600) -> bool:
		for i in max_frames:
			await get_tree().process_frame
			_skip_dialogs()
			var cs := get_tree().current_scene
			if cs != null and String(cs.scene_file_path).ends_with(path_end):
				if not (cs is Level) or (cs as Level)._ready_done:
					return true
		return false

	func _skip_dialogs() -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		await _run()
		RunManager.end_run()
		if errors == 0:
			print("MAPQA: tudo verde")
		get_tree().quit(1 if errors > 0 else 0)

	func _run() -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.map_route_seed = -1
		# Chegada do Torpor (tela 2) → vencer → tela de mapa com 3 saídas.
		RunManager.current_screen = 2
		RunManager.current_node = ""
		RunManager.advance_and_reload()
		var on_map: bool = await scene_is("WorldMap.tscn")
		var opts := RunManager.options_after(RunManager.last_node, RunManager.current_screen)
		check(on_map and RunManager.choosing and RunManager.current_screen == 3 and opts.size() == 3,
			"chegada → tela de mapa com 3 caminhos (tela=%d opções=%s)" % [RunManager.current_screen, str(opts)])
		check(not RunManager.choose_node("e5.2a") and not RunManager.choose_node("lixo"), "escolha fora das saídas é recusada")
		var hazard := ""
		for id in opts:
			if String(EonMap.find(String(id)).kind) == "hazard":
				hazard = String(id)
		check(RunManager.choose_node(hazard), "escolhe a Passagem perigosa (%s)" % hazard)
		var on_lv: bool = await scene_is("Level01.tscn")
		var lv := get_tree().current_scene as Level
		check(on_lv and lv != null and lv.screen == 3 and RunManager.node_kind() == "hazard" and lv.zones.size() == 2,
			"a tela 3 carrega como PERIGO (kind=%s zonas=%d)" % [RunManager.node_kind(), lv.zones.size() if lv else -1])
		check(RunManager.screen_role(3) == "travel" and RunManager.beat_slot(3) == "e0.L1", "papel legado e slot de beat preservados")
		# Recompensa do perigo: +5 vida máx. ao vencer.
		var hp0 := Progression.bonus_max_health
		RunManager.advance_and_reload()
		await scene_is("WorldMap.tscn")
		check(Progression.bonus_max_health == hp0 + 5 and int(RunManager.last_reward.get("hp", 0)) == 5,
			"recompensa do perigo paga (+%d vida máx.)" % (Progression.bonus_max_health - hp0))
		# A trilha alta da camada 2 (escalada) e o cruzamento.
		var o2 := RunManager.options_after(RunManager.last_node, 4)
		check(o2.size() == 2 and o2.has("e0.2a"), "da trilha alta seguem 2 caminhos (%s)" % str(o2))
		RunManager.choose_node("e0.2a")
		await scene_is("Level01.tscn")
		# Morte na tela 4 → checkpoint 2 (chegada), rota cortada.
		RunManager.respawn_at_checkpoint()
		await scene_is("Level01.tscn")
		check(RunManager.current_screen == 2 and RunManager.current_node == "e0.0b" and RunManager.path[RunManager.path.size() - 1] == "e0.0b"
			and not RunManager.path.has("e0.2a"), "morte volta à chegada com a rota cortada (%s)" % str(RunManager.path))
		# Segredo trancado sem pulo duplo (Éon 0, camada 6).
		RunManager.current_screen = 7     # camada 5, trilha alta
		RunManager.current_node = "e0.5a"
		RunManager.last_node = "e0.5a"
		RunManager.current_screen = 8
		RunManager.choosing = true
		var o6 := RunManager.options_after("e0.5a", 8)
		check(o6.has("e0.6a") and not RunManager.node_available("e0.6a") and not RunManager.choose_node("e0.6a"),
			"sala secreta trancada sem o pulo duplo (%s)" % str(o6))
		check(RunManager.available_options("e0.5a", 8).size() >= 1, "sempre há uma saída livre")
		# Snapshot / continuar (rota até o checkpoint).
		RunManager.choose_node("e0.6b")
		await scene_is("Level01.tscn")
		var snap := RunManager.run_snapshot()
		check(int(snap.screen) == 6 and String(snap.node) == "e0.4b" and int(snap.map_v) == 1 and not (snap.path as Array).has("e0.6b"),
			"snapshot grava a rota até o checkpoint (tela=%s nó=%s rota=%s)" % [str(snap.screen), str(snap.node), str(snap.path)])
		RunManager.saved_run = snap
		RunManager.run_active = false
		RunManager.continue_run()
		await scene_is("Level01.tscn")
		check(RunManager.current_screen == 6 and RunManager.current_node == "e0.4b" and RunManager.path.has("e0.0b"),
			"continuar retoma no Desafio com a rota (%s)" % str(RunManager.path))
		# Save ANTIGO (sem bloco de mapa): migra pro nó padrão do checkpoint.
		RunManager.saved_run = {"screen": 15, "orbs": 50, "difficulty": 1}
		RunManager.run_active = false
		RunManager.continue_run()
		await scene_is("Level01.tscn")
		check(RunManager.current_screen == 15 and RunManager.current_node == "e1.4b" and str(RunManager.path) == str(["e1.4b"]),
			"save antigo migra (tela 15 → nó e1.4b, rota %s)" % str(RunManager.path))
		# Save com rota estragada: ids ruins e fora de ordem são descartados.
		RunManager.saved_run = {"screen": 15, "map_v": 1, "path": ["e1.0b", "xx", 7, "e1.3c", "e1.2a", "e1.6a"]}
		RunManager.run_active = false
		RunManager.continue_run()
		await scene_is("Level01.tscn")
		check(str(RunManager.path) == str(["e1.0b", "e1.3c", "e1.4b"]), "rota estragada no save é limpa (%s)" % str(RunManager.path))
		# Rota automática (bot): determinística por semente, nunca abre o mapa.
		var r1 := await _auto_route(7)
		var r2 := await _auto_route(7)
		var r0 := await _auto_route(0)
		var mids := r0.filter(func(id): return int(EonMap.find(String(id)).row) == 1)
		check(r1.size() == 9 and str(r1) == str(r2), "rota automática semente 7 é determinística (%s)" % str(r1))
		check(mids.size() == r0.size(), "semente 0 = sempre a trilha do meio (%s)" % str(r0))
		var secret := r1.filter(func(id): return String(EonMap.find(String(id)).kind) == "secret")
		check(secret.is_empty(), "o bot sem pulo duplo nunca entra em segredo")
		RunManager.map_route_seed = -1

	## Percorre o Éon 0 inteiro com a rota automática (sem jogar: avança direto).
	func _auto_route(seed: int) -> Array:
		Progression.reset_run()
		RunManager.begin()
		RunManager.map_route_seed = seed
		RunManager.current_screen = 2
		RunManager.current_node = "e0.0b"
		RunManager.path.assign(["e0.0b"])
		for i in 8:
			RunManager.advance_and_reload()
			await frames(2)
			var cs := get_tree().current_scene
			if cs != null and String(cs.scene_file_path).ends_with("WorldMap.tscn"):
				check(false, "rota automática abriu a tela de mapa")
				break
		await scene_is("Level01.tscn")
		return RunManager.path_in_eon(0)
