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
## SOM: o estado da música é do Áudio. Cada cue vai primeiro a `Audio.cue()`;
## se o Áudio conhece o cue, o som é dele (`_snd = false`) e aqui só a imagem.
## Sem essa API, a Staging toca um som mínimo (play_sfx/play_music/duck).
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
var _little: _Little
var _aura: Sprite2D
var _locked: bool = false
var _music_stopped: bool = false
var _snd: bool = true                          # a Staging toca o som deste cue?
var _ducked: bool = false                      # abaixou a música (soter) — soltar no fim

var _fx_layer: CanvasLayer                     # abaixo da caixa (90): flash e preto
var _white: ColorRect
var _black: ColorRect


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


# --- API para o Level ------------------------------------------------------------

## Abre a caixa de diálogo e encena as falas pelo `cue`. Devolve a caixa
## (await .finished / .choice_made como sempre).
func play(lines: Array, choices: Array = [], scene: String = "") -> DialogueBox:
	_scene = scene
	_box = DialogueBox.play(lines, choices)
	_box.line_shown.connect(_on_line)
	_box.finished.connect(_on_finished.bind(_box))
	_scene_open()
	return _box


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
			var t := _tw()
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
			if Audio.has_method("voice_theme"):
				Audio.call("voice_theme", "santuario")
			else:
				Audio.play_music("theme")
		"soter":
			# M3: a música do Éon cai a −14 dB ao abrir o encontro ("Senta.").
			Audio.duck_music(600.0, -14.0)
			_ducked = true


func _on_line(index: int, line: Dictionary) -> void:
	_flush()
	var cue := String(line.get("cue", ""))
	var who := String(line.get("speaker", ""))
	var text := String(line.get("text", ""))
	_snd = true
	if cue != "" and Audio.has_method("cue"):
		_snd = not bool(Audio.call("cue", cue))
	match cue:
		"heartbeat":
			if _snd:
				_beat()
		"music_stop":
			if _snd:
				Audio.stop_music(0.0)
			_music_stopped = true
		"chime":
			if _snd:
				Audio.play_sfx("stele_unlock", -1.0, -6.0)
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
			elif text.contains("mais baixo"):
				Audio.duck_music(9.0, -14.0)
				_cam_to(1.2, Vector2(_side() * 50.0, 6.0), 1.6)
		"tentacao":
			# M2: o passado "quente" vira arma — a música do chefe recua.
			if text.begins_with("(Como ele sabe"):
				Audio.duck_music(5.0, -10.0)
		"anagnorise":
			if text.begins_with("Fui eu que fechei"):
				_cam_to(1.32, Vector2(0, D_LIFT - 10.0), 1.2)   # baixa à altura dela
			elif text.begins_with("Falta o mais difícil"):
				_cam_to(1.0, Vector2(0, D_LIFT * 0.6), 1.4)     # abre o quadro


func _on_finished(box: DialogueBox) -> void:
	if box != _box:
		return
	_flush()
	if _ducked:
		Audio.duck_music(0.0, 0.0)
		_ducked = false
	match _scene:
		"rei":
			_cam_release(0.5)
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
		"anagnorise":
			_cam_release(0.6)
		"santuario":
			if _music_stopped:
				await get_tree().create_timer(1.0, true, false, true).timeout
			if not is_inside_tree():
				return
			if Audio.has_method("voice_theme"):
				Audio.call("voice_theme", "")
			elif RunManager.run_active:
				Audio.play_music(Audio.track_for_screen(RunManager.current_screen))
			_music_stopped = false
	_scene = ""


# --- cena A: o Rei sai da névoa (tela 1) ----------------------------------------

func _a_fog() -> void:
	var c := _view_center()
	_cam_to(1.08, Vector2(60, 0), 2.0)
	if _snd:
		Audio.play_sfx("fog_swell")
		Audio.duck_music(9.0, -8.0)
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
	_cam_to(1.15, Vector2(70, 0), 1.0)
	if _snd:
		Audio.play_sfx("boss_appear", -1.0, -8.0)


func _a_mask_lights() -> void:
	if _king == null:
		return
	_king.glint_on = false
	var p := _king.global_position + HEAD
	VfxLibrary._flash_sprite(self, p, "halo", Color(GOLD, 0.9), 0.25, 1.4, 0.45)
	VfxLibrary._flash_sprite(self, p, "flare", Color(1, 0.95, 0.7, 1.0), 0.15, 0.7, 0.15)
	Juice.shake(0.15)
	if _snd:
		Audio.play_sfx("mask_light")


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
	if _snd:
		Audio.play_sfx("block", -1.0, -4.0)
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
	_cam_to(1.12, Vector2(s * 60.0, 0), 3.0)
	for f in _fogs:
		t.parallel().tween_property(f, "modulate:a", 0.25, 1.0).set_delay(1.6)


func _b_voice_merge() -> void:
	if _king == null:
		_b_king_enters()
		_flush()
	if _snd:
		Audio.play_sfx("voice_merge")
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
	var t := _tw()
	for k in 2:
		t.tween_interval(0.45)
		t.tween_callback(func() -> void:
			if Audio.has_sfx("clap"):
				Audio.play_sfx("clap")
			else:
				Audio.play_sfx("parry", 0.02, -10.0)
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
		if Audio.has_method("ring_note"):
			Audio.call("ring_note", i, false)
		else:
			Audio.play_sfx("ring_steal")
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
	# O tema da Voz, grave e lento (pitch 0,75) por 3 s → corta → `roubo`
	# (com o Áudio novo, o cue `mask_falls` já fez isso).
	_music_stopped = false
	if not _snd:
		return
	Audio.play_music("theme", false, 0.75)
	var m := create_tween().set_ignore_time_scale(true)
	m.tween_interval(3.0)
	m.tween_callback(func() -> void:
		Audio.stop_music(0.0)
		Audio.set_music_pitch(1.0, 0.0)
		Audio.play_music("roubo"))


## Vira o motor: o manto colapsa, as gemas viram 3 anéis concêntricos em volta
## de um núcleo negro, tudo afunda 120 px no chão rachado; fade para o preto.
func _b_sink() -> void:
	if _king == null:
		return
	_orbit = 2
	_orbit_weak = false
	_king.collapse(_tw())
	# Colapsa (0,8 s), o motor gira à vista (1 s), afunda (1,6 s), preto (0,8 s).
	var t := _tw()
	t.tween_interval(1.8)
	t.tween_property(_king, "global_position:y", _king.global_position.y + 120.0, 1.6).set_ease(Tween.EASE_IN)
	t.tween_property(_black, "color:a", 1.0, 0.8)
	_crack_ground(_king.global_position)
	if _snd:
		Audio.play_sfx("dive")
		Audio.play_sfx("boss_step", -1.0, -2.0)
		Audio.stop_music(2.0)
	Juice.shake(0.35)
	_cam_to(1.12, Vector2(_side() * 60.0, 40.0), 1.8)


# --- cena C: a descida ao Centro (tela 65) -----------------------------------

## Antes da caixa: preto 1 s → a câmera desce DESCENT px até a altura de jogo e a
## paleta vai do dourado da Coroa ao cinza-violeta do Centro → a Sophia cai de
## joelhos e se ergue. Sem música (só vento): a `centro` entra no 1º caco.
func descend() -> void:
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
	t.tween_interval(1.0)
	t.tween_property(_black, "color:a", 0.0, 0.6)
	if _cam != null:
		t.parallel().tween_property(_cam, "base_offset", Vector2(_cam_saved.base_offset), 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(cm, "color", Color(0.86, 0.84, 0.96), 2.5)
	t.tween_callback(_kneel)
	t.tween_interval(1.5)
	await t.finished
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
	if _snd:
		Audio.stop_music(0.0)
	_music_stopped = true
	# Recua para enquadrar os três (ela e as duas formas caídas).
	_cam_to(0.8, Vector2(_frame_forms_dx(), D_LIFT), 0.8)
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
		# O som da gema que volta é do HUD (restore_ring).
		if _hud != null and _hud.has_method("restore_ring"):
			_hud.call("restore_ring", i))


func _d_flash() -> void:
	_flash_white(0.12, 0.3)
	Juice.shake(0.35)
	if _snd:
		Audio.play_sfx("nova")
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
	var t := _tw()
	if col != null:
		t.tween_property(col, "scale", Vector2(0.25, 0.25), 3.0).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(col, "modulate:a", 0.4, 3.0)
	if rei != null:
		# O Rei enfraquecido vira névoa e entra no Colosso.
		var to := col.global_position if col != null else rei.global_position
		t.parallel().tween_property(rei, "global_position", to, 1.6)
		t.parallel().tween_property(rei, "modulate", Color(0.8, 0.82, 0.9, 0.0), 1.6)
	# O pequeno: encolhido e cego, ao lado do pé dela.
	_little = _Little.new()
	_little.scale = Vector2.ONE * 1.5
	add_child(_little)
	var side := 1.0
	if player != null:
		side = float(player.get("facing")) if "facing" in player else 1.0
		_little.global_position = player.global_position + Vector2(side * 30.0, 22.0)
	_little.modulate.a = 0.0
	t.parallel().tween_property(_little, "modulate:a", 1.0, 1.2).set_delay(1.8)
	if _snd:
		Audio.play_sfx("whisper", -1.0, -6.0)


func _d_theme() -> void:
	# O tema da Voz volta sozinho, lento — agora é dela (cue `theme_alone`).
	if _snd:
		Audio.play_music("theme", true, 0.85)
	_music_stopped = false


func _d_reclaim() -> void:
	if _little == null or player == null:
		return
	var hand := player.global_position + Vector2(10.0, -12.0)
	var t := _tw()
	t.tween_property(_little, "glow", 1.0, 0.5)
	t.tween_property(_little, "global_position", hand, 0.7).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_little, "scale", Vector2(0.3, 0.3), 0.7)
	t.tween_callback(func() -> void:
		VfxLibrary._flash_sprite(self, hand, "light", Color(1, 0.95, 0.75, 1), 0.2, 1.1, 0.5)
		if _snd:
			Audio.play_sfx("revive", -1.0, -4.0))
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
func _hide_boss_bodies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.is_boss_enemy:
			e.visible = false


func _clear_fog(dur: float) -> void:
	for f in _fogs:
		if is_instance_valid(f):
			var t := create_tween()
			t.tween_property(f, "modulate:a", 0.0, dur)
			t.tween_callback(f.queue_free)
	_fogs.clear()


func _crack_ground(at: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 64
	for k in 5:
		var ln := Line2D.new()
		ln.width = 2.0
		ln.default_color = Color(0.05, 0.03, 0.06, 0.9)
		var p := at + Vector2(0, 2) - global_position
		ln.add_point(p)
		var dir := Vector2(cos(PI + PI * float(k) / 4.0) * 1.0, 0.12)
		for s in 3:
			p += dir.rotated(rng.randf_range(-0.4, 0.4)) * rng.randf_range(14.0, 26.0)
			ln.add_point(p)
		add_child(ln)


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
	var t := _tw()
	t.tween_property(_cam, "zoom", Vector2(zoom, zoom) * _base_zoom(), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if "base_offset" in _cam:
		t.parallel().tween_property(_cam, "base_offset", Vector2(_cam_saved.base_offset) + shift, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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


func _beat() -> void:
	var s := "heartbeat" if Audio.has_sfx("heartbeat") else "boss_step"
	var t := _tw()
	t.tween_callback(func() -> void: Audio.play_sfx(s, 0.0, -4.0))
	t.tween_interval(0.28)
	t.tween_callback(func() -> void: Audio.play_sfx(s, 0.0, -9.0))


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


func _ground_y() -> float:
	if player != null:
		return player.global_position.y + 24.0
	return 298.0


func _process(delta: float) -> void:
	_orbit_t += delta
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
	if _cam != null and is_instance_valid(_cam) and not _cam_saved.is_empty():
		_cam.zoom = _cam_saved.zoom
		_cam.process_mode = _cam_saved.process_mode
		if "base_offset" in _cam:
			_cam.set("base_offset", _cam_saved.base_offset)


# =============================================================================
## O Rei de cena (figurante): a mesma pintura do chefe, sem IA nem colisão.
## Raiz nos PÉS. `body` leva a pintura e o orbe (silhueta/esfriar mexem nele);
## a máscara, a rachadura e o olho cego são desenhados por cima.
class _King extends Node2D:
	var body: Node2D
	var art: CharacterArt
	var orb: Sprite2D
	var over: Node2D
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
		body = Node2D.new()
		add_child(body)
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
		# Desenhos POR CIMA da pintura (orbe aceso, rachadura, olho cego).
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
		t.tween_callback(func() -> void: art.set_anim("idle"))

	func glint(a: float) -> void:
		_glint_a = maxf(_glint_a, a)

	func crack_open(dur: float, t: Tween) -> void:
		t.tween_property(self, "_crack", 1.0, dur)

	func drop_mask(t: Tween) -> void:
		t.tween_property(self, "_blind", 1.0, 0.3)
		t.parallel().tween_property(self, "_mask_off", 1.0, 0.6).set_ease(Tween.EASE_IN)

	func collapse(t: Tween) -> void:
		t.tween_property(body, "scale:y", 0.2, 0.8).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(self, "_collapse", 1.0, 0.8)

	func _process(delta: float) -> void:
		_t += delta
		_glint_a = maxf(0.0, _glint_a - delta * 0.8)
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
		# A máscara caindo: desce 30 px girando 20° e some.
		if _mask_off > 0.0 and _mask_off < 1.0:
			over.draw_set_transform(head + Vector2(6.0 * _mask_off, 30.0 * _mask_off), deg_to_rad(20.0) * _mask_off * _dir, Vector2.ONE)
			var mc := Color(0.95, 0.92, 0.82, 1.0 - _mask_off)
			var oval := PackedVector2Array()
			for i in 16:
				var a2 := TAU * float(i) / 16.0
				oval.append(Vector2(cos(a2) * 13.0, sin(a2) * 21.0))
			over.draw_colored_polygon(oval, mc)
			var ink := Color(0.1, 0.08, 0.06, mc.a)
			over.draw_line(Vector2(-6, -6), Vector2(-6, 2), ink, 2.0)
			over.draw_line(Vector2(6, -6), Vector2(6, 2), ink, 2.0)
			over.draw_line(Vector2(0, -4), Vector2(0, 10), Color(ink, mc.a * 0.5), 1.0)
			over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# O motor: um núcleo negro no meio dos anéis.
		if _collapse > 0.0:
			over.draw_circle(Vector2(0, -36), 10.0 * _collapse, Color(0.01, 0.01, 0.02, _collapse))


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


## "Alguém pequeno": encolhido e cego, do tamanho do pé dela.
class _Little extends Node2D:
	var glow: float = 0.0
	var _t: float = 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var breath := 1.0 + 0.04 * sin(_t * 2.4)
		var body := Color(0.08, 0.07, 0.1).lerp(Color(1, 0.95, 0.8), glow)
		draw_set_transform(Vector2(0, -7), 0.0, Vector2(1.0, breath))
		draw_circle(Vector2.ZERO, 9.0, Color(0.85, 0.82, 0.95, 0.18))   # contorno pálido (lê no escuro)
		draw_circle(Vector2.ZERO, 7.5, body)
		draw_circle(Vector2(3, -6), 4.6, body)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2(4.5, -13.5), 1.8, Color(0.92, 0.93, 0.96, 1.0 - glow * 0.5))
		if glow > 0.0:
			draw_circle(Vector2(0, -8), 16.0, Color(1, 0.95, 0.75, 0.25 * glow))
