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
## BUSES: Master (limitador) ← Music, Ambience, SFX ← (UI, Voice, SFX_L2/L1/R1/R2);
## Master ← Tell ← (Tell_L2/L1/R1/R2): avisos do combate, sem o abafado do slow-mo.
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
## Avisos do combate (R5) num bus PRÓPRIO, fora do passa-baixas da câmera lenta
## (o aviso é informação: não pode sumir numa esquiva perfeita). Segue o slider
## de SFX; tem os seus degraus de pan (Tell_L2 … Tell_R2).
const TELL_BUS := "Tell"
const TELL_PAN_BUSES := {-2: "Tell_L2", -1: "Tell_L1", 1: "Tell_R1", 2: "Tell_R2"}
const NO_POS := Vector2(INF, INF)
const EON_TRACKS := ["torpor", "fome", "corrente", "silencio", "espelho", "praga", "coroa"]
# Tema da Voz (ROTEIRO §5 #8): `theme` é a música DELA. Santuário = baixo, por
# baixo da conversa; roubo = distorcido 3 s e corta; anagnórise = volta sozinho.
const VOICE_THEME := "theme"
const VOICE_SANCTUARY_DB := -3.0  # + o ducking normal do diálogo (−9) = −12 dB
const VOICE_STOLEN_PITCH := 0.75  # roubo: tema 5 semitons abaixo e mais lento…
const VOICE_STOLEN_SECS := 3.0    # …por 3 s → corte seco → `roubo`
const VOICE_ALONE_PITCH := 0.85   # anagnórise: o tema volta sozinho, mais lento (= Staging)
const VOICE_ALONE_FADE := 4.0
const SCENE_FADE := 2.0           # entrada/saída do tema no santuário
const SCENE_DUCK_SCALE := 0.35    # roubo/anagnórise: a música É a cena — diálogo abaixa só ~3 dB
const FOG_DUCK_DB := -8.0
const CRACK_DELAY := 0.5          # roubo (`sink`): a rachadura do chão abre logo depois (= Staging _b_sink)
const RING_NOTE_HOLD_MS := 1500   # após um ring_note, o sinal de Anel não toca som próprio
# Coração (R22 / intro): `heartbeat` é UMA batida lub-dub; a intro toca duas.
const HEART_GAP := 1.1            # s entre as 2 batidas da intro (~55 bpm: acordando)
const HEART_PULSE_DB := -3.0      # vinheta de vida baixa: por baixo (o arquivo já está a −18 LUFS)…
const HEART_DIP_DB := -3.0        # …e a música abre espaço (−3 dB por ~0,6 s): sem isso a batida some
                                  # sob a música de chefe (medido: tools/audio/tell_check.py)
const HEART_PULSE_MIN_MS := 600   # nunca mais que ~1,6 batida/s, mesmo se o HUD chamar mais
## Faixas opcionais: tocam se o arquivo existir, sem ele o jogo usa a reserva.
## `menu` = tema do menu (opções por síntese aguardando o João; sem arquivo = `theme`).
## `boss_<éon>` = variação da música de chefe por Arconte (#40; opções geradas
## por `tools/audio_synth/boss_variants.py`, aguardando o João; sem arquivo = `boss`).
const OPTIONAL_MUSIC := ["menu", "boss_torpor", "boss_fome", "boss_corrente", "boss_silencio",
	"boss_espelho", "boss_praga", "boss_coroa"]
# Silêncio antes do chefe (NEURO R9): na tela do Arconte (e no 3º encontro da
# Provação) a música do chefe NÃO entra ao chegar — a do Éon sai em 0,6 s e fica
# só a ambiência; o stinger `boss_appear` (card de chefe) cai no vazio e a faixa
# do chefe entra 0,3 s depois. Na morte do chefe a música some em 150 ms,
# `boss_die` soa sozinho e ela volta ~2 s depois.
const PRE_BOSS_FADE := 0.6
const BOSS_ENTRY_DELAY := 0.3     # s entre o stinger e a faixa de chefe
const BOSS_ENTRY_FADE := 0.25
const BOSS_WAIT_MAX := 25.0       # rede de segurança: sem stinger em 25 s, a faixa entra mesmo assim
const BOSS_KILL_DB := -30.0       # morte do chefe: a música quase some…
const BOSS_KILL_IN := 0.15        # …em 150 ms,
const BOSS_KILL_HOLD := 1.6       # fica fora enquanto o boss_die soa,
const BOSS_KILL_OUT := 1.0        # e volta em 1 s (≈ 2,6 s ao todo)
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
		# --- avisos do combate (R5): brilho do telegrafo; o Combate chama ---
		"tell_parry", "tell_unblock",
		# ===== ONDA 7 (Áudio7): conteúdo novo das Ondas 5–6 — docs/onda2/AUDIO7.md =====
		# --- kit dos chefes (BossBrain.sfx: Galila puxa, Astaphaios devolve) ---
		"chain", "glass",
		# --- cargas antes do tiro (VFX7): luz da Sophia × trevas × Rei ---
		"charge_light", "charge_dark", "charge_king",
		# --- Sophia: pulo duplo, Queda Estelar, contra-ataque ---
		"double_jump", "star_charge", "star_impact", "riposte_ready", "riposte",
		"combo_tick",                                         # R7: adoçante tonal do combo (gancho combo_changed)
		# --- golpes dos inimigos por TIPO (move_sfx) + voadores ---
		"atk_swing", "atk_combo", "atk_rush", "atk_leap", "atk_slam", "atk_wave", "atk_shot",
		"atk_shot_air", "atk_fan", "atk_burst", "atk_homing", "atk_lob", "atk_pillar", "atk_fissure",
		"atk_grab", "atk_blink", "atk_summon", "atk_nova", "atk_dive", "atk_glide", "fly_fall",
		# --- Campeões ---
		"champion_enter", "champion_fury",
		# --- chefes: fase 3, guarda, olho do Rei, morte em 5 passos ---
		"boss_phase3", "guard_break", "eye_hit",
		"boss_death_impact", "boss_death_stagger", "boss_death_collapse", "boss_death_hush", "boss_death_shatter",
		# --- chefes: golpes-assinatura (move_sfx resolve o id do golpe) ---
		"bs_melee", "bs_cast", "bs_leap", "bs_land",
		"bs_yawn", "bs_lullaby", "bs_rain",                   # Athoth (Torpor)
		"bs_suck", "bs_bite", "bs_breath",                    # Harmas (Fome) / Belias
		"bs_cage",                                            # Galila (Corrente)
		"bs_scream", "bs_pages", "bs_wings",                  # Yabel (Silêncio)
		"bs_split", "bs_swap",                                # Astaphaios (Espelho)
		"bs_spores", "bs_cloud", "bs_burrow",                 # Belias (Praga)
		"bs_decree", "bs_coronation", "bs_royal_cut", "bs_sweep",  # Armupiel (Coroa)
		"bs_ray", "bs_hand", "bs_rings",                      # o Rei
		"bs_collapse",                                        # Colosso
		# --- perigos do level6 ---
		"hz_tide_wake", "hz_tide_tick", "hz_guillotine", "hz_winch", "hz_maw_bite", "hz_maw_warn",
		"hz_beam_on", "hz_beam_off", "hz_mirror_warn", "hz_mirror_flip", "hz_mist_breath",
		"hz_chain_swing", "hz_bell_toll", "hz_ether_drain", "hz_silence_in", "hz_silence_out",
		"hz_sink_start", "hz_sink_gone", "hz_sink_return", "hz_spears", "hz_shackles",
		"hz_spore_swell", "hz_spore_burst", "hz_spore_pop", "hz_shard_warn", "hz_shard_fall", "hz_shard_impact",
		"hz_totem_arm", "hz_totem_summon", "hz_totem_hit", "hz_totem_break",
		"hz_ward_drain", "hz_ward_out", "hz_ward_saved", "hz_altar", "hz_altar_hum",
		"hz_secret_mark", "hz_secret_open", "hz_column", "hz_saw",
		# --- UI nova: mapa, loja, objetivo, conquista, dom do Soter ---
		"map_open", "map_select", "map_locked", "shop_seal", "relic_equip", "zone_objective",
		"achievement", "soter_gift",
		# --- roubo: a rachadura abre, o Rei afunda (cue `sink`) ---
		"crack_open", "king_sink",
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
	0.04: ["swing_", "hit", "enemy_hurt", "enemy_die", "proj_", "block", "atk_", "fly_", "chain", "glass",
		"hz_shard_impact", "hz_totem_hit", "hz_spears", "hz_chain_swing", "hz_spore_pop"],
	0.06: ["step", "land", "jump", "cloth", "dodge", "gib_"],
	0.05: ["boss_step", "king_step"],
	0.03: ["blip_", "double_jump", "bs_melee", "bs_bite", "eye_hit"],
	0.0: ["tell_", "heartbeat", "ui_", "shop_", "subtitle_", "stele_", "ring_", "shard", "spark", "weapon_", "boss_", "zone_", "level_", "portal_", "cast_",
		"charge_", "riposte_ready", "map_", "achievement", "soter_", "relic_", "hz_", "bs_", "star_", "champion_", "guard_", "crack_", "king_sink"],
}

## Sons frequentes que ganham ±1,5 dB de volume aleatório (R11: "não enjoa").
const VOLUME_JITTER_DB := 1.5
const JITTER_FAMILIES := ["swing_", "hit", "step", "enemy_hurt", "land", "block", "cloth", "boss_step", "king_step",
	"atk_", "fly_", "hz_shard_impact", "hz_totem_hit"]

## Sons tocados em sequência (sobem as variações em ordem em vez de sortear).
const SEQUENTIAL := ["spark"]

## Anti-spam próprio (ms): o arpejo das faíscas chega com 40–70 ms entre orbes.
const SPAM_OVERRIDE := {"spark": 20,
	# Onda 7: tiques de dano e presenças não metralham; a conquista em rajada
	# (check_progress pode liberar várias de uma vez) toca UMA vez.
	"hz_tide_tick": 300, "hz_ward_drain": 250, "hz_ether_drain": 400, "hz_altar_hum": 1500,
	"achievement": 2500, "relic_equip": 300, "hz_shard_warn": 200, "fly_fall": 120}

## Vozes simultâneas próprias: o arpejo precisa deixar as caudas soarem.
const MAX_SAME_OVERRIDE := {"spark": 6, "achievement": 1, "hz_ward_drain": 1, "hz_altar_hum": 1,
	"hz_tide_tick": 1, "hz_mist_breath": 2}

## R7 — ADOÇANTE DO COMBO: a partir do 3º acerto seguido, um tique de vidro a
## ~−16 dB do impacto, subindo a pentatônica (+16 semitons no máximo); o combo
## zerou → volta ao começo. O IMPACTO não muda de tom (só o tique sobe).
const COMBO_FROM := 3
const COMBO_SCALE := [0, 2, 4, 7, 9, 12, 14, 16]
## R9 — ABAIXADAS CURTAS da música nos momentos de recompensa (−7 dB, entra em
## 40 ms, segura, volta em 600 ms) e no aparo (−3 dB por 250 ms). Nunca atropela
## uma abaixada maior já ativa (névoa, cena, morte do chefe, coração).
## nome -> [dB, entrada s, segura s, saída s]
const MOMENT_DUCKS := {
	"ring_gain": [-7.0, 0.04, 0.8, 0.6], "ring_steal": [-7.0, 0.04, 1.6, 0.6],
	"level_clear": [-7.0, 0.04, 0.8, 0.6], "weapon_upgrade": [-6.0, 0.04, 0.6, 0.6],
	"soter_gift": [-8.0, 0.04, 2.0, 0.8], "boss_phase3": [-8.0, 0.04, 0.8, 0.6],
	"parry": [-3.0, 0.02, 0.13, 0.1],   # −3 dB por ~250 ms
}

## Golpes dos inimigos (`atk_*`): num grupo de 5–6 bichos, o mesmo golpe saindo
## junto vira metralha. Anti-spam de 130 ms e no máximo 2 vozes (Guardião, R11).
const ENEMY_ATK_PREFIX := "atk_"
const ENEMY_ATK_SPAM_MS := 130
const ENEMY_ATK_MAX_SAME := 2

## Sons de INFORMAÇÃO fora da família `tell_` que também vão no bus Tell (sem o
## abafado da câmera lenta, tom fixo): a janela do contra-ataque abriu.
const TELL_EXTRA := ["riposte_ready"]
## Sons de interface fora de `ui_`/`shop_` (bus UI).
const UI_EXTRA := ["map_open", "map_select", "map_locked", "achievement"]

## ONDA 7 — golpes. `move_sfx(golpe, etapa, posição, chefe)` escolhe o som do
## golpe: 1º pelo id (só chefes: BOSS_MOVE_SFX), 2º pelo TIPO (KIND_SFX).
## Etapas: "wind" (o telegrafo começa — o aviso tell_* continua por conta do
## Enemy), "strike" (o golpe sai), "land" (salto do chefe pousa).
## O id é normalizado: "guarda3"/"corte_b" → "guarda"/"corte".
const KIND_SFX := {
	# inimigos comuns (EnemyMoves)
	"swing": {"strike": "atk_swing"}, "combo": {"strike": "atk_combo"},
	"rush": {"strike": "atk_rush"}, "leap": {"strike": "atk_leap"},
	"slam": {"strike": "atk_slam"}, "nova": {"strike": "atk_nova"},
	"shot": {"strike": "atk_shot"}, "burst": {"strike": "atk_burst"},
	"lob": {"strike": "atk_lob"}, "pillar": {"strike": "atk_pillar"},
	"fissure": {"strike": "atk_fissure"}, "grab": {"strike": "atk_grab"},
	"dive": {"strike": "atk_dive"}, "glide": {"strike": "atk_glide"},
	"blink": {"wind": "atk_blink"}, "summon": {"strike": "atk_summon"},
	"wave": {"strike": "atk_wave"},
	# chefes (BossBrain): melee/slam/charge/shot/cast/leap
	"melee": {"strike": "bs_melee"}, "charge": {"strike": "atk_rush"},
	"cast": {"strike": "bs_cast"},
}
## Chefes: só a etapa pedida; o que não estiver aqui cai no tipo ("" = mudo
## nesta etapa: o kit do chefe já soa). O pouso de todo salto ("land") é `bs_land`.
const BOSS_MOVE_SFX := {
	# Athoth (Torpor)
	"bocejo": {"wind": "bs_yawn", "strike": ""}, "cancao": {"wind": "bs_lullaby", "strike": ""},
	"chuva": {"strike": "bs_rain"}, "orbes": {"strike": "atk_homing"}, "deslize": {"strike": "bs_sweep"},
	# Harmas (Fome)
	"succao": {"wind": "bs_suck", "strike": "bs_bite"}, "boca": {"strike": "bs_bite"}, "sopro": {"strike": "bs_breath"},
	# Galila (Corrente)
	"corrente": {"strike": "chain"}, "puxao": {"strike": "atk_grab"}, "prisao": {"strike": "bs_cage"},
	"giro": {"strike": "bs_sweep"},
	# Yabel (Silêncio)
	"asas": {"strike": "bs_wings"}, "pergaminhos": {"strike": "bs_pages"}, "grito": {"strike": "bs_scream"},
	"laminas": {"strike": "atk_fan"}, "pisca": {"strike": "atk_blink"}, "mergulho": {"strike": "atk_dive"},
	# Astaphaios (Espelho) — a guarda já soa `glass` pelo kit
	"cacos": {"strike": "atk_fan"}, "guarda": {"strike": ""}, "reflexos": {"strike": "bs_split"},
	"troca": {"strike": "bs_swap"},
	# Belias (Praga)
	"bote": {"strike": "atk_leap"}, "mordida": {"strike": "bs_bite"}, "esporos": {"strike": "bs_spores"},
	"enterrar": {"strike": "bs_burrow"}, "nuvem": {"strike": "bs_cloud"},
	# Armupiel (Coroa)
	"espadao": {"strike": "bs_royal_cut"}, "varredura": {"strike": "bs_sweep"},
	"decreto": {"wind": "bs_decree", "strike": ""}, "corte_real": {"strike": "bs_royal_cut"},
	"coroacao": {"wind": "bs_coronation", "strike": ""},
	# o Rei (as cargas de luz roubada: charge_king, pelo VFX7)
	"leque": {"strike": "atk_fan"}, "raio": {"strike": "bs_ray"}, "mao": {"strike": "bs_hand"},
	"aneis": {"strike": "bs_rings"}, "larvas": {"strike": "atk_summon"}, "teleporte": {"strike": "atk_blink"},
	# Colosso
	"desabamento": {"strike": "bs_collapse"},
}
## Morte do chefe em 5 passos (sinal Enemy.boss_dying): impacto, cambaleio,
## colapso, pausa, estilhaço. O passo 4 soma com o `boss_die` do Enemy.
const DEATH_STEP_SFX := ["boss_death_impact", "boss_death_stagger", "boss_death_collapse",
	"boss_death_hush", "boss_death_shatter"]

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
var _temp_duck_db: float = 0.0       # duck_music(): abaixada temporária (relógio real)
var _td_active: bool = false         # envelope da abaixada: desce em _td_in, segura _td_hold,
var _td_t0: int = 0                  # volta em _td_out (µs do PEDIDO em _td_t0)
var _td_from: float = 0.0
var _td_db: float = 0.0
var _td_in: float = 0.0
var _td_hold: float = 0.0
var _td_out: float = 0.0
var _music_pitch: float = 1.0
var _pitch_tween: Tween
var _shut_down: bool = false
## Sorteios do áudio (tom, variação, ponto da ambiência) num gerador PRÓPRIO:
## antes usavam o global (randf/randi) em quantidades que dependem do relógio
## real (anti-spam) e desalinhavam o sorteio do jogo (pedido do Balance).
var _rng := RandomNumberGenerator.new()

# --- tema da Voz / cenas ---
var voice_theme_mode: String = ""    # "", "santuario", "roubo", "sozinha"
var _roubo_due_us: int = 0           # µs do corte agendado tema → `roubo` (0 = nenhum)
var _duck_scale: float = 1.0         # 1 = ducking de diálogo cheio; menor nas cenas musicais
var _ring_note_ms: int = -100000     # último ring_note (a cena já tocou a gema: o sinal não repete)
var _later: Array = []               # [µs, nome, dB]: SFX agendados por relógio real (ver _process)
# --- silêncio antes do chefe (R9) ---
var boss_pending: String = ""        # faixa de chefe esperando o stinger ("" = nada esperando)
var _boss_due_us: int = 0            # µs em que a faixa de chefe entra (0 = não agendada)
var _boss_wait_us: int = 0           # µs limite da espera (rede de segurança)
var _boss_seen: bool = false         # o chefe já apareceu nesta visita da tela
var _pulse_ms: int = -100000         # último low_health_pulse
## Ferramenta (QA/bot): com a variável de ambiente GNOSIS_AUDIO_LOG=<arquivo.json>,
## conta cada SFX tocado e grava a contagem no encerramento (prova que os
## ganchos da Onda 7 disparam jogando — sem ouvir nada).
var played_counts: Dictionary = {}
var _log_events: Array = []          # ver _play: cada SFX tocado (R13 offline)
var _log_beds: Array = []            # amostras da música/ambiência e dos buses (R13 offline)
var _log_path: String = OS.get_environment("GNOSIS_AUDIO_LOG")
var _watch: _Watch = null            # ONDA 7: observador de eventos sem sinal (ver _Watch)

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
	_ensure_bus(TELL_BUS, "Master")
	for k in TELL_PAN_BUSES:
		_ensure_bus(TELL_PAN_BUSES[k], TELL_BUS)
		_ensure_panner(TELL_PAN_BUSES[k], PAN_MAX * float(k) / 2.0)
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
	_watch = _Watch.new()
	_watch.name = "Watch"
	_watch.audio = self
	_watch.process_mode = Node.PROCESS_MODE_PAUSABLE   # pausa do jogo = sem eventos
	add_child(_watch)
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
	return _play(real_name, 1.0 + _rng.randf_range(-pitch_var, pitch_var), volume_db, world_pos, false)


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
		volume_db += _rng.randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)
	var p: AudioStreamPlayer
	if real_name.begins_with("blip_"):
		p = _voice                    # voz: a sílaba nova corta a anterior
	else:
		var i := _grab_player(real_name, now)
		p = _players[i]
		_pl_name[i] = real_name
		_pl_start[i] = now
		var bus := _bus_for(real_name)
		if world_pos.is_finite():
			if bus == "SFX":
				bus = PAN_BUSES.get(_pan_step(pan_for(world_pos)), "SFX")
			elif bus == TELL_BUS:
				bus = TELL_PAN_BUSES.get(_pan_step(pan_for(world_pos)), TELL_BUS)
		p.bus = bus
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
	if _log_path != "":
		played_counts[real_name] = int(played_counts.get(real_name, 0)) + 1
		# R13 offline: [tempo de JOGO (s), arquivo, dB do player, tom, bus]
		if _log_events.size() < 200000:
			_log_events.append([float(Engine.get_physics_frames()) / 60.0, String((stream as Resource).resource_path),
				p.volume_db, p.pitch_scale, String(p.bus)])
	_on_sfx_event(real_name)
	return true


## Anti-spam (ms) do som: mesmo nome não repete em menos que isto.
func spam_ms_for(sfx_name: String) -> int:
	if SPAM_OVERRIDE.has(sfx_name):
		return int(SPAM_OVERRIDE[sfx_name])
	if sfx_name.begins_with(ENEMY_ATK_PREFIX):
		return ENEMY_ATK_SPAM_MS
	return SPAM_MS


## Vozes simultâneas do mesmo som (R11): golpes de inimigo no máximo 2.
func max_same_for(sfx_name: String) -> int:
	if MAX_SAME_OVERRIDE.has(sfx_name):
		return int(MAX_SAME_OVERRIDE[sfx_name])
	if sfx_name.begins_with(ENEMY_ATK_PREFIX):
		return ENEMY_ATK_MAX_SAME
	return MAX_SAME


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
	var limit := max_same_for(sfx_name)
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
	if sfx_name.begins_with("tell_") or TELL_EXTRA.has(sfx_name):
		return TELL_BUS
	if UI_EXTRA.has(sfx_name):
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
			i = list.size() - 1 - _rng.randi() % 2     # no topo: alterna as duas mais agudas
		else:
			i = last + 1
	else:
		i = _rng.randi() % (list.size() - 1)
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
	_start_temp_duck(db, DUCK_IN, maxf(seconds, 0.0), DUCK_OUT)


## Envelope da abaixada por relógio real (como o ducking): um quadro longo não
## pula nem engole o fade — antes era Tween e atrasava sob carga.
func _start_temp_duck(db: float, secs_in: float, hold: float, secs_out: float) -> void:
	_td_from = _temp_duck_db
	_td_db = db
	_td_in = maxf(secs_in, 0.0001)
	_td_hold = hold
	_td_out = maxf(secs_out, 0.0001)
	_td_t0 = Time.get_ticks_usec()
	_td_active = true
	_wake()


func _temp_duck_value(now: int) -> float:
	var t := float(now - _td_t0) / 1000000.0
	if t < _td_in:
		return lerpf(_td_from, _td_db, t / _td_in)
	t -= _td_in
	if t < _td_hold:
		return _td_db
	t -= _td_hold
	if t < _td_out:
		return lerpf(_td_db, 0.0, t / _td_out)
	_td_active = false
	return 0.0


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
	new.play(_rng.randf() * maxf(stream.get_length() - 1.0, 0.0))
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


# --- Envelopes (ducking / slow-mo / camada / duck_music) por tempo REAL ---
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
	if _td_active:
		_temp_duck_db = _temp_duck_value(now)
		busy = true
	if not _later.is_empty():
		busy = true
		_fire_later(now)
	if boss_pending != "":
		busy = true
		if (_boss_due_us > 0 and now >= _boss_due_us) or (_boss_due_us == 0 and now >= _boss_wait_us):
			_start_boss_track()
	if _roubo_due_us > 0:
		busy = true
		if now >= _roubo_due_us:
			_roubo_due_us = 0
			if not _shut_down:
				play_music("roubo", false, 1.0, 0.0)
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
	# ONDA 7: ganchos por SINAL (ninguém precisa chamar): a morte do chefe em
	# 5 passos e a janela do contra-ataque da Sophia.
	if node.has_signal("boss_dying"):
		var cb := Callable(self, "_on_boss_dying").bind(node)
		if not node.is_connected("boss_dying", cb):
			node.connect("boss_dying", cb)
	if node.has_signal("riposte_window_opened"):
		var cr := Callable(self, "_on_riposte_window")
		if not node.is_connected("riposte_window_opened", cr):
			node.connect("riposte_window_opened", cr)
	if node.has_signal("combo_changed"):
		var cc := Callable(self, "_on_combo_changed")
		if not node.is_connected("combo_changed", cc):
			node.connect("combo_changed", cc)
	if _watch != null:
		_watch.track(node)


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
	# ONDA 7: dom do Soter (pulo duplo), relíquia equipada, conquista.
	if pr != null:
		_connect_if(pr, "double_jump_granted", "_on_double_jump_granted")
		_connect_if(pr, "relics_changed", "_on_relics_changed")
	var ach := get_node_or_null("/root/Achievements")
	if ach != null:
		_connect_if(ach, "unlocked", "_on_achievement")
	# Slow-mo (sinal novo do Combate): liga só se existir — compila sem ele.
	var juice := get_node_or_null("/root/Juice")
	if juice != null and juice.has_signal("slowmo_changed"):
		var cb := Callable(self, "_on_slowmo_changed")
		if not juice.is_connected("slowmo_changed", cb):
			juice.connect("slowmo_changed", cb)


## Faixa certa pra uma tela do run (só pela ESTRUTURA — nunca número fixo).
## "" = silêncio: o Centro antes do 1º caco devolvido (cena C, "memória =
## música"). Quem religar a música por esta função (voltar da pausa, trocar de
## tela) respeita o silêncio.
func track_for_screen(screen: int) -> String:
	if RunManager.is_final(screen):
		return "mente"
	if RunManager.is_center(screen):
		return "centro" if Progression.restored_rings.size() > 0 else ""
	if RunManager.is_king_screen(screen):
		return "rei"
	if RunManager.is_archon_screen(screen):
		return boss_track(RunManager.eon_index(screen))
	return "eon_" + EON_TRACKS[clampi(RunManager.eon_index(screen), 0, EON_TRACKS.size() - 1)]


## Música de chefe do Arconte do Éon `eon` (0..6): `boss_<éon>` se o João
## aprovar e o arquivo existir; senão a padrão, `boss`.
func boss_track(eon: int) -> String:
	var t: String = "boss_" + EON_TRACKS[clampi(eon, 0, EON_TRACKS.size() - 1)]
	return t if has_music(t) else "boss"


## Faixa e ambiência da Provação: dois encontros no clima do Éon do Arconte
## escolhido, o terceiro é o chefe. Usa `boss_index` (não a tela), então não
## depende da fórmula de tela da CodexSession.
func trial_track() -> String:
	if CodexSession.stage >= 2:
		return boss_track(CodexSession.boss_index)
	return "eon_" + EON_TRACKS[clampi(CodexSession.boss_index, 0, EON_TRACKS.size() - 1)]


func _play_trial_context() -> void:
	_end_scene_music()
	if CodexSession.stage >= 2:
		_await_boss(trial_track())
	else:
		_boss_seen = false            # encontros 1–2: o chefe (3º) ainda vai aparecer
		boss_pending = ""
		play_music(trial_track())
	var eon: String = EON_TRACKS[clampi(CodexSession.boss_index, 0, EON_TRACKS.size() - 1)]
	play_ambience("amb_" + eon, AMB_ARCHON_DB if CodexSession.stage >= 2 else 0.0)


func _play_run_context(screen: int) -> void:
	_end_scene_music()
	if RunManager.is_center(screen):
		_update_center_music()
	elif RunManager.is_archon_screen(screen):
		_await_boss(track_for_screen(screen))
	else:
		play_music(track_for_screen(screen))
	_update_ambience(screen)


# --- Silêncio antes do chefe (NEURO R9) ------------------------------------

## Tela de chefe: se o chefe ainda não apareceu nesta visita, a música atual sai
## em 0,6 s e a do chefe fica ESPERANDO o stinger (`boss_appear`). Se já
## apareceu (ex.: voltar da pausa no meio da luta), toca direto.
func _await_boss(track: String) -> void:
	if _boss_seen:
		boss_pending = ""
		play_music(track)
		return
	if boss_pending == track:
		return                        # já esperando (contexto pedido 2×)
	boss_pending = track
	_boss_due_us = 0
	_boss_wait_us = Time.get_ticks_usec() + int(BOSS_WAIT_MAX * 1000000.0)
	current_track = track
	if _playing_track != "" and _playing_track != track:
		stop_music(PRE_BOSS_FADE)
		current_track = track
	_wake()


func _start_boss_track() -> void:
	var t := boss_pending
	boss_pending = ""
	_boss_due_us = 0
	_boss_seen = true
	if t != "" and not _shut_down:
		play_music(t, true, 1.0, BOSS_ENTRY_FADE)


## Ganchos de SFX com efeito na música (R9): o stinger solta a faixa de chefe
## que esperava; a morte do chefe tira a música por ~2 s.
func _on_sfx_event(real_name: String) -> void:
	match real_name:
		"boss_appear":
			_boss_seen = true
			if boss_pending != "" and _boss_due_us == 0:
				_boss_due_us = Time.get_ticks_usec() + int(BOSS_ENTRY_DELAY * 1000000.0)
				_wake()
		"boss_die":
			_start_temp_duck(BOSS_KILL_DB, BOSS_KILL_IN, BOSS_KILL_HOLD, BOSS_KILL_OUT)
		_:
			# R9: abaixada curta no momento (só se nenhuma outra estiver ativa)
			if MOMENT_DUCKS.has(real_name) and not _td_active:
				var d: Array = MOMENT_DUCKS[real_name]
				_start_temp_duck(float(d[0]), float(d[1]), float(d[2]), float(d[3]))


## Centro (ROTEIRO §2, cena C): sem música até o 1º caco; depois `centro` entra
## e sobe um degrau por caco até o volume cheio no 6º. Curva = a do Level
## (`_restore_echo`: 0,35 + 0,65·k/6), para os dois nunca brigarem pela camada:
## 1 caco ≈ −9,8 dB, 3 ≈ −6 dB, 6 = 0 dB.
func _update_center_music() -> void:
	var k: int = Progression.restored_rings.size()
	if k <= 0:
		if _playing_track != "":
			stop_music(MUSIC_FADE * 2.0)
		current_track = "centro"
		return
	set_music_layer_volume(clampf(0.35 + 0.65 * float(k) / float(CENTER_SHARDS), 0.0, 1.0), "centro")
	play_music("centro")


func _on_screen_changed(screen: int) -> void:
	_boss_seen = false                # tela nova (ou recomeço): o chefe ainda não apareceu
	boss_pending = ""
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
	boss_pending = ""
	_boss_seen = false
	_layer_db.clear()
	_td_active = false
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
##   "sozinha"   — `theme` volta sozinho, lento (0,85), entrando em 4 s;
##   ""          — fim: volta à música da tela (Éon/Arconte/Provação).
## Em "roubo"/"sozinha" o diálogo abaixa a música só ~3 dB (a música É a cena).
func voice_theme(mode: String) -> void:
	_roubo_due_us = 0
	if mode != "":
		boss_pending = ""             # a cena manda na música
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
			# 3 s de relógio REAL desde o pedido (ver _process). Um timer novo
			# disparava cedo sob carga: recebe no 1º passo o quadro inteiro.
			_roubo_due_us = Time.get_ticks_usec() + int(VOICE_STOLEN_SECS * 1000000.0)
			_wake()
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
	_roubo_due_us = 0
	voice_theme_mode = ""
	if _temp_duck_db < -0.01:          # abaixada de cena (ex.: névoa) não atravessa a tela
		_release_temp_duck(DUCK_OUT)
	if _duck_scale != 1.0:
		_duck_scale = 1.0
		_apply_volumes()


## Solta a abaixada de `duck_music` em `secs` (0 = na hora).
func _release_temp_duck(secs: float) -> void:
	if secs <= 0.0:
		_td_active = false
		_set_temp_duck(0.0)
		return
	_start_temp_duck(0.0, secs, 0.0, 0.0)


## Som de um `cue` de fala (ROTEIRO §5). Devolve true se o cue é conhecido
## (mesmo os que não têm som, como `wait_2s`); false = cue desconhecido.
## A imagem (névoa, máscara, gemas) é de quem encena; aqui só o som.
func cue(cue_name: String) -> bool:
	if _shut_down:
		return CUES.has(cue_name)
	match cue_name:
		"heartbeat":                 # intro: coração no escuro (2 batidas)
			play_sfx("heartbeat")
			play_sfx_later("heartbeat", HEART_GAP, -2.0)
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
		"mask_cracks":               # queda do Rei: estalo seco (= Staging)
			play_sfx("block", -1.0, -4.0)
		"king_sinks":                # o Rei afunda na névoa
			play_sfx_pitched("fog_swell", 0.8, -2.0)
		"chime":                     # o nome de Ina (= Staging)
			play_sfx("stele_unlock", -1.0, -6.0)
		"music_stop":                # santuário da Coroa: a música da Voz para
			stop_music(1.5)
		"voice_merge":               # cena B: Voz e Rei em uníssono
			play_sfx("voice_merge")
		"rings_fly":                 # cena B: as gemas voam — o som é por gema (ring_note)
			pass
		"mask_falls":                # cena B: a máscara cai — tema distorcido → roubo
			voice_theme("roubo")
		"sink":                      # cena B: vira motor e afunda, o chão racha; a música para
			play_sfx("king_sink")
			play_sfx_later("crack_open", CRACK_DELAY, -2.0)
			play_sfx_pitched("fog_swell", 0.6, -8.0)
			stop_music(2.0)
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
			play_sfx("revive", -1.0, -4.0)
		"wait_2s":
			pass
		_:
			return false
	return true


## Uma gema do roubo/anagnórise (0..6). Roubo: `ring_steal` um semitom ACIMA a
## cada gema; devolução (`returning`): `ring_gain` um semitom ABAIXO a cada uma.
func ring_note(index: int, returning: bool = false) -> bool:
	var i := clampi(index, 0, 6)
	_ring_note_ms = Time.get_ticks_msec()
	if returning:
		return play_sfx_pitched("ring_gain", pow(2.0, -float(i) / 12.0), -4.0)
	return play_sfx_pitched("ring_steal", pow(2.0, float(i) / 12.0), -2.0)


## Toca `sfx_name` daqui a `secs` segundos de RELÓGIO REAL (pausa e câmera
## lenta não atrasam). Para sequências curtas de cena (as 2 batidas da intro).
func play_sfx_later(sfx_name: String, secs: float, volume_db: float = 0.0) -> void:
	if _shut_down:
		return
	_later.append([Time.get_ticks_usec() + int(maxf(secs, 0.0) * 1000000.0), sfx_name, volume_db])
	_wake()


func _fire_later(now: int) -> void:
	var keep: Array = []
	for item in _later:
		if now >= int(item[0]):
			play_sfx(String(item[1]), -1.0, float(item[2]))
		else:
			keep.append(item)
	_later = keep


## Aviso de vida baixa (R22): UMA batida grave de coração, bem por baixo da
## mixagem. O HUD chama a cada pulso da vinheta (~0,9 Hz, no máximo 8 s).
## Dono do volume = Áudio: quem chama não passa dB. Devolve true se tocou.
func low_health_pulse() -> bool:
	var now := Time.get_ticks_msec()
	if now - _pulse_ms < HEART_PULSE_MIN_MS:
		return false
	_pulse_ms = now
	if not _td_active:                 # nunca atropela uma abaixada maior (névoa, morte do chefe)
		_start_temp_duck(HEART_DIP_DB, 0.06, 0.3, 0.3)
	return play_sfx("heartbeat", 0.0, HEART_PULSE_DB)


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
	# Se a cena acabou de tocar as gemas (ring_note), o sinal não toca de novo.
	var scene_played := Time.get_ticks_msec() - _ring_note_ms < RING_NOTE_HOLD_MS
	if _in_game() and not scene_played:
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


# --- ONDA 7: golpes, morte do chefe e ganchos ------------------------------

var _id_re: RegEx = null


## Som do golpe `mv` (Dictionary de EnemyMoves ou do BossBrain) na `stage`
## ("wind" | "strike" | "land"). `boss` = golpe de chefe (consulta o id).
## Devolve o nome ("" = este golpe não tem som nesta etapa). Não toca nada.
func move_sound_for(mv: Dictionary, stage: String, boss: bool = false) -> String:
	if stage == "land":
		return "bs_land" if boss else ""
	var id := move_base_id(String(mv.get("id", "")))
	var kind := String(mv.get("kind", ""))
	if boss and BOSS_MOVE_SFX.has(id):
		var m: Dictionary = BOSS_MOVE_SFX[id]
		if m.has(stage):
			return String(m[stage])
	if stage == "strike" and kind == "shot":
		# variações de tiro: teleguiado, de CIMA (voador), leque (vários)
		if float(mv.get("homing", 0.0)) > 0.0:
			return "atk_homing"
		if bool(mv.get("air", false)):
			return "atk_shot_air"
		var offs = mv.get("offs", [])
		if int(mv.get("count", 1)) > 1 or (offs is Array and (offs as Array).size() > 1):
			return "atk_fan"
	var k: Dictionary = KIND_SFX.get(kind, {})
	return String(k.get(stage, ""))


## "guarda3" → "guarda", "corte_b" → "corte" (variações de fase do mesmo golpe).
func move_base_id(id: String) -> String:
	if _id_re == null:
		_id_re = RegEx.new()
		_id_re.compile("(_[a-c]|[0-9])+$")
	return _id_re.sub(id, "", false)


## Toca o som do golpe (ver `move_sound_for`). Enemy:
## `Audio.move_sfx(_mv, "strike", global_position)`; BossBrain:
## `Audio.move_sfx(mv, "strike", e.global_position, true)`.
func move_sfx(mv: Dictionary, stage: String, world_pos: Vector2 = NO_POS, boss: bool = false) -> bool:
	var n := move_sound_for(mv, stage, boss)
	if n == "" or not has_sfx(n):
		return false
	if world_pos.is_finite():
		return play_sfx_at(n, world_pos)
	return play_sfx(n)


## Passo da morte do chefe (0..4) → som ("" fora da faixa).
func death_step_sfx(step: int) -> String:
	return String(DEATH_STEP_SFX[step]) if step >= 0 and step < DEATH_STEP_SFX.size() else ""


func _on_boss_dying(step: int, enemy: Node = null) -> void:
	var n := death_step_sfx(step)
	if n == "":
		return
	if enemy is Node2D and is_instance_valid(enemy) and (enemy as Node2D).is_inside_tree():
		play_sfx_at(n, (enemy as Node2D).global_position)
	else:
		play_sfx(n)


func _on_riposte_window() -> void:
	play_sfx("riposte_ready")


## R7: o combo da Sophia mudou (`Player.combo_changed`, 1 por acerto; 0 = zerou).
func _on_combo_changed(count: int) -> void:
	var p := combo_tick_pitch(count)
	if p > 0.0:
		play_sfx_pitched("combo_tick", p)


## Tom do tique do combo no acerto `count` (0 = sem tique).
func combo_tick_pitch(count: int) -> float:
	if count < COMBO_FROM:
		return 0.0
	var s: int = int(COMBO_SCALE[mini(count - COMBO_FROM, COMBO_SCALE.size() - 1)])
	return pow(2.0, float(s) / 12.0)


func _on_double_jump_granted() -> void:
	play_sfx("soter_gift")


func _on_relics_changed() -> void:
	if _in_game():
		play_sfx("relic_equip")


func _on_achievement(_id: String = "") -> void:
	play_sfx("achievement")


func _connect_if(obj: Object, sig: String, method: String) -> void:
	if not obj.has_signal(sig):
		return
	var cb := Callable(self, method)
	if not obj.is_connected(sig, cb):
		obj.connect(sig, cb)


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
	_set_bus(TELL_BUS, sfx_vol, 0.0)
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
	if _log_path != "":
		var f := FileAccess.open(_log_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(played_counts, "	", true))
			f.close()
		var fe := FileAccess.open(_log_path.get_basename() + ".events.json", FileAccess.WRITE)
		if fe != null:
			fe.store_string(JSON.stringify({"sfx": _log_events, "beds": _log_beds}))
			fe.close()
	_td_active = false
	_later.clear()
	for t in [_music_tween, _amb_tween, _pitch_tween]:
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


# --- ONDA 7: OBSERVADOR (eventos que ainda não têm sinal) -----------------
## Os golpes dos inimigos/chefes, o voador derrubado, a fúria do Campeão, a
## quebra de guarda, o olho do Rei, o pouso da Queda Estelar,
## o objetivo da zona, o selo aberto e os perigos SILENCIOSOS do level6 não
## emitem sinal. Em vez de esperar 7 donos, o Áudio OLHA o estado público
## desses nós uma vez por quadro de física (só BORDAS: o quadro em que muda) e
## toca o som. Regras:
##   · só onde hoje NÃO há som (onde já há um genérico, a troca é pedido ao dono
##     em docs/pedidos/audio7.md — senão o som dobra, R4);
##   · lê propriedades com `get()` e confere tipo: se um dono renomear algo, o
##     evento só fica mudo (sem erro) e o AudioQA avisa;
##   · pausado (PROCESS_MODE_PAUSABLE) não observa; perigo longe da câmera
##     (> WATCH_FAR px) não soa.
## Se um dono passar a chamar o som direto, remova o evento daqui (a tabela de
## "quem liga o quê" está em docs/onda2/AUDIO7.md).
class _Watch extends Node:
	const WATCH_FAR := 720.0
	const BREAK_MIN_T := 1.3          # atordoado > 1,3 s = quebra de guarda (o aparo dá 1,1)
	## Golpes que SÃO TIRO (nascem Projectile): o observador não toca `atk_*` neles —
	## o tiro já soa por charge_* (VFX7) + proj_fire (decisão do chefe, pedido do vfx7).
	const SHOT_KINDS := ["shot", "burst", "lob", "fissure"]
	var audio: Node = null
	var _w: Dictionary = {}           # instance_id -> {"n": nó, "k": tipo, ...estado anterior}
	var _hud_t := 0.0
	var _hud_prev := -1

	func track(node: Node) -> void:
		var k := _kind_of(node)
		if k == "":
			return
		var id := node.get_instance_id()
		if _w.has(id):
			return
		_w[id] = {"n": node, "k": k, "init": false}
		node.tree_exiting.connect(func() -> void: _w.erase(id), CONNECT_ONE_SHOT)

	func _kind_of(node: Node) -> String:
		var sc = node.get_script()
		if sc == null:
			return ""
		var g: String = String(sc.get_global_name())
		var base = sc.get_base_script()
		while g == "" and base != null:
			g = String(base.get_global_name())
			base = base.get_base_script()
		if g in ["MirrorBeam", "MirrorPlatform", "MistPatch", "SinkingPlatform", "SporePod", "ShardFall",
				"SilenceField", "SecretMark", "Guillotine", "DarkTide", "WardLight", "SummonTotem"]:
			return g
		if "estate" in node and "_mv" in node:
			return "Enemy"
		if node.has_signal("riposte_window_opened") and "state" in node:
			return "Player"
		return ""

	func _physics_process(delta: float) -> void:
		for id in _w.keys():
			var r: Dictionary = _w[id]
			var n = r.n
			if not is_instance_valid(n) or not (n as Node).is_inside_tree():
				continue
			match String(r.k):
				"Enemy": _enemy(r, n)
				"Player": _player(r, n)
				_: _hazard(r, n)
			r.init = true
		_hud_t -= delta
		if _hud_t <= 0.0:
			_hud_t = 0.25
			_hud()
		if audio._log_path != "" and Engine.get_physics_frames() % 6 == 0:
			_log_bed()

	## R13 offline: a cada 0,1 s de jogo, o que a música e a ambiência tocam
	## (arquivo, posição, volume do player) e o volume dos buses.
	func _log_bed() -> void:
		var row: Array = [float(Engine.get_physics_frames()) / 60.0]
		for pl in [audio._music[audio._music_cur], audio._amb[audio._amb_cur]]:
			var a := pl as AudioStreamPlayer
			if a.playing and a.stream != null:
				row.append([String(a.stream.resource_path), a.get_playback_position(), a.volume_db, a.pitch_scale])
			else:
				row.append([])
		var buses := {}
		for b in ["Master", "Music", "Ambience", "SFX", "UI", "Voice", "Tell"]:
			var i := AudioServer.get_bus_index(b)
			if i >= 0:
				buses[b] = AudioServer.get_bus_volume_db(i)
		row.append(buses)
		audio._log_beds.append(row)

	# --- inimigos e chefes ---------------------------------------------------
	func _enemy(r: Dictionary, e) -> void:
		var st: int = int(e.get("estate"))
		var brain = e.get("brain")
		var boss: bool = brain != null and is_instance_valid(brain)
		var pos: Vector2 = (e as Node2D).global_position
		var mv = brain.get("mv") if boss else e.get("_mv")
		if r.init and st != int(r.st) and mv is Dictionary and not (mv as Dictionary).is_empty():
			if st == Enemy.EState.WINDUP:
				audio.move_sfx(mv, "wind", pos, boss)
			elif st == Enemy.EState.STRIKE and not SHOT_KINDS.has(String((mv as Dictionary).get("kind", ""))):
				# TIRO não: o projétil já soa (charge_* do VFX7 + proj_fire). Só corpo a corpo.
				audio.move_sfx(mv, "strike", pos, boss)
		# voador derrubado (cai): borda de _downed 0 → > 0
		var dn: float = float(e.get("_downed")) if e.get("_downed") != null else 0.0
		if r.init and dn > 0.0 and float(r.get("dn", 0.0)) <= 0.0 and float(e.get("fly_height")) > 0.0:
			audio.play_sfx_at("fly_fall", pos)
		# fúria do Campeão
		var fury: bool = bool(e.get("_champ_fury"))
		if r.init and fury and not bool(r.get("fury", false)):
			audio.play_sfx_at("champion_fury", pos)
		if boss:
			_boss(r, e, brain, st, pos)
		r.st = st
		r.dn = dn
		r.fury = fury

	func _boss(r: Dictionary, e, brain, st: int, pos: Vector2) -> void:
		# pouso do salto: _airborne true → false (vivo)
		var air: bool = bool(brain.get("_airborne"))
		if r.init and bool(r.get("air", false)) and not air and not bool(brain.get("_dead")):
			audio.play_sfx_at("bs_land", pos)
		r.air = air
		# quebra de guarda: a postura volta CHEIA no mesmo quadro em que ele fica
		# atordoado longo (o aparo atordoa 1,1 s; a quebra, 1,5 s)
		var poise: float = float(brain.get("_poise"))
		var ph: int = int(brain.get("phase"))
		if r.init and poise > float(r.get("poise", poise)) and st == Enemy.EState.STAGGER \
				and float(e.get("attack_timer")) > BREAK_MIN_T and ph == int(r.get("ph", ph)) \
				and float(brain.get("_roar_t")) <= 0.0 and int(brain.get("_dying")) < 0:
			audio.play_sfx_at("guard_break", pos)
		r.poise = poise
		r.ph = ph
		# olho do Rei (ponto fraco): o Rei tem uma hurtbox própria do olho
		if not bool(r.get("eye", false)):
			var box = brain.get("_eye_box")
			if box != null and is_instance_valid(box) and (box as Object).has_signal("hit_received"):
				(box as Object).connect("hit_received", func(_d, _s, _k, _u, _a) -> void:
					if is_instance_valid(brain) and bool(brain.get("_low")):
						var orb = e.get("_orb")
						audio.play_sfx_at("eye_hit", (orb as Node2D).global_position if orb is Node2D else pos))
				r.eye = true

	# --- Sophia --------------------------------------------------------------
	func _player(r: Dictionary, p) -> void:
		# 2º pulo, carga da Queda Estelar e golpe do contra-ataque NÃO são daqui:
		# o player.gd já toca jump/dive/swing nesses momentos e o dono TROCA na
		# fonte (Guardião, auditoria do 634bc91: observar aqui = som dobrado).
		# Só o pouso da Queda fica: é camada POR BAIXO da `nova` (sem baque próprio).
		var dive: bool = false
		var cm = p.get("current_move")
		if cm != null and int(p.get("state")) == Player.State.ATTACK:
			dive = bool(cm.get("air")) and cm.has_method("is_heavy") and bool(cm.call("is_heavy"))
		var landed: bool = dive and bool(p.get("dive_landed"))
		if r.init and landed and not bool(r.get("land", false)):
			audio.play_sfx("star_impact")
		r.land = landed

	# --- perigos do level6 (só os eventos hoje MUDOS) ---------------------------
	func _hazard(r: Dictionary, h) -> void:
		var pos: Vector2 = (h as Node2D).global_position
		var cam := get_viewport().get_camera_2d() if get_viewport() != null else null
		var far: bool = cam != null and absf(pos.x - cam.get_screen_center_position().x) > WATCH_FAR
		var k: String = r.k
		if not r.has("cm"):
			r.cm = (h.get_script() as Script).get_script_constant_map()
		var cm: Dictionary = r.cm
		match k:
			"MirrorBeam":
				var c: float = float(h.call("_cycle", float(cm.get("PERIOD", 3.0))))
				var on: bool = c >= float(cm.get("ON_AT", 1.8))
				if r.init and on != bool(r.get("on", on)) and not far:
					audio.play_sfx_at("hz_beam_on" if on else "hz_beam_off", pos)
				r.on = on
			"MirrorPlatform":
				var sol: bool = bool(h.get("_solid"))
				if r.init and sol != bool(r.get("sol", sol)) and not far:
					audio.play_sfx_at("hz_mirror_flip", pos)
				r.sol = sol
			"MistPatch":
				var den: float = float(h.call("density")) if h.has_method("density") else \
					0.5 + 0.5 * sin(float(h.call("_cycle", float(cm.get("PERIOD", 6.0)))) / float(cm.get("PERIOD", 6.0)) * TAU)
				var thick: bool = den >= float(cm.get("THICK", 0.5))
				if r.init and thick and not bool(r.get("thick", thick)) and not far:
					audio.play_sfx_at("hz_mist_breath", pos)
				r.thick = thick
			"SinkingPlatform":
				var s: String = String(h.get("_state"))
				var was: String = String(r.get("s", s))
				if r.init and s != was and not far:
					if s == "sinking":
						audio.play_sfx_at("hz_sink_start", pos)
					elif s == "rest" and was == "sunk":
						audio.play_sfx_at("hz_sink_return", pos)
				r.s = s
			"SporePod":
				if not bool(h.get("_dead")):
					var c2: float = float(h.call("_cycle", float(cm.get("PERIOD", 4.2))))
					var sw: bool = c2 >= float(cm.get("SWELL_AT", 2.4)) and c2 < float(cm.get("BURST_AT", 3.2))
					if r.init and sw and not bool(r.get("sw", sw)) and not far:
						audio.play_sfx_at("hz_spore_swell", pos)
					r.sw = sw
			"ShardFall":
				var warn_t: float = float(cm.get("WARN", 0.8))
				var drops = h.get("_drops")
				if drops is Array:
					var nd: int = (drops as Array).size()
					for d in drops:
						if not (d is Dictionary):
							continue
						var at := Vector2(float(d.get("x", pos.x)), pos.y)
						var t: float = float(d.get("t", 0.0))
						# cada caco é um Dictionary vivo: a marca "_aud" guarda o que já soou
						var done: int = int(d.get("_aud", 0))
						if done < 1:
							d["_aud"] = 1
							if not far:
								audio.play_sfx_at("hz_shard_warn", at)
						elif done < 2 and t >= warn_t:
							d["_aud"] = 2
							if not far:
								audio.play_sfx_at("hz_shard_fall", at)
					r.nd = nd
			"SilenceField":
				var ins: bool = bool(h.get("_inside"))
				if r.init and not ins and bool(r.get("ins", false)):
					audio.play_sfx("hz_silence_out")
				r.ins = ins
			"SecretMark":
				var dj: bool = bool(h.get("_has_dj"))
				if r.init and dj and not bool(r.get("dj", dj)) and not far:
					audio.play_sfx_at("hz_secret_mark", pos)
				r.dj = dj
			"Guillotine":
				var c3: float = float(h.call("_cycle", float(cm.get("PERIOD", 3.2))))
				var up: bool = c3 >= float(cm.get("STUCK_END", 3.0))
				if r.init and up and not bool(r.get("up", up)) and not far:
					audio.play_sfx_at("hz_winch", pos)
				r.up = up
			"DarkTide":
				var tc: float = float(h.get("_tick_cd"))
				if r.init and bool(h.get("_running")) and tc > float(r.get("tc", tc)) + 0.05:
					audio.play_sfx("hz_tide_tick")   # é a Sophia sendo corroída (centro)
				r.tc = tc
			"WardLight":
				var armed: bool = bool(h.get("_armed"))
				if r.init and armed and not bool(r.get("armed", armed)):
					audio.play_sfx("zone_objective")
				r.armed = armed
				if armed and bool(h.get("_drain_now")) and not far:
					audio.play_sfx_at("hz_ward_drain", pos)   # anti-spam próprio de 250 ms
			"SummonTotem":
				var armed2: bool = bool(h.get("_armed"))
				if r.init and armed2 and not bool(r.get("armed", armed2)):
					audio.play_sfx("zone_objective")
					audio.play_sfx_at("hz_totem_arm", pos)
				r.armed = armed2

	# --- HUD: selo aberto (o aviso do grau novo é um toast sem som) -------------
	func _hud() -> void:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud == null or not ("_tier_seen" in hud):
			_hud_prev = -1
			return
		var t: int = int(hud.get("_tier_seen"))
		var rm := get_node_or_null("/root/RunManager")
		var real: bool = rm != null and bool(rm.get("run_active")) and not CodexSession.active
		if _hud_prev >= 0 and t > _hud_prev and real:
			audio.play_sfx("shop_seal")
		_hud_prev = t
