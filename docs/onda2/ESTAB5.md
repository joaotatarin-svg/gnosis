# ESTAB5 — Estabilidade das QAs sob carga (Onda 5)

Branch `dir5/estab5` (base `integracao/onda1` 37ea6f5). Só ferramentas de teste
mudaram; **o jogo não foi tocado** (cinematic.gd/level.gd/staging.gd intactos).

## O problema
`tools/validate.ps1` às vezes reprovava a GnoseQA com
"card de chefe congela ao nascer o Arconte" + "card de chefe liberou o jogo",
sempre com a máquina carregada (bots de balance).

## Causa (medida, não suposta)
Uma cópia de diagnóstico da QA imprimiu o estado do nível no instante da checagem.
Nas falhas: `ready_done=false zone_active=false dialogos=1 paused=true` — a
**resposta da tentação** (tela 10) ainda estava aberta. A `goto_screen` antiga
esperava 0,5 s + `skip_all` + 0,3 s de relógio. Sob carga o timer criado no quadro
da carga da cena disparava nesse mesmo quadro; `skip_all` não via caixa nenhuma e
saía; a tentação abria DEPOIS, pausava o mundo e o gatilho do chefe nunca rodava.
As duas falhas vinham juntas porque a caixa seguia segurando a pausa.

**Não é bug do jogo**: com o nível pronto, o card nasce 1 quadro depois do gatilho,
segura a pausa e dura ~2,05 s (1,8 s + saída 0,25 s). Nenhum pedido em `docs/pedidos/`.

## O que mudou
- `tools/gnose_qa.gd`: nenhuma espera por segundos de relógio.
  - `until(cond, min_frames, min_secs)`: espera por ESTADO quadro a quadro; só
    desiste quando passaram os dois tetos (quadros E segundos) — o relógio nunca
    decide se passou.
  - `goto_screen`: espera o Level novo com `_ready_done` (só vira true depois dos
    bicos narrativos), sem caixa/cinemática, mundo solto e `PLAYING`, fechando os
    diálogos que aparecerem. Se não ficar jogável, reprova com o estado no log.
  - Card de chefe: espera o card nascer; confere a pausa; espera o card terminar
    (`_done`); novas checagens: "segura a pausa até acabar" e "dura ≥ 1,5 s" (piso
    de relógio: carga só alonga o card). Objeto liberado compara igual a null:
    usa `card_seen`.
  - Estela, prólogo, epílogo, Crônicas e as caixas da medição de texto: por estado
    ou por número de quadros.
- `tools/save_qa.gd`: o "Continuar" esperava 0,8 s e 1,2 s; agora espera o
  `SceneManager` ficar ocioso e a cena ser `Level01`.
- `tools/audio_qa.gd` (o Audio agenda por relógio real; a QA mede latências):
  - `_wait_real` termina 1 quadro DEPOIS do prazo. O `process_frame` acorda a QA
    antes do `_process` do Audio, então ela lia o envelope do quadro anterior —
    sob carga isso derrubou o slow-mo (1890 Hz em vez de 1500) 1 vez em 15.
  - `duck_music`: amostra todo quadro até o fim do hold e guarda o mais fundo.
  - Faixa de chefe, corte do roubo e 2ª batida: piso exato (nunca cedo) e teto
    + 2× o maior intervalo entre quadros medido na espera (`_poll_until`).
  - 1ª batida: conferida como síncrona (o registro muda dentro do `cue`) em vez
    de |Δ| < 50 ms (preempção da thread estourava).
  - Amostra "cedo" do roubo só conta se caiu antes do prazo (o piso de `cut_ms`
    já garante "não cortou cedo").
- `tools/validate.ps1` / `validate.sh`: etapa **LangQA** e modo
  **`-Repeat N`** / **`--repeat N`** (Scripts 1×, QAs N×, resumo "k/N verdes";
  verde só se passou nas N; logs `<QA>.rNN.out.log`).

Revisadas sem padrão frágil: CodexQA (já usava `_until` por quadros), HeroQA,
WaveQA, PuppetQA (o tempo medido é só impresso), LangQA (síncrona), TecnicoQA
(roda com `--fixed-fps 60`, timers determinísticos por quadro).

## Taxas antes/depois (GnoseQA, rodadas sequenciais)
| condição | antes (QA original) | depois |
|---|---|---|
| carga ambiente (~15–30 Godot de balance, CPU 100 %) | 2/10 falhas + 0/20 (a carga ambiente variou) | — |
| 3 GnoseQA em paralelo + ambiente | 3/12 falhas | — |
| + 8 workers Python de CPU | 2/20 falhas | — |
| + 8 workers Python + 6 Godot headless em laço | **17/20 falhas** | **0/30 falhas** |

Antes e depois da última linha rodaram **ao mesmo tempo**, na mesma carga.

AudioQA (mesma carga pesada): original 0/15 falhas; 1ª versão endurecida 1/15
(slow-mo, causa acima) → corrigida; depois 0/9 com 4 workers Idle (bateria
limitada a 10 min a pedido do chefe). `validate.ps1 -Repeat 2` com 4 workers Idle:
**TUDO VERDE, 2/2 em todas as 10 QAs** (incl. LangQA).

Logs: `C:\gnosis-wt\_caps\estab5\<bateria>\summary.txt` e `runNN.log`.

## Limites honestos
- Não há rodada "isolada" de verdade: a máquina sempre teve bots de balance
  rodando. A carga artificial foi encerrada a pedido do chefe (≤ 4 workers Idle).
- `validate.ps1` ainda roda `--quit-after 20000` e aceita exit 0 sem conferir a
  linha final da QA: uma QA que estoure 20000 quadros sai "verde" sem terminar.
  As atuais usam bem menos (GnoseQA ~420 quadros). Fora do meu escopo mudar.
- `-Skip Scripts` não pula a etapa (a), comportamento antigo do script.
- SaveQA escreve em `user://qa/` do worktree: duas SaveQA em PARALELO no mesmo
  worktree colidiriam (o `-Repeat` roda em sequência, sem problema).
- AudioQA mede latência por relógio real: com quadros acima de ~1 s ainda pode
  ser imprecisa; o teto cresce com o intervalo medido, então isso vira tempo, não
  falha.
