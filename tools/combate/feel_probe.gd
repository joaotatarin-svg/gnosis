extends Node
## FERRAMENTA (Combate 6 — não faz parte do jogo): MEDE o "feel" da Sophia com
## Input simulado, em passos de física (determinístico com --fixed-fps 60):
##   andar   — quadros até 90 % da velocidade, até parar, giro (direita → esquerda)
##   amassar — botão amassado (leve / forte a cada 5 quadros): golpes por segundo
##   aereo   — pulo + forte 2x por pulo, 4 pulos: quantos mergulhos saem, preparo,
##             trava no pouso
##   duplo   — altura do pulo simples e do 2º pulo (com a trava forçada aberta)
##   dano    — dano de cada golpe nos níveis de arma 1/3/5
##   corrida — quanto tempo cada quadro desenhado da corrida fica na tela
## Uso: godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/combate/FeelProbe.tscn
## Saída: linhas "FEEL|..." (compare antes × depois) e "QA PASS"/"QA FAIL" (checagens
## do Combate 6 — só valem depois dele: aéreo ≤ 1 por pulo, pulo duplo travado
## sem a flag, 2º pulo mais baixo que o 1º).

const SCREEN := 3


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var r := Runner.new()
	get_tree().root.add_child.call_deferred(r)


class Runner extends Node:
	var pl: Player
	var _held: Dictionary = {}
	var fails: Array[String] = []

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = SCREEN
		GameManager.current_screen = SCREEN
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")
		_main.call_deferred()

	func _process(_d: float) -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				e.queue_free()

	# --- passos de física com Input simulado ---
	func _step(n: int = 1) -> void:
		for i in n:
			await get_tree().physics_frame
			for a in _held.keys():
				_held[a] -= 1
				if _held[a] <= 0:
					Input.action_release(a)
					_held.erase(a)

	func _tap(a: String, frames: int = 3) -> void:
		Input.action_press(a)
		_held[a] = frames

	func _hold(a: String) -> void:
		Input.action_press(a)

	func _release(a: String) -> void:
		Input.action_release(a)
		_held.erase(a)

	func _settle() -> void:
		for a in ["move_left", "move_right", "attack_light", "attack_heavy", "jump", "dodge", "block"]:
			Input.action_release(a)
		_held.clear()
		var n := 0
		while n < 240 and (not pl.is_on_floor() or pl.state != Player.State.IDLE or absf(pl.velocity.x) > 0.5 or pl.attack_cd > 0.0):
			await _step()
			n += 1
		await _step(20)

	func _main() -> void:
		while true:
			await get_tree().process_frame
			pl = get_tree().get_first_node_in_group("player") as Player
			if pl != null and pl.is_inside_tree():
				break
		await _step(90)
		Progression.weapon_level = 3
		pl.health.max_health = 99999
		pl.health.current_health = 99999
		print("FEEL|inicio tela=%d fisica=%d Hz interp=%s max_fps=%d vel=%.0f pulo=%.0f" % [SCREEN, Engine.physics_ticks_per_second, str(ProjectSettings.get_setting("physics/common/physics_interpolation")), Engine.max_fps, pl.data.move_speed, pl.data.jump_velocity])
		await _walk()
		await _mash("attack_light", "leve")
		await _mash("attack_heavy", "forte")
		await _aerial()
		await _double()
		_damage_table()
		_run_frames()
		if fails.is_empty():
			print("QA PASS: FeelProbe (aéreo 1/pulo, pulo duplo travado, 2º pulo mais baixo)")
		else:
			for f in fails:
				push_error("QA FAIL: FeelProbe — " + f)
		get_tree().quit()

	# --- andar: arrancada, freio, giro ---
	func _walk() -> void:
		await _settle()
		var full: float = pl.data.move_speed
		_hold("move_right")
		var t90 := -1
		var vs: Array[String] = []
		for i in 30:
			await _step()
			vs.append("%.0f" % pl.velocity.x)
			if t90 < 0 and pl.velocity.x >= full * 0.9:
				t90 = i + 1
		await _step(20)
		_release("move_right")
		var tstop := -1
		var vstop: Array[String] = []
		for i in 30:
			await _step()
			vstop.append("%.0f" % pl.velocity.x)
			if tstop < 0 and absf(pl.velocity.x) < 1.0:
				tstop = i + 1
		await _settle()
		_hold("move_right")
		await _step(40)
		var x0 := pl.global_position.x
		_release("move_right")
		_hold("move_left")
		var tflip := -1
		var tfull := -1
		for i in 40:
			await _step()
			if tflip < 0 and pl.facing == -1:
				tflip = i + 1
			if tfull < 0 and pl.velocity.x <= -full * 0.9:
				tfull = i + 1
		var skid: float = pl.global_position.x - x0
		_release("move_left")
		print("FEEL|andar ate90%%=%d q (%.0f ms) parar=%d q (%.0f ms) giro: vira=%d q, 90%%_do_outro_lado=%d q" % [t90, t90 * 1000.0 / 60.0, tstop, tstop * 1000.0 / 60.0, tflip, tfull])
		print("FEEL|andar vx_arrancada=%s" % ",".join(vs.slice(0, 10)))
		print("FEEL|andar vx_freio=%s" % ",".join(vstop.slice(0, 10)))
		print("FEEL|andar giro_deslize=%.1f px" % skid)

	# --- botão amassado: quantos golpes saem por segundo ---
	func _mash(btn: String, label: String) -> void:
		await _settle()
		var starts := 0
		var moves: Array[String] = []
		var last_move: ComboData = null
		var was_hit := false
		var dmg := 0
		for i in 120:
			if i % 5 == 0:
				_tap(btn, 2)
			await _step()
			# golpe novo = o hitbox ligou (hit_started passou a true) num golpe novo
			if pl.state == Player.State.ATTACK and pl.hit_started and (not was_hit or pl.current_move != last_move):
				starts += 1
				moves.append(pl.current_move.id)
				dmg += pl.pending_dmg
			was_hit = pl.state == Player.State.ATTACK and pl.hit_started
			last_move = pl.current_move if pl.state == Player.State.ATTACK else null
		print("FEEL|amassar_%s golpes_em_2s=%d (%.1f/s) dano_bruto=%d seq=%s" % [label, starts, starts / 2.0, dmg, ",".join(moves)])

	# --- pulo + forte (aéreo forte) em spam ---
	func _aerial() -> void:
		await _settle()
		var dives := 0
		var novas := 0
		var windup_q: Array[String] = []
		var lock_q: Array[String] = []
		var in_dive := false
		var pressed_at := -1
		var landed_at := -1
		var frame := 0
		for k in 4:
			_tap("jump")
			for i in 42:
				if i == 10 or i == 16:
					_tap("attack_heavy")
					if pressed_at < 0:
						pressed_at = frame
				await _step()
				frame += 1
				var diving: bool = pl.state == Player.State.ATTACK and pl.current_move != null and pl.current_move.air and pl.current_move.is_heavy()
				if diving and not in_dive:
					dives += 1
				if diving and pl.hit_started and pressed_at >= 0:
					windup_q.append(str(frame - pressed_at))
					pressed_at = -1
				if diving and pl.dive_landed and landed_at < 0:
					novas += 1
					landed_at = frame
				if landed_at >= 0 and not diving:
					lock_q.append(str(frame - landed_at))
					landed_at = -1
				in_dive = diving
			pressed_at = -1
		print("FEEL|aereo 4_pulos x 2_apertos: mergulhos=%d novas=%d preparo(q)=%s trava_pouso(q)=%s" % [dives, novas, ",".join(windup_q), ",".join(lock_q)])
		if dives > 4:
			fails.append("aéreo forte saiu %d vezes em 4 pulos" % dives)

	# --- pulo duplo ---
	func _double() -> void:
		await _settle()
		var y0 := pl.global_position.y
		_tap("jump")
		var top1 := y0
		for i in 60:
			await _step()
			top1 = minf(top1, pl.global_position.y)
		var h1 := y0 - top1
		await _settle()
		# sem a flag: o 2º toque não pode fazer nada
		_tap("jump")
		await _step(18)
		var vy_before := pl.velocity.y
		_tap("jump")
		await _step(2)
		var locked_ok: bool = pl.velocity.y >= vy_before
		await _settle()
		pl.set("debug_double_jump", true)
		y0 = pl.global_position.y
		_tap("jump")
		await _step(22)
		var y_at := pl.global_position.y
		_tap("jump")
		var top2 := y_at
		for i in 70:
			await _step()
			top2 = minf(top2, pl.global_position.y)
		var h2 := y_at - top2
		# aéreo forte depois do 2º pulo (1 por pulo, não duplica)
		await _settle()
		var dives := 0
		var in_dive := false
		_tap("jump")
		for i in 90:
			if i == 8 or i == 30 or i == 36:
				_tap("attack_heavy")
			if i == 20:
				_tap("jump")
			await _step()
			var diving: bool = pl.state == Player.State.ATTACK and pl.current_move != null and pl.current_move.air and pl.current_move.is_heavy()
			if diving and not in_dive:
				dives += 1
			in_dive = diving
		pl.set("debug_double_jump", false)
		print("FEEL|pulo altura_1=%.0f px  2o_pulo_sobe=%.0f px (a partir de %.0f px)  travado_sem_flag=%s  aereos_com_2o_pulo=%d" % [h1, h2, y0 - y_at, str(locked_ok), dives])
		if not locked_ok:
			fails.append("pulo duplo saiu sem a flag da progressão")
		if h2 <= 1.0 or h2 >= h1:
			fails.append("2º pulo (%.0f) deveria subir e ser menor que o 1º (%.0f)" % [h2, h1])
		if dives > 1:
			fails.append("aéreo forte duplicou com o 2º pulo (%d)" % dives)

	# --- dano por golpe e nível de arma ---
	func _damage_table() -> void:
		var keep := Progression.weapon_level
		for lvl in [1, 3, 5]:
			Progression.weapon_level = lvl
			var parts: Array[String] = []
			for m in pl.data.combos:
				if m.required_weapon_level > lvl:
					continue
				var d: int = pl.call("move_damage", m) if pl.has_method("move_damage") else m.damage + (lvl - 1) * 6
				var extra := ""
				if m.air and m.is_heavy():
					var nova: int = pl.call("dive_nova_damage", d) if pl.has_method("dive_nova_damage") else d
					var contact: int = pl.call("dive_contact_damage", d) if pl.has_method("dive_contact_damage") else d
					extra = "(contato %d + onda %d)" % [contact, nova]
				elif m.aoe_radius > 0.0:
					extra = "(+onda %d)" % int(d * 0.8)
				parts.append("%s=%d%s" % [m.id, d, extra])
			print("FEEL|dano nv%d %s" % [lvl, " ".join(parts)])
		Progression.weapon_level = keep

	# --- corrida: tempo de tela de cada quadro desenhado ---
	func _run_frames() -> void:
		var db: Dictionary = CharacterArt.frame_db("sophia")
		if db.is_empty():
			print("FEEL|corrida sem banco de quadros")
			return
		var seqs: Dictionary = db.meta.states
		var seq_name := "rund" if seqs.has("rund") else "run"
		var adv: Array = seqs[seq_name].get("advance", [])
		var world_k: float = pl.visual.profile.height * 1.19 / float(db.meta.body_px)
		var spd: float = pl.data.move_speed
		var holds: Array[String] = []
		var mn := 1e9
		var mx := 0.0
		var tot := 0.0
		for v in adv:
			var ms: float = float(v) * world_k / spd * 1000.0
			holds.append("%.0f" % ms)
			mn = minf(mn, ms)
			mx = maxf(mx, ms)
			tot += ms
		var n := adv.size()
		print("FEEL|corrida seq=%s quadros=%d ciclo=%.0f px (%.0f ms a %.0f px/s) troca_media=%.1f/s quadro_ms=[%s] min=%.0f max=%.0f (a 60 Hz: <16,7 ms = quadro que nunca aparece)" % [seq_name, n, tot * spd / 1000.0, tot, spd, n / (tot / 1000.0), ",".join(holds), mn, mx])
