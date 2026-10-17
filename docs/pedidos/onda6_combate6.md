# Pedidos do Combate 6 (Onda 6, 17/10/2026) — Sophia: dano, aéreo, ritmo, movimento, pulo duplo

Tudo do lado do Combate 6 está no branch `dir6/combate6` e funciona sem estes pedidos
(chamadas protegidas). Régua de números: `scripts/combat/sophia_tuning.gd`. Relatório: `docs/onda2/COMBATE6.md`.

## Números novos da Sophia (para todo mundo calibrar em cima)
Dano = base da tabela × **0,65** × (1 + **0,17** × (nível da arma − 1)). Antes: base + 6 × (nível − 1).

| golpe | nv1 antes→depois | nv3 | nv5 |
|---|---|---|---|
| leve (L, LL) | 12 → 8 | 24 → 10 | 36 → 13 |
| 3º leve (LLL) | 20 → 13 | 32 → 17 | 44 → 22 |
| pesado (H) | 24 → 16 | 36 → 21 | 48 → 26 |
| HHH | — | 56 → 38 | 68 → 48 |
| Queda Estelar (pulo + forte) | — | 42+42 → 9 (contato) + 21 (onda) | 54+54 → 12 + 26 |

Ritmo (botão amassado, 2 s): leve **4,5 → 2,5 golpes/s**, forte **2,5 → 1,5/s**. DPS sustentado de uma string
leve que conecta tudo: ~21/s (nv1) a ~36/s (nv5). Queda Estelar: no máximo 1 a cada ~1,7 s (antes ~1 a cada 0,75 s,
e ainda encadeava em HH → HHH no chão sem recuperação).

## chefes6 (`scripts/entities/bosses/**`, `_kit_*`/`_boss_*`/`_enter_phase*`)
1. **Não dupliquem o corte.** Com a vida de hoje, os chefes já passam de "5–6 porradas" para **37–103 golpes leves**
   (Athoth 289 hp ≈ 37 leves no nv1; Armupiel 1332 hp ≈ 103 leves no nv5; com HHH ≈ 8 → 28). A conta por chefe
   (vida no meio do run × dano novo) está em `docs/onda2/COMBATE6.md` §3.
2. Recomendo **vida dos chefes ×1,0 a ×1,4** (não mais), e o resto da dificuldade em **fases/padrões**: um humano
   acerta ~35–45 % do tempo numa luta boa → Athoth ≈ 35–45 s, Armupiel ≈ 90–120 s com os números acima.
   Se passarem de ×1,5, me avisem: aí eu devolvo um pouco de dano no nível 5 (`WEAPON_STEP`).
3. A Queda Estelar agora tem **0,24 s de preparo pairando** (pose `windup_heavy`) e **0,40 s presa no chão** depois
   da onda: é uma janela de punição limpa para o chefe (golpe rápido depois do pouso).
4. O aparo/contra-ataque continua igual (×1,5 do pesado). A defesa agora também pode ser apertada na janela de
   encadear de um golpe (aparo no meio do combo) — padrões com "golpe atrasado" ficam justos.

## inimigos6 (`bestiary.gd`, `enemy.gd`)
1. Alvo do João: comuns com **4–8 golpes**. Com o dano novo (golpes leves, meio de cada Éon):
   larva/sombra/larva ardente **3**, servo 4, sonâmbulo 5, canino 6–7, escudeiro 8–9, carcereiro 8–9,
   bruto/pretoriano **12–13**. Sugestão: **larva 18→26, sombra 22→30, larva_ardente 16→24** (passam a 4);
   bruto/pretoriano podem ficar (tanques) **se** tiverem leitura de armadura/atordoamento; senão −20 % de vida.
2. Voadores: o que a Sophia tem contra o ar — pulo 81 px, **pulo duplo +55 px** (depois do Soter), Giro Celeste
   (2 por pulo, o 1º paira), lançadores (LH, LLH, HHL), Esfera Solar. A Queda Estelar NÃO serve contra voador
   (desce). Voador que fica acima de ~90 px do chão o tempo todo, antes do Soter, só cai com magia — evitem.

## progressao6 (`progression_manager.gd`, `game_content.gd`, `upgrade_menu.gd`)
1. **Contrato do pulo duplo:** `Progression.has_double_jump() -> bool` e `grant_double_jump()` (salvo no save/run).
   A Sophia já lê: `has_double_jump()` se o método existir; senão a propriedade `double_jump` (falso se não houver).
2. O nível da arma agora vale **+17 % multiplicativo** por nível (nv5 = ×1,68; antes nv5 = leve ×3). Curva sugerida
   para a economia nova: **nv2 na Fome, nv3 na Corrente/Silêncio, nv4 no Espelho/Praga, nv5 só na Coroa** (é a
   curva da tabela do relatório; a vida dos inimigos sobe ×1,0 → ×1,8 no run e a arma ×1,0 → ×1,68).
3. `ComboData.windup_time()` / `recovery_time()` não são mais usados pela Sophia (a régua é `SophiaTuning`).
   O dano-base da tabela de golpes (`game_content.gd`) continua sendo a base: mexer nele muda tudo × 0,65.

## narrativa6 (cena do Soter)
1. Na cena em que o Soter concede o pulo duplo: chamar `Progression.grant_double_jump()`. Nada mais é preciso do
   meu lado. Ensino sugerido (texto curto, logo depois): "No ar, pule outra vez." — e uma plataforma alta à vista.

## level6 (layouts)
1. Alturas (centro do corpo, tela 3, `--fixed-fps 60`): **pulo 81 px**; **2º pulo sobe mais 55 px** a partir de
   onde foi apertado (no ápice: ~136 px no total). Velocidade 185 px/s; o arco do pulo NÃO mudou nesta onda
   (gravidade e velocidade iguais) — plataformas antigas continuam alcançáveis.
2. Pulo duplo = caminhos/segredos **opcionais**; nada obrigatório acima de 81 px antes do Soter.

## arte (GPT + integrador) — "movimento travado": números da corrida
1. A corrida (`rund`, 16 quadros desenhados) troca de quadro **pela distância** (`advance`). A 185 px/s, o tempo de
   tela de cada quadro é **[19, 15, 38, 29, 33, 53, 27, 1, 34, 5, 16, 32, 54, 19, 29, 27] ms** (ciclo 430 ms, 80 px).
   Com a física a 60 Hz (16,7 ms), o **quadro 8 (1 ms) e o 10 (5 ms) nunca aparecem** e o 6 e o 13 seguram 3+
   passos (53–54 ms): a passada "engasga" duas vezes por ciclo mesmo com o corpo deslizando liso.
   Pedido: reespaçar o `advance` para ficar perto de uniforme (~27 ms = ~5 px de mundo por quadro a 185 px/s)
   ou tirar os quadros 8 e 10 e redistribuir. Média hoje: 37 trocas/s.
2. Poses que o combate passou a pedir (hoje usam reservas): **preparo da Queda Estelar no ar** (hoje `windup_heavy`
   do chão), **pouso pesado preso** (0,40 s; hoje segura `attack_dive`), **pirueta do pulo duplo** (hoje o corpo
   inteiro gira 360° em 0,34 s com a pose `jump` — funciona, mas 3–4 quadros de cambalhota ficariam melhores).

## estab5 / técnico (`game_manager.gd`)
1. **VSync desligado + `Engine.max_fps` = taxa do monitor (144)** dá ritmo de quadro irregular e rasgo de tela sem
   VSync — parte do "travado" pode ser isso, não o movimento. A física (60 Hz) está com interpolação ligada e a
   câmera segue por física (interpolada): esses dois estão certos. Sugestão: testar no PC do João VSync ligado
   (ou Mailbox) com a correção de desempenho de hoje, e expor a opção de forma clara.

## ui5 (tela de Golpes / dicas)
1. "Queda Estelar (pulo + forte): 1 por pulo, carrega no ar, presa ao pousar." e, depois do Soter,
   "Pulo duplo: pule de novo no ar." (texto novo → i18n).
