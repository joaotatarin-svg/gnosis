# GUARDIÃO DA SATISFAÇÃO — auditorias (branch `dir7/guardiao`)

> Lei: `docs/handoff/NEURO_SATISFACAO.md` (§2 R1–R22, §3 recompensa ética, §4 o que NÃO fazer, §5 checklist).
> Vereditos: **APROVADO** / **APROVADO COM RESSALVAS** (entra; ressalva vira pedido ao dono) / **REPROVADO** (não entra).
> Branch que muda depois de aprovado precisa de reauditoria do DELTA (o veredito vale para o commit citado).
> Sondas: `tools/guardiao/**`. Capturas e logs: `C:\gnosis-wt\_caps\guardiao\`.

## Índice de vereditos (o mais novo em cima)

| Branch | Commit auditado | Veredito | R |
|---|---|---|---|
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
