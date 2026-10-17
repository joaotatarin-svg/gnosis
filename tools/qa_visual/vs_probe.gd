extends Node
## SONDA QA-VISUAL de BISSECÇÃO do vsync (roda em qualquer base, até a pré-Onda 1).
## Abre a tela, pula diálogos, espera 2 s e mede 8 s de quadros.
## Uso: godot --audio-driver Dummy --path . --resolution 1280x720 --position 100,100 res://tools/qa_visual/VsProbe.tscn -- tela=22 vsync=1
## (para bissecar, copie este .gd e o .tscn para tools/ de um worktree antigo e ajuste o caminho no .tscn)
## vsync=keep: não mexe no vsync (fica o que o jogo aplicou das Opções).
## Args: tela=22 vsync=1|0|keep vsync=1 interp=keep|0|1 maxfps=0 → "VS|..."

func _ready() -> void:
	get_tree().root.add_child.call_deferred(W.new())


class W extends Node:
	var screen: int = 22
	var vsync: bool = true
	var keep_vsync: bool = false
	var interp: String = "keep"
	var maxfps: int = 0
	var _f: int = 0
	var _t0: int = 0
	var _last: int = 0
	var _dts: Array = []

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		AudioServer.set_bus_mute(0, true)
		for a in OS.get_cmdline_user_args():
			var kv: PackedStringArray = String(a).split("=", true, 1)
			if kv.size() < 2:
				continue
			match kv[0]:
				"tela": screen = int(kv[1])
				"vsync":
					vsync = kv[1] == "1"
					keep_vsync = kv[1] == "keep"
				"interp": interp = kv[1]
				"maxfps": maxfps = int(kv[1])
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_d: float) -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				c._finish()
		if get_tree().paused:
			get_tree().paused = false
		_f += 1
		if _f == 30:
			# aplica DEPOIS do jogo (GameManager aplica as Opções no começo)
			if not keep_vsync:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = maxfps
			if interp != "keep":
				get_tree().physics_interpolation = interp == "1"
		var now := Time.get_ticks_usec()
		if _f == 120:
			_t0 = now
		elif _f > 120:
			_dts.append(float(now - _last) / 1000.0)
			if float(now - _t0) / 1e6 >= 8.0:
				var s := _dts.duplicate()
				s.sort()
				var tot := 0.0
				for d in _dts:
					tot += d
				var avg: float = tot / _dts.size()
				print("VS|tela=%d|vsync=%s|modo_real=%d|interp=%s(%s)|maxfps=%d|driver=%s|quadros=%d|qps=%.1f|ms_med=%.2f|ms_p99=%.2f|ms_max=%.2f" % [screen, str(vsync), DisplayServer.window_get_vsync_mode(), interp, str(get_tree().physics_interpolation), maxfps, RenderingServer.get_current_rendering_driver_name(), _dts.size(), 1000.0 / avg, avg, s[int(s.size() * 0.99)], s[s.size() - 1]])
				get_tree().quit()
		_last = now
