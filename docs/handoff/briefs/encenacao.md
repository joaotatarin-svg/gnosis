# Brief — ENCENAÇÃO (dir2/encenacao)
Leia: REGRAS_NUVEM.md, docs/ROTEIRO.md §2 (cenas A–D) e §5 (ganchos), docs/handoff/NARRATIVA_EMOCIONAL.md §6 e §9, docs/handoff/REVISAO.md #1 e #10, docs/pedidos/roteiro.md, docs/pedidos/combate.md (level.gd), docs/AUDIO.md (API de música).

ARQUIVOS SEUS: scripts/levels/level.gd, scripts/levels/final_battle.gd, scripts/entities/{sleeper,npc_encounter,chest,seal_puzzle,exit_portal}.gd, scripts/fx/cinematic.gd, scripts/autoload/narrative.gd, scenes/levels/*, novos em scripts/levels/ (ex.: staging.gd), tools/encenacao/, docs/onda2/ENCENACAO.md.

APIs de outros (chame de forma que compile sem elas): DialogueBox line_shown (existe), wait_2s e lock_advance (ui-hud); HUD ring_dot_global_pos/ring_dot_world_pos/detach_ring/ring_detach_finished (existem), restore_ring (ui-hud); Audio play_music(t,loop,pitch), set_music_pitch, duck_music, set_music_layer_volume, SFX fog_swell/king_step/mask_light/voice_merge/whisper (existem); player.health.reset_mercy() (combate).

TAREFAS (commit a cada uma):
1. REVISAO #1: um único desfecho por tela (`_resolved`); se o chefe/tela já foi vencido, a morte simultânea não manda ao checkpoint. Timers de morte com create_timer(t, false). Provar com tools/revisao/SondaCorrida.tscn (telas 10 a/b, 1, 64) antes e depois.
2. cinematic.gd usa PauseStack.
3. Ganchos ROTEIRO §5: #1 santuário antes da loja, #3 eco do Centro, #4 7º Anel na 1ª queda (+slow_mo 0.2,1.2), #5 sleeper ao acordar, #6 fala de cada final; reset_mercy ao trancar zona; toast "As duas formas precisam cair juntas."
4. Cenas A (Rei sai da névoa, tela 1), B (roubo, 64: gemas voam com detach_ring, avanço travado até a 7ª; máscara cai; vira motor), C (descida ao Centro, 65), D (anagnórise, 68: restore_ring, clarão, Colosso encolhe, escolha). Por código, dirigidas pelos `cue` via line_shown. Nenhuma gema antes da fala 5; "Yaldabaoth" só a partir da fala 6.
5. Itens restantes da NARRATIVA_EMOCIONAL §9 nos seus arquivos.
Prova: capturas em sequência das telas 1, 64, 65, 68; GnoseQA/CodexQA verdes.
