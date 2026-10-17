# Brief — UI-MENUS (dir2/ui-menus)
Leia: REGRAS_NUVEM.md, docs/QA_UX_BUGS.md, docs/UI.md, docs/pedidos/roteiro.md (tabela de textos), docs/pedidos/audio.md (UI), docs/pedidos/combate.md ("Reduzir flashes"), docs/handoff/REVISAO.md #10 e #13, docs/ESTILO_TEXTO.md.

ARQUIVOS SEUS: scripts/ui/{upgrade_menu,pause_menu,options_menu,moves_screen,gallery,chronicles,character_atelier,codex_style,codex_menu,pregame,credits,end_screen,codex_frame}.gd e suas .tscn, scripts/entities/stela.gd, scripts/fx/codex_sanctum.gd, scripts/levels/codex_trial.gd, novos em tools/ui_menus/, docs/onda2/UI_MENUS.md.

TAREFAS (commit a cada uma; captura antes/depois):
1. pause_menu, upgrade_menu, stela.gd, codex_trial.gd usam PauseStack.push/pop(self).
2. A1: loja com foco no 1º item, setas, ui_accept compra, ui_cancel fecha. M3: indisponível apagado + "faíscas insuficientes". M6: "Melhorias" na pausa desabilitada em combate ("Disponível fora de combate").
3. ui_cancel volta em todos os menus (pausa, opções, golpes, crônicas, ateliê, bestiário, créditos, pré-jogo). L1, L3 (repetição com atraso ~0,35 s depois ~0,08 s), P4.
4. Opção "Reduzir flashes" (padrão off) em GameManager.settings["reduce_flashes"] salvando como as outras (`settings.get(...)`). `Audio.play_sfx("ui_open")` ao abrir painéis se existir.
5. M7: a Estela só abre com o golpe leve sem inimigo vivo perto e fora de combo.
6. L2 (nomes do Bestiário), P1 (ornamentos sobre textos/sliders), P3 (dicas da Provação no dispositivo em uso).
7. Créditos: atribuições CC-BY com fallback embutido + bloco "## CRÉDITOS" do LICENSES.md + Godot (MIT) + fontes OFL.
8. Textos do Roteiro nos seus arquivos.
