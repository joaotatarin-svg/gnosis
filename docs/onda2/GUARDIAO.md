# GUARDIÃO DA SATISFAÇÃO — auditorias (branch `dir7/guardiao`)

> Lei: `docs/handoff/NEURO_SATISFACAO.md` (§2 R1–R22, §3 recompensa ética, §4 o que NÃO fazer, §5 checklist).
> Vereditos: **APROVADO** / **APROVADO COM RESSALVAS** (entra; ressalva vira pedido ao dono) / **REPROVADO** (não entra).
> Branch que muda depois de aprovado precisa de reauditoria do DELTA (o veredito vale para o commit citado).
> Sondas: `tools/guardiao/**`. Capturas e logs: `C:\gnosis-wt\_caps\guardiao\`.

## Índice de vereditos (o mais novo em cima)

| Branch | Commit auditado | Veredito | R |
|---|---|---|---|
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
