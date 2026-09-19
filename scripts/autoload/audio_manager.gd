extends Node
## Áudio do GNOSIS. Toca SFX/música de assets/audio/ SE os arquivos existirem —
## silencioso e sem erro enquanto os sons ainda não foram gerados. Autoload `Audio`.
## Basta soltar os .ogg na pasta com os nomes do CATALOG (lista em docs/AUDIO.md).
##
## O que este autoload faz sozinho (sem ninguém chamar):
##   · música por CONTEXTO (menu / Rei / Éon / Arconte / Centro / Mente) ouvindo
##     RunManager.screen_changed e GameManager.state_changed, com crossfade;
##   · faísca, arma, Anel ganho, roubo e caco ouvindo os sinais de Progression.
## O resto do jogo só chama `Audio.play_sfx(nome)` / `Audio.play_music(faixa)`.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 16                  # vozes simultâneas de SFX
const MUSIC_FADE := 1.2           # segundos de crossfade entre faixas
const SPAM_MS := 40               # mesmo som não repete em menos que isto
const SILENT_DB := -60.0
const EON_TRACKS := ["torpor", "fome", "corrente", "silencio", "espelho", "praga", "coroa"]

## CATÁLOGO: todo nome de som que o jogo pode pedir. O AudioQA confere que cada
## um está documentado em docs/AUDIO.md e que não há arquivo órfão na pasta.
const CATALOG := {
	"sfx": [
		# --- Sophia: golpes ---
		"swing_light", "swing_heavy", "swing_air", "launcher", "dive",
		"hit", "hit_heavy",
		# --- Sophia: defesa / movimento ---
		"parry", "block", "dodge", "dodge_perfect", "jump", "land", "step", "rooted",
		"player_hurt", "player_die",
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
		"ui_confirm", "ui_back",
	],
	"music": [
		"theme", "rei",
		"eon_torpor", "eon_fome", "eon_corrente", "eon_silencio", "eon_espelho", "eon_praga", "eon_coroa",
		"boss", "roubo", "centro", "mente", "epilogo",
	],
}

## Nomes antigos ainda usados por scripts de outros donos → nome do catálogo.
const ALIASES := {
	"ui": "ui_click",
	"cast": "cast_solar",
	"stela": "stele_open",       # narrativa (Estelas)
	"caption": "subtitle_tick",  # legendas de caminhada
}

## Variação de tom por família de som (golpes ±8 %, UI 0, resto ±4 %).
const PITCH_FAMILIES := {
	0.08: ["swing_", "hit", "step", "gib_", "enemy_hurt", "enemy_die", "proj_", "dodge", "land", "jump"],
	0.0: ["ui_", "shop_", "subtitle_", "stele_", "ring_", "shard", "weapon_", "boss_", "zone_", "level_", "portal_"],
}

var master_vol: float = 0.9
var sfx_vol: float = 0.9
var music_vol: float = 0.7

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}          # caminho base -> AudioStream ou null (cache negativa)
var _last_play_ms: Dictionary = {}   # nome -> msec do último disparo (anti-spam)

# --- música (dois players: A toca, B entra por cima com fade) ---
var _music: Array[AudioStreamPlayer] = []
var _music_cur: int = 0
var _music_tween: Tween
var current_track: String = ""       # última faixa PEDIDA (mesmo sem arquivo)
var _playing_track: String = ""      # faixa que realmente está tocando

# --- memória pros ganchos por sinal ---
var _last_orbs: int = 0
var _last_weapon: int = 1
var _last_rings: int = 0
var _last_restored: int = 0
var _last_stolen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # a música não para na pausa
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = SILENT_DB
		add_child(m)
		_music.append(m)
	_apply_volumes()
	# Os outros autoloads ainda não existem neste _ready (ordem do project.godot).
	_connect_context.call_deferred()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


# --- SFX ---------------------------------------------------------------

## Toca um efeito. `pitch_var` < 0 = variação automática pela família do som.
func play_sfx(sfx_name: String, pitch_var: float = -1.0, volume_db: float = 0.0) -> void:
	var real_name: String = ALIASES.get(sfx_name, sfx_name)
	var stream = _load(SFX_DIR + real_name)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play_ms.get(real_name, -SPAM_MS)) < SPAM_MS:
		return
	_last_play_ms[real_name] = now
	if pitch_var < 0.0:
		pitch_var = _pitch_for(real_name)
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
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


func _pitch_for(sfx_name: String) -> float:
	for amount in PITCH_FAMILIES:
		for prefix in PITCH_FAMILIES[amount]:
			if sfx_name.begins_with(prefix):
				return float(amount)
	return 0.04


# --- Música ------------------------------------------------------------

## Troca a faixa com crossfade. Idempotente: pedir a faixa que já toca não faz
## nada. Se o arquivo não existir, a faixa ANTERIOR continua (nunca silêncio
## abrupto por falta de arquivo).
func play_music(track_name: String, loop: bool = true) -> void:
	current_track = track_name
	if track_name == _playing_track and _music[_music_cur].playing:
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
	new.play()
	_playing_track = track_name
	_crossfade(old, new)


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
			_music_tween = create_tween()
			_music_tween.tween_property(m, "volume_db", SILENT_DB, fade)
			_music_tween.tween_callback(m.stop)


func _crossfade(old: AudioStreamPlayer, new: AudioStreamPlayer) -> void:
	_kill_tween()
	_music_tween = create_tween().set_parallel(true)
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


func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.MENU:
			play_music("theme")
		GameManager.State.PLAYING:
			if RunManager.run_active:
				play_music(track_for_screen(RunManager.current_screen))
			elif CodexSession.active:
				# Provação: dois encontros no clima do Éon, o terceiro é chefe.
				play_music("boss" if CodexSession.stage >= 2 else "eon_torpor")


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

func set_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	match bus_name:
		"Master": master_vol = linear
		"SFX": sfx_vol = linear
		"Music": music_vol = linear
	_apply_volumes()


func _apply_volumes() -> void:
	_set_bus("Master", master_vol)
	_set_bus("SFX", sfx_vol)
	_set_bus("Music", music_vol)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
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
