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

## Cena do Soter com a arte desenhada (18/10, merge de dir2/arte-gpt 62f3ed0)
- Soter: `lift` (mãos erguidas) nas falas 0–1, `talk` na 2, `offer` (estende a mão para o degrau) na 4,
  `rest` (mãos juntas) antes do `fade`. Sophia: `soter_look` na fala 0, `soter_land` quando pousa (fala 1),
  `soter_bow` na fala dela "(Leve...)"; `stop_action()` ao fechar a caixa (ela volta a andar). Coluna de luz =
  `visual.bless_light(true/false)` (sem o método, o sprite antigo). Prova: `_caps\encenacao5\o6\soter_sheet_antes.png`
  × `soter_sheet_depois.png` e `soter_poses_crop.png`; SoterProbe 6/6 (pulo duplo concedido de verdade agora).

## CHECAGEM DE SATISFAÇÃO (docs/handoff/NEURO_SATISFACAO.md)
| Decisão | R atendidas | R violadas / justificativa | §4 conferido |
|---|---|---|---|
| Legendas só na calma (CaptionBar) | **R21** (respiro: a história fala nas pausas, não por cima da luta) | — | 13 (um sistema por vez; HOT_RANGE ajustável) |
| Lição gnóstica na caixa de chegada do Éon | R21 (momento parado, 1 linha) | — | — |
| Contra-ataque ensinado no 1º aparo (câmera lenta 0,55 s) | **R8** racionado: 1 vez por run (`Narrative.once`), escala 0,35; a saída em rampa é do Juice | O abafamento de som na lentidão é do Áudio/Juice (não é meu) | 5 (nada de slow-mo repetido) |
| Soter concede a leveza | **R9** (a música cai −14 dB no encontro, a cena tem silêncio); **R21** (0,9 s de respiro antes do prompt; Soter espera até 45 s, sem relógio na tela; `rest` + 1,6 s antes de partir) | — | 12 (recompensa FIXA: 30 faíscas, sem sorteio); 4 (sem clarão de tela cheia: só a coluna de luz nela) |
| Roubo: decalque + fachos + tremor | R9 (a cena corta a música no "Sete.") | Tremor em 6 pulsos (0,3–0,55): é o momento mais raro do jogo (1 vez por run) — §4.1 permite tremor no raro | 1, 4 (sem flash branco aqui; o clarão do roubo é o da máscara, 1×) |
| Quadro de diálogo / Sophia idle | R21 (a conversa assenta, ela para de correr) | — | — |
Nenhum truque de cassino: nada aleatório, nada com prazo ou perda; o degrau fica na tela para treinar.

## QA7 + ressalvas do Guardião (19/10)
- **#5** fichas do bestiário `acolito` e `espectro` (lore 2 linhas + dica, tom das Estelas; EN no lote 14).
- **#17** `Gnosis.boss_card` não repete o mesmo card na mesma tela por 8 s (a batalha dupla e a wave pediam juntas).
- **#28** Tween vazio no Staging: `_King.crack_open` no caminho pintado devolvia o Tween da cena sem passo (o
  `_flush` disparava o erro). Agora leva um intervalo.
- **#30 (narrativa)** cards da Cinemática com QUEBRA EQUILIBRADA (`_balance_text`): a caixa encolhe até a menor
  largura com o mesmo nº de linhas. `tools/encenacao/WidowProbe`: viúvas nos epílogos PT/EN 2 → 0.
- **Descida ao Centro (tela 65)**: de ~8,0 s (+ caixa) para ~4,95 s sem controle (ilustração 1,9 s, câmera desce
  1,6 s, joelhos 0,85 s); o preto entre a ilustração e o jogo caiu de 0,7 para 0,35 s. Medido pela soma dos
  tempos do Tween (não cronometrei com sonda).
- **Guardião R6**: as 30 faíscas do degrau (e as 120 do presente quando a arma está selada/no máximo) entram
  como as outras: `SparkOrb.burst` (9 orbes, a nota sobe em escala, o contador do HUD sobe 1 a 1).
- **Guardião (bug)**: o presente de arma do Soter usa `Progression.gift_weapon_level()` (respeita o selo).

### CHECAGEM DE SATISFAÇÃO (estas decisões)
| Decisão | R atendidas | R violadas / justificativa | §4 |
|---|---|---|---|
| Descida ao Centro em ~5 s | **R21** (pausa curta que conta, sem espera vazia); R8 (sem câmera lenta; o "tempo parado" é a ilustração, 1×) | — | 5 (não vira espera) |
| Faíscas do Soter em orbes | **R6** (entrega sensorial: orbe + nota que sobe + contador 1 a 1), quantidade fixa | — | 12 (sem sorteio) |
| Card do chefe não repete | R18/R21 (leitura limpa, sem congelar duas vezes) | — | 13 |
| Quebra equilibrada nos cards | R18 (leitura) | — | — |
