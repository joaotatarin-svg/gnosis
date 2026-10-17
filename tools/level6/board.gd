extends Node
## FERRAMENTA (não faz parte do jogo): PRANCHA DE LAYOUT de uma tela do run.
## Abre a tela, pula diálogos, tira o HUD e passa uma câmera de zoom 1,0 por
## toda a travessia (da parede esquerda à direita), costurando os quadros numa
## faixa só: o layout inteiro (plataformas, perigos, segredos) numa imagem.
## Uso: godot --audio-driver Dummy --path . --resolution 320x180 --position 4000,4000 \
##        res://tools/level6/Board.tscn -- <tela> <saida.png> [dj] [node=e1.3a] [y_centro]
##   dj = concede o pulo duplo (se o Progression já expuser grant_double_jump).
## A faixa sai com 2 px de imagem = 1 px de mundo, de y-180 a y+180 do centro.


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var w := BoardWorker.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.screen = int(args[0])
	if args.size() >= 2:
		w.out = args[1]
	for i in range(2, args.size()):
		if args[i] == "dj":
			w.dj = true
		elif args[i].begins_with("zoom="):
			w.zoom = float(args[i].substr(5))
		elif args[i].begins_with("node="):
			w.node_id = args[i].substr(5)
		elif args[i].is_valid_float():
			w.cy = float(args[i])
	get_tree().root.add_child.call_deferred(w)


class BoardWorker extends Node:
	var screen: int = 2
	var out: String = "user://board.png"
	var dj: bool = false
	var node_id: String = ""         # nó do mapa (ex.: e1.3a); "" = padrão da camada
	var cy: float = 160.0
	var zoom: float = 1.0            # zoom=2: metade do mundo por quadro (janela 320x180 → 1 px = 1 px de mundo)
	var _count: int = 0
	var _cam: Camera2D
	var _tiles: Array = []
	var _xs: Array = []
	var _tile_i: int = -1
	var _wait: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		if "map_route_seed" in RunManager:
			RunManager.set("map_route_seed", 0)
		if node_id != "" and "current_node" in RunManager:
			RunManager.set("current_node", node_id)
		if dj and Progression.has_method("grant_double_jump"):
			Progression.call("grant_double_jump")
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_delta: float) -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
				return
		var lv := get_tree().current_scene
		if not (lv is Level) or not lv._ready_done:
			return
		_count += 1
		if _count < 40:
			return
		if _cam == null:
			_setup(lv)
			return
		if _wait > 0:
			_wait -= 1
			return
		if _tile_i >= 0:
			_tiles.append(get_viewport().get_texture().get_image())
		_tile_i += 1
		if _tile_i >= _xs.size():
			_stitch()
			get_tree().quit()
			return
		_cam.global_position = Vector2(float(_xs[_tile_i]), cy)
		_wait = 4

	func _setup(lv: Level) -> void:
		# Sem HUD, sem inimigos andando, Sophia parada no começo.
		for n in get_tree().get_nodes_in_group("hud"):
			if n is CanvasItem:
				(n as CanvasItem).visible = false
			elif n is CanvasLayer:
				(n as CanvasLayer).visible = false
		for c in lv.get_children():
			if c is CanvasLayer and c.name.begins_with("HUD"):
				c.visible = false
		# Legendas/caixas dos autoloads (CanvasLayers fora da fase) também somem.
		for r in get_tree().root.get_children():
			if r == lv or r == self:
				continue
			for cl in r.find_children("*", "CanvasLayer", true, false):
				(cl as CanvasLayer).visible = false
			if r is CanvasLayer:
				(r as CanvasLayer).visible = false
		var ov := LayoutOverlay.new()
		ov.level = lv
		ov.z_index = 90
		ov.z_as_relative = false
		lv.add_child(ov)
		_cam = Camera2D.new()
		_cam.zoom = Vector2(zoom, zoom)
		_cam.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
		lv.add_child(_cam)
		_cam.make_current()
		var left: float = Level.WALL_LEFT - 60.0
		var right: float = float(lv.get("_end_x")) + 60.0
		var half_w := 320.0 / zoom
		var x := left + half_w
		while x - half_w < right:
			_xs.append(x)
			x += half_w * 2.0
		print("BOARD tela %d: %d quadros (x %.0f..%.0f)" % [screen, _xs.size(), left, right])

	func _stitch() -> void:
		if _tiles.is_empty():
			return
		var tw: int = (_tiles[0] as Image).get_width()
		var th: int = (_tiles[0] as Image).get_height()
		var big := Image.create(tw * _tiles.size(), th, false, (_tiles[0] as Image).get_format())
		for i in _tiles.size():
			var im: Image = _tiles[i]
			big.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i(i * tw, 0))
		big.save_png(out)
		print("BOARD salvo: ", out, " ", big.get_width(), "x", big.get_height())


## Esquema por cima da pintura: plataformas (ciano), perigos (vermelho),
## segredos/objetos (dourado), gatilhos e paredes das zonas (branco).
class LayoutOverlay extends Node2D:
	var level: Level

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if level == null:
			return
		var font := ThemeDB.fallback_font
		for i in level.zones.size():
			var c: float = level.zone_center(i)
			draw_line(Vector2(c - Level.ZONE_HALF, -200), Vector2(c - Level.ZONE_HALF, 320), Color(1, 1, 1, 0.5), 2.0)
			draw_line(Vector2(c + Level.ZONE_HALF, -200), Vector2(c + Level.ZONE_HALF, 320), Color(1, 1, 1, 0.5), 2.0)
			draw_line(Vector2(c - Level.ZONE_TRIGGER, 250), Vector2(c - Level.ZONE_TRIGGER, 320), Color(1, 1, 0.3, 0.8), 2.0)
			var obj: String = ""
			if level.has_method("zone_objective"):
				obj = String(level.call("zone_objective", i))
			draw_string(font, Vector2(c - 60, -10), "ZONA %d %s" % [i + 1, obj], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))
		for n in level.get_children():
			if n is StaticBody2D:
				for ch in n.get_children():
					if ch is CollisionShape2D and ch.one_way_collision and ch.shape is RectangleShape2D:
						var sz: Vector2 = (ch.shape as RectangleShape2D).size
						var p: Vector2 = (n as Node2D).global_position + (ch as Node2D).position
						draw_rect(Rect2(p - sz * 0.5, sz), Color(0.3, 1, 1, 0.9), false, 2.0)
						draw_string(font, p + Vector2(-20, -10), "y%.0f" % p.y, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 1, 1))
			var tag: String = ""
			var col := Color(1, 0.85, 0.3)
			if n.is_in_group("lv6_hazard"):
				tag = String(n.get("hazard_kind")) if "hazard_kind" in n else "perigo"
				col = Color(1, 0.3, 0.3)
			elif n is Chest:
				tag = "BAU"
			elif n is SealPuzzle:
				tag = "SELOS"
			elif n is Sleeper:
				tag = "ADORMECIDO"
			elif n is Stela:
				tag = "ESTELA"
			elif n.is_in_group("lv6_objective"):
				tag = String(n.get("hazard_kind")) if "hazard_kind" in n else "objetivo"
				col = Color(0.6, 1, 0.5)
			if tag != "" and n is Node2D:
				var q: Vector2 = (n as Node2D).global_position
				draw_circle(q, 5, col)
				draw_string(font, q + Vector2(-24, -48), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
