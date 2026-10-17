extends Node2D
## FERRAMENTA (fora do jogo): prancha/filme de ANIMAÇÃO da Sophia e de 3 criaturas.
## Uso:
##   godot --path . --resolution 1280x720 res://tools/AnimQA.tscn -- board <saida.png>
##       prancha parada: Sophia em todos os estados (quadro do meio da ação) +
##       servo/canino/larva em passo, preparo, golpe, dano e dissolução.
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <pasta>/f.png \
##         res://tools/AnimQA.tscn -- film_sophia
##       roteiro: parada → corre → leve, leve → forte → esquiva frente/trás →
##       bloqueio → magia → pulo/queda → dano → morte. (ffmpeg monta o GIF.)
##   ... -- film_criaturas     servo, canino e larva andam, golpeiam, apanham e dissolvem.
##   ... -- run_drift <saida.json>   mede a deriva do pé de apoio na corrida.
## Dirige o CharacterArt direto (sem input/IA): o que se vê é só o visual.

const GROUND := 292.0
var mode: String = "board"
var out: String = ""
var actors: Array = []        # [{art, timeline, i, t, vx}]
var clock: float = 0.0
var ended: bool = false
var camera: Camera2D
var follow: Node2D


func _ready() -> void:
	SaveManager.persist_enabled = false
	GameManager.set_state(GameManager.State.MENU)
	RenderingServer.set_default_clear_color(Color("1b232b"))
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		mode = args[0]
	if args.size() >= 2:
		out = args[1]
	_floor()
	match mode:
		"film_sophia": _film_sophia()
		"film_criaturas": _film_creatures()
		"run_drift": await _run_drift()
		_: await _board()


func _floor() -> void:
	var l := Line2D.new()
	l.width = 1.0
	l.default_color = Color(0.45, 0.55, 0.6, 0.6)
	l.add_point(Vector2(-2000, GROUND))
	l.add_point(Vector2(4000, GROUND))
	add_child(l)
	# marcas no chão a cada 40 px: referência pra ver pé patinando
	for i in 150:
		var m := Line2D.new()
		m.width = 1.0
		m.default_color = Color(0.45, 0.55, 0.6, 0.45)
		m.add_point(Vector2(-2000 + i * 40, GROUND))
		m.add_point(Vector2(-2000 + i * 40, GROUND + 6))
		add_child(m)


func _sophia(pos: Vector2, sc: float) -> CharacterArt:
	var p: ArtProfile = Bestiary.player_profile(GameContent.characters[0], 1, [])
	var art := CharacterArt.new()
	add_child(art)
	art.set_profile(p)
	art.position = pos - Vector2(0, CharacterArt.GROUND_Y * p.height / 44.0 * sc)   # pés no chão
	art.scale = Vector2.ONE * sc
	return art


func _creature(id: String, pos: Vector2, sc: float) -> CharacterArt:
	var art := CharacterArt.new()
	add_child(art)
	var p: ArtProfile = Bestiary.get_type(id).profile
	art.set_profile(p)
	art.position = pos - Vector2(0, CharacterArt.GROUND_Y * p.height / 44.0 * sc)
	art.scale = Vector2(-sc, sc)     # olham pra esquerda (pra Sophia)
	return art


func _label(text: String, pos: Vector2) -> void:
	var lb := Label.new()
	lb.text = text
	lb.position = pos
	lb.add_theme_font_size_override("font_size", 8)
	add_child(lb)


# ------------------------------------------------------------------ prancha
func _board() -> void:
	var cells := [["idle", 0.3], ["walk", 0.0], ["windup", 0.02], ["attack", 0.06], ["windup_heavy", 0.1], ["attack_heavy", 0.05],
		["dodge", 0.15], ["dodge_back", 0.15], ["block", 0.3], ["cast", 0.2], ["jump", 0.05], ["fall", 0.2], ["hurt", 0.05], ["dead", 1.0]]
	var n: int = cells.size()
	for i in n:
		var col: int = i % 7
		var row: int = i / 7
		var art := _sophia(Vector2(46 + col * 91, 128 + row * 150), 1.25)
		art.set_process(false)
		var st: String = cells[i][0]
		art.dodge_back = st == "dodge_back"
		art.set_anim("dodge" if st == "dodge_back" else st)
		art.anim_time = cells[i][1]
		if st == "walk":
			art.motion_distance = 20.0
		art.queue_redraw()
		_label(st, Vector2(col * 91 + 4, row * 150 + 6))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://anim_board.png")
	get_tree().quit()


# ------------------------------------------------------------------ filmes
## timeline: [estado, duração, vx (px/s de tela), dodge_back]
func _film_sophia() -> void:
	var art := _sophia(Vector2(160, GROUND), 2.6)
	var cam := Camera2D.new()
	cam.position = Vector2(320, 180)
	add_child(cam)
	cam.make_current()
	camera = cam
	follow = art
	var tl := [["idle", 0.8, 0.0], ["walk", 1.25, 250.0], ["idle", 0.35, 0.0],
		["windup", 0.04, 0.0], ["attack", 0.30, 30.0], ["windup", 0.04, 0.0], ["attack", 0.32, 30.0],
		["idle", 0.25, 0.0], ["windup_heavy", 0.17, 0.0], ["attack_heavy", 0.45, 40.0], ["idle", 0.3, 0.0],
		["dodge", 0.30, 330.0], ["idle", 0.2, 0.0], ["dodge", 0.30, -330.0, true], ["idle", 0.25, 0.0],
		["block", 0.5, 0.0], ["cast", 0.55, 0.0], ["idle", 0.2, 0.0], ["jump", 0.35, 0.0, false, -1.0], ["fall", 0.35, 0.0, false, 1.0],
		["idle", 0.3, 0.0], ["hurt", 0.45, -40.0], ["dead", 1.6, 0.0], ["dead", 0.01, 0.0]]
	actors.append({"art": art, "tl": tl, "i": -1, "t": 0.0, "y0": art.position.y})
	_label("SOPHIA — filme de animação (AnimQA)", Vector2(6, 6))


func _film_creatures() -> void:
	var ids := ["servo", "canino", "larva"]
	for k in ids.size():
		var art := _creature(ids[k], Vector2(600, GROUND - k * 0.0), 1.1)
		art.visible = true
		var tl := [["idle", 0.3 + k * 0.5, 0.0], ["walk", 1.6, -150.0], ["windup", 0.5, 0.0], ["attack", 0.3, 0.0], ["recover", 0.3, 0.0],
			["walk", 0.6, -120.0], ["hurt", 0.3, 40.0], ["idle", 0.3, 0.0], ["dead", 1.3, 0.0], ["dead", 2.0 - k * 0.5, 0.0]]
		actors.append({"art": art, "tl": tl, "i": -1, "t": 0.0, "y0": GROUND, "lane": k})
		art.z_index = 3 - k
	# três faixas de profundidade (2.5D) pra não sobrepor
	for a in actors:
		a.art.position.y -= 70.0 * a.lane
		a.y0 = a.art.position.y
	_label("CRIATURAS — passo, preparo, golpe, dano, dissolução", Vector2(6, 6))


func _process(delta: float) -> void:
	if actors.is_empty() or ended:
		return
	clock += delta
	var alive := false
	for a in actors:
		var art: CharacterArt = a.art
		if a.i < 0 or a.t >= float(a.tl[a.i][1]):
			a.i += 1
			a.t = 0.0
			if a.i >= a.tl.size():
				continue
			var step: Array = a.tl[a.i]
			art.dodge_back = step.size() > 3 and bool(step[3])
			art.set_anim(String(step[0]))
		if a.i >= a.tl.size():
			continue
		alive = true
		var st: Array = a.tl[a.i]
		a.t += delta
		art.position.x += float(st[2]) * delta
		# pose_progress das criaturas (preparo/golpe/recuo)
		art.pose_progress = clampf(a.t / float(st[1]), 0.0, 1.0) if String(st[0]) in ["windup", "attack", "recover"] and not art.painted.get("hero", false) else -1.0
		if st.size() > 4:
			# arco do pulo: sobe e desce
			var u: float = a.t / float(st[1])
			art.position.y = a.y0 - (sin((u * 0.5) * PI) * 70.0 if float(st[4]) < 0.0 else cos((u * 0.5) * PI) * 70.0)
		else:
			art.position.y = a.y0
	if camera != null and follow != null:
		# câmera acompanha devagar (o chão marcado mostra o deslocamento)
		camera.position.x = lerpf(camera.position.x, follow.position.x + 60.0, 1.0 - exp(-delta * 2.5))
	if not alive:
		ended = true
		get_tree().quit()


# ------------------------------------------------------------------ deriva do pé
## Corre a Sophia em velocidade constante e mede, quadro a quadro, onde a
## bota de trás e a da frente caem no MUNDO; grava JSON pra prancha de deriva.
func _run_drift() -> void:
	var art := _sophia(Vector2(100, GROUND), 1.0)
	art.set_process(false)
	var db: Dictionary = CharacterArt.frame_db("sophia")
	var rows: Array = []
	if not db.is_empty():
		var meta: Dictionary = db.meta
		var seq: Dictionary = meta.states.run
		var k: float = art.profile.height * 1.19 / float(meta.body_px)
		for e in seq.frames:
			var fr: Dictionary = meta.frames[e.f]
			rows.append({"f": e.f, "rear_world": (float(fr.rear_x) - float(e.anchor[0])) * k, "front_world": (float(fr.front_x) - float(e.anchor[0])) * k,
				"foot_world": (float(fr.foot_y) - float(e.anchor[1])) * k})
	var f := FileAccess.open(out if out != "" else "user://run_drift.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, " "))
	f.close()
	print("RUN DRIFT: ", rows.size(), " quadros")
	get_tree().quit()


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("ANIMQA salvo: ", path)
