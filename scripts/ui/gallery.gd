extends Node2D
## Codex / Galeria — o roster real do jogo (renderizado pelo motor de arte
## procedural): evolução do herói, waves, bots de Éon, Arcontes, as formas do
## Demiurgo e os aliados. W/S (ou setas) rolam; Esc volta ao menu.

const COLS := 6
const CW := 100.0        # largura da célula
const CH := 116.0        # altura da célula (arte + nome, sem sobrepor)
const X0 := 70.0
const Y0 := 95.0
const VIEW_H := 360.0    # altura visível (res base)

var _cam: Camera2D
var _max_scroll: float = 0.0


func _ready() -> void:
	var rows := 0

	var entries: Array = []
	var hero := GameContent.get_character("sophia")
	entries.append({"n": "Sophia Nv.1", "p": Bestiary.player_profile(hero, 1, [])})
	entries.append({"n": "Sophia Nv.3", "p": Bestiary.player_profile(hero, 3, [])})
	entries.append({"n": "Sophia Nv.5", "p": Bestiary.player_profile(hero, 5, [])})
	for t in Bestiary.wave_types:
		entries.append({"n": t.name, "p": t.profile})
	for b in Bestiary.bosses:
		entries.append({"n": b.name, "p": b.profile})
	for s in Bestiary.specials:
		entries.append({"n": s.name, "p": s.profile})
	entries.append({"n": Bestiary.demiurge.name, "p": Bestiary.demiurge.profile})
	entries.append({"n": "Soter, o Ungido", "p": Bestiary.soter_profile()})
	entries.append({"n": "Velkar, o Arrependido", "p": Bestiary.velkar_profile()})

	rows = int(ceil(float(entries.size()) / float(COLS)))
	var total_h := Y0 + rows * CH + 40.0
	_max_scroll = maxf(0.0, total_h - VIEW_H)

	# fundo cobre tudo (inclusive a parte rolável)
	var bg := ColorRect.new()
	bg.color = Color("0a151c")
	bg.position = Vector2(-40, -40)
	bg.size = Vector2(760, total_h + 80.0)
	bg.z_index = -10
	add_child(bg)

	# cabeçalho fixo (não rola com a câmera)
	var hud := CanvasLayer.new()
	add_child(hud)
	var header := ColorRect.new()
	header.color = Color("0a151c")
	header.size = Vector2(640,51)
	hud.add_child(header)
	var back := CodexStyle.button(hud, "Voltar", Vector2(541, 12), 80, _leave, false, "ui_back")
	CodexStyle.label(hud, "Bestiário", Vector2(20, 8), 18, CodexStyle.GOLD_HI, 300, true)
	var hint := CodexStyle.label(hud, "W/S · setas · analógico rolam   ·   Esc / B volta", Vector2(20, 32), 10, CodexStyle.MUTED, 320)
	hint.add_theme_font_override("font", CodexStyle.italic())
	CodexStyle.rule(hud, Vector2(0, 46), 640, Color(CodexStyle.GOLD, 0.5))
	back.grab_focus()

	for i in entries.size():
		var col := i % COLS
		var row := i / COLS
		var cx := X0 + col * CW
		var cy := Y0 + row * CH

		var card := Polygon2D.new()
		card.polygon = PackedVector2Array([Vector2(cx-48,cy-49),Vector2(cx+48,cy-49),Vector2(cx+48,cy+65),Vector2(cx-48,cy+65)])
		card.color = Color("12232b")
		var edge := Line2D.new()
		edge.points = PackedVector2Array([Vector2(cx-48,cy-49),Vector2(cx+48,cy-49),Vector2(cx+48,cy+65),Vector2(cx-48,cy+65),Vector2(cx-48,cy-49)])
		edge.width = 0.6
		edge.default_color = Color(0.77, 0.65, 0.42, 0.35)
		add_child(edge)
		add_child(card)
		var shadow := _shadow_at(Vector2(cx, cy + 28))
		add_child(shadow)

		var art := CharacterArt.new()
		art.set_profile(entries[i].p)
		var hgt: float = entries[i].p.height
		var sc: float = 50.0 / (190.0 if art.painted.get("sheet","") == "yaldabaoth" else hgt*1.3)
		art.scale = Vector2(sc, sc)
		art.position = Vector2(cx, cy+25-24*hgt/44*sc)
		add_child(art)

		# Só o nome próprio (antes da vírgula) — o resto sobrepunha as células.
		var short_name := String(entries[i].n).split(",")[0]
		if short_name.length() > 17:
			var split_at: int = short_name.rfind(" ",17)
			if split_at > 0:
				short_name = short_name.substr(0,split_at) + "\n" + short_name.substr(split_at+1)
		_label(short_name, Vector2(cx - 48, cy + 34), 9, HORIZONTAL_ALIGNMENT_CENTER, 96)

	# câmera pra rolar (o viewport base é 640x360)
	_cam = Camera2D.new()
	_cam.position = Vector2(320, 180)
	add_child(_cam)
	_cam.make_current()


func _process(delta: float) -> void:
	var dir := Input.get_axis("move_up", "move_down") if InputMap.has_action("move_up") else 0.0
	if absf(dir) < 0.3:
		dir = Input.get_axis("ui_up", "ui_down")
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir = -1.0
	elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir = 1.0
	if dir != 0.0 and _cam != null:
		_cam.position.y = clampf(_cam.position.y + dir * 260.0 * delta, 180.0, 180.0 + _max_scroll)


func _label(text: String, pos: Vector2, size: int, align: int, width: float) -> void:
	add_child(_make_label(text, pos, size, align, width))


func _make_label(text: String, pos: Vector2, size: int, align: int, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(width, 16)
	l.horizontal_alignment = align
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.add_theme_font_size_override("font_size", size)
	return l


func _shadow_at(pos: Vector2) -> Polygon2D:
	var s := Polygon2D.new()
	s.color = Color(0, 0, 0, 0.28)
	s.position = pos
	s.polygon = PackedVector2Array([
		Vector2(20, 0), Vector2(16, 3), Vector2(0, 5), Vector2(-16, 3),
		Vector2(-20, 0), Vector2(-16, -3), Vector2(0, -5), Vector2(16, -3)
	])
	return s


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		_leave()


## Volta pro Ateliê (de onde o Bestiário é aberto) — botão e Esc/B iguais.
func _leave() -> void:
	SceneManager.change_scene("res://scenes/ui/CharacterAtelier.tscn")
