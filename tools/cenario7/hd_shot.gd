extends Node
## FERRAMENTA (cenário 7, não faz parte do jogo): o mesmo Shot/CleanShot, mas
## a cena do jogo é renderizada num SubViewport 1280×720 (2D em 640×360, como o
## jogo) — a janela do Godot fica MÍNIMA (320×180, fora da vista) e a imagem
## sai em resolução cheia. Serve para julgar os fundos em alta resolução.
## Uso: godot --audio-driver Dummy --fixed-fps 60 --path . --resolution 320x180 --position 4000,4000 \
##        res://tools/cenario7/HdShot.tscn -- <tela> <saida.png> [frames] [opções do Shot] [nohud] [x=<x>] [face=<-1|1>] [oldbg]
##   oldbg   = desliga os fundos novos (HD) e usa as camadas antigas — para o ANTES.
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
	var cl = load("res://tools/scenery/clean_shot.gd").Cleaner.new()
	cl.nohud = args.has("nohud")
	for a in args:
		if a.begins_with("x="):
			cl.x = float(a.substr(2))
		elif a.begins_with("face="):
			cl.face = int(a.substr(5))
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	cl.process_priority = 100
	_vp.add_child.call_deferred(cl)
	var mv := Mover.new()
	mv.vp = _vp
	mv.process_mode = Node.PROCESS_MODE_ALWAYS
	mv.process_priority = -100
	get_tree().root.add_child.call_deferred(mv)


class Mover extends Node:
	## A cada quadro: se a cena atual do jogo ainda está na raiz, muda ela para
	## dentro do SubViewport (câmera, parallax e shaders de tela passam a usar o
	## viewport de 1280×720).
	var vp: SubViewport

	func _process(_delta: float) -> void:
		var cs := get_tree().current_scene
		if cs == null or vp == null or cs.get_parent() == vp:
			return
		if cs.get_parent() != get_tree().root:
			return
		cs.get_parent().remove_child(cs)
		vp.add_child(cs)
		get_tree().current_scene = cs
