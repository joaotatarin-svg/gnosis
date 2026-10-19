extends CanvasLayer
class_name Cinematic
## Cinemática leve, toda por código: cards de texto sobre as ILUSTRAÇÕES das
## cinemáticas (`assets/cinematic/cine_NN_*.png`, 1536×1024: prólogo 01–06,
## epílogos 10–12) com Ken Burns lento e legenda no terço inferior — ou sobre a
## pintura do Éon (Crônicas, créditos) — e o CARD DE CHEFE com letterbox. Pausa o mundo enquanto
## toca (process ALWAYS) pela pilha de pausa (PauseStack): ao terminar, larga só
## a SUA pausa — se um diálogo ou a loja ainda seguram o mundo, ele continua parado.
## Uso:  await Cinematic.prologue().finished
##       Cinematic.boss_card("ATHOTH", "Arconte do Torpor")
##       await Cinematic.epilogue("semente", 7, 18).finished
## Qualquer tecla/botão avança o card; Esc (pause) pula tudo.

signal finished

const TEXT_W := 470.0
# Ilustrações das cinemáticas (artes/gpt/cinematic → assets/cinematic). Sem texto;
# o terço inferior é calmo para a legenda. Número = ordem do MANIFESTO.
const ART_DIR := "res://assets/cinematic/"
const ART := {
	1: "cine_01_monada_a.png", 2: "cine_02_eons_a.png", 3: "cine_03_sophia_nuvem_a.png",
	4: "cine_04_cego_a.png", 5: "cine_05_kenoma_a.png", 6: "cine_06_faisca_a.png",
	7: "cine_07_roubo_a.png", 8: "cine_08_descida_a.png", 9: "cine_09_anagnorise_a.png",
	10: "cine_10_ascensao_a.png", 11: "cine_11_ruptura_a.png", 12: "cine_12_semente_a.png",
}
const KB_ZOOM := 0.06              # Ken Burns: zoom 1,00 → 1,06 ao longo da ilustração
const KB_PAN := 0.7                # deriva = 70 % da folga que o zoom abre (nunca mostra borda)
const XFADE := 0.8                 # troca de ilustração dentro do mesmo card (s)
const ART_DIM := Color(0.92, 0.92, 0.94, 1.0)   # a pintura quase cheia (a legenda tem a faixa escura)

var cards: Array = []              # [{title, text, bg | art: [nº...], time}]
var boss: Dictionary = {}          # {name, title} → modo card de chefe
var _idx: int = -1
var _done: bool = false
var _advance: bool = false
var _skip_all: bool = false
var _black: ColorRect
var _bg: TextureRect
var _title: Label
var _text: Label
var _hint: Control
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _boss_name: Label
var _boss_title: Label
var _boss_band: TextureRect       # faixa escura macia sob nome+título (QA7 #17/#23: legível sobre qualquer arte)
var _vig: ColorRect
var _art_box: Control              # as ilustrações (duas camadas para a troca)
var _art_a: TextureRect
var _art_b: TextureRect
var _shade: TextureRect            # faixa escura do terço inferior (legenda)
var _art_cur: Array = []           # ilustrações do card em tela
var _art_fade: bool = true         # o fade do card leva a ilustração junto?
var _kb_tweens: Array = []


## Fonte de TÍTULO: `CodexStyle.display()` (Cinzel) quando a UI nova estiver
## presente; senão, a serifada de corpo. Procurada pelo nome para este arquivo
## compilar com e sem a UI nova (o corpo continua em `CodexStyle.serif()`).
static func title_font() -> Font:
	var s: Script = load("res://scripts/ui/codex_style.gd")
	if s != null:
		for m in s.get_script_method_list():
			if String(m.get("name", "")) == "display":
				return s.call("display")
	return CodexStyle.serif()


static func _spawn() -> Cinematic:
	var c := Cinematic.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.call_deferred("add_child", c)
	return c


## Caminho da ilustração nº `n` (1–12); "" se não existir no projeto.
static func art_path(n: int) -> String:
	if not ART.has(n):
		return ""
	var p: String = ART_DIR + String(ART[n])
	return p if ResourceLoader.exists(p) else ""


## Textura da ilustração nº `n` (null se faltar: o card cai na pintura do Éon).
static func art_texture(n: int) -> Texture2D:
	var p := art_path(n)
	if p == "":
		return null
	var t = load(p)
	return t as Texture2D


## Um TextureRect de tela cheia que COBRE a tela (corta as sobras do 3:2).
static func make_art_rect() -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Faixa escura do terço inferior: a legenda lê em qualquer ilustração.
static func make_shade() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0.005, 0.012, 0.86)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	var r := TextureRect.new()
	r.texture = gt
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## KEN BURNS lento: zoom 1,00 → 1,00+KB_ZOOM e deriva leve na direção `dir`
## (x, y em −1..1) em `dur` s reais. A deriva só usa a folga que o zoom abre
## (o TextureRect cobre a tela exata): a borda da pintura nunca aparece.
static func ken_burns(r: Control, owner: Node, dur: float, dir: Vector2) -> Tween:
	var half := Vector2(320.0, 180.0)
	if r.is_inside_tree():
		half = r.get_viewport_rect().size * 0.5
	r.pivot_offset = half
	var tw := owner.create_tween().set_ignore_time_scale(true)
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(r):
			return
		var z := 1.0 + KB_ZOOM * k
		r.scale = Vector2(z, z)
		r.position = Vector2(dir.x * half.x, dir.y * half.y) * (z - 1.0) * KB_PAN, 0.0, 1.0, maxf(dur, 0.1))
	return tw


## O mito em 3 cards (backlog #6: o prólogo inteiro em ≤ 20 s; o jogador decide
## nos primeiros 60 s): o Um e os Éons → Sophia, o filho cego e a nuvem → o
## Kenoma e as faíscas. O último card NÃO diz "acorda": quem diz é
## a Voz, na primeira fala do jogo (Narrative.intro). Entrada/saída mais curtas
## que no epílogo (0,45 + 0,3 s); 3 × 0,75 + 17,6 s de leitura ≈ 19,9 s sem apertar nada.
static func prologue() -> Cinematic:
	var c := _spawn()
	# Onda 3: as 6 ilustrações do prólogo, duas por card, trocando no meio dele
	# (a Mônada → os Éons; Sophia e a nuvem → o Cego; o Kenoma → a faísca).
	# `bg` fica de reserva (sem a ilustração, volta a pintura do Éon).
	c.cards = [
		{"title": "", "text": "No princípio havia o Um. Dele emanaram os Éons, aos pares,\ncomo luz que transborda. Ali nada dormia. Nada esquecia.", "bg": 8, "art": [1, 2], "time": 5.4, "fade_in": 0.45, "fade_out": 0.3},
		{"title": "", "text": "A mais jovem, Sophia, quis alcançar a Fonte sozinha.\nDo desejo sem par nasceu um filho sem forma,\ne ela o escondeu numa nuvem.", "bg": 4, "art": [3, 4], "time": 5.8, "fade_in": 0.45, "fade_out": 0.3},
		{"title": "", "text": "Cego para a Luz, ele se acreditou o único deus e fez o Kenoma.\nNo barro dormem as faíscas que ele levou da mãe.\n\nUma delas acaba de sentir dor.", "bg": 0, "art": [5, 6], "time": 6.4, "fade_in": 0.45, "fade_out": 0.3},
	]
	return c


## Letterbox + nome grande + título; congela ~1,8 s.
static func boss_card(p_name: String, p_title: String) -> Cinematic:
	var c := _spawn()
	c.boss = {"name": p_name, "title": p_title}
	return c


## Cards do final escolhido + "Crônicas: N/18" + créditos curtos.
static func epilogue(ending: String, chron_n: int, chron_total: int) -> Cinematic:
	var c := _spawn()
	var bg := 8
	var art: Array = []
	match ending:
		"ascensao":
			bg = 3
			art = [10]
		"ruptura":
			bg = 6
			art = [11]
		"semente":
			bg = 0
			art = [12]
	# A ilustração do final fica sob o título e os cards do epílogo (o Ken Burns
	# corre por todos eles, sem piscar); Crônicas e créditos voltam à pintura do Éon.
	c.cards.append({"title": GameManager.end_title, "text": GameManager.end_subtitle, "bg": bg, "art": art, "time": 6.0})
	for t in Narrative.epilogue_cards(ending):
		c.cards.append({"title": "", "text": String(t), "bg": bg, "art": art, "time": 5.4})
	var chron_line := "Todas as pedras foram lidas. A faísca lembra por inteiro." if chron_n >= chron_total \
		else "Ficaram %d Estelas por ler no Kenoma. As Crônicas guardam as que foram lidas." % (chron_total - chron_n)
	c.cards.append({"title": "CRÔNICAS  %d / %d" % [chron_n, chron_total], "text": chron_line, "bg": 7, "time": 5.0})
	c.cards.append({"title": "GNOSIS", "text": "João Tatarin — direção, produção e escolhas\nArte ilustrada gerada por IA sob direção do autor\nCódigo escrito com Claude (Anthropic) e Codex (OpenAI)\nSons e efeitos CC0/CC-BY — ver assets/LICENSES.md\n\nInspirado nos textos de Nag Hammadi, na Pistis Sophia\ne nos relatos de Irineu, Hipólito e Clemente.", "bg": 8, "time": 7.0})
	# Depois dos créditos, em qualquer final: tela preta e só isto (bg -1 = sem
	# pintura). Não contradiz nenhum final e abre a porta do Jogo 2.
	c.cards.append({"title": "", "text": "...mãe?", "bg": -1, "time": 2.6})
	return c


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	PauseStack.push(self)
	if not boss.is_empty():
		_build_boss()
		_run_boss()
	else:
		_build_cards()
		_run_cards()


# --- cards ------------------------------------------------------------------

func _build_cards() -> void:
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.material = PaintedLibrary.material()
	_bg.modulate = Color(0.42, 0.44, 0.48, 1.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# As ilustrações: duas camadas (troca com fusão dentro do card), recortadas na tela.
	_art_box = Control.new()
	_art_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_box.clip_contents = true
	_art_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_box)
	_art_a = Cinematic.make_art_rect()
	_art_b = Cinematic.make_art_rect()
	_art_box.add_child(_art_a)
	_art_box.add_child(_art_b)
	_art_a.modulate = ART_DIM
	_art_b.modulate = Color(ART_DIM, 0.0)

	# vinheta: escurece as bordas para o texto assentar
	_vig = ColorRect.new()
	_vig.color = Color(0.0, 0.01, 0.02, 0.38)
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vig)
	_shade = Cinematic.make_shade()
	_shade.visible = false
	add_child(_shade)

	_title = Label.new()
	_title.anchor_left = 0.5
	_title.anchor_right = 0.5
	_title.anchor_top = 0.5
	_title.anchor_bottom = 0.5
	_title.offset_left = -TEXT_W * 0.5
	_title.offset_right = TEXT_W * 0.5
	_title.offset_top = -92.0
	_title.offset_bottom = -58.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", CodexStyle.GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("outline_size", 5)
	_title.add_theme_font_override("font", Cinematic.title_font())
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_text = Label.new()
	_text.anchor_left = 0.5
	_text.anchor_right = 0.5
	_text.anchor_top = 0.5
	_text.anchor_bottom = 0.5
	_text.offset_left = -TEXT_W * 0.5
	_text.offset_right = TEXT_W * 0.5
	_text.offset_top = -52.0
	_text.offset_bottom = 70.0
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", CodexStyle.PAPER)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_text.add_theme_constant_override("outline_size", 4)
	_text.add_theme_constant_override("line_spacing", 3)
	_text.add_theme_font_override("font", CodexStyle.serif())
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)

	# Rodapé com os ícones do dispositivo em uso (teclado ↔ controle, traduzido):
	# "[Enter] avança · [Esc] pula" / "[A] avança · [≡] pula" (QA2 #13, UI5).
	# Qualquer tecla/botão continua avançando.
	_hint = InputGlyphs.card_hint()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -240.0
	_hint.offset_top = -24.0
	_hint.offset_right = -14.0
	_hint.offset_bottom = -8.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_set_alpha(0.0)


func _set_alpha(a: float) -> void:
	_bg.modulate.a = a
	_title.modulate.a = a
	_text.modulate.a = a
	if _art_fade:
		_art_box.modulate.a = a
		_shade.modulate.a = a


func _run_cards() -> void:
	for i in cards.size():
		if _skip_all:
			break
		_idx = i
		var card: Dictionary = cards[i]
		var arts: Array = _card_art(card)
		# Mesma ilustração do card anterior: ela fica (o Ken Burns segue); só o texto troca.
		var keep: bool = not arts.is_empty() and arts == _art_cur
		_title.text = String(card.get("title", ""))
		_text.text = String(card.get("text", ""))
		_layout(not arts.is_empty())
		var bg_i: int = int(card.get("bg", -1))
		_bg.texture = PaintedLibrary.background(bg_i) if bg_i >= 0 and arts.is_empty() else null
		if not keep:
			_show_art(arts, i)
		_art_fade = not keep
		_advance = false
		await _fade(1.0, float(card.get("fade_in", 0.55)))
		if arts.size() > 1:
			await _hold_art(arts, float(card.get("time", 5.0)))
		else:
			await _hold(float(card.get("time", 5.0)))
		var nxt: Array = _card_art(cards[i + 1]) if i + 1 < cards.size() else []
		_art_fade = _skip_all or arts.is_empty() or nxt != arts
		await _fade(0.0, float(card.get("fade_out", 0.35)))
	_finish()


## As ilustrações do card que existem no projeto (sem elas, o card usa `bg`).
func _card_art(card: Dictionary) -> Array:
	var out: Array = []
	for n in card.get("art", []):
		if Cinematic.art_path(int(n)) != "":
			out.append(int(n))
	return out


## Card ILUSTRADO: pintura cheia, faixa escura embaixo, título + texto no terço
## inferior (o texto cresce para cima a partir da base). Card de pintura do Éon:
## o layout antigo, centrado, com a vinheta.
func _layout(illustrated: bool) -> void:
	_shade.visible = illustrated
	_vig.color.a = 0.08 if illustrated else 0.38
	if not illustrated:
		_title.anchor_top = 0.5
		_title.anchor_bottom = 0.5
		_title.offset_top = -92.0
		_title.offset_bottom = -58.0
		_text.anchor_top = 0.5
		_text.anchor_bottom = 0.5
		_text.offset_top = -52.0
		_text.offset_bottom = 70.0
		return
	_text.anchor_top = 1.0
	_text.anchor_bottom = 1.0
	_text.offset_bottom = -26.0
	_text.offset_top = -26.0 - 120.0
	var lines: int = maxi(1, _text.get_line_count())
	var h: float = float(lines) * (float(_text.get_line_height()) + 3.0)
	_text.offset_top = -26.0 - h
	_title.anchor_top = 1.0
	_title.anchor_bottom = 1.0
	_title.offset_bottom = _text.offset_top - 2.0
	_title.offset_top = _title.offset_bottom - 34.0


## Começa a(s) ilustração(ões) do card `i`: a 1ª entra com Ken Burns que dura o
## tempo em que ela fica na tela (somando os cards seguintes com a mesma pintura).
func _show_art(arts: Array, i: int) -> void:
	for t in _kb_tweens:
		if t is Tween and t.is_valid():
			t.kill()
	_kb_tweens.clear()
	_art_cur = arts
	_art_b.modulate.a = 0.0
	_art_b.texture = null
	if arts.is_empty():
		_art_a.texture = null
		return
	_art_a.texture = Cinematic.art_texture(int(arts[0]))
	_art_a.modulate = ART_DIM
	_art_box.move_child(_art_a, 0)
	var span := 0.0
	if arts.size() > 1:
		span = float(cards[i].get("time", 5.0)) / float(arts.size()) + XFADE + 0.6
	else:
		for k in range(i, cards.size()):
			if _card_art(cards[k]) != arts:
				break
			span += float(cards[k].get("time", 5.0)) + float(cards[k].get("fade_in", 0.55)) + float(cards[k].get("fade_out", 0.35))
	_kb_tweens.append(Cinematic.ken_burns(_art_a, self, span, _kb_dir(int(arts[0]))))


## Direção da deriva por ilustração (variada, determinística).
func _kb_dir(n: int) -> Vector2:
	var dirs := [Vector2(0.6, -0.5), Vector2(-0.6, 0.35), Vector2(0.45, 0.5), Vector2(-0.5, -0.4)]
	return dirs[n % dirs.size()]


## Card com mais de uma ilustração: divide o tempo e funde uma na outra (XFADE).
## Se o jogador avança, o card acaba (como sempre).
func _hold_art(arts: Array, total: float) -> void:
	var slice := total / float(arts.size())
	var front := _art_a
	var back := _art_b
	for j in range(1, arts.size()):
		await _hold(slice - XFADE * 0.5)
		if _advance or _skip_all:
			return
		back.texture = Cinematic.art_texture(int(arts[j]))
		back.scale = Vector2.ONE
		back.position = Vector2.ZERO
		back.modulate = Color(ART_DIM, 0.0)
		_art_box.move_child(back, -1)
		_kb_tweens.append(Cinematic.ken_burns(back, self, slice + XFADE + 0.6, _kb_dir(int(arts[j]))))
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(back, "modulate:a", 1.0, XFADE)
		await _hold(XFADE)
		back.modulate.a = 1.0
		front.modulate.a = 0.0
		var sw := front
		front = back
		back = sw
		if _advance or _skip_all:
			return
	await _hold(slice - XFADE * 0.5)


## Espera `t` segundos reais ou até o jogador avançar.
func _hold(t: float) -> void:
	var left := t
	while left > 0.0 and not _advance and not _skip_all:
		var dt: float = get_process_delta_time()
		left -= dt
		await get_tree().process_frame


func _fade(to: float, dur: float) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(_set_alpha, _bg.modulate.a, to, dur)
	await tw.finished


# --- card de chefe ----------------------------------------------------------

func _build_boss() -> void:
	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_bottom = 0.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_top)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bottom.offset_top = 0.0
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_bottom)

	# Faixa de leitura: elipse escura que esfuma nas pontas, atrás do nome e do
	# subtítulo. Sem ela o subtítulo (12 px) caía sobre o Colosso, plataformas e
	# chefes claros e sumia (QA7 #17 e #23).
	_boss_band = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.01, 0.02, 0.72))
	g.set_color(1, Color(0.0, 0.01, 0.02, 0.0))
	g.add_point(0.55, Color(0.0, 0.01, 0.02, 0.5))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 32
	_boss_band.texture = gt
	_boss_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_boss_band.stretch_mode = TextureRect.STRETCH_SCALE
	_boss_band.anchor_left = 0.5
	_boss_band.anchor_right = 0.5
	_boss_band.anchor_top = 0.5
	_boss_band.anchor_bottom = 0.5
	_boss_band.offset_left = -340.0
	_boss_band.offset_right = 340.0
	_boss_band.offset_top = -96.0
	_boss_band.offset_bottom = 6.0
	_boss_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_band.modulate.a = 0.0
	add_child(_boss_band)

	_boss_name = Label.new()
	_boss_name.text = String(boss.get("name", ""))
	_boss_name.anchor_left = 0.5
	_boss_name.anchor_right = 0.5
	_boss_name.anchor_top = 0.5
	_boss_name.anchor_bottom = 0.5
	_boss_name.offset_left = -300.0
	_boss_name.offset_right = 300.0
	_boss_name.offset_top = -74.0
	_boss_name.offset_bottom = -34.0
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_boss_name.add_theme_font_size_override("font_size", 30)
	_boss_name.add_theme_color_override("font_color", CodexStyle.GOLD)
	_boss_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_boss_name.add_theme_constant_override("outline_size", 7)
	_boss_name.add_theme_font_override("font", Cinematic.title_font())
	_boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name.modulate.a = 0.0
	add_child(_boss_name)

	_boss_title = Label.new()
	_boss_title.text = String(boss.get("title", ""))
	_boss_title.anchor_left = 0.5
	_boss_title.anchor_right = 0.5
	_boss_title.anchor_top = 0.5
	_boss_title.anchor_bottom = 0.5
	_boss_title.offset_left = -300.0
	_boss_title.offset_right = 300.0
	_boss_title.offset_top = -32.0
	_boss_title.offset_bottom = -12.0
	_boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_title.add_theme_font_size_override("font_size", 12)
	_boss_title.add_theme_color_override("font_color", CodexStyle.PAPER)
	_boss_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_boss_title.add_theme_constant_override("outline_size", 5)
	_boss_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # título longo (EN) quebra em vez de vazar
	_boss_title.offset_bottom = 6.0
	_boss_title.add_theme_font_override("font", Cinematic.title_font())
	_boss_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_title.modulate.a = 0.0
	add_child(_boss_title)


func _run_boss() -> void:
	Audio.play_sfx("boss_appear")
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", 44.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bar_bottom, "offset_top", -44.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_boss_name, "modulate:a", 1.0, 0.35)
	tw.tween_property(_boss_band, "modulate:a", 1.0, 0.3)
	tw.tween_property(_boss_title, "modulate:a", 1.0, 0.5).set_delay(0.15)
	_boss_name.scale = Vector2(1.18, 1.18)
	_boss_name.pivot_offset = Vector2(300.0, 40.0)
	tw.tween_property(_boss_name, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.8, true, false, true).timeout
	var out := create_tween()
	out.set_ignore_time_scale(true)
	out.set_parallel(true)
	out.tween_property(_bar_top, "offset_bottom", 0.0, 0.25)
	out.tween_property(_bar_bottom, "offset_top", 0.0, 0.25)
	out.tween_property(_boss_name, "modulate:a", 0.0, 0.22)
	out.tween_property(_boss_title, "modulate:a", 0.0, 0.22)
	out.tween_property(_boss_band, "modulate:a", 0.0, 0.22)
	await out.finished
	_finish()


# --- comum ------------------------------------------------------------------

func _finish() -> void:
	if _done:
		return
	_done = true
	PauseStack.pop(self)
	finished.emit()
	queue_free()


## Apagado sem passar por _finish (troca de cena): não segura a pausa.
func _exit_tree() -> void:
	if not _done:
		PauseStack.pop(self)


func _unhandled_input(event: InputEvent) -> void:
	if _done or not boss.is_empty():
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause"):
		_skip_all = true
	_advance = true
