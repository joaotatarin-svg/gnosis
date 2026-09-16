# GUIA_IA — leia isto ANTES de qualquer coisa em cada sessão

> **ANTES DE TUDO (leia primeiro):** arquivos citados com "@" (ex.: `@GUIA_IA.md`,
> `@docs`) **já estão no seu contexto** — o Continue injeta o conteúdo
> automaticamente. **NÃO** especule sobre caminhos, **NÃO** ache que "não existem",
> **NÃO** fique se perguntando onde estão: use o conteúdo que já recebeu. Pense
> pouco, seja direto, aja. Se precisar de um arquivo que ainda não recebeu, apenas
> **peça o nome dele** — não invente caminhos nem entre em loop de dúvida.

> Fonte única de verdade do projeto **GNOSIS**. É um **mapa** (aponta onde as
> coisas estão), não uma cópia do código. Mantenha-o curto e atualizado.
> Se algo aqui divergir do código, o **código** manda — corrija este guia.
> Versão completa: `BIBLIA.md`. Plano: topo de `ROADMAP.md`.

## 1. O que é o jogo (1 parágrafo)

Beat-em-up 2.5D de rolagem lateral (estilo Grand Chase) com combate de ação
(estilo God of War 2018/Ragnarok) e progressão por essência. Tema: cosmologia
gnóstica de fantasia (Demiurgo, Arcontes, Pleroma). Feito em **Godot 4.7.1**,
**GDScript**, com **arte procedural/vetorial em código** como base (PNG só pro
Demiurgo; áudio futuro). Protagonista única: **Sophia**. É o **Jogo 1** de uma
tetralogia planejada.

## 2. Como rodar / validar (SEM abrir a UI)

- Rodar: `godot --path .` (abre a janela do jogo).
- **Validar sintaxe/compilação (use SEMPRE após editar):**
  `godot --headless --path . --editor --quit`  → não pode aparecer `SCRIPT ERROR`.
- Rodar uma cena X frames headless: `godot --headless --path . res://<cena>.tscn --quit-after 150`
- **Ver o jogo (captura PNG):**
  `godot --path . --resolution 1280x720 --position 4000,4000 res://tools/Shot.tscn -- <tela|res://cena.tscn> <saida.png> [frames] [hurt]`
  (janela fora do monitor; pula diálogos; `hurt` força a fase 2 dos chefes).
  Vitrine do roster: `res://tools/Showcase.tscn`.
- Cena inicial: `scenes/ui/MainMenu.tscn`. Fase: `scenes/levels/Level01.tscn`.
- Há **git**: commite ao fechar cada passo validado.

## 3. Estrutura de pastas

```
scripts/autoload/   sistemas globais (o CORAÇÃO — ver §4)
scripts/data/       "moldes" Resource (art_profile, character_data, combo_data, skill_data, enemy_data)
scripts/fx/         arte e efeitos (character_art = motor de desenho; projectile, aoe_nova, impact_burst, damage_number, spark_orb, camera_shake, hazard_zone)
scripts/combat/     hitbox, hurtbox
scripts/components/ health_component
scripts/entities/   player, enemy, chest, sleeper, seal_puzzle, npc_encounter, exit_portal
scripts/levels/     level (a "arena" dirigida pelo RunManager)
scripts/ui/         menus, hud, dialogue_box, upgrade_menu, gallery, end_screen, options_menu
scenes/             as cenas .tscn (espelham as pastas)
tools/              ferramentas da IA (shot, showcase, cut_art) — NÃO fazem parte do jogo
docs/               GDD.md, LORE.md, BUILD.md, AUDIO.md, PIPELINE_ARTE.md
```

## 4. Autoloads (globais, sempre ligados) — o coração

| Nome | Arquivo | O que faz |
|------|---------|-----------|
| `GameManager` | game_manager.gd | estado, dificuldade, **input (teclado+gamepad)**, tela atual, patches |
| `GameContent` | game_content.gd | roster: Sophia + combos + magias |
| `Bestiary` | bestiary.gd | 15 tipos de wave + 7 Arcontes + Demiurgo + Soter/Velkar; `player_profile()`; `screen_multiplier()` |
| `Progression` | progression_manager.gd | faíscas (orbs), nível de arma, magias, itens, Adormecidos |
| `Audio` | audio_manager.gd | toca SFX/música de `assets/audio/` (silencioso se faltar) |
| `SaveManager` | save_manager.gd | save META em `user://save.json` (best_screen, finais, volumes) |
| `SceneManager` | scene_manager.gd | troca de cena com fade + overlays |
| `Juice` | juice.gd | hitstop + screen shake |
| `RunManager` | run_manager.gd | estrutura do run: telas 1..50, waves, chefe a cada 7 (Éons), HP entre telas |
| `Narrative` | narrative.gd | TODO o texto: a Voz, intros de Éon, tentações, finais |
| `FpsOverlay` | fps_overlay.gd | contador de FPS (F3) |

## 5. Sistemas principais (onde mexer)

- **Combate/herói:** `scripts/entities/player.gd` (máquina de estados: IDLE/RUN/
  JUMP/ATTACK/DODGE/BLOCK/HURT/DEAD). Combo = sequência de botões (leve/forte)
  casada contra `GameContent`. Golpe tem wind-up + recuperação (`ComboData.
  windup_time()/recovery_time()`; `is_heavy()` = termina em "heavy"). Status
  impostos por chefes: `root_timer` (preso; esquiva quebra), `status_slow`
  (névoa), `silenced_timer` (magias caladas).
- **Inimigos:** `scripts/entities/enemy.gd`. Do bestiário: `style` (melee/ranged/
  charge/slam), `behavior` de wave (shield/teleport/exploder/summoner) e `kit`
  de chefe (torpor/fome/corrente/silencio/espelho/praga/coroa). Chefes têm 2
  fases (`_enter_phase2` a 50%), armadura no wind-up, invocam (`minion_spawned`).
  Telegrafo amarelo=aparável, vermelho=imparável.
- **Arte procedural:** `scripts/fx/character_art.gd` desenha qualquer criatura a
  partir de um `ArtProfile` (corpo + cores + features: horns/cape/wings/helmet/
  bracers/blade/staff/aura/shield/... + assinaturas dos Arcontes: eyelid/maw/
  chains/sewn/mirror/rot/bigcrown). Anima por `set_anim(estado)`.
- **Zonas de chão:** `scripts/fx/hazard_zone.gd` ("sleep" lentifica, "poison" fere).
- **Combate/hit:** `scripts/combat/hitbox.gd` + `hurtbox.gd` (times "player"/
  "enemy"; `unblockable`; o atacante vai junto no sinal).
- **Fase/run:** `scripts/levels/level.gd` monta waves e conteúdo por tela
  (determinístico: `screen % N`). Chefe, morte, vitória, diálogos, portal.
- **UI:** `hud.gd` (barras + barra de chefe via grupo "hud"), `dialogue_box.gd`
  (falas + escolhas), `upgrade_menu.gd` (Santuário/loja).

## 6. Convenções de código (SIGA)

- **GDScript, indentação com TAB** (não espaços). Comentários **em português**.
- **Arte por código**: `_draw()`/`Polygon2D`. PNG só nos hooks já existentes.
- Tipagem: use tipos (`var x: int`). Se um valor vem de função sem tipo (ex.:
  `load()`), use `var x =` (sem `:=`) pra não quebrar inferência.
- `class_name` para coisas reutilizáveis. Sinais para comunicação entre nós.
- Balanceamento **determinístico por tela** (mesma tela = mesmos stats).
- Não introduza dependências externas nem assets. Mantém exportável (`res://`).

## 7. Estado atual (atualize quando mudar)

FEITO: menu, run completo (50 telas/7 Éons/chefes/morte/3 finais/vitória), combate
(combos leve+forte c/ wind-up e cooldown, esquiva, parry, elites), arte procedural
ANIMADA, VFX das magias, **7 Arcontes com assinatura visual + mecânica própria +
2 fases**, 4 bots especiais, IA de grupo, HUD colorido + barra de chefe, cenário
por Éon (+ hook de PNG em `assets/backgrounds/`), plataformas one-way, FPS
counter, conteúdo (baús/Adormecidos/puzzle), narrativa completa, save, opções,
config de build+instalador, git.
FALTA (ordem no `ROADMAP.md` F1→F6): motor de arte do herói/waves subir de nível ·
combos por nível de arma (hoje todos nível 1) + launcher/juggle · arco canônico
(7 Anéis, o Rei, roubo, Centro, batalha dupla) · balance (bot + playtest) · áudio
(ÚLTIMO — `assets/audio/`, `docs/AUDIO.md`) · build (export templates).

## 7b. DIREÇÃO DE ARTE (decidida em 2026-09-09)
**Procedural é a base** (herói, waves, Arcontes). PNG ilustrado só pro Rei/
Demiurgo (hook `assets/characters/<id>.png`), a receber shader pra casar com o
vetor. O PNG de manto da Sophia foi aposentado (colidia com o mundo vetorial).
Não usar PNG em outro personagem sem decisão explícita do usuário. Ver `BIBLIA.md §10`.

## 8. Regras de trabalho pra você (IA local) — evitar perda de contexto

1. **Início de cada sessão: leia este GUIA_IA.md inteiro primeiro.** Depois, só
   abra os arquivos relevantes à tarefa (não tente carregar o projeto todo — seu
   contexto é pequeno).
2. **Passos pequenos e verificáveis.** Após cada mudança, rode
   `godot --headless --path . --editor --quit` e confirme **zero SCRIPT ERROR**.
3. **Não alucine.** Se não tem certeza de uma função/nome, **abra o arquivo** e
   confira antes de usar.
4. **Ao terminar algo relevante, ATUALIZE este guia** (§7 e onde precisar) e a
   `BIBLIA.md §6`. Eles são a memória entre sessões.
5. Não invente assets nem libs. Não quebre as convenções do §6.
6. Referências profundas de história ficam em `docs/LORE.md`; design em
   `docs/GDD.md`. Não duplique — aponte.

## 9. Glossário rápido do lore

- **Kenoma**: o mundo material (a prisão). **Pleroma**: a plenitude divina (o alvo).
- **Mônada**: a Fonte/luz primordial. **Sophia**: aeon caída (a protagonista é um caco dela).
- **Demiurgo (Yaldabaoth)**: falso criador cego (chefe final). **Arcontes**: seus
  carcereiros (Athoth, Harmas, Galila, Yabel, Astaphaios, Belias, Armupiel).
- **Faísca**: luz presa na matéria = moeda/XP. **Éon**: um ato/capítulo (são 7).
- **Anéis**: 1 por Arconte = habilidade nova (mecânica a construir; ver LORE ★).
- **Soter**: aliado messiânico que não luta (abençoa). **Velkar**: Arconte arrependido.
- **Saga**: 4 jogos; os 3 primeiros ISOLADOS (sem se mencionar), o 4º conecta tudo.
