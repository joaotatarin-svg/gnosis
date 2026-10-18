# QA7 — Diretor de QA do jogo inteiro (Onda 7, versão 3.0.1)

Branch `dir7/qa7` (base `origin/integracao/onda1` = prévia 3, 4cfd64c). Worktree `C:\gnosis-wt\qa7`.
Capturas/logs fora do git em `C:\gnosis-wt\_caps\qa7\`.

## Estado (PAUSA pedida pelo chefe, 18/10)
Coberto até agora:
- Worktree importado (`--editor --quit`): 0 `SCRIPT ERROR`/`Parse Error`.
- `tools/qa_visual` trazido de `origin/dir4/qa-visual2`.
- Sonda nova `tools/qa7/qa7_bot.gd` + `tools/qa7/QA7Bot.tscn`: cópia do BalanceBot com colunas extras no CSV
  (`weapon` nível da arma, `minhp` menor fração de vida, `zero` mortes reais, `nets` redes de segurança acionadas
  — zona forçada/avanço forçado/teleporte à fenda —, `left` inimigos vivos no timeout, `jumps`, `dj` pulo duplo)
  e `ia=3` (pula/pulo duplo quando o alvo está acima — voadores/plataformas).
- Teste curto telas 1–4, seed 1, vel 4, ia=3: roda (51 s reais). Já mostra: tela 1 (Rei) 146 de dano / 2 quase-mortes;
  dano à distância domina (acolito(tiro)=92, sonambulo(tiro)=49) e `zona`=72 (dano sem golpe identificado — investigar).
  O bot precisou do teleporte à fenda nas telas 2–4 (rede de segurança; checar se a fenda é alcançável a pé).

Ainda NÃO feito: run inteiro 68 telas × 3 sementes; passada visual; caça de bugs; relatório final.

## BILHETE PARA O SUCESSOR
- Próximo passo: rodar `QA7Bot.tscn -- 1 68 4 seed=N ia=3 out=C:/gnosis-wt/_caps/qa7/bot/sN` para N=1,2,3 em paralelo
  (headless, `--audio-driver Dummy --fixed-fps 60`), agrupar erros do .log com Python; depois funcionários para
  passada visual (Shot em 640x360 `--position 4000,4000`) e caça de bugs.
- Armadilha: o bot cura ao cair abaixo de 45% (quase-morte); "morte real" só se um golpe passa de 45%.
- Armadilha: o bot teleporta à fenda/zona — use a coluna `nets` para achar fenda/gatilho inalcançável.
