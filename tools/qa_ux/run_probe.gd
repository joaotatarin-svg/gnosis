extends Node
## SONDA DE QA-UX (não faz parte do jogo): joga UMA tela do run como um jogador
## faria — anda com move_right, briga com o inimigo mais perto (leve/forte/
## esquiva), e depois de alguns segundos de briga "limpa" a zona (pra o lote
## caber no tempo). Fecha loja/estela, pula diálogos (escolha 0), anda até a
## fenda. Enquanto isso VIGIA glitches e grava PNGs + uma linha de log por evento.
## Uso:
##   godot --audio-driver Dummy --path . --resolution 1280x720 --position 4000,4000 \
##     res://tools/qa_ux/RunProbe.tscn -- <tela> <pasta_saida> [segundos_max] [modo]
## modo: "fight" (padrão: briga 5 s por zona antes de limpar) · "fast" (limpa já)
##       "die" (deixa a Sophia morrer na 1ª zona e vê o checkpoint)
## Saída (prefixo QA| no stdout, pra grep):
##   QA|<tela>|EVT|<evento>|<detalhe>   ·   QA|<tela>|BUG?|<tipo>|<detalhe>
##   QA|<tela>|END|<resultado>|<tempo>|...

func _ready() -> void:
	var w := Probe.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.screen = int(args[0])
	if args.size() >= 2:
		w.out_dir = args[1]
	if args.size() >= 3:
		w.max_time = float(args[2])
	if args.size() >= 4:
		w.mode = args[3]
	get_tree().root.add_child.call_deferred(w)


class Probe extends Node:
	var screen: int = 2
	var out_dir: String = "user://qa"
	var max_time: float = 120.0
	var mode: String = "fight"

	var t: float = 0.0                 # tempo real de jogo (s)
	var _level: Level = null
	var _level_t: float = 0.0          # tempo desde que a tela ficou pronta
	var _zone_t: float = 0.0           # tempo com zona trancada
	var _last_zone: int = -2
	var _shots: Dictionary = {}        # nome -> já salvo
	var _dialogs: int = 0
	var _dialog_ids: Dictionary = {}
	var _shop_seen: int = 0
	var _stela_seen: int = 0
	var _bug_once: Dictionary = {}
	var _off_timer: Dictionary = {}    # inimigo -> tempo fora da arena
	var _atk_clock: float = 0.0
	var _atk_i: int = 0
	var _dmg_taken: int = 0
	var _last_hp: int = -1
	var _floor_min: float = 99999.0
	var _floor_max: float = -99999.0
	var _fps_sum: float = 0.0
	var _fps_n: int = 0
	var _done: bool = false
	var _portal_t: float = -1.0
	var _start_screen: int = 0
	var _died: bool = false
	var _boss_bar_max: int = 0
	var _idle_t: float = 0.0           # parado sem progresso (sem zona, sem inimigo, sem fenda)
	var _last_x: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		DirAccess.make_dir_recursive_absolute(out_dir)
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		_start_screen = screen
		# Anéis coerentes com a tela: os Arcontes já vencidos antes dela.
		for sk in GameContent.characters[0].skills:
			if sk.ring == "":
				continue
			var n: int = Bestiary.bosses.map(func(b): return b.id).find(sk.ring)
			var archon_screen: int = RunManager.FIRST_EON_SCREEN + (n + 1) * RunManager.EON_LEN - 1
			if n >= 0 and archon_screen < screen:
				Progression.add_ring(sk.ring, sk.id)
		if screen >= RunManager.CENTER_FIRST:
			Progression.steal_rings()
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func log_evt(kind: String, what: String, detail: String = "") -> void:
		print("QA|%d|%s|%s|%s|t=%.1f" % [screen, kind, what, detail, t])

	func bug(what: String, detail: String, shot: bool = true) -> void:
		if _bug_once.has(what):
			return
		_bug_once[what] = true
		log_evt("BUG?", what, detail)
		if shot:
			_save("bug_" + what)

	func _save(name: String) -> void:
		var img := get_viewport().get_texture().get_image()
		if img == null:
			return
		var p := "%s/s%02d_%s.png" % [out_dir, screen, name]
		img.save_png(p)
		log_evt("SHOT", name, p)

	func _shot_once(name: String) -> void:
		if _shots.has(name):
			return
		_shots[name] = true
		_save(name)

	func _physics_process(delta: float) -> void:
		if _done:
			return
		t += delta
		if Engine.get_frames_per_second() > 0:
			_fps_sum += Engine.get_frames_per_second()
			_fps_n += 1
		var tree := get_tree()
		# --- diálogos / painéis / cinematográficas ---------------------------
		for c in tree.root.get_children():
			if c is DialogueBox:
				var key := str(c.get_instance_id())
				if not _dialog_ids.has(key):
					_dialog_ids[key] = 0.0
					_dialogs += 1
					var first := ""
					if c.lines.size() > 0:
						first = str(c.lines[0]).substr(0, 70).replace("\n", " ")
					log_evt("EVT", "dialog", first)
				_dialog_ids[key] += delta
				# deixa 0,4 s na tela (pra captura), depois avança
				if _dialog_ids[key] > 0.4:
					if _dialogs == 1:
						_shot_once("dialog1")
					if c.choices.size() > 0 and c._in_choices:
						_shot_once("choices")
						c._on_choice(0)
					elif c.choices.size() > 0:
						c.idx = c.lines.size()
						c._show_line()
					else:
						c._finish()
				_release_all()
				return
			# painel de leitura da Estela (classe interna StelaPanel)
			if "entry" in c and "fresh" in c and c.has_signal("finished"):
				_stela_seen += 1
				_shot_once("stela_panel")
				c.finished.emit()
				c.queue_free()
				tree.paused = false
		var cs := tree.current_scene
		if cs == null:
			return
		# Mudou de tela? (fenda/loja/roubo avançaram)
		if RunManager.current_screen != _start_screen and not _died:
			_finish_ok("ADVANCED", "-> %d" % RunManager.current_screen)
			return
		if not cs is Level:
			# EndScreen (fim de jogo) ou outra cena
			if cs.scene_file_path.ends_with("EndScreen.tscn"):
				_shot_once("endscreen")
				_finish_ok("ENDSCREEN", cs.scene_file_path)
			return
		_level = cs
		# lojas (UpgradeMenu) como overlay
		for c in cs.get_children():
			if c is CanvasLayer and c.has_method("_close") and c.has_method("_rebuild"):
				_shop_seen += 1
				_shot_once("shop")
				_check_shop(c)
				c._close()
		if tree.paused:
			_release_all()
			return
		if not _level._ready_done:
			return
		_level_t += delta
		var pl: Player = _level.player
		if pl == null or pl.health == null:
			return
		if _level_t > 1.2:
			_shot_once("arrive")
		_watch(pl)
		if pl.health.is_dead():
			_release_all()
			if not _died:
				_died = true
				_shot_once("dead")
				log_evt("EVT", "player_dead", "")
			return
		# HP: em modo "die" não cura; senão mantém >= 40% (sonda não é balance).
		if mode != "die" and pl.health.current_health < pl.health.max_health * 0.4:
			pl.health.heal(pl.health.max_health)
		_drive(pl, delta)
		if t > max_time:
			_finish_fail()

	## Pilotagem: anda, briga, limpa, segue.
	func _drive(pl: Player, delta: float) -> void:
		var lv := _level
		var alive: Array = []
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.estate != Enemy.EState.DEAD:
				alive.append(e)
		if lv.zone_index != _last_zone:
			_last_zone = lv.zone_index
			_zone_t = 0.0
			if lv.zone_index >= 0:
				log_evt("EVT", "zone_start", "%d/%d" % [lv.zone_index + 1, lv.zones.size()])
		if lv.zone_active or (RunManager.is_final(lv.screen) and alive.size() > 0):
			_zone_t += delta
			_idle_t = 0.0
			if _zone_t > 1.5:
				_shot_once("fight%d" % lv.zone_index)
			var fight_for := 0.4 if mode == "fast" else 5.0
			if mode == "die":
				fight_for = 9999.0
			if _zone_t > fight_for:
				# limpa a wave viva (como o modo clear do Shot) a cada 1,5 s
				if fmod(_zone_t, 1.5) < delta:
					for e in alive:
						e._on_hit_received(e.health.max_health + 999, pl.global_position, 60.0, false, null)
			if mode == "die":
				_release_all()   # fica parada apanhando
				return
			_fight(pl, alive, delta)
			if _zone_t > 60.0:
				bug("zona_nao_termina", "zona %d ativa há 60 s, vivos=%d wave=%d/%d alive_var=%d" % [lv.zone_index, alive.size(), lv.wave_index, lv.waves.size(), lv.alive])
			return
		if alive.size() > 0 and not lv.zone_active:
			# inimigo vivo fora de zona (minion órfão / chefe) — briga mesmo assim
			_fight(pl, alive, delta)
			return
		_release("attack_light")
		_release("attack_heavy")
		# fenda aberta?
		var portal: Node2D = null
		for c in lv.get_children():
			if c is ExitPortal:
				portal = c
		if portal != null:
			if _portal_t < 0.0:
				_portal_t = t
				log_evt("EVT", "portal_open", "x=%.0f player_x=%.0f" % [portal.global_position.x, pl.global_position.x])
			if t - _portal_t > 0.6:
				_shot_once("portal")
		Input.action_release("move_left")
		Input.action_press("move_right")
		# progresso? (anda mas não sai do lugar = preso)
		if absf(pl.global_position.x - _last_x) < 0.5:
			_idle_t += delta
		else:
			_idle_t = 0.0
		_last_x = pl.global_position.x
		if _idle_t > 6.0:
			bug("preso_andando", "x=%.0f y=%.0f zona=%d/%d portal=%s end_x=%.0f" % [pl.global_position.x, pl.global_position.y, lv.zone_index, lv.zones.size(), str(portal != null), lv._end_x])
			if _idle_t > 8.0 and portal == null and lv.zone_index >= lv.zones.size() - 1:
				_finish_fail()

	## Briga simples: vai até o inimigo mais perto e bate (leve, leve, forte), esquiva às vezes.
	func _fight(pl: Player, alive: Array, delta: float) -> void:
		if alive.is_empty():
			_release_all()
			return
		var best: Node2D = alive[0]
		for e in alive:
			if e.global_position.distance_to(pl.global_position) < best.global_position.distance_to(pl.global_position):
				best = e
		var dx: float = best.global_position.x - pl.global_position.x
		if absf(dx) > 46.0:
			Input.action_press("move_right" if dx > 0 else "move_left")
			Input.action_release("move_left" if dx > 0 else "move_right")
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
		_atk_clock -= delta
		if absf(dx) < 80.0 and _atk_clock <= 0.0:
			_atk_clock = 0.28
			_atk_i += 1
			var act := "attack_heavy" if _atk_i % 4 == 3 else "attack_light"
			if _atk_i % 11 == 0:
				act = "dodge"
			if _atk_i % 13 == 0:
				act = "skill1"
			_tap(act)

	func _tap(action: String) -> void:
		Input.action_press(action)
		await get_tree().create_timer(0.05, true, false, true).timeout
		Input.action_release(action)

	func _release(a: String) -> void:
		Input.action_release(a)

	func _release_all() -> void:
		for a in ["move_left", "move_right", "attack_light", "attack_heavy", "dodge", "skill1", "jump"]:
			Input.action_release(a)

	## Vigia de glitches (posição, arena, HUD duplicado, chão).
	func _watch(pl: Player) -> void:
		var lv := _level
		var p := pl.global_position
		if p.y > Level.GROUND_Y + 40.0:
			bug("player_abaixo_do_chao", "y=%.0f (chão=%.0f)" % [p.y, Level.GROUND_Y])
		if p.y < -600.0:
			bug("player_no_ceu", "y=%.0f" % p.y)
		if p.x < Level.WALL_LEFT - 30.0 or p.x > lv._end_x + 30.0:
			bug("player_fora_da_arena", "x=%.0f limites=[%.0f,%.0f]" % [p.x, Level.WALL_LEFT, lv._end_x])
		if pl.is_on_floor():
			_floor_min = minf(_floor_min, p.y)
			_floor_max = maxf(_floor_max, p.y)
		# HP perdido (só registro)
		if _last_hp >= 0 and pl.health.current_health < _last_hp:
			_dmg_taken += _last_hp - pl.health.current_health
		_last_hp = pl.health.current_health
		var b := lv.arena_bounds()
		for e in get_tree().get_nodes_in_group("enemy"):
			if not e is Enemy or e.estate == Enemy.EState.DEAD:
				continue
			var ep: Vector2 = e.global_position
			var off: bool = ep.x < b.x - 40.0 or ep.x > b.y + 40.0 or ep.y > Level.GROUND_Y + 50.0 or ep.y < -500.0
			var k := e.get_instance_id()
			if off:
				_off_timer[k] = _off_timer.get(k, 0.0) + get_physics_process_delta_time()
				if _off_timer[k] > 2.0:
					bug("inimigo_fora_da_arena", "%s em (%.0f,%.0f) arena=[%.0f,%.0f] zona_ativa=%s" % [e.type_id, ep.x, ep.y, b.x, b.y, str(lv.zone_active)])
			else:
				_off_timer[k] = 0.0
		# HUD: um só, e uma só barra de chefe visível
		var huds := get_tree().get_nodes_in_group("hud")
		if huds.size() != 1:
			bug("hud_duplicado", "grupo hud tem %d nós" % huds.size(), false)
		var bars := 0
		for h in huds:
			if "_boss_box" in h and h._boss_box != null and h._boss_box.visible:
				bars += 1
		_boss_bar_max = maxi(_boss_bar_max, bars)

	## Loja: botões habilitados sem faíscas suficientes?
	func _check_shop(menu: Node) -> void:
		var btns: Array = menu.find_children("*", "Button", true, false)
		var txt := []
		for bt in btns:
			txt.append("%s%s" % [bt.text.replace("\n", " ").substr(0, 40), "" if not bt.disabled else "(x)"])
		log_evt("EVT", "shop", "faiscas=%d botoes=%s" % [Progression.orbs, " | ".join(txt)])

	func _finish_ok(result: String, detail: String) -> void:
		_done = true
		_release_all()
		_save("end")
		_end(result, detail)

	func _finish_fail() -> void:
		_done = true
		_release_all()
		var lv := _level
		var d := ""
		if lv != null and lv.player != null:
			var vivos := 0
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and e.estate != Enemy.EState.DEAD:
					vivos += 1
			d = "zona=%d/%d wave=%d/%d ativa=%s vivos=%d alive_var=%d player=(%.0f,%.0f) end_x=%.0f state=%d paused=%s gm_state=%d" % [lv.zone_index, lv.zones.size(), lv.wave_index, lv.waves.size(), str(lv.zone_active), vivos, lv.alive, lv.player.global_position.x, lv.player.global_position.y, lv._end_x, lv.player.state, str(get_tree().paused), GameManager.state]
		_save("timeout")
		_end("TIMEOUT", d)

	func _end(result: String, detail: String) -> void:
		var fps := _fps_sum / maxf(1.0, float(_fps_n))
		print("QA|%d|END|%s|%.1fs|%s|dialogos=%d loja=%d estela=%d dano=%d chao_y=[%.1f,%.1f] barras_chefe_max=%d fps=%.0f" % [screen, result, t, detail, _dialogs, _shop_seen, _stela_seen, _dmg_taken, _floor_min, _floor_max, _boss_bar_max, fps])
		await get_tree().create_timer(0.1, true, false, true).timeout
		get_tree().quit()
