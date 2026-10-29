extends Node
## FERRAMENTA (não faz parte do jogo): captura a TELA DE MAPA no estado de um run
## de verdade (rota, nó vencido, saídas). Monta a rota do Éon até a camada
## pedida (semente) e instancia o WorldMap num SubViewport 640×360 (a base do
## jogo) — a janela do Godot pode ser mínima e fora da tela (o João joga ao
## mesmo tempo); o PNG sai em 1280×720 (ampliado 2×, sem filtro).
## Uso: godot --audio-driver Dummy --path . --resolution 320x180 --position 4000,4000 \
##        res://tools/map6/MapShot.tscn -- <eon 0..6> <camada 1..8> <saida.png> [semente=3] [mover=N] [asas] [rota=a,b,..]
##   mover = aperta "baixo" N vezes antes da foto (mostra outra seleção).
##   asas  = a Sophia já tem o pulo duplo (o Soter já passou).
##   rota  = ids explícitos da rota (camadas 0..camada-1), no lugar da semente.

var eon: int = 0
var layer: int = 1
var out: String = "user://map.png"
var seed: int = 3
var moves: int = 0
var wings: bool = false
var route: Array = []


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var a := OS.get_cmdline_user_args()
	if a.size() >= 1: eon = clampi(int(a[0]), 0, 6)
	if a.size() >= 2: layer = clampi(int(a[1]), 1, 8)
	if a.size() >= 3: out = a[2]
	for i in range(3, a.size()):
		var s := String(a[i])
		if s.begins_with("semente="): seed = int(s.substr(8))
		elif s.begins_with("mover="): moves = int(s.substr(6))
		elif s == "asas": wings = true
		elif s.begins_with("rota="): route = Array(s.substr(5).split(","))
	_shoot()


func _shoot() -> void:
	SaveManager.persist_enabled = false
	Gnosis.persist_enabled = false
	GameManager.selected_character = GameContent.characters[0]
	Progression.reset_run()
	RunManager.begin()
	Narrative.once("prologue")
	if wings and Progression.has_method("grant_double_jump"):
		Progression.call("grant_double_jump")
	# Rota até a camada anterior (sem jogar).
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cur := EonMap.default_id(eon, 0)
	RunManager.path.assign([cur])
	for l in range(1, layer):
		if l < route.size():
			cur = String(route[l])
		else:
			var nx: Array = (EonMap.find(cur).next as Array).filter(func(id): return RunManager.node_available(String(id)))
			cur = String(nx[rng.randi() % nx.size()])
		RunManager.path.append(cur)
	# Estado de "acabou de vencer `cur`, escolhendo a camada `layer`".
	RunManager.current_screen = EonMap.screen_of(eon, layer)
	RunManager.current_node = ""
	RunManager.last_node = cur
	RunManager.last_reward = EonMap.find(cur).get("reward", {})
	RunManager.choosing = true
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 360)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var map: Control = (load("res://scenes/ui/WorldMap.tscn") as PackedScene).instantiate()
	map.size = Vector2(640, 360)
	vp.add_child(map)
	for i in 30:
		await get_tree().process_frame
	for i in moves:
		var ev := InputEventAction.new()
		ev.action = "ui_down"
		ev.pressed = true
		vp.push_input(ev)
		await get_tree().process_frame
		var up := InputEventAction.new()
		up.action = "ui_down"
		up.pressed = false
		vp.push_input(up)
		for k in 6:
			await get_tree().process_frame
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("MAPSHOT salvo: ", out)
	RunManager.end_run()
	get_tree().quit()
