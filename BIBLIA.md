# BÍBLIA DO PROJETO — GNOSIS (handoff pra qualquer chat)

> Se você é uma IA assumindo este projeto num chat novo: **leia isto primeiro.**
> É o mapa mestre. Detalhes profundos ficam nos docs apontados. O código sempre
> manda; se algo aqui divergir, corrija este arquivo.

> **CÓPIA CODEX — 17/09/2026.** Trabalhar somente nesta pasta `Gnosis-Codex - Copia`.
> João autorizou novas ilustrações, recursos e shaders nesta sessão. Nesta cópia,
> a arte ativa está em assets/painted e PaintedLibrary; instruções históricas
> limitando PNG ao Rei ou mandando restaurar o antigo rig não se aplicam à
> apresentação atual. Sophia continua sendo a única protagonista.
> Guia atual: docs/CODEX_ENTREGA.md; auditoria: docs/AUDITORIA_VISUAL_CODEX.md.
> O original em Desktop/Gnosis deve permanecer intocado.

## 0. Contexto do trabalho

- **Projeto:** `C:\Users\jmtat\OneDrive\Desktop\Gnosis-Codex - Copia` (cópia
  isolada; pasta renomeada em 17/09/2026 — o Claude trabalha aqui).
  **Repositório git local** independente desde 2026-09-16 (branch `codex/despertar`). Commite ao fechar
  cada passo validado; o OneDrive NÃO é controle de versão.
- **Usuário:** orquestra e decide; NÃO é programador nem designer. Fala português.
  Espera que a IA lidere as sugestões técnicas/criativas e faça o trabalho braçal.
  Quer que a IA seja opinativa e honesta (sem hype falso).
- **Godot (validar/rodar) — caminho nesta máquina:**
  `C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`
  - Validar (SEMPRE após editar): `& $godot --headless --path "<proj>" --editor --quit` → não pode ter `SCRIPT ERROR`.
  - Rodar uma cena: `& $godot --headless --path "<proj>" "res://<cena>.tscn" --quit-after 150`
  - Abrir o jogo pro usuário ver: use o `win64.exe` (sem console) via `Start-Process`, run_in_background. O usuário tem atalho `Jogar GNOSIS` no Desktop.
  - **A IA CONSEGUE VER O JOGO** (desde 2026-09-09): `tools/shot.gd` abre uma
    tela em janela real (fora da área visível), pula diálogos e salva um PNG.
    `& $godot --path . --resolution 1280x720 --position 4000,4000 "res://tools/Shot.tscn" -- <tela|res://cena.tscn> "<saida.png>" [frames] [hurt]`
    `hurt` = na metade dos frames tira 55% da vida dos chefes (força a FASE 2).
    Vitrine do roster inteiro: `res://tools/Showcase.tscn`. Use SEMPRE após mexer
    em visual, e leia o PNG. Feel/timing ainda dependem do usuário jogar.
  - Se um Godot ficar pendurado: matar só processos `Godot*` iniciados nos
    últimos minutos (o usuário pode ter o editor aberto).

## 1. O que é o jogo

Beat-em-up 2.5D de rolagem lateral (Grand Chase) + combate de ação (God of War
2018/Ragnarok) + progressão por essência. Tema: **cosmologia gnóstica** de
fantasia. Godot 4.7.1 / GDScript. **Arte procedural/vetorial em código** como
base (herói, waves, Arcontes); PNG ilustrado só pro Rei/Demiurgo (ver §10).
Roda leve (renderer gl_compatibility).

## 2. A SAGA (decisão firme do usuário)

Tetralogia. GNOSIS = **Jogo 1**. Os **3 primeiros jogos são ISOLADOS** —
mitologias diferentes e subexploradas, autoconclusivos, **NENHUM menciona o
outro**. Só o **Jogo 4** conecta tudo (os 3 protagonistas se encontram e
descobrem o **Universo Primordial** — a "criação da criação"). Conexão é
arquétipa/invisível, nunca por personagem/objeto recorrente. Jogo 2 candidato:
finlandês (Kalevala). Jogo 3: eslavo. Os 4 jogos = **mesmo motor** (troca dados,
não código). Detalhes: `docs/LORE.md` seção "A SAGA".

## 3. Como rodar / validar
Ver §0. Cena inicial: `scenes/ui/MainMenu.tscn`. Fase: `scenes/levels/Level01.tscn`
(reusada como arena de todas as telas, dirigida pelo RunManager).

## 4. Arquitetura

**Autoloads** (`scripts/autoload/`, o coração):
`GameManager` (estado, input teclado+gamepad, tela atual, patches) ·
`GameContent` (roster: Sophia, combos, magias) ·
`Bestiary` (15 tipos de wave + 7 Arcontes + Demiurgo + Soter/Velkar + Sombra da
Sophia; `player_profile()`, `screen_multiplier()`, `is_boss_id()`) ·
`Progression` (faíscas, arma, magias, itens, Adormecidos) · `Audio` (SFX/música
de `assets/audio/`, silencioso se faltar) · `SaveManager` (save meta) ·
`SceneManager` (troca de cena c/ fade) · `Juice` (hitstop+shake) · `RunManager`
(run: 50 telas, waves, chefe a cada 7 = 7 Éons, HP entre telas) · `Narrative`
(todo o texto) · `FpsOverlay` (F3).

**Pastas:** `scripts/data` (Resources) · `scripts/fx` (`character_art.gd` = motor
de desenho; projectile/aoe_nova/impact_burst/damage_number/spark_orb/camera_shake/
**hazard_zone** = zonas de chão dos chefes) · `scripts/combat` (hitbox/hurtbox) ·
`scripts/components` (health_component) · `scripts/entities` (player/enemy/chest/
sleeper/seal_puzzle/npc_encounter/exit_portal) · `scripts/levels` (level) ·
`scripts/ui` (menus/hud/dialogue_box/upgrade_menu/gallery/end_screen/options_menu)
· `tools/` (ferramentas da IA, fora do jogo: shot, showcase, cut_art, slice).

**Sistemas-chave:**
- Combate herói: `scripts/entities/player.gd` (máquina de estados). Combo =
  sequência de botões leve/forte casada em `GameContent`. Golpe tem wind-up +
  recuperação (`ComboData.windup_time()/recovery_time()`, `is_heavy()`), e um
  cooldown `attack_cd` que compromete o jogador. Contador de combo via
  `register_hit()` → sinal `combo_changed`. **Status impostos por chefes:**
  `root_timer` (Corrente: preso, esquiva quebra), `status_slow` (névoa do
  Torpor), `silenced_timer` (aura do Silêncio cala magias). `apply_root(t)`.
- Inimigos: `scripts/entities/enemy.gd`. Do bestiário: `style` (melee/ranged/
  charge/slam), `behavior` de wave (**shield** = leve bate no escudo, só pesado/
  magia ferem · **teleport** = pisca pro outro lado da Sophia · **exploder** =
  corre e explode, imparável · **summoner** = atira e chama larvas) e `kit` de
  chefe (§6). Telegrafo amarelo=aparável, vermelho=imparável (elite/explosão).
  Chefes: `_enter_phase2()` a 50% (fúria: +25% vel., cooldown -30%) · armadura
  no wind-up (elite e chefe) · `_fit_body()` escala colisões/sombra ao desenho
  (pés no chão) · `minion_spawned` → `level._on_minion` conta na wave · ao
  nascer chama `hud.show_boss(self)` via grupo "hud".
- Arte: `character_art.gd` desenha de um `ArtProfile` (corpo + cores + features).
  Anima por `set_anim("idle/walk/attack/attack_heavy/hurt/dead")`. Features
  gerais: horns/crown/cape/wings/spikes/helmet/pauldrons/bracers/blade/staff/
  claws/tail/aura/hero/shield. **Assinaturas dos Arcontes:** eyelid (Torpor) ·
  maw (Fome) · chains (Corrente) · sewn (Silêncio) · mirror (Espelho) · rot
  (Praga) · bigcrown (Coroa). `set_texture()` troca pelo PNG (só Demiurgo).
- Fase: `level.gd` — waves + conteúdo determinístico por tela (`screen % N`),
  chefe, morte, vitória, diálogos (`_play_narrative_beats`), portal de saída.
  Fundo: `Background.tscn` (parallax) cobre o viewport com zoom-out 0.75.
- HUD: `hud.gd` — barras de vida/Éter com tema próprio; **barra de chefe** na
  base da tela (nome, vida, "FASE II"), via grupo "hud" (`show_boss`, `boss_phase`).

## 5. Convenções (SIGA)
GDScript, **TAB** (não espaço), comentários **em português**. Arte por código
(`_draw()`/`Polygon2D`); PNG só nos hooks existentes. Tipagem explícita; se valor
vem sem tipo (`load()`), use `var x =` (não `:=`). `class_name` p/ reutilizáveis;
sinais entre nós. Balanceamento **determinístico por tela**. Mantém exportável
(`res://`). Sem dependências externas.

## 6. Estado atual (FEITO / FALTA) — atualize sempre
**ONDA 7 — PRÉVIAS 3.1 e 3.2 (28-29/10/2026, integração `integracao/onda1`, detalhe em `docs/handoff/INTEGRADOR.md`):**
- Integração por script: `tools/integrar.ps1 "branch sha" ... [-Repeat N] [-Push]` (merge em lote, i18n regenerado quando só ele
  conflita, reimport 2x, `validate.ps1`, imprime VERDE/VERMELHO). Todos os lotes fecharam com `-Repeat 2` verde.
- **3.1** (vfx7 a63c40b, chefes6 b0b52f0, polimento7 2d54867 sobre encenacao5/chefes6/audio7): chefes recalibrados (BossProbe: nenhuma
  luta estoura 420 s; Armupiel e batalha final deixaram de dar TIMEOUT), VFX/sons novos (tiro hostil = atk_*, proj_fire só da Sophia,
  confirmação de morte), hurtbox pelo desenho, renda de faíscas igual em todas as dificuldades, contra-ataque que mira o aparado.
- **3.2** (arte-gpt de546f8/50f807a/118cb99 com fio de contorno da Sophia, mapa7 4e4b9cc com lugar do Soter numa fonte só
  `RunManager.SOTER_SLOTS`, encenacao5 0561f28/9e1d21a, ui7 12c6643, perigos7 04afd65, progressao6 54141ed com selos 7, cenario7 1b1c69f,
  chefes6 8d00636/61645f7/82454b2/213d292, polimento7 2854fc0/28d8df7): Rei com BodyBox (ReiProbe: atravessa 0, apelão 0, cobre 96 %),
  Raio do Rei virou orbe, Coroa/Praga com padrões novos, Réplica do Juízo só arma com a postura acesa, Campeão com UM stinger
  (`champion_enter`; card sem `boss_appear`), invocador esgotado, fim do jogo pela curva da Progressão.
- BossProbe em 944ec41 (s): Rei 74, Athoth 97, Harmas 83, Galila 123, Yabel 158, Astaphaios 91, Belias 149, Coroa 192 (4 quase-mortes),
  Rei+Colosso 140 (6). Sem TIMEOUT. Coroa e a batalha final são as lutas mais duras; falta playtest humano para dizer se cansam.
- Build interna 3.1: `_build\preview3_1`; 3.2: `_build\preview3_2` (branches `preview/3.1`, `preview/3.2`, sem atalho no Desktop).

**SESSÃO CLAUDE — 18/09/2026 (rumo à 1.1.0 "comercializável"):** João reportou
"tela 3 → chefe → volta ao começo", "curto", "sem história", "não ensina
gnosticismo". Diagnóstico: ele jogou o **Desafio** (demo de 3 encontros, botão
principal do menu), não a Campanha. Feito nesta sessão (prompt-mestre em
`docs/PROMPT_SESSAO_1809.md`), em ondas de agentes integradas na `codex/despertar`:
- **Onda 0:** 3 branches órfãs da sessão anterior integradas — run de **68
  telas** (Éons de 9, travessias com 1–3 zonas de combate; `RunManager.zone_plan`,
  `screen_role`), 64 ganchos de áudio (`audio_manager.gd CATALOG`, música por
  contexto, crossfade), poses procedurais da Sophia (esquiva/dano/bloqueio/queda).
- **UX (versão final):** menu Continuar · Nova campanha · Provação (ex-desafio,
  "treino de 3 encontros") · Ateliê & Bestiário · Crônicas · Opções · Sair;
  `project.godot` nome "GNOSIS" v1.1.0; pausa com Golpes & Controles
  (`scripts/ui/moves_screen.gd`: 14 combos, Anéis, tabela teclado/Xbox/DS),
  Opções (tela cheia, vsync, tremor, vibração, legenda P/M/G → `Juice.shake_mult`,
  `Juice.rumble_enabled`, `GameManager.caption_font_size()`), HUD por papel
  (`GameManager.screen_title`: "Torpor · Travessia II" + 9 pontos do Éon), save
  v2 tolerante, fim de jogo com pintura, Provação avisa que a Campanha tem 68
  telas. `tools/UxShots.tscn`, `tools/SaveQA.tscn`.
- **GNOSE (ensina o gnosticismo):** autoload `Gnosis` preenchido — **18 Estelas**
  (`scripts/entities/stela.gd`; telas 1,3,8,12,…,66; J/X abre painel com
  título, 5–6 linhas e fonte histórica; desbloqueia Crônica; `docs/GNOSE.md`),
  **legendas de caminhada** sem pausar (`scripts/ui/caption_bar.gd`;
  `Narrative.walk_arrival/walk_cleared`, ~95 falas; a Voz com o viés dela, as
  Estelas com a do Pleroma), **cinemáticas** (`scripts/fx/cinematic.gd`:
  prólogo em 6 cards na tela 1, card de chefe com letterbox, epílogo com
  "Crônicas N/18" + créditos), tela **Crônicas** (`scenes/ui/Chronicles.tscn`,
  persiste em `user://chronicles.json`). `tools/GnoseQA.tscn`.
- **Balance r5:** o bot nas 68 telas media 339 quase-mortes (travessias
  triplicaram o dano/tela) → densidade de waves por Éon (2 inimigos nos Éons
  0–1, 3 depois; 1 wave por zona até o Éon 2), cura entre telas 25%, dano
  final +50% (era +59%). Dados em `shots/s1809/`. Nova medição pendente.
- Fixes: portal de saída adiava colisão (erro de física), ferramentas pulam o
  prólogo e não gravam Crônicas.
- **ASSETS (som e VFX de packs, autorizado por João):** 66 SFX + 14 músicas
  preenchidos com packs CC0/CC-BY (Kenney, OpenGameArt, Little Robot Sound
  Factory CC-BY 3.0, Kevin MacLeod CC-BY 4.0) — licenças e atribuição em
  `assets/LICENSES.md`; packs brutos em `assets/_packs/` (fora do git, 730 MB);
  `assets/_packs/build_assets.py` regera tudo. `scripts/fx/vfx_library.gd`
  (`class_name VfxLibrary`, CPUParticles2D + sprites do Particle Pack: hit,
  parry, esquiva perfeita, mortes por porte, chefe em 2 estágios + flash,
  fase 2, cast por cor do Anel, nova, rastro, portal, ambiente por Éon) ligada em
  enemy/player/impact_burst/aoe_nova/projectile/gib/scenery/level. Sons são
  "de pack" ajustados — João pode substituir qualquer um pelo nome do arquivo.
  Loop das músicas não é perfeito na emenda. `tools/VfxShowcase.tscn`.
- **BUILD 1.1.0:** `builds/GNOSIS.exe` + `.pck` (95 MB) exportado por linha de
  comando; instalador `installer/Output/GNOSIS-Setup-1.1.0.exe` (118,7 MB,
  Inno Setup 6.7.3 via `ISCC.exe /DAppVersion=1.1.0`). Exe testado headless.
- **QA:** CodexQA, AudioQA, GnoseQA e SaveQA passam na build integrada.
- **FALTA:** playtest humano (feel, timing das legendas, ritmo das travessias);
  balance r6 medida pelo bot (Éons 3+ ainda quentes na r5: 298 quase-mortes);
  fundos por Éon em resolução cheia; sons com clima gnóstico gerados por João
  (`docs/AUDIO.md` tem os prompts); animação quadro a quadro das criaturas.

**SESSÃO CLAUDE — 17/09/2026 (pasta renomeada pra `Gnosis-Codex - Copia`):**
revisão honesta da entrega Codex com capturas reais: o salto visual é grande e
válido (menu, Sophia, chefes, Rei, fundos, ateliê). Três problemas achados e
dois corrigidos nesta sessão: (1) cenário idêntico em todas as telas (pilar em
x=40 e braseiro em x=290 fixos) → `scenery.gd` agora sorteia pilar/obelisco/
entulho/braseiro por rng determinístico da tela, arena de chefe mais limpa;
(2) criaturas comuns deslizavam estáticas (só chefes têm boneco) →
`character_art._painted_motion()` dá passo com balanço/squash, recuo comprimido
no preparar, avanço esticado no golpe, recuo no dano; espectros flutuam, feras
galopam. Prancha de verificação: `tools/WaveQA.tscn` (salva `shots/waves.png`).
(3) Fundos borrados (9 recortes de 512×341 esticados) — pendente: usuário gera
9 imagens 1536×1024 (uma por Éon + Centro + Mente) e a IA liga no hook
`assets/backgrounds/eon_<i>.png` com parallax dividido. Código morto em
`scenery.gd` (`_build_far/_build_mid/_make_prop/_build_near`, geração vetorial
antiga) ainda não foi removido. Identidade git configurada só neste repo.

**ARTICULAÇÕES DOS CHEFES — 17/09/2026:** João pediu movimento de boneco e
cancelou a troca dos nomes. Nomes e lançadores permanecem como estavam.
BossPuppet usa Skeleton2D/Bone2D: armaduras por recortes rígidos sobrepostos;
espectros, Rei e fera por pele UV. Os sete Arcontes, Colosso e Demiurgo têm
braços/cabeça/tronco articulados, pernas ou tecido/asas, e ciclo próprio da fera.
Enemy fornece progresso do ataque, velocidade e fase; recuperação suaviza a
volta ao repouso. Ateliê tem dez modos, ciclo de combate e mostrar articulações.
QA de nove chefes e integração sem falhas; bot venceu três encontros em 27,8 s,
combo 13, dano real e fase 2. Capturas puppets-0/1/2 e puppet-joints em shots/.
Recortes e junções ainda admitem acabamento artístico; não é animação desenhada
quadro a quadro. Manual da atualização: docs/ANIMACAO_CHEFES.md.

**EDIÇÃO CODEX — 2026-09-17 (somente Gnosis-Codex):** repositório e
user:// independentes. Novo menu, ateliê, catálogo e desafio de três encontros
com seleção entre sete chefes. Seis folhas novas de arte integradas: Sophia
com seis poses; Arcontes/Colosso; criaturas/NPCs; Yaldabaoth/orbe; nove ambientes;
arquitetura/objetos. PaintedLibrary centraliza atlas/pivôs e transparência.
CharacterArt continua recebendo os estados reais do combate. Colisões, dano,
progressão e campanha herdados foram preservados. Revisão de câmera, chão,
plataformas, paralaxe, névoa, primeiro plano, VFX, desmembramento e interfaces.
QA passou com zero falhas. Bot venceu três encontros por inputs (26,3 s, combo
12, dano real e fase 2). Capturas da campanha, menus e chefes em shots/.
Áudio, build independente, playtest humano integral e animações mais extensas
seguem pendentes. docs/CODEX_ENTREGA.md detalha alterações e limitações.
As decisões históricas abaixo servem de contexto; esta entrada descreve a cópia.

**Diagnóstico honesto (2026-09-09):** protótipo completo em largura; a
profundidade está sendo construída fase a fase (plano F0–F6 no topo de
`ROADMAP.md`). Duração real de uma run ≈ 1–1,5 h; meta realista da versão final
= 2–3 h com o arco dos Anéis completo.

**FEITO (base):** run completo (50 telas / 7 Éons / chefes / morte / 3 finais /
vitória); combate GoW (leve+forte c/ wind-up e cooldown, combos, esquiva i-frames,
parry, elites); arte procedural ANIMADA (bípedes articulados); VFX das magias;
conteúdo (baús/Adormecidos/puzzle dos Selos); narrativa completa (Voz, tentações
dos 7 Arcontes, Soter, Velkar, pré-Demiurgo, 3 finais); save meta; opções
(volumes); menu cinematográfico; config de build+instalador+patches; cenário por
Éon (`level._build_eon_scenery`, hook PNG `assets/backgrounds/eon_<i>.png`);
plataformas one-way; FPS counter (F3); magias trancadas (adquire vencendo chefes);
transição por portal; câmera com zoom out.

**PERSONAGEM ÚNICA = Sophia**, procedural (decisão do usuário): removidos os 3
jogáveis antigos (Thalos/Lyra/Sophos); só `sophia` em `game_content.gd`; sem
seleção no PreGame; NÃO re-adicionar. O PNG de manto (`assets/characters/sophia/`)
foi **aposentado** em 2026-09-09 (colidia com o mundo vetorial; escondia as pernas)
— o arquivo fica na pasta mas o código não o carrega mais.

**Arte ilustrada — só o Demiurgo:** `enemy._apply_illustrated_art()` usa
`assets/characters/<id>.png` (+ `<id>_orb.png` = orbe-olho com tell) se existir.
`demiurgo.png` + `demiurgo_orb.png` feitos pelo usuário (O Rei / Fase 1), recortados
de `artes/arconte final.png` via `tools/cut_art.gd`. Falta: shader de posterização/
contorno pra casar com o vetor (F1) e o usuário ajustar `disp`/`ORB_HOME`.

**FEITO 2026-09-09 (F0/F1/F2 parciais):** git iniciado · **faixa cinza corrigida**
(`Background.tscn` e chão cobrem o viewport com zoom) · HUD com barras coloridas +
**barra de chefe** · **7 Arcontes com identidade** (assinatura visual + `kit`):
- Athoth/Torpor (wraith, pálpebra): salva de 3 + **névoa do sono** no chão (lentidão).
- Harmas/Fome (colosso, boca no torso): slam + **sucção** durante o wind-up.
- Galila/Corrente (bruto, correntes): investida + **corrente que prende** (esquiva quebra).
- Yabel/Silêncio (wraith alado, boca costurada): **aura cala magias**; fase 2 **pisca pra trás**.
- Astaphaios/Espelho (humanoide prateado, cacos): lunge; fase 2 **invoca a Sombra da Sophia**.
- Belias/Praga (besta, gavinhas): investida deixa **poças de veneno**.
- Armupiel/Coroa (colosso, coroa alta): slam; fase 2 **chama servos e fica blindado** (+ onda rasteira).
**2 fases** em todos (fúria a 50%) · **4 bots novos** (Larva Ardente tier 1,
Escudeiro do Selo tier 2, Fantasma do Vazio e Invocador de Larvas tier 3) ·
IA de grupo (`_separation`) · waves ~15% maiores · `hazard_zone.gd` ·
`tools/shot.gd` (a IA vê) · `tools/Showcase.tscn` (vitrine).

**FEITO 2026-09-11 (C+D — ARCO CANÔNICO COMPLETO, jogável de ponta a ponta):**
- **Run de 54 telas:** O Rei (tela 1, chefe-tutorial com o PNG do Demiurgo; a Voz
  o apresenta como amigo, o "rito" é o duelo; ao cair, o selo racha) · 7 Éons
  (2–50; Arconte em 8,15,22,29,36,43,50) · **roubo** na 50 (o Rei reaparece
  inteiro, arranca os 7 Anéis, a Voz se revela Yaldabaoth, ele vira um motor de
  anéis e afunda pro Centro) · **Centro** 51–53 (Sophia SEM magias e sem a Voz;
  ecos translúcidos dos Arcontes; cada eco quebrado devolve 1 caco = o poder de
  1 Anel; só 6 voltam — o 7º volta na 1ª queda da batalha final) · **batalha
  dupla** na 54 (`scripts/levels/final_battle.gd`: Rei enfraquecido + Colosso
  Oco; quem cai se refaz em 14 s se o outro não cair junto; os 7 Anéis giram no
  céu spawnando larvas; caíram juntos → reclamar → 3 finais).
- **7 Anéis = 7 magias** (`game_content.gd`, `SkillData.ring`): Névoa do Sono
  (lentidão em área), Boca Voraz (suga+morde), Corrente da Lei (prende),
  Grito Mudo (atordoa), Reflexo (5 s devolvendo golpes), Flor Podre (veneno no
  chão), Coroa da Mônada (nova enorme) + Esfera Solar inata (O/Y). Anel equipado
  em U/X; seleção 1–7, Q/E, L2. `Progression.rings/rings_stolen/restored_rings`.
- **HUD dos Anéis** (◆ coloridos; ❖ = equipado; cinza = roubado) + `toast()`.
- **7 bots de Éon** (`Bestiary.EON_BOTS`, entram nas waves do seu Éon): Sonâmbulo
  (tiro que lenta), Glutão (cura ao morder), Carcereiro (corrente que prende),
  Bibliotecário Mudo (aura cala magias), Reflexo (recua quando você golpeia),
  Portador de Esporos (poça ao morrer), Pretoriano (broquel: leve pela frente
  = metade do dano).
- `tools/shot.gd` ganhou modo `clear` (mata tudo a cada terço dos frames — testa
  fluxo completo de tela/chefe/loja). Loja só mostra magias já adquiridas.

**FEITO 2026-09-11 (tarde — E parcial + F1 restos):** `tools/balance_bot.gd`
(BOT DE BALANCE: joga o run sozinho headless, mede tempo/dano/quase-mortes por
tela, tabela `BAL` + `user://balance.txt`; `Juice.speed_mult` acelera) ·
**BALANCE r1 aplicado com dados** (o bot morreu na tela 17 com 19 quase-mortes:
não havia NENHUMA cura no run → agora Anel = cura cheia, início de tela recompõe
30% do perdido, loja vende Restauração 50 faíscas; Sophia 90→120 HP; dano de
waves/Arcontes -15~20%; salva de chefe 65%/projétil; Rei-tutorial 12→8) ·
**anti-softlock** (inimigo fora da arena volta pro centro) · **Codex reescrito**
(rolagem, sem sobreposição, roster completo) · **shader posterização+tinta**
(`assets/shaders/posterize_ink.gdshader`) nos PNGs do Rei/Demiurgo · Showcase
atualizado · `shot.gd` modo `clear` · docs em dia (GDD/LORE/AUDIO/README).

**FEITO 2026-09-11 (noite):** balance FECHADO em 3 rodadas medidas
(`docs/BALANCE.md`: r3 = bot vence o run, dano -43%, timeouts 18→3) · fixes
críticos achados pelo bot: **paredes da arena** (dava pra cair pra fora do
mundo em x~1900) + resgate do vazio · **tinta do rig em 2 passes** (barras
pretas na Sophia do menu) · **controles**: SDL_GameControllerDB (869
mapeamentos Windows: Xbox/DualShock/DualSense/genéricos, carregado no boot),
layout ergonômico novo (ataques no polegar X/Y; A pulo; B esquiva; L1 parry;
R1 Anel; R2 Esfera; L2 troca Anel; deadzone 0.25) + rumble discreto
(dano/parry/esquiva perfeita/chefe caindo).

**FEITO 2026-09-11 (noite 2 — CHECKPOINTS + CONTINUAR):** a morte não encerra
mais o run: **renasce no início do trecho atual** (Limiar→1 · Éon→2,9,…,44 ·
Centro→51 · Mente→54) com a progressão intacta e **20% das faíscas escorrendo**
como custo. **Com apelo narrativo** (`Narrative.death_revive`): antes do roubo
é a VOZ que recompõe a Sophia — solícita mas possessiva/urgente (foreshadow: o
carcereiro precisa da chave viva; linhas variam a cada queda); no Centro são os
cacos dela mesma; na Mente os Anéis a refazem CONTRA o Yaldabaoth ("Eles lembram
de mim"). Diálogos de tela tocam 1x por run (`Narrative.once`; morrer não repete
intro/tentação). **Run salvo em disco** (`SaveManager` grava snapshot no avanço
e na morte): menu ganha **"Continuar — <Éon> (Tela N)"**; vitória limpa o save;
ferramentas de dev não sujam o save (`SaveManager.persist_enabled=false`).
`shot.gd` ganhou modo `die` (testa a morte→checkpoint; validado com captura).

**FALTA:** **playtest de feel do usuário** (parry/Anéis/timing — só então mexer
de novo em número) · **áudio (ÚLTIMO**, usuário gera, `docs/AUDIO.md`) · build
(export templates ~600 MB, precisa de OK do usuário).

## 7. Decisões importantes (não reverter sem falar com o usuário)
- Título **GNOSIS**; "Kenoma" = nome do MUNDO no lore.
- Godot (não web); 2D vetorial (não pixel art, não low-poly 3D).
- **Direção de arte (2026-09-09): procedural é a base** (herói, waves, Arcontes).
  PNG ilustrado só pro Rei/Demiurgo (o "de fora"), a receber shader. Rig ilustrado
  da Sophia aposentado.
- Herói evolui de aparência com a arma (gear). Capa saiu do herói (usuário não
  gostou) → **bracelete**; capa só no Demiurgo.
- Combate estilo GoW com parry/esquiva; elites imparáveis (vermelho). Chefes têm
  armadura no telegrafo e 2 fases.
- Finais: recomendação = manter os 3 (Ascensão/Ruptura/Semente) como epílogo
  pós-"reclamar" (usuário ainda confirma).
- Áudio deixado por último de propósito.
- Personagem messiânico **Soter** (não luta, abençoa) + Arconte arrependido **Velkar**.

## 8. Docs do projeto
`docs/GDD.md` (design) · `docs/LORE.md` (história/saga, densa) · `docs/BUILD.md`
(export+instalador+patches) · `docs/AUDIO.md` (lista de SFX c/ prompts) ·
`docs/PIPELINE_ARTE.md` (histórico da rota ilustrada) · `ROADMAP.md` (plano F0–F6
+ histórico) · `GUIA_IA.md` (versão enxuta pra IA local 14B) · `CLAUDE.md`/
`AGENTS.md` (mapa curto lido automaticamente).

## 9. Como trabalhar (ritual)
1. Leia esta BÍBLIA + `ROADMAP.md`.
2. Trabalhe em passos pequenos; **valide headless após cada mudança** (§0).
3. **Capture tela** (`tools/shot.gd`) após qualquer mudança visual e olhe o PNG.
4. Ao terminar algo, **atualize §6 aqui e o `ROADMAP.md`** e faça **commit**.
5. Feel/timing/balance: peça o usuário jogar e reportar.
6. Áudio é a ÚLTIMA etapa.

## 10. DIREÇÃO DE ARTE — REVERTIDA PELO USUÁRIO (2026-09-09, tarde)

> ⚠️ **O texto abaixo (§10 antigo) foi SUPERADO.** O usuário viu o procedural v2
> e disse, textualmente, que quer a Sophia e o Demiurgo **o mais próximos possível
> dos PNGs ilustrados** — o procedural "ridículo" ao lado deles. Decisão que vale:
> - **ILUSTRADO é a base pros personagens principais** (Sophia, Rei/Demiurgo, e
>   idealmente os 7 Arcontes quando houver créditos de geração).
> - **Sophia = rig cutout em PNG** (`assets/characters/sophia/rig.json` + 4 partes:
>   cabeça/corpo/saia/cajado), animado por código em `CharacterArt._draw_rig()`:
>   corpo inclina, cabeça respira, saia balança, **cajado gira na mão** conforme a
>   pose (`_wpn`), orbe de luz na ponta, contorno de tinta (4 cópias escuras) pra
>   casar com o vetor. Sem pernas mesmo (manto longo — ela desliza). Altura
>   `Player.RIG_HEIGHT` = 68 px. Ligado em `player._refresh_look()`.
> - **Demiurgo = PNG** (`enemy._apply_illustrated_art`, já era). O gear da arma
>   evolui só a LUZ (orbe/aura), não a roupa.
> - **O mundo sobe até eles, não o contrário:** cenário v2 (`scenery.gd`) com
>   6 camadas, astro por Éon, névoa, vinheta; próximo passo é fundo/Arcontes
>   ilustrados via Kairogen quando o usuário recarregar créditos (hoje: 0).
> - Procedural (`character_art.gd` v2) continua sendo o motor das waves/NPCs e
>   o fallback de tudo. O desmembramento (gib) só vale pra procedural.
> - Regra: **NUNCA mais rebaixar um personagem ilustrado pra procedural** sem o
>   usuário pedir.

### §10 antigo (histórico — não vale mais)

Contexto: o usuário mostrou uma referência ilustrada (anatomia, roupa, sombras)
e quis esse nível pros principais. Verdade técnica: **isso não é atingível em
código procedural**; exigiria assets por parte do corpo, rig e animação às cegas,
mais créditos de geração de imagem. Foi testado: o PNG de manto da Sophia entrou
no jogo e **colidiu com o mundo vetorial** (fotorrealista ao lado de vetor) além
de esconder as pernas. Capturas de tela provaram o problema.

**Decisão (recomendação da IA, adotada com o "mete marcha" do usuário):**
- **Procedural é a base** de tudo que luta: herói, waves, Arcontes. O motor
  `character_art.gd` é o que sobe de nível (F1): proporções, rosto/cabelo, poses,
  assinaturas por personagem (já feitas pros 7 Arcontes).
- **PNG só pro Rei/Demiurgo** (o ser "de fora" pode ter outra textura), com
  shader de posterização + contorno pra casar com o vetor (a fazer).
- O hook `assets/characters/<id>.png` continua existindo pros chefes, mas a
  regra é NÃO usar PNG sem decisão explícita do usuário.
- Histórico e pipeline da rota ilustrada (Kairogen, rembg, godot-mcp, rig cutout)
  ficam em `docs/PIPELINE_ARTE.md` como referência, não como plano.
