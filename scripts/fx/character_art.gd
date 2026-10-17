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
	painted = PaintedLibrary.character(p)
	material = PaintedLibrary.material()
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


func has_rig() -> bool:
	return not rig.is_empty()


func set_anim(state: String) -> void:
	if state != anim_state:
		anim_state = state
		anim_time = 0.0


func _process(delta: float) -> void:
	anim_time += delta
	if is_instance_valid(boss_puppet):
		boss_puppet.visible = texture == null
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
	if is_instance_valid(boss_puppet) and texture == null:
		return
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


func _draw_painted(s: float) -> void:
	var tex: Texture2D
	var rect: Rect2
	var flip: float = -1.0 if painted.get("flip",false) else 1.0
	var tint := Color.WHITE
	if profile.painted_id == "sombra_sophia":
		tint = Color("745581")
	if painted.get("hero",false):
		var frame: int = 0
		if anim_state in ["walk","charge"]: frame = 1 + int(anim_time * 9.0) % 2
		elif anim_state in ["jump","fall","dodge"]: frame = 2
		elif anim_state in ["windup","windup_heavy","windup_cast","block"]: frame = 3
		elif anim_state.begins_with("attack"): frame = 4
		elif anim_state == "cast": frame = 5
		var anchors := [Vector2(269,492),Vector2(268,488),Vector2(267,493),Vector2(265,453),Vector2(239,455),Vector2(236,468)]
		var body_heights := [466.0,445.0,449.0,350.0,378.0,403.0]
		var factor: float = profile.height * 1.19 / body_heights[frame]
		tex = PaintedLibrary.region("sophia",Rect2((frame%3)*512,(frame/3)*512,512,512))
		rect = Rect2(-anchors[frame].x*factor,GROUND_Y*s-anchors[frame].y*factor,512*factor,512*factor)
	else:
		tex = PaintedLibrary.region(painted.sheet,painted.rect)
		var h: float = profile.height * 1.30
		if painted.sheet == "yaldabaoth": h = 190.0
		var w: float = h * tex.get_width()/tex.get_height()
		rect = Rect2(-w*0.5,GROUND_Y*s-h,w,h)
		if painted.sheet == "inhabitants" and not profile.painted_id in ["soter","velkar","sleeper"]:
			tint = Color.WHITE.lerp(profile.primary.lightened(0.3),0.22)
	var breath: float = sin(anim_time*2.5)*0.006 if anim_state == "idle" else 0.0
	var lean: float = _lean * (0.4 if painted.get("hero",false) else 0.7)
	var oy: float = _bob
	var crouch: float = _crouch * 0.45
	# Criaturas sem boneco: o corpo inteiro anda, recua, avança e encolhe.
	var m: Array = [0.0, 0.0, 1.0, 1.0]
	if painted.get("hero", false):
		# Sophia: os estados sem quadro próprio ganham movimento de corpo inteiro.
		m = _hero_motion()
		crouch = 0.0
		if anim_state in HERO_MOTION_STATES:
			lean = 0.0
			oy = m[4]
	else:
		m = _painted_motion()
		if anim_state == "dead": lean += _dead * 1.3
	draw_set_transform(Vector2(m[0]*s,GROUND_Y*s+oy*s),lean+m[1],Vector2(flip*m[2],(1.0-crouch+breath)*m[3]))
	rect.position.y -= GROUND_Y*s
	draw_texture_rect(tex,rect,false,tint)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	# O nível da arma mantém feedback visual sem trocar os atributos do combate.
	if profile.has("hero") and profile.has("pauldrons"):
		var strength: float = 0.22 if not profile.has("aura") else 0.65
		draw_arc(Vector2(0,-29*s),8*s,-2.8,-0.35,24,Color(profile.eye,strength),0.7,true)
		var marks: int = 1 + int(profile.has("helmet")) + int(profile.has("bracers")) + int(profile.has("aura"))
		for i in marks:
			var a: float = -2.5 + i*0.54
			var point := Vector2(0,-29*s) + Vector2(cos(a),sin(a))*9*s
			draw_circle(point,0.8*s,Color(profile.eye,0.65))
	if damage_ratio > 0.45 and profile.height >= 70:
		draw_arc(Vector2(0,GROUND_Y*s-30*s),24*s,0.15,2.7,40,Color(profile.eye,0.38),1.0,true)


## Estados da Sophia em que `_hero_motion` assume a pose inteira (a inclinação
## e o afundar genéricos de `_compute_pose` são ignorados).
const HERO_MOTION_STATES := ["dodge", "hurt", "block", "jump", "fall", "dead", "attack_air", "attack_dive", "cast"]


## Movimento procedural da Sophia (folha de 6 quadros; os estados sem quadro
## reaproveitam um parecido). O corpo inteiro conta a ação: a esquiva é um
## mergulho que gira pra frente, o dano recua e comprime, o bloqueio trava
## agachado, pulo/queda esticam e comprimem, a morte tomba pra trás com quique,
## o golpe aéreo gira, o mergulho aponta pro chão e a magia recua e avança.
## Só desenho: combate, hitboxes e tempos não mudam. `pose_progress` não é
## alimentado no herói, então tudo sai de `anim_time`.
## Devolve [deslocamento x, rotação, escala x, escala y, deslocamento y]
## (deslocamentos em unidades do corpo; y positivo = afunda).
func _hero_motion() -> Array:
	var t := anim_time
	var ox := 0.0
	var oy := 0.0
	var rot := 0.0
	var sx := 1.0
	var sy := 1.0
	match anim_state:
		"dodge":
			# rolamento (~0.30 s): gira rápido pra frente e segue crescendo,
			# agachado e esticado, deslizando pra frente — mergulho, não passo
			var k := clampf(t / 0.30, 0.0, 1.0)
			var e := ease(k, 0.45)
			rot = 0.25 + 1.05 * e
			sx = 1.10
			sy = 0.80
			# gira em torno do quadril (não dos pés): a cabeça desce e as pernas
			# sobem — silhueta de rolamento, não de tropeço
			var hip: float = 14.0 * sy
			ox = 3.0 + 7.0 * e - hip * sin(rot)
			oy = -hip * (1.0 - cos(rot)) - 1.5 * sin(k * PI)
		"hurt":
			# recuo e squash que relaxam em 0.25 s
			var k := 1.0 - clampf(t / 0.25, 0.0, 1.0)
			ox = -4.5 * k
			rot = -0.16 * k
			sx = 1.0 - 0.08 * k
			sy = 1.0 + 0.06 * k
			oy = -1.0 * k
		"block":
			# quadro de preparação, agachado, levemente pra trás e travado
			ox = -1.0
			rot = -0.05
			sy = 0.92
			sx = 1.03
		"jump":
			rot = 0.04
			sx = 0.96
			sy = 1.06
		"fall":
			rot = 0.02
			sx = 1.03
			sy = 0.97
		"dead":
			# tomba pra trás devagar (aceleração de queda), bate e quica
			var k := clampf(t / 0.70, 0.0, 1.0)
			var fall := pow(clampf(k / 0.72, 0.0, 1.0), 1.8)
			var bounce := 0.0
			if k > 0.72:
				bounce = sin((k - 0.72) / 0.28 * PI) * 0.16
			rot = -1.4 * fall + bounce
			oy = 4.5 * fall
			ox = -2.0 * fall
			sy = 1.0 - 0.06 * fall
		"attack_air":
			# giro parcial no ar
			var k := clampf(t / 0.32, 0.0, 1.0)
			rot = 0.6 * k
			ox = 1.5 + 1.5 * k
			sx = 1.04
		"attack_dive":
			# mergulho: inclinação forte pra frente, apontando pro chão
			var k := clampf(t / 0.25, 0.0, 1.0)
			rot = 0.35 + 0.25 * k
			ox = 2.0
			sx = 1.06
			sy = 0.95
		"cast":
			# recua no início e avança no fim: a magia sai do corpo
			var k := clampf(t / 0.30, 0.0, 1.0)
			var e := smoothstep(0.0, 1.0, k)
			ox = lerpf(-2.0, 2.5, e)
			rot = lerpf(-0.05, 0.08, e)
			sx = 1.0 + 0.05 * sin(k * PI)
			sy = 1.0 - 0.03 * sin(k * PI)
	return [ox, rot, sx, sy, oy]


## Movimento procedural das criaturas pintadas (ilustração de peça única, sem
## boneco). Como não há membros, o corpo inteiro conta a ação: passo com
## balanço e squash, recuo comprimido no preparar (telegrafo), avanço esticado
## no golpe, recuo no dano. Espectros flutuam; feras galopam.
## Devolve [deslocamento x (unidades do corpo), rotação extra, escala x, escala y].
func _painted_motion() -> Array:
	var t := anim_time
	var p: float = maxf(pose_progress, 0.0)
	var fury: float = motion_fury
	var wraith: bool = profile.body == ArtProfile.Body.WRAITH
	var beast: bool = profile.body == ArtProfile.Body.BEAST
	var ox := 0.0
	var rot := 0.0
	var sx := 1.0
	var sy := 1.0
	match anim_state:
		"walk":
			var stride: float = clampf(motion_stride, 0.35, 1.5)
			if wraith:
				# espectro: flutua e balança devagar, sem passo
				rot = sin(t * 2.2) * 0.05
				sx = 1.0 + sin(t * 2.2) * 0.02
			elif beast:
				# fera: galope curto, corpo estica e comprime
				var ph := sin(t * 11.0 * fury)
				rot = ph * 0.07
				sx = 1.0 + absf(ph) * 0.06
				sy = 1.0 - absf(ph) * 0.05
			else:
				# bípede: balança de um pé pro outro (mesma frequência do _bob)
				var ph := sin(t * 9.0 * fury)
				rot = ph * 0.05 * stride
				sx = 1.0 - absf(ph) * 0.03 * stride
				sy = 1.0 + absf(ph) * 0.03 * stride
		"charge":
			ox = 2.0
			rot = 0.12
			sx = 1.12
			sy = 0.92
		"windup", "windup_heavy", "windup_cast":
			# recua e comprime rápido, depois segura tremendo (telegrafo legível)
			var e := ease(p, 0.45)
			var tremor: float = sin(t * 38.0) * 0.012 * e
			ox = -3.0 * e
			rot = -0.06 * e + tremor
			sx = 1.0 - 0.06 * e
			sy = 1.0 + 0.05 * e
			if anim_state == "windup_heavy":
				ox = -1.5 * e
				sy = 1.0 + 0.10 * e
		"attack", "attack_heavy", "cast":
			# golpe: avança e estica no começo, depois assenta
			var e := ease(clampf(p if pose_progress >= 0.0 else t / 0.25, 0.0, 1.0), 0.35)
			var punch: float = sin(e * PI)
			ox = (1.5 if anim_state == "cast" else 7.0) * punch
			rot = 0.14 * punch
			sx = 1.0 + 0.12 * punch
			sy = 1.0 - 0.08 * punch
			if anim_state == "attack_heavy":
				rot = 0.16 * punch
				sy = 1.0 - 0.14 * punch
		"recover":
			# volta pro repouso ainda inclinado à frente
			var back: float = 1.0 - p
			ox = 2.0 * back
			rot = 0.05 * back
		"hurt":
			var k := 1.0 - clampf(t / 0.25, 0.0, 1.0)
			ox = -3.5 * k
			rot = -0.10 * k
			sx = 1.0 - 0.10 * k
			sy = 1.0 + 0.08 * k
		_:
			if wraith:
				rot = sin(t * 1.7) * 0.03
	return [ox, rot, sx, sy]


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
