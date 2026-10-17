extends Node
## FERRAMENTA (não faz parte do jogo): SONDA DE DESEMPENHO.
## Abre uma tela do run com janela real, espera o chefe/waves, ENCHE a arena com
## N criaturas comuns (repõe quem morre), a Sophia ataca sem parar (gera golpes,
## faíscas, desmembramento) e mede o tempo de cada frame por alguns segundos.
## Uso:
##   godot --path . --audio-driver Dummy --resolution 1280x720 --position 4000,4000 res://tools/PerfProbe.tscn -- \
##         [tela=19] [n=12] [seg=10] [vsync=0|1] [ataque=1|0] [out=C:/x/perf.json]
## Imprime "PERF ..." (qps médio, mínimo, p1%, tempo de frame médio/mediana/p99/máx,
## draw calls, nós, memória) e grava o JSON em `out`
## (se dado). NÃO use --fixed-fps aqui (ele falsifica o tempo real).
## Na nuvem (sem GPU): rode `--headless` para o custo de CPU (draw calls = 0) e
## com janela pequena (`--resolution 320x180`, llvmpipe) só para contar draw
## calls/objetos — o tempo do llvmpipe não vale como medida. tools/perf/run.sh faz os dois.

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)   # ferramenta NUNCA toca som (pedido do dono)
	var p := PerfWorker.new()
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"tela": p.screen = int(kv[1])
			"n": p.extra = int(kv[1])
			"seg": p.seconds = float(kv[1])
			"vsync": p.vsync = kv[1] == "1"
			"ataque": p.attack = kv[1] == "1"
			"out": p.out = kv[1]
	get_tree().root.add_child.call_deferred(p)


class PerfWorker extends Node:
	var screen: int = 19
	var extra: int = 12            # criaturas comuns além do que a tela já tem
	var seconds: float = 10.0
	var vsync: bool = false
	var attack: bool = true
	var out: String = ""
	var _frame: int = 0
	var _warm: int = 240           # frames de aquecimento (chefe nasce, card some)
	var _measuring: bool = false
	var _t0: int = 0
	var _last: int = 0
	var _dts: PackedFloat64Array = PackedFloat64Array()
	var _draws: int = 0
	var _objs: int = 0
	var _alive_sum: int = 0
	var _types: Array = []

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		# Headless: o Godot DORME ~6,9 ms por quadro quando não há janela que
		# desenhe (low_processor_usage_mode_sleep_usec). Zera para o tempo do
		# quadro ser só o trabalho de CPU do jogo.
		if DisplayServer.get_name() == "headless":
			OS.low_processor_usage_mode_sleep_usec = 0
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_delta: float) -> void:
		# Pula diálogos e cards (não conta frame com diálogo).
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
				return
		if get_tree().paused:
			get_tree().paused = false
		_frame += 1
		var lv := get_tree().current_scene
		if not lv is Level:
			return
		var pl: Player = (lv as Level).player
		if pl == null:
			return
		# Sophia imortal (a sonda mede render, não o balanceamento).
		if pl.health != null and pl.health.current_health < pl.health.max_health:
			pl.health.current_health = pl.health.max_health
		if _frame < _warm:
			return
		_top_up(lv as Level, pl)
		if attack and _frame % 14 == 0:
			Input.action_press("attack_light")
		elif attack and _frame % 14 == 3:
			Input.action_release("attack_light")
		if not _measuring:
			if _frame >= _warm + 60:   # 1 s pra estabilizar depois de encher
				_measuring = true
				_t0 = Time.get_ticks_usec()
				_last = _t0
			return
		var now := Time.get_ticks_usec()
		_dts.append(float(now - _last) / 1000.0)
		_last = now
		_draws += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_objs += int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		_alive_sum += _count_alive()
		if float(now - _t0) / 1000000.0 >= seconds:
			_report()

	## Mantém `extra` criaturas comuns vivas perto da Sophia.
	func _top_up(lv: Level, pl: Player) -> void:
		if lv.enemy_scene == null:
			return
		if _types.is_empty():
			_types = Bestiary.types_for_screen(screen)
			if _types.is_empty():
				_types = ["servo"]
		var commons := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and not e.is_boss_enemy and e.estate != Enemy.EState.DEAD and e.has_meta("perf"):
				commons += 1
		var k := 0
		while commons < extra and k < 4:      # até 4 por frame (não engasga o spawn)
			var e := lv.enemy_scene.instantiate()
			e.type_id = _types[(commons + _frame) % _types.size()]
			e.set_meta("perf", true)
			lv.add_child(e)
			var side := -1.0 if commons % 2 == 0 else 1.0
			e.global_position = Vector2(pl.global_position.x + side * (60.0 + float(commons) * 18.0), 250.0)
			commons += 1
			k += 1

	func _count_alive() -> int:
		var n := 0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.estate != Enemy.EState.DEAD:
				n += 1
		return n

	func _report() -> void:
		Input.action_release("attack_light")
		var n := _dts.size()
		var sorted := _dts.duplicate()
		sorted.sort()
		var total := 0.0
		for d in _dts:
			total += d
		var avg_ms := total / float(n)
		var p99_ms: float = sorted[mini(n - 1, int(float(n) * 0.99))]
		var max_ms: float = sorted[n - 1]
		# "1% low": qps médio do pior 1% dos frames.
		var worst := 0.0
		var cnt := maxi(1, n / 100)
		for i in range(n - cnt, n):
			worst += sorted[i]
		var low1 := 1000.0 / (worst / float(cnt))
		var res := {
			"tela": screen, "extra": extra, "seg": seconds, "vsync": vsync, "ataque": attack,
			"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
			"gpu": RenderingServer.get_video_adapter_name(),
			"frames": n,
			"fps_medio": snappedf(1000.0 / avg_ms, 0.1),
			"fps_1pct_low": snappedf(low1, 0.1),
			"fps_min": snappedf(1000.0 / max_ms, 0.1),
			"ms_medio": snappedf(avg_ms, 0.01), "ms_p99": snappedf(p99_ms, 0.01), "ms_max": snappedf(max_ms, 0.01),
			"ms_mediana": snappedf(sorted[n / 2], 0.01),
			"headless": DisplayServer.get_name() == "headless",
			"inimigos_vivos_medio": snappedf(float(_alive_sum) / float(n), 0.1),
			"draw_calls_medio": _draws / n, "objetos_medio": _objs / n,
			"nos": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"mem_estatica_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
			"vram_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		}
		print("PERF ", JSON.stringify(res))
		if out != "":
			var f := FileAccess.open(out, FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(res, "\t"))
				f.close()
		get_tree().quit()
