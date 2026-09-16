# AGENTS.md — GNOSIS (lido automaticamente pelo Codex em toda sessão)

Jogo **GNOSIS**: beat-em-up 2.5D (Grand Chase) + ação estilo God of War, tema
gnóstico. **Godot 4.7.1 / GDScript. Arte procedural/vetorial em código** como
base (PNG ilustrado só pro Rei/Demiurgo; áudio futuro). É o Jogo 1 de uma tetralogia.

> Este arquivo é só o **mapa**. O handoff COMPLETO está em **`BIBLIA.md`** —
> leia-o no início de cada sessão. Plano mestre (F0–F6) no topo de `ROADMAP.md`.
> História em `docs/LORE.md`, design em `docs/GDD.md`.

## Como rodar / validar (SEMPRE após editar código)
Godot (esta máquina):
`C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`
- Validar: `& $godot --headless --path . --editor --quit` → **não pode ter `SCRIPT ERROR`**.
- Rodar cena headless: `& $godot --headless --path . "res://<cena>.tscn" --quit-after 150`
- **VER o jogo (a IA enxerga!):** `& $godot --path . --resolution 1280x720 --position 4000,4000 "res://tools/Shot.tscn" -- <tela|res://cena.tscn> "<saida.png>" [frames] [hurt]`
  → abre janela fora do monitor, pula diálogos, salva PNG; leia o PNG.
  `hurt` força a fase 2 dos chefes. Vitrine do roster: `res://tools/Showcase.tscn`.
  **Use após toda mudança visual.** Feel/timing ainda dependem do usuário jogar.
- Abrir o jogo p/ o usuário ver: `win64.exe` (sem console) via `Start-Process` em
  background, ou o atalho `Jogar GNOSIS` no Desktop. Cena inicial: `scenes/ui/MainMenu.tscn`.
- **Git existe** (desde 2026-09-09). Commite ao fechar cada passo validado.

## Convenções (SIGA)
GDScript, indentação com **TAB**, comentários **em português**. Arte por código
(`_draw`/Polygon2D); PNG só onde já existe hook. Tipagem explícita; valor sem
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
- **Personagem ÚNICA = Sophia**, **procedural** (PNG de manto aposentado; NÃO
  re-adicionar os 3 jogáveis antigos nem o PNG do herói).
- Nomes CANÔNICOS gnósticos: Demiurgo = **Yaldabaoth**; Arcontes = Athoth, Harmas,
  Galila, Yabel, Astaphaios, Belias, Armupiel. **Respeito:** nunca usar nomes
  sagrados de fés vivas (Sabaoth/Adonai…) como vilão.
- Feito: run (50 telas/7 Éons/chefes/3 finais), combate GoW, arte procedural
  animada, VFX, **7 Arcontes com assinatura visual + mecânica própria + 2 fases**,
  4 bots especiais, IA de grupo, HUD colorido + barra de chefe, cenário por Éon,
  plataformas, conteúdo, narrativa, save, opções.
- Falta (ROADMAP F1–F6): motor de arte do herói/waves subir de nível · combos por
  nível de arma, launcher/juggle · **arco canônico** (Anéis, o Rei, roubo, Centro,
  batalha dupla) · balance por bot + playtest · **áudio (ÚLTIMO**, usuário gera,
  `docs/AUDIO.md`) · build.

## Como o usuário trabalha
Orquestra e decide; NÃO é programador. Fala português. Quer a IA opinativa e
**honesta** (sem hype). Passos pequenos, validar sempre, capturar tela, **atualizar
BIBLIA.md §6 e ROADMAP.md** e commitar ao terminar algo.
