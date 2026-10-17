extends Node
## SONDA QA-VISUAL (não faz parte do jogo): re-testa no renderer real alguns
## itens do docs/QA_UX_BUGS.md que as sondas da qa-ux não cobrem mais (a HUD
## mudou de API) e mede a Sophia DENTRO do quadro no começo das brigas.
##  A) Batalha final (68): quantas barras, de quem, e o que acontece quando um cai.  (A3)
##  B) Loja do santuário (tela 24, pós-Campeão): legenda por cima? foco? Esc fecha? (A1/A2/M3)
##  C) Morte de pé (tela 3): cai/faz pose "dead"? (A4)
##  D) Sophia no quadro: anda até a zona trancar e mede o x de TELA por 3 s.     (A5)
##  E) Escolha final (3 botões): cabem na tela? o motivo do bloqueado aparece?   (A6)
##  F) Pausa no meio do Arconte (tela 10): Melhorias trancada e com o porquê?     (M6)
## Saída: "VIS|<caso>|<detalhe>" e PNGs vis_*.png na pasta.
## Uso: godot --audio-driver Dummy --path . --resolution 1280x720 --position 4000,4000 \
##        res://tools/qa_visual/VisualProbe.tscn -- <pasta> [casos=ABCD]

func _ready() -> void:
	var w := V.new()
	var a := OS.get_cmdline_user_args()
	w.out_dir = a[0] if a.size() > 0 else "user://"
	if a.size() > 1:
		w.cases = a[1]
	get_tree().root.add_child.call_deferred(w)


class V extends Node:
	var out_dir: String
	var cases: String = "ABCDEF"

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		AudioServer.set_bus_mute(0, true)
		_run.call_deferred()

	func log_v(k: String, d: String) -> void:
		print("VIS|%s|%s" % [k, d])

	func wait(s: float) -> void:
		await get_tree().create_timer(s, true, false, true).timeout

	func shot(name: String) -> void:
		await RenderingServer.frame_post_draw
		var p := "%s/vis_%s.png" % [out_dir, name]
		get_viewport().get_texture().get_image().save_png(p)
		log_v("SHOT", p)

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

	func pad(b: JoyButton) -> void:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = true
		Input.parse_input_event(e)
		await wait(0.06)
		var r := e.duplicate()
		r.pressed = false
		Input.parse_input_event(r)
		await wait(0.15)

	func skip_dialogs() -> void:
		for i in 60:
			var open := false
			for c in get_tree().root.get_children():
				if c is DialogueBox:
					open = true
					if c.choices.size() > 0:
						c._on_choice(0)
					else:
						c._finish()
			if not open:
				return
			await wait(0.1)

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

	func screen_x(n: Node2D) -> Vector2:
		return get_viewport().get_canvas_transform() * n.global_position

	func bosses() -> Array:
		var out := []
		for en in get_tree().get_nodes_in_group("enemy"):
			if en is Enemy and en.is_boss_enemy and en.estate != Enemy.EState.DEAD:
				out.append(en)
		return out

	func hud() -> Node:
		return get_tree().get_first_node_in_group("hud")

	func boss_str(h: Node) -> String:
		if h == null:
			return "sem hud"
		var b = h.get("boss")
		var nm := "<nenhum>"
		if b != null and is_instance_valid(b):
			nm = str(b.get("display_name"))
		return "barra_de='%s' ratio=%.2f fase=%d visivel=%.2f" % [nm, float(h.get("boss_ratio")), int(h.get("boss_phase_n")), float(h.get("_boss_show"))]

	func _run() -> void:
		if "A" in cases:
			await _case_final()
		if "B" in cases:
			await _case_shop()
		if "C" in cases:
			await _case_death()
		if "D" in cases:
			for s in [3, 13, 22, 31, 40, 50, 58, 66]:
				await _case_frame(s)
		if "E" in cases:
			await _case_choices()
		if "F" in cases:
			await _case_pause_boss()
		log_v("FIM", "")
		get_tree().quit()

	# ---- A) batalha final ----
	func _case_final() -> void:
		await level_at(68)
		await wait(3.0)
		await skip_dialogs()
		var bs := bosses()
		var lv := get_tree().current_scene
		log_v("final_chefes", ", ".join(bs.map(func(b): return "%s hp=%d/%d tela=%s" % [b.display_name, b.health.current_health, b.health.max_health, str(screen_x(b))])))
		log_v("final_inicio", boss_str(hud()))
		await shot("final_inicio")
		if bs.size() >= 2:
			var b0: Enemy = bs[0]
			b0._on_hit_received(int(b0.health.max_health * 0.6), lv.player.global_position, 10.0, false, null)
			await wait(0.8)
			log_v("final_apos_bater_em_" + b0.display_name, boss_str(hud()))
			await shot("final_bateu_um")
			b0._on_hit_received(b0.health.max_health + 999, lv.player.global_position, 10.0, false, null)
			await wait(1.0)
			await skip_dialogs()
			log_v("final_um_caiu", boss_str(hud()) + " outro_vivo=" + str(bs[1].estate != Enemy.EState.DEAD))
			await shot("final_um_caiu")

	# ---- B) loja do santuário ----
	func _case_shop() -> void:
		await level_at(24)
		var menu: Node = null
		for i in 120:
			await skip_dialogs()
			for c in get_tree().current_scene.get_children():
				if c.scene_file_path.ends_with("UpgradeMenu.tscn"):
					menu = c
			if menu != null:
				break
			var lv := get_tree().current_scene
			if lv is Level:
				lv.player.health.current_health = lv.player.health.max_health
				for en in get_tree().get_nodes_in_group("enemy"):
					if en is Enemy and en.estate != Enemy.EState.DEAD:
						en._on_hit_received(99999, lv.player.global_position, 10.0, false, null)
				if not lv.zone_active:
					Input.action_press("move_right")
			await wait(0.25)
		Input.action_release("move_right")
		if menu == null:
			log_v("loja_santuario", "NAO_ABRIU")
			return
		# força uma legenda no momento da loja (como acontece no jogo, ex.: a Voz comenta)
		Gnosis.caption("A Voz", "Teste de sobreposição: esta legenda não deveria aparecer por cima da loja.")
		await wait(1.6)
		var cap: Node = null
		for c in Gnosis.get_children():
			if c is CaptionBar:
				cap = c
		var cap_vis := "?"
		if cap != null:
			cap_vis = "layer=%d visivel=%s alpha=%.2f" % [cap.layer, str(cap.visible), float(cap.get("_root").modulate.a) if cap.get("_root") != null else -1.0]
		var fo := get_viewport().gui_get_focus_owner()
		log_v("loja_santuario", "paused=%s layer_loja=%s legenda[%s] foco=%s" % [str(get_tree().paused), str(menu.get("layer")), cap_vis, (fo.get("text") if fo != null else "<nenhum>")])
		await shot("loja_santuario")
		await key(KEY_DOWN)
		fo = get_viewport().gui_get_focus_owner()
		log_v("loja_santuario_baixo", "foco=" + (str(fo.get("text")) if fo != null else "<nenhum>"))
		await pad(JOY_BUTTON_B)
		await wait(0.4)
		log_v("loja_santuario_B", "aberta=" + str(is_instance_valid(menu) and menu.is_inside_tree()))

	# ---- C) morte de pé ----
	func _case_death() -> void:
		await level_at(3)
		await wait(0.5)
		var lv := get_tree().current_scene as Level
		var pl: Player = lv.player
		var y0 := pl.global_position.y
		pl._on_hit_received(99999, pl.global_position + Vector2(30, 0), 10.0, true, null)
		await wait(0.25)
		await shot("morte_pe_0")
		await wait(1.0)
		var anim := str(pl.visual.get("anim_state")) if pl.get("visual") != null else "?"
		log_v("morte_pe", "y0=%.0f y=%.0f estado=%d anim=%s" % [y0, pl.global_position.y, int(pl.state), anim])
		await shot("morte_pe_1")

	# ---- D) Sophia dentro do quadro ----
	func _case_frame(screen: int) -> void:
		await level_at(screen)
		var lv := get_tree().current_scene as Level
		var t := 0.0
		Input.action_press("move_right")
		while t < 10.0 and not lv.zone_active:
			await wait(0.1)
			await skip_dialogs()
			t += 0.1
		Input.action_release("move_right")
		var n := 0
		var fora := 0
		var xmin := 9999.0
		var xmax := -9999.0
		for i in 30:
			lv.player.health.current_health = lv.player.health.max_health
			var p := screen_x(lv.player)
			n += 1
			xmin = minf(xmin, p.x)
			xmax = maxf(xmax, p.x)
			if p.x < 8.0 or p.x > 632.0:
				fora += 1
			if i == 10:
				await shot("quadro_t%02d" % screen)
			await wait(0.1)
		log_v("quadro_t%02d" % screen, "zona=%s x_tela=[%.0f,%.0f] de 640  fora_do_quadro=%d/%d" % [str(lv.zone_active), xmin, xmax, fora, n])

	# ---- E) escolha final ----
	func _case_choices() -> void:
		await level_at(68)
		await wait(0.5)
		var d := DialogueBox.play([{"speaker": "Sophia", "text": "Ninguém vai escolher por mim."}], Narrative.final_choices(0))
		for i in 12:
			if d._in_choices:
				break
			await key(KEY_J)
			await wait(0.3)
		await wait(0.8)
		var vr := get_viewport().get_visible_rect()
		var info := []
		for b in d._choice_box.get_children():
			if b is Button:
				var r: Rect2 = b.get_global_rect()
				info.append("'%s' x=[%.0f,%.0f] dentro=%s desab=%s" % [b.text, r.position.x, r.end.x, str(vr.encloses(r)), str(b.disabled)])
		var box_r: Rect2 = d._choice_box.get_global_rect()
		log_v("escolha_final", "em_escolha=%s caixa_x=[%.0f,%.0f] tela=%.0f | %s" % [str(d._in_choices), box_r.position.x, box_r.end.x, vr.size.x, " | ".join(info)])
		await shot("escolha_final")

	# ---- F) pausa no meio do chefe ----
	func _case_pause_boss() -> void:
		await level_at(10)
		var lv := get_tree().current_scene as Level
		var t := 0.0
		Input.action_press("move_right")
		while t < 12.0 and (not lv.zone_active or bosses().is_empty()):
			await wait(0.1)
			await skip_dialogs()
			t += 0.1
		Input.action_release("move_right")
		await wait(2.5)
		await skip_dialogs()
		await key(KEY_ESCAPE)
		await wait(0.6)
		var b: Button = null
		for n in get_tree().root.find_children("*", "Button", true, false):
			if n is Button and str(n.text).begins_with("Melhorias") and n.is_visible_in_tree():
				b = n
		log_v("pausa_chefe", "paused=%s chefes_vivos=%d melhorias=%s" % [str(get_tree().paused), bosses().size(), ("desabilitada=" + str(b.disabled)) if b != null else "nao_achada"])
		await shot("pausa_chefe")
