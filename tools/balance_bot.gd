extends Node
## FERRAMENTA (não faz parte do jogo): BOT DE BALANCE. Joga o run inteiro
## sozinho (IA simples: persegue, bate, esquiva telegrafos, usa magias, compra
## na loja) e mede POR TELA: tempo, dano tomado e "quase-mortes" (vida < 25% →
## conta 1 morte e cura cheia, pra run nunca parar). No fim imprime a tabela
## com a curva de dificuldade e avisos (HOT = dano demais, COLD = de menos).
## Com as TRAVESSIAS (r4): sem inimigo vivo e tela ainda não limpa, o bot ANDA
## pra direita até o gatilho da próxima zona; o timeout é por ZONA parada.
## Uso: godot --path . res://tools/BalanceBot.tscn -- [tela_ini] [tela_fim] [vel]
##   vel = multiplicador de velocidade (padrão 3; Juice.speed_mult).

func _ready() -> void:
	var w := BalanceWorker.new()
	w.last_screen = RunManager.MAX_SCREEN
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.first_screen = int(args[0])
	if args.size() >= 2:
		w.last_screen = int(args[1])
	if args.size() >= 3:
		w.speed = float(args[2])
	get_tree().root.add_child.call_deferred(w)


class BalanceWorker extends Node:
	var first_screen: int = 1
	var last_screen: int = 68
	var speed: float = 3.0

	const ZONE_TIMEOUT := 100.0        # s de jogo numa zona sem limpar = travada
	const LOW_HP := 0.45               # abaixo disso: conta morte e cura cheia
	                                   # (alto o bastante pra um golpe não matar
	                                   # o medidor antes da cura — morte real ainda
	                                   # encerra o run e aparece no relatório)
	var _idle_clear: float = 0.0       # s com a tela limpa sem conseguir avançar
	var _zone_t: float = 0.0           # s na zona atual (timeout por zona)
	var _zone_cur: int = -2            # zona em andamento (detecta troca)
	var _zones: int = 1                # zonas da tela atual (pro relatório)

	var _cur: int = -1
	var _rows: Array = []              # {screen, time, dmg, deaths, timeout}
	var _t: float = 0.0
	var _dmg: int = 0
	var _deaths: int = 0
	var _timeout: bool = false
	var _last_hp: int = -1
	var _atk_t: float = 0.0
	var _atk_i: int = 0
	var _dodge_cd: float = 0.0
	var _cast_t: float = 0.0
	var _done: bool = false
	var _beat: float = 0.0             # heartbeat de progresso no stdout
	# padrão de golpes do bot: mistura strings reais (LLL, LLH, HH, LLLH)
	const PATTERN := ["light", "light", "light", "heavy", "light", "light", "heavy", "heavy", "heavy"]

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false   # ferramenta não suja o save real
		Juice.speed_mult = speed
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		RunManager.current_screen = first_screen
		GameManager.current_screen = first_screen
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(delta: float) -> void:
		if _done:
			return
		# heartbeat: prova de vida no stdout a cada ~5 s reais
		_beat += delta / maxf(0.1, Engine.time_scale)
		if _beat > 5.0:
			_beat = 0.0
			var php := -1
			var pn := get_tree().get_first_node_in_group("player")
			if pn != null and pn.health != null:
				php = pn.health.current_health
			print("BAT tela=%d t=%.0fs dmg=%d hp=%d cena=%s" % [RunManager.current_screen, _t, _dmg, php, str(get_tree().current_scene)])
		# 1) pula diálogos (escolha padrão = Recusar / 1º final)
		var had_dialog := false
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
				had_dialog = true
		if had_dialog:
			return
		# 2) loja pós-chefe: compra o que der (emula progressão real) e fecha
		var cs := get_tree().current_scene
		if cs == null:
			return
		for c in cs.get_children():
			if c is CanvasLayer and c.has_method("_close"):
				_auto_shop()
				c._close()
				return
		# 3) fim do run (vitória ou passou da última tela pedida)
		if not RunManager.run_active or RunManager.current_screen > last_screen:
			_finish("fim do run (tela %d)" % RunManager.current_screen)
			return
		var pl: Player = get_tree().get_first_node_in_group("player")
		if pl == null or pl.health == null:
			return
		# 4) troca de tela: fecha a linha anterior
		if RunManager.current_screen != _cur:
			_flush_row()
			_cur = RunManager.current_screen
			_last_hp = pl.health.current_health
			_zone_cur = -2
			_zone_t = 0.0
		_t += delta
		var lv0 := get_tree().current_scene
		if lv0 is Level:
			_zones = maxi(1, lv0.zones.size())
			if lv0.zone_index != _zone_cur:
				_zone_cur = lv0.zone_index
				_zone_t = 0.0
		_zone_t += delta
		# 5) medição de dano/quase-morte
		var hp := pl.health.current_health
		if hp < _last_hp:
			_dmg += _last_hp - hp
		_last_hp = hp
		if pl.state != Player.State.DEAD and hp < int(pl.health.max_health * LOW_HP):
			_deaths += 1
			pl.health.heal(pl.health.max_health)
			_last_hp = pl.health.current_health
		# 6) timeout da ZONA: mata o que está vivo (uma vez) pra seguir medindo
		# as outras zonas/telas. (SEM return: o bot ainda precisa andar depois.)
		if _zone_t > ZONE_TIMEOUT:
			_zone_t = 0.0
			_timeout = true
			print("BAT TIMEOUT na tela %d zona %d — matando a zona" % [_cur, _zone_cur])
			# Diagnóstico: quem estava vivo e onde (pra achar stalls determinísticos).
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) and e.estate != Enemy.EState.DEAD:
					print("BAT   vivo: %s hp=%d pos=(%.0f,%.0f) estado=%s range=%.0f cd=%.2f" % [e.type_id, e.health.current_health, e.global_position.x, e.global_position.y, Enemy.EState.keys()[e.estate], e.attack_range, e.cooldown_timer])
					e._on_hit_received(e.health.max_health + 9999, pl.global_position, 10.0, false, null)
			print("BAT   player: pos=(%.0f,%.0f) estado=%s cd=%.2f chao=%s" % [pl.global_position.x, pl.global_position.y, Player.State.keys()[pl.state], pl.attack_cd, str(pl.is_on_floor())])
		_drive(pl, delta)

	## A "mão" do bot: anda até o inimigo mais perto, bate, esquiva, conjura.
	func _drive(pl: Player, delta: float) -> void:
		_dodge_cd = maxf(0.0, _dodge_cd - delta)
		_cast_t += delta
		var target: Enemy = null
		var best := INF
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or not e is Enemy or e.estate == Enemy.EState.DEAD:
				continue
			var d: float = absf(e.global_position.x - pl.global_position.x)
			if d < best:
				best = d
				target = e
		if target == null:
			Input.action_release("move_left")
			Input.action_release("move_right")
			var lv := get_tree().current_scene
			# Tela limpa: anda até a fenda (se existir, o bot "entra" nela).
			for c in lv.get_children():
				if c is ExitPortal:
					pl.global_position = c.global_position + Vector2(0, -20)
			# Travessia: ainda há zonas à frente → ANDA pra direita até o gatilho.
			var zones_left: bool = lv is Level and not lv.zone_active and lv.zone_index + 1 < lv.zones.size()
			if zones_left:
				Input.action_press("move_right")
			_idle_clear += delta
			if zones_left and _idle_clear > 25.0:
				# Rede de segurança: preso no caminho → salta pro gatilho da zona.
				print("BAT zona forcada (tela %d, bot preso em x=%.0f)" % [_cur, pl.global_position.x])
				_idle_clear = 0.0
				pl.global_position = Vector2(lv.zone_center(lv.zone_index + 1) - Level.ZONE_TRIGGER + 8.0, 250.0)
			elif not zones_left and _idle_clear > 14.0 and lv is Level and lv.has_method("_advance_via_exit"):
				# Rede de segurança: limpa há tempo demais sem avançar → força a saída.
				print("BAT avanco forcado (tela %d presa limpa)" % _cur)
				_idle_clear = 0.0
				lv._advance_via_exit()
			return
		_idle_clear = 0.0
		var dx := target.global_position.x - pl.global_position.x
		# esquiva quando o golpe está armado perto (telegrafo)
		if _dodge_cd <= 0.0 and target.estate == Enemy.EState.WINDUP and absf(dx) < 150.0:
			Input.action_press("dodge")
			_release_later("dodge")
			_dodge_cd = 1.4
			return
		# aproxima
		if absf(dx) > 60.0:
			Input.action_release("move_left" if dx > 0 else "move_right")
			Input.action_press("move_right" if dx > 0 else "move_left")
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
			# vira pro alvo com um toquinho de direção
			if signf(dx) != float(pl.facing) and dx != 0.0:
				var a := "move_right" if dx > 0 else "move_left"
				Input.action_press(a)
				_release_later(a)
		# magias: Esfera Solar quando sobra Éter; o Anel equipado de vez em quando
		if _cast_t > 3.0 and pl.mana >= 24.0:
			_cast_t = 0.0
			Input.action_press("skill2")
			_release_later("skill2")
		# golpes em cadência
		_atk_t += delta
		if absf(dx) < 90.0 and _atk_t > 0.30:
			_atk_t = 0.0
			var btn: String = PATTERN[_atk_i % PATTERN.size()]
			_atk_i += 1
			var act := "attack_light" if btn == "light" else "attack_heavy"
			Input.action_press(act)
			_release_later(act)

	func _release_later(a: String) -> void:
		await get_tree().create_timer(0.05, true, false, true).timeout
		Input.action_release(a)

	func _auto_shop() -> void:
		if Progression.can_upgrade_weapon():
			Progression.upgrade_weapon()
		var ch: CharacterData = GameManager.selected_character
		if ch != null:
			for sk in ch.skills:
				if Progression.is_skill_unlocked(sk.id) and Progression.skill_level(sk.id) < sk.max_level \
						and Progression.orbs >= Progression.skill_upgrade_cost(sk.id) + 150:
					Progression.upgrade_skill(sk)

	func _flush_row() -> void:
		if _cur > 0:
			_rows.append({"screen": _cur, "time": _t, "dmg": _dmg, "deaths": _deaths, "timeout": _timeout, "zones": _zones})
		_t = 0.0
		_dmg = 0
		_deaths = 0
		_timeout = false
		_zones = 1

	func _finish(reason: String) -> void:
		_done = true
		_flush_row()
		var lines: Array[String] = []
		lines.append("BALANCE — %s | arma final nv.%d | faíscas sobrando %d" % [reason, Progression.weapon_level, Progression.orbs])
		lines.append("tela | zonas | tempo(s) | dano | mortes | avisos")
		var tot_t := 0.0
		var tot_d := 0
		var tot_m := 0
		for r in _rows:
			var warn := ""
			if r.timeout: warn += " TIMEOUT"
			if r.dmg >= 70: warn += " HOT"
			elif r.dmg <= 3 and r.screen > 3: warn += " COLD"
			if r.time > 45.0 + 60.0 * float(r.zones) and not r.timeout: warn += " SLOW"
			lines.append("%4d | %5d | %8.1f | %4d | %6d |%s" % [r.screen, r.zones, r.time, r.dmg, r.deaths, warn])
			tot_t += r.time
			tot_d += int(r.dmg)
			tot_m += int(r.deaths)
		lines.append("TOTAL: %.1f min de jogo | %d de dano | %d mortes" % [tot_t / 60.0, tot_d, tot_m])
		var f := FileAccess.open("user://balance.txt", FileAccess.WRITE)
		for l in lines:
			print("BAL ", l)
			if f:
				f.store_line(l)
		if f:
			f.close()
		get_tree().quit()
