# Áudio do GNOSIS — estado, mixagem e catálogo

> Diretor de Áudio, Onda 1 (17/10/2026), branch `dir/audio`. Tudo aqui é
> CC0 / CC-BY / síntese própria (créditos: `assets/LICENSES.md`). Sem IA paga,
> sem MusicGen/AudioCraft. Pipeline reprodutível em `tools/audio_synth/`.

## ESTADO PARA A PRÓXIMA SESSÃO

**Feito (commitado em `dir/audio`):**
- Auditoria + mixagem de TODO o áudio (tabela antes/depois no fim). Música em −16 LUFS integrado
  (eram de −8 a −27!), true peak ≤ −1 dBTP; ambiências −28 (Silêncio −31); SFX por categoria (M-max).
- **Emenda dos loops de música consertada**: ponto de loop achado por similaridade (croma+MFCC+ataques),
  ajuste fino de fase e crossfade compensado por correlação. Antes: o fim era fade/acorde final e voltava
  'do nada' (degrau de até +40 dB na volta). Agora: degrau ≤ ~6 dB (variação musical normal), sem salto.
  Algumas faixas pulam a introdução no loop (ver `tools/audio_synth/music_loops.json`).
- **9 ambiências sintetizadas** (7 Éons + Limiar + Centro), loop perfeito por construção, player próprio
  com crossfade de 2,5 s, escolhidas sozinhas pela tela (Arconte: −5 dB; Mente: nenhuma).
- **Magias/projéteis/nova/faísca REFEITOS DO ZERO por síntese** (retorno do João: "bem paia"),
  3 opções de cada geradas, escolhida a opção 2 (meio-termo) — ver §Magias. Faísca: tilintar
  pentatônico que SOBE a escala quando coletada em sequência.
- Stinger de chefe (`boss_appear`), camadas de coro em `boss_die`/`level_clear`/`ring_gain`, surto em `boss_phase2`.
- Variações (`nome_2`, `nome_3`) dos eventos frequentes + sorteio sem repetir no `audio_manager.gd`.
- Sons do contrato: `step`, `step_heavy`, `cloth`, `boss_step`, `blip_*` (5 falantes × 4 sílabas),
  `ui_move`/`ui_confirm`/`ui_back`/`ui_open`; e os 5 da cena do Rei: `fog_swell`, `king_step` (3),
  `mask_light`, `voice_merge`, `whisper`.
- `audio_manager.gd`: buses Music/Ambience/SFX/UI/Voice, limitador no Master, ducking automático em
  DialogueBox/Cinematic + `duck(on)`, API da Narrativa (`play_music(t, loop, pitch)`, `set_music_pitch`,
  `duck_music(s, db)`, `set_music_layer_volume(t)`), `play_blip(falante)`. Volume padrão 1ª execução:
  Master 0,7, Música 0,6 (pedido do João).

**Falta / problemas conhecidos (honesto):**
- **Ninguém OUVIU nada ainda.** Avaliei só por medição e espectrograma (`tools/audio_synth/spectro.py`).
  O João precisa ouvir as amostras (lista no relatório) — principalmente magias, blips e ambiências.
- **AudioQA: 1 falha aberta** — `duck(): música -4.4 → -4.4 → -4.4 dB`: no teste headless o tween do
  `duck(true/false)` não muda o bus (o `duck_music()` com o mesmo padrão PASSA, e o DialogueBox liga o
  estado `is_ducked()` corretamente). Investigar `_update_duck`/`_set_duck` (suspeita: o tween é criado
  mas não roda/é morto; testar com print dentro de `_set_duck`). Até lá o ducking de diálogo pode não
  abaixar a música de fato.
- Tema do menu NÃO foi refeito (Gregorian Chant serve; a Narrativa disse que `theme` vira o tema da Voz).
- Faísca/orbe: o som de COLETA toca pelo sinal de Progression (já existia). Um som de orbe **chegando**
  em Sophia e de **estouro** quando o orbe sai precisa de 1 linha em `spark_orb.gd` (pedido em
  `docs/pedidos/audio.md`).
- `save_manager.gd` usa 0,9/0,7 como fallback de volume quando o save não tem a chave — pedir ao
  Técnico pra igualar a 0,7/0,6 (pedido feito).
- Ninguém chama ainda: `step_heavy`, `cloth`, `boss_step`, `blip_*`, `ui_open`, os 5 da cena do Rei (os
  outros diretores vão ligar).

**Próximos passos exatos:** (1) consertar o teste/efeito do `duck()`; (2) João ouve `_caps/audio/opcoes/`
e escolhe opção por magia → mudar `CHOICE` em `tools/audio_synth/magic.py` e rodar
`python tools/audio_synth/build_sfx.py cast_solar ...`; (3) rodar AudioQA; (4) playtest com som real.

**Como validar (SEMPRE com `--audio-driver Dummy` — não tocar nos alto-falantes):**
```
& $godot --headless --audio-driver Dummy --path . --editor --quit          # zero SCRIPT ERROR
& $godot --headless --audio-driver Dummy --path . "res://tools/AudioQA.tscn" --quit-after 2000
python tools/audio_synth/measure.py assets/audio saida.json                  # loudness de tudo
```

## Pipeline (`tools/audio_synth/`)

| Script | Faz |
|---|---|
| `common.py` | I/O, loudness BS.1770-4 (bate com o ffmpeg ebur128 em ±0,1 LU), limitador, síntese (sino modal, metal, voz por formantes, reverb linear e circular) |
| `build_sfx.py` | todos os SFX: packs + camadas, variações, normalização por categoria |
| `magic.py` | magias, projéteis, nova, faísca (síntese; `python magic.py` grava as 3 opções em `_caps/audio/opcoes/`) |
| `story.py` | SFX da cena do Rei (síntese) |
| `build_music.py` | masteriza as músicas a partir dos MP3 originais, acha e costura o loop |
| `build_ambience.py` | ambiências periódicas (loop perfeito por construção) |
| `measure.py` · `seam_clips.py` · `spectro.py` | medição, clipes da emenda, mosaico de espectrogramas |

Packs brutos: fora do git, `GNOSIS_PACKS` (padrão: `assets/_packs` da cópia original).

## Mixagem

- **Música:** −16 LUFS integrado, TP ≤ −1 dBTP; se o limitador precisaria cortar > 3 dB nos picos, a faixa
  fica mais baixa (Rei −20,5, Roubo −19,4) em vez de esmagada. Silêncio −17,5 (quase silêncio).
- **Ambiência:** −28 LUFS integrado (Silêncio −31). Segue o slider de Música.
- **SFX:** alvo de *maior loudness momentânea* (M-max, mono medido como dual-mono) por categoria;
  teto −1 dBFS com limitador. Golpe −12, pesado −10, swing −18, passo −20 (o player toca a −6 dB),
  magia −13 (Coroa −11), chefe −10, UI −22, ui_move −27, blip −25, faísca −25, legenda −30.
  Transientes muito curtos (passo, soco) ficam 1–4 dB abaixo do alvo porque o teto de pico manda.
- **Buses:** Master (HardLimiter −0,5 dB) ← Music, Ambience, SFX ← (UI, Voice). UI = `ui_*`, `shop_*`,
  `subtitle_tick`; Voice = `blip_*` (monofônico). Sliders: Master, SFX (inclui UI/Voz), Música (inclui ambiência).
- **Ducking:** DialogueBox/Cinematic na árvore → música −9 dB, ambiência −5 dB (entra 0,25 s, sai 0,8 s).

## API do `Audio` (compatível com a antiga)

`play_sfx(nome, pitch_var=-1, volume_db=0)` · `play_sfx_at(nome, pos)` · `play_music(faixa, loop=true, pitch=1.0)` ·
`stop_music(fade)` · `set_music_pitch(p, fade=1)` · `duck_music(segundos, db=-12)` · `set_music_layer_volume(t, faixa='')` ·
`play_ambience(nome, volume_db=0)` · `stop_ambience(fade)` · `duck(on)` · `is_ducked()` · `play_blip(falante)` ·
`blip_for_speaker(falante)` · `has_sfx/has_music/has_ambience` · `variants_of(nome)` · `set_volume(bus, linear)` ·
`track_for_screen(tela)` · `ambience_for_screen(tela)` · `play_sfx_pitched(nome, tom, dB)` · `voice_theme(modo)` ·
`cue(nome)` · `ring_note(i, devolvendo)` · `menu_track()` · `shutdown()`.

### Tema da Voz e API das cenas (Onda 2 — ROTEIRO §2 e §5 #8)

`theme` (Gregorian Chant) é o **tema da Voz**. Quem encena chama:

| Chamada | Quando | O que faz |
|---|---|---|
| `Audio.voice_theme("santuario")` | antes da conversa do santuário | `theme` entra em 2 s, 3 dB abaixo (+ ducking do diálogo = −12 dB) |
| `Audio.voice_theme("")` | depois da conversa | volta à música da tela (Éon/Arconte/Provação) |
| `Audio.cue(line.get("cue", ""))` | a cada fala mostrada (`DialogueBox.line_shown`) | som do `cue` (tabela abaixo); devolve false se o cue é desconhecido |
| `Audio.ring_note(i, devolvendo)` | cada gema que voa (roubo, i = 0..6) / volta (anagnórise) | `ring_steal` +1 semitom por gema / `ring_gain` −1 semitom por gema |
| `Audio.play_sfx("clap")` | roubo #4 (sem cue) | 2 palmas secas e lentas em sala de pedra |

| `cue` | Som |
|---|---|
| `heartbeat` | `heartbeat` (2 batidas abafadas) |
| `fog_thickens` | `fog_swell` + música −8 dB ("desce a 40 %") até `king_emerges` ou a troca de tela |
| `king_emerges` | `king_step`; na tela do Rei também `boss_appear` −8 dB e a música volta em 2 s |
| `mask_lights` / `mask_cracks` | `mask_light` / `block` −4 dB (estalo seco) |
| `king_sinks` | `fog_swell` a 0,8 de tom |
| `chime` | `stele_unlock` −6 dB |
| `music_stop` | para a música em 1,5 s |
| `voice_merge` | `voice_merge` |
| `rings_fly` | nada (o som é por gema: `ring_note`) |
| `mask_falls` | `voice_theme("roubo")`: corte seco para `theme` a 0,75 por 3 s REAIS → corte seco para `roubo` (sem loop) |
| `sink` | `dive` + `boss_step` −2 dB + `fog_swell` a 0,6 −4 dB + música para em 2 s |
| `rings_return` | corte seco da música |
| `flash` | `nova` + `ring_gain` −3 dB |
| `colossus_shrinks` | `child_breath` |
| `theme_alone` | `voice_theme("sozinha")`: `theme` a 0,85, entra em 4 s |
| `reclaim` | `revive` −4 dB |
| `wait_2s` | nada (é da UI) |

Em `roubo`/`sozinha` o ducking de diálogo vale só 35 % (~−3 dB): ali a música É a cena. Trocar de tela,
voltar ao menu ou abrir a Provação desfaz tudo (cancela o corte agendado, solta abaixadas de cena).
O AudioQA confere que todo `cue` usado em `narrative.gd` é tratado. Os sons batem com os que a Staging
(`scripts/levels/staging.gd`, Encenação) já escolheu — quem encena pode chamar `Audio.cue` OU tocar direto,
nunca os dois (dobra o som).

**Centro:** `centro` só entra no 1º caco; camada = 0,35 + 0,65·cacos/6 (1 caco ≈ −9,8 dB … 6 = 0 dB) — a
mesma curva do `level.gd` (`_restore_echo`), para os dois não brigarem.

**Tema do menu:** o menu toca `menu` se `music/menu.ogg` existir (faixa opcional, `OPTIONAL_MUSIC`), senão
`theme`. As opções sintetizadas estão em `tools/audio_synth/menu_theme.py` (ver ESTADO).

Falantes → voz: Sophia → `blip_sophia`; O Rei, Yaldabaoth e os 7 Arcontes → `blip_rei`; A Voz, Soter, ??? →
`blip_voz`; Estela → `blip_estela`; resto → `blip_npc`. A UI chama `Audio.play_blip(speaker)` a cada
caractere visível (ou a cada 2) — a sílaba nova corta a anterior; anti-spam de 40 ms.

## Magias (refeitas por síntese)

Estrutura: ATAQUE → CORPO tonal na nota do Anel → CAUDA (reverb/brilho). Opção escolhida: `CHOICE` em `magic.py`.

| Som | Nota | Timbre |
|---|---|---|
| `sfx/cast_solar.ogg` | Mi maior | fwump de luz + pad morno + faíscas de cristal subindo |
| `sfx/cast_torpor.ogg` | Ré | sopro abafado, sinos de caixinha caindo de tom, coro 'u' bocejando |
| `sfx/cast_fome.ogg` | Mi | sucção ressonante subindo → 2 mordidas mastigadas + rosnado 'a→o' |
| `sfx/cast_corrente.ogg` | Fá | elos chacoalhando acelerados → cadeado de metal afinado + soco |
| `sfx/cast_silencio.ogg` | Sol | inspiração + coro subindo e CORTE seco → baque surdo e zumbido de ouvido |
| `sfx/cast_espelho.ogg` | Lá | cristal ao contrário (o reflexo) → cristal real do outro lado + eco pingue-pongue |
| `sfx/cast_praga.ogg` | Si♭ | gosma em formante, bolhas que estouram, enxame miúdo, zumbido desafinado |
| `sfx/cast_coroa.ogg` | Dó | estrondo + coro masculino grave 'o→a' + metal + sinos dourados |
| `sfx/cast_fail.ogg` | — | chiado seco que desce e morre (sem sino) |
| `sfx/proj_fire / proj_hit` | — | zip de luz / estouro brilhante + sino curto (3 variações cada) |
| `sfx/nova.ogg` | — | baque + onda de ruído que se afasta e abre no estéreo + ping |
| `sfx/spark.ogg` | Mi pent. | tilintar cristalino (fundamental + parcial de taça + 5ª), ataque de 4 ms, 5 alturas |

## Catálogo (todos os arquivos)

Fonte: **S** = síntese própria · **P+S** = pack + camada sintetizada · **P** = pack CC0/CC-BY.
Var = nº de arquivos (`nome`, `nome_2`...). M-max = loudness momentânea máx. do arquivo principal.

| Arquivo | Fonte | Var | M-max | Novo? |
|---|---|---|---|---|
| `sfx/swing_light.ogg` | P | 3 | -18.6 |  |
| `sfx/swing_heavy.ogg` | P | 3 | -18.4 |  |
| `sfx/swing_air.ogg` | P | 1 | -18.0 |  |
| `sfx/launcher.ogg` | P+S | 1 | -16.2 |  |
| `sfx/dive.ogg` | P | 1 | -16.2 |  |
| `sfx/hit.ogg` | P+S | 3 | -13.9 |  |
| `sfx/hit_heavy.ogg` | P+S | 3 | -11.9 |  |
| `sfx/parry.ogg` | P+S | 1 | -13.1 |  |
| `sfx/block.ogg` | P | 3 | -13.7 |  |
| `sfx/dodge.ogg` | P | 1 | -20.3 |  |
| `sfx/dodge_perfect.ogg` | P | 1 | -13.9 |  |
| `sfx/jump.ogg` | P | 1 | -20.0 |  |
| `sfx/land.ogg` | P | 2 | -20.0 |  |
| `sfx/step.ogg` | P | 3 | -24.2 |  |
| `sfx/rooted.ogg` | P | 1 | -13.0 |  |
| `sfx/player_hurt.ogg` | P | 1 | -15.2 |  |
| `sfx/player_die.ogg` | P | 1 | -13.0 |  |
| `sfx/step_heavy.ogg` | P+S | 3 | -22.0 | novo |
| `sfx/cloth.ogg` | P | 3 | -26.0 | novo |
| `sfx/boss_step.ogg` | P+S | 3 | -14.2 | novo |
| `sfx/cast_solar.ogg` | S | 1 | -13.0 |  |
| `sfx/cast_torpor.ogg` | S | 1 | -13.0 |  |
| `sfx/cast_fome.ogg` | S | 1 | -13.2 |  |
| `sfx/cast_corrente.ogg` | S | 1 | -13.0 |  |
| `sfx/cast_silencio.ogg` | S | 1 | -13.0 |  |
| `sfx/cast_espelho.ogg` | S | 1 | -13.3 |  |
| `sfx/cast_praga.ogg` | S | 1 | -13.0 |  |
| `sfx/cast_coroa.ogg` | S | 1 | -11.0 |  |
| `sfx/cast_fail.ogg` | S | 1 | -20.0 |  |
| `sfx/enemy_hurt.ogg` | P | 3 | -17.0 |  |
| `sfx/enemy_die.ogg` | P | 1 | -15.0 |  |
| `sfx/elite_die.ogg` | P | 1 | -13.0 |  |
| `sfx/champion_die.ogg` | P | 1 | -12.0 |  |
| `sfx/boss_appear.ogg` | P+S | 1 | -10.2 |  |
| `sfx/boss_phase2.ogg` | P+S | 1 | -10.0 |  |
| `sfx/boss_die.ogg` | P+S | 1 | -10.3 |  |
| `sfx/revive.ogg` | P | 1 | -14.0 |  |
| `sfx/form_revive.ogg` | P | 1 | -14.0 |  |
| `sfx/proj_fire.ogg` | S | 3 | -18.0 |  |
| `sfx/proj_hit.ogg` | S | 3 | -16.8 |  |
| `sfx/nova.ogg` | S | 1 | -12.2 |  |
| `sfx/gib_bounce.ogg` | P | 1 | -26.2 |  |
| `sfx/chest_hit.ogg` | P | 2 | -18.1 |  |
| `sfx/chest_open.ogg` | P | 1 | -16.3 |  |
| `sfx/sleeper_wake.ogg` | P | 1 | -14.0 |  |
| `sfx/seal_right.ogg` | P | 1 | -16.0 |  |
| `sfx/seal_wrong.ogg` | P | 1 | -21.7 |  |
| `sfx/seal_solved.ogg` | P | 1 | -14.0 |  |
| `sfx/portal_open.ogg` | P | 1 | -14.0 |  |
| `sfx/portal_enter.ogg` | P | 1 | -14.0 |  |
| `sfx/zone_lock.ogg` | P | 1 | -15.1 |  |
| `sfx/zone_clear.ogg` | P | 1 | -15.2 |  |
| `sfx/level_clear.ogg` | P+S | 1 | -13.2 |  |
| `sfx/spark.ogg` | S | 5 | -25.0 |  |
| `sfx/weapon_upgrade.ogg` | P | 1 | -13.0 |  |
| `sfx/ring_gain.ogg` | P+S | 1 | -13.0 |  |
| `sfx/ring_steal.ogg` | P | 1 | -13.0 |  |
| `sfx/shard.ogg` | P | 1 | -20.9 |  |
| `sfx/stele_open.ogg` | P | 1 | -18.8 |  |
| `sfx/stele_unlock.ogg` | P | 1 | -18.0 |  |
| `sfx/subtitle_tick.ogg` | P | 1 | -30.0 |  |
| `sfx/shop_buy.ogg` | P | 1 | -18.3 |  |
| `sfx/shop_fail.ogg` | P | 1 | -22.0 |  |
| `sfx/ui_click.ogg` | P | 1 | -27.5 |  |
| `sfx/ui_move.ogg` | P | 1 | -27.8 |  |
| `sfx/ui_advance.ogg` | P | 1 | -22.0 |  |
| `sfx/ui_choice.ogg` | P | 1 | -18.0 |  |
| `sfx/ui_confirm.ogg` | P | 1 | -22.0 |  |
| `sfx/ui_back.ogg` | P | 1 | -24.4 |  |
| `sfx/ui_open.ogg` | S | 1 | -22.0 | novo |
| `sfx/blip_voz.ogg` | S | 4 | -25.0 | novo |
| `sfx/blip_rei.ogg` | S | 4 | -25.0 | novo |
| `sfx/blip_sophia.ogg` | S | 4 | -25.0 | novo |
| `sfx/blip_estela.ogg` | S | 4 | -25.0 | novo |
| `sfx/blip_npc.ogg` | S | 4 | -25.0 | novo |
| `sfx/fog_swell.ogg` | S | 1 | -17.0 | novo |
| `sfx/king_step.ogg` | P+S | 3 | -15.0 | novo |
| `sfx/mask_light.ogg` | S | 1 | -17.0 | novo |
| `sfx/voice_merge.ogg` | S | 1 | -15.0 | novo |
| `sfx/whisper.ogg` | S | 1 | -21.0 | novo |
| `sfx/heartbeat.ogg` | S | 1 | -18.0 | onda 2 |
| `sfx/clap.ogg` | S | 1 | -15.2 | onda 2 |
| `sfx/child_breath.ogg` | S | 1 | -21.0 | onda 2 |

| Música | Faixa (Kevin MacLeod) | Loop (s) | Alvo LUFS |
|---|---|---|---|
| `music/theme.ogg` | Gregorian Chant | 6.97 → 173.69 | -16.0 |
| `music/rei.ogg` | Lord of the Land | 12.77 → 102.77 | -20.4 |
| `music/eon_torpor.ogg` | Ossuary 1 - A Beginning | 2.09 → 112.97 | -16.0 |
| `music/eon_fome.ogg` | Ritual | 39.47 → 214.94 | -16.0 |
| `music/eon_corrente.ogg` | Oppressive Gloom | 7.43 → 170.14 | -16.0 |
| `music/eon_silencio.ogg` | Ossuary 5 - Rest | 11.38 → 183.92 | -17.5 |
| `music/eon_espelho.ogg` | Ossuary 6 - Air | 38.08 → 227.12 | -16.0 |
| `music/eon_praga.ogg` | Unseen Horrors | 0.23 → 234.02 | -16.1 |
| `music/eon_coroa.ogg` | Crossing the Chasm | 3.25 → 166.45 | -16.0 |
| `music/boss.ogg` | Volatile Reaction | 29.72 → 132.69 | -16.0 |
| `music/roubo.ogg` | Anguish | sem loop | -19.4 |
| `music/centro.ogg` | Echoes of Time | 3.25 → 260.71 | -16.0 |
| `music/mente.ogg` | Night of Chaos | 5.34 → 126.87 | -16.0 |
| `music/epilogo.ogg` | Bittersweet | 13.0 → 112.0 | -16.0 |

| Ambiência | Onde | Caráter |
|---|---|---|
| `amb/amb_torpor.ogg` | Éon 1 | sub que respira, sopro, caixinha de música abafada, coro 'u' |
| `amb/amb_fome.ogg` | Éon 2 | pulso lub-dub, vento em osso, 2ª menor grave, roer |
| `amb/amb_corrente.ogg` | Éon 3 | pedal de órgão, bigorna/elos a cada 4 s, vento de masmorra |
| `amb/amb_silencio.ogg` | Éon 4 | ar branco, harmônicos de vidro, sino muito longe |
| `amb/amb_espelho.ogg` | Éon 5 | pad prateado + gêmeo desafinado, sinos ao contrário respondidos do outro lado |
| `amb/amb_praga.ogg` | Éon 6 | enxame, drone doente, gemidos de coro 'o' |
| `amb/amb_coroa.ogg` | Éon 7 | coro em Ré maior com nota rachada, metal grave, sinos de catedral |
| `amb/amb_limiar.ogg` | tela do Rei | salão oco, sino que dobra a cada 16 s |
| `amb/amb_centro.ogg` | O Centro | coração lento, harpa de vidro com 7 notas (uma por Éon) |

## Loudness antes → depois (medido com `measure.py`)

I = integrado (LUFS) · M = M-max · TP = true peak (dBTP) · emenda = degrau de nível na volta do loop (dB).

| Arquivo | I antes | I depois | M antes | M depois | TP antes | TP depois | emenda antes | emenda depois |
|---|---|---|---|---|---|---|---|---|
| amb/amb_centro.ogg | — | -28.0 | — | -25.2 | — | -13.0 |  | 2.4 |
| amb/amb_coroa.ogg | — | -28.0 | — | -25.2 | — | -16.3 |  | -0.4 |
| amb/amb_corrente.ogg | — | -28.0 | — | -26.0 | — | -15.0 |  | 0.9 |
| amb/amb_espelho.ogg | — | -28.0 | — | -24.8 | — | -16.0 |  | -4.2 |
| amb/amb_fome.ogg | — | -28.1 | — | -26.6 | — | -14.5 |  | 0.7 |
| amb/amb_limiar.ogg | — | -28.1 | — | -25.9 | — | -17.3 |  | -3.2 |
| amb/amb_praga.ogg | — | -28.1 | — | -27.3 | — | -14.8 |  | -0.0 |
| amb/amb_silencio.ogg | — | -31.1 | — | -27.0 | — | -19.4 |  | 1.0 |
| amb/amb_torpor.ogg | — | -28.0 | — | -25.8 | — | -15.2 |  | -0.1 |
| music/boss.ogg | -8.0 | -16.0 | -3.0 | -10.6 | 1.7 | -5.8 | 39.9 | 3.7 |
| music/centro.ogg | -15.4 | -16.0 | -7.7 | -8.5 | -0.2 | -1.4 | 19.5 | 0.6 |
| music/eon_coroa.ogg | -12.9 | -16.1 | -7.6 | -10.8 | 0.7 | -2.5 | 34.5 | -0.6 |
| music/eon_corrente.ogg | -17.4 | -16.1 | -11.3 | -10.6 | -1.7 | -1.2 | 29.1 | 1.5 |
| music/eon_espelho.ogg | -22.5 | -16.0 | -14.5 | -9.0 | -6.5 | -1.4 | 6.3 | -6.2 |
| music/eon_fome.ogg | -17.3 | -16.0 | -10.0 | -9.1 | 0.2 | -1.3 | -2.4 | -3.2 |
| music/eon_praga.ogg | -27.1 | -16.2 | -17.7 | -8.9 | -8.3 | -0.3 | 5.4 | -0.3 |
| music/eon_silencio.ogg | -18.1 | -17.5 | -12.6 | -12.0 | -2.6 | -1.8 | 27.2 | 1.6 |
| music/eon_torpor.ogg | -19.9 | -16.0 | -11.5 | -9.1 | -3.8 | -1.4 | 25.4 | -3.0 |
| music/epilogo.ogg | -16.3 | -16.0 | -11.0 | -10.6 | -2.6 | -2.3 | 5.7 | -2.9 |
| music/mente.ogg | -24.1 | -16.0 | -16.9 | -9.9 | -8.2 | -1.5 | 5.9 | -0.1 |
| music/rei.ogg | -24.1 | -20.5 | -18.1 | -14.7 | -2.2 | -1.3 | 31.6 | 3.3 |
| music/roubo.ogg | -22.5 | -19.4 | -11.9 | -9.2 | -1.6 | -1.3 | 16.0 | 32.4 |
| music/theme.ogg | -15.9 | -16.0 | -10.4 | -10.7 | -1.7 | -1.7 | -2.6 | 4.8 |
| sfx/blip_estela.ogg | — | -25.0 | — | -25.0 | — | -6.5 |  |  |
| sfx/blip_npc.ogg | — | -24.9 | — | -24.9 | — | -10.6 |  |  |
| sfx/blip_rei.ogg | — | -25.0 | — | -25.0 | — | -11.1 |  |  |
| sfx/blip_sophia.ogg | — | -25.0 | — | -25.0 | — | -8.9 |  |  |
| sfx/blip_voz.ogg | — | -24.9 | — | -24.9 | — | -12.5 |  |  |
| sfx/block.ogg | -18.0 | -13.7 | -18.0 | -13.7 | -2.9 | -0.9 |  |  |
| sfx/boss_appear.ogg | -15.8 | -13.2 | -13.6 | -10.2 | -2.8 | -0.7 |  |  |
| sfx/boss_die.ogg | -16.2 | -15.2 | -13.4 | -10.3 | -3.3 | -0.9 |  |  |
| sfx/boss_phase2.ogg | -12.5 | -12.8 | -11.8 | -10.0 | -3.1 | -0.7 |  |  |
| sfx/boss_step.ogg | — | -19.1 | — | -14.2 | — | -0.9 |  |  |
| sfx/cast_coroa.ogg | -18.4 | -15.8 | -14.5 | -11.0 | -2.8 | -1.4 |  |  |
| sfx/cast_corrente.ogg | -13.4 | -15.8 | -13.4 | -13.0 | -2.5 | -2.2 |  |  |
| sfx/cast_espelho.ogg | -10.6 | -16.5 | -9.7 | -13.3 | -2.7 | -0.9 |  |  |
| sfx/cast_fail.ogg | -17.6 | -20.0 | -17.6 | -20.0 | -2.6 | -8.7 |  |  |
| sfx/cast_fome.ogg | -19.1 | -15.0 | -16.9 | -13.2 | -3.2 | -0.8 |  |  |
| sfx/cast_praga.ogg | -19.7 | -16.6 | -17.9 | -13.0 | -2.8 | -1.4 |  |  |
| sfx/cast_silencio.ogg | -19.9 | -15.8 | -14.4 | -13.1 | -3.2 | -0.7 |  |  |
| sfx/cast_solar.ogg | -13.2 | -17.4 | -11.6 | -13.0 | -3.1 | -2.0 |  |  |
| sfx/cast_torpor.ogg | -19.5 | -15.7 | -16.0 | -13.0 | -3.1 | -3.7 |  |  |
| sfx/champion_die.ogg | -13.4 | -13.2 | -12.2 | -12.0 | -3.1 | -2.9 |  |  |
| sfx/chest_hit.ogg | -26.1 | -18.1 | -26.1 | -18.1 | -9.3 | -1.0 |  |  |
| sfx/chest_open.ogg | -24.1 | -16.4 | -21.1 | -16.4 | -3.0 | -1.0 |  |  |
| sfx/cloth.ogg | — | -26.1 | — | -26.1 | — | -8.6 |  |  |
| sfx/dive.ogg | -19.5 | -16.4 | -19.5 | -16.4 | -3.5 | -1.1 |  |  |
| sfx/dodge.ogg | -23.2 | -20.3 | -23.2 | -20.3 | -3.7 | -1.0 |  |  |
| sfx/dodge_perfect.ogg | -21.4 | -17.2 | -21.2 | -14.0 | -2.7 | -1.0 |  |  |
| sfx/elite_die.ogg | -15.5 | -15.2 | -13.2 | -13.0 | -3.0 | -2.7 |  |  |
| sfx/enemy_die.ogg | -16.4 | -15.6 | -15.0 | -15.0 | -3.0 | -2.8 |  |  |
| sfx/enemy_hurt.ogg | -18.0 | -17.3 | -18.0 | -17.3 | -2.2 | -3.1 |  |  |
| sfx/fog_swell.ogg | — | -20.7 | — | -17.0 | — | -6.1 |  |  |
| sfx/form_revive.ogg | -9.1 | -14.7 | -8.5 | -14.2 | -2.1 | -8.7 |  |  |
| sfx/gib_bounce.ogg | -28.3 | -26.2 | -28.3 | -26.2 | -2.9 | -0.9 |  |  |
| sfx/hit.ogg | -18.6 | -14.0 | -18.6 | -14.0 | -3.0 | -0.7 |  |  |
| sfx/hit_heavy.ogg | -16.0 | -11.9 | -16.0 | -11.9 | -2.2 | -0.6 |  |  |
| sfx/jump.ogg | -20.0 | -20.1 | -20.0 | -20.1 | -3.5 | -3.3 |  |  |
| sfx/king_step.ogg | — | -19.6 | — | -15.0 | — | -2.0 |  |  |
| sfx/land.ogg | -21.6 | -20.0 | -21.6 | -20.0 | -3.0 | -1.6 |  |  |
| sfx/launcher.ogg | -22.1 | -16.4 | -22.1 | -16.4 | -3.0 | -1.2 |  |  |
| sfx/level_clear.ogg | -24.8 | -18.6 | -20.2 | -13.3 | -3.5 | -0.9 |  |  |
| sfx/mask_light.ogg | — | -21.0 | — | -17.0 | — | -8.8 |  |  |
| sfx/nova.ogg | -15.7 | -16.3 | -13.9 | -12.3 | -3.0 | -0.4 |  |  |
| sfx/parry.ogg | -21.6 | -15.8 | -19.2 | -13.1 | -7.1 | -0.9 |  |  |
| sfx/player_die.ogg | -16.7 | -16.7 | -13.1 | -13.1 | -3.4 | -3.6 |  |  |
| sfx/player_hurt.ogg | -18.3 | -15.5 | -18.3 | -15.5 | -2.5 | -1.0 |  |  |
| sfx/portal_enter.ogg | -14.2 | -15.4 | -12.5 | -14.0 | -2.9 | -4.7 |  |  |
| sfx/portal_open.ogg | -13.9 | -17.8 | -10.0 | -14.0 | -2.7 | -6.9 |  |  |
| sfx/proj_fire.ogg | -12.5 | -18.2 | -12.5 | -18.2 | -2.8 | -4.3 |  |  |
| sfx/proj_hit.ogg | -13.3 | -16.9 | -13.3 | -16.9 | -2.4 | -0.7 |  |  |
| sfx/revive.ogg | -11.5 | -16.7 | -8.8 | -14.0 | -2.8 | -8.0 |  |  |
| sfx/ring_gain.ogg | -18.8 | -16.4 | -15.0 | -13.0 | -3.1 | -2.6 |  |  |
| sfx/ring_steal.ogg | -13.3 | -14.9 | -11.3 | -13.0 | -2.6 | -4.0 |  |  |
| sfx/rooted.ogg | -14.4 | -13.2 | -14.4 | -13.2 | -2.0 | -1.7 |  |  |
| sfx/seal_right.ogg | -19.4 | -19.2 | -16.4 | -16.0 | -2.2 | -2.0 |  |  |
| sfx/seal_solved.ogg | -18.2 | -16.8 | -15.4 | -14.1 | -3.1 | -1.4 |  |  |
| sfx/seal_wrong.ogg | -27.0 | -21.9 | -27.0 | -21.9 | -3.7 | -1.2 |  |  |
| sfx/shard.ogg | -27.1 | -21.2 | -27.1 | -21.2 | -3.8 | -1.1 |  |  |
| sfx/shop_buy.ogg | -23.5 | -19.3 | -22.1 | -18.5 | -3.4 | -1.5 |  |  |
| sfx/shop_fail.ogg | -20.0 | -22.0 | -20.0 | -22.0 | -3.0 | -5.2 |  |  |
| sfx/sleeper_wake.ogg | -11.2 | -16.0 | -9.2 | -14.0 | -2.9 | -7.5 |  |  |
| sfx/spark.ogg | -24.0 | -25.0 | -24.0 | -25.0 | -3.4 | -10.8 |  |  |
| sfx/stele_open.ogg | -27.5 | -22.0 | -23.6 | -19.0 | -3.9 | -1.0 |  |  |
| sfx/stele_unlock.ogg | -17.4 | -19.7 | -15.3 | -18.0 | -3.2 | -5.4 |  |  |
| sfx/step.ogg | -38.4 | -24.3 | -38.4 | -24.3 | -17.1 | -1.0 |  |  |
| sfx/step_heavy.ogg | — | -22.0 | — | -22.0 | — | -2.8 |  |  |
| sfx/subtitle_tick.ogg | -29.1 | -30.3 | -29.1 | -30.3 | -11.1 | -13.7 |  |  |
| sfx/swing_air.ogg | -21.1 | -18.0 | -18.7 | -18.0 | -3.3 | -2.6 |  |  |
| sfx/swing_heavy.ogg | -23.4 | -18.5 | -23.4 | -18.5 | -3.0 | -1.2 |  |  |
| sfx/swing_light.ogg | -22.9 | -18.6 | -22.9 | -18.6 | -3.1 | -0.8 |  |  |
| sfx/ui_advance.ogg | -20.6 | -22.1 | -20.6 | -22.1 | -3.0 | -5.5 |  |  |
| sfx/ui_back.ogg | -28.8 | -24.7 | -28.8 | -24.7 | -2.7 | -1.1 |  |  |
| sfx/ui_choice.ogg | -21.4 | -21.3 | -18.2 | -18.0 | -6.5 | -5.9 |  |  |
| sfx/ui_click.ogg | -38.3 | -27.9 | -38.3 | -27.9 | -14.2 | -1.1 |  |  |
| sfx/ui_confirm.ogg | -12.6 | -22.0 | -12.6 | -22.0 | -3.2 | -12.4 |  |  |
| sfx/ui_move.ogg | -36.5 | -28.1 | -36.5 | -28.1 | -9.5 | -1.5 |  |  |
| sfx/ui_open.ogg | — | -22.0 | — | -22.0 | — | -11.1 |  |  |
| sfx/voice_merge.ogg | — | -16.8 | — | -15.0 | — | -5.4 |  |  |
| sfx/weapon_upgrade.ogg | -14.0 | -15.7 | -11.4 | -13.0 | -3.1 | -4.6 |  |  |
| sfx/whisper.ogg | — | -24.2 | — | -21.3 | — | -8.2 |  |  |
| sfx/zone_clear.ogg | -23.2 | -20.1 | -18.0 | -15.2 | -2.7 | -0.7 |  |  |
| sfx/zone_lock.ogg | -19.5 | -16.6 | -18.3 | -15.2 | -3.0 | -1.3 |  |  |

(Variações `_2`, `_3` omitidas da tabela; estão no `tools/audio_synth/sfx_report.json`.)

