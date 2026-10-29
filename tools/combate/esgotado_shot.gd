extends Node
## FERRAMENTA (Polimento 7, não vai no jogo): prova visual do invocador ESGOTADO
## (teto de 3 invocações). Abre uma tela real do run, põe um invocador ao lado da
## Sophia (o resto da wave some), salva ANTES; força a 3ª invocação (as larvas
## dela somem para não poluir a foto) e salva o sopro (DEPOIS_sopro) e o estado
## parado (DEPOIS). Também salva recortes 3× em volta dele.
## Uso: godot --audio-driver Dummy --path . --resolution 640x360 --position 4000,4000 \
##        res://tools/combate/EsgotadoShot.tscn -- <tela> <pasta>

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	# o trabalho mora num nó do ROOT (sobrevive à troca de cena, roda com pausa)
	var w := _Worker.new()
	w.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(w)
	w.ready.connect(w._start, CONNECT_ONE_SHOT)


class _Worker extends Node:
	var screen: int = 38
	var out_dir: String = "C:/gnosis-wt/_caps/polimento7/esgotado"
	var _count: int = 0
	var _inv: Node2D = null
	var _stage: int = 0
	var _t: int = 0


	func _start() -> void:
		var args := OS.get_cmdline_user_args()
		if args.size() >= 1:
			screen = int(args[0])
		if args.size() >= 2:
			out_dir = args[1]
		DirAccess.make_dir_recursive_absolute(out_dir)
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
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
				return
		_count += 1
		var lv := get_tree().current_scene
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		if lv == null or pl == null or _count < 30:
			return
		# só o NOSSO invocador: o resto da wave fica parado e invisível
		for e in get_tree().get_nodes_in_group("enemy"):
			if e != _inv and e is Node2D and not (e.type_id == "larva" and _stage == 0):
				e.process_mode = Node.PROCESS_MODE_DISABLED
				e.visible = false
		match _stage:
			0:
				var scn = load("res://scenes/entities/Enemy.tscn")
				_inv = scn.instantiate()
				_inv.type_id = "invocador"
				lv.add_child(_inv)
				_inv.global_position = pl.global_position + Vector2(110, -20)
				_stage = 1
				_t = 0
			1:
				_t += 1
				_inv.cooldown_timer = 99.0          # não ataca durante a foto
				_inv._summon_calls = 0
				if _t == 50:
					_save("antes")
					_inv._summon_calls = Enemy.SUMMON_MAX_CALLS - 1
					_inv._summon_larvae()
					_stage = 2
					_t = 0
			2:
				_t += 1
				_inv.cooldown_timer = 99.0
				if _t == 3:
					_save("depois_sopro")
				if _t == 60:
					_save("depois")
					get_tree().quit()


	func _save(tag: String) -> void:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_tela%d.png" % [out_dir, tag, screen])
		# recorte 3× em volta do invocador (coordenadas de tela = canvas × janela/base)
		var xf: Transform2D = _inv.get_viewport().get_canvas_transform()
		var k: float = float(img.get_width()) / 640.0
		var p: Vector2 = (xf * _inv.global_position) * k
		var half := Vector2(70, 70) * k
		var r := Rect2i(Vector2i(p - half - Vector2(0, 30) * k), Vector2i(half * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 4 and r.size.y > 4:
			var crop := img.get_region(r)
			crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
			crop.save_png("%s/%s_tela%d_zoom.png" % [out_dir, tag, screen])
		print("ESGOTADO salvo: ", tag, " invocador em ", _inv.global_position, " esgotado=", _inv._summon_exhausted)
