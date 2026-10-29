extends Node
## FERRAMENTA (arte, NEURO R18): mede se a Sophia "salta" do fundo de uma tela.
## Abre a tela, espera, e salva 3 PNGs do MESMO instante (árvore pausada):
##   <saida>_on.png   com a luz de contorno (rim + halo) da Sophia
##   <saida>_off.png  sem (como era antes)
##   <saida>_bg.png   sem a Sophia (fundo puro → máscara por diferença)
## O contraste (WCAG, luminância relativa) é calculado por tools/anim/contrast_r18.py.
## Uso: godot --path . --audio-driver Dummy --resolution 640x360 --position 4000,4000 \
##        res://tools/ContrastProbe.tscn -- <tela> <saida_sem_extensao> [quadro=150]


func _ready() -> void:
	var w := Worker.new()
	var args := OS.get_cmdline_user_args()
	w.screen = int(args[0]) if args.size() >= 1 else 3
	w.out = String(args[1]) if args.size() >= 2 else "user://contrast"
	w.at = int(args[2]) if args.size() >= 3 else 150
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var screen: int = 3
	var out: String = ""
	var at: int = 150
	var _n: int = 0
	var _step: int = 0
	var _vis: CharacterArt

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		AudioServer.set_bus_mute(0, true)
		SaveManager.persist_enabled = false
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_d: float) -> void:
		# pula diálogos (ex.: tela 68 abre com fala) — o quadro só conta sem caixa na tela
		var had_dialog := false
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
				had_dialog = true
		if had_dialog and _step == 0:
			return
		_n += 1
		if _n < at:
			return
		if _step == 0:
			var p := get_tree().get_first_node_in_group("player")
			if p == null:
				return
			_vis = p.get("visual") as CharacterArt
			get_tree().paused = true
			# sem inimigos na foto (só Sophia × fundo)
			for e in get_tree().get_nodes_in_group("enemy"):
				(e as CanvasItem).visible = false
			_vis.rim_enabled = true
			_vis.queue_redraw()
		elif _step == 3:
			_save("_on")
			_vis.rim_enabled = false
			_vis.queue_redraw()
		elif _step == 6:
			_save("_off")
			_vis.visible = false
		elif _step == 9:
			_save("_bg")
			print("CONTRASTE salvo: ", out)
			get_tree().quit()
		_step += 1

	func _save(suffix: String) -> void:
		get_viewport().get_texture().get_image().save_png(out + suffix + ".png")
