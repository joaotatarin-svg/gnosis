extends Node
## FERRAMENTA (Combate2): regras de travessia (#41), números de dano (opção),
## sombra de contato presa ao chão e contorno de leitura (R18).
## godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/combate/RuleProbe.tscn
## Saída: "RULEPROBE|..." + "QA PASS/FAIL".

func _ready() -> void:
	var w := P.new()
	get_tree().root.add_child.call_deferred(w)


class P extends Node:
	var errors: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func check(ok: bool, msg: String) -> void:
		if ok:
			print("QA PASS: ", msg)
		else:
			errors += 1
			push_error("QA FAIL: " + msg)

	func key(k: Key, hold: float = 0.06) -> void:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = true
		Input.parse_input_event(e)
		await wait(hold)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await wait(0.15)

	func skip_dialogs() -> void:
		for i in 40:
			var d: DialogueBox = null
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					d = c
			if d == null:
				return
			await key(KEY_ENTER if d._in_choices else KEY_J)

	func level_at(screen: int) -> void:
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		await wait(0.8)
		await skip_dialogs()
		await wait(0.4)

	func _run() -> void:
		# --- 1. qual regra vale em cada tela (determinístico) ---
		RunManager.begin()
		var found: Dictionary = {}
		for s in range(1, RunManager.MAX_SCREEN + 1):
			var k := EonRule.rule_for(s)
			if k != "":
				found[s] = k
		print("RULEPROBE|telas_com_regra=%s" % str(found))
		check(found == {7: "torpor", 25: "corrente"}, "regra só na tela 7 (Torpor) e 25 (Corrente)")

		# --- 2. Torpor: a névoa nasce na tela 7 ---
		await level_at(7)
		var lv := get_tree().current_scene
		var r7 = lv.get_node_or_null("EonRule")
		check(r7 != null and r7.kind == "torpor", "tela 7 liga a névoa do Torpor")
		check(r7 != null and r7.z_index < VfxLibrary.Z, "a névoa fica abaixo dos VFX (telegrafo passa por cima)")
		await level_at(6)
		check(get_tree().current_scene.get_node_or_null("EonRule") == null, "tela 6 (travessia comum) não tem regra")

		# --- 3. Corrente: a varredura prende a Sophia (e esquiva escapa) ---
		await level_at(25)
		lv = get_tree().current_scene
		var r25 = lv.get_node_or_null("EonRule")
		check(r25 != null and r25.kind == "corrente", "tela 25 liga as correntes")
		var pl: Player = lv.player
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		await wait(0.3)
		if r25 != null and pl != null:
			# Uma corrente sobre a Sophia, no meio da varredura.
			r25._chains = [{"x": pl.global_position.x, "side": -1.0, "timer": EonRule.CHAIN_SWING * 0.5, "phase": "swing", "hit": []}]
			r25._zone_seen = int(lv.get("zone_index"))
			var hp0: int = pl.health.current_health
			await wait(0.15)
			print("RULEPROBE|corrente|root=%.2f hp %d→%d" % [pl.root_timer, hp0, pl.health.current_health])
			check(pl.root_timer > 0.0, "a ponta da corrente prende a Sophia")
			check(pl.health.current_health < hp0, "a corrente fere de leve")
			# Esquivando (i-frames), não prende.
			await wait(1.5)
			pl.root_timer = 0.0
			pl.invuln_timer = 1.0
			r25._chains = [{"x": pl.global_position.x, "side": 1.0, "timer": EonRule.CHAIN_SWING * 0.5, "phase": "swing", "hit": []}]
			await wait(0.15)
			check(pl.root_timer <= 0.0, "esquiva (i-frames) escapa da corrente")
			# O tiro de corrente da Galila/Carcereiro (Projectile.root_time) prende
			# mesmo com o dano ligando os i-frames (antes nunca prendia).
			await wait(1.2)
			pl.invuln_timer = 0.0
			pl.root_timer = 0.0
			var pr := Projectile.new()
			pr.direction = -1
			pr.speed = 200.0
			pr.damage = 3
			pr.pierce = false
			pr.target_team = "player"
			pr.root_time = 1.1
			lv.add_child(pr)
			pr.global_position = pl.global_position + Vector2(30, 0)
			await wait(0.4)
			print("RULEPROBE|tiro_corrente|root=%.2f" % pl.root_timer)
			check(pl.root_timer > 0.0, "o tiro de corrente da Galila prende a Sophia")

		# --- 4. Números de dano respeitam a opção ---
		var holder := Node2D.new()
		lv.add_child(holder)
		GameManager.settings["damage_numbers"] = false
		DamageNumber.spawn(holder, Vector2(100, 100), 12, Color.WHITE)
		var n_off := holder.get_child_count()
		GameManager.settings["damage_numbers"] = true
		DamageNumber.spawn(holder, Vector2(100, 100), 12, Color.WHITE)
		var n_on := holder.get_child_count()
		GameManager.settings.erase("damage_numbers")
		DamageNumber.spawn(holder, Vector2(100, 100), 12, Color.WHITE)   # mesmo alvo: SOMA (R16)
		var n_sum := holder.get_child_count()
		DamageNumber.spawn(holder, Vector2(100, 100), 12, Color(1.0, 0.5, 0.5))   # outra cor: cria (padrão = ligado)
		var n_def := holder.get_child_count()
		print("RULEPROBE|numeros|off=%d on=%d soma=%d padrao=%d" % [n_off, n_on, n_sum, n_def])
		# R16: o 2º número no mesmo alvo e no mesmo instante SOMA no que está vivo (n_sum = 1);
		# o padrão (opção ausente) segue LIGADO: um número de outra cor cria o 2º nó.
		check(n_off == 0 and n_on == 1 and n_sum == 1 and n_def == 2, "números de dano: desligado não cria, ligado/ausente cria, mesmo alvo soma")
		GameManager.settings["damage_numbers"] = true

		# --- 5. Sombra de contato presa ao chão e contorno ---
		var scn = load("res://scenes/entities/Enemy.tscn")
		var en: Enemy = scn.instantiate()
		en.type_id = "larva"
		lv.add_child(en)
		en.global_position = pl.global_position + Vector2(120, 0)
		await wait(0.8)
		var sh: Node2D = en.get_node("Shadow")
		var y_floor := sh.global_position.y
		check(en.get_node_or_null("Rim") != null and en.visual.get_parent().name == "Rim", "o desenho do inimigo mora no CanvasGroup do contorno")
		en.velocity.y = -420.0                 # lançado
		await wait(0.25)
		var up: float = en._floor_y - en.global_position.y
		print("RULEPROBE|sombra|chao=%.0f no_ar=%.0f subiu=%.0f escala=%.2f" % [y_floor, sh.global_position.y, up, sh.scale.x / en._shadow_scale.x])
		check(up > 20.0 and absf(sh.global_position.y - y_floor) < 2.0, "no ar a sombra fica no chão")
		check(sh.scale.x < en._shadow_scale.x, "no ar a sombra encolhe")
		en.health.take_damage(9999)
		await wait(0.05)
		check(en._rim_mat == null or float(en._rim_mat.get_shader_parameter("rim_strength")) == 0.0, "morto: contorno desligado (não contorna a dissolução)")

		print("RULEPROBE|fim|falhas=%d" % errors)
		get_tree().quit(1 if errors > 0 else 0)
