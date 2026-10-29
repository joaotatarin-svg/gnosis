extends Node2D
class_name DamageNumber
## Número de dano flutuante: sobe, dá uma tremidinha e some.
## C1 (QA visual): com o mundo PAUSADO (caixa de diálogo / cena encenada / card
## de chefe / pausa) o número não fica congelado na tela: some na hora. O
## estado usado é o que já existe — `get_tree().paused` (o DialogueBox pausa
## pela PauseStack) — e `clear_all()` fica para quem quiser limpar antes.

var value: int = 0
var color: Color = Color(1.0, 0.92, 0.6)
var _time: float = 0.0
var keep_in_pause: bool = false   # só o pré-aquecimento (desenha com a árvore pausada)

const LIFE := 0.7
## R16 (NEURO_SATISFACAO): acertos no MESMO alvo em até 0,3 s somam no número que
## já está na tela (ele cresce e dá "pop"), no máximo 6 números vivos, entrada
## 1,35 → 1,0 em 80 ms (ease-out-back, relógio real: o hitstop não estica o pop).
const MERGE_WINDOW := 0.3         # s de jogo desde o último acerto somado
const MERGE_DIST := 36.0          # px do ponto do acerto (o alvo recua no golpe)
const MAX_ALIVE := 6
const POP_MS := 80.0
const POP_FROM := 1.35

var _anchor: Vector2 = Vector2.ZERO   # onde o 1º acerto nasceu (global)
var _since_hit: float = 0.0           # s desde o último acerto somado
var _pop_ms: int = 0                  # Time.get_ticks_msec() do último pop
var _hits: int = 1


## Opção "Números de dano" (GameManager.settings["damage_numbers"], padrão
## ligado). `force` = ignora a opção (só o pré-aquecimento de VFX usa).
static func spawn(parent: Node, pos: Vector2, amount: int, col: Color, force: bool = false) -> void:
	if not force and not enabled():
		return
	if not force and parent != null and parent.is_inside_tree():
		var alive: Array = parent.get_tree().get_nodes_in_group("damage_number")
		# soma no número do mesmo alvo (mesma cor, perto, acerto recente)
		for o in alive:
			var d := o as DamageNumber
			if d != null and not d.is_queued_for_deletion() and not d.keep_in_pause 					and d.color == col and d._since_hit <= MERGE_WINDOW and d._anchor.distance_to(pos) <= MERGE_DIST:
				d._add(amount)
				return
		# teto: some o mais velho
		var live := alive.filter(func(o): return o is DamageNumber and not o.is_queued_for_deletion())
		if live.size() >= MAX_ALIVE:
			var oldest: DamageNumber = live[0]
			for o in live:
				if (o as DamageNumber)._time > oldest._time:
					oldest = o
			oldest.queue_free()
	var n := DamageNumber.new()
	n.value = amount
	n.color = col
	n.keep_in_pause = force
	parent.add_child(n)
	n.global_position = pos + Vector2(randf_range(-6, 6), -26)
	n._anchor = pos
	n._pop_ms = Time.get_ticks_msec()
	n.z_index = 50


## Mais um acerto no mesmo alvo: soma, pop de novo e a vida recomeça (sobe menos).
func _add(amount: int) -> void:
	value += amount
	_hits += 1
	_since_hit = 0.0
	_time = minf(_time, LIFE * 0.25)
	_pop_ms = Time.get_ticks_msec()


## A opção está ligada? Valor ausente ou de tipo errado = ligado.
static func enabled() -> bool:
	var v = GameManager.settings.get("damage_numbers", true)
	return not (typeof(v) == TYPE_BOOL and v == false)


## Apaga todos os números vivos (cena encenada começando, troca de tela...).
static func clear_all() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("damage_number"):
		n.queue_free()


func _ready() -> void:
	add_to_group("damage_number")
	# roda mesmo pausado — só para perceber a pausa e sumir (C1)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not keep_in_pause and get_tree().paused:
		visible = false
		queue_free()
		return
	_time += delta
	_since_hit += delta
	position.y -= 34.0 * delta * (1.0 - _time / LIFE)
	queue_redraw()
	if _time >= LIFE:
		queue_free()


func _draw() -> void:
	var t := _time / LIFE
	var fade := 1.0 if t < 0.6 else (1.0 - t) / 0.4
	var font := ThemeDB.fallback_font
	var size := 11 if value < 25 else (13 if value < 45 else 16)
	var txt := str(value)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	# pop de entrada / de soma (relógio real)
	var k := clampf(float(Time.get_ticks_msec() - _pop_ms) / POP_MS, 0.0, 1.0)
	var c1 := 1.70158
	var back := 1.0 + (c1 + 1.0) * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)   # ease-out-back 0→1
	var sc := lerpf(POP_FROM if _hits == 1 else 1.22, 1.0, back)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	# sombra + número
	draw_string(font, Vector2(-w * 0.5 + 1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * fade))
	draw_string(font, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.r, color.g, color.b, fade))
