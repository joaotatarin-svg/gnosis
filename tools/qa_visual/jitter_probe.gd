extends Node
## SONDA QA-VISUAL (não faz parte do jogo): TREMOR de câmera/personagem em
## tempo REAL (sem --fixed-fps), com physics_interpolation do projeto.
## Abre a tela, some com os inimigos, faz a Sophia ANDAR 3 s para a direita e
## ficar PARADA 2 s. A cada quadro desenhado mede: dt, origem da câmera
## (canvas_transform) e x/y da Sophia NA TELA (px de 640×360, com fração).
## (Node2D não expõe a transformação interpolada: a posição desenhada é
## reconstruída como lerp(física anterior, atual, fração) — aproximação.)
## Tremor = quadros em que o x de tela da Sophia ANDA PARA TRÁS (≥0,25 px)
## enquanto ela corre num sentido só, ou se mexe ≥0,25 px parada.
## Saída: "JIT|fase=<anda|parada>|quadros=..|qps=..|recuos=..|max_recuo=..|desvio_passo=..|mov_parada=.."
## Uso: godot --audio-driver Dummy --path . --resolution 1280x720 --position 4000,4000 \
##   res://tools/qa_visual/JitterProbe.tscn -- [tela=3] [vsync=0|1] [out=arquivo.csv]

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var w := J.new()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = String(a).split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"tela": w.screen = int(kv[1])
			"vsync": w.vsync = kv[1] == "1"
			"out": w.out = kv[1]
	get_tree().root.add_child.call_deferred(w)


class J extends Node:
	var screen: int = 3
	var vsync: bool = false
	var out: String = ""
	var _f: int = 0
	var _t0: int = 0
	var _phase: String = "carga"
	var _rows: Array = []      # [t_ms, fase, dt_ms, cam_x, sx, sy]
	var _last: int = 0
	var _pp: Vector2 = Vector2.ZERO    # posição física anterior da Sophia
	var _pc: Vector2 = Vector2.ZERO    # posição física atual
	var _pl: Player = null

	## Guarda as duas últimas posições FÍSICAS (pra reconstruir a interpolada).
	func _physics_process(_d: float) -> void:
		if _pl != null and is_instance_valid(_pl):
			_pp = _pc
			_pc = _pl.global_position

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = 1000        # mede DEPOIS de todo mundo (câmera já andou)
		SaveManager.persist_enabled = false
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
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
				c._finish()
				return
		if get_tree().paused:
			get_tree().paused = false
		var lv := get_tree().current_scene
		if not (lv is Level) or (lv as Level).player == null:
			return
		_f += 1
		var pl: Player = lv.player
		if _pl == null:
			_pl = pl
			_pc = pl.global_position
			_pp = _pc
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy:
				e.queue_free()
		if _f == 120:
			_t0 = Time.get_ticks_usec()
			_last = _t0
			_phase = "anda"
			Input.action_press("move_right")
		if _f < 120:
			return
		var now := Time.get_ticks_usec()
		var t := float(now - _t0) / 1000.0
		if _phase == "anda" and t > 3000.0:
			_phase = "parada"
			Input.action_release("move_right")
		var ct := get_viewport().get_canvas_transform()
		# Posição que vai pra tela: com physics_interpolation o Godot desenha
		# lerp(física anterior, física atual, fração) — reconstruída aqui.
		var frac := Engine.get_physics_interpolation_fraction() if get_tree().physics_interpolation else 1.0
		var sp: Vector2 = ct * _pp.lerp(_pc, frac)
		_rows.append([t, _phase, float(now - _last) / 1000.0, ct.origin.x, sp.x, sp.y])
		_last = now
		if t > 5000.0:
			_report()

	func _report() -> void:
		for fase in ["anda", "parada"]:
			var rs: Array = _rows.filter(func(r): return r[1] == fase)
			if fase == "parada":
				rs = rs.filter(func(r): return r[0] > 3600.0)   # 0,6 s pra frear e a câmera assentar
			if rs.size() < 3:
				continue
			var back := 0
			var max_back := 0.0
			var steps: Array = []
			var mov := 0
			var dtsum := 0.0
			for i in range(1, rs.size()):
				var d: float = rs[i][4] - rs[i - 1][4]
				dtsum += rs[i][2]
				steps.append(d / maxf(0.001, rs[i][2]))    # px de tela por ms
				if fase == "anda" and d < -0.25:
					back += 1
					max_back = maxf(max_back, -d)
				if fase == "parada" and absf(d) >= 0.25:
					mov += 1
			var mean := 0.0
			for s in steps:
				mean += s
			mean /= steps.size()
			var dev := 0.0
			for s in steps:
				dev += (s - mean) * (s - mean)
			dev = sqrt(dev / steps.size())
			print("JIT|tela=%d|vsync=%s|fase=%s|quadros=%d|qps=%.0f|recuos=%d|max_recuo=%.2fpx|vel_media=%.4fpx/ms|desvio_vel=%.4f (%.0f%%)|mov_parada=%d" % [screen, str(vsync), fase, rs.size(), 1000.0 * (rs.size() - 1) / maxf(1.0, dtsum), back, max_back, mean, dev, 100.0 * dev / maxf(0.0001, absf(mean)), mov])
		if out != "":
			var f := FileAccess.open(out, FileAccess.WRITE)
			f.store_line("t_ms;fase;dt_ms;cam_x;tela_x;tela_y")
			for r in _rows:
				f.store_line("%.2f;%s;%.3f;%.3f;%.3f;%.3f" % r)
			f.close()
		get_tree().quit()
