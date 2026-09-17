# CLAUDE.md — GNOSIS (lido automaticamente pelo Claude Code em toda sessão)

> **ESTA PASTA É A EDIÇÃO CODEX (desde 17/09/2026):** `Desktop\Gnosis-Codex - Copia`.
> É a cópia onde o GPT (Codex/Astra) integrou **arte ilustrada** (PNG em
> `assets/painted/`, catálogo em `scripts/fx/painted_library.gd`, chefes com
> boneco articulado em `scripts/fx/boss_puppet.gd`). O motor procedural de
> `character_art.gd` virou **fallback**. Instruções antigas do tipo "PNG só pro
> Rei" ou "restaurar o rig" NÃO valem aqui. Guia: `docs/CODEX_ENTREGA.md`.
> O original em `Desktop\Gnosis` fica intocado.

Jogo **GNOSIS**: beat-em-up 2.5D (Grand Chase) + ação estilo God of War, tema
gnóstico. **Godot 4.7.1 / GDScript.** Arte ilustrada (PNG gerado por IA) sobre
base procedural; áudio futuro. É o Jogo 1 de uma tetralogia.

> Este arquivo é só o **mapa**. O handoff COMPLETO está em **`BIBLIA.md`** —
> leia-o no início de cada sessão. Plano mestre (F0–F6) no topo de `ROADMAP.md`.
> História em `docs/LORE.md`, design em `docs/GDD.md`.

## Como rodar / validar (SEMPRE após editar código)
Godot (esta máquina):
`C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`
- Validar: `& $godot --headless --path . --editor --quit` → **não pode ter `SCRIPT ERROR`**.
- Rodar cena headless: `& $godot --headless --path . "res://<cena>.tscn" --quit-after 150`
- **VER o jogo (a IA enxerga!):** `& $godot --path . --resolution 1280x720 --position 4000,4000 "res://tools/Shot.tscn" -- <tela|res://cena.tscn> "<saida.png>" [frames] [hurt]`
  → abre janela fora do monitor, pula diálogos, salva PNG; leia o PNG com Read.
  `hurt` força a fase 2 dos chefes. Vitrine do roster: `res://tools/Showcase.tscn`.
  **Use após toda mudança visual.** Feel/timing ainda dependem do usuário jogar.
- Abrir o jogo p/ o usuário ver: `win64.exe` (sem console) via `Start-Process` em
  background, ou o atalho `Jogar GNOSIS` no Desktop. Cena inicial: `scenes/ui/MainMenu.tscn`.
- **Git existe** (desde 2026-09-09). Commite ao fechar cada passo validado.

## Convenções (SIGA)
GDScript, indentação com **TAB**, comentários **em português**. Arte: PNG das
folhas em `assets/painted/` via `PaintedLibrary` (novas folhas = novos recortes
lá); efeitos e fallback por código (`_draw`/Polygon2D). Tipagem explícita; valor sem
tipo (`load()`) → use `var x =` (não `:=`). Balanceamento **determinístico por
tela**. Mantém exportável (`res://`). Sem libs externas.

## Arquitetura (resumo — detalhe em BIBLIA.md §4)
Autoloads em `scripts/autoload/`: GameManager, GameContent, Bestiary, Progression,
Audio, SaveManager, SceneManager, Juice, RunManager, Narrative, FpsOverlay.
Pastas: `scripts/{data,fx,combat,components,entities,levels,ui}`, `scenes/`,
`docs/`, `tools/` (ferramentas da IA: shot, showcase, cut_art).
Motor de arte: `scripts/fx/character_art.gd` (desenha de um `ArtProfile`).
Inimigos: `enemy.gd` com `style` (melee/ranged/charge/slam), `behavior` de wave
(shield/teleport/exploder/summoner) e `kit` de chefe (7 Arcontes, 2 fases).

## Estado / decisões-chave (detalhe em BIBLIA.md §6-7 e ROADMAP.md)
- **Personagem ÚNICA = Sophia**, ilustrada (folha `assets/painted/sophia.png`,
  6 poses; NÃO re-adicionar os 3 jogáveis antigos).
- Nomes CANÔNICOS gnósticos: Demiurgo = **Yaldabaoth**; Arcontes = Athoth, Harmas,
  Galila, Yabel, Astaphaios, Belias, Armupiel. **Respeito:** nunca usar nomes
  sagrados de fés vivas (Sabaoth/Adonai…) como vilão.
- Feito: run de 54 telas com o **arco dos Anéis completo** (Rei, 7 Éons,
  roubo, Centro, batalha dupla, 3 finais), combate GoW com combos por nível,
  launcher/juggle, 7 Arcontes com mecânica própria + 2 fases + **boneco
  articulado**, arte ilustrada (Sophia, criaturas, chefes, Rei, 9 fundos, props),
  menu/ateliê/desafio Codex, HUD, cenário por Éon variado por tela, balance por
  bot, narrativa, save, opções.
- Falta (topo do ROADMAP.md): animação das criaturas comuns · fundos por Éon em
  resolução cheia (usuário gera) · playtest humano · **áudio (ÚLTIMO**, usuário gera,
  `docs/AUDIO.md`) · build.

## Como o usuário trabalha
Orquestra e decide; NÃO é programador. Fala português. Quer a IA opinativa e
**honesta** (sem hype). Passos pequenos, validar sempre, capturar tela, **atualizar
BIBLIA.md §6 e ROADMAP.md** e commitar ao terminar algo.
