extends Node
## Áudio do GNOSIS. Toca SFX/música/ambiência de assets/audio/ SE os arquivos
## existirem — silencioso e sem erro quando faltam. Autoload `Audio`.
## Lista completa e mixagem: docs/AUDIO.md. Pipeline: tools/audio_synth/.
##
## O que este autoload faz sozinho (sem ninguém chamar):
##   · música por CONTEXTO (menu / Rei / Éon / Arconte / Centro / Mente) ouvindo
##     RunManager.screen_changed e GameManager.state_changed, com crossfade;
##   · AMBIÊNCIA por Éon num player próprio (crossfade de 2,5 s), por baixo da música;
##   · DUCKING: abaixa música/ambiência enquanto houver DialogueBox ou Cinematic
##     (cards, card de chefe) na árvore — detectado por `node_added`, sem
##     ninguém precisar chamar nada. Quem quiser forçar: `Audio.duck(true/false)`;
##   · faísca, arma, Anel ganho, roubo e caco ouvindo os sinais de Progression.
## O resto do jogo só chama `Audio.play_sfx(nome)` / `Audio.play_music(faixa)`.
##
## VARIAÇÕES: se existirem `nome_2.ogg`, `nome_3.ogg`... ao lado de `nome.ogg`,
## `play_sfx(<nome>)` sorteia uma delas sem repetir a anterior. Nada muda pra
## quem chama. `spark` sobe a escala pentatônica quando coletada em sequência.
##
## BUSES: Master (limitador) ← Music, Ambience, SFX ← (UI, Voice).
## UI = ui_*/shop_*/subtitle_tick; Voice = blip_* (vozes "gromelô", monofônico:
## a sílaba nova corta a anterior, como uma boca).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMB_DIR := "res://assets/audio/amb/"
const POOL := 24                  # vozes simultâneas de SFX
const MUSIC_FADE := 1.2           # segundos de crossfade entre faixas
const AMB_FADE := 2.5             # crossfade entre ambiências
const SPAM_MS := 40               # mesmo som não repete em menos que isto
const SILENT_DB := -60.0
const MAX_VARIANTS := 6           # procura nome_2 .. nome_6
const SEQ_WINDOW_MS := 600        # faísca: coletas dentro disto sobem a escala
const DUCK_MUSIC_DB := -9.0       # quanto a música abaixa no diálogo/card
const DUCK_AMB_DB := -5.0
const DUCK_IN := 0.25
const DUCK_OUT := 0.8
const AMB_ARCHON_DB := -5.0       # ambiência do Éon mais baixa na luta de Arconte
const EON_TRACKS := ["torpor", "fome", "corrente", "silencio", "espelho", "praga", "coroa"]

## CATÁLOGO: todo nome de som que o jogo pode pedir. O AudioQA confere que cada
## um está documentado em docs/AUDIO.md e que não há arquivo órfão na pasta.
## (Variações `nome_N` não entram aqui — são achadas sozinhas.)
const CATALOG := {
	"sfx": [
		# --- Sophia: golpes ---
		"swing_light", "swing_heavy", "swing_air", "launcher", "dive",
		"hit", "hit_heavy",
		# --- Sophia: defesa / movimento ---
		"parry", "block", "dodge", "dodge_perfect", "jump", "land", "step", "rooted",
		"player_hurt", "player_die",
		# --- contrato da Animação (passos, roupa, pisada de chefe) ---
		"step_heavy", "cloth", "boss_step",
		# --- Sophia: magias (a Esfera inata + os 7 Anéis) ---
		"cast_solar", "cast_torpor", "cast_fome", "cast_corrente", "cast_silencio",
		"cast_espelho", "cast_praga", "cast_coroa", "cast_fail",
		# --- inimigos / chefes ---
		"enemy_hurt", "enemy_die", "elite_die", "champion_die",
		"boss_appear", "boss_phase2", "boss_die", "revive", "form_revive",
		# --- projéteis / área / pedaços ---
		"proj_fire", "proj_hit", "nova", "gib_bounce",
		# --- objetos da tela ---
		"chest_hit", "chest_open", "sleeper_wake",
		"seal_right", "seal_wrong", "seal_solved",
		"portal_open", "portal_enter",
		# --- estrutura do run ---
		"zone_lock", "zone_clear", "level_clear",
		"spark", "weapon_upgrade", "ring_gain", "ring_steal", "shard",
		"stele_open", "stele_unlock", "subtitle_tick",
		# --- loja / interface ---
		"shop_buy", "shop_fail", "ui_click", "ui_move", "ui_advance", "ui_choice",
		"ui_confirm", "ui_back", "ui_open",
		# --- vozes "gromelô" (a UI chama por caractere/sílaba) ---
		"blip_voz", "blip_rei", "blip_sophia", "blip_estela", "blip_npc",
		# --- roteiro: "o Rei sai da névoa" (tela 1) ---
		"fog_swell", "king_step", "mask_light", "voice_merge", "whisper",
	],
	"music": [
		"theme", "rei",
		"eon_torpor", "eon_fome", "eon_corrente", "eon_silencio", "eon_espelho", "eon_praga", "eon_coroa",
		"boss", "roubo", "centro", "mente", "epilogo",
	],
	"amb": [
		"amb_torpor", "amb_fome", "amb_corrente", "amb_silencio", "amb_espelho", "amb_praga", "amb_coroa",
		"amb_limiar", "amb_centro",
	],
}

## Nomes antigos ainda usados por scripts de outros donos → nome do catálogo.
const ALIASES := {
	"ui": "ui_click",
	"cast": "cast_solar",
	"stela": "stele_open",       # narrativa (Estelas)
	"caption": "subtitle_tick",  # legendas de caminhada
}

## Variação de tom por família de som (verificadas em ordem; resto ±4 %).
const PITCH_FAMILIES := {
	0.08: ["swing_", "hit", "step", "gib_", "enemy_hurt", "enemy_die", "proj_", "dodge", "land", "jump", "cloth"],
	0.05: ["boss_step", "king_step"],
	0.03: ["blip_"],
	0.0: ["ui_", "shop_", "subtitle_", "stele_", "ring_", "shard", "spark", "weapon_", "boss_", "zone_", "level_", "portal_", "cast_"],
}

## Sons tocados em sequência (sobem as variações em ordem em vez de sortear).
const SEQUENTIAL := ["spark"]

## Falante do diálogo → voz "gromelô".
const SPEAKER_BLIPS := {
	"Sophia": "blip_sophia",
	"O Rei": "blip_rei", "Yaldabaoth": "blip_rei",
	"Athoth": "blip_rei", "Harmas": "blip_rei", "Galila": "blip_rei", "Yabel": "blip_rei",
	"Astaphaios": "blip_rei", "Belias": "blip_rei", "Armupiel": "blip_rei",
	"A Voz": "blip_voz", "Soter": "blip_voz", "???": "blip_voz",
	"Estela": "blip_estela",
}

# Volume padrão da 1ª execução (sem save): moderado (pedido do João).
var master_vol: float = 0.7
var sfx_vol: float = 0.9
var music_vol: float = 0.6

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _voice: AudioStreamPlayer        # blips: monofônico
var _cache: Dictionary = {}          # caminho base -> AudioStream ou null (cache negativa)
var _variants: Dictionary = {}       # nome -> Array de streams (nome, nome_2, ...)
var _last_variant: Dictionary = {}   # nome -> índice tocado por último
var _last_play_ms: Dictionary = {}   # nome -> msec do último disparo (anti-spam)

# --- música (dois players: A toca, B entra por cima com fade) ---
var _music: Array[AudioStreamPlayer] = []
var _music_cur: int = 0
var _music_tween: Tween
var current_track: String = ""       # última faixa PEDIDA (mesmo sem arquivo)
var _playing_track: String = ""      # faixa que realmente está tocando

# --- ambiência (dois players, crossfade próprio) ---
var _amb: Array[AudioStreamPlayer] = []
var _amb_cur: int = 0
var _amb_tween: Tween
var current_ambience: String = ""    # última ambiência PEDIDA
var _amb_db: float = 0.0             # volume-alvo da ambiência atual

# --- ducking ---
var _duck_holders: Dictionary = {}   # instance_id -> true (diálogos/cards vivos)
var _manual_duck: int = 0
var _duck: float = 0.0               # 0 = normal, 1 = abaixado (tweenado)
var _duck_target: float = 0.0
var _temp_duck_db: float = 0.0       # duck_music(): abaixada temporária (tweenada)
var _temp_duck_tween: Tween
var _layer_db: Dictionary = {}       # faixa -> dB extra (set_music_layer_volume)
var _music_pitch: float = 1.0
var _pitch_tween: Tween
var _duck_tween: Tween

# --- memória pros ganchos por sinal ---
var _last_orbs: int = 0
var _last_weapon: int = 1
var _last_rings: int = 0
var _last_restored: int = 0
var _last_stolen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # a música não para na pausa
	_ensure_bus("Music", "Master")
	_ensure_bus("Ambience", "Master")
	_ensure_bus("SFX", "Master")
	_ensure_bus("UI", "SFX")
	_ensure_bus("Voice", "SFX")
	_ensure_limiter()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = SILENT_DB
		add_child(m)
		_music.append(m)
		var a := AudioStreamPlayer.new()
		a.bus = "Ambience"
		a.volume_db = SILENT_DB
		add_child(a)
		_amb.append(a)
	_apply_volumes()
	get_tree().node_added.connect(_on_node_added)
	# Os outros autoloads ainda não existem neste _ready (ordem do project.godot).
	_connect_context.call_deferred()


func _ensure_bus(bus_name: String, send: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)


## Limitador no Master: nada passa de -0,5 dBFS quando muitos sons somam.
func _ensure_limiter() -> void:
	var master := AudioServer.get_bus_index("Master")
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	lim.pre_gain_db = 0.0
	lim.release = 0.12
	AudioServer.add_bus_effect(master, lim)


# --- SFX ---------------------------------------------------------------

## Toca um efeito. `pitch_var` < 0 = variação automática pela família do som.
func play_sfx(sfx_name: String, pitch_var: float = -1.0, volume_db: float = 0.0) -> void:
	var real_name: String = ALIASES.get(sfx_name, sfx_name)
	if variants_of(real_name).is_empty():
		return
	var now := Time.get_ticks_msec()
	var last_ms := int(_last_play_ms.get(real_name, -SEQ_WINDOW_MS))
	if now - last_ms < SPAM_MS:
		return
	var stream = _pick_variant(real_name, now - last_ms < SEQ_WINDOW_MS)
	_last_play_ms[real_name] = now
	if pitch_var < 0.0:
		pitch_var = _pitch_for(real_name)
	var p: AudioStreamPlayer
	if real_name.begins_with("blip_"):
		p = _voice                    # voz: a sílaba nova corta a anterior
	else:
		p = _players[_next]
		_next = (_next + 1) % _players.size()
		p.bus = _bus_for(real_name)
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db
	p.play()


## Toca um efeito posicionado: atenua pela distância horizontal até a câmera
## (até -18 dB); sem câmera, toca normal.
func play_sfx_at(sfx_name: String, pos: Vector2, pitch_var: float = -1.0) -> void:
	var att := 0.0
	var cam := get_viewport().get_camera_2d() if get_viewport() != null else null
	if cam != null:
		var d := absf(pos.x - cam.get_screen_center_position().x)
		att = -clampf((d - 380.0) / 40.0, 0.0, 18.0)
	play_sfx(sfx_name, pitch_var, att)


## Voz "gromelô" do falante (a UI chama a cada caractere/sílaba).
func play_blip(speaker: String) -> void:
	play_sfx(blip_for_speaker(speaker))


func blip_for_speaker(speaker: String) -> String:
	return String(SPEAKER_BLIPS.get(speaker, "blip_npc"))


func _bus_for(sfx_name: String) -> String:
	if sfx_name.begins_with("ui_") or sfx_name.begins_with("shop_") or sfx_name == "subtitle_tick":
		return "UI"
	return "SFX"


func _pitch_for(sfx_name: String) -> float:
	for amount in PITCH_FAMILIES:
		for prefix in PITCH_FAMILIES[amount]:
			if sfx_name.begins_with(prefix):
				return float(amount)
	return 0.04


## Lista de streams do som: [nome, nome_2, nome_3 ...] (só os que existem).
func variants_of(sfx_name: String) -> Array:
	if _variants.has(sfx_name):
		return _variants[sfx_name]
	var list: Array = []
	var base = _load(SFX_DIR + sfx_name)
	if base != null:
		list.append(base)
		for i in range(2, MAX_VARIANTS + 1):
			var v = _load(SFX_DIR + "%s_%d" % [sfx_name, i])
			if v == null:
				break
			list.append(v)
	_variants[sfx_name] = list
	return list


## Escolhe a variação: sorteio sem repetir a anterior. Sons SEQUENTIAL sobem a
## fila enquanto `recent` (tocados em sequência) e voltam ao 1º após pausa.
func _pick_variant(sfx_name: String, recent: bool):
	var list := variants_of(sfx_name)
	if list.is_empty():
		return null
	if list.size() == 1:
		return list[0]
	var last: int = int(_last_variant.get(sfx_name, -1))
	var i: int
	if SEQUENTIAL.has(sfx_name):
		if not recent:
			i = 0
		elif last >= list.size() - 1:
			i = list.size() - 1 - randi() % 2     # no topo: alterna as duas mais agudas
		else:
			i = last + 1
	else:
		i = randi() % (list.size() - 1)
		if last >= 0 and i >= last:
			i += 1
	_last_variant[sfx_name] = i
	return list[i]


# --- Música ------------------------------------------------------------

## Troca a faixa com crossfade. Idempotente: pedir a faixa que já toca não faz
## nada. Se o arquivo não existir, a faixa ANTERIOR continua (nunca silêncio
## abrupto por falta de arquivo).
func play_music(track_name: String, loop: bool = true, pitch: float = 1.0) -> void:
	current_track = track_name
	if track_name == _playing_track and _music[_music_cur].playing:
		if not is_equal_approx(pitch, _music_pitch):
			set_music_pitch(pitch, 0.0)
		return
	var stream = _load(MUSIC_DIR + track_name)
	if stream == null:
		return
	_set_loop(stream, loop)
	var old := _music[_music_cur]
	_music_cur = (_music_cur + 1) % 2
	var new := _music[_music_cur]
	new.stream = stream
	new.volume_db = SILENT_DB
	_music_pitch = maxf(pitch, 0.05)
	new.pitch_scale = _music_pitch
	new.play()
	_playing_track = track_name
	_apply_volumes()                  # camada (dB) da faixa nova
	_crossfade(old, new)


## Muda o tom/velocidade da música (1 = normal; 0,8 = mais grave e lenta).
## `fade` em segundos (0 = na hora). Vale pra faixa atual e as seguintes até
## alguém mudar de novo.
func set_music_pitch(pitch: float, fade: float = 1.0) -> void:
	_music_pitch = maxf(pitch, 0.05)
	if _pitch_tween != null and _pitch_tween.is_valid():
		_pitch_tween.kill()
	if fade <= 0.0:
		for m in _music:
			m.pitch_scale = _music_pitch
		return
	_pitch_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	for m in _music:
		_pitch_tween.tween_property(m, "pitch_scale", _music_pitch, fade)


## Abaixa a música por `seconds` (em `db`) e volta sozinha com fade —
## pra uma fala ou um golpe de cena. Soma com o ducking de diálogo.
func duck_music(seconds: float, db: float = -12.0) -> void:
	if _temp_duck_tween != null and _temp_duck_tween.is_valid():
		_temp_duck_tween.kill()
	_temp_duck_tween = create_tween().set_ignore_time_scale(true)
	_temp_duck_tween.tween_method(_set_temp_duck, _temp_duck_db, db, DUCK_IN)
	_temp_duck_tween.tween_interval(maxf(seconds, 0.0))
	_temp_duck_tween.tween_method(_set_temp_duck, db, 0.0, DUCK_OUT)


func _set_temp_duck(v: float) -> void:
	_temp_duck_db = v
	_apply_volumes()


## Volume da "camada" da faixa ATUAL, 0..1 (0 = −18 dB, 1 = normal). Ex.: o
## Centro sobe conforme os cacos voltam. Fica guardado por faixa (trocar de
## faixa e voltar mantém o nível). `track` vazio = faixa que está tocando.
func set_music_layer_volume(t: float, track: String = "") -> void:
	var key := track if track != "" else current_track
	_layer_db[key] = lerpf(-18.0, 0.0, clampf(t, 0.0, 1.0))
	_apply_volumes()


## Silencia a música com fade (0 = corta na hora).
func stop_music(fade: float = MUSIC_FADE) -> void:
	current_track = ""
	_playing_track = ""
	_kill_tween()
	for m in _music:
		if not m.playing:
			continue
		if fade <= 0.0:
			m.stop()
		else:
			_music_tween = create_tween().set_ignore_time_scale(true)
			_music_tween.tween_property(m, "volume_db", SILENT_DB, fade)
			_music_tween.tween_callback(m.stop)


func _crossfade(old: AudioStreamPlayer, new: AudioStreamPlayer) -> void:
	_kill_tween()
	_music_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_music_tween.tween_property(new, "volume_db", 0.0, MUSIC_FADE).from(SILENT_DB)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", SILENT_DB, MUSIC_FADE)
		_music_tween.chain().tween_callback(old.stop)


func _kill_tween() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func _set_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED


# --- Ambiência -----------------------------------------------------------

## Toca a ambiência (`"torpor"` ou `"amb_torpor"`) em loop, com crossfade.
## `volume_db` = nível relativo (ex.: -5 na luta de Arconte). "" = para.
func play_ambience(amb_name: String, volume_db: float = 0.0) -> void:
	if amb_name == "":
		stop_ambience()
		return
	if not amb_name.begins_with("amb_"):
		amb_name = "amb_" + amb_name
	var cur := _amb[_amb_cur]
	if amb_name == current_ambience and cur.playing:
		if not is_equal_approx(volume_db, _amb_db):
			_amb_db = volume_db
			_kill_amb_tween()
			_amb_tween = create_tween().set_ignore_time_scale(true)
			_amb_tween.tween_property(cur, "volume_db", volume_db, AMB_FADE)
		return
	current_ambience = amb_name
	_amb_db = volume_db
	var stream = _load(AMB_DIR + amb_name)
	if stream == null:
		return
	_set_loop(stream, true)
	var old := cur
	_amb_cur = (_amb_cur + 1) % 2
	var new := _amb[_amb_cur]
	new.stream = stream
	new.volume_db = SILENT_DB
	# começa num ponto aleatório: duas telas do mesmo Éon não soam idênticas
	new.play(randf() * maxf(stream.get_length() - 1.0, 0.0))
	_kill_amb_tween()
	_amb_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_amb_tween.tween_property(new, "volume_db", volume_db, AMB_FADE).from(SILENT_DB)
	if old.playing:
		_amb_tween.tween_property(old, "volume_db", SILENT_DB, AMB_FADE)
		_amb_tween.chain().tween_callback(old.stop)


func stop_ambience(fade: float = AMB_FADE) -> void:
	current_ambience = ""
	_kill_amb_tween()
	for a in _amb:
		if not a.playing:
			continue
		if fade <= 0.0:
			a.stop()
		else:
			_amb_tween = create_tween().set_ignore_time_scale(true)
			_amb_tween.tween_property(a, "volume_db", SILENT_DB, fade)
			_amb_tween.tween_callback(a.stop)


func _kill_amb_tween() -> void:
	if _amb_tween != null and _amb_tween.is_valid():
		_amb_tween.kill()
	_amb_tween = null


## Ambiência certa pra uma tela do run ("" = nenhuma).
func ambience_for_screen(screen: int) -> String:
	if RunManager.is_final(screen):
		return ""
	if RunManager.is_center(screen):
		return "amb_centro"
	if RunManager.is_king_screen(screen):
		return "amb_limiar"
	return "amb_" + EON_TRACKS[clampi(RunManager.eon_index(screen), 0, EON_TRACKS.size() - 1)]


func _update_ambience(screen: int) -> void:
	var vol := AMB_ARCHON_DB if RunManager.is_archon_screen(screen) else 0.0
	play_ambience(ambience_for_screen(screen), vol)


# --- Ducking (diálogo / cards) -------------------------------------------

## Abaixa (true) ou devolve (false) música e ambiência. Contado: cada `true`
## precisa de um `false`. Diálogos e cards já fazem isso sozinhos.
func duck(on: bool) -> void:
	_manual_duck = maxi(0, _manual_duck + (1 if on else -1))
	_update_duck()


func is_ducked() -> bool:
	return _manual_duck > 0 or not _duck_holders.is_empty()


func _on_node_added(node: Node) -> void:
	if node is DialogueBox or node is Cinematic:
		var id := node.get_instance_id()
		_duck_holders[id] = true
		node.tree_exiting.connect(_on_duck_holder_gone.bind(id), CONNECT_ONE_SHOT)
		_update_duck()


func _on_duck_holder_gone(id: int) -> void:
	_duck_holders.erase(id)
	_update_duck()


func _update_duck() -> void:
	var target := 1.0 if is_ducked() else 0.0
	if is_equal_approx(target, _duck_target):
		return
	_duck_target = target
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween().set_ignore_time_scale(true)
	_duck_tween.tween_method(_set_duck, _duck, target, DUCK_IN if target > 0.5 else DUCK_OUT)


func _set_duck(v: float) -> void:
	_duck = v
	_apply_volumes()


# --- Música por contexto ----------------------------------------------

func _connect_context() -> void:
	var rm := get_node_or_null("/root/RunManager")
	if rm != null and not rm.screen_changed.is_connected(_on_screen_changed):
		rm.screen_changed.connect(_on_screen_changed)
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and not gm.state_changed.is_connected(_on_state_changed):
		gm.state_changed.connect(_on_state_changed)
		_on_state_changed(gm.state)
	var pr := get_node_or_null("/root/Progression")
	if pr != null and not pr.orbs_changed.is_connected(_on_orbs):
		_last_orbs = pr.orbs
		_last_weapon = pr.weapon_level
		_last_rings = pr.rings.size()
		_last_restored = pr.restored_rings.size()
		_last_stolen = pr.rings_stolen
		pr.orbs_changed.connect(_on_orbs)
		pr.weapon_level_changed.connect(_on_weapon)
		pr.rings_changed.connect(_on_rings)


## Faixa certa pra uma tela do run (só pela ESTRUTURA — nunca número fixo).
func track_for_screen(screen: int) -> String:
	if RunManager.is_final(screen):
		return "mente"
	if RunManager.is_center(screen):
		return "centro"
	if RunManager.is_king_screen(screen):
		return "rei"
	if RunManager.is_archon_screen(screen):
		return "boss"
	return "eon_" + EON_TRACKS[clampi(RunManager.eon_index(screen), 0, EON_TRACKS.size() - 1)]


func _on_screen_changed(screen: int) -> void:
	if RunManager.run_active:
		play_music(track_for_screen(screen))
		_update_ambience(screen)


func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.MENU:
			play_music("theme")
			stop_ambience()
		GameManager.State.PLAYING:
			if RunManager.run_active:
				play_music(track_for_screen(RunManager.current_screen))
				_update_ambience(RunManager.current_screen)
			elif CodexSession.active:
				# Provação: dois encontros no clima do Éon, o terceiro é chefe.
				play_music("boss" if CodexSession.stage >= 2 else "eon_torpor")
				play_ambience("amb_torpor", AMB_ARCHON_DB if CodexSession.stage >= 2 else 0.0)


# --- Ganchos por sinal (Progression) ------------------------------------

func _in_game() -> bool:
	# Fora do jogo (menu, restauração do save) os sinais disparam sem evento real.
	return GameManager.state == GameManager.State.PLAYING or GameManager.state == GameManager.State.UPGRADE


func _on_orbs(total: int) -> void:
	var delta := total - _last_orbs
	_last_orbs = total
	if _in_game() and delta > 0 and delta <= 40:
		play_sfx("spark")


func _on_weapon(level: int) -> void:
	var grew := level > _last_weapon
	_last_weapon = level
	if _in_game() and grew:
		play_sfx("weapon_upgrade")


func _on_rings() -> void:
	var rings: int = Progression.rings.size()
	var restored: int = Progression.restored_rings.size()
	var stolen: bool = Progression.rings_stolen
	if _in_game():
		if stolen and not _last_stolen:
			play_sfx("ring_steal")
		elif restored > _last_restored:
			play_sfx("shard")
		elif rings > _last_rings:
			play_sfx("ring_gain")
	_last_rings = rings
	_last_restored = restored
	_last_stolen = stolen


# --- Volumes -------------------------------------------------------------

## Sliders das Opções: "Master", "SFX", "Music" (a ambiência segue a música;
## UI e Voz seguem o SFX).
func set_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	match bus_name:
		"Master": master_vol = linear
		"SFX": sfx_vol = linear
		"Music": music_vol = linear
	_apply_volumes()


func _apply_volumes() -> void:
	_set_bus("Master", master_vol, 0.0)
	_set_bus("SFX", sfx_vol, 0.0)
	var layer: float = float(_layer_db.get(_playing_track, 0.0))
	_set_bus("Music", music_vol, DUCK_MUSIC_DB * _duck + _temp_duck_db + layer)
	_set_bus("Ambience", music_vol, DUCK_AMB_DB * _duck)


func _set_bus(bus_name: String, linear: float, extra_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)) + extra_db)
		AudioServer.set_bus_mute(idx, linear <= 0.001)


# --- Carga com cache negativa ------------------------------------------

func _load(base: String):
	if _cache.has(base):
		return _cache[base]
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(base + ext):
			var s = load(base + ext)
			_cache[base] = s
			return s
	_cache[base] = null
	return null


## Existe arquivo pra este som? (usado pelo AudioQA e por quem quiser checar)
func has_sfx(sfx_name: String) -> bool:
	return _load(SFX_DIR + ALIASES.get(sfx_name, sfx_name)) != null


func has_music(track_name: String) -> bool:
	return _load(MUSIC_DIR + track_name) != null


func has_ambience(amb_name: String) -> bool:
	if not amb_name.begins_with("amb_"):
		amb_name = "amb_" + amb_name
	return _load(AMB_DIR + amb_name) != null
