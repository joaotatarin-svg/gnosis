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
var _end_x: float = 1720.0        # parede fixa da direita
var _zone_walls: Array = []       # paredes móveis da zona trancada
var _cam_locked: bool = false     # câmera presa na zona (restaurar ao destrancar)
var _ready_done: bool = false

@onready var spawns: Node2D = $Spawns
@onready var player: Player = $Player


func _ready() -> void:
	if RunManager.run_active:
		screen = RunManager.current_screen
	GameManager.current_screen = screen
	GameManager.set_state(GameManager.State.PLAYING)
	if player:
		player.died.connect(_on_player_died)

	if RunManager.run_active:
		zones = RunManager.zone_plan(screen)
	else:
		zones = [[_test_wave()]]  # rodando Level01.tscn direto (teste)
	_layout_arena()

	# Cenário do Éon (scenery.gd): céu+astro, skyline, props, névoa, chão com
	# relevo, primeiro plano e vinheta. Se houver PNG do Éon, ele é usado.
	_build_eon_scenery()

	_build_platforms()
	_build_walls()
	_spawn_extras()
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
	if not _ready_done or zone_active or zones.is_empty() or player == null:
		return
	if GameManager.state != GameManager.State.PLAYING:
		return
	var next := zone_index + 1
	if next >= zones.size():
		return
	if player.global_position.x >= zone_center(next) - ZONE_TRIGGER:
		_start_zone(next)


func zone_center(i: int) -> float:
	return ZONE_FIRST_X + float(i) * ZONE_STEP


## Limites jogáveis atuais (x mín, x máx): a zona trancada ou a arena inteira.
## Usado pelos inimigos que teleportam, pra não caírem atrás de uma parede.
func arena_bounds() -> Vector2:
	if zone_active and zone_index >= 0:
		var c := zone_center(zone_index)
		return Vector2(c - ZONE_HALF, c + ZONE_HALF)
	return Vector2(WALL_LEFT, _end_x)


## Comprimento da arena e pontos de descanso, derivados do número de zonas.
func _layout_arena() -> void:
	var n := maxi(1, zones.size())
	_end_x = zone_center(n - 1) + ARENA_PAD
	rest_points = [Vector2(-380.0, GROUND_Y)]
	for i in n - 1:
		rest_points.append(Vector2(zone_center(i) + ZONE_STEP * 0.5, GROUND_Y))
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
			await DialogueBox.play(Narrative.intro()).finished
			await DialogueBox.play(Narrative.king_intro()).finished
		return
	if RunManager.is_eon_start(screen) and Narrative.once("eon_%d" % RunManager.eon_index(screen)):
		await DialogueBox.play(Narrative.eon_intro(RunManager.eon_index(screen))).finished
	elif screen == RunManager.CENTER_FIRST and Narrative.once("centro"):
		await DialogueBox.play(Narrative.center_intro()).finished

	if RunManager.is_final(screen):
		if Narrative.once("mente"):
			await DialogueBox.play(Narrative.final_pre()).finished
	elif RunManager.is_archon_screen(screen) and Narrative.once("tentacao_%d" % screen):
		var d := DialogueBox.play(Narrative.temptation(RunManager.boss_id_for(screen)), ["Recusar", "Ceder"])
		var choice: int = await d.choice_made
		if choice == 0:
			await DialogueBox.play(Narrative.refusal_response()).finished
		else:
			Progression.add_orbs(80)      # o suborno do Arconte
			await DialogueBox.play(Narrative.concession_response()).finished


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


## Plataformas one-way (sobe por baixo, pousa em cima). Foco em jogabilidade:
## dão reposicionamento e verticalidade sem tirar o combate do chão. Layout
## determinístico por tela e por zona; telas de chefe ficam limpas.
func _build_platforms() -> void:
	if RunManager.run_active and RunManager.is_boss_screen(screen):
		return
	var layouts := [
		[Vector2(320, 250), Vector2(600, 214)],
		[Vector2(220, 250), Vector2(470, 250), Vector2(720, 214)],
		[Vector2(400, 224)],
		[Vector2(260, 250), Vector2(640, 250)],
		[Vector2(180, 250), Vector2(430, 216), Vector2(700, 250)],
	]
	for z in maxi(1, zones.size()):
		var layout: Array = layouts[(screen + z * 2) % layouts.size()]
		var shift := Vector2(float(z) * ZONE_STEP, 0.0)
		for pos in layout:
			add_child(_make_platform(pos + shift, 130.0))


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
		sl.global_position = rest_points[0] + Vector2(-90.0, -10.0)
	if screen % 7 == 3:
		var puz := SealPuzzle.new()
		puz.screen = screen
		add_child(puz)
		puz.global_position = rest_points[last] + Vector2(170.0, 0.0)
	# Encontros da história: Soter nos Éons 1, 3 e 5 (offset 6, no descanso do
	# meio) e Velkar no Éon 6 (offset 5), perto do fim.
	if not RunManager.run_active:
		return
	var eon := RunManager.eon_index(screen)
	var off := RunManager.eon_offset(screen)
	var mid: Vector2 = rest_points[rest_points.size() / 2]
	if off == 6 and eon in [1, 3, 5]:
		var soter := NpcEncounter.new()
		soter.kind = "soter"
		soter.meeting = [1, 3, 5].find(eon)
		add_child(soter)
		soter.global_position = mid + Vector2(0.0, -10.0)
	elif off == 5 and eon == 6:
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
	_start_wave()


func _lock_zone(c: float) -> void:
	_unlock_zone()
	for wx in [c - ZONE_HALF, c + ZONE_HALF]:
		var w := _make_wall(wx)
		add_child(w)
		_zone_walls.append(w)
	_set_camera_limits(c - ZONE_HALF, c + ZONE_HALF)
	_cam_locked = true
	Audio.play_sfx("zone_lock")


func _unlock_zone() -> void:
	for w in _zone_walls:
		if is_instance_valid(w):
			w.queue_free()
	_zone_walls.clear()
	if _cam_locked:
		_cam_locked = false
		_set_camera_limits(WALL_LEFT, _end_x)
		Audio.play_sfx("zone_clear")


## Três pontos de spawn relativos ao centro da zona (centro-160, centro, centro+160).
func _place_spawns(c: float) -> void:
	var pts := spawns.get_children()
	for k in pts.size():
		var p: Node2D = pts[k]
		p.position = Vector2(c + (float(k) - float(pts.size() - 1) * 0.5) * 160.0, 250.0)


func _on_zone_cleared() -> void:
	zone_active = false
	_unlock_zone()
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
			fb.won.connect(_win)
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
	alive = 0
	for i in wave.size():
		var e := enemy_scene.instantiate()
		e.type_id = wave[i]
		# Em tela normal, o último inimigo da última wave da ÚLTIMA zona é um Elite.
		if not is_boss and is_last_wave and is_last_zone and i == wave.size() - 1:
			e.is_elite = true
		# Desafio do Éon: o bot da última wave é o CAMPEÃO.
		if is_trial and is_last_wave and wave[i] == eon_bot:
			e.is_champion = true
		add_child(e)
		if from_edge:
			e.global_position = Vector2(c + ZONE_TRIGGER - 10.0 - float(i) * 34.0, 250.0)
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
			Gnosis.boss_card("campeao", screen)


## Invocações (invocador, Coroa, Espelho) contam na wave: precisam morrer também.
func _on_minion(m: Node) -> void:
	alive += 1
	m.defeated.connect(_on_enemy_defeated)
	m.minion_spawned.connect(_on_minion)


func _on_enemy_defeated(e) -> void:
	# No Centro, quebrar um eco devolve o caco de memória daquele Anel.
	if e is Enemy and String(e.type_id).begins_with("eco_"):
		_restore_echo(String(e.type_id).trim_prefix("eco_"))
	alive -= 1
	if alive > 0:
		return
	wave_index += 1
	if wave_index >= waves.size():
		_on_zone_cleared()
	else:
		await get_tree().create_timer(0.8).timeout
		if is_inside_tree():
			_start_wave()


func _on_screen_cleared() -> void:
	if not RunManager.run_active:
		SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
		return

	if player and player.health:
		RunManager.store_health(player.health.current_health, player.health.max_health)
	Audio.play_sfx("level_clear")

	if RunManager.is_final(screen):
		_win()
	elif RunManager.is_king_screen(screen):
		# O Rei "cai": o selo racha, os 7 tronos acordam. Sem loja — é prólogo.
		await DialogueBox.play(Narrative.king_fall()).finished
		RunManager.advance_and_reload()
	elif RunManager.is_archon_screen(screen):
		# Arconte caído: a essência vira um ANEL (uma magia nova).
		await _grant_ring()
		if RunManager.is_theft_screen(screen):
			# O ROUBO: o Rei reaparece, leva os 7 Anéis, a máscara cai.
			await DialogueBox.play(Narrative.theft()).finished
			Progression.steal_rings()
			RunManager.advance_and_reload()
		else:
			# Loja de recompensa pós-chefe; ao fechar, avança.
			RunManager.pending_advance = true
			SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	elif RunManager.screen_role(screen) == "trial":
		# O Campeão caiu: SANTUÁRIO do meio do Éon (loja); ao fechar, avança.
		RunManager.pending_advance = true
		SceneManager.instance_overlay("res://scenes/ui/UpgradeMenu.tscn")
	else:
		# Tela normal limpa: abre a fenda à direita — o jogador ANDA até ela.
		_open_exit()


## Fenda de saída no fim da travessia; ao entrar nela, avança de tela.
func _open_exit() -> void:
	var portal := ExitPortal.new()
	portal.position = Vector2(_end_x - 200.0, 300.0)
	add_child(portal)
	portal.entered.connect(_advance_via_exit)
	VfxLibrary.portal(self, portal.position, Color(0.8, 0.9, 1.0))


func _advance_via_exit() -> void:
	if player and player.health:
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
			return


func _win() -> void:
	RunManager.best_screen = maxi(RunManager.best_screen, screen)
	RunManager.clear_saved_run()   # o run acabou de verdade — "Continuar" some
	RunManager.end_run()
	GameManager.set_state(GameManager.State.GAME_OVER)
	# O dilema final: Ascensão / Ruptura / Semente (esta exige os Adormecidos).
	var d := DialogueBox.play(Narrative.final_lines(), Narrative.final_choices(Progression.sleepers_freed))
	var idx: int = await d.choice_made
	Narrative.apply_ending(idx)
	SaveManager.save_game()
	# EPÍLOGO em cards (final escolhido + Crônicas N/18 + créditos), depois o EndScreen.
	await Cinematic.epilogue(Narrative.ending, Gnosis.chronicles_count(), Gnosis.chronicles_total()).finished
	SceneManager.change_scene("res://scenes/ui/EndScreen.tscn")


func _on_player_died() -> void:
	GameManager.set_state(GameManager.State.GAME_OVER)
	RunManager.best_screen = maxi(RunManager.best_screen, screen)
	# Fora de run (cena de teste direto): fim simples, como era.
	if not RunManager.run_active:
		SaveManager.save_game()
		await get_tree().create_timer(1.3).timeout
		GameManager.end_title = "Você caiu no Kenoma"
		GameManager.end_subtitle = "Chegou até a Tela %d." % screen
		SceneManager.change_scene("res://scenes/ui/EndScreen.tscn")
		return
	# CHECKPOINT: a morte não pega. Algo te recompõe — antes do roubo é a Voz
	# (o carcereiro precisa da chave viva), depois são os próprios cacos.
	# Custo: parte das faíscas escorre na queda.
	RunManager.deaths_this_run += 1
	var lost := int(Progression.orbs * 0.2)
	if lost > 0:
		Progression.add_orbs(-lost)
	SaveManager.save_game()
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	await DialogueBox.play(Narrative.death_revive(screen, RunManager.deaths_this_run, lost)).finished
	Audio.play_sfx("revive")
	RunManager.respawn_at_checkpoint()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameManager.state == GameManager.State.PLAYING:
		SceneManager.instance_overlay("res://scenes/ui/PauseMenu.tscn")
		GameManager.set_state(GameManager.State.PAUSED)
