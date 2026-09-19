# Áudio do GNOSIS — lista de compras DEFINITIVA

> **ESTADO (18/09/2026): TODOS os arquivos abaixo JÁ EXISTEM** — os 66 SFX e
> as 14 músicas foram preenchidos com packs **CC0 / CC-BY** (Kenney,
> OpenGameArt, Kevin MacLeod). Fontes, autores e licenças por arquivo em
> `assets/LICENSES.md`; o script que monta tudo a partir dos packs brutos é
> `assets/_packs/build_assets.py`. O jogo já toca som do menu ao epílogo.
> **João pode substituir qualquer um** gerando o seu (prompts abaixo) e
> salvando por cima com o **mesmo nome** — nada no código muda. A atribuição
> CC-BY (texto pronto em `assets/LICENSES.md`) precisa ir nos créditos enquanto
> algum arquivo CC-BY continuar em uso.

O código de áudio está **pronto e ligado**: todo evento do jogo já chama
`Audio.play_sfx("<nome>")` ou a música certa é escolhida sozinha pelo contexto
(menu, Rei, Éon, Arconte, Centro, Mente). Enquanto o arquivo não existir, o jogo
segue em silêncio, **sem erro**. Você só precisa gerar os arquivos abaixo e
soltar na pasta com o **nome exato**.

- SFX → `assets/audio/sfx/<nome>.ogg` (aceita .ogg / .wav / .mp3)
- Música → `assets/audio/music/<nome>.ogg`
- Catálogo-mestre no código: `scripts/autoload/audio_manager.gd` (`const CATALOG`).
  O `tools/AudioQA.tscn` confere que este documento, o catálogo, a pasta e as
  chamadas no código batem.

Total: **66 SFX** + **14 músicas**.

## Como pedir pra IA (regras que valem pra todos os prompts)

- **SFX:** ElevenLabs *Sound Effects* (elevenlabs.io/sound-effects). Cole o
  prompt em inglês como está; marque duração próxima da "alvo"; gere 3–4
  variações e fique com a mais seca. **Sem música, sem cauda de reverb longa**
  (o jogo é rápido — cauda longa vira lama). Alternativa: Stable Audio.
- **Música:** Suno ou Udio. Peça **instrumental, loopável, sem vocal com letra**
  (coro "ooh/aah" pode). Cada faixa de Éon: 2–3 min. Gere 2 candidatas e escolha.
- **Tom do jogo:** gnóstico, melancólico, sacro-mas-errado. Nada de "epic
  trailer" genérico; pense em coral distante, sinos, órgão, cordas graves,
  percussão surda. Referências de clima: God of War (2018), Blasphemous, Hades
  (só na função dos SFX), Dark Souls (menus).

---

## 1. SFX — Sophia (golpes)

| Arquivo | Quando toca | Alvo | Prompt (ElevenLabs SFX) |
|---|---|---|---|
| `sfx/swing_light.ogg` | golpe leve sai do wind-up (`player.gd`) | 0,25 s | "fast light blade whoosh, short air swipe, tight and dry, no impact, no music, no reverb tail" |
| `sfx/swing_heavy.ogg` | golpe pesado sai do wind-up | 0,4 s | "heavy two-handed blade swing, deep low whoosh with weight, slow arc, dry, no impact, no music, no reverb tail" |
| `sfx/swing_air.ogg` | Giro Celeste (golpe aéreo leve) | 0,45 s | "spinning aerial blade whoosh, three quick rotating swipes, airy, dry, no music" |
| `sfx/launcher.ogg` | lançador (golpe que joga o inimigo pro alto) | 0,4 s | "rising uppercut whoosh with a bright upward sweep, short, dry, no music, no reverb tail" |
| `sfx/dive.ogg` | Queda Estelar (mergulho aéreo pesado) — o pouso toca `nova` | 0,5 s | "fast downward dive whoosh, falling blade with rising pitch, ends abruptly, dry, no music" |
| `sfx/hit.ogg` | qualquer golpe leve acerta (também usado pelo Hitbox genérico) | 0,2 s | "short punchy melee impact, fantasy blade hitting flesh with a faint metallic edge, dry, no tail, no music" |
| `sfx/hit_heavy.ogg` | golpe pesado acerta | 0,35 s | "heavy crushing melee impact, deep thud with bone crack and low sub punch, dry, short tail, no music" |

## 2. SFX — Sophia (defesa e movimento)

| Arquivo | Quando toca | Alvo | Prompt |
|---|---|---|---|
| `sfx/parry.ogg` | parry perfeito (bloqueou dentro da janela) | 0,5 s | "metallic parry clang with a bright crystalline shimmer, satisfying deflect, short decay, no music" |
| `sfx/block.ogg` | bloqueio absorvendo um golpe (sem parry) | 0,3 s | "dull shield block thud, muffled metal on leather, short, dry, no music" |
| `sfx/dodge.ogg` | esquiva / rolamento | 0,3 s | "quick cloth dash whoosh, short air swipe with fabric rustle, dry, no music" |
| `sfx/dodge_perfect.ogg` | esquiva perfeita (golpe passou durante o rolamento) | 0,6 s | "time-slow whoosh with a glassy reverse swell and a soft chime, brief, ethereal, no music" |
| `sfx/jump.ogg` | pulo | 0,25 s | "light jump effort, short cloth whoosh and soft grunt-less push off stone, dry, no music" |
| `sfx/land.ogg` | pouso após queda | 0,25 s | "soft two-foot landing on stone with light cloth settle, short, dry, no music" |
| `sfx/step.ogg` | passo (a cada ~0,3 s andando; toca a -6 dB, tom varia) | 0,15 s | "single soft footstep on ancient stone floor, light sandal, dry, very short, no music" |
| `sfx/rooted.ogg` | Corrente da Lei te prende no lugar | 0,5 s | "iron chain snapping taut around a body, short rattle then lock, dry, no music" |
| `sfx/player_hurt.ogg` | Sophia toma dano | 0,35 s | "female hero pain grunt, short, restrained, with a faint light flicker sound, dry, no music" |
| `sfx/player_die.ogg` | Sophia cai (0 HP) | 1,5 s | "hero falls, final breath and a spark of light dimming out, soft low drone fading, somber, no music" |

## 3. SFX — Magias (Esfera inata + os 7 Anéis)

Cada Anel é a paixão de um Arconte virada contra o Kenoma — o som deve lembrar o Éon dele.

| Arquivo | Quando toca | Alvo | Prompt |
|---|---|---|---|
| `sfx/cast_solar.ogg` | Esfera Solar (inata): orbe que explode em área | 0,6 s | "holy light orb cast, warm solar shimmer whoosh launching forward, bright, short, no music" |
| `sfx/cast_torpor.ogg` | Névoa do Sono (Anel do Torpor): nuvem que deixa lento | 0,9 s | "sleepy fog spell release, slow breathy exhale with muffled soft bells, dreamlike, short, no music" |
| `sfx/cast_fome.ogg` | Boca Voraz (Anel da Fome): suga inimigos e morde | 0,8 s | "hungry vacuum pull ending in a sharp bite snap, gnawing wet texture, short, no music" |
| `sfx/cast_corrente.ogg` | Corrente da Lei (Anel da Corrente): corrente que prende | 0,7 s | "iron chain launched forward with rattling links and a sharp metallic lock at the end, dry, no music" |
| `sfx/cast_silencio.ogg` | Grito Mudo (Anel do Silêncio): atordoa ao redor | 0,9 s | "silent scream: sudden air pressure drop, sucked-out vacuum then a muted subsonic thump, eerie, no music" |
| `sfx/cast_espelho.ogg` | Reflexo (Anel do Espelho): 5 s devolvendo golpes | 0,8 s | "mirror shield forming, glassy crystalline chime sweep with a silver reverse tone, short, no music" |
| `sfx/cast_praga.ogg` | Flor Podre (Anel da Praga): canteiro de veneno | 0,9 s | "rotten flower blooming, wet squelch and buzzing spores with a sick low hum, short, no music" |
| `sfx/cast_coroa.ogg` | Coroa da Mônada (Anel da Coroa): nova enorme | 1,4 s | "radiant crown nova: massive golden light burst with choir-like harmonic swell and deep boom, short tail, no music" |
| `sfx/cast_fail.ogg` | sem Éter ou calada pelo Silêncio | 0,3 s | "spell fizzle, dry short sputter of light dying out, negative feedback, no music" |

## 4. SFX — Inimigos e chefes

| Arquivo | Quando toca | Alvo | Prompt |
|---|---|---|---|
| `sfx/enemy_hurt.ogg` | criatura comum toma dano (integração: `enemy.gd`) | 0,3 s | "creature pain grunt, small hollow monster, short, dry, no music" |
| `sfx/enemy_die.ogg` | criatura comum morre (a faísca se liberta) | 0,8 s | "creature death: wet collapse with a soft magical light release, short dissipate, no music" |
| `sfx/elite_die.ogg` | Elite morre | 1,0 s | "large creature death roar cut short, heavy body fall and a burst of released light, no music" |
| `sfx/champion_die.ogg` | Campeão do Éon morre (tela Desafio) | 1,4 s | "champion monster death: deep roar, crushing collapse, bright light release with a low bell toll, no music" |
| `sfx/boss_appear.ogg` | Arconte / Rei / Colosso aparece (barra de chefe) | 1,8 s | "boss reveal stinger: low brass-like drone swell, deep impact, distant choir shimmer, ominous, short tail" |
| `sfx/boss_phase2.ogg` | chefe entra na fase 2 (50 % de vida) | 1,4 s | "boss enrage: rising distorted roar with a cracking energy surge and a deep boom, no music" |
| `sfx/boss_die.ogg` | Arconte cai | 2,0 s | "archon death: massive body fall, shattering stone, long exhale of light, low choir sigh, no music" |
| `sfx/revive.ogg` | Sophia recomposta no checkpoint (a Voz / os cacos) | 1,8 s | "hero reassembled from light: reverse shimmer converging, soft heartbeat and a warm inhale, no music" |
| `sfx/form_revive.ogg` | batalha final: a forma caída do Demiurgo se refaz | 1,6 s | "dark resurrection surge, deep inhale of power, ominous rebuild with bone clicks and low drone, no music" |

## 5. SFX — Projéteis, área, pedaços

| Arquivo | Quando toca | Alvo | Prompt |
|---|---|---|---|
| `sfx/proj_fire.ogg` | projétil de luz nasce (Sophia ou Arconte) | 0,3 s | "magic light bolt launch, quick bright zip, dry, no music" |
| `sfx/proj_hit.ogg` | projétil acerta (atenuado pela distância) | 0,3 s | "magic bolt impact, small bright burst with a soft crackle, dry, no music" |
| `sfx/nova.ogg` | nova de área com dano (Fúria, Queda Estelar, Anéis) | 0,7 s | "expanding ring of light shockwave, quick whoosh outward with a bright ping, short tail, no music" |
| `sfx/gib_bounce.ogg` | primeiro quique de um pedaço desmembrado (rate-limit) | 0,15 s | "small wet chunk hitting stone floor, single short splat-thud, dry, no music" |

## 6. SFX — Objetos da tela

| Arquivo | Quando toca | Alvo | Prompt |
|---|---|---|---|
| `sfx/chest_hit.ogg` | golpe no baú fechado | 0,3 s | "blade hitting an old wooden chest, dull wood knock with metal fittings rattle, short, dry" |
| `sfx/chest_open.ogg` | baú abre e solta faíscas | 1,0 s | "treasure chest lid opening with a warm sparkle of light spilling out, short, no music" |
| `sfx/sleeper_wake.ogg` | um Adormecido desperta (faísca acende) | 1,2 s | "a sleeping soul waking: soft gasp, gentle rising chime and warm light bloom, tender, no music" |
| `sfx/seal_right.ogg` | Selo golpeado na ordem certa | 0,5 s | "stone glyph lighting up, soft resonant ping with a faint choir tone, short, no music" |
| `sfx/seal_wrong.ogg` | Selo errado (puzzle reseta) | 0,5 s | "wrong-answer buzz: low stone grind with a harsh muted thud, negative, short, no music" |
| `sfx/seal_solved.ogg` | os 3 Selos resolvidos (chuva de faíscas) | 1,4 s | "puzzle solved: ascending three-note crystalline chime with a warm light burst, no music" |
| `sfx/portal_open.ogg` | fenda de saída aparece (tela limpa) | 1,4 s | "portal of light tearing open, rising shimmer with a soft sustained hum, ethereal, short tail" |
| `sfx/portal_enter.ogg` | Sophia entra na fenda (troca de tela) | 1,0 s | "stepping through a light portal: quick whoosh inward with a soft bloom and fade, no music" |

## 7. SFX — Estrutura do run (zonas, faíscas, Anéis, Estelas, legendas)

| Arquivo | Quando toca | Alvo | Prompt |
|---|---|---|---|
| `sfx/zone_lock.ogg` | bolsão de combate trava (paredes sobem) | 0,9 s | "arena lock: heavy stone slabs slamming shut with a low rumble, short, no music" |
| `sfx/zone_clear.ogg` | bolsão limpo (paredes descem) | 1,0 s | "zone cleared: stone barriers sinking with a soft resolving chime, short, no music" |
| `sfx/level_clear.ogg` | tela limpa (antes do portal / loja) | 1,6 s | "screen cleared fanfare, short sacred two-chord swell with a distant bell, no drums, short tail" |
| `sfx/spark.ogg` | faísca coletada (automático: aumento pequeno de faíscas) | 0,2 s | "tiny spark pickup, bright short glassy tick, dry, no music" |
| `sfx/weapon_upgrade.ogg` | arma sobe de nível (automático) | 1,2 s | "weapon empowered: blade being forged in light, metallic ring rising into a bright chord, no music" |
| `sfx/ring_gain.ogg` | Arconte cai → Anel se condensa (automático) | 1,6 s | "sacred ring forming: crystalline resonance ascending and locking into place, holy, short tail, no music" |
| `sfx/ring_steal.ogg` | o roubo: o Rei leva os 7 Anéis (automático) | 2,5 s | "seven chimes ripped away in reverse one after another, hollow loss, dark whoosh, ends in silence, no music" |
| `sfx/shard.ogg` | caco de memória devolve o poder de um Anel (automático) | 0,8 s | "small memory shard clicking into place, soft crystalline warm tone, brief, no music" |
| `sfx/stele_open.ogg` | Estela lida (inscrição de lore) | 1,0 s | "ancient stone tablet awakening: low rumble with a soft glowing hum and a page-turn whisper, no music" |
| `sfx/stele_unlock.ogg` | nova entrada nas Crônicas | 1,0 s | "chronicle unlocked: quill scratch on parchment followed by a gentle sacred chime, no music" |
| `sfx/subtitle_tick.ogg` | legenda de caminhada aparece (discreto) | 0,12 s | "very soft UI tick, single quiet wooden click, dry, no music" |

## 8. SFX — Loja e interface

| Arquivo | Quando toca | Alvo | Prompt |
|---|---|---|---|
| `sfx/shop_buy.ogg` | compra na loja confirmada | 0,6 s | "purchase confirmed: sparks being absorbed with a warm soft chime, short, no music" |
| `sfx/shop_fail.ogg` | compra sem faíscas suficientes | 0,4 s | "denied: dull low double-thud, muted, negative, dry, no music" |
| `sfx/ui_click.ogg` | botão pressionado (todo botão `CodexStyle.button`; slider de opções) | 0,15 s | "soft UI click, subtle warm wooden tick, dry, no music" |
| `sfx/ui_move.ogg` | foco/mouse muda de botão | 0,1 s | "very soft UI hover tick, tiny stone tap, dry, no music" |
| `sfx/ui_advance.ogg` | avança uma fala no diálogo | 0,15 s | "dialogue advance: soft parchment flick, quiet and short, dry, no music" |
| `sfx/ui_choice.ogg` | escolha feita num diálogo (Recusar/Ceder, finais) | 0,7 s | "decision made: single low resonant bell with a short shimmer, weighty, no music" |
| `sfx/ui_confirm.ogg` | confirmação de menu (iniciar campanha, salvar opções) | 0,4 s | "menu confirm: warm two-note rising tick, soft, dry, no music" |
| `sfx/ui_back.ogg` | voltar / cancelar num menu | 0,3 s | "menu back: soft descending tick, dry, no music" |

> Os nomes antigos `sfx/ui.ogg` e `sfx/cast.ogg` **não** são mais necessários: o
> autoload redireciona `ui` → `ui_click`, `cast` → `cast_solar`, `stela` →
> `stele_open` e `caption` → `subtitle_tick` (nomes usados pela narrativa).

---

## 9. Músicas (14)

Todas **instrumentais**, **loopáveis** (comece e termine no mesmo acorde/pad,
sem fade no arquivo — o jogo faz o crossfade de 1,2 s). Os Éons seguem a obra
alquímica: **nigredo** (Torpor, Fome, Corrente — preto, pesado), **albedo**
(Silêncio, Espelho — branco, esvaziado), **rubedo** (Praga, Coroa — vermelho,
febril, falso ouro).

| Arquivo | Onde toca | BPM | Duração | Prompt (Suno/Udio) |
|---|---|---|---|---|
| `music/theme.ogg` | menu principal | 60 | 2–3 min, loop | "melancholic gnostic ambient, distant choir pads, slow bowed strings, faint bells, hopeful yet grieving, no drums, instrumental, loopable" |
| `music/rei.ogg` | O Limiar (tela do Rei — chefe-tutorial) | 70 | 2 min, loop | "regal but hollow theme, muted low brass, slow processional drum, cathedral bells, warm melody with a wrong note underneath, instrumental, loopable" |
| `music/eon_torpor.ogg` | Éon 1 — Torpor (nigredo) | 52 | 2–3 min, loop | "sleep-fog ambient, sub drones, muffled distant lullaby on music box, slow breathing texture, heavy eyelids, no drums, instrumental, loopable" |
| `music/eon_fome.ogg` | Éon 2 — Fome (nigredo) | 84 | 2–3 min, loop | "gnawing hunger, hollow tribal percussion, throbbing bass pulse, scraping strings, wet textures, restless, instrumental, loopable" |
| `music/eon_corrente.ogg` | Éon 3 — Corrente (nigredo) | 92 | 2–3 min, loop | "iron law march, chain clanks as percussion, anvil hits, low organ pedal, rigid rhythm, oppressive order, instrumental, loopable" |
| `music/eon_silencio.ogg` | Éon 4 — Silêncio (albedo) | 60 | 2–3 min, loop | "near-silence ambient, sparse glass harmonics, long pauses, breath and wind, single piano notes far away, white and empty, no drums, instrumental, loopable" |
| `music/eon_espelho.ogg` | Éon 5 — Espelho (albedo) | 76 | 2–3 min, loop | "mirror world, reversed piano phrases answered by their forward twin, silver shimmer pads, doubled melodies slightly out of phase, uncanny, instrumental, loopable" |
| `music/eon_praga.ogg` | Éon 6 — Praga (rubedo) | 100 | 2–3 min, loop | "rot and swarm, buzzing insect textures, detuned sick strings, feverish pulse, low choir moans, decaying beauty, instrumental, loopable" |
| `music/eon_coroa.ogg` | Éon 7 — Coroa (rubedo) | 110 | 2–3 min, loop | "false gold majesty, grand brass and full choir that cracks at the edges, timpani, triumphant but hollow, cathedral scale, instrumental, loopable" |
| `music/boss.ogg` | tela de Arconte (os 7) e Provação | 128 | 2–3 min, loop | "hybrid orchestral boss battle, driving taiko and low brass, aggressive choir stabs, sacred-horror, relentless, instrumental, loopable" |
| `music/roubo.ogg` | o roubo dos Anéis (após o 7º Arconte cair; ligado por one-liner no Level) | 50 | 60–90 s, sem loop | "betrayal cue: the regal theme inverted and slowed, no drums, descending choir, bells detuning, collapsing into a low drone, instrumental" |
| `music/centro.ogg` | O Centro (ecos dos Arcontes devolvem cacos) | 64 | 2–3 min, loop | "memory shards, glassy plucked harp, slow heartbeat pulse, intimate and inward, fragments of the seven eon themes echoing softly, instrumental, loopable" |
| `music/mente.ogg` | A Mente — batalha dupla (Rei + Colosso) | 132 | 3 min, loop | "final battle, full choir and pipe organ over pounding drums, layered themes clashing, apocalyptic sacred, relentless, instrumental, loopable" |
| `music/epilogo.ogg` | tela de fim (3 finais) | 58 | 2 min, loop | "dawn after the war, solo piano with warm choir pads, slow resolution, bittersweet peace, no drums, instrumental, loopable" |

Regra de seleção (automática, no `audio_manager.gd`): menu → `theme` · tela do
Rei → `rei` · Éon *i* → `eon_<nome>` · tela de Arconte → `boss` · Centro →
`centro` · Mente → `mente`. `roubo` e `epilogo` são ligados por one-liner
(`Audio.play_music("roubo")` no `level.gd` após o 7º Arconte cair;
`Audio.play_music("epilogo")` no `end_screen.gd`). Se um arquivo não existir, a
faixa anterior continua.

---

## 10. Export (o que entregar)

- Formato: **.ogg Vorbis**, 44,1 kHz, mono pros SFX (estéreo só se o efeito
  tiver largura de verdade), estéreo pras músicas. Qualidade q5–q6 (~160 kb/s).
- Loudness: músicas em **≈ -14 LUFS integrado**, pico ≤ -1 dBTP. SFX
  normalizados com pico em **-3 dBFS** (curtos) — o jogo já dá -6 dB nos passos.
- Corte o silêncio do começo (o ataque do som tem que estar no zero) e deixe no
  máximo 100–200 ms de cauda nos SFX curtos.
- Música: exporte o loop **sem fade** e confira que o fim emenda no começo.
- Ferramenta grátis pra converter/normalizar: Audacity (Efeito → Loudness
  Normalization; Exportar → OGG). Não precisa reiniciar nada: solte na pasta e
  rode o jogo.

## 11. Como testar (checklist)

1. `& $godot --headless --path . "res://tools/AudioQA.tscn" --quit-after 300`
   → esperado `AUDIO QA: 0 falhas`. Ele confere: (a) todo nome do catálogo está
   neste documento; (b) nenhum arquivo órfão na pasta (nome errado = o jogo nunca
   toca); (c) tocar nome inexistente não dá erro; (d) crossfade/stop sem arquivo
   não dá erro; (e) toda tela do run tem faixa do catálogo; (f) toda chamada
   `play_sfx("…")` no código usa nome do catálogo.
2. `& $godot --headless --path . "res://tools/CodexPlaytest.tscn" --quit-after 400`
   → o bot joga com inputs reais; se um gancho quebrou o combate, ele acusa.
3. Abra o jogo (`Jogar GNOSIS`) e passe pelo roteiro: menu (tema + cliques) →
   Nova campanha → tela do Rei (`rei`, `boss_appear`) → andar (passos), pular
   (`jump`/`land`), golpes leve/pesado, Esfera Solar (`cast_solar`) → tomar dano,
   bloquear, parry → matar o Rei (`boss_die`) → Éon 1 (`eon_torpor`), baú, portal.
4. Opções → sliders: a música responde ao "Música", os cliques ao "SFX".
5. Se um som ficar alto/baixo demais, me diga o nome: o volume por som é
   ajustado no código (`play_sfx(nome, pitch, volume_db)`), sem regerar.
