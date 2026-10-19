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
## Fase 2 (zonas de chão e golpe corpo a corpo de inimigo). `gif <pasta> fase2`.
const ATTACKS2 := ["zonas", "garra"]
const GIF_FRAMES := 110           # 1,8 s por ataque
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
var _perf_noimpact: bool = false
var _draws: float = 0.0
var _gpu: float = 0.0
var _rcpu: float = 0.0
# fatias do quadro (µs): física, process e envio do desenho (pre→post draw)
var _ph0: int = 0
var _pr0: int = 0
var _rd0: int = 0
var _acc := {"fisica": 0.0, "process": 0.0, "desenho": 0.0}


## Nó que roda por ÚLTIMO na física e no process: fecha as fatias do quadro.
class PerfTail extends Node:
	var sc: Node
	func _physics_process(_d: float) -> void:
		sc._slice("fisica", sc._ph0)
	func _process(_d: float) -> void:
		sc._slice("process", sc._pr0)


func _slice(key: String, t0: int) -> void:
	if frame > PERF_WARM and t0 > 0:
		_acc[key] += float(Time.get_ticks_usec() - t0) / 1000.0


func _physics_process(_d: float) -> void:
	_ph0 = Time.get_ticks_usec()

const SOPHIA_POS := Vector2(170, 286)
const DUMMY_POS := Vector2(400, 286)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		mode = args[0]
	if args.size() >= 2:
		out = args[1]
	if mode == "gif":
		var which: String = args[2] if args.size() >= 3 else "all"
		queue = ATTACKS.duplicate() if which == "all" else (ATTACKS2.duplicate() if which == "fase2" else [which])
	elif mode == "perf" and args.size() >= 3:
		perf_n = int(args[2])
		_perf_noimpact = args.size() >= 4 and args[3] == "noimpact"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.size_2d_override = Vector2i(640, 360)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	if mode == "perf":
		process_priority = -1000
		process_physics_priority = -1000
		var tail := PerfTail.new()
		tail.sc = self
		tail.process_priority = 1000
		tail.process_physics_priority = 1000
		add_child(tail)
		RenderingServer.frame_pre_draw.connect(func() -> void: _rd0 = Time.get_ticks_usec())
		RenderingServer.frame_post_draw.connect(func() -> void: _slice("desenho", _rd0))
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
	sc.build(1 if attack in ["salva"] else (2 if attack == "galila" else (5 if attack == "zonas" else 0)), 3)
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
	if attack == "garra":
		dummy.position = SOPHIA_POS + Vector2(64, 0)    # corpo a corpo: colado nela


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
				_fire_still()
			if frame == 4 + 24:
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


## A função existe na VfxLibrary desta versão? (a mesma vitrine filma o ANTES)
func _has(fn: String) -> bool:
	for m in (VfxLibrary as Script).get_script_method_list():
		if String(m.name) == fn:
			return true
	return false


func _fire(a: String) -> void:
	match a:
		"zonas":
			# Névoa do Sono (da Sophia), Flor Podre (do Arconte) e coluna de luz
			HazardZone.spawn(world, Vector2(215, 300), "sleep", 60.0, 2.0, Color(0.72, 0.78, 1.0), "enemy", 0)
			HazardZone.spawn(world, Vector2(420, 300), "poison", 55.0, 2.0, Color(0.62, 1.0, 0.5))
			HazardZone.pillar(world, Vector2(318, 300), 26.0, 0.55, 0, Color(1.0, 0.55, 0.3))
			sophia_hb.monitorable = false
		"garra":
			# golpe corpo a corpo de criatura: rastro do golpe + acerto na Sophia
			if _has("melee_slash"):
				VfxLibrary.melee_slash(dummy, Vector2(-34, -4), Vector2(30, 54), -1, Color(1.0, 0.55, 0.3), "swing")
			var tw := create_tween()
			tw.tween_interval(0.07)
			tw.tween_callback(func() -> void: ImpactBurst.spawn(world, SOPHIA_POS + Vector2(10, -8), Color(1.0, 0.45, 0.35), false))
			tw.tween_interval(0.5)
			tw.tween_callback(func() -> void:
				if _has("melee_slash"):
					VfxLibrary.melee_slash(dummy, Vector2(-30, -4), Vector2(60, 54), -1, Color(1.0, 0.55, 0.3), "rush", true))
			tw.tween_interval(0.12)
			tw.tween_callback(func() -> void: ImpactBurst.spawn(world, SOPHIA_POS + Vector2(10, -12), Color(1.0, 0.45, 0.35), true))
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
			w.lifetime = 2.2
			w.look = "spike"                    # contrato: onda rasteira = forma "spike"
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


## Foto de catálogo: as 8 famílias voando em fileira (zoom 2,4 da câmera:
## cada px da base vira ~5 px na foto), para inspecionar núcleo/rastro/coroa.
const FAMILIES := [
	["light", "", Color(1.0, 0.95, 0.7)], ["solar", "", Color(1.0, 0.85, 0.5)],
	["chain_light", "", Color(0.85, 0.85, 0.95)], ["dark", "", Color(1.0, 0.55, 0.3)],
	["king", "", Color(1.0, 0.85, 0.5)], ["chain", "", Color(0.78, 0.78, 0.85)],
	["sleep", "", Color(0.75, 0.8, 1.0)], ["wave", "spike", Color(0.62, 1.0, 0.5)],
	["", "bolt", Color(0.9, 0.4, 1.0)], ["", "wisp", Color(0.4, 0.9, 1.0)],
	["", "seed", Color(0.7, 1.0, 0.4)], ["", "page", Color(1.0, 0.9, 0.75)]]


func _fire_still() -> void:
	sophia.visible = false
	dummy.visible = false
	sophia_hb.monitorable = false
	dummy_hb.monitorable = false
	for c in world.get_children():
		if c is Camera2D:
			c.zoom = Vector2(2.4, 2.4)
			c.position = Vector2(330, 214)
	var i := 0
	for f in FAMILIES:
		var p := _proj(1, 1, f[2], "player", 150.0)
		p.lifetime = 9.0
		p.look = f[1]
		if f[0] != "":
			p.set_meta("vfx_kind", f[0])
		var col_x := 268.0 if i < 8 else 330.0
		var row := i if i < 8 else i - 8
		_launch(p, Vector2(col_x, 156 + row * 16))
		i += 1


# ---------------------------------------------------------------------------
# Desempenho: mantém `perf_n` projéteis no ar (metade de cada lado), com alvos.
# ---------------------------------------------------------------------------

func _perf_step() -> void:
	var now := Time.get_ticks_usec()
	_pr0 = now
	if frame > PERF_WARM and _last_us > 0:
		_times.append(float(now - _last_us) / 1000.0)
		_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
		_rcpu += RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
	if frame == 2 and _perf_noimpact:
		sophia_hb.monitorable = false
		dummy_hb.monitorable = false
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
		var nf := float(_times.size())
		var line := "perf n=%d%s quadros=%d media_ms=%.3f p95_ms=%.3f fps_medio=%.1f fisica_ms=%.3f process_ms=%.3f desenho_ms=%.3f gpu_ms=%.3f render_cpu_ms=%.3f draw_calls=%.0f vfx_vivos=%d" % [perf_n, " sem_impacto" if _perf_noimpact else "", _times.size(), avg, p95, 1000.0 / avg, _acc.fisica / nf, _acc.process / nf, _acc.desenho / nf, _gpu / nf, _rcpu / nf, _draws / nf, get_tree().get_nodes_in_group(VfxLibrary.GROUP).size()]
		print("VFX7 ", line)
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_line(line)
			f.close()
		get_tree().quit()
