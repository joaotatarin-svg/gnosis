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

## O que NÃO ficou bom / não testei
- Feel do flash novo e do alcance: só medido (atlas/sonda), sem captura em janela nem playtest humano.
- A sonda só cobre inimigo parado, no chão, mesma altura; voadores e chefes grandes não entram na bateria.
- O 2º leve continua sendo um golpe que termina entre os pés no desenho; o acompanhamento é regra de jogo
  (eixo prolongado até o chão), não arte nova. Um quadro com o cajado varrendo à frente resolveria de vez (pedido
  já feito à Arte pelo combate6).

## BILHETE PARA O SUCESSOR (19/10)
- Feito: tarefas 1–5, QA7 #1/#10/#15/#19, R3, R10 do inimigo, R15, sons do Áudio7, charge_up no cast,
  contra-ataque. Bot QA7 das telas de timeout e `validate.ps1 -Repeat 2`: ver §12.
- `tools/qa7/` é cópia LOCAL (não versionada aqui) do worktree qa7 só para medir; não commitar.
- Arquivos-chave: `scripts/combat/{hitbox,staff_reach}.gd`, `scripts/entities/enemy.gd` (`_fit_hurtbox*`,
  `FLASH_ADD`, `die`), `scripts/entities/enemies/enemy_flash_layer.gd` (`LUMA_K`), `scripts/entities/player.gd`
  (`FLASH_ADD`, `rearm`, sons), `tools/combate/{hitbox_probe.gd,flash_luma.py}`, `tools/validate.ps1`.
- Sonda: `godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/combate/HitboxProbe.tscn -- <json> [rapido]`.
- Armadilhas: `frame_geometry()` tem 1 quadro de atraso (por isso a previsão do atlas na troca de pose); a
  Hitbox não pode mudar `monitoring` dentro de sinal (use `deactivate()`, nunca `monitoring = false`).
