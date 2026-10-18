# ONDA 6 — o jogo precisa ficar BOM DE JOGAR (playtest do João, 17/10/2026)

## O que o João sentiu jogando a prévia (palavras dele, resumidas — é a prioridade nº 1)
1. "Tá bem melhor, mas bem longe da versão final."
2. **Movimentação não está lisa, meio travada** — mas é MUITO responsiva; **ataques frenéticos demais**.
3. **Fácil demais.** **Chefes morrem com 5–6 porradas.** Bichos fracos e fáceis.
4. **Sempre a mesma coisa / linear**: vai pra frente e bate nos bichinhos.
5. **Sem variedade de inimigos**: basicamente ataque básico corpo a corpo; **não tem bicho que voa**, não tem bicho diferente.
6. **Mini-chefes iguais ao chefe** (ex.: o 2º chefe tem "mini-chefes" com a mesma cara) — não diferencia.
7. **Dano da Sophia forte demais.** **Combo "pular + triângulo" (aéreo forte) roubado**, sem cooldown.
8. **Antes do 2º chefe já tinha upgrades no nível máximo** (pausa → Melhorias). Economia generosa demais.
9. **Boss fights iguais, sem graça.**
10. **História corrida**: passa por cima do jogo enquanto a ação rola, e **nada é ensinado de fato** (nem mecânica, nem a gnose). Dublagem futura pode ajudar, mas quer medidas JÁ.
11. **Quer PULO DUPLO**, liberado pelo **"Jesus" do jogo = SOTER** (o Salvador; não renomear), numa cena.
12. **Foco: o jogo está muito LINEAR → desenvolvimento de MAPA.**

## Princípios (valem para todos)
- Feito para ser GOSTOSO e JUSTO, sem truques de cassino (ver docs/handoff/NEURO_SATISFACAO.md). Dificuldade vem de leitura,
  padrões e escolhas — não de números inflados sozinhos.
- Referências: God of War (peso, chefes com fases e padrões), Hollow Knight/Ender Lilies (mapa com caminhos, segredos,
  verticalidade, chefes memoráveis), Hades (variedade e ritmo), Grand Chase (beat-em-up 2.5D).
- Silêncio (`--audio-driver Dummy`); janelas no CANTO do monitor (`--position 1200,600`) — o João gosta de ver.
- i18n está LIGADO: todo texto novo passa por `tools/i18n` (extract → traduzir → build --strict → LangQA/EnFit).
- Validação: `tools/validate.ps1 -Path <wt>` VERDE; capturas/GIFs antes/depois; commit cedo e sempre; push do seu branch;
  NUNCA merge em integracao (o chefe integra). Limite de uso existe: commite a cada passo.

## Donos de arquivo nesta onda (NÃO edite arquivo de outro; pedidos em docs/pedidos/onda6_<cargo>.md)
| Cargo | Branch | Arquivos |
|---|---|---|
| combate6 (Sophia: feel, dano, aéreo, pulo duplo) | dir6/combate6 | player.gd, juice.gd, camera_shake.gd, scripts/combat/**, scripts/components/**, scenes/entities/Player.tscn |
| inimigos6 (variedade, voadores, campeões) | dir6/inimigos6 | enemy.gd (EXCETO funções de kit de chefe `_kit_*`, `_boss_*`, `_enter_phase*`), bestiary.gd, projectile.gd, hazard_zone.gd, scripts/entities/enemies/** (novo) |
| chefes6 (lutas de chefe de verdade) | dir6/chefes6 | scripts/entities/bosses/** (novo), funções de kit de chefe em enemy.gd (`_kit_*`, `_boss_*`, `_enter_phase*`), final_battle.gd |
| progressao6 (economia, upgrades, travas) | dir6/progressao6 | progression_manager.gd, game_content.gd, upgrade_menu.gd (lógica e preços), spark_orb.gd (taxas) |
| mapa6 (estrutura macro não-linear) | dir6/mapa6 | run_manager.gd, scripts/levels/map/** (novo), scenes/ui/WorldMap.tscn + scripts/ui/world_map.gd (novos) |
| level6 (layout de cada tela, verticalidade, perigos, segredos) | dir6/level6 | level.gd (funções de layout: plataformas, paredes, zonas, spawn), scripts/levels/layouts/** (novo), scripts/entities/{chest,seal_puzzle,exit_portal}.gd |
| narrativa6 (ritmo da história, ensino, Soter → pulo duplo) | dir6/narrativa6 | narrative.gd, gnosis.gd, staging.gd, npc_encounter.gd, sleeper.gd, cinematic.gd, caption_bar.gd, level.gd (SÓ `_play_narrative_beats` e ganchos de fala) |
| arte (GPT + integrador) | dir2/arte-gpt | character_art.gd, painted_library.gd, boss_puppet.gd, assets/painted/**, artes/gpt/** |
| ui5 / cenario5 / estab5 (continuam da onda 5) | dir5/* | scripts/ui/** (exceto caption_bar, world_map, upgrade_menu-lógica) / scenery* / tools de QA |

Contratos entre áreas (combinem por docs/pedidos): Progression expõe `has_double_jump()`/`grant_double_jump()`; o pulo duplo é
mecânica do combate6 e cena da narrativa6 (Soter concede); level6 usa o pulo duplo para caminhos/segredos opcionais (nunca
obrigatório antes do Soter); mapa6 define QUE telas existem e em que ordem/ramos, level6 define COMO cada tela é; inimigos6
cria tipos que level6 posiciona (voadores precisam de espaço vertical).
