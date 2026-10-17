extends Node
## FERRAMENTA (Combate 6 — não faz parte do jogo): o MODO SEQUÊNCIA do Shot
## (`tools/shot.gd`, ShotWorker) com roteiros de Input do combate que o Shot não
## tem: aéreo forte em spam, pulo duplo, andar/parar/virar e botão amassado.
## O ShotWorker cuida da cena, dos diálogos, dos quadros e do _meta.json (o
## `tools/seq_to_media.py --follow player` funciona igual); aqui só apertamos botões.
##
## Uso (sempre com --fixed-fps 60):
##   godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1280x720 --position 1200,600 \
##     res://tools/combate/ActShot.tscn -- <tela> <saida.png> <frames> seq=N every=K roteiro=NOME \
##     [arma=N] [duplo] [solo|freeze]
## Roteiros: aereo | duplo | andar | amassa | combo
##   aereo  = pula e aperta forte 2x por pulo, 4 pulos (o "pulo + triângulo" roubado)
##   duplo  = pulo, 2º pulo no ar, forte; depois pulo + 2º pulo + forte 2x (não pode sair 2 aéreos)
##   andar  = direita, solta, esquerda, solta, toques curtos (arrancada, freio, giro)
##   amassa = leve a cada 5 quadros por 1 s, depois forte a cada 5 quadros (botão amassado)
##   combo  = leve, leve, leve no ritmo; pesado; leve leve forte (o jogador "bom")
## `duplo` (opção) liga o pulo duplo à força (player.debug_double_jump) — senão
## vale a trava da progressão.

const ShotScript = preload("res://tools/shot.gd")


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	# A janela fica no canto do monitor do João: ela NÃO rouba o foco (o teclado
	# dele continua onde estava) e nenhum controle/tecla de verdade entra no
	# roteiro (o DualShock ligado apertava esquiva/defesa no meio da filmagem).
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	Driver.mute_real_input()
	var w = ShotScript.ShotWorker.new()
	var d := Driver.new()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		w.screen = int(args[0])
	if args.size() >= 2:
		w.out = args[1]
	if args.size() >= 3:
		w.frames = int(args[2])
	w.hold = true
	for i in range(3, args.size()):
		var kv := String(args[i]).split("=", true, 1)
		var key: String = kv[0]
		var val: String = kv[1] if kv.size() > 1 else ""
		match key:
			"seq": w.seq_count = maxi(0, int(val))
			"every": w.seq_every = maxi(1, int(val))
			"solo": w.solo = true
			"freeze": w.freeze = true
			"roteiro": d.script_name = val
			"arma": d.weapon_level = clampi(int(val), 1, 5)
			"duplo": d.force_double = true
			_: push_warning("ACTSHOT: argumento ignorado '%s'" % args[i])
	d.worker = w
	get_tree().root.add_child.call_deferred(w)
	get_tree().root.add_child.call_deferred(d)


class Driver extends Node:
	## Tira todas as teclas/botões das ações (só nesta execução, nada é salvo):
	## Input.action_press do roteiro continua valendo.
	static func mute_real_input() -> void:
		for a in InputMap.get_actions():
			if not String(a).begins_with("ui_"):
				InputMap.action_erase_events(a)

	var worker: Node
	var script_name: String = "aereo"
	var weapon_level: int = 3
	var force_double: bool = false
	var _held: Dictionary = {}
	var _setup := false
	var _last_t: int = -1
	var _log_state: String = ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		if worker == null or not is_instance_valid(worker):
			return
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl == null:
			return
		if not _setup:
			_setup = true
			mute_real_input()
			Progression.weapon_level = weapon_level
			if force_double:
				pl.set("debug_double_jump", true)   # sem efeito antes do pulo duplo existir
		var t: int = int(worker.get("_act_t"))
		if t < 0 or t == _last_t:
			return
		_last_t = t
		_tick_held()
		_run(t)
		var s := "%s/%s%s" % [Player.State.keys()[pl.state], pl.current_move.id if pl.current_move != null else "-", "" if pl.is_on_floor() else "(ar)"]
		if s != _log_state:
			_log_state = s
			print("ACTSHOT t=%d %s y=%.0f vx=%.0f" % [t, s, pl.global_position.y, pl.velocity.x])

	func _run(t: int) -> void:
		match script_name:
			"aereo":
				for k in 4:
					var b: int = k * 42
					if t == b + 2:
						_tap("jump")
					if t == b + 12 or t == b + 18:
						_tap("attack_heavy")
			"duplo":
				if t == 2: _tap("jump")
				if t == 24: _tap("jump")          # 2º pulo no ar
				if t == 40: _tap("attack_heavy")
				if t == 100: _tap("jump")
				if t == 112: _tap("attack_heavy")  # aéreo no 1º pulo...
				if t == 150: _tap("jump")          # ...2º pulo depois do mergulho? (só se ainda no ar)
				if t == 156: _tap("attack_heavy")
			"andar":
				if t == 2: _press("move_right", 50)
				if t == 80: _press("move_left", 40)
				if t == 150: _press("move_right", 6)
				if t == 170: _press("move_left", 6)
			"amassa":
				if t < 60 and t % 5 == 2:
					_tap("attack_light")
				if t >= 80 and t < 140 and t % 5 == 2:
					_tap("attack_heavy")
			"combo":
				for tt in [2, 18, 34]:
					if t == tt: _tap("attack_light")
				if t == 80: _tap("attack_heavy")
				for tt in [130, 146]:
					if t == tt: _tap("attack_light")
				if t == 162: _tap("attack_heavy")

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
