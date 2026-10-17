extends Node
## FERRAMENTA (não faz parte do jogo): filma uma CENA ENCENADA em quadros.
## Abre uma tela do run, AVANÇA as falas sozinha (cada fala fica `hold`
## quadros, como um jogador lendo) e salva PNGs no fim de cada fala (e no meio,
## quando a fala tem `cue`), além de quadros soltos enquanto a cena roda sem
## caixa (a descida do Centro). Sem inimigo na tela por `kill` quadros, mata
## todos os vivos DE UMA VEZ (o chefe/as duas formas caem juntas).
## Uso (rodar com --fixed-fps 60 e --audio-driver Dummy):
##   godot --path . --resolution 1280x720 res://tools/encenacao/CenaShot.tscn -- \
##     <tela> <prefixo_saida> [hold=150] [kill=90] [free=6] [max=4000]
## Tela 64: 6 Anéis no bolso (o 7º vem do Arconte). 65: Anéis roubados.
## 68: roubados + 6 cacos devolvidos (o 7º volta na 1ª queda).

var screen: int = 1
var prefix: String = "/tmp/cena"
var hold: int = 150
var kill_after: int = 90
var free_max: int = 6
var max_frames: int = 4000


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		screen = int(args[0])
	if args.size() >= 2:
		prefix = args[1]
	for i in range(2, args.size()):
		var kv: PackedStringArray = String(args[i]).split("=", true, 1)
		var v := int(kv[1]) if kv.size() > 1 else 0
		match kv[0]:
			"hold": hold = v
			"kill": kill_after = v
			"free": free_max = v
			"max": max_frames = v
	var w := _Worker.new()
	w.screen = screen
	w.prefix = prefix
	w.hold = hold
	w.kill_after = kill_after
	w.free_max = free_max
	w.max_frames = max_frames
	get_tree().root.add_child.call_deferred(w)


class _Worker extends Node:
	var screen: int = 1
	var prefix: String = ""
	var hold: int = 150
	var kill_after: int = 90
	var free_max: int = 6
	var max_frames: int = 4000
	var _f: int = 0
	var _box_id: int = 0
	var _line_f: int = 0
	var _line: int = -1
	var _cue: String = ""
	var _hold: int = 150
	var _boxes: int = 0
	var _shots: int = 0
	var _free_f: int = 0
	var _free_shots: int = 0
	var _quiet: int = 0
	var _killed: bool = false
	var _start_screen: int = 0

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
		var order: Array = []
		for sk in GameContent.characters[0].skills:
			if sk.ring != "":
				order.append(sk)
		var n := 6 if screen == RunManager.LAST_ARCHON_SCREEN else (7 if screen > RunManager.LAST_ARCHON_SCREEN else 0)
		for k in mini(n, order.size()):
			Progression.add_ring(order[k].ring, order[k].id)
		if screen > RunManager.LAST_ARCHON_SCREEN:
			Progression.steal_rings()
		if RunManager.is_final(screen):
			for k in 6:
				Progression.restore_ring(order[k].ring)
		_start_screen = screen
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_d: float) -> void:
		_f += 1
		if _f > max_frames or RunManager.current_screen != _start_screen:
			if _f > 30:
				print("CENA: fim (quadros=%d, fotos=%d)" % [_f, _shots])
				get_tree().quit()
			return
		var box: DialogueBox = null
		for c in get_tree().root.get_children():
			if c is DialogueBox and not c.is_queued_for_deletion():
				box = c
		if box != null:
			_quiet = 0
			_drive(box)
			return
		_line = -1
		_box_id = 0
		# Cena sem caixa (descida do Centro, mundo pausado pela cena): quadros soltos.
		var cs := get_tree().current_scene
		if cs is Level and get_tree().paused and _free_shots < free_max:
			_free_f += 1
			if _free_f % 30 == 0:
				_free_shots += 1
				_save("livre%02d" % _free_shots)
			return
		if not (cs is Level):
			return
		_quiet += 1
		var lv: Level = cs
		# Sem caixa: anda até a zona (o duelo da tela 1 começa no gatilho).
		if lv.zone_index < 0 and lv.zones.size() > 0 and lv.player != null and _quiet > 20:
			lv.player.global_position = Vector2(lv.zone_center(0) - Level.ZONE_TRIGGER + 8.0, lv.player.global_position.y)
		if _quiet == kill_after and not _killed:
			_kill_all(lv)

	func _kill_all(lv: Level) -> void:
		var vivos: Array = []
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.estate != Enemy.EState.DEAD:
				vivos.append(e)
		if vivos.is_empty():
			_quiet = 0
			return
		_killed = vivos.any(func(e) -> bool: return e.is_boss_enemy)
		_save("antes_da_queda")
		for e in vivos:
			e._on_hit_received(e.health.max_health + 999, lv.player.global_position, 60.0, false, null)
		print("CENA: matou %d inimigos no quadro %d" % [vivos.size(), _f])

	func _drive(box: DialogueBox) -> void:
		var id := box.get_instance_id()
		if id != _box_id:
			_box_id = id
			_boxes += 1
			_line = -1
		if box.idx != _line:
			_line = box.idx
			_line_f = 0
			_cue = ""
			if _line < box.lines.size():
				_cue = String(box.lines[_line].get("cue", ""))
			# Falas com efeito longo ficam mais tempo (o tempo de um jogador que olha).
			_hold = hold * 2 if _cue in ["rings_fly", "rings_return", "colossus_shrinks", "sink", "fog_thickens", "king_emerges"] else hold
		_line_f += 1
		if box.get("_in_choices"):
			if _line_f == 40:
				_save("d%d_escolha" % _boxes)
			if _line_f >= 60:
				box._on_choice(0)
			return
		if _cue != "" and _line_f == _hold / 2:
			_save("d%d_l%02d_%s_meio" % [_boxes, _line, _cue])
		if _line_f == _hold - 2:
			_save("d%d_l%02d%s" % [_boxes, _line, ("_" + _cue) if _cue != "" else ""])
		if _line_f >= _hold:
			# Avança como o jogador (respeita lock_advance/wait_2s se a UI tiver).
			if box.is_typing():
				box.reveal_all()
			var ev := InputEventAction.new()
			ev.action = "ui_accept"
			ev.pressed = true
			Input.parse_input_event(ev)
			_line_f = _hold - 30

	func _save(tag: String) -> void:
		var img := get_viewport().get_texture().get_image()
		var path := "%s_%03d_%s.png" % [prefix, _shots, tag]
		img.save_png(path)
		_shots += 1
		print("CENA: ", path)
