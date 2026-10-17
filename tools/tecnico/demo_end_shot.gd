extends Node
## FERRAMENTA (não faz parte do jogo): captura a tela de fim da DEMO no
## fallback (ninguém ligado em `GameManager.demo_finished`).
## Uso: xvfb-run godot --audio-driver Dummy --path . res://tools/tecnico/DemoEndShot.tscn -- <saida.png>

func _ready() -> void:
	# A cena some na troca para a EndScreen: o trabalho roda numa cópia filha do ROOT.
	if name != "DemoEndWorker":
		var w: Node = (get_script() as Script).new()
		w.name = "DemoEndWorker"
		get_tree().root.add_child.call_deferred(w)
		return
	SaveManager.persist_enabled = false
	Gnosis.persist_enabled = false
	var out := "user://demo_end.png"
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		out = args[0]
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameManager.demo = true
	GameManager.finish_demo()
	for i in 120:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("DemoEndShot: ", out)
	get_tree().quit()
