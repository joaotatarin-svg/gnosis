extends Node2D
## VITRINE DOS ATAQUES (VFX7 — ferramenta da IA). Monta um Éon dentro de um
## SubViewport 1280×720 (2D em 640×360, como o jogo), coloca uma Sophia e uma
## criatura de treino e dispara os ataques à distância REAIS (Projectile,
## AoeNova, VfxLibrary) — os mesmos parâmetros que player.gd/enemy.gd usam.
##
## Uso (sempre com --fixed-fps 60: cada quadro = 1/60 s de jogo):
##   godot --audio-driver Dummy --fixed-fps 60 --resolution 320x180 --position 4000,4000 \
##     res://tools/VfxShowcase7.tscn -- gif <pasta> <ataque|all>
##       → <pasta>/<ataque>/f_000.png… (1280×720). Ataques: ver ATTACKS.
##   ... -- still <arquivo.png>          → todas as famílias no ar numa foto
##   ... -- perf <arquivo.txt> [n=20]    → mede ms/quadro com n projéteis no ar
## A janela fica minúscula e fora da tela; a imagem sai do SubViewport.

const ATTACKS := ["solar", "corrente", "coroa", "rei", "salva", "galila"]
const GIF_FRAMES := 84            # 1,4 s por ataque
const FIRE_AT := 22               # quadro do disparo (antes disso: antecipação)
const PERF_WARM := 90
const PERF_FRAMES := 360

var mode: String = "gif"
var out: String = "user://vfx7"
var queue: Array = []
var attack: String = ""
var frame: int = 0
var perf_n: int = 20

var vp: SubViewport
var world: Node2D
var sophia: Node2D
var dummy: Node2D
var sophia_hb: Hurtbox
var dummy_hb: Hurtbox
var _times: Array[float] = []
var _last_us: int = 0
var _perf_flip: int = 0

const SOPHIA_POS := Vector2(170, 286)
const DUMMY_POS := Vector2(470, 286)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		mode = args[0]
	if args.size() >= 2:
		out = args[1]
	if mode == "gif":
		var which: String = args[2] if args.size() >= 3 else "all"
		queue = ATTACKS.duplicate() if which == "all" else [which]
	elif mode == "perf" and args.size() >= 3:
		perf_n = int(args[2])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.size_2d_override = Vector2i(640, 360)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_build_world()
	if mode == "gif":
		_next_attack()


func _build_world() -> void:
	if world != null:
		world.queue_free()
	world = Node2D.new()
	vp.add_child(world)
	var sc := Scenery.new()
	world.add_child(sc)
	sc.build(1 if attack in ["salva"] else (2 if attack == "galila" else 0), 3)
	var ground := Node2D.new()
	world.add_child(ground)
	sc.build_ground(ground, 316.0)
	var cam := Camera2D.new()
	cam.position = Vector2(320, 206)
	cam.zoom = Vector2(1.2, 1.2)        # o zoom do jogo (camera_shake.gd ZOOM)
	world.add_child(cam)
	cam.make_current()
	# Sophia (só o visual) e uma criatura de treino, cada uma com Hurtbox real
	sophia = Node2D.new()
	world.add_child(sophia)
	sophia.position = SOPHIA_POS
	var sart := CharacterArt.new()
	sophia.add_child(sart)
	sart.set_profile(Bestiary.player_profile(GameContent.get_character("sophia"), 1, []))
	sophia_hb = _hurtbox(sophia, "player")
	dummy = Node2D.new()
	world.add_child(dummy)
	dummy.position = DUMMY_POS
	var dart := CharacterArt.new()
	dummy.add_child(dart)
	var prof = Bestiary.get_type("cego").get("profile", null)
	if prof == null:
		prof = Bestiary.wave_types[0].get("profile", null)
	if prof != null:
		dart.set_profile(prof)
	dart.scale.x = -1.0
	dummy_hb = _hurtbox(dummy, "enemy")


func _hurtbox(host: Node2D, team: String) -> Hurtbox:
	var hb := Hurtbox.new()
	hb.team = team
	hb.collision_layer = 8
	hb.collision_mask = 8
	hb.monitorable = true
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(26, 54)
	cs.shape = r
	hb.add_child(cs)
	hb.position = Vector2(0, -4)
	host.add_child(hb)
	return hb


func _next_attack() -> void:
	if queue.is_empty():
		get_tree().quit()
		return
	attack = queue.pop_front()
	frame = 0
	DirAccess.make_dir_recursive_absolute(out.path_join(attack))
	_build_world()


func _process(_delta: float) -> void:
	frame += 1
	match mode:
		"gif":
			if frame == 2:
				_anticipate(attack)
			if frame == FIRE_AT:
				_fire(attack)
			if frame >= 2:
				var img := vp.get_texture().get_image()
				img.save_png(out.path_join(attack).path_join("f_%03d.png" % (frame - 2)))
			if frame >= GIF_FRAMES + 2:
				print("VFX7 GIF ", attack, " ok")
				_next_attack()
		"still":
			if frame == 4:
				for a in ATTACKS:
					_fire_still(a)
			if frame == 4 + 14:
				vp.get_texture().get_image().save_png(out)
				print("VFX7 STILL ", out)
				get_tree().quit()
		"perf":
			_perf_step()


# ---------------------------------------------------------------------------
# Os ataques (parâmetros copiados de player.gd/_cast_skill e enemy.gd/_begin_strike)
# ---------------------------------------------------------------------------

func _hand(dir: int) -> Vector2:
	return SOPHIA_POS + Vector2(18.0 * dir, -6.0)


## Antecipação (VFX7: VfxLibrary.charge_up). No jogo ela só aparece quando os
## donos dos ataques chamarem a API no wind-up (pedidos em docs/pedidos/vfx7.md).
func _anticipate(a: String) -> void:
	var dur := float(FIRE_AT - 2) / 60.0
	match a:
		"solar":
			VfxLibrary.charge_up(sophia, Vector2(18, -6), Color(1.0, 0.85, 0.5), dur, "light")
		"corrente":
			VfxLibrary.charge_up(sophia, Vector2(18, -6), Color(0.85, 0.85, 0.95), dur, "light")
		"coroa":
			VfxLibrary.charge_up(sophia, Vector2(14, -18), Color(1.0, 0.9, 0.5), dur, "light")
		"rei":
			VfxLibrary.charge_up(dummy, Vector2(-16, -14), Color(1.0, 0.85, 0.5), dur, "king")
		"salva":
			VfxLibrary.charge_up(dummy, Vector2(-16, -10), Color(1.0, 0.55, 0.3), dur, "dark")
		"galila":
			VfxLibrary.charge_up(dummy, Vector2(-20, -20), Color(0.78, 0.78, 0.85), dur, "dark")


func _fire(a: String) -> void:
	match a:
		"solar":
			VfxLibrary.cast(world, SOPHIA_POS + Vector2(14, -18), Color(1.0, 0.85, 0.5))
			var p := _proj(1, 26, Color(1.0, 0.85, 0.5), "enemy", 340.0)
			p.explode_radius = 70.0
			_launch(p, _hand(1))
		"corrente":
			VfxLibrary.cast(world, SOPHIA_POS + Vector2(14, -18), Color(0.85, 0.85, 0.95))
			var c := _proj(1, 18, Color(0.85, 0.85, 0.95), "enemy", 430.0)
			c.root_time = 1.8
			_launch(c, _hand(1))
		"coroa":
			VfxLibrary.cast(world, SOPHIA_POS + Vector2(14, -18), Color(1.0, 0.9, 0.5))
			AoeNova.spawn(world, SOPHIA_POS + Vector2(60, 0), 48, 210.0, Color(1.0, 0.9, 0.5))
		"rei":
			var k := _proj(-1, 20, Color(1.0, 0.85, 0.5), "player", 200.0)
			k.lifetime = 2.4
			_launch(k, DUMMY_POS + Vector2(-16, -14))
		"salva":
			for oy in [-16.0, 0.0, 16.0]:
				var s := _proj(-1, 12, Color(1.0, 0.55, 0.3), "player", 300.0)
				s.lifetime = 1.6
				_launch(s, DUMMY_POS + Vector2(-16, -10 + oy))
		"galila":
			var g := _proj(-1, 10, Color(0.78, 0.78, 0.85), "player", 260.0)
			g.root_time = 1.1
			g.lifetime = 1.4
			_launch(g, DUMMY_POS + Vector2(-20, -20))
			var w := _proj(-1, 10, Color(0.8, 0.85, 1.0), "player", 220.0)
			w.lifetime = 1.8
			_launch(w, DUMMY_POS + Vector2(-30, 12))


func _proj(dir: int, dmg: int, col: Color, team: String, spd: float) -> Projectile:
	var p := Projectile.new()
	p.direction = dir
	p.damage = dmg
	p.color = col
	p.pierce = false
	p.target_team = team
	p.speed = spd
	return p


func _launch(p: Projectile, at: Vector2) -> void:
	world.add_child(p)
	p.global_position = at


## Foto com todas as famílias no ar (sem alvos no caminho).
func _fire_still(a: String) -> void:
	sophia_hb.monitorable = false
	dummy_hb.monitorable = false
	var y := 90.0 + float(ATTACKS.find(a)) * 34.0
	var cols := {"solar": Color(1.0, 0.85, 0.5), "corrente": Color(0.85, 0.85, 0.95), "coroa": Color(1.0, 0.9, 0.5),
		"rei": Color(1.0, 0.85, 0.5), "salva": Color(1.0, 0.55, 0.3), "galila": Color(0.78, 0.78, 0.85)}
	var team := "enemy" if a in ["solar", "corrente", "coroa"] else "player"
	var p := _proj(1 if team == "enemy" else -1, 10, cols[a], team, 0.0)
	p.lifetime = 9.0
	if a == "corrente" or a == "galila":
		p.root_time = 1.0
	if a == "coroa":
		p.explode_radius = 0.0
	if a == "rei":
		p.lifetime = 9.4
	_launch(p, Vector2(320, y))


# ---------------------------------------------------------------------------
# Desempenho: mantém `perf_n` projéteis no ar (metade de cada lado), com alvos.
# ---------------------------------------------------------------------------

func _perf_step() -> void:
	var now := Time.get_ticks_usec()
	if frame > PERF_WARM and _last_us > 0:
		_times.append(float(now - _last_us) / 1000.0)
	_last_us = now
	var live := 0
	for n in world.get_children():
		if n is Projectile and n.is_physics_processing():
			live += 1
	var cols := [Color(1.0, 0.85, 0.5), Color(1.0, 0.55, 0.3), Color(0.78, 0.78, 0.85), Color(0.62, 1.0, 0.5), Color(0.7, 0.8, 1.0)]
	while live < perf_n:
		_perf_flip += 1
		var mine := _perf_flip % 2 == 0
		var col: Color = cols[_perf_flip % cols.size()]
		var p := _proj(1 if mine else -1, 1, col, "enemy" if mine else "player", 160.0 + float(_perf_flip % 5) * 30.0)
		p.lifetime = 3.0
		if _perf_flip % 7 == 0:
			p.explode_radius = 60.0 if mine else 0.0
		var y := 230.0 + float(_perf_flip % 9) * 8.0
		_launch(p, Vector2(200.0 if mine else 440.0, y))
		live += 1
	if _times.size() >= PERF_FRAMES:
		_times.sort()
		var sum := 0.0
		for t in _times:
			sum += t
		var avg := sum / float(_times.size())
		var p95: float = _times[int(_times.size() * 0.95)]
		var line := "perf n=%d quadros=%d media_ms=%.3f p95_ms=%.3f fps_medio=%.1f vfx_vivos=%d" % [perf_n, _times.size(), avg, p95, 1000.0 / avg, get_tree().get_nodes_in_group(VfxLibrary.GROUP).size()]
		print("VFX7 ", line)
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_line(line)
			f.close()
		get_tree().quit()
