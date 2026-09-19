# Licenças dos assets de terceiros — GNOSIS

Todo som, música e sprite de partícula usado pelo jogo vem de packs **CC0** ou
**CC-BY** (com atribuição abaixo). Nada NC / SA / ND. Os packs brutos ficam em
`assets/_packs/` (fora do git, `.gdignore`); só o resultado montado entra em
`assets/audio/` e `assets/vfx/`. O script `assets/_packs/build_assets.py`
regera tudo a partir dos packs (corte, tom, camadas, normalização -3 dBFS).

**Como substituir um som:** gere o seu e salve por cima do arquivo com o
mesmo nome em `assets/audio/sfx/` ou `assets/audio/music/` (.ogg/.wav/.mp3).

## Texto de atribuição (copiar nos créditos do jogo)

> Música de Kevin MacLeod (incompetech.com), licenciada sob Creative Commons:
> By Attribution 4.0 — https://creativecommons.org/licenses/by/4.0/
> Efeitos sonoros: "Fantasy Sound Effects Library" e "Magic SFX Preview Pack"
> de Little Robot Sound Factory (www.littlerobotsoundfactory.com), CC-BY 3.0.
> Demais sons e sprites de partícula: Kenney (kenney.nl), rubberduck,
> artisticdude, Arcanorum, Clint Bellanger, rockseller, WolfTech, nosycat,
> StarNinjas, qubodup, ViRiX, looneybits, MedicineStorm, Owlish Media e outros
> autores CC0 do OpenGameArt.org.

## Packs

| Pack | Autor | Licença | URL | Uso |
|---|---|---|---|---|
| Impact Sounds | Kenney | CC0 1.0 | https://kenney.nl/assets/impact-sounds | hit, parry, block, land, step, chest_hit |
| RPG Audio | Kenney | CC0 1.0 | https://kenney.nl/assets/rpg-audio | dodge, jump, stele_open/unlock, ui_advance, shop_buy |
| UI Audio | Kenney | CC0 1.0 | https://kenney.nl/assets/ui-audio | ui_move |
| Interface Sounds | Kenney | CC0 1.0 | https://kenney.nl/assets/interface-sounds | ui_click, ui_confirm, ui_back, cast_fail, shop_fail, subtitle_tick, dodge_perfect (camada) |
| Sci-Fi Sounds | Kenney | CC0 1.0 | https://kenney.nl/assets/sci-fi-sounds | nova |
| Digital Audio | Kenney | CC0 1.0 | https://kenney.nl/assets/digital-audio | (reserva) |
| Music Jingles | Kenney | CC0 1.0 | https://kenney.nl/assets/music-jingles | (reserva) |
| Particle Pack | Kenney | CC0 1.0 | https://kenney.nl/assets/particle-pack | todos os PNG de `assets/vfx/` |
| Smoke Particles | Kenney | CC0 1.0 | https://kenney.nl/assets/smoke-particles | (reserva) |
| RPG Sound Pack | artisticdude | CC0 1.0 | https://opengameart.org/content/rpg-sound-pack | swing_light, launcher, champion_die, weapon_upgrade |
| 80 CC0 RPG SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/80-cc0-rpg-sfx | dive, rooted, cast_corrente, cast_praga, enemy_die, spark, shard, chest_open, stele_open, shop_buy |
| 80 CC0 creature SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/80-cc0-creature-sfx | enemy_hurt, elite_die, cast_fome |
| 100 CC0 SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/100-cc0-sfx | gib_bounce, chest_open, seal_right, zone_lock, ui_choice, champion_die |
| 75 CC0 breaking/falling/hit SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx | seal_wrong, boss_die |
| 50 CC0 Sci-Fi SFX | rubberduck | CC0 1.0 | https://opengameart.org/content/50-cc0-sci-fi-sfx | (reserva) |
| Battle Sound Effects | remaxim | CC0 1.0 (multi-licença; usada a CC0) | https://opengameart.org/content/battle-sound-effects | swing_heavy, swing_air |
| Fantasy Sound Effects Library | Little Robot Sound Factory | **CC-BY 3.0** | https://opengameart.org/content/fantasy-sound-effects-library | boss_appear, boss_phase2, seal_solved |
| Magic SFX Preview Pack | Little Robot Sound Factory | **CC-BY 3.0** | https://opengameart.org/content/magic-sfx-sample | cast_coroa |
| Magic Spell SFX | Arcanorum | CC0 1.0 | https://opengameart.org/content/magic-spell-sfx | cast_solar, cast_espelho, proj_fire, weapon_upgrade, ring_gain |
| Misc SFX Pack | MedicineStorm | CC0 1.0 | https://opengameart.org/content/misc-sfx-pack | hit_heavy, cast_silencio, proj_hit, boss_die |
| Bell dings/chimes | (anônimo, OGA) | CC0 1.0 | https://opengameart.org/content/bell-dingschimes | dodge_perfect, zone_clear, level_clear, ring_gain, ring_steal, stele_unlock |
| Cure Magic | (anônimo, OGA) | CC0 1.0 | https://opengameart.org/content/cure-magic | revive, sleeper_wake |
| 3 dark magic spells | (anônimo, OGA) | CC0 1.0 | https://opengameart.org/content/3-dark-magic-spells | form_revive |
| Energy Drain | nosycat (qubodup) | CC0 1.0 | https://opengameart.org/content/energy-drain | player_die |
| Freeze Spell | StarNinjas | CC0 1.0 | https://opengameart.org/content/freeze-spell-0 | cast_torpor |
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
e transcodificadas pra OGG (estéreo, q≈0.55, corte em 5 min com fade).

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

## SFX — arquivo final → fonte(s) no pack

| Arquivo | Fonte(s) em `assets/_packs/` |
|---|---|
| `sfx/swing_light.ogg` | `oga_rpg_artisticdude/RPG Sound Pack/battle/swing.wav` |
| `sfx/swing_heavy.ogg` | `oga_battle/battle_sound_effects/swish_2.wav` |
| `sfx/swing_air.ogg` | `oga_battle/battle_sound_effects/swish_3.wav` |
| `sfx/launcher.ogg` | `oga_rpg_artisticdude/RPG Sound Pack/battle/swing3.wav` |
| `sfx/dive.ogg` | `oga_misc/80-cc0-rpg-sfx/blade_01.ogg` |
| `sfx/hit.ogg` | `kenney_impact-sounds/Audio/impactPunch_medium_000.ogg` |
| `sfx/hit_heavy.ogg` | `oga_misc/misc-sfx-pack/HeavyHit.ogg` |
| `sfx/parry.ogg` | `kenney_impact-sounds/Audio/impactBell_heavy_001.ogg` |
| `sfx/block.ogg` | `kenney_impact-sounds/Audio/impactSoft_heavy_000.ogg` |
| `sfx/dodge.ogg` | `kenney_rpg-audio/Audio/cloth1.ogg` |
| `sfx/dodge_perfect.ogg` | `oga_misc/bell-dingschimes/bell_ding2.wav`, `kenney_interface-sounds/Audio/glass_002.ogg` |
| `sfx/jump.ogg` | `kenney_rpg-audio/Audio/cloth2.ogg` |
| `sfx/land.ogg` | `kenney_impact-sounds/Audio/impactSoft_medium_000.ogg` |
| `sfx/step.ogg` | `kenney_impact-sounds/Audio/footstep_concrete_000.ogg` |
| `sfx/rooted.ogg` | `oga_misc/80-cc0-rpg-sfx/chain_01.ogg` |
| `sfx/player_hurt.ogg` | `oga_owlish/Human/gasp1.wav` |
| `sfx/player_die.ogg` | `oga_misc/energy-drain/qubodup-PowerDrain.ogg` |
| `sfx/cast_solar.ogg` | `oga_misc/magic-spell-sfx/magical_1.ogg` |
| `sfx/cast_torpor.ogg` | `oga_misc/freeze-spell-0/freeze.wav` |
| `sfx/cast_fome.ogg` | `oga_creature_rubberduck/eat_01.ogg` |
| `sfx/cast_corrente.ogg` | `oga_misc/80-cc0-rpg-sfx/chain_02.ogg` |
| `sfx/cast_silencio.ogg` | `oga_misc/misc-sfx-pack/GhostOhh.ogg` |
| `sfx/cast_espelho.ogg` | `oga_misc/magic-spell-sfx/magical_6.ogg` |
| `sfx/cast_praga.ogg` | `oga_misc/80-cc0-rpg-sfx/creature_slime_02.ogg` |
| `sfx/cast_coroa.ogg` | `oga_magic_lrsf/Healing Full.wav` |
| `sfx/cast_fail.ogg` | `kenney_interface-sounds/Audio/error_006.ogg` |
| `sfx/enemy_hurt.ogg` | `oga_creature_rubberduck/hurt_01.ogg` |
| `sfx/enemy_die.ogg` | `oga_misc/80-cc0-rpg-sfx/creature_die_01.ogg` |
| `sfx/elite_die.ogg` | `oga_creature_rubberduck/roar_02.ogg` |
| `sfx/champion_die.ogg` | `oga_rpg_artisticdude/RPG Sound Pack/NPC/giant/giant4.wav`, `oga_100sfx_rubberduck/gong_02.ogg` |
| `sfx/boss_appear.ogg` | `oga_fantasy_lrsf/Fantasy Sound Library/Mp3/Dragon_Growl_00.mp3` |
| `sfx/boss_phase2.ogg` | `oga_fantasy_lrsf/Fantasy Sound Library/Mp3/Dragon_Growl_01.mp3` |
| `sfx/boss_die.ogg` | `oga_misc/misc-sfx-pack/BoneSplosion.ogg`, `oga_breaking_rubberduck/bfh1_rock_breaking_02.ogg` |
| `sfx/revive.ogg` | `oga_misc/cure-magic/Cure3.wav` |
| `sfx/form_revive.ogg` | `oga_misc/3-dark-magic-spells/dm.mp3` |
| `sfx/proj_fire.ogg` | `oga_misc/magic-spell-sfx/magical_4.ogg` |
| `sfx/proj_hit.ogg` | `oga_misc/misc-sfx-pack/ElectricSpark.ogg` |
| `sfx/nova.ogg` | `kenney_sci-fi-sounds/Audio/lowFrequency_explosion_000.ogg` |
| `sfx/gib_bounce.ogg` | `oga_100sfx_rubberduck/plop_01.ogg` |
| `sfx/chest_hit.ogg` | `kenney_impact-sounds/Audio/impactWood_medium_000.ogg` |
| `sfx/chest_open.ogg` | `oga_100sfx_rubberduck/wooded_box_open.ogg`, `oga_misc/80-cc0-rpg-sfx/item_gem_03.ogg` |
| `sfx/sleeper_wake.ogg` | `oga_misc/cure-magic/Cure1.wav` |
| `sfx/seal_right.ogg` | `oga_100sfx_rubberduck/bell_01.ogg` |
| `sfx/seal_wrong.ogg` | `oga_breaking_rubberduck/bfh1_rock_hit_01.ogg` |
| `sfx/seal_solved.ogg` | `oga_fantasy_lrsf/Fantasy Sound Library/Mp3/Jingle_Achievement_00.mp3` |
| `sfx/portal_open.ogg` | `oga_misc/4-space-portal-sounds/1.mp3` |
| `sfx/portal_enter.ogg` | `oga_misc/teleport-spell/teleport.wav` |
| `sfx/zone_lock.ogg` | `oga_100sfx_rubberduck/slam_02.ogg` |
| `sfx/zone_clear.ogg` | `oga_misc/bell-dingschimes/bell_ding2.wav` |
| `sfx/level_clear.ogg` | `oga_misc/bell-dingschimes/bell_ding4.wav`, `oga_misc/bell-dingschimes/bell_ding1.wav` |
| `sfx/spark.ogg` | `oga_misc/80-cc0-rpg-sfx/item_gem_01.ogg` |
| `sfx/weapon_upgrade.ogg` | `oga_rpg_artisticdude/RPG Sound Pack/inventory/metal-ringing.wav`, `oga_misc/magic-spell-sfx/magical_6.ogg` |
| `sfx/ring_gain.ogg` | `oga_misc/magic-spell-sfx/magical_6.ogg`, `oga_misc/bell-dingschimes/bell_ding3.wav` |
| `sfx/ring_steal.ogg` | `oga_misc/bell-dingschimes/bell_ding1.wav` |
| `sfx/shard.ogg` | `oga_misc/80-cc0-rpg-sfx/item_gem_02.ogg` |
| `sfx/stele_open.ogg` | `kenney_rpg-audio/Audio/bookOpen.ogg`, `oga_misc/80-cc0-rpg-sfx/stones_01.ogg` |
| `sfx/stele_unlock.ogg` | `kenney_rpg-audio/Audio/bookFlip2.ogg`, `oga_misc/bell-dingschimes/bell_ding3.wav` |
| `sfx/subtitle_tick.ogg` | `kenney_interface-sounds/Audio/tick_004.ogg` |
| `sfx/shop_buy.ogg` | `kenney_rpg-audio/Audio/handleCoins.ogg`, `oga_misc/80-cc0-rpg-sfx/item_gem_04.ogg` |
| `sfx/shop_fail.ogg` | `kenney_interface-sounds/Audio/error_005.ogg` |
| `sfx/ui_click.ogg` | `kenney_interface-sounds/Audio/click_001.ogg` |
| `sfx/ui_move.ogg` | `kenney_ui-audio/Audio/rollover2.ogg` |
| `sfx/ui_advance.ogg` | `kenney_rpg-audio/Audio/bookFlip1.ogg` |
| `sfx/ui_choice.ogg` | `oga_100sfx_rubberduck/gong_02.ogg` |
| `sfx/ui_confirm.ogg` | `kenney_interface-sounds/Audio/confirmation_001.ogg` |
| `sfx/ui_back.ogg` | `kenney_interface-sounds/Audio/back_001.ogg` |

## VFX (`assets/vfx/*.png`, 128 px, Kenney Particle Pack CC0)

circle_05, light_01, light_02, spark_04, spark_06, star_07, star_09, smoke_04,
smoke_08, flame_04, flame_06, magic_03, magic_05, twirl_02, scorch_01, slash_03,
symbol_02, dirt_02, trace_06, flare_01, window_02 → renomeados em `build_assets.py`
(`VFX`).
