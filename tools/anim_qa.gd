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
		"film_gait": _film_gait(args.size() >= 3 and args[2] == "old")
		"film_criaturas": _film_creatures()
		"film_boss": _film_boss(args[2] if args.size() >= 3 else "arconte_sono")
		"boss_board": await _boss_board(args[2] if args.size() >= 3 else "")
		"shader_cmp": await _shader_cmp()
		"npc_board": await _npc_board()
		"cego_board": await _cego_board()
		"rim_board": await _rim_board()
		"weapon_board": await _weapon_board()
		"bot_board": await _bot_board()
		"own_board": await _own_board(args.size() >= 3 and args[2] == "champ")
		"soter_board": await _soter_board()
		"death_board": await _death_board()
		"film_walk": _film_walk(args.slice(2))
		"film_death": _film_death(args.slice(2), false)
		"film_death_old": _film_death(args.slice(2), true)
		"geo_board": await _geo_board()
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
		["block", 0.5, 0.0], ["block_parry", 0.45, 0.0], ["riposte", 0.45, 20.0], ["cast", 0.55, 0.0], ["idle", 0.2, 0.0], ["jump", 0.35, 0.0, false, -1.0], ["fall", 0.35, 0.0, false, 1.0],
		["idle", 0.3, 0.0], ["hurt", 0.45, -40.0], ["dead", 1.6, 0.0], ["dead", 0.01, 0.0]]
	actors.append({"art": art, "tl": tl, "i": -1, "t": 0.0, "y0": art.position.y})
	_label("SOPHIA — filme de animação (AnimQA)", Vector2(6, 6))


## Fila 9 (S17/S18): parada → arranca → corre → freia → pulo → PULO DUPLO → pouso.
## `old` = como era antes: sem largada/freada e o 2º pulo com a pirueta por código.
var gait_old: bool = false


func _film_gait(old: bool) -> void:
	gait_old = old
	var art := _sophia(Vector2(160, GROUND), 2.6)
	art.drawn_gait = not old
	var cam := Camera2D.new()
	cam.position = Vector2(320, 180)
	add_child(cam)
	cam.make_current()
	camera = cam
	follow = art
	var tl := [["idle", 0.6, 0.0], ["walk", 0.9, 250.0], ["idle", 0.6, 0.0], ["walk", 0.5, 250.0], ["idle", 0.5, 0.0],
		["jump", 0.30, 0.0, false, -1.0], ["fall", 0.12, 0.0, false, 0.2], ["double_jump", 0.34, 40.0, false, -0.8],
		["fall", 0.35, 40.0, false, 1.0], ["idle", 0.6, 0.0]]
	actors.append({"art": art, "tl": tl, "i": -1, "t": 0.0, "y0": art.position.y})
	_label("SOPHIA — arrancada, freada e pulo duplo (%s)" % ("ANTES" if old else "DEPOIS"), Vector2(6, 6))


func _film_creatures() -> void:
	RenderingServer.set_default_clear_color(Color("56636e"))   # fundo claro: bichos são escuros
	var ids := ["servo", "canino", "larva"]
	for k in ids.size():
		var art := _creature(ids[k], Vector2(190 + k * 190, GROUND), 1.9)
		var tl := [["idle", 0.3 + k * 0.25, 0.0], ["walk", 1.4, -55.0], ["windup", 0.5, 0.0], ["attack", 0.3, 0.0], ["recover", 0.3, 0.0],
			["walk", 0.6, 45.0], ["hurt", 0.3, 30.0], ["idle", 0.3, 0.0], ["dead", 1.2, 0.0], ["dead", 1.0 - k * 0.25, 0.0]]
		actors.append({"art": art, "tl": tl, "i": -1, "t": 0.0, "y0": art.position.y})
	_label("CRIATURAS — passo, preparo, golpe, dano, dissolução", Vector2(6, 6))


func _process(delta: float) -> void:
	if actors.is_empty() or ended:
		return
	clock += delta
	var alive := false
	for a in actors:
		var art: CharacterArt = a.art
		if a.i >= a.tl.size():
			continue
		if a.i < 0 or a.t >= float(a.tl[a.i][1]):
			a.i += 1
			a.t = 0.0
			if a.i >= a.tl.size():
				continue
			var step: Array = a.tl[a.i]
			art.dodge_back = step.size() > 3 and bool(step[3])
			# ações avulsas (S14): "block_parry" = guarda + aparo; "riposte" = contra-ataque
			match String(step[0]):
				"block_parry":
					art.set_anim("block")
					art.play_action("parry")
				"riposte":
					art.set_anim("idle")
					art.play_action("riposte")
				"double_jump":
					# o que o player faz no 2º pulo: quadros desenhados (S17) ou,
					# antes deles, a pirueta inteira girando o cartão
					art.set_anim("jump")
					if not gait_old and art.has_action("double_jump"):
						art.play_action("double_jump")
					else:
						var tw := art.create_tween()
						tw.tween_property(art, "rotation", TAU, 0.3).from(0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
						tw.tween_callback(func() -> void: art.rotation = 0.0)
				_:
					art.set_anim(String(step[0]))
		if a.i >= a.tl.size():
			continue
		alive = true
		var st: Array = a.tl[a.i]
		a.t += delta
		art.position.x += float(st[2]) * delta
		# pose_progress das criaturas (preparo/golpe/recuo)
		var s0: String = String(st[0])
		art.pose_progress = clampf(a.t / float(st[1]), 0.0, 1.0) if (s0.begins_with("windup") or s0.begins_with("attack") or s0 == "recover") and not art.painted.get("hero", false) else -1.0
		if st.size() > 4:
			# arco do pulo: sobe e desce
			# |st[4]| = fração: subida de 70 px × f a partir de onde está; queda de f da altura
			var u: float = a.t / float(st[1])
			if a.t <= delta:
				a["ys"] = art.position.y
			var ys: float = float(a.get("ys", a.y0))
			var f: float = absf(float(st[4]))
			if float(st[4]) < 0.0:
				art.position.y = ys - sin((u * 0.5) * PI) * 70.0 * f
			else:
				art.position.y = ys + (a.y0 - ys) * f * (1.0 - cos((u * 0.5) * PI))
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


# ------------------------------------------------------------------ chefes
## Chefe pelo id do Bestiário (arconte_sono, ..., colosso, rei_final).
func _boss(id: String, pos: Vector2, sc: float, puppet: bool = false) -> CharacterArt:
	var art := CharacterArt.new()
	add_child(art)
	var p: ArtProfile = Bestiary.get_type(id).profile
	art.set_profile(p)
	if puppet:
		art._boss_db = {}          # força o boneco (comparação antes × depois)
	art.position = pos - Vector2(0, CharacterArt.GROUND_Y * p.height / 44.0 * sc)
	art.scale = Vector2(sc, sc)
	return art


## Prancha ANTES × DEPOIS por chefe com quadros: linha de cima = boneco antigo,
## linha de baixo = quadros desenhados, nos mesmos estados/instantes.
## `only` = um id; vazio = todos os chefes que têm atlas.
func _boss_board(only: String) -> void:
	RenderingServer.set_default_clear_color(Color("56636e"))
	get_window().size = Vector2i(1400, 520)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var ids: Array = []
	for b in Bestiary.bosses:
		ids.append(b.id)
	ids.append_array(["colosso", "rei_final"])
	if only != "":
		ids = [only]
	var cells := [["idle", -1.0, 0.6], ["walk", -1.0, 0.5], ["windup", 0.9, 0.6], ["attack", 0.15, 0.06], ["recover", 0.5, 0.2], ["hurt", -1.0, 0.08], ["dead", -1.0, 0.5]]
	for id in ids:
		var probe := _boss(id, Vector2(-999, -999), 1.0)
		var framed: bool = probe.has_boss_frames()
		probe.free()
		if not framed and only == "":
			continue
		var stage := Node2D.new()
		add_child(stage)
		for row in 2:
			for i in cells.size():
				var art := _boss(id, Vector2(100 + i * 200, 240 + row * 260), 1.6, row == 0)
				remove_child(art)
				stage.add_child(art)
				art.set_process(false)
				art.set_anim(String(cells[i][0]))
				# avança o relógio visual como no jogo (mola, boneco) até o instante
				var steps: int = int(float(cells[i][2]) * 60.0)
				for f in steps:
					art.pose_progress = float(cells[i][1]) if float(cells[i][1]) < 0.0 else float(cells[i][1]) * float(f + 1) / steps
					if cells[i][0] == "walk":
						art.motion_stride = 1.0
						art.motion_distance += 2.0
					art._process(1.0 / 60.0)
				if row == 0:
					var lb := Label.new()
					lb.text = String(cells[i][0])
					lb.position = Vector2(i * 200 + 10, 4)
					stage.add_child(lb)
			var tag := Label.new()
			tag.text = ("BONECO (antes)" if row == 0 else "QUADROS (depois)") + "  " + id
			tag.position = Vector2(8, 250 + row * 260 - 30)
			stage.add_child(tag)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save((out if out != "" else "user://boss_board") + "_" + id + ".png")
		stage.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## Sophia e uma criatura com o shader painted_flex (cor ao quadrado) × o
## painted_boss (cor do vértice separada): prova do achado do shader.
func _shader_cmp() -> void:
	RenderingServer.set_default_clear_color(Color("56636e"))
	for col in 2:
		var art := _sophia(Vector2(140 + col * 260, GROUND), 2.0)
		var cr := _creature("servo", Vector2(230 + col * 260, GROUND), 1.6)
		for a in [art, cr]:
			a.set_process(false)
			a.set_anim("idle")
			if col == 1:
				a._flex_material().shader = load(CharacterArt.BOSS_SHADER)
			a.queue_redraw()
		_label("painted_flex (hoje)" if col == 0 else "cor do vértice 1x (corrigido)", Vector2(80 + col * 260, 20))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://shader_cmp.png")
	get_tree().quit()


## NPCs por quadros: Soter, Velkar (estados pedidos ao encontro) e o
## Adormecido dormindo → despertando (troca de perfil como no sleeper.gd).
func _npc_board() -> void:
	RenderingServer.set_default_clear_color(Color("56636e"))
	var rows := [[Bestiary.soter_profile(), ["idle", "talk", "bless", "fade"]], [Bestiary.velkar_profile(), ["idle", "talk", "kneel", "farewell"]]]
	for r in rows.size():
		for i in rows[r][1].size():
			var art := CharacterArt.new()
			add_child(art)
			art.set_profile(rows[r][0])
			art.position = Vector2(60 + i * 110, 120 + r * 120) - Vector2(0, CharacterArt.GROUND_Y * art.profile.height / 44.0)
			art.set_process(false)
			art.set_anim(String(rows[r][1][i]))
			for f in 40:
				art._process(1.0 / 60.0)
			_label(String(rows[r][1][i]), Vector2(40 + i * 110, 10 + r * 120))
	# Adormecido: dormindo, depois acorda (0,3 / 0,8 / 1,5 / 3 s)
	var times := [-1.0, 0.3, 0.8, 1.5, 3.0]
	for i in times.size():
		var art := CharacterArt.new()
		add_child(art)
		var p := ArtProfile.new()
		p.body = ArtProfile.Body.HUMANOID
		p.height = 42.0
		p.painted_id = "sleeper"
		p.primary = Color("435962")
		p.eye = Color(0.5, 0.5, 0.55)
		art.set_profile(p)
		art.set_anim("idle")
		art.position = Vector2(60 + i * 110, 340) - Vector2(0, CharacterArt.GROUND_Y * p.height / 44.0)
		art.set_process(false)
		if times[i] >= 0.0:
			var q: ArtProfile = p.duplicate()
			q.eye = Color(1.0, 0.92, 0.55)
			art.set_profile(q)
			for f in int(times[i] * 60.0):
				art._process(1.0 / 60.0)
		_label("dorme" if times[i] < 0.0 else "acorda %.1fs" % times[i], Vector2(40 + i * 110, 250))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://npc_board.png")
	get_tree().quit()


## Contorno de luz dos inimigos (#30): sobre o fundo escuro de Torpor,
## Silêncio e Centro, cada linha = um Éon; à esquerda SEM contorno, à direita
## COM (parado e preparando).
func _rim_board() -> void:
	get_window().size = Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var rows := [[0, ["sonambulo", "larva"]], [3, ["mudo", "invocador"]], [7, ["servo", "canino"]]]
	for r in rows.size():
		var eon: int = rows[r][0]
		var bg := Sprite2D.new()
		bg.texture = SceneryLibrary.layer(eon, "far")
		bg.centered = false
		bg.region_enabled = true
		var tex_h: float = float(bg.texture.get_height())
		bg.region_rect = Rect2(0, tex_h * 0.35, bg.texture.get_width(), tex_h * 0.45)
		bg.scale = Vector2.ONE * 1280.0 / float(bg.texture.get_width())
		bg.position = Vector2(0, r * 240)
		bg.modulate = Color(0.75, 0.75, 0.8)
		add_child(bg)
		CharacterArt.rim_override = eon
		var col: int = 0
		for rim_on in [false, true]:
			for id in rows[r][1]:
				for st in ["idle", "windup"]:
					var art := CharacterArt.new()
					add_child(art)
					art.set_profile(Bestiary.get_type(id).profile)
					art.rim_enabled = rim_on
					var sc: float = 150.0 / (art.profile.height * 1.3)
					art.scale = Vector2(-sc, sc)
					art.position = Vector2(80 + col * 160, r * 240 + 215) - Vector2(0, CharacterArt.GROUND_Y * art.profile.height / 44.0 * sc)
					art.set_process(false)
					art.set_anim(st)
					art.pose_progress = 0.8 if st == "windup" else -1.0
					for f in 20:
						art._process(1.0 / 60.0)
					art.modulate = Color.WHITE
					col += 1
			_label(("COM contorno" if rim_on else "SEM contorno") + " · Éon %d" % eon, Vector2(10 + (0 if not rim_on else 640), r * 240 + 6))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://rim_board.png")
	CharacterArt.rim_override = -1
	get_tree().quit()


## GEOMETRIA POR QUADRO (Onda 6): a Sophia em golpes e 3 inimigos, com
## CharacterArt.frame_geometry(true) desenhada por cima do quadro renderizado:
## verde = caixa do corpo, amarelo = contorno, vermelho = eixo do cajado.
func _geo_board() -> void:
	RenderingServer.set_default_clear_color(Color("2b3440"))
	get_window().size = Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var arts: Array = []
	var cells := [["idle", 0.4], ["attack", 0.25, 1], ["attack", 0.25, 2], ["attack", 0.3, 3], ["attack_heavy", 0.2], ["cast", 0.25], ["dodge", 0.15]]
	for i in cells.size():
		var art := _sophia(Vector2(80 + i * 165, 300), 2.2)
		art.set_process(false)
		if cells[i].size() > 2:
			art.combo_step = int(cells[i][2])
		art.set_anim(String(cells[i][0]))
		art.anim_time = float(cells[i][1])
		art.queue_redraw()
		arts.append(art)
	var ids := ["arconte_fome", "arconte_coroa", "escudeiro", "cao", "rei_final"]
	for k in ids.size():
		var b := _boss(ids[k], Vector2(130 + k * 250, 650), 1.3)
		b.scale.x = -b.scale.x
		b.set_process(false)
		b.set_anim("attack" if k % 2 == 0 else "idle")
		b.pose_progress = 0.3
		b.queue_redraw()
		arts.append(b)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var over := Node2D.new()
	over.z_index = 50
	add_child(over)
	over.draw.connect(func() -> void:
		for a in arts:
			var g: Dictionary = a.frame_geometry(true)
			if g.is_empty():
				continue
			over.draw_rect(g.body, Color(0.2, 1.0, 0.3, 0.9), false, 1.5)
			if g.has("body_poly"):
				var pl: PackedVector2Array = g.body_poly
				pl.append(pl[0])
				over.draw_polyline(pl, Color(1.0, 0.9, 0.2, 0.9), 1.0)
			if g.has("staff"):
				over.draw_line(g.staff[0], g.staff[1], Color(1.0, 0.2, 0.2, 0.95), 3.0)
				over.draw_circle(g.tip, 3.0, Color(1, 1, 1)))
	over.queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://geo_board.png")
	get_tree().quit()


## MORTE DE CHEFE: até 3 chefes lado a lado; parados 0,8 s, levam o golpe final.
## `old` = como era (estado "dead" + desmembramento imediato em 3×3 pedaços);
## senão = play_boss_death (cambaleio, joelhos, pausa, cacos de luz).
func _film_death(ids: Array, old: bool) -> void:
	RenderingServer.set_default_clear_color(Color("2b3440"))
	if ids.is_empty():
		ids = ["arconte_fome", "arconte_coroa", "rei_final"]
	var arts: Array = []
	for k in ids.size():
		var art := _boss(String(ids[k]), Vector2(110 + k * 210, GROUND), 0.62)
		art.scale.x = -art.scale.x
		art.set_anim("idle")
		arts.append(art)
		_label(String(ids[k]), Vector2(70 + k * 210, GROUND + 8))
	_label("MORTE DE CHEFE — " + ("antes (desmembra na hora)" if old else "depois (peso + cacos de luz)"), Vector2(6, 6))
	await get_tree().create_timer(0.8).timeout
	for art in arts:
		if old:
			art.set_anim("dead")
			var parts: Array = art.gib_parts()
			Gib.burst(self, art.global_position, parts, -1.0, art.global_position.y + 30.0, Vector2(120, -160), art.profile.eye, art._ink())
			art.visible = false
		else:
			art.play_boss_death()
	await get_tree().create_timer(2.4).timeout
	get_tree().quit()


## FLUIDEZ (FILA 7): até 4 personagens (ids do Bestiário) ANDANDO lado a lado
## (andar pela distância, chão marcado), golpe e recuperação no fim.
func _film_walk(ids: Array) -> void:
	RenderingServer.set_default_clear_color(Color("56636e"))
	if ids.is_empty():
		ids = ["sonambulo", "glutao", "carcereiro"]
	for k in ids.size():
		var art := _boss(String(ids[k]), Vector2(560, 80 + (k + 1) * 82), 0.9)
		art.scale.x = -art.scale.x       # olha pra esquerda e anda pra esquerda
		var tl := [["walk", 2.4, -38.0], ["windup", 0.5, 0.0], ["attack", 0.25, 0.0], ["recover", 0.7, 0.0], ["idle", 0.3, 0.0]]
		actors.append({"art": art, "tl": tl, "i": -1, "t": 0.0, "y0": art.position.y})
		_label(String(ids[k]), Vector2(6, 80 + k * 82 + 40))
	_label("ANDAR (FILA 7) — quadros desenhados pela distância", Vector2(6, 6))


## Bots de Éon (#7): para cada um, o Arconte (referência), o bot ANTES
## (miniatura dos quadros do Arconte) e DEPOIS (arte própria, ou o interino
## dessaturado/tingido enquanto a folha não chega), parado e preparando.
func _bot_board() -> void:
	get_window().size = Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("3a4450"))
	var bots := [["sonambulo", "arconte_sono"], ["glutao", "arconte_fome"], ["carcereiro", "arconte_corrente"], ["mudo", "arconte_silencio"],
		["reflexo", "arconte_espelho"], ["esporos", "arconte_praga"], ["pretoriano", "arconte_coroa"]]
	for b in bots.size():
		var cx: float = 92.0 + b * 182.0
		var boss_p: ArtProfile = Bestiary.get_type(String(bots[b][1])).profile
		var bot_p: ArtProfile = Bestiary.get_type(String(bots[b][0])).profile
		var cells := [["ARCONTE", boss_p, "idle", false], ["antes", bot_p, "idle", true], ["depois", bot_p, "idle", false], ["depois", bot_p, "windup", false]]
		for i in cells.size():
			var art := CharacterArt.new()
			add_child(art)
			art.set_profile(cells[i][1])
			if cells[i][3]:
				# antes: os quadros do Arconte em escala de criatura, sem paleta própria
				art._boss_db = CharacterArt.frame_db("bosses/" + BossPuppet.NAMES[["arconte_sono", "arconte_fome", "arconte_corrente", "arconte_silencio", "arconte_espelho", "arconte_praga", "arconte_coroa"].find(String(bots[b][1]))])
				art.painted["family"] = false
			var sc: float = (0.55 if i == 0 else 1.0) * 1.6
			art.scale = Vector2(sc, sc)
			var gy: float = [160.0, 330.0, 500.0, 680.0][i]
			art.position = Vector2(cx, gy) - Vector2(0, CharacterArt.GROUND_Y * art.profile.height / 44.0 * sc)
			art.set_process(false)
			art.set_anim(String(cells[i][2]))
			art.pose_progress = 0.8 if cells[i][2] == "windup" else -1.0
			for f in 20:
				art._process(1.0 / 60.0)
			art.modulate = Color.WHITE
			if b == 0:
				_label(String(cells[i][0]), Vector2(4, gy - 150))
		_label(String(bots[b][0]), Vector2(cx - 40, 4))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://bot_board.png")
	get_tree().quit()


## Dono falso do desenho (o CharacterArt lê `type_id`/`is_champion` do pai).
class FakeHost extends Node2D:
	var type_id: String = ""
	var is_champion: bool = false


## Fila 9: inimigos com ARTE PRÓPRIA. Coluna por tipo; linhas: ANTES (o
## interino de hoje: pintura de outra criatura + tinta do tipo) e DEPOIS
## (parado, preparo, golpe/tiro, morte). `champ` = os 7 Campeões de Éon.
func _own_board(champ: bool) -> void:
	get_window().size = Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("3a4450"))
	var ids: Array = Bestiary.EON_BOTS if champ else ["espectro", "alado", "acolito", "cornudo", "fantasma"]
	var rows := [["antes", "idle"], ["parado", "idle"], ["preparo", "windup"], ["golpe", "attack"], ["tiro", "cast"], ["morte", "dead"]]
	var colw: float = 1240.0 / ids.size()
	for b in ids.size():
		var id: String = String(ids[b])
		var def: Dictionary = Bestiary.get_type(id)
		var cx: float = 40.0 + colw * (b + 0.5)
		for i in rows.size():
			var host := FakeHost.new()
			host.type_id = id
			host.is_champion = champ
			add_child(host)
			var art := CharacterArt.new()
			if i == 0:
				add_child(art)       # sem dono = o interino (pintura trocada pelo Bestiary)
			else:
				host.add_child(art)
			art.set_profile(def.profile)
			if i == 0 and def.has("tint"):
				art.self_modulate = def.tint
			var sc: float = 1.15 * (1.35 if champ else 1.0)
			art.scale = Vector2(sc, sc)
			var gy: float = 100.0 + i * 118.0
			host.position = Vector2(cx, gy) - Vector2(0, CharacterArt.GROUND_Y * art.profile.height / 44.0 * sc)
			if i == 0:
				art.position = host.position
			art.set_process(false)
			art.set_anim(String(rows[i][1]))
			art.pose_progress = 0.8 if rows[i][1] in ["windup", "attack", "cast"] else -1.0
			for f in (6 if rows[i][1] == "dead" else 40):
				art._process(1.0 / 60.0)
			if b == 0:
				_label(String(rows[i][0]), Vector2(4, gy - 60))
		_label(("Campeão " if champ else "") + id, Vector2(cx - 50, 4))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://own_board.png")
	get_tree().quit()


## Fila 9 bloco 4: a cena da bênção. ANTES = o que a cena tinha (Soter
## `bless`, Sophia parada); DEPOIS = Soter lift/offer/rest + Sophia
## soter_look/soter_land/soter_bow e a coluna de luz por FX (bless_light).
func _soter_board() -> void:
	get_window().size = Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("2b3440"))
	var pairs := [["ANTES", "bless", "", false], ["fala 0", "lift", "soter_look", true], ["fala 1", "lift", "soter_look", true],
		["fala 4", "offer", "soter_land", false], ["parte", "rest", "soter_bow", false]]
	for i in pairs.size():
		var cx: float = 140.0 + i * 250.0
		var so := CharacterArt.new()
		add_child(so)
		so.set_profile(Bestiary.soter_profile())
		so.scale = Vector2(2.0, 2.0)
		so.position = Vector2(cx - 50, 520) - Vector2(0, CharacterArt.GROUND_Y * so.profile.height / 44.0 * 2.0)
		so.set_process(false)
		so.set_anim(String(pairs[i][1]))
		var hero := _sophia(Vector2(cx + 45, 520), 2.0)
		hero.scale.x = -hero.scale.x        # olha pra ele
		hero.set_process(false)
		hero.set_anim("idle")
		if String(pairs[i][2]) != "":
			hero.play_action(String(pairs[i][2]))
		if pairs[i][3] and i == 2:
			hero.bless_light(true)
		for f in 50:
			so._process(1.0 / 60.0)
			hero._process(1.0 / 60.0)
		_label(String(pairs[i][0]) + " — " + String(pairs[i][1]) + (" / " + String(pairs[i][2]) if String(pairs[i][2]) != "" else ""), Vector2(cx - 110, 300))
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://soter_board.png")
	get_tree().quit()


## FILA 10: morte de chefe em 4 etapas. Coluna por chefe; 1ª linha = ANTES
## (sem o estado `dying`: hurt → quadro de queda, no meio da morte); demais =
## DEPOIS no relógio da morte (tranco, cambaleio, joelhos, tombado).
func _death_board() -> void:
	get_window().size = Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("2b3440"))
	var ids := ["arconte_sono", "arconte_fome", "arconte_corrente", "arconte_silencio", "arconte_espelho", "arconte_praga", "arconte_coroa", "colosso", "rei_final"]
	var times := [0.5, 0.08, 0.25, 0.48, 0.95]
	var colw: float = 1240.0 / ids.size()
	for b in ids.size():
		var cx: float = 40.0 + colw * (b + 0.5)
		for r in times.size():
			var gy: float = 150.0 + r * 135.0
			var art := _boss(String(ids[b]), Vector2(cx, gy), 0.42)
			art.set_process(false)
			if r == 0 and not art._boss_db.is_empty():
				var db: Dictionary = art._boss_db.duplicate()
				var meta: Dictionary = db.meta.duplicate()
				var st: Dictionary = meta.states.duplicate()
				st.erase("dying")
				meta["states"] = st
				db["meta"] = meta
				art._boss_db = db
			art.play_boss_death()
			art._death_t = float(times[r])
			art._process(0.0)
			if b == 0:
				_label(("ANTES" if r == 0 else "t=%.2f s" % times[r]), Vector2(2, gy - 110))
		_label(String(ids[b]).trim_prefix("arconte_"), Vector2(cx - 40, 4))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://death_board.png")
	get_tree().quit()


## Progressão da arma (#46): a Sophia do nível 1 ao 5, parada, golpeando e
## lançando magia (ponta do cajado, rastro e bracelete).
func _weapon_board() -> void:
	get_window().size = Vector2i(1280, 720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color("1b232b"))
	var states := [["idle", 0.4], ["attack_heavy", 0.06], ["cast", 0.2]]
	for lvl in range(1, 6):
		for s in states.size():
			var p: ArtProfile = Bestiary.player_profile(GameContent.characters[0], lvl, [])
			var art := CharacterArt.new()
			add_child(art)
			art.set_profile(p)
			art.weapon_level_override = lvl
			var sc: float = 200.0 / (p.height * 1.19)
			art.scale = Vector2.ONE * sc
			art.position = Vector2(110 + (lvl - 1) * 250 + (s - 1) * 60, 225 + s * 235) - Vector2(0, CharacterArt.GROUND_Y * p.height / 44.0 * sc)
			art.set_process(false)
			art.set_anim(String(states[s][0]))
			for f in int(float(states[s][1]) * 60.0):
				art._process(1.0 / 60.0)
		_label("ARMA nível %d" % lvl, Vector2(60 + (lvl - 1) * 250, 8))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://weapon_board.png")
	get_tree().quit()


## O Cego pequeno (cena D): poses pelo glow como a encenação anima, ao lado
## da Sophia (escala 1,5 como no staging.gd), em fundo escuro da Mente.
func _cego_board() -> void:
	RenderingServer.set_default_clear_color(Color("140f1c"))
	var cases := [["curled", 0.0, 1.5], ["trembling", 0.0, 1.5], ["look_up", 0.3, 1.5], ["reach", 0.7, 1.5], ["lifted", 1.0, 1.5], ["nestled", 1.0, 0.5]]
	for i in cases.size():
		var x: float = 60.0 + i * 100.0
		var s := _sophia(Vector2(x - 26.0, GROUND), 1.0)
		s.set_process(false)
		s.set_anim("idle")
		s.queue_redraw()
		var c := CegoPequeno.new()
		add_child(c)
		c.position = Vector2(x + 4.0, GROUND)
		c.scale = Vector2.ONE * float(cases[i][2])
		c.glow = float(cases[i][1])
		if cases[i][0] == "trembling":
			c.set_anim("trembling")
		c._process(0.0)
		_label("%s (glow %.1f)" % [cases[i][0], cases[i][1]], Vector2(x - 40.0, GROUND + 10.0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(out if out != "" else "user://cego_board.png")
	get_tree().quit()


## Filme de um chefe sozinho: parado → anda → prepara (hold) → golpe → recupera
## → dano → parado → prepara forte → golpe forte → morte (dissolve).
func _film_boss(id: String) -> void:
	RenderingServer.set_default_clear_color(Color("56636e"))
	var art := _boss(id, Vector2(300, GROUND), 1.5)
	art.scale.x = -art.scale.x       # olha pra esquerda, como no jogo
	var tl := [["idle", 1.2, 0.0], ["walk", 1.2, -40.0], ["windup", 0.8, 0.0], ["attack", 0.25, 0.0], ["recover", 0.6, 0.0],
		["idle", 0.4, 0.0], ["hurt", 0.4, 25.0], ["idle", 0.5, 0.0], ["windup_heavy", 0.9, 0.0], ["attack_heavy", 0.3, 0.0],
		["recover", 0.6, 0.0], ["dead", 1.2, 0.0], ["dead", 0.01, 0.0]]
	actors.append({"art": art, "tl": tl, "i": -1, "t": 0.0, "y0": art.position.y})
	_label("CHEFE %s — quadros desenhados (AnimQA)" % id, Vector2(6, 6))


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("ANIMQA salvo: ", path)
