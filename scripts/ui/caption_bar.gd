extends CanvasLayer
class_name CaptionBar
## Legendas de caminhada: falas curtas (1–2 linhas, 3–5 s) que aparecem na base
## da tela SEM pausar o jogo — a Voz comenta, a Sophia responde a si mesma.
## Fila: uma fala por vez, com fade; `clear()` ao trocar de tela. Vive como
## filho do autoload `Gnosis` (persiste entre cenas) e é PAUSÁVEL: durante um
## DialogueBox o relógio dela congela em vez de queimar a fala escondida.

const SPEAKER_COLOR := Color(1.0, 0.9, 0.55)
const MIN_TIME := 3.0
const MAX_TIME := 5.2

var _queue: Array = []            # [{speaker, text}]
var _time_left: float = 0.0       # tempo da fala atual
var _gap: float = 0.0             # respiro entre falas
var _showing: bool = false
var _root: Control
var _strip: ColorRect
var _speaker: Label
var _text: Label
var _tween: Tween


func _ready() -> void:
	layer = 60                     # acima do HUD (1), abaixo do DialogueBox (90)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Faixa na base da tela, acima da barra do chefe (que ocupa y 312–344 na
	# resolução base 640×360).
	_root.anchor_left = 0.10
	_root.anchor_right = 0.90
	_root.anchor_top = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_top = -100.0
	_root.offset_bottom = -56.0
	_root.modulate.a = 0.0
	add_child(_root)

	_strip = ColorRect.new()
	_strip.color = Color(0.02, 0.045, 0.06, 0.62)
	_strip.anchors_preset = Control.PRESET_FULL_RECT
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_strip)

	_speaker = Label.new()
	_speaker.anchors_preset = Control.PRESET_TOP_WIDE
	_speaker.offset_top = 3.0
	_speaker.offset_bottom = 15.0
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.add_theme_font_size_override("font_size", 9)
	_speaker.add_theme_color_override("font_color", SPEAKER_COLOR)
	_speaker.add_theme_font_override("font", CodexStyle.serif())
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_speaker)

	_text = Label.new()
	_text.anchors_preset = Control.PRESET_FULL_RECT
	_text.offset_left = 10.0
	_text.offset_right = -10.0
	_text.offset_top = 15.0
	_text.offset_bottom = -3.0
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 11)
	_text.add_theme_color_override("font_color", CodexStyle.PAPER)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_text.add_theme_constant_override("outline_size", 3)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_text)


## Enfileira uma fala. `lines` = Array de {speaker, text} (formato do Narrative).
func say_lines(lines: Array) -> void:
	for l in lines:
		if l is Dictionary and String(l.get("text", "")) != "":
			_queue.append(l)


func say(speaker: String, text: String) -> void:
	_queue.append({"speaker": speaker, "text": text})


## Esvazia tudo (troca de tela, morte).
func clear() -> void:
	_queue.clear()
	_time_left = 0.0
	_gap = 0.0
	if _showing:
		_hide()


func _process(delta: float) -> void:
	if _showing:
		_time_left -= delta
		if _time_left <= 0.0:
			_hide()
		return
	if _gap > 0.0:
		_gap -= delta
		return
	if _queue.is_empty():
		return
	# Não fala por cima de um diálogo/cinemática (a árvore está pausada —
	# este nó é pausável, então nem chega aqui; fica como salvaguarda).
	if get_tree().paused:
		return
	_show(_queue.pop_front())


func _show(l: Dictionary) -> void:
	_showing = true
	var text := String(l.get("text", ""))
	_speaker.text = String(l.get("speaker", "")).to_upper()
	_text.text = text
	_time_left = clampf(MIN_TIME + float(text.length()) * 0.03, MIN_TIME, MAX_TIME)
	Audio.play_sfx("caption")
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, 0.25)


func _hide() -> void:
	_showing = false
	_gap = 0.9
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, 0.35)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
