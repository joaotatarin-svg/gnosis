extends Node
## FERRAMENTA (Combate, Onda 3): prova de F1 (flash aditivo da Sophia), do aparo
## com quadros + contra-ataque, do telegrafo por contorno nos chefes por quadros,
## da pose de morte antes do desmembramento e dos números de dano na pausa (C1).
## godot --audio-driver Dummy --fixed-fps 60 --path . --resolution 1280x720 --position 4000,4000 \
##       res://tools/combate/FlashParryProbe.tscn -- [out=<pasta para PNGs>]
## (com --headless roda igual, só não salva PNG). Saída: "FPPROBE|..." + "QA PASS/FAIL".

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)   # ferramenta NUNCA toca som
	var w := P.new()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			w.out = a.trim_prefix("out=")
	get_tree().root.add_child.call_deferred(w)


class P extends Node:
	var errors: int = 0
	var out: String = ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		_run.call_deferred()

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	## Passos de FÍSICA (o Input é lido no _physics_process): sem --fixed-fps o
	## headless roda muitos quadros de processo por passo de física e um aperto de
	## 2 quadros de processo podia sumir entre dois passos (falso negativo).
	func pframes(n: int) -> void:
		for i in n:
			await get_tree().physics_frame

	func check(ok: bool, msg: String) -> void:
		if ok:
			print("QA PASS: ", msg)
		else:
			errors += 1
			push_error("QA FAIL: " + msg)

	func key(k: Key, down: bool) -> void:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)

	func skip_dialogs() -> void:
		for i in 40:
			var d: DialogueBox = null
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					d = c
			if d == null:
				return
			key(KEY_ENTER if d._in_choices else KEY_J, true)
			await wait(0.06)
			key(KEY_ENTER if d._in_choices else KEY_J, false)
			await wait(0.15)

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
		await wait(0.3)

	## Recorte em volta de um ponto do mundo (px da imagem) → PNG.
	func snap(name: String, world: Vector2, half: Vector2 = Vector2(140, 170)) -> void:
		if out == "" or DisplayServer.get_name() == "headless":
			return
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var sp: Vector2 = get_viewport().get_canvas_transform() * world
		sp *= Vector2(img.get_width(), img.get_height()) / get_viewport().get_visible_rect().size
		var r := Rect2i(Vector2i(sp - half), Vector2i(half * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 4 and r.size.y > 4:
			img.get_region(r).save_png(out.path_join(name + ".png"))

	func spawn(level: Node, type_id: String, pos: Vector2) -> Enemy:
		var e: Enemy = level.enemy_scene.instantiate()
		e.type_id = type_id
		level.add_child(e)
		e.global_position = pos
		return e

	func _run() -> void:
		if out != "":
			DirAccess.make_dir_recursive_absolute(out)
		await level_at(3)
		var lv: Node = get_tree().current_scene
		var pl: Player = lv.player
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		await wait(0.4)
		pl.health.current_health = pl.health.max_health
		Juice.reduce_flashes = false
		var feet: Vector2 = pl.global_position + Vector2(0, -30)
		await snap("f1_0_antes", feet)

		# --- F1: dano = flash ADITIVO curto, sem pintar a Sophia ---------------
		pl._on_hit_received(10, pl.global_position + Vector2(40, 0), 120.0, false, null)
		await frames(2)   # a camada entra no quadro seguinte ao golpe (pose nova já desenhada)
		var fl = pl.get("_flash_layer")
		var mod: Color = pl.visual.modulate
		print("FPPROBE|f1|modulate=%s camada=%s visivel=%s pico=%.2f malha=%d" % [str(mod), str(fl != null), str(fl != null and fl.visible), fl.peak if fl != null else -1.0, pl.visual._body_mesh.get("pts", PackedVector2Array()).size()])
		check(mod.r <= 1.01 and mod.g >= 0.99 and mod.b >= 0.99, "F1: o dano não tinge mais o corpo (modulate=%s)" % str(mod))
		check(fl != null and fl.visible and fl.peak > 0.1, "F1: a camada aditiva acende no dano")
		await snap("f1_1_pico", feet)
		await wait(0.04)
		await snap("f1_2_apagando", feet)
		await wait(0.12)
		check(fl == null or not fl.visible, "F1: o flash acaba em ≤ 100 ms reais (+ folga do quadro)")
		await snap("f1_3_depois", feet)
		# ≤ 3 cheios/s: o 2º flash em < 333 ms sai mais fraco
		await wait(0.5)
		pl.invuln_timer = 0.0
		pl._flash(Player.HURT_TINT)
		var p1: float = fl.peak
		await wait(0.12)
		pl._flash(Player.HURT_TINT)
		var p2: float = fl.peak
		print("FPPROBE|f1_freq|pico1=%.2f pico2(<333ms)=%.2f" % [p1, p2])
		check(p2 < p1 * 0.6, "F1: ≤ 3 flashes cheios por segundo")
		# Reduzir flashes
		await wait(0.6)
		Juice.reduce_flashes = true
		pl._flash(Player.HURT_TINT)
		var p3: float = fl.peak
		Juice.reduce_flashes = false
		print("FPPROBE|f1_reduzir|pico=%.2f (normal %.2f)" % [p3, p1])
		check(p3 <= p1 * 0.55, "F1: 'Reduzir flashes' corta o flash pela metade")
		await wait(0.3)

		# --- Aparo com quadros + contra-ataque ----------------------------------
		pl.health.current_health = pl.health.max_health
		var foe := spawn(lv, "servo", pl.global_position + Vector2(46, -6))
		await wait(0.5)
		foe.estate = Enemy.EState.CHASE
		var hp_foe: int = foe.health.current_health
		Input.action_press("block")          # bloqueio (aparo = golpe dentro de 0,18 s)
		await pframes(3)
		pl._on_hit_received(10, foe.global_position, 120.0, false, foe)
		await pframes(1)
		var act: String = str(pl.visual.get("_action"))
		print("FPPROBE|aparo|estado=%d acao=%s janela=%.2f vida=%d/%d" % [pl.state, act, pl._riposte_t, pl.health.current_health, pl.health.max_health])
		check(act == "parry", "aparo toca os quadros 'parry' (play_action)")
		check(pl._riposte_t > 0.0, "aparo abre a janela do contra-ataque")
		await snap("aparo", pl.global_position + Vector2(0, -30))
		await wait(0.1)
		Input.action_press("attack_light")   # ataque dentro da janela → contra-ataque
		await pframes(2)
		Input.action_release("attack_light")
		Input.action_release("block")
		act = str(pl.visual.get("_action"))
		print("FPPROBE|contra|estado=%d acao=%s riposting=%s dano=%d dx=%.0f foe_estado=%d" % [pl.state, act, str(pl.riposting), pl.pending_dmg, foe.global_position.x - pl.global_position.x if is_instance_valid(foe) else -1.0, foe.estate if is_instance_valid(foe) else -1])
		check(pl.state == Player.State.ATTACK and pl.riposting, "ataque na janela vira contra-ataque")
		check(act == "riposte", "contra-ataque toca os quadros 'riposte'")
		if OS.get_environment("FP_DEBUG") != "":
			for k in 30:
				await pframes(1)
				if not is_instance_valid(foe):
					break
				var hb: Hitbox = pl.hitbox
				var cs: CollisionShape2D = foe.get_node("Hurtbox/HurtShape")
				print("FPDBG|%d st=%d dx=%.1f vx=%.0f mon=%s act=%s live=%s box=%s hurt_cx=%.1f hurt_w=%.1f seq=%s" % [k, pl.state, foe.global_position.x - pl.global_position.x, pl.velocity.x, hb.monitoring, hb._active, hb._live, Rect2(hb.global_position - pl.global_position - hb.box_size() * 0.5, hb.box_size()), cs.global_position.x - pl.global_position.x, (cs.shape as RectangleShape2D).size.x * absf(cs.global_scale.x), str(pl.visual.get("_shown_key"))])
		await wait(0.12)
		await snap("contra_ataque", pl.global_position + Vector2(0, -30))
		await wait(0.5)
		var hp_after: int = foe.health.current_health if is_instance_valid(foe) else 0
		print("FPPROBE|contra_dano|vida %d -> %d" % [hp_foe, hp_after])
		check(hp_after < hp_foe, "o contra-ataque acerta quem foi aparado")
		# fora da janela: ataque normal
		await wait(0.8)
		pl._riposte_t = 0.0
		Input.action_press("attack_light")
		await frames(2)
		Input.action_release("attack_light")
		check(not pl.riposting, "sem aparo, o ataque é o golpe normal")
		await wait(0.8)
		if is_instance_valid(foe):
			foe.queue_free()

		# --- Telegrafo por contorno e pose de morte (chefe por quadros) ---------
		var boss := spawn(lv, "arconte_sono", pl.global_position + Vector2(170, -10))
		await wait(0.6)
		var framed: bool = boss.visual.has_boss_frames()
		boss._begin_windup()
		await frames(3)
		var tc: Color = boss.visual.telegraph_color
		print("FPPROBE|telegrafo|quadros=%s contorno=%s modulate=%s" % [str(framed), str(tc), str(boss.visual.modulate)])
		check(framed, "Athoth usa quadros desenhados")
		check(tc.a > 0.5 and boss.visual.modulate.b > 0.95, "telegrafo = contorno (telegraph_color), sem pintar o corpo")
		await snap("telegrafo_contorno", boss.global_position + Vector2(0, -90), Vector2(170, 170))
		boss.attack_timer = 0.0
		boss._begin_strike()
		check(boss.visual.telegraph_color.a == 0.0, "o golpe zera o contorno")
		await wait(0.5)
		boss.estate = Enemy.EState.CHASE
		var gibs0: int = Gib.live_pieces()
		var bpos: Vector2 = boss.global_position
		boss.health.take_damage(999999)
		await wait(0.2)
		var alive_mid: bool = is_instance_valid(boss)
		var anim_mid: String = str(boss.visual.anim_state) if alive_mid else "-"
		print("FPPROBE|morte|0,2s vivo=%s anim=%s gibs=%d" % [str(alive_mid), anim_mid, Gib.live_pieces() - gibs0])
		# Polimento 7: com cérebro (chefes6), a morte de chefe virou um MOMENTO
		# (BossBrain.death_sequence: dor → morte, mais longo) — o tempo e os pedaços
		# são do chefes6; aqui só confere que ele NÃO se parte na hora.
		var has_brain: bool = alive_mid and boss.get("brain") != null
		if has_brain:
			check(Gib.live_pieces() == gibs0, "chefe (death_sequence do chefes6) não se parte na hora")
			print("FPPROBE|morte|com cérebro: o resto da morte é medido pelas ferramentas do chefes6")
			await snap("morte_pose", bpos + Vector2(0, -90), Vector2(170, 170))
		else:
			check(alive_mid and anim_mid == "dead" and Gib.live_pieces() == gibs0, "chefe segura a pose 'dead' antes de se partir")
			await snap("morte_pose", bpos + Vector2(0, -90), Vector2(170, 170))
			await wait(0.45)
			print("FPPROBE|morte|0,65s vivo=%s gibs=%d" % [str(is_instance_valid(boss)), Gib.live_pieces() - gibs0])
			check(not is_instance_valid(boss) and Gib.live_pieces() > gibs0, "depois da pose, desmembra")
			await snap("morte_gibs", bpos + Vector2(0, -60), Vector2(170, 170))

		# --- C1: número de dano some quando o mundo pausa ------------------------
		await wait(0.5)
		DamageNumber.spawn(lv, pl.global_position, 77, Color(1, 0.9, 0.6))
		await frames(1)
		var n0: int = get_tree().get_nodes_in_group("damage_number").size()
		get_tree().paused = true
		await frames(2)
		var n1: int = get_tree().get_nodes_in_group("damage_number").size()
		get_tree().paused = false
		print("FPPROBE|c1|numeros antes=%d pausado=%d" % [n0, n1])
		check(n0 > 0 and n1 == 0, "C1: número de dano some com o mundo pausado")
		# e com a caixa de diálogo de verdade (a cena encenada usa a mesma caixa)
		DamageNumber.spawn(lv, pl.global_position, 88, Color(1, 0.9, 0.6))
		await frames(1)
		var box := DialogueBox.play([{"who": "?", "text": "teste"}])
		await frames(3)
		var n2: int = get_tree().get_nodes_in_group("damage_number").size()
		print("FPPROBE|c1_caixa|pausado=%s numeros=%d" % [str(get_tree().paused), n2])
		check(n2 == 0, "C1: número some quando a caixa de diálogo abre")
		if is_instance_valid(box):
			box.queue_free()
		await frames(2)
		print("QA RESULT: ", errors, " falhas")
		get_tree().quit()
