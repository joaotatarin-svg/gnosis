extends Node
## FERRAMENTA (chefes6, 28/10 — playtest do João no Rei): SONDA DO REI.
## 1) CAIXA × DESENHO: força poses (parado, preparo, golpe, recuperação, dor)
##    e mede, em 5 alturas do chão, quanto da silhueta PINTADA do Rei está
##    coberta pela caixa de dano (cobertura) e quanto da caixa cai fora do
##    desenho (apelão). Compara a caixa GENÉRICA (Hurtbox/HurtShape) com a
##    BodyBox do chefe (se existir).
## 2) ESPERADO × REAL: a Sophia dá golpes leves de 9 distâncias até o Rei.
##    ESPERADO = a caixa do cajado (quadro de impacto) encostou no desenho;
##    REAL = o Rei perdeu vida. "atravessa" = esperado sem dano.
## 3) GOLPES: força cada poder (leque, gesto, raio, mão, anéis, teleporte) e
##    fotografa o meio de cada um (achar o "quadrado").
## Com janela, salva PNGs com as caixas desenhadas por cima: vermelho = caixa
## genérica, verde = BodyBox, amarelo = borda do desenho medida.
## Uso:
##   headless (números): godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/chefes6/ReiProbe.tscn -- out=C:/x/rei tag=depois
##   janela (fotos):     godot --audio-driver Dummy --fixed-fps 60 --resolution 640x360 --position 4000,4000 --path . res://tools/chefes6/ReiProbe.tscn -- out=C:/x/rei tag=depois fotos
## Saída: <out>_<tag>.txt (linhas "REI|...") e <out>_<tag>_*.png.

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var w := Runner.new()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		match kv[0]:
			"out": w.out = kv[1]
			"tag": w.tag = kv[1]
			"fotos": w.photos = true
			"sem_caixa": w.no_body = true
			"tela": w.screen = int(kv[1])
	get_tree().root.add_child.call_deferred(w)


class Runner extends Node:
	var out: String = "user://rei_probe"
	var tag: String = "x"
	var photos: bool = false
	var no_body: bool = false          # "antes": tira a BodyBox e religa a caixa genérica
	var screen: int = 1
	var boss: Enemy = null
	var pl: Player = null
	var lines: Array[String] = []
	var atlas_img: Image = null
	var overlay: Overlay = null
	var hp_lost: int = 0
	var _frozen: bool = false
	var _t: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		seed(hash("rei-probe"))
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_d: float) -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
		var cs := get_tree().current_scene
		if cs != null:
			for c in cs.get_children():
				if c is CanvasLayer and c.has_method("_close"):
					c._close()

	func _physics_process(d: float) -> void:
		_t += d
		if _t > 240.0:
			_log("REI|ERRO|tempo esgotado")
			_finish()
			return
		if pl == null:
			pl = get_tree().get_first_node_in_group("player") as Player
			return
		if boss == null:
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and e.is_boss_enemy and e.brain != null and e.process_mode != Node.PROCESS_MODE_DISABLED:
					boss = e
			if boss == null:
				Input.action_press("move_right")
				return
			Input.action_release("move_right")
			boss.health.health_changed.connect(_on_hp)
			_run.call_deferred()
			return
		# Sophia imortal; o Rei não decide nada sozinho (a sonda manda)
		if pl.health != null:
			pl.health.current_health = pl.health.max_health
		if _frozen and is_instance_valid(boss) and boss.brain != null:
			var br = boss.brain
			br._gap_t = 999.0
			br._hit_times.clear()
			br._poise = br._poise_max
			boss.velocity.x = 0.0

	var _hp_prev: int = -1
	func _on_hp(cur: int, _mx: int = 0) -> void:
		if _hp_prev >= 0 and cur < _hp_prev:
			hp_lost += _hp_prev - cur
		_hp_prev = cur

	func _log(s: String) -> void:
		print(s)
		lines.append(s)

	func _finish() -> void:
		var f := FileAccess.open("%s_%s.txt" % [out, tag], FileAccess.WRITE)
		if f:
			for l in lines:
				f.store_line(l)
			f.close()
		get_tree().quit()

	func _wait(s: float) -> void:
		var n := int(round(s * 60.0))
		for i in n:
			await get_tree().physics_frame

	# --- roteiro ---------------------------------------------------------
	func _run() -> void:
		await _wait(2.5)                       # entrada do chefe/diálogo
		_frozen = true
		boss.move_speed = 0.0
		var lv := boss.get_parent()
		var b: Vector2 = boss.brain.arena_bounds()
		var cx: float = (b.x + b.y) * 0.5
		boss.global_position.x = cx
		boss.reset_physics_interpolation()
		pl.global_position.x = cx - 170.0
		pl.reset_physics_interpolation()
		if no_body and boss.get_node_or_null("BodyBox") != null:
			boss.get_node("BodyBox").queue_free()
			await get_tree().physics_frame
			(boss.get_node("Hurtbox/HurtShape") as CollisionShape2D).disabled = false
		await _wait(0.6)
		var db: Dictionary = boss.visual._boss_db
		atlas_img = Image.load_from_file(ProjectSettings.globalize_path(String(db.meta.atlas)))
		overlay = Overlay.new()
		overlay.r = self
		overlay.z_index = 200
		overlay.z_as_relative = false
		lv.add_child(overlay)
		_log("REI|INFO|tag=%s|bodybox=%s|art_scale=%.2f" % [tag, str(not no_body and boss.get_node_or_null("BodyBox") != null), boss._art_scale])
		# 1) caixa × desenho em várias poses
		await _measure("parado")
		for mv_id in ["gesto", "mao", "leque"]:
			boss.brain._start(boss.brain._find(mv_id))
			await _wait(boss.wind_up * 0.5)
			await _measure(mv_id + "_preparo")
			while boss.estate == Enemy.EState.WINDUP:
				await get_tree().physics_frame
			await _wait(0.05)
			await _measure(mv_id + "_golpe")
			while boss.estate == Enemy.EState.STRIKE:
				await get_tree().physics_frame
			await _wait(0.1)
			await _measure(mv_id + "_recupera")
			_clear_hazards()
			await _wait(1.6)
		# 2) esperado × real (golpe leve da Sophia, de fora para dentro)
		await _hits()
		# 3) os poderes (fotos)
		if photos:
			await _moves()
		_finish()

	func _clear_hazards() -> void:
		for n in get_tree().get_nodes_in_group("boss_hazard"):
			n.queue_free()
		for n in boss.get_parent().get_children():
			if n is Projectile:
				n.queue_free()

	# --- 1) cobertura ------------------------------------------------------
	const HEIGHTS := [8.0, 24.0, 40.0, 64.0, 96.0]

	func _measure(label: String) -> void:
		await get_tree().physics_frame
		var gy: float = boss.brain.ground_y()
		var tot := {"drawn": 0, "main_in": 0, "main_out": 0, "body_in": 0, "body_out": 0}
		var edges: Array = []
		for h in HEIGHTS:
			var y: float = gy - float(h)
			var lo := INF
			var hi := -INF
			for xi in range(-260, 261, 2):
				var p := Vector2(boss.global_position.x + float(xi), y)
				var dr := _drawn(p)
				var im := _in_main(p)
				var ib := _in_body(p)
				if dr:
					tot.drawn += 1
					lo = minf(lo, p.x)
					hi = maxf(hi, p.x)
				if im:
					tot.main_in += 1 if dr else 0
					tot.main_out += 0 if dr else 1
				if ib:
					tot.body_in += 1 if dr else 0
					tot.body_out += 0 if dr else 1
			if lo < INF:
				edges.append([Vector2(lo, y), Vector2(hi, y)])
		overlay.edges = edges
		var main_n: int = tot.main_in + tot.main_out
		var body_n: int = tot.body_in + tot.body_out
		_log("REI|CAIXA|%s|quadro=%s|desenho=%d|generica: cobre %d%% fora %d%%|bodybox: cobre %d%% fora %d%%" % [label, boss.visual._shown_key, tot.drawn,
			_pct(tot.main_in, tot.drawn), _pct(tot.main_out, main_n), _pct(tot.body_in, tot.drawn), _pct(tot.body_out, body_n)])
		if photos:
			await _shot("caixa_" + label)

	func _pct(a: int, b: int) -> int:
		return 0 if b <= 0 else int(round(100.0 * float(a) / float(b)))

	## O ponto (global) cai num pixel OPACO do quadro do Rei que está na tela?
	func _drawn(p: Vector2) -> bool:
		var v = boss.visual
		var key: String = v._shown_key
		var cut := key.rfind(":")
		if cut <= 0 or atlas_img == null:
			return false
		var seq: Dictionary = v._boss_db.meta.states.get(key.substr(0, cut), {})
		var i := int(key.substr(cut + 1))
		if seq.is_empty() or i >= seq.frames.size():
			return false
		var ent: Dictionary = seq.frames[i]
		var fr: Dictionary = v._boss_db.meta.frames[ent.f]
		var xf: Transform2D = v.get_global_transform() * v._body_xform
		var q: Vector2 = xf.affine_inverse() * p + Vector2(float(ent.anchor[0]), float(ent.anchor[1]))
		var rr: Array = fr.rect
		if q.x < 0.0 or q.y < 0.0 or q.x >= float(rr[2]) or q.y >= float(rr[3]):
			return false
		return atlas_img.get_pixel(int(rr[0]) + int(q.x), int(rr[1]) + int(q.y)).a >= 0.5

	func _main_rect() -> Rect2:
		var hs: CollisionShape2D = boss.get_node_or_null("Hurtbox/HurtShape")
		if hs == null or hs.disabled or not (hs.shape is RectangleShape2D):
			return Rect2()
		var sz: Vector2 = (hs.shape as RectangleShape2D).size
		var xf: Transform2D = hs.get_global_transform()
		return Rect2(xf * (-sz * 0.5), Vector2.ZERO).expand(xf * (sz * 0.5))

	func _in_main(p: Vector2) -> bool:
		var r := _main_rect()
		return r.size != Vector2.ZERO and r.has_point(p)

	func _body_rects() -> Array:
		var bb = boss.get_node_or_null("BodyBox")
		var out_r: Array = []
		if bb != null:
			for r in bb.rects:
				out_r.append(Rect2(boss.global_transform * r.position, r.size))
		return out_r

	func _in_body(p: Vector2) -> bool:
		for r in _body_rects():
			if (r as Rect2).has_point(p):
				return true
		return false

	# --- 2) esperado × real -------------------------------------------------
	func _hits() -> void:
		var bx: float = boss.global_position.x
		var res: Array[String] = []
		var atravessa := 0
		var apelao := 0
		var esperados := 0
		for dist in [150.0, 120.0, 100.0, 95.0, 90.0, 85.0, 80.0, 75.0, 70.0, 65.0, 60.0, 55.0, 50.0]:
			boss.health.current_health = boss.health.max_health
			_hp_prev = boss.health.current_health
			hp_lost = 0
			pl.global_position = Vector2(bx - dist, pl.global_position.y)
			pl.velocity = Vector2.ZERO
			pl.reset_physics_interpolation()
			pl.facing = 1
			await _wait(0.5)
			pl.global_position.x = bx - dist
			Input.action_press("attack_light")
			await get_tree().physics_frame
			Input.action_release("attack_light")
			var touched := false
			var shot_done := false
			for k in 40:
				await get_tree().physics_frame
				if pl.hitbox.monitoring:
					if _hitbox_touches_drawing():
						touched = true
					if photos and not shot_done:
						shot_done = true
						overlay.staff = _hitbox_rect()
						await _shot("golpe_%d" % int(dist))
						overlay.staff = Rect2()
			var hit := hp_lost > 0
			if touched:
				esperados += 1
			if touched and not hit:
				atravessa += 1
			if hit and not touched:
				apelao += 1
			res.append("%d:%s%s" % [int(dist), "E" if touched else "-", "A" if hit else "-"])
			_log("REI|GOLPE|dist=%d|esperado=%s|real=%s|dano=%d" % [int(dist), str(touched), str(hit), hp_lost])
			await _wait(0.4)
		_log("REI|RESUMO|esperados=%d|atravessa=%d|apelao=%d|%s" % [esperados, atravessa, apelao, " ".join(res)])

	func _hitbox_rect() -> Rect2:
		var cs: CollisionShape2D = pl.hitbox._shape_node()
		if cs == null or not (cs.shape is RectangleShape2D):
			return Rect2()
		var sz: Vector2 = (cs.shape as RectangleShape2D).size
		var xf: Transform2D = cs.get_global_transform()
		return Rect2(xf * (-sz * 0.5), Vector2.ZERO).expand(xf * (sz * 0.5))

	func _hitbox_touches_drawing() -> bool:
		var r := _hitbox_rect()
		if r.size == Vector2.ZERO:
			return false
		var x := r.position.x
		while x <= r.end.x:
			var y := r.position.y
			while y <= r.end.y:
				if _drawn(Vector2(x, y)):
					return true
				y += 2.0
			x += 2.0
		return false

	# --- 3) poderes ----------------------------------------------------------
	func _moves() -> void:
		var bx: float = boss.global_position.x
		boss.health.current_health = boss.health.max_health
		for mv_id in ["leque", "gesto", "raio", "mao", "aneis", "teleporte"]:
			pl.global_position.x = bx - 170.0
			pl.reset_physics_interpolation()
			boss.global_position.x = bx
			boss.reset_physics_interpolation()
			await _wait(0.6)
			boss.brain._start(boss.brain._find(mv_id))
			var shots := 0
			var tt := 0.0
			while tt < 2.4 and shots < 4:
				await _wait(0.4)
				tt += 0.4
				await _shot("poder_%s_%d" % [mv_id, shots])
				shots += 1
			_clear_hazards()
			await _wait(1.5)

	func _shot(name: String) -> void:
		if not photos:
			return
		overlay.queue_redraw()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%s_%s.png" % [out, tag, name])


## Desenha as caixas sobre o mundo (vermelho = genérica, verde = BodyBox,
## amarelo = borda do desenho medida, ciano = cajado da Sophia).
class Overlay extends Node2D:
	var r = null
	var edges: Array = []
	var staff: Rect2 = Rect2()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if r == null or r.boss == null or not is_instance_valid(r.boss):
			return
		var m: Rect2 = r._main_rect()
		if m.size != Vector2.ZERO:
			draw_rect(m, Color(1, 0.15, 0.15, 0.95), false, 1.5)
		for b in r._body_rects():
			draw_rect(b, Color(0.2, 1.0, 0.3, 0.9), false, 1.2)
		for e in edges:
			draw_line(e[0], e[1], Color(1, 0.9, 0.1, 0.8), 1.0)
			draw_circle(e[0], 2.0, Color(1, 0.9, 0.1))
			draw_circle(e[1], 2.0, Color(1, 0.9, 0.1))
		if staff.size != Vector2.ZERO:
			draw_rect(staff, Color(0.2, 0.9, 1.0, 0.95), false, 1.2)
