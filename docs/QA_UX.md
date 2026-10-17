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
