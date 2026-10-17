extends Node
## FERRAMENTA (não faz parte do jogo): MEDIÇÃO DE QPS COM AS OPÇÕES DO SAVE.
## Diferente da PerfProbe (que força VSync/max_fps), esta NÃO mexe em VSync nem
## em Engine.max_fps: vale o que o boot aplicou a partir do save do user dir
## (inclusive a migração do VSync da 1.2.0). Abre a tela pedida, pula diálogos,
## deixa a Sophia imortal batendo de leve e mede o tempo real de cada quadro.
## Uso (janela VISÍVEL — medir qps fora do monitor não vale):
##   godot --audio-driver Dummy --path . res://tools/perf/FpsReal.tscn -- \
##         [tela=22] [seg=25] [vsync=save|0|1] [out=C:/x/fps.json]
## `vsync=1` força o comportamento antigo (comparação). Imprime "FPSREAL ...".
## NUNCA grava o save (persist desligado depois do boot).

## A cena troca para a fase: o trabalho fica num nó filho da RAIZ (sobrevive).
func _ready() -> void:
	get_tree().root.add_child.call_deferred(FpsWorker.new())


class FpsWorker extends Node:
	var screen: int = 22
	var seconds: float = 25.0
	var force_vsync: String = "save"
	var out: String = ""
	var _frame: int = 0
	var _warm_s: float = 4.0        # s reais de aquecimento (cena monta, card some)
	var _start: int = 0
	var _t0: int = 0
	var _last: int = 0
	var _measuring: bool = false
	var _dts: PackedFloat64Array = PackedFloat64Array()
	var _boot_info: Dictionary = {}


	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_start = Time.get_ticks_usec()
		AudioServer.set_bus_mute(0, true)   # ferramenta nunca toca som
		for a in OS.get_cmdline_user_args():
			var kv := String(a).split("=", true, 1)
			if kv.size() < 2:
				continue
			match kv[0]:
				"tela": screen = int(kv[1])
				"seg": seconds = float(kv[1])
				"vsync": force_vsync = kv[1]
				"out": out = kv[1]
		# O que o boot aplicou (antes de qualquer mudança desta ferramenta).
		_boot_info = {
			"user_dir": OS.get_user_data_dir(),
			"settings_vsync": GameManager.settings.get("vsync"),
			"settings_rev": GameManager.settings.get("settings_rev"),
			"vsync_mode": DisplayServer.window_get_vsync_mode(),
			"max_fps": Engine.max_fps,
			"refresh_hz": DisplayServer.screen_get_refresh_rate(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"gpu": RenderingServer.get_video_adapter_name(),
		}
		SaveManager.persist_enabled = false
		Gnosis.persist_enabled = false
		if force_vsync == "1" or force_vsync == "0":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if force_vsync == "1" else DisplayServer.VSYNC_DISABLED)
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")


	func _process(_delta: float) -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
		if get_tree().paused:
			get_tree().paused = false
		_frame += 1
		var lv := get_tree().current_scene
		if lv is Level and (lv as Level).player != null:
			var pl: Player = (lv as Level).player
			if pl.health != null and pl.health.current_health < pl.health.max_health:
				pl.health.current_health = pl.health.max_health
			if _frame % 14 == 0:
				Input.action_press("attack_light")
			elif _frame % 14 == 3:
				Input.action_release("attack_light")
		var now := Time.get_ticks_usec()
		if float(now - _start) / 1000000.0 < _warm_s:
			return
		if not _measuring:
			_measuring = true
			_t0 = now
			_last = now
			return
		_dts.append(float(now - _last) / 1000.0)
		_last = now
		if float(now - _t0) / 1000000.0 >= seconds:
			_report()


	func _report() -> void:
		set_process(false)
		var n := _dts.size()
		var total := 0.0
		for d in _dts:
			total += d
		var sorted := _dts.duplicate()
		sorted.sort()
		var avg_ms := total / maxf(1.0, float(n))
		var p99_ms: float = sorted[clampi(int(n * 0.99), 0, n - 1)] if n > 0 else 0.0
		var worst1 := 0.0   # média do 1% pior → "1% low" em qps
		var k := maxi(1, n / 100)
		for i in k:
			worst1 += sorted[n - 1 - i]
		worst1 /= float(k)
		var r := _boot_info.duplicate()
		r.merge({
			"screen": screen, "seconds": total / 1000.0, "frames": n, "forced_vsync": force_vsync,
			"vsync_mode_measured": DisplayServer.window_get_vsync_mode(),
			"fps_avg": 1000.0 / avg_ms if avg_ms > 0.0 else 0.0,
			"fps_1pct_low": 1000.0 / worst1 if worst1 > 0.0 else 0.0,
			"frame_ms_avg": avg_ms, "frame_ms_p99": p99_ms, "frame_ms_max": sorted[n - 1] if n > 0 else 0.0,
			"window": DisplayServer.window_get_size(), "window_mode": DisplayServer.window_get_mode(),
		})
		print("FPSREAL ", JSON.stringify(r))
		if out != "":
			var f := FileAccess.open(out, FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(r, "  "))
				f.close()
		get_tree().quit(0)
