# QA de experiência do usuário (cargo `qa-ux`)

Sondas que jogam o GNOSIS por automação (eventos de tecla/gamepad injetados com
`Input.parse_input_event`, ou `Input.action_press` na pilotagem) e fotografam o
que um jogador veria. Não fazem parte do jogo; não gravam save nem Crônicas.
**Sempre com `--audio-driver Dummy`** (silêncio obrigatório).

`$godot` = `Godot_v4.7.1-stable_win64_console.exe` (caminho no CLAUDE.md).

| Sonda | O que faz | Como rodar |
|---|---|---|
| `tools/qa_ux/RunProbe.tscn` | Joga UMA tela do run: anda (`move_right`), briga com o inimigo mais perto (leve/forte/esquiva/anel) por 5 s por zona, depois limpa a wave; fecha loja/estela, escolhe a 1ª opção nos diálogos, anda até a fenda. Vigia: Sophia abaixo do chão/fora da arena, inimigo fora da arena >2 s, HUD duplicado, zona que não termina, "andando e preso". PNGs: `dialog1, arrive, fightN, shop, portal, end, bug_*`. | `& $godot --audio-driver Dummy --path . --resolution 1280x720 --position 4000,4000 res://tools/qa_ux/RunProbe.tscn -- <tela> <pasta> [seg_max] [fight\|fast\|die]` |
| `tools/qa_ux/run_all.sh` | RunProbe nas 68 telas em paralelo, 1 log por tela, resumo `END` por linha. ~7 min com 5 em paralelo. | `bash tools/qa_ux/run_all.sh <pasta> 5 fight` |
| `tools/qa_ux/contact_sheet.py` | Pranchas de contato (linhas = telas, colunas = momentos). | `python tools/qa_ux/contact_sheet.py <pasta_run> <pasta_pranchas> 6` |
| `tools/qa_ux/montage.py` | Grade simples de PNGs com legenda. | `python tools/qa_ux/montage.py out.png 2 800 a.png b.png ...` |
| `tools/qa_ux/UiProbe.tscn` | Menus por TECLADO: foco inicial e ordem do foco, pré-jogo, prólogo, pausa (Esc/Start), loja pela pausa (foco, Enter sem faíscas, Esc), Opções/Golpes (Esc volta pra pausa), Abandonar → Continuar, morte → checkpoint, Crônicas/Ateliê/Opções/Bestiário (B e Esc), Provação. | `... res://tools/qa_ux/UiProbe.tscn -- <pasta>` |
| `tools/qa_ux/PadProbe.tscn` | Só CONTROLE: A confirma? B volta? D-pad lateral no menu; A na pausa; A na escolha da tentação (tela 10). | `... res://tools/qa_ux/PadProbe.tscn -- <pasta>` |
| `tools/qa_ux/MiscProbe.tscn` | Casos pontuais: legenda grande, Crônicas (1 toque = 1 linha?), Estela (prompt/painel), morte no ar, Esc durante card de chefe + posição da Sophia na tela, câmera na parede, barra de chefe na batalha final (bate só num). | `... res://tools/qa_ux/MiscProbe.tscn -- <pasta>` |

Saída para grep: `QA|<tela>|BUG?|...`, `QA|<tela>|END|...`, `UI|BUG?|...`,
`PAD|BUG?|...`, `MISC|...`. Verde = toda tela termina em `END|ADVANCED`
(68 = `ENDSCREEN`), nenhum `BUG?`, nenhum `SCRIPT ERROR` nos logs.

Limitações honestas: não há joystick físico (eventos injetados); a janela fica
fora do monitor e é limitada ao tamanho dele, então tela cheia real / ultrawide
(pillarbox do `aspect=keep`) não foi fotografada; a pilotagem é simples (não
mede feel/timing); dano é "curado" acima de 40% para a sonda não morrer.

Relatório de bugs da passada: `C:\gnosis-wt\_caps\qa-ux\BUGS.md`.

## Linux / nuvem (Onda 2)

Sem monitor: `RENDER=headless` (padrão) roda com `--headless --fixed-fps 60` — rápido e
determinístico, SEM PNG (as sondas detectam o headless e só registram o momento da foto).
`RENDER=xvfb` grava os PNGs numa janela virtual (Xvfb + opengl3/llvmpipe; ~2–5× mais lento
e com 1–2 fps numa máquina compartilhada).

```
bash tools/qa_ux/run_all.sh /home/user/caps/qa/run_h 2 fight            # 68 telas, ~10 min
RENDER=xvfb TEMPO=500 bash tools/qa_ux/run_all.sh /home/user/caps/qa/run_x 2 fight "1 10 68"
godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/qa_ux/UiProbe.tscn -- <pasta>
xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --rendering-driver opengl3 \
  --path . --resolution 1280x720 res://tools/qa_ux/MiscProbe.tscn -- <pasta>
python3 tools/qa_ux/contact_sheet.py <pasta_run> <pasta_pranchas> 8
```
`run_all.sh` grava `RESUMO.txt` (uma linha por tela + `TOTAL`). "resources still in use at
exit" (REVISAO #15) não conta como erro. Em xvfb, com 1–2 fps, a pilotagem por tempo fica
imprecisa (ex.: a UiProbe viu o checkpoint antes do diálogo de morte nascer) — o veredito
vale pelo headless; o xvfb é para OLHAR.

## QAs de regressão (`tools/regressao/`)

Um teste headless por bug conhecido (B1, A1–A6, REVISAO #1/#3/#10). PASS = o bug não
acontece mais. Descrevem o COMPORTAMENTO (o que o jogador vê), não a implementação.
```
tools/regressao/run_all.sh              # todos; tabela ID · estado · falhas
tools/regressao/run_all.sh A3 R1        # só alguns
AUTOTESTE=1 tools/regressao/run_all.sh B1   # o teste simula a correção → deve dar PASS
godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/regressao/Reg.tscn -- A4
```
Saída `REG|<ID>|CHECK|<nome>|OK/FALHA|<detalhe>` e `REG|<ID>|PASS|FAIL|BROKEN`. Esperas são em
QUADROS (1/60 s de jogo). R3 grava no `user://` e recusa rodar sem `override.cfg` isolado.
Contratos que os testes leem: A3 → `hud.boss_bars() -> Array` de `{node, ratio, phase}`;
R10 → `PauseStack.push/pop`.
