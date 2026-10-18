extends Node
## FERRAMENTA (não faz parte do jogo): captura a TELA DE MAPA dentro de um run
## de verdade. Monta a rota do Éon até a camada pedida (semente da rota
## automática), vence o nó e salva o PNG da tela de mapa que abre.
## Uso: godot --audio-driver Dummy --path . --resolution 1280x720 --position 1200,600 \
##        res://tools/map6/MapShot.tscn -- <eon 0..6> <camada 1..8> <saida.png> [semente=3] [mover=N]
##   mover = aperta "baixo" N vezes antes da foto (mostra outra seleção).

var eon: int = 0
var layer: int = 1
var out: String = "user://map.png"
var seed: int = 3
var moves: int = 0


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var a := OS.get_cmdline_user_args()
	if a.size() >= 1: eon = clampi(int(a[0]), 0, 6)
	if a.size() >= 2: layer = clampi(int(a[1]), 1, 8)
	if a.size() >= 3: out = a[2]
	for i in range(3, a.size()):
		if String(a[i]).begins_with("semente="): seed = int(String(a[i]).substr(8))
		if String(a[i]).begins_with("mover="): moves = int(String(a[i]).substr(6))
	var w := Worker.new()
	w.eon = eon
	w.layer = layer
	w.out = out
	w.seed = seed
	w.moves = moves
	get_tree().root.add_child.call_deferred(w)


class Worker extends Node:
	var eon: int
	var layer: int
	var out: String
	var seed: int
	var moves: int

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		# Rota até a camada anterior (sem jogar), com a semente pedida.
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var cur := EonMap.default_id(eon, 0)
		RunManager.path.assign([cur])
		for l in range(1, layer):
			var nx: Array = (EonMap.find(cur).next as Array).filter(func(id): return RunManager.node_available(String(id)))
			cur = String(nx[rng.randi() % nx.size()])
			RunManager.path.append(cur)
		RunManager.current_screen = EonMap.screen_of(eon, layer - 1)
		RunManager.current_node = cur
		RunManager.map_route_seed = -1
		RunManager.advance_and_reload()
		for i in 90:
			await get_tree().process_frame
		for i in moves:
			var ev := InputEventAction.new()
			ev.action = "ui_down"
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().process_frame
			var up := InputEventAction.new()
			up.action = "ui_down"
			up.pressed = false
			Input.parse_input_event(up)
			for k in 6:
				await get_tree().process_frame
		for i in 20:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out)
		print("MAPSHOT salvo: ", out, " cena=", get_tree().current_scene.scene_file_path if get_tree().current_scene else "-")
		get_tree().quit()
