# Pedidos do agente de DESEMPENHO (Onda 2) a outros donos

Detalhes, números e como reproduzir: `docs/onda2/PERF.md`. Os patches estão prontos e
passam `git apply --check` no `integracao/onda1` atual (dd25cdb); foram validados numa cópia
dele (ver PERF.md §9).

## 1. Técnico / chefe (dono de `scripts/fx/vfx_library.gd`) — PRIORIDADE ALTA
**O prewarm que já está em `integracao/onda1` (dd25cdb) não funciona** — medido: com ele, a
1ª morte desmembrada, a 1ª esquiva e a 1ª variante do Éon ainda compilam shader no meio da luta,
e ~16 MB de textura ainda sobem no 1º inimigo / 1ª morte da variante (picos de 137–244 ms no
llvmpipe). Causas: alfa 0,004 (< 0,007 o Godot não desenha o item) e objetos de imitação que não
geram as mesmas variantes (ver `docs/onda2/PERF.md` §5).
- Aplicar: `git apply tools/perf/patches/vfx_prewarm.patch` (gerado sobre `integracao/onda1`):
  troca só o corpo de `VfxLibrary.prewarm`; a chamada em `Level._ready` continua como está.
- Se a base mudar: `python3 tools/perf/gera_patch.py --ref integracao/onda1` regenera
  (o corpo vem de `tools/perf/prewarm_proposta.gd`).
- Prova depois de aplicar: `tools/perf/run.sh engasgos` (rodar a sonda com `prewarm=0`, já que o
  jogo pré-aquece sozinho) → colunas "shaders" e "tex MB" zeradas.
- Custo: ~160–190 ms a mais no load da fase (CPU e llvmpipe), atrás do diálogo/card de abertura.
  Invisível (alfa 0,01; captura `/home/user/caps/perf/prewarm_antes_depois_f2.png`).

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
