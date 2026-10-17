extends Node
## FERRAMENTA (loja/Steam — não faz parte do jogo): igual ao tools/Shot.tscn
## (aceita TODOS os argumentos dele: modos, seq=, every=, act=, solo...), mas
## esconde as legendas (CaptionBar) e o contador de FPS — capturas limpas para
## a página da loja. Opções próprias (palavras soltas depois do `--`):
##   nohud   também esconde o HUD
##   drive   "piloto": a Sophia anda até o chefe (ou o inimigo mais perto) e
##           luta de perto — golpes leves, pesado e magia — para a foto
##           mostrar combate de verdade, e não a Sophia na borda da tela
##   god     a Sophia não morre durante a captura (cura a cada quadro)
## Uso: godot --path . --audio-driver Dummy --fixed-fps 60 --resolution 1920x1080 \
##        res://tools/store/StoreShot.tscn -- <tela> <saida.png> [frames] [opções do Shot] [nohud] [drive] [god]

const GAP := 70.0           # distância (px do mundo) que a Sophia mantém do alvo
const GAP_BOSS := 105.0     # chefes são largos: fica na borda do manto, visível

var _nohud: bool = false
var _drive: bool = false
var _god: bool = false
var _t: int = 0
var _held: Dictionary = {}  # ação -> frames restantes


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	_nohud = args.has("nohud")
	_drive = args.has("drive")
	_god = args.has("god")
	# O Shot.tscn lê os argumentos e cria o ShotWorker na raiz.
	var shot = load("res://tools/Shot.tscn").instantiate()
	add_child(shot)
	# Sobe para a raiz para sobreviver à troca de cena.
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)


func _process(_delta: float) -> void:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c is CaptionBar or (_nohud and c.is_in_group("hud")):
			c.visible = false
	if get_tree().paused:
		return
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null or not pl is Node2D:
		return
	if _god and "health" in pl and pl.health != null:
		pl.health.heal(9999)
	if _drive:
		_drive_step(pl as Node2D)


## Piloto simples: aproxima, alinha na profundidade e golpeia.
func _drive_step(pl: Node2D) -> void:
	_t += 1
	_tick_held()
	var target: Enemy = _pick_target(pl)
	if target == null:
		_release(["move_left", "move_right", "move_up", "move_down"])
		return
	var dx: float = target.global_position.x - pl.global_position.x
	var dy: float = target.global_position.y - pl.global_position.y
	var gap: float = GAP_BOSS if target.is_boss_enemy else GAP
	# horizontal: chega a GAP do alvo
	if absf(dx) > gap + 14.0:
		_hold("move_right" if dx > 0.0 else "move_left", "move_left" if dx > 0.0 else "move_right")
	elif absf(dx) < gap - 30.0:
		# perto demais: recua um passo (fica de frente porque golpeia depois)
		_hold("move_left" if dx > 0.0 else "move_right", "move_right" if dx > 0.0 else "move_left")
	else:
		_release(["move_left", "move_right"])
		# vira para o alvo
		if "facing" in pl and int(pl.get("facing")) * signf(dx) < 0.0:
			_tap("move_right" if dx > 0.0 else "move_left")
	# profundidade (2.5D)
	if absf(dy) > 8.0:
		_hold("move_down" if dy > 0.0 else "move_up", "move_up" if dy > 0.0 else "move_down")
	else:
		_release(["move_up", "move_down"])
	# golpes quando está no alcance
	if absf(dx) < gap + 40.0:
		var c: int = _t % 240
		if c in [10, 24, 38]:
			_tap("attack_light")
		elif c == 70:
			_tap("attack_heavy")
		elif c == 130:
			_tap("skill2")         # Esfera Solar (inata)
		elif c == 190:
			_tap("skill1")         # Anel equipado


func _pick_target(pl: Node2D) -> Enemy:
	var best: Enemy = null
	var best_d: float = INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e is Enemy or not e.visible or e.estate == Enemy.EState.DEAD:
			continue
		var d: float = (e as Node2D).global_position.distance_to(pl.global_position)
		if e.is_boss_enemy:
			d -= 10000.0         # chefe primeiro
		if d < best_d:
			best_d = d
			best = e
	return best


func _hold(a: String, opposite: String) -> void:
	if InputMap.has_action(opposite):
		Input.action_release(opposite)
	if InputMap.has_action(a):
		Input.action_press(a)


func _release(acts: Array) -> void:
	for a in acts:
		if InputMap.has_action(a):
			Input.action_release(a)


func _tap(a: String) -> void:
	if InputMap.has_action(a):
		Input.action_press(a)
		_held[a] = 3


func _tick_held() -> void:
	for a in _held.keys():
		_held[a] -= 1
		if _held[a] <= 0:
			Input.action_release(a)
			_held.erase(a)
