extends Node
## FERRAMENTA (não faz parte do jogo): SONDA DE CHEFES (Onda 6, chefes6).
## Um bot "jogador MÉDIO" enfrenta cada chefe na tela real dele e mede:
## tempo de luta, golpes da Sophia que tiraram vida do chefe, dano recebido,
## quase-mortes (vida < 25 % → conta e cura cheia; a luta nunca para) e em
## que segundo cada FASE começou.
## O jogador médio NÃO é perfeito: reage ao telegrafo com atraso e acerta a
## defesa só às vezes (sorteio determinístico por tela) — vermelho: rola em
## ~65 %; amarelo: apara em ~35 %, rola em ~30 %, senão come o golpe.
## Uso (headless, rápido):
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/chefes6/BossProbe.tscn -- \
##         telas=1,10,19 [vel=3] [wl=N] [out=C:/x/sonda] [skill=0.65]
##   telas=all = Rei, os 7 Arcontes e a batalha final.
##   wl   = força o nível da arma (senão o esperado da tela: BossTuning).
## Captura (janela, vel=1): cap=C:/caps/dir every=4 capsec=7 → em cada FASE,
##   capsec s de quadros (<cap>/<chefe>_###.png) para o tools/seq_to_media.py.

const ALL := [1, 10, 19, 28, 37, 46, 55, 64, 68]


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var w := ProbeWorker.new()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		var k: String = kv[0]
		var v: String = kv[1] if kv.size() > 1 else ""
		match k:
			"telas":
				if v == "all":
					w.screens = ALL.duplicate()
				else:
					w.screens = []
					for s in v.split(","):
						w.screens.append(int(s))
			"vel": w.speed = float(v)
			"wl": w.force_wl = int(v)
			"out": w.out_base = v
			"skill": w.skill = float(v)
			"cap": w.cap_dir = v
			"every": w.cap_every = maxi(1, int(v))
			"capsec": w.cap_sec = float(v)
			"timeout": w.fight_timeout = float(v)
			"perfil": w.profile = v
	get_tree().root.add_child.call_deferred(w)


class ProbeWorker extends Node:
	var screens: Array = [10]
	var speed: float = 3.0
	var force_wl: int = 0
	var out_base: String = "user://boss_probe"
	var skill: float = 0.65            # chance de rolar do vermelho (o resto escala daqui)
	## perfil: "medio" = bate em sequências de 3–4 e se afasta ~0,8 s (como um
	## jogador que respeita o chefe); "agressivo" = bate sem parar (o bot antigo).
	var profile: String = "medio"
	var _string_left: int = 3
	var _backoff_t: float = 0.0
	var cap_dir: String = ""
	var cap_every: int = 4
	var cap_sec: float = 7.0
	var fight_timeout: float = 420.0

	var _idx: int = -1
	var _rows: Array = []
	var _rng := RandomNumberGenerator.new()
	# estado da luta
	var _bosses: Array = []
	var _fight_on: bool = false
	var _t: float = 0.0
	var _hits: int = 0
	var _dmg_dealt: int = 0
	var _dmg_taken: int = 0
	var _near: int = 0
	var _phase_t: Dictionary = {}      # "id:fase" -> s
	var _hp_seen: int = -1
	var _watched_pl: int = 0
	var _load_t: float = 0.0
	var _done_screen: bool = false
	# reação a telegrafos
	var _plan: Dictionary = {}         # boss instance id -> {"act": "dodge|parry|none", "seen": windup id}
	var _windup_seq: Dictionary = {}   # boss id -> estado anterior
	var _block_hold: float = 0.0
	var _atk_t: float = 0.0
	var _atk_i: int = 0
	var _cast_t: float = 0.0
	var _dodge_cd: float = 0.0
	var _jump_cd: float = 0.0
	var _proj_seen: Dictionary = {}    # projétil id -> decidido
	# captura
	var _cap_left: float = 0.0
	var _cap_n: int = 0
	var _cap_k: int = 0
	var _cap_name: String = ""
	var _cap_pending: Array = []
	var _phase_seen: Dictionary = {}
	const PATTERN := ["light", "light", "light", "heavy", "light", "light", "heavy", "heavy", "heavy"]
	const NEAR_DEATH := 0.25

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Juice.speed_mult = speed
		Engine.physics_ticks_per_second = int(round(60.0 * speed))
		Engine.max_physics_steps_per_frame = maxi(8, int(ceil(speed)) + 1)
		GameManager.selected_character = GameContent.characters[0]
		_next_screen()

	func _next_screen() -> void:
		_release_all()
		_idx += 1
		if _idx >= screens.size():
			_finish()
			return
		var s: int = screens[_idx]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = s
		GameManager.current_screen = s
		# Progressão esperada: arma da tela e os Anéis dos Arcontes já vencidos.
		var wl: int = force_wl if force_wl > 0 else _expected_wl(s)
		Progression.weapon_level = wl
		var n_rings: int = 7 if s >= 68 else maxi(0, RunManager.eon_index(s)) if s > 1 else 0
		var k := 0
		for sk in GameContent.characters[0].skills:
			if sk.ring != "" and k < n_rings:
				Progression.add_ring(sk.ring, sk.id)
				k += 1
		_rng.seed = hash("probe-%d" % s)
		seed(hash("probe-g-%d" % s))
		_bosses = []
		_fight_on = false
		_t = 0.0
		_hits = 0
		_dmg_dealt = 0
		_dmg_taken = 0
		_near = 0
		_phase_t = {}
		_phase_seen = {}
		_plan = {}
		_load_t = 0.0
		_done_screen = false
		_watched_pl = 0
		_cap_left = 0.0
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _expected_wl(s: int) -> int:
		var bt = load("res://scripts/entities/bosses/boss_tuning.gd")
		if bt != null:
			return int(bt.expected_weapon_level(s))
		return clampi(1 + RunManager.eon_index(s) / 2, 1, 5)

	func _process(_delta: float) -> void:
		# diálogos: escolha padrão
		var had := false
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
				had = true
		var cs := get_tree().current_scene
		if cs != null:
			for c in cs.get_children():
				if c is CanvasLayer and c.has_method("_close"):
					c._close()
		if had:
			return
		_capture_tick()

	func _physics_process(delta: float) -> void:
		if _idx < 0 or _idx >= screens.size() or _done_screen:
			return
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl == null or pl.health == null:
			return
		_watch(pl)
		_load_t += delta
		if _load_t > 600.0:
			_end_fight("SEM LUTA (não achou o chefe)")
			return
		_collect_bosses()
		if not _fight_on:
			if not _bosses.is_empty():
				_fight_on = true
				_t = 0.0
				_start_capture("p1")
			else:
				# anda até o gatilho do duelo
				Input.action_press("move_right")
				return
		_t += delta
		# quase-morte: conta e cura
		if pl.state != Player.State.DEAD and pl.health.current_health < int(pl.health.max_health * NEAR_DEATH):
			_near += 1
			pl.health.heal(pl.health.max_health)
			_hp_seen = pl.health.current_health
		if pl.state == Player.State.DEAD:
			_near += 1
			_end_fight("MORREU")
			return
		# fases
		for b in _bosses:
			if is_instance_valid(b):
				var key := "%s:%d" % [b.type_id, b.phase]
				if not _phase_t.has(key):
					_phase_t[key] = _t
					if b.phase > 1:
						_start_capture("p%d" % b.phase)
		if _all_down():
			_end_fight("ok")
			return
		if _t > fight_timeout:
			_end_fight("TIMEOUT")
			return
		_drive(pl, delta)

	func _collect_bosses() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.is_boss_enemy and not _bosses.has(e) and e.process_mode != Node.PROCESS_MODE_DISABLED:
				_bosses.append(e)
				e.health.health_changed.connect(_on_boss_hp.bind(e))
				e.set_meta("probe_hp", e.health.current_health)

	func _all_down() -> bool:
		if _bosses.is_empty():
			return false
		if RunManager.is_final(screens[_idx]):
			var lv := get_tree().current_scene
			var fb = lv.get_node_or_null("FinalBattle") if lv != null else null
			return fb != null and bool(fb.get("_done"))
		for b in _bosses:
			if is_instance_valid(b) and b.estate != Enemy.EState.DEAD:
				return false
		return true

	func _on_boss_hp(cur: int, _mx: int, e: Enemy) -> void:
		var prev: int = int(e.get_meta("probe_hp", cur))
		if cur < prev:
			_hits += 1
			_dmg_dealt += prev - cur
		e.set_meta("probe_hp", cur)

	func _watch(pl: Player) -> void:
		if _watched_pl == pl.get_instance_id():
			return
		_watched_pl = pl.get_instance_id()
		_hp_seen = pl.health.current_health
		pl.health.health_changed.connect(_on_pl_hp)

	func _on_pl_hp(cur: int, _mx: int) -> void:
		if _fight_on and _hp_seen >= 0 and cur < _hp_seen:
			_dmg_taken += _hp_seen - cur
		_hp_seen = cur

	func _end_fight(why: String) -> void:
		_done_screen = true
		_release_all()
		var s: int = screens[_idx]
		var names: Array = []
		for b in _bosses:
			if is_instance_valid(b):
				names.append(str(b.type_id))
		var ph: Array = []
		var keys: Array = _phase_t.keys()
		keys.sort_custom(func(a, b): return float(_phase_t[a]) < float(_phase_t[b]))
		for k in keys:
			ph.append("%s@%.0fs" % [k, float(_phase_t[k])])
		var row := {"screen": s, "boss": "+".join(names), "time": _t, "hits": _hits, "dealt": _dmg_dealt,
			"taken": _dmg_taken, "near": _near, "why": why, "phases": " ".join(ph), "wl": Progression.weapon_level}
		_rows.append(row)
		print("PROBE tela=%d %s t=%.0fs golpes=%d dano_dado=%d dano_tomado=%d quase_mortes=%d arma=%d [%s] %s" % [s, row.boss, _t, _hits, _dmg_dealt, _dmg_taken, _near, row.wl, why, row.phases])
		_flush_caps()
		_next_screen.call_deferred()

	# --- a mão do bot -------------------------------------------------------
	func _drive(pl: Player, delta: float) -> void:
		_dodge_cd = maxf(0.0, _dodge_cd - delta)
		_jump_cd = maxf(0.0, _jump_cd - delta)
		_cast_t += delta
		if _block_hold > 0.0:
			_block_hold -= delta
			Input.action_press("block")
			if _block_hold <= 0.0:
				Input.action_release("block")
			return
		var target: Enemy = null
		var best := INF
		for b in _bosses:
			if not is_instance_valid(b) or b.estate == Enemy.EState.DEAD:
				continue
			var d: float = absf(b.global_position.x - pl.global_position.x)
			if d < best:
				best = d
				target = b
		# ajudantes vivos perto (servos, ecos, larvas) também apanham
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and not e.is_boss_enemy and e.estate != Enemy.EState.DEAD:
				var d2: float = absf(e.global_position.x - pl.global_position.x)
				if d2 < best * 0.6:
					best = d2
					target = e
		# 1) telegrafos de TODOS os chefes (o que estiver para bater)
		var reacted := false
		for b in _bosses:
			if is_instance_valid(b):
				if not reacted and b.estate == Enemy.EState.WINDUP:
					reacted = _react_windup(pl, b)
				_windup_seq[b.get_instance_id()] = b.estate
		if reacted:
			return
		# 2) perigos no chão e projéteis
		if _avoid_hazards(pl):
			return
		if _avoid_projectiles(pl):
			return
		if target == null:
			_release_moves()
			return
		var dx := target.global_position.x - pl.global_position.x
		var reach := 70.0 + 30.0 * maxf(0.0, target.get("_art_scale") - 1.0)
		if _backoff_t > 0.0:
			# respiro: recua, olha o chefe e só volta depois
			_backoff_t -= delta
			Input.action_release("move_right" if dx > 0 else "move_left")
			Input.action_press("move_left" if dx > 0 else "move_right")
			if _backoff_t <= 0.0:
				_string_left = 3 + (_rng.randi() % 2)
				_release_moves()
			return
		# esperando o golpe armado (vai defender): não entra batendo
		if profile == "medio" and target.estate == Enemy.EState.WINDUP and absf(dx) < reach + 40.0:
			var pc: Dictionary = _plan.get(target.get_instance_id(), {})
			if pc.get("act", "none") != "none" and not pc.get("done", false):
				_release_moves()
				return
		if absf(dx) > reach:
			Input.action_release("move_left" if dx > 0 else "move_right")
			Input.action_press("move_right" if dx > 0 else "move_left")
		else:
			_release_moves()
			if signf(dx) != float(pl.facing) and dx != 0.0:
				var a := "move_right" if dx > 0 else "move_left"
				Input.action_press(a)
				_release_later(a)
		if _cast_t > 4.0 and pl.mana >= 24.0:
			_cast_t = 0.0
			Input.action_press("skill2")
			_release_later("skill2")
		_atk_t += delta
		if absf(dx) < reach + 20.0 and _atk_t > 0.32:
			_atk_t = 0.0
			var btn: String = PATTERN[_atk_i % PATTERN.size()]
			_atk_i += 1
			var act := "attack_light" if btn == "light" else "attack_heavy"
			Input.action_press(act)
			_release_later(act)
			if profile == "medio":
				_string_left -= 1
				if _string_left <= 0:
					_backoff_t = 0.6 + _rng.randf() * 0.5

	## Telegrafo: decide UMA vez por preparação (sorteio) e age perto do golpe.
	func _react_windup(pl: Player, b: Enemy) -> bool:
		var id := b.get_instance_id()
		var cur: Dictionary = _plan.get(id, {})
		var fresh: bool = int(_windup_seq.get(id, -1)) != Enemy.EState.WINDUP
		if fresh or cur.is_empty():
			# preparação nova: decide UMA vez (sorteio determinístico)
			var unb: bool = b.attack_hitbox.unblockable
			var r := _rng.randf()
			var act := "none"
			if unb:
				act = "dodge" if r < skill else "none"
			else:
				if r < skill * 0.55:
					act = "parry"
				elif r < skill * 1.0:
					act = "dodge"
			cur = {"act": act, "done": false}
			_plan[id] = cur
		if cur.done or cur.act == "none":
			return false
		var far: float = absf(b.global_position.x - pl.global_position.x)
		var reach: float = maxf(b.attack_range, 90.0) + 40.0
		if far > reach:
			return false
		if b.attack_timer > 0.17:
			return false
		cur.done = true
		if cur.act == "parry":
			_release_moves()
			Input.action_press("block")
			_block_hold = 0.35
		elif _dodge_cd <= 0.0:
			# rola para LONGE do chefe
			var away := "move_left" if b.global_position.x > pl.global_position.x else "move_right"
			_release_moves()
			Input.action_press(away)
			Input.action_press("dodge")
			_release_later("dodge")
			_release_later(away)
			_dodge_cd = 0.8
		return true

	func _avoid_hazards(pl: Player) -> bool:
		for hz in get_tree().get_nodes_in_group("boss_hazard"):
			if not is_instance_valid(hz) or not hz.has_method("threat_at"):
				continue
			var th: float = hz.threat_at(pl.global_position)
			if th <= 0.0:
				continue
			var id := hz.get_instance_id()
			if not _proj_seen.has(id):
				_proj_seen[id] = _rng.randf() < minf(0.95, skill + 0.1)
			if not _proj_seen[id]:
				continue
			var go: String = hz.escape_dir(pl.global_position) if hz.has_method("escape_dir") else "move_right"
			if go == "jump":
				if _jump_cd <= 0.0 and pl.is_on_floor():
					Input.action_press("jump")
					_release_later("jump")
					_jump_cd = 0.5
				return false
			if go == "dodge":
				if _dodge_cd <= 0.0:
					Input.action_press("dodge")
					_release_later("dodge")
					_dodge_cd = 0.8
				return true
			Input.action_release("move_left" if go == "move_right" else "move_right")
			Input.action_press(go)
			return true
		return false

	func _avoid_projectiles(pl: Player) -> bool:
		for n in get_tree().current_scene.get_children() if get_tree().current_scene != null else []:
			if not (n is Projectile) or n.target_team != "player":
				continue
			var rel: Vector2 = pl.global_position - n.global_position
			if absf(rel.x) > 95.0 or absf(rel.y) > 60.0 or signf(rel.x) != signf(float(n.direction)):
				continue
			var id := n.get_instance_id()
			if not _proj_seen.has(id):
				_proj_seen[id] = _rng.randf() < skill * 0.9
			if not _proj_seen[id]:
				continue
			_proj_seen[id] = false   # reage uma vez
			var low: bool = n.global_position.y > pl.global_position.y - 6.0
			if low and pl.is_on_floor() and _jump_cd <= 0.0:
				Input.action_press("jump")
				_release_later("jump")
				_jump_cd = 0.5
				return true
			if _dodge_cd <= 0.0:
				Input.action_press("dodge")
				_release_later("dodge")
				_dodge_cd = 0.8
				return true
		return false

	func _release_moves() -> void:
		Input.action_release("move_left")
		Input.action_release("move_right")

	func _release_all() -> void:
		for a in ["move_left", "move_right", "jump", "dodge", "block", "attack_light", "attack_heavy", "skill1", "skill2"]:
			Input.action_release(a)
		_block_hold = 0.0

	func _release_later(a: String) -> void:
		await get_tree().create_timer(0.05, true, true, false).timeout
		Input.action_release(a)

	# --- captura ---------------------------------------------------------
	func _start_capture(tag: String) -> void:
		if cap_dir == "" or _phase_seen.has(tag):
			return
		_phase_seen[tag] = true
		_cap_left = cap_sec
		_cap_k = 0
		if _cap_name == "" or not _cap_name.begins_with("s%d_" % screens[_idx]):
			_cap_name = "s%d_%s" % [screens[_idx], RunManager.boss_id_for(screens[_idx])]
			_cap_n = 0
			DirAccess.make_dir_recursive_absolute(cap_dir)

	func _capture_tick() -> void:
		if _cap_left <= 0.0 or cap_dir == "":
			return
		_cap_left -= get_process_delta_time()
		_cap_k += 1
		if _cap_k % cap_every != 0:
			return
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s_%03d.png" % [cap_dir, _cap_name, _cap_n]
		_cap_n += 1
		_cap_pending.append([WorkerThreadPool.add_task(img.save_png.bind(path)), img])

	func _flush_caps() -> void:
		for j in _cap_pending:
			WorkerThreadPool.wait_for_task_completion(j[0])
		_cap_pending = []

	func _finish() -> void:
		var lines: Array[String] = []
		lines.append("SONDA DE CHEFES — jogador médio (skill=%.2f, vel=%.1f)" % [skill, speed])
		lines.append("tela | chefe | arma | tempo(s) | golpes | dano dado | dano tomado | quase-mortes | fim | fases")
		for r in _rows:
			lines.append("%4d | %s | %d | %6.1f | %4d | %5d | %5d | %d | %s | %s" % [r.screen, r.boss, r.wl, r.time, r.hits, r.dealt, r.taken, r.near, r.why, r.phases])
		var f := FileAccess.open(out_base + ".txt", FileAccess.WRITE)
		for l in lines:
			print("PROBE ", l)
			if f:
				f.store_line(l)
		if f:
			f.close()
		get_tree().quit()
