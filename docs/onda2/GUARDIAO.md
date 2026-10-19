# GUARDIÃO DA SATISFAÇÃO — auditorias (branch `dir7/guardiao`)

> Lei: `docs/handoff/NEURO_SATISFACAO.md` (§2 R1–R22, §3 recompensa ética, §4 o que NÃO fazer, §5 checklist).
> Vereditos: **APROVADO** / **APROVADO COM RESSALVAS** (entra; ressalva vira pedido ao dono) / **REPROVADO** (não entra).
> Branch que muda depois de aprovado precisa de reauditoria do DELTA (o veredito vale para o commit citado).
> Sondas: `tools/guardiao/**`. Capturas e logs: `C:\gnosis-wt\_caps\guardiao\`.

## Índice de vereditos (o mais novo em cima)

| Branch | Commit auditado | Veredito | R |
|---|---|---|---|
| dir7/vfx7 | 44e587d (fase 2: e99ff1d..cc9e736) | APROVADO COM RESSALVAS | R15 só nos tiros (o acerto corpo a corpo da Sophia segue em 360°) |
| dir7/perigos7 | dc8eaa7 (WIP) | APROVADO (inofensivo: só recorte/ferramenta; auditoria real quando o perigo pintado entrar no jogo) | — |
| dir7/cenario7 | 54e3717 (WIP) | APROVADO (inofensivo: ferramenta HdShot + chave `hd_disabled`) | — |
| dir7/audio7 | 634bc91 (WIP) | **REPROVADO** sozinho (entra junto das 3 trocas do player.gd ou com o observador sem os 3 eventos) | R4/§4.3 (som dobrado), §4.7 (atk_* sem teto), true peak |
| dir7/dublagem | bf0c8b3 | APROVADO COM RESSALVAS (só ferramenta; nada entra no jogo) | R13 (true peak após codificar), bus Voice, tell × voz grave |
| dir2/arte-gpt | 4038d12 (delta de 62f3ed0) | APROVADO COM RESSALVAS (inofensivo, mas a R17 NÃO chega ao jogo) | R17 não entregue; R3/R21 no dia em que ligar |
| dir6/chefes6 | 7a934d9 (WIP) | APROVADO COM RESSALVAS (só o retrato WIP; reauditar o delta final) | R5/§5.6 (guarda do Astaphaios sem aviso), R11 (som da carga repete), falta CHECAGEM |
| dir5/encenacao5 | 0f04eff | APROVADO COM RESSALVAS | R6 parcial (faíscas do degrau sem orbe), §3 (presente de arma fura o selo — antigo) |
| dir7/polimento7 | 661a1a0 | APROVADO COM RESSALVAS | R10 (flash dos inimigos ainda 0,55), falta CHECAGEM DE SATISFAÇÃO no doc |
| dir2/arte-gpt | 62f3ed0 (+60a8cf7 já integrado) | APROVADO COM RESSALVAS | R10 (flash dos inimigos após a cor real), R18 |

---

## dir2/arte-gpt — 62f3ed0 (e 60a8cf7, já integrado em a2ea6c2)

**O que muda (código):** `assets/shaders/painted_flex.gdshader` (cor do vértice em `varying`: a pintura deixa de sair
"ao quadrado", mais escura e saturada); `scripts/fx/character_art.gd` (+`stop_action()`, poses `hold` de cena,
`bless_light()` = coluna de luz aditiva do Soter); `tools/anim_qa.gd` (`soter_board`); folha/JSON da Sophia
(poses `soter_look/land/bow`). O topo atual do branch é **14277f6 (WIP: morte de chefe em 4 etapas) — NÃO auditado**,
não integrar sem nova auditoria.

**Checagem:**
- **R10 (fotossensibilidade) — ok na luz do Soter:** `bless_light` tem alfa de pico 0,26 (faixa larga) e 0,30 (miolo),
  o miolo respira 0,55↔1,0 em 0,9 s + 0,9 s = **0,56 Hz** (limite 3 Hz), área estreita (≈1,2 × altura da Sophia de
  largura), cor morna, sem vermelho. `character_art.gd` (`bless_light`, laços de 2 camadas × 10 faixas).
- **R10 — RESSALVA (efeito colateral do 60a8cf7, já integrado):** com a cor real a pintura ficou mais clara
  (luminância média do atlas da Sophia 0,39 → 0,53, medida do polimento7). A Sophia foi recalibrada no
  polimento7 (`Player.FLASH_ADD` 0,6 → 0,42), mas o flash dos INIMIGOS continua `Enemy.FLASH_ADD := 0.55`
  (`scripts/entities/enemy.gd:59`) — calibrado para a cor antiga. Pela mesma conta (×0,7), o equivalente é ≈ **0,38–0,40**.
  Sem isso, cada acerto estoura mais área do corpo do inimigo em branco (mais "clarão" por acerto, §4.4; R4: dose média).
  **Dono:** polimento7 (o pedido dele já cobre "hitbox/flash" em `enemy.gd`) — correção mínima: `FLASH_ADD` dos inimigos
  ≈ 0,40, medido no atlas das criaturas como foi feito na Sophia.
- **R18 (legibilidade) — ok/a confirmar:** a cor real aumenta a luminância dos personagens; contra os fundos escuros dos
  Éons isso tende a SUBIR o contraste. Não medi 3:1 em escala de cinza nesta rodada (fica para a auditoria geral, TAREFA 1).
- **R19/R20 (animação):** as poses de cena são paradas (`hold`), sem squash; a pose solta sozinha quando ela se mexe
  (`_tick_action`: `anim_state != "idle"` → `_action = ""`) — o jogador nunca fica preso pela arte. ok.
- **§3/§4:** nada de economia. ok.

**Veredito: APROVADO COM RESSALVAS** (62f3ed0 pode entrar; ressalva R10 vai para o polimento7). 14277f6+ = reauditar.

---

## dir7/polimento7 — 661a1a0

**O que muda:** `enemy.gd` `_fit_hurtbox_geometry()` (hurtbox = 80 % da largura × 92 % da altura do corpo DESENHADO por
quadro, `frame_geometry(true).body`, suavizado 0,5/quadro); `player.gd` `FLASH_ADD` 0,6 → 0,42 (cor real da pintura);
`tools/combate/hitbox_probe.gd` mede contra o corpo da API; docs.

**Medido (HitboxProbe no 661a1a0, worktree de sonda, headless 60 fps)** — log `C:\gnosis-wt\_caps\guardiao\hitbox_polimento7.log`:
- caixa do cajado desenhado: esperados 128, reais 134, certos 128, **atravessa 0**, **apelão 6 (4 %)**
  (base do próprio polimento7, 18/10: atravessa 1, apelão 11 — melhorou nas duas pontas).
- contra o corpo (frame_geometry): o cajado encostou 134×, sem dano em **5 (3,7 %)** — sobra um resto pequeno do
  "cajado atravessa" (playtest 2 #3), aceitável.
- contato: Sophia colada num bruto 1,5 s: vida 120 → 120 (dano de contato continua desligado).
- `QA PASS: HitboxProbe (atravessa 0 %, apelão 4 %)`.

**Checagem:**
- **§5 item 2 ("o golpe entra?") / SDT competência:** acerto mais fiel ao desenho, sem ímã — atende.
- **R1:** flash continua instantâneo, ≤ 100 ms reais (`FLASH_TIME 0.10`, `FLASH_HOLD 0.035`). Atende.
- **R10:** Sophia recalibrada (0,42, mesmo pico de luminância medido, 35 % do corpo estourado). Atende para ela.
  **RESSALVA:** o flash dos inimigos (`Enemy.FLASH_ADD := 0.55`, `enemy.gd:59`) não foi recalibrado para a cor real
  (o 60a8cf7 vale também para as criaturas). Correção mínima: medir igual no atlas das criaturas e baixar para ≈ 0,40.
- **Regra da equipe:** `docs/onda2/POLIMENTO7.md` **não tem a seção "CHECAGEM DE SATISFAÇÃO"** (obrigatória desde 18/10).
  Correção mínima: acrescentar (hurtbox → §5.2/R1; FLASH_ADD → R1/R10).
- Nada de economia, tremor, hitstop, som ou VFX novo.

**Veredito: APROVADO COM RESSALVAS** (entra; as 2 ressalvas vão para o próximo commit do polimento7).

---

## dir5/encenacao5 — 0f04eff (cena do Soter; inclui o merge de arte-gpt 62f3ed0, aprovado acima)

**Delta próprio (fbd46c8..0f04eff):** `scripts/entities/npc_encounter.gd` (poses do Soter lift/talk/offer/rest, poses de
cena da Sophia soter_look/land/bow com `stop_action()` ao fechar, `bless_light` com sprite antigo de reserva, 0,9 s de
respiro antes do prompt, `rest` + 1,6 s antes de partir) e `docs/onda2/NARRATIVA6.md` (CHECAGEM DE SATISFAÇÃO).

**Checagem (conferida contra o código, não só contra o doc):**
- **R21 (respiro):** 0,9 s sem prompt depois da fala (`npc_encounter.gd`, `create_timer(0.9, …, true)`), 1,6 s de `rest`
  antes de partir. Atende.
- **Autonomia (SDT) / sem armadilha:** o mini-desafio do degrau espera até `LEDGE_WAIT = 45 s` (l. 20) e libera se ela se
  afastar > 520 px; a pose `hold` solta assim que ela se mexe (character_art). Ninguém fica preso. Atende.
- **Ensinar fazendo (playtest #10/#11):** concede o pulo duplo, mostra o degrau aceso e pede o duplo na hora, com o
  degrau ficando para treinar. Atende (competência).
- **R10:** coluna de luz 0,56 Hz, alfa ≤ 0,3; sem clarão de tela. Atende.
- **§3:** recompensa FIXA de 30 faíscas ao pisar no degrau (l. 178), sem sorteio, sem prazo visível. Atende.
- **R6 — PARCIAL:** as 30 faíscas são creditadas de uma vez (`Progression.add_orbs(30)`) com `stele_unlock` a −4 dB, sem
  orbe voando nem o tique pentatônico na chegada. Correção mínima (opcional, não bloqueia): soltar os orbes do degrau
  pelo `SparkOrb` (mesmo caminho das mortes) para o som chegar junto da recompensa.
- **§3 — RESSALVA ANTIGA (não é deste delta):** o presente de arma do Soter faz `weapon_level += 1` direto
  (`npc_encounter.gd:~109-113`) e fura o selo por Arconte de `Progression.gift_weapon_level()` (PROGRESSAO6 §8).
  Dono: narrativa6/encenacao5 + progressao6. Correção mínima: chamar `gift_weapon_level()`.
- O doc alega "música −14 dB no encontro" (R9): não medi o áudio nesta rodada (sem som); fica como alegação.

**Veredito: APROVADO COM RESSALVAS.**

---

## dir6/chefes6 — 7a934d9 (WIP; d09566d auditado por funcionário + bf67430/5abf958/7a934d9 por mim)

**O que muda:** recalibração de vida/dano para o dano REAL da Sophia (`BossTuning.expected_hit` ← `SophiaTuning.move_damage`;
golpes-alvo: Rei 30, Sono 21, Fome 30, Corrente 38, Silêncio 28, Espelho 28, Praga 26, Coroa 26, final 16/forma, Colosso 18;
`dmg_scale` Armupiel 0,27, Colosso/final 0,30, Astaphaios 0,42, Belias 0,45, Harmas 0,55); Armupiel: corte 1×/fase,
Pretorianos com vida ≈ 4 golpes, `spark_reward` 0 e meio dano; Espadão com recuperação maior (1,25 s) e onda mais lenta;
ganchos do VFX7 (carga no preparo do tiro, cancelada em STAGGER/HURT/DEAD); golpes utilitários com `"tell": false`.

**Checagem:**
- **R3 (tremor raro) — atende/melhora:** `boss_brain.gd` strike 0,5 → 0,35; Colosso 0,8 → 0,5; `boss_hazard.gd` coluna deixa
  de tremer (só "arena" 0,35). Corte real: `AoeNova` treme 0,45, mas agora 1×/fase.
- **R5 (telegrafo) — atende nos golpes:** todo tiro tem carga (forma de círculo que fecha + cor + som) pelo `wind_up` inteiro
  (0,65–0,85 s), glint Z+7/Z+8 acima da carga (Z). Decreto do Armupiel avisa 1,15 s; `dupla_b` 0,7 s. O `_glint_done` é
  rearmado a cada `_begin_windup` (`enemy.gd:689`), então o `"tell": false` não vaza para o golpe seguinte.
- **R5 / §5.6 — RESSALVA (Astaphaios `guarda`):** a guarda REFLETE o golpe da Sophia (`_filter`: dano × REFLECT_K,
  imparável) e agora não tem nenhum aviso no preparo (0,4 s, `"tell": false`); o anel de vidro só aparece quando a guarda
  já está ativa (`_on_strike` → `_show_ring`). Uma Sophia no meio do combo (o final "compromete") toma o reflexo sem
  aviso legível. Tirar o AMARELO está certo (amarelo = aparável), mas a guarda precisa de um aviso PRÓPRIO.
  Correção mínima: mostrar o `MirrorRing` (ou um anel de vidro azul crescendo) + som "glass" já no INÍCIO do wind
  (0,4 s), não no strike. Os outros `"tell": false` (pisca, deslize, troca, teleporte, larvas, corte real, reflexos)
  não causam dano por si — ok.
- **R4/R11 — DÚVIDA (dono vfx7/audio7, não o chefes6):** sem `charge_dark` no catálogo, a carga usa "proj_fire" a pitch
  0,55/−9 dB e o disparo toca "proj_fire" de novo: o mesmo arquivo 2× por tiro de chefe. Pedido já em
  `docs/pedidos/vfx7.md`; precisa entrar antes da 3.1.
- **Dano de contato:** continua desligado (`enemy.gd` `monitoring=false`); chefe só fere no contato em investida. Atende.
- **§3:** Pretorianos e reflexos com `spark_reward` 0 (fixo). Atende.
- **Dificuldade (playtest #3/#9):** ainda FORA da meta pelo próprio CHEFES6 (r7: Armupiel 219 s/10 quase-mortes,
  final 292 s/14). Não sondei o 7a934d9 (WIP). Lembrete §4/§3: dificuldade por leitura e padrão, não por vida inflada; a
  queda de dano do Armupiel (0,4 → 0,27) vai na direção certa.
- **Regra da equipe:** `docs/onda2/CHEFES6.md` não tem a seção "CHECAGEM DE SATISFAÇÃO". Correção: acrescentar.
- Nada de hitstop > 200 ms, slow-mo novo, clarão de tela ou flash vermelho novos.

**Veredito: APROVADO COM RESSALVAS para o retrato 7a934d9** — não bloqueia a prévia se for preciso integrar o WIP, mas a
ressalva da guarda do Astaphaios (R5) deve ser corrigida antes da versão "redonda"; o commit final exige reauditoria do delta.

---

## dir2/arte-gpt — 4038d12 (delta 62f3ed0..4038d12: morte de chefe em 4 etapas)

**O que muda:** folhas `boss_<n>_<nome>_death_a.png` → estado `dying` nos 9 `*_frames.json` (tranco, cambaleio, joelhos,
tombado; `dur` 0,17/0,17/0,28, o tombado segura); `character_art.gd`: `_death_seq` prefere `dying`, `_boss_index` indexa
pelo relógio da morte (`_death_t`); `tools/anim_bosses/add_death.py`; AnimQA `death_board`; CHECAGEM (R17–R20) no ARTE_GPT.md.

**Prova vista:** `C:\gnosis-wt\_caps\arte-gpt\fila9\death_board.png` — as 4 etapas leem bem nos 9 chefes (silhueta muda
de verdade: em pé → curvado → joelhos → deitado com contorno). Como arte, atende R17 ("acabou" sem olhar a barra).

**ACHADO PRINCIPAL — a morte em 4 etapas não aparece no JOGO:** `_death_seq` só roda com `_death_t >= 0`
(`character_art.gd` `_boss_seq`, ~l. 2305), e `_death_t` só é ligado por `play_boss_death()` (l. 2503–2505). Ninguém
chama `play_boss_death()` fora das ferramentas: `git grep` em integracao/onda1, arte-gpt, chefes6, vfx7 e polimento7 → só
`tools/anim_qa.gd:523,697` e `tools/puppet_qa.gd:215`. O sinal `Enemy.boss_dying(step)` (emitido pelo
`BossBrain._death_sequence`, 0..4) não tem nenhum ouvinte. No jogo, a morte do chefe continua: cérebro (2,45 s:
`DEATH_STEPS [0.35, 0.55, 0.95, 0.6]`) → `_death_pose_then_burst` (quadro "dead" 0,4 s) → gibs. A prova é da AnimQA, que
chama `play_boss_death()` direto. → a CHECAGEM do doc ("R17 atendida") **não se confirma no jogo**.

**R8 / R21 / R3 — o que fica em risco NO DIA em que alguém ligar (`play_boss_death` no `boss_dying(0)`):**
- duas linhas do tempo competindo: a arte estilhaça em 1,08 s e encerra em 1,9 s; o cérebro segura até 2,45 s e então
  `_death_pose_then_burst` (+0,4 s) faz OUTRO fim (gibs). Resultado: dois finais ou um corpo invisível esperando 1,4 s.
- tremor empilhado em ~2,9 s: cérebro 0,8 (impacto) + arte 0,7 (joelhos, `_tick_death`) + cérebro 0,5 (colapso) +
  `_death_pose_then_burst` 0,9 (gibs). R3 pede o ápice UMA vez (morte de chefe 0,9–1,0); 4 tremores grandes seguidos
  é o §4.1. O slow-mo (0,3 × 1,0 s, só chefe) e o hitstop 0,2 s estão dentro do R8/R2.
- duração: 2,45 + 0,4 = **2,85 s reais** até os gibs, com duck de música −14 dB por 3 s (R9 ok). Aceitável para
  um chefe (evento raro), mas não pode crescer: somar 1,9 s da arte por cima passaria de ~3 s com o controle "morto".

**Correção mínima (dono: chefes6 + arte, combinar por docs/pedidos):** UM dono da linha do tempo — o `BossBrain`
chama `visual.play_boss_death(eye_color)` no passo 0 (ou o `CharacterArt` ouve `boss_dying`), alinha `DEATH_STEPS` com
os 0,34/0,62/1,08/1,9 da arte, e o `_on_died` NÃO faz o `_death_pose_then_burst` quando `visual.is_dying()` (os cacos da
arte já são o fim). Tremor: só o do impacto (≤ 0,5) e o do estilhaço (0,9); tirar o 0,7 dos joelhos ou o 0,5 do
colapso. Depois disso, reauditoria com captura em jogo (Shot `kill` num chefe).

**Veredito: APROVADO COM RESSALVAS** — o delta é inofensivo (não muda timing, tremor nem som do jogo; só dados de
quadros e o índice), então pode entrar; mas a R17 pretendida **não está entregue** até a ligação acima existir, e a
ligação precisa vir com a linha do tempo única (R3/R21).

---

## dir7/audio7 — 634bc91 (WIP: a3c2317 sons, 8803bd2 CATALOG/ganchos, bf3bcc3/634bc91 pedidos, 70044eb observador `_Watch`)

Medições offline (funcionário, ffmpeg ebur128 + numpy; NADA tocado): `C:\gnosis-wt\_caps\guardiao\audio\audio7_meas.json`,
`base_meas.json`. 143 .ogg novos (118 sons).

**Atende (com evidência):**
- **R8:** passa-baixas no slow-mo 1,5 kHz (2,5 kHz na esquiva), entra 60 ms / sai 250 ms, música −4 dB; bus Tell fora do
  filtro (`audio_manager.gd:56-70`, ~1048).
- **R9:** silêncio pré-chefe (`PRE_BOSS_FADE` 0,6 s, faixa de chefe 0,3 s depois do stinger); morte do chefe
  `duck_music(3, −14)` + −30 dB no `boss_die`.
- **R11:** `MAX_SAME 3`, limitador no Master −1 dB, round-robin sem repetir, ±1,5 dB, ±4 % tom; 3 variações em
  hit/hit_heavy/swing/step/enemy_hurt (land 2).
- **R12:** atk_slam/atk_nova com transiente 4–7 ms e 42–79 % da energia < 90 Hz; leves sem sub (atk_swing 0 % < 90 Hz).
- **R13:** música de Éon −16,0 LUFS × chefe −15,9 no arquivo; os 3 LU vêm do `EON_MUSIC_DB −3` no código.
- **R14:** pan × 0,5 em 5 degraus; sons novos de inimigo/perigo por `play_sfx_at`.
- **R6, R22, §4.8, §4.10:** tique na chegada do orbe subindo; coração 63 Hz ≤ 8 s; voz de dor ≤ 1/250 ms; impacto não
  sobe de tom com o combo.

**VIOLA (introduzido pelo branch):**
- **R4 / §4.3 — dois sons no MESMO evento:** o `_Watch` toca `double_jump` e o `player.gd:432` continua tocando `jump`
  (o próprio código diz "o `jump` do player continua"); `star_charge` + `dive` (`player.gd:542`) na Queda Estelar;
  `riposte` + `_swing_sfx` (`player.gd:628`) no contra-ataque. Nos tiros hostis, `atk_shot/fan/homing` (observador) +
  `proj_fire` (`projectile.gd:55`) = 2 sons por tiro (o próprio `docs/pedidos/audio7.md` admite "Hoje são 2 sons por tiro").
  O branch depende de TROCAS que outros donos ainda não fizeram: integrado sozinho, o jogo fica com som dobrado.
- **§4.7 — risco de repetição:** um `atk_*` em TODO golpe de TODO inimigo, só com o anti-spam de 40 ms; atk_fan, burst,
  homing, lob com 1 variação, atk_combo/rush/leap/slam/wave/dive com 2. Com 4–6 inimigos isso passa de dezenas/min.

**Parciais:** R5 `tell_parry` ~93 ms acima de −20 dB (alvo 40 ms); R9 sem ducking de −6..−8 dB em ring_gain/ring_steal/
level_clear/weapon_upgrade nem −3 dB no parry; R8 o slow-mo da morte de chefe (escala 0,3) cai no caso "esquiva" (2,5 kHz);
true peak: o funcionário mediu 7 arquivos acima de −1 dBTP (hz_spears −0,2; boss_death_impact, boss_phase3, bs_bite,
bs_hand, bs_land −0,8; bs_wings −0,9); minha contraprova do hz_spears deu −1,0 dBTP (limiar). O limitador do Master
segura o pico de amostra; vale baixar 0,5–1 dB nesses 7 na síntese (`onda7.py`) para ter folga.

**Correção mínima para virar APROVADO:**
1. Até as trocas do `player.gd` e do `projectile.gd` entrarem, o `_Watch` NÃO toca `double_jump`, `star_charge` e `riposte`
   (ou o chefe integra o audio7 JUNTO do commit do combate/polimento que faz as 3 trocas + a do `proj_fire` hostil).
   Melhor: o observador checa uma flag do player (`sfx_owned_by_watch`) antes de tocar.
2. `SPAM_OVERRIDE` 120–150 ms e `MAX_SAME_OVERRIDE` 2 para `atk_*`.
3. (não bloqueia) 3ª variação para atk_combo/rush/leap/dive e 2ª–3ª para atk_fan/burst/homing; −0,5 a −1 dB nos 7 arquivos.

**Veredito: REPROVADO no 634bc91 como entrega isolada** (R4 violada por construção). Com o item 1 resolvido (por qualquer
dos dois caminhos) e o item 2, passa a APROVADO COM RESSALVAS — reauditoria só do delta.

---

## dir7/dublagem — bf0c8b3

**O que muda:** só ferramentas/docs (`voicelib.py`, DUBLAGEM.md); nenhum `.gd` e nenhuma voz no jogo. Amostras
medidas (72, `_caps/dublagem/amostras`; medições `C:\gnosis-wt\_caps\guardiao\audio\dub_meas.json`):
loudness −21,7 / −19,0 / −17,8 LUFS (alvo −18; 36/72 mais de 1 LU abaixo), true peak máx −0,5 dBTP — **29/72 acima de −1
dBTP** (o teto de −1 dBFS é aplicado ANTES do Vorbis, `voicelib.py:224-227`, e a codificação sobe o pico), 2–5 kHz mediana
2 % (ok). Plano de ducking (DUBLAGEM §7.6: música −9 dB no diálogo, −3 dB extra com voz) atende R9.

**Ressalvas para quando a voz ENTRAR (não bloqueiam este branch):**
- **R13:** medir o true peak DEPOIS de codificar e renormalizar (loudnorm 2 passes, −18 LUFS / −1,5 dBTP).
- **bus Voice** está dentro do SFX (`audio_manager.gd:298`): pegaria o slider de efeitos e o abafado do slow-mo. Levar ao Master.
- **R5:** nada protege o `tell_unblock` (80–250 Hz) de vozes graves (Yaldabaoth/Armupiel, F0 95–138 Hz) ao mesmo tempo:
  legenda falada em luta com voz −3 dB e o bus Tell nunca abaixa.
- Sem fala repetida em combate (cada fala é única) — ok para §4.8.

**Veredito: APROVADO COM RESSALVAS** (não muda o jogo; as ressalvas são condição para a integração das vozes, versão 3.3).

---

## dir7/vfx7 — 44e587d (fase 2: e99ff1d, 58e2d3a, 994e0f1, cc9e736; base da diferença 0a77007)

**O que muda:** `enemy_overlay.gd` observa o golpe do inimigo (carga `charge_up` no wind-up de TIRO, cancelada se o golpe
morrer; rastro `melee_slash` quando a caixa corpo a corpo liga); `vfx_library.gd` (`melee_slash`, `claw_impact`,
`_spray` em cone ±50° + 20 % em 360°, contagem do teto sem montar Array); `impact_burst.gd` (acerto de inimigo na Sophia →
`claw_impact` no lugar do `hit`); `hazard_zone.gd` premium (névoa, bolhas, coluna); `projectile.gd` não redesenha com
visual premium; CHECAGEM DE SATISFAÇÃO no VFX7.md.

**Checagem (código lido):**
- **R4:** `claw_impact` SUBSTITUI o `VfxLibrary.hit` no acerto de inimigo (o `ImpactBurst` retorna antes); `_claim` evita
  o segundo `hit` no mesmo ponto. Um evento por acerto — atende. Dose do `claw_impact` (3 garras + luz + anel + 8–12
  fagulhas + fumaça) é alta, mas é dano RECEBIDO (informação, ≤ 1 por golpe inimigo) e passa pelo `flash_budget()`.
- **R5:** o rastro do golpe sai no STRIKE (depois do glint, nunca por cima do aviso); imparável ganha borda vermelha na mesma
  forma; z do rastro = inimigo + 2 (relativo), glint em Z+7/Z+8. Carga dos tiros com forma (espinhos fechando). Atende.
  Obs. de integração: os chefes já criam a própria carga no `BossBrain._start` (chefes6). A overlay só existe para inimigos com
  `moves`/Elite/Campeão (`enemy._setup_layers`), então não há carga dupla nos chefes hoje — se um chefe ganhar `moves`,
  vira carga dupla.
- **R10:** `flash_budget()` (3 cheios/s, resto 30 %, "Reduzir flashes" corta) em todo clarão novo; sem `screen_flash`; o
  brilho que corre na borda das zonas gira a 2–5 rad/s (≤ 0,8 Hz por ponto). Atende.
- **R15 — PARCIAL (RESSALVA):** o cone ±50° está no `_spray` (impactos de PROJÉTIL/ataque premium). O acerto MAIS COMUM do
  jogo, o golpe corpo a corpo da Sophia (`hitbox.gd` → `ImpactBurst.spawn` → `VfxLibrary.hit`), continua com
  `direction (0,−1)`, `spread 180` (círculo inteiro), as 7 fagulhas vetoriais do `ImpactBurst._ready` em ângulo aleatório
  em 360° e o talho do pesado em `randf_range(-0.7, 0.7)` (±40°; a R15 pede ±15° alinhado ao arco). O próprio VFX7.md
  admite que o `ImpactBurst` não recebe o lado do golpe. Correção mínima: `ImpactBurst.spawn(..., dir_x)` com o `facing`
  do dono (o `hitbox.gd` já o calcula para o `Juice.kick`) → `hit()` usa o cone do `_spray` e o talho ±15°. Donos:
  vfx7 (API) + polimento7/combate (passar o lado no `hitbox.gd`).
- **R18:** o doc mede 10,2–12,7 : 1 para os tiros novos (alvo ≥ 3:1); zonas de chão atrás dos personagens (z −1). Aceito
  como medida do dono (não refiz).
- **§4:** sem `Juice.shake` novo, sem clarão de tela, nada de economia.

**Veredito: APROVADO COM RESSALVAS** (R15 incompleta no golpe principal; a ressalva não piora nada que já existe).

---

## dir7/perigos7 — dc8eaa7 (WIP) e dir7/cenario7 — 54e3717 (WIP)

- **perigos7:** só o recorte das folhas `hz_1..hz_7` (`tools/hazards7/*.py`, PNGs, `assets/painted/hazards/hazards_data.gd`
  +4 linhas de catálogo). Nenhum perigo do jogo muda ainda.
- **cenario7:** ferramenta `tools/cenario7/HdShot` + `Scenery.hd_disabled` (static, falso por padrão; só ferramenta liga).
- Nada toca combate, VFX de jogo, som, economia ou UI → **APROVADO (inofensivo)**. A auditoria de verdade vem quando o
  perigo pintado e o fundo HD entrarem no jogo. Vou cobrar: R5 (todo perigo avisa com forma + som antes de ferir; o
  audio7 já tem `hz_*`), R18 (fundo HD 10–25 % menos saturado que os personagens, contraste ≥ 3:1 em escala de cinza),
  R10 (perigos que piscam ≤ 3 Hz) e §4.11 (cor nunca é o único aviso).
