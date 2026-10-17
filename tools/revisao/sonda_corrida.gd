extends Node
## SONDA DE REVISÃO (não faz parte do jogo): corrida "morte da Sophia x queda
## do chefe" numa tela de Arconte. Prova o que acontece quando os dois morrem
## em sequência curta (ex.: Esfera Solar/veneno ainda no ar depois da queda).
## Uso: godot --headless --audio-driver Dummy --path . res://tools/revisao/SondaCorrida.tscn -- <tela> <a|b>
##   a = Sophia morre primeiro, chefe cai 20 frames depois (< 1,5 s do renascer)
##   b = chefe cai e a Sophia morre no MESMO frame

func _ready() -> void:
	var w := Worker.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.screen = int(args[0])
	if args.size() >= 2:
		w.mode = args[1]
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var screen: int = 10
	var mode: String = "a"
	var _f: int = 0
	var _boss_seen: int = -1
	var _killed_player: int = -1
	var _killed_boss: bool = false
	var _shop_seen: int = -1
	var _last := ""
	var _stable: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _log(msg: String) -> void:
		print("CORRIDA f=%d %s" % [_f, msg])

	func _process(_d: float) -> void:
		_f += 1
		# Diálogos: escolhe a 1ª opção / fecha (como o Shot).
		for c in get_tree().root.get_children():
			if c is DialogueBox and c.is_node_ready():
				var fala: String = ""
				if c.lines.size() > 0:
					fala = String(c.lines[0].get("text", "")).substr(0, 50)
				_log("dialogo fechado: '%s'" % fala)
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
		var cs := get_tree().current_scene
		var lv: Level = cs as Level
		var estado := "cena=%s tela_run=%d tela_level=%s pending_advance=%s aneis=%s run_active=%s" % [
			cs.name if cs else "-", RunManager.current_screen, str(lv.screen) if lv else "-",
			str(RunManager.pending_advance), str(Progression.rings), str(RunManager.run_active)]
		if estado != _last:
			_log(estado)
			_last = estado
			_stable = 0
		else:
			_stable += 1
		if lv == null:
			return
		var boss: Enemy = null
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.is_boss_enemy and e.estate != Enemy.EState.DEAD:
				boss = e
		if boss != null and _boss_seen < 0 and not _killed_boss:
			_boss_seen = _f
			_log("chefe presente: " + String(boss.type_id))
		var pl: Player = lv.player
		# Leva a Sophia ao gatilho da zona (o jogador andaria até lá).
		if lv.zone_index < 0 and lv._ready_done and pl != null:
			pl.global_position = Vector2(lv.zone_center(0) - Level.ZONE_TRIGGER + 8.0, 250.0)
		if _boss_seen > 0 and not _killed_boss and _f - _boss_seen >= 120:
			if mode == "b":
				_log("MATA chefe e Sophia no mesmo frame")
				boss._on_hit_received(boss.health.max_health + 999, pl.global_position, 10.0, false, null)
				pl.health.take_damage(99999)
				_killed_boss = true
			elif _killed_player < 0:
				_log("MATA a Sophia")
				pl.health.take_damage(99999)
				_killed_player = _f
			elif _f - _killed_player >= 20 and boss != null:
				_log("MATA o chefe (golpe em voo)")
				boss._on_hit_received(boss.health.max_health + 999, pl.global_position, 10.0, false, null)
				_killed_boss = true
		# Loja pós-chefe: o jogador "lê" por 200 frames antes de fechar.
		for c in lv.get_children():
			if c is CanvasLayer and c.has_method("_close") and c.has_method("_buy_heal"):
				if _shop_seen < 0:
					_shop_seen = _f
					_log("LOJA pós-chefe aberta (pending_advance=%s)" % str(RunManager.pending_advance))
				elif _f - _shop_seen == 200:
					_log("fechando a loja")
					c._close()
		if _killed_boss and _stable > 240:
			_log("FINAL: tela_run=%d tela_level=%d aneis=%s snapshot.screen=%s" % [RunManager.current_screen, lv.screen, str(Progression.rings), str(RunManager.run_snapshot().get("screen"))])
			get_tree().quit()
		if _f > 6000:
			_log("TIMEOUT")
			get_tree().quit()
