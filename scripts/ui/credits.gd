extends Control
class_name Credits
## CRÉDITOS — equipe, fontes e a atribuição OBRIGATÓRIA (CC-BY) das músicas e
## sons, lida de `assets/LICENSES.md` (fonte única: quem troca um asset atualiza
## só aquele arquivo). Se o .md não estiver no pacote exportado, usa o texto de
## atribuição embutido abaixo (a build nunca sai sem o crédito exigido).
## Rola sozinho; ↑/↓ (teclado, D-pad, analógico) rolam na mão; Esc/B ou
## "Voltar" saem. Acessível pelo menu e pela tela de fim (vitória).

const SPEED := 16.0               # px/s rolando sozinho
const MANUAL := 160.0             # px/s com o direcional

## De onde ler os créditos (variável para as ferramentas de QA testarem a falta do arquivo).
static var licenses_path: String = "res://assets/LICENSES.md"

## Atribuição mínima OBRIGATÓRIA (CC-BY), embutida: vale quando o LICENSES.md
## não vem no pacote exportado ou perdeu o bloco "## CRÉDITOS".
const FALLBACK_ATTRIBUTION := [
	"Música: Kevin MacLeod (incompetech.com) — Licensed under Creative Commons: By Attribution 4.0 — https://creativecommons.org/licenses/by/4.0/",
	"Efeitos sonoros: \"Fantasy Sound Effects Library\" — Little Robot Sound Factory (www.littlerobotsoundfactory.com) — CC-BY 3.0 — https://creativecommons.org/licenses/by/3.0/",
	"Efeitos CC0: Kenney (kenney.nl) e autores CC0 do OpenGameArt.org",
	"Partículas: Kenney Particle Pack (CC0)",
]

## i18n (QA7 #16): o LICENSES.md não passa pelo extrator e muda quando entra som
## novo. A linha é traduzida inteira se houver chave; senão o RÓTULO ("Efeitos CC0:")
## e os TRECHOS conhecidos abaixo são traduzidos um a um (o resto é nome próprio).
const CREDIT_HEADS := [
	"Música:", "Faixas:", "Efeitos sonoros:", "Efeitos CC0:", "Partículas:",
	"Ambiências, magias, vozes e camadas sintetizadas:",
]
const CREDIT_FRAGMENTS := [
	"e outros autores CC0 do", "feitas para GNOSIS", "anônimo",
	"multi-licença; usada a CC0", "e colaboradores", "licença MIT",
]

## Para onde "Voltar" leva (a tela de fim manda pro menu também).
static var return_to: String = "res://scenes/ui/MainMenu.tscn"

var _roll: VBoxContainer
var _clip: Control
var _back: Button
var _y: float = 0.0
var _hold: float = 1.2            # respiro antes de começar a rolar


func _ready() -> void:
	GameManager.set_state(GameManager.State.MENU)
	theme = CodexStyle.theme()
	var bg := ColorRect.new()
	bg.color = CodexStyle.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var painting := TextureRect.new()
	painting.texture = PaintedLibrary.background(8)
	painting.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	painting.modulate = Color(0.28, 0.32, 0.38)
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painting)
	var motes := CodexStyle.Motes.new()
	add_child(motes)

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.position = Vector2(120, 0)
	_clip.size = Vector2(400, 360)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_roll = VBoxContainer.new()
	_roll.add_theme_constant_override("separation", 3)
	_roll.custom_minimum_size.x = 400
	_roll.size.x = 400
	_clip.add_child(_roll)
	_fill()
	_y = 300.0
	_roll.position.y = _y

	# Bordas que esfumam o rolo (em cima e embaixo).
	var fade := _Fade.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	_back = CodexStyle.button(self, "Voltar", Vector2(540, 324), 84, _leave, false, "ui_back")
	var hint := InputGlyphs.Hint.new()     # segue o dispositivo em uso (#33)
	hint.pairs = [["@scroll", "rolam"], ["ui_cancel", "volta"]]
	hint.position = Vector2(16, 330)
	hint.size = Vector2(300, 16)
	hint.font_size = 9
	hint.icon_h = 12.0
	hint.align = 0
	add_child(hint)
	_back.grab_focus()


# --- conteúdo -------------------------------------------------------------------

func _fill() -> void:
	var logo := _line("GNOSIS", 40, CodexStyle.PAPER, CodexStyle.logo())
	logo.add_theme_color_override("font_shadow_color", Color(CodexStyle.GOLD, 0.25))
	logo.add_theme_constant_override("shadow_outline_size", 6)
	_line("O DESPERTAR", 10, CodexStyle.GOLD, CodexStyle.display())
	_gap(26)
	_head("Criação e direção")
	_line("João Tatarin", 15, CodexStyle.PAPER, CodexStyle.display())
	_gap(14)
	_head("Desenvolvido com")
	_line("Claude", 15, CodexStyle.PAPER, CodexStyle.display())
	_small("(Anthropic)  ·  e Codex (OpenAI)")
	_small("Arte ilustrada gerada por IA sob direção do autor")
	_gap(14)
	var lic := _read_licenses()
	# Música e sons: o bloco "## CRÉDITOS" do LICENSES.md (ou a reserva embutida).
	_head("Música e sons")
	var lines: Array = lic.credits if lic.credits.size() > 0 else FALLBACK_ATTRIBUTION
	for a in lines:
		var t := String(a)
		if t.begins_with("Faixas:"):
			_small(t)
		else:
			_para(t)
	if lic.packs.size() > 0:
		_gap(10)
		_head("Pacotes de sons e partículas")
		for p in lic.packs:
			_small(String(p))
	_gap(10)
	_head("Fontes")
	_small("Cinzel e Cinzel Decorative  —  Natanael Gama")
	_small("Alegreya  —  Juan Pablo del Peral / Huerta Tipográfica")
	_small("SIL Open Font License 1.1  (assets/fonts/*/OFL.txt)")
	_gap(10)
	_head("Motor")
	_small("Godot Engine  —  © Juan Linietsky, Ariel Manzur e colaboradores (licença MIT)")
	_small("godotengine.org/license")
	_gap(40)
	_line("Obrigado por despertar.", 13, CodexStyle.GOLD_HI, CodexStyle.italic())
	_gap(160)


## Lê o LICENSES.md: o bloco "## CRÉDITOS" (cada linha "- " é uma linha de
## crédito) e a tabela "## Packs" (pack — autor (licença)).
func _read_licenses() -> Dictionary:
	var out := {"credits": [], "packs": []}
	if not FileAccess.file_exists(licenses_path):
		return out
	var f := FileAccess.open(licenses_path, FileAccess.READ)
	if f == null:
		return out
	var section := ""
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("## "):
			section = line.substr(3).to_lower()
			continue
		if section.begins_with("créditos") and line.begins_with("- "):
			out.credits.append(line.substr(2).strip_edges())
		elif section == "packs" and line.begins_with("|") and not line.begins_with("|---") and not line.begins_with("| Pack"):
			var c := line.split("|", false)
			if c.size() >= 3:
				out.packs.append("%s  —  %s  (%s)" % [c[0].strip_edges(), c[1].strip_edges(), c[2].strip_edges().replace("**", "")])
	return out


func _line(text: String, size: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = _tr_credit(text)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # já vem traduzido
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 400
	_roll.add_child(l)
	return l


## Texto de crédito no idioma atual (ver CREDIT_HEADS/CREDIT_FRAGMENTS).
static func _tr_credit(text: String) -> String:
	if not I18n.is_en():
		return text
	var out := I18n.t(text)      # chave inteira (ou padrão "%s: %s" parcial)
	if out == text:
		for h in CREDIT_HEADS:
			if out.begins_with(h):
				out = I18n.t(h) + out.substr(String(h).length())
				break
	# trechos em português que sobraram (padrão parcial ou linha nova)
	for frag in CREDIT_FRAGMENTS:
		if out.contains(frag):
			out = out.replace(frag, I18n.t(frag))
	return out


func _head(text: String) -> void:
	_line(text.to_upper(), 9, CodexStyle.GOLD, CodexStyle.display())
	var r := CodexStyle.rule(_roll, Vector2.ZERO, 400, Color(CodexStyle.GOLD, 0.6))
	r.custom_minimum_size = Vector2(400, 7)


func _small(text: String) -> void:
	_line(text, 10, Color(CodexStyle.PAPER, 0.82), CodexStyle.body())


func _para(text: String) -> void:
	var l := _line(text, 11, CodexStyle.PAPER, CodexStyle.body())
	l.add_theme_constant_override("line_spacing", 0)


func _gap(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	_roll.add_child(c)


# --- rolagem e saída ------------------------------------------------------------

func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_up", "ui_down")
	if absf(dir) < 0.3 and InputMap.has_action("move_up"):
		dir = Input.get_axis("move_up", "move_down")
	if absf(dir) > 0.3:
		_y -= dir * MANUAL * delta
		_hold = 1.5
	elif _hold > 0.0:
		_hold -= delta
	else:
		_y -= SPEED * delta
	var h := _roll.get_combined_minimum_size().y
	_y = clampf(_y, 360.0 - h, 320.0)
	_roll.position.y = _y


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		_leave()


func _leave() -> void:
	var to := return_to
	return_to = "res://scenes/ui/MainMenu.tscn"
	SceneManager.change_scene(to)


class _Fade extends Control:
	func _draw() -> void:
		var ink := Color("0a151c")
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, 60), Vector2(0, 60)]),
			PackedColorArray([ink, ink, Color(ink, 0), Color(ink, 0)]))
		draw_polygon(PackedVector2Array([Vector2(0, size.y - 70), Vector2(size.x, size.y - 70), Vector2(size.x, size.y), Vector2(0, size.y)]),
			PackedColorArray([Color(ink, 0), Color(ink, 0), ink, ink]))
