extends Node
## Áudio do GNOSIS. Toca SFX/música/ambiência de assets/audio/ SE os arquivos
## existirem — silencioso e sem erro quando faltam. Autoload `Audio`.
## Lista completa e mixagem: docs/AUDIO.md. Pipeline: tools/audio_synth/.
##
## O que este autoload faz sozinho (sem ninguém chamar):
##   · música por CONTEXTO (menu / Rei / Éon / Arconte / Centro / Mente / Provação)
##     ouvindo RunManager.screen_changed e GameManager.state_changed, com crossfade;
##   · AMBIÊNCIA por Éon num player próprio (crossfade de 2,5 s), por baixo da música;
##   · DUCKING: abaixa música/ambiência enquanto houver DialogueBox ou Cinematic
##     (cards, card de chefe) na árvore — detectado por `node_added`, sem
##     ninguém precisar chamar nada. Quem quiser forçar: `Audio.duck(true/false)`;
##   · CENTRO: a faixa `centro` só entra no 1º caco de memória devolvido e sobe
##     um degrau por caco (ROTEIRO §2, cena C: "memória = música");
##   · SLOW-MO: se o Juice tiver o sinal `slowmo_changed(active, scale)`, abafa
##     SFX/música/ambiência (passa-baixas) e abaixa a música 4 dB (R8);
##   · arma, Anel ganho, roubo e caco ouvindo os sinais de Progression. (A faísca
##     NÃO toca mais no crédito: toca na CHEGADA de cada orbe, quem chama é o orbe.)
## O resto do jogo só chama `Audio.play_sfx(nome)` / `Audio.play_music(faixa)`.
##
## VARIAÇÕES: se existirem `nome_2.ogg`, `nome_3.ogg`... ao lado de `nome.ogg`,
## `play_sfx(<nome>)` sorteia uma delas sem repetir a anterior (round-robin).
## `spark` sobe a escala pentatônica quando coletada em sequência.
## VOZES: no máximo MAX_SAME instâncias do mesmo som ao mesmo tempo (rouba a mais
## velha); o pool usa primeiro um player livre e só então rouba o mais antigo.
## ESTÉREO: `play_sfx(nome, -1, 0, posição_no_mundo)` ou `play_sfx_at` dão um pan
## discreto pelo x NA TELA (no máximo 50 % para um lado). Sem posição = centro.
##
## BUSES: Master (limitador) ← Music, Ambience, SFX ← (UI, Voice, SFX_L2/L1/R1/R2).
## UI = ui_*/shop_*/subtitle_tick; Voice = blip_* (vozes "gromelô", monofônico:
## a sílaba nova corta a anterior, como uma boca). SFX_Lx/Rx = pan fixo.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const AMB_DIR := "res://assets/audio/amb/"
const POOL := 24                  # vozes simultâneas de SFX
const MAX_SAME := 3               # instâncias simultâneas do MESMO som (R11)
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
const LIMITER_CEILING_DB := -1.0  # teto do Master (R11: ≤ −1 dBTP)
const EON_MUSIC_DB := -3.0        # música de Éon ~3 LU abaixo da de chefe (R13)
const CENTER_SHARDS := 6          # cacos de memória no Centro (6 ecos; o 7º Anel volta na Mente)
const LAYER_RATE_DB := 6.0        # dB/s com que a "camada" de uma faixa muda (sem degrau)
# Slow-mo (R8): passa-baixas 20 kHz → 1,5 kHz em 60 ms, volta em 250 ms; música −4 dB.
const SLOW_OPEN_HZ := 20000.0
const SLOW_CUT_HZ := 1500.0
const SLOW_DODGE_HZ := 2500.0     # esquiva perfeita (scale ≈ 0,3): abafa menos
const SLOW_IN := 0.06
const SLOW_OUT := 0.25
const SLOW_MUSIC_DB := -4.0
const SLOW_BUSES := ["SFX", "Music", "Ambience"]
# Estéreo discreto (R14): pan = clamp((x_tela − meio) / meia_largura, −1, 1) × 0,5,
# quantizado em 5 posições (buses com AudioEffectPanner fixo).
const PAN_MAX := 0.5
const PAN_BUSES := {-2: "SFX_L2", -1: "SFX_L1", 1: "SFX_R1", 2: "SFX_R2"}
const NO_POS := Vector2(INF, INF)
const EON_TRACKS := ["torpor", "fome", "corrente", "silencio", "espelho", "praga", "coroa"]
# Tema da Voz (ROTEIRO §5 #8): `theme` é a música DELA. Santuário = baixo, por
# baixo da conversa; roubo = distorcido 3 s e corta; anagnórise = volta sozinho.
const VOICE_THEME := "theme"
const VOICE_SANCTUARY_DB := -3.0  # + o ducking normal do diálogo (−9) = −12 dB
const VOICE_STOLEN_PITCH := 0.75  # roubo: tema 5 semitons abaixo e mais lento…
const VOICE_STOLEN_SECS := 3.0    # …por 3 s → corte seco → `roubo`
const VOICE_ALONE_PITCH := 0.9    # anagnórise: o tema volta sozinho, mais lento
const VOICE_ALONE_FADE := 4.0
const SCENE_FADE := 2.0           # entrada/saída do tema no santuário
const SCENE_DUCK_SCALE := 0.35    # roubo/anagnórise: a música É a cena — diálogo abaixa só ~3 dB
const FOG_DUCK_DB := -8.0         # cena A: "a música do Limiar desce a 40 %"
## Faixas opcionais: tocam se o arquivo existir, sem ele o jogo usa a reserva.
## `menu` = tema do menu (opções por síntese aguardando o João; sem arquivo = `theme`).
const OPTIONAL_MUSIC := ["menu"]
## Todos os `cue` das falas (ROTEIRO §5) que `cue()` conhece. `wait_2s` é da UI
## (só é reconhecido, sem som). Ver `cue()`.
const CUES := ["heartbeat", "fog_thickens", "king_emerges", "mask_lights", "mask_cracks", "king_sinks",
	"wait_2s", "chime", "music_stop", "voice_merge", "rings_fly", "mask_falls", "sink",
	"rings_return", "flash", "colossus_shrinks", "theme_alone", "reclaim"]

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
		# --- roteiro: intro, roubo e anagnórise (ROTEIRO §2, sons ★) ---
		"heartbeat", "clap", "child_breath",
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
## Com 3 variações por som, impacto não precisa de ±8 %: ±4 % (≈ ±0,7 semitom);
## passos/corpo ±6 % (R11).
const PITCH_FAMILIES := {
	0.04: ["swing_", "hit", "enemy_hurt", "enemy_die", "proj_", "block"],
	0.06: ["step", "land", "jump", "cloth", "dodge", "gib_"],
	0.05: ["boss_step", "king_step"],
	0.03: ["blip_"],
	0.0: ["ui_", "shop_", "subtitle_", "stele_", "ring_", "shard", "spark", "weapon_", "boss_", "zone_", "level_", "portal_", "cast_"],
}

## Sons frequentes que ganham ±1,5 dB de volume aleatório (R11: "não enjoa").
const VOLUME_JITTER_DB := 1.5
const JITTER_FAMILIES := ["swing_", "hit", "step", "enemy_hurt", "land", "block", "cloth", "boss_step", "king_step"]

## Sons tocados em sequência (sobem as variações em ordem em vez de sortear).
const SEQUENTIAL := ["spark"]

## Anti-spam próprio (ms): o arpejo das faíscas chega com 40–70 ms entre orbes.
const SPAM_OVERRIDE := {"spark": 20}

## Vozes simultâneas próprias: o arpejo precisa deixar as caudas soarem.
const MAX_SAME_OVERRIDE := {"spark": 6}

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
var _pl_name: Array[String] = []     # som que cada player do pool tocou por último
var _pl_start: Array[int] = []       # quando (ms) — pra roubar a voz mais velha
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

# --- envelopes por tempo REAL (ducking, slow-mo, camada) — ver _process ---
var _duck_holders: Dictionary = {}   # instance_id -> true (diálogos/cards vivos)
var _manual_duck: int = 0
var _duck: float = 0.0               # 0 = normal, 1 = abaixado
var _duck_target: float = 0.0
var _duck_env := Vector3.ZERO        # (valor de partida, duração s, —) do fade atual
var _duck_t0: int = 0                # µs em que o fade atual foi PEDIDO
var _slow: float = 0.0               # 0 = aberto, 1 = abafado
var _slow_target: float = 0.0
var _slow_env := Vector3.ZERO
var _slow_t0: int = 0
var _slow_hz: float = SLOW_CUT_HZ
var _lp_filters: Array[AudioEffectLowPassFilter] = []
var _lp_slots: Array[Vector2i] = []  # (bus, índice do efeito) de cada filtro
var _layer_db: Dictionary = {}       # faixa -> dB extra pedido (set_music_layer_volume)
var _layer_now: float = 0.0          # dB extra aplicado agora (anda até o pedido)
var _env_us: int = 0                 # relógio da camada (µs)
var _temp_duck_db: float = 0.0       # duck_music(): abaixada temporária (tweenada)
var _temp_duck_tween: Tween
var _music_pitch: float = 1.0
var _pitch_tween: Tween
var _shut_down: bool = false

# --- tema da Voz / cenas ---
var voice_theme_mode: String = ""    # "", "santuario", "roubo", "sozinha"
var _scene_token: int = 0            # invalida o corte agendado do roubo
var _duck_scale: float = 1.0         # 1 = ducking de diálogo cheio; menor nas cenas musicais

# --- memória pros ganchos por sinal ---
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
	for k in PAN_BUSES:
		_ensure_bus(PAN_BUSES[k], "SFX")
		_ensure_panner(PAN_BUSES[k], PAN_MAX * float(k) / 2.0)
	_ensure_limiter()
	_ensure_lowpass()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
		_pl_name.append("")
		_pl_start.append(0)
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
	set_process(false)
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


## Limitador no Master: nada passa de −1 dBFS quando muitos sons somam.
func _ensure_limiter() -> void:
	var master := AudioServer.get_bus_index("Master")
	for i in AudioServer.get_bus_effect_count(master):
		var e := AudioServer.get_bus_effect(master, i)
		if e is AudioEffectHardLimiter:
			(e as AudioEffectHardLimiter).ceiling_db = LIMITER_CEILING_DB
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = LIMITER_CEILING_DB
	lim.pre_gain_db = 0.0
	lim.release = 0.12
	AudioServer.add_bus_effect(master, lim)


## Pan fixo de um bus de estéreo (R14).
func _ensure_panner(bus_name: String, pan: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	for i in AudioServer.get_bus_effect_count(idx):
		var e := AudioServer.get_bus_effect(idx, i)
		if e is AudioEffectPanner:
			(e as AudioEffectPanner).pan = pan
			return
	var p := AudioEffectPanner.new()
	p.pan = pan
	AudioServer.add_bus_effect(idx, p)


## Passa-baixas do slow-mo (R8): um por bus, desligado (sem custo) até precisar.
func _ensure_lowpass() -> void:
	_lp_filters.clear()
	_lp_slots.clear()
	for bus_name in SLOW_BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		var found: AudioEffectLowPassFilter = null
		var slot := -1
		for i in AudioServer.get_bus_effect_count(idx):
			if AudioServer.get_bus_effect(idx, i) is AudioEffectLowPassFilter:
				found = AudioServer.get_bus_effect(idx, i) as AudioEffectLowPassFilter
				slot = i
				break
		if found == null:
			found = AudioEffectLowPassFilter.new()
			AudioServer.add_bus_effect(idx, found)
			slot = AudioServer.get_bus_effect_count(idx) - 1
		found.cutoff_hz = SLOW_OPEN_HZ
		found.resonance = 0.5
		AudioServer.set_bus_effect_enabled(idx, slot, false)
		_lp_filters.append(found)
		_lp_slots.append(Vector2i(idx, slot))


# --- SFX ---------------------------------------------------------------

## Toca um efeito. `pitch_var` < 0 = variação automática pela família do som.
## `world_pos` (opcional) = posição no MUNDO: dá um pan discreto pelo x na tela
## (use para inimigos, projéteis, telegrafos — não para a Sophia nem a UI).
## Devolve true se tocou (false: sem arquivo ou barrado pelo anti-spam).
func play_sfx(sfx_name: String, pitch_var: float = -1.0, volume_db: float = 0.0, world_pos: Vector2 = NO_POS) -> bool:
	var real_name: String = ALIASES.get(sfx_name, sfx_name)
	if pitch_var < 0.0:
		pitch_var = _pitch_for(real_name)
	return _play(real_name, 1.0 + randf_range(-pitch_var, pitch_var), volume_db, world_pos, false)


## Toca um efeito com tom EXATO (sem aleatório nem volume sorteado): arpejos,
## escalas (faísca por orbe, Anéis voando um semitom acima a cada um).
## pitch 1 = original; `pow(2, semitons / 12.0)` para subir em semitons.
## Sons em sequência (spark) usam sempre a 1ª variação: quem chama manda no tom.
func play_sfx_pitched(sfx_name: String, pitch: float, volume_db: float = 0.0, world_pos: Vector2 = NO_POS) -> bool:
	var real_name: String = ALIASES.get(sfx_name, sfx_name)
	return _play(real_name, clampf(pitch, 0.05, 8.0), volume_db, world_pos, true)


## Toca um efeito posicionado: atenua pela distância horizontal até a câmera
## (até −18 dB) e dá o pan discreto pela posição na tela; sem câmera, só o pan.
func play_sfx_at(sfx_name: String, pos: Vector2, pitch_var: float = -1.0) -> bool:
	var att := 0.0
	var cam := get_viewport().get_camera_2d() if get_viewport() != null else null
	if cam != null:
		var d := absf(pos.x - cam.get_screen_center_position().x)
		att = -clampf((d - 380.0) / 40.0, 0.0, 18.0)
	return play_sfx(sfx_name, pitch_var, att, pos)


func _play(real_name: String, pitch: float, volume_db: float, world_pos: Vector2, exact: bool) -> bool:
	if _shut_down or variants_of(real_name).is_empty():
		return false
	var now := Time.get_ticks_msec()
	var last_ms := int(_last_play_ms.get(real_name, -SEQ_WINDOW_MS))
	if now - last_ms < spam_ms_for(real_name):
		return false
	var stream
	if exact and SEQUENTIAL.has(real_name):
		stream = variants_of(real_name)[0]
	else:
		stream = _pick_variant(real_name, now - last_ms < SEQ_WINDOW_MS)
	_last_play_ms[real_name] = now
	if not exact and _jitters(real_name):
		volume_db += randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)
	var p: AudioStreamPlayer
	if real_name.begins_with("blip_"):
		p = _voice                    # voz: a sílaba nova corta a anterior
	else:
		var i := _grab_player(real_name, now)
		p = _players[i]
		_pl_name[i] = real_name
		_pl_start[i] = now
		var bus := _bus_for(real_name)
		if bus == "SFX" and world_pos.is_finite():
			bus = PAN_BUSES.get(_pan_step(pan_for(world_pos)), "SFX")
		p.bus = bus
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
	return true


## Anti-spam (ms) do som: mesmo nome não repete em menos que isto.
func spam_ms_for(sfx_name: String) -> int:
	return int(SPAM_OVERRIDE.get(sfx_name, SPAM_MS))


## Quantas instâncias deste som estão tocando agora (pool de SFX).
func voices_playing(sfx_name: String) -> int:
	var n := 0
	for i in _players.size():
		if _pl_name[i] == sfx_name and _players[i].playing:
			n += 1
	return n


## Escolhe o player: se o som já tem MAX_SAME vozes, rouba a mais velha DELE;
## senão um player livre; senão o mais velho do pool.
func _grab_player(sfx_name: String, now: int) -> int:
	var limit := int(MAX_SAME_OVERRIDE.get(sfx_name, MAX_SAME))
	var same := 0
	var oldest_same := -1
	var oldest_any := -1
	for i in _players.size():
		if not _players[i].playing:
			continue
		if oldest_any < 0 or _pl_start[i] < _pl_start[oldest_any]:
			oldest_any = i
		if _pl_name[i] == sfx_name:
			same += 1
			if oldest_same < 0 or _pl_start[i] < _pl_start[oldest_same]:
				oldest_same = i
	if same >= limit and oldest_same >= 0:
		return oldest_same
	for k in _players.size():
		var i := (_next + k) % _players.size()
		if not _players[i].playing:
			_next = (i + 1) % _players.size()
			return i
	return oldest_any if oldest_any >= 0 else 0


## Pan (−PAN_MAX..PAN_MAX) de uma posição do mundo pelo x NA TELA.
func pan_for(world_pos: Vector2) -> float:
	var vp := get_viewport()
	if vp == null or not world_pos.is_finite():
		return 0.0
	var screen := vp.get_canvas_transform() * world_pos
	var half := maxf(vp.get_visible_rect().size.x * 0.5, 1.0)
	return clampf((screen.x - half) / half, -1.0, 1.0) * PAN_MAX


## Pan → degrau de bus (−2..2; 0 = centro).
func _pan_step(pan: float) -> int:
	return clampi(roundi(pan / PAN_MAX * 2.0), -2, 2)


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


func _jitters(sfx_name: String) -> bool:
	for prefix in JITTER_FAMILIES:
		if sfx_name.begins_with(prefix):
			return true
	return false


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
## nada (só ajusta o tom). Se o arquivo não existir, a faixa ANTERIOR continua
## (nunca silêncio abrupto por falta de arquivo).
## `fade` em segundos: < 0 = padrão (1,2 s); 0 = CORTE SECO (a anterior para na
## hora e a nova entra cheia) — ex.: o tema distorcido "corta" e o roubo entra.
func play_music(track_name: String, loop: bool = true, pitch: float = 1.0, fade: float = -1.0) -> void:
	current_track = track_name
	if track_name == _playing_track and _music[_music_cur].playing:
		if not is_equal_approx(pitch, _music_pitch):
			set_music_pitch(pitch, 0.0)
		return
	var stream = _load(MUSIC_DIR + track_name)
	if stream == null or _shut_down:
		return
	_set_loop(stream, loop)
	var old := _music[_music_cur]
	_music_cur = (_music_cur + 1) % 2
	var new := _music[_music_cur]
	new.stream = stream
	_music_pitch = maxf(pitch, 0.05)
	new.pitch_scale = _music_pitch
	_playing_track = track_name
	_layer_now = float(_layer_db.get(track_name, 0.0))   # faixa nova entra já na sua camada
	_apply_volumes()
	var gain := track_gain_db(track_name)
	_kill_tween()
	if fade == 0.0:
		old.stop()
		new.volume_db = gain
		new.play()
		return
	new.volume_db = SILENT_DB
	new.play()
	var secs := MUSIC_FADE if fade < 0.0 else fade
	_music_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_music_tween.tween_property(new, "volume_db", gain, secs).from(SILENT_DB)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", SILENT_DB, secs)
		_music_tween.chain().tween_callback(old.stop)


## Ganho fixo da faixa (dB) aplicado no player: Éon ~3 LU abaixo do chefe (R13).
func track_gain_db(track_name: String) -> float:
	return EON_MUSIC_DB if track_name.begins_with("eon_") else 0.0


## Muda o tom/velocidade da música (1 = normal; 0,8 = mais grave e lenta).
## `fade` em segundos (0 = na hora). Vale pra faixa atual e as seguintes até
## alguém mudar de novo (o menu volta a 1).
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
## Abaixada longa: `duck_music(999, -14)` e depois `duck_music(0, 0)` solta.
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


## Volume da "camada" de uma faixa, 0..1 (0 = −18 dB, 1 = normal). Ex.: o
## Centro sobe conforme os cacos voltam. Fica guardado por faixa (trocar de
## faixa e voltar mantém o nível; o menu zera tudo). Muda sem degrau (6 dB/s).
## `track` vazio = faixa pedida por último.
func set_music_layer_volume(t: float, track: String = "") -> void:
	var key := track if track != "" else current_track
	_layer_db[key] = lerpf(-18.0, 0.0, clampf(t, 0.0, 1.0))
	_wake()


## Silencia a música com fade (0 = corta na hora).
func stop_music(fade: float = MUSIC_FADE) -> void:
	current_track = ""
	_playing_track = ""
	_kill_tween()
	# UM tween só (paralelo) para os dois players: antes cada player ganhava o
	# seu e só o último ficava guardado — o outro, órfão, seguia baixando e
	# depois PARAVA o player mesmo que ele já tocasse a faixa seguinte.
	for m in _music:
		if not m.playing:
			continue
		if fade <= 0.0:
			m.stop()
		else:
			if _music_tween == null:
				_music_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
			_music_tween.tween_property(m, "volume_db", SILENT_DB, fade)
			_music_tween.tween_callback(m.stop).set_delay(fade)


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
	if stream == null or _shut_down:
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
	for a in _amb:                    # um tween só (ver stop_music)
		if not a.playing:
			continue
		if fade <= 0.0:
			a.stop()
		else:
			if _amb_tween == null:
				_amb_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
			_amb_tween.tween_property(a, "volume_db", SILENT_DB, fade)
			_amb_tween.tween_callback(a.stop).set_delay(fade)


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


# --- Envelopes (ducking / slow-mo / camada) por tempo REAL ---------------
#
# Antes o ducking era um Tween criado no quadro do pedido. Tween (e timer) novo
# recebe no 1º passo o delta INTEIRO do quadro em que nasceu — inclusive o tempo
# ANTES do pedido: num quadro longo (carga de cena, 1º quadro do jogo) o fade
# pulava direto pro fim. Agora cada fade guarda o instante (Time, em µs) em que
# foi PEDIDO e o valor de partida; _process só interpola pelo relógio real
# desde então (ignora time_scale e pausa). Duração proporcional à distância:
# um fade revertido no meio volta no mesmo ritmo.

func _wake() -> void:
	if not is_processing():
		_env_us = Time.get_ticks_usec()
		set_process(true)


## Começa um fade de `cur` até `target`; devolve (partida, duração).
func _env_start(cur: float, target: float, secs_in: float, secs_out: float) -> Vector3:
	var secs := secs_in if target > cur else secs_out
	return Vector3(cur, maxf(secs * absf(target - cur), 0.0001), 0.0)


func _env_value(env: Vector3, t0: int, target: float, now: int) -> float:
	var k := clampf(float(now - t0) / 1000000.0 / env.y, 0.0, 1.0)
	return lerpf(env.x, target, k)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := float(now - _env_us) / 1000000.0
	_env_us = now
	var busy := false
	if _duck != _duck_target:
		_duck = _env_value(_duck_env, _duck_t0, _duck_target, now)
		busy = true
	if _slow != _slow_target:
		_slow = _env_value(_slow_env, _slow_t0, _slow_target, now)
		_apply_lowpass()
		busy = true
	var layer_goal := float(_layer_db.get(_playing_track, 0.0))
	if _layer_now != layer_goal:
		_layer_now = move_toward(_layer_now, layer_goal, clampf(dt, 0.0, 0.1) * LAYER_RATE_DB)
		busy = true
	_apply_volumes()
	if not busy:
		set_process(false)


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
	if target == _duck_target:
		return
	_duck_target = target
	_duck_env = _env_start(_duck, target, DUCK_IN, DUCK_OUT)
	_duck_t0 = Time.get_ticks_usec()
	_wake()


# --- Slow-mo (R8) ----------------------------------------------------------

## Sinal do Juice: `active` liga/desliga; `scale` ≈ 0,3 = esquiva perfeita
## (abafa menos, 2,5 kHz); finalização/chefe (0,15–0,22) = 1,5 kHz.
func _on_slowmo_changed(active: bool, scale: float = 0.25) -> void:
	var target := 1.0 if active else 0.0
	if active:
		_slow_hz = SLOW_DODGE_HZ if absf(scale - 0.3) <= 0.05 else SLOW_CUT_HZ
		_apply_lowpass()
	if target == _slow_target:
		return
	_slow_target = target
	_slow_env = _env_start(_slow, target, SLOW_IN, SLOW_OUT)
	_slow_t0 = Time.get_ticks_usec()
	_wake()


## Corte atual do passa-baixas (Hz), interpolado em escala logarítmica.
func lowpass_cutoff_hz() -> float:
	return exp(lerpf(log(SLOW_OPEN_HZ), log(_slow_hz), _slow))


func _apply_lowpass() -> void:
	var hz := lowpass_cutoff_hz()
	var on := _slow > 0.001
	for i in _lp_filters.size():
		_lp_filters[i].cutoff_hz = hz
		AudioServer.set_bus_effect_enabled(_lp_slots[i].x, _lp_slots[i].y, on)


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
	if pr != null and not pr.weapon_level_changed.is_connected(_on_weapon):
		_last_weapon = pr.weapon_level
		_last_rings = pr.rings.size()
		_last_restored = pr.restored_rings.size()
		_last_stolen = pr.rings_stolen
		pr.weapon_level_changed.connect(_on_weapon)
		pr.rings_changed.connect(_on_rings)
	# Slow-mo (sinal novo do Combate): liga só se existir — compila sem ele.
	var juice := get_node_or_null("/root/Juice")
	if juice != null and juice.has_signal("slowmo_changed"):
		var cb := Callable(self, "_on_slowmo_changed")
		if not juice.is_connected("slowmo_changed", cb):
			juice.connect("slowmo_changed", cb)


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


## Faixa e ambiência da Provação: dois encontros no clima do Éon do Arconte
## escolhido, o terceiro é o chefe. Usa `boss_index` (não a tela), então não
## depende da fórmula de tela da CodexSession.
func trial_track() -> String:
	if CodexSession.stage >= 2:
		return "boss"
	return "eon_" + EON_TRACKS[clampi(CodexSession.boss_index, 0, EON_TRACKS.size() - 1)]


func _play_trial_context() -> void:
	_end_scene_music()
	play_music(trial_track())
	var eon: String = EON_TRACKS[clampi(CodexSession.boss_index, 0, EON_TRACKS.size() - 1)]
	play_ambience("amb_" + eon, AMB_ARCHON_DB if CodexSession.stage >= 2 else 0.0)


func _play_run_context(screen: int) -> void:
	_end_scene_music()
	if RunManager.is_center(screen):
		_update_center_music()
	else:
		play_music(track_for_screen(screen))
	_update_ambience(screen)


## Centro (ROTEIRO §2, cena C): sem música até o 1º caco; depois `centro` entra
## a −15 dB e sobe 3 dB por caco até o volume cheio no 6º.
func _update_center_music() -> void:
	var k: int = Progression.restored_rings.size()
	if k <= 0:
		if _playing_track != "":
			stop_music(MUSIC_FADE * 2.0)
		current_track = "centro"
		return
	set_music_layer_volume(clampf(float(k) / float(CENTER_SHARDS), 0.0, 1.0), "centro")
	play_music("centro")


func _on_screen_changed(screen: int) -> void:
	if CodexSession.active:
		return                        # a Provação escolhe pelo estado (abaixo)
	if RunManager.run_active:
		_play_run_context(screen)


func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameManager.State.MENU:
			_reset_music_mods()
			play_music(menu_track())
			stop_ambience()
		GameManager.State.PLAYING:
			# Provação ANTES do run: CodexSession.start_demo() também liga
			# RunManager.run_active (REVISAO #8).
			if CodexSession.active:
				_play_trial_context()
			elif RunManager.run_active:
				_play_run_context(RunManager.current_screen)


## Menu: desfaz o que as cenas deixaram na música (tom, camadas, abaixada).
func _reset_music_mods() -> void:
	_end_scene_music()
	_layer_db.clear()
	if _temp_duck_tween != null and _temp_duck_tween.is_valid():
		_temp_duck_tween.kill()
	_temp_duck_db = 0.0
	if not is_equal_approx(_music_pitch, 1.0):
		set_music_pitch(1.0, 0.0)
	_wake()


## Faixa do menu: `menu` se o arquivo existir (tema próprio, escolha do João),
## senão `theme` (que é o tema da Voz — ver `voice_theme`).
func menu_track() -> String:
	for t in OPTIONAL_MUSIC:
		if t == "menu" and has_music(t):
			return t
	return VOICE_THEME


# --- Tema da Voz e API das cenas (ROTEIRO §2 e §5 #8) ----------------------
#
# Quem encena (Level/Cinematic) chama no momento da fala:
#   Audio.voice_theme("santuario")  antes da conversa do santuário;
#   Audio.voice_theme("")           depois dela (volta à música da tela);
#   Audio.cue(line.get("cue", ""))  a cada fala mostrada (DialogueBox.line_shown);
#   Audio.ring_note(i, devolvendo)  a cada gema que voa (roubo) ou volta (anagnórise).
# Trocar de tela (ou voltar ao menu) desfaz tudo o que a cena deixou.

## O tema da Voz em cada momento da história:
##   "santuario" — `theme` entra em 2 s, 3 dB abaixo (+ o ducking do diálogo);
##   "roubo"     — corte seco para `theme` a 0,75 de tom (distorcido) por 3 s
##                 de relógio real, depois corte seco para `roubo` (sem loop);
##   "sozinha"   — `theme` volta sozinho, lento (0,9), entrando em 4 s;
##   ""          — fim: volta à música da tela (Éon/Arconte/Provação).
## Em "roubo"/"sozinha" o diálogo abaixa a música só ~3 dB (a música É a cena).
func voice_theme(mode: String) -> void:
	_scene_token += 1
	voice_theme_mode = mode
	match mode:
		"santuario":
			_duck_scale = 1.0
			_layer_db[VOICE_THEME] = VOICE_SANCTUARY_DB
			play_music(VOICE_THEME, true, 1.0, SCENE_FADE)
			_wake()
		"roubo":
			_duck_scale = SCENE_DUCK_SCALE
			_layer_db.erase(VOICE_THEME)
			_release_temp_duck(0.0)
			stop_music(0.0)               # recomeça do início mesmo se o tema já tocava
			play_music(VOICE_THEME, false, VOICE_STOLEN_PITCH, 0.0)
			_apply_volumes()
			var token := _scene_token
			# Timer que ignora time_scale e pausa: 3 s REAIS (a cena roda em slow-mo/pausa).
			get_tree().create_timer(VOICE_STOLEN_SECS, true, false, true).timeout.connect(
				func() -> void:
					if token == _scene_token and not _shut_down:
						play_music("roubo", false, 1.0, 0.0))
		"sozinha":
			_duck_scale = SCENE_DUCK_SCALE
			_layer_db.erase(VOICE_THEME)
			_release_temp_duck(0.0)
			play_music(VOICE_THEME, true, VOICE_ALONE_PITCH, VOICE_ALONE_FADE)
			_apply_volumes()
		_:
			voice_theme_mode = ""
			_layer_db.erase(VOICE_THEME)
			if CodexSession.active:
				_play_trial_context()
			elif RunManager.run_active:
				_play_run_context(RunManager.current_screen)
			else:
				_end_scene_music()


## Desfaz o estado de cena (troca de tela, menu, Provação): cancela o corte
## agendado do roubo e devolve o ducking de diálogo ao normal.
func _end_scene_music() -> void:
	_scene_token += 1
	voice_theme_mode = ""
	if _temp_duck_db < -0.01:          # abaixada de cena (ex.: névoa) não atravessa a tela
		_release_temp_duck(DUCK_OUT)
	if _duck_scale != 1.0:
		_duck_scale = 1.0
		_apply_volumes()


## Solta a abaixada de `duck_music` em `secs` (0 = na hora).
func _release_temp_duck(secs: float) -> void:
	if _temp_duck_tween != null and _temp_duck_tween.is_valid():
		_temp_duck_tween.kill()
	if secs <= 0.0:
		_set_temp_duck(0.0)
		return
	_temp_duck_tween = create_tween().set_ignore_time_scale(true)
	_temp_duck_tween.tween_method(_set_temp_duck, _temp_duck_db, 0.0, secs)


## Som de um `cue` de fala (ROTEIRO §5). Devolve true se o cue é conhecido
## (mesmo os que não têm som, como `wait_2s`); false = cue desconhecido.
## A imagem (névoa, máscara, gemas) é de quem encena; aqui só o som.
func cue(cue_name: String) -> bool:
	if _shut_down:
		return CUES.has(cue_name)
	match cue_name:
		"heartbeat":                 # intro: coração no escuro
			play_sfx("heartbeat")
		"fog_thickens":              # cena A: névoa adensa; a música do Limiar desce a 40 %
			play_sfx("fog_swell")
			duck_music(9999.0, FOG_DUCK_DB)
		"king_emerges":              # cenas A e B: o Rei sai da névoa
			play_sfx("king_step")
			if RunManager.run_active and RunManager.is_king_screen(RunManager.current_screen):
				play_sfx("boss_appear", -1.0, -8.0)
				_release_temp_duck(SCENE_FADE)
		"mask_lights":               # cena A: a máscara acende
			play_sfx("mask_light")
		"mask_cracks":               # queda do Rei: o mesmo sino, um trítono abaixo (rachado)
			play_sfx_pitched("mask_light", pow(2.0, -6.0 / 12.0), -3.0)
		"king_sinks":                # o Rei afunda na névoa
			play_sfx_pitched("fog_swell", 0.8, -2.0)
		"chime":                     # o nome de Ina
			play_sfx_pitched("mask_light", 1.0, -6.0)
		"music_stop":                # santuário da Coroa: a música da Voz para
			stop_music(1.5)
		"voice_merge":               # cena B: Voz e Rei em uníssono
			play_sfx("voice_merge")
		"rings_fly":                 # cena B: as gemas voam — o som é por gema (ring_note)
			pass
		"mask_falls":                # cena B: a máscara cai — tema distorcido → roubo
			voice_theme("roubo")
		"sink":                      # cena B: vira motor e afunda; a música para
			play_sfx("dive")
			play_sfx_pitched("fog_swell", 0.6, 0.0)
			stop_music(1.5)
		"rings_return":              # cena D: corte de música; os Anéis voltam (ring_note)
			stop_music(0.0)
		"flash":                     # cena D: clarão + acorde
			play_sfx("nova")
			play_sfx_pitched("ring_gain", 1.0, -3.0)
		"colossus_shrinks":          # cena D: o Colosso oco; respiração pequena
			play_sfx("child_breath")
		"theme_alone":               # cena D: o tema da Voz, agora dela
			voice_theme("sozinha")
		"reclaim":                   # cena D: o pequeno vira luz
			play_sfx("revive", -1.0, -6.0)
		"wait_2s":
			pass
		_:
			return false
	return true


## Uma gema do roubo/anagnórise (0..6). Roubo: `ring_steal` um semitom ACIMA a
## cada gema; devolução (`returning`): `ring_gain` um semitom ABAIXO a cada uma.
func ring_note(index: int, returning: bool = false) -> bool:
	var i := clampi(index, 0, 6)
	if returning:
		return play_sfx_pitched("ring_gain", pow(2.0, -float(i) / 12.0), -4.0)
	return play_sfx_pitched("ring_steal", pow(2.0, float(i) / 12.0), -2.0)


# --- Ganchos por sinal (Progression) ------------------------------------

func _in_game() -> bool:
	# Fora do jogo (menu, restauração do save) os sinais disparam sem evento real.
	return GameManager.state == GameManager.State.PLAYING or GameManager.state == GameManager.State.UPGRADE


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
	if restored != _last_restored and not CodexSession.active and RunManager.run_active \
			and RunManager.is_center(RunManager.current_screen):
		_update_center_music()
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
	_set_bus("Music", music_vol, DUCK_MUSIC_DB * _duck * _duck_scale + _temp_duck_db + _layer_now + SLOW_MUSIC_DB * _slow)
	_set_bus("Ambience", music_vol, DUCK_AMB_DB * _duck)


func _set_bus(bus_name: String, linear: float, extra_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)) + extra_db)
		AudioServer.set_bus_mute(idx, linear <= 0.001)


# --- Encerramento (REVISAO #15) ------------------------------------------

## Ao fechar o jogo: para todos os players e solta os streams, pra nenhuma
## reprodução Ogg ficar "still in use at exit".
## Janela fechada (X / Alt+F4): ainda há quadros depois, o mixer solta tudo.
## `get_tree().quit()` (botão Sair) não manda WM_CLOSE_REQUEST: o autoload só
## fica sabendo ao sair da árvore, já no encerramento — então para tudo e dá
## ~40 ms para a thread de áudio misturar uma vez e apagar as reproduções.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown(false)
	elif what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_PREDELETE:
		shutdown(true)


func shutdown(settle: bool = false) -> void:
	if _shut_down:
		return
	_shut_down = true
	set_process(false)
	for t in [_music_tween, _amb_tween, _temp_duck_tween, _pitch_tween]:
		if t != null and (t as Tween).is_valid():
			(t as Tween).kill()
	var all: Array[AudioStreamPlayer] = []
	all.append_array(_players)
	all.append_array(_music)
	all.append_array(_amb)
	if _voice != null:
		all.append(_voice)
	var any_playing := false
	for p in all:
		if is_instance_valid(p):
			any_playing = any_playing or p.playing
			p.stop()
			p.stream = null
	_variants.clear()
	_cache.clear()
	if settle and any_playing:
		OS.delay_msec(40)


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
