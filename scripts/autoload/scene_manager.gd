extends Node
## Troca de cenas com TRANSIÇÃO + helper de overlay. Autoload `SceneManager`.
## Também instala o tema do Códex no motor inteiro (fontes próprias, botões,
## painéis) e toca "ui_move" sempre que o foco de interface muda de lugar.
## Transição: o véu azul-noite desce, uma faísca dourada acende no centro
## enquanto a cena troca, e o véu se abre de novo.

var _fade: ColorRect
var _spark: Control
var _busy: bool = false
var _swapped: bool = false         # a troca desta transição já aconteceu (véu abrindo)
var _target: String = ""           # cena da transição em curso (ainda não trocada)
var _pending: String = ""          # pedido que chegou com o véu abrindo: roda em seguida
var _quiet_until: int = 0          # msec: silêncio do "ui_move" logo após abrir uma tela


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CodexStyle.install_global(get_tree())
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	get_tree().node_added.connect(_on_node_added)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color("0a151c")
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # por código, anchors_preset não aplica
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	_spark = _VeilSpark.new()
	_spark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark.modulate.a = 0.0
	layer.add_child(_spark)


func _exit_tree() -> void:
	CodexStyle.release(get_tree())


## Troca de cena com o véu. REVISAO #12: pedido que chega no meio de uma
## transição NÃO se perde (quem chama, ex. RunManager, já mudou a tela e
## salvou antes): com o véu ainda descendo, o último pedido vira o destino;
## com o véu já abrindo (cena nova no ar), ele fica guardado e roda logo ao fim.
## Ao trocar, a pilha de pausa é zerada — nenhum dono da cena velha segura o
## mundo novo pausado.
func change_scene(path: String) -> void:
	if _busy:
		if _swapped:
			_pending = path
		else:
			_target = path
		return
	_busy = true
	_target = path
	while _target != "":
		_swapped = false
		var t := create_tween().set_parallel(true)
		t.tween_property(_fade, "modulate:a", 1.0, 0.22)
		t.tween_property(_spark, "modulate:a", 1.0, 0.22)
		await t.finished
		PauseStack.clear()
		var err := get_tree().change_scene_to_file(_target)
		if err != OK:
			push_error("SceneManager: não consegui abrir %s (erro %d)." % [_target, err])
		_swapped = true
		_target = ""
		_quiet_until = Time.get_ticks_msec() + 250
		var t2 := create_tween().set_parallel(true)
		t2.tween_property(_spark, "modulate:a", 0.0, 0.18)
		t2.tween_property(_fade, "modulate:a", 0.0, 0.3).set_delay(0.05)
		await t2.finished
		_target = _pending
		_pending = ""
	_swapped = false
	_busy = false


## Há uma transição em curso (véu descendo/abrindo ou pedido na fila)?
func is_busy() -> bool:
	return _busy


## Instancia uma cena por cima da cena atual (ex.: pausa, loja).
func instance_overlay(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Cena não encontrada: " + path)
		return null
	var inst := packed.instantiate()
	_quiet_until = Time.get_ticks_msec() + 200
	get_tree().current_scene.add_child(inst)
	return inst


## Som de mover o foco (todas as telas, teclado/controle/mouse). O primeiro
## foco de uma tela recém-aberta não faz barulho (ela já tocou "ui_open").
func _on_focus_changed(_node: Control) -> void:
	if Time.get_ticks_msec() < _quiet_until:
		return
	Audio.play_sfx("ui_move")


## Uma tela nova (overlay em CanvasLayer) acabou de entrar: silencia o foco inicial.
func _on_node_added(n: Node) -> void:
	if n is CanvasLayer:
		_quiet_until = maxi(_quiet_until, Time.get_ticks_msec() + 120)


## A faísca do véu: losango dourado com halo, pulsando devagar.
class _VeilSpark extends Control:
	var _t: float = 0.0
	func _process(delta: float) -> void:
		if modulate.a <= 0.0:
			return
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var p := 1.0 + 0.12 * sin(_t * 9.0)
		draw_circle(c, 16.0 * p, Color(0.77, 0.65, 0.42, 0.06))
		draw_circle(c, 8.0 * p, Color(0.93, 0.83, 0.6, 0.12))
		CodexStyle.draw_spark(self, c, 6.0 * p)
		var w := 70.0 * p
		draw_line(c + Vector2(-w, 0), c + Vector2(-10, 0), Color(0.77, 0.65, 0.42, 0.35), 0.5, true)
		draw_line(c + Vector2(10, 0), c + Vector2(w, 0), Color(0.77, 0.65, 0.42, 0.35), 0.5, true)
