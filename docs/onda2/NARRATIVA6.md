# NARRATIVA 6 — relatório (dir5/encenacao5, 18/10/2026)

Pedido do João (playtest 17/10): "a história passa por cima do jogo durante a ação e nada é ensinado";
"quer PULO DUPLO, liberado pelo Soter, numa cena".

## O que mudou
- **Legendas só na calma** (`caption_bar.gd`): nenhuma legenda nova começa com inimigo vivo a < 380 px ou luta
  de chefe com barra; a fila espera 1 s de calma. Falas `urgent` (fase 2/3 dos Arcontes, 7º Anel — curtas, da
  própria luta) passam. Uma fala comum que estava no ar quando a luta começou sai e volta à frente da fila
  (uma vez). No encontro com NPC a fila velha é descartada. Prova: `tools/encenacao/CalmProbe` (4/4).
- **Uma ideia gnóstica por Éon** na caixa de chegada do Éon (mundo parado), 1 linha da Sophia: sono/esquecimento,
  Kenoma (falta), destino dos Arcontes (correntes), Silêncio (a verdade espera), conhecer-se (o reflexo copia),
  a faísca não apodrece, poder que pede joelhos tem medo.
- **Ensino na hora**: 1º aparo do run → câmera lenta + "contra-ataque: golpeie agora"; 1º Anel → a Voz manda
  experimentar (a dica de tecla do HUD já existia); pulo duplo → prompt "no ar, pule outra vez" + degrau.
- **Soter concede a leveza** (1º encontro, tela 17): depois da bênção escolhida, 5 falas: as mãos nos ombros
  (coluna de luz nela), a rubrica (ela sobe um palmo; `grant_double_jump`), "Há passagens que só se alcançam
  com asas... Dou leveza", "Vê aquela luz no alto?" (o DEGRAU DE LUZ acende a 116 px — só com pulo duplo). Ele
  espera ela subir (até 45 s ou ela ir embora), paga 30 faíscas, diz "Quem dá asas não luta..." e parte; o degrau
  fica como lugar de treino. Prova: `tools/encenacao/SoterProbe` (6/6) e `_caps\encenacao5\o6\soter_sheet.png`.
- `archon_phase3` (chefes6), `node_arrival(kind)` (mapa6), `InputGlyphs.card_hint()` nos cards (UI5).
- Roubo: decalque pintado `fx_floor_crack_a` (6 quadros) como efeito principal, grande, com fachos/poço/tremor;
  quadro sobe para o abismo ficar acima da caixa. Estela atrás dos lutadores (z −1). Correção: o meio do quadro
  de diálogo usa o ALVO da câmera (com câmera atrasada a Sophia saía do quadro).

## Validação
`validate.ps1 -Repeat 2`: TUDO VERDE (11 etapas, 2/2). i18n: `build --strict` 1380/1380, LangQA e EnFit (0 falhas).

## Limites honestos
- O pulo duplo em si é do combate6/progressao6: nesta base não há `grant_double_jump` → a cena roda, o degrau
  aparece, mas a Sophia não consegue subir até os dois branches entrarem (a sonda põe ela em cima).
- Não joguei com controle; ritmo/volume de falas precisam do João. A "calma" corta TODA legenda comum em
  combate: se ficar silencioso demais, baixar `HOT_RANGE`.
- O contra-ataque lê um campo privado do player (pedido ao combate6).
