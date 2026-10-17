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
## Lugar (QA-UX M1): na BASE da tela, abaixo da linha do chão (pés em y≈242 e
## telegrafos de chão até ≈265 na base 640×360) — faixa termina em y 354; com a
## barra do chefe no ar a faixa sobe e termina logo acima dela (hud.boss_area_top()).
## Some (QA-UX A2/L4/M4): árvore pausada ou PauseStack segurando (pausa, loja,
## opções, golpes, diálogo, card de chefe), Sophia morta (a fila é descartada) e
## fora de uma tela do run.
## Luta de chefe (backlog #21): legenda de CHEGADA não fala por cima do chefe.
## Na 1ª vez que uma barra de chefe/Campeão aparece na tela, a fala no ar sai e
## a fila enfileirada ANTES (chegada da tela) é descartada; o que nasce DURANTE a
## luta (fase 2 dos Arcontes, 7º Anel, lembranças dos ecos) passa normalmente.
## Velocidade do texto segue as Opções (DialogueBox.text_speed()).

const SPEAKER_COLOR := Color("ecd498")
const MIN_TIME := 3.0
const MAX_TIME := 5.2
const CPS := 55.0
const BOTTOM_Y := 354.0           # base da faixa sem chefe (base 640×360)
const BOSS_GAP := 4.0             # folga acima do nome do chefe
const MIN_TOP_Y := 250.0          # nunca sobe além disto (pés em ≈242)

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
var _bottom: float = BOTTOM_Y     # base atual da faixa (desliza quando o chefe entra)
var _height: float = 56.0
var _fight_armed: bool = true     # a próxima luta de chefe da tela ainda corta a chegada
var _in_fight: bool = false


func _ready() -> void:
	layer = 60                     # acima do HUD (1), abaixo do DialogueBox (90)
	process_mode = Node.PROCESS_MODE_ALWAYS   # só pra se ESCONDER na pausa
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Faixa na base da tela, abaixo dos pés (ver _layout).
	_root.position = Vector2(640.0 * 0.12, BOTTOM_Y - _height)
	_root.size = Vector2(640.0 * 0.76, _height)
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
	_fight_armed = true
	_in_fight = false
	_queue.clear()
	_time_left = 0.0
	_gap = 0.0
	if _showing:
		_hide()


func _process(delta: float) -> void:
	# Pausa / diálogo / loja / card: some e congela (a fala não "queima" escondida).
	var paused := get_tree().paused or PauseStack.is_held()
	_root.visible = not paused
	if paused:
		return
	# Fora de uma tela do run (menu, Crônicas, fim), nada fica pendurado.
	if not (get_tree().current_scene is Level):
		if _showing or not _queue.is_empty():
			clear()
		return
	# Sophia caída: ninguém "fala" com ela morta (L4); a fila não volta depois.
	if _player_dead():
		if _showing or not _queue.is_empty():
			clear()
			_kill_tween()
			_root.modulate.a = 0.0     # sem fade: a morte vem com câmera lenta
		return
	_check_fight()
	_layout(delta)
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
	var sp := DialogueBox.text_speed()
	_shown = INF if is_inf(sp) else _shown + delta * CPS * sp
	var now := total if is_inf(_shown) else mini(int(_shown), total)
	var txt := _text.text
	for i in range(before, now):
		if is_inf(_shown):
			break                  # instantâneo: sem rajada de blips
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
	_height = 20.0 + ceilf(float(fs) * 1.15) * 2.0
	_layout(-1.0)
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


## Posição da faixa: base em BOTTOM_Y, ou logo acima da barra do chefe.
## `delta < 0` = sem animação (encaixa na hora).
func _layout(delta: float) -> void:
	var target := BOTTOM_Y
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("boss_area_top"):
		var top: float = hud.call("boss_area_top")
		if top < BOTTOM_Y:
			target = top - BOSS_GAP
	target = maxf(target, MIN_TOP_Y + _height)
	_bottom = target if delta < 0.0 else move_toward(_bottom, target, delta * 160.0)
	_root.position = Vector2(640.0 * 0.12, _bottom - _height)
	_root.size = Vector2(640.0 * 0.76, _height)


## Começou a luta de chefe (1ª barra viva na tela)? Corta a chegada (#21).
func _check_fight() -> void:
	var fight := false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("boss_bars"):
		fight = not (hud.call("boss_bars") as Array).is_empty()
	if fight and not _in_fight and _fight_armed:
		_fight_armed = false
		_queue.clear()
		if _showing:
			_hide()
	_in_fight = fight


## Há luta de chefe com barra viva agora? (QA/sonda)
func in_boss_fight() -> bool:
	return _in_fight


func _player_dead() -> bool:
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null or not ("health" in pl) or pl.get("health") == null:
		return false
	return int(pl.health.current_health) <= 0


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
