# Pedidos do agente de DESEMPENHO (Onda 2) a outros donos

Detalhes, números e como reproduzir: `docs/onda2/PERF.md`. Os patches estão prontos e
passam `git apply --check` na base `integracao/onda1`; foram validados numa cópia do
projeto (validate.sh igual à base: só os 2 vermelhos conhecidos).

## 1. Técnico (ou o dono de `scripts/fx/vfx_library.gd` + `scripts/levels/level.gd`) — PRIORIDADE ALTA
**Pré-aquecer o combate no load da fase** (fecha a pendência "engasgos até 193 ms no 1º golpe").
- Aplicar: `git apply tools/perf/patches/vfx_prewarm.patch`
  - acrescenta `VfxLibrary.prewarm(level)` no fim de `vfx_library.gd`;
  - 1 linha em `level.gd::_ready`, logo depois de `_spawn_extras()`: `VfxLibrary.prewarm(self)`.
- Se o `level.gd` tiver mudado e o patch não entrar: a linha é só essa; o corpo da função
  é `tools/perf/prewarm_proposta.gd` (regenera os patches com `python3 tools/perf/gera_patch.py`).
- Prova esperada depois de aplicar: `tools/perf/run.sh engasgos` → coluna "shaders" 0 em todos
  os eventos e "tex MB" 0 (hoje: 3 variantes de shader e ~16 MB de textura no meio da luta).
- Custo: ~160–190 ms a mais no load da fase (atrás do diálogo/card de abertura). Invisível
  (alfa 0,01; captura em `/home/user/caps/perf/prewarm_antes_depois_f2.png`).

## 2. Anim-Sophia (dono de `scripts/fx/character_art.gd`) — PRIORIDADE BAIXA (REVISAO #16)
- Aplicar: `git apply tools/perf/patches/character_art_alloc.patch`
  - malha da pintura da criatura guardada na instância (some a chave `"%s:%s@%s:%s" % [...]`
    formatada a cada quadro por criatura); `const HERO_CHAIN` e `const HERO_FALLBACK_ANCHORS`.
- Ganho medido pequeno: ~3–15 µs por criatura por quadro (depende da carga da máquina);
  A/B headless tela 50 + 24 criaturas: quadro mediano 1,93 → 1,66 ms (mínimo de 4 rodadas, ruidoso).
- Não muda nada visual (mesma malha, mesmo desenho).

## 3. Técnico (`export_presets.cfg`) — peso do instalador
- `.pck` hoje: **89 MB**. Peso morto em runtime (conferir antes):
  - as 5 folhas cromáticas ORIGINAIS `assets/painted/{sophia,archons,yaldabaoth,architecture,inhabitants}.png`
    (**7,5 MB**): o jogo só as carrega se faltar a versão `derived/` (fallback de `PaintedLibrary.sheet`).
    Mantê-las no git (fonte do `clean_sheets.py`), mas excluir do export:
    `exclude_filter="tools/*, artes/*, shots/*, docs/*, assets/painted/sophia.png, assets/painted/archons.png, assets/painted/yaldabaoth.png, assets/painted/architecture.png, assets/painted/inhabitants.png"`
    — e um teste no CodexQA garantindo `PaintedLibrary.has_clean_sheets()` no build.
  - `assets/characters/` (**1,7 MB**): nenhum script do jogo carrega (só ferramentas em `tools/`);
    `set_rig()` existe mas ninguém chama. Confirmar e excluir do export.

## 4. Cenário (informativo, não é pedido de mudança)
- A tela sozinha (tela 3, sem inimigos) já faz ~210 draw calls; cada criatura soma ~12.
  Não medi em GPU integrada. Se for otimizar, o cenário é o maior bloco.
