extends Node
## FERRAMENTA (não faz parte do jogo): SONDA DE ENGASGOS DE PRIMEIRA VEZ.
## Abre uma tela do run, deixa assentar e dispara, UM POR VEZ e com quadros de
## silêncio entre eles, cada efeito/ação do combate (VFX, gibs, números, ações
## da Sophia, morte de inimigo...). Cada evento roda em 2 RODADAS: a 1ª paga o
## custo de "primeira vez" (compilar shader, criar material, subir textura,
## carregar script/recurso); a 2ª é o custo normal. A diferença é o engasgo
## que o pré-aquecimento (VfxLibrary.prewarm) deve eliminar.
## Uso (ver tools/perf/run.sh):
##   godot --path . --audio-driver Dummy [--headless] --resolution 640x360 res://tools/perf/HitchProbe.tscn -- \
##         [tela=3] [prewarm=0|1] [out=/caminho/engasgos.json]
## `prewarm=1` chama tools/perf/prewarm_proposta.gd (a correção proposta) no
## load da fase, ANTES de medir — prova de que a correção funciona sem editar o jogo.
## Para medir de verdade a 1ª vez, apague antes o cache de shaders do Godot
## (user://shader_cache) e o do driver (MESA_SHADER_CACHE_DISABLE=true) — o run.sh faz.

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)   # ferramenta NUNCA toca som (pedido do dono)
	var w := HitchWorker.new()
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"tela": w.screen = int(kv[1])
			"prewarm": w.prewarm = kv[1] == "1"
			"out": w.out = kv[1]
	get_tree().root.add_child.call_deferred(w)


class HitchWorker extends Node:
	const QUIET := 18          # quadros de base antes de cada evento
	const WATCH := 14          # quadros observados depois do evento
	const REST := 22           # folga depois (efeitos morrem)
	const WARM := 300          # quadros de assentamento depois que a fase abre

	var screen: int = 3
	var prewarm: bool = false
	var out: String = ""

	var _frame: int = 0
	var _level_frame: int = -1
	var _last_us: int = 0
	var _pre_us: int = 0
	var _render_ms: float = 0.0
	var _events: Array = []        # [nome, Callable]
	var _ev: int = 0
	var _round: int = 0
	var _phase: String = "warm"
	var _pf: int = 0               # quadro dentro da fase
	var _base_dt: PackedFloat64Array = PackedFloat64Array()
	var _base_rd: PackedFloat64Array = PackedFloat64Array()
	var _watch_dt: PackedFloat64Array = PackedFloat64Array()
	var _watch_rd: PackedFloat64Array = PackedFloat64Array()
	var _watch_pr: PackedFloat64Array = PackedFloat64Array()
	var _call_ms: float = 0.0
	var _added: Dictionary = {}    # classe/script -> qtde de nós criados na janela
	var _results: Array = []
	var _enemy: Node = null
	var _prewarm_ms: float = -1.0
	var _release: Array = []       # [quadro, ação] para soltar botão

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		RenderingServer.frame_pre_draw.connect(func(): _pre_us = Time.get_ticks_usec())
		RenderingServer.frame_post_draw.connect(func(): _render_ms = float(Time.get_ticks_usec() - _pre_us) / 1000.0)
		get_tree().node_added.connect(_on_node_added)
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _on_node_added(n: Node) -> void:
		if _phase != "watch" and _phase != "fire":
			return
		var s: Script = n.get_script()
		var k: String = n.get_class()
		if s != null:
			var gn: StringName = s.get_global_name()
			k = String(gn) if gn != &"" else s.resource_path.get_file()
		_added[k] = int(_added.get(k, 0)) + 1

	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var dt := float(now - _last_us) / 1000.0
		_last_us = now
		# Pula diálogos e cards (o quadro com diálogo não conta).
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
		if pl.health != null and pl.health.current_health < pl.health.max_health:
			pl.health.current_health = pl.health.max_health
		pl.mana = float(pl.max_mana_total)
		for r in _release.duplicate():
			if _frame >= int(r[0]):
				Input.action_release(String(r[1]))
				_release.erase(r)
		if _level_frame < 0:
			_level_frame = _frame
			if prewarm:
				var t0 := Time.get_ticks_usec()
				var pw = load("res://tools/perf/prewarm_proposta.gd")
				pw.prewarm(lv)
				_prewarm_ms = float(Time.get_ticks_usec() - t0) / 1000.0
			_build_events(lv as Level, pl)
			return
		match _phase:
			"warm":
				if _frame - _level_frame >= WARM:
					_start_quiet()
			"quiet":
				_pf += 1
				_base_dt.append(dt)
				_base_rd.append(_render_ms)
				if _pf >= QUIET:
					_fire(lv as Level, pl)
			"watch":
				_pf += 1
				_watch_dt.append(dt)
				_watch_rd.append(_render_ms)
				_watch_pr.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				if _pf >= WATCH:
					_close_event()
			"rest":
				_pf += 1
				if _pf >= REST:
					_next()

	func _start_quiet() -> void:
		_phase = "quiet"
		_pf = 0
		_base_dt.clear()
		_base_rd.clear()

	func _fire(lv: Level, pl: Player) -> void:
		_phase = "fire"
		_added.clear()
		_watch_dt.clear()
		_watch_rd.clear()
		_watch_pr.clear()
		var ev: Array = _events[_ev]
		var t0 := Time.get_ticks_usec()
		(ev[1] as Callable).call()
		_call_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		_phase = "watch"
		_pf = 0

	func _close_event() -> void:
		var ev: Array = _events[_ev]
		var bdt := _median(_base_dt)
		var brd := _median(_base_rd)
		var mdt := _max(_watch_dt)
		var mrd := _max(_watch_rd)
		var mpr := _max(_watch_pr)
		_results.append({
			"evento": ev[0], "rodada": _round + 1,
			"chamada_ms": snappedf(_call_ms, 0.01),
			"quadro_base_ms": snappedf(bdt, 0.01), "quadro_pico_ms": snappedf(mdt, 0.01),
			"excesso_ms": snappedf(maxf(0.0, mdt - bdt), 0.01),
			"render_base_ms": snappedf(brd, 0.01), "render_pico_ms": snappedf(mrd, 0.01),
			"process_pico_ms": snappedf(mpr, 0.01),
			"nos_criados": _added.duplicate(),
		})
		print("HITCH r%d %-28s chamada=%6.2f  pico=%7.2f (base %5.2f)  render=%7.2f (base %5.2f)" % [_round + 1, ev[0], _call_ms, mdt, bdt, mrd, brd])
		_phase = "rest"
		_pf = 0

	func _next() -> void:
		_ev += 1
		if _ev >= _events.size():
			_ev = 0
			_round += 1
			if _round >= 2:
				_report()
				return
		_start_quiet()

	func _median(a: PackedFloat64Array) -> float:
		if a.is_empty():
			return 0.0
		var s := a.duplicate()
		s.sort()
		return s[s.size() / 2]

	func _max(a: PackedFloat64Array) -> float:
		var m := 0.0
		for v in a:
			m = maxf(m, v)
		return m

	## Lista de eventos, na ordem em que aparecem numa luta comum.
	func _build_events(lv: Level, pl: Player) -> void:
		var col := Color(1.0, 0.85, 0.5)
		var at := func() -> Vector2: return pl.global_position + Vector2(46.0 * signf(pl.visual.scale.x if pl.visual else 1.0), -18.0)
		_events = [
			["inimigo_nasce", func(): _spawn_enemy(lv, pl)],
			["sophia_golpe_leve", func(): _press("attack_light")],
			["impact_burst", func(): ImpactBurst.spawn(lv, at.call(), col)],
			["damage_number", func(): DamageNumber.spawn(lv, at.call(), 12, col)],
			["vfx_hit_leve", func(): VfxLibrary.hit(lv, at.call(), false, col)],
			["vfx_hit_pesado", func(): VfxLibrary.hit(lv, at.call(), true, col)],
			["inimigo_leva_golpe", func(): _hurt_enemy(pl, 1)],
			["inimigo_morre_desmembra", func(): _hurt_enemy(pl, 99999)],
			["spark_orb", func(): SparkOrb.burst(lv, at.call(), 5)],
			["sophia_esquiva", func(): _press("dodge")],
			["sophia_pesado", func(): _press("attack_heavy")],
			["sophia_magia_inata", func(): _press("skill2")],
			["vfx_parry", func(): VfxLibrary.parry(lv, at.call())],
			["vfx_dodge_perfect", func(): VfxLibrary.dodge_perfect(lv, at.call())],
			["vfx_cast", func(): VfxLibrary.cast(lv, at.call())],
			["vfx_nova_ring", func(): VfxLibrary.nova_ring(lv, at.call(), 60.0)],
			["vfx_dust", func(): VfxLibrary.dust(lv, at.call())],
			["vfx_spark_pickup", func(): VfxLibrary.spark_pickup(lv, at.call())],
			["vfx_enemy_death", func(): VfxLibrary.enemy_death(lv, at.call(), col)],
			["vfx_elite_death", func(): VfxLibrary.elite_death(lv, at.call(), col)],
			["hazard_zone", func(): HazardZone.spawn(lv, at.call(), "poison", 50.0, 1.2, Color(0.5, 1.0, 0.4), "enemy", 0)],
			["aoe_nova", func(): AoeNova.spawn(lv, at.call(), 0, 50.0, col)],
			["projetil", func(): _projectile(lv, at.call())],
			["vfx_screen_flash", func(): VfxLibrary.screen_flash(lv)],
			["vfx_portal", func(): VfxLibrary.portal(lv, at.call(), Color(0.8, 0.9, 1.0), 1.0)],
			["vfx_boss_appear", func(): VfxLibrary.boss_appear(lv, at.call(), col)],
			["vfx_boss_phase2", func(): VfxLibrary.boss_phase2(lv, at.call(), col)],
			["vfx_boss_death", func(): VfxLibrary.boss_death(lv, at.call(), col)],
		]

	func _press(action: String) -> void:
		Input.action_press(action)
		_release.append([_frame + 3, action])

	## Inimigo comum do Éon desta tela, parado (sem IA) ao lado da Sophia.
	func _spawn_enemy(lv: Level, pl: Player) -> void:
		var types: Array = Bestiary.types_for_screen(screen)
		var e := lv.enemy_scene.instantiate()
		e.type_id = types[0] if not types.is_empty() else "servo"
		lv.add_child(e)
		e.global_position = pl.global_position + Vector2(70.0, 0.0)
		e.set_physics_process(false)     # sem IA: não ataca nem anda (só leva golpe)
		_enemy = e

	func _hurt_enemy(pl: Player, dmg: int) -> void:
		if _enemy == null or not is_instance_valid(_enemy):
			return
		var d: int = mini(dmg, int(_enemy.health.current_health))
		_enemy._on_hit_received(d, pl.global_position, 120.0, false, null)

	func _projectile(lv: Level, pos: Vector2) -> void:
		var p := Projectile.new()
		p.direction = 1
		p.damage = 0
		p.target_team = "none"
		p.lifetime = 0.4
		lv.add_child(p)
		p.global_position = pos

	func _report() -> void:
		# Resumo por evento: rodada 1 × rodada 2.
		var by: Dictionary = {}
		for r in _results:
			var k: String = r.evento
			if not by.has(k):
				by[k] = {}
			by[k][r.rodada] = r
		var rows: Array = []
		for ev in _events:
			var k: String = ev[0]
			var r1: Dictionary = by.get(k, {}).get(1, {})
			var r2: Dictionary = by.get(k, {}).get(2, {})
			if r1.is_empty() or r2.is_empty():
				continue
			rows.append({
				"evento": k,
				"pico1_ms": r1.quadro_pico_ms, "pico2_ms": r2.quadro_pico_ms,
				"render1_ms": r1.render_pico_ms, "render2_ms": r2.render_pico_ms,
				"chamada1_ms": r1.chamada_ms, "chamada2_ms": r2.chamada_ms,
				"primeira_vez_ms": snappedf(maxf(0.0, float(r1.quadro_pico_ms) - float(r2.quadro_pico_ms)), 0.01),
				"nos": r1.nos_criados,
			})
		var res := {
			"tela": screen, "prewarm": prewarm, "prewarm_ms": snappedf(_prewarm_ms, 0.01),
			"headless": DisplayServer.get_name() == "headless",
			"gpu": RenderingServer.get_video_adapter_name(),
			"resolucao": str(get_viewport().get_visible_rect().size),
			"resumo": rows, "bruto": _results,
		}
		print("HITCHSUM ", JSON.stringify({"tela": screen, "prewarm": prewarm, "prewarm_ms": res.prewarm_ms}))
		for row in rows:
			print("HITCHROW %-28s 1a=%7.2f  2a=%7.2f  1a_vez=%7.2f  render 1a/2a=%7.2f/%7.2f" % [row.evento, row.pico1_ms, row.pico2_ms, row.primeira_vez_ms, row.render1_ms, row.render2_ms])
		if out != "":
			var f := FileAccess.open(out, FileAccess.WRITE)
			if f != null:
				f.store_string(JSON.stringify(res, "\t"))
				f.close()
		get_tree().quit()
