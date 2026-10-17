extends Node
## FERRAMENTA (não faz parte do jogo): abre uma tela do run com janela real,
## pula os diálogos, espera uns frames e salva um PNG do viewport pra a IA VER.
## Uso: godot --path . res://tools/Shot.tscn -- <tela|res://cena.tscn> <saida.png> [frames] [modo] [opção=valor ...]
##   Modos (palavra solta, como antes): hurt|kill|clear|wave|die|dialog
##   hurt = na metade dos frames, tira 55% da vida dos chefes (força a FASE 2).
##   wave = na metade, mata a wave viva UMA vez (mostra a wave seguinte — ex.: o Campeão).
## Com as TRAVESSIAS: sem inimigo vivo, a Sophia "anda" sozinha até o gatilho
## da próxima zona (ou até a fenda) — toda captura mostra combate.
## O trabalho é feito por um nó filho do ROOT (sobrevive à troca de cena e
## roda mesmo com a árvore pausada pelo DialogueBox).
##
## MODO SEQUÊNCIA (filmar MOVIMENTO — Onda 1, diretor técnico):
##   seq=N      salva N quadros em vez de 1: <saida>_000.png ... <saida>_NNN.png
##   every=K    um quadro a cada K frames (padrão 2 = 30 qps a 60 fps)
##   act=NOME   a Sophia EXECUTA uma ação por Input simulado, a partir do 1º quadro:
##              idle | walk | light | heavy | dodge | magic | jump | combo | demo
##   solo       some com os inimigos (Sophia sozinha — filmar a animação dela)
##   freeze     congela os inimigos (ficam parados na tela)
##   hold       não usa o "anda até a próxima zona" durante a sequência
##   O primeiro quadro sai no frame [frames]; total = frames + N*K.
##   Também grava <saida>_meta.json (por quadro: posição da Sophia e dos chefes
##   EM PIXELS DA IMAGEM, estado/golpe da Sophia, estado/fase dos chefes, fps) —
##   o tools/seq_to_media.py usa isso pra recortar acompanhando o personagem.
##   RECOMENDADO: passar `--fixed-fps 60` ao Godot (antes do `--`) pra que o
##   tempo de jogo entre quadros seja fixo mesmo que salvar o PNG seja lento.
## Ex.: godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 --position 4000,4000 \
##        res://tools/Shot.tscn -- 3 C:/caps/sophia.png 60 seq=90 every=2 act=demo solo

const ACTS := ["idle", "walk", "light", "heavy", "dodge", "magic", "jump", "combo", "demo"]


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)   # ferramenta NUNCA toca som (pedido do dono)
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
	# Do 4º argumento em diante: modos (palavra solta) e opções chave=valor.
	for i in range(3, args.size()):
		var a: String = args[i]
		var kv := a.split("=", true, 1)
		var key: String = kv[0]
		var val: String = kv[1] if kv.size() > 1 else ""
		match key:
			"hurt": w.hurt = true
			"kill": w.kill = true
			"clear": w.clear = true
			"die": w.die = true
			"dialog": w.keep_dialog = true
			"wave": w.wave = true
			"seq": w.seq_count = maxi(0, int(val))
			"every": w.seq_every = maxi(1, int(val))
			"act":
				if val in ACTS:
					w.act = val
				else:
					push_warning("SHOT: ação desconhecida '%s' (use %s)" % [val, ", ".join(ACTS)])
			"solo": w.solo = true
			"freeze": w.freeze = true
			"hold": w.hold = true
			_: push_warning("SHOT: argumento ignorado '%s'" % a)
	get_tree().root.add_child.call_deferred(w)


class ShotWorker extends Node:
	var screen: int = 1
	var scene_path: String = ""
	var out: String = "user://shot.png"
	var frames: int = 90
	var hurt: bool = false
	var kill: bool = false          # na metade: mata os inimigos comuns com golpe pesado (vê desmembramento)
	var keep_dialog: bool = false   # não pula diálogos (pra fotografar a caixa)
	var clear: bool = false         # a cada terço: mata TUDO e anda até a próxima zona/portal (fluxo da travessia)
	var die: bool = false           # na metade: MATA A SOPHIA (testa checkpoint/renascimento)
	var wave: bool = false          # na metade: mata a wave viva uma vez (vê a próxima)
	# --- modo sequência ---
	var seq_count: int = 0          # 0 = foto única (comportamento antigo)
	var seq_every: int = 2
	var act: String = ""            # roteiro de Input simulado da Sophia
	var solo: bool = false          # esconde/desliga os inimigos
	var freeze: bool = false        # congela os inimigos
	var hold: bool = false          # sem _walk_ahead durante a sequência
	var _seq_saved: int = 0
	var _meta: Array = []
	var _act_t: int = -1            # frame do roteiro (-1 = ainda não começou)
	var _held: Dictionary = {}      # ação -> frames restantes até soltar
	var _pending: Array = []        # [id da tarefa, Image] das gravações em andamento
	var _hurt_done: bool = false
	var _count: int = 0
	var _deadline: int = 1200
	var _since_kill: int = 0        # frames desde a última matança (clear)

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false   # ferramenta não suja o save real
		if seq_count > 0:
			_deadline = frames + seq_count * seq_every + 1200
		if scene_path != "":
			get_tree().change_scene_to_file.call_deferred(scene_path)
			return
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")      # ferramenta pula o prólogo em cards
		Gnosis.persist_enabled = false   # e não grava Crônicas no disco
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
				if keep_dialog:
					had_dialog = true
					break
				if c.choices.size() > 0:
					c._on_choice(0)     # escolha padrão (ex.: "Recusar")
				else:
					c._finish()
				had_dialog = true
		if had_dialog and not keep_dialog:
			return                      # conta frames só sem diálogo na tela
		_count += 1
		if solo or freeze:
			_tame_enemies()
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
		var in_seq := seq_count > 0 and _count >= frames
		# Com roteiro de ação ou "hold", a Sophia não é teleportada durante a filmagem.
		if not (in_seq and (hold or act != "" or solo)):
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
		if seq_count > 0:
			_process_seq()
			return
		if _count >= frames or _deadline <= 0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(out)
			print("SHOT salvo: ", out, " ", img.get_width(), "x", img.get_height())
			_print_diag()
			get_tree().quit()


	# --- MODO SEQUÊNCIA ---------------------------------------------------

	## Roda o roteiro de Input e salva um quadro a cada `seq_every` frames.
	func _process_seq() -> void:
		if _count >= frames:
			if _act_t < 0:
				_act_t = 0
				print("SHOT seq: começando %d quadros a cada %d frames (ação=%s)" % [seq_count, seq_every, act if act != "" else "-"])
			_run_act(_act_t)
			_act_t += 1
			var rel := _count - frames
			if rel % seq_every == 0 and _seq_saved < seq_count:
				var img := get_viewport().get_texture().get_image()
				var path := _frame_path(_seq_saved)
				# Salvar PNG é lento (~0,3 s): vai pra uma thread e o jogo segue.
				# (o Callable não segura o Image vivo — guardamos a referência junto)
				_pending.append([WorkerThreadPool.add_task(img.save_png.bind(path)), img])
				_reap_saves(false)
				_meta.append(_frame_meta(_seq_saved, img.get_width()))
				_seq_saved += 1
		if _seq_saved >= seq_count or _deadline <= 0:
			_release_all()
			_reap_saves(true)
			_write_meta()
			print("SHOT seq salva: %d quadros em %s_###.png" % [_seq_saved, _prefix()])
			_print_diag()
			get_tree().quit()

	## Libera as gravações concluídas (ou espera todas, no fim).
	func _reap_saves(wait_all: bool) -> void:
		var vivos: Array = []
		for job in _pending:
			if wait_all or WorkerThreadPool.is_task_completed(job[0]):
				WorkerThreadPool.wait_for_task_completion(job[0])
			else:
				vivos.append(job)
		_pending = vivos

	func _prefix() -> String:
		var lower := out.to_lower()
		if lower.ends_with(".png"):
			return out.substr(0, out.length() - 4)
		return out

	func _frame_path(i: int) -> String:
		return "%s_%03d.png" % [_prefix(), i]

	## Dados do quadro: onde estão a Sophia e os chefes NA IMAGEM salva.
	func _frame_meta(i: int, img_w: int) -> Dictionary:
		var vis := get_viewport().get_visible_rect().size
		var k: float = float(img_w) / maxf(1.0, vis.x)
		var d := {"i": i, "frame": _count, "act_t": _act_t, "fps": Engine.get_frames_per_second()}
		var pl := get_tree().get_first_node_in_group("player")
		if pl is Node2D:
			var p: Vector2 = (pl as Node2D).get_global_transform_with_canvas().origin * k
			d["player"] = [roundi(p.x), roundi(p.y)]
			if pl is Player:
				d["state"] = Player.State.keys()[pl.state]
				d["move"] = pl.current_move.id if pl.current_move != null else ""
		var bosses: Array = []
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.is_boss_enemy and e.visible:
				var b: Vector2 = (e as Node2D).get_global_transform_with_canvas().origin * k
				bosses.append({"pos": [roundi(b.x), roundi(b.y)], "estate": Enemy.EState.keys()[e.estate], "phase": e.phase})
		d["bosses"] = bosses
		return d

	func _write_meta() -> void:
		var f := FileAccess.open(_prefix() + "_meta.json", FileAccess.WRITE)
		if f == null:
			push_warning("SHOT: não consegui gravar o meta.json")
			return
		var vis := get_viewport().get_visible_rect().size
		f.store_string(JSON.stringify({
			"target": scene_path if scene_path != "" else str(screen),
			"start_frame": frames, "every": seq_every, "count": _seq_saved,
			"act": act, "solo": solo, "freeze": freeze,
			"viewport": [vis.x, vis.y],
			"physics_fps": Engine.physics_ticks_per_second,
			"frames": _meta,
		}, "\t"))
		f.close()

	## Inimigos fora do caminho: "solo" esconde e desliga; "freeze" só congela.
	func _tame_enemies() -> void:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not e is Node2D:
				continue
			if e.process_mode != Node.PROCESS_MODE_DISABLED:
				e.process_mode = Node.PROCESS_MODE_DISABLED
			if solo and e.visible:
				e.visible = false

	# --- ROTEIROS DE AÇÃO (Input simulado, igual a um jogador) -----------
	# t = frames desde o 1º quadro. "tap" = aperta e solta 3 frames depois.

	func _run_act(t: int) -> void:
		_tick_held()
		match act:
			"walk":
				# 1º terço: direita · 2º: parada · 3º: esquerda (vê partida, freio e virada).
				var third := maxi(1, seq_count * seq_every / 3)
				if t == 0:
					_press("move_right")
				elif t == third:
					Input.action_release("move_right")
				elif t == third * 2:
					_press("move_left")
			"light":
				# Corrente de golpes leves (combo inteiro), toques a cada 14 frames.
				if t % 14 == 2 and t < 100:
					_tap("attack_light")
			"heavy":
				if t == 2 or t == 70:
					_tap("attack_heavy")
			"dodge":
				if t == 0:
					_press("move_right")
				if t == 8 or t == 50:
					_tap("dodge")
				if t == 90:
					Input.action_release("move_right")
			"magic":
				if t == 2:
					_tap("skill2")      # Esfera Solar (inata)
				if t == 80:
					_tap("skill1")      # Anel equipado
			"jump":
				if t == 2 or t == 60:
					_tap("jump")
				if t == 20:
					_tap("attack_light")   # golpe aéreo
			"combo":
				# leve, leve, pesado (lançador/variação) e um aéreo.
				for tt in [2, 16, 30]:
					if t == tt:
						_tap("attack_light")
				if t == 46:
					_tap("attack_heavy")
				if t == 80:
					_tap("jump")
				if t == 92:
					_tap("attack_light")
			"demo":
				# Tudo em ~5 s (seq=150 every=2): anda, para, leve x3, pesado, esquiva, magia, pulo.
				if t == 0:
					_press("move_right")
				elif t == 40:
					Input.action_release("move_right")
				for tt in [55, 69, 83]:
					if t == tt:
						_tap("attack_light")
				if t == 140:
					_tap("attack_heavy")   # espera a recuperação do 3º leve
				if t == 195:
					_press("move_left", 20)
					_tap("dodge")
				if t == 235:
					_tap("skill2")
				if t == 280:
					_tap("jump")

	func _press(a: String, frames_held: int = -1) -> void:
		Input.action_press(a)
		if frames_held > 0:
			_held[a] = frames_held

	func _tap(a: String) -> void:
		_press(a, 3)

	func _tick_held() -> void:
		for a in _held.keys():
			_held[a] -= 1
			if _held[a] <= 0:
				Input.action_release(a)
				_held.erase(a)

	func _release_all() -> void:
		for a in ["move_left", "move_right", "move_up", "move_down", "attack_light", "attack_heavy", "dodge", "jump", "skill1", "skill2", "block"]:
			if InputMap.has_action(a):
				Input.action_release(a)
		_held.clear()


	## Diagnóstico da travessia: onde a Sophia está e em que zona a tela ficou.
	func _print_diag() -> void:
		var lvd := get_tree().current_scene
		var pld := get_tree().get_first_node_in_group("player")
		if lvd is Level and pld != null:
			var vivos := 0
			for e in get_tree().get_nodes_in_group("enemy"):
				if e is Enemy and e.estate != Enemy.EState.DEAD:
					vivos += 1
			print("SHOT tela=%d zona=%d/%d wave=%d/%d ativa=%s vivos=%d player=(%.0f,%.0f) fps=%.0f" % [lvd.screen, lvd.zone_index, lvd.zones.size(), lvd.wave_index, lvd.waves.size(), str(lvd.zone_active), vivos, pld.global_position.x, pld.global_position.y, Engine.get_frames_per_second()])


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
				# Testa a fenda DE VERDADE: solta a Sophia 100 px antes e ANDA até ela.
				if lv.player.global_position.distance_to(c.global_position) > 130.0:
					lv.player.global_position = c.global_position + Vector2(-100, -20)
				Input.action_press("move_right")
				return
		var next: int = lv.zone_index + 1
		if next < lv.zones.size():
			lv.player.global_position = Vector2(lv.zone_center(next) - Level.ZONE_TRIGGER + 8.0, 250.0)
