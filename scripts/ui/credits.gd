extends Control
class_name Credits
## CRÉDITOS — equipe, fontes e a atribuição OBRIGATÓRIA (CC-BY) das músicas e
## sons, lida de `assets/LICENSES.md` (fonte única: quem troca um asset atualiza
## só aquele arquivo). Se o .md não estiver no pacote exportado, usa o texto de
## atribuição embutido abaixo (a build nunca sai sem o crédito exigido).
## Rola sozinho; ↑/↓ (teclado, D-pad, analógico) rolam na mão; Esc/B ou
## "Voltar" saem. Acessível pelo menu e pela tela de fim (vitória).

const LICENSES := "res://assets/LICENSES.md"
const SPEED := 16.0               # px/s rolando sozinho
const MANUAL := 160.0             # px/s com o direcional

## Atribuição mínima (cópia do bloco "Texto de atribuição" do LICENSES.md).
const FALLBACK_ATTRIBUTION := [
	"Música de Kevin MacLeod (incompetech.com), licenciada sob Creative Commons: By Attribution 4.0 — https://creativecommons.org/licenses/by/4.0/",
	"Efeitos sonoros: \"Fantasy Sound Effects Library\" e \"Magic SFX Preview Pack\" de Little Robot Sound Factory (www.littlerobotsoundfactory.com), CC-BY 3.0.",
	"Demais sons e sprites de partícula: Kenney (kenney.nl) e autores CC0 do OpenGameArt.org.",
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
	CodexStyle.label(self, "W/S · setas · analógico rolam   ·   Esc / B volta", Vector2(16, 332), 9, Color(CodexStyle.MUTED, 0.8), 260)
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
	_small("(Anthropic)")
	_gap(14)
	var lic := _read_licenses()
	_head("Música")
	if lic.tracks.size() > 0:
		_line("Kevin MacLeod  ·  incompetech.com", 12, CodexStyle.PAPER, CodexStyle.body_bold())
		_small(", ".join(PackedStringArray(lic.tracks)))
		_small("Licença Creative Commons: By Attribution 4.0")
		_small("https://creativecommons.org/licenses/by/4.0/")
	_gap(10)
	_head("Atribuição")
	var attribution: Array = lic.attribution if lic.attribution.size() > 0 else FALLBACK_ATTRIBUTION
	for a in attribution:
		_para(String(a))
	if lic.packs.size() > 0:
		_gap(10)
		_head("Sons e partículas")
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
	_gap(40)
	_line("Obrigado por despertar.", 13, CodexStyle.GOLD_HI, CodexStyle.italic())
	_gap(160)


## Lê o LICENSES.md: bloco de atribuição (linhas "> "), tabela de músicas e de packs.
func _read_licenses() -> Dictionary:
	var out := {"attribution": [], "tracks": [], "packs": []}
	if not FileAccess.file_exists(LICENSES):
		return out
	var f := FileAccess.open(LICENSES, FileAccess.READ)
	if f == null:
		return out
	var section := ""
	var para := ""
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("## "):
			section = line.substr(3).to_lower()
			continue
		if section.begins_with("texto de atribuição") and line.begins_with(">"):
			var t := line.trim_prefix(">").strip_edges()
			# Parágrafo novo quando o anterior fechou (ponto final ou fim de URL).
			if para != "" and (para.ends_with(".") or para.ends_with("/")):
				out.attribution.append(para)
				para = t
			else:
				para = (para + " " + t).strip_edges()
		elif section.begins_with("músicas") and line.begins_with("| `music/"):
			var cells := line.split("|", false)
			if cells.size() >= 2:
				out.tracks.append(cells[1].strip_edges())
		elif section == "packs" and line.begins_with("|") and not line.begins_with("|---") and not line.begins_with("| Pack"):
			var c := line.split("|", false)
			if c.size() >= 3:
				out.packs.append("%s  —  %s  (%s)" % [c[0].strip_edges(), c[1].strip_edges(), c[2].strip_edges().replace("**", "")])
	if para != "":
		out.attribution.append(para)
	return out


func _line(text: String, size: int, col: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 400
	_roll.add_child(l)
	return l


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
