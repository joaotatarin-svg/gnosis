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


## Opção "Números de dano" (GameManager.settings["damage_numbers"], padrão
## ligado). `force` = ignora a opção (só o pré-aquecimento de VFX usa).
static func spawn(parent: Node, pos: Vector2, amount: int, col: Color, force: bool = false) -> void:
	if not force and not enabled():
		return
	var n := DamageNumber.new()
	n.value = amount
	n.color = col
	n.keep_in_pause = force
	parent.add_child(n)
	n.global_position = pos + Vector2(randf_range(-6, 6), -26)
	n.z_index = 50


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
	# sombra + número
	draw_string(font, Vector2(-w * 0.5 + 1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * fade))
	draw_string(font, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color.r, color.g, color.b, fade))
