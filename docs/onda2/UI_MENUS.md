# UI-MENUS — relatório da Onda 2 (branch `dir2/ui-menus`)

Continuação de um agente derrubado pelo reinício das 06:05. Ele tinha deixado só a
sonda `tools/ui_menus/` (não commitada, sem compilar porque esperava `Credits.licenses_path`).
Aproveitei a sonda: ela é o teste de tudo abaixo.

## 1. Commits
- `d2bc48a` Créditos: lê o bloco `## CRÉDITOS` do LICENSES.md, reserva CC-BY embutida; sonda dos menus
- `b1a2906` PauseStack (pausa, loja, Estela, Provação); loja A1/M3; Melhorias trancada em combate (M6); Estela M7; dicas da Provação P3
- `6934ce8` Reduzir flashes; Crônicas L3; medalhão P1; Bestiário L2
- `316b699` Opções: gravação (versão intermediária, substituída no commit seguinte)
- `2873254` Opções gravam SÓ por `SaveManager.save_game()` (a pedido do chefe saiu a gravação direta do save.json); `ui_open` no resultado da Provação; pedidos

## 2. O que mudou
- `scripts/ui/pause_menu.gd`: `PauseStack.push/pop` (com `_exit_tree`), `clear()` ao abandonar. **M6**: em combate
  (zona trancada ou inimigo vivo) "Melhorias" fica desabilitada, com a linha "Disponível fora de combate" embaixo;
  apertar dá `shop_fail`. Helper estático `in_combat(tree)`.
- `scripts/ui/upgrade_menu.gd`: PauseStack (fechar por cima da pausa mantém a pausa; sem pausa embaixo, despausa).
  **A1**: foco no 1º item ao abrir (trancado também), setas/D-pad, Enter/A compra, Esc/B fecha. **M3**: linha
  indisponível mais apagada (texto, preço, filete) + faixa "Faíscas insuficientes · faltam N" no item focado
  ("…para as melhorias" no Voltar quando nada dá).
- `scripts/entities/stela.gd`: painel na PauseStack. **M7**: só abre sem inimigo vivo a < 320 px, sem zona trancada e
  fora de combo (`combo_sequence` + `combo_reset_timer`); o convite some com inimigo perto. Enter lê, mas o
  `ui_accept` que também é `jump` (Espaço/A) não lê.
- `scripts/levels/codex_trial.gd`: resultado na PauseStack (+ `ui_open`); botões fazem `clear()` antes de trocar de cena;
  **P3**: `hint_label` muda entre teclado e controle pelo último dispositivo; "Ir para a Campanha".
- `scripts/ui/options_menu.gd`: **"Reduzir flashes"** (padrão desligada) em `GameManager.settings["reduce_flashes"]`,
  espelhada em `Juice.reduce_flashes` se o campo existir; gravar = só `SaveManager.save_game()`.
- `scripts/ui/chronicles.gd`: **L3**: repetição própria (1 passo no aperto, 0,35 s parado, depois 0,08 s); o eco do teclado do sistema é ignorado.
- `scripts/fx/codex_sanctum.gd` + `codex_style.gd` + `character_atelier.gd`: **P1**: `medallion` (0,25 nas telas de
  texto): o medalhão vira textura e os 7 anéis que pareciam cursores somem. O menu principal (pintura cobre) não muda.
- `scripts/ui/gallery.gd`: **L2**: o nome quebra em 2 linhas só se não couber (medido na fonte); "Sophia Nv. 1".
- `scripts/ui/credits.gd`: lê o bloco "## CRÉDITOS" (linhas "- ") + tabela de Packs; reserva embutida CC-BY (Kevin
  MacLeod 4.0, LRSF 3.0, Kenney CC0); Godot (MIT) + godotengine.org/license; fontes OFL; Codex (OpenAI) igual ao card do epílogo.
- `tools/ui_menus/menu_probe.gd`: sonda (seções loja pausa pilha voltar cronicas opcoes estela provacao creditos
  bestiario; `opcoes_provacao` só a pedido). Com `--headless` pula as capturas (tempos confiáveis).
- Textos do Roteiro: todos os itens da tabela que caem nos meus arquivos já estavam aplicados na base; faltava só "Ir para a Campanha".
- `ui_cancel` (Esc/B) volta em pausa, opções, golpes, crônicas, ateliê, bestiário, créditos e pré-jogo. Já existia na base;
  agora a sonda testa. O B real depende do B1 do Técnico.

## 3. Capturas (`/home/user/caps/ui-menus/`)
- Antes: `antes/ux_*.png` (UxShots do agente anterior), `probe0/*.png` (sonda na base).
- Depois: `depois/ux_*.png` (UxShots) e `depois_probe/*.png` (sonda).
- `probe1/loja_0faiscas.png`: foco no 1º item, aviso "faltam 50", linhas apagadas (antes: `probe0/loja_0faiscas.png`).
- `depois_probe/pausa_em_combate*.png`: Melhorias apagada + "Disponível fora de combate".
- `depois/ux_pregame.png`, `ux_atelie.png`, `probe1/opcoes_flash_ligado.png`: sem círculos sobre títulos e sliders
  (antes: `antes/ux_pregame.png`, `ux_atelie.png`, `ux_options.png`).
- `probe1/provacao_controle.png`: faixa com "Analógico mover · A saltar · … RT esfera".
- `depois_probe/creditos_*.png`: rolo dos créditos com o bloco e os packs.

## 4. Validação
`TIMEOUT=900 tools/validate.sh` (código final), igual à base:
```
Scripts        OK      ScriptCheck    OK
CodexQA        FALHOU  pass=32  | QA FAIL: diretório de save independente   (falso, override.cfg — Técnico)
AudioQA        FALHOU  pass=23  | QA FAIL: duck(): música -4.4 → -4.4 → -4.4 dB  (conhecido — Áudio)
GnoseQA OK pass=18 · SaveQA OK pass=13 · PuppetQA OK · HeroQA OK · WaveQA OK
```
Sonda: `godot --headless --audio-driver Dummy --path . res://tools/ui_menus/MenuProbe.tscn -- <pasta>` → **57 ok, 0 falha(s)**;
com janela (seções loja pausa estela provacao creditos bestiario) → 34 ok, 0 falha(s). Na base: 40 ok, 10 falhas.

## 5. O que NÃO ficou bom / limites
- O B do controle só funciona com o B1 do Técnico; a sonda mapeia A/B só dentro dela.
- "Reduzir flashes" grava, mas volta a "Desligada" ao reabrir o jogo até `reduce_flashes` entrar no `SETTINGS_DEFAULT`
  (Técnico). Não tem efeito visível até o Juice/Cenário lerem o campo (Combate/Cenário).
- Opções mudadas na Provação: dependem do REVISAO #13 do Técnico. Testável com a seção `opcoes_provacao`. Não testei com o código dele.
- Diálogo e cinemática ainda escrevem `paused` direto (UI-HUD/Encenação): fechar um diálogo com a loja aberta ainda despausa.
- L3: medido em tempo real com a CPU carregada; a sonda aceita 4 a 11 passos em 1 s (o ideal é ~10, e eu vi 4 a 7 sob carga).
  Não testei com teclado e controle físicos.
- A faixa vazia do aviso da loja deixa 13 px de folga quando não há aviso (é de propósito, para o painel não pular).
- `tools/UxShots` (não é meu) quebrou no fim (Provação, `current_scene` nulo por lentidão); as telas antes disso foram salvas.

## 6. Pedidos
`docs/pedidos/onda2_ui-menus.md`. Pedidos ao Técnico: B1, `reduce_flashes` no SETTINGS_DEFAULT, #13, `clear()` no SceneManager.
A UI-HUD e a Encenação devem passar o diálogo e a cinemática para a PauseStack. O Combate deve criar `Juice.reduce_flashes`.
