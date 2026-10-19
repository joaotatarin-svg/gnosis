# GUARDIÃO DA SATISFAÇÃO — auditorias (branch `dir7/guardiao`)

> Lei: `docs/handoff/NEURO_SATISFACAO.md` (§2 R1–R22, §3 recompensa ética, §4 o que NÃO fazer, §5 checklist).
> Vereditos: **APROVADO** / **APROVADO COM RESSALVAS** (entra; ressalva vira pedido ao dono) / **REPROVADO** (não entra).
> Branch que muda depois de aprovado precisa de reauditoria do DELTA (o veredito vale para o commit citado).
> Sondas: `tools/guardiao/**`. Capturas e logs: `C:\gnosis-wt\_caps\guardiao\`.

## TAREFA 1 — auditoria do que JÁ está no jogo (origin/integracao/onda1 @ 0cc4aa5, 19/10)

Método: li o código integrado (worktree de sonda `C:\gnosis-wt\guardiao_sonda`), rodei sondas headless
(HitboxProbe, FeelProbe, FlashParryProbe), medi os .ogg offline (ffmpeg ebur128 + numpy, NADA tocado:
`_caps\guardiao\audio\base_meas.json`) e fiz 4 capturas mínimas 320×180 (telas 3, 22, 40, 58:
`_caps\guardiao\r18_grade.png` e `r18_grade_cinza.png`). O feel e o timing finos ainda dependem do playtest do João (§5).

| R | Estado | Evidência | Dono da correção |
|---|---|---|---|
| R1 flash + vibração no hitstop | **ATENDIDA** | `enemy.gd` `_flash()` é instantâneo (camada aditiva) e apaga em `FLASH_FADE 0,11` s reais. Vibração `VIB_LIGHT 1,5` / `VIB_HEAVY 3,0` px em relógio real. Sophia: `FLASH_TIME 0,10`, `VIB_AMP 1,5` | — |
| R2 hitstop por peso, o maior vence | **ATENDIDA** | `juice.gd:192-201`: 50/90/108 ms, +33 na morte, +17 na multidão, 25 no multi-hit, 75 no dano, 100 na queda, teto 200. `hit_stop()` estende até o maior (l. 263-269). Um por golpe (`hitbox.gd` `_flush_impact`). A entrada apertada no hitstop fica guardada | — |
| R3 tremor dedup / Perlin / chute | **PARCIAL** | Na Sophia está ok: maior pedido do quadro (`camera_shake.gd` `_frame_trauma`), Simplex 15 Hz, chute 2/4 px, leve = 0, pesado 0,30, dano 0,35. O problema são os inimigos COMUNS, que tremem a tela em golpe de rotina: pancada 0,35 (`enemy.gd:802` e `:1846`), explosão 0,45 (`:874`), agarrão 0,35 (`:2266`), fúria do Campeão 0,4 (`:2080`). A morte de chefe ainda empilha 0,8 + 0,5 + 0,9 (`boss_brain` + `_death_pose_then_burst`). §4.1 | inimigos6 (comuns: ≤ 0,15 ou só quando ACERTA a Sophia); chefes6 (morte com um ápice só) |
| R4 um acerto = um evento | **ATENDIDA** | `hitbox.gd:133-139`: um VFX por par, no ponto de contato. Som 1× por golpe, e o pesado toca NO LUGAR do leve (`:173`). Voz de dor ≤ 1 a cada 250 ms. `ImpactBurst` → `ProjectileFX`/`_claim` evita duplicar | (audio7: não pode reintroduzir a dobra) |
| R5 telegrafo glint / forma / som | **ATENDIDA** (com ressalvas) | Glint 180 ms antes (`enemy.gd:701`), redondo amarelo × losango vermelho, em Z+7/+8. Os sons `tell_parry`/`tell_unblock` existem. Tinta 45 % + pulso 2 Hz (`enemy.gd:52-54`). `_flash` volta à cor-base (bug corrigido). Ressalvas: `tell_parry` dura ~93 ms (alvo 40); o golpe aparado que ainda feria só foi corrigido no polimento7 87290ca | polimento7 (integrar 87290ca); Áudio |
| R6 faísca na chegada, em escala | **ATENDIDA** | `spark_orb.gd:102-109`: `spark` toca na CHEGADA (5 variações em sequência subindo) e o HUD conta 1 a 1 | — |
| R7 adoçante tonal do combo | **PARCIAL (quase nada feito)** | `hud.gd:312-320` só tem o pop 1,25→1,0. Não há tique de combo, nem marcos 10/25/50, nem filete de validade | Áudio (`combo_tick`) + UI |
| R8 slow-mo abafado, em rampa, racionado | **ATENDIDA** | Racionado: chefe sempre; inimigo comum só no fim da tela ou com golpe grande (`enemy.gd:1176-1183`). Rampa de 0,18 s. Passa-baixas pelo `slowmo_changed`. Detalhe: a morte de chefe (escala 0,3) cai no corte de "esquiva" (2,5 kHz) | Áudio (o Juice informa o tipo do slow-mo) |
| R9 ducking e silêncio | **PARCIAL** | Silêncio pré-chefe e duck na morte do chefe ok. Falta duck em ring_gain, ring_steal, level_clear e weapon_upgrade (−6..−8 dB) e no parry (−3 dB): `audio_manager.gd:1065` só trata boss_appear e boss_die | Áudio |
| R10 ≤ 3 flashes/s, "Reduzir flashes" | **ATENDIDA** | `Juice.flash_strength`: 333 ms, meia força, chefe 2,0, ×0,5 no modo reduzido. Opção no menu (`options_menu.gd:79`). Dano na Sophia em branco quente, não vermelho. `screen_flash` só na fase 2 e na morte de chefe, 35 % no modo reduzido. Ressalvas: a FlashParryProbe falha com `--fixed-fps` (artefato do relógio de parede); o clarão de tela usa a `eye_color` do chefe, então um chefe de olho vermelho dá clarão vermelho a α 0,6 (§4.4). Conferir | combate (sonda); VFX (clarão sem vermelho saturado) |
| R11 round-robin, vozes, limitador | **ATENDIDA** | 3 variações de hit, hit_heavy, swing, step e enemy_hurt; `MAX_SAME 3`; HardLimiter no Master | — |
| R12 grave com harmônicos | **PARCIAL** | `hit_heavy` tem 78–86 % da energia abaixo de 90 Hz e `nova` 69 %: ok. Mas o `hit` LEVE tem 42–44 % abaixo de 90 Hz em 2 das 3 variações, e a R pede leve sem sub | Áudio |
| R13 loudness | **PARCIAL / não medida** | Não gravei a mixagem de 10 min (regra de silêncio). Arquivos base com true peak acima de −1 dBTP: hit −0,7, hit_heavy −0,6, nova −0,4, swing_heavy_3 −0,5 (o limitador segura) | Áudio (gravar 10 min offline com o bot + ebur128) |
| R14 estéreo × 0,5 | **ATENDIDA** | `audio_manager.gd:62-68` | — |
| R15 fagulhas na direção do golpe | **VIOLADA** | No golpe corpo a corpo, que é o mais comum, o `hit()` de `vfx_library.gd` usa `spread 180` (360°) e o talho sai em `randf_range(-0.7,0.7)` (±40°). `impact_burst.gd:32-34` solta 7 fagulhas em 360°. O vfx7 fase 2 só corrigiu os tiros | vfx7 (API com o lado do golpe) + polimento7 (`hitbox.gd` passa o `facing`) |
| R16 números de dano | **PARCIAL** | A opção liga/desliga existe (`options_menu.gd:105`). Falta agrupar os acertos em 300 ms, o teto de 6 e o pop de entrada (`damage_number.gd:19-29`) | UI |
| R17 confirmação de morte | **PARCIAL** | O golpe que mata ganha +33 ms de hitstop. Falta o impacto 2 semitons abaixo / +2 dB e o contorno branco de 1 quadro. A morte de chefe em 4 etapas está desenhada, mas NÃO está ligada ao jogo (ver arte-gpt 4038d12) | Áudio + combate; chefes6 + arte |
| R18 legibilidade 3:1 | **PARCIAL (risco alto)** | No teste do apertar de olhos em cinza (`r18_grade_cinza.png`), as telas 40 e 58 têm fundo claro e cheio de contraste interno (raios, arcos), e a Sophia, que é clara, se mistura. Estimativa grosseira Sophia × fundo local: 1,5–2,2 : 1 (alvo ≥ 3:1; medida a 320×180, sem inimigos na tela). A Sophia não tem luz de contorno (o `painted_flex` não tem rim; os inimigos têm o `enemy_grade`) | cenario7 (fundos HD com 15–25 % menos contraste e saturação no plano de jogo) + arte (rim de 1 px na Sophia) |
| R19 smear + segurar pose | **ATENDIDA** | Smear do cajado de 110 ms (`character_art.gd` `_draw_smear`; o alvo é 60–90, um pouco longo). Não verifiquei se a pose de impacto é segurada | (arte, ajuste fino) |
| R20 squash moderado | **ATENDIDA** | `player.gd` `_squash` limita a ±7 % (x·y ≈ 1), 60 + 160 ms | — |
| R21 respiro + HUD recua | **PARCIAL** | O HUD recua a α 0,6 após 4 s (`hud.gd:55-58`). Mas entre ondas são só **0,8 s** (`level.gd:803`), e o alvo é 2–4 s | level6 |
| R22 vida baixa discreta | **ATENDIDA** | Vinheta abaixo de 25 %, 0,9 Hz, no máximo 8 s por dano (`hud.gd:60-62, 492-500`); coração em 63 Hz | — |

### §3 (recompensa ética) e §4 (excessos): economia, baús, segredos, faíscas, mapa
(um funcionário leu e citou arquivo:linha; eu conferi os pontos críticos)
- **Determinística, sem cassino.** Cada inimigo paga `spark_reward × _reward_mult` (curva por tela × dificuldade). O baú paga
  `15 + 2·tela` (`chest.gd:85-101`). Selos, Adormecido e baú saem por `tela % N` (`level.gd:540-556`). A recompensa do nó do mapa
  vem de tabela fixa e aparece ANTES da escolha (`eon_map.gd:108-114`, `world_map.gd:249-250`). RNG só existe em VFX, som e IA,
  ou com semente por tela. **Nenhum** `Time.get_date` ou `unix` ligado a recompensa, nenhuma sequência diária, e as conquistas são permanentes.
- **RISCO §3 / grind (donos level6 + mapa6).** Morrer e refazer o trecho paga DE NOVO o baú, os Selos, o Adormecido e a
  recompensa do nó, porque nada registra o que já foi coletado. Com banco baixo, morrer pode dar lucro e anular o custo da morte.
  Bug junto: `sleepers_freed` conta 2× (`sleeper.gd:43-44`), o que afeta o final "Semente" e uma conquista.
- **RISCO leve §3 (aversão à perda).** Morrer tira 20 % das faíscas não gastas (`level.gd:1009-1011`). É anunciado e
  proporcional, então é aceitável, mas só fica coerente depois de corrigir o item acima.
- **Balanceamento (progressao6).** A dificuldade multiplica a RENDA (Difícil 1,5×, Muito Difícil 2,2×) e os preços não mudam,
  então no Difícil a loja inteira cabe. Falta decidir se a dificuldade deve escalar as faíscas.
- **Misericórdia oculta** (`health_component.gd`): limiar acima de 10 % (o doc sugere acima de 30 %), 1× por zona, com flash e hitstop. Ok;
  decidir o limiar com o João.
- Até o 2º chefe (bot, PROGRESSAO6), dá para comprar ~27–45 % do que está aberto, e o selo por Arconte impede maximizar
  cedo. O item 8 do playtest ("upgrades no máximo antes do 2º chefe") está resolvido no integrado.

### §5: checklist do João, o que o código já garante × o que só o playtest diz
1 Peso leve/pesado: o código está ok (R2, R4); o `hit` leve ainda tem sub (R12).
2 Golpe "entra": ok (R1); o aparo justo só vem com o polimento7 87290ca.
3 Responsividade: buffers no hitstop ok.
4 Cansaço visual: risco nos tremores de inimigo comum (R3) e no fundo cheio (R18).
5 Parry: forma, som e 180 ms ok; falta a guarda do Astaphaios (chefes6).
6 Telegrafo coberto: o glint fica acima de tudo, ok.
7 Faíscas: ok (R6).
8 Finalização: racionada, ok (R8).
9 Ouvido: risco de repetição dos `atk_*` quando o audio7 entrar (§4.7).
10 Momento grande: o silêncio pré-chefe está ok; a morte de chefe empilha tremores (R3).
Bônus de acessibilidade: tremor 0 e "Reduzir flashes" existem, e o telegrafo continua (o glint não é cortado).
**Tudo isso precisa do playtest para ser confirmado.**

### Prioridade das correções (impacto ÷ esforço)
1. R15: fagulhas na direção do golpe (vfx7 + polimento7). É barato e é o acerto mais visto do jogo.
2. R3: tremor de inimigo comum ≤ 0,15 ou só no acerto (inimigos6), e um ápice só na morte de chefe (chefes6).
3. R18: fundo do plano de jogo com menos contraste + rim na Sophia (cenario7 + arte). É o maior risco de "não dá pra ler".
4. §3: não pagar de novo o que já foi coletado depois de morrer (level6 + mapa6), e corrigir o `sleepers_freed` contado 2×.
5. R21: 2–4 s entre ondas (level6).
6. R7 combo e R9 ducks (Áudio + UI).
7. R16 e R17 (UI, Áudio).

## Índice de vereditos (o mais novo em cima)

| Branch | Commit auditado | Veredito | R |
|---|---|---|---|
| dir7/ui7 | 12c6643 FINAL | APROVADO | R16 atende, R18, R21, R4 (shop_buy) |
| dir7/perigos7 | 04afd65 FINAL (delta de a1c0e4c) | APROVADO | R5, R18 (≥ 3,5:1), R4 |
| dir2/arte-gpt | e3966e6 + de546f8 (delta de 2c219b4) | APROVADO COM RESSALVAS | R18 (melhora, ainda < 3:1; halo leve no cajado), R3 fechado |
| dir7/mapa7 | 8e8afc3 FINAL (delta de 26d28b3) | APROVADO | §3/§4 (nenhuma isca impossível) |
| dir7/vfx7 | a63c40b (delta de 2a5919b) | APROVADO COM RESSALVAS (ressalvas anteriores fechadas; tiro hostil "legado" ficou mudo) | R4, R10, R17 |
| dir5/encenacao5 | 0561f28 (delta de ab957ac: sons das cenas + QA7 #12) | APROVADO COM RESSALVAS | R4 (aparição do Campeão em dobro), R9 ok |
| dir6/chefes6 | b0b52f0 (delta de ed66a82: trocas de som) | APROVADO COM RESSALVAS | R4 (pancada/pouso com onda = 3 sons até a troca do proj_fire hostil), R11 ok |
| dir7/mapa7 | 26d28b3 | APROVADO | §3 (nada de cadeado que não abre), R10 |
| dir7/perigos7 | a1c0e4c (topo, sem FINAL) | APROVADO COM RESSALVAS (falta o doc com CHECAGEM) | R5, R10, R18 |
| dir6/chefes6 | ed66a82 FINAL | APROVADO COM RESSALVAS (ressalvas anteriores fechadas; resta o 0,7 da arte) | R5, R17, R3 |
| dir7/audio7 | 6df9411 FINAL | APROVADO COM RESSALVAS (REPROVADO anterior fechado; troca do proj_fire hostil tem de entrar junto) | R4 |
| dir7/vfx7 | 2a5919b | APROVADO COM RESSALVAS (R15 fechada; poça armando pisca 4,8 Hz) | R15, R5, R10 |
| dir5/encenacao5 | ab957ac (delta de 0f04eff) | APROVADO (ressalvas anteriores fechadas) | R6, §3, R21 |
| dir2/arte-gpt | e114a52 (+f30ed17/2c219b4 docs; delta de 4038d12) | APROVADO | R18 |
| dir7/polimento7 | 87290ca (delta de 661a1a0) | APROVADO COM RESSALVAS (ressalvas anteriores fechadas; nova: dono único dos 3 sons) | R5 (aparo justo), R10, R4 |
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

---

## dir7/polimento7 — 87290ca (reauditoria do delta 661a1a0..87290ca; f7bdd80 é merge da integração)

**O que muda:** `hitbox.gd` (`_off`: golpe encerrado deixa de ferir NA HORA, mesmo dentro do sinal de acerto; `monitoring`
desliga adiado em `_sync_monitoring`; `rearm()` para multi-hit); `enemy.gd` (`FLASH_ADD` 0,55 → 0,40 × `luma_k()` do atlas;
morte desliga caixas adiado); `enemy_flash_layer.gd` (`LUMA_K` por atlas, tabela gerada offline por
`tools/combate/flash_luma.py`, faixa 0,55–1,25); `player.gd` (sons próprios do Áudio7: `double_jump`, `star_charge`,
`riposte`, com o genérico de reserva quando o som não existe no CATALOG); `staff_reach.gd`; `validate.ps1` (+FeelProbe/HitboxProbe);
CHECAGEM DE SATISFAÇÃO no POLIMENTO7.md.

**Medido no 87290ca (worktree de sonda, headless 60 fps):** importação sem `SCRIPT ERROR`;
HitboxProbe `QA PASS (atravessa 0 %, apelão 9 %; corpo desenhado: sem dano 0.0 %, apelão 0.6 %)` — 140 esperados, 154 reais,
contra o corpo (frame_geometry) 153 encostos e **0 sem dano**, 1 dano sem encostar (0,6 %); contato 120 → 120.
Log `C:\gnosis-wt\_caps\guardiao\p7b_HitboxProbe.log`. FeelProbe `QA PASS` (aéreo 1/pulo, pulo duplo travado, 2º pulo mais baixo). FlashParryProbe: aparo, janela do contra-ataque
e contra-ataque `PASS`; o item "≤ 3 flashes cheios/s" FALHA com `--fixed-fps 60` (pico1 0,12 = pico2 0,12) mas PASSA em tempo real
(pico1 0,25 → pico2 0,12) — e a integração atual falha igual com `--fixed-fps`. É artefato da sonda: o `Juice.flash_strength`
mede o intervalo em `Time.get_ticks_msec()` (relógio de parede) e o headless com passo fixo corre mais rápido que o relógio.
No jogo a 60 fps reais o limite vale. Pedido (combate/polimento7, não bloqueia): rodar a FlashParryProbe SEM `--fixed-fps` no
`validate.ps1`, ou o `flash_strength` contar em passos como o hitstop.

**Checagem:**
- **R5 / §5.5 (aparo justo) — CORRIGE o bug mais grave do QA7:** antes, `deactivate()` dentro do sinal de acerto era
  bloqueado pelo Godot e o golpe APARADO continuava ferindo — o jogador fazia a coisa certa e era punido (o oposto de
  competência, SDT). Agora `_on_area_entered` sai cedo com `_off` (`hitbox.gd`, início de `_on_area_entered`). Atende.
- **R10:** inimigo 0,40 × fator do atlas; atlas claros (Astaphaios 0,57, Soter 0,56, Rei 0,73) deixam de estourar o corpo
  grande; escuros sobem até 1,25 para o acerto continuar visível (R1). Fecha a minha ressalva do 661a1a0. Atende.
  Obs.: a tabela é estática — atlas repintado (ex.: arte-gpt e114a52 nos Campeões) pede rodar `flash_luma.py` de novo.
- **R4 — atende no código do player, com RESSALVA de integração:** o `player.gd` agora toca o som próprio NO LUGAR do
  genérico. Mas o `dir7/audio7` (634bc91) ainda toca os mesmos 3 pelo observador `_Watch` (`audio_manager.gd` ~1811/1820/1829
  do audio7). O anti-spam de 40 ms do mesmo nome provavelmente engole a 2ª chamada no mesmo quadro, mas isso é sorte, não
  desenho, e o `riposte` do observador sai pela borda de `_riposte_t` (pode cair fora dos 40 ms). Correção mínima (dono:
  **audio7**): tirar `double_jump`, `star_charge` e `riposte` do `_Watch` — quem toca agora é o player. Com isso o meu
  item 1 do audio7 também fecha.
- **R1/R2/R3/R16/R20:** intocados (conferido no diff).
- CHECAGEM no doc: presente e confere com o código (exceto a frase "o observador do Áudio7 deixa de tocá-los", que ainda
  não é verdade no audio7 634bc91).

**Veredito: APROVADO COM RESSALVAS** — entra; a ressalva é do audio7 (tirar os 3 do observador).

---

## dir2/arte-gpt — e114a52 (+ f30ed17, 2c219b4 só bilhete; delta de 4038d12)

`despill_full` nas folhas de 2 Campeões (`champ_carcereiro_frames.png`, `champ_esporos_frames.png`: franja rosada pintada
→ ferrugem/vinho), ajustes no pipeline (`build_frames.py`, `boss_frames.py`, `mk_champ_recipes.py`, 2 receitas) e doc.
- **R18:** tira a franja rosada (cor de "chave" vazando) e mantém o brilho dos esporos (lê como esporos acesos). Melhora.
- **R17:** Campeão de vidro morre estilhaçando EM PÉ de propósito, com monte de cacos no chão — morte distinta. Ok.
- Nenhum código de jogo, som, tremor ou economia.
- Lembrete: o `LUMA_K` do polimento7 tem esses 2 atlas (0,99 e 0,93); a mudança de luminância do despill é pequena,
  mas rodar o `flash_luma.py` de novo depois da integração.

**Veredito: APROVADO.**

---

## dir5/encenacao5 — ab957ac (delta de 0f04eff; 2c20de2 é merge da integração)

**O que muda:** `npc_encounter.gd` (as 30 faíscas do degrau agora voam em 9 orbes `SparkOrb.burst` do degrau até ela; presente
de arma do Soter por `Progression.gift_weapon_level()`, com 120 faíscas EM ORBES quando a arma está selada/no máximo);
`gnosis.gd` (o mesmo card de chefe não repete na mesma tela em < 8 s); `staging.gd` (descida ao Centro ~5 s sem controle,
antes 8–10 s; Tween nunca vazio); `cinematic.gd` (quebra equilibrada, sem viúvas); lore do acólito/espectro; i18n.

**Checagem:**
- **R6 — fecha a ressalva:** crédito na hora + orbes com o tique em escala na chegada (mesmo caminho das mortes). Atende.
- **§3 — fecha a ressalva antiga:** o presente respeita o selo por Arconte (`gift_weapon_level()` devolve false se selada ou
  no máximo, `progression_manager.gd:292-297`); a troca é fixa (120). Determinístico, sem sorteio. Atende.
- **R21 — melhora:** perda de controle na descida cai de 8–10 s para ~5 s, com o peso na ilustração/câmera e não no preto.
- **Card sem repetir:** usa `Time.get_ticks_msec()` (relógio de sessão, não data real) só para não duplicar o anúncio —
  sem efeito de recompensa. Ok (§4: menos ruído).
- Nada de tremor, flash ou slow-mo novo.

**Veredito: APROVADO.**

---

## dir6/chefes6 — ed66a82 FINAL (reauditoria do delta 7a934d9..ed66a82: 7316741, 723f190, 3f620df, ed66a82; os outros são merges)

**O que muda:**
- QA7: a Sophia é desenhada na frente do chefe; o Rei fica longe da borda (margem de 110–120 px); a investida não sai do quadro;
  `BossHazard.MIN_WARN 0,45` s em toda área que fere; as formas da final voltam mais fracas a cada vez (`0,45 − 0,1·n`, mín. 0,2)
  e mais devagar (`REVIVE_AFTER + 3·n`).
- Ressalvas do Guardião:
  - a guarda do Espelho mostra o anel desde o INÍCIO do wind (`_on_windup`: `_show_ring(wind + strike)`);
  - a carga do tiro tem som próprio (`charge_dark`/`charge_king`; muda até o Áudio7 entrar, sem repetir o `proj_fire`).
- Morte desenhada ligada: o `BossBrain._death_sequence` chama `visual.play_boss_death()` e segue os marcos 0,34/0,62/1,08 s
  da arte (`_until_death_t`), espera o `death_finished`, e o `Enemy._on_died` não faz o segundo final quando `visual.is_dying()`.
- Recalibração: Rei 27 golpes, Fome 26, Rei-tutorial sem larvas até a fase 3, Armupiel com 1 Pretoriano só na fase 2.
- CHECAGEM DE SATISFAÇÃO no CHEFES6.md.

**Medido por mim (BossProbe no ed66a82, headless, vel=3, bot médio skill 0,65, vida 120; importação 0 erros;
log `C:\gnosis-wt\_caps\guardiao\c6_bossprobe.log`):**

| Tela | Chefe | Tempo | Golpes | Quase-mortes | Fases |
|---|---|---|---|---|---|
| 1 | Rei | 95 s | 23 | 1 | 2@41 s, 3@66 s |
| 46 | Astaphaios | 130 s | 30 | 2 | 2@62 s, 3@99 s |
| 68 | Rei-Mentira + Colosso | 149 s | 64 | **5** | 2@49 s, 3@63 s |

Os tempos ficam dentro de 1,5–2,5 min e da variação de ±25 % que o próprio doc declara. Na final eu medi 5 quase-mortes (o doc diz 3);
é a última luta e o bot tem vida fixa de 120, então não reprova. Fica para o playtest.

**Checagem:**
- **R5, fecha a ressalva:** a guarda que reflete avisa com anel de vidro + som desde o início dos 0,4 s de preparo. Nenhuma área
  fere com menos de 0,45 s de contorno (QA7 #20). "Amarelo" agora só aparece em golpe que dá para aparar.
- **R4/R11, fecha a ressalva:** a carga e o disparo deixam de ser o mesmo arquivo.
- **R17, fecha o achado do arte-gpt 4038d12:** a morte em 4 etapas desenhada agora APARECE no jogo, e há um só final
  (sem gibs depois do estilhaço).
- **R3: quase fechado.** Do lado do cérebro sobra um tremor grande no golpe final (0,8) e micro-tremores de 0,15.
  **Resta** o `Juice.shake(0.7)` da ARTE em 0,34 s (`character_art.gd` `_tick_death`, "cai de joelhos"): são dois grandes em
  ~0,34 s. Com o decaimento de 1,4/s ele lê quase como um tremor longo, mas o ápice deveria ser um só. O próprio CHEFES6 já
  aponta isso como pedido à arte. Correção mínima (dono: **arte-gpt**): 0,7 → 0,15 (micro), ou nada.
- **R8:** slow-mo 0,3× por 0,8 s, só na morte do chefe. Atende.
- **R9:** fase −8 dB por 0,8 s; morte −14 dB por 3 s. Atende.
- **R21:** a final converge (as formas voltam mais fracas e mais devagar). É regra visível, não um quase-acerto fabricado (§3). Atende.
  As lutas ficam em 1,5–2,5 min (antes chegavam a 420 s com TIMEOUT).
- **R18:** a Sophia na frente do manto do Rei e o Rei longe da borda (QA7 #3). Atende.
- **§3:** sorteio de golpes semeado por tela, entre golpes legíveis, sem repetir 3×. Pretorianos e reflexos com 0 faíscas. Atende.
- A CHECAGEM do doc confere com o código.

**Veredito: APROVADO COM RESSALVAS.** Entra na 3.1. A única ressalva é do arte-gpt (o tremor de 0,7 na queda), que não bloqueia.

---

## dir7/audio7 — 6df9411 FINAL (reauditoria do delta 634bc91..6df9411: 801f46e + 6df9411)

**O que muda:**
- `audio_manager.gd`: o `_Watch` deixa de tocar `double_jump`, `star_charge` e `riposte`. Fica só `star_impact`, como camada sob a `nova`.
- `atk_*` passa a ter anti-spam de 130 ms e no máximo 2 vozes (`ENEMY_ATK_SPAM_MS`, `ENEMY_ATK_MAX_SAME`, `max_same_for()`).
- Síntese refeita com pico verdadeiro ≤ −1 dBTP (`onda7.py`, `build_sfx.py`) e verificação offline nova (`tools/audio/onda7_check.py`).
- `AUDIO7.md` com a tabela "quem liga cada som" e a CHECAGEM DE SATISFAÇÃO.

**Contraprova (ffmpeg ebur128, offline, nada tocado):** hz_spears −1,0 · boss_death_impact −1,0 · boss_phase3 −1,3 ·
bs_land −1,1 · bs_wings −1,0 dBTP. Antes iam até −0,2. Atende o teto de −1 dBTP.

**Checagem:**
- **R4: fecha o REPROVADO do 634bc91.** Os 3 eventos dobrados saíram do observador. O polimento7 87290ca toca o som
  próprio na fonte (troca, não soma). O `star_impact` é camada desenhada sob a `nova` (sem baque próprio), e isso a R4 permite.
- **§4.7 / R11: atende.** `atk_*` com 130 ms e 2 vozes evita a "metralha" num grupo de 5–6 inimigos.
- **R13: parcial, e honesto.** Os arquivos estão no alvo, mas a mixagem de 10 min não foi gravada (driver Dummy). Mesma pendência da TAREFA 1.
- **RESSALVA (R4, de integração):** o tiro hostil ainda soa DUAS vezes no mesmo instante assim que o audio7 entrar. O observador
  toca `atk_shot`/`atk_fan`/`atk_homing` no STRIKE, e o `projectile.gd:55` continua com `Audio.play_sfx("proj_fire")` para
  todo projétil, tanto no integrado quanto no polimento7. O pedido existe (`docs/pedidos/audio7.md:46`), mas ninguém fez a troca.
  Correção mínima: 1 linha no `projectile.gd` (`if team == "player": Audio.play_sfx("proj_fire")`), do dono do
  projétil (polimento7/inimigos), integrada JUNTO com o audio7.

**Veredito: APROVADO COM RESSALVAS.** Entra. A troca do `proj_fire` hostil precisa entrar na mesma integração; sem ela, os tiros
inimigos ficam com som dobrado.

---

## dir7/vfx7 — 2a5919b (reauditoria do delta 44e587d..2a5919b: 9d9d353, 5bd7ecd, 2a5919b; 92d8d34 é merge)

**O que muda:**
- **R15:** `ImpactBurst.spawn(..., dir)`, `VfxLibrary.hit(..., dir)` e `claw_impact(..., dir)`. Sem `dir`, a direção é deduzida pela
  posição da Sophia (`_guess_dir`). O resultado é um cone de ±50° no sentido do golpe, 20 % das fagulhas soltas em 360° e o talho
  do pesado alinhado em ±15°. Das 7 fagulhas vetoriais, 6 saem no cone.
- QA7: as poças hostis ARMAM por 0,5 s antes de ferir (#8); a aparição do fantasma/reflexo tem 0,6 s de wind, marca
  (anel + fumaça) e o som do telegrafo (#9); a repulsa vale até 90 px (#15); a coleira `EnemyAggro.leash_x` está pronta
  (#10, falta a chamada no `enemy.gd`).
- A carga fica muda sem o nome no CATALOG (antes caía num `proj_fire` grave, som dobrado).
- Desempenho medido pelo dono: 8,3 → 4,2 ms.

**Checagem:**
- **R15, fecha a ressalva:** o acerto mais comum agora sai no sentido do golpe (`vfx_library.gd` `hit`: `direction = dir + (0,−0,25)`,
  `spread 50`; talho em `dir.angle() ± 0,26`). Atende.
- **R5:** a aparição pelas costas passa de 0,25 s para 0,6 s, com marca e som. A poça não fere no quadro em que nasce. Atende,
  e isso é justiça pura (§5.6).
- **R4/R11:** a carga não dobra o som do disparo. Atende.
- **R10 / R5, RESSALVA pequena:** enquanto a poça arma, a borda pulsa a `sin(_t * 30)` = **4,8 Hz** por 0,5 s
  (`hazard_zone.gd`, `if arming: pulse = 0.5 + sin(_t * 30.0) * 0.5`). A área é pequena e dura pouco, então não fere a
  WCAG. Mas a R5/R10 pede pulso de aviso ≤ 3 Hz (o telegrafo usa 2 Hz) e o §4.4 diz "nunca acima de 3 Hz". Correção mínima:
  `sin(_t * 18.0)` (≈ 2,9 Hz), ou crescer sem piscar.
- **R21 / justiça:** a coleira impede que atirador e voador fujam para a borda. Bom, mas só vale quando o `enemy.gd` chamar
  (pedido ao polimento7).

**Veredito: APROVADO COM RESSALVAS** (só o pulso de 4,8 Hz da poça armando).

---

## dir7/mapa7 — 26d28b3 (6ccf9c3, 5d02ed9, 1d8973f, 26d28b3)

**O que muda:**
- O segredo de ANTES do Soter (e0.6a, e1.3a) vira o tipo `hidden`, a **câmara oculta**: não pede pulo duplo, alcança-se com pulos
  simples por torres, tem um perigo opcional no chão e paga o MESMO prêmio da sala secreta (`EonMap.REWARDS.hidden = secret`).
- As salas `secret` (pulo duplo) só existem depois da tela 17 (1º Soter) e abrem no mesmo run.
- No `world_map.gd`, o selo (asas + cadeado) diz "precisa de asas" / "aberta". Enquanto está fechado, a recompensa aparece como
  "escondida" e o texto diz por quê e quando. Há um aviso único, "as salas secretas se abrem", com halo de 4 s.
- MapQA 28 e LayoutQA verdes; i18n `--strict`.

**Checagem (código lido):**
- **§3 / §4.12:** prêmio fixo por tipo (`hidden` = `{"orbs": 20, "per_eon": 6, "hp": 8, "mp": 8}`), mostrado antes da escolha.
  Sem sorteio. Atende.
- **§3, aversão à perda, resolvida de verdade:** o "ponto honesto" do próprio MAPA7.md (e0.6a e e1.3a nunca abriam em nenhum
  run, ou seja, um cadeado que não abre) foi corrigido em 26d28b3. Antes do Soter não existe mais sala trancada; depois dele, ela
  abre no mesmo run. Nada de FOMO nem de "volte amanhã". Atende.
- **Autonomia (SDT):** o mapa mostra o mundo inteiro, e o fechado explica o motivo. O aviso "abriu" sai 1× por run e é ligado
  à história (o Soter), não à sorte (princípio 4). Atende.
- **R10:** o halo pulsa a ~0,6 Hz por 4 s, numa área pequena, sem clarão. Atende.
- **§4.11:** forma (asas, chave, cadeado) + texto além da cor lilás/azul. Atende.
- **R18 / R5 na câmara oculta:** torres de pulo simples e perigo opcional; nada obrigatório. Ok (o perigo segue as regras de
  aviso do perigos7).
- O MAPA7.md tem a CHECAGEM. O parágrafo "Ponto honesto" ficou desatualizado depois do 26d28b3; vale atualizar (não bloqueia).

**Veredito: APROVADO.**

---

## dir7/perigos7 — a1c0e4c (topo atual; 01b2705, 709a517, dc8eaa7 + merge do audio7 6df9411 em 9873c70). Ainda sem "FINAL".

**O que muda:**
- `scripts/fx/hazard_art.gd` (novo): desenho pintado de 15 perigos a partir das folhas `hz_1..hz_7`.
- `level_hazard.gd` `warn_outline()`: borda ESCURA por fora e VERMELHA por dentro, pulsando a `WARN_HZ 2,0`.
- Os 15 perigos usam a arte e ligam os sons `hz_*` do audio7 na fonte (aviso e golpe). A porta do selo toca ao abrir.
- Prancha antes/depois em `C:\gnosis-wt\_caps\perigos7\prancha_*.png` (vi a das lanças: no aviso, a grade fica com contorno
  vermelho e borda escura e lê bem no fundo violeta).

**Checagem:**
- **R5 (aviso antes de ferir):** as janelas de aviso dos perigos cíclicos são guilhotina 0,7 s (`WARN_AT 1,9 → DROP_AT 2,6`), boca 0,8 s,
  lanças 0,6 s, esporos 0,8 s, feixe do espelho 0,5 s, plataforma-espelho 0,6 s e cacos 0,8 s. Todas ≥ 0,45 s (o mesmo mínimo
  dos chefes). Cada uma tem FORMA (contorno da peça), cor e som de aviso (`hz_*_warn`). Atende.
- **R10:** o pulso do aviso é de 2 Hz (`HazardArt.pulse`); o aviso é informação e não cai com "Reduzir flashes", como pede a R10 para
  o glint. A "tremedeira" da boca e das correntes é a PEÇA vibrando 1 px (`sin(_t*50)`), não a câmera nem um flash. Atende.
- **R18 / §4.11:** borda escura + borda vermelha lê em fundo claro (Coroa, Pleroma) e escuro (Silêncio, Torpor), conforme o
  QA7 #25. Não medi 3:1 por perigo. A prancha das lanças lê bem.
- **R3:** nenhum `Juice.shake` novo nos perigos. Atende.
- **R4:** o som do perigo é ligado NA FONTE e o observador do audio7 cuida só dos perigos que eram mudos. Ver na integração se
  algum perigo ficou tocando pelos dois caminhos: o `docs/pedidos/audio7.md` lista as trocas `dark_tide` e `guillotine`.
- **Regra da equipe:** não há `docs/onda2/PERIGOS7.md` com CHECAGEM DE SATISFAÇÃO no branch. Correção: escrever antes do FINAL.

**Veredito: APROVADO COM RESSALVAS** (falta só o doc/CHECAGEM). Quando sair o FINAL, reaudito só o delta.

---

## dir6/chefes6 — b0b52f0 (delta ed66a82..b0b52f0: 9fae4af = merge do audio7 6df9411, já aprovado; commit próprio b0b52f0)

**O que muda (b0b52f0):**
- `enemy.gd` `_enter_phase`: `boss_phase3` NO LUGAR de `boss_phase2` na fase 3 (troca, não soma).
- `boss_hazard.gd`: `hz_saw` 1× por serra (`_saw_sfx`); `hz_column` no golpe da coluna, exceto quando quem criou já soa
  (`strike_sound = false` no pouso do salto, que já toca `bs_land` pelo observador).
- `boss_brain.gd` `ground_wave()`: `atk_wave` com guarda de 120 ms (duas ondas do mesmo golpe = 1 som).

**Checagem (R4 e R11):**
- **Fase 3, coluna e serra: atende R4.** São trocas na fonte e nada mais toca nesses eventos. O observador não trata `BossHazard`, e o
  Decreto do Armupiel tem `strike: ""` na `BOSS_MOVE_SFX`, então a coluna dele soa uma vez só.
- **Pouso do salto: atende.** `bs_land` (observador) e a coluna-sombra muda.
- **R11: atende.** `atk_wave` herda o anti-spam de 130 ms e as 2 vozes do prefixo `atk_` do audio7. A guarda de 120 ms do cérebro
  é redundante, mas inofensiva. `atk_wave` tem 2 variações (ideal 3, não bloqueia).
- **R4, RESSALVA (pancada `slam` com `waves` e pouso de salto com ondas):** no MESMO quadro tocam o som do golpe
  (`bs_royal_cut`/`atk_slam` no strike, ou `bs_land` no pouso, pelo observador), o `atk_wave` (novo) e o `proj_fire` de cada
  onda, porque a onda rasteira é um `Projectile` (`projectile.gd:55` toca `proj_fire` em todo projétil). Hoje são **3 sons**.
  Com a troca já pendente do `proj_fire` hostil (só o tiro da Sophia toca), caem para 2: golpe + onda, que é aceitável como
  camada (a onda é um objeto visível que parte do impacto). Correção mínima:
  (1) a troca do `projectile.gd` (dono polimento7/inimigos), que já é condição do audio7;
  (2) opcional, `atk_wave` a −3 dB (`sfx(..., -3)`) para soar como camada sob o golpe, não como segundo impacto.
- AoeNova com dano 0 continua mudo (`aoe_nova.gd:29`). Ok.

**Veredito: APROVADO COM RESSALVAS** (a ressalva depende da mesma linha do `projectile.gd` que já trava o audio7).

---

## dir5/encenacao5 — 0561f28 (delta ab957ac..0561f28: commit próprio 0561f28; 7d7fb98 e 80617fb são merges do audio7 6df9411 e da integração)

**O que muda:**
- `staging.gd` (roubo): a fenda abre em `Audio.CRACK_DELAY`, junto com o `crack_open` do cue `sink`; cada pulso do tremor
  leva `boss_step` a −6 dB.
- `npc_encounter.gd` (Soter): `Audio.duck_music(600, −24)` na fala da leveza, e o `soter_gift` entra no silêncio.
- `level.gd` (QA7 #12): o Campeão nasce no chão, 150 px à frente da Sophia, dentro da zona e do quadro
  (`_champion_x`). O card sai só quando ele está visível (≥ 0,6 s, teto de 2 s; `_champion_card_when_visible`).
  ChampionProbe 0 falhas.
- NARRATIVA6.md atualizado.

**Checagem (código lido; nada tocado):**
- **R9: atende.** Antes do grande momento vem o vazio: a música para e a fenda abre COM o `crack_open` (princípio 1 de sincronia:
  imagem e som no mesmo evento). No Soter, −24 dB sob o dom. A soltura vem do `Staging._on_finished` (`duck_music(0, 0)` quando
  `_ducked`), e a cena do Soter liga `_ducked` (`staging.gd:377`). Como o envelope é um só, a soltura sobrescreve o −24.
  Conferido por leitura, não no jogo.
- **R4 no roubo: atende.** O `boss_step` a −6 dB acompanha o tremor como camada. É 1× por run, então não cansa (§4.7).
- **R5 / R18 no Campeão: atende.** Nascer dentro do quadro e à frente acaba com o "golpe de fora da tela"; o card só sai com ele visível.
  O ataque dele segue o telegrafo de sempre (glint + wind-up).
- **R4, RESSALVA (aparição do Campeão em dobro):** o `Enemy._ready` já chama `_boss_intro_fx` (deferred) para todo
  `is_boss_enemy or is_champion` (`enemy.gd:322-334`: `boss_appear` + `VfxLibrary.boss_appear` na posição dele). O novo
  `_champion_card_when_visible` chama de novo `VfxLibrary.boss_appear(self, champ.global_position + (0,−20))`. São DUAS colunas
  de luz no mesmo ponto e no mesmo quadro. Correção mínima: tirar a chamada do `level.gd`, porque o Enemy já faz a aparição.
- **Lembrete fora deste delta (dono polimento7/inimigos, pedido do audio7):** o `_boss_intro_fx` toca o stinger `boss_appear` também
  para o Campeão. O audio7 pediu `champion_enter` para ele, porque o stinger de chefe é o que solta a música de chefe (R9).

**Veredito: APROVADO COM RESSALVAS.** Entra no pacote de som; a ressalva é 1 linha no `level.gd`.

---

## dir7/vfx7 — a63c40b (delta 2a5919b..a63c40b: commit próprio a63c40b; o resto é o merge do audio7 6df9411, já aprovado)

**O que muda:**
- `projectile.gd`: `proj_fire` só quando `target_team == "enemy"` (tiro da Sophia).
- `hazard_zone.gd`: a poça armando pulsa com `sin(_t * 18)`, ≈ 2,9 Hz.
- `vfx_library.gd`: `kill_confirm()` (estrela branca em X, anel fino e risco vertical de luz, ~120 ms, dentro do `flash_budget`),
  chamado no `enemy_death` de inimigo comum.

**Checagem:**
- **R4: fecha a ressalva do audio7 e do chefes6 b0b52f0.** O tiro hostil soa só pelo `atk_*` do observador e a onda rasteira
  (Projectile) só pelo `atk_wave`. Pancada e pouso com ondas caem de 3 sons para 2 (golpe + onda), o que é aceitável como camada.
- **R10: fecha a ressalva.** Poça a 2,9 Hz (≤ 3).
- **R17: parcial → quase atende.** O golpe que mata o inimigo comum ganha uma forma própria (estrela em X ≠ fagulha redonda do
  acerto), curta e no orçamento de flashes. Ainda falta a parte do SOM (impacto 2 semitons abaixo / +2 dB, dono Áudio + combate).
- **R4/R5, RESSALVA NOVA (tiro hostil que ficou MUDO):** o observador do audio7 só toca o golpe quando o inimigo tem `_mv`
  (repertório do EnemyMoves; `audio_manager.gd:1780`). Atiram com `_mv` vazio, e agora sem nenhum som no disparo:
  - o caminho antigo `attack_style "ranged"` (`enemy.gd:733` `_begin_strike`, projéteis em `:762`). Pega os ECOS dos Arcontes
    de estilo "ranged" (eco do Athoth, do Yabel e do Rei, `bestiary.gd:370/379/395`), que entram nas ondas finais
    (`run_manager.gd:351-352`). Os tipos comuns têm todos repertório próprio;
  - o voleio que quica do Astaphaios (`boss_astaphaios.gd:153`, `_bounce_volley`), que sai 0,9 s depois do golpe;
  - os restos de kit em `enemy.gd:826/856` (`_kit_strike`/`_ground_wave`), se algum chefe ainda passar por eles.
  O aviso (glint + `tell_*`) continua; o que falta é o som do DISPARO, que localiza a ameaça fora da tela (R14).
  Correção mínima (dono inimigos/polimento7 no `enemy.gd`; chefes6 no Astaphaios): nesses pontos, tocar
  `Audio.play_sfx_at("atk_shot", pos)` 1× por salva (ou `move_sfx({"kind": "shot"}, "strike", pos)`).

**Veredito: APROVADO COM RESSALVAS.** O pacote de som pode fechar; a ressalva é som que FALTA (não som dobrado) em inimigos de
fim de jogo.

---

## dir7/mapa7 — 8e8afc3 FINAL (delta 26d28b3..8e8afc3: 0e9ff0c, 932ae93, 8e8afc3)

**O que muda:** `screen_layouts.gd` `_high_cache(screen)`: antes da tela 17 (1º Soter) o baú alto é uma TORRE de pulo simples
(`tower_cache`); a saliência de pulo duplo (`dj_cache`, com setas no chão) só aparece a partir da 17. `map_qa.gd` confere
isso. MAPA7.md com a decisão final e a CHECAGEM atualizada (o "ponto honesto" foi resolvido).

**Checagem:**
- **§3/§4 (nada de isca impossível, nenhum "quase" fabricado):** antes do pulo duplo o jogador não vê mais um prêmio que não
  alcança, e todo baú visível é alcançável com o que ele tem. Atende. É o mesmo princípio da câmara oculta do 26d28b3.
- Prêmio e posição são determinísticos (sem sorteio). Atende.
- **Observação (não bloqueia):** a regra usa o NÚMERO da tela (`SOTER_SCREEN := 17`), não o fato de ter o pulo duplo. Se um dia
  o Soter mudar de tela, ou o mapa permitir chegar na 17+ sem o encontro, volta a existir saliência inalcançável. Mais robusto:
  `RunManager.has_double_jump()` na hora de montar a tela (o layout é por tela; se precisar ser estático, ao menos uma
  checagem no MapQA de que todo caminho até a 17 passa pelo Soter).

**Veredito: APROVADO.**

---

## dir2/arte-gpt — e3966e6 + de546f8 (delta depois de 2c219b4; 380a5c1 é merge da integração)

**O que muda:**
- `painted_flex.gdshader`: `rim_amt` acende a borda POR DENTRO, só onde a pintura é escura (botas, calça, cabelo na sombra), e
  `halo_amt` põe um halo de ~1 px POR FORA, mais forte junto das partes escuras. A cor é a do Éon misturada a 35 % com branco quente.
- `character_art.gd`: só na Sophia (`HERO_RIM 0,6`, `HERO_HALO 0,4`, `rim_px 1,6`); tremor da queda na morte desenhada
  0,7 → 0,15.
- `belias.json`: `foot_gap 0` (pés no chão).
- Sondas `ContrastProbe` / `FeetProbe` / `contrast_r18.py` e pedido ao cenario7.

**Prova vista:** `C:\gnosis-wt\_caps\arte-gpt\r18\r18_antes_depois.png` (Torpor 3, Corrente 30, Praga 57) e o meu recorte ampliado
2× das pernas/botas: `C:\gnosis-wt\_caps\guardiao\r18_arte_zoom.png`.

**O rim "lava" a pintura? NÃO.** O miolo da pintura fica igual: o manto branco e o turquesa não mudam, porque a luz de recorte só entra nas
bordas ESCURAS (fator `dark`). O que se nota é o HALO de fora:
- ele cria um filete claro e translúcido em volta das botas e, principalmente, ao longo do CAJADO, uma faixa pálida vertical de
  ~3–4 px dos dois lados da haste. Em Torpor e Corrente, ampliado, ela lê como um "fantasma" e não como luz da cena;
- no tamanho do jogo é sutil, mas o cajado é fino e está sempre em movimento, então o halo dele vai chamar atenção
  em golpe e smear.
- **Ponto:** o rim está bom. O halo está no limite: baixar `HERO_HALO` 0,4 → ~0,25, ou não aplicar halo em partes finas
  (ex.: pular texels cuja vizinhança tem `mx` alto só num eixo), resolve sem perder a separação nas botas.

**Checagem:**
- **R18: melhora, mas continua PARCIAL.** O dono mediu 1,4–2,0 → 1,7–2,4 : 1, ainda abaixo de 3:1. O resto tem de vir do FUNDO
  (pedido ao cenario7: plano de jogo com 15–25 % menos contraste e saturação), como já está no despacho da TAREFA 1. Correto não
  forçar mais luz na Sophia: rim forte vira "recorte de adesivo" e briga com a pintura.
- **R3: fecha a ressalva do chefes6.** A morte de chefe agora tem UM tremor grande (0,8 no golpe final) + micro de 0,15.
- **R10:** o rim/halo é estático (não pisca). Atende.
- **Pés do Belias:** sem fresta entre pé e chão. Favorece o R18 (contato com o chão = leitura de peso). Ok.

**Veredito: APROVADO COM RESSALVAS** (halo 0,4 → ~0,25 ou sem halo no cajado; o R18 fecha só com o cenário).

---

## dir7/ui7 — 12c6643 FINAL (f913fc8, fdb785e, 8b5cf25, 0daadb7, 12c6643; o resto é o merge do audio7)

**O que muda (UI de jogo):**
- `damage_number.gd` (R16): soma acertos no MESMO alvo em ≤ 0,3 s (mesma cor, ≤ 36 px), no máximo 6 vivos (some o mais velho),
  pop 1,35 → 1,0 em 80 ms com ease-out-back no relógio real (o hitstop não estica), e pop de 1,22 a cada soma.
- `hud.gd`: HUD na CanvasLayer 20, acima do mundo, da vinheta do cenário (1) e do clarão (5); Pausa/Loja em 45. Ganha uma
  sombra de leitura macia atrás do medalhão e das barras (α 0,32, ou 0,5 com chefe) e uma faixa escura atrás do nome/título do
  chefe (QA7 #17/#23). "Siga em frente" sai do CENTRO e vira seta com chevrons na borda direita por 3,2 s (QA7 #30).
- `dialogue_box.gd`: a caixa fecha sozinha se a cena trocar (QA7 #14).
- `upgrade_menu.gd`: relíquia sem `shop_buy` por cima do `relic_equip`.
- Traduções (QA7 #6/#16 e outros).

**Checagem:**
- **R16: ATENDE agora** (era PARCIAL na TAREFA 1): agrupar, teto, pop e opção liga/desliga (já existia).
- **R18:** a sombra de leitura e a faixa do card separam o HUD do mundo sem caixa dura. Atende.
- **R21:** tirar o "Siga em frente" do centro desafoga o meio da tela (legenda, dica e convite já estavam lá). Atende. Os chevrons
  correm a ~1,6 ciclos/s, numa área pequena, ≤ 3 Hz (R10).
- **R22:** a vinheta de vida baixa continua no próprio HUD (agora acima do clarão). Sem mudança no ritmo. Atende.
- **R4:** relíquia = 1 som (`relic_equip`). Atende.
- **Justiça/UX:** caixa de diálogo órfã tapando botões (QA7 #14) resolvida.
- Nada de economia mudou (só o som da compra), nada de tremor nem flash novo.

**Veredito: APROVADO.**

---

## dir7/perigos7 — 04afd65 FINAL (delta a1c0e4c..04afd65: a0cf7e1, 04afd65)

**O que muda:** `level_hazard.gd`: um terceiro fio CLARO e quente (`WARN_HOT`) no meio da borda de aviso (escuro, vermelho, claro),
para ler em fundo de luminância média, onde nem o escuro nem o vermelho passam de 3:1. `tools/hazards7/contrast.py` mede.
`PERIGOS7.md` com a CHECAGEM DE SATISFAÇÃO. uid do HazardArt.

**Checagem:**
- **R18: atende.** O dono mediu ≥ 3,51:1 em todos os fundos (é o primeiro elemento do jogo com 3:1 medido). Não refiz a medida.
- **R5:** forma + cor + som, aviso ≥ 0,45 s (tempos inalterados), a frente visível da maré coincide com o dano. Atende.
- **R4/R11 (som dobrado):** conferido no código. A fonte toca `hz_guillotine` (queda) e `hz_tide_wake` (maré acorda); o observador
  do audio7 só toca `hz_winch` (lâmina subindo) e `hz_tide_tick` (`audio_manager.gd:1919/1924`). São eventos diferentes, nada dobra. Atende.
- **Atenção leve (§4.9, não bloqueia):** o `hz_tide_tick` repete a cada ≥ 300 ms enquanto a Sophia está sendo corroída (1 voz). É
  informação (dano contínuo), mas um tique contínuo é o tipo de som que irrita. Se o playtest reclamar, espaçar para ~600 ms ou
  baixar 3 dB.
- **R10:** pulso de 2 Hz; o feixe deixou de piscar a ~6 Hz; decorativo × 0,5 com "Reduzir flashes", e o aviso não reduz. Atende.
- A CHECAGEM do doc confere com o código.

**Veredito: APROVADO.**

---

## BILHETE PARA O SUCESSOR (19/10)
- **Estado:** a TAREFA 1 está publicada (seção do topo). A TAREFA 2 está fechada: todos os branches da Onda 7 têm veredito (índice no topo).
  Pendentes que vou cobrar:
  - `ui7` (ainda WIP; não auditado);
  - FINAL do `perigos7` (reauditar só o delta depois de a1c0e4c);
  - troca do `proj_fire` hostil no `projectile.gd`, junto com o audio7;
  - `shake(0,7)` da arte em `character_art._tick_death`;
  - pulso de 4,8 Hz da poça armando (vfx7).
- **Ferramentas:**
  - worktree de SONDA `C:\gnosis-wt\guardiao_sonda` (destacado, `override.cfg` próprio "GNOSIS-WT-guardiao"; `.godot`
    já importado). Para auditar um branch: `git -C C:\gnosis-wt\guardiao_sonda checkout -q --detach <commit>`, importar
    headless e rodar as sondas (`tools/combate/HitboxProbe|FeelProbe|FlashParryProbe`, `tools/chefes6/BossProbe -- telas=.. vel=3`).
  - A FlashParryProbe tem de rodar SEM `--fixed-fps` (o Juice mede flashes pelo relógio de parede).
- **Áudio:** só offline (`ffmpeg -af "apad=pad_dur=0.6,ebur128=peak=true"`); as medições de base estão em `_caps\guardiao\audio\`.
- **R18:** capturas 320×180 em `--position 4000,4000` (`tools/Shot.tscn -- <tela> <png> 150`) e a grade em cinza em `_caps\guardiao\`.
- **Armadilhas:**
  - diff de branch que fez merge da integração: use o delta dos commits PRÓPRIOS (`git show <c>`), não o `...` (vem sujo);
  - o chefes6 já matou processos com "BossProbe" na linha de comando; se uma sonda cair, rode de novo.
