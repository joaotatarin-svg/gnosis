extends Node2D
## QA dos bonecos de chefe (9 chefes + 2 criaturas da família).
## Uso (godot --path . res://tools/PuppetQA.tscn -- <modo> [pasta]):
##   (sem modo) | check  → regressão: pesos normalizados, vínculos, juntas que
##                         mexem, custo (vértices/triângulos/tempo de montagem).
##                         Roda headless. Imprime uma tabela curta.
##   boards <pasta>      → prancha ampliada por boneco: parado, preparação (hold),
##                         pico do golpe, dano e articulações. Precisa de janela.
##   seq <pasta>         → quadros 30 fps de uma sequência fixa (parado, andar,
##                         preparação, golpe, recuperação, dano) com os 11 bonecos
##                         numa grade 4×3; tools/anim_bosses/make_gifs.py corta
##                         cada célula em GIF.
## Tudo é determinístico: a animação é dirigida à mão com passo fixo.

const STEP := 1.0/60.0
var failures: int = 0
var entries: Array = []   # [{name, profile, style}]


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	SaveManager.persist_enabled = false
	GameManager.set_state(GameManager.State.MENU)
	RenderingServer.set_default_clear_color(Color("11171d"))
	for b in Bestiary.bosses: entries.append({"name":b.id,"profile":b.profile,"style":b.style})
	for id in ["colosso","rei_final"]:
		var s: Dictionary = Bestiary.get_type(id)
		entries.append({"name":id,"profile":s.profile,"style":s.style})
	for id in ["glutao","pretoriano"]:
		var c: Dictionary = Bestiary.get_type(id)
		entries.append({"name":id+" (criatura)","profile":c.profile,"style":c.style})
	await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "check"
	var out: String = args[1] if args.size() > 1 else "res://shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	if mode in ["boards","seq"]:
		# 1 unidade = 1 pixel (sem o stretch 640×360 do jogo).
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if mode == "boards": await _boards(out)
	elif mode == "seq": await _sequence(out)
	else: _check()
	print("PUPPET QA: ",failures," falhas")
	get_tree().quit(0 if failures == 0 else 1)


func _make(entry: Dictionary, parent: Node) -> CharacterArt:
	var art := CharacterArt.new()
	parent.add_child(art)
	art.set_profile(entry.profile)
	art.set_process(false)
	return art


func _states(style: String, beast: bool) -> Array:
	match style:
		"slam": return ["windup_heavy","attack_heavy"]
		"ranged": return ["windup_cast","cast"]
		"charge": return ["windup_heavy" if beast else "windup","charge"]
	return ["windup","attack"]


## Linha do tempo: [[estado, duração]]. Progresso = tempo/duração (como o Enemy).
func _timeline(entry: Dictionary) -> Array:
	var st: Array = _states(entry.style,entry.profile.body == ArtProfile.Body.BEAST)
	return [["idle",1.2],["walk",1.0],[st[0],0.8],[st[1],0.25],["recover",0.6],["idle",0.5],["hurt",0.5],["idle",0.6]]


## Avança o boneco de `from` até `until` segundos da linha do tempo.
func _run(puppet: BossPuppet, timeline: Array, from: float, until: float) -> void:
	var t: float = from
	while t < until-0.0001:
		var start: float = 0.0
		var state: String = "idle"
		var dur: float = 1.0
		for seg in timeline:
			if t < start+seg[1]:
				state = seg[0]; dur = seg[1]
				break
			start += seg[1]
		var local: float = t-start
		var progress: float = -1.0
		if state.begins_with("windup") or state in ["attack","attack_heavy","cast","charge","recover"]:
			progress = clampf(local/dur,0,1)
		puppet.drive(state,local,STEP,progress,1.0 if state == "walk" else 0.0,1.0)
		t += STEP


func _check() -> void:
	var table: Array = []
	for entry in entries:
		var art := _make(entry,self)
		var puppet: BossPuppet = art.boss_puppet
		check(puppet != null,"Sem boneco: "+entry.name)
		if puppet == null: continue
		puppet.call("clear_cache")
		var t0: int = Time.get_ticks_usec()
		puppet.call("ensure_built")
		var ms: float = (Time.get_ticks_usec()-t0)/1000.0
		check(puppet.skin != null,"Sem malha: "+entry.name)
		check(puppet.skin.get_bone_count() == puppet.bones.size(),"Vínculos incompletos: "+entry.name)
		var n: int = puppet.skin.polygon.size()
		var bad: int = 0
		for v in n:
			var sum: float = 0
			for bone in puppet.skin.get_bone_count(): sum += puppet.skin.get_bone_weights(bone)[v]
			if absf(sum-1.0) > 0.001: bad += 1
		check(bad == 0,"Pesos não normalizados: %s (%d)" % [entry.name,bad])
		for piece in puppet.pieces:
			check(piece.get_parent() != null and piece.polygon.size() >= 3,"Peça solta: "+entry.name)
		_run(puppet,_timeline(entry),0.0,3.2)
		var joint: Bone2D = puppet.bones.head if puppet.kind == "beast" else puppet.bones.arm_l
		check(absf(joint.rotation) > 0.01,"Articulação imóvel: "+entry.name)
		var cells: int = puppet.grid.x*puppet.grid.y*2
		table.append("%-24s grade %2dx%2d  vértices %4d  triângulos %4d (de %d)  peças %d  montagem %.0f ms" % [entry.name,puppet.grid.x,puppet.grid.y,n,puppet.triangle_count,cells,puppet.pieces.size(),ms])
		art.queue_free()
	for line in table: print(line)


func _place(art: CharacterArt, centre_x: float, ground_y: float, px_height: float) -> void:
	var p: ArtProfile = art.profile
	var h: float = 190.0 if int(art.painted.puppet) == 8 else p.height*1.3
	art.scale = Vector2.ONE*px_height/h
	art.position = Vector2(centre_x,ground_y-art.scale.y*CharacterArt.GROUND_Y*p.height/44.0)


func _label(text: String, pos: Vector2, parent: Node, size: int = 14) -> void:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size",size)
	label.text = text
	parent.add_child(label)


func _boards(out: String) -> void:
	# 5 células de 360 px: parado, preparação (hold), pico do golpe, dano, ossos.
	get_window().size = Vector2i(1800,500)
	await get_tree().process_frame
	for entry in entries:
		var stage := Node2D.new()
		add_child(stage)
		var tl: Array = _timeline(entry)
		var marks := [1.0,1.2+1.0+0.8*0.92,1.2+1.0+0.8+0.25*0.18,1.2+1.0+0.8+0.25+0.6+0.5+0.10,1.0]
		var names := ["PARADO","PREPARAÇÃO (hold)","GOLPE (pico)","DANO","ARTICULAÇÕES"]
		for i in 5:
			var art := _make(entry,stage)
			_place(art,180+i*360,470,420)
			_run(art.boss_puppet,tl,0.0,marks[i])
			if i == 4:
				art.boss_puppet.debug_bones = true
				art.boss_puppet.debug_layer.visible = true
				art.boss_puppet.debug_layer.queue_redraw()
				_tint_weights(art.boss_puppet)
			_label(names[i],Vector2(i*360+12,8),stage)
		_label(entry.name,Vector2(12,474),stage,12)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("board_%s.png" % String(entry.name).split(" ")[0]))
		stage.queue_free()
		await get_tree().process_frame


func _sequence(out: String) -> void:
	# Grade 4×3 de 400×300; 30 fps (dois passos de 1/60 por quadro).
	get_window().size = Vector2i(1600,900)
	await get_tree().process_frame
	var stage := Node2D.new()
	add_child(stage)
	var arts: Array = []
	for i in entries.size():
		var art := _make(entries[i],stage)
		_place(art,200+(i%4)*400,288+floori(i/4.0)*300,250)
		arts.append(art)
		_label(String(entries[i].name),Vector2((i%4)*400+8,floori(i/4.0)*300+4),stage,12)
	var total: float = 0.0
	for seg in _timeline(entries[0]): total += seg[1]
	var frame: int = 0
	var t: float = 0.0
	while t < total-0.001:
		for i in arts.size(): _run(arts[i].boss_puppet,_timeline(entries[i]),t,t+STEP*2)
		t += STEP*2
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("f_%04d.png" % frame))
		frame += 1
	print("quadros: ",frame)


## Pinta cada vértice com a cor dos ossos que o puxam (mistura pelos pesos).
func _tint_weights(puppet: BossPuppet) -> void:
	var skin: Polygon2D = puppet.skin
	var colors := PackedColorArray()
	colors.resize(skin.polygon.size())
	colors.fill(Color.BLACK)
	for b in skin.get_bone_count():
		var hue: float = fmod(b*0.618034,1.0)
		var c := Color.from_hsv(hue,0.85,1.0)
		var w: PackedFloat32Array = skin.get_bone_weights(b)
		for v in colors.size(): colors[v] += c*w[v]
	for v in colors.size(): colors[v].a = 1.0
	skin.vertex_colors = colors
