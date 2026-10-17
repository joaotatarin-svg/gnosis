# Licenças e créditos de áudio/VFX — GNOSIS

Todo som, música e sprite de partícula do jogo é **CC0**, **CC-BY** (atribuição
abaixo) ou **síntese própria** (código Python em `tools/audio_synth/`, sem
sample de terceiros e sem IA). Nada NC / SA / ND. MusicGen/AudioCraft NÃO são
usados. Packs brutos: fora do git (`assets/_packs/` da cópia original).

## CRÉDITOS (bloco para a tela de Créditos — cada linha "- " é uma linha)

- Música: Kevin MacLeod (incompetech.com) — Licensed under Creative Commons: By Attribution 4.0 — https://creativecommons.org/licenses/by/4.0/
- Faixas: Gregorian Chant · Lord of the Land · Ossuary 1 - A Beginning · Ritual · Oppressive Gloom · Ossuary 5 - Rest · Ossuary 6 - Air · Unseen Horrors · Crossing the Chasm · Volatile Reaction · Anguish · Echoes of Time · Night of Chaos · Bittersweet
- Efeitos sonoros: "Fantasy Sound Effects Library" — Little Robot Sound Factory (www.littlerobotsoundfactory.com) — CC-BY 3.0 — https://creativecommons.org/licenses/by/3.0/
- Efeitos CC0: Kenney (kenney.nl), rubberduck, artisticdude, remaxim, Clint Bellanger, rockseller, nosycat, StarNinjas, qubodup, MedicineStorm, Owlish Media e outros autores CC0 do OpenGameArt.org
- Ambiências, magias, vozes e camadas sintetizadas: feitas para GNOSIS
- Partículas: Kenney Particle Pack (CC0)

## Síntese própria (licença do jogo)

| Arquivo(s) | O que é |
|---|---|
| `amb/amb_*.ogg` (9) | ambiências — `build_ambience.py` |
| `sfx/cast_*` (9), `proj_fire*`, `proj_hit*`, `nova`, `spark*` | magias, projéteis, nova, faísca — `magic.py` |
| `sfx/blip_*` (5 × 4), `ui_open` | vozes "gromelô" por formantes, sino de abrir — `build_sfx.py` |
| `sfx/fog_swell`, `mask_light`, `voice_merge`, `whisper` | cena do Rei — `story.py` |
| `sfx/heartbeat`, `clap`, `child_breath` | intro, roubo e anagnórise — `story.py` (Onda 2) |
| `sfx/tell_parry`, `tell_unblock` | avisos do combate (R5) — `tells.py` (Onda 2b) |
| `sfx/boss_appear` | stinger sintetizado + rosnado LRSF (CC-BY) |
| camadas em `boss_phase2`, `boss_die`, `level_clear`, `ring_gain`, `hit_heavy*`, `step_heavy*`, `boss_step*`, `king_step*`, `launcher`, `parry` | sub-grave, coro, sino ou surto sintetizados sobre o pack |

## Packs

| Pack | Autor | Licença | URL | Uso |
|---|---|---|---|---|
| Impact Sounds | Kenney | CC0 1.0 | https://kenney.nl/assets/impact-sounds | hit (+camada metal), parry, block, land, step, step_heavy, boss_step, king_step, chest_hit |
| RPG Audio | Kenney | CC0 1.0 | https://kenney.nl/assets/rpg-audio | dodge, jump, cloth, stele_open/unlock, ui_advance, shop_buy |
| UI Audio | Kenney | CC0 1.0 | https://kenney.nl/assets/ui-audio | ui_move |
| Interface Sounds | Kenney | CC0 1.0 | https://kenney.nl/assets/interface-sounds | ui_click, ui_confirm, ui_back, shop_fail, subtitle_tick, dodge_perfect (camada) |
| Sci-Fi Sounds | Kenney | CC0 1.0 | https://kenney.nl/assets/sci-fi-sounds | (reserva — nova virou síntese) |
| Digital Audio | Kenney | CC0 1.0 | https://kenney.nl/assets/digital-audio | (reserva) |
| Music Jingles | Kenney | CC0 1.0 | https://kenney.nl/assets/music-jingles | (reserva) |
| Particle Pack | Kenney | CC0 1.0 | https://kenney.nl/assets/particle-pack | todos os PNG de `assets/vfx/` |
| Smoke Particles | Kenney | CC0 1.0 | https://kenney.nl/assets/smoke-particles | (reserva) |
| RPG Sound Pack | artisticdude | CC0 1.0 | https://opengameart.org/content/rpg-sound-pack | swing_light, launcher, champion_die, weapon_upgrade |
| 80 CC0 RPG SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/80-cc0-rpg-sfx | dive, rooted, enemy_die, shard, chest_open, stele_open, shop_buy |
| 80 CC0 creature SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/80-cc0-creature-sfx | enemy_hurt, elite_die |
| 100 CC0 SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/100-cc0-sfx | gib_bounce, chest_open, seal_right, zone_lock, ui_choice, champion_die |
| 75 CC0 breaking/falling/hit SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx | seal_wrong, boss_die |
| 50 CC0 Sci-Fi SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/50-cc0-sci-fi-sfx | (reserva) |
| Battle Sound Effects | remaxim | CC0 1.0 (multi-licença; usada a CC0) | https://opengameart.org/content/battle-sound-effects | swing_heavy, swing_air |
| Fantasy Sound Effects Library | Little Robot Sound Factory | **CC-BY 3.0** | https://opengameart.org/content/fantasy-sound-effects-library | boss_appear (camada de rosnado), boss_phase2, seal_solved |
| Magic SFX Preview Pack | Little Robot Sound Factory | CC-BY 3.0 | https://opengameart.org/content/magic-sfx-sample | (NÃO usado desde 17/10/2026) |
| Magic Spell SFX | Arcanorum | CC0 1.0 | https://opengameart.org/content/magic-spell-sfx | weapon_upgrade, ring_gain |
| Misc SFX Pack | MedicineStorm | CC0 1.0 | https://opengameart.org/content/misc-sfx-pack | hit_heavy, boss_die |
| Bell dings/chimes | (anônimo, OGA) | CC0 1.0 | https://opengameart.org/content/bell-dingschimes | dodge_perfect, zone_clear, level_clear, ring_gain, ring_steal, stele_unlock |
| Cure Magic | (anônimo, OGA) | CC0 1.0 | https://opengameart.org/content/cure-magic | revive, sleeper_wake |
| 3 dark magic spells | (anônimo, OGA) | CC0 1.0 | https://opengameart.org/content/3-dark-magic-spells | form_revive |
| Energy Drain | nosycat (qubodup) | CC0 1.0 | https://opengameart.org/content/energy-drain | player_die |
| Freeze Spell | StarNinjas | CC0 1.0 | https://opengameart.org/content/freeze-spell-0 | (reserva — cast_torpor virou síntese) |
| Teleport Spell | Clint Bellanger | CC0 1.0 | https://opengameart.org/content/teleport-spell | portal_enter |
| 4 Space / Portal Sounds | rockseller | CC0 1.0 | https://opengameart.org/content/4-space-portal-sounds | portal_open |
| Sound Effects Pack (Owlish Media) | Owlish Media | CC0 1.0 | https://opengameart.org/content/sound-effects-pack | player_hurt |
| Portal sound | WolfTech | CC0 1.0 | https://opengameart.org/content/portal-sound | (reserva) |
| Ghost Monster Voice | qubodup / shd | CC0 1.0 | https://opengameart.org/content/ghost-monster-voice-moaning-growling | (reserva) |
| Atmospheric Interaction Sound Pack | ViRiX | CC0 1.0 | https://opengameart.org/content/atmospheric-interaction-sound-pack | (reserva) |
| Chunky Explosion / Earth Element Magic Spell | looneybits | CC0 1.0 | https://opengameart.org/content/chunky-explosion · https://opengameart.org/content/earth-element-magic-spell | (reserva) |
| Fantasy Magic Spell | (anônimo, OGA) | CC0 1.0 | https://opengameart.org/content/fantasy-magic-spell | (reserva) |

## Músicas (Kevin MacLeod — incompetech.com — CC-BY 4.0)

Baixadas de `https://incompetech.com/music/royalty-free/mp3-royaltyfree/<Título>.mp3`
e masterizadas por `tools/audio_synth/build_music.py` (ponto de loop por similaridade, emenda em crossfade,
−16 LUFS, OGG q4). Pontos de loop: `tools/audio_synth/music_loops.json`.

| Arquivo | Faixa |
|---|---|
| `music/theme.ogg` | Gregorian Chant |
| `music/rei.ogg` | Lord of the Land |
| `music/eon_torpor.ogg` | Ossuary 1 - A Beginning |
| `music/eon_fome.ogg` | Ritual |
| `music/eon_corrente.ogg` | Oppressive Gloom |
| `music/eon_silencio.ogg` | Ossuary 5 - Rest |
| `music/eon_espelho.ogg` | Ossuary 6 - Air |
| `music/eon_praga.ogg` | Unseen Horrors |
| `music/eon_coroa.ogg` | Crossing the Chasm |
| `music/boss.ogg` | Volatile Reaction |
| `music/roubo.ogg` | Anguish |
| `music/centro.ogg` | Echoes of Time |
| `music/mente.ogg` | Night of Chaos |
| `music/epilogo.ogg` | Bittersweet |

Alternativas já baixadas em `_packs/incompetech/` (mesma licença): Ossuary 2 -
Turn, Dark Times, Killers, Lightless Dawn, Ghost Story, Long Note One/Two.

## SFX de pack — fontes

As receitas exatas (arquivo do pack, tom, camadas, variações) estão em
`tools/audio_synth/build_sfx.py` (`RECIPES`) e `story.py` (`king_step`). Resumo
das variações novas: `hit_2/3` (Kenney impactPunch_medium_001/003 + impactMetal_light),
`hit_heavy_2/3` (impactPunch_heavy_000/002), `swing_light_2/3` (swing2.wav, swing.wav agudo),
`swing_heavy_2/3` (swish_4.wav, swish_2.wav grave), `step_2/3` (footstep_concrete_001/002),
`step_heavy` (footstep_concrete_003/004/001 graves), `cloth` (Kenney RPG cloth3/cloth4/clothBelt),
`boss_step` (impactPlate_heavy_000/003, impactMining_001, impactGeneric_light), `block_2/3`
(impactSoft_heavy_001/002), `land_2`, `chest_hit_2`, `enemy_hurt_2/3` (rubberduck hurt_02/03),
`king_step` (footstep_concrete graves). Os demais SFX de pack mantêm as fontes da tabela de packs.

## VFX (`assets/vfx/*.png`, 128 px, Kenney Particle Pack CC0)

circle_05, light_01, light_02, spark_04, spark_06, star_07, star_09, smoke_04,
smoke_08, flame_04, flame_06, magic_03, magic_05, twirl_02, scorch_01, slash_03,
symbol_02, dirt_02, trace_06, flare_01, window_02 → renomeados em `build_assets.py`
(`VFX`).
