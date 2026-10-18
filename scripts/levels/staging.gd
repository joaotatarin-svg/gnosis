extends Node2D
class_name Staging
## ENCENAÇÃO (Onda 2): as cenas A–D do ROTEIRO §2, dirigidas pelo campo `cue`
## das falas. O Level chama `stage().play(falas, escolhas, "cena")` no lugar de
## `DialogueBox.play(...)`; a caixa avisa cada fala (`line_shown`) e aqui o cue
## vira imagem, câmera e som — a caixa não sabe de nada.
##
## Cenas: "intro" (M1, o batimento) · "rei" (A, o Rei sai da névoa, tela 1) ·
## "rei_queda" (a máscara racha) · "roubo" (B, tela 64) · "centro" (C, tela 65,
## ver `descend()`) · "anagnorise" (D, tela 68) · "santuario" (o tema da Voz) ·
## "tentacao" (M2, a janela) · "soter" (M3, "Senta.").
##
## Tudo roda com o mundo PAUSADO pela caixa (process ALWAYS; tweens ignoram o
## slow-mo). Se o jogador avançar antes de um efeito acabar, o efeito salta ao
## estado final (`_flush`) — nenhuma cena fica pela metade. A câmera é a da
## Sophia (camera_shake.gd): durante a cena ela roda sempre e a cena mexe no
## `base_offset`/`zoom`; ao fim tudo volta como estava.
## APIs de outros donos são chamadas com has_method (compila sem elas).
## SOM: dono único = Áudio. Cada cue vai a `Audio.cue()` (som e música da
## cena), o tema da Voz por `Audio.voice_theme()`, as gemas por `ring_note`
## (ou pelo HUD). Aqui só ficam os momentos de cena sem cue (corte seco do
## "Sete.", palmas, sussurro, passos do Rei, música baixa de Soter/tentação).
## A câmera mexe em `zoom` (RELATIVO ao zoom de jogo salvo) e `base_offset`
## (entra no ALVO da câmera; o deslocamento lateral é limitado pela margem
## segura da câmera nova — o quadro anda o que ela deixar).

const GOLD := Color(1.0, 0.86, 0.5)
const FOG_TINT := Color(0.78, 0.8, 0.86)
const BLIND_TINT := Color(0.62, 0.68, 0.8)    # o Rei "esfria" quando a máscara cai
const HEAD := Vector2(0.0, -188.0)            # rosto (máscara) do Rei (px, local aos pés; medido na captura)
# A descida do Centro (cena C): o roteiro pede 200 px, mas a pintura de fundo
# acaba ~120 px acima do enquadramento normal (aparecia a borda) — 120.
const DESCENT := 120.0
# Cena D: a câmera desce um pouco para a Sophia ficar ACIMA da caixa de diálogo.
const D_LIFT := 48.0
const HAND := Vector2(-66.0, -84.0)           # mão estendida do Rei (olhando à esquerda)
# QUADRO DE DIÁLOGO (Onda 5, QA2 #1): com QUALQUER caixa aberta, a câmera desce
# até os pés da Sophia ficarem nesta altura da tela (px da base 640×360). A caixa
# começa em y 250 (placa do nome em 240); com escolhas ela cresce até 214 (204).
const FEET_Y := 226.0
const FEET_Y_TALL := 198.0
const FEET_BELOW_BODY := 12.0                 # pés ≈ 12 px abaixo da origem (camera_shake.gd)
const PARTNER_RANGE := 420.0                  # interlocutor até esta distância entra no quadro
# Cenas com o Rei de corpo inteiro (≈ 200 px de mundo): o quadro abre para a
# cabeça dele caber com os pés dela acima da caixa.
const KING_ZOOM := 0.8
# Rosto do Rei DEPOIS de "a máscara cai" (cena B): o estado pintado do atlas
# (pedido à arte: Rei sem máscara) ou, enquanto não chega, o recorte do retrato
# `rei_revelado` (tools/encenacao/rei_mascara_rachada.py).
const REVEALED_STATES := ["revealed", "unmasked", "sem_mascara"]
# Poses da folha `rei_revelado_a` (arte, Onda 6). Foram pintadas olhando para o
# lado OPOSTO do Rei de máscara: o figurante espelha a pintura nelas para ele
# continuar virado para a Sophia (a mão aberta e os Anéis do lado dela).
const MIRRORED_POSES := ["mask_crack", "revealed", "triumph", "dominion", "sinking"]
const REVEALED_FACE := "res://assets/cinematic/rei_mascara_rachada.png"
const FACE_H := 44.0                          # altura do rosto recortado (px de mundo)
const FACE_DX := Vector2(0.0, 0.0)            # ajuste do recorte sobre a cabeça pintada

var level: Node2D
var player: Node2D
var final_battle: Node                         # tela 68 (FinalBattle)
var _cam: Camera2D
var _cam_saved: Dictionary = {}
var _hud: Node
var _hud_mode: int = -1
var _box: DialogueBox
var _scene: String = ""
var _tweens: Array = []

var _king: _King
var _fogs: Array = []
var _gems: Array = []                          # gemas no MUNDO (orbitam a cabeça dele)
var _gem_born: Dictionary = {}                 # índice -> true (já nasceu no mundo)
var _orbit: int = 0                            # 0 parado · 1 órbita · 2 motor (3 anéis)
var _orbit_t: float = 0.0
var _orbit_weak: bool = false                  # "...espera... eu... lembro..."
var _little: CegoPequeno                       # o Cego pequeno pintado (scripts/fx/cego_pequeno.gd)
var _aura: Sprite2D
var _locked: bool = false
var _music_stopped: bool = false
var _ducked: bool = false                      # abaixou a música (soter) — soltar no fim

var _fx_layer: CanvasLayer                     # abaixo da caixa (90): flash e preto
var _white: ColorRect
var _black: ColorRect
# ILUSTRAÇÕES das cenas (Onda 3): 07 roubo (B), 08 descida (C), 09 anagnórise (D)
# entram como um card de tela cheia ATRÁS da caixa (na camada dos efeitos, entre o
# preto e o flash), com Ken Burns lento; saem na fala seguinte.
var _art_rect: TextureRect
var _art_kb: Tween
var _art_line: int = -2                        # fala em que a ilustração entrou
var _line_idx: int = -1                        # fala atual da caixa
var _descending: bool = false                  # a descida do Centro (cena C, sem caixa)
# Quadro de diálogo (QA2 #1): o último enquadramento pedido (zoom relativo e
# deslocamento) — refeito quando a caixa cresce para as escolhas.
var _cur_k: float = 1.0
var _cur_shift: Vector2 = Vector2.ZERO
var _framed: bool = false                      # a cena já mexeu na câmera nesta caixa
var _tall_seen: bool = false
var _boxes: Array = []                         # caixas abertas (DialogueBox) que vigio
var _vis_mode: int = -1                        # process_mode do Visual da Sophia (idle na conversa)
# ENSINO NA HORA (Onda 6): o 1º APARO do run abre a janela do contra-ataque —
# câmera lenta curta + prompt "contra-ataque: golpeie agora" (uma vez por run).
const RIPOSTE_SLOW := 0.35
const RIPOSTE_SLOW_TIME := 0.55
var _riposte_taught: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 20                               # acima dos personagens, abaixo dos VFX
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 86
	add_child(_fx_layer)
	_black = _rect(Color(0, 0, 0, 0))
	_white = _rect(Color(1, 1, 1, 0))


func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


func setup(p_level: Node2D, p_player: Node2D) -> void:
	level = p_level
	player = p_player
	if player != null and player.has_node("Camera2D"):
		_cam = player.get_node("Camera2D")
	_hud = get_tree().get_first_node_in_group("hud")
	# Toda caixa de diálogo que abrir (pela cena ou direto no DialogueBox.play):
	# a Sophia para em pé e a câmera sobe o quadro acima da caixa.
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


# --- API para o Level ------------------------------------------------------------

## Abre a caixa de diálogo e encena as falas pelo `cue`. Devolve a caixa
## (await .finished / .choice_made como sempre).
func play(lines: Array, choices: Array = [], scene: String = "") -> DialogueBox:
	_scene = scene
	_clear_damage_numbers()
	_framed = false
	_box = DialogueBox.play(lines, choices)
	_box.line_shown.connect(_on_line)
	_box.finished.connect(_on_finished.bind(_box))
	_scene_open()
	return _box


## Há cena dirigida no ar? (entre play() e o fim do _on_finished, a descida do
## Centro sem caixa, ou uma ilustração de cena na tela). O HUD (ui3) chama por
## has_method para esconder dicas/combo/faíscas durante as cenas (QA C2).
func is_active() -> bool:
	return _scene != "" or _descending or _art_on()


# --- quadro de diálogo (Onda 5, QA2 #1 e #9) ---------------------------------------
# A caixa cobre o terço de baixo da tela, onde ficam os pés de todo mundo: com a
# câmera de jogo, a Sophia falava ESCONDIDA atrás dela (Cena A, roubo, chegada da
# Mente, diálogos comuns). Agora toda caixa — a da cena (play) ou a direta
# (DialogueBox.play do Level/NPC) — faz o mesmo que já valia para Soter/Velkar:
# a Sophia para em pé (idle, respirando) e a câmera desce o quadro até os pés dela
# ficarem em FEET_Y, centrada entre ela e quem fala (chefe, NPC, Rei-figurante
# a até PARTNER_RANGE px). Os enquadramentos próprios das cenas (_cam_to) também
# respeitam essa altura. Ao fechar (sem outra caixa logo em seguida), tudo volta.

func _on_node_added(n: Node) -> void:
	if not (n is DialogueBox):
		return
	_boxes.append(n)
	n.tree_exited.connect(_on_box_closed.bind(n), CONNECT_ONE_SHOT)
	if CodexSession.active or not is_inside_tree():
		return
	_settle_player()
	if n == _box:
		# Caixa da cena: o enquadramento é dela; sem um, o quadro de diálogo.
		if not _framed:
			_frame_dialog()
	else:
		_framed = false
		_frame_dialog()


func _on_box_closed(b: Node) -> void:
	_boxes.erase(b)
	if b != _box and is_inside_tree():
		_release_soon(0.45)


## Há caixa de diálogo aberta?
func _box_open() -> bool:
	for b in _boxes:
		if is_instance_valid(b) and (b as Node).is_inside_tree() and not (b as Node).is_queued_for_deletion():
			return true
	return false


## A caixa aberta cresceu para as escolhas (a última fala antes delas já usa a
## caixa alta — DialogueBox._show_line)?
func _box_tall() -> bool:
	for b in _boxes:
		if is_instance_valid(b) and not (b as Node).is_queued_for_deletion():
			var box: DialogueBox = b
			if not box.choices.is_empty() and box.idx >= box.lines.size() - 1:
				return true
	return false


## Centra o quadro entre a Sophia e quem fala (se houver alguém perto); a altura
## (pés acima da caixa) vem do _cam_to.
func _frame_dialog() -> void:
	if _cam == null or player == null or not is_instance_valid(player):
		return
	var other := _partner()
	var dx := 0.0
	var k := 1.0
	if other != null:
		dx = _mid_shift(other.global_position.x)
		if other == _king:
			k = KING_ZOOM
	_cam_to(k, Vector2(dx, 0.0), 0.6)


## O interlocutor mais perto da Sophia (até PARTNER_RANGE): o Rei-figurante, um
## NPC (Soter/Velkar) ou um chefe visível.
func _partner() -> Node2D:
	var px := player.global_position.x
	var cands: Array = []
	if _king != null and is_instance_valid(_king) and _king.visible:
		cands.append(_king)
	if level != null:
		for c in level.get_children():
			if c is NpcEncounter and (c as Node2D).visible:
				cands.append(c)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.is_boss_enemy and (e as Node2D).is_visible_in_tree():
			cands.append(e)
	var best: Node2D = null
	var bd := PARTNER_RANGE
	for c in cands:
		var d: float = absf((c as Node2D).global_position.x - px)
		if d < bd:
			bd = d
			best = c
	return best


## Deslocamento X (relativo ao alvo normal da câmera) que põe o meio entre a
## Sophia e `x` no centro. A câmera ainda segura a Sophia na faixa segura.
func _mid_shift(x: float) -> float:
	_cam_take()
	var mid := (player.global_position.x + x) * 0.5
	# O alvo normal da câmera (corpo + enquadramento salvo + antecipação), e não
	# onde ela ESTÁ: logo depois de um teleporte/corrida a câmera ainda vem
	# atrasada e o meio sairia torto (Sophia fora do quadro).
	var look = _cam.get("_look_ahead")
	var unshifted := player.global_position.x + Vector2(_cam_saved.base_offset).x + (float(look) if look != null else 0.0)
	return mid - unshifted


## Quanto a câmera desce (px de mundo, somado ao base_offset salvo) para os pés
## da Sophia ficarem em FEET_Y (FEET_Y_TALL com escolhas) no zoom relativo `k`.
func _lift(k: float) -> float:
	if _cam == null:
		return 0.0
	var z := _base_zoom().y * k
	var half := get_viewport_rect().size.y * 0.5
	var feet := FEET_Y_TALL if _box_tall() else FEET_Y
	var base_y := float(Vector2(_cam_saved.base_offset).y) if not _cam_saved.is_empty() else -66.0
	return (FEET_BELOW_BODY - base_y) - (feet - half) / maxf(z, 0.01)


## QA2 #9: a caixa pausa o mundo no quadro em que abriu — a Sophia ficava
## congelada no meio da passada. Em pé no chão, ela vai para o parado (idle) e
## o Visual dela segue respirando durante a conversa (só o Visual: o corpo,
## a física e o estado do Player não são tocados). Morta, ferida ou no ar, fica.
func _settle_player() -> void:
	if player == null or not is_instance_valid(player) or not (player is CharacterBody2D):
		return
	var vis = player.get("visual")
	if not (vis is CharacterArt):
		return
	if "state" in player:
		var st := int(player.get("state"))
		if st == Player.State.DEAD or st == Player.State.HURT:
			return
	var body := player as CharacterBody2D
	if not body.is_on_floor():
		return
	body.velocity.x = 0.0
	(vis as CharacterArt).set_anim("idle")
	if _vis_mode < 0:
		_vis_mode = (vis as Node).process_mode
		(vis as Node).process_mode = Node.PROCESS_MODE_ALWAYS


func _unsettle_player() -> void:
	if _vis_mode < 0:
		return
	var vis = player.get("visual") if player != null and is_instance_valid(player) else null
	if vis is Node and is_instance_valid(vis):
		(vis as Node).process_mode = _vis_mode
	_vis_mode = -1


## Solta a câmera e a Sophia daqui a 2 quadros — se nenhuma outra caixa abriu
## nesse meio-tempo (falas em sequência: a próxima caixa só reenquadra, sem o
## quadro voltar ao jogo e descer de novo).
func _release_soon(dur: float) -> void:
	for _i in 2:
		await get_tree().process_frame
	if not is_inside_tree() or _box_open():
		return
	_unsettle_player()
	_cam_release(dur)


## A cena da tela 1 terminou: o Rei-figurante segura o lugar até o duelo
## começar (o Rei de verdade nasce na zona) e então some na coluna de luz.
func zone_started() -> void:
	if _king == null or not is_instance_valid(_king):
		return
	var k := _king
	_king = null
	# O Rei de verdade só se desenha quando o mundo volta a rodar (o card de
	# chefe congela tudo no quadro em que ele nasce): até lá, o figurante segura.
	for i in 3:
		await get_tree().process_frame     # o card nasce por call_deferred
	while is_inside_tree() and get_tree().paused:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.1, true, false, true).timeout
	if not is_instance_valid(k):
		return
	var t := create_tween()
	t.tween_property(k, "modulate:a", 0.0, 0.25)
	t.tween_callback(k.queue_free)
	_clear_fog(1.2)


# --- despacho por fala -----------------------------------------------------------

func _scene_open() -> void:
	match _scene:
		"intro":
			# M1: preto, sem música; só o coração. A luz volta devagar.
			Audio.stop_music(0.0)
			_music_stopped = true
			_black.color.a = 1.0
			# Fora do _flush: a 1ª fala aparece já no escuro (não pode pular a volta da luz).
			var t := create_tween().set_ignore_time_scale(true)
			t.tween_interval(1.5)
			t.tween_property(_black, "color:a", 0.0, 1.4)
		"rei":
			# Cena A: a música do Limiar desce; a câmera trava e desliza.
			_cam_take()
		"roubo":
			# "Sete." e a música do chefe CORTA SECA (sem crossfade).
			Audio.stop_music(0.0)
			_music_stopped = true
			_hide_boss_bodies()            # o corpo do Arconte não fica congelado no palco
			_cam_take()
			_hud_take()
		"anagnorise":
			_cam_take()
		"santuario":
			# O tema da Voz, baixo (plantio — o roubo colhe).
			Audio.voice_theme("santuario")
		"soter":
			# M3: a música do Éon cai a −14 dB ao abrir o encontro ("Senta.").
			Audio.duck_music(600.0, -14.0)
			_ducked = true
			_frame_npc()
		"velkar":
			_frame_npc()
		"tentacao":
			# #18: o Arconte já está no palco (Level._stage_archon); a câmera
			# enquadra os dois, ela à esquerda e ele à direita.
			_frame_boss()


func _on_line(index: int, line: Dictionary) -> void:
	_flush()
	_line_idx = index
	if _art_on() and index != _art_line:
		_hide_art(0.8)                 # a ilustração da cena dura uma fala
	if index == 0:
		# O golpe final pode criar o número DEPOIS de a cena abrir (a morte do
		# chefe chama a cena no meio do golpe): limpa de novo na 1ª fala.
		_clear_damage_numbers()
	var cue := String(line.get("cue", ""))
	var who := String(line.get("speaker", ""))
	var text := String(line.get("text", ""))
	if cue != "":
		Audio.cue(cue)                 # o som do cue é do Áudio
	match cue:
		"music_stop":
			_music_stopped = true
		"fog_thickens": _a_fog()
		"king_emerges":
			if _scene == "roubo":
				_b_king_enters()
			else:
				_a_emerges()
		"mask_lights": _a_mask_lights()
		"mask_cracks": _fall_cracks()
		"king_sinks": _fall_sinks()
		"voice_merge": _b_voice_merge()
		"rings_fly": _b_rings_fly()
		"mask_falls": _b_mask_falls()
		"sink": _b_sink()
		"rings_return": _d_rings_return()
		"flash": _d_flash()
		"colossus_shrinks": _d_shrink()
		"theme_alone": _d_theme()
		"reclaim": _d_reclaim()
	# Falas sem cue que a cena também marca (por quem fala / rubrica).
	match _scene:
		"intro":
			if index == 1:
				# Só depois da 1ª fala da Voz entra a faixa do Limiar, baixa.
				Audio.play_music("rei")
				_music_stopped = false
		"roubo":
			if text.contains("aplaude"):
				_b_applause()
			elif who == "Uma voz nos Anéis":
				_orbit_weak = true
				Audio.play_sfx("whisper")
			elif who == Narrative.YAL and cue == "" and _king != null and is_instance_valid(_king):
				# O Rei revelado (arte): o orbe ao alto no nome; a mão puxando os
				# Anéis em "os sete eram meus filhos"; parado nas outras falas.
				if text.begins_with("Chama-me pelo nome"):
					_king.pose("triumph")
				elif text.begins_with("Choraste por mim"):
					_king.pose("dominion")
				else:
					_king.rest()
			if text.contains("mais baixo"):
				Audio.duck_music(9.0, -14.0)
				_cam_to(KING_ZOOM + 0.06, Vector2(_side() * 50.0, 6.0), 1.6)
		"tentacao":
			# M2: o passado "quente" vira arma — a música do chefe recua.
			if text.begins_with("(Como ele sabe"):
				Audio.duck_music(5.0, -10.0)
		"anagnorise":
			_little_pose(who, text)
			if text.begins_with("Fui eu que fechei"):
				_cam_to(1.32, Vector2(0, D_LIFT - 10.0), 1.2)   # baixa à altura dela
			elif text.begins_with("Falta o mais difícil"):
				_cam_to(1.0, Vector2(0, D_LIFT * 0.6), 1.4)     # abre o quadro


func _on_finished(box: DialogueBox) -> void:
	if box != _box:
		return
	_flush()
	_hide_art(0.5)
	if _ducked:
		Audio.duck_music(0.0, 0.0)
		_ducked = false
	# A câmera volta ao jogo (se nenhuma outra caixa abrir logo em seguida —
	# _release_soon). O roubo fica no preto até a tela mudar.
	match _scene:
		"roubo": pass
		"anagnorise": _release_soon(0.6)
		_: _release_soon(0.5)
	match _scene:
		"rei":
			# O Rei vai ao seu lugar no duelo e espera (zone_started o tira).
			if _king != null and is_instance_valid(_king):
				var t := create_tween().set_ignore_time_scale(true)
				t.tween_property(_king, "global_position:x", _duel_x(), 0.6)
		"rei_queda":
			_clear_fog(0.6)
		"roubo":
			_black.color.a = 1.0                   # fica no preto até a tela mudar
			_hud_release()
			_unlock()
		"santuario":
			if _music_stopped:
				await get_tree().create_timer(1.0, true, false, true).timeout
			if not is_inside_tree():
				return
			Audio.voice_theme("")
			_music_stopped = false
	_scene = ""


# --- cena A: o Rei sai da névoa (tela 1) ----------------------------------------

func _a_fog() -> void:
	var c := _view_center()
	_cam_to(KING_ZOOM, Vector2(60, 0), 2.0)
	_spawn_fog(Vector2(c.x + 190.0, _ground_y()), 0.7, 1.6)
	_king = _make_king(Vector2(c.x + 220.0, _ground_y()))
	_king.silhouette(0.0)
	_king.modulate.a = 0.0
	_king.glint_on = true
	var t := _tw()
	t.tween_interval(1.6)
	t.tween_property(_king, "modulate:a", 1.0, 0.5)
	t.parallel().tween_property(_king, "global_position:x", c.x + 90.0, 2.4)
	t.parallel().tween_callback(_king.step).set_delay(0.1)
	t.parallel().tween_callback(_king.step).set_delay(1.3)


func _a_emerges() -> void:
	if _king == null:
		_a_fog()
		_flush()
	# A névoa abre em volta dele; a cor volta; a capa assenta.
	for f in _fogs:
		_tw().tween_property(f, "modulate:a", 0.22, 0.8)
	var t := _tw()
	t.tween_method(_king.silhouette, 0.0, 1.0, 0.8)
	_cam_to(KING_ZOOM + 0.03, Vector2(70, 0), 1.0)


func _a_mask_lights() -> void:
	if _king == null:
		return
	_king.glint_on = false
	var p := _king.global_position + HEAD
	VfxLibrary._flash_sprite(self, p, "halo", Color(GOLD, 0.9), 0.25, 1.4, 0.45)
	VfxLibrary._flash_sprite(self, p, "flare", Color(1, 0.95, 0.7, 1.0), 0.15, 0.7, 0.15)
	Juice.shake(0.15)


## Tentação: centra o quadro entre a Sophia e o Arconte parado (zoom de jogo)
## e sobe os dois acima da caixa.
func _frame_boss() -> void:
	if player == null:
		return
	var boss: Node2D = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.is_boss_enemy:
			boss = e
			break
	if boss == null:
		return
	var mid := (player.global_position.x + boss.global_position.x) * 0.5
	# Desce o quadro como na cena D: os dois ficam ACIMA da caixa de diálogo.
	_cam_to(1.0, Vector2(mid - _view_center().x, D_LIFT), 0.8)


## Encontro com Soter/Velkar: a caixa cobria os dois (os pés ficam a 76 % da
## tela, a caixa começa a ~65 %) — o NPC falava, ajoelhava e abençoava escondido.
## Centra o quadro entre ela e o NPC mais perto e desce D_LIFT, como na tentação.
func _frame_npc() -> void:
	if player == null or level == null:
		return
	var npc: Node2D = null
	var best := INF
	for c in level.get_children():
		if c is NpcEncounter:
			var d := absf((c as Node2D).global_position.x - player.global_position.x)
			if d < best:
				best = d
				npc = c
	if npc == null:
		return
	var mid := (player.global_position.x + npc.global_position.x) * 0.5
	_cam_to(1.0, Vector2(mid - _view_center().x, D_LIFT), 0.6)


## Onde o Rei espera o duelo (o 1º ponto de spawn da zona 0 do Level).
func _duel_x() -> float:
	if level != null and "ZONE_FIRST_X" in level:
		return float(level.get("ZONE_FIRST_X")) - 160.0
	return 460.0


# --- a queda do Rei (tela 1) -------------------------------------------------

## O Rei de verdade se desfez no golpe final; o figurante volta onde ele caiu
## (ajoelhado) para a máscara rachar e ele afundar na névoa.
func fall_at(pos: Vector2) -> void:
	_hide_boss_bodies()
	_king = _make_king(Vector2(pos.x, _ground_y()))
	_king.modulate.a = 0.0
	_tw().tween_property(_king, "modulate:a", 1.0, 0.35)


func _fall_cracks() -> void:
	if _king == null:
		return
	_king.crack_open(0.3, _tw())
	Juice.shake(0.12)


func _fall_sinks() -> void:
	if _king == null:
		return
	_spawn_fog(_king.global_position, 0.8, 1.0)
	var t := _tw()
	t.tween_property(_king, "global_position:y", _king.global_position.y + 60.0, 1.2).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_king, "modulate:a", 0.0, 1.2)
	t.tween_callback(_king.queue_free)


# --- cena B: o roubo (tela 64) -----------------------------------------------

## O Rei sai do lado com mais espaço (a Sophia pode estar junto a uma parede).
func _side() -> float:
	if player == null or level == null:
		return 1.0
	var right := 1720.0
	if "_end_x" in level:
		right = float(level.get("_end_x"))
	return 1.0 if player.global_position.x + 260.0 < right else -1.0


func _b_king_enters() -> void:
	var s := _side()
	var px := player.global_position.x if player != null else _view_center().x
	_spawn_fog(Vector2(px + s * 230.0, _ground_y()), 0.65, 1.2)
	_king = _make_king(Vector2(px + s * 330.0, _ground_y()))
	_king.face(-s)
	_king.modulate.a = 0.0
	var t := _tw()
	t.tween_property(_king, "modulate:a", 1.0, 0.6)
	t.parallel().tween_property(_king, "global_position:x", px + s * 125.0, 2.5)
	t.parallel().tween_callback(_king.step).set_delay(0.3)
	t.parallel().tween_callback(_king.step).set_delay(1.5)
	_cam_to(KING_ZOOM, Vector2(s * 60.0, 0), 3.0)
	for f in _fogs:
		t.parallel().tween_property(f, "modulate:a", 0.25, 1.0).set_delay(1.6)


func _b_voice_merge() -> void:
	if _king == null:
		_b_king_enters()
		_flush()
	# A cor do nome "A Voz" pisca uma vez: a voz saiu da boca dele.
	var plate = _box.get("_plate") if _box != null else null
	if plate is CanvasItem:
		var t := _tw()
		t.tween_property(plate, "modulate", Color(1.6, 1.3, 0.7), 0.12)
		t.tween_property(plate, "modulate", Color.WHITE, 0.45)
	_king.glint(0.5)


func _b_applause() -> void:
	if _king == null:
		return
	Audio.play_sfx("clap")             # o arquivo já tem as 2 palmas lentas
	var t := _tw()
	for k in 2:
		t.tween_interval(0.45)
		t.tween_callback(func() -> void:
			if _king != null:
				VfxLibrary._flash_sprite(self, _king.hand(), "spark", Color(1, 0.95, 0.8), 0.08, 0.3, 0.12))


## Os 7 Anéis voam da mão dela para a mão dele, um a cada 0,8 s. O avanço da
## caixa fica travado até a 7ª chegar (lock_advance, se a UI tiver).
func _b_rings_fly() -> void:
	if _king == null:
		_b_king_enters()
		_flush()
	_lock()
	var t := _tw()
	for i in 7:
		t.tween_callback(_steal_gem.bind(i))
		t.tween_interval(0.8)
	t.tween_interval(0.6)
	t.tween_callback(_unlock)


func _steal_gem(i: int) -> void:
	if _gem_born.has(i):
		return
	var dur := 0.7
	if _hud != null and _hud.has_method("detach_ring"):
		var to: Vector2 = get_viewport().get_canvas_transform() * (_king.hand())
		dur = float(_hud.call("detach_ring", i, to))
		if dur <= 0.0:
			dur = 0.7
	else:
		Audio.ring_note(i)
	_gem_born[i] = true
	# A gema "do mundo" nasce quando a do HUD chega na mão dele.
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_interval(dur)
	t.tween_callback(_gem_arrives.bind(i))
	if _cam != null:
		_tw().tween_property(_cam, "zoom", _cam.zoom + Vector2(0.01, 0.01) * _base_zoom(), 0.2)
	if i == 6:
		Juice.shake(0.8)


func _gem_arrives(i: int) -> void:
	if not is_inside_tree() or _king == null:
		return
	var g := _Gem.new()
	g.color = _ring_color(i)
	g.index = i
	add_child(g)
	g.global_position = _king.hand()
	VfxLibrary._flash_sprite(self, g.global_position, "glow", Color(g.color, 0.9), 0.1, 0.5, 0.25)
	_gems.append(g)
	if _orbit == 0:
		_orbit = 1


func _b_mask_falls() -> void:
	if _king == null:
		_b_king_enters()
		_flush()
	# Pulo de avanço: as gemas que faltavam chegam todas agora.
	for i in 7:
		if not _gem_born.has(i):
			_gem_born[i] = true
			_gem_arrives(i)
	_unlock()
	_orbit = 1
	_king.drop_mask(_tw())
	var t := _tw()
	t.tween_method(_king.cool, 0.0, 1.0, 0.6)
	_flash_white(0.08)
	Juice.shake(0.5)
	# O clarão abre na ILUSTRAÇÃO do roubo (07): os anéis voando para a mão dele,
	# a máscara caindo. Some na fala seguinte, já com o Rei cego no palco.
	_show_art(7, 0.3, Vector2(0.35, -0.45), 7.0)
	# O tema da Voz distorcido → corte → `roubo`: é do Áudio (cue `mask_falls`).
	_music_stopped = false


## Vira o motor: o manto colapsa, as gemas viram 3 anéis concêntricos em volta
## de um núcleo negro, tudo afunda 120 px no chão rachado; fade para o preto.
func _b_sink() -> void:
	if _king == null:
		return
	_orbit = 2
	_orbit_weak = false
	_king.collapse(_tw())
	# Colapsa (0,8 s), o motor gira à vista (1 s), afunda (1,6 s), preto (0,8 s).
	# O chão abre em FENDAS de luz a partir dos pés dele; ele afunda RECORTADO
	# pela linha do chão (_King.clip), com brilho na borda — não achata.
	var feet := Vector2(_king.global_position.x, _ground_y())
	var crack := _crack_ground(feet)
	var t := _tw()
	t.tween_interval(1.0)
	t.tween_property(_king, "global_position:y", _king.global_position.y + 220.0, 1.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for g in _gems:
		if is_instance_valid(g):
			t.parallel().tween_property(g, "modulate:a", 0.0, 0.45)
	t.tween_property(_black, "color:a", 1.0, 0.8)
	var opening := _tw()
	opening.tween_interval(0.15)
	opening.tween_property(crack, "open", 1.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# O momento é épico: luz âmbar forte saindo do chão, tremor crescente, poeira.
	var quake := _tw()
	for k in 6:
		quake.tween_callback(Juice.shake.bind(0.3 + 0.05 * float(k)))
		quake.tween_callback(VfxLibrary.dust.bind(self, feet + Vector2((float(k) - 2.5) * 30.0, -2.0)))
		quake.tween_callback(VfxLibrary._flash_sprite.bind(self, feet + Vector2(0, -10), "halo", Color(1.0, 0.72, 0.3, 0.75), 0.6, 2.2 + 0.3 * float(k), 0.5))
		quake.tween_interval(0.45)
	# O quadro abre e SOBE o chão bem acima da caixa: o abismo fica à vista.
	_cam_to(0.9, Vector2(_side() * 60.0, 100.0), 1.0)


# --- cena C: a descida ao Centro (tela 65) -----------------------------------

## Antes da caixa: preto 1 s → a câmera desce DESCENT px até a altura de jogo e a
## paleta vai do dourado da Coroa ao cinza-violeta do Centro → a Sophia cai de
## joelhos e se ergue. Sem música (só vento): a `centro` entra no 1º caco.
func descend() -> void:
	_descending = true
	PauseStack.push(self)
	Audio.stop_music(0.0)
	_black.color.a = 1.0
	_cam_take()
	if _cam != null:
		_cam.base_offset = Vector2(_cam_saved.base_offset) + Vector2(0, -DESCENT)
		if _cam.has_method("snap"):
			_cam.call("snap")              # câmera nova: pula para o alvo alto
		else:
			_cam.offset = _cam.base_offset
	var cm := CanvasModulate.new()
	cm.color = Color(1.25, 1.0, 0.6)
	add_child(cm)
	var t := _tw()
	if Cinematic.art_texture(8) != null:
		# A queda em ILUSTRAÇÃO (08): do preto, ela cai de cabeça entre os cacos
		# (a deriva desce com ela); volta ao preto e o jogo segue a descida.
		t.tween_interval(0.3)
		t.tween_callback(_show_art.bind(8, 0.7, Vector2(0.0, -0.9), 4.0))
		t.tween_interval(3.0)
		t.tween_callback(_hide_art.bind(0.6))
		t.tween_interval(0.7)
	else:
		t.tween_interval(1.0)
	t.tween_property(_black, "color:a", 0.0, 0.6)
	if _cam != null:
		t.parallel().tween_property(_cam, "base_offset", Vector2(_cam_saved.base_offset), 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(cm, "color", Color(0.86, 0.84, 0.96), 2.5)
	t.tween_callback(_kneel)
	t.tween_interval(1.5)
	await t.finished
	_descending = false
	if not is_inside_tree():
		return
	PauseStack.pop(self)
	# O violeta do Centro fica um pouco; depois o cenário volta ao natural.
	var back := create_tween()
	back.tween_property(cm, "color", Color.WHITE, 3.0)
	back.tween_callback(cm.queue_free)
	_cam_release(0.0)


func _kneel() -> void:
	if player == null:
		return
	Audio.play_sfx("land")
	VfxLibrary.dust(self, player.global_position + Vector2(0, 22))
	var vis: Node2D = player.get_node_or_null("Visual")
	if vis == null:
		return
	var s0: Vector2 = vis.scale
	var t := _tw()
	t.tween_property(vis, "scale", Vector2(s0.x * 1.08, s0.y * 0.72), 0.12)
	t.tween_interval(0.7)
	t.tween_property(vis, "scale", s0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- cena D: a anagnórise (tela 68) ------------------------------------------

func _d_rings_return() -> void:
	_music_stopped = true
	# Recua para enquadrar os três (ela e as duas formas caídas).
	_cam_to(0.9, Vector2(_frame_forms_dx(), D_LIFT), 0.8)   # 0,8 mostrava o fim do chão
	var pts: Array = []
	if final_battle != null and is_instance_valid(final_battle) and final_battle.has_method("release_rings"):
		pts = final_battle.call("release_rings")
	if pts.size() < 7:
		var c := _view_center()
		for k in 7:
			pts.append(c + Vector2(cos(TAU * k / 7.0) * 220.0, -120.0 + sin(TAU * k / 7.0) * 30.0))
	var t := _tw()
	t.tween_interval(0.5)                 # param no ar
	for i in 7:
		t.tween_callback(_return_gem.bind(i, pts[i]))
		t.tween_interval(0.35)
	t.tween_interval(0.6)
	# Depois, push-in nela (1,0 → 1,25).
	t.tween_callback(_cam_to.bind(1.25, Vector2(0, D_LIFT), 2.0))


## Deslocamento X da câmera (a partir da Sophia) que põe as formas caídas no quadro.
func _frame_forms_dx() -> float:
	if player == null or final_battle == null or not is_instance_valid(final_battle) or not "forms" in final_battle:
		return 0.0
	var xs: Array = [player.global_position.x]
	for f in final_battle.get("forms"):
		if is_instance_valid(f):
			xs.append((f as Node2D).global_position.x)
	var mid := (float(xs.min()) + float(xs.max())) * 0.5
	return clampf(mid - player.global_position.x, -260.0, 260.0)


func _return_gem(i: int, from: Vector2) -> void:
	if player == null:
		return
	var g := _Gem.new()
	g.color = _ring_color(i)
	g.scale = Vector2.ONE * 1.7
	add_child(g)
	g.global_position = from
	var chest := player.global_position + Vector2(0, -22)
	var a0 := (from - chest).angle()
	var r0 := from.distance_to(chest)
	var t := create_tween().set_ignore_time_scale(true)
	_tweens.append(t)
	# Espiral até o peito (o inverso do roubo).
	t.tween_method(func(k: float) -> void:
		if is_instance_valid(g):
			var a := a0 + k * PI * 1.5
			g.global_position = chest + Vector2(cos(a), sin(a)) * r0 * (1.0 - k), 0.0, 1.0, 1.0).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		if is_instance_valid(g):
			VfxLibrary._flash_sprite(self, chest, "glow", Color(g.color, 0.9), 0.15, 0.7, 0.3)
			g.queue_free()
		# O som da gema que volta é do HUD (restore_ring); sem ele, a nota do Áudio.
		if _hud != null and _hud.has_method("restore_ring"):
			_hud.call("restore_ring", i)
		else:
			Audio.ring_note(i, true))


func _d_flash() -> void:
	_flash_white(0.12, 0.3)
	Juice.shake(0.35)
	if player != null and _aura == null:
		_aura = Sprite2D.new()
		_aura.texture = VfxLibrary.tex("glow")
		_aura.material = VfxLibrary._additive()
		_aura.modulate = Color(1.0, 0.9, 0.6, 0.0)
		_aura.scale = Vector2.ONE * 1.6
		add_child(_aura)
		_aura.global_position = player.global_position + Vector2(0, -18)
		_tw().tween_property(_aura, "modulate:a", 0.55, 0.4)


func _d_shrink() -> void:
	var rei: Node2D = null
	var col: Node2D = null
	if final_battle != null and is_instance_valid(final_battle) and "forms" in final_battle:
		var forms: Array = final_battle.get("forms")
		if forms.size() >= 2:
			rei = forms[0] if is_instance_valid(forms[0]) else null
			col = forms[1] if is_instance_valid(forms[1]) else null
	# Acompanha o Colosso encolhendo; depois volta para o pé dela.
	_cam_to(0.95, Vector2(_frame_forms_dx(), D_LIFT), 1.0)
	var back := _tw()
	back.tween_interval(3.0)
	back.tween_callback(_cam_to.bind(1.3, Vector2(0, D_LIFT), 1.2))
	# O pequeno: encolhido e cego, ao lado do pé dela.
	_little = CegoPequeno.new()
	_little.scale = Vector2.ONE * 1.5
	add_child(_little)
	var side := 1.0
	if player != null:
		side = float(player.get("facing")) if "facing" in player else 1.0
		_little.global_position = player.global_position + Vector2(side * 30.0, 22.0)
	# A pintura olha para a direita: ao lado direito dela, ele vira para ela.
	_little.scale.x = -absf(_little.scale.x) * side
	_little.modulate.a = 0.0
	var spot := _little.global_position
	var t := _tw()
	if col != null:
		# O Colosso se abre e encolhe VINDO até o pé dela: no fim, só o pequeno.
		t.tween_property(col, "scale", Vector2(0.25, 0.25), 3.0).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(col, "global_position", spot + Vector2(0, -6), 3.0).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(col, "modulate:a", 0.4, 3.0)
		t.parallel().tween_property(col, "modulate:a", 0.0, 0.4).set_delay(3.0)
	if rei != null:
		# O Rei enfraquecido vira névoa e entra no Colosso.
		var to := col.global_position if col != null else rei.global_position
		t.parallel().tween_property(rei, "global_position", to, 1.6)
		t.parallel().tween_property(rei, "modulate", Color(0.8, 0.82, 0.9, 0.0), 1.6)
	t.parallel().tween_property(_little, "modulate:a", 1.0, 1.0).set_delay(2.6)


## O Cego pequeno (CegoPequeno) muda de pose pela fala: ouve "...mãe?" e olha
## pra cima; treme quando ela assume a culpa; estende a mão no "Levanta."; no
## `reclaim` volta à pose automática pelo `glow` (erguido → aninhado na mão dela).
func _little_pose(_who: String, text: String) -> void:
	if _little == null or not is_instance_valid(_little):
		return
	if text.begins_with("...mãe?"):           # quem fala é ele (Narrative.CEGO)
		_little.set_anim("look_up")
	elif text.begins_with("Fui eu que fechei"):
		_little.set_anim("trembling")
	elif text.begins_with("Levanta."):
		_little.set_anim("reach")
		# Ele estende a mão; depois, a ILUSTRAÇÃO da anagnórise (09): ela o abraça.
		var t := _tw()
		t.tween_interval(1.3)
		t.tween_callback(_show_art.bind(9, 0.9, Vector2(-0.3, 0.35), 7.0))


func _d_theme() -> void:
	# O tema da Voz volta sozinho, lento — agora é dela (o Áudio, pelo cue `theme_alone`).
	_music_stopped = false


func _d_reclaim() -> void:
	if _little == null or player == null:
		return
	var hand := player.global_position + Vector2(10.0, -12.0)
	_little.set_anim("")                  # volta ao glow: erguido → aninhado
	var t := _tw()
	t.tween_property(_little, "glow", 1.0, 0.5)
	t.tween_property(_little, "global_position", hand, 0.7).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_little, "scale", Vector2(0.3 * signf(_little.scale.x), 0.3), 0.7)
	t.tween_callback(func() -> void:
		VfxLibrary._flash_sprite(self, hand, "light", Color(1, 0.95, 0.75, 1), 0.2, 1.1, 0.5))
	t.tween_property(_little, "modulate:a", 0.0, 0.3)


# --- peças -------------------------------------------------------------------

func _make_king(feet: Vector2) -> _King:
	var k := _King.new()
	add_child(k)
	k.global_position = feet
	return k


func _spawn_fog(at: Vector2, alpha: float, dur: float) -> void:
	for i in 3:
		var f := Sprite2D.new()
		f.texture = VfxLibrary.tex("smoke")
		f.modulate = Color(FOG_TINT, 0.0)
		f.position = at + Vector2(float(i - 1) * 70.0, -30.0 - float(i % 2) * 34.0) - global_position
		f.scale = Vector2.ONE * 1.4
		f.rotation = float(i) * 1.7
		add_child(f)
		_fogs.append(f)
		var t := _tw()
		t.tween_property(f, "modulate:a", alpha, dur)
		t.parallel().tween_property(f, "scale", Vector2.ONE * 1.4 * 1.4, dur)


## O corpo do chefe caído (congelado no meio da morte pela caixa) sai de cena.
## (Também os pedaços do desmembramento, que ficam parados no ar com a caixa aberta.)
func _hide_boss_bodies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.is_boss_enemy:
			e.visible = false
	if level != null:
		for c in level.get_children():
			if c is Gib:
				(c as Node2D).visible = false


## Card de ilustração da cena (nº de Cinematic.ART): tela cheia, atrás da caixa
## e do flash, entra em `fade` s com Ken Burns de `dur` s. Dura até a próxima fala
## (ou `_hide_art`). Sem o arquivo, não faz nada (a cena segue no palco).
func _show_art(n: int, fade: float, dir: Vector2, dur: float) -> void:
	var tex := Cinematic.art_texture(n)
	if tex == null:
		return
	if _art_rect == null:
		# Na camada dos efeitos, ENTRE o preto e o branco: cobre o preto (a descida
		# começa no escuro) e o clarão branco passa por cima dela (o roubo).
		_art_rect = Cinematic.make_art_rect()
		_fx_layer.add_child(_art_rect)
		_fx_layer.move_child(_art_rect, _black.get_index() + 1)
	if _art_kb != null and _art_kb.is_valid():
		_art_kb.kill()
	_art_rect.texture = tex
	_art_rect.modulate = Color(1, 1, 1, 0)
	_art_line = _line_idx
	_art_kb = Cinematic.ken_burns(_art_rect, self, dur, dir)
	_tw().tween_property(_art_rect, "modulate:a", 1.0, fade)


func _hide_art(fade: float) -> void:
	if not _art_on():
		return
	_art_line = -2
	var t := _tw()
	t.tween_property(_art_rect, "modulate:a", 0.0, fade)


func _art_on() -> bool:
	return _art_rect != null and is_instance_valid(_art_rect) and _art_line != -2


## C1 (QA visual): o número de dano do último golpe ficava CONGELADO na tela a
## cena inteira (a caixa pausa a árvore e ele não some). A cena começa sem eles.
func _clear_damage_numbers() -> void:
	if level == null or not is_instance_valid(level):
		return
	var stack: Array = [level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c is DamageNumber:
				c.queue_free()
			elif c.get_child_count() > 0:
				stack.append(c)


func _clear_fog(dur: float) -> void:
	for f in _fogs:
		if is_instance_valid(f):
			var t := create_tween()
			t.tween_property(f, "modulate:a", 0.0, dur)
			t.tween_callback(f.queue_free)
	_fogs.clear()


## O chão do roubo abre (feedback do João: os riscos pretos grossos de antes
## liam como rabisco): FENDAS de verdade — `_FloorCrack` — que crescem a partir
## de `at` (pés do Rei). Se a arte entregar a sequência pintada (decalque), ela
## toca no lugar do desenho. A cena anima `open` 0→1.
func _crack_ground(at: Vector2) -> Node2D:
	var c := _FloorCrack.new()
	# No chão: atrás dos lutadores e à frente do piso (como os props, z -1
	# absoluto) — o decalque não cobre os pés da Sophia; o Rei (na Staging) fica
	# por cima.
	c.z_as_relative = false
	c.z_index = -1
	c.seed_value = 64
	add_child(c)
	c.global_position = at
	return c


func _ring_color(i: int) -> Color:
	var ch: CharacterData = GameManager.selected_character
	if ch != null:
		var rs: Array = GameContent.ring_skills(ch)
		if i < rs.size():
			return (rs[i] as SkillData).color
	return GOLD


# --- câmera, HUD, flashes -------------------------------------------------------

func _cam_take() -> void:
	if _cam == null or not _cam_saved.is_empty():
		return
	_cam_saved = {"zoom": _cam.zoom, "process_mode": _cam.process_mode,
		"base_offset": _cam.get("base_offset") if "base_offset" in _cam else _cam.offset}
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS


## Zoom de jogo (o salvo ao tomar a câmera): os zooms da cena são relativos a ele.
func _base_zoom() -> Vector2:
	if not _cam_saved.is_empty():
		return Vector2(_cam_saved.zoom)
	return _cam.zoom if _cam != null else Vector2.ONE


## Zoom e deslocamento RELATIVOS ao enquadramento normal.
func _cam_to(zoom: float, shift: Vector2, dur: float) -> void:
	if _cam == null:
		return
	_cam_take()
	_framed = true
	_cur_k = zoom
	_cur_shift = shift
	_tall_seen = _box_tall()
	# Com caixa aberta, os pés dela ficam ACIMA da caixa (QA2 #1).
	var s := shift
	if _box_open():
		s.y = maxf(s.y, _lift(zoom))
	var t := _tw()
	t.tween_property(_cam, "zoom", Vector2(zoom, zoom) * _base_zoom(), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if "base_offset" in _cam:
		t.parallel().tween_property(_cam, "base_offset", Vector2(_cam_saved.base_offset) + s, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _cam_release(dur: float) -> void:
	if _cam == null or _cam_saved.is_empty():
		return
	var saved := _cam_saved
	_cam_saved = {}
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(_cam, "zoom", Vector2(saved.zoom), maxf(dur, 0.01))
	if "base_offset" in _cam:
		t.parallel().tween_property(_cam, "base_offset", Vector2(saved.base_offset), maxf(dur, 0.01))
	t.tween_callback(func() -> void:
		if is_instance_valid(_cam):
			_cam.process_mode = saved.process_mode)


## O 1º aparo do run: o jogador acabou de aparar e a janela do contra-ataque
## está aberta (`_riposte_t` do player do combate6) — ensina NA HORA, com a
## câmera lenta dando tempo de apertar. Sem o campo (outro player), nada.
func _tutor_riposte() -> void:
	if _riposte_taught or player == null or not is_instance_valid(player) or get_tree().paused:
		return
	var rt = player.get("_riposte_t")
	if not (rt is float) or float(rt) <= 0.0:
		return
	_riposte_taught = true
	if not Narrative.once("dica_contra"):
		return
	Juice.slow_mo(RIPOSTE_SLOW, RIPOSTE_SLOW_TIME)
	Staging.hint_now([{"keys": ["attack_light"], "text": Narrative.hint_riposte()}])


## Dica de controle AGORA no HUD (fura a fila; a que estiver na tela cede):
## `show_hint_now` se a UI tiver; senão a mesma manobra do level._tutor_hint.
static func hint_now(segs: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := tree.get_first_node_in_group("hud") if tree != null else null
	if hud == null:
		return
	if hud.has_method("show_hint_now"):
		hud.call("show_hint_now", segs)
	elif "hints" in hud:
		var q: Array = hud.get("hints")
		q.push_front(segs)
		if "_hint" in hud and "_hint_gap" in hud:
			hud.set("_hint", [])
			hud.set("_hint_gap", 0.0)
	elif hud.has_method("show_hint"):
		hud.call("show_hint", segs)


## O HUD roda durante a cena do roubo (as gemas do HUD voam com a caixa aberta).
func _hud_take() -> void:
	if _hud == null or _hud_mode >= 0:
		return
	_hud_mode = _hud.process_mode
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS


func _hud_release() -> void:
	if _hud == null or _hud_mode < 0 or not is_instance_valid(_hud):
		return
	_hud.process_mode = _hud_mode
	_hud_mode = -1


func _lock() -> void:
	if _box != null and is_instance_valid(_box) and _box.has_method("lock_advance"):
		_box.call("lock_advance", true)
		_locked = true


func _unlock() -> void:
	if _locked and _box != null and is_instance_valid(_box) and _box.has_method("lock_advance"):
		_box.call("lock_advance", false)
	_locked = false


func _flash_white(hold: float, fade: float = 0.25) -> void:
	var a := 1.0
	if "reduce_flashes" in Juice and bool(Juice.get("reduce_flashes")):
		a = 0.35
	var t := _tw()
	t.tween_property(_white, "color:a", a, 0.03)
	t.tween_interval(hold)
	t.tween_property(_white, "color:a", 0.0, fade)


func _tw() -> Tween:
	var t := create_tween().set_ignore_time_scale(true)
	_tweens.append(t)
	return t


## O jogador avançou: o que estava no meio salta para o estado final.
func _flush() -> void:
	var list := _tweens
	_tweens = []
	for t in list:
		if t is Tween and t.is_valid() and t.is_running():
			t.custom_step(60.0)


func _view_center() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * (get_viewport_rect().size * 0.5)


## O chão da cena (fixo do Level — a Sophia pode estar no ar quando a cena começa).
func _ground_y() -> float:
	return _ground()


static func _ground() -> float:
	return Level.GROUND_Y


func _process(delta: float) -> void:
	_orbit_t += delta
	_tutor_riposte()
	# A caixa cresceu para as escolhas (ou voltou): o quadro sobe mais um pouco.
	if not _cam_saved.is_empty() and _box_open() and _box_tall() != _tall_seen:
		_cam_to(_cur_k, _cur_shift, 0.35)
	if _king == null or not is_instance_valid(_king):
		return
	var head := _king.global_position + HEAD + Vector2(0, 10)
	for g in _gems:
		if not is_instance_valid(g):
			continue
		var gem: _Gem = g
		var target: Vector2
		var k := float(gem.index)
		if _orbit == 2:
			# Motor: 3 anéis concêntricos em volta do núcleo negro.
			var ring := gem.index % 3
			var r := 16.0 + 14.0 * float(ring)
			var a := _orbit_t * (3.0 - float(ring)) * (1.0 if ring % 2 == 0 else -1.0) + TAU * k / 7.0
			target = _king.global_position + Vector2(0, -36) + Vector2(cos(a) * r, sin(a) * r * 0.45)
		else:
			var a2 := _orbit_t * PI + TAU * k / 7.0          # 1 volta / 2 s
			target = head + Vector2(cos(a2) * 50.0, sin(a2) * 16.0)
		gem.global_position = gem.global_position.lerp(target, clampf(delta * 8.0, 0.0, 1.0))
		gem.dim = (0.35 + 0.45 * absf(sin(_orbit_t * (1.3 + k * 0.71) + k * 2.0))) if _orbit_weak else 1.0


func _exit_tree() -> void:
	PauseStack.pop(self)
	if _ducked:
		Audio.duck_music(0.0, 0.0)
	_hud_release()
	_unsettle_player()
	if _cam != null and is_instance_valid(_cam) and not _cam_saved.is_empty():
		_cam.zoom = _cam_saved.zoom
		_cam.process_mode = _cam_saved.process_mode
		if "base_offset" in _cam:
			_cam.set("base_offset", _cam_saved.base_offset)


# =============================================================================
## O Rei de cena (figurante): a mesma pintura do chefe, sem IA nem colisão.
## Raiz nos PÉS. `body` leva a pintura e o orbe (silhueta/esfriar mexem nele);
## a rachadura e o caco da máscara caindo são desenhados por cima.
## Depois de "a máscara cai" (QA2 #2): se o atlas do Rei tiver um estado
## REVEALED_STATES (o Rei sem máscara, pedido à arte), a pintura troca para ele;
## senão o rosto vira o recorte do retrato `rei_revelado` (máscara rachada, olho
## aceso) — `face_spr`. O disco preto antigo só sobra se faltar o recorte.
class _King extends Node2D:
	var body: Node2D
	var art: CharacterArt
	var orb: Sprite2D
	var face_spr: Sprite2D                          # rosto revelado (recorte provisório)
	var clip: _Clip                             # máscara de recorte (piso)
	var over: Node2D
	var rest_anim: String = "idle"              # pose de descanso (vira o estado revelado)
	var _painted_reveal: bool = false
	var glint_on: bool = false
	var _glint_a: float = 0.0
	var _t: float = 0.0
	var _sil: float = 1.0
	var _cool: float = 0.0
	var _crack: float = 0.0                     # 0..1 (desenho da rachadura)
	var _mask_off: float = 0.0                  # 0..1 (a máscara caindo)
	var _blind: float = 0.0                     # 0..1 (o olho cego aparece)
	var _collapse: float = 0.0                  # 0..1 (vira motor)
	var _dir: float = 1.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		# Recorte pela linha do chão: o que afunda some abaixo do piso.
		clip = _Clip.new()
		add_child(clip)
		body = Node2D.new()
		clip.add_child(body)
		art = CharacterArt.new()
		var t: Dictionary = Bestiary.get_type("rei")
		if t.has("profile"):
			art.set_profile(t.profile)
		var s := 92.0 / 44.0
		art.position = Vector2(0, -24.0 * s)
		art.set_anim("idle")
		body.add_child(art)
		orb = Sprite2D.new()
		orb.texture = PaintedLibrary.region("yaldabaoth", Rect2(1065, 155, 400, 550))
		orb.material = PaintedLibrary.material()
		orb.position = Vector2(78.0, -168.0) + Vector2(0, -24.0)
		orb.scale = Vector2.ONE * 72.0 / 550.0
		body.add_child(orb)
		# O rosto revelado (recorte), invisível até a máscara cair; filho do corpo:
		# vira com ele, esfria com ele e achata no colapso.
		if ResourceLoader.exists(Staging.REVEALED_FACE):
			var tex: Texture2D = load(Staging.REVEALED_FACE)
			face_spr = Sprite2D.new()
			face_spr.texture = tex
			face_spr.scale = Vector2.ONE * Staging.FACE_H / float(tex.get_height())
			face_spr.position = Staging.HEAD + Staging.FACE_DX
			face_spr.modulate.a = 0.0
			body.add_child(face_spr)
		# Desenhos POR CIMA da pintura (orbe aceso, rachadura, caco da máscara).
		over = Node2D.new()
		add_child(over)
		over.draw.connect(_draw_over)

	## A pintura olha para a esquerda; `d` > 0 vira o Rei para a direita.
	func face(d: float) -> void:
		_dir = -1.0 if d > 0.0 else 1.0
		body.scale.x = absf(body.scale.x) * _dir

	## Onde a mão estendida está (mundo): recebe as gemas no roubo.
	func hand() -> Vector2:
		return global_position + Vector2(Staging.HAND.x * _dir, Staging.HAND.y)

	func silhouette(k: float) -> void:
		_sil = k
		_tint()

	func cool(k: float) -> void:
		_cool = k
		_tint()

	func _tint() -> void:
		var c := Color(0.06, 0.05, 0.08).lerp(Color.WHITE, _sil)
		c = c.lerp(c * Staging.BLIND_TINT, _cool)
		body.modulate = Color(c.r, c.g, c.b, 1.0)

	func step() -> void:
		Audio.play_sfx("king_step")
		art.set_anim("walk")
		var t := create_tween()
		t.tween_property(body, "position:y", -3.0, 0.3).set_trans(Tween.TRANS_SINE)
		t.tween_property(body, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
		t.tween_callback(func() -> void: art.set_anim(rest_anim))

	func glint(a: float) -> void:
		_glint_a = maxf(_glint_a, a)

	func crack_open(dur: float, t: Tween) -> void:
		if has_pose("mask_crack"):
			# A máscara racha NA PINTURA (mão no rosto): nada desenhado por cima
			# deslizando em relação ao corpo.
			pose("mask_crack")
			_painted_reveal = true
			return
		t.tween_property(self, "_crack", 1.0, dur)

	func drop_mask(t: Tween) -> void:
		var st := revealed_state()
		if st != "":
			# A pintura do Rei SEM máscara (arte, Onda 6): a mão no rosto com a
			# máscara rachando (`mask_crack`) e, 0,35 s depois, o vazio escuro com
			# UM olho âmbar (`revealed`). A máscara inteira cai por cima.
			_painted_reveal = true
			rest_anim = st
			if has_pose("mask_crack"):
				pose("mask_crack")
				t.tween_interval(0.35)
				t.tween_callback(pose.bind(st))
			else:
				pose(st)
				t.tween_interval(0.01)
		elif face_spr != null:
			# Provisório: a máscara racha, um caco cai e o rosto do retrato aparece.
			t.tween_property(face_spr, "modulate:a", 1.0, 0.25)
		else:
			t.tween_property(self, "_blind", 1.0, 0.3)
		t.parallel().tween_property(self, "_mask_off", 1.0, 0.6).set_ease(Tween.EASE_IN)

	## O estado "Rei sem máscara" do atlas pintado ("" = ainda não existe).
	func revealed_state() -> String:
		for s in Staging.REVEALED_STATES:
			if has_pose(s):
				return s
		return ""

	## O atlas pintado do Rei tem esta pose (estados da folha `rei_revelado_a`:
	## mask_crack, revealed, triumph, dominion, sinking)?
	func has_pose(st: String) -> bool:
		if art == null or not art.has_boss_frames():
			return false
		var db = art.get("_boss_db")
		if not (db is Dictionary):
			return false
		var meta = (db as Dictionary).get("meta", {})
		if not (meta is Dictionary):
			return false
		var states = (meta as Dictionary).get("states", {})
		return states is Dictionary and (states as Dictionary).has(st)

	## Troca a pose pintada (se existir). Nas poses em que o orbe-olho já está
	## pintado na mão (ou o corpo afunda), o orbe solto some.
	func pose(st: String) -> void:
		if not has_pose(st):
			return
		art.set_anim(st)
		art.scale.x = -absf(art.scale.x) if st in Staging.MIRRORED_POSES else absf(art.scale.x)
		if st in Staging.REVEALED_STATES:
			rest_anim = st
		orb.visible = not (st in ["triumph", "dominion", "sinking", "mask_crack"])

	## Volta à pose de descanso (revelado, depois que a máscara caiu).
	func rest() -> void:
		pose(rest_anim)

	func collapse(t: Tween) -> void:
		if has_pose("sinking"):
			# A pintura dele afundando em rachaduras de luz; o achatamento é curto.
			pose("sinking")
			t.tween_property(body, "scale:y", 0.7, 0.8).set_ease(Tween.EASE_IN)
		else:
			t.tween_property(body, "scale:y", 0.2, 0.8).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(self, "_collapse", 1.0, 0.8)

	func _process(delta: float) -> void:
		_t += delta
		_glint_a = maxf(0.0, _glint_a - delta * 0.8)
		if clip != null:
			clip.floor_y = Staging._ground() - global_position.y + 4.0
			clip.queue_redraw()
		if over != null:
			over.queue_redraw()

	func _draw_over() -> void:
		var head := Staging.HEAD
		var orb_p := Vector2(orb.position.x * _dir, orb.position.y)
		# O orbe-olho: o único ponto de luz da silhueta (pulsa 0,8 Hz).
		if glint_on or _glint_a > 0.0:
			var p := 0.55 + 0.45 * sin(_t * TAU * 0.8)
			var a := maxf(p * (1.0 - _sil * 0.6) if glint_on else 0.0, _glint_a)
			over.draw_circle(orb_p, 13.0, Color(1.0, 0.92, 0.55, 0.18 * a))
			over.draw_circle(orb_p, 6.0, Color(1.0, 0.95, 0.7, 0.55 * a))
			over.draw_circle(orb_p, 2.5, Color(1, 1, 0.9, a))
		# A rachadura (queda da tela 1): 3 segmentos brancos sobre a máscara.
		if _crack > 0.0:
			var pts := [head + Vector2(-3, -14), head + Vector2(2, -5), head + Vector2(-2, 3), head + Vector2(4, 13)]
			var n := _crack * 3.0
			for s in 3:
				var k := clampf(n - float(s), 0.0, 1.0)
				if k > 0.0:
					var q: Vector2 = pts[s].lerp(pts[s + 1], k)
					over.draw_line(pts[s], q, Color(0.12, 0.08, 0.06, 0.95), 2.0)
					over.draw_line(pts[s] + Vector2(1, 0), q + Vector2(1, 0), Color(1, 0.95, 0.8, 0.8), 0.8)
		# O rosto por trás da máscara: preto, um olho cego (branco-leitoso, sem pupila).
		if _blind > 0.0:
			var sy := 1.0 - _collapse * 0.8
			var hp := Vector2(head.x, head.y * sy)
			over.draw_set_transform(hp, 0.0, Vector2(1.0, 1.55))
			over.draw_circle(Vector2.ZERO, 12.5, Color(0.02, 0.02, 0.04, _blind))
			over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			over.draw_circle(hp + Vector2(0, -3), 8.0, Color(0.9, 0.92, 0.95, 0.15 * _blind))
			over.draw_circle(hp + Vector2(0, -3), 4.5, Color(0.9, 0.92, 0.95, 0.9 * _blind))
		# A máscara caindo: desce 30 px girando 20° e some. Com a pintura sem
		# máscara cai a máscara inteira; no provisório (rosto do retrato, máscara
		# rachada), só o CACO que se soltou em cima do olho.
		if _mask_off > 0.0 and _mask_off < 1.0 and not _painted_reveal:
			over.draw_set_transform(head + Vector2(6.0 * _mask_off, 30.0 * _mask_off), deg_to_rad(20.0) * _mask_off * _dir, Vector2.ONE)
			var mc := Color(0.95, 0.92, 0.82, 1.0 - _mask_off)
			var ink := Color(0.1, 0.08, 0.06, mc.a)
			if face_spr == null:
				var oval := PackedVector2Array()
				for i in 16:
					var a2 := TAU * float(i) / 16.0
					oval.append(Vector2(cos(a2) * 13.0, sin(a2) * 21.0))
				over.draw_colored_polygon(oval, mc)
				over.draw_line(Vector2(-6, -6), Vector2(-6, 2), ink, 2.0)
				over.draw_line(Vector2(6, -6), Vector2(6, 2), ink, 2.0)
				over.draw_line(Vector2(0, -4), Vector2(0, 10), Color(ink, mc.a * 0.5), 1.0)
			else:
				var shard := PackedVector2Array([Vector2(-7 * _dir, -9), Vector2(4 * _dir, -11), Vector2(7 * _dir, -2),
					Vector2(1 * _dir, 2), Vector2(-3 * _dir, 9), Vector2(-8 * _dir, 1)])
				over.draw_colored_polygon(shard, mc)
				var edge := shard.duplicate()
				edge.append(shard[0])
				over.draw_polyline(edge, ink, 1.0, true)
			over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# O motor: um núcleo negro no meio dos anéis.
		if _collapse > 0.0 and not _painted_reveal:
			over.draw_circle(Vector2(0, -36), 10.0 * _collapse, Color(0.01, 0.01, 0.02, _collapse))
		# Afundando: a borda do chão por onde ele entra brilha (o corpo some
		# abaixo dela pelo recorte `clip`).
		var sunk := global_position.y - Staging._ground()
		if sunk > 1.0:
			var w := 90.0
			var gy := -sunk
			var ga := clampf(sunk / 20.0, 0.0, 1.0)
			over.draw_set_transform(Vector2(0, gy), 0.0, Vector2(1.0, 0.22))
			over.draw_circle(Vector2.ZERO, w, Color(1.0, 0.78, 0.4, 0.3 * ga))
			over.draw_circle(Vector2.ZERO, w * 0.62, Color(1.0, 0.88, 0.6, 0.5 * ga))
			over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			over.draw_line(Vector2(-w * 0.8, gy), Vector2(w * 0.8, gy), Color(1.0, 0.95, 0.8, 0.85 * ga), 1.5, true)


## Uma gema de Anel no mundo (o roubo e a devolução).
class _Gem extends Node2D:
	var color: Color = Color(1, 0.86, 0.5)
	var index: int = 0
	var dim: float = 1.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 10.0, Color(color, 0.18 * dim))
		var d := PackedVector2Array([Vector2(0, -6), Vector2(4.5, 0), Vector2(0, 6), Vector2(-4.5, 0)])
		draw_colored_polygon(d, Color(color.r, color.g, color.b, 0.95 * maxf(dim, 0.4)))
		draw_circle(Vector2(-1, -2), 1.4, Color(1, 1, 1, 0.8 * dim))


## Recorte do Rei pela linha do chão (clip_children): só o que está ACIMA de
## `floor_y` (local) aparece. Parado no chão, não corta nada (pés ≈ 0).
class _Clip extends Node2D:
	var floor_y: float = 4.0

	func _ready() -> void:
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY

	func _draw() -> void:
		draw_rect(Rect2(-400.0, -600.0, 800.0, 600.0 + floor_y), Color.WHITE)


## Fendas no chão que ABREM (cena B): ramos irregulares saindo do ponto,
## achatados na perspectiva do piso, com largura variável (afina na ponta),
## borda escura suave e um núcleo de luz âmbar com brilho aditivo. `open` 0→1
## cresce o comprimento e a largura; faíscas sobem das pontas enquanto abre.
## DECALQUE PINTADO (Produção, `artes/gpt/fx/fx_floor_crack_a.png` →
## tools/encenacao/fx_floor_crack.py → tira de DECAL_FRAMES quadros: fissura →
## ramifica → luz âmbar → placas caindo → abismo → poeira): é o efeito PRINCIPAL,
## grande, sob o Rei; os fachos de luz, o poço e as faíscas ficam de apoio por
## cima. Sem o arquivo, as fendas desenhadas fazem o papel.
class _FloorCrack extends Node2D:
	const DECALS := ["res://assets/cinematic/fx_floor_crack_a.png", "res://assets/painted/fx/fx_floor_crack_a.png"]
	const DECAL_FRAMES := 6
	const DECAL_W := 330.0                     # largura do decalque (px de mundo)
	const CORE := Color(1.0, 0.78, 0.38)
	const EDGE := Color(0.05, 0.03, 0.04)
	var open: float = 0.0:
		set(v):
			open = v
			queue_redraw()
			if _glow != null:
				_glow.queue_redraw()
			if _decal != null:
				_decal.frame = clampi(int(v * float(_decal.hframes)), 0, _decal.hframes - 1)
				_decal.modulate.a = clampf(v * 8.0, 0.0, 1.0)
	var seed_value: int = 64
	var _branches: Array = []                  # [{pts: PackedVector2Array, w: float}]
	var _glow: Node2D
	var _decal: Sprite2D
	var _spark_t: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		for path in DECALS:
			if ResourceLoader.exists(path):
				var tex: Texture2D = load(path)
				_decal = Sprite2D.new()
				_decal.texture = tex
				_decal.hframes = DECAL_FRAMES
				var fw := float(tex.get_width()) / float(DECAL_FRAMES)
				# o tampo do bloco achatado um pouco para caber na faixa do chão; o
				# centro fica logo abaixo dos pés (ele está no meio do tampo)
				_decal.scale = Vector2(1.0, 0.8) * DECAL_W / fw
				_decal.position = Vector2(0.0, 8.0)
				_decal.modulate.a = 0.0
				add_child(_decal)
				break
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var dirs := [PI + 0.1, -0.1, PI * 0.7, PI * 0.3, PI * 1.25, PI * 1.82]
		for k in dirs.size():
			var a: float = float(dirs[k]) + rng.randf_range(-0.12, 0.12)
			var length: float = rng.randf_range(150.0, 220.0) * (1.0 if k < 2 else 0.6)
			var pts := PackedVector2Array([Vector2.ZERO])
			var p := Vector2.ZERO
			var n := 9
			for i in n:
				a += rng.randf_range(-0.45, 0.45)
				p += Vector2(cos(a), sin(a)) * (length / float(n))
				pts.append(p)
			_branches.append({"pts": pts, "w": rng.randf_range(4.0, 5.5) * (1.0 if k < 2 else 0.7)})
		_glow = Node2D.new()
		_glow.material = VfxLibrary._additive()
		add_child(_glow)
		_glow.draw.connect(_draw_glow)

	func _process(delta: float) -> void:
		if _glow != null and open > 0.0:
			_glow.queue_redraw()               # os fachos tremulam
		# Faíscas sobem das pontas enquanto a fenda abre (uma ponta por vez).
		if open <= 0.0 or open >= 1.0 or _branches.is_empty():
			return
		_spark_t += delta
		if _spark_t < 0.1:
			return
		_spark_t = 0.0
		var b: Dictionary = _branches[randi() % _branches.size()]
		var tip := _tip(b)
		var gp := global_position + Vector2(tip.x, tip.y * 0.3)
		VfxLibrary._flash_sprite(get_parent(), gp + Vector2(0, -4), "spark", Color(1.0, 0.85, 0.55, 0.9), 0.12, 0.02, 0.45)

	## Ponta atual do ramo (cresce com `open`).
	func _tip(b: Dictionary) -> Vector2:
		var pts: PackedVector2Array = b.pts
		var f := clampf(open, 0.0, 1.0) * float(pts.size() - 1)
		var i := mini(int(f), pts.size() - 2)
		return pts[i].lerp(pts[i + 1], f - float(i))

	## Faixa do ramo (polígono), já achatada no piso: largura × `wmul`.
	func _strip(b: Dictionary, wmul: float) -> PackedVector2Array:
		var pts: PackedVector2Array = b.pts
		var reach := clampf(open, 0.0, 1.0) * float(pts.size() - 1)
		var line := PackedVector2Array()
		for i in pts.size():
			if float(i) <= reach:
				line.append(pts[i])
			else:
				var tp := _tip(b)
				if tp.distance_to(line[line.size() - 1]) > 0.5:
					line.append(tp)
				break
		if line.size() < 2 or line[line.size() - 1].distance_to(line[0]) < 1.0:
			return PackedVector2Array()
		# O traçado vai para o plano do piso (achatado); a LARGURA não (senão as
		# fendas deitadas viram fio).
		for i in line.size():
			line[i] = Vector2(line[i].x, line[i].y * 0.3)
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var wopen := clampf(open * 1.6, 0.0, 1.0)
		for i in line.size():
			var d: Vector2
			if i < line.size() - 1:
				d = (line[i + 1] - line[i]).normalized()
			else:
				d = (line[i] - line[i - 1]).normalized()
			var nrm := Vector2(-d.y, d.x)
			# afina para a ponta; serrilha leve (largura variável)
			var taper := 1.0 - float(i) / float(maxi(1, line.size() - 1))
			var jag := 0.75 + 0.25 * sin(float(i) * 2.3 + float(seed_value))
			var w: float = float(b.w) * wmul * wopen * (0.2 + 0.8 * taper) * jag
			var q := line[i]
			left.append(q + nrm * w)
			right.append(q - nrm * w)
		right.reverse()
		left.append_array(right)
		return left

	## Desenha a faixa em QUADS (um por segmento): a faixa fina e torta pode se
	## auto-cruzar como polígono único; quad a quad nunca falha.
	func _poly(ci: CanvasItem, pts: PackedVector2Array, c: Color) -> void:
		var n := pts.size() / 2
		if n < 2:
			return
		for i in n - 1:
			var q := PackedVector2Array([pts[i], pts[i + 1], pts[pts.size() - 2 - i], pts[pts.size() - 1 - i]])
			# quad degenerado (largura ~0) → "Invalid polygon": pula
			var area := absf((q[2] - q[0]).cross(q[3] - q[1])) * 0.5
			if area > 0.05:
				ci.draw_colored_polygon(q, c)

	func _draw() -> void:
		if _decal != null:
			return
		for b in _branches:
			_poly(self, _strip(b, 2.2), Color(EDGE, 0.35))
			_poly(self, _strip(b, 1.25), Color(EDGE, 0.8))
			_poly(self, _strip(b, 0.55), Color(CORE, 0.95))

	func _draw_glow() -> void:
		var a := clampf(open * 2.0, 0.0, 1.0)
		if _decal == null:                     # com o decalque, as fendas são as dele
			for b in _branches:
				_poly(_glow, _strip(b, 1.8), Color(CORE.r, CORE.g * 0.9, CORE.b * 0.7, 0.28 * a))
				_poly(_glow, _strip(b, 0.35), Color(1.0, 0.95, 0.8, 0.7 * a))
		# Luz SUBINDO das fendas: fachos aditivos que nascem nos ramos e somem
		# para cima (degradê por vértice), tremulando.
		var tt := float(Time.get_ticks_msec()) * 0.001
		for bi in _branches.size():
			var b: Dictionary = _branches[bi]
			var pts: PackedVector2Array = b.pts
			for j in range(1, pts.size(), 2):
				if float(j) > open * float(pts.size() - 1):
					break
				var base := Vector2(pts[j].x, pts[j].y * 0.3)
				var flick := 0.75 + 0.25 * sin(tt * 9.0 + float(j) * 1.7 + float(bi))
				var hgt := (70.0 + 50.0 * flick) * a * (1.0 - float(j) / float(pts.size()))
				var half := 5.0 + 3.0 * flick
				_glow.draw_polygon(PackedVector2Array([base + Vector2(-half, 0), base + Vector2(half, 0),
					base + Vector2(half * 0.4, -hgt), base + Vector2(-half * 0.4, -hgt)]),
					PackedColorArray([Color(CORE, 0.55 * a * flick), Color(CORE, 0.55 * a * flick),
					Color(CORE, 0.0), Color(CORE, 0.0)]))
		# o "poço" de luz sob os pés dele
		_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		_glow.draw_circle(Vector2.ZERO, 70.0 * a, Color(CORE, 0.14 * a))
		_glow.draw_circle(Vector2.ZERO, 38.0 * a, Color(CORE, 0.3 * a))
		_glow.draw_circle(Vector2.ZERO, 16.0 * a, Color(1.0, 0.95, 0.8, 0.6 * a))
		_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# coluna de luz larga no centro (o chão "se abre" para o motor)
		var ch := 160.0 * a
		_glow.draw_polygon(PackedVector2Array([Vector2(-34, 0), Vector2(34, 0), Vector2(18, -ch), Vector2(-18, -ch)]),
			PackedColorArray([Color(1.0, 0.8, 0.45, 0.45 * a), Color(1.0, 0.8, 0.45, 0.45 * a), Color(CORE, 0.0), Color(CORE, 0.0)]))
