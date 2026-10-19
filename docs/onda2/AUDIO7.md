# Onda 7 — Áudio7 (branch `dir7/audio7`, base `origin/integracao/onda1`)

> Som com identidade (sombrio, sacro, cósmico) para o conteúdo novo das Ondas 5–6. 100 % síntese própria
> (numpy, `tools/audio_synth/onda7.py`), determinística. Nenhum pack novo, nenhum crédito novo.

## BILHETE PARA O SUCESSOR (atualizado a cada bloco)

**Estado:** 118 sons novos (143 arquivos com as variações) gerados e no CATALOG; API `move_sfx` e ganchos por
sinal no `audio_manager.gd`; AudioQA com o bloco (h) da Onda 7. Pendente/feito: ver as seções abaixo.

**Armadilhas:** `M.choir(notas, dur, vogal, shift, ...)`: a 4ª posição é `shift`, então passe `vowel2=` por nome.
`build_sfx.py` só grava `sfx_report.json` no fim, e uma receita que quebra perde o relatório do lote. Os
`.import` dos sons antigos aparecem como modificados depois do import (só CRLF), então NÃO os commite.

**Como refazer:** `GNOSIS_PACKS=<cópia OneDrive>/assets/_packs python tools/audio_synth/build_sfx.py <nomes>`
(nomes: `python tools/audio_synth/onda7.py --list`) → import headless → AudioQA.

## Paleta (a "cara" do som)
- **Luz** (Sophia, Mônada, Soter, altar): vidro (parciais de taça), sinos, coro aberto 'a' em **Mi maior**.
- **Trevas** (Arcontes, criaturas, perigos): serras graves desafinadas (2ª menor/trítono), formantes 'o/u',
  aspereza (AM 20–40 Hz), pedra e ferro.
- **O Rei/Yaldabaoth:** luz ROUBADA, ou seja, coro masculino grave + metal dourado + sub.
- **Cada Arconte** tem a textura do seu Éon: Torpor = caixinha/bocejo, Fome = sucção/mordida, Corrente =
  elos/grades, Silêncio = grito que corta e zumbido, Espelho = vidro dos dois lados, Praga = esporos e enxame,
  Coroa = gongo/coro/lâmina dourada.

## Mixagem (M-max por categoria, mesmo método das ondas anteriores)
Categorias novas, somadas ao `CAT` do `build_sfx.py`:

| Categoria | M-max | Uso |
|---|---|---|
| `eatk` | −19 | golpe de inimigo comum, abaixo do swing da Sophia (−18) e do acerto (−12) |
| `eatk_big` | −16 | pancada, coluna e invocação de inimigo; `chain`/`glass` do kit |
| `charge` / `charge_big` | −19 / −16 | carga antes do tiro (cresce; quem pesa é o tiro) e carga do Rei |
| `sophia` / `sophia_big` | −19 / −13 | pulo duplo / Queda Estelar pousando (soma com a `nova`) |
| `bsig` / `bsig_soft` | −13 / −15 | golpe-assinatura de chefe / feitiço longo de chefe |
| `boss_mid` / `death_hush` | −12 / −24 | passos da morte que somam com `boss_die` / a pausa (quase nada) |
| `hazard_big` / `hazard` / `hazard_soft` / `hazard_amb` | −15 / −18 / −22 / −28 | perigo que fere / perigo / aviso-presença / presença contínua |

Usam categorias existentes: `tell` (−17, `riposte_ready`), `swing_big`, `champion` (−12), `boss` (−10),
`elite`, `hit`, `reward` (−13), `ui_big`/`ui`/`shop`, `structure`, `story`.

## API nova do `Audio` (Onda 7)
- `move_sfx(mv: Dictionary, stage: String, pos := NO_POS, boss := false) -> bool`: som do golpe. Ordem:
  1. `BOSS_MOVE_SFX[id]`, só para chefes (id normalizado: `guarda3` → `guarda`, `corte_b` → `corte`);
  2. o tiro: teleguiado → `atk_homing`, de cima → `atk_shot_air`, vários → `atk_fan`;
  3. `KIND_SFX[kind]`.

  Etapas: `"wind"` (início do telegrafo; o `tell_*` continua à parte), `"strike"` e `"land"` (pouso do salto
  do chefe = `bs_land`). Golpe ou etapa sem som devolve false, sem erro.
- `move_sound_for(mv, stage, boss) -> String`: a mesma resolução, sem tocar (o AudioQA usa).
  `move_base_id(id)` e `death_step_sfx(passo)` também estão expostas.
- **Ganchos por sinal (ninguém precisa chamar):**
  - `Enemy.boss_dying(passo 0..4)` dispara `boss_death_impact` → `_stagger` → `_collapse` → `_hush` →
    `_shatter`. O passo 4 soma com o `boss_die` do Enemy.
  - `Player.riposte_window_opened` → `riposte_ready` (bus Tell).
  - `Progression.double_jump_granted` → `soter_gift`.
  - `Progression.relics_changed` → `relic_equip` (só no jogo; o sinal não dispara no load).
  - `Achievements.unlocked` → `achievement` (rajada = 1 som; anti-spam de 2,5 s).
- **Cue `sink` (roubo):** `king_sink`, depois `crack_open` 0,5 s mais tarde e `fog_swell` 0,6 a −8 dB. Antes era
  `dive` + `boss_step` + `fog_swell`, ou seja, sons de combate reaproveitados.
- **Buses:** `riposte_ready` → Tell; `map_*` e `achievement` → UI (`shop_seal` já é UI pelo prefixo).
- **Tom:** cargas, informação, chefes, perigos e UI tocam com tom fixo. Golpes de inimigo, voadores, cacos,
  lanças e corrente variam ±4 % e ±1,5 dB.

## Catálogo dos sons novos

Todos são síntese própria (S). Var = nº de arquivos (`nome`, `nome_2`, ...).

| Arquivo | Categoria / M-max | Var | Como soa |
|---|---|---|---|
| `sfx/chain.ogg` | eatk_big -16 | 3 | Galila: o laço pega — elos acelerando + PUXÃO (sopro) + trava de ferro. |
| `sfx/glass.ogg` | eatk_big -16 | 3 | Astaphaios: a guarda de espelho devolve o golpe — vidro 'ping' que se espelha (o mesmo som ao contrário do outro lado) + lascas. |
| `sfx/charge_light.ogg` | charge -19 | 1 | Sophia carrega: coro em Mi maior que abre, fio de luz subindo, faíscas. |
| `sfx/charge_dark.ogg` | charge -19 | 1 | Arconte carrega: serras graves desafinadas inspirando (sucção), sub que cresce e um sussurro 'u' — a escuridão puxa o ar antes do tiro. |
| `sfx/charge_king.ogg` | charge_big -16 | 1 | O Rei carrega: luz ROUBADA — coro masculino grave 'o' + gongo ao contrário + sino dourado no topo; mais longo e mais largo. |
| `sfx/double_jump.ogg` | sophia -19 | 2 | 2º pulo (dom do Soter): sopro para cima + ANEL de luz (vidro em Mi-Si). |
| `sfx/star_charge.ogg` | charge -19 | 1 | Queda Estelar carregando (paira): estrelas se juntando, sobe e segura. |
| `sfx/star_impact.ogg` | sophia_big -13 | 1 | Queda Estelar pousa: baque fundo + cratera de pedra + chuva de estrelas. |
| `sfx/riposte_ready.ogg` | tell -17 | 1 | Aparo perfeito → a janela do contra-ataque ABRIU: dois 'tins' de lâmina subindo (Si6→Mi7), curtos — o ouvido aprende 'agora!'. |
| `sfx/riposte.ogg` | swing_big -16 | 1 | Contra-ataque: estocada — sopro rasgado + 'xing' de lâmina + peso. |
| `sfx/atk_swing.ogg` | eatk -19 | 3 | Garra/osso cortando o ar: sopro médio + estalo ósseo. |
| `sfx/atk_combo.ogg` | eatk -19 | 2 | Duas garradas coladas (a 2ª mais grave). |
| `sfx/atk_rush.ogg` | eatk -19 | 2 | Investida: pé que firma + sopro acelerando + rosnado. |
| `sfx/atk_leap.ogg` | eatk -19 | 2 | Bote: sibilo + sopro para cima (o bicho salta). |
| `sfx/atk_slam.ogg` | eatk_big -16 | 2 | Pancada no chão: soco grave + cascalho. |
| `sfx/atk_wave.ogg` | eatk -19 | 2 | Onda pelo chão: pedra rolando que se afasta (grave rugoso + estalos). |
| `sfx/atk_shot.ogg` | eatk -19 | 3 | Tiro das trevas: 'thum' grave + zunido descendo (não o zip claro da Sophia). |
| `sfx/atk_shot_air.ogg` | eatk -19 | 2 | Tiro de CIMA (voador): o mesmo tiro com 'queda' de tom e sopro de asa. |
| `sfx/atk_fan.ogg` | eatk -19 | 1 | Leque: 3 zunidos abrindo em leque (esq → centro → dir). |
| `sfx/atk_burst.ogg` | eatk -19 | 1 | Rajada: catraca de 4 disparos secos (o arco do atirador). |
| `sfx/atk_homing.ogg` | eatk -19 | 1 | Teleguiado: fogo-fátuo que ondula (vibrato largo) + sussurro. |
| `sfx/atk_lob.ogg` | eatk -19 | 1 | Arco: arremesso 'fuup' para cima + giro (bamboleio) no ar. |
| `sfx/atk_pillar.ogg` | eatk_big -16 | 1 | Coluna de luz (profana) brotando: sub crescendo → explosão de coro rachado. |
| `sfx/atk_fissure.ogg` | eatk -19 | 1 | Lâmina rasteira pelo chão: raspar de pedra que corre + rachaduras. |
| `sfx/atk_grab.ogg` | eatk -19 | 1 | Agarrão: avanço + mão que fecha (pano/carne) + puxão. |
| `sfx/atk_blink.ogg` | eatk -19 | 1 | Aparece ATRÁS: sucção ao contrário + estalo + sussurro do outro lado. |
| `sfx/atk_summon.ogg` | eatk_big -16 | 1 | Invocação: canto grave 'u' + borbulho do chão + rachadura. |
| `sfx/atk_nova.ogg` | eatk_big -16 | 1 | Pulso escuro: ar sendo puxado → estouro grave. |
| `sfx/atk_dive.ogg` | eatk -19 | 2 | Mergulho do voador: guincho descendo + vento rasgando. |
| `sfx/atk_glide.ogg` | eatk -19 | 1 | Planar: 2 batidas de asa + sopro longo. |
| `sfx/fly_fall.ogg` | eatk -19 | 2 | Voador atingido cai: asas descompassadas + assobio de queda + baque. |
| `sfx/champion_enter.ogg` | champion -12 | 1 | Campeão entra: trompa de guerra grave (serra em 5ª) + ferro arrastado + rugido. |
| `sfx/champion_fury.ogg` | champion -12 | 1 | Fúria do Campeão: rugido que acende (sobe) + labareda. |
| `sfx/boss_phase3.ogg` | boss -10 | 1 | Fase 3 (desespero): rugido duplo + coro em cluster que racha + impacto. |
| `sfx/guard_break.ogg` | elite -13 | 1 | Quebra de guarda: armadura racha (pedra+vidro) + ar escapando + sino abafado. |
| `sfx/eye_hit.ogg` | hit -12 | 2 | Olho do Rei atingido (ponto fraco): vidro perfurado (ping desafinado) + chiado molhado + guincho de coro curto — dói e soa como ACERTO CRÍTICO. |
| `sfx/boss_death_impact.ogg` | boss -10 | 1 | Morte 0 — IMPACTO: golpe final que PARA o tempo (baque + metal + ar sugado). |
| `sfx/boss_death_stagger.ogg` | boss_soft -14 | 1 | Morte 1 — CAMBALEIA: gemido grave descendo + rangido de armadura. |
| `sfx/boss_death_collapse.ogg` | boss_mid -12 | 1 | Morte 2 — COLAPSO: joelho, corpo, pedra (3 baques) + estrondo baixo. |
| `sfx/boss_death_hush.ogg` | death_hush -24 | 1 | Morte 3 — PAUSA: quase nada. Um sopro que sai do corpo + zumbido de ouvido. |
| `sfx/boss_death_shatter.ogg` | boss_mid -12 | 1 | Morte 4 — ESTILHAÇO: o corpo vira cacos de luz (vidro em cascata) + coro que sobe (a centelha sai) + sino grave. |
| `sfx/bs_melee.ogg` | bsig -13 | 2 | Golpe pesado de chefe (reserva do tipo melee): lâmina larga + peso. |
| `sfx/bs_cast.ogg` | bsig_soft -15 | 2 | Feitiço de chefe (reserva do tipo cast): canto escuro que cresce. |
| `sfx/bs_leap.ogg` | bsig -13 | 1 | Salto do chefe: tomada de impulso + sopro subindo e sumindo. |
| `sfx/bs_land.ogg` | bsig -13 | 1 | Queda do chefe: estrondo + rachadura de chão. |
| `sfx/bs_yawn.ogg` | bsig_soft -15 | 1 | Athoth (Torpor) — bocejo: voz gigante 'a→o' descendo, com ar. |
| `sfx/bs_lullaby.ogg` | bsig_soft -15 | 1 | Athoth — canção de ninar: caixinha de música desafinada que desacelera. |
| `sfx/bs_rain.ogg` | bsig_soft -15 | 1 | Athoth — chuva de orbes: pingos de sono caindo de cima, espalhados. |
| `sfx/bs_suck.ogg` | bsig -13 | 1 | Harmas (Fome) — sucção: inspiração enorme e úmida que cresce. |
| `sfx/bs_bite.ogg` | bsig -13 | 1 | Harmas/Belias — mordida: duas dentadas pesadas e molhadas + rosnado. |
| `sfx/bs_breath.ogg` | bsig -13 | 1 | Sopro (Harmas/Yabel): rajada rugindo, grave e larga. |
| `sfx/bs_cage.ogg` | bsig -13 | 1 | Galila (Corrente) — prisão: 3 grades de ferro descendo + correntes. |
| `sfx/bs_scream.ogg` | bsig -13 | 1 | Yabel (Silêncio) — grito: guincho que sobe e CORTA seco → zumbido. |
| `sfx/bs_pages.ogg` | bsig_soft -15 | 1 | Yabel — pergaminhos: revoada de papel + sussurros. |
| `sfx/bs_wings.ogg` | bsig -13 | 1 | Yabel — asas: duas batidas grandes (corpo de pano + vento). |
| `sfx/bs_split.ogg` | bsig_soft -15 | 1 | Astaphaios (Espelho) — reflexos: acorde de vidro que se DIVIDE nos dois lados. |
| `sfx/bs_swap.ogg` | bsig_soft -15 | 1 | Astaphaios — troca: vidro ao contrário de um lado, estalo do outro. |
| `sfx/bs_spores.ogg` | bsig_soft -15 | 1 | Belias (Praga) — esporos: sopros úmidos espalhados + bolhas. |
| `sfx/bs_cloud.ogg` | bsig_soft -15 | 1 | Belias — nuvem: gás sibilando que cresce + enxame miúdo. |
| `sfx/bs_burrow.ogg` | bsig -13 | 1 | Belias — enterrar: escavar descendo (terra + grave que afunda). |
| `sfx/bs_decree.ogg` | bsig -13 | 1 | Armupiel (Coroa) — decreto: gongo + coro masculino em uníssono que proclama. |
| `sfx/bs_coronation.ogg` | bsig -13 | 1 | Armupiel — coroação: coro que sobe + sinos dourados + metal da coroa. |
| `sfx/bs_royal_cut.ogg` | bsig -13 | 1 | Armupiel — corte real: lâmina dourada pesada (shing longo) + ar cortado. |
| `sfx/bs_sweep.ogg` | bsig -13 | 1 | Armupiel — varredura: sopro LARGO e longo de um lado ao outro. |
| `sfx/bs_ray.ogg` | bsig -13 | 1 | Rei — raio: zumbido de luz roubada (serra brilhante em coro) + estouro. |
| `sfx/bs_hand.ogg` | bsig -13 | 1 | Rei — mão: mão gigante descendo (sopro grave) + pancada enorme. |
| `sfx/bs_rings.ogg` | bsig_soft -15 | 1 | Rei — anéis: os 7 tons dos Anéis girando em volta (espiral estéreo). |
| `sfx/bs_collapse.ogg` | bsig -13 | 1 | Colosso — desabamento: rochas caindo do teto em cascata. |
| `sfx/hz_tide_wake.ogg` | hazard_big -15 | 1 | Maré escura acorda: muralha de treva subindo + sussurros de olhos. |
| `sfx/hz_tide_tick.ogg` | hazard_soft -22 | 1 | Maré corroendo (tique de dano): chiado ácido curto. |
| `sfx/hz_guillotine.ogg` | hazard_big -15 | 1 | Guilhotina cai: ferro raspando no trilho (rápido) + CHOP pesado. |
| `sfx/hz_winch.ogg` | hazard_soft -22 | 1 | Guilhotina sobe: catraca de manivela. |
| `sfx/hz_maw_bite.ogg` | hazard_big -15 | 1 | Boca do chão morde: dentada de pedra molhada + rosnado da fenda. |
| `sfx/hz_maw_warn.ogg` | hazard -18 | 1 | Boca acordando (aviso): rosnado grave subindo da rachadura. |
| `sfx/hz_beam_on.ogg` | hazard -18 | 1 | Feixe do espelho acende: zumbido de vidro em laser (1,2 s). |
| `sfx/hz_beam_off.ogg` | hazard_soft -22 | 1 | Feixe apaga: vidro que esfria (tom caindo curto). |
| `sfx/hz_mirror_warn.ogg` | hazard_soft -22 | 1 | Plataforma-reflexo vai sumir: vidro tremendo (trêmulo 12 Hz). |
| `sfx/hz_mirror_flip.ogg` | hazard_soft -22 | 1 | Plataforma-reflexo troca de lado: sopro de vidro de um canal ao outro. |
| `sfx/hz_mist_breath.ogg` | hazard_soft -22 | 1 | Névoa do Torpor respira: inspira-expira lento e sonolento + caixinha abafada. |
| `sfx/hz_chain_swing.ogg` | hazard -18 | 2 | Pêndulo de corrente: rangido do elo no topo + lâmina cortando o ar. |
| `sfx/hz_bell_toll.ogg` | hazard_big -15 | 1 | Badalo do Silêncio (o sino MUDO): baque de bronze abafado, sem brilho, com o ar sendo puxado depois — o som que 'apaga' o som. |
| `sfx/hz_ether_drain.ogg` | hazard -18 | 1 | Éter arrancado: vidro sugado para baixo + crepitar azul. |
| `sfx/hz_silence_in.ogg` | hazard -18 | 1 | Entrar no campo de silêncio: o som é SUGADO (sopro crescente) e corta; sobra só um zumbido de ouvido baixinho. |
| `sfx/hz_silence_out.ogg` | hazard_soft -22 | 1 | Sair do campo: ouvido destampando (estalo grave + ar de volta). |
| `sfx/hz_sink_start.ogg` | hazard_soft -22 | 1 | Pedra adormecida afunda: ranger de pedra grave + bolhas de lodo. |
| `sfx/hz_sink_gone.ogg` | hazard_soft -22 | 1 | Pedra some no fundo: 'plof' grave e abafado. |
| `sfx/hz_sink_return.ogg` | hazard_soft -22 | 1 | Pedra volta: subida suave (pedra + caixinha). |
| `sfx/hz_spears.ogg` | hazard_big -15 | 2 | Lanças da guarda brotam: 3 'shink' de ferro em cascata + estalo de pedra. |
| `sfx/hz_shackles.ogg` | hazard_big -15 | 1 | Grilhões do chão: correntes saltando + argola que FECHA (clank). |
| `sfx/hz_spore_swell.ogg` | hazard_soft -22 | 1 | Cápsula de esporos incha: rangido orgânico úmido subindo. |
| `sfx/hz_spore_burst.ogg` | hazard -18 | 1 | Cápsula estoura: 'plop' molhado + sopro de nuvem chiando. |
| `sfx/hz_spore_pop.ogg` | hazard -18 | 1 | Cápsula destruída: estalo seco + sopro fraco. |
| `sfx/hz_shard_warn.ogg` | hazard_soft -22 | 1 | Céu rachando (sombra no chão): vidro estalando lá no alto. |
| `sfx/hz_shard_fall.ogg` | hazard_soft -22 | 1 | Caco caindo: assobio de vidro descendo (0,18 s). |
| `sfx/hz_shard_impact.ogg` | hazard -18 | 3 | Caco se espatifa no chão. |
| `sfx/hz_totem_arm.ogg` | hazard -18 | 1 | Totem profano acorda: zumbido grave em trítono acendendo. |
| `sfx/hz_totem_summon.ogg` | hazard -18 | 1 | Totem chama reforço: canto invertido + rasgo (portal escuro). |
| `sfx/hz_totem_hit.ogg` | hazard -18 | 2 | Totem atingido: pedra oca ressoando (não madeira). |
| `sfx/hz_totem_break.ogg` | hazard_big -15 | 1 | Totem desaba: pedra rachando em cascata + o mal expirando. |
| `sfx/hz_ward_drain.ogg` | hazard_soft -22 | 1 | Luz do Adormecido sendo drenada: chama tremeluzindo, chiado frio. |
| `sfx/hz_ward_out.ogg` | hazard -18 | 1 | A luz apaga: vela soprada + sino de vidro descendo e morrendo. |
| `sfx/hz_ward_saved.ogg` | reward -13 | 1 | A luz resistiu: acorde de coro em Mi maior que respira aliviado. |
| `sfx/hz_altar.ogg` | reward -13 | 1 | Altar do Santuário cura: água de luz + acorde sacro (Mi maior aberto). |
| `sfx/hz_altar_hum.ogg` | hazard_amb -28 | 1 | Coluna de luz do altar (presença, perto dele): zumbido sacro baixinho. |
| `sfx/hz_secret_mark.ogg` | hazard_soft -22 | 1 | Marca do segredo acende (pulo duplo): brilho dourado de 2 notas. |
| `sfx/hz_secret_open.ogg` | reward -13 | 1 | Sala secreta / selo abre: pedra deslizando + correntes caindo + coro. |
| `sfx/hz_column.ogg` | hazard_big -15 | 1 | Perigo de chefe golpeia (coluna/arena): estouro de energia escura vertical. |
| `sfx/hz_saw.ogg` | hazard -18 | 1 | Serra-Anel girando (perigo do chefe): zunido metálico com giro (AM 18 Hz). |
| `sfx/map_open.ogg` | ui_big -18 | 1 | Mapa abre: pergaminho desenrolando + sino grave longe. |
| `sfx/map_select.ogg` | ui_big -18 | 1 | Nó escolhido: carimbo de cera + sino em Mi (o caminho foi decidido). |
| `sfx/map_locked.ogg` | ui -22 | 1 | Nó trancado: batida surda em pedra + corrente curta. |
| `sfx/shop_seal.ogg` | shop -18 | 1 | Loja: SELO aberto — cera estalando + luz que sai (vidro subindo) + coro curto. |
| `sfx/relic_equip.ogg` | shop -18 | 1 | Relíquia equipada: metal antigo assentando + brilho de 2 notas. |
| `sfx/zone_objective.ogg` | structure -15 | 1 | Objetivo da zona: trompa grave curta + sino (chama a atenção, sem alarme). |
| `sfx/achievement.ogg` | ui_big -18 | 1 | Conquista: arpejo sacro de vidro (Mi-Sol#-Si-Mi) + sino — 'você entendeu algo'. |
| `sfx/soter_gift.ogg` | reward -13 | 1 | O Soter concede o pulo duplo: coro alto que se abre + anel de luz em espiral. |
| `sfx/crack_open.ogg` | story -15 | 1 | Roubo — a rachadura abre: pedra/vidro rasgando devagar + luz vazando (zumbido). |
| `sfx/king_sink.ogg` | story -15 | 1 | Roubo — o Rei afunda: estrondo descendo de tom + gemido de metal + coro que cai. |
