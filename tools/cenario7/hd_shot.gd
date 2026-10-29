extends Node
## FERRAMENTA (cenário 7, não faz parte do jogo): o mesmo Shot/CleanShot, mas
## a cena do jogo é renderizada num SubViewport 1280×720 (2D em 640×360, como o
## jogo) — a janela do Godot fica MÍNIMA (320×180, fora da vista) e a imagem
## sai em resolução cheia. Serve para julgar os fundos em alta resolução.
## Uso: godot --audio-driver Dummy --fixed-fps 60 --path . --resolution 320x180 --position 4000,4000 \
##        res://tools/cenario7/HdShot.tscn -- <tela> <saida.png> [frames] [opções do Shot] [nohud] [x=<x>] [face=<-1|1>] [oldbg]
##   oldbg   = desliga os fundos novos (HD) e usa as camadas antigas — para o ANTES.
##   perf    = mede o custo: a partir do 120º quadro com a fase pronta, 600 quadros de
##             tempo de GPU do SubViewport 1280×720, tempo de processo e memória de
##             textura/vídeo (Performance), e imprime "HDPERF ...". Use sem --fixed-fps.
##   blink   = a Sophia pisca (some 1 quadro sim, 1 não): com seq=2 every=1 sai um
##             par com/sem ela → máscara exata da Sophia (contraste R18, contrast.py).
## Todas as opções do tools/shot.gd valem (seq=N every=K act=walk solo hold...).

const W := 1280
const H := 720

var _vp: SubViewport


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)   # ferramenta nunca toca som
	var args := OS.get_cmdline_user_args()
	Scenery.hd_disabled = args.has("oldbg")
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.size_2d_override = Vector2i(640, 360)
	_vp.size_2d_override_stretch = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.audio_listener_enable_2d = false
	get_tree().root.add_child.call_deferred(_vp)
	var shot = load("res://tools/shot.gd")
	var w = shot.ShotWorker.new()
	if args.size() >= 1:
		w.screen = int(args[0])
	if args.size() >= 2:
		w.out = args[1]
	if args.size() >= 3:
		w.frames = int(args[2])
	for i in range(3, args.size()):
		var kv: PackedStringArray = (args[i] as String).split("=", true, 1)
		var key: String = kv[0]
		var val: String = kv[1] if kv.size() > 1 else ""
		match key:
			"seq": w.seq_count = maxi(0, int(val))
			"every": w.seq_every = maxi(1, int(val))
			"act": w.act = val
			"solo": w.solo = true
			"freeze": w.freeze = true
			"hold": w.hold = true
			"hurt": w.hurt = true
			"wave": w.wave = true
	# O worker vive DENTRO do SubViewport: o get_viewport() dele (de onde sai o
	# PNG) é o de 1280×720.
	_vp.add_child.call_deferred(w)
	var mv := Mover.new()
	mv.vp = _vp
	mv.nohud = args.has("nohud")
	mv.blink = args.has("blink")
	mv.perf = args.has("perf")
	for a in args:
		if a.begins_with("x="):
			mv.pin_x = float(a.substr(2))
		elif a.begins_with("face="):
			mv.face = int(a.substr(5))
	mv.process_mode = Node.PROCESS_MODE_ALWAYS
	mv.process_priority = -100
	get_tree().root.add_child.call_deferred(mv)


class Mover extends Node:
	## A cada quadro: se a cena atual do jogo ainda está na raiz, muda ela para
	## dentro do SubViewport (câmera, parallax e shaders de tela passam a usar o
	## viewport de 1280×720).
	## (Fora da raiz o SceneTree zera o current_scene; por isso quem prende a
	## Sophia em x= e esconde legendas/HUD é este nó, com a referência guardada.)
	var vp: SubViewport
	var nohud: bool = false
	var pin_x: float = INF
	var face: int = 0
	var blink: bool = false
	var perf: bool = false
	var level: Node = null
	var _pf: int = 0
	var _gpu: Array = []
	var _cpu: Array = []

	func _process(_delta: float) -> void:
		var cs := get_tree().current_scene
		if cs != null and vp != null and cs.get_parent() == get_tree().root:
			cs.get_parent().remove_child(cs)
			vp.add_child(cs)
			level = cs
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if c is CaptionBar or (nohud and c.is_in_group("hud")):
				c.visible = false
		if level == null or not is_instance_valid(level) or not ("player" in level):
			return
		var pl = level.get("player")
		if pl == null:
			return
		if pin_x != INF:
			(pl as Node2D).global_position.x = pin_x
		if face != 0 and "facing" in pl:
			pl.set("facing", face)
		if blink:
			(pl as CanvasItem).visible = Engine.get_process_frames() % 2 == 0
		if perf:
			_measure()

	func _measure() -> void:
		_pf += 1
		var rid := vp.get_viewport_rid()
		if _pf == 1:
			RenderingServer.viewport_set_measure_render_time(rid, true)
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = 0
		if _pf < 120:
			return
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		_cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		if _gpu.size() >= 600:
			_gpu.sort()
			_cpu.sort()
			var g := 0.0
			for v in _gpu:
				g += float(v)
			var c := 0.0
			for v in _cpu:
				c += float(v)
			print("HDPERF gpu_ms med=%.3f p95=%.3f | process_ms med=%.3f | tex_MB=%.1f vid_MB=%.1f | fps=%.0f" % [
				g / _gpu.size(), float(_gpu[int(_gpu.size() * 0.95)]), c / _cpu.size(),
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				Engine.get_frames_per_second()])
			get_tree().quit()
