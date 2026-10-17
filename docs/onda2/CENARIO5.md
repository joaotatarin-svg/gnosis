# CENÁRIO 5 — primeiro plano que não tapa ninguém (Onda 5, 17/10/2026)

Branch `dir5/cenario5` (base `integracao/onda1` 37ea6f5). Arquivos: `scripts/levels/scenery.gd`
(classe `Foreground`), `tools/scenery/fg_audit.gd` + `FgAudit.tscn` (novos),
`tools/scenery/clean_shot.gd` (opção `legacyfg`), `docs/pedidos/cenario5.md`.

## O problema (QA2 #3 + pedido 6 da Encenação 3)
A coluna escura de primeiro plano (`fgcol`, a asa esquerda da pintura) era ancorada EM CIMA de cada
descanso (`rest_points[i] ± 60`) — exatamente onde o Level põe NPC, Estela, baú e Selos — e tinha
~157 px de largura (≈25% do quadro). Como o primeiro plano anda só 0,35× mais rápido que o mundo,
uma coluna perto de um NPC fica sobre ele por ~600 px de câmera: o Soter da 17 ficava atrás dela o
encontro inteiro; na 4 o baú sumia; na 3/38/59 os Selos; na 61 o Velkar e o baú.

## A regra nova (em `Scenery.Foreground`)
1. **Coluna fina:** fatia de `COL_W = 52 px` da asa (a fatia mais perto da borda de dentro que seja
   ≥ 72% opaca — `_crop_x`), 460 px de altura. Cobre ~5–7% do quadro.
2. **Posição escolhida depois dos extras** (`_place_columns`, `call_deferred` no fim do quadro do
   `_ready` do Level): em volta de cada descanso entre zonas, varre âncoras de 4 em 4 px e aceita só as
   que (a) ficam FORA do quadro enquanto qualquer zona está trancada (câmera em c ± 150) e (b) ficam a
   pelo menos `_min_gap(hw)` de todo ponto protegido. Conta: distância na tela entre coluna e ponto =
   `1,35·D + 0,35·s` (s = posição do ponto na tela); para nunca cobrir com o ponto visível,
   `|D| ≥ (COL_W/2 + hw + 0,35·(320 + hw)) / 1,35` (≈ 180 px para um NPC). Sem lugar seguro, o
   descanso fica SEM coluna (é o caso das telas com NPC + Estela + Selos juntos, como a 17).
3. **Rede de segurança** (`_fade_columns`, a cada quadro): coluna que mesmo assim passar sobre um ponto
   protegido some (alfa → 0); sobre a Sophia fica translúcida (0,45).
4. Entulho de baixo (`fg_rubble`) mantido como estava (mede ~1–3% do quadro, fica abaixo dos pés).

Pontos protegidos (lidos, sem editar o Level): filhos diretos do Level das classes `NpcEncounter`,
`Stela`, `Chest`, `Sleeper`, `SealPuzzle` (meia-largura 185: três pilares), `ExitPortal`; a Estela que o
Gnosis vai pôr depois das falas (`Gnosis.stela_for_screen` + `_stela_pos`); a fenda em `_end_x − 200`.

## CONTRATO para o level design (level6 e depois) — "faixas proibidas para primeiro plano"
O layout novo (plataformas altas, perigos, segredos) informa o cenário SEM mexer em `scenery.gd`:
- **Nó protegido:** qualquer `Node2D` no grupo **`fg_guard`** (em qualquer lugar da árvore).
  Meia-largura em `set_meta("fg_half", px)`; padrão 80 px. Ex.: `segredo.add_to_group("fg_guard")`.
- **Faixa inteira:** variável no Level **`var fg_forbidden: Array = []`** com `Vector2(x0, x1)` em x de
  mundo (ex.: um trecho vertical de plataformas onde a leitura do pulo importa).
- **Quando:** até o fim do quadro em que o `_ready` do Level termina a parte síncrona (antes do primeiro
  `await`). O que nascer depois não move colunas — só as faz sumir quando passam por cima (varredura a
  cada 0,5 s).
- Zonas de luta continuam derivadas de `Level.ZONE_FIRST_X/ZONE_STEP/ZONE_HALF` e `rest_points`; se o
  level6 mudar a fórmula das zonas, avisar (a regra "fora do quadro com zona trancada" usa essas
  constantes).
- **Conferir:** `godot --headless --audio-driver Dummy --path . res://tools/scenery/FgAudit.tscn -- telas=1-68`
  deve sair com `hits=0 fight=0` e `cover_max ≤ 0.10`.

## Auditoria (`tools/scenery/FgAudit.tscn`, headless, 68 telas)
Abre cada tela, espera o Level ficar pronto (pula diálogos) e varre a câmera de parede a parede
(passo 8 px) medindo pela mesma geometria do jogo (`Foreground.audit_at`, grade de 4 px, alfa ≥ 0,5):
`cover` (quadro coberto por silhueta), `hits` (posições de câmera com coluna sobre um ponto protegido
visível), `fight` (coluna no quadro com zona trancada). `legacy` mede o ANTES.

RESULTADOS_AUDITORIA

## Capturas (fora do git, `C:\gnosis-wt\_caps\cenario5\`)
- `prancha_antes_depois.png` — telas 17 (Soter), 61 (Velkar + baú), 4 (baú), 30 (Estela), 3 (Selos),
  mesma câmera; antes = `legacyfg`. Antes: coluna preta de ~25% do quadro sobre o NPC/baú/Selos.
  Depois: nada na frente.
- `prancha_coluna_t2.png` — a coluna fina continua existindo onde há lugar seguro (tela 2).
- `boss10_f20.png` — arena de chefe no começo: o obelisco NÃO aparece no meio (já resolvido na
  Onda 2 pelo `ArenaSet`; conferido).
- `audit_antes.csv` / `audit_depois.csv` (+ `.txt`).

## O que NÃO ficou bom / não deu tempo
- **Menos colunas:** de 59 para as que couberam (ver tabela). Onde o descanso tem NPC/Estela/Selos
  juntos não sobra lugar seguro — a profundidade de primeiro plano fica só no entulho de baixo e no bokeh.
- **Tela 17 continua amontoada** (Estela + Selos + Soter no mesmo descanso): é posição do Level/Gnosis,
  não do cenário — pedido em `docs/pedidos/cenario5.md`.
- **Near com bordas retas (Silêncio/Centro):** tentei "roer" os cortes retos da faixa near
  (detector de borda vertical + perfil irregular). O detector pega também lados VERDADEIROS de torres e
  caixas pintadas e o resultado ficou pior (franjas, traço vertical fino). Descartado, nada aplicado.
- A fatia fina da coluna tem a borda de fora reta (corte da textura). Escura e desfocada, lê como pilar;
  sem playtest em movimento.
- A regra mede com a câmera no y de repouso; com a Sophia no alto de plataformas a câmera sobe e o
  entulho de baixo some — a cobertura só cai.
