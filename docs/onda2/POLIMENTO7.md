# Onda 7 — POLIMENTO DE COMBATE (branch `dir7/polimento7`, base `origin/integracao/onda1`)

Tarefas: (1) hurtbox dos inimigos ≈ 80 % do corpo DESENHADO por quadro (`visual.frame_geometry().body`);
(2) caixa do cajado da Sophia via `frame_geometry().staff/tip` (API oficial da arte) no lugar do StaffReach próprio;
(3) 2º golpe leve que bate atrás do pé; (4) `Player.FLASH_ADD` para a cor real da pintura; (5) FeelProbe e
HitboxProbe no `validate.ps1`. Extras pedidos pelo chefe: QA7 #1 (hitbox viva depois do aparo), ressalva R10 do
Guardião (`Enemy.FLASH_ADD`), sons próprios do Áudio7 (R4), `charge_up` do VFX7 no cast das magias.

## 1. Hurtbox = corpo desenhado (tarefa 1, QA7 #21)
`enemy.gd` `_fit_hurtbox_geometry()`: lê `visual.frame_geometry(true).body` (silhueta do quadro, sem arma/pano,
medida offline pela Arte) e põe a Hurtbox em **80 % da largura**, centrada no corpo, dos pés até **92 % da altura**
(corta a ponta de chifre/cabelo), suavizada 50 %/quadro. Sem geometria no quadro → a conta antiga pelo JSON.
Larguras (hurtbox × corpo da API × malha pintada): larva 26 × 33 × 39, servo 23 × 28 × 56, canino 39 × 48 × 52,
bruto 45 × 56 × 64 (antes: 19, 28, 26, 32 — metade do desenho no canino/bruto).
Testei 88 % de largura: não melhora o "sem dano" e sobe o apelão contra o corpo (3,2 %) → fica 80 %.

## 2. Cajado pela API da Arte (tarefa 2) e o 2º leve (tarefa 3)
`StaffReach.current()` agora usa `frame_geometry().staff` ([cabo, ponta] do eixo VISÍVEL, já com tranco/escala/mola do
corpo). A API descreve o quadro do último `_draw`: no passo em que a pose troca (o impacto sai no mesmo passo em que
o golpe começa) ela ainda mostra o quadro anterior — aí vale a previsão pelo atlas (mesma pose que o Visual vai
desenhar), para o acerto não atrasar 1 quadro. Nos quadros estáveis a fonte é a API (`source=api` na sonda).
- **2º leve (`s4.light2_hit`)**: o desenho é um golpe DESCENDENTE cuja ponta termina entre os pés (−6 px). Saiu a
  varredura fixa `MIN_SWEEP` (10 px à frente do pé em TODO quadro de impacto) e entrou o **acompanhamento**
  (`_follow_through`): só em golpe descendente cuja ponta para atrás do pé da frente, o eixo do cajado continua
  até a linha do chão (máx. 16 px). O alcance passa a sair da geometria do desenho, não de um número fixo.
- Quadro com o cajado inteiro atrás do corpo num golpe de frente: sem caixa (antes gerava forma de tamanho
  negativo — 48 erros "RectangleShape2D size cannot be negative" numa BossProbe).

## 3. HitboxProbe antes × depois (mesma sonda, nível 3, 6 golpes × 4 tipos × 8 distâncias)
A sonda ganhou: `m_LL`, medida contra o corpo da API (`frame_geometry().body`), linha por caso "sem dano", modo
`rapido` (sem a bateria da caixa antiga), hurtbox seguindo o quadro também com a física do inimigo parada (antes a
hurtbox congelava 2 quadros depois do nascimento e media errado) e só conta toque na JANELA do golpe (hitbox
ativa; o cajado parado na pose de volta `ready`/`rec_*` não é golpe).
| | antes (4cfd64c) | depois |
|---|---|---|
| atravessa (cajado encosta na hurtbox, sem dano) | 0 de 126 | **0 de 140** |
| encosta no CORPO desenhado sem dano | **16 de 148 (10,8 %)** | **0 de 153 (0 %)** |
| dano sem o cajado encostar no corpo desenhado | 6 (4,3 % dos acertos) | **1 (0,6 %)** |
| "apelão" contra a hurtbox (folga de 4 px da caixa) | 12 (9 %) | 14 (9 %) — todos encostam no desenho |
| contato (colada num bruto 1,5 s) | 120 → 120 | 120 → 120 |
Logs: `C:\gnosis-wt\_caps\polimento7\antes\hitbox_probe_mesma_sonda.log` × `...\depois\hitbox_probe_8.log`.
(A 1ª medição da base, com a sonda antiga, deu atravessa 1–2 e sem dano 5–7 %: `antes\hitbox_probe*.log`.)

## 4. QA7 #1 — hitbox do inimigo ferindo depois do aparo (R5)
`hitbox.gd`: `deactivate()` era chamado DENTRO do sinal de acerto (aparo → `stagger()`, morte) e o Godot bloqueava
a troca de `monitoring` ("Function blocked during in/out signal", 86× no QA7) — a caixa seguia ligada. Agora:
`_off` corta o dano NA HORA (`_on_area_entered` confere `_off` e `_live`) e o `monitoring` desliga adiado
(`_sync_monitoring`, fora do sinal). O multi-hit da Sophia usa `rearm()` (desliga e liga no mesmo passo, fora de
sinal). `die()` também desliga adiado. BossProbe `telas=1,10,19 vel=3`: **0** "Function blocked" (QA7: 24).

## 5. Flash (tarefa 4 e ressalva R10)
- `Player.FLASH_ADD` 0,6 → **0,42**: com a cor ao quadrado a pintura tinha luminância média 0,39 e o pico do flash
  0,84 (30 % do corpo estourado em branco); na cor real (0,53) 0,42 dá o mesmo pico (0,84) e 35 % em branco; 0,6
  estouraria 47 %.
- `Enemy.FLASH_ADD` 0,55 → **0,40** × fator por atlas (`EnemyFlashLayer.LUMA_K`, tabela gerada offline por
  `tools/combate/flash_luma.py`). Achado: as criaturas/chefes por quadros já usavam `painted_boss` (cor real) — o
  0,55 não era "cor antiga"; o risco R10 real eram os atlas CLAROS. Pico/branco antes → depois:
  Astaphaios 0,95/68 % → 0,82/27 %, Rei 0,91/40 % → 0,77/16 %, Reflexo 0,94/60 % → 0,79/26 %, bruto 0,78/4 % →
  0,70/2 %, conjurador 0,74/1 % → 0,69/1 %. Média dos atlas: 0,83/19 % → 0,72/10 %.

## 6. Sons próprios (Áudio7, R4) — merge de `dir7/audio7` 6df9411
2º pulo → `double_jump`, Queda Estelar → `star_charge`, contra-ataque → `riposte` (no lugar de jump/dive/swing),
direto na fonte (o observador do Áudio7 não toca estes). Entrada de chefe: `champion_enter` para Campeão,
`boss_appear` só para chefe (o stinger libera a música de chefe — R9).

## 7. validate.ps1 (tarefa 5)
Entraram `FeelProbe` e `HitboxProbe` (rápido) com `--fixed-fps 60` e `FlashParryProbe` SEM `--fixed-fps` (o
Juice conta os flashes no relógio de parede — pedido do Guardião). A FlashParryProbe foi ajustada: o aparo e o
contra-ataque esperam passos de FÍSICA (sem física fixa o headless roda vários quadros de processo por passo e o
aperto sumia — falso negativo), e a morte de chefe com cérebro (death_sequence do chefes6) só confere que ele
não se parte na hora (o resto é das ferramentas do chefes6).

## 8. Patches do VFX7 no enemy.gd (merge de `dir7/vfx7` 2a5919b) e QA7
- **#10 (R21)**: atirador e voador presos pela coleira (`EnemyAggro.leash_x` no `_desired_x`, `retreat_dir` no
  recuo) — não fogem para fora da arena.
- **#15**: atirador colado esquece a intenção de longe e reage na hora.
- **#19 (R5)**: a fúria acelera o preparo em 15 %, mas o aviso nunca cai abaixo de ~0,42 s.
- Arte própria (`has_own_art()`): sem tinta do tipo nem graduação do interino.
- **R15**: `ImpactBurst.spawn(..., dir)` recebe a direção do golpe (quem bate → quem apanha; o lançador sobe, a
  Queda desce) e o acerto de magia no inimigo passa a direção da origem para `VfxLibrary.hit`.

## 9. Tremor de câmera (R3, prioridade 2 do Guardião)
Golpe de ROTINA de inimigo comum (pancada, explosão, pouso, salto, agarrão, fúria do Campeão) tremia 0,25–0,45.
Agora `Enemy._shake_routine()` limita a **0,12** em inimigo comum; chefes seguem com o valor deles; a quebra de
guarda (0,25/0,3), a Sophia ferida (0,35) e o pesado dela (0,30) ficam fortes. A câmera já fica com o MAIOR pedido
do quadro (sem soma). FeelProbe: `tremor leve=0.00 pesado=0.30 inimigo_comum=0.12 sophia_ferida=0.35`.

## 10. Contra-ataque que chegava curto (achado da FlashParryProbe)
Com a caixa do cajado desenhado (alcance ~26 px) o avanço do contra-ataque mirava onde o aparado ESTAVA, mas o
stagger o empurra a ~200 px/s: 3 de 3 contra-ataques erraram (servo a 79–95 px). `_riposte_lunge` agora mira onde
ele vai estar (`RIPOSTE_LEAD` 0,2 s do recuo) e desconta a frenagem: 4 de 4 acertam (59 → 35).

## 11. Carga visual no cast (pedido do VFX7)
`VfxLibrary.charge_up(self, …, 0,12 s, "light")` no instante do cast, SEM atrasar o disparo: o preparo de 0,2 s
foi descartado (magia é a saída de emergência e a resposta é o ponto forte que o João elogiou). O disparo sai no
mesmo quadro de antes.

## 12. Hurtbox dos CHEFES = contorno desenhado (3.2 — João, 19/10: "a Sophia atravessa o manto do Rei")
- Achado (BossHurtProbe, nova): na prévia 3 a caixa do chefe era ½ do recorte do quadro (ciano nas pranchas): no
  Rei a barra do manto ficava de fora — 30 px (soma dos dois lados, por linha) de pano DESENHADO na altura do
  cajado da Sophia sem dano. No boneco articulado (reserva sem atlas) era pior: caixa fixa 54×96 num manto de
  200 px de largura (26 % do desenho acertável, 45 px de cada lado) — é exatamente o print do João.
- Agora (`enemy.gd` `_fit_hurtbox*`/`_fit_hurt_poly`): nos chefes a Hurtbox é um POLÍGONO CONVEXO =
  `frame_geometry().body_poly` (contorno do corpo, sem cajado/fios) + os 2 cantos de baixo de `body` (a barra do
  manto no chão), encolhido 10 % na largura e com o topo cortado em 92 % (igual aos comuns). Sem suavização: segue o
  quadro como ele é desenhado (no hitstop o quadro não troca → a caixa para, R1). Boneco: `BossPuppet.body_polygon()`
  (casco convexo da malha pintada, só células visíveis, levado pelo balanço do quadril). Inimigos comuns: intocados.
- BossHurtProbe (10 chefes × 5 poses; "faixa" = pés até 1 Sophia de altura, onde o cajado bate):
| | prévia 3 (½ recorte) | 2d54867 (retângulo 80 %) | agora (contorno) |
|---|---|---|---|
| silhueta dentro da hurtbox | 73 % | 80 % | 79 % |
| hurtbox fora do desenho ("apelão") | 22 % | 21 % | **15 %** |
| pano sem dano na faixa (px/linha, 2 lados) | 25,1 | 15,0 | **12,5** (Rei: 30 → 9) |
| boneco: silhueta dentro / pano sem dano | 62 % / 31,9 | — | **93 % / 3,8** (Rei 26 % → 97 %) |
  O que sobra fora são fiapos/rasgos da barra e os tentáculos de névoa do Athoth (não são corpo). A caixa do cajado
  da Sophia tem ~4 px de folga, então ~6 px por lado de fiapo ainda pega na ponta.
- Provas: `C:\gnosis-wt\_caps\polimento7\hurt_chefes\antes\*.png` × `...\depois\*.png` (vermelho = hurtbox,
  ciano = caixa da prévia 3, pontilhado = altura da Sophia; `*_boneco.png` = reserva sem atlas) e os `.log`.
- Sonda: `godot --audio-driver Dummy --path . --resolution 320x180 --position 4000,4000
  res://tools/combate/BossHurtProbe.tscn -- png=<dir> [puppet] [ids=rei,colosso]` (precisa de renderer).

- **BodyBox do Chefes6** (Rei e Rei-Mentira, 6 faixas por quadro, `scripts/entities/bosses/boss_body_box.gd`):
  `_fit_hurtbox` sai na hora se o inimigo tem o nó `BodyBox` — não troca a forma nem mexe no `disabled` da
  HurtShape (senão o golpe conta 2× ou a caixa dele é desfeita). BossHurtProbe confere: `HURTPROBE_BODYBOX|PASS`.
  Sem a BodyBox (este branch), o Rei usa o contorno: pano sem dano na faixa 30,2 → 9,2 px/linha.
- BossProbe (chefes6, `telas=all vel=3`, depois): os 9 chefes terminam `[ok]`, sem erro de forma
  (`...\hurt_chefes\depois\bossprobe.log`).

## 13. Campeão mais curto (decisão do chefe ao pedido 2 da Progressão 7)
`enemy.gd` bloco `is_champion`: vida ×1,7 → **×1,35**, dano ×1,15 → **×1,0**. Repertório de elite, brado, onda
dupla, 2º fôlego e letreiro continuam: a dificuldade vem do que ele FAZ, não da barra.

## 14. Ressalvas do Guardião ao 2d54867
- R4: a carga visual do cast (`ChargeFX`) sai MUDA (`silent` antes do `add_child`; o som tocava no `_ready`) — o
  cast já toca `cast_*` e o tiro `proj_fire` no mesmo quadro.
- `projectile.gd:55` (`proj_fire` também no tiro hostil): arquivo do VFX7, editado por DELEGAÇÃO DO CHEFE (VFX7
  encerrado), mudança mínima — `proj_fire` só se `target_team == "enemy"` (tiro da Sophia); o hostil soa na salva.

## 15. Bot QA7 das telas de timeout (run inteiro, seed 1, ia=3, vel 4, BelowNormal)
Antes = 2d54867 (`_caps\polimento7\bot\run_s1.*`), depois = 3.2 com contorno dos chefes + Campeão ×1,35
(`...\bot\run32_s1.*`). Total 92,3 → 93,6 min, 209 → 208 quase-mortes.
- Timeouts: **13 → 9 telas**. Saíram as Provações do Campeão (33 mudo, 42 reflexo) e 35/36/49; Provações 6/15/24/
  33/42 ficaram 15–25 s mais curtas e com 25–48 % menos dano tomado.
- Arcontes (10, 28, 37, 46, 64, 68) seguem passando dos 100 s do bot (bug 2 do QA7, balance dos chefes —
  Chefes6), mas a vida que SOBRA no corte caiu na soma 3677 → 2534 (Athoth 1020 → 274, Galila 375 → 195, Yabel
  690 → 342, Astaphaios 574 → 215; Armupiel 229 → 669 e Rei-final 789 → 839 pioraram — ruído de sorteio/IA).
- Timeouts de inimigo comum que restam: 38 (invocador@x 2288), 39 (reflexo@2306), 43 (arauto@2190), todos na zona 1
  e LONGE (x > 2190): o bot passa pela fenda e eles ficam vivos para trás. Não é dano/vida — é posição. Pedido ao
  QA7/Mapa em `docs/pedidos/polimento7.md`.

## 16. Re-teste da 3.1 (QA7 d67a51b): N1 e #10
- **N1 — Campeão com 2 stingers** (`boss_appear` do card + `champion_enter`): `level.gd` e `cinematic.gd` editados
  por DELEGAÇÃO DO CHEFE, só neste ponto. `Cinematic.boss_card(nome, título, sting=true)`; o card do Campeão
  (`Level._champion_card`, inclusive a reserva "O CAMPEÃO", antes via `Gnosis.boss_card("campeao")`) passa
  `sting=false`; o ramo órfão `Gnosis.boss_card("campeao")` também passa `sting=false` (ressalva do Guardião). Decisão pela NEURO: Campeão não é chefe → R4 (um evento = um som: só `champion_enter`) e R9 (o
  stinger de chefe é que solta a música de chefe; o Campeão fica na música do Éon). Prova: bot na tela 15 com
  `GNOSIS_AUDIO_LOG` → `champion_enter=1`, `boss_appear` ausente (`_caps\polimento7\bot\audio_t15.json`).
- **#10 — "inimigo longe" nas telas de timeout: NÃO é coleira.** Medi a distância inimigo × Sophia no instante do
  timeout nos logs do próprio QA7 (`_caps\qa7\bot31\s1-3.log`) e no meu run: em todos os casos de inimigo comum
  ele está a ≤ 160 px da Sophia (o invocador a ≤ 275, que é o alcance dele, 260). x ≈ 2000–2800 é só onde fica a
  ZONA 1/2 da tela — a luta está acontecendo, só é longa. Causas: invocador repõe larvas sem teto TOTAL (teto de 3
  vivas, `_summon` a cada 6 s), reflexo que salta para trás a cada golpe, arauto que mantém 240 px. Não mexi: é
  balance de inimigo (proposta ao chefe: teto total de invocações por invocador, ex. 3 chamadas = 6 larvas).
- **Teto de invocações (decisão do chefe, 28/10)**: `enemy.gd` `_summon_larvae()` (função de invocação, não-kit):
  3 chamadas por invocador (até 6 larvas no total; o teto de 3 vivas continua). Na 3ª ele fica ESGOTADO.
  1ª versão (0ba25d8): escurecia 38 % e parava só o recuo da IA. Ressalvas do Guardião: no ramo `shooter` do
  `_desired_x` ele ainda se afastava a pé (175 px) e o escuro sumia no fundo escuro (tela 48).
  Agora: `_process_chase` sai na hora se esgotado → PARADO, virado para a Sophia, SEM golpe nenhum (não anda, não
  recua, não atira — esgotado = janela de punição clara). Leitura: o corpo DESSATURA para cinza CLARO (graduação do
  contorno, sat 0,08 × 2,0 de luz), solta um sopro na hora e uma fumaça cinza leve e contínua. Nenhum multiplicador
  de dano/vida. Reflexo e arauto intocados. Capturas (tela 48 fundo escuro, 38 fundo claro):
  `C:\gnosis-wt\_caps\polimento7\esgotado\{antes,depois,depois_sopro}_tela{48,38}[_zoom].png` (`v1_escuro_*` = 1ª versão).
  A fumaça contínua é discreta (lê melhor no zoom); quem carrega a leitura é o cinza claro.
  Bot com a versão nova (`botun34_s1`): telas com invocador 1928,6 → 1783,5 s (−7,5 %; v1 dava −9 %), dano
  tomado nelas 7740 → 6637; 38 e 39 seguem fora do timeout. A 35 passou a dar timeout por um CORNUDO colado na
  Sophia (hp 18, x 2831 × 2871) — sorteio, não o invocador. Run 93,6 → 89,6 min, quase-mortes 208 → 179.
  Bot (run inteiro, seed 1, mesmo código salvo o teto; `botun32_s1` × `botun33_s1`): nas 16 telas com
  invocador o tempo somado cai 1928,6 → 1754,1 s (−9 %); 38: 131 → 65 s, 48: 181 → 118 s, 57: 172 → 124 s
  (58/59 subiram 18–28 s: ruído de sorteio). Timeouts 9 → 7 (saem 38 e 39; a 43 fica — arauto). Run 93,6 → 88,8
  min, quase-mortes 208 → 189.

## 17. 3.2.1 (base integracao/onda1 0400a19): RuleProbe e #10 de novo
- **RuleProbe** (`tools/combate/rule_probe.gd`, autorizado): com a R16 o 2º número no MESMO alvo soma (não cria
  nó) e a sonda esperava 2. Agora confere as 3 coisas: desligado não cria (0), mesmo alvo soma (1) e o padrão
  (opção ausente) segue ligado — um número de OUTRA cor cria o 2º nó (2). `RULEPROBE|numeros|off=0 on=1 soma=1
  padrao=2`, todas as QA PASS.
- **#10 outra vez: os inimigos NÃO estão longe.** Nos logs do próprio QA7 (`_caps\qa7\bot32\s1-3.log`) medi
  inimigo − Sophia no timeout: escudeiro x=4175 com a Sophia em 4253 (−78 px, em GUARDA), arauto −43, mudo +49,
  aberração +42/+115, mudo/acólito +173/+202, arauto −230 (o arauto mantém ~200 px de propósito). O x≈2000–2400
  é o x ABSOLUTO da zona 1 (a zona 0 nasce em x 620, cada zona tem 940 px + a passagem) — não é distância.
  Bot na base 3.2.1 (`botun321_s1`): 4 timeouts no run inteiro (14, 35, 43, 49; nenhum de chefe); 14 e 49 com
  o inimigo a ≤ 75 px; 35 sem ninguém vivo no instante (intervalo entre ondas — o tempo da zona conta o total);
  43 com o invocador a 427 px porque o BOT estava correndo para o outro lado (estado RUN), larvas recém-chamadas
  ao lado dele. Não há posição para corrigir: o que sobra é duração de luta (guarda do escudeiro, que o bot não
  quebra; arauto, que é a identidade dele). Nada mudado no enemy.gd/level.gd por isso.

## CHECAGEM DE SATISFAÇÃO (docs/handoff/NEURO_SATISFACAO.md)
- **R1 (alvo pisca/treme no hitstop)**: flash continua instantâneo e ≤ 100 ms reais; só a intensidade mudou. A
  hurtbox segue o quadro desenhado, mas no hitstop (time_scale 0,05) o quadro não troca → caixas paradas no
  congelamento, como a regra pede.
- **R2 (hitstop por peso)**: intocado (o impacto continua saindo UMA vez por golpe no `_flush_impact`).
- **R3 (tremor)**: golpe de rotina de inimigo comum 0,25–0,45 → ≤ 0,12; forte só no que importa (Sophia ferida,
  pesado dela, quebra de guarda, chefes); maior pedido do quadro vence.
- **R9/R21**: stinger de chefe não toca para Campeão; atirador não foge da arena (a Arena fecha).
- **R15 (fagulhas no sentido do golpe)**: direção passada ao ImpactBurst e ao `VfxLibrary.hit`.
- **R4 (um evento = um som)**: os três sons próprios saem no evento e o observador do Áudio7 deixa de tocá-los
  (sem som em dobro).
- **R5 (telegrafo/aparo justo)**: corrigido o bug que fazia o golpe APARADO ainda ferir (QA7 #1). O aparo agora
  encerra o golpe no mesmo instante, e o contra-ataque alcança quem foi aparado. A fúria não corta o aviso abaixo
  de ~0,4 s (QA7 #19).
- **R10 (fotossensibilidade)**: flash da Sophia com o mesmo pico de antes na cor nova; inimigos mais fracos
  (média 0,83 → 0,72) e os chefes claros e grandes deixam de estourar 40–68 % do corpo em branco. O limite de
  3 cheios/s continua no `Juice.flash_strength`.
- **R16 (números de dano)**: intocado.
- **R18 (legibilidade)**: o flash não vira silhueta branca (≤ 35 % do corpo estourado na Sophia, ≤ ~30 % nos
  atlas mais claros); nos atlas escuros o fator sobe (até 1,25) para o acerto continuar visível.
- **R20 (squash)**: intocado.
- **Justiça (playtest 2: "o cajado atravessa")**: 0 casos de atravessar, 0 % encosta no desenho sem dano, 0,6 % de
  dano sem encostar no desenho — o alcance é o do desenho, sem ficar apelão.

- **Economia (renda igual em todas as dificuldades, Progressão 7 item 4 / Guardião §3)**: `_reward_mult` não
  multiplica mais pela dificuldade (antes Difícil 1,5× e Muito Difícil 2,2× com os mesmos preços). §3 (recompensa
  com limite ético): a dificuldade fica no combate, sem "pagar mais para sofrer mais" nem Normal "pobre"; nenhum
  sorteio novo, nenhuma escassez artificial (§4 conferido).
- **Justiça nos chefes (3.2)**: hurtbox = contorno desenhado; o manto que se vê é acertável (Rei 30 → 9 px/linha
  de pano sem dano) e a caixa acerta MENOS o ar (21 % → 15 %) — fiel, não apelão. R1 mantida (sem suavização,
  quadro parado no hitstop). R18: o jogador lê o golpe pelo desenho e o desenho responde.
- **Campeão ×1,35 (3.2)**: R5/R21 — luta mais curta, a ameaça vem do repertório legível (telegrafo, brado) e não
  de barra inflada; recompensa do Campeão intocada (sem perda artificial).
- **R4 (3.2)**: carga do cast muda — um evento (cast) = um som.
- **Invocador esgotado (3.2)**: justiça/R18 — a zona tem FIM previsível (máx. 6 larvas) e o estado é lido no corpo
  (cinza CLARO + fumaça + parado sem golpe: janela de punição); recompensa por persistir sem número escondido (nenhum bônus de dano
  invisível). R21: menos fuga = menos perseguição para fora do enquadramento. §4: sem aleatoriedade nova.
- **R4/R9 (Campeão, 3.2)**: aparição do Campeão = 1 som (`champion_enter`), sem stinger nem música de chefe —
  o Campeão é mini-chefe do Éon, a 'entrada de chefe' fica reservada aos Arcontes e ao Rei (contraste preservado).

## O que NÃO ficou bom / não testei
- Feel do flash novo e do alcance: só medido (atlas/sonda), sem captura em janela nem playtest humano.
- A sonda só cobre inimigo parado, no chão, mesma altura; voadores e chefes grandes não entram na bateria.
- O 2º leve continua sendo um golpe que termina entre os pés no desenho; o acompanhamento é regra de jogo
  (eixo prolongado até o chão), não arte nova. Um quadro com o cajado varrendo à frente resolveria de vez (pedido
  já feito à Arte pelo combate6).

## BILHETE PARA O SUCESSOR (19/10)
- Feito: tarefas 1–5, QA7 #1/#10/#15/#19, R3, R10 do inimigo, R15, sons do Áudio7, charge_up no cast,
  contra-ataque (até 2d54867). 3.2: hurtbox dos chefes/boneco (§12), Campeão ×1,35 (§13), ressalvas do Guardião (§14), bot QA7 de timeouts (§15).
- 3.2 (28/10): validate VERDE 14/14 depois do último código. Sonda dos chefes: `tools/combate/BossHurtProbe.tscn`
  (renderer). Chefe com `BodyBox` (Chefes6) é pulado no `_fit_hurtbox` — manter assim.
- `tools/qa7/` é cópia LOCAL (não versionada aqui) do worktree qa7 só para medir; não commitar.
- Arquivos-chave: `scripts/combat/{hitbox,staff_reach}.gd`, `scripts/entities/enemy.gd` (`_fit_hurtbox*`,
  `FLASH_ADD`, `die`), `scripts/entities/enemies/enemy_flash_layer.gd` (`LUMA_K`), `scripts/entities/player.gd`
  (`FLASH_ADD`, `rearm`, sons), `tools/combate/{hitbox_probe.gd,flash_luma.py}`, `tools/validate.ps1`.
- Sonda: `godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/combate/HitboxProbe.tscn -- <json> [rapido]`.
- Armadilhas: `frame_geometry()` tem 1 quadro de atraso (por isso a previsão do atlas na troca de pose); a
  Hitbox não pode mudar `monitoring` dentro de sinal (use `deactivate()`, nunca `monitoring = false`).
