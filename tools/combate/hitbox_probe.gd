extends Node
## FERRAMENTA (Combate 6 — playtest 2: "o cajado atravessa"): SONDA DE HITBOX.
## Para 5 golpes × 4 tipos de inimigo × 7 distâncias, mede:
##   ESPERADO = o cajado DESENHADO (mão→ponta do quadro na tela, espessura 3 px)
##              encostou na hurtbox do inimigo em algum quadro do golpe;
##   REAL     = o inimigo tomou dano.
## "atravessa" = esperado e não acertou · "apelão" = acertou sem o cajado encostar.
## Roda a mesma bateria com a caixa ANTIGA (34×42 fixa) para comparar.
## Também grava a geometria quadro a quadro (servo a 28 px) num JSON que o
## `tools/combate/hitbox_overlay.py` desenha sobre os quadros do atlas (PNG) —
## tudo headless, sem janela.
## Uso: godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/combate/HitboxProbe.tscn -- [saida.json]
## Saída: linhas "HITBOX|..." e "QA PASS/FAIL" (nova: atravessa ≤ 10 % dos esperados e apelão ≤ 10 % dos acertos).

const SCREEN := 3
const TYPES := ["larva", "servo", "canino", "bruto"]
const MOVES := [["m_L", [], "light"], ["m_LLL", ["light", "light"], "light"], ["m_H", [], "heavy"], ["m_LH", ["light"], "heavy"], ["m_HHH", ["heavy", "heavy"], "heavy"]]
const DISTS := [8.0, 16.0, 24.0, 32.0, 40.0, 48.0, 56.0, 64.0]
const STAFF_R := 1.5          # meia espessura do cajado desenhado (px de mundo)


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var r := Runner.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		r.out_json = args[0]
	get_tree().root.add_child.call_deferred(r)


class Runner extends Node:
	var pl: Player
	var out_json: String = "user://hitbox_probe.json"
	var frames_dump: Array = []
	var hurt_vs_drawn: Dictionary = {}
	var x0: float = 0.0
	var y0: float = 0.0

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
			if is_instance_valid(e) and not e.has_meta("probe") and not e.is_queued_for_deletion():
				e.queue_free()

	func _step(n: int = 1) -> void:
		for i in n:
			await get_tree().physics_frame

	func _main() -> void:
		while true:
			await get_tree().process_frame
			pl = get_tree().get_first_node_in_group("player") as Player
			if pl != null and pl.is_inside_tree():
				break
		await _step(90)
		Progression.weapon_level = 3
		while not pl.is_on_floor():
			await _step()
		x0 = pl.global_position.x
		y0 = pl.global_position.y
		var res_new: Dictionary = await _battery(false)
		var res_old: Dictionary = await _battery(true)
		var contact_ok: bool = await _contact_test()
		_report("NOVA (cajado desenhado)", res_new)
		_report("ANTIGA (caixa 34x42 fixa)", res_old)
		for t in hurt_vs_drawn:
			print("HITBOX|inimigo %s: %s" % [t, hurt_vs_drawn[t]])
		var f := FileAccess.open(out_json, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"frames": frames_dump, "k_height": pl.visual.profile.height}, "\t"))
			f.close()
			print("HITBOX|geometria gravada em ", out_json)
		var exp_n: int = res_new.exp
		var tp: int = res_new.tp
		var real_n: int = res_new.real
		var through: float = float(exp_n - tp) / maxf(1.0, float(exp_n))
		var cheat: float = float(real_n - tp) / maxf(1.0, float(real_n))
		if not contact_ok:
			push_error("QA FAIL: HitboxProbe — encostar no inimigo feriu a Sophia")
		if through <= 0.10 and cheat <= 0.10 and contact_ok:
			print("QA PASS: HitboxProbe (atravessa %.0f %%, apelão %.0f %%)" % [through * 100.0, cheat * 100.0])
		else:
			push_error("QA FAIL: HitboxProbe — atravessa %.0f %%, apelão %.0f %%" % [through * 100.0, cheat * 100.0])
		get_tree().quit()

	## Playtest 2: encostar/atacar colado no inimigo NÃO fere (sem dano de contato).
	func _contact_test() -> bool:
		pl.state = Player.State.IDLE
		pl.global_position = Vector2(x0, y0)
		pl.invuln_timer = 0.0
		var hp0: int = pl.health.current_health
		var en = load(Enemy.ENEMY_SCENE).instantiate()
		en.type_id = "bruto"
		en.set_meta("probe", true)
		pl.get_parent().add_child(en)
		en.global_position = Vector2(x0 + 4.0, y0)
		await _step(2)
		en.set_physics_process(false)          # parado, sem atacar: só o corpo encostado
		for i in 90:
			en.global_position = Vector2(x0 + 4.0, y0)
			pl.invuln_timer = 0.0
			await _step()
		var hp1: int = pl.health.current_health
		en.queue_free()
		await _step(2)
		print("HITBOX|contato: Sophia colada num bruto por 1,5 s: vida %d -> %d" % [hp0, hp1])
		return hp1 == hp0

	func _report(label: String, r: Dictionary) -> void:
		print("HITBOX|%s: esperados=%d reais=%d certos=%d atravessa=%d apelão=%d alcance_max_real=%.0f px alcance_max_desenho=%.0f px" % [label, r.exp, r.real, r.tp, r.exp - r.tp, r.real - r.tp, r.max_real, r.max_exp])
		print("HITBOX|%s contra o CORPO DESENHADO: cajado encostou no desenho %d vezes, sem dano em %d (%.0f %%) — hurtbox estreita" % [label, r.exp_d, r.miss_d, 100.0 * r.miss_d / maxf(1.0, r.exp_d)])
		print("HITBOX|%s contra o CORPO (frame_geometry): cajado encostou %d vezes, sem dano em %d (%.1f %%)" % [label, r.exp_g, r.miss_g, 100.0 * r.miss_g / maxf(1.0, r.exp_g)])
		for line in r.lines:
			print("HITBOX|  " + line)

	## Uma bateria completa (5 golpes × 4 tipos × 7 distâncias).
	func _battery(legacy: bool) -> Dictionary:
		pl.set("debug_legacy_hitbox", legacy)
		var r := {"exp": 0, "real": 0, "tp": 0, "exp_d": 0, "miss_d": 0, "exp_g": 0, "miss_g": 0, "max_real": 0.0, "max_exp": 0.0, "lines": []}
		for mv in MOVES:
			for t in TYPES:
				var cells: Array[String] = []
				for d in DISTS:
					var dump: bool = (not legacy) and t == "servo" and is_equal_approx(d, 24.0)
					var o: Dictionary = await _trial(String(mv[0]), mv[1], String(mv[2]), t, d, dump)
					var e: bool = o.exp
					var h: bool = o.hit
					r.exp += int(e)
					r.exp_d += int(o.exp_drawn)
					r.miss_d += int(o.exp_drawn and not h)
					r.exp_g += int(o.exp_geo)
					r.miss_g += int(o.exp_geo and not h)
					r.real += int(h)
					r.tp += int(e and h)
					if h:
						r.max_real = maxf(r.max_real, d)
					if e:
						r.max_exp = maxf(r.max_exp, d)
					cells.append("%d:%s" % [int(d), ("ok" if h else "ATRAVESSA") if e else ("APELAO" if h else "-")])
				r.lines.append("%s x %-7s %s" % [mv[0], t, " ".join(cells)])
		pl.set("debug_legacy_hitbox", false)
		return r

	## Um golpe contra um inimigo parado a `d` px (centro a centro) na frente.
	func _trial(move_id: String, prefix: Array, btn: String, type_id: String, d: float, dump: bool) -> Dictionary:
		# Sophia parada no ponto de partida, olhando para a direita
		for a in ["move_left", "move_right", "attack_light", "attack_heavy", "jump", "dodge", "block"]:
			Input.action_release(a)
		pl.state = Player.State.IDLE
		pl.hitbox.deactivate()
		pl.velocity = Vector2.ZERO
		pl.global_position = Vector2(x0, y0)
		pl.reset_physics_interpolation()
		pl.facing = 1
		pl.visual.scale.x = absf(pl.visual.scale.x)
		pl.attack_cd = 0.0
		pl.invuln_timer = 99.0
		await _step(12)
		var en = load(Enemy.ENEMY_SCENE).instantiate()
		en.type_id = type_id
		en.set_meta("probe", true)
		pl.get_parent().add_child(en)
		en.global_position = Vector2(x0 + d, y0)
		en.reset_physics_interpolation()
		await _step(2)
		en.set_physics_process(false)
		en.velocity = Vector2.ZERO
		en.health.max_health = 99999
		en.health.current_health = 99999
		en.global_position = Vector2(x0 + d, y0)
		var hp0: int = en.health.current_health
		# o golpe: prefixo da string + o botão
		pl.combo_sequence.assign(prefix)
		pl.state = Player.State.IDLE
		pl.attack_cd = 0.0
		var ok: bool = pl._attack_input(btn, prefix.size() > 0)
		if not ok or pl.current_move == null or pl.current_move.id != move_id:
			push_warning("HITBOX: golpe %s não saiu (saiu %s)" % [move_id, pl.current_move.id if pl.current_move else "-"])
		var expected := false
		var expected_drawn := false
		var expected_geo := false
		var geo_w := -1.0
		var drawn_w := -1.0
		var n := 0
		while pl.state == Player.State.ATTACK and n < 120:
			await _step()
			n += 1
			if not is_instance_valid(en):
				break
			en.global_position.x = x0 + d          # parado (o golpe empurra)
			var g: Dictionary = StaffReach.current(pl.visual)
			var hurt: Rect2 = _hurt_rect(en)
			var touch := false
			if pl.hit_started and g.has("tip"):
				var hand: Vector2 = pl.to_global(Vector2(g.hand.x * pl.facing, g.hand.y))
				var tip: Vector2 = pl.to_global(Vector2(g.tip.x * pl.facing, g.tip.y))
				var segs: Array = [[hand, tip]]
				# o arco desenhado (smear) entre a ponta anterior e a atual
				if g.get("prev") != null:
					var pv: Vector2 = pl.to_global(Vector2(g.prev.x * pl.facing, g.prev.y))
					segs.append([pv, tip])
					segs.append([hand, pv])
				touch = _segs_hit(segs, hurt.grow(STAFF_R))
				expected = expected or touch
				var dr: Rect2 = _drawn_rect(en, hurt)
				if dr.size.x > 0.0 and _segs_hit(segs, dr):
					expected_drawn = true
				# Polimento 7: corpo pela API oficial da Arte (silhueta medida por quadro)
				var gb: Rect2 = _geo_body(en)
				if gb.size.x > 0.0:
					geo_w = gb.size.x
					if _segs_hit(segs, gb):
						expected_geo = true
			if drawn_w < 0.0:
				drawn_w = _drawn_width(en)
			if dump:
				var hb := pl.hitbox
				frames_dump.append({
					"move": move_id, "seq": g.get("seq", ""), "i": g.get("i", -1),
					"hand": _v(g.get("hand", Vector2.INF)), "tip": _v(g.get("tip", Vector2.INF)),
					"hit_rect": [hb.position.x, hb.position.y, hb.box_size().x, hb.box_size().y],
					"live": hb.monitoring,
					"hurt": [hurt.position.x - pl.global_position.x, hurt.position.y - pl.global_position.y, hurt.size.x, hurt.size.y],
					"touch": touch,
				})
		var hit: bool = is_instance_valid(en) and en.health.current_health < hp0
		if is_instance_valid(en):
			en.queue_free()
		await _step(2)
		if not hurt_vs_drawn.has(type_id):
			hurt_vs_drawn[type_id] = "hurtbox %.0f px × corpo (frame_geometry) %s × malha %s" % [_hurt_rect_size(type_id), ("%.0f px" % geo_w) if geo_w > 0.0 else "n/d", ("%.0f px" % drawn_w) if drawn_w > 0.0 else "n/d (sem _draw no headless)"]
		return {"exp": expected, "hit": hit, "exp_drawn": expected_drawn, "exp_geo": expected_geo}

	## Corpo DESENHADO pela API da Arte: `visual.frame_geometry(true).body` (mundo).
	func _geo_body(en: Node) -> Rect2:
		var art = en.get("visual")
		if art == null or not art.has_method("frame_geometry"):
			return Rect2()
		var g: Dictionary = art.frame_geometry(true)
		return g.get("body", Rect2())

	func _segs_hit(segs: Array, r: Rect2) -> bool:
		for sg in segs:
			if _seg_hits_rect(sg[0], sg[1], r):
				return true
		return false

	## Corpo DESENHADO do inimigo: faixa x da malha pintada (−10 % de cada lado,
	## as bordas do quadro têm transparência) × a faixa y da hurtbox.
	func _drawn_rect(en: Node, hurt: Rect2) -> Rect2:
		var art = en.get("visual")
		if art == null or art._body_mesh.is_empty():
			return Rect2()
		var xf: Transform2D = art.get_global_transform() * art._body_xform
		var lo := INF
		var hi := -INF
		for p in PackedVector2Array(art._body_mesh.pts):
			var gx: float = (xf * p).x
			lo = minf(lo, gx)
			hi = maxf(hi, gx)
		var m: float = (hi - lo) * 0.1
		return Rect2(lo + m, hurt.position.y, maxf(0.0, hi - lo - 2.0 * m), hurt.size.y)

	var _hurt_w: Dictionary = {}
	func _hurt_rect_size(type_id: String) -> float:
		return float(_hurt_w.get(type_id, 0.0))

	## Largura do corpo DESENHADO do inimigo (AABB da malha pintada, em px de mundo).
	func _drawn_width(en: Node) -> float:
		var cs: CollisionShape2D = en.get_node("Hurtbox/HurtShape")
		_hurt_w[en.type_id] = (cs.shape as RectangleShape2D).size.x * absf(cs.global_scale.x)
		var art = en.get("visual")
		if art == null or art._body_mesh.is_empty():
			return -1.0
		var pts: PackedVector2Array = art._body_xform * PackedVector2Array(art._body_mesh.pts)
		var lo := INF
		var hi := -INF
		for p in pts:
			var gx: float = (art.get_global_transform() * p).x
			lo = minf(lo, gx)
			hi = maxf(hi, gx)
		return hi - lo

	func _v(p: Vector2) -> Array:
		return [p.x, p.y] if p != Vector2.INF else []

	func _hurt_rect(en: Node) -> Rect2:
		var cs: CollisionShape2D = en.get_node("Hurtbox/HurtShape")
		var sz: Vector2 = (cs.shape as RectangleShape2D).size * cs.global_scale.abs()
		return Rect2(cs.global_position - sz * 0.5, sz)

	func _seg_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
		if r.has_point(a) or r.has_point(b):
			return true
		var c := [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]
		for j in 4:
			if Geometry2D.segment_intersects_segment(a, b, c[j], c[(j + 1) % 4]) != null:
				return true
		return false
