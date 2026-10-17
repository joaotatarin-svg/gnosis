# DESEMPENHO — Onda 2 (agente de Desempenho, branch `dir2/perf`)

Não editei o jogo: medi e entreguei as correções como patch pronto para os donos
(`tools/perf/patches/`). Tudo reproduzível com **`tools/perf/run.sh`**.

> **Limite honesto da medição.** Nuvem sem GPU: render por llvmpipe (CPU) numa máquina de
> 4 núcleos dividida com ~10 agentes (carga 15–30). Por isso: (a) **contagens** — variantes
> de shader compiladas, MB de textura enviados, draw calls — são exatas; (b) **tempos** só
> valem como relativos, e uso o **mínimo entre repetições** (ruído só soma tempo). Os ms do
> llvmpipe NÃO são os ms do PC do João: lá a GPU compila mais rápido, mas o engasgo de
> 193 ms da linha de base (RX 7600) mostra que é visível. Nada foi medido em GPU integrada.

## 1. Commits
(lista no fim do relatório ao chefe — `git log --oneline integracao/onda1..dir2/perf`)

## 2. Ferramentas (todas minhas, fora do jogo)
| Arquivo | O que faz |
|---|---|
| `tools/perf/run.sh [perfil\|engasgos\|alloc\|pck\|tudo]` | roda tudo e escreve `RESUMO.md` na pasta `OUT` |
| `tools/perf/HitchProbe.tscn` (`hitch_probe.gd`) | dispara, um por vez e 2 vezes, 30 eventos do combate; mede o pico do quadro e **conta as variantes de shader compiladas** (arquivos novos/crescidos em `user://shader_cache`) e os MB de textura enviados à GPU em cada um |
| `tools/PerfProbe.tscn` (`perf_probe.gd`) | perfil por tela (enche a arena, Sophia ataca). Agora: no headless desliga o sono de 6,9 ms que o Godot faz sem janela (antes o tempo do quadro era "6,9 ms + trabalho") e reporta mediana |
| `tools/perf/AllocBench.tscn` | micro-medição da alocação por quadro (REVISAO #16), hoje × proposto |
| `tools/perf/pck_peso.py` | lê o `.pck` exportado (formato v4) e soma por pasta de ORIGEM |
| `tools/perf/prewarm_proposta.gd` | a correção dos engasgos (corpo de `VfxLibrary.prewarm`) |
| `tools/perf/gera_patch.py` | gera `patches/vfx_prewarm.patch` e `patches/character_art_alloc.patch` |
| `tools/perf/resumo.py` | tabelas em Markdown a partir dos JSON |

## 3. Achados (tabela)
| # | Achado | Evidência | Correção | Dono | Prioridade |
|---|---|---|---|---|---|
| P1 | **3 variantes de shader compiladas no meio da luta** (cache frio = 1ª sessão do jogador): 1º desmembramento (gib com `painted_clean` em retângulo recortado), 1ª esquiva (afterimage `painted_ghost`), 1ª criatura-variante do Éon (boneco articulado → shader de esqueleto 2D) | contagem do cache, 3/3 repetições | `VfxLibrary.prewarm` (patch) → **0** | Técnico | ALTA |
| P2 | **~16 MB de textura carregados do disco e enviados à GPU no meio da luta**: folha `inhabitants` (8 MB) no 1º inimigo (carrega no 1º desenho), folha `archons` (7,2 MB) na 1ª morte de variante do Éon (os gibs recortam dela), boneco do Éon (1 MB), texturas de VFX (0,1–0,2 MB cada, 1º uso) | `RENDER_TEXTURE_MEM_USED` por evento | prewarm carrega e segura as referências → **0** | Técnico | ALTA |
| P3 | O resto dos efeitos (partículas, aditivo, flashes, números, projétil, nova, portal...) **já compila no load** da fase: o Godot GLES3 compila a variante padrão quando o material nasce. Não eram a causa | 0 variantes nesses eventos | — | — | — |
| P4 | **2ª sessão é limpa**: o Godot guarda os binários em `user://shader_cache`; com cache quente, 0 compilações na luta. O engasgo de shader é de 1ª sessão (e depois de atualizar driver/jogo). As texturas (P2) pesam em TODA sessão | rodada com cache quente | prewarm cobre os dois | — | — |
| P5 | Perfil de CPU por tela: 0,4–0,6 ms/quadro sem extras e 1,1–1,4 ms com 12–15 criaturas (nesta CPU dividida) → **CPU não é gargalo** | tabela §4 | — | — | — |
| P6 | Draw calls: ~210 só a tela (tela 3), **~12 por criatura**; 330–410 com 12 extras | GL n=0 × n=6 × n=12 | não mexi (Cenário é o maior bloco); medir em iGPU | Cenário | BAIXA |
| P7 | REVISAO #16 (alocação por quadro): a chave `"%s:%s@%s:%s" % [...]` da malha + `grid_mesh` custam 3–15 µs por criatura por quadro; dicionário `chain` montado todo quadro (Sophia). `PaintedLibrary.region` **não** é mais por quadro (só gibs/props) | AllocBench + A/B | `character_art_alloc.patch` | Anim-Sophia | BAIXA |
| P8 | `.pck` = **89 MB**; ~**9 MB** sem uso em runtime: 5 folhas cromáticas originais (7,5 MB, só fallback) e `assets/characters/` (1,7 MB, só ferramentas) | `pck_peso.py` | `exclude_filter` no export | Técnico | MÉDIA |

## 4. Perfil por tela (brief item 1)
`OUT=/home/user/caps/perf/run tools/perf/run.sh perfil` — CPU = headless (sem render);
GL = janela 320×180 no llvmpipe, só as contagens valem. n=12 criaturas extras (repostas
quando morrem), Sophia imortal atacando sem parar.

| Tela | Papel | CPU n=0 ms mediana / p99 / máx | CPU n=extra ms mediana / p99 / máx | vivos | GL draw calls | GL objetos | nós |
|---:|---|---|---|---:|---:|---:|---:|
| 1 | Rei | 0.41 / 4.76 / 55.2 | 1.09 / 4.38 / 63.2 | 12.2 | 331 | 1332 | 441 |
| 3 | travessia | 0.50 / 1.85 / 43.3 | 1.34 / 5.96 / 18.9 | 12.5 | 327 | 972 | 596 |
| 10 | Arconte | 0.43 / 4.86 / 82.4 | 1.14 / 5.87 / 58.2 | 12.3 | 398 | 1355 | 452 |
| 22 | travessia | 0.49 / 4.84 / 66.1 | 1.19 / 11.58 / 60.1 | 12.0 | 406 | 1752 | 491 |
| 36 | antessala | 0.57 / 4.50 / 103.9 | 1.35 / 6.56 / 135.5 | 13.0 | 403 | 1801 | 514 |
| 50 | travessia | 0.44 / 1.40 / 219.6 | 1.29 / 5.22 / 58.4 | 13.2 | 368 | 1265 | 532 |
| 63 | antessala | 0.63 / 4.47 / 87.3 | 1.39 / 5.92 / 56.1 | 12.6 | 358 | 1121 | 499 |
| 64 | Arconte + roubo | 0.49 / 3.42 / 51.3 | 1.29 / 7.73 / 79.4 | 12.9 | 360 | 1395 | 392 |
| 65 | Centro | 0.41 / 2.39 / 162.7 | 1.12 / 7.98 / 65.0 | 12.5 | 341 | 976 | 436 |
| 68 | final (dupla) | 0.54 / 3.87 / 63.1 | 1.38 / 7.60 / 46.0 | 15.1 | 361 | 885 | 449 |

Draw calls por criatura (GL, tela 3, sem ataque): n=0 → 210, n=6 → 285 ⇒ **~12,5 por criatura**.

Leitura: a CPU do jogo cabe com folga (mediana ≤ 1,4 ms com 13–15 inimigos). Os p99 de
4–12 ms e máximos de 50–220 ms aparecem também SEM inimigos e mudam de rodada para rodada:
são a máquina compartilhada (e os custos de 1ª vez do §5), não a tela. Não há tela "pesada"
de CPU. Tela 68 (batalha dupla) tem mais vivos (15) e fica no mesmo patamar.

## 5. Engasgos de primeira vez (brief item 2) — lista exata para o prewarm
`OUT=/home/user/caps/perf/run2 REPS=3 tools/perf/run.sh engasgos` (tela 3, cache de shaders
FRIO a cada rodada: `user://shader_cache` apagado e `MESA_SHADER_CACHE_DISABLE=true`).

Repetições: cpu/prewarm=0: 3, cpu/prewarm=1: 3, gl/prewarm=0: 3, gl/prewarm=1: 3. Excesso = pico da 1ª vez − pico da 2ª vez (mínimo entre repetições, ms). Shaders = variantes compiladas no evento (arquivos novos/crescidos em user://shader_cache, cache frio). Tex = MB de textura enviados à GPU no evento.

| Evento | CPU excesso sem → com prewarm | GL excesso sem → com | shaders sem → com | tex MB sem → com | shaders (sem prewarm) |
|---|---|---|---|---|---|
| inimigo_nasce | 32 → 0 | 169 → 4 | 0 → 0 | 8.0 → 0.0 |  |
| sophia_golpe_leve | 0 → 4 | 28 → 26 | 0 → 0 | 0.0 → 0.0 |  |
| impact_burst | 0 → 0 | 31 → 0 | 0 → 0 | 0.1 → 0.0 |  |
| damage_number | 0 → 1 | 0 → 0 | 0 → 0 | 0.1 → -0.0 |  |
| vfx_hit_leve | 2 → 0 | 0 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| vfx_hit_pesado | 0 → 0 | 27 → 0 | 0 → 0 | 0.2 → 0.0 |  |
| inimigo_leva_golpe | 0 → 0 | 0 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| inimigo_morre_desmembra | 0 → 4 | 181 → 3 | 1 → 0 | 0.0 → -0.1 | CanvasShaderGLES3/903bfe1c |
| spark_orb | 0 → 0 | 0 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| sophia_esquiva | 1 → 2 | 103 → 0 | 1 → 0 | 0.0 → 0.0 | CanvasShaderGLES3/7f418b5f |
| sophia_pesado | 0 → 3 | 0 → 1 | 0 → 0 | 0.0 → 0.0 |  |
| sophia_magia_inata | 3 → 2 | 25 → 0 | 0 → 0 | 0.2 → 0.0 |  |
| vfx_parry | 0 → 1 | 1 → 0 | 0 → 0 | 0.2 → 0.0 |  |
| vfx_dodge_perfect | 0 → 0 | 43 → 0 | 0 → 0 | 0.1 → 0.0 |  |
| vfx_cast | 0 → 2 | 0 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| vfx_nova_ring | 0 → 0 | 0 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| vfx_dust | 0 → 2 | 0 → 10 | 0 → 0 | 0.0 → 0.0 |  |
| vfx_spark_pickup | 0 → 0 | 0 → 0 | 0 → 0 | 0.1 → 0.0 |  |
| vfx_enemy_death | 3 → 0 | 0 → 7 | 0 → 0 | 0.0 → 0.0 |  |
| vfx_elite_death | 1 → 2 | 27 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| hazard_zone | 0 → 0 | 4 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| aoe_nova | 0 → 0 | 0 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| projetil | 0 → 2 | 3 → 7 | 0 → 0 | 0.0 → 0.0 |  |
| vfx_screen_flash | 0 → 3 | 0 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| vfx_portal | 0 → 2 | 2 → 0 | 0 → 0 | 0.1 → 0.0 |  |
| vfx_boss_appear | 0 → 1 | 27 → 0 | 0 → 0 | 0.0 → 0.0 |  |
| vfx_boss_phase2 | 1 → 1 | 68 → 6 | 0 → 0 | 0.1 → 0.0 |  |
| vfx_boss_death | 0 → 2 | 44 → 44 | 0 → 0 | 0.1 → 0.0 |  |
| inimigo_eon_nasce | 12 → 0 | 160 → 1 | 1 → 0 | 1.0 → 0.0 | SkeletonShaderGLES3/6bb7c9a2 |
| inimigo_eon_morre | 50 → 0 | 124 → 8 | 0 → 0 | 7.2 → 0.1 |  |

- Custo do prewarm no load (chamada, CPU headless, mínimo): 161 ms
- Custo do prewarm no load (chamada, janela llvmpipe, mínimo): 167 ms
- prewarm=0: variantes compiladas DURANTE a luta (soma dos eventos): [3, 3, 3]; no cache ao abrir a fase: [10, 10, 10]
- prewarm=1: variantes compiladas DURANTE a luta (soma dos eventos): [0, 0, 0]; no cache ao abrir a fase: [13, 13, 13]
- Cache QUENTE (2ª sessão, sem prewarm): variantes compiladas durante a luta = 0

Leitura (mínimo de 3 rodadas, cache frio):
- **Os 5 engasgos grandes** (llvmpipe): 1º inimigo **169 → 4 ms**, 1º desmembramento **181 → 3**,
  1ª esquiva **103 → 0**, 1ª variante do Éon **160 → 1**, 1ª morte da variante **124 → 8**.
  Em CPU pura (headless): 1º inimigo 32 → 0 ms, 1ª morte da variante 50 → 0, nascer da variante 12 → 0.
- Menores somem também (hit pesado 27 → 0, dodge perfeito 43 → 0, fase 2 de chefe 68 → 6...).
- Sobra: `vfx_boss_death` 44 → 44 ms (fica de fora do prewarm porque sacode a câmera; acontece
  com hit-stop e câmera lenta, então não aparece como travada) e ~26 ms no 1º golpe leve
  (sem shader e sem textura: não atribuí).
- Valores negativos de "tex MB" = textura liberada no evento (normal).

**O que o prewarm cobre** (`tools/perf/prewarm_proposta.gd`, ~120 linhas):
1. texturas de VFX (22 × 128 px) e as folhas `inhabitants` + `archons` (+ `yaldabaoth` no Rei/final),
   o `mesh_cache.res` e as texturas do boneco do Arconte do Éon — **segurando as referências**
   (`_warm_refs`) até a próxima fase;
2. o VISUAL real (`CharacterArt`, sem `Enemy`: fora do grupo "enemy", sem física/IA) de cada tipo
   de criatura da tela (`Bestiary.types_for_screen`) — inclui o boneco articulado da variante;
3. os gibs reais dessas criaturas (`gib_parts` + `Gib.burst`);
4. uma camada de afterimage sobre o atlas da Sophia (shader `painted_ghost`);
5. um `Skeleton2D` + `Polygon2D` com osso (shader de esqueleto);
6. os efeitos reais: `hit` leve/pesado, `parry`, `dodge_perfect`, `cast`, `nova_ring`, `dust`,
   `spark_pickup`, `enemy_death`, `elite_death`, `boss_appear`, `boss_phase2`, `portal`,
   `projectile_trail`, `ImpactBurst`, `DamageNumber` (`boss_death` fica de fora: sacode a câmera).

Tudo num nó `PrewarmStage` no centro da câmera, **alfa 0,01 e escala 0,25**, que some sozinho
depois de 3 quadros desenhados. Sem som, sem tremor.

**Duas armadilhas que medi (e por isso o desenho é esse):**
- **SubViewport invisível não serve**: desenhei tudo num SubViewport 32×32 e a 1ª morte ainda
  compilou a variante — o que compila lá não vale para a tela.
- **Alfa < 0,007 o Godot descarta antes de desenhar** (não compila nada). Com 0,004 nada
  aconteceu; com 0,01 compila. 0,01 = no máximo ~2,5/255 de brilho por camada, por 3 quadros,
  durante o diálogo/card de abertura. Captura: `/home/user/caps/perf/prewarm_antes_depois_f2.png`
  (esq. sem prewarm, dir. com — quadro 2 da fase; nada visível no centro).

**Prova ponta a ponta**: apliquei os patches numa cópia do projeto e rodei a sonda SEM o
prewarm da sonda (o próprio `Level._ready` pré-aqueceu): 0 variantes e 0 MB de textura nos
eventos de 1ª vez (`/home/user/caps/perf/patch_e2e_t3.json`).

## 6. Alocação por quadro (brief item 3 / REVISAO #16)
`tools/perf/run.sh alloc` (µs por chamada, melhor de 5; variou 3–5× entre rodadas com a carga):

| Medida | hoje | proposto |
|---|---:|---:|
| chave da malha formatada + `grid_mesh` (por criatura pintada, por quadro) | 2,9–15,4 | 0,18 |
| dicionário `chain` em `_hero_seq` (Sophia, por quadro) | 3,4–13,5 | 0,2–0,7 (const) |
| `PaintedLibrary.region` (só gibs/props, não é mais por quadro) | 1,7–8,3 | — |
| 11 `set_shader_parameter` por personagem | 0,4–1,4 | (não mexi) |
| `draw_grid` (cópia da malha + cores, inevitável hoje) | 1,5–6,9 | (não mexi) |

A/B de quadro (headless, tela 50 + 24 criaturas, 4 rodadas intercaladas, cópia com o patch):
mediana 1,93/1,99/2,04/2,12 ms (hoje) × 1,66/1,81/1,99/2,82 ms (patch) → mínimo **1,93 → 1,66 ms**.
Ganho real mas pequeno e no meio do ruído. Prioridade baixa, sem risco visual.

## 7. Peso do `.pck` por pasta (brief item 3)
`tools/perf/run.sh pck` (exporta com `--export-pack "Windows Desktop"`, não precisa de templates):

| Pasta (origem) | MB | % |
|---|---:|---:|
| assets/audio/music (28 faixas, ~110 kb/s — já razoável) | 32,2 | 36 |
| assets/painted/derived (folhas limpas + bonecos) | 21,9 | 25 |
| assets/backgrounds (9 Éons × 5 camadas) | 16,6 | 19 |
| assets/painted (raiz: `eons.png` usado + **5 originais cromáticas sem uso**) | 9,6 | 11 |
| assets/audio/amb | 3,9 | 4 |
| assets/audio/sfx (254 arquivos) | 1,6 | 2 |
| assets/characters (**sem uso em runtime**) | 1,7 | 2 |
| fontes, UI, VFX, scripts, cenas | ~1,5 | 2 |
| **Total** | **89,1** | |

Maior arquivo: `derived/sophia_frames.png` (5,7 MB no pck; 2048² com mipmaps = ~21 MB de VRAM).

## 8. O que NÃO ficou bom / não deu tempo
- **Nada medido em GPU real nem em iGPU.** Os ms do §5 são do llvmpipe. Recomendo o João rodar
  `GL=1 tools/perf/run.sh engasgos` (ou o PerfProbe) no PC dele depois do patch — ou o chefe pedir.
- A sonda de engasgos roda na tela 3 (Torpor). As criaturas mudam por Éon; o prewarm usa
  `Bestiary.types_for_screen(tela)`, então deve generalizar, mas só medi a tela 3 com repetição
  (OUTRAS_TELAS).
- Ainda há um resíduo de ~25 ms na 1ª esquiva no llvmpipe com o prewarm (0 shaders, 0 textura):
  provável custo interno do driver de software; não consegui atribuir.
- Não otimizei draw calls (cada criatura tem material próprio → não agrupa). Cenário/Anim decidem.
- Os eventos de chefe (fase 2, morte) foram medidos como VFX isolados, não com o chefe real.

## 9. Validação
`tools/validate.sh` no meu worktree e na cópia com os 2 patches aplicados — iguais à base:
```
# meu worktree (dir2/perf) — tools/validate.sh
Scripts        OK         6s  pass=0  code=0
ScriptCheck    OK         2s  pass=0  code=0
CodexQA        FALHOU    17s  pass=32  code=1   | QA FAIL: diretório de save independente
AudioQA        FALHOU     5s  pass=23  code=1   | QA FAIL: duck(): música -4.4 → -4.4 → -4.4 dB
GnoseQA        OK        17s  pass=18  code=0
SaveQA         OK         1s  pass=13  code=0
PuppetQA/HeroQA/WaveQA OK
# cópia do projeto com vfx_prewarm.patch + character_art_alloc.patch aplicados
SCRIPTCHECK: 110 scripts, 0 com erro
(mesmo resumo acima: só os 2 vermelhos conhecidos)
```
(`diretório de save independente` = falso conhecido do override.cfg; `duck()` = bug conhecido do Áudio.)
