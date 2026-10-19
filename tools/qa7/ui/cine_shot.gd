extends Node
## SONDA QA7 (não faz parte do jogo): toca o PRÓLOGO ou um EPÍLOGO (Cinematic)
## sozinho e fotografa a tela a cada `every` segundos, até a cinemática acabar.
## Uso: godot --audio-driver Dummy --fixed-fps 60 --path . --resolution 1280x720 --position 4000,4000 \
##   res://tools/qa7/ui/CineShot.tscn -- <prologue|ascensao|ruptura|semente> <prefixo> [every=2.7]
## (Com LangWrap: QA7_TARGET=res://tools/qa7/ui/CineShot.tscn.)

var mode: String = "prologue"
var prefix: String = "user://cine"
var every: float = 2.7


func _ready() -> void:
	SaveManager.persist_enabled = false
	Gnosis.persist_enabled = false
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		mode = a[0]
	if a.size() > 1:
		prefix = a[1]
	for i in range(2, a.size()):
		var kv := String(a[i]).split("=", true, 1)
		if kv.size() == 2 and kv[0] == "every":
			every = float(kv[1])
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var c: Cinematic
	if mode == "prologue":
		c = Cinematic.prologue()
	else:
		Narrative.apply_ending(["ascensao", "ruptura", "semente"].find(mode))
		c = Cinematic.epilogue(mode, 7, 18)
	var done := [false]
	c.finished.connect(func() -> void: done[0] = true)
	var n := 0
	var t := 0.0
	while not done[0] and t < 120.0:
		await get_tree().create_timer(every, true, false, true).timeout
		t += every
		if done[0]:
			break
		await RenderingServer.frame_post_draw
		var p := "%s_%02d.png" % [prefix, n]
		get_viewport().get_texture().get_image().save_png(p)
		print("CINE: ", p)
		n += 1
	print("CINE: fim (%d fotos, %.1fs)" % [n, t])
	get_tree().quit()
