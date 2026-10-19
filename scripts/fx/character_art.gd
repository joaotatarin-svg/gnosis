extends Node2D
class_name CharacterArt
## MOTOR DE ARTE v2 — desenha e ANIMA um personagem por código a partir de um
## ArtProfile. A edição Codex usa PaintedLibrary/PNG; o desenho antigo é fallback.
##
## Corpos:
##  - HUMANOID / BRUTE / COLOSSUS: bípedes articulados (pernas, braços, arma NA
##    MÃO: o cajado/lâmina acompanha o braço e dá leitura ao golpe).
##  - WRAITH: espectro flutuante com capuz e farrapos que ondulam.
##  - BEAST: quadrúpede de verdade (4 patas galopando, cabeça à frente, cauda).
## Estados (set_anim): idle, walk, charge, windup, windup_heavy, windup_cast,
##  attack, attack_heavy, attack_up (lançador), attack_air, attack_dive, cast,
##  block, dodge, jump, fall, hurt, dead.
## `damage_ratio` (0..1) faz rachaduras de luz aparecerem no corpo ferido.
## `gib_parts()` devolve as peças do corpo pro desmembramento (Gib).

@export var profile: ArtProfile

const STEEL := Color(0.80, 0.83, 0.92)
const GROUND_Y := 24.0            # linha do chão em unidades do corpo (pés)

var anim_state: String = "idle"
var anim_time: float = 0.0
var _interim_checked: bool = false
var drawn_gait: bool = true       # Sophia: largada/freada desenhadas (S18) ao começar/parar de correr
var damage_ratio: float = 0.0     # 0 = inteiro · 1 = quase morto (rachaduras)
var _rig_draws: Array = []        # buffer de desenho do rig (tinta em 2 passes)
var painted: Dictionary = {}
var boss_puppet: BossPuppet
var pose_progress: float = -1.0
var motion_stride: float = 1.0
var motion_fury: float = 1.0
var texture: Texture2D = null     # se setado, usa a arte ilustrada no lugar do procedural
var texture_height: float = 64.0  # altura de exibição do sprite (px)

# --- Rig cutout: PNG ilustrado em PARTES, animado por código ---
# [{name, tex, off:Vector2, pivot:Vector2, z:int}] ordenado por z. Sem partes = procedural.
var rig: Array = []
var rig_scale: float = 0.06
var rig_foot: Vector2 = Vector2.ZERO
const RIG_INK := Color(0.10, 0.07, 0.12, 1.0)   # contorno de tinta ao redor do PNG

# --- pose do frame (calculada em _compute_pose) ---
var _bob := 0.0
var _lean := 0.0
var _leg_f := 0.0
var _leg_b := 0.0
var _arm_f := 0.0
var _arm_b := 0.0
var _wpn := 0.0          # ângulo da arma: 0 = pra cima, + = gira pra frente/baixo
var _wpn_glow := 0.0     # brilho do orbe do cajado (magia / golpe forte)
var _crouch := 0.0       # agachar (esquiva, bloqueio)
var _dead := 0.0         # 0..1 corpo caindo


func set_profile(p: ArtProfile) -> void:
	profile = p
	painted = PaintedLibrary.character(p, _host_ctx())
	material = _flex_material()
	# Pinturas grandes exibidas a ~1/4: mipmap evita cintilar a borda (o
	# BossPuppet, filho deste nó, herda o filtro).
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if is_instance_valid(boss_puppet):
		remove_child(boss_puppet)
		boss_puppet.queue_free()
		boss_puppet = null
	if painted.has("puppet"):
		boss_puppet = BossPuppet.new()
		add_child(boss_puppet)
		boss_puppet.configure(painted)
		var h: float = 190.0 if int(painted.puppet) == 8 else profile.height * 1.3
		boss_puppet.scale = Vector2(-1 if painted.flip else 1,1) * h / 100.0
		boss_puppet.position.y = GROUND_Y * profile.height / 44.0
	# Chefe com QUADROS DESENHADOS: o CharacterArt toca os quadros e o boneco
	# fica de reserva (existe, mas não anima nem aparece).
	var fname: String = String(painted.get("frames", ""))
	if fname != "" and not fname.contains("/"):
		fname = "bosses/" + fname
	_boss_db = frame_db(fname) if fname != "" else {}
	# Adormecido: dorme enquanto o olho está apagado; o sleeper.gd troca o
	# perfil (olho aceso) ao despertar → toca acordar → de pé → reverência.
	var was_asleep: bool = _npc_asleep
	_npc_asleep = p.painted_id == "sleeper" and p.eye.r < 0.8
	if was_asleep and not _npc_asleep:
		_npc_wake_t = 0.0
	_flex_material().shader = load(BOSS_SHADER if has_boss_frames() else FLEX_SHADER)
	_bsp = Vector2.ZERO
	_bsv = Vector2.ZERO
	queue_redraw()


## Liga a arte ilustrada (PNG). Enquanto houver textura, o procedural é ignorado
## mas as animações de nó (squash/flash/facing) e o bob continuam valendo.
func set_texture(tex: Texture2D, disp_height: float = 64.0) -> void:
	texture = tex
	texture_height = disp_height
	queue_redraw()


## Liga o rig cutout a partir de um rig.json (ver assets/characters/<id>/rig.json):
## {"source":[w,h], "foot_center":[x,y], "parts":[{file,name,off,pivot,z}]}.
## `disp_height` = altura de exibição do personagem inteiro (px de mundo).
func set_rig(json_path: String, disp_height: float) -> bool:
	rig.clear()
	if not FileAccess.file_exists(json_path):
		return false
	var f := FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var src: Array = data.get("source", [1, 1])
	var fc: Array = data.get("foot_center", [0, 0])
	rig_foot = Vector2(float(fc[0]), float(fc[1]))
	rig_scale = disp_height / maxf(1.0, float(src[1]))
	for p in data.get("parts", []):
		var tex = load(p.file)
		if tex == null:
			continue
		rig.append({
			"name": String(p.name), "tex": tex,
			"off": Vector2(float(p.off[0]), float(p.off[1])),
			"pivot": Vector2(float(p.pivot[0]), float(p.pivot[1])),
			"z": int(p.get("z", 0)),
		})
	rig.sort_custom(func(a, b): return a.z < b.z)
	queue_redraw()
	return not rig.is_empty()


## Contexto do Enemy dono deste desenho (tipo do Bestiary e Campeão) para o
## PaintedLibrary escolher a arte própria. Sobe até 2 níveis (o Rim do Enemy
## põe o desenho dentro de um CanvasGroup).
func _host_ctx() -> Dictionary:
	var n: Node = get_parent()
	for _i in 2:
		if n == null:
			break
		var t = n.get("type_id")
		if t != null:
			var champ = n.get("is_champion")
			return {"type": String(t), "champion": champ == true}
		n = n.get_parent()
	return {}


## Tem ARTE PRÓPRIA (Fila 9: voadores, cornudo, fantasma, acólito, campeões)?
## Quem tinge o interino (tinta do tipo, graduação do Campeão) deve pular.
func has_own_art() -> bool:
	return painted.get("own_art", false) and has_boss_frames()


## A arte própria já vem com a cor certa: desfaz a tinta e a graduação de cor
## que o Enemy aplicou para disfarçar o interino (mantém só a transparência).
func _clear_interim_tint() -> void:
	if not has_own_art():
		return
	self_modulate = Color(1, 1, 1, self_modulate.a)
	var g: Node = get_parent()
	if g is CanvasGroup and (g as CanvasGroup).material is ShaderMaterial:
		var m: ShaderMaterial = (g as CanvasGroup).material
		if m.get_shader_parameter("grade_sat") != null:
			m.set_shader_parameter("grade_hue", 0.0)
			m.set_shader_parameter("grade_sat", 1.0)
			m.set_shader_parameter("grade_tint", Color(1, 1, 1, 1))


func has_rig() -> bool:
	return not rig.is_empty()


func set_anim(state: String) -> void:
	if state != anim_state:
		# pouso: saindo da queda/mergulho pro chão segura o quadro agachado
		if anim_state in ["fall", "attack_dive"] and state in ["idle", "walk"]:
			_land_t = 0.09
		# renascer (checkpoint): saindo da morte, levanta apoiada no cajado
		if anim_state == "dead" and state in ["idle", "walk"]:
			_rise_t = 0.45
		# RECUPERAÇÃO desenhada (S15): voltando pro parado depois de um golpe,
		# magia, mergulho, esquiva ou dano, toca o quadro de "volta" daquela ação
		var rec: String = ""
		if state == "idle" and painted.get("hero", false):
			match anim_state:
				"attack": rec = "rec_light%d" % clampi(combo_step if combo_step > 0 else 1, 1, 3)
				"attack_heavy", "attack_up": rec = "rec_heavy"
				"cast": rec = "rec_cast"
				"attack_air", "attack_dive", "fall": rec = "rec_air"
				"dodge": rec = "rec_dodge"
				"hurt": rec = "rec_hurt"
		# ARRANCADA / FREADA desenhadas (S18): parado → correndo toca a largada;
		# correndo (mais que um toque) → parado toca a derrapagem
		var gait: String = ""
		if drawn_gait and painted.get("hero", false) and rec == "":
			if anim_state in ["idle", "recover"] and state == "walk":
				gait = "start_run"
			elif anim_state == "walk" and state == "idle" and anim_time > 0.3:
				gait = "stop_run"
		anim_state = state
		anim_time = 0.0
		if rec != "":
			play_action(rec)
		elif gait != "":
			play_action(gait)
		# giro do manto na esquiva (contrato com o Áudio: some se não houver arquivo)
		if state == "dodge" and painted.get("hero", false) and is_visible_in_tree():
			Audio.play_sfx("cloth", 0.1, -4.0)


func _process(delta: float) -> void:
	if not _interim_checked:
		_interim_checked = true
		_clear_interim_tint()      # depois do _ready do Enemy (tinta + Rim já postos)
	anim_time += delta
	_tick_visual(delta)
	if is_instance_valid(boss_puppet):
		var framed: bool = has_boss_frames()
		boss_puppet.visible = texture == null and not framed
		if not framed:
			boss_puppet.modulate = self_modulate
			boss_puppet.drive(anim_state,anim_time,delta,pose_progress,motion_stride,motion_fury)
	queue_redraw()


func _ink() -> Color:
	return Color(profile.primary.r * 0.22, profile.primary.g * 0.22, profile.primary.b * 0.22, 1.0)


func _is_biped() -> bool:
	return profile.body == ArtProfile.Body.HUMANOID or profile.body == ArtProfile.Body.BRUTE or profile.body == ArtProfile.Body.COLOSSUS


# =========================================================================
# POSE
# =========================================================================

func _compute_pose() -> void:
	var t := anim_time
	_bob = 0.0; _lean = 0.0; _leg_f = 0.0; _leg_b = 0.0; _arm_f = 0.0; _arm_b = 0.0
	_wpn = 0.08; _wpn_glow = 0.0; _crouch = 0.0; _dead = 0.0
	match anim_state:
		"walk":
			var ph := sin(t * 9.0)
			_leg_f = ph * 0.55
			_leg_b = -ph * 0.55
			_arm_f = -ph * 0.35
			_arm_b = ph * 0.4
			_bob = -absf(sin(t * 9.0)) * 2.2
			_lean = 0.08
			_wpn = 0.22 + ph * 0.05
		"charge":
			# investida: corpo jogado pra frente, pernas em galope rápido
			var ph := sin(t * 14.0)
			_leg_f = ph * 0.7
			_leg_b = -ph * 0.7
			_arm_f = -0.9
			_arm_b = -0.9
			_bob = -absf(ph) * 2.0
			_lean = 0.38
			_wpn = 1.3
		"windup":
			# braço puxado pra trás, tremendo (o telegrafo)
			var tr := sin(t * 40.0) * 0.04
			_arm_f = -0.9 + tr
			_arm_b = 0.4
			_wpn = -1.4 + tr
			_lean = -0.10
			_leg_f = 0.18
			_leg_b = -0.1
		"windup_heavy":
			# arma erguida acima da cabeça, segurando
			var tr := sin(t * 34.0) * 0.05
			_arm_f = -2.4 + tr
			_arm_b = -2.0 + tr
			_wpn = -2.7 + tr
			_lean = -0.2
			_bob = -2.0
			_leg_f = 0.3
			_leg_b = -0.2
		"windup_cast":
			# cajado erguido à frente, orbe carregando
			_arm_f = -1.5
			_arm_b = -0.3
			_wpn = -0.35
			_wpn_glow = clampf(t * 2.0, 0.0, 1.0)
			_lean = -0.06
		"attack":
			# corte rápido: braço vem de trás e VARRE pra frente
			var e := ease(clampf(t / 0.22, 0.0, 1.0), 2.2)
			_arm_f = lerpf(-0.8, 1.5, e)
			_wpn = lerpf(-1.3, 2.1, e)
			_arm_b = -0.3
			_leg_f = 0.25
			_leg_b = -0.15
			_lean = 0.12
		"attack_heavy":
			# pesado: carrega acima da cabeça e DESCE (overhead), duas mãos
			var ph := clampf(t / 0.5, 0.0, 1.0)
			var e := ease(ph, 3.2)
			_arm_f = lerpf(-2.4, 1.3, e)
			_arm_b = lerpf(-2.0, 0.7, e)
			_wpn = lerpf(-2.7, 1.9, e)
			_lean = lerpf(-0.16, 0.28, ph)
			_bob = -2.0 * (1.0 - ph)
			_leg_f = 0.3
			_leg_b = -0.2
			_wpn_glow = 1.0 - ph
		"attack_up":
			# lançador: varredura de baixo pra cima
			var e := ease(clampf(t / 0.28, 0.0, 1.0), 2.0)
			_arm_f = lerpf(1.4, -1.7, e)
			_wpn = lerpf(2.3, -1.0, e)
			_arm_b = 0.4
			_lean = lerpf(0.2, -0.14, e)
			_bob = -3.5 * e
			_leg_f = 0.35
			_leg_b = -0.25
		"attack_air":
			# giro no ar: a arma dá uma volta inteira
			var ph := clampf(t / 0.32, 0.0, 1.0)
			_wpn = -1.5 + TAU * ph
			_arm_f = lerpf(-1.2, 1.6, ph)
			_arm_b = -0.6
			_leg_f = 0.6
			_leg_b = -0.4
			_lean = 0.15
		"attack_dive":
			# queda: arma apontada pra baixo à frente, pernas erguidas
			_arm_f = 1.4
			_arm_b = -0.6
			_wpn = 2.5
			_lean = 0.4
			_leg_f = -0.5
			_leg_b = -0.3
		"cast":
			var e := ease(clampf(t / 0.3, 0.0, 1.0), 1.8)
			_arm_f = lerpf(0.2, -1.9, e)
			_wpn = lerpf(0.1, -0.55, e)
			_wpn_glow = 1.0
			_arm_b = -0.4
			_lean = -0.06
		"block":
			_arm_f = 1.25
			_arm_b = 0.95
			_wpn = 1.57
			_crouch = 0.14
			_lean = -0.06
		"dodge":
			# rolamento: corpo joga pra frente e encolhe
			_lean = 0.65
			_crouch = 0.3
			_leg_f = 0.8
			_leg_b = 0.3
			_arm_f = 0.9
			_arm_b = -0.6
			_wpn = 0.8
			_bob = 4.0
		"jump":
			_leg_f = 0.55
			_leg_b = -0.3
			_arm_f = -0.5
			_arm_b = -0.7
			_wpn = -0.3
			_lean = 0.05
		"fall":
			_leg_f = 0.2
			_leg_b = -0.5
			_arm_f = 1.0
			_arm_b = -1.0
			_wpn = 0.35
		"hurt":
			_lean = -0.2
			_arm_f = 0.7
			_arm_b = 0.6
			_bob = -1.0
			_wpn = 0.95
			_leg_f = 0.2
			_leg_b = -0.3
		"dead":
			_dead = ease(clampf(t / 0.45, 0.0, 1.0), 0.6)
			_lean = -1.45 * _dead
			_bob = 19.0 * _dead
			_leg_f = 0.5 * _dead
			_leg_b = -0.4 * _dead
			_arm_f = 0.9 * _dead
			_arm_b = -0.7 * _dead
			_wpn = 1.2 * _dead
		_:  # idle
			_bob = sin(t * 2.4) * 0.7
			_leg_f = 0.04
			_leg_b = -0.04
			_arm_f = 0.1
			_arm_b = -0.1
			_wpn = 0.08 + sin(t * 2.4) * 0.03


# =========================================================================
# DRAW
# =========================================================================

func _draw() -> void:
	if profile == null:
		return
	if is_instance_valid(boss_puppet) and texture == null and not has_boss_frames():
		return
	if _shattered:
		return                                # morte encenada: o corpo virou cacos
	var s := profile.height / 44.0
	_compute_pose()

	# Transform do corpo: bob + inclinação + agachar (mantendo os pés no chão).
	var sy := 1.0 - _crouch
	draw_set_transform(Vector2(0, _bob * s + GROUND_Y * s * _crouch), _lean, Vector2(1.0, sy))

	if not painted.is_empty() and texture == null:
		_draw_painted(s)
		return

	# Rig cutout (PNG em partes): anima as peças e ignora o procedural.
	if not rig.is_empty():
		_draw_rig(s)
		return

	# Arte ilustrada (PNG): desenha o sprite e ignora o procedural.
	if texture != null:
		var th := texture_height
		var tw := th * float(texture.get_width()) / float(texture.get_height())
		draw_texture_rect(texture, Rect2(-tw * 0.5, GROUND_Y - th, tw, th), false)
		return

	# camadas de trás
	if profile.has("aura"): _aura(s)
	if profile.has("wings"): _wings(s)
	if profile.has("cape"): _cape(s)
	if profile.has("rot"): _rot(s)
	if profile.has("hair") and not profile.has("hero"): _hair_back(s)

	match profile.body:
		ArtProfile.Body.WRAITH: _draw_wraith(s)
		ArtProfile.Body.BEAST: _draw_beast(s)
		_: _draw_biped(s)

	# adereços da cabeça (comuns)
	if profile.has("spikes") and _is_biped(): _spikes(s)
	if profile.has("helmet") and not profile.has("hero"): _helmet(s)
	if profile.has("horns"): _horns(s)
	if profile.has("crown") and not profile.has("hero"): _crown(s)
	if profile.height >= 70.0:
		_codex_regalia(s)
	# assinaturas dos Arcontes
	if profile.has("eyelid"): _eyelid(s)
	if profile.has("sewn"): _sewn(s)
	if profile.has("maw"): _maw(s)
	if profile.has("chains"): _chains(s)
	if profile.has("mirror"): _mirror(s)
	if profile.has("bigcrown"): _bigcrown(s)
	if profile.has("cracked"): _cracked_face(s)
	# ferido: luz vazando pelas rachaduras
	if damage_ratio > 0.45:
		_cracks(s)


# =========================================================================
# RIG CUTOUT (PNG em partes)
# =========================================================================

## Desenha o rig: corpo inclina, cabeça respira, saia balança, cajado GIRA na
## mão conforme a pose (_wpn). Cada peça gira em torno do próprio pivô.
## Contorno de tinta (4 cópias escuras deslocadas) pra casar com o mundo vetorial.
func _draw_rig(s: float) -> void:
	var t := anim_time
	var body := Transform2D(_lean * 0.6, Vector2(0, _bob * s))
	if profile != null and profile.has("aura"):
		draw_set_transform_matrix(body)
		_aura(s)
	var tip_world := Vector2.ZERO
	var has_staff := false
	for part in rig:
		var ang := 0.0
		var extra := Vector2.ZERO
		match part.name:
			"cajado":
				ang = clampf(_wpn * 0.75, -2.2, 2.2)
				has_staff = true
			"saia":
				if anim_state == "walk" or anim_state == "charge":
					ang = sin(t * 9.0) * 0.045
				elif anim_state == "dodge":
					ang = 0.18
				elif anim_state == "dead":
					ang = 0.0
				else:
					ang = sin(t * 2.4) * 0.012
			"cabeca":
				ang = _lean * 0.35 + sin(t * 2.4) * 0.015
				extra = Vector2(0, sin(t * 2.4 + 0.6) * 0.5 * s)
				if anim_state == "hurt":
					ang -= 0.18
			_:
				ang = _lean * 0.25
		var pv: Vector2 = (part.pivot - rig_foot) * rig_scale + Vector2(0, GROUND_Y * s)
		var xf := Transform2D(ang, pv + extra).scaled_local(Vector2(rig_scale, rig_scale))
		var full := body * xf
		_rig_draws.append([full, part])
		if part.name == "cajado":
			# ponta do cajado (em coords da imagem) → mundo, pra desenhar o orbe
			tip_world = full * (Vector2(48.0, 28.0) - part.pivot)
	# PASSE 1: toda a tinta primeiro; PASSE 2: as cores por cima. (Se a tinta de
	# uma peça vem depois da cor da anterior, a borda dura do recorte vira uma
	# BARRA preta atravessando o corpo — visível no menu, em escala grande.)
	var px := 1.4 / rig_scale
	for e in _rig_draws:
		draw_set_transform_matrix(e[0])
		var part_i: Dictionary = e[1]
		var oi: Vector2 = part_i.off - part_i.pivot
		for d in [Vector2(px, 0), Vector2(-px, 0), Vector2(0, px), Vector2(0, -px)]:
			draw_texture(part_i.tex, oi + d, RIG_INK)
	for e in _rig_draws:
		draw_set_transform_matrix(e[0])
		var part_c: Dictionary = e[1]
		draw_texture(part_c.tex, part_c.off - part_c.pivot)
	_rig_draws.clear()
	# orbe de luz na ponta do cajado (a faísca) — cresce ao conjurar/golpe forte
	if has_staff and profile != null:
		draw_set_transform_matrix(Transform2D())
		var glow := 0.35 + _wpn_glow * 0.65
		var pulse := 1.0 + sin(t * 3.0) * 0.12
		var e := profile.eye
		draw_circle(tip_world, (4.0 + 5.0 * _wpn_glow) * s * pulse, Color(e.r, e.g, e.b, glow * 0.4))
		draw_circle(tip_world, 2.2 * s, Color(e.r, e.g, e.b, 0.9))
		draw_circle(tip_world, 1.0 * s, Color(1, 1, 1, 0.95))


# --- geometria por corpo ---------------------------------------------------

func _torso_points() -> PackedVector2Array:
	match profile.body:
		ArtProfile.Body.BRUTE:
			return PackedVector2Array([Vector2(-14,-17), Vector2(14,-17), Vector2(12,8), Vector2(-12,8)])
		ArtProfile.Body.COLOSSUS:
			return PackedVector2Array([Vector2(-17,-23), Vector2(17,-23), Vector2(15,9), Vector2(-15,9)])
		_:
			if profile.has("hero"):
				# túnica: ombros estreitos, cintura, saia curta
				return PackedVector2Array([Vector2(-7,-13), Vector2(7,-13), Vector2(6,2), Vector2(9,12), Vector2(-9,12), Vector2(-6,2)])
			return PackedVector2Array([Vector2(-8,-13), Vector2(8,-13), Vector2(7,7), Vector2(-7,7)])


func _hip_y() -> float:
	match profile.body:
		ArtProfile.Body.BRUTE: return 7.0
		ArtProfile.Body.COLOSSUS: return 8.0
		_: return 6.0


func _shoulder() -> Vector2:
	match profile.body:
		ArtProfile.Body.BRUTE: return Vector2(13, -14)
		ArtProfile.Body.COLOSSUS: return Vector2(16, -19)
		_: return Vector2(7.5, -11)


func _head_pos() -> Vector2:
	match profile.body:
		ArtProfile.Body.BRUTE: return Vector2(2, -21)
		ArtProfile.Body.COLOSSUS: return Vector2(2, -28)
		ArtProfile.Body.WRAITH: return Vector2(0, -15)
		ArtProfile.Body.BEAST: return Vector2(14, -4)
		_: return Vector2(0, -19.5)


func _head_radius() -> float:
	match profile.body:
		ArtProfile.Body.COLOSSUS: return 7.5
		ArtProfile.Body.BRUTE: return 6.0
		ArtProfile.Body.BEAST: return 5.5
		ArtProfile.Body.WRAITH: return 0.0
		_: return 6.0


func _eye_pos(s: float) -> Vector2:
	if profile.body == ArtProfile.Body.WRAITH:
		return Vector2(0, -12) * s
	return _head_pos() * s


# --- bípede ------------------------------------------------------------------

func _draw_biped(s: float) -> void:
	if profile.has("hero"):
		_draw_sophia(s)
		return
	var hero := profile.has("hero")
	var hip_y := _hip_y()
	var hip_x := 3.5
	var leg_len := 15.0
	var leg_th := 5.0
	var arm_len := 13.0
	var arm_th := 4.5
	match profile.body:
		ArtProfile.Body.BRUTE:
			hip_x = 6.0; leg_th = 7.0; arm_len = 16.0; arm_th = 7.0
		ArtProfile.Body.COLOSSUS:
			hip_x = 7.0; leg_th = 9.0; arm_len = 18.0; arm_th = 9.0
	if hero:
		leg_th = 4.2; arm_th = 3.8
	var sh := _shoulder()
	var leg_col := profile.primary.darkened(0.18)
	var arm_col := profile.primary.darkened(0.06)
	var boot_col := profile.primary.darkened(0.5)
	var glove_col := profile.secondary if hero else profile.primary.darkened(0.35)
	if hero:
		leg_col = profile.primary.darkened(0.35)
		arm_col = profile.skin.darkened(0.05)

	# perna e braço de trás
	var foot_b := _limb(Vector2(-hip_x, hip_y), _leg_b, leg_len, leg_th, leg_col, s, true)
	_boot(foot_b, s, boot_col)
	var hand_b := _limb(Vector2(-sh.x, sh.y), _arm_b, arm_len, arm_th, arm_col, s, false)
	draw_circle(hand_b * s, arm_th * 0.6 * s, glove_col)
	if profile.has("claws"): _claws_at(hand_b, s)

	# torso
	var tp := _torso_points()
	_shaded(tp, profile.primary, s)
	draw_polyline(_closed(tp, s), _ink(), maxf(1.2, 1.6 * s), true)
	draw_line(tp[0] * s, tp[1] * s, profile.primary.lerp(Color.WHITE, 0.5), maxf(1.0, 1.3 * s))
	draw_line(tp[0] * s, tp[tp.size() - 1] * s, profile.primary.lerp(Color.WHITE, 0.32), maxf(0.8, 1.0 * s))
	# cinto
	var belt_w := 8.0 if profile.body == ArtProfile.Body.HUMANOID else 12.0
	var belt_y := hip_y - 1.0 if not hero else 1.5
	draw_line(Vector2(-belt_w, belt_y) * s, Vector2(belt_w, belt_y) * s, profile.secondary if hero else profile.primary.darkened(0.55), maxf(1.4, 1.7 * s))
	if hero:
		draw_circle(Vector2(0, belt_y) * s, 1.6 * s, profile.secondary.lerp(Color.WHITE, 0.4))

	# perna da frente
	var foot_f := _limb(Vector2(hip_x, hip_y), _leg_f, leg_len, leg_th, leg_col, s, true)
	_boot(foot_f, s, boot_col)

	# núcleo de luz no peito — a faísca (só o herói)
	if hero:
		var core := Vector2(0, -6) * s
		var pulse := 1.0 + sin(anim_time * 3.0) * 0.18
		draw_circle(core, 3.4 * s * pulse, Color(profile.eye.r, profile.eye.g, profile.eye.b, 0.35))
		draw_circle(core, 1.8 * s, profile.eye)
		draw_circle(core, 0.85 * s, Color(1, 1, 1, 0.9))

	if profile.has("pauldrons"): _pauldrons(s)
	if profile.has("bracers"): _bracers(s)

	# cabeça (antes do braço da frente, que passa por cima ao golpear)
	_head(s)

	# braço da frente + mão + arma
	var hand := _limb(sh, _arm_f, arm_len, arm_th, arm_col, s, false)
	draw_circle(hand * s, arm_th * 0.62 * s, glove_col)
	_weapon(s, hand)


## Desenha um membro (quad) girando em torno do pivô. Retorna a ponta (mão/pé).
func _limb(pivot: Vector2, angle: float, length: float, thick: float, col: Color, s: float, is_leg: bool) -> Vector2:
	var dir := Vector2(sin(angle), cos(angle))
	var end := pivot + dir * length
	var perp := Vector2(dir.y, -dir.x) * (thick * 0.5)
	var quad := PackedVector2Array([
		(pivot + perp) * s, (end + perp) * s, (end - perp) * s, (pivot - perp) * s
	])
	var top := col.lerp(Color.WHITE, 0.08)
	draw_polygon(quad, PackedColorArray([top, col, col.darkened(0.15), top]))
	draw_polyline(PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]), _ink(), maxf(1.0, 1.2 * s), true)
	# articulação (joelho/cotovelo) no meio
	draw_circle((pivot + dir * length * 0.5) * s, thick * 0.42 * s, col.darkened(0.08))
	if is_leg:
		draw_circle(end * s, thick * 0.55 * s, col.darkened(0.2))
	return end


## Bota: bloco escuro no pé, com uma pontinha à frente (facing +x).
func _boot(foot: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		(foot + Vector2(-3, -3)) * s, (foot + Vector2(5, -2)) * s,
		(foot + Vector2(5.5, 3)) * s, (foot + Vector2(-3, 3)) * s
	])
	draw_colored_polygon(pts, col)
	draw_line(pts[0], pts[3], _ink(), maxf(0.8, 1.0 * s))


# --- cabeça ------------------------------------------------------------------

func _head(s: float) -> void:
	var hp := _head_pos() * s
	var r := _head_radius() * s
	if profile.has("hero") or profile.has("face"):
		_face(hp, r, s)
		return
	if r > 0.0:
		draw_circle(hp, r, profile.primary.lerp(Color.WHITE, 0.16))
		draw_arc(hp, r, 0, TAU, 18, _ink(), maxf(1.0, 1.4 * s))
		draw_arc(hp, r, PI, 1.5 * PI, 10, profile.primary.lerp(Color.WHITE, 0.55), maxf(1.0, 1.3 * s))
	_single_eye(hp, r, s)


## O olho único dos Arcontes (a faísca presa) — pisca de leve.
func _single_eye(hp: Vector2, r: float, s: float) -> void:
	var eye_pos := hp
	if profile.body == ArtProfile.Body.WRAITH:
		eye_pos = Vector2(0, -12) * s
	elif profile.body == ArtProfile.Body.BEAST:
		eye_pos = hp + Vector2(1.5, -1.0) * s
	var blink := 1.0 - maxf(0.0, sin(anim_time * 0.7) - 0.96) * 12.0
	var er := (4.2 if r > 0.0 else 4.6) * s
	draw_circle(eye_pos, er, Color(profile.eye.r, profile.eye.g, profile.eye.b, 0.30))
	draw_circle(eye_pos, 2.6 * s * clampf(blink, 0.2, 1.0), profile.eye)
	draw_circle(eye_pos, 1.1 * s * clampf(blink, 0.2, 1.0), Color(1, 1, 1, 0.95))
	if r > 0.0:
		draw_line(eye_pos + Vector2(-4, -4) * s, eye_pos + Vector2(4, -3.4) * s, _ink(), maxf(1.0, 1.4 * s))


## Rosto (herói): pele, dois olhos em 3/4, cabelo com franja, boca.
func _face(hp: Vector2, r: float, s: float) -> void:
	# pescoço
	draw_line(hp + Vector2(0, r * 0.6), hp + Vector2(0, r * 1.6), profile.skin.darkened(0.15), maxf(2.0, 3.0 * s))
	# cabeça
	draw_circle(hp, r, profile.skin)
	draw_arc(hp, r, 0, TAU, 20, _ink(), maxf(1.0, 1.3 * s))
	# olhos (olham pra frente = +x)
	for ex: float in [1.2, 4.0]:
		var ep := hp + Vector2(ex, -0.3) * s
		draw_circle(ep, 1.35 * s, Color(profile.eye.r, profile.eye.g, profile.eye.b, 0.5))
		draw_circle(ep, 1.0 * s, _ink())
		draw_circle(ep + Vector2(0.3, -0.3) * s, 0.4 * s, Color(1, 1, 1, 0.9))
	# sobrancelhas + boca
	draw_line(hp + Vector2(0.2, -2.2) * s, hp + Vector2(2.4, -2.5) * s, _ink(), maxf(0.7, 0.9 * s))
	draw_line(hp + Vector2(3.0, -2.5) * s, hp + Vector2(5.2, -2.2) * s, _ink(), maxf(0.7, 0.9 * s))
	draw_line(hp + Vector2(2.2, 2.6) * s, hp + Vector2(4.2, 2.5) * s, profile.skin.darkened(0.45), maxf(0.7, 0.9 * s))
	# cabelo: calota + franja lateral
	if profile.has("hair"):
		var hc := profile.hair
		# calota = crescente: arco externo (esq→dir por cima) + borda interna de volta
		var cap := PackedVector2Array()
		for i in 13:
			var a := PI + PI * float(i) / 12.0
			cap.append(hp + Vector2(cos(a) * r * 1.12, sin(a) * r * 1.12 + 0.6 * s))
		cap.append(hp + Vector2(r * 0.8, -r * 0.1))
		cap.append(hp + Vector2(r * 0.3, -r * 0.45))
		cap.append(hp + Vector2(-r * 0.4, -r * 0.35))
		cap.append(hp + Vector2(-r * 0.85, 0.0))
		draw_colored_polygon(cap, hc)
		draw_polyline(cap, _ink(), maxf(0.8, 1.0 * s))
		# mecha da frente
		draw_colored_polygon(PackedVector2Array([hp + Vector2(r * 0.9, -r * 0.5), hp + Vector2(r * 1.3, r * 0.9), hp + Vector2(r * 0.55, r * 0.2)]), hc.darkened(0.08))


## Cabelo comprido caindo pelas costas (desenhado ATRÁS do corpo). Ondula.
func _hair_back(s: float) -> void:
	var hp := _head_pos()
	var r := _head_radius()
	var sway := sin(anim_time * 3.0) * 1.5
	var flow := 0.0
	if anim_state == "walk" or anim_state == "charge" or anim_state == "dodge":
		flow = 5.0
	var hc := profile.hair
	# faixa que desce da nuca e afina na ponta (sem auto-interseção)
	var pts := PackedVector2Array([
		Vector2(hp.x - r * 0.6, hp.y - r * 0.9),
		Vector2(hp.x + r * 0.3, hp.y - r * 1.0),
		Vector2(hp.x - r * 0.2, hp.y + r * 0.6),
		Vector2(hp.x - 2.0 - flow * 0.3 + sway * 0.5, hp.y + 12.0),
		Vector2(hp.x - 5.0 - flow + sway, hp.y + 22.0),
		Vector2(hp.x - 10.0 - flow * 1.4 + sway * 1.3, hp.y + 20.0),
		Vector2(hp.x - 8.0 - flow * 0.8 + sway * 0.6, hp.y + 10.0),
		Vector2(hp.x - r * 1.0, hp.y + r * 0.2),
	])
	_shaded(pts, hc.darkened(0.12), s)
	draw_polyline(_closed(pts, s), _ink(), maxf(0.8, 1.0 * s))


# --- arma na mão -------------------------------------------------------------

## Direção da arma a partir do ângulo `_wpn` (0 = pra cima).
func _wdir() -> Vector2:
	return Vector2(sin(_wpn), -cos(_wpn))


func _weapon(s: float, hand: Vector2) -> void:
	var h := hand * s
	var d := _wdir()
	var n := Vector2(-d.y, d.x)
	if profile.has("staff"):
		var top := h + d * 28.0 * s
		var bot := h - d * 13.0 * s
		var shaft_col := profile.secondary.lerp(STEEL, 0.35)
		var w := 1.6 * s
		draw_colored_polygon(PackedVector2Array([top + n * w, top - n * w, bot - n * w, bot + n * w]), shaft_col)
		draw_line(top, bot, shaft_col.lerp(Color.WHITE, 0.35), maxf(0.8, 0.9 * s))
		# ponteira (garras de metal) + orbe
		draw_colored_polygon(PackedVector2Array([top + n * 4.0 * s, top + d * 6.0 * s, top - n * 4.0 * s, top - d * 1.0 * s]), profile.secondary)
		var orb := top + d * 3.5 * s
		var glow := 0.4 + _wpn_glow * 0.6
		var pulse := 1.0 + sin(anim_time * 3.0) * 0.12
		draw_circle(orb, (5.0 + 4.0 * _wpn_glow) * s * pulse, Color(profile.eye.r, profile.eye.g, profile.eye.b, glow * 0.45))
		draw_circle(orb, 3.2 * s, profile.eye)
		draw_circle(orb, 1.4 * s, Color(1, 1, 1, 0.9))
	if profile.has("blade"):
		var tip := h + d * 27.0 * s
		var base := h + d * 3.0 * s
		var w := 3.0 * s
		draw_colored_polygon(PackedVector2Array([base + n * w, base + d * 20.0 * s + n * w * 0.8, tip, base + d * 20.0 * s - n * w * 0.8, base - n * w]), STEEL)
		draw_line(base + n * w * 0.3, tip, Color(1, 1, 1, 0.65), maxf(0.8, 1.0 * s))
		draw_polyline(PackedVector2Array([base + n * w, tip, base - n * w]), _ink(), maxf(0.7, 0.9 * s))
		# guarda + cabo
		draw_line(base + n * 5.0 * s, base - n * 5.0 * s, profile.secondary, maxf(1.5, 2.0 * s))
		draw_line(h - d * 4.0 * s, base, profile.secondary.darkened(0.2), maxf(1.5, 2.2 * s))
	if profile.has("claws"):
		_claws_at(hand, s)
	if profile.has("shield"):
		_shield(s, hand)


func _claws_at(o: Vector2, s: float) -> void:
	var c := STEEL.lerp(profile.secondary, 0.3)
	var d := Vector2(sin(_arm_f), cos(_arm_f))
	if profile.body == ArtProfile.Body.BEAST or profile.body == ArtProfile.Body.WRAITH:
		d = Vector2(0.6, 0.8)
	for k: float in [-1.0, 0.0, 1.0]:
		var kk: float = k
		var side: Vector2 = Vector2(-d.y, d.x) * kk * 2.2
		draw_colored_polygon(_v([o + side - d * 1.0, o + side + Vector2(-d.y, d.x) * 1.2 * signf(kk + 0.5), o + side + d * 6.5], s), c)


## Escudeiro: broquel redondo na mão da frente.
func _shield(s: float, hand: Vector2) -> void:
	draw_circle(hand * s, 7.5 * s, profile.secondary)
	draw_arc(hand * s, 7.5 * s, 0, TAU, 16, _ink(), maxf(1.0, 1.3 * s))
	draw_arc(hand * s, 5.0 * s, 0, TAU, 16, profile.secondary.lerp(Color.WHITE, 0.3), maxf(0.8, 1.0 * s))
	draw_circle(hand * s, 2.0 * s, STEEL)


# --- WRAITH: espectro flutuante -----------------------------------------------

func _draw_wraith(s: float) -> void:
	var hover := sin(anim_time * 2.2) * 1.8
	var body_col := profile.primary
	# farrapos (tiras que ondulam) — parte de baixo
	var hem_y := 8.0
	for i in 5:
		var x := -8.0 + float(i) * 4.0
		var ph := anim_time * 3.0 + float(i) * 1.1
		var len := 12.0 + 4.0 * sin(ph * 0.7)
		var sw := sin(ph) * 2.5
		var pts := PackedVector2Array([
			Vector2(x - 2.0, hem_y), Vector2(x + 2.0, hem_y),
			Vector2(x + 1.0 + sw, hem_y + len), Vector2(x - 1.0 + sw * 0.8, hem_y + len + 2.0)
		])
		_shaded(pts, body_col.darkened(0.15), s)
	# corpo (manto) com capuz pontudo
	var pts := PackedVector2Array([
		Vector2(-7, -22 + hover * 0.3), Vector2(0, -26 + hover * 0.3), Vector2(7, -22 + hover * 0.3),
		Vector2(11, -4), Vector2(9, hem_y + 1), Vector2(-9, hem_y + 1), Vector2(-11, -4)
	])
	_shaded(pts, body_col, s)
	draw_polyline(_closed(pts, s), _ink(), maxf(1.2, 1.7 * s), true)
	draw_line(pts[0] * s, pts[1] * s, body_col.lerp(Color.WHITE, 0.5), maxf(1.0, 1.4 * s))
	# sombra do capuz (o rosto é um buraco escuro com o olho)
	var hood := PackedVector2Array([Vector2(-5, -20), Vector2(5, -20), Vector2(6, -8), Vector2(-6, -8)])
	draw_colored_polygon(_v(hood, s), Color(0.05, 0.03, 0.08, 0.85))
	# braços finos flutuando (com garras se tiver)
	var arm_col := body_col.darkened(0.1)
	var hand_b := _limb(Vector2(-8, -8), _arm_b - 0.3 + sin(anim_time * 2.0) * 0.08, 11.0, 3.0, arm_col, s, false)
	if profile.has("claws"): _claws_at(hand_b, s)
	if profile.has("pauldrons"): _pauldrons(s)
	_single_eye(Vector2.ZERO, 0.0, s)
	var hand := _limb(Vector2(8, -8), _arm_f + 0.3, 11.0, 3.0, arm_col, s, false)
	_weapon(s, hand)


# --- BEAST: quadrúpede -----------------------------------------------------------

func _draw_beast(s: float) -> void:
	var t := anim_time
	var gallop := 0.0
	var speed := 0.0
	match anim_state:
		"walk": speed = 9.0
		"charge": speed = 15.0
	var body_bob := 0.0
	var leg_a := [0.05, -0.05, -0.05, 0.05]       # traseira B, traseira F, dianteira B, dianteira F
	if speed > 0.0:
		gallop = sin(t * speed)
		body_bob = -absf(gallop) * 2.0
		leg_a = [gallop * 0.7, -gallop * 0.5, -gallop * 0.6, gallop * 0.7]
	elif anim_state == "windup" or anim_state == "windup_heavy":
		leg_a = [0.5, 0.4, -0.5, -0.4]             # agacha pra saltar
		body_bob = 2.5
	elif anim_state == "attack" or anim_state == "attack_heavy":
		leg_a = [-0.5, -0.4, 0.6, 0.7]             # bote
		body_bob = -3.0
	elif anim_state == "hurt":
		leg_a = [0.3, 0.3, -0.3, -0.3]
	elif anim_state == "dead":
		leg_a = [0.9, 0.7, -0.8, -0.9]
	var col := profile.primary
	var leg_col := col.darkened(0.2)
	var hip_y := 9.0 + body_bob
	# cauda (pra TRÁS = -x)
	var sway := sin(t * 3.0) * 2.0
	_shaded(PackedVector2Array([Vector2(-14, 2 + body_bob), Vector2(-30, -6 + sway + body_bob), Vector2(-33, -1 + sway + body_bob), Vector2(-16, 9 + body_bob)]), col.darkened(0.25), s)
	# patas de trás (lado de trás)
	_limb(Vector2(-10, hip_y), leg_a[0], 15.0, 4.5, leg_col.darkened(0.1), s, true)
	_limb(Vector2(9, hip_y), leg_a[2], 15.0, 4.5, leg_col.darkened(0.1), s, true)
	# corpo
	var body := PackedVector2Array([
		Vector2(-16, -3 + body_bob), Vector2(-8, -11 + body_bob), Vector2(8, -12 + body_bob),
		Vector2(17, -6 + body_bob), Vector2(16, 6 + body_bob), Vector2(-14, 8 + body_bob)
	])
	_shaded(body, col, s)
	draw_polyline(_closed(body, s), _ink(), maxf(1.2, 1.6 * s), true)
	draw_line(body[1] * s, body[2] * s, col.lerp(Color.WHITE, 0.45), maxf(1.0, 1.3 * s))
	# espinhos no dorso
	if profile.has("spikes"):
		var c := profile.secondary.lerp(col, 0.4)
		for x: float in [-9, -3, 3, 9]:
			draw_colored_polygon(_v([Vector2(x - 2, -10 + body_bob), Vector2(x, -18 + body_bob), Vector2(x + 2, -10 + body_bob)], s), c)
	# patas da frente (lado de cá)
	var pf := _limb(Vector2(-8, hip_y + 1), leg_a[1], 15.0, 5.0, leg_col, s, true)
	var ff := _limb(Vector2(11, hip_y + 1), leg_a[3], 15.0, 5.0, leg_col, s, true)
	if profile.has("claws"):
		_claws_at(ff, s)
		_claws_at(pf, s)
	# cabeça à frente com mandíbula
	var hp := Vector2(15, -6 + body_bob)
	var r := _head_radius()
	var jaw_open := 0.0
	if anim_state == "windup" or anim_state == "attack" or anim_state == "windup_heavy" or anim_state == "attack_heavy":
		jaw_open = 3.5
	var head := PackedVector2Array([
		Vector2(hp.x - r, hp.y - r), Vector2(hp.x + r * 1.4, hp.y - r * 0.8),
		Vector2(hp.x + r * 1.6, hp.y + 1), Vector2(hp.x - r * 0.6, hp.y + r * 0.6)
	])
	_shaded(head, col.lerp(Color.WHITE, 0.1), s)
	draw_polyline(_closed(head, s), _ink(), maxf(1.0, 1.4 * s), true)
	var jaw := PackedVector2Array([
		Vector2(hp.x - r * 0.4, hp.y + 1), Vector2(hp.x + r * 1.5, hp.y + 1.5 + jaw_open),
		Vector2(hp.x + r * 1.2, hp.y + 4 + jaw_open), Vector2(hp.x - r * 0.3, hp.y + 3.5)
	])
	draw_colored_polygon(_v(jaw, s), col.darkened(0.3))
	# dentes
	var tooth := Color(0.92, 0.9, 0.82)
	for i in 3:
		var x := hp.x + r * (0.2 + float(i) * 0.45)
		draw_colored_polygon(_v([Vector2(x - 1, hp.y + 1), Vector2(x + 1, hp.y + 1), Vector2(x, hp.y + 3)], s), tooth)
	# orelhas/chifres
	if profile.has("horns"):
		draw_colored_polygon(_v([Vector2(hp.x - 2, hp.y - r), Vector2(hp.x - 5, hp.y - r - 8), Vector2(hp.x + 2, hp.y - r + 1)], s), profile.secondary)
	_single_eye(hp * s, r * s, s)


# --- sombreamento / helpers -------------------------------------------------

func _shaded(points: PackedVector2Array, base: Color, s: float) -> void:
	var miny := INF
	var maxy := -INF
	for p in points:
		miny = minf(miny, p.y)
		maxy = maxf(maxy, p.y)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for p in points:
		pts.append(p * s)
		var t := 0.0
		if maxy > miny:
			t = (p.y - miny) / (maxy - miny)
		var shf := lerpf(1.18, 0.46, t)
		cols.append(Color(base.r * shf, base.g * shf, base.b * shf, base.a))
	draw_polygon(pts, cols)


func _v(points: Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * s)
	return out


func _closed(points: PackedVector2Array, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * s)
	if points.size() > 0:
		out.append(points[0] * s)
	return out


## Rachaduras de luz no corpo ferido (a faísca vazando).
func _cracks(s: float) -> void:
	var k := clampf((damage_ratio - 0.45) / 0.55, 0.0, 1.0)
	var c := Color(profile.eye.r, profile.eye.g, profile.eye.b, 0.55 + 0.4 * sin(anim_time * 9.0) * k)
	var cx := 0.0
	var cy := -6.0
	if profile.body == ArtProfile.Body.BEAST:
		cx = 2.0; cy = -3.0
	var lines := [
		[Vector2(cx - 1, cy - 6), Vector2(cx + 2, cy - 1), Vector2(cx - 2, cy + 4)],
		[Vector2(cx + 3, cy - 4), Vector2(cx + 6, cy + 1)],
		[Vector2(cx - 5, cy), Vector2(cx - 2, cy + 3), Vector2(cx - 6, cy + 8)],
	]
	var n := 1 + int(k * 2.0)
	for i in n:
		var ln: Array = lines[i]
		draw_polyline(_v(ln, s), c, maxf(1.2, 1.6 * s))
		draw_polyline(_v(ln, s), Color(1, 1, 1, 0.5 * k), maxf(0.6, 0.7 * s))


# --- adereços --------------------------------------------------------------

func _horns(s: float) -> void:
	if profile.body == ArtProfile.Body.BEAST:
		return
	var hp := _head_pos()
	var c := profile.secondary.darkened(0.1)
	draw_colored_polygon(_v([Vector2(hp.x - 5, hp.y - 4), Vector2(hp.x - 12, hp.y - 15), Vector2(hp.x - 2, hp.y - 6)], s), c)
	draw_colored_polygon(_v([Vector2(hp.x + 5, hp.y - 4), Vector2(hp.x + 12, hp.y - 15), Vector2(hp.x + 2, hp.y - 6)], s), c)


func _crown(s: float) -> void:
	var hp := _head_pos()
	var r := _head_radius()
	var c := profile.eye.lerp(Color(0.9, 0.75, 0.3), 0.5)
	var base_y := hp.y - r + 0.5
	draw_colored_polygon(_v([Vector2(hp.x - 7, base_y), Vector2(hp.x + 7, base_y), Vector2(hp.x + 7, base_y - 3), Vector2(hp.x - 7, base_y - 3)], s), c.darkened(0.2))
	for x: float in [-6, 0, 6]:
		draw_colored_polygon(_v([Vector2(hp.x + x - 3, base_y - 3), Vector2(hp.x + x, base_y - 11), Vector2(hp.x + x + 3, base_y - 3)], s), c)


func _cape(s: float) -> void:
	var sway := sin(anim_time * 2.0) * 1.4
	_shaded(PackedVector2Array([Vector2(-8,-13), Vector2(8,-13), Vector2(15+sway,24), Vector2(0,19), Vector2(-15+sway,24)]), profile.secondary, s)


func _wings(s: float) -> void:
	var flap := sin(anim_time * 4.0) * 3.0
	var c := profile.secondary.lerp(profile.primary, 0.25)
	for sx: float in [-1.0, 1.0]:
		var pts := PackedVector2Array([
			Vector2(9 * sx, -10), Vector2(22 * sx, -22 - flap), Vector2(34 * sx, -16 - flap),
			Vector2(28 * sx, -4 - flap * 0.5), Vector2(30 * sx, 6), Vector2(18 * sx, 2), Vector2(11 * sx, 6)
		])
		_shaded(pts, c, s)
		draw_polyline(_closed(pts, s), _ink(), maxf(0.8, 1.0 * s))
		# nervuras
		draw_line(Vector2(9 * sx, -10) * s, Vector2(28 * sx, -4 - flap * 0.5) * s, c.darkened(0.3), maxf(0.7, 0.8 * s))
		draw_line(Vector2(9 * sx, -10) * s, Vector2(34 * sx, -16 - flap) * s, c.darkened(0.3), maxf(0.7, 0.8 * s))


func _spikes(s: float) -> void:
	var c := profile.secondary.lerp(profile.primary, 0.4)
	var tp := _torso_points()
	var top_y := tp[0].y
	for x: float in [-8, -2, 4, 10]:
		draw_colored_polygon(_v([Vector2(x - 3, top_y), Vector2(x, top_y - 10), Vector2(x + 3, top_y)], s), c)


func _pauldrons(s: float) -> void:
	var c := profile.secondary
	var trim := profile.secondary.lerp(Color.WHITE, 0.3)
	var sh := _shoulder()
	var w := 7.0 if profile.body == ArtProfile.Body.HUMANOID else 10.0
	for sx: float in [-1.0, 1.0]:
		var pts := _v([Vector2(sh.x * sx + w * sx, sh.y - 3), Vector2(sh.x * sx - 3 * sx, sh.y - 4), Vector2(sh.x * sx - 4 * sx, sh.y + 6), Vector2(sh.x * sx + (w + 1) * sx, sh.y + 7)], s)
		draw_colored_polygon(pts, c)
		draw_polyline(pts, _ink(), maxf(0.8, 1.0 * s))
		draw_line(pts[0], pts[1], trim, maxf(1.0, 1.2 * s))


func _bracers(s: float) -> void:
	var c := profile.secondary
	var sh := _shoulder()
	for sx: float in [-1.0, 1.0]:
		var a := _arm_f if sx > 0.0 else _arm_b
		var d := Vector2(sin(a), cos(a))
		var p := Vector2(sh.x * sx, sh.y) + d * 8.5
		var n := Vector2(-d.y, d.x) * 3.2
		draw_colored_polygon(_v([p + n, p + n + d * 4.5, p - n + d * 4.5, p - n], s), c)


func _helmet(s: float) -> void:
	var hp := _head_pos()
	var r := _head_radius()
	draw_colored_polygon(_v([
		Vector2(hp.x - r - 1.5, hp.y + 1), Vector2(hp.x - r - 1.5, hp.y - r * 1.1), Vector2(hp.x, hp.y - r - 4.5),
		Vector2(hp.x + r + 1.5, hp.y - r * 1.1), Vector2(hp.x + r + 1.5, hp.y + 1)
	], s), profile.secondary)
	draw_line((hp + Vector2(-r * 0.8, 0)) * s, (hp + Vector2(r * 0.8, 0)) * s, profile.eye, maxf(1.0, 1.4 * s))
	# crista
	draw_colored_polygon(_v([Vector2(hp.x - 1.5, hp.y - r - 3), Vector2(hp.x, hp.y - r - 9), Vector2(hp.x + 1.5, hp.y - r - 3)], s), profile.secondary.lerp(Color.WHITE, 0.25))


func _aura(s: float) -> void:
	var pulse := 1.0 + sin(anim_time * 2.0) * 0.06
	var col := Color(profile.eye.r, profile.eye.g, profile.eye.b, 0.09)
	draw_circle(Vector2(0, -2) * s, profile.height * 0.62 * pulse, col)
	draw_circle(Vector2(0, -2) * s, profile.height * 0.45 * pulse, col)


# --- assinaturas dos Arcontes (uma feature própria por Éon) ----------------

## Torpor: pálpebra pesada cobrindo mais da metade do olho.
func _eyelid(s: float) -> void:
	var ep := _eye_pos(s)
	var r := 4.8 * s
	var lid := profile.primary.lerp(Color.WHITE, 0.16) if profile.body != ArtProfile.Body.WRAITH else profile.primary
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(ep + Vector2(cos(a), sin(a)) * r)
	pts.append(ep + Vector2(r, 1.4 * s))
	pts.append(ep + Vector2(-r, 1.4 * s))
	draw_colored_polygon(pts, lid)
	draw_line(ep + Vector2(-r, 1.4 * s), ep + Vector2(r, 1.4 * s), _ink(), maxf(1.0, 1.3 * s))


## Silêncio: boca costurada abaixo do olho.
func _sewn(s: float) -> void:
	var m := _eye_pos(s) + Vector2(0, 6.5) * s
	draw_line(m + Vector2(-5, 0) * s, m + Vector2(5, 0) * s, _ink(), maxf(1.0, 1.4 * s))
	for i in 4:
		var x := -3.75 + float(i) * 2.5
		draw_line(m + Vector2(x, -2) * s, m + Vector2(x + 1.2, 2) * s, _ink(), maxf(0.8, 1.1 * s))


## Fome: boca sem fim escancarada no torso, com dentes e brasa no fundo.
func _maw(s: float) -> void:
	var c := Vector2(0, -4) * s
	var w := 10.0 * s
	var h := 6.0 * s * (1.0 + 0.15 * sin(anim_time * 3.0))
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(c + Vector2(cos(a) * w, sin(a) * h))
	draw_colored_polygon(pts, Color(0.08, 0.02, 0.04))
	draw_circle(c, 2.4 * s, Color(profile.eye.r, profile.eye.g, profile.eye.b, 0.65))
	var tooth := Color(0.92, 0.9, 0.82)
	for i in 5:
		var x := -w * 0.8 + float(i) * w * 0.4
		draw_colored_polygon(PackedVector2Array([c + Vector2(x - 1.3 * s, -h * 0.9), c + Vector2(x + 1.3 * s, -h * 0.9), c + Vector2(x, -h * 0.9 + 3.0 * s)]), tooth)
		draw_colored_polygon(PackedVector2Array([c + Vector2(x - 1.1 * s, h * 0.9), c + Vector2(x + 1.1 * s, h * 0.9), c + Vector2(x, h * 0.9 - 2.4 * s)]), tooth)


## Corrente: elos pendurados dos ombros, balançando.
func _chains(s: float) -> void:
	var sway := sin(anim_time * 2.2) * 1.5
	var link := STEEL.darkened(0.35)
	for sx: float in [-1.0, 1.0]:
		for i in 6:
			var q := Vector2(13.0 * sx + sway * float(i) * 0.4, -12.0 + 4.5 * float(i)) * s
			draw_arc(q, 2.0 * s, 0, TAU, 8, link, maxf(1.0, 1.2 * s))


## Espelho: cacos de espelho orbitando o corpo.
func _mirror(s: float) -> void:
	var n := 6
	for i in n:
		var a := anim_time * 0.8 + TAU * float(i) / float(n)
		var c := Vector2(cos(a), sin(a) * 0.55) * 26.0 * s + Vector2(0, -6) * s
		var d := Vector2(cos(a + 1.3), sin(a + 1.3))
		var o := Vector2(-d.y, d.x)
		var col := Color(0.75, 0.85, 1.0, 0.5 + 0.3 * sin(anim_time * 3.0 + float(i)))
		draw_colored_polygon(PackedVector2Array([c + d * 5.0 * s, c - d * 3.0 * s + o * 2.5 * s, c - d * 3.0 * s - o * 2.5 * s]), col)


## Praga: gavinhas podres saindo das costas, com flores mortas na ponta.
func _rot(s: float) -> void:
	var c := profile.secondary.darkened(0.2)
	var fl := Color(0.55, 0.18, 0.4)
	for k: float in [-1.0, 0.0, 1.0]:
		var sway := sin(anim_time * 1.6 + k) * 2.0
		var a := Vector2(k * 6.0, -14.0) * s
		var b := Vector2(k * 14.0 + sway, -30.0 + absf(k) * 6.0) * s
		var e := Vector2(k * 20.0 + sway * 1.5, -22.0 + absf(k) * 8.0) * s
		draw_polyline(PackedVector2Array([a, b, e]), c, maxf(1.5, 2.2 * s))
		draw_circle(e, 3.0 * s, fl)
		draw_circle(e, 1.3 * s, Color(0.1, 0.05, 0.08))


## Coroa: coroa alta de cinco pontas + halo cego.
func _bigcrown(s: float) -> void:
	var hp := _head_pos()
	var c := profile.eye.lerp(Color(0.9, 0.75, 0.3), 0.5)
	draw_colored_polygon(_v([Vector2(hp.x - 9, hp.y - 5), Vector2(hp.x + 9, hp.y - 5), Vector2(hp.x + 9, hp.y - 9), Vector2(hp.x - 9, hp.y - 9)], s), c.darkened(0.25))
	for i in 5:
		var x := hp.x - 8.0 + float(i) * 4.0
		var h := 14.0 if i == 2 else (10.0 if i % 2 == 0 else 7.0)
		draw_colored_polygon(_v([Vector2(x - 2, hp.y - 9), Vector2(x, hp.y - 9 - h), Vector2(x + 2, hp.y - 9)], s), c)
	draw_arc(Vector2(hp.x, hp.y - 12) * s, 16.0 * s, 0, TAU, 32, Color(c.r, c.g, c.b, 0.35), maxf(1.0, 1.5 * s))


## Colosso Oco: cacos da máscara branca do Rei cravados no rosto gigante.
func _cracked_face(s: float) -> void:
	var hp := _head_pos()
	var white := Color(0.93, 0.92, 0.9)
	var r := _head_radius()
	draw_colored_polygon(_v([Vector2(hp.x - r * 0.9, hp.y - r * 0.5), Vector2(hp.x - r * 0.2, hp.y - r * 1.1), Vector2(hp.x + r * 0.2, hp.y - r * 0.3), Vector2(hp.x - r * 0.5, hp.y + r * 0.3)], s), white)
	draw_colored_polygon(_v([Vector2(hp.x + r * 0.3, hp.y + r * 0.2), Vector2(hp.x + r * 1.0, hp.y - r * 0.2), Vector2(hp.x + r * 0.9, hp.y + r * 0.9), Vector2(hp.x + r * 0.2, hp.y + r * 0.8)], s), white.darkened(0.08))
	# fresta da máscara (o olho cego)
	draw_line((hp + Vector2(-r * 0.6, -r * 0.2)) * s, (hp + Vector2(-r * 0.1, -r * 0.35)) * s, _ink(), maxf(1.0, 1.3 * s))


# =========================================================================
# DESMEMBRAMENTO — peças do corpo pro Gib
# =========================================================================

## Devolve as peças do corpo como polígonos locais (já escalados), com cor.
## [{pts: PackedVector2Array, col: Color, kind: String}]
func gib_parts() -> Array:
	var s := profile.height / 44.0
	var parts: Array = []
	if has_boss_frames() and not _boss_shown.is_empty():
		return _frame_gibs()
	if not painted.is_empty() and not painted.get("hero",false):
		return _painted_gibs(s)
	if texture != null:
		return parts
	match profile.body:
		ArtProfile.Body.WRAITH:
			var body := PackedVector2Array([Vector2(-7,-22), Vector2(0,-26), Vector2(7,-22), Vector2(11,-4), Vector2(9,9), Vector2(-9,9), Vector2(-11,-4)])
			parts.append_array(_shards(body, profile.primary, s, 4))
			parts.append({"pts": _circle_poly(Vector2(0, -12) * s, 3.0 * s), "col": profile.eye, "kind": "eye"})
		ArtProfile.Body.BEAST:
			var body := PackedVector2Array([Vector2(-16,-3), Vector2(-8,-11), Vector2(8,-12), Vector2(17,-6), Vector2(16,6), Vector2(-14,8)])
			parts.append({"pts": _v(body, s), "col": profile.primary, "kind": "torso"})
			var hp := Vector2(15, -6)
			var r := _head_radius()
			parts.append({"pts": _v([Vector2(hp.x - r, hp.y - r), Vector2(hp.x + r * 1.4, hp.y - r * 0.8), Vector2(hp.x + r * 1.6, hp.y + 3), Vector2(hp.x - r * 0.6, hp.y + r * 0.6)], s), "col": profile.primary.lerp(Color.WHITE, 0.1), "kind": "head"})
			for px: float in [-10.0, -8.0, 9.0, 11.0]:
				parts.append({"pts": _quad(Vector2(px, 9), 0.2, 15.0, 4.5, s), "col": profile.primary.darkened(0.2), "kind": "limb"})
			parts.append({"pts": _v([Vector2(-14, 2), Vector2(-30, -6), Vector2(-33, -1), Vector2(-16, 9)], s), "col": profile.primary.darkened(0.25), "kind": "limb"})
		_:
			var hip_y := _hip_y()
			var sh := _shoulder()
			var hip_x := 3.5
			var leg_th := 5.0
			var arm_len := 13.0
			var arm_th := 4.5
			match profile.body:
				ArtProfile.Body.BRUTE:
					hip_x = 6.0; leg_th = 7.0; arm_len = 16.0; arm_th = 7.0
				ArtProfile.Body.COLOSSUS:
					hip_x = 7.0; leg_th = 9.0; arm_len = 18.0; arm_th = 9.0
			var hero := profile.has("hero")
			var leg_col := profile.primary.darkened(0.35 if hero else 0.18)
			var arm_col := profile.skin.darkened(0.05) if hero else profile.primary.darkened(0.06)
			parts.append({"pts": _quad(Vector2(-hip_x, hip_y), -0.3, 15.0, leg_th, s), "col": leg_col, "kind": "limb"})
			parts.append({"pts": _quad(Vector2(hip_x, hip_y), 0.4, 15.0, leg_th, s), "col": leg_col, "kind": "limb"})
			parts.append({"pts": _quad(Vector2(-sh.x, sh.y), -0.5, arm_len, arm_th, s), "col": arm_col, "kind": "limb"})
			parts.append({"pts": _quad(sh, 0.9, arm_len, arm_th, s), "col": arm_col, "kind": "limb"})
			var tp := _torso_points()
			if profile.body == ArtProfile.Body.COLOSSUS or profile.body == ArtProfile.Body.BRUTE:
				parts.append_array(_shards(tp, profile.primary, s, 3))
			else:
				parts.append({"pts": _v(tp, s), "col": profile.primary, "kind": "torso"})
			var hp := _head_pos() * s
			var hr := _head_radius() * s
			var head_col := profile.skin if hero or profile.has("face") else profile.primary.lerp(Color.WHITE, 0.16)
			parts.append({"pts": _circle_poly(hp, hr), "col": head_col, "kind": "head"})
			if profile.has("staff"):
				parts.append({"pts": _v([Vector2(9, -26), Vector2(12, -26), Vector2(12, 14), Vector2(9, 14)], s), "col": profile.secondary.lerp(STEEL, 0.35), "kind": "weapon"})
			if profile.has("blade"):
				parts.append({"pts": _v([Vector2(10, -4), Vector2(14, -6), Vector2(34, -2), Vector2(14, 2)], s), "col": STEEL, "kind": "weapon"})
	return parts


func _quad(pivot: Vector2, angle: float, length: float, thick: float, s: float) -> PackedVector2Array:
	var dir := Vector2(sin(angle), cos(angle))
	var end := pivot + dir * length
	var perp := Vector2(dir.y, -dir.x) * (thick * 0.5)
	return PackedVector2Array([(pivot + perp) * s, (end + perp) * s, (end - perp) * s, (pivot - perp) * s])


func _circle_poly(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## Parte um polígono em `n` cacos triangulares (leque a partir do centro).
func _shards(poly: PackedVector2Array, col: Color, s: float, n: int) -> Array:
	var out: Array = []
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	var m := poly.size()
	var per := maxi(1, int(ceil(float(m) / float(n))))
	var i := 0
	while i < m:
		var pts := PackedVector2Array([c * s])
		for k in per + 1:
			pts.append(poly[(i + k) % m] * s)
		out.append({"pts": pts, "col": col.darkened(0.05 * float(i)), "kind": "shard"})
		i += per
	return out


## Sophia v3: silhueta esguia, marfim sobre petróleo, ouro e cabelo de luz.
## Compartilha a cinemática do cajado e os estados do combate, sem sprites.
func _draw_sophia(s: float) -> void:
	var gold: Color = profile.secondary
	var cloth: Color = profile.primary
	var dark := Color("244650")
	var sway: float = sin(anim_time * 2.8) * 1.6
	# Pernas articuladas expostas sob os dois painéis da túnica.
	var back := _limb(Vector2(-3, 8), _leg_b, 13, 3.3, dark.darkened(0.2), s, true)
	_boot(back, s, dark.darkened(0.5))
	var hand_b := _limb(Vector2(-6, -11), _arm_b, 13, 3, cloth.darkened(0.3), s, false)
	draw_circle(hand_b * s, 1.8 * s, gold)
	# Cabelo comprido em mechas, separado do corpo e sem capa.
	_shaded(PackedVector2Array([Vector2(-5,-28),Vector2(3,-28),Vector2(1,-13),Vector2(-6+sway,5),Vector2(-14+sway,13),Vector2(-10,-7)]), profile.hair.darkened(0.25), s)
	draw_line(Vector2(-5,-21)*s,Vector2(-9+sway,6)*s, profile.hair, 0.8*s,true)
	var foot := _limb(Vector2(3, 8), _leg_f, 13, 3.5, dark, s, true)
	_boot(foot, s, dark.darkened(0.4))
	draw_line((foot+Vector2(-2,-4))*s,(foot+Vector2(3,-4))*s,gold,1.2*s,true)
	# Corpete facetado e painéis assimétricos com debrum.
	_shaded(PackedVector2Array([Vector2(-7,-13),Vector2(5,-14),Vector2(8,-7),Vector2(4,2),Vector2(-4,3),Vector2(-8,-5)]), cloth, s)
	_shaded(PackedVector2Array([Vector2(-4,2),Vector2(0,3),Vector2(-1+sway,14),Vector2(-9+sway,17),Vector2(-7,8)]), cloth.darkened(0.17), s)
	_shaded(PackedVector2Array([Vector2(0,3),Vector2(4,2),Vector2(9+sway,15),Vector2(5+sway,18),Vector2(1,13)]), cloth, s)
	draw_polyline(_v([Vector2(-6,-11),Vector2(0,-4),Vector2(5,-12)],s),gold,1.3*s,true)
	draw_polyline(_v([Vector2(-3,3),Vector2(-3+sway,12),Vector2(-7+sway,14)],s),gold,0.7*s,true)
	draw_polyline(_v([Vector2(3,4),Vector2(6+sway,14),Vector2(5+sway,16)],s),gold,0.7*s,true)
	draw_line(Vector2(-5,2)*s,Vector2(5,2)*s,gold,2.2*s,true)
	draw_circle(Vector2(0,2)*s,1.8*s,dark)
	draw_circle(Vector2(0,-6)*s,3.5*s,Color(profile.eye,0.13))
	draw_colored_polygon(_v([Vector2(0,-9),Vector2(1.4,-6),Vector2(0,-3),Vector2(-1.4,-6)],s),profile.eye)
	# Rosto em três quartos: perfil angular e olho único visível nesta escala.
	draw_line(Vector2(0,-16)*s,Vector2(0,-12)*s,profile.skin.darkened(0.2),3*s,true)
	_shaded(PackedVector2Array([Vector2(-4,-25),Vector2(2,-26),Vector2(5,-22),Vector2(4,-18),Vector2(1,-16),Vector2(-3,-18)]),profile.skin,s)
	_shaded(PackedVector2Array([Vector2(-5,-24),Vector2(-3,-29),Vector2(3,-29),Vector2(6,-25),Vector2(2,-25),Vector2(-1,-22),Vector2(-3,-17)]),profile.hair,s)
	draw_line(Vector2(1,-22)*s,Vector2(4,-21.7)*s,dark,0.8*s,true)
	draw_circle(Vector2(3,-21.7)*s,0.45*s,profile.eye)
	draw_line(Vector2(2,-18.8)*s,Vector2(3.8,-19)*s,profile.skin.darkened(0.4),0.45*s,true)
	draw_line(Vector2(-4,-25)*s,Vector2(5,-25)*s,gold,0.8*s,true)
	# Ombreira e bracelete evoluem, mas o rosto permanece legível.
	if profile.has("pauldrons"):
		_shaded(PackedVector2Array([Vector2(-8,-13),Vector2(-4,-16),Vector2(-1,-12),Vector2(-6,-9)]),gold,s)
	var hand := _limb(Vector2(6,-11),_arm_f,13,3.2,cloth,s,false)
	draw_circle(hand*s,2.1*s,gold)
	draw_circle(hand*s,1.0*s,profile.eye)
	_weapon(s,hand)
	# Diadema e astrolábio preservam a silhueta durante a evolução.
	if profile.has("helmet"):
		draw_arc(Vector2(0,-23)*s,9*s,PI*1.08,PI*1.91,30,Color(gold,0.65),0.6*s,true)
	if profile.has("crown"):
		for i in 3:
			draw_circle(Vector2((i-1)*4,-34-abs(i-1)*-2)*s,0.9*s,profile.eye)


## Inscrições e ornamentos ligam os carcereiros à arquitetura dos sete anéis.
func _codex_regalia(s: float) -> void:
	var metal: Color = profile.secondary.lerp(profile.eye, 0.42)
	if profile.body == ArtProfile.Body.WRAITH:
		for side in [-1.0, 1.0]:
			var drift: float = sin(anim_time * 2.0 + side) * 2.0
			var ribbon := PackedVector2Array([Vector2(side*6,-24),Vector2(side*11,-18),Vector2(side*13,2),Vector2(side*20+drift,17),Vector2(side*13+drift,13),Vector2(side*8,-8)])
			_shaded(ribbon,profile.primary.lightened(0.08),s)
			draw_polyline(_v([Vector2(side*6,-24),Vector2(side*10,-17),Vector2(side*11,1),Vector2(side*17+drift,13)],s),metal,0.65*s,true)
		for i in 5:
			var yy: float = -4.0 + i * 3.4
			draw_line(Vector2(-2,yy)*s,Vector2(2,yy+1.5)*s,Color(profile.eye,0.4),0.55*s,true)
		draw_arc(Vector2(0,-16)*s,16*s,PI*1.1,PI*1.9,32,Color(metal,0.65),0.8*s,true)
	elif profile.body == ArtProfile.Body.BEAST:
		for i in 5:
			var x: float = -11.0 + i * 5.0
			draw_polyline(_v([Vector2(x,-6),Vector2(x+2,-1),Vector2(x+1,3)],s),Color(profile.eye,0.45),0.65*s,true)
	else:
		for side in [-1.0, 1.0]:
			draw_polyline(_v([Vector2(side*9,-10),Vector2(side*5,-2),Vector2(side*6,5)],s),metal,0.85*s,true)
			for i in 3:
				draw_circle(Vector2(side*9,-10+i*4)*s,0.6*s,profile.eye)
		var skirt := PackedVector2Array([Vector2(-5,7),Vector2(5,7),Vector2(7,17),Vector2(0,21),Vector2(-7,17)])
		_shaded(skirt,profile.secondary,s)
		draw_polyline(_closed(skirt,s),metal,0.6*s,true)


# =========================================================================
# PINTURA ANIMADA (Sophia por quadros desenhados · criaturas de peça única)
# =========================================================================
# Regras (docs/ANIMACAO.md): troca SECA entre quadros pintados, escala única
# por personagem, pé travado pela âncora de cada quadro (JSON offline),
# rotação do corpo inteiro ≤ MAX_ROT, squash ≤ ±MAX_SQUASH, inclinação e
# curvatura no VERTEX SHADER (painted_flex: deslocamento ∝ altura², pés
# pregados), vento no cabelo/manto por máscara, smear do cajado, afterimages
# e morte por dissolução.

const MAX_ROT := 0.12
const MAX_SQUASH := 0.07
const FLEX_SHADER := "res://assets/shaders/painted_flex.gdshader"
const BOSS_SHADER := "res://assets/painted/shaders/painted_boss.gdshader"   # chefes por quadros
const FRAMES_JSON := "res://assets/painted/derived/%s_frames.json"
const MESH_COLS := 6
const MESH_ROWS := 10

static var _frame_dbs: Dictionary = {}     # personagem → {meta, atlas, flex} (ou {} se não houver)
static var _mesh_cache: Dictionary = {}    # chave do quadro+âncora → grade {pts, uvs, idx}

var motion_distance: float = 0.0   # distância horizontal percorrida (fase da corrida/passo)
var dodge_back: bool = false        # esquiva pra trás (o player liga; usa o quadro de recuo)
var combo_step: int = 0             # golpe leve 1/2/3 do combo (o player liga; 0 = genérico)
var _combat_clock: float = 99.0     # s desde o último estado de combate (parada → prontidão)
var _land_t: float = 0.0            # segura o quadro de pouso (s)
var _rise_t: float = 0.0            # tempo restante do levantar (s)
## Corrida com os meios do RIFE (run16, borram as pernas). Desligado na Onda 2:
## a corrida padrão é o ciclo desenhado "rund" (S2 + passagens da S11).
const USE_RUN_INBETWEENS := false
var dissolve_max: float = 1.0       # forma que pode se refazer dissolve só até aqui
var _last_x: float = INF
var _wind_time: float = 0.0
var _flex_mat: ShaderMaterial
var _shown_key: String = ""         # quadro desenhado agora (troca → smear/passo)
var _shown_tip: Vector2 = Vector2.INF
var _smear: Dictionary = {}
var _smear_clock: float = 0.0
var _ghosts: AfterimageLayer
var _ghost_timer: float = 0.0
var _impact: float = 0.0            # squash de impacto (pouso na morte etc.)
var _step_phase: int = -1


## Banco de quadros desenhados do personagem (atlas + JSON gerados por
## tools/anim/build_frames.py). Vazio = usa as 6 poses antigas.
static func frame_db(character: String) -> Dictionary:
	if _frame_dbs.has(character):
		return _frame_dbs[character]
	var db: Dictionary = {}
	var path: String = FRAMES_JSON % character
	var data = null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is JSON:
			data = res.data
	if data == null and FileAccess.file_exists(path):
		data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) == TYPE_DICTIONARY and ResourceLoader.exists(String(data.atlas)):
		db = {"meta": data, "atlas": load(String(data.atlas))}
		if ResourceLoader.exists(String(data.get("flex", ""))):
			db["flex"] = load(String(data.flex))
		if ResourceLoader.exists(String(data.get("sil", ""))):
			db["sil"] = load(String(data.sil))
	_frame_dbs[character] = db
	return db


## Material próprio (cada personagem tem uniforms de curvatura/vento/dissolução).
func _flex_material() -> ShaderMaterial:
	if _flex_mat == null:
		_flex_mat = ShaderMaterial.new()
		_flex_mat.shader = load(FLEX_SHADER)
	return _flex_mat


## Grade de vértices (MESH_COLS×MESH_ROWS) de um retângulo da folha, com os
## vértices em px da folha RELATIVOS À ÂNCORA (y=0 = pé). Devolve
## {pts, uvs, idx}; o desenho escala pro mundo e o shader dobra por altura.
## (Triângulos direto no RenderingServer: sem recurso Mesh por quadro, o
## lote de polígonos do canvas cuida de dezenas de personagens.)
static func grid_mesh(key: String, rect: Rect2, anchor: Vector2, sheet_size: Vector2, flip: bool = false) -> Dictionary:
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in MESH_ROWS + 1:
		for c in MESH_COLS + 1:
			var fx: float = float(c) / MESH_COLS
			var fy: float = float(r) / MESH_ROWS
			var px: float = rect.position.x + rect.size.x * fx
			var py: float = rect.position.y + rect.size.y * fy
			var vx: float = px - anchor.x
			if flip:
				vx = -vx
			verts.append(Vector2(vx, py - anchor.y))
			uvs.append(Vector2(px, py) / sheet_size)
	for r in MESH_ROWS:
		for c in MESH_COLS:
			var i: int = r * (MESH_COLS + 1) + c
			idx.append_array([i, i + 1, i + MESH_COLS + 2, i, i + MESH_COLS + 2, i + MESH_COLS + 1])
	var grid := {"pts": verts, "uvs": uvs, "idx": idx}
	_mesh_cache[key] = grid
	return grid


## Desenha a grade no item `ci` com os pontos já transformados por `xf`.
static func draw_grid(ci: RID, grid: Dictionary, xf: Transform2D, tex: Texture2D, col: Color) -> void:
	var pts: PackedVector2Array = xf * PackedVector2Array(grid.pts)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(col)
	RenderingServer.canvas_item_add_triangle_array(ci, grid.idx, pts, cols, grid.uvs, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())


## Estado de animação → sequência do banco (com cadeia de reserva).
func _hero_seq(states: Dictionary) -> String:
	var st: String = anim_state
	if st == "dodge" and dodge_back:
		st = "dodge_back"
	var chain := {
		"walk": ["run"], "charge": ["run"], "dodge_back": ["dodge"], "attack_up": ["attack_heavy", "attack"],
		"attack_air": ["attack_heavy", "attack"], "attack_dive": ["attack_air", "attack_heavy", "attack"],
		"windup_heavy": ["windup"], "windup_cast": ["cast"], "fall": ["jump"], "dead": ["hurt"],
		"recover": ["idle"], "attack_heavy": ["attack"],
	}
	# ação avulsa por cima do estado (aparo, contra-ataque): play_action()
	if _action != "" and states.has(_action):
		return _action
	if _rise_t > 0.0 and st in ["idle", "walk"] and states.has("rise"):
		return "rise"
	if _land_t > 0.0 and st in ["idle", "walk"] and states.has("land"):
		return "land"
	if st in ["walk", "charge"] and USE_RUN_INBETWEENS and states.has("run16"):
		return "run16"
	if st in ["walk", "charge"] and states.has("rund"):
		return "rund"          # ciclo todo DESENHADO (s2 + s11), sem meios do RIFE
	if st in ["windup", "attack"] and combo_step > 0 and states.has(st + str(combo_step)):
		return st + str(combo_step)
	if st == "idle" and _combat_clock < 1.8 and states.has("ready"):
		return "ready"
	if states.has(st):
		return st
	for alt in chain.get(st, []):
		if states.has(alt):
			return alt
	return "idle"


## Índice do quadro: corrida pela DISTÂNCIA percorrida; o resto por tempo
## (dur[i] por quadro, o último segura; loop/fps opcionais).
func _seq_index(seq: Dictionary, seq_name: String) -> int:
	var n: int = seq.frames.size()
	if n <= 1:
		return 0
	if seq_name.begins_with("run"):
		# fase pela DISTÂNCIA: cada quadro dura o quanto o pé apoiado recua
		# nele (advance, px da folha) — o pé volta ao mesmo ponto a cada troca
		var world_k: float = profile.height * 1.19 / float(frame_db("sophia").meta.body_px) if painted.get("hero", false) else 1.0
		var adv: Array = seq.get("advance", [])
		if adv.size() == n:
			var total: float = 0.0
			for v in adv:
				total += float(v) * world_k
			var d: float = fposmod(motion_distance, maxf(total, 1.0))
			for j in n:
				d -= float(adv[j]) * world_k
				if d < 0.0:
					return j
			return n - 1
		var cycle: float = float(seq.get("cycle_bodies", 1.6)) * profile.height * 1.19
		return int(fposmod(motion_distance / maxf(cycle, 1.0), 1.0) * n) % n
	if seq.get("loop", false) and float(seq.get("fps", 0.0)) > 0.0:
		return int(anim_time * float(seq.fps)) % n
	var t: float = _action_t if seq_name != "" and seq_name == _action else anim_time
	var durs: Array = seq.get("dur", [])
	for i in n - 1:
		var d: float = float(durs[i]) if i < durs.size() else (float(durs.back()) if not durs.is_empty() else 0.1)
		if t < d:
			return i
		t -= d
	return n - 1


func _draw_painted(s: float) -> void:
	var tint := Color.WHITE
	if profile.painted_id == "sombra_sophia":
		tint = Color("745581")
	var mat: ShaderMaterial = _flex_material()
	var hero: bool = painted.get("hero", false)
	var db: Dictionary = frame_db("sophia") if hero else {}
	var tex: Texture2D
	var mesh: Dictionary
	var k: float               # px da folha → px do mundo
	var body_h: float          # altura do corpo em px da folha (base da curvatura)
	var m: Array               # [ox, rot, sx, sy, oy, bend(px de mundo)]
	var tip := Vector2.INF
	var flex_tex: Texture2D = null
	if hero and not db.is_empty():
		var meta: Dictionary = db.meta
		var seq_name: String = _hero_seq(meta.states)
		var seq: Dictionary = meta.states[seq_name]
		var i: int = _seq_index(seq, seq_name)
		var e: Dictionary = seq.frames[i]
		var fr: Dictionary = meta.frames[e.f]
		var rr: Array = fr.rect
		var rect := Rect2(rr[0], rr[1], rr[2], rr[3])
		var anchor := Vector2(e.anchor[0], e.anchor[1])
		tex = db.atlas
		flex_tex = db.get("flex", null)
		# âncora e ponta do cajado vêm em px LOCAIS do quadro; a grade usa px do atlas
		mesh = grid_mesh("sophia:%s@%s" % [e.f, anchor], rect, rect.position + anchor, Vector2(tex.get_width(), tex.get_height()))
		_geo_fr = fr
		_geo_anchor = anchor
		body_h = float(meta.body_px)
		k = profile.height * 1.19 / body_h
		if fr.tip != null:
			tip = (Vector2(fr.tip[0], fr.tip[1]) - anchor) * k
		var key: String = seq_name + ":" + str(i)
		if key != _shown_key:
			_on_frame_changed(seq, seq_name, i, tip)
			_shown_key = key
		m = _hero_motion()
	elif has_boss_frames():
		# CHEFE POR QUADROS: mesma lógica da Sophia (atlas + âncora por quadro);
		# escala e lugar herdados da pintura antiga (meta.fit) → o corpo ocupa
		# o mesmo espaço do boneco (colisões/_fit_body coerentes).
		var meta: Dictionary = _boss_db.meta
		var seq_name: String = _boss_seq(meta.states)
		var seq: Dictionary = meta.states[seq_name]
		var i: int = _boss_index(seq)
		var e: Dictionary = seq.frames[i]
		var fr: Dictionary = meta.frames[e.f]
		var rr: Array = fr.rect
		var rect := Rect2(rr[0], rr[1], rr[2], rr[3])
		var anchor := Vector2(e.anchor[0], e.anchor[1])
		tex = _boss_db.atlas
		flex_tex = _boss_db.get("flex", null)
		mesh = grid_mesh("%s:%s@%s" % [meta.character, e.f, anchor], rect, rect.position + anchor, Vector2(tex.get_width(), tex.get_height()))
		body_h = float(meta.body_px)
		var hw: float = _boss_world_h()
		k = hw * float(meta.fit.body_frac) / body_h
		var key: String = seq_name + ":" + str(i)
		if key != _shown_key:
			_on_boss_frame_changed(seq, i)
			_shown_key = key
		m = _boss_m.duplicate() if _death_t < 0.0 else _death_motion()
		# pé e centro do corpo onde estavam na pintura antiga (unidades do corpo)
		m[0] = float(m[0]) + float(meta.fit.dx) * hw / s
		m[4] = float(m[4]) - float(meta.fit.foot_gap) * hw / s
		_boss_shown = {"rect": rect, "anchor": anchor, "k": k, "tex": tex}
		_geo_fr = fr
		_geo_anchor = anchor
		if fr.has("head"):
			_boss_shown["head"] = Vector2(fr.head[0], fr.head[1])
		# criaturas comuns: mesma tinta leve por tipo da pintura única
		if painted.get("sheet", "") == "inhabitants" and not painted.get("bot", false) and not profile.painted_id in ["soter", "velkar", "sleeper"]:
			tint = Color.WHITE.lerp(profile.primary.lightened(0.3), 0.22)
	else:
		var rect: Rect2
		var anchor: Vector2
		if hero:
			# reserva: 6 poses antigas, mesma ESCALA (sem normalizar por altura)
			var frame: int = 0
			if anim_state in ["walk", "charge"]: frame = 1 + int(fposmod(motion_distance / (profile.height * 0.9), 1.0) * 2.0) % 2
			elif anim_state in ["jump", "fall", "dodge"]: frame = 2
			elif anim_state in ["windup", "windup_heavy", "windup_cast", "block"]: frame = 3
			elif anim_state.begins_with("attack"): frame = 4
			elif anim_state == "cast": frame = 5
			var anchors := [Vector2(269,492),Vector2(268,488),Vector2(267,493),Vector2(265,453),Vector2(239,455),Vector2(236,468)]
			rect = Rect2((frame % 3) * 512, (frame / 3) * 512, 512, 512)
			anchor = rect.position + anchors[frame]
			tex = PaintedLibrary.sheet("sophia")
			body_h = 466.0
			m = _hero_motion()
		else:
			tex = PaintedLibrary.sheet(painted.sheet)
			rect = painted.rect
			anchor = Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)
			body_h = rect.size.y
			if painted.sheet == "inhabitants" and not profile.painted_id in ["soter", "velkar", "sleeper"]:
				tint = Color.WHITE.lerp(profile.primary.lightened(0.3), 0.22)
			m = _painted_motion()
		var h: float = profile.height * 1.19 if hero else profile.height * 1.30
		if not hero and painted.sheet == "yaldabaoth":
			h = 190.0
		k = h / body_h
		mesh = grid_mesh("%s:%s@%s:%s" % [painted.get("sheet", "sophia"), rect, anchor, painted.get("flip", false)], rect, anchor, Vector2(tex.get_width(), tex.get_height()), painted.get("flip", false))
	# --- uniforms do shader (curvatura, vento, dissolução) ---
	mat.set_shader_parameter("body_h", body_h * k)
	mat.set_shader_parameter("bend", float(m[5]))
	mat.set_shader_parameter("wind_time", _wind_time)
	mat.set_shader_parameter("use_flex", flex_tex != null)
	if flex_tex != null:
		mat.set_shader_parameter("flex_mask", flex_tex)
	var running: bool = anim_state in ["walk", "charge", "dodge", "jump", "fall"]
	var framed_boss: bool = not hero and has_boss_frames()
	if framed_boss:
		# chefe: só o pano/trapos de baixo (G da máscara); onda da barra por receita
		var ca: float = float(_boss_db.meta.get("cloth_amp", 0.0))
		mat.set_shader_parameter("hair_amp", 0.0)
		mat.set_shader_parameter("cloth_amp", (ca * 1.5 if running else ca) if flex_tex != null else 0.0)
		mat.set_shader_parameter("hem_wave", float(_boss_db.meta.get("hem_wave", 0.0)) * (1.4 if running else 1.0))
		# contorno de luz na cor do Éon (inimigos; NPCs não): mais forte na preparação
		var rim: float = 0.0
		if rim_enabled and String(_boss_db.meta.get("kind", "")) != "npc":
			rim = RIM_BASE * (2.0 if anim_state.begins_with("windup") else 1.0)
		if _death_t >= 0.0:
			rim = _death_rim()                  # a luz vaza pela borda antes de quebrar
			tint = tint * _death_tint()
		mat.set_shader_parameter("rim_amt", rim)
		mat.set_shader_parameter("rim_color", _death_col if _death_t >= 0.0 else eon_light())
		mat.set_shader_parameter("rim_px", 6.0 if _death_t >= DEATH_FALL else 4.0)
		# família do Arconte SEM arte própria (interino #7): dessatura + tinta da criatura
		var family: bool = painted.get("family", false)
		mat.set_shader_parameter("sat_mul", 0.45 if family else 1.0)
		if family:
			tint = Color.WHITE.lerp(profile.primary.lightened(0.35), 0.5)
	else:
		mat.set_shader_parameter("hair_amp", (5.0 if running else 2.4) if flex_tex != null else 0.0)
		mat.set_shader_parameter("cloth_amp", (4.0 if running else 1.8) if flex_tex != null else 0.0)
		mat.set_shader_parameter("hem_wave", 2.0 if profile.body == ArtProfile.Body.WRAITH else 0.0)
	mat.set_shader_parameter("texel", Vector2(1.0 / tex.get_width(), 1.0 / tex.get_height()))
	mat.set_shader_parameter("dissolve", _dissolve_amount())
	mat.set_shader_parameter("glow_color", profile.eye)
	# --- desenho: corpo (transform limitado) + malha da pintura ---
	var rot: float = clampf(float(m[1]), -MAX_ROT, MAX_ROT)
	var sx: float = clampf(float(m[2]), 1.0 - MAX_SQUASH, 1.0 + MAX_SQUASH)
	var sy: float = clampf(float(m[3]) * (1.0 - _impact * 0.06), 1.0 - MAX_SQUASH, 1.0 + MAX_SQUASH)
	sx *= 1.0 + _impact * 0.06
	var origin := Vector2(float(m[0]) * s, GROUND_Y * s + float(m[4]) * s)
	draw_set_transform(origin, rot, Vector2(sx, sy))
	var mt := Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
	if framed_boss and telegraph_color.a > 0.0:
		# TELEGRAFO: contorno brilhante pulsando atrás do corpo (8 cópias
		# deslocadas, cor chapada) — a pintura continua legível por cima.
		var pulse: float = 0.75 + 0.25 * sin(_wind_time * 18.0)
		var glow := Color(telegraph_color.r * 1.4, telegraph_color.g * 1.4, telegraph_color.b * 1.4, telegraph_color.a * pulse)
		var w: float = 1.3 / maxf(absf(sx), 0.5)
		for j in 8:
			var off := Vector2.from_angle(TAU * j / 8.0) * w
			draw_grid(get_canvas_item(), mesh, Transform2D(0.0, Vector2(k, k), 0.0, off), _silhouette_tex(tex), glow)
	draw_grid(get_canvas_item(), mesh, mt, tex, tint)
	_body_xform = Transform2D(rot, Vector2(sx, sy), 0.0, origin) * mt
	_body_mesh = mesh
	_body_tex = tex
	_body_tip = tip
	_draw_smear()
	if hero and tip != Vector2.INF:
		_draw_weapon_glow(tip)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# O nível da arma mantém feedback visual sem trocar os atributos do combate.
	# (Com os quadros desenhados o nível aparece no cristal do cajado —
	# _draw_weapon_glow; as marcas antigas só valem na reserva das 6 poses.)
	if profile.has("hero") and profile.has("pauldrons") and frame_db("sophia").is_empty():
		var strength: float = 0.22 if not profile.has("aura") else 0.65
		draw_arc(Vector2(0,-29*s),8*s,-2.8,-0.35,24,Color(profile.eye,strength),0.7,true)
		var marks: int = 1 + int(profile.has("helmet")) + int(profile.has("bracers")) + int(profile.has("aura"))
		for i in marks:
			var a: float = -2.5 + i*0.54
			var point := Vector2(0,-29*s) + Vector2(cos(a),sin(a))*9*s
			draw_circle(point,0.8*s,Color(profile.eye,0.65))
	if damage_ratio > 0.45 and profile.height >= 70:
		draw_arc(Vector2(0,GROUND_Y*s-30*s),24*s,0.15,2.7,40,Color(profile.eye,0.38),1.0,true)


var _body_xform := Transform2D.IDENTITY   # último transform do corpo (afterimage)
var _geo_fr: Dictionary = {}               # quadro desenhado agora (geometria medida no atlas)
var _geo_anchor := Vector2.ZERO


## GEOMETRIA DO QUADRO DESENHADO AGORA (Onda 6, "o cajado atravessa"): medida
## offline na silhueta de cada quadro (tools/anim/geometry.py) e levada pelo
## mesmo transform do corpo (âncora, escala, tranco, flip do pai). Coordenadas
## LOCAIS deste nó (use `to_global` / `global=true` para o mundo). Chaves:
##   body: Rect2        caixa do corpo (sem cajado/arma fina nem fios soltos)
##   body_poly: PackedVector2Array   contorno convexo do corpo (≤ 10 pontos)
##   staff: PackedVector2Array [cabo, ponta]   eixo do cajado (só a Sophia)
##   staff_estimated: bool   cajado cruzando o corpo (eixo estimado da ponta)
##   tip: Vector2       ponta de cristal do cajado (só a Sophia)
## Vazio se o personagem não toca quadros desenhados (boneco/pintura única).
func frame_geometry(global: bool = false) -> Dictionary:
	if _geo_fr.is_empty() or not _geo_fr.has("body"):
		return {}
	var xf: Transform2D = _body_xform
	if global:
		xf = get_global_transform() * xf
	var out: Dictionary = {}
	var b: Array = _geo_fr.body
	var corners := PackedVector2Array()
	for cc in [Vector2(b[0], b[1]), Vector2(b[0] + b[2], b[1]), Vector2(b[0] + b[2], b[1] + b[3]), Vector2(b[0], b[1] + b[3])]:
		corners.append(xf * (cc - _geo_anchor))
	var r := Rect2(corners[0], Vector2.ZERO)
	for cc in corners:
		r = r.expand(cc)
	out["body"] = r
	if _geo_fr.has("body_poly"):
		var poly := PackedVector2Array()
		for p in _geo_fr.body_poly:
			poly.append(xf * (Vector2(p[0], p[1]) - _geo_anchor))
		out["body_poly"] = poly
	if _geo_fr.has("staff"):
		var s: Array = _geo_fr.staff
		out["staff"] = PackedVector2Array([xf * (Vector2(s[0], s[1]) - _geo_anchor), xf * (Vector2(s[2], s[3]) - _geo_anchor)])
		out["staff_estimated"] = bool(_geo_fr.get("staff_est", false))
		out["tip"] = out.staff[1]
	return out
var _body_mesh: Dictionary = {}
var _body_tex: Texture2D
var _body_tip := Vector2.INF


## Número ou lista do JSON (floats) → lista de inteiros.
static func _int_list(v) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			out.append(int(x))
	elif v != null:
		out.append(int(v))
	return out


## Troca de quadro: passo no chão (som), início do smear do cajado.
func _on_frame_changed(seq: Dictionary, seq_name: String, i: int, tip: Vector2) -> void:
	if seq_name.begins_with("run") and i in _int_list(seq.get("steps", [])) and is_visible_in_tree():
		Audio.play_sfx("step", 0.08, -6.0)
	if i in _int_list(seq.get("smear_at", [])) and tip != Vector2.INF and _body_tip != Vector2.INF:
		_smear = {"a": _body_tip, "b": tip}
		_smear_clock = 0.0
	if anim_state == "dead" and i == seq.frames.size() - 1 and seq.frames.size() > 1:
		_impact = 1.0


## Nível da arma da Sophia (1..5): override do QA ou Progression (só leitura).
func _weapon_level() -> int:
	if weapon_level_override > 0:
		return clampi(weapon_level_override, 1, 5)
	return clampi(int(Progression.weapon_level), 1, 5)


## PROGRESSÃO DA ARMA VISÍVEL (#46), sem arte nova: o cristal do cajado (ponta
## medida por quadro no atlas) ganha halo maior, cor mais quente e pulso a cada
## nível; nível 3+ cintila em cruz; 4+ motes orbitam o cristal; 5 ganha um
## anel dourado. (Bracelete: sem posição medida por quadro — fica de fora.) Desenhado no espaço do corpo (curva junto).
func _draw_weapon_glow(tip: Vector2) -> void:
	var lvl: int = _weapon_level()
	var body: float = profile.height * 1.19
	var t: float = _wind_time
	var cast_boost: float = 1.2 if anim_state in ["cast", "windup_cast", "attack_heavy"] else 1.0
	var core: Color = Color(0.55, 0.9, 1.0).lerp(Color(1.0, 0.97, 0.85), clampf((lvl - 2) / 3.0, 0.0, 1.0))
	var pulse: float = 1.0 + 0.12 * sin(t * (2.0 + lvl * 0.6))
	var radii := [1.3, 1.9, 2.5, 3.1, 3.8]
	var alphas := [0.10, 0.17, 0.24, 0.31, 0.38]
	var r: float = float(radii[lvl - 1]) * pulse * cast_boost * body / 55.0
	var a: float = float(alphas[lvl - 1]) * cast_boost
	# halo em camadas (de fora pra dentro)
	draw_circle(tip, r * 1.6, Color(core, a * 0.35))
	draw_circle(tip, r, Color(core, a))
	draw_circle(tip, r * 0.45, Color(1, 1, 1, minf(1.0, a * 1.6)))
	if lvl >= 3:
		# cintilação em cruz, girando devagar
		var ang: float = t * 0.8
		var len: float = r * (1.6 + 0.3 * (lvl - 3))
		for k in 2:
			var d := Vector2.from_angle(ang + k * PI * 0.5) * len
			draw_line(tip - d, tip + d, Color(core, a * 0.9), 0.5 + 0.1 * lvl, true)
	if lvl >= 4:
		# motes orbitando o cristal
		for k in lvl - 2:
			var o: float = t * (1.6 + k * 0.3) + k * TAU / float(lvl - 2)
			draw_circle(tip + Vector2(cos(o), sin(o) * 0.6) * r * 2.2, 0.5 + 0.1 * lvl, Color(core, 0.75))
	if lvl >= 5:
		draw_arc(tip, r * 1.35, 0.0, TAU, 28, Color(1.0, 0.85, 0.45, 0.55 * pulse), 0.6, true)


## Arco de smear do cajado: varre da ponta do quadro anterior até a ponta do
## golpe em volta do ombro, ~0,11 s, mais forte na cabeça do arco.
func _draw_smear() -> void:
	if _smear.is_empty():
		return
	var life: float = 0.11
	if _smear_clock > life:
		_smear = {}
		return
	var fade: float = 1.0 - _smear_clock / life
	var a: Vector2 = _smear.a
	var b: Vector2 = _smear.b
	var c := Vector2(0.0, -profile.height * 1.19 * 0.74)     # ombro, aproximado
	var a0: float = (a - c).angle()
	var a1: float = (b - c).angle()
	var da: float = wrapf(a1 - a0, -PI, PI)
	var r0: float = (a - c).length()
	var r1: float = (b - c).length()
	var n: int = 14
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var cols := PackedColorArray()
	for j in n + 1:
		var u: float = float(j) / n
		var ang: float = a0 + da * u
		var r: float = lerpf(r0, r1, u)
		outer.append(c + Vector2.from_angle(ang) * r)
		inner.append(c + Vector2.from_angle(ang) * r * lerpf(0.86, 0.55, u))
	# arma mais forte = rastro mais denso, mais quente e com faíscas (#46)
	var lvl: int = _weapon_level() if painted.get("hero", false) else 1
	var rich: float = 0.75 + 0.08 * lvl
	var tone: Color = Color(0.80, 0.98, 1.0).lerp(Color(1.0, 0.95, 0.75), clampf((lvl - 3) / 2.0, 0.0, 1.0))
	var pts := PackedVector2Array()
	for j in n + 1:
		pts.append(outer[j])
		cols.append(Color(tone, minf(1.0, 0.85 * rich) * fade * pow(float(j) / n, 1.6)))
	for j in range(n, -1, -1):
		pts.append(inner[j])
		cols.append(Color(0.55, 0.85, 1.0, 0.0))
	if pts.size() >= 3:
		draw_polygon(pts, cols)
	if lvl >= 3:
		# faíscas soltas ao longo do arco (mais a cada nível)
		for j in (lvl - 2) * 3:
			var u: float = fmod(0.13 + j * 0.37, 1.0)
			var ang: float = a0 + da * u
			var p: Vector2 = c + Vector2.from_angle(ang) * lerpf(r0, r1, u) * (1.0 + 0.06 * sin(j * 2.1))
			draw_circle(p, 0.6 + 0.15 * lvl, Color(tone, 0.9 * fade * u))


## Dissolução: criaturas comuns (sem boneco) e a Sophia morta não usam;
## a forma das criaturas se desfaz em ruído com borda luminosa.
func _dissolve_amount() -> float:
	if anim_state != "dead" or painted.get("hero", false) or _death_t >= 0.0:
		return 0.0
	return clampf((anim_time - 0.12) / 0.75, 0.0, 1.0) * dissolve_max


## Avança relógios visuais (chamado por _process).
func _tick_visual(delta: float) -> void:
	_wind_time += delta
	_smear_clock += delta
	_impact = move_toward(_impact, 0.0, delta * 6.0)
	if has_boss_frames():
		_tick_boss(delta)
	_tick_death(delta)
	if _npc_wake_t >= 0.0:
		_npc_wake_t += delta
	_tick_action(delta)
	_land_t = maxf(0.0, _land_t - delta)
	if _rise_t > 0.0:
		_rise_t = maxf(0.0, _rise_t - delta)
	if anim_state.begins_with("attack") or anim_state.begins_with("windup") or anim_state in ["cast", "hurt", "block"]:
		_combat_clock = 0.0
	else:
		_combat_clock += delta
	if is_inside_tree():
		var x: float = global_position.x
		if _last_x != INF:
			motion_distance += absf(x - _last_x)
		_last_x = x
	# passo das criaturas: fase pela distância (meia passada = um apoio)
	if not painted.is_empty() and not painted.get("hero", false) and not painted.has("puppet") and anim_state in ["walk", "charge"]:
		if profile.body != ArtProfile.Body.WRAITH:
			var stride: float = profile.height * (0.55 if profile.body != ArtProfile.Body.BEAST else 0.4)
			var ph: int = int(motion_distance / maxf(stride, 1.0))
			if _step_phase >= 0 and ph != _step_phase and is_visible_in_tree():
				var heavy: bool = profile.body in [ArtProfile.Body.BRUTE, ArtProfile.Body.COLOSSUS] or profile.height >= 70.0
				Audio.play_sfx_at("step_heavy" if heavy else "step", global_position, 0.1)
			_step_phase = ph
	else:
		_step_phase = -1
	# afterimages: esquiva (rastro contínuo) e golpe forte (no instante do golpe)
	if painted.get("hero", false) and not _body_mesh.is_empty():
		_ghost_timer -= delta
		if anim_state == "dodge" and _ghost_timer <= 0.0 and anim_time < 0.26:
			spawn_afterimage(Color(0.55, 0.85, 1.0, 0.55), 0.09)
			_ghost_timer = 0.035
		elif anim_state == "attack_heavy" and anim_time < 0.09 and _ghost_timer <= 0.0:
			spawn_afterimage(Color(1.0, 0.92, 0.6, 0.6), 0.08)
			_ghost_timer = 0.03


## AÇÃO AVULSA da Sophia por cima do estado do player (quadros S14):
## "parry" (aparo + desvio + abertura) e "riposte" (estocada, giro, follow,
## volta à guarda). O player.gd ainda não chama isto (Pedido ao combate); o
## aparo é reconhecido pelo flash próprio do _parry (modulate azul > 3,5)
## enquanto o estado é "block".
var _action: String = ""
var _action_t: float = 0.0


## A Sophia tem essa ação DESENHADA? (ex.: "double_jump" — o player usa isto
## para trocar a pirueta por código pela cambalhota pintada da S17)
func has_action(action_name: String) -> bool:
	if not painted.get("hero", false):
		return false
	var db: Dictionary = frame_db("sophia")
	return not db.is_empty() and db.meta.states.has(action_name)


func play_action(action_name: String) -> void:
	if not has_action(action_name):
		return
	_action = action_name
	_action_t = 0.0
	anim_time = 0.0
	queue_redraw()             # troca a pose mesmo com o mundo pausado (cena com caixa de diálogo)


## Encerra a ação avulsa (as poses `hold` da cena do Soter ficam até aqui).
func stop_action() -> void:
	_action = ""
	queue_redraw()


## COLUNA DE LUZ da bênção do Soter (Fila 9: a luz pintada na folha não se
## separa do corpo — é refeita aqui): feixe morno aditivo descendo sobre ela,
## mais forte no meio, com o miolo pulsando. Anima com o jogo pausado.
## `on = false` apaga em `fade` s.
func bless_light(on: bool = true, fade: float = 0.6) -> void:
	var old: Node2D = get_node_or_null("BlessLight") as Node2D
	if not on:
		if old != null:
			var t := old.create_tween()
			t.tween_property(old, "modulate:a", 0.0, fade)
			t.tween_callback(old.queue_free)
		return
	if old != null:
		return
	var root := Node2D.new()
	root.name = "BlessLight"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.z_index = 1
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var h: float = profile.height * 1.19 * 2.4
	var foot: float = GROUND_Y * profile.height / 44.0
	# faixas verticais com alfa caindo para as bordas (feixe macio, sem quina);
	# a camada 1 é o miolo estreito que pulsa
	for layer in 2:
		var half: float = profile.height * (0.6 if layer == 0 else 0.24)
		var peak: float = 0.26 if layer == 0 else 0.3
		var band := Node2D.new()
		root.add_child(band)
		var n: int = 10
		for k in n:
			var x0: float = -half + 2.0 * half * float(k) / n
			var x1: float = -half + 2.0 * half * float(k + 1) / n
			var xm: float = (x0 + x1) * 0.5 / half
			var a: float = peak * pow(maxf(0.0, 1.0 - xm * xm), 1.5)
			var poly := Polygon2D.new()
			poly.material = add
			poly.polygon = PackedVector2Array([Vector2(x0, foot - h), Vector2(x1, foot - h), Vector2(x1 * 0.85, foot + 2.0), Vector2(x0 * 0.85, foot + 2.0)])
			var top := Color(1.0, 0.92, 0.62, 0.0)
			var low := Color(1.0, 0.86, 0.52, a)
			poly.vertex_colors = PackedColorArray([top, top, low, low])
			band.add_child(poly)
	add_child(root)
	root.modulate.a = 0.0
	var t2 := root.create_tween()
	t2.tween_property(root, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	# miolo respirando (luz viva, não um retângulo parado)
	var pulse := root.create_tween().set_loops()
	pulse.tween_property(root.get_child(1), "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(root.get_child(1), "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _tick_action(delta: float) -> void:
	if not painted.get("hero", false):
		return
	if _action == "" and anim_state == "block" and modulate.b > 3.5:
		play_action("parry")
	if _action == "":
		return
	_action_t += delta
	var seq: Dictionary = frame_db("sophia").meta.states.get(_action, {})
	var total: float = 0.0
	for d in seq.get("dur", []):
		total += float(d)
	# pose de cena (`hold`, S19 do Soter): fica até stop_action() ou ela se mexer
	if seq.get("hold", false):
		if anim_state != "idle":
			_action = ""
		return
	# o aparo acaba junto com a guarda; o contra-ataque vai até o fim
	if _action_t > total + 0.12 or (_action == "parry" and anim_state != "block"):
		_action = ""
	# recuperação e freada só valem enquanto ela está parada (andou/atacou = corta)
	elif (_action.begins_with("rec_") or _action == "stop_run") and anim_state != "idle":
		_action = ""
	# largada só enquanto corre; pulo duplo só no ar (golpe/esquiva/pouso = corta)
	elif _action == "start_run" and anim_state != "walk":
		_action = ""
	elif _action == "double_jump" and not anim_state in ["jump", "fall"]:
		_action = ""


## Cópia translúcida do corpo neste instante, parada no mundo, que some em
## `life` s (60–90 ms). Aditiva e tingida — lê como rastro de luz.
func spawn_afterimage(col: Color, life: float = 0.08) -> void:
	if _body_mesh.is_empty() or not is_inside_tree():
		return
	if _ghosts == null or not is_instance_valid(_ghosts):
		# irmão (não filho): o nó do personagem não ganha filhos extras e o
		# rastro fica atrás do corpo; some junto com o personagem
		var host: Node = get_parent()
		if host == null:
			return
		_ghosts = AfterimageLayer.new()
		host.add_child(_ghosts)
		host.move_child(_ghosts, get_index())
		tree_exiting.connect(_ghosts.queue_free)
	_ghosts.add(get_global_transform() * _body_xform, _body_mesh, _body_tex, col, life)


## Movimento procedural da Sophia SOBRE os quadros desenhados: só empurrões
## pequenos (recuo, avanço, impacto). Sem girar o cartão: rotação ≤ 0,12 rad,
## squash ≤ ±7%; a inclinação vira CURVATURA no shader (bend, px de mundo no
## topo da cabeça, pés pregados).
## Devolve [ox, rot, sx, sy, oy, bend] (ox/oy em unidades do corpo).
func _hero_motion() -> Array:
	var t := anim_time
	var ox := 0.0
	var oy := 0.0
	var rot := 0.0
	var sx := 1.0
	var sy := 1.0
	var bend := 0.0
	match anim_state:
		"idle":
			sy = 1.0 + sin(t * 2.5) * 0.006
			bend = sin(t * 1.3) * 0.6
		"walk", "charge":
			bend = 1.5
		"dodge":
			var k := clampf(t / 0.30, 0.0, 1.0)
			var e := sin(k * PI)
			if dodge_back:
				ox = -2.0 * e
				bend = -4.0 * e
			else:
				ox = 2.5 * e
				bend = 6.0 * e
				sx = 1.0 + 0.06 * e
				sy = 1.0 - 0.06 * e
		"hurt":
			var k := 1.0 - clampf(t / 0.25, 0.0, 1.0)
			ox = -3.0 * k
			bend = -4.0 * k
			sx = 1.0 - 0.04 * k
			sy = 1.0 + 0.04 * k
		"block":
			sy = 0.97
			bend = -1.0
		"jump":
			var k := 1.0 - clampf(t / 0.2, 0.0, 1.0)
			sx = 1.0 - 0.05 * k
			sy = 1.0 + 0.06 * k
		"fall":
			sy = 0.98
		"windup", "windup_heavy", "windup_cast":
			var e := clampf(t / 0.08, 0.0, 1.0)
			sy = 1.0 - 0.03 * e
			bend = -2.5 * e
			if anim_state == "windup_heavy":
				ox = sin(t * 40.0) * 0.25 * e      # tremor curto segurando o peso
		"attack", "attack_up":
			var k := 1.0 - clampf(t / 0.18, 0.0, 1.0)
			bend = 3.5 * k
			sx = 1.0 + 0.04 * k
			sy = 1.0 - 0.03 * k
		"attack_heavy":
			var k := 1.0 - clampf(t / 0.25, 0.0, 1.0)
			bend = 5.0 * k
			sx = 1.0 + 0.06 * k
			sy = 1.0 - 0.06 * k
			ox = 1.5 * k
		"attack_air":
			rot = 0.10 * clampf(t / 0.32, 0.0, 1.0)
			bend = 2.0
		"attack_dive":
			rot = 0.12
			bend = 4.0
			sy = 1.04
		"cast":
			var k := clampf(t / 0.30, 0.0, 1.0)
			var e := smoothstep(0.0, 1.0, k)
			ox = lerpf(-1.5, 1.5, e)
			bend = lerpf(-2.0, 2.5, e)
			sx = 1.0 + 0.04 * sin(k * PI)
			sy = 1.0 - 0.03 * sin(k * PI)
	return [ox, clampf(rot, -MAX_ROT, MAX_ROT), sx, sy, oy, bend]


## Movimento das criaturas pintadas (peça única, sem boneco): o corpo inteiro
## conta a ação SEM girar o cartão — passo com quique e squash moderado pela
## DISTÂNCIA (os pés não patinam no ritmo), recuo comprimido no preparar,
## avanço esticado no golpe; inclinações viram curvatura no shader.
## Devolve [ox, rot, sx, sy, oy, bend].
func _painted_motion() -> Array:
	var t := anim_time
	var p: float = maxf(pose_progress, 0.0)
	var wraith: bool = profile.body == ArtProfile.Body.WRAITH
	var beast: bool = profile.body == ArtProfile.Body.BEAST
	var ox := 0.0
	var oy := 0.0
	var sx := 1.0
	var sy := 1.0
	var bend := 0.0
	var stride_len: float = profile.height * (0.4 if beast else 0.55)
	var ph: float = fposmod(motion_distance / maxf(stride_len, 1.0), 1.0)   # 0..1 por passo
	match anim_state:
		"walk", "charge":
			if wraith:
				oy = sin(t * 2.2) * 1.2
				bend = sin(t * 1.7) * 1.5
			else:
				var lift: float = sin(ph * PI)            # 0 no apoio, 1 no meio do passo
				oy = -lift * (1.4 if beast else 1.1)
				sy = 1.0 + 0.035 * lift - 0.035 * (1.0 - lift)
				sx = 1.0 - 0.02 * lift
				bend = 2.0 + sin(ph * TAU) * (1.2 if beast else 0.8)
				if anim_state == "charge":
					bend += 4.0
					ox = 2.0
		"windup", "windup_heavy", "windup_cast":
			var e := ease(p, 0.45)
			var tremor: float = sin(t * 38.0) * 0.3 * e
			ox = -3.0 * e + tremor
			sx = 1.0 - 0.05 * e
			sy = 1.0 + 0.05 * e
			bend = -4.0 * e
			if anim_state == "windup_heavy":
				ox = -1.5 * e + tremor
				sy = 1.0 + 0.07 * e
		"attack", "attack_heavy", "cast":
			var e := ease(clampf(p if pose_progress >= 0.0 else t / 0.25, 0.0, 1.0), 0.35)
			var punch: float = sin(e * PI)
			ox = (1.5 if anim_state == "cast" else 7.0) * punch
			bend = 6.0 * punch
			sx = 1.0 + 0.06 * punch
			sy = 1.0 - 0.05 * punch
			if anim_state == "attack_heavy":
				sy = 1.0 - 0.07 * punch
		"recover":
			var back: float = 1.0 - p
			ox = 2.0 * back
			bend = 2.0 * back
		"hurt":
			var k := 1.0 - clampf(t / 0.25, 0.0, 1.0)
			ox = -3.5 * k
			bend = -4.0 * k
			sx = 1.0 - 0.06 * k
			sy = 1.0 + 0.06 * k
		"dead":
			# afunda um pouco enquanto dissolve (sem tombar o cartão)
			var k := clampf(t / 0.5, 0.0, 1.0)
			sy = 1.0 - 0.05 * k
			bend = -2.0 * k
		_:
			if wraith:
				oy = sin(t * 1.7) * 1.0
				bend = sin(t * 1.3) * 1.2
			else:
				sy = 1.0 + sin(t * 2.0) * 0.008
	return [ox, 0.0, sx, sy, oy, bend]


# =========================================================================
# CHEFES POR QUADROS DESENHADOS (folhas do GPT, docs/ANIMACAO_CHEFES.md)
# =========================================================================
# Atlas + JSON de tools/anim_bosses/boss_frames.py. Troca SECA entre os quadros
# pintados (idle/andar com meios do RIFE em vaivém), HOLD no quadro da
# preparação com tensão e tremor, ESTALO no golpe (mola com sobressalto +
# afterimage), recuo no dano, dissolução na morte. O movimento extra é uma
# MOLA amortecida em (avanço, curvatura do shader) — o "boneco leve" por cima
# dos quadros, sem girar o cartão. O BossPuppet fica de reserva (sem atlas).

var _boss_db: Dictionary = {}                     # {meta, atlas, flex, sil} ou {} (= boneco)
var _boss_m: Array = [0.0, 0.0, 1.0, 1.0, 0.0, 0.0]   # [ox, rot, sx, sy, oy, bend] da mola
var _bsp := Vector2.ZERO                          # mola: (avanço x, curvatura) atuais
var _bsv := Vector2.ZERO
var _boss_state_seen: String = ""
var _boss_shown: Dictionary = {}                  # último quadro desenhado (gibs)
var _npc_asleep: bool = false                     # Adormecido ainda dormindo
var _npc_wake_t: float = -1.0                     # s desde o despertar (-1 = não)
## Contorno do telegrafo (cor; a = intensidade). Nos chefes por quadros o tom
## chapado da preparação (Enemy.TELEGRAPH_*) vira este contorno pulsante.
var telegraph_color := Color(0, 0, 0, 0)
const _TELEGRAPH_TINTS := [Color(1.0, 0.85, 0.2, 1.0), Color(1.0, 0.25, 0.25, 1.0)]


const RIM_BASE := 0.32              # contorno de luz dos inimigos (≈0,3; ×2 na preparação)
static var rim_override: int = -1   # QA: força o Éon da cor do contorno (-1 = tela atual)
var rim_enabled: bool = true        # QA/cenas: desliga o contorno deste personagem
var weapon_level_override: int = -1 # QA: força o nível da arma da Sophia (-1 = Progression)


## Cor de luz do Éon atual (SceneryLibrary.LOOK "glow", só leitura) para o
## contorno dos inimigos — cada Éon separa os seus bichos do fundo na sua cor.
static func eon_light() -> Color:
	var eon: int = rim_override
	if eon < 0:
		eon = RunManager.eon_index(GameManager.current_screen)
	var lk: Dictionary = SceneryLibrary.look(eon)
	return Color(lk.get("glow", Color(0.8, 0.9, 1.0)))


## true quando este chefe toca quadros desenhados (senão, o boneco).
func has_boss_frames() -> bool:
	return not _boss_db.is_empty()


## Altura do recorte antigo em px de mundo (a mesma conta do boneco).
func _boss_world_h() -> float:
	return 190.0 if int(painted.get("puppet", -1)) == 8 else profile.height * 1.3


## Estado de animação → sequência do atlas do chefe (com reserva).
func _boss_seq(states: Dictionary) -> String:
	var st: String = anim_state
	if _death_t >= 0.0:
		return _death_seq(states)
	if _npc_asleep and states.has("asleep"):
		return "asleep"
	if _npc_wake_t >= 0.0 and states.has("wake") and st == "idle":
		var total: float = 0.0
		for d in states.wake.get("dur", []):
			total += float(d)
		if _npc_wake_t < total + 0.3:
			return "wake"
	if states.has(st):
		return st
	var chain := {"charge": ["attack", "walk"], "windup_heavy": ["windup"], "windup_cast": ["windup"],
		"attack_heavy": ["attack"], "cast": ["attack"], "attack_up": ["attack"], "attack_air": ["attack"],
		"attack_dive": ["attack"], "stagger": ["hurt"], "block": ["hurt"], "dodge": ["walk"],
		"dead": ["hurt"], "recover": ["idle"], "jump": ["idle"], "fall": ["idle"]}
	for alt in chain.get(st, []):
		if states.has(alt):
			return alt
	return "idle"


## Quadro da sequência: andar pela DISTÂNCIA (cycle_bodies), laços pelo relógio
## contínuo (não reinicia a cada idle↔walk), `at` pelo PROGRESSO real do
## inimigo (preparação/golpe/recuperação), senão `dur` por quadro.
func _boss_index(seq: Dictionary) -> int:
	var n: int = seq.frames.size()
	if n <= 1:
		return 0
	if _death_t >= DEATH_STAGGER:
		return n - 1                          # morte encenada: o quadro de queda
	if _death_t >= 0.0:
		return 0
	if seq.has("cycle_bodies"):
		var cyc: float = float(seq.cycle_bodies) * _boss_world_h() * float(_boss_db.meta.fit.body_frac)
		return int(fposmod(motion_distance / maxf(cyc, 1.0), 1.0) * n) % n
	if seq.get("loop", false) and float(seq.get("fps", 0.0)) > 0.0:
		return int(_wind_time * float(seq.fps) * motion_fury) % n
	if seq.has("at") and pose_progress >= 0.0:
		var at: Array = seq.at
		var idx: int = 0
		for j in mini(n, at.size()):
			if pose_progress >= float(at[j]):
				idx = j
		return idx
	if _npc_wake_t >= 0.0 and is_same(_boss_db.meta.states.get("wake", {}), seq):
		# acordar: relógio próprio (o estado do nó continua "idle")
		var t: float = _npc_wake_t
		var durs: Array = seq.get("dur", [])
		for i in n - 1:
			var d: float = float(durs[i]) if i < durs.size() else 0.3
			if t < d:
				return i
			t -= d
		return n - 1
	return _seq_index(seq, "")


func _on_boss_frame_changed(seq: Dictionary, i: int) -> void:
	if anim_state == "dead" and i == seq.frames.size() - 1 and seq.frames.size() > 1:
		_impact = 1.0
	# efeito que a folha trazia PINTADO e foi apagado no recorte (pó do sono da
	# mariposa): refeito por partícula na frente do corpo ao entrar na sequência
	if i == 0 and seq.has("puff") and is_visible_in_tree() and not _boss_shown.is_empty():
		var pc: Array = seq.puff
		var r: Rect2 = _boss_shown.rect
		var front: Vector2 = _body_xform * (Vector2(r.size.x * 0.88, r.size.y * 0.42) - _boss_shown.anchor)
		call_deferred("_puff_at", to_global(front), Color(float(pc[0]), float(pc[1]), float(pc[2]), 0.85))
	if i in _int_list(seq.get("impact_at", [])) and i > 0:
		spawn_afterimage(Color(profile.eye, 0.5), 0.09)


func _puff_at(pos: Vector2, col: Color) -> void:
	var host: Node = get_tree().current_scene if is_inside_tree() else null
	if host != null:
		VfxLibrary.cast(host, pos, col)


func _silhouette_tex(tex: Texture2D) -> Texture2D:
	return _boss_db.get("sil", tex)


## Mola + poses de corpo inteiro dos chefes por quadros (chamada por _tick_visual).
func _tick_boss(delta: float) -> void:
	var entered: bool = anim_state != _boss_state_seen
	_boss_state_seen = anim_state
	var t: float = anim_time
	var p: float = pose_progress if pose_progress >= 0.0 else clampf(t / 0.4, 0.0, 1.0)
	var spirit: bool = String(_boss_db.meta.get("kind", "")) == "spirit"
	var heavy: float = 1.3 if anim_state in ["attack_heavy", "windup_heavy"] else 1.0
	var goal := Vector2.ZERO
	var sx: float = 1.0
	var sy: float = 1.0
	var oy: float = 0.0
	var tremor: float = 0.0
	var freq: float = 3.2
	var damp: float = 0.75
	match anim_state:
		"windup", "windup_heavy", "windup_cast":
			# chega à pose em 35% do tempo e SEGURA: tensão crescente + tremor fino
			var e: float = (1.0 - pow(1.0 - clampf(p / 0.35, 0.0, 1.0), 3.0)) * (1.0 + 0.10 * smoothstep(0.35, 1.0, p))
			goal = Vector2(-2.0, -3.5) * e * heavy
			sx = 1.0 - 0.025 * e
			sy = 1.0 + 0.035 * e * heavy
			tremor = sin(_wind_time * 47.0) * 0.3 * smoothstep(0.45, 1.0, p)
			freq = 5.0
			damp = 0.85
		"attack", "attack_heavy", "cast", "attack_up", "charge":
			var settle: float = 1.0 - 0.6 * smoothstep(0.35, 1.0, p)
			goal = (Vector2(1.5, 3.0) if anim_state == "cast" else Vector2(3.0, 5.0)) * settle * heavy
			if anim_state == "charge":
				goal = Vector2(2.0, 6.0)
			sx = 1.0 + 0.05 * (1.0 - p)
			sy = 1.0 - 0.04 * (1.0 - p)
			freq = 7.0
			damp = 0.4
			if entered:
				# ESTALO: velocidade injetada (sobressalto) + rastro de luz curto
				_bsv += Vector2(60.0, 90.0) * heavy
				spawn_afterimage(Color(profile.eye, 0.5), 0.09)
		"recover":
			goal = Vector2(1.5, 2.0) * (1.0 - smoothstep(0.0, 1.0, p))
			freq = 2.6
			damp = 0.7
		"hurt", "stagger":
			var k: float = 1.0 - clampf(t / 0.3, 0.0, 1.0)
			goal = Vector2(-3.0, -4.0) * k
			sx = 1.0 - 0.05 * k
			sy = 1.0 + 0.05 * k
			freq = 5.0
			damp = 0.35
			if entered:
				_bsv += Vector2(-50.0, -70.0)
		"dead":
			sy = 1.0 - 0.04 * clampf(t / 0.5, 0.0, 1.0)
			freq = 2.0
			damp = 0.9
		_:
			if anim_state == "walk":
				goal.y = 1.5
	if spirit and anim_state != "dead":
		oy = sin(_wind_time * 1.7) * 0.8          # espectro flutua
	elif anim_state == "idle":
		sy *= 1.0 + sin(_wind_time * 2.0) * 0.006
	# mola amortecida (sobressalto na entrada do golpe, assentamento depois)
	var w: float = TAU * freq
	var steps: int = clampi(ceili(delta * 120.0), 1, 8)
	var h: float = minf(delta, 0.1) / steps
	for _j in steps:
		_bsv += (-2.0 * damp * w * _bsv - w * w * (_bsp - goal)) * h
		_bsp += _bsv * h
	_boss_m = [_bsp.x + tremor, 0.0, sx, sy, oy, _bsp.y]
	# Telegrafo: o tom chapado que o Enemy põe na preparação vira CONTORNO
	# pulsante (a pintura do quadro de preparação continua legível).
	if anim_state.begins_with("windup"):
		for c in _TELEGRAPH_TINTS:
			if modulate.is_equal_approx(c):
				telegraph_color = Color(c.r, c.g, c.b, 0.9)
				modulate = Color.WHITE
	else:
		telegraph_color.a = move_toward(telegraph_color.a, 0.0, delta * 8.0)


# -------------------------------------------------------------------------
# MORTE DE CHEFE COM PESO (Onda 6, pedido do João: "acaba só murcha")
# -------------------------------------------------------------------------
# play_boss_death(): ~1,9 s, tudo com a PRÓPRIA pintura:
#   0,00–0,34  cambaleio: quadro de dano, tremor forte decaindo, 2 lampejos
#   0,34–0,62  queda: quadro de morte (joelhos/colapso) com impacto e tremor de tela
#   0,62–1,08  pausa dramática: luz do Éon vazando pela borda (contorno sobe), tremor fino
#   1,08       ESTILHAÇA: o quadro vira ~40 cacos do atlas com física, brilho na cor
#              do Éon, clarão e faíscas (ShatterLayer); o corpo some
#   1,90       sinal `death_finished` (quem chamou libera o nó)
signal death_finished
const DEATH_STAGGER := 0.34
const DEATH_FALL := 0.62
const DEATH_BREAK := 1.08
const DEATH_END := 1.9
var _death_t: float = -1.0
var _death_col := Color.WHITE
var _shattered: bool = false
static var _atlas_images: Dictionary = {}     # atlas → Image (cobertura dos cacos)


## Morte encenada do chefe/criatura por quadros. `col` = cor do brilho (padrão:
## luz do Éon). Sem quadros desenhados, só emite o sinal no fim (quem chama
## mantém a morte antiga).
func play_boss_death(col: Color = Color(0, 0, 0, 0)) -> void:
	_death_col = col if col.a > 0.0 else eon_light()
	_death_t = 0.0
	_shattered = false
	anim_state = "dead"
	anim_time = 0.0
	_bsv += Vector2(-70.0, -90.0)          # tranco do golpe final
	if not has_boss_frames():
		get_tree().create_timer(DEATH_END).timeout.connect(func() -> void: death_finished.emit())


func is_dying() -> bool:
	return _death_t >= 0.0


func _tick_death(delta: float) -> void:
	if _death_t < 0.0:
		return
	var before: float = _death_t
	_death_t += delta
	if before < DEATH_STAGGER and _death_t >= DEATH_STAGGER:
		_impact = 1.0                       # cai de joelhos
		if is_inside_tree():
			Juice.shake(0.7)
	if before < DEATH_BREAK and _death_t >= DEATH_BREAK:
		_shatter()
	if before < DEATH_END and _death_t >= DEATH_END:
		death_finished.emit()


## Sequência e quadro durante a morte encenada.
func _death_seq(states: Dictionary) -> String:
	if _death_t < DEATH_STAGGER and states.has("hurt"):
		return "hurt"
	return "dead" if states.has("dead") else "hurt"


## Movimento de corpo inteiro durante a morte (substitui o da mola normal).
func _death_motion() -> Array:
	var t: float = _death_t
	var ox: float = 0.0
	var bend: float = 0.0
	var sx: float = 1.0
	var sy: float = 1.0
	if t < DEATH_STAGGER:
		var k: float = 1.0 - t / DEATH_STAGGER
		ox = sin(t * 55.0) * 3.0 * k - 2.0 * (1.0 - k)
		bend = -6.0 * k
		sx = 1.0 - 0.04 * k
		sy = 1.0 + 0.04 * k
	elif t < DEATH_FALL:
		var k2: float = (t - DEATH_STAGGER) / (DEATH_FALL - DEATH_STAGGER)
		ox = -2.0 * (1.0 - k2)
		sy = 1.0 - 0.05 * (1.0 - k2)
		sx = 1.0 + 0.05 * (1.0 - k2)
	else:
		# pausa: tremor fino crescendo (a luz quer sair)
		var k3: float = clampf((t - DEATH_FALL) / (DEATH_BREAK - DEATH_FALL), 0.0, 1.0)
		ox = sin(t * 61.0) * 0.6 * k3
	return [ox, 0.0, sx, sy, 0.0, bend]


## Brilho do contorno e tinta do corpo durante a morte.
func _death_rim() -> float:
	if _death_t < DEATH_FALL:
		return RIM_BASE
	return lerpf(RIM_BASE, 2.2, clampf((_death_t - DEATH_FALL) / (DEATH_BREAK - DEATH_FALL), 0.0, 1.0))


func _death_tint() -> Color:
	# dois lampejos brancos no cambaleio
	var f: float = 0.0
	for at in [0.0, 0.16]:
		f = maxf(f, 1.0 - absf(_death_t - at) / 0.06)
	return Color(1, 1, 1).lerp(Color(2.2, 2.2, 2.2), clampf(f, 0.0, 1.0))


## Quebra o quadro desenhado atual em cacos do próprio atlas.
func _shatter() -> void:
	_shattered = true
	if _boss_shown.is_empty() or not is_inside_tree() or get_parent() == null:
		return
	var tex: Texture2D = _boss_shown.tex
	if not _atlas_images.has(tex):
		var img: Image = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			if img.has_mipmaps():
				img.clear_mipmaps()
		_atlas_images[tex] = img
	var img2: Image = _atlas_images[tex]
	var rect: Rect2 = _boss_shown.rect
	var an: Vector2 = _boss_shown.anchor
	var xf: Transform2D = get_global_transform() * _body_xform
	var layer := ShatterLayer.new()
	get_parent().add_child(layer)
	var cols: int = 6
	var rows: int = 8
	var centre: Vector2 = xf * (rect.size * 0.5 - an + Vector2.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for r in rows:
		for c in cols:
			var tile := Rect2(rect.position + Vector2(c * rect.size.x / cols, r * rect.size.y / rows), rect.size / Vector2(cols, rows))
			# só cacos com pintura (amostra a cobertura no atlas)
			var cover: int = 0
			if img2 != null:
				for sy2 in 4:
					for sx2 in 4:
						var px := Vector2i(tile.position + tile.size * Vector2((sx2 + 0.5) / 4.0, (sy2 + 0.5) / 4.0))
						if px.x >= 0 and px.y >= 0 and px.x < img2.get_width() and px.y < img2.get_height() and img2.get_pixelv(px).a > 0.5:
							cover += 1
			else:
				cover = 16
			if cover < 3:
				continue
			# canto do caco em px do atlas relativos à âncora → mundo
			var loc: Array = []
			var uvs := PackedVector2Array()
			var jit := Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12)) * tile.size
			var corners := [tile.position, tile.position + Vector2(tile.size.x, 0), tile.end, tile.position + Vector2(0, tile.size.y)]
			for k in 4:
				var cp: Vector2 = corners[k] + (jit if k == 2 else Vector2.ZERO)
				loc.append(xf * (cp - rect.position - an))
				uvs.append(cp / Vector2(tex.get_width(), tex.get_height()))
			# cada célula vira 2 CACOS triangulares (diagonal alternada): lê como
			# pintura que trinca, não como confete quadrado
			var tris: Array = [[0, 1, 2], [0, 2, 3]] if (r + c) % 2 == 0 else [[0, 1, 3], [1, 2, 3]]
			for tri in tris:
				var tp: Array = [loc[tri[0]], loc[tri[1]], loc[tri[2]]]
				var mid: Vector2 = (tp[0] + tp[1] + tp[2]) / 3.0
				var dir: Vector2 = (mid - centre).normalized() if mid.distance_to(centre) > 0.5 else Vector2.UP
				var vel: Vector2 = dir * rng.randf_range(50.0, 160.0) + Vector2(0, rng.randf_range(-220.0, -80.0))
				var pts := PackedVector2Array()
				var tuv := PackedVector2Array()
				for q in 3:
					pts.append(tp[q] - mid)
					tuv.append(uvs[tri[q]])
				layer.add_piece(mid, pts, tuv, tex, vel, rng.randf_range(-8.0, 8.0), rng.randf_range(0.7, 1.05))
	layer.burst(centre, _death_col, absf(xf.get_scale().y) * rect.size.y)


## Ponto da CABEÇA no quadro desenhado atual (coordenadas locais deste nó):
## para presos por quadro (máscara, rachadura, olho) seguirem a pintura.
## Vector2.INF se o atlas não tiver a medida.
func head_point() -> Vector2:
	if _boss_shown.is_empty() or not _boss_shown.has("head"):
		return Vector2.INF
	return _body_xform * (_boss_shown.head - _boss_shown.anchor)


## Gibs do chefe por quadros: 3×3 pedaços do ÚLTIMO quadro desenhado.
func _frame_gibs() -> Array:
	var parts: Array = []
	var s: float = profile.height / 44.0
	var rect: Rect2 = _boss_shown.rect
	var an: Vector2 = _boss_shown.anchor
	var k: float = _boss_shown.k
	var hw: float = _boss_world_h()
	var org := Vector2(float(_boss_m[0]) * s + float(_boss_db.meta.fit.dx) * hw, GROUND_Y * s + float(_boss_m[4]) * s - float(_boss_db.meta.fit.foot_gap) * hw)
	for row in 3:
		for column in 3:
			var tile := Rect2(rect.position + Vector2(column * rect.size.x / 3.0, row * rect.size.y / 3.0), rect.size / 3.0)
			var p0: Vector2 = org + (tile.position - rect.position - an) * k
			var sz: Vector2 = tile.size * k
			var at := AtlasTexture.new()
			at.atlas = _boss_shown.tex
			at.region = tile
			at.filter_clip = true
			var pts := PackedVector2Array([p0, p0 + Vector2(sz.x, 0.0), p0 + sz, p0 + Vector2(0.0, sz.y)])
			parts.append({"pts": pts, "col": Color.WHITE, "kind": "painted", "tex": at, "size": sz, "flip": 1.0})
	return parts


func _painted_gibs(s: float) -> Array:
	var parts: Array = []
	var source: Rect2 = painted.rect
	var h: float = 190.0 if painted.sheet == "yaldabaoth" else profile.height*1.3
	var w: float = h * source.size.x/source.size.y
	var flip: float = -1.0 if painted.get("flip",false) else 1.0
	for row in 3:
		for column in 3:
			var tile := Rect2(source.position + Vector2(column*source.size.x/3,row*source.size.y/3),source.size/3)
			var x: float = (-w*0.5+column*w/3)*flip
			var y: float = GROUND_Y*s-h+row*h/3
			var points := PackedVector2Array([Vector2(x,y),Vector2(x+w/3*flip,y),Vector2(x+w/3*flip,y+h/3),Vector2(x,y+h/3)])
			parts.append({"pts":points,"col":Color.WHITE,"kind":"painted","tex":PaintedLibrary.region(painted.sheet,tile),"size":Vector2(w/3,h/3),"flip":flip})
	return parts


## Cacos da pintura (morte de chefe): física simples, giro, brilho na cor do
## Éon que esquenta e some; clarão e faíscas aditivos por cima. Fica no MUNDO.
class ShatterLayer extends Node2D:
	var pieces: Array = []      # {p, pts, uvs, tex, v, w, a, life, t}
	var sparks: Array = []      # {p, v, life, t}
	var flash_p := Vector2.ZERO
	var flash_r: float = 0.0
	var flash_t: float = 9.0
	var col := Color.WHITE
	var glow: Node2D
	const GRAV := 520.0

	func _ready() -> void:
		top_level = true
		global_transform = Transform2D.IDENTITY
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		z_index = 2
		glow = Node2D.new()
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = m
		add_child(glow)
		glow.draw.connect(_draw_glow)

	func add_piece(p: Vector2, pts: PackedVector2Array, uvs: PackedVector2Array, tex: Texture2D, v: Vector2, w: float, life: float) -> void:
		pieces.append({"p": p, "pts": pts, "uvs": uvs, "tex": tex, "v": v, "w": w, "a": 0.0, "life": life, "t": 0.0})

	func burst(c: Vector2, color: Color, body_h: float) -> void:
		col = color
		flash_p = c
		flash_r = body_h * 0.55
		flash_t = 0.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in 46:
			var a: float = rng.randf() * TAU
			sparks.append({"p": c + Vector2.from_angle(a) * rng.randf() * body_h * 0.25, "v": Vector2.from_angle(a) * rng.randf_range(80.0, 260.0) + Vector2(0, -80), "life": rng.randf_range(0.35, 0.8), "t": 0.0})

	func _process(delta: float) -> void:
		flash_t += delta
		for it in pieces:
			it.t += delta
			it.v.y += GRAV * delta
			it.v *= 1.0 - 0.6 * delta
			it.p += it.v * delta
			it.a += it.w * delta
		for s in sparks:
			s.t += delta
			s.v *= 1.0 - 2.2 * delta
			s.v.y += 120.0 * delta
			s.p += s.v * delta
		pieces = pieces.filter(func(it): return it.t < it.life)
		sparks = sparks.filter(func(s): return s.t < s.life)
		queue_redraw()
		glow.queue_redraw()
		if pieces.is_empty() and sparks.is_empty() and flash_t > 0.4:
			queue_free()

	func _xf_pts(it: Dictionary, grow: float = 1.0) -> PackedVector2Array:
		var out := PackedVector2Array()
		var r := Transform2D(float(it.a), Vector2.ONE * grow, 0.0, it.p)
		for v in it.pts:
			out.append(r * v)
		return out

	func _draw() -> void:
		for it in pieces:
			var u: float = float(it.t) / float(it.life)
			# a pintura esquenta na cor do Éon e some
			var c := Color(1, 1, 1).lerp(Color(col.r * 1.6, col.g * 1.6, col.b * 1.6), clampf(u * 1.4, 0.0, 1.0))
			c.a = 1.0 - smoothstep(0.55, 1.0, u)
			var cs := PackedColorArray()
			for _q in it.pts.size():
				cs.append(c)
			draw_polygon(_xf_pts(it), cs, it.uvs, it.tex)

	func _draw_glow() -> void:
		if flash_t < 0.4:
			# clarão com queda radial (anéis concêntricos), na cor do Éon
			var k: float = 1.0 - flash_t / 0.4
			var rad: float = flash_r * (0.5 + 0.7 * (1.0 - k))
			for ring in 6:
				var f: float = 1.0 - float(ring) / 6.0
				glow.draw_circle(flash_p, rad * f, Color(col, 0.12 * k))
			glow.draw_circle(flash_p, flash_r * 0.18 * (0.5 + k), Color(1, 1, 1, 0.7 * k))
		for it in pieces:
			var u: float = float(it.t) / float(it.life)
			var a: float = 0.5 * (1.0 - u)
			var cs := PackedColorArray()
			for _q in it.pts.size():
				cs.append(Color(col, a))
			glow.draw_polygon(_xf_pts(it, 1.15), cs, it.uvs, it.tex)
		for s in sparks:
			var u2: float = float(s.t) / float(s.life)
			glow.draw_circle(s.p, 1.6 * (1.0 - u2) + 0.4, Color(col.lerp(Color.WHITE, 0.5), 1.0 - u2))


## Camada de afterimages: cópias do corpo paradas no MUNDO (top_level) que
## somem em 60–90 ms. Desenho aditivo tingido (shader painted_ghost).
class AfterimageLayer extends Node2D:
	var items: Array = []    # {xf, mesh, tex, col, life, t}
	static var ghost_material: ShaderMaterial

	func _ready() -> void:
		top_level = true
		global_transform = Transform2D.IDENTITY
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if ghost_material == null:
			ghost_material = ShaderMaterial.new()
			ghost_material.shader = load("res://assets/shaders/painted_ghost.gdshader")
		material = ghost_material

	func add(xf: Transform2D, mesh: Dictionary, tex: Texture2D, col: Color, life: float) -> void:
		items.append({"xf": xf, "mesh": mesh, "tex": tex, "col": col, "life": life, "t": 0.0})
		queue_redraw()

	func _process(delta: float) -> void:
		if items.is_empty():
			return
		for it in items:
			it.t += delta
		items = items.filter(func(it): return it.t < it.life)
		queue_redraw()

	func _draw() -> void:
		for it in items:
			var c: Color = it.col
			c.a *= 1.0 - it.t / it.life
			CharacterArt.draw_grid(get_canvas_item(), it.mesh, it.xf, it.tex, c)
