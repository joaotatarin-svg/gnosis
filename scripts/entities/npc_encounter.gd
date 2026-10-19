extends Node2D
class_name NpcEncounter
## Encontro com um personagem da história (Soter ou Velkar). Aproximou →
## diálogo; Soter oferece bênção (escolha); Velkar dá faíscas e a verdade.
## kind: "soter" | "velkar" · meeting: índice do encontro de Soter (0..2)

var kind: String = "soter"
var meeting: int = 0
var triggered: bool = false
var _art: CharacterArt

# SOTER CONCEDE A LEVEZA (Onda 6, pedido do João: o pulo duplo vem do "Jesus" do
# jogo, numa cena). 1º encontro: depois da bênção escolhida, as mãos nos ombros
# dela, luz, ela fica leve (Progression.grant_double_jump) e um DEGRAU DE LUZ
# aparece no alto — só se alcança com o pulo duplo. Soter espera ela subir
# (mini-desafio com prompt curto) e só então parte.
const LEDGE_UP := 116.0          # topo do degrau acima do chão (pulo simples 81 px; duplo ~136 — combate6)
const LEDGE_DX := 130.0          # à frente de Soter
const LEDGE_W := 72.0
const LEDGE_WAIT := 45.0         # s até Soter partir mesmo sem ela subir
var _player: Node2D
var _ledge: _LightStep
var _glow_fx: Array = []


func _ready() -> void:
	_art = CharacterArt.new()
	_art.set_profile(Bestiary.soter_profile() if kind == "soter" else Bestiary.velkar_profile())
	_art.set_anim("idle")
	add_child(_art)

	if kind == "soter":
		# Facho de luz sutil sobre ele
		var beam := Polygon2D.new()
		beam.color = Color(1.0, 0.95, 0.7, 0.08)
		beam.polygon = PackedVector2Array([Vector2(-26, -160), Vector2(26, -160), Vector2(16, 26), Vector2(-16, 26)])
		add_child(beam)
		move_child(beam, 0)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 56.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if triggered or not body.is_in_group("player"):
		return
	triggered = true
	# Legendas de caminhada que ainda esperavam a calma (ex.: "Há alguém de branco
	# mais adiante...") ficariam velhas depois do encontro: saem da fila.
	var cap = Gnosis.get("_caption")
	if cap != null and is_instance_valid(cap) and cap.has_method("clear"):
		cap.call("clear")
	# O encontro anima COM o mundo pausado pela caixa (fala, abençoa, ajoelha).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if kind == "soter":
		_do_soter(body)
	else:
		_do_velkar()


## A pose de quem fala (atlas do GPT — docs/onda2/ARTE_GPT.md §NPCs): ele fala
## (`talk`) nas próprias falas e escuta (`idle`) nas da Sophia; o Velkar se
## ajoelha quando conta do pai e se ergue para dar as faíscas.
func _on_line(_index: int, line: Dictionary) -> void:
	if _art == null:
		return
	var who := String(line.get("speaker", ""))
	var text := String(line.get("text", ""))
	if kind == "velkar":
		if text.begins_with("Lá em cima não há tirano"):
			_art.set_anim("kneel")
			return
		if _art.anim_state == "kneel":
			if text.begins_with("Quando chegares nele"):
				_art.set_anim("rise")          # levanta (0,4 s) e volta a falar
				var t := create_tween()
				t.tween_interval(0.5)
				t.tween_callback(_art.set_anim.bind("talk"))
			return                             # ajoelhado durante "Tu choras por ele?" e "Era meu pai."
	if who.to_lower().contains(kind):
		_art.set_anim("talk")
	else:
		_art.set_anim("idle")


func _do_soter(player: Node) -> void:
	var d := _dialog(Narrative.soter_meeting(meeting), Narrative.soter_blessings(), "soter")
	d.line_shown.connect(_on_line)
	_art.set_anim("talk")
	var choice: int = await d.choice_made
	# A bênção: as mãos sobem antes da luz (bless, 2 quadros).
	_art.set_anim("bless")
	await get_tree().create_timer(0.55, true, false, true).timeout
	if not is_inside_tree():
		return
	match choice:
		0:
			if player.health:
				player.health.heal(player.health.max_health)
		1:
			# O presente respeita o selo de nível da arma (Progressão); selada ou
			# no máximo, vêm faíscas no lugar — entregues como orbes (R6).
			if not Progression.gift_weapon_level():
				Progression.add_orbs(120)
				SparkOrb.burst(get_parent(), global_position + Vector2(0, -30), 9)
		2:
			Progression.bonus_max_health += 25
			Progression.stats_changed.emit()
			if player.health:
				player.health.max_health += 25
				player.health.heal(25)
	# 1º encontro: a LEVEZA (pulo duplo) e o degrau de luz; ele espera ela subir.
	if meeting == 0 and not _has_double_jump():
		await _soter_lightness(player)
		if not is_inside_tree():
			return
	# Soter parte em luz.
	AoeNova.spawn(get_parent(), global_position + Vector2(0, -10), 0, 60.0, Color(1.0, 0.95, 0.7))
	_art.set_anim("fade")                    # vira as costas e se desfaz em luz
	var t := create_tween()
	t.tween_interval(0.3)
	t.tween_property(self, "modulate:a", 0.0, 0.8)
	# A Voz volta a falar só depois que ele some — ela não o viu (o Cego não o vê).
	var n := meeting
	t.tween_callback(func() -> void: Gnosis.captions(Narrative.after_soter(n)))
	t.tween_callback(queue_free)


## A cena da leveza (Narrative.soter_lightness): fala 0 = as mãos (a luz sobe
## nela), fala 1 = rubrica (ela fica leve: o pulo duplo é concedido), fala 4 =
## "Vê aquela luz no alto?" (o degrau acende). Depois: prompt curto no HUD e o
## mini-desafio — Soter espera até ela pisar no degrau (ou LEDGE_WAIT s).
func _soter_lightness(player: Node) -> void:
	_player = player as Node2D
	var d := _dialog(Narrative.soter_lightness(), [], "soter")
	d.line_shown.connect(_on_lightness_line)
	_art.set_anim("lift")
	await d.finished
	if not is_inside_tree():
		return
	_grant_double_jump()
	if _ledge == null:
		_spawn_ledge()
	_sophia_light(false)
	_sophia_action("")                         # a pose de cena solta: ela anda
	_art.set_anim("idle")
	# RESPIRO (R21): um instante de silêncio antes do prompt — a cena assenta, o
	# jogador olha o degrau aceso antes de a dica aparecer.
	await get_tree().create_timer(0.9, true, false, true).timeout
	if not is_inside_tree():
		return
	_hint_double_jump()
	var waited := 0.0
	var done := false
	while is_inside_tree() and waited < LEDGE_WAIT:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		waited += get_process_delta_time()
		if _on_ledge():
			done = true
			break
		# Ela seguiu caminho sem subir: ele não a prende.
		if _player != null and is_instance_valid(_player) and absf(_player.global_position.x - global_position.x) > 520.0:
			break
	if not is_inside_tree():
		return
	if done:
		Audio.play_sfx("stele_unlock", -1.0, -4.0)
		# As 30 faíscas entram como TODAS as outras (R6): creditadas e entregues em
		# orbes que voam do degrau até ela, com a nota que sobe em escala.
		Progression.add_orbs(30)
		if _ledge != null and is_instance_valid(_ledge):
			_ledge.reward()
			SparkOrb.burst(get_parent(), _ledge.global_position + Vector2(0, -20), 9)
		Gnosis.captions(Narrative.soter_lightness_done())
		_art.set_anim("rest")                  # mãos juntas, em paz — antes de partir
		await get_tree().create_timer(1.6, true, false, true).timeout
	else:
		_art.set_anim("rest")
		await get_tree().create_timer(0.8, true, false, true).timeout
	_clear_glow()


func _on_lightness_line(index: int, _line: Dictionary) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	match index:
		0:
			# As mãos dele se erguem (lift); ela olha para ele, cajado em pé
			# (soter_look); a coluna de luz morna desce sobre ela (bless_light).
			_art.set_anim("lift")
			_sophia_action("soter_look")
			# R9: a música, já baixa no encontro, quase some — o dom (`soter_gift`,
			# tocado pelo Áudio quando o pulo duplo é concedido, na fala seguinte)
			# entra no silêncio. A Staging solta o abafamento ao fim da cena.
			Audio.duck_music(600.0, -24.0)
			if not _sophia_light(true):
				var col := _glow_sprite("glow", Vector2(0.9, 2.6), Color(1.0, 0.92, 0.65, 0.0))
				col.global_position = _player.global_position + Vector2(0, -40)
				create_tween().tween_property(col, "modulate:a", 0.55, 0.9)
		1:
			# Leve: ela sobe um palmo e desce devagar (pousa: soter_land); a luz
			# se recolhe quando ela toca o chão de novo.
			_grant_double_jump()
			var land := create_tween()
			land.tween_interval(0.6)
			land.tween_callback(_sophia_action.bind("soter_land"))
			land.tween_interval(1.2)
			land.tween_callback(_sophia_light.bind(false))
			var halo := _glow_sprite("halo", Vector2.ONE * 0.6, Color(1.0, 0.9, 0.6, 0.9))
			halo.global_position = _player.global_position + Vector2(0, 10)
			var t := create_tween()
			t.tween_property(halo, "scale", Vector2.ONE * 2.4, 1.0).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(halo, "modulate:a", 0.0, 1.0)
			var vis = _player.get("visual")
			if vis is Node2D:
				var v := vis as Node2D
				var y0 := v.position.y
				var lift := create_tween()
				lift.tween_property(v, "position:y", y0 - 7.0, 0.6).set_trans(Tween.TRANS_SINE)
				lift.tween_property(v, "position:y", y0, 1.2).set_trans(Tween.TRANS_SINE)
		2:
			_art.set_anim("talk")
		3:
			# "(Leve. Como antes de cair.)" — ela agradece com a cabeça.
			_sophia_action("soter_bow")
			_art.set_anim("idle")
		4:
			# "Vê aquela luz no alto?" — ele estende a mão para o degrau que acende.
			_art.set_anim("offer")
			_spawn_ledge()


## Pose de CENA da Sophia (arte, Fila 9): "soter_look" / "soter_land" /
## "soter_bow" ficam paradas até `stop_action()` ou ela se mexer; "" solta.
func _sophia_action(action: String) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var vis = _player.get("visual")
	if not (vis is CharacterArt):
		return
	var art := vis as CharacterArt
	if action == "":
		if art.has_method("stop_action"):
			art.stop_action()
		return
	if art.has_method("has_action") and not art.has_action(action):
		return
	art.play_action(action)


## Coluna de luz sobre ela (FX da arte: `bless_light`, anima com o mundo pausado).
## Devolve false se o Visual não tiver o efeito (cai no sprite antigo).
func _sophia_light(on: bool) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var vis = _player.get("visual")
	if vis is Object and (vis as Object).has_method("bless_light"):
		(vis as Object).call("bless_light", on)
		return true
	return false


## Concede o pulo duplo (contrato da Onda 6: Progression.grant_double_jump()).
## Sem o método ainda (branch sem a progressão nova): a flag `double_jump`, que
## o player.gd do combate6 também lê.
func _grant_double_jump() -> void:
	if _has_double_jump():
		return
	if Progression.has_method("grant_double_jump"):
		Progression.call("grant_double_jump")
	elif "double_jump" in Progression:
		Progression.set("double_jump", true)
	else:
		push_warning("Soter: Progression sem grant_double_jump()/double_jump — pulo duplo não concedido")


func _has_double_jump() -> bool:
	if Progression.has_method("has_double_jump"):
		return bool(Progression.call("has_double_jump"))
	return bool(Progression.get("double_jump")) if "double_jump" in Progression else false


func _hint_double_jump() -> void:
	Staging.hint_now([{"keys": ["jump", "jump"], "text": Narrative.hint_double_jump()}])


## O degrau de luz: plataforma de mão única no alto, à frente de Soter (para o
## lado que tem chão), que fica na tela como lugar de treino.
func _spawn_ledge() -> void:
	if _ledge != null and is_instance_valid(_ledge):
		return
	var lv := get_parent()
	if lv == null:
		return
	var side := 1.0
	if "_end_x" in lv and global_position.x + LEDGE_DX + 80.0 > float(lv.get("_end_x")):
		side = -1.0
	_ledge = _LightStep.new()
	_ledge.width = LEDGE_W
	lv.add_child(_ledge)
	_ledge.global_position = Vector2(global_position.x + side * LEDGE_DX, Level.GROUND_Y - LEDGE_UP)


func _on_ledge() -> bool:
	if _ledge == null or not is_instance_valid(_ledge) or _player == null or not is_instance_valid(_player):
		return false
	if not (_player is CharacterBody2D) or not (_player as CharacterBody2D).is_on_floor():
		return false
	var feet := _player.global_position.y + 12.0
	var near := absf(_player.global_position.x - _ledge.global_position.x) < LEDGE_W * 0.5 + 6.0
	return near and feet < _ledge.global_position.y + 4.0


func _glow_sprite(tex: String, sc: Vector2, col: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = VfxLibrary.tex(tex)
	s.material = VfxLibrary._additive()
	s.scale = sc
	s.modulate = col
	s.top_level = true
	s.z_index = 25
	add_child(s)
	_glow_fx.append(s)
	return s


func _clear_glow() -> void:
	_sophia_light(false)
	for s in _glow_fx:
		if is_instance_valid(s):
			var t := create_tween()
			t.tween_property(s, "modulate:a", 0.0, 0.6)
			t.tween_callback(s.queue_free)
	_glow_fx.clear()


## Diálogo pela encenação do Level (cues como `wait_2s`/`chime`, música
## baixa) quando houver; senão, a caixa pura.
func _dialog(lines: Array, choices: Array, scene: String) -> DialogueBox:
	var lv := get_parent()
	if lv != null and lv.has_method("stage"):
		return lv.call("stage").play(lines, choices, scene)
	return DialogueBox.play(lines, choices)


func _do_velkar() -> void:
	# Termina numa escolha sem efeito mecânico ("Vem comigo" / "Fica em paz").
	# Pela encenação (cena "velkar"): a câmera sobe os dois acima da caixa.
	var d := _dialog(Narrative.velkar_meeting(), Narrative.velkar_choices(), "velkar")
	d.line_shown.connect(_on_line)
	_art.set_anim("talk")
	var choice: int = await d.choice_made
	# A despedida: a mão no peito, sem voltar a falar.
	_art.set_anim("farewell")
	await _dialog(Narrative.velkar_farewell(choice), [], "velkar").finished
	if not is_inside_tree():
		return
	Progression.add_orbs(150)
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -20), Color(0.75, 0.6, 0.5))
	# Velkar fica — mancando pro canto dele (walk, devagar), e escurece um pouco.
	_art.set_anim("walk")
	var t := create_tween()
	t.tween_property(self, "global_position:x", global_position.x + 46.0, 2.6)
	t.parallel().tween_property(self, "modulate", Color(0.7, 0.7, 0.7, 1.0), 2.6)
	t.tween_callback(_art.set_anim.bind("idle"))
	t.tween_callback(func() -> void: process_mode = Node.PROCESS_MODE_INHERIT)


## Ouro indica encontro, nunca hostilidade. A sombra ancora os pés no palco.
func _draw() -> void:
	draw_set_transform(Vector2(0,26),0,Vector2(1,0.25))
	draw_circle(Vector2.ZERO,21,Color(0,0,0,0.26))
	draw_arc(Vector2.ZERO,25,0,TAU,48,Color(0.77,0.65,0.42,0.4),1,true)
	draw_set_transform(Vector2.ZERO)
	var col := Color("e0c48c") if kind == "soter" else Color("aa9890")
	draw_polyline(PackedVector2Array([Vector2(-3,-40),Vector2(0,-44),Vector2(3,-40),Vector2(0,-36),Vector2(-3,-40)]),col,0.7,true)


## Degrau de luz (o mini-desafio do pulo duplo): plataforma de mão única com
## uma laje dourada que pulsa e um brilho no alto (a "luz" que Soter aponta).
## Fica na tela depois que ele parte (lugar de treino).
class _LightStep extends StaticBody2D:
	var width: float = 72.0
	var _t: float = 0.0
	var _glow: Node2D
	var _flash: float = 0.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(width, 10)
		col.shape = rect
		col.position = Vector2(0, 5)
		col.one_way_collision = true
		add_child(col)
		z_index = -1
		process_mode = Node.PROCESS_MODE_ALWAYS
		_glow = Node2D.new()
		_glow.material = VfxLibrary._additive()
		add_child(_glow)
		_glow.draw.connect(_draw_glow)
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.8)

	func reward() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(0.0, _flash - delta * 0.8)
		queue_redraw()
		_glow.queue_redraw()

	func _draw() -> void:
		var hw := width * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(-hw, 0), Vector2(hw, 0), Vector2(hw - 6, 7), Vector2(-hw + 6, 7)]),
			Color(0.95, 0.85, 0.55, 0.85))
		draw_line(Vector2(-hw, 0), Vector2(hw, 0), Color(1, 0.97, 0.85, 1), 1.5, true)

	func _draw_glow() -> void:
		var p := 0.75 + 0.25 * sin(_t * 3.0)
		var hw := width * 0.5
		_glow.draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.3))
		_glow.draw_circle(Vector2.ZERO, hw + 14.0, Color(1.0, 0.85, 0.5, 0.22 * p + 0.3 * _flash))
		_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# a luz no alto (o que Soter aponta), um palmo acima da laje
		_glow.draw_circle(Vector2(0, -26), 7.0 + 2.0 * p, Color(1.0, 0.92, 0.7, 0.35 * p))
		_glow.draw_circle(Vector2(0, -26), 2.5, Color(1, 1, 0.9, 0.9))
