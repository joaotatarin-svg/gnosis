extends Node
## FERRAMENTA (não faz parte do jogo): abre uma tela do run com janela real,
## pula os diálogos, espera uns frames e salva um PNG do viewport pra a IA VER.
## Uso: godot --path . res://tools/Shot.tscn -- <tela> <saida.png> [frames] [hurt|kill|clear|wave|die]
##   hurt = na metade dos frames, tira 55% da vida dos chefes (força a FASE 2).
##   wave = na metade, mata a wave viva UMA vez (mostra a wave seguinte — ex.: o Campeão).
## Com as TRAVESSIAS: sem inimigo vivo, a Sophia "anda" sozinha até o gatilho
## da próxima zona (ou até a fenda) — toda captura mostra combate.
## O trabalho é feito por um nó filho do ROOT (sobrevive à troca de cena e
## roda mesmo com a árvore pausada pelo DialogueBox).

func _ready() -> void:
	var w := ShotWorker.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		if args[0].begins_with("res://"):
			w.scene_path = args[0]      # cena avulsa (menu, galeria...)
		else:
			w.screen = int(args[0])
	if args.size() >= 2:
		w.out = args[1]
	if args.size() >= 3:
		w.frames = int(args[2])
	if args.size() >= 4 and args[3] == "hurt":
		w.hurt = true
	if args.size() >= 4 and args[3] == "kill":
		w.kill = true
	if args.size() >= 4 and args[3] == "clear":
		w.clear = true
	if args.size() >= 4 and args[3] == "die":
		w.die = true
	if args.size() >= 4 and args[3] == "wave":
		w.wave = true
	get_tree().root.add_child.call_deferred(w)


class ShotWorker extends Node:
	var screen: int = 1
	var scene_path: String = ""
	var out: String = "user://shot.png"
	var frames: int = 90
	var hurt: bool = false
	var kill: bool = false          # na metade: mata os inimigos comuns com golpe pesado (vê desmembramento)
	var clear: bool = false         # a cada terço: mata TUDO e anda até a próxima zona/portal (fluxo da travessia)
	var die: bool = false           # na metade: MATA A SOPHIA (testa checkpoint/renascimento)
	var wave: bool = false          # na metade: mata a wave viva uma vez (vê a próxima)
	var _hurt_done: bool = false
	var _count: int = 0
	var _deadline: int = 1200
	var _since_kill: int = 0        # frames desde a última matança (clear)

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false   # ferramenta não suja o save real
		if scene_path != "":
			get_tree().change_scene_to_file.call_deferred(scene_path)
			return
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		for sk in GameContent.characters[0].skills:
			if sk.ring != "":
				Progression.add_ring(sk.ring, sk.id)
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_delta: float) -> void:
		_deadline -= 1
		var had_dialog := false
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)     # escolha padrão (ex.: "Recusar")
				else:
					c._finish()
				had_dialog = true
		if had_dialog:
			return                      # conta frames só sem diálogo na tela
		_count += 1
		if hurt and not _hurt_done and _count >= frames / 2:
			_hurt_done = true
			var pl := get_tree().get_first_node_in_group("player")
			for e in get_tree().get_nodes_in_group("enemy"):
				if e.is_boss_enemy and pl != null:
					e._on_hit_received(int(e.health.max_health * 0.55), pl.global_position, 10.0, false, null)
		_since_kill += 1
		if wave and not _hurt_done and _count >= frames / 2:
			_hurt_done = true
			_since_kill = 0
			var plw := get_tree().get_first_node_in_group("player")
			for e in get_tree().get_nodes_in_group("enemy"):
				if plw != null and e.estate != Enemy.EState.DEAD:
					e._on_hit_received(e.health.max_health + 999, plw.global_position, 60.0, false, null)
		if clear:
			var third := maxi(1, frames / 3)
			# No meio de cada terço: mata tudo que estiver vivo (a wave seguinte,
			# a zona ou o chefe caem) — o último terço ainda sobra pra VER o resultado.
			if _count % third == third / 2:
				_since_kill = 0
				var pl2 := get_tree().get_first_node_in_group("player")
				for e in get_tree().get_nodes_in_group("enemy"):
					if pl2 != null and e.estate != Enemy.EState.DEAD:
						e._on_hit_received(e.health.max_health + 999, pl2.global_position, 60.0, false, null)
			# Fecha a loja pós-chefe/santuário, se abriu (avança de tela).
			var cs := get_tree().current_scene
			if cs != null:
				for c in cs.get_children():
					if c is CanvasLayer and c.has_method("_close"):
						c._close()
		_walk_ahead(get_tree().current_scene)
		if die and not _hurt_done and _count >= frames / 2:
			_hurt_done = true
			var plx := get_tree().get_first_node_in_group("player")
			if plx != null and plx.health != null:
				print("SHOT: matando a Sophia (teste de checkpoint) na tela ", RunManager.current_screen)
				plx.health.take_damage(99999)
		if kill and not _hurt_done and _count >= frames / 2:
			_hurt_done = true
			var pl := get_tree().get_first_node_in_group("player")
			for e in get_tree().get_nodes_in_group("enemy"):
				if not e.is_boss_enemy and pl != null:
					e.force_dismember = true
					e._on_hit_received(e.health.max_health + 5, pl.global_position, 260.0, false, null)
		if _count >= frames or _deadline <= 0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(out)
			print("SHOT salvo: ", out, " ", img.get_width(), "x", img.get_height())
			# Diagnóstico da travessia: onde a Sophia está e em que zona a tela ficou.
			var lvd := get_tree().current_scene
			var pld := get_tree().get_first_node_in_group("player")
			if lvd is Level and pld != null:
				var vivos := 0
				for e in get_tree().get_nodes_in_group("enemy"):
					if e is Enemy and e.estate != Enemy.EState.DEAD:
						vivos += 1
				print("SHOT tela=%d zona=%d/%d wave=%d/%d ativa=%s vivos=%d player=(%.0f,%.0f) fps=%.0f" % [lvd.screen, lvd.zone_index, lvd.zones.size(), lvd.wave_index, lvd.waves.size(), str(lvd.zone_active), vivos, pld.global_position.x, pld.global_position.y, Engine.get_frames_per_second()])
			get_tree().quit()


	## Sem inimigo vivo: "anda" até a fenda (avança) ou até o gatilho da
	## próxima zona (ela tranca e as waves nascem) — o fluxo da travessia.
	func _walk_ahead(cs: Node) -> void:
		if cs == null or not cs is Level or _since_kill < 60:
			return
		var lv: Level = cs
		if lv.player == null or lv.zone_active:
			return
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.estate != Enemy.EState.DEAD:
				return
		for c in lv.get_children():
			if c is ExitPortal:
				lv.player.global_position = c.global_position + Vector2(0, -20)
				return
		var next: int = lv.zone_index + 1
		if next < lv.zones.size():
			lv.player.global_position = Vector2(lv.zone_center(next) - Level.ZONE_TRIGGER + 8.0, 250.0)
