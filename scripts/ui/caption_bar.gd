extends CanvasLayer
class_name CaptionBar
## Legendas de caminhada: falas curtas (1–2 linhas, 3–5 s) que aparecem na base
## da tela SEM pausar o jogo — a Voz comenta, a Sophia responde a si mesma.
## Fila: uma fala por vez, com fade; `clear()` ao trocar de tela. Vive como
## filho do autoload `Gnosis` (persiste entre cenas). Durante um DialogueBox
## ou a pausa (árvore pausada) a legenda SOME e o relógio dela congela.
## Visual: faixa que se dissolve nas pontas, filetes dourados, nome do falante
## em versalete, retrato pequeno quando houver; o texto entra em máquina de
## escrever com o "blip" de voz do falante (mesmos sons do DialogueBox).
## O tamanho do texto segue as Opções (Legendas P/M/G).

const SPEAKER_COLOR := Color("ecd498")
const MIN_TIME := 3.0
const MAX_TIME := 5.2
const CPS := 55.0

var _queue: Array = []            # [{speaker, text}]
var _time_left: float = 0.0       # tempo da fala atual
var _gap: float = 0.0             # respiro entre falas
var _showing: bool = false
var _root: Control
var _strip: _Strip
var _speaker: Label
var _text: Label
var _tween: Tween
var _shown: float = 0.0
var _typing: bool = false
var _blip: String = "blip_npc"
var _blips: int = 0


func _ready() -> void:
	layer = 60                     # acima do HUD (1), abaixo do DialogueBox (90)
	process_mode = Node.PROCESS_MODE_ALWAYS   # só pra se ESCONDER na pausa
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Faixa na base da tela, acima da barra do chefe (y 318–352 na base 640×360).
	_root.anchor_left = 0.12
	_root.anchor_right = 0.88
	_root.anchor_top = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_top = -104.0
	_root.offset_bottom = -50.0
	_root.modulate.a = 0.0
	add_child(_root)

	_strip = _Strip.new()
	_strip.bar = self
	_strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_strip)

	_speaker = Label.new()
	_speaker.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_speaker.offset_top = 4.0
	_speaker.offset_bottom = 16.0
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.add_theme_font_size_override("font_size", 8)
	_speaker.add_theme_color_override("font_color", SPEAKER_COLOR)
	_speaker.add_theme_font_override("font", CodexStyle.display())
	_speaker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_speaker.add_theme_constant_override("outline_size", 3)
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_speaker)

	_text = Label.new()
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 34.0
	_text.offset_right = -34.0
	_text.offset_top = 17.0
	_text.offset_bottom = -3.0
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", CodexStyle.body())
	_text.add_theme_color_override("font_color", CodexStyle.PAPER)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_text.add_theme_constant_override("outline_size", 4)
	_text.add_theme_constant_override("line_spacing", -1)
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
	# Pausa / diálogo: some e congela (a fala não "queima" escondida).
	var paused := get_tree().paused
	_root.visible = not paused
	if paused:
		return
	# Fora de uma tela do run (menu, Crônicas, fim), nada fica pendurado.
	if not (get_tree().current_scene is Level):
		if _showing or not _queue.is_empty():
			clear()
		return
	if _showing:
		_type(delta)
		_time_left -= delta
		if _time_left <= 0.0:
			_hide()
		return
	if _gap > 0.0:
		_gap -= delta
		return
	if _queue.is_empty():
		return
	_show(_queue.pop_front())


func _type(delta: float) -> void:
	if not _typing:
		return
	var total := _text.get_total_character_count()
	var before := int(_shown)
	_shown += delta * CPS
	var now := mini(int(_shown), total)
	var txt := _text.text
	for i in range(before, now):
		if i < txt.length() and txt[i] != " ":
			_blips += 1
			if _blips % 2 == 1:
				Audio.play_sfx(_blip, -1.0, -6.0)
	_text.visible_characters = now
	if now >= total:
		_typing = false
		_text.visible_characters = -1


func _show(l: Dictionary) -> void:
	_showing = true
	var text := String(l.get("text", ""))
	var who := String(l.get("speaker", ""))
	_speaker.text = who
	_strip.portrait = DialogueBox.portrait_for(who)
	_blip = DialogueBox.blip_for(who)
	_text.add_theme_font_size_override("font_size", GameManager.caption_font_size() + 1)
	# Legenda grande precisa de mais altura (2 linhas cabem sempre).
	var fs := GameManager.caption_font_size() + 1
	_root.offset_top = -50.0 - (24.0 + fs * 2.6)
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_blips = 0
	_typing = true
	_time_left = clampf(MIN_TIME + float(text.length()) * 0.03, MIN_TIME, MAX_TIME) + float(text.length()) / CPS
	Audio.play_sfx("caption")
	_strip.queue_redraw()
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


## Faixa: azul-noite que se dissolve nas pontas + filetes dourados + retrato.
class _Strip extends Control:
	var bar
	var portrait: Texture2D
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var steps := 16
		for i in steps:
			var a := float(i) / steps
			var b := float(i + 1) / steps
			var ka := sin(a * PI)
			var kb := sin(b * PI)
			var x0 := w * a
			var x1 := w * b
			draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)]),
				PackedColorArray([Color(0.02, 0.045, 0.06, 0.72 * ka), Color(0.02, 0.045, 0.06, 0.72 * kb), Color(0.02, 0.045, 0.06, 0.72 * kb), Color(0.02, 0.045, 0.06, 0.72 * ka)]))
			var g := Color(CodexStyle.GOLD, 0.6)
			draw_line(Vector2(x0, 0), Vector2(x1, 0), Color(g, g.a * ka * ka), 0.6, true)
			draw_line(Vector2(x0, h), Vector2(x1, h), Color(g, g.a * 0.6 * ka * ka), 0.6, true)
		CodexStyle.draw_diamond(self, Vector2(w * 0.5, 0), 2.2, CodexStyle.GOLD_HI)
		if portrait != null:
			var c := Vector2(19.0, h * 0.5 + 2.0)
			var r := 12.0
			draw_circle(c, r + 2.0, CodexStyle.INK_DEEP)
			draw_texture_rect(portrait, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
			draw_arc(c, r + 0.6, 0.0, TAU, 32, CodexStyle.GOLD, 1.0, true)
