# Fila da ONDA 2 (o chefe mantém)

## ESTADO AO VIVO (chefe na nuvem, 17/10/2026 05:50 UTC)
- `integracao/onda1` = Onda 1 inteira mergeada + `tools/validate.sh` (Linux) + `PauseStack` (scripts/autoload/pause_stack.gd).
  Validação na nuvem (Godot 4.7.1 Linux headless): tudo verde menos AudioQA (ducking — agente Áudio consertando).
- Agentes ATIVOS na nuvem (branch `dir2/<cargo>`, worktree `/home/user/wt/<cargo>`), donos destes arquivos:
  | cargo | arquivos |
  |---|---|
  | tecnico | autoloads save/gnosis/run/game/scene/codex_session/progression/bestiary/game_content/fps, project.godot, export_presets.cfg, installer/, scripts/data/, assets/input/, tools/save_qa, codex_qa, validate |
  | ui-hud | scripts/ui/hud.gd, caption_bar.gd, dialogue_box.gd |
  | ui-menus | demais scripts/ui/*, stela.gd, codex_sanctum.gd, codex_trial.gd |
  | encenacao | level.gd, final_battle.gd, sleeper/npc_encounter/chest/seal_puzzle/exit_portal, cinematic.gd, narrative.gd, scenes/levels |
  | combate | player.gd, enemy.gd, juice.gd, camera_shake/spark_orb/projectile/impact_burst/aoe_nova/hazard_zone/damage_number/gib/vfx_library, scripts/combat, scripts/components |
  | audio | audio_manager.gd, assets/audio, assets/LICENSES.md, tools/audio_synth |
  | cenario | scenery.gd, scenery_library.gd, shaders scenery_*, assets/backgrounds, tools/scenery |
  | loja | assets/store (novo), tools/store |
- LIVRES para a sessão LOCAL (arte GPT, branch `dir2/arte-gpt`): artes/gpt, assets/painted, boss_puppet.gd, painted_library.gd, character_art.gd, docs/ANIMACAO_CHEFES.md.
- Bastão para a sessão local agendado no servidor para 07:12 UTC. Batida de integração da nuvem a cada hora (min 47).


## Combate / câmera (dono: Game Design & Combate)
- Câmera: look-ahead + smoothing deixam a Sophia fora do quadro ~16 quadros (virar+esquivar). (Técnico)
- Interpolação de física (physics_interpolation) p/ monitores 144 Hz + `reset_physics_interpolation()` em teleportes. (Técnico)
- Presença em tela: Sophia pequena; terço inferior morto (enquadramento/zoom da câmera). (Chefe)
- Telegrafo do chefe: WINDUP pinta o sprite inteiro de amarelo sólido ~0,7 s → trocar por contorno/brilho. (Técnico → Anim-Chefes)
- Golpes L/LL/LLL usam a mesma pose → mapear para os quadros S4 do GPT. (Anim-Sophia)

- NEURO: C:\gnosis-wt\_caps\neuro\NEURO_SATISFACAO.md (22 recs). Fase A do Combate em andamento (juice/camera/hitbox/orbes). Fase B (player/enemy): R1 flash em tempo real + vibração da vítima; R5 telegrafo com brilho 180 ms + forma + som, tingir 40–50%, bug enemy.gd:778; R4 um VFX por acerto + som em camadas; R10 flash ≤3/s.
- APROVADO pelo João: "misericórdia oculta" (sobrevive com 1 HP uma vez por luta) → Combate.
- Polimento UI: barra do chefe com preenchimento rosado de baixo contraste sobre trilho cinza claro; marcador "II" colado na borda direita.

## Cenário / VFX
- Pré-aquecer VFX/gibs/shaders no load da fase (engasgos até 193 ms no 1º golpe). (Técnico)

## Técnico
- Remover código morto: scripts/ui/main_menu.gd (UI), scripts/data/enemy_data.gd, upgrade_data.gd, 6 tools soltos.
- NÃO commitar .import reescritos só por fim de linha (editor headless).

## Roteiro → Encenação
- 4 cenas: Rei sai da névoa (1), roubo (64), descida ao Centro (65), anagnórise (68). API HUD: ring_dot_global_pos/detach_ring.
- Implementar C:\gnosis-wt\_caps\narrativa\NARRATIVA_EMOCIONAL.md (21 itens; 12 primeiros = texto em narrative.gd). Ganchos: level.gd (conversa do santuário antes da loja, falas dos finais, caco do Centro como legenda), enemy.gd (legenda na fase 2), final_battle.gd (legenda do 7º Anel), sleeper.gd (fala do Adormecido), DialogueBox `cue` + sinal line_shown (pedido à UI), Audio (pitch/duck_music/camada do Centro — pedido ao Áudio). Decidir pistas fortes: morte de Yabel (versão A×B) e Velkar "inclinas a cabeça" (opcional).
- Roteiro renomeou magia "Coroa da Mônada"→"Coroa Partida" e item →"Diadema da Fonte" (João: confirmar; chefe concorda).

## Arte (Produção GPT)
- Chefes: folhas de quadros por Arconte (idle/andar/preparação/golpe/dano/morte). Refs em C:\gnosis-wt\_gpt\refs\chefes\.
- Criaturas comuns (inhabitants).

## QA-UX (docs/QA_UX_BUGS.md — 24 itens, 21 confirmados)
- **B1 BLOQUEANTE:** controle não confirma/volta (ui_accept/ui_cancel sem botões de gamepad, `game_manager._register_inputs`); trava na escolha da tentação (tela 10) só de controle.
- A1 loja sem foco/Esc (`upgrade_menu.gd`) · A2 legenda (layer 60) por cima de pausa/loja/opções · A3 tela 68: uma barra p/ dois chefes (nome do Colosso, vida do Rei) · A4 Sophia morta congela no ar (`player._physics_process` retorna antes de move_and_slide) · A5 câmera tira a Sophia da tela (look-ahead somado após limites) · A6 escolha final estoura a borda direita · A7 campanha sem dica de controles · M1 legenda cobre pés/telegrafos · M2 toast colado no nome do Anel · M3 itens indisponíveis da loja parecem selecionados · M5 emendas de 1 px no chão/fundo.
- Obs.: a UI nova (dir/ui) pode já ter resolvido parte (A1 loja com foco, Esc/B). Testar de novo na integração.

## Arte GPT
- Chefes: só Athoth pronto (`artes/gpt/boss_1_athoth_a.png`, 3/4 de perfil, névoa roxa colada no magenta). Faltam 8 + criaturas. Chats: Sophia https://chatgpt.com/c/6ad2fe7b-b2dc-83e9-8d58-209255b8f4af · Athoth https://chatgpt.com/c/6ad306c4-77ac-83e9-8a1e-bd5c7f47dfa5 (um chat novo por chefe, anexando a ref de `C:\gnosis-wt\_gpt\refs\chefes\`).
