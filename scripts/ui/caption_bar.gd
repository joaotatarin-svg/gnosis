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
## Lugar (QA-UX M1, Onda 3): no TOPO, logo abaixo da faixa de dicas do HUD
## (y 66 na base 640×360), centrada e mais estreita que antes (420 px) — com o
## zoom 1,2 da câmera a base da tela é chão de luta (pés, telegrafos de chão,
## barra do chefe) e a legenda ficava nas canelas da Sophia. O topo central é
## céu/arquitetura em todas as telas; a faixa é mais discreta (véu α 0,5) e cresce
## para baixo só o que o texto pedir. O HUD sabe onde ela está
## (hud.set_caption_band) para o toast nascer logo abaixo.
## Some (QA-UX A2/L4/M4): árvore pausada ou PauseStack segurando (pausa, loja,
## opções, golpes, diálogo, card de chefe), Sophia morta (a fila é descartada) e
## fora de uma tela do run.
## Luta de chefe (backlog #21): legenda de CHEGADA não fala por cima do chefe.
## Na 1ª vez que uma barra de chefe/Campeão aparece na tela, a fala no ar sai e
## a fila enfileirada ANTES (chegada da tela) é descartada; o que nasce DURANTE a
## luta (fase 2 dos Arcontes, 7º Anel, lembranças dos ecos) passa normalmente.
## Velocidade do texto segue as Opções (DialogueBox.text_speed()).
## DUBLAGEM (Onda 7 — edição do Áudio por delegação do chefe): cada legenda pede
## `Audio.play_voice(fala, self)`. Com voz: sem blips, o texto anda no ritmo da
## voz e a legenda fica no ar pelo menos a voz + 0,4 s (a próxima da fila só entra
## depois: duas vozes nunca se sobrepõem). Escondida (pausa/caixa) = voz congelada;
## saiu (luta, troca de tela, morte) = voz cortada com fade. Sem voz: como antes.

const SPEAKER_COLOR := Color("ecd498")
const MIN_TIME := 3.0
const MAX_TIME := 5.2
const CPS := 55.0
const TOP_Y := 66.0               # topo da faixa (abaixo das dicas do HUD, y 37–55)
const STRIP_W := 420.0            # largura da faixa (centrada; livre dos Anéis e do combo)
const STRIP_A := 0.5              # véu da faixa (era 0,72 na base: no topo, mais discreta)

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
var _height: float = 48.0
var _fight_armed: bool = true     # a próxima luta de chefe da tela ainda corta a chegada
var _in_fight: bool = false
# CALMA (Onda 6, playtest do João: "a história passa por cima do jogo durante a
# ação"): nenhuma legenda nova começa com combate por perto; a fila espera a
# zona ficar calma por CALM_NEED s. Fala marcada `urgent` (fase de chefe, 7º
# Anel: curtas, da própria luta) passa. Uma fala comum que estava na tela
# quando a luta começou sai e volta para a frente da fila (uma vez).
const CALM_NEED := 1.0
const HOT_RANGE := 380.0           # inimigo vivo a esta distância da Sophia = combate
var _calm_t: float = 0.0
var _hot: bool = false
var _current: Dictionary = {}      # fala na tela (para devolver à fila)
var _shown_t: float = 0.0
var _lines_shown: int = 0
const MIN_FS := 11                # menor corpo aceito ao apertar para 1 linha
const VOICE_TAIL := 0.4           # dublagem: a legenda fica no ar a voz + isto (s)
var _voice_dur: float = 0.0       # duração da voz da legenda atual (0 = blips)
var _cps: float = CPS             # letras/s da legenda atual
var _voice_synced: bool = false   # a voz já começou e o ritmo do texto foi acertado
var _voice_refused: bool = false  # a fala tem voz, mas a guarda de frequência da luta barrou


func _ready() -> void:
	layer = 60                     # acima do HUD (1), abaixo do DialogueBox (90)
	process_mode = Node.PROCESS_MODE_ALWAYS   # só pra se ESCONDER na pausa
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Faixa no topo central (ver _layout).
	_root.position = Vector2(320.0 - STRIP_W * 0.5, TOP_Y)
	_root.size = Vector2(STRIP_W, _height)
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
	_speaker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # i18n: I18n.t em _show
	_root.add_child(_speaker)

	_text = Label.new()
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 24.0
	_text.offset_right = -24.0
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
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED      # i18n: I18n.t em _show
	_root.add_child(_text)


## Enfileira uma fala. `lines` = Array de {speaker, text} (formato do Narrative).
func say_lines(lines: Array) -> void:
	for l in lines:
		if l is Dictionary and String(l.get("text", "")) != "":
			_queue.append(l)


## Fura a fila: as falas entram logo DEPOIS da que está no ar (a da Estela da
## tela 1, que é por proximidade e perderia o momento atrás das outras).
func say_next(lines: Array) -> void:
	var k := 0
	for l in lines:
		if l is Dictionary and String(l.get("text", "")) != "":
			_queue.insert(k, l)
			k += 1


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
	# Também com CENA no ar sem pausa (Cinemática, rubrica/ilustração da Encenação —
	# HUD.scene_active): a legenda espera e aparece depois (QA2 #4).
	var paused := get_tree().paused or PauseStack.is_held() or _scene_on()
	_root.visible = not paused
	_report_band()
	if _voice_dur > 0.0:
		Audio.pause_voice(self, paused)    # legenda escondida = voz congelada
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
	_check_calm(delta)
	_layout(delta)
	if _showing:
		# A luta começou com uma fala comum no ar: ela sai e espera a calma
		# (volta à frente da fila uma vez; se já voltou, fica até o fim).
		if _hot and not bool(_current.get("urgent", false)) and not bool(_current.get("_requeued", false)) \
				and _shown_t < 0.6 * (_shown_t + maxf(_time_left, 0.0)):
			var again := _current.duplicate()
			again["_requeued"] = true
			_queue.push_front(again)
			_hide()
			return
		_voice_step()
		_type(delta)
		_time_left -= delta
		_shown_t += delta
		if _time_left <= 0.0:
			_hide()
		return
	if _gap > 0.0:
		_gap -= delta
		return
	if _queue.is_empty():
		return
	# Com combate por perto, só a fala urgente da luta passa à frente.
	if _calm_t < CALM_NEED:
		for i in _queue.size():
			if bool((_queue[i] as Dictionary).get("urgent", false)):
				_show(_queue.pop_at(i))
				return
		return
	_show(_queue.pop_front())


## Combate por perto? (inimigo vivo e visível a HOT_RANGE px da Sophia, ou luta
## de chefe com barra). `_calm_t` conta o tempo desde que tudo acalmou.
func _check_calm(delta: float) -> void:
	_hot = _in_fight or _enemy_near()
	_calm_t = 0.0 if _hot else _calm_t + delta


func _enemy_near() -> bool:
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Enemy) or not (e as Node2D).is_visible_in_tree():
			continue
		if "estate" in e and int(e.get("estate")) == Enemy.EState.DEAD:
			continue
		if e.process_mode == Node.PROCESS_MODE_DISABLED:
			continue                   # Arconte parado à espera do gatilho (tentação)
		if absf((e as Node2D).global_position.x - pl.global_position.x) < HOT_RANGE:
			return true
	return false


## Há combate por perto agora (a fila de legendas está esperando)? QA/sonda.
func is_holding() -> bool:
	return _calm_t < CALM_NEED and not _queue.is_empty()


## Dublagem, a cada quadro da legenda no ar: a voz que espera a folga da luta
## (golpe avisado, aviso, stinger — Guardião §10/§20) segura o texto; quando ela
## começa, o texto anda no ritmo dela (termina junto, §3); se a luta não deu folga
## e o Audio desistiu da voz, a legenda segue só com texto. Voz soando = a
## legenda não sai antes dela + VOICE_TAIL.
func _voice_step() -> void:
	if _voice_dur <= 0.0:
		return
	if Audio.is_voice_pending(self):
		_time_left = maxf(_time_left, VOICE_TAIL)
		return
	if not _voice_synced:
		_voice_synced = true
		var left: float = Audio.voice_time_left(self)
		if left <= 0.0:
			_voice_dur = 0.0           # desistiu (ou já acabou): texto no ritmo de sempre
			return
		var sp := DialogueBox.text_speed()
		if not is_inf(sp):
			var rest := maxi(1, _text.get_total_character_count() - int(_shown))
			_cps = float(rest) / maxf(0.3, left - 0.15)
		_time_left = maxf(_time_left, left + VOICE_TAIL)
	if Audio.is_voice_playing(self):
		_time_left = maxf(_time_left, VOICE_TAIL)


func _type(delta: float) -> void:
	if not _typing:
		return
	if _voice_dur > 0.0 and not _voice_synced:
		return                     # a voz ainda espera a folga: o texto também
	var total := _text.get_total_character_count()
	var before := int(_shown)
	var sp := DialogueBox.text_speed()
	_shown = INF if is_inf(sp) else _shown + delta * _cps
	var now := total if is_inf(_shown) else mini(int(_shown), total)
	var txt := _text.text
	for i in range(before, now):
		if is_inf(_shown) or _voice_dur > 0.0 or _voice_refused:
			break                  # instantâneo, dublada ou voz barrada na luta: sem blips
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
	_current = l
	_shown_t = 0.0
	# i18n (Onda 4): exibe traduzido; o falante pt segue como chave de retrato/blip.
	var text := I18n.t(String(l.get("text", "")))
	var who := String(l.get("speaker", ""))
	_speaker.text = I18n.t(who)
	_strip.portrait = DialogueBox.portrait_for(who, String(l.get("mood", "")))
	# Com retrato, o texto abre espaço à esquerda (o medalhão fica dentro da faixa).
	_text.offset_left = 62.0 if _strip.portrait != null else 24.0
	_blip = DialogueBox.blip_for(who)
	# Hierarquia do topo (QA2 #10): a legenda usa o tamanho das Opções SEM o +1 de
	# antes (13 px no M — o mesmo corpo da caixa de diálogo, legível em 640×360) e,
	# se o texto passa de 1 linha por pouco, desce 1 px para caber numa linha só.
	var fs := GameManager.caption_font_size()
	var lw := STRIP_W - (62.0 if _strip.portrait != null else 24.0) - 24.0
	var font: Font = CodexStyle.body()
	var nlines := _lines_for(font, text, lw, fs)
	if nlines == 2 and fs - 1 >= MIN_FS and _lines_for(font, text, lw, fs - 1) == 1:
		fs -= 1
		nlines = 1
	_text.add_theme_font_size_override("font_size", fs)
	# Altura pelo texto de verdade (1–3 linhas): a faixa não reserva espaço à toa.
	var line_h := ceilf(float(fs) * 1.15)
	_height = 21.0 + line_h * float(nlines)
	_lines_shown = nlines
	_layout(-1.0)
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_blips = 0
	_typing = true
	_time_left = clampf(MIN_TIME + float(text.length()) * 0.03, MIN_TIME, MAX_TIME) + float(text.length()) / CPS
	Audio.play_sfx("caption")
	# Dublagem: com voz, a legenda dura pelo menos a voz e o texto anda com ela.
	var sp := DialogueBox.text_speed()
	_cps = CPS * (1.0 if is_inf(sp) else sp)
	# combate por perto / fala da luta = voz de LUTA (guarda de frequência, Guardião §9)
	_voice_dur = Audio.play_voice(l, self, _hot or _in_fight or bool(l.get("urgent", false)))
	# fala que TEM voz mas a guarda da luta barrou: só legenda (nem voz, nem blips)
	_voice_refused = _voice_dur <= 0.0 and Audio.voices_enabled() and not Audio.voice_entry(l).is_empty()
	_voice_synced = false
	if _voice_dur > 0.0:
		_time_left = maxf(_time_left, _voice_dur + VOICE_TAIL)
		_voice_step()              # sem espera: já sincroniza o ritmo do texto
	_strip.queue_redraw()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, 0.25)


## Quantas linhas o texto ocupa (1–3) na largura `lw` com a fonte `fs`.
func _lines_for(font: Font, text: String, lw: float, fs: int) -> int:
	var tsz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, lw, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
	return clampi(int(ceilf(tsz.y / maxf(1.0, font.get_height(fs)) - 0.01)), 1, 3)


## Cena no ar (Cinemática na raiz, caixa, Encenação dirigindo)? Pergunta ao HUD.
func _scene_on() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and hud.has_method("scene_active") and bool(hud.call("scene_active"))


## Linhas da fala atual (QA/sonda).
func shown_lines() -> int:
	return _lines_shown


## Posição da faixa: topo central, fixa (o chefe não a empurra mais).
## `delta` fica por compatibilidade (antes animava a subida acima da barra).
func _layout(_delta: float) -> void:
	_root.position = Vector2(320.0 - STRIP_W * 0.5, TOP_Y)
	_root.size = Vector2(STRIP_W, _height)


## Avisa o HUD onde a faixa está agora (base em y, ou -1 = sem legenda na tela),
## para o toast não nascer embaixo dela.
func _report_band() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("set_caption_band"):
		return
	var on := _root.visible and _root.modulate.a > 0.05
	hud.call("set_caption_band", (TOP_Y + _height) if on else -1.0)


## Retângulo da faixa (base 640×360) — QA/sonda.
func band_rect() -> Rect2:
	return Rect2(_root.position, _root.size)


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
	if _voice_dur > 0.0:
		Audio.stop_voice(self)     # saiu da tela: a voz sai junto (fade curto)
		_voice_dur = 0.0
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
		var va: float = STRIP_A
		for i in steps:
			var a := float(i) / steps
			var b := float(i + 1) / steps
			var ka := sin(a * PI)
			var kb := sin(b * PI)
			var x0 := w * a
			var x1 := w * b
			draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)]),
				PackedColorArray([Color(0.02, 0.045, 0.06, va * ka), Color(0.02, 0.045, 0.06, va * kb), Color(0.02, 0.045, 0.06, va * kb), Color(0.02, 0.045, 0.06, va * ka)]))
			var g := Color(CodexStyle.GOLD, 0.45)
			draw_line(Vector2(x0, 0), Vector2(x1, 0), Color(g, g.a * ka * ka), 0.6, true)
		CodexStyle.draw_diamond(self, Vector2(w * 0.5, 0), 2.2, CodexStyle.GOLD_HI)
		if portrait != null:
			var c := Vector2(44.0, h * 0.5 + 1.0)
			var r := 12.0
			draw_circle(c, r + 2.0, CodexStyle.INK_DEEP)
			draw_texture_rect(portrait, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
			draw_arc(c, r + 0.6, 0.0, TAU, 32, CodexStyle.GOLD, 1.0, true)
