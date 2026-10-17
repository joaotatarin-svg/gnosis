extends Node
## SONDA QA-VISUAL (não faz parte do jogo): filma o FEEL do combate em quadros.
## Abre uma tela, anda até a zona trancar e roda um roteiro por Input simulado:
##   combo (L L L) → pesado (H) → esquiva → APARAR (aperta "block" quando um
##   inimigo entra em WINDUP perto, ~0,1 s antes do golpe) — 2× cada.
## Salva um quadro (1280×720) a cada `every` quadros e um meta JSON por quadro
## (Sophia/chefe em px da imagem, estado, golpe, Engine.time_scale = hitstop,
## zoom e origem da câmera) — compatível com tools/seq_to_media.py --follow.
## Uso: godot --fixed-fps 60 --audio-driver Dummy --path . --resolution 1280x720 --position 4000,4000 \
##   res://tools/qa_visual/CombatSeq.tscn -- <tela> <prefixo> [every=2] [frames=600] [solo_chefe]

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var w := W.new()
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		w.screen = int(a[0])
	if a.size() > 1:
		w.prefix = a[1]
	for i in range(2, a.size()):
		var kv: PackedStringArray = String(a[i]).split("=", true, 1)
		match kv[0]:
			"every": w.every = maxi(1, int(kv[1]))
			"frames": w.total = int(kv[1])
	get_tree().root.add_child.call_deferred(w)


class W extends Node:
	var screen: int = 3
	var prefix: String = "user://combat"
	var every: int = 2
	var total: int = 600
	var _f: int = 0
	var _t: int = -1          # quadro do roteiro (começa quando a zona tranca)
	var _n: int = 0
	var _meta: Array = []
	var _held: Dictionary = {}
	var _parries: int = 0
	var _parry_cd: int = 0

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
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _press(a: String, fr: int) -> void:
		Input.action_press(a)
		_held[a] = fr

	func _process(_d: float) -> void:
		_f += 1
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
				return
		for a in _held.keys():
			_held[a] -= 1
			if _held[a] <= 0:
				Input.action_release(a)
				_held.erase(a)
		var lv := get_tree().current_scene
		if not (lv is Level) or (lv as Level).player == null:
			return
		var pl: Player = lv.player
		pl.health.current_health = pl.health.max_health
		if _t < 0:
			if (lv as Level).zone_active or _f > 900:
				_t = 0
				Input.action_release("move_right")
			elif _f > 30:
				Input.action_press("move_right")
			return
		_t += 1
		_script(pl)
		if _t % every == 0:
			_save(lv, pl)
		if _t >= total:
			var f := FileAccess.open(prefix + "_meta.json", FileAccess.WRITE)
			f.store_string(JSON.stringify({"target": str(screen), "every": every, "count": _n, "viewport": [640.0, 360.0], "frames": _meta, "physics_fps": 60}))
			f.close()
			print("CSEQ: fim quadros=%d aparos=%d" % [_n, _parries])
			get_tree().quit()

	## Roteiro (em quadros desde a zona trancar). Encara o inimigo mais perto.
	func _script(pl: Player) -> void:
		var e := _nearest(pl)
		if e != null and _held.is_empty() and _t % 20 == 0:
			var dir := signf(e.global_position.x - pl.global_position.x)
			if absf(e.global_position.x - pl.global_position.x) > 46.0:
				_press("move_right" if dir > 0 else "move_left", 8)
		var c := _t % 300
		match c:
			20, 34, 48: _press("attack_light", 3)      # L L L
			110: _press("attack_heavy", 3)             # H
			170: _press("dodge", 3)                    # esquiva
		# Aparar: um inimigo perto entrando em WINDUP → aperta block (fica 10 quadros).
		if _parry_cd > 0:
			_parry_cd -= 1
		elif c > 190 and e != null and e.estate == Enemy.EState.WINDUP and absf(e.global_position.x - pl.global_position.x) < 90.0:
			_press("block", 10)
			_parry_cd = 40
			_parries += 1

	func _nearest(pl: Player) -> Enemy:
		var best: Enemy = null
		var bd := 1e9
		for x in get_tree().get_nodes_in_group("enemy"):
			if x is Enemy and x.estate != Enemy.EState.DEAD:
				var d := absf(x.global_position.x - pl.global_position.x)
				if d < bd:
					bd = d
					best = x
		return best

	func _save(lv: Level, pl: Player) -> void:
		var img := get_viewport().get_texture().get_image()
		var sc := float(img.get_width()) / 640.0
		img.save_png("%s_%03d.png" % [prefix, _n])
		var ct := get_viewport().get_canvas_transform()
		var pp: Vector2 = (ct * pl.global_position) * sc
		var bosses: Array = []
		for x in get_tree().get_nodes_in_group("enemy"):
			if x is Enemy and x.is_boss_enemy and x.estate != Enemy.EState.DEAD:
				var bp: Vector2 = (ct * x.global_position) * sc
				bosses.append({"pos": [roundi(bp.x), roundi(bp.y)], "estate": Enemy.EState.keys()[x.estate], "phase": int(x.get("phase")) if x.get("phase") != null else 1})
		var cam := get_viewport().get_camera_2d()
		_meta.append({"i": _n, "frame": _t, "player": [roundi(pp.x), roundi(pp.y)],
			"state": Player.State.keys()[pl.state], "move": pl.current_move.id if pl.current_move != null else "",
			"time_scale": snappedf(Engine.time_scale, 0.01), "zoom": snappedf(cam.zoom.x, 0.001) if cam != null else 0.0,
			"cam_origin": [snappedf(ct.origin.x, 0.01), snappedf(ct.origin.y, 0.01)], "bosses": bosses})
		_n += 1
