extends Node
## FERRAMENTA (não faz parte do jogo): filma e CRONOMETRA a abertura da
## campanha como um jogador novo — "Começar" → prólogo em cards (sem pular) →
## caixas de diálogo (cada fala fica `hold` quadros, como quem lê) → controle →
## caminhada (legendas) → Cena A (o Rei) → duelo. Imprime o tempo de cada marco
## ("ABERTURA|<marco>|<segundos>") e salva PNGs nos marcos.
## Uso (sempre com --fixed-fps 60 e --audio-driver Dummy):
##   godot --path . --fixed-fps 60 --resolution 1280x720 res://tools/encenacao/AberturaShot.tscn -- \
##     <prefixo_saida> [hold=150] [walk=N] [max=7200] [duel=N]
##   walk=N: N quadros depois do controle, segura → (o jogador "corre" para a direita);
##           walk=-1: fica parado (ouve todas as legendas) e só anda depois da Cena A.
##   duel=N: depois da Cena A, fica N quadros no duelo (para ver a 1ª dica de telegrafo).

var prefix: String = "/tmp/abertura"
var hold: int = 150
var walk: int = 30
var max_frames: int = 7200
var duel: int = 900


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		prefix = args[0]
	for i in range(1, args.size()):
		var kv: PackedStringArray = String(args[i]).split("=", true, 1)
		var v := int(kv[1]) if kv.size() > 1 else 0
		match kv[0]:
			"hold": hold = v
			"walk": walk = v
			"max": max_frames = v
			"duel": duel = v
	var w := _Worker.new()
	w.prefix = prefix
	w.hold = hold
	w.walk = walk
	w.max_frames = max_frames
	w.duel = duel
	get_tree().root.add_child.call_deferred(w)


class _Worker extends Node:
	var prefix: String = ""
	var hold: int = 150
	var walk: int = 30
	var max_frames: int = 7200
	var duel: int = 900
	var _f: int = 0
	var _shots: int = 0
	var _card: int = -1
	var _card_f: int = 0
	var _box_id: int = 0
	var _boxes: int = 0
	var _line: int = -1
	var _line_f: int = 0
	var _control_f: int = -1
	var _last_caption: String = ""
	var _scene_a_f: int = -1
	var _duel_f: int = -1
	var _slow_seen: bool = false
	var _hint_last: String = ""
	var _walking: bool = false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		# O mesmo que o Pré-jogo faz ao apertar "Começar a travessia".
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")
		_mark("comecar")

	func _t() -> float:
		return float(_f) / 60.0

	func _mark(what: String, extra: String = "") -> void:
		print("ABERTURA|%s|%.1f|%s" % [what, _t(), extra])

	func _process(_d: float) -> void:
		_f += 1
		if _f > max_frames:
			_finish("tempo máximo")
			return
		var cine: Cinematic = null
		var box: DialogueBox = null
		for c in get_tree().root.get_children():
			if c is Cinematic and not c.is_queued_for_deletion():
				cine = c
			elif c is DialogueBox and not c.is_queued_for_deletion():
				box = c
		_watch_captions()
		_watch_hints()
		if cine != null:
			_drive_cards(cine)
			return
		if box != null:
			_drive_box(box)
			return
		var cs := get_tree().current_scene
		if not (cs is Level):
			return
		var lv: Level = cs
		if _control_f < 0 and lv.get("_ready_done") and not get_tree().paused and GameManager.state == GameManager.State.PLAYING:
			_control_f = _f
			_mark("controle", "primeiro comando possível")
			_save("controle")
		if _control_f < 0:
			return
		var since := _f - _control_f
		if since in [90, 240, 420]:
			_save("caminhada_%d" % since)
		# Anda para a direita (jogador apressado) ou fica parado até a Cena A.
		var go := (walk >= 0 and since >= walk) or (walk < 0 and _scene_a_f >= 0)
		if go and not _walking:
			_walking = true
			Input.action_press("move_right")
			_mark("anda")
		if lv.zone_index >= 0 and _duel_f < 0:
			_duel_f = _f
			Input.action_release("move_right")
			_walking = false
			_mark("duelo", "zona trancada (o Rei de verdade nasce)")
		if _duel_f >= 0:
			if Engine.time_scale < 0.9 and not _slow_seen:
				_slow_seen = true
				_mark("camera_lenta", "time_scale=%.2f" % Engine.time_scale)
				_save("telegrafo_lento")
			if _f - _duel_f in [30, 200]:
				_save("duelo_%d" % (_f - _duel_f))
			if _f - _duel_f >= duel:
				_finish("fim do duelo filmado")

	func _drive_cards(c: Cinematic) -> void:
		var idx: int = int(c.get("_idx"))
		if idx != _card:
			_card = idx
			_card_f = 0
			_mark("card_%d" % idx)
		_card_f += 1
		if _card_f == 70:
			_save("card_%d" % idx)

	func _drive_box(box: DialogueBox) -> void:
		var id := box.get_instance_id()
		if id != _box_id:
			_box_id = id
			_boxes += 1
			_line = -1
			if _scene_a_f < 0 and _control_f >= 0:
				_scene_a_f = _f
				_mark("cena_a", "caixa aberta depois do controle")
		if box.idx != _line:
			_line = box.idx
			_line_f = 0
			if _line < box.lines.size():
				var l: Dictionary = box.lines[_line]
				_mark("fala", "%s: %s" % [String(l.get("speaker", "")), String(l.get("text", "")).left(70)])
		_line_f += 1
		if box.get("_in_choices"):
			if _line_f >= 60:
				box._on_choice(0)
			return
		if _line_f == hold - 2:
			_save("d%d_l%02d" % [_boxes, _line])
		if _line_f >= hold:
			if box.is_typing():
				box.reveal_all()
			var ev := InputEventAction.new()
			ev.action = "ui_accept"
			ev.pressed = true
			Input.parse_input_event(ev)
			_line_f = hold - 30

	func _watch_captions() -> void:
		var cap = Gnosis.get("_caption")
		if cap == null or not ("_text" in cap):
			return
		var txt := ""
		if bool(cap.get("_showing")):
			txt = String(cap.get("_text").text)
		if txt != _last_caption:
			_last_caption = txt
			if txt != "":
				_mark("legenda", txt.left(80))
				_save("legenda")

	func _watch_hints() -> void:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud == null or not ("_hint" in hud):
			return
		var h: Array = hud.get("_hint")
		var s := ""
		for seg in h:
			s += String(seg.get("text", "")) + " · "
		if s != _hint_last:
			_hint_last = s
			if s != "":
				_mark("dica", s)

	func _save(tag: String) -> void:
		var img := get_viewport().get_texture().get_image()
		var path := "%s_%03d_%s.png" % [prefix, _shots, tag]
		img.save_png(path)
		_shots += 1

	func _finish(why: String) -> void:
		Input.action_release("move_right")
		_mark("fim", why)
		get_tree().quit()
