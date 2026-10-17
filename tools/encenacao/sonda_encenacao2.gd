extends Node
## FERRAMENTA (não faz parte do jogo): sonda headless da Encenação 2.
## Uso: godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/encenacao/SondaEncenacao2.tscn
## Imprime "SONDA|<item>|PASS/FAIL|detalhe" para:
##  - tela 68: a fala de chegada da Mente entra na caixa do final_pre (e não vira legenda);
##  - tela 10: o Arconte está no palco durante a tentação e o card só vem no gatilho;
##  - tela 63: o Elite da antessala da Coroa não é o Invocador.

func _ready() -> void:
	get_tree().root.add_child.call_deferred(_W.new())


## O trabalho roda num nó filho do ROOT (sobrevive à troca de cena).
class _W extends Node:
	var _fails: int = 0


	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		AudioServer.set_bus_mute(0, true)
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()


	func _check(item: String, ok: bool, det: String) -> void:
		if not ok:
			_fails += 1
		print("SONDA|%s|%s|%s" % [item, "PASS" if ok else "FAIL", det])


	func _goto(s: int) -> void:
		# Sobras da tela anterior (card de chefe, caixa) não contam para a próxima.
		for c in get_tree().root.get_children():
			if c is Cinematic or c is DialogueBox:
				c.queue_free()
		await get_tree().process_frame
		PauseStack.clear()
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = s
		GameManager.current_screen = s
		get_tree().change_scene_to_file("res://scenes/levels/Level01.tscn")
		for _i in 4:
			await get_tree().process_frame


	func _box() -> DialogueBox:
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				return c
		return null


	func _run() -> void:
		# 1) Mente (68): a fala de chegada entra na caixa.
		await _goto(68)
		var d: DialogueBox = null
		for _i in 60:
			d = _box()
			if d != null:
				break
			await get_tree().process_frame
		var arr: String = String(Narrative.walk_arrival(68)[0].text)
		var in_box := false
		if d != null:
			for l in d.lines:
				if String(l.get("text", "")) == arr:
					in_box = true
		_check("mente_chegada_na_caixa", in_box, "caixa=%s" % ("sim" if d != null else "não"))
		if d != null:
			d._finish()
		for _i in 30:
			await get_tree().process_frame
		var cap = Gnosis.get("_caption")
		var queued: Array = cap.get("_queue") if cap != null else []
		var showing := cap != null and bool(cap.get("_showing"))
		var cap_txt := String(cap.get("_text").text) if showing else ""
		var as_caption := cap_txt == arr
		for q in queued:
			if String(q.get("text", "")) == arr:
				as_caption = true
		_check("mente_chegada_nao_e_legenda", not as_caption, "fila=%d mostrando='%s'" % [queued.size(), cap_txt.left(40)])

		# 2) Tentação em cena (10).
		await _goto(10)
		d = null
		for _i in 60:
			d = _box()
			if d != null:
				break
			await get_tree().process_frame
		var boss: Enemy = null
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.is_boss_enemy:
				boss = e
		_check("tentacao_arconte_em_cena", d != null and boss != null and boss.visible, "caixa=%s chefe=%s" % [str(d != null), str(boss.type_id) if boss != null else "-"])
		var cine_early := false
		for c in get_tree().root.get_children():
			if c is Cinematic:
				cine_early = true
		_check("tentacao_sem_card_antes_da_escolha", not cine_early, "")
		# Fecha a tentação e a resposta.
		for _i in 200:
			d = _box()
			if d == null:
				break
			if d.choices.size() > 0:
				d._on_choice(0)
			else:
				d._finish()
			await get_tree().process_frame
		for _i in 20:
			await get_tree().process_frame
		var lv: Level = get_tree().current_scene as Level
		var bx := boss.global_position.x if is_instance_valid(boss) else 0.0
		for _i in 30:
			await get_tree().process_frame
		var still := is_instance_valid(boss) and absf(boss.global_position.x - bx) < 1.0
		_check("arconte_espera_ate_o_gatilho", still and lv.zone_index < 0, "zona=%d moveu=%s" % [lv.zone_index, str(not still)])
		lv.player.global_position.x = lv.zone_center(0) - Level.ZONE_TRIGGER + 8.0
		var card := false
		for _i in 30:
			await get_tree().process_frame
			for c in get_tree().root.get_children():
				if c is Cinematic:
					card = true
			if card:
				break
		var same := lv.zone_index == 0 and is_instance_valid(boss) and boss.process_mode == Node.PROCESS_MODE_INHERIT
		var bosses := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.is_boss_enemy:
				bosses += 1
		_check("gatilho_acorda_o_mesmo_arconte_com_card", card and same and bosses == 1 and lv.alive == 1, "card=%s mesmo=%s chefes=%d vivos=%d" % [str(card), str(same), bosses, lv.alive])
		PauseStack.clear()
		get_tree().paused = false

		# 3) Antessala da Coroa (63): o Elite não é o Invocador.
		await _goto(63)
		for _i in 60:
			var bb := _box()
			if bb != null:
				bb._finish()
			await get_tree().process_frame
		lv = get_tree().current_scene as Level
		var plan: Array = lv.zones
		var last_wave: Array = plan[plan.size() - 1][(plan[plan.size() - 1] as Array).size() - 1]
		# Vai à última zona e à última wave.
		lv.player.global_position.x = lv.zone_center(plan.size() - 1) - Level.ZONE_TRIGGER + 8.0
		for _i in 10:
			await get_tree().process_frame
		lv.wave_index = (plan[plan.size() - 1] as Array).size() - 1
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		await get_tree().process_frame
		lv._start_wave()
		await get_tree().process_frame
		var elite_type := "-"
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.is_elite and not e.is_queued_for_deletion():
				elite_type = String(e.type_id)
		_check("antessala_coroa_elite_nao_invocador", elite_type != "-" and elite_type != "invocador", "wave=%s elite=%s" % [str(last_wave), elite_type])

		print("SONDA|fim|%s|%d falha(s)" % ["PASS" if _fails == 0 else "FAIL", _fails])
		get_tree().quit()
