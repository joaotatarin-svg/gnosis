extends Node
## Áudio do GNOSIS. Toca SFX/música de assets/audio/ SE os arquivos existirem —
## silencioso e sem erro enquanto você ainda não gerou os sons. Autoload `Audio`.
## Basta soltar os .ogg/.wav na pasta (nomes na lista do README de áudio).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 10

var master_vol: float = 0.9
var sfx_vol: float = 0.9
var music_vol: float = 0.7

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer
var _cache: Dictionary = {}


func _ready() -> void:
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func play_sfx(sfx_name: String, pitch_var: float = 0.08) -> void:
	var stream = _load(SFX_DIR + sfx_name)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func play_music(track_name: String) -> void:
	var stream = _load(MUSIC_DIR + track_name)
	if stream == null:
		return
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


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
