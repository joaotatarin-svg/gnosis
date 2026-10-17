# GNOSIS — Relatório de bugs de UX (QA-UX, passada 1)

Base testada: `codex/despertar` @ `d291db0` (worktree `C:\gnosis-wt\qa-ux`, branch `dir/qa-ux`), 17/10/2026.
Ferramentas: `tools/qa_ux/*` (ver `docs/QA_UX.md`). Todos os Godot com `--audio-driver Dummy`.
**C** = confirmado com captura/log · **S** = suspeita (leitura de código ou evidência parcial).

## O que FUNCIONOU (pra não perder de vista)
- **68/68 telas avançam** pilotadas por input (anda → zona tranca → briga 5 s → limpa → fenda/loja/roubo). 68 termina no EndScreen depois do epílogo. Nenhuma zona travada, nenhum portal que não abre, nenhum inimigo fora da arena >2 s, nenhuma barra de chefe duplicada. Resumo: `C:\gnosis-wt\_caps\qa-ux\run_all.txt`, logs `C:\gnosis-wt\_caps\qa-ux\run\sNN.log`, pranchas `C:\gnosis-wt\_caps\qa-ux\pranchas\`.
- **0 `SCRIPT ERROR`/`ERROR` de jogo** nos 68 logs (só "resources still in use"/"ObjectDB leaked" ao sair).
- Pés no chão: y do jogador no chão sempre 285,9–286,0 nas 68 telas.
- Morte → checkpoint certo (morreu na 4 → volta na 2, faíscas 100→80, HP cheio). Abandonar → menu mostra "Continuar · … (Tela N)" com foco nele → Continuar carrega a tela certa. Pausa abre/fecha com Esc e com Start; Opções/Golpes voltam pra pausa com Esc.
- `CodexQA`: `QA RESULT: 0 falhas`.

## Tabela (ordenada por severidade)

| ID | Sev. | C/S | Área (arquivo provável) | Como reproduzir | Esperado × Obtido | Captura |
|---|---|---|---|---|---|---|
| B1 | **Bloqueante** (jogador de controle) | C | `scripts/autoload/game_manager.gd` `_register_inputs()` (não mapeia controle em `ui_accept`/`ui_cancel`) | Só com controle: no menu, foco em "Nova campanha", apertar **A**. Tela 10: na tentação do Athoth ("Recusar/Ceder") apertar **A**. Loja pós-chefe/santuário (tela 6): tentar fechar. | Esperado: A confirma, B volta. Obtido: `InputMap ui_accept = Enter, Kp Enter, Space`; `ui_cancel = Escape` — nenhum botão de controle. A não aciona nenhum botão (menu fica parado; na tentação a caixa continua aberta com a árvore pausada = **softlock na 1ª tentação** sem teclado/mouse). B não volta em nenhum menu, pausa, Opções, Crônicas. A tela de Golpes diz "Esc / B fecham" — B não fecha. Só D-pad (foco) e Start (pausa) funcionam. Steam Deck/controle = jogo inacessível. | `C:\gnosis-wt\_caps\qa-ux\ui\pad_tentacao_escolha.png` · log `PAD|BUG?|A_nao_confirma`, `PAD|tentacao_A_escolhe|caixa_ainda_aberta=true`, `UI|inputmap.ui_accept|Enter, Kp Enter, Space` |
| A1 | Alta | C | `scripts/ui/upgrade_menu.gd` (sem `grab_focus`, sem `_unhandled_input`) | Pausa → Melhorias (ou a loja pós-chefe/santuário). Apertar ↓, Enter, Esc. | Esperado: 1º item focado, setas navegam, Esc fecha. Obtido: foco `<nenhum>`; setas e Enter não fazem nada; Esc não fecha (só clique no botão). Somado a B1, a loja pós-chefe trava quem joga sem mouse. | `C:\gnosis-wt\_caps\qa-ux\ui\ui09_loja_pela_pausa.png` · `UI|BUG?|loja_sem_foco`, `loja_nao_fecha_com_esc` |
| A2 | Alta | C | `scripts/ui/caption_bar.gd` (`layer = 60`, não some com a árvore pausada) | Tela 1, logo após a intro (legenda da Voz ativa), abrir a pausa; entrar em Melhorias, Opções, Golpes. | Esperado: menus por cima de tudo. Obtido: a faixa de legenda fica **por cima** da pausa (cobre "Abandonar run"), da loja (cobre "Restauração"), das Opções (cobre "Legendas" e "Voltar") e da tela de Golpes. | `C:\gnosis-wt\_caps\qa-ux\ui\ui08_pausa.png`, `ui09_loja_pela_pausa.png`, `ui10_opcoes_pela_pausa.png`, `ui11_golpes_pela_pausa.png` (todas em `...\ui\`) |
| A3 | Alta | C | `scripts/ui/hud.gd` `show_boss()` + `scripts/levels/final_battle.gd` | Tela 68. Bater só no Rei até 40%. Depois matar só o Rei. | Esperado: duas barras (Rei e Colosso) ou barra do alvo certo. Obtido: uma barra com o nome "O Colosso Oco — a Verdade" desde o início (o Rei, que está na tela, não tem barra); bater no Rei baixa ESSA barra e ela vira "Colosso … — FASE II" (fase aplicada ao chefe errado); quando o Rei cai a barra **some** com o Colosso vivo e cheio. Os dois chefes alimentam a mesma barra. | `C:\gnosis-wt\_caps\qa-ux\misc\misc_final_barra.png`, `misc_final_um_caiu.png`, `C:\gnosis-wt\_caps\qa-ux\run\s68_arrive.png` · `MISC|final_apos_bater_em_O Rei…|barra='O Colosso Oco — a Verdade  —  FASE II' largura=40%`, `final_um_caiu|barra_visivel=false outro_vivo=true` |
| A4 | Alta | C | `scripts/entities/player.gd` `_physics_process()` (retorna cedo em `State.DEAD`, antes de `move_and_slide()` e `_sync_anim()`) | Pular e morrer no ar (ou morrer de pé). | Esperado: cair até o chão e fazer a pose "dead". Obtido: **congela no ar** (y=219, chão=286) na pose de pulo; de pé, fica em idle — nunca toca a anim "dead" (anim_state="jump"/"idle"). Morte sem feedback visual. | `C:\gnosis-wt\_caps\qa-ux\misc\misc_morte_no_ar.png`, `C:\gnosis-wt\_caps\qa-ux\ui\ui15_morte.png`, `...\ui\crop_morte.png` · `MISC|morte_no_ar|y_no_golpe=219 y_1.2s=219 no_chao=false estado=8 anim=jump` |
| A5 | Alta | C | `scripts/fx/camera_shake.gd` (look-ahead ±90 px vai em `offset`, que o Godot soma DEPOIS dos `limit_*`) | Tela 10: andar até o card do Athoth e ficar parada perto da parede esquerda da arena, virada pra direita. | Esperado: Sophia sempre na tela. Obtido: Sophia **fora da tela** (x de tela = −48 px; jogador x=191, centro da câmera 559, limites [150,1090]); o Arconte atira pra fora do quadro. Também mostra 90 px além das paredes da arena (o fundo cobre, então não aparece faixa vazia). | `C:\gnosis-wt\_caps\qa-ux\misc\misc_esc_no_card.png`, `...\misc\crop_card.png`, `...\misc\misc_camera_parede_esq.png` · `MISC|esc_no_card_player|pos=(191,286) tela_px=(-48,242) … cam_center=(559.4,…) limites=[150,1090]` |
| A6 | Alta | C | `scripts/ui/dialogue_box.gd` `_show_choices()` (HBox de botões cresce além da caixa) | Tela 68, vencer a batalha dupla → escolha final com 3 opções. | Esperado: caixa e 3 botões dentro da tela; motivo do "Semente" bloqueado visível. Obtido: a caixa **estoura a borda direita**; "Semente — plantar a gnose" cortado na borda, desabilitado sem explicação (a dica só existe como tooltip de mouse). É o momento mais importante do jogo. | `C:\gnosis-wt\_caps\qa-ux\run\s68_choices.png`, `C:\gnosis-wt\_caps\qa-ux\crop68.png` |
| A7 | Alta (atrito) | C | `scripts/levels/level.gd` / `hud.gd` (só `codex_trial.gd` tem faixa de teclas) | Nova campanha → prólogo → Rei. | Esperado: dica de controles nas primeiras telas (mover/pular/golpes/esquiva/aparar), na forma do dispositivo em uso. Obtido: nenhuma dica na campanha; o jogador precisa achar "Golpes & Controles" no pré-jogo/pausa. A Provação tem a faixa (só teclado). | `C:\gnosis-wt\_caps\qa-ux\ui\ui07_rei_inicio.png`, `C:\gnosis-wt\_caps\qa-ux\run\s01_arrive.png` |
| M1 | Média | C | `scripts/ui/caption_bar.gd` (faixa em y 260–304 de 360) | Qualquer tela com legenda (quase todas), especialmente chefes. | Esperado: legenda fora da faixa de jogo. Obtido: a faixa escura cobre os **pés** da Sophia/inimigos e telegrafos de chão (névoa do Torpor, poças); com 2 linhas a 2ª encosta/sai da faixa. | `C:\gnosis-wt\_caps\qa-ux\run\s10_fight0.png`, `C:\gnosis-wt\_caps\qa-ux\misc\misc_legenda_G.png`, `C:\gnosis-wt\_caps\qa-ux\test\s02_fight0.png` |
| M2 | Média | C | `scripts/ui/hud.gd` `toast()` (mesma linha da fileira de Anéis) | Tela 68 (ou qualquer toast com Anéis no HUD). | Esperado: toast em área própria. Obtido: o texto cola no nome do Anel: "(roubado)As duas formas precisam cair JUNTAS." | `C:\gnosis-wt\_caps\qa-ux\crop68b.png` |
| M3 | Média | C | `scripts/ui/codex_style.gd` (estilo `disabled` aplicado por `apply_existing`) + `upgrade_menu.gd` | Loja com 0 faíscas. | Esperado: indisponível = apagado e "faíscas insuficientes". Obtido: itens indisponíveis com **borda dourada** (parecem destacados/selecionados), texto quase igual ao ativo, nenhum aviso. | `C:\gnosis-wt\_caps\qa-ux\ui\crop_loja.png` |
| M4 | Média | C | `scripts/fx/cinematic.gd` boss card × `hud.gd` / `caption_bar.gd` | Entrar numa tela de Arconte (card "ATHOTH"). | Esperado: card limpo. Obtido: a tarja de letterbox corta a barra de vida do HUD ao meio; fileira de Anéis e legenda ficam por cima do card. | `C:\gnosis-wt\_caps\qa-ux\res\t10_1366x768.png` |
| M5 | Média | C | `scripts/levels/scenery.gd` (emendas dos tiles de chão/fundo) | Qualquer tela; olhar o chão. | Esperado: chão contínuo. Obtido: linhas verticais duras de 1 px no chão e no fundo onde os tiles se encontram (todas as telas). | `C:\gnosis-wt\_caps\qa-ux\crop_seam50.png`, `C:\gnosis-wt\_caps\qa-ux\test\s02_portal.png` |
| M6 | Média (design) | S | `scripts/ui/pause_menu.gd` → Melhorias | Em luta de chefe: pausa → Melhorias → "Restauração — cura cheia (50)". | Esperado (provável): cura só em santuário/pós-chefe. Obtido (por código): loja acessível a qualquer momento pela pausa — cura cheia no meio do chefe, quebra a tensão. Não comprei de fato na sonda. | — |
| M7 | Média | S | `scripts/entities/stela.gd` (`attack_light` abre a Estela) | Tela 1: a Estela fica perto do ponto de partida; apertar J (ataque) perto dela. | Esperado: ataque ataca; ler com botão de interação. Obtido (por código + prompt "J · ler a Estela"): o golpe leve abre o painel e pausa o jogo. Não aconteceu em combate nas 68 telas (as Estelas ficam fora das zonas). | `C:\gnosis-wt\_caps\qa-ux\misc\misc_estela_painel.png` |
| L1 | Baixa | C | `scripts/ui/character_atelier.gd`, `gallery.gd` (`_unhandled_input` só trata `pause`) | Ateliê/Bestiário: apertar B. | Obtido: não volta (Esc/Start voltam por serem "pause"). Some com o fix do B1 se essas telas também tratarem `ui_cancel`. | log `UI|BUG?|b_nao_volta|CharacterAtelier.tscn` / `Gallery.tscn` |
| L2 | Baixa | C | `scripts/ui/gallery.gd` (células estreitas) | Menu → Ateliê → Bestiário. | Nomes cortados: "Larva do Kenom", "Ceifador Cornuc", "Escudeiro do Sel", "Servo do Demiurgo" vaza da célula. | `C:\gnosis-wt\_caps\qa-ux\ui\ui24_Gallery.png` |
| L3 | Baixa | C | `scripts/ui/chronicles.gd` `_process()` | Crônicas: segurar ↓ por 0,25 s. | Rola 3 linhas (repetição sem atraso inicial). Um toque = 1 linha (ok). | log `MISC|cronicas_sel|inicio=1 1toque=2 toque_0.25s=5` |
| L4 | Baixa | C | `scripts/ui/caption_bar.gd` × morte | Morrer enquanto uma legenda de caminhada roda. | A Sophia "fala" a legenda da Estela enquanto está morta. | `C:\gnosis-wt\_caps\qa-ux\ui\ui15_morte.png` |
| P1 | Polimento | C | `scripts/fx/codex_sanctum.gd` (ornamentos) | Pré-jogo, Opções, Ateliê. | Círculos/pontos decorativos por cima de títulos e textos; nas Opções os pontos sobre o slider de Música parecem cursores. | `C:\gnosis-wt\_caps\qa-ux\ui\ui02_pregame.png`, `ui23_OptionsMenu_navegado.png`, `ui20_CharacterAtelier.png` |
| P2 | Polimento | C | `scripts/levels/scenery.gd` / `level.gd` | Andar até a parede esquerda da arena. | Parede invisível no meio de cenário contínuo; ~25% de baixo da tela é chão liso escuro sem detalhe. | `C:\gnosis-wt\_caps\qa-ux\misc\misc_camera_parede_esq.png` |
| P3 | Polimento | C | `scripts/levels/codex_trial.gd` | Provação com controle. | Faixa de dicas só mostra teclas de teclado. | `C:\gnosis-wt\_caps\qa-ux\ui\ui26_provacao.png` |
| P4 | Polimento | C | `scripts/ui/moves_screen.gd` | Golpes & Controles. | Rodapé "Esc / B fecham" — B não fecha (ver B1). | `C:\gnosis-wt\_caps\qa-ux\ui\ui03_pregame_golpes.png` |
| D1 | Baixa (dev) | C | `user://` compartilhado (mesmo nome de projeto) | Abrir o menu num worktree. | Menu mostrou "Continuar · Torpor (Tela 2)" e Crônicas "1 de 18" vindos de outro processo/da máquina: ferramentas e worktrees dividem o save com o jogo do João. Risco só de desenvolvimento. | `C:\gnosis-wt\_caps\qa-ux\res\menu_1920x1080.png`, `C:\gnosis-wt\_caps\qa-ux\ui\ui18_Chronicles.png` |
| D2 | Baixa | C | saída do processo | Fechar o jogo. | "N resources still in use at exit" / "ObjectDB instances leaked" em todo exit. Inofensivo pro jogador. | qualquer `run\sNN.log` |

## Não testado / limites desta passada
- Controle físico (eventos injetados; o resultado do B1 vem do `InputMap` impresso pela sonda, então vale para controle real).
- Tela cheia real e ultrawide 2560×1080: a janela fica limitada ao monitor (1920×1080) e a captura pega só a área de conteúdo; com `stretch/aspect=keep` o layout é idêntico em 1366×768, 1920×1080 e 800×600 (`C:\gnosis-wt\_caps\qa-ux\res\`) — as barras laterais do ultrawide não foram vistas.
- Feel/timing, áudio, caminho "Ceder", final "Semente", leitura de todas as 18 Estelas, run inteiro sem cura artificial (a sonda cura abaixo de 40%).
- A sonda limpa as waves depois de 5 s de briga: softlock que só surge com combate longo não seria pego.

## Ferramentas
`C:\gnosis-wt\qa-ux\tools\qa_ux\` (RunProbe, run_all.sh, UiProbe, PadProbe, MiscProbe, contact_sheet.py, montage.py) — manual em `C:\gnosis-wt\qa-ux\docs\QA_UX.md`.

---

# Passada 2 — Linux/nuvem, `integracao/onda1` (17/10/2026, cargo `qa`, branch `dir2/qa`)

Base: `dir2/qa` = `integracao/onda1` (c1beb1c) + só ferramentas de QA. Sondas portadas para Linux
(`docs/QA_UX.md` § Linux). Capturas/logs em `/home/user/caps/qa/` (fora do git).

**Run das 68 telas (headless, `--fixed-fps 60`, modo fight):** 68/68 avançam (68 termina no
EndScreen), 0 `BUG?`, 0 `SCRIPT ERROR`; só "resources still in use at exit" (REVISAO #15) em 37 logs.
Chão: y 285,9–286,0 em todas. Resumo: `/home/user/caps/qa/run_h/RESUMO.txt`.
**Xvfb (PNG):** telas 1–13 e 19, 28, 37, 46, 55, 64, 65, 68 — todas avançam, 0 erro. Pranchas:
`/home/user/caps/qa/pranchas/`, `/home/user/caps/qa/pranchas_chefes/prancha_19-68.png`.
**UiProbe/PadProbe/MiscProbe:** rodadas headless (`/home/user/caps/qa/h/`) e em xvfb
(`/home/user/caps/qa/{ui,pad,misc}/`).

## Bug → teste → estado (QAs de regressão, `tools/regressao/run_all.sh`, 2 rodadas idênticas)

| ID | Teste | Estado hoje | O que o teste viu |
|---|---|---|---|
| B1 | `reg_b1.gd` | **FALHA** 6/6 | `ui_accept`=Enter, Kp Enter, Space; `ui_cancel`=Escape. A não aciona "Nova campanha"; tentação continua aberta e pausada; B não fecha loja nem pausa. Autoteste (A/B adicionados ao InputMap) → PASS 6/6. |
| A1 | `reg_a1.gd` | **FALHA** 2/8 | Melhorou (Esc fecha só a loja, setas navegam, Enter compra, foco volta à pausa), mas com 0 faíscas o foco nasce em "Voltar ao jogo"/"Seguir caminho" e não no 1º item (especificação do brief ui-menus). |
| A2 | `reg_a2.gd` | **PASSA** 4/4 | Corrigido na onda 1: a CaptionBar some com a árvore pausada (pausa, loja, Opções, Golpes). Fica como guarda contra regressão (atenção quando a pausa migrar para PauseStack). |
| A3 | `reg_a3.gd` | **FALHA** 6/9 | HUD sem `boss_bars()`. Pela barra única de hoje (MiscProbe): nome "O Colosso Oco" com o Rei na tela; bater no Rei baixa a barra do Colosso para 40% e marca "FASE II"; Rei cai → barra some com o Colosso vivo e cheio. Captura: `/home/user/caps/qa/run_x2/s68_arrive.png`. |
| A4 | `reg_a4.gd` | **FALHA** 3/3 | Morte no ar: y=213 com chão 286 após 1,2 s, anim "jump"; de pé: anim "idle" (nunca "dead"). |
| A5 | `reg_a5.gd` | **FALHA** 4/8 | Parede esquerda, virada para a direita: x de tela −50 (zona trancada da tela 10 e arena da 5). Virada para a esquerda: câmera mostra 90 px além do limite. |
| A6 | `reg_a6.gd` | **FALHA** 1/3 | Estouro corrigido (textos mais curtos: botões x 146–591 dentro do painel 36–604, sem corte). Falta: "Semente" trancado sem motivo visível (só tooltip). |
| R1 (REVISAO #1) | `reg_r1.gd` | **FALHA** 6/6 | Cenários a (20 quadros) e b (mesmo quadro): Anel dado, loja aberta, diálogo de morte por cima da loja, termina na tela 2 com `arconte_sono`. |
| R3 (REVISAO #3) | `reg_r3.gd` | **FALHA** 3/4 | save.json zerado ou cortado → best=1, sem "Continuar", sem finais; chronicles.json zerado → 0 lidas. Gravação normal OK. |
| R10 (REVISAO #10) | `reg_r10.gd` | **FALHA** 3/5 | Fechar um diálogo despausa com a loja ou a pausa abertas; diálogo de morte nasce com o mundo pausado por outro dono (PauseStack). |

## Outros achados da passada 2
- **Probe desatualizada (corrigida):** a UiProbe apertava Enter na loja com 0 faíscas com o foco em
  "Voltar ao jogo" (fechava a loja) e o Esc seguinte fechava a pausa → `SCRIPT ERROR` e travamento.
  A MiscProbe lia `_boss_box`/`_boss_name` do HUD antigo.
- **L1 continua:** B não volta em Crônicas, Ateliê, Opções, Bestiário (some com B1).
- **L2 resolvido:** nomes do Bestiário agora quebram em 2 linhas (`/home/user/caps/qa/ui/ui25_Gallery_navegado.png`).
- **M1 continua:** legenda cobre os pés do Rei na tela 68 (`s68_arrive.png`).
- **Esc durante o card de chefe** (tela 10) não abre a pausa (`MISC|esc_no_card|pausa_aberta=false`) — S, pode ser intencional.
- **Artefato, não bug:** em xvfb a 1–2 fps a UiProbe viu "morreu na 4, voltou na 4"; no headless a
  mesma sonda vê o checkpoint certo (tela 2, faíscas 100→80, HP cheio).
