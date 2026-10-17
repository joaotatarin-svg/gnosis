# Brief — TÉCNICO (dir2/tecnico)
Leia: docs/handoff/REGRAS_NUVEM.md (ou /home/user/wt/REGRAS_NUVEM.md), docs/handoff/REVISAO.md, docs/QA_UX_BUGS.md (B1), docs/pedidos/audio.md (Técnico), docs/pedidos/anim-sophia.md (item 2), docs/BUILD.md.

ARQUIVOS SEUS: scripts/autoload/{save_manager,gnosis,run_manager,game_manager,scene_manager,codex_session,progression_manager,bestiary,game_content,fps_overlay}.gd, project.godot, export_presets.cfg, installer/*, scripts/data/*, assets/input/*, tools/save_qa.gd, tools/codex_qa.gd, tools/script_check*, tools/validate.*, novos em tools/tecnico/ e na raiz (LICENSE_godot.txt), docs/onda2/TECNICO.md.

TAREFAS (commit a cada uma validada):
1. B1: `_register_inputs()` mapeia JOY_BUTTON_A em ui_accept e JOY_BUTTON_B em ui_cancel (sem tirar teclas); ui_up/down/left/right com D-pad e analógico. Checagem no CodexQA (ou QA nova) que falha sem isso.
2. Save atômico (REVISAO #3) em save_manager.gd e gnosis.gd: .tmp → flush/close → copia atual para .bak → rename; load tenta .bak se o principal falhar. Teste com principal truncado.
3. Tipos errados (REVISAO #5): continue_run tolerante (_int/_float/_bool/_str_array), settings só se typeof bater com SETTINGS_DEFAULT, gnosis.gd str(id). Teste com os casos da revisão.
4. Export (REVISAO #2/#4/#6): include_filter (assets/LICENSES.md, OFL das fontes, assets/input/*.txt), exclude_filter="tools/*, artes/*, docs/*, assets/_packs/*, shots/*"; nada do jogo depende de res://tools em runtime. Instalador copia LICENSES.md e LICENSE_godot.txt (MIT do Godot); AppVersion 1.1.0. NÃO mude AppPublisher/AppId (anote).
5. Patches (REVISAO #7): só `patch_<config/version>_*.pck`; ignorar o resto com print.
6. Provação (REVISAO #8): codex_session usa FIRST_EON_SCREEN + boss_index*EON_LEN (+EON_LEN-1 no estágio do Arconte), sincronizado com codex_trial.gd.
7. REVISAO #9: SaveQA em user://qa/; CodexQA aceita user dir GNOSIS-WT-* (override.cfg) sem afrouxar a intenção.
8. REVISAO #12: SceneManager guarda o último pedido durante o fade e executa ao fim; chama PauseStack.clear() ao trocar de cena.
9. REVISAO #13: opções sempre gravam (persist de run separado de settings), inclusive na Provação.
10. Setting `reduce_flashes` (bool, false) em SETTINGS_DEFAULT; apply_settings espelha no Juice com `if "reduce_flashes" in juice`. Volume padrão 1ª execução: Master 0,7 / Música 0,6.
11. Se sobrar: remover código morto (scripts/data/enemy_data.gd, upgrade_data.gd se sem uso — grep inclusive .tscn/.tres); avaliar default_texture_filter (anim-sophia #2) com captura antes/depois.
NÃO ligue physics_interpolation (o chefe liga na integração).
