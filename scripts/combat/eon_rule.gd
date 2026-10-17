extends Node2D
class_name EonRule
## REGRA DE TRAVESSIA por Éon (backlog #41, docs/onda2/COMBATE2.md §7).
## Uma travessia de cada Éon muda a regra do combate com mecânicas que já
## existem, para quebrar o molde de 9 telas. Esta é a 1ª travessia DEPOIS do
## Desafio (posição 5 do Éon): no Torpor cai na tela 7 (dentro da demo).
## Implementadas: Torpor ("a névoa fecha") e Corrente ("correntes no cenário").
## Quem liga é o Player (_ready → EonRule.attach): não depende do level.gd.
##
##  - torpor: névoa que FECHA a visão. Só um círculo em volta da Sophia fica
##    limpo (respira devagar entre 110 e 165 px). Fora dele, os inimigos são só
##    um par de OLHOS acesos; telegrafos, golpes e projéteis passam por cima da
##    névoa (z maior): o jogo continua justo, só a leitura muda.
##  - corrente: duas correntes pesadas penduradas na zona. Cada uma descansa
##    puxada para um lado; avisa (chocalha + brilho na ponta, 0,7 s) e varre o
##    chão como pêndulo. Quem a ponta pega fica PRESO (a mesma raiz da Galila) e
##    toma um dano leve — inclusive os inimigos: dá para atrair um inimigo para a
##    varredura. Esquiva (i-frames) e bloqueio escapam, como no tiro da Galila.

const RULE_OFFSET := 5                 # posição no Éon (0..8): a travessia depois do Desafio
const Z_FOG := 28                      # acima dos personagens, abaixo dos VFX (Z=32) e dos números (50)

# --- Torpor ---
const FOG_COLOR := Color(0.07, 0.09, 0.16)
const FOG_ALPHA := 0.9
const FOG_R_MIN := 110.0               # raio limpo (px de mundo) na expiração…
const FOG_R_MAX := 165.0               # …e na inspiração
const FOG_SOFT := 70.0                 # largura da borda (degradê)
const FOG_BREATH := 7.0                # período da respiração (s)
const FOG_IN := 1.6                    # a névoa desce em 1,6 s ao entrar

# --- Corrente ---
const CHAIN_OFFSETS := [-210.0, 210.0] # x das correntes em relação ao centro da zona
const CHAIN_LEN := 196.0               # comprimento do pêndulo (px)
const CHAIN_REST := 0.95               # ângulo de descanso (rad, ~54°) — ponta lá em cima
const CHAIN_TELL := 0.7                # aviso antes de soltar (s)
const CHAIN_SWING := 0.75              # duração da varredura (s)
const CHAIN_PERIOD := 4.6              # intervalo entre varreduras de uma corrente (s)
const CHAIN_HIT_R := 20.0              # raio da ponta (bola de ferro)
const CHAIN_ROOT := 0.8                # tempo preso (s) — igual ao tiro do Carcereiro
const CHAIN_COLOR := Color(0.62, 0.62, 0.7)

var kind: String = ""
var player: Node2D
var lane_y: float = 286.0              # y do centro do corpo da Sophia no chão
var _t: float = 0.0
var _fog_r: float = FOG_R_MAX
var _fog_tex: GradientTexture2D
# Corrente: estado de cada corrente (dicionários: x, side, timer, phase, hit)
var _chains: Array = []
var _zone_seen: int = -2


## Qual regra vale nesta tela ("" = nenhuma). Determinístico pela tela.
static func rule_for(screen: int) -> String:
	if not RunManager.run_active:
		return ""
	if RunManager.screen_role(screen) != "travel" or RunManager.eon_offset(screen) != RULE_OFFSET:
		return ""
	match RunManager.eon_index(screen):
		0: return "torpor"
		2: return "corrente"
	return ""


## Liga a regra da tela atual (se houver) no nível do `p_player`. Idempotente.
static func attach(p_player: Node2D) -> EonRule:
	if p_player == null or not p_player.is_inside_tree():
		return null
	var lv := p_player.get_parent()
	if lv == null or not lv.has_method("arena_bounds"):
		return null                    # só nas fases (Level), não em cenas de teste
	var k := rule_for(RunManager.current_screen)
	if k == "":
		return null
	var old := lv.get_node_or_null("EonRule")
	if old != null:
		return old as EonRule
	var r := EonRule.new()
	r.name = "EonRule"
	r.kind = k
	r.player = p_player
	r.lane_y = p_player.global_position.y
	lv.add_child(r)
	return r


func _ready() -> void:
	z_index = Z_FOG
	z_as_relative = false
	if kind == "torpor":
		_fog_tex = GradientTexture2D.new()
		_fog_tex.width = 256
		_fog_tex.height = 256
		_fog_tex.fill = GradientTexture2D.FILL_RADIAL
		_fog_tex.fill_from = Vector2(0.5, 0.5)
		_fog_tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		# centro limpo até ~ (r - soft)/r, depois engrossa até a borda do quadrado
		g.set_offset(0, 0.0)
		g.set_color(0, Color(FOG_COLOR, 0.0))
		g.set_offset(1, 1.0)
		g.set_color(1, Color(FOG_COLOR, FOG_ALPHA))
		g.add_point(0.55, Color(FOG_COLOR, 0.0))
		g.add_point(0.8, Color(FOG_COLOR, FOG_ALPHA * 0.6))
		_fog_tex.gradient = g
	elif kind == "corrente":
		z_index = 5                    # corrente fica entre o cenário e os VFX (gibs = 6)
	# Aviso único da regra (o HUD mostra se tiver toast; senão, segue mudo).
	var msg := "A névoa engrossa: só se vê o que está perto." if kind == "torpor" else "Correntes pendem do teto. Atraia os inimigos para a varredura."
	get_tree().call_group("hud", "toast", msg)


func _physics_process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player):
		return
	if player is CharacterBody2D and (player as CharacterBody2D).is_on_floor():
		lane_y = player.global_position.y     # o chão é plano: guarda a altura da faixa
	if kind == "corrente":
		_update_chains(delta)
	queue_redraw()


# --- Torpor -----------------------------------------------------------------

func _draw_fog() -> void:
	var breath := 0.5 + 0.5 * sin(_t * TAU / FOG_BREATH)
	_fog_r = lerpf(FOG_R_MIN, FOG_R_MAX, breath)
	var k := clampf(_t / FOG_IN, 0.0, 1.0)      # a névoa desce ao entrar
	var a := k * k * (3.0 - 2.0 * k)
	var c := to_local(player.global_position + Vector2(0, -16))
	# O quadrado do degradê: o miolo transparente vai até 55 % do meio-lado.
	var half := (_fog_r + FOG_SOFT) / 0.8
	var mod := Color(1, 1, 1, a)
	draw_texture_rect(_fog_tex, Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0), false, mod)
	# Fora do quadrado: névoa cheia até bem além da vista (zoom/tremor).
	var far := 1400.0
	var col := Color(FOG_COLOR, FOG_ALPHA * a)
	draw_rect(Rect2(c.x - far, c.y - far, far * 2.0, far - half), col)                  # cima
	draw_rect(Rect2(c.x - far, c.y + half, far * 2.0, far - half), col)                  # baixo
	draw_rect(Rect2(c.x - far, c.y - half, far - half, half * 2.0), col)                 # esquerda
	draw_rect(Rect2(c.x + half, c.y - half, far - half, half * 2.0), col)                # direita
	# Olhos na névoa: quem está fora do círculo vira um par de brasas.
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Enemy) or not is_instance_valid(e) or e.estate == Enemy.EState.DEAD:
			continue
		var head := _enemy_head(e)
		var d := head.distance_to(player.global_position + Vector2(0, -16))
		if d < _fog_r * 0.85:
			continue
		var vis := clampf((d - _fog_r * 0.85) / 60.0, 0.0, 1.0) * a
		var hp := to_local(head)
		var face: float = signf(e.visual.scale.x) if e.visual != null else 1.0
		var ec: Color = e.eye_color
		var blink := 1.0 if fmod(_t + float(e.get_instance_id() % 97) * 0.13, 3.7) > 0.12 else 0.0
		for sx in [-2.5, 2.5]:
			var p := hp + Vector2(sx + face * 1.5, 0)
			draw_circle(p, 3.2, Color(ec, 0.22 * vis * blink))
			draw_circle(p, 1.3, Color(ec.lightened(0.4), 0.95 * vis * blink))
		# O telegrafo também atravessa a névoa: os olhos incham no wind-up.
		if e.estate == Enemy.EState.WINDUP:
			draw_circle(hp, 7.0, Color(ec, 0.25 * vis))


## Altura aproximada dos olhos (o desenho cresce para cima a partir dos pés).
func _enemy_head(e: Enemy) -> Vector2:
	var h := 44.0
	if e.visual != null and e.visual.profile != null:
		h = e.visual.profile.height
	return e.global_position + Vector2(0, 24.0 * e.scale.y - h * 0.95 * e.scale.y)


# --- Corrente ---------------------------------------------------------------

func _update_chains(delta: float) -> void:
	var lv := get_parent()
	var zi: int = int(lv.get("zone_index")) if "zone_index" in lv else -1
	var active: bool = bool(lv.get("zone_active")) if "zone_active" in lv else false
	if zi != _zone_seen and zi >= 0 and lv.has_method("zone_center"):
		_zone_seen = zi
		_chains.clear()
		var cx: float = lv.zone_center(zi)
		for i in CHAIN_OFFSETS.size():
			_chains.append({
				"x": cx + float(CHAIN_OFFSETS[i]),
				"side": -1.0 if i % 2 == 0 else 1.0,     # de que lado descansa
				"timer": 1.6 + float(i) * CHAIN_PERIOD * 0.5,
				"phase": "rest", "hit": [],
			})
	for ch in _chains:
		if not active and ch.phase == "rest":
			continue                   # sem combate na zona: as correntes só balançam
		ch.timer -= delta
		match ch.phase:
			"rest":
				if ch.timer <= 0.0:
					ch.phase = "tell"
					ch.timer = CHAIN_TELL
					VfxLibrary.tell_glint(get_parent(), _tip(ch), true)
					Audio.play_sfx_at("rooted", _tip(ch), 0.05)
			"tell":
				if ch.timer <= 0.0:
					ch.phase = "swing"
					ch.timer = CHAIN_SWING
					ch.hit = []
					Audio.play_sfx_at("swing_heavy", _tip(ch), 0.1)
			"swing":
				_chain_hits(ch)
				if ch.timer <= 0.0:
					ch.phase = "rest"
					ch.side = -ch.side
					ch.timer = CHAIN_PERIOD
					Juice.shake(0.15)


## Ângulo atual do pêndulo (0 = pendurado reto, ponta no chão).
func _angle(ch: Dictionary) -> float:
	var rest: float = CHAIN_REST * float(ch.side)
	match ch.phase:
		"tell":
			# chocalha no lugar (aviso), sem sair do descanso
			return rest + sin(_t * 40.0) * 0.04
		"swing":
			var k: float = 1.0 - clampf(float(ch.timer) / CHAIN_SWING, 0.0, 1.0)
			var e := 0.5 - 0.5 * cos(k * PI)                 # acelera e freia como pêndulo
			return lerpf(rest, -rest, e)
	return rest + sin(_t * 1.3 + float(ch.x) * 0.01) * 0.03


func _pivot(ch: Dictionary) -> Vector2:
	return Vector2(float(ch.x), lane_y + 4.0 - CHAIN_LEN)


func _tip(ch: Dictionary) -> Vector2:
	var a := _angle(ch)
	return _pivot(ch) + Vector2(sin(a), cos(a)) * CHAIN_LEN


func _chain_hits(ch: Dictionary) -> void:
	var tip := _tip(ch)
	var targets: Array = [player]
	targets.append_array(get_tree().get_nodes_in_group("enemy"))
	for n in targets:
		if not is_instance_valid(n) or ch.hit.has(n):
			continue
		var body: Vector2 = n.global_position + Vector2(0, -4)
		if absf(body.x - tip.x) > CHAIN_HIT_R + 10.0 or absf(body.y - tip.y) > CHAIN_HIT_R + 26.0:
			continue
		ch.hit.append(n)
		var dmg := 4 + int(GameManager.current_screen / 10)
		if n == player:
			# prende ANTES do dano (o dano liga i-frames e o apply_root recusa)
			if n.has_method("apply_root"):
				n.apply_root(CHAIN_ROOT)
			if n.has_method("_on_hit_received"):
				n._on_hit_received(dmg, tip, 120.0, false, null)
		elif n is Enemy and n.estate != Enemy.EState.DEAD:
			n.apply_damage(dmg * 3, tip, 160.0)
			n.apply_root(CHAIN_ROOT * 2.0)
		ImpactBurst.spawn(get_parent(), tip, CHAIN_COLOR)


func _draw_chains() -> void:
	var dark := Color(0.05, 0.05, 0.07, 0.95)
	for ch in _chains:
		var pv := to_local(_pivot(ch))
		var tp := to_local(_tip(ch))
		var dir := tp - pv
		var u := dir.normalized()
		var ang := u.angle()
		var n := int(dir.length() / 7.0)
		# elos alternados: oval de frente / de lado, com contorno escuro (lê em
		# qualquer fundo — R18)
		for i in n:
			var p := pv + dir * (float(i) + 0.5) / float(n)
			draw_set_transform(p, ang, Vector2(1.0, 0.62))
			if i % 2 == 0:
				draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 14, dark, 3.4, true)
				draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 14, CHAIN_COLOR, 1.8, true)
			else:
				draw_line(Vector2(-5.5, 0), Vector2(5.5, 0), dark, 4.2, true)
				draw_line(Vector2(-5.0, 0), Vector2(5.0, 0), CHAIN_COLOR.lightened(0.15), 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# a bola de ferro com cravos (a parte que machuca) + brilho no aviso
		var r := CHAIN_HIT_R * 0.72
		var spikes := PackedVector2Array()
		for k in 16:
			var a := TAU * float(k) / 16.0 + _t * 0.0
			var rr := r * (1.3 if k % 2 == 0 else 0.95)
			spikes.append(tp + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(spikes, dark)
		draw_circle(tp, r, dark)
		draw_circle(tp, r - 1.5, CHAIN_COLOR.darkened(0.55))
		draw_circle(tp + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.3))
		if ch.phase == "tell":
			draw_circle(tp, CHAIN_HIT_R * (1.15 + 0.2 * sin(_t * 30.0)), Color(1.0, 0.3, 0.25, 0.28))
		# rastro da varredura
		if ch.phase == "swing":
			draw_arc(pv, CHAIN_LEN, PI * 0.5 - CHAIN_REST, PI * 0.5 + CHAIN_REST, 24, Color(1, 1, 1, 0.1), 8.0, true)


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	if kind == "torpor":
		_draw_fog()
	elif kind == "corrente":
		_draw_chains()
