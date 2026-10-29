extends Node2D
class_name Level
## Uma tela do run — o ARCO DOS ANÉIS: o Rei (tela 1), Éons de 9 telas
## (2–64) com travessias, o Desafio (Campeão) e o Arconte, o roubo (64), o
## Centro com ecos (65–67) e a batalha dupla (68).
##
## A tela é uma TRAVESSIA (Grand Chase / God of War): 1–3 ZONAS de combate
## enfileiradas à direita. O jogador anda; ao chegar numa zona ela TRANCA
## (paredes móveis), as waves nascem; limpou → destranca, "Siga em frente".
## Última zona limpa → loja pós-chefe (avança) ou portal. Morte → checkpoint.

@export var enemy_scene: PackedScene
@export var screen: int = 1

# Geometria da travessia (px de mundo). Zona i tem centro em ZONE_FIRST_X + i*ZONE_STEP.
## R21 (Guardião, Onda 7): respiro entre ondas da mesma zona (era 0,8 s).
const WAVE_BREATH := 2.0
const ZONE_FIRST_X := 620.0
const ZONE_STEP := 1500.0
const ZONE_TRIGGER := 430.0       # cruzou centro-430 → tranca
const ZONE_HALF := 470.0          # paredes móveis em centro±470
const WALL_LEFT := -720.0
const ARENA_PAD := 720.0          # parede direita = último centro + 720
const GROUND_Y := 298.0           # pés no chão

var zones: Array = []             # plano da tela: [zona][wave][type_id]
var zone_index: int = -1          # zona em andamento (-1 = nenhuma começou)
var zone_active: bool = false     # zona trancada com inimigos vivos
var waves: Array = []             # waves da zona atual
var wave_index: int = 0
var alive: int = 0
var rest_points: Array = []       # descansos (Vector2) entre as zonas
var _exited: bool = false          # a fenda já foi atravessada (evita avanço duplo)
var _end_x: float = 1720.0        # parede fixa da direita
var _zone_walls: Array = []       # paredes móveis da zona trancada
var _cam_locked: bool = false     # câmera presa na zona (restaurar ao destrancar)
var _ready_done: bool = false
# DESFECHO ÚNICO da tela (REVISAO #1): vitória (tela/chefe vencido) OU morte
# (volta ao checkpoint) — nunca as duas. Quem SELA primeiro manda. A vitória
# sela na hora; a morte só sela quando acaba a queda (DEATH_GRACE s de jogo):
# se o chefe/a tela cair nessa janela (golpe em voo, veneno, Esfera), conta a
# vitória e a Sophia se levanta ali mesmo com 1 de vida.
var _resolved: bool = false
var _death_pending: bool = false  # caiu; a morte ainda não selou o desfecho
const DEATH_GRACE := 1.5          # segundos de JOGO (timer não corre pausado)
var _staging: Staging = null      # encenação das cenas (staging.gd), criada sob demanda
var _last_boss_pos: Vector2 = Vector2.ZERO   # onde o chefe caiu (a queda do Rei)
# LAYOUT (level6, Onda 6): a forma da tela vem de ScreenLayouts (tipo, passagens,
# alturas, perigos, segredos, objetivo por zona) e é montada pelo LayoutBuilder.
var layout: Dictionary = {}
var _zone_x: Array = []           # centro de cada zona (passagens têm comprimento próprio)
var _layout_res: Dictionary = {}  # o que o builder montou (objetivos, vãos de plataforma)
const AIR_SPAWN_Y := 150.0        # voadores nascem no alto da arena
## CONTRATO com o cenário (CENARIO5): faixas Vector2(x0, x1) onde coluna de
## primeiro plano não cobre nada — as zonas de luta (as passagens têm
## comprimento próprio) e as estruturas de pulo (escalada, torre, sala secreta).
var fg_forbidden: Array = []

# ABERTURA (backlog #6): na tela 1 a Sophia acorda à ESQUERDA, com a Estela
# "logo adiante"; o resto da intro vira legenda enquanto ela anda, e a Cena A
# (o Rei sai da névoa) só abre quando ela chega ao gatilho do duelo.
const KING_SPAWN_X := -470.0
# A MENTE (68): a Sophia acorda a 70 px da parede esquerda da arena trancada.
const FINAL_SOPHIA_DX := 70.0
var _king_scene_pending: bool = false   # Cena A ainda não tocou (abre no gatilho)
var _king_scene_running: bool = false
# TENTAÇÃO EM CENA (#18): o Arconte já está no palco durante a conversa (parado,
# sem IA); ao cruzar o gatilho, ESSE corpo entra na luta, com o card de chefe.
var _staged_boss: Enemy = null
# DICAS DO DUELO (#10): 1º telegrafo aparável e 1º imparável do run.
const TUTOR_SLOW_SCALE := 0.25
const TUTOR_SLOW_TIME := 0.3          # s reais de câmera lenta
var _tutor_parry_done: bool = false
var _tutor_unblock_done: bool = false

@onready var spawns: Node2D = $Spawns
@onready var player: Player = $Player


func _ready() -> void:
	if RunManager.run_active:
		screen = RunManager.current_screen
	GameManager.current_screen = screen
	GameManager.set_state(GameManager.State.PLAYING)
	if player:
		player.died.connect(_on_player_died)
	# Pré-aquece VFX/shaders/gibs no load da fase (evita o engasgo do 1º golpe).
	VfxLibrary.prewarm(self)

	if RunManager.run_active:
		zones = RunManager.zone_plan(screen)
	else:
		zones = [[_test_wave()]]  # rodando Level01.tscn direto (teste)
	_layout_arena()
	# Telas com a passagem 0 ABERTA (segredo, antessala): a Sophia nasce antes.
	if RunManager.run_active and player != null and not is_nan(float(layout.get("spawn_x", NAN))):
		player.global_position.x = float(layout.spawn_x)
		_snap_camera()
	if RunManager.run_active and RunManager.is_king_screen(screen) and player != null:
		player.global_position.x = KING_SPAWN_X
		_snap_camera()
	if RunManager.run_active and RunManager.is_final(screen) and player != null:
		_lock_final_arena()
	_tutor_parry_done = Narrative.seen.has("dica_aparar")
	_tutor_unblock_done = Narrative.seen.has("dica_imparavel")

	# Cenário do Éon (scenery.gd): céu+astro, skyline, props, névoa, chão com
	# relevo, primeiro plano e vinheta. Se houver PNG do Éon, ele é usado.
	_build_eon_scenery()

	_build_platforms()
	_build_walls()
	_spawn_extras()
	# A encenação nasce já: ela vigia TODA caixa de diálogo da tela (a Sophia para
	# em pé e a câmera sobe o quadro acima da caixa — QA2 #1/#9).
	if player != null:
		stage()
	await _play_narrative_beats()
	if not is_inside_tree():
		return
	if RunManager.run_active:
		Gnosis.setup_screen(self, screen, rest_points)
	_ready_done = true
	# Tela 68: a batalha dupla tem controlador próprio (FinalBattle) — começa já.
	if RunManager.run_active and RunManager.is_final(screen):
		_start_wave()


## Gatilho das zonas: o jogador anda pra direita e, ao cruzar centro-430 de uma
## zona ainda não iniciada, ela tranca e as waves nascem.
func _process(_delta: float) -> void:
	if _ready_done and player != null and RunManager.run_active:
		_tutor_watch()
	if not _ready_done or zone_active or zones.is_empty() or player == null:
		return
	if GameManager.state != GameManager.State.PLAYING or _king_scene_running:
		return
	var next := zone_index + 1
	if next >= zones.size():
		return
	if player.global_position.x >= zone_center(next) - ZONE_TRIGGER:
		if _king_scene_pending:
			_play_king_scene()      # a Cena A abre no gatilho; o duelo vem depois
			return
		_start_zone(next)


## F2 (QA visual): a Mente é uma ARENA trancada desde a chegada (centro ± ZONE_HALF,
## paredes e véus da zona). A Sophia acorda perto da borda esquerda, virada para
## a direita, e a câmera já para no quadro da luta: o clarão, a caixa e o card
## mostram o mesmo lugar onde as duas formas nascem (FinalBattle.REI_DX/COL_DX).
func _lock_final_arena() -> void:
	var c := zone_center(0)
	zone_index = 0
	zone_active = true
	for wx in [c - ZONE_HALF, c + ZONE_HALF]:
		var w := _make_wall(wx)
		add_child(w)
		_zone_walls.append(w)
	_set_camera_limits(c - ZONE_HALF, c + ZONE_HALF)
	_cam_locked = true
	player.global_position.x = c - ZONE_HALF + FINAL_SOPHIA_DX
	if "facing" in player:
		player.set("facing", 1)
	_snap_camera()


## Cena A (ROTEIRO §2): o Rei sai da névoa quando ela chega ao gatilho do duelo.
## As legendas da caminhada que sobraram (jogador apressado) são descartadas:
## a caixa assume a cena e nada fala por cima do duelo (#21).
func _play_king_scene() -> void:
	_king_scene_pending = false
	_king_scene_running = true
	_clear_captions()
	await stage().play(Narrative.king_intro(), [], "rei").finished
	_king_scene_running = false


## Esvazia a fila de legendas (CaptionBar vive no autoload Gnosis).
func _clear_captions() -> void:
	var cap = Gnosis.get("_caption")
	if cap != null and is_instance_valid(cap) and cap.has_method("clear"):
		cap.call("clear")


## A câmera pula para a Sophia (sem deslizar do ponto antigo).
func _snap_camera() -> void:
	if player == null or not player.has_node("Camera2D"):
		return
	var cam: Camera2D = player.get_node("Camera2D")
	if cam.has_method("snap"):
		cam.call("snap")
	else:
		cam.reset_smoothing()


# --- dicas do duelo (#10) -----------------------------------------------------

## O 1º telegrafo AMARELO (aparável) de um chefe e o 1º VERMELHO (imparável) do
## run: câmera lenta curta + dica de controle no HUD (`show_hint`, com a tecla
## do dispositivo em uso). Cada dica toca uma vez por run (Narrative.seen: com
## checkpoint a tela recarrega e ela não repete). O Rei-tutorial só tem golpe
## aparável; o 1º imparável costuma ser o Elite do fim da tela 2.
func _tutor_watch() -> void:
	if _tutor_parry_done and _tutor_unblock_done:
		return
	if CodexSession.active or get_tree().paused:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Enemy) or not ("estate" in e) or int(e.get("estate")) != Enemy.EState.WINDUP:
			continue
		# A janela de aparar abre GLINT_LEAD s antes do golpe (o brilho de aviso).
		if float(e.get("attack_timer")) > Enemy.GLINT_LEAD:
			continue
		var hb = e.get("attack_hitbox")
		var unb: bool = hb != null and bool(hb.get("unblockable"))
		if unb and not _tutor_unblock_done:
			_tutor_unblock_done = true
			Narrative.once("dica_imparavel")
			_tutor_hint(e, [{"keys": [], "text": "brilho vermelho não se apara:"}, {"keys": ["dodge"], "text": "esquive"}],
				"Vermelho não se apara: esquive.")
			return
		if not unb and not _tutor_parry_done and bool(e.get("is_boss_enemy")):
			_tutor_parry_done = true
			Narrative.once("dica_aparar")
			_tutor_hint(e, [{"keys": [], "text": "brilho amarelo:"}, {"keys": ["block"], "text": "apare no tempo"}],
				"Brilho amarelo: bloqueie no tempo e apare.")
			return


func _tutor_hint(_e: Node, segs: Array, fallback: String) -> void:
	Juice.slow_mo(TUTOR_SLOW_SCALE, TUTOR_SLOW_TIME)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_hint_now"):
		hud.call("show_hint_now", segs)
	elif hud != null and hud.has_method("show_hint") and "hints" in hud:
		# Sem a API "agora": a dica fura a fila (as da tela 1 podem estar esperando).
		# A dica que estiver na tela (ex.: "mover · pular") cede o lugar já.
		var q: Array = hud.get("hints")
		q.push_front(segs)
		if "_hint" in hud and "_hint_gap" in hud:
			hud.set("_hint", [])
			hud.set("_hint_gap", 0.0)
	elif hud != null and hud.has_method("toast"):
		hud.call("toast", fallback)


func zone_center(i: int) -> float:
	if i >= 0 and i < _zone_x.size():
		return float(_zone_x[i])
	return ZONE_FIRST_X + float(i) * ZONE_STEP


## Começo (x de mundo) da passagem ANTES da zona i: a parede esquerda da tela
## (i = 0) ou a parede direita da zona anterior.
func passage_start(i: int) -> float:
	if i <= 0:
		return WALL_LEFT
	return zone_center(i - 1) + ZONE_HALF


## Objetivo da zona i ("ondas", "totem", "proteger") — prancha/HUD/QA.
func zone_objective(i: int) -> String:
	var zs: Array = layout.get("zones", [])
	if i >= 0 and i < zs.size():
		return String(zs[i].get("objective", "ondas"))
	return "ondas"


## Limites jogáveis atuais (x mín, x máx): a zona trancada ou a arena inteira.
## Usado pelos inimigos que teleportam, pra não caírem atrás de uma parede.
func arena_bounds() -> Vector2:
	if zone_active and zone_index >= 0:
		var c := zone_center(zone_index)
		return Vector2(c - ZONE_HALF, c + ZONE_HALF)
	return Vector2(WALL_LEFT, _end_x)


## Comprimento da arena e pontos de descanso, derivados do número de zonas e
## do LAYOUT da tela (cada passagem tem o seu comprimento: travessias longas).
## O descanso fica no meio de cada passagem.
func _layout_arena() -> void:
	var n := maxi(1, zones.size())
	layout = ScreenLayouts.plan(screen, n)
	var gaps: Array = layout.get("gaps", [])
	_zone_x = [ZONE_FIRST_X]
	for i in range(1, n):
		var gap: float = float(gaps[i - 1]) if i - 1 < gaps.size() else ScreenLayouts.PASS_SHORT
		_zone_x.append(float(_zone_x[i - 1]) + ZONE_HALF * 2.0 + gap)
	_end_x = zone_center(n - 1) + ARENA_PAD
	rest_points = [Vector2(-380.0, GROUND_Y)]
	for i in range(1, n):
		rest_points.append(Vector2((passage_start(i) + zone_center(i) - ZONE_HALF) * 0.5, GROUND_Y))
	# A câmera nunca mostra além das paredes fixas.
	_set_camera_limits(WALL_LEFT, _end_x)


func _set_camera_limits(left: float, right: float) -> void:
	if player == null or not player.has_node("Camera2D"):
		return
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = int(left)
	cam.limit_right = int(right)
	cam.limit_smoothed = true


## Diálogos de entrada da tela: intro + o Rei (1), chegada num Éon, tentação
## do Arconte, o Centro (65) e a batalha final (68).
func _play_narrative_beats() -> void:
	if not RunManager.run_active:
		return
	# Cada bico narrativo toca UMA vez por run (Narrative.once): com os
	# checkpoints, morrer recarrega a tela — sem isto, tudo repetiria.
	if RunManager.is_king_screen(screen):
		# PRÓLOGO em cards (o mito: Mônada → Éons → Sophia → o Cego → faíscas),
		# só uma vez por run, antes de a Voz falar.
		if not CodexSession.active and Narrative.once("prologue"):
			await Cinematic.prologue().finished
			if not is_inside_tree():
				return
		if Narrative.once("intro"):
			# Só o escuro, o coração e "Acorda." — depois, o controle (#6). O
			# resto da intro são as legendas de chegada (walk_arrival da tela 1).
			await stage().play(Narrative.intro(), [], "intro").finished
			# Cena A: o Rei sai da névoa quando ela chega ao duelo (_process).
			_king_scene_pending = Narrative.once("rei")
		return
	if RunManager.is_eon_start(screen) and Narrative.once("eon_%d" % RunManager.eon_index(screen)):
		await DialogueBox.play(Narrative.eon_intro(RunManager.eon_index(screen))).finished
	elif screen == RunManager.CENTER_FIRST and Narrative.once("centro"):
		# Cena C: a descida ao Centro, depois o "Voz?" (ROTEIRO §2).
		await stage().descend()
		if not is_inside_tree():
			return
		await stage().play(Narrative.center_intro(), [], "centro").finished

	if RunManager.is_final(screen):
		if Narrative.once("mente"):
			# A fala de chegada da Mente entra na caixa (depois do clarão): a
			# batalha dupla começa logo em seguida e nada fala por cima dela (#21).
			var pre: Array = Narrative.final_pre()
			var arr: Array = _take_arrival_lines()
			for k in arr.size():
				pre.insert(mini(1 + k, pre.size()), arr[k])
			await DialogueBox.play(pre).finished
	elif RunManager.is_archon_screen(screen) and Narrative.once("tentacao_%d" % screen):
		# TENTAÇÃO EM CENA (#18): o Arconte nasce ANTES da conversa, enquadrado,
		# parado (o mundo está pausado pela caixa); a fala de chegada da Sophia
		# (que olha para ele) abre a caixa; o card de chefe vem depois da escolha.
		_stage_archon()
		# 2 quadros para o Arconte se montar (pose do boneco) antes de a caixa
		# congelar o mundo — a IA dele nem chega a andar.
		for _i in 2:
			await get_tree().process_frame
		if not is_inside_tree():
			return
		var lines: Array = _take_arrival_lines()
		lines.append_array(Narrative.temptation(RunManager.boss_id_for(screen)))
		var d := stage().play(lines, ["Recusar", "Ceder"], "tentacao")
		var choice: int = await d.choice_made
		if choice == 0:
			await DialogueBox.play(Narrative.refusal_response()).finished
		else:
			Progression.add_orbs(80)      # o suborno do Arconte
			await DialogueBox.play(Narrative.concession_response()).finished
		# Até ela cruzar o gatilho, o Arconte espera parado (sem IA, sem golpe).
		if _staged_boss != null and is_instance_valid(_staged_boss):
			_staged_boss.process_mode = Node.PROCESS_MODE_DISABLED


## A fala de chegada da tela (walk_arrival) sai da LEGENDA e vai para a caixa:
## marca a legenda como já dita (o Gnosis.setup_screen não a repete) e devolve
## as falas. Nas telas de chefe (#21) a legenda cairia em cima da luta.
func _take_arrival_lines() -> Array:
	if not Narrative.once("walk_a_%d" % screen):
		return []
	return Narrative.walk_arrival(screen)


## Tentação em cena (#18): o Arconte nasce ANTES da conversa, no ponto onde
## nasceria no duelo, virado para ela e PARADO (a caixa pausa o mundo; depois
## da escolha o process dele fica desligado até o gatilho: sem IA, sem golpe). A Sophia fica a um passo do gatilho; a Staging ("tentacao") enquadra
## os dois. Depois da escolha nada muda até ela andar: no gatilho a zona tranca,
## este mesmo corpo acorda (_start_wave) e só então vem o card de chefe.
func _stage_archon() -> void:
	if enemy_scene == null or zones.is_empty() or player == null:
		return
	var wave0: Array = (zones[0] as Array)[0]
	if wave0.is_empty():
		return
	var c := zone_center(0)
	player.global_position.x = c - ZONE_TRIGGER - 10.0
	if "facing" in player:
		player.set("facing", 1)
	_snap_camera()
	_place_spawns(c)
	var e: Enemy = enemy_scene.instantiate()
	e.type_id = wave0[0]
	add_child(e)
	e.global_position = (spawns.get_child(0) as Node2D).global_position
	var vis = e.get("visual")
	if vis is Node2D and player.global_position.x < e.global_position.x:
		(vis as Node2D).scale.x = -absf((vis as Node2D).scale.x)
	_staged_boss = e


## Cenário do Éon via Scenery (Background.tscn). O chão visual, o primeiro plano
## e a vinheta são filhos do Level (coords de mundo); o GroundVisual estático é
## substituído pelo relevo procedural.
func _build_eon_scenery() -> void:
	if not has_node("Background"):
		return
	var sc: Scenery = $Background
	var eon := RunManager.eon_index(screen) if RunManager.run_active else 0
	var used_png: bool = sc.build(eon, screen)
	if has_node("Ground/GroundVisual"):
		$Ground/GroundVisual.visible = used_png
	if not used_png:
		sc.build_ground(self, 310.0)
		sc.build_foreground(self)
	sc.build_vignette(self)


## LAYOUT da tela (level6): plataformas one-way em 2–4 alturas, perigos do
## Éon, segredos no alto, escalada, torre da saída e objetos de objetivo —
## tudo do plano de ScreenLayouts, montado pelo LayoutBuilder. Determinístico
## por tela; telas de chefe ficam limpas (o plano devolve "chefe").
func _build_platforms() -> void:
	if RunManager.run_active and RunManager.is_boss_screen(screen):
		return
	if layout.is_empty():
		layout = ScreenLayouts.plan(screen, maxi(1, zones.size()))
	_layout_res = LayoutBuilder.build(self, layout)
	fg_forbidden.clear()
	for zi in maxi(1, zones.size()):
		fg_forbidden.append(Vector2(zone_center(zi) - ZONE_HALF, zone_center(zi) + ZONE_HALF))
	for b in _layout_res.get("bands", []):
		fg_forbidden.append(b)


## Plataforma one-way comum (pública: o LayoutBuilder usa).
func make_platform(center: Vector2, w: float) -> StaticBody2D:
	return _make_platform(center, w)


## Trechos do chão (x0, x1) ocupados pelo conteúdo da tela — Estela, baú,
## Adormecido, Selos e encontros — que perigos/torres não podem cobrir.
## Mesma conta de posição do _spawn_extras e do Gnosis._stela_pos.
func reserved_spans() -> Array:
	var out: Array = []
	if rest_points.is_empty():
		return out
	var last: int = rest_points.size() - 1
	var stela: Vector2 = rest_points[0] + Vector2(150.0, 0.0)
	if rest_points.size() >= 2:
		stela = rest_points[1 + (screen % (rest_points.size() - 1))] + Vector2(-200.0, 0.0)
	out.append([stela.x - 45.0, stela.x + 45.0])
	if screen % 3 == 1:
		var cx: float = rest_points[mini(1, last)].x + 40.0
		out.append([cx - 35.0, cx + 35.0])
	if screen % 4 == 2:
		var sx: float = _sleeper_x()
		out.append([sx - 40.0, sx + 40.0])
	if screen % 7 == 3:
		var px: float = _seal_x()
		out.append([px - 125.0, px + 125.0])
	if RunManager.run_active:
		if RunManager.soter_meeting_at(screen) >= 0 or RunManager.velkar_at(screen):
			var mx: float = rest_points[rest_points.size() / 2].x
			out.append([mx - 60.0, mx + 60.0])
	return out


## Onde ficam os Selos: no último descanso + 170; se o encontro (Soter/Velkar)
## está no MESMO descanso, + 300 (a passagem já cresceu: Estela, NPC e Selos
## lado a lado com folga — a tela 17 tinha os três empilhados).
func _seal_x() -> float:
	var last: int = rest_points.size() - 1
	var x: float = rest_points[last].x + 170.0
	if last == rest_points.size() / 2 and ScreenLayouts.npc_on_screen(screen):
		x = rest_points[last].x + 300.0
	elif last == 0 and is_nan(float(layout.get("spawn_x", NAN))) and RunManager.run_active 			and not (Gnosis.stela_for_screen(screen) as Dictionary).is_empty():
		# tela de uma zona com Estela (descanso + 150): os Selos vão para trás do começo
		x = rest_points[0].x - 220.0
	return x


## Onde dorme o Adormecido: no descanso 0 (atrás do começo) ou, se a Sophia
## nasce antes (passagem 0 aberta), atrás DELA — continua opcional ("olhe pra trás").
func _sleeper_x() -> float:
	var sp := float(layout.get("spawn_x", NAN))
	if not is_nan(sp):
		return sp - 70.0
	return rest_points[0].x - 90.0


## Paredes invisíveis nas bordas da arena: ninguém (jogador, inimigo, knockback)
## sai do chão e cai no vazio. A direita fecha logo depois da última zona.
func _build_walls() -> void:
	for wx in [WALL_LEFT, _end_x]:
		add_child(_make_wall(wx))


func _make_wall(wx: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = Vector2(wx, 60.0)
	wall.collision_layer = 1
	wall.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 1600)
	col.shape = rect
	wall.add_child(col)
	return wall


func _make_platform(center: Vector2, w: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 12)
	col.shape = rect
	col.one_way_collision = true
	body.add_child(col)
	var vis := Sprite2D.new()
	vis.texture = PaintedLibrary.prop(5)
	vis.material = PaintedLibrary.material()
	vis.scale = Vector2(w/vis.texture.get_width(),22.0/vis.texture.get_height())
	vis.position.y = 5.0
	body.add_child(vis)
	return body


## Conteúdo opcional da tela (determinístico: mesma tela = mesmo conteúdo),
## sempre nos DESCANSOS entre as zonas: baú no descanso 1, Adormecido no 0,
## Selos no último. Nada disso aparece em tela de chefe — chefe é só o chefe.
func _spawn_extras() -> void:
	if RunManager.run_active and RunManager.is_boss_screen(screen):
		return
	var last: int = rest_points.size() - 1
	if screen % 3 == 1:
		var c := Chest.new()
		c.screen = screen
		add_child(c)
		c.global_position = rest_points[mini(1, last)] + Vector2(40.0, 0.0)
	if screen % 4 == 2:
		var sl := Sleeper.new()
		sl.screen = screen
		add_child(sl)
		sl.global_position = Vector2(_sleeper_x(), rest_points[0].y - 10.0)
	if screen % 7 == 3:
		var puz := SealPuzzle.new()
		puz.screen = screen
		add_child(puz)
		puz.global_position = Vector2(_seal_x(), rest_points[last].y)
	# Encontros da história (Soter e Velkar, no descanso do meio). Os lugares
	# vêm de RunManager.SOTER_SLOTS/VELKAR_SLOT (mapa7: fonte única).
	if not RunManager.run_active:
		return
	var mid: Vector2 = rest_points[rest_points.size() / 2]
	var meet := RunManager.soter_meeting_at(screen)
	if meet >= 0:
		var soter := NpcEncounter.new()
		soter.kind = "soter"
		soter.meeting = meet
		add_child(soter)
		soter.global_position = mid + Vector2(0.0, -10.0)
	elif RunManager.velkar_at(screen):
		var velkar := NpcEncounter.new()
		velkar.kind = "velkar"
		add_child(velkar)
		velkar.global_position = mid + Vector2(0.0, -12.0)


func _test_wave() -> Array:
	var ids: Array = Bestiary.types_for_screen(screen)
	if ids.is_empty():
		ids = ["servo"]
	return ids.slice(0, mini(3, ids.size()))


# --- zonas ------------------------------------------------------------------

## Tranca a zona i (paredes móveis + câmera), posiciona os spawns e solta a 1ª wave.
func _start_zone(i: int) -> void:
	zone_index = i
	zone_active = true
	waves = zones[i]
	wave_index = 0
	var c := zone_center(i)
	_lock_zone(c)
	_place_spawns(c)
	if RunManager.run_active:
		Gnosis.zone_started(screen, i, zones.size())
	if _staging != null:
		_staging.zone_started()      # o Rei de cena (tela 1) dá lugar ao de verdade
	_arm_objective(i)
	_start_wave()


## OBJETIVO da zona (layout): o totem começa a invocar / a luz começa a contar.
func _arm_objective(i: int) -> void:
	var obj = _layout_res.get("objectives", {}).get(i)
	if obj == null or not is_instance_valid(obj):
		return
	if obj.has_method("arm"):
		obj.call("arm")
	var msg := ""
	match zone_objective(i):
		"totem": msg = "Um totem chama reforços: quebre-o."
		"proteger": msg = "Proteja a luz do Adormecido: lute longe dela."
	if msg != "":
		get_tree().call_group("hud", "toast", msg)


## A zona acabou: o totem racha, a luz paga (ou não).
func _close_objective(i: int) -> void:
	var obj = _layout_res.get("objectives", {}).get(i)
	if obj == null or not is_instance_valid(obj):
		return
	if obj.has_method("finish"):
		obj.call("finish")
	elif obj.has_method("disarm"):
		obj.call("disarm")


func _lock_zone(c: float) -> void:
	_unlock_zone()
	for wx in [c - ZONE_HALF, c + ZONE_HALF]:
		var w := _make_wall(wx)
		add_child(w)
		_zone_walls.append(w)
	_set_camera_limits(c - ZONE_HALF, c + ZONE_HALF)
	_cam_locked = true
	Audio.play_sfx("zone_lock")
	# Misericórdia oculta (Combate) recomeça a cada zona trancada.
	if player and player.health and player.health.has_method("reset_mercy"):
		player.health.call("reset_mercy")


func _unlock_zone() -> void:
	for w in _zone_walls:
		if is_instance_valid(w):
			w.queue_free()
	_zone_walls.clear()
	if _cam_locked:
		_cam_locked = false
		_set_camera_limits(WALL_LEFT, _end_x)
		Audio.play_sfx("zone_clear")


## Três pontos de spawn relativos ao centro da zona (centro-160, centro, centro+160),
## empurrados para fora de baixo das plataformas baixas (ninguém nasce dentro
## de um degrau).
func _place_spawns(c: float) -> void:
	var pts := spawns.get_children()
	for k in pts.size():
		var p: Node2D = pts[k]
		p.position = Vector2(_spawn_x(c + (float(k) - float(pts.size() - 1) * 0.5) * 160.0, c), 250.0)


## X de nascimento no chão livre de plataforma baixa, dentro da zona.
func _spawn_x(x: float, c: float) -> float:
	var spans: Array = _layout_res.get("spans", [])
	var out := LayoutBuilder._clear_x(x, spans, c)
	return clampf(out, c - ZONE_HALF + 40.0, c + ZONE_HALF - 40.0)


## Voador? (contrato com inimigos6: `Enemy.is_flyer()` / `flying`, ou Bestiary.is_flyer)
func _is_flyer(e: Node) -> bool:
	if e.has_method("is_flyer"):
		return bool(e.call("is_flyer"))
	for prop in ["is_flyer", "flying", "flies"]:
		if prop in e and bool(e.get(prop)):
			return true
	if Bestiary.has_method("is_flyer") and "type_id" in e:
		return bool(Bestiary.call("is_flyer", String(e.get("type_id"))))
	return false


func _on_zone_cleared() -> void:
	zone_active = false
	_unlock_zone()
	_close_objective(zone_index)
	var total := zones.size()
	var last_zone := zone_index >= total - 1
	if RunManager.run_active and total > 0:
		Gnosis.zone_cleared(screen, zone_index, total)
	if last_zone:
		_on_screen_cleared()
	else:
		get_tree().call_group("hud", "toast", "Siga em frente  →")


# --- waves ------------------------------------------------------------------

func _start_wave() -> void:
	# Tela 68: a batalha dupla tem controlador próprio (FinalBattle).
	if RunManager.run_active and RunManager.is_final(screen):
		if not has_node("FinalBattle"):
			_place_spawns(ZONE_FIRST_X)
			var fb := FinalBattle.new()
			fb.name = "FinalBattle"
			add_child(fb)
			fb.won.connect(_on_final_won)
			fb.start(self, enemy_scene, spawns.get_children())
		return
	if enemy_scene == null or wave_index >= waves.size():
		return
	var wave: Array = waves[wave_index]
	var is_boss := RunManager.run_active and RunManager.is_boss_screen(screen)
	var is_last_wave := wave_index == waves.size() - 1
	var is_last_zone := zones.is_empty() or zone_index >= zones.size() - 1
	var is_trial := RunManager.run_active and RunManager.screen_role(screen) == "trial"
	var eon_bot: String = Bestiary.EON_BOTS[clampi(RunManager.eon_index(screen), 0, Bestiary.EON_BOTS.size() - 1)]
	var points := spawns.get_children()
	# Da 2ª wave em diante os inimigos ENTRAM pela borda direita da zona.
	var from_edge := zone_active and wave_index >= 1
	var c := zone_center(maxi(0, zone_index))
	var champion: Node2D = null
	alive = 0
	# Em tela normal, o último inimigo da última wave da ÚLTIMA zona é um Elite —
	# menos o Invocador (Balance P4): Invocador Elite (×2,2 de vida, recua e chama
	# larvas) fazia da antessala da Coroa (63) quase um Arconte. Passa ao anterior.
	var elite_i := wave.size() - 1
	while elite_i > 0 and String(wave[elite_i]) == "invocador":
		elite_i -= 1
	for i in wave.size():
		# Tentação em cena: o Arconte que já estava no palco é ESTE corpo.
		if i == 0 and is_boss and wave_index == 0 and _staged_boss != null and is_instance_valid(_staged_boss) \
				and String(_staged_boss.type_id) == String(wave[0]):
			var sb := _staged_boss
			_staged_boss = null
			sb.process_mode = Node.PROCESS_MODE_INHERIT
			sb.defeated.connect(_on_enemy_defeated)
			sb.minion_spawned.connect(_on_minion)
			alive += 1
			continue
		var e := enemy_scene.instantiate()
		e.type_id = wave[i]
		if not is_boss and is_last_wave and is_last_zone and i == elite_i:
			e.is_elite = true
		# Desafio do Éon: o bot da última wave é o CAMPEÃO.
		if is_trial and is_last_wave and wave[i] == eon_bot:
			e.is_champion = true
		add_child(e)
		if e.is_champion:
			# QA7 #12: o CAMPEÃO nasce DENTRO do quadro, no chão, à frente da Sophia
			# (mesmo voador) — antes vinha da borda/do alto e levava > 4 s para entrar.
			e.global_position = Vector2(_champion_x(c), 250.0)
			champion = e as Node2D
		elif _is_flyer(e):
			# voadores nascem NO ALTO da arena (verticalidade: use as plataformas)
			e.global_position = Vector2(c + (float(i % 3) - 1.0) * 200.0, AIR_SPAWN_Y)
		elif from_edge:
			e.global_position = Vector2(_spawn_x(c + ZONE_TRIGGER - 10.0 - float(i) * 34.0, c), 250.0)
		else:
			var p: Node2D = points[i % points.size()]
			e.global_position = p.global_position
		e.defeated.connect(_on_enemy_defeated)
		e.minion_spawned.connect(_on_minion)
		alive += 1
	# CARD DE CHEFE (letterbox + nome + título, congela ~1,8 s): ao nascer o
	# Rei/Arconte e, no Desafio, o Campeão (última wave).
	if RunManager.run_active:
		if is_boss and wave_index == 0:
			Gnosis.boss_card(RunManager.boss_id_for(screen), screen)
		elif is_trial and is_last_wave and wave.has(eon_bot):
			_champion_card_when_visible(champion)


## Onde o Campeão nasce: 150 px à frente da Sophia, para o lado da zona com mais
## espaço, dentro da zona e do quadro (a câmera mostra ±266 px dela).
func _champion_x(c: float) -> float:
	if player == null:
		return _spawn_x(c + 120.0, c)
	var dir := 1.0 if player.global_position.x <= c else -1.0
	return _spawn_x(player.global_position.x + dir * 150.0, c)


## QA7 #12: o letreiro do Campeão só sai quando ele JÁ está na tela — ele surge
## (o brilho de aparição é do Enemy) e, ~0,6 s depois (ou quando entra no quadro,
## até 2 s), vem o card.
func _champion_card_when_visible(champ: Node2D) -> void:
	# (O brilho de aparição é do próprio Enemy._boss_intro_fx — aqui não repete: R4.)
	var t := 0.0
	while t < 2.0:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		if champ == null or not is_instance_valid(champ):
			break
		var sp: Vector2 = champ.get_global_transform_with_canvas().origin
		var vr := get_viewport().get_visible_rect()
		if t >= 0.6 and vr.grow(-20.0).has_point(sp):
			break
	if champ != null and is_instance_valid(champ) and "estate" in champ and int(champ.get("estate")) == Enemy.EState.DEAD:
		return
	_champion_card()


## Card do Campeão com o NOME do bot do Éon (#20): "O GLUTÃO · Guardião do
## santuário da Fome" — não o "O CAMPEÃO" genérico (que ainda colidia com a
## dificuldade "Campeão"). Nada na Provação (sandbox), como no Gnosis.
func _champion_card() -> void:
	if CodexSession.active:
		return
	var c: Dictionary = Narrative.champion_card(RunManager.eon_index(screen))
	if c.is_empty():
		Gnosis.boss_card("campeao", screen)
		return
	Cinematic.boss_card(String(c.name), String(c.title))


## Invocações (invocador, Coroa, Espelho) contam na wave: precisam morrer também.
func _on_minion(m: Node) -> void:
	alive += 1
	m.defeated.connect(_on_enemy_defeated)
	m.minion_spawned.connect(_on_minion)


func _on_enemy_defeated(e) -> void:
	# No Centro, quebrar um eco devolve o caco de memória daquele Anel.
	if e is Enemy and String(e.type_id).begins_with("eco_"):
		_restore_echo(String(e.type_id).trim_prefix("eco_"))
	if e is Enemy and e.is_boss_enemy:
		_last_boss_pos = e.global_position
	alive -= 1
	if alive > 0:
		return
	wave_index += 1
	if wave_index >= waves.size():
		_on_zone_cleared()
	else:
		# R21 (Guardião): respiro entre ondas — era 0,8 s.
		await get_tree().create_timer(WAVE_BREATH, false).timeout
		if is_inside_tree():
			_start_wave()


func _on_screen_cleared() -> void:
	if _resolved:
		return                     # a morte já selou o desfecho desta tela
	_resolved = true
	_rescue_if_fallen()            # caiu junto com o chefe: a vitória vale
	if not RunManager.run_active:
		SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
		return

	if player and player.health:
		RunManager.store_health(player.health.current_health, player.health.max_health)
	Audio.play_sfx("level_clear")
	# H3 (QA visual): o chefe/Campeão morreu enquanto o card dele ainda estava
	# na tela — a cena, a caixa e a loja esperam o card acabar (não sobrepõem).
	await _cinematics_done()
	if not is_inside_tree():
		return

	if RunManager.is_final(screen):
		_win()
	elif RunManager.is_king_screen(screen):
		# O Rei "cai": o selo racha, os 7 tronos acordam. Sem loja — é prólogo.
		stage().fall_at(_last_boss_pos)
		await stage().play(Narrative.king_fall(), [], "rei_queda").finished
		RunManager.advance_and_reload()
	elif RunManager.is_archon_screen(screen):
		# Arconte caído: a essência vira um ANEL (uma magia nova).
		await _grant_ring()
		if RunManager.is_theft_screen(screen):
			# O ROUBO (cena B): o Rei reaparece, leva os 7 Anéis, a máscara cai.
			await stage().play(Narrative.theft(), [], "roubo").finished
			Progression.steal_rings()
			RunManager.advance_and_reload()
		else:
			# Loja de recompensa pós-chefe; ao fechar, avança.
			RunManager.pending_advance = true
			SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	elif RunManager.screen_role(screen) == "trial":
		# O Campeão caiu: SANTUÁRIO do meio do Éon — antes da loja, a conversa
		# da dupla (o afeto que o roubo vai colher; ROTEIRO §5, gancho 1).
		if Narrative.once("santuario_%d" % screen):
			await stage().play(Narrative.sanctuary(RunManager.eon_index(screen)), [], "santuario").finished
			if not is_inside_tree():
				return
		# Loja; ao fechar, avança.
		RunManager.pending_advance = true
		SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	else:
		# Tela normal limpa: abre a fenda à direita — o jogador ANDA até ela.
		_open_exit()


## Espera os cards (Cinematic) que estão na tela ou acabaram de ser pedidos
## (nascem por call_deferred) terminarem. Teto de ~6 s por segurança.
func _cinematics_done() -> void:
	await get_tree().process_frame
	for _i in 360:
		var busy := false
		for c in get_tree().root.get_children():
			if c is Cinematic and not c.is_queued_for_deletion():
				busy = true
				break
		if not busy:
			return
		await get_tree().process_frame


## Fenda de saída no fim da travessia; ao entrar nela, avança de tela.
## Telas "chegar ao topo" (layout exit_top): a fenda abre no ALTO da torre do fim.
func _open_exit() -> void:
	var portal := ExitPortal.new()
	portal.position = Vector2(_end_x - 200.0, 300.0)
	if _layout_res.has("exit_top"):
		portal.position = _layout_res.exit_top
		get_tree().call_group("hud", "toast", "A fenda abriu no alto: suba.")
	add_child(portal)
	portal.entered.connect(_advance_via_exit)
	VfxLibrary.portal(self, portal.position, Color(0.8, 0.9, 1.0))


func _advance_via_exit() -> void:
	if _exited or player == null or player.health == null or player.health.is_dead():
		return                     # morta não atravessa; e a fenda só avança uma vez
	_exited = true
	RunManager.store_health(player.health.current_health, player.health.max_health)
	RunManager.advance_and_reload()


## Ao vencer um Arconte, seu Anel se condensa: a magia dele passa pra Sophia.
func _grant_ring() -> void:
	var boss_id := RunManager.boss_id_for(screen)
	var ch: CharacterData = GameManager.selected_character
	if ch == null:
		return
	for skill in ch.skills:
		if skill.ring == boss_id:
			Progression.add_ring(boss_id, skill.id)
			# Equipa o Anel novo (o jogador experimenta na hora).
			Progression.selected_ring = maxi(0, GameContent.ring_skills(ch).find(skill))
			Progression.rings_changed.emit()
			# A essência do Arconte REFAZ a Sophia (cura cheia — o respiro do Éon).
			if player and player.health:
				player.health.heal(player.health.max_health)
			await DialogueBox.play(Narrative.ring_gained(boss_id, skill.display_name, Progression.rings.size())).finished
			return


## No Centro: um eco quebrado devolve o PODER de um Anel roubado.
func _restore_echo(boss_id: String) -> void:
	if not Progression.rings.has(boss_id) or Progression.restored_rings.has(boss_id):
		return
	Progression.restore_ring(boss_id)
	var ch: CharacterData = GameManager.selected_character
	if ch == null:
		return
	for skill in ch.skills:
		if skill.ring == boss_id:
			get_tree().call_group("hud", "toast", Narrative.echo_shard(boss_id, skill.display_name))
			break
	# A LEMBRANÇA verdadeira que volta com o caco (legendas, sem pausar). A
	# música = memória (`centro` entra no 1º caco e sobe por caco) é do Áudio,
	# pelo sinal de caco devolvido.
	Juice.slow_mo(0.3, 0.6)          # M8: o caco quebra devagar
	Gnosis.captions(Narrative.echo_memory(boss_id))


## A encenação da tela (cenas A–D, ROTEIRO §2): um nó só, criado na 1ª vez.
func stage() -> Staging:
	if _staging == null or not is_instance_valid(_staging):
		_staging = Staging.new()
		_staging.name = "Staging"
		add_child(_staging)
		_staging.setup(self, player)
	return _staging


## As duas formas caíram juntas (FinalBattle.won): mesmo desfecho único.
func _on_final_won() -> void:
	if _resolved:
		return
	_resolved = true
	_rescue_if_fallen()
	_win()


func _win() -> void:
	RunManager.best_screen = maxi(RunManager.best_screen, screen)
	RunManager.clear_saved_run()   # o run acabou de verdade — "Continuar" some
	RunManager.end_run()
	GameManager.set_state(GameManager.State.GAME_OVER)
	# Cena D, a anagnórise, e o dilema final: Ascensão / Ruptura / Semente
	# (esta exige os Adormecidos).
	if has_node("FinalBattle"):
		stage().final_battle = get_node("FinalBattle")
	var d := stage().play(Narrative.final_lines(), Narrative.final_choices(Progression.sleepers_freed), "anagnorise")
	var idx: int = await d.choice_made
	Narrative.apply_ending(idx)
	SaveManager.save_game()
	# A fala curta do final escolhido, antes do epílogo (ROTEIRO §5, gancho 6).
	await DialogueBox.play(Narrative.ending_lines(idx)).finished
	# EPÍLOGO em cards (final escolhido + Crônicas N/18 + créditos), depois o EndScreen.
	await Cinematic.epilogue(Narrative.ending, Gnosis.chronicles_count(), Gnosis.chronicles_total()).finished
	SceneManager.change_scene("res://scenes/ui/EndScreen.tscn")


func _on_player_died() -> void:
	GameManager.set_state(GameManager.State.GAME_OVER)
	RunManager.best_screen = maxi(RunManager.best_screen, screen)
	# Fora de run (cena de teste direto): fim simples, como era.
	if not RunManager.run_active:
		SaveManager.save_game()
		await get_tree().create_timer(1.3, false).timeout
		if not is_inside_tree():
			return
		GameManager.end_title = "Você caiu no Kenoma"
		GameManager.end_subtitle = "Chegou até a Tela %d." % screen
		SceneManager.change_scene("res://scenes/ui/EndScreen.tscn")
		return
	if _resolved:
		# A tela já foi vencida (o chefe caiu antes, no mesmo quadro, ou o golpe
		# final ainda estava no ar): a queda não desfaz a vitória.
		_rescue_if_fallen()
		return
	# A queda: a morte só sela o desfecho quando ela acaba. Timer de JOGO (não
	# corre com o mundo pausado) e ligado a este nó (some com a tela).
	_death_pending = true
	get_tree().create_timer(DEATH_GRACE, false).timeout.connect(_commit_death)


## Fim da queda: se nada venceu a tela nesse meio-tempo, a morte manda.
## CHECKPOINT: a morte não pega. Algo te recompõe — antes do roubo é a Voz
## (o carcereiro precisa da chave viva), depois são os próprios cacos.
## Custo: parte das faíscas escorre na queda.
func _commit_death() -> void:
	if not is_inside_tree() or not _death_pending:
		return
	_death_pending = false
	if _resolved:
		return
	_resolved = true
	RunManager.deaths_this_run += 1
	var lost := int(Progression.orbs * 0.2)
	if lost > 0:
		Progression.add_orbs(-lost)
	SaveManager.save_game()
	await DialogueBox.play(Narrative.death_revive(screen, RunManager.deaths_this_run, lost)).finished
	if not is_inside_tree():
		return
	Audio.play_sfx("revive")
	RunManager.respawn_at_checkpoint()


## A Sophia caída numa tela já vencida se levanta ali mesmo, com 1 de vida
## (sem contar a morte, sem perder faíscas). Usa `player.revive(hp)` se o
## Combate expuser; senão, levanta pelo estado público do Player.
func _rescue_if_fallen() -> void:
	_death_pending = false
	if player == null or player.health == null or not player.health.is_dead():
		return
	if player.has_method("revive"):
		player.call("revive", 1)
	else:
		player.health.current_health = 1
		player.health.health_changed.emit(player.health.current_health, player.health.max_health)
		player.state = Player.State.IDLE
		player.velocity = Vector2.ZERO
		player.invuln_timer = maxf(player.invuln_timer, 1.2)
	if GameManager.state == GameManager.State.GAME_OVER and not (RunManager.run_active and RunManager.is_final(screen)):
		GameManager.set_state(GameManager.State.PLAYING)
	Audio.play_sfx("revive")
	VfxLibrary.dodge_perfect(self, player.global_position + Vector2(0, -20))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameManager.state == GameManager.State.PLAYING:
		SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		GameManager.set_state(GameManager.State.PAUSED)
