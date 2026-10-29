# CENÁRIO 7 — fundos HD dos 9 Éons (FILA 12) + R18 (Sophia salta do fundo) + QA7 #22

Branch `dir7/cenario7`. Base atualizada com `integracao/onda1` ba91602 (merge fc1a811, sem conflito).
Arquivos meus: `scripts/levels/scenery.gd` (camadas HD, véu da faixa, `LaneHalo`, plataformas),
`scripts/fx/scenery_library.gd` (dados HD), `assets/backgrounds/hd/*`, `artes/gpt/bg/*` (fontes),
`assets/shaders/scenery_floor.gdshader`, `tools/cenario7/*`, este doc, `docs/pedidos/cenario7.md`.

## 1. O que está feito
- **FILA 12 integrada (9/9 Éons):** far + mid + asas + chão HD (1536 px, variante `_a`), chave magenta
  trimap, linha do chão MEDIDA por camada, mid alinhado pela base dos objetos, parallax 0,04 / 0,18 / 0,40,
  variante/fase/tom por tela (determinístico). Feito pelo antecessor (c4963ee, dbae0df, 05b69b7).
- **R18 — fundo calmo na faixa de luta:** (a) véu escuro liso na cor do ar do Éon por cima do far+mid,
  só na altura da luta (antecessor); (b) NOVO `LaneHalo`: sombra de profundidade macia que segue a Sophia
  POR TRÁS (z −1: na frente do fundo e do chão, atrás dos lutadores). Elipse 58×84 px lógicos, miolo
  chato até 36 % do raio e borda longa (não vira recorte), cor = ar do Éon muito escuro, alfa por Éon
  `LANE_HALO_A = [0.72, 0.66, 0.72, 0.70, 0.72, 0.68, 0.70, 0.66, 0.70]`. Some quando a Sophia some.
- **QA7 #22 (coluna de luz fantasma sob as plataformas):** sem coluna/silhueta esticada (c4963ee) e o halo
  da borda virou elipse aditiva (2fa2c49) — o retângulo claro do Espelho sumiu.
  Prova: `C:\gnosis-wt\_caps\cenario7\final\qa22_plataformas_depois.png`.

## 2. Medida R18 (ferramenta OFICIAL da Arte, `tools/anim/contrast_r18.py`)
Borda de 2 px por dentro da Sophia × anel de 3–8 px por fora, com a luz de contorno da Arte LIGADA,
janela 640×360, quadro 150. ANTES = fundos antigos (o que está na integração; `ProbeBg ... oldbg`).
| tela (Éon) | antes (integração) | só HD (05b69b7) | DEPOIS (HD + véu + LaneHalo) |
|---|---|---|---|
| 3 Torpor | 2,01 | 2,36 | **2,89** |
| 13 Fome | 2,40 | 2,65 | **2,97** |
| 22 Corrente | 2,00 | 2,01 | **2,89** |
| 30 Silêncio | 2,23 | 2,07 | **2,82** |
| 31 Silêncio | 2,22 | 2,21 | **2,86** |
| 40 Espelho | 1,58 | 1,63 | **2,81** |
| 49 Praga | 1,77 | 2,06 | **2,85** |
| 57 Coroa | 1,77 | 1,68 | **2,78** |
| 58 Coroa | 1,95 | 1,94 | **2,75** |
| 66 Centro | 2,07 | 2,44 | **2,93** |
| 68 Mente | — | — | não medido (tela final abre com diálogo; o probe não pula) |
(O Guardião citou 2,06 / 2,37 / 1,71 nas telas 3 / 30 / 57 — rotuladas pela Arte como Torpor/Corrente/Praga,
mas pelo `RunManager.eon_index` são Torpor / Silêncio / Coroa.)

**Leitura honesta: 1,6–2,4 → 2,75–2,97 : 1. NÃO chega a 3:1.** O fundo atrás dela já está em ≈ 0,013–0,029
de luminância (quase preto); daqui em diante escurecer mais NÃO sobe a razão: a própria borda da Sophia cai
junto (os 2 px de borda são pixels antisserrilhados que misturam com o fundo) — teste com alfa 0,84:
2,90 / 2,93 / 2,92 e a sombra vira uma "bolha" visível no Espelho e na Coroa (rejeitado). O teto pelo fundo
é ≈ 2,9–3,0. **O que falta é do lado da Sophia** (borda média ≈ 0,14–0,17): pedido à Arte/anim-sophia em
`docs/pedidos/cenario7.md` (luz de recorte um pouco mais forte só na borda; com este fundo, +0,02 de
luminância de borda já passa de 3:1).

Como medir de novo: `godot --path . --audio-driver Dummy --resolution 640x360 --position 4000,4000
res://tools/cenario7/ProbeBg.tscn -- <tela> <saida> 150 [oldbg]` e `python tools/anim/contrast_r18.py <saida>`
(ou `tools/cenario7/r18_lum.py <saida>`, que mostra as luminâncias borda/anel em cima/baixo).
ATENÇÃO: o modo `blink` do HdShot + `contrast.py` (do antecessor) NÃO serve mais — o LaneHalo pisca junto
com a Sophia e entra na máscara. Use o ProbeBg.

## 3. Capturas (1280×720, `HdShot` — mesmo Shot, renderizado num SubViewport 1280×720 com `--resolution 1280x720`)
`C:\gnosis-wt\_caps\cenario7\final\` — `antes_<tela>.png` (fundos antigos) e `depois_<tela>.png`
(HD + véu + LaneHalo) das telas 3, 13, 22, 31, 40, 49, 58, 66, 68 (1 por Éon);
prancha `prancha_9eons_antes_depois.png`. Medidas e recortes: `C:\gnosis-wt\_caps\cenario7\probe\`
(`old_*`, `hd_*`, `fin_*`; `crop_cmp4.png` = o alfa 0,84 rejeitado).

## 4. Validação
`tools/validate.ps1` → TUDO VERDE (14 etapas; CodexQA 53 PASS, AudioQA 66, SaveQA 49, TecnicoQA 43…).

## 5. CHECAGEM DE SATISFAÇÃO
| decisão | R atendidas | R violadas / risco | §4 |
|---|---|---|---|
| Fundos HD dos 9 Éons | R18 (fundo menos detalhado/contrastado na faixa via véu), identidade por Éon | nenhuma; mid/asas variam por tela de forma determinística (sem sorteio que afete jogo) | ok (nada de flash/tremor/som) |
| Véu escuro na faixa de luta | R18 (fundo 10–25 % menos saturado e com menos contraste interno atrás dos lutadores) | escurece o cenário na altura da luta — céu e astro intactos (degradê) | ok |
| LaneHalo atrás da Sophia | R18 (sobe o contraste local 1,6–2,4 → 2,75–2,97) | **R18 não cumprido por inteiro (< 3:1)** — falta a borda da Sophia (pedido à Arte); alfa limitado a 0,72 para não virar bolha (beleza > número) | ok: estático, sem pulso/flash; não é cor como aviso |
| #22 halo da plataforma | R18 (sem forma fantasma brigando com a leitura) | nenhuma | ok |
| Inimigos | já têm contorno de leitura próprio (enemy.gd, inimigos6) | o LaneHalo NÃO vai nos inimigos (em ondas cheias escureceria a faixa toda) — não medi o contraste deles | — |
Nenhum truque de cassino (§3): não há recompensa, escassez nem aleatoriedade de jogo nesta mudança.

## BILHETE PARA O SUCESSOR
- Estado: tudo acima commitado e enviado em `dir7/cenario7`. FILA 12 integrada; R18 2,75–2,97 : 1 (falta a
  borda da Sophia, pedido feito); #22 feito.
- Chaves: `Scenery.hd_disabled` (antes/depois), `LANE_HALO_A/R/UP` em `scenery.gd`, `_lane_veil`
  (`LANE_TOP/FULL/ALPHA`), `FloorBand lane_dim`.
- Armadilhas: Sophia tem a ORIGEM no meio do corpo (não nos pés) — por isso `LANE_HALO_UP = 6`. A tela 68
  (Mente) começa com diálogo: ContrastProbe fotografa o diálogo. Não suba o alfa do halo acima de ~0,74.
- Próximo: quando a Arte subir a luz de recorte, rodar ProbeBg nas 10 telas da tabela e atualizar §2.
  Pendente (não feito): variantes `_b/_c` de mid/asas (só `_a` está no jogo, por peso de memória);
  medir contraste dos INIMIGOS contra o fundo novo.
