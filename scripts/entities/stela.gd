extends Node2D
class_name Stela
## Estela de lore: uma pedra escrita deixada nos descansos entre as zonas.
## Chegue perto e aperte o golpe leve (J / X) ou Enter para LER: abre um painel
## estilizado (CodexStyle) com o ensino gnóstico daquela pedra e desbloqueia a
## entrada correspondente nas Crônicas (persistem entre runs — `Gnosis`).
## Só abre FORA de combate (QA M7): com inimigo vivo perto, zona trancada ou a
## Sophia no meio de um combo, o golpe leve é só golpe.
## Desenhada por código (obsidiana + inscrições em marfim + brilho de ouro
## enquanto ainda não foi lida). `entry` vem de `Gnosis.STELAS`.
## Ilustração (Onda 3): cada Estela tem um afresco em `assets/stelae/<id>.png`
## (recortado das folhas do GPT por assets/stelae/build_stelae.py), mostrado à
## esquerda do texto no painel de leitura e como miniatura nas Crônicas
## (`Stela.art_for(id)` + o Control `Stela.ArtFrame`).

var entry: Dictionary = {}
var _near: bool = false
var _read_now: bool = false        # lida nesta visita (apaga o brilho)
var _t: float = 0.0
var _prompt: Label
var _busy: bool = false

## Inimigo vivo a menos disto (px) da Sophia = combate: a Estela não abre.
const ENEMY_NEAR := 320.0


func _ready() -> void:
	z_index = 1                      # na frente do chão, atrás dos lutadores
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2          # o corpo da Sophia
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 58.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	_prompt = Label.new()
	_prompt.text = _prompt_text()
	_prompt.position = Vector2(-60.0, -100.0)
	_prompt.size = Vector2(120.0, 14.0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 9)
	_prompt.add_theme_color_override("font_color", CodexStyle.GOLD)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.visible = false
	add_child(_prompt)


func _process(delta: float) -> void:
	_t += delta
	# O convite só aparece quando ler é possível (sem inimigo vivo por perto).
	if _near and not _busy:
		_prompt.visible = not _enemy_near()
		if _prompt.visible:
			_prompt.text = _prompt_text()      # segue o dispositivo e o remapeamento (#33)
	queue_redraw()


## "J · ler a Estela" no teclado, "X · ler a Estela" no Xbox, etc.
static func _prompt_text() -> String:
	return "%s · ler a Estela" % InputGlyphs.label("attack_light")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_near = true
		_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _near or _busy or entry.is_empty():
		return
	var read := event.is_action_pressed("attack_light")
	# Enter também lê — mas não o pulo (Espaço/A também são "ui_accept").
	if not read and event.is_action_pressed("ui_accept") and not event.is_action("jump"):
		read = true
	if not read or not can_read():
		return
	get_viewport().set_input_as_handled()
	open()


## Ler só fora de combate: sem inimigo vivo perto, sem zona trancada e sem a
## Sophia no meio de um combo (aí o aperto é golpe).
func can_read() -> bool:
	if _enemy_near():
		return false
	var lv := get_tree().current_scene
	if lv != null and "zone_active" in lv and bool(lv.get("zone_active")):
		return false
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null:
		var seq = pl.get("combo_sequence")
		var timer = pl.get("combo_reset_timer")
		if seq is Array and not seq.is_empty() and timer != null and float(timer) > 0.0:
			return false
	return true


func _enemy_near() -> bool:
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	var from: Vector2 = pl.global_position if pl != null else global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D) or e.is_queued_for_deletion():
			continue
		var h = e.get("health")
		if h != null and h.has_method("is_dead") and h.is_dead():
			continue
		if (e as Node2D).global_position.distance_to(from) < ENEMY_NEAR:
			return true
	return false


## Ilustração da Estela `id` (null se não houver o arquivo).
static func art_for(id: String) -> Texture2D:
	var p := "res://assets/stelae/%s.png" % id
	return load(p) if ResourceLoader.exists(p) else null


## Abre o painel de leitura; ao fechar, desbloqueia a Crônica (se inédita).
func open() -> void:
	_busy = true
	_read_now = true
	_prompt.visible = false
	Audio.play_sfx("stela")
	var fresh: bool = Gnosis.unlock(String(entry.get("id", "")))
	var panel := StelaPanel.new()
	panel.entry = entry
	panel.fresh = fresh
	get_tree().root.add_child(panel)
	await panel.finished
	if not is_inside_tree():
		return
	if fresh:
		get_tree().call_group("hud", "toast", "Crônica desbloqueada: %s  (%d/%d)" % [
			String(entry.get("title", "")), Gnosis.chronicles_count(), Gnosis.chronicles_total()])
		ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -40), CodexStyle.GOLD)
	_busy = false
	if _near:
		_prompt.visible = true


func _draw() -> void:
	var unread: bool = not _read_now and not Gnosis.is_unlocked(String(entry.get("id", "")))
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	# sombra no chão
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, 24.0, Color(0, 0, 0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# brilho de ouro enquanto ainda não foi lida
	if unread:
		draw_circle(Vector2(0, -40), 34.0 + 4.0 * pulse, Color(CodexStyle.GOLD, 0.05 + 0.05 * pulse))
		draw_circle(Vector2(0, -40), 18.0, Color(CodexStyle.GOLD, 0.06 + 0.06 * pulse))
	# plinto
	draw_rect(Rect2(-19, -8, 38, 10), Color(0.07, 0.10, 0.13))
	draw_rect(Rect2(-19, -8, 38, 10), Color(0.30, 0.33, 0.33, 0.7), false, 1.0)
	# a lápide (obsidiana com topo arqueado)
	var slab := PackedVector2Array([
		Vector2(-14, -8), Vector2(-14, -64), Vector2(-10, -73), Vector2(0, -78),
		Vector2(10, -73), Vector2(14, -64), Vector2(14, -8),
	])
	draw_colored_polygon(slab, Color(0.06, 0.09, 0.12))
	draw_polyline(slab, Color(0.42, 0.38, 0.26, 0.9), 1.2, true)
	draw_line(Vector2(-14, -8), Vector2(14, -8), Color(0.42, 0.38, 0.26, 0.9), 1.2, true)
	# olho de ouro no topo (a faísca)
	var gem := Color(CodexStyle.GOLD, 0.95 if unread else 0.5)
	draw_circle(Vector2(0, -68), 2.6, gem)
	# inscrições: fileiras de traços curtos (glifos), marfim
	var ink := Color(CodexStyle.PAPER, (0.55 + 0.25 * pulse) if unread else 0.42)
	var seed_v: int = int(entry.get("screen", 1))
	for row in 7:
		var y := -58.0 + float(row) * 6.5
		var x := -10.0
		var k := 0
		while x < 9.0:
			var w := 2.0 + float((seed_v * 7 + row * 5 + k * 3) % 4)
			if x + w > 10.0:
				w = 10.0 - x
			draw_line(Vector2(x, y), Vector2(x + w, y), ink, 1.2, false)
			x += w + 1.6
			k += 1
	# ranhura vertical central (a "coluna" da estela)
	draw_line(Vector2(0, -14), Vector2(0, -10), ink, 1.0, false)


## Painel de leitura da Estela: pausa o mundo, mostra título + linhas + fonte
## histórica; fecha com golpe leve / pulo / Enter / Esc.
class StelaPanel extends CanvasLayer:
	signal finished
	var entry: Dictionary = {}
	var fresh: bool = false
	var _guard: float = 0.25          # ignora o próprio aperto que abriu

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		PauseStack.push(self)          # (o som de abrir é o "stela", tocado pela pedra)
		layer = 92
		var dim := ColorRect.new()
		dim.color = Color(0.0, 0.02, 0.03, 0.55)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)

		var panel := PanelContainer.new()
		panel.theme = CodexStyle.theme()
		panel.custom_minimum_size = Vector2(600, 0)
		center.add_child(panel)

		# Afresco à esquerda, texto à direita (sem ilustração: só o texto, como antes).
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var tex := Stela.art_for(String(entry.get("id", "")))
		if tex != null:
			var art := Stela.ArtFrame.new()
			art.texture = tex
			art.custom_minimum_size = Vector2(132, 126)
			art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(art)
		var text_w := 424.0 if tex != null else 540.0

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		vbox.custom_minimum_size = Vector2(text_w, 0)
		row.add_child(vbox)

		var head := Label.new()
		head.text = "ESTELA  ·  %s" % String(entry.get("eon", "Kenoma")).to_upper()
		head.add_theme_font_size_override("font_size", 9)
		head.add_theme_color_override("font_color", CodexStyle.MUTED)
		head.add_theme_font_override("font", Cinematic.title_font())
		vbox.add_child(head)

		var title := Label.new()
		title.text = String(entry.get("title", ""))
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", CodexStyle.GOLD)
		title.add_theme_font_override("font", Cinematic.title_font())
		vbox.add_child(title)

		var rule := ColorRect.new()
		rule.color = Color(CodexStyle.GOLD, 0.55)
		rule.custom_minimum_size = Vector2(0, 1)
		vbox.add_child(rule)

		var body := Label.new()
		var lines: Array = entry.get("lines", [])
		body.text = "\n".join(PackedStringArray(lines))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(text_w, 0)
		body.add_theme_font_size_override("font_size", 11)
		body.add_theme_color_override("font_color", CodexStyle.PAPER)
		body.add_theme_constant_override("line_spacing", 0 if tex != null else 2)
		vbox.add_child(body)

		var src := Label.new()
		src.text = "Fonte: %s" % String(entry.get("source", ""))
		src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		src.custom_minimum_size = Vector2(text_w, 0)
		src.add_theme_font_size_override("font_size", 9)
		src.add_theme_color_override("font_color", CodexStyle.MUTED)
		vbox.add_child(src)

		# Rodapé: contagem das Crônicas + "fechar" com o ÍCONE do dispositivo em uso
		# (Esc no teclado, B/Círculo no controle — QA2 #13); troca sozinho se ela
		# mudar de teclado para controle com o painel aberto.
		var foot_row := HBoxContainer.new()
		foot_row.alignment = BoxContainer.ALIGNMENT_END
		foot_row.add_theme_constant_override("separation", 18)
		vbox.add_child(foot_row)
		var foot := Label.new()
		var n: int = Gnosis.chronicles_count()
		var total: int = Gnosis.chronicles_total()
		foot.text = ("• nova Crônica  %d/%d" % [n, total]) if fresh else ("Crônica %d/%d" % [n, total])
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		foot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_theme_font_size_override("font_size", 9)
		foot.add_theme_color_override("font_color", CodexStyle.GOLD if fresh else CodexStyle.MUTED)
		foot_row.add_child(foot)
		var close_hint := InputGlyphs.Hint.new()
		close_hint.pairs = [["ui_cancel", "fechar"]]
		close_hint.font_size = 9
		close_hint.icon_h = 11.0
		close_hint.align = 2
		close_hint.color = CodexStyle.MUTED
		close_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot_row.add_child(close_hint)

	func _process(delta: float) -> void:
		if _guard > 0.0:
			_guard -= delta

	func _unhandled_input(event: InputEvent) -> void:
		if _guard > 0.0:
			return
		if event.is_action_pressed("attack_light") or event.is_action_pressed("jump") \
				or event.is_action_pressed("ui_accept") or event.is_action_pressed("pause") \
				or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			Audio.play_sfx("ui")
			PauseStack.pop(self)
			finished.emit()
			queue_free()

	func _exit_tree() -> void:
		PauseStack.pop(self)


## Moldura do afresco da Estela: fundo azul-noite, a pintura inteira (proporção
## mantida, centrada), filete de ouro duplo e cantoneiras. `locked` = ainda não
## lida: pedra escura com o olho de ouro apagado (sem spoiler da imagem).
class ArtFrame extends Control:
	var texture: Texture2D:
		set(v):
			texture = v
			queue_redraw()
	var locked: bool = false:
		set(v):
			locked = v
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r.grow(1.5), Color(0, 0, 0, 0.55))
		draw_rect(r, CodexStyle.INK_DEEP)
		if texture != null and not locked:
			var ts := texture.get_size()
			var k := minf(size.x / ts.x, size.y / ts.y)
			var ds := ts * k
			draw_texture_rect(texture, Rect2((size - ds) * 0.5, ds), false)
		else:
			# pedra fechada: degradê escuro + o olho de ouro apagado
			var c := size * 0.5
			draw_circle(c, minf(size.x, size.y) * 0.28, Color(CodexStyle.GOLD, 0.05))
			CodexStyle.draw_diamond(self, c, minf(size.x, size.y) * 0.08, Color(CodexStyle.GOLD_LO, 0.8))
		draw_rect(r, Color(CodexStyle.GOLD, 0.9), false, 1.0)
		draw_rect(r.grow(-2.5), Color(CodexStyle.GOLD_LO, 0.7), false, 0.6)
		for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			CodexStyle.draw_diamond(self, p, 2.4, CodexStyle.GOLD_HI, Color(0, 0, 0, 0.6))
