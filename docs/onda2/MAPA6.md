# MAPA6 — o run deixa de ser um corredor (Onda 6, diretor de mapa)

Branch `dir6/mapa6` (base 37ea6f5). Queixa do João: *"o jogo está muito LINEAR: vai pra
frente e bate nos bichinhos"*.

## 1. O desenho

Cada Éon (9 telas) virou um **grafo por camadas**. Todo caminho passa por **exatamente um
nó por camada**, então a tela 2..64 continua sendo "a camada N do Éon K": beats da
história, Estelas, Soter/Velkar, balance por tela, sorteio determinístico e checkpoints
(camadas 0, 4 e 7, que são nós únicos) seguem valendo **em qualquer rota**. A escolha muda
o **tipo** da tela e a **recompensa**.

Grafo do Éon 1 — Fome (telas 11–19); `★` = Estela na camada; `🔒` = exige pulo duplo:

```
camada:   0          1           2            3              4            5            6            7          8
tela:     11         12★         13           14             15★          16           17★(Soter)   18         19
                  ┌ ESCALADA ─ PERIGO ──── SEGREDO🔒 ─┐               ┌ PERIGO ──── ESCALADA ─┐
 CHEGADA ─────────┼ TRAVESSIA ─ ARENA ──── TRAVESSIA ─┼─ O DESAFIO ───┼ TRAVESSIA ─ TRAVESSIA ─┼─ ANTESSALA ─ ARCONTE
 (checkpoint)     └ SANTUÁRIO ─ TRAVESSIA ─ SANTUÁRIO ┘  (checkpoint)  └ SANTUÁRIO ─ ARENA ─────┘  (checkpoint)  Harmas
```
Arestas: mesma trilha + uma trilha vizinha (o cruzamento alterna por Éon+camada); da
chegada e do Desafio saem todas as trilhas; tudo converge no Desafio e na antessala.
Nenhum nó livre fica num beco que só o pulo duplo resolve (MapQA confere).

### Tipos de nó (`EonMap.KINDS`) e recompensa (`EonMap.REWARDS`, paga ao VENCER o nó)
| Tipo | O que é (zone_plan) | Recompensa |
|---|---|---|
| combat · Travessia | plano LEGADO da tela (2–3 zonas) — a rota do meio é o jogo de antes | +6 +3×Éon faíscas |
| hazard · Passagem perigosa | 2 zonas, 1 wave, uma criatura a menos (o chão é o perigo — level6) | +5 vida máx. |
| platform · Escalada | 2 zonas, 1 wave normal (altura/plataformas/voadores — level6) | +5 Éter máx. |
| sanctuary · Santuário | 2 zonas de 2 criaturas (luta leve) | cura inteira na próxima tela |
| challenge · Arena (opcional) | 2 zonas: 2 e 3 waves, +1 criatura/wave, bot do Éon na última | +30 +10×Éon faíscas, +8 vida máx. |
| secret · Sala secreta | 2 zonas de 2 guardiões; **exige o pulo duplo** (Soter) | +20 +6×Éon faíscas, +10 vida, +10 Éter |
| arrival / trial / antechamber / archon | inalterados | (os de antes: loja, Anel…) |

Todos os tipos do mapa têm **2 zonas** de propósito: as legendas de zona Z0/Z1 do
ROTEIRO tocam em qualquer rota. Tabela literal por Éon em `EonMap.LANES` (o chefe/João
ajustam ali, sem código).

### Tamanho do run
Igual: 9 nós por Éon, 68 telas. Mudam a densidade e o ritmo (Arena mais longa; santuário
e perigo mais curtos). Bot r9-mapa (seed 3, Éons 0–1): 5,7 min, 485 de dano, 0 mortes;
Arena 26 s × travessia 12–28 s × santuário 16 s.

## 2. Arquivos
- `scripts/levels/map/eon_map.gd` (novo, `class_name EonMap`): tabela, construção do grafo
  em cache, recompensas, `find(id)`, `default_id`, `slot`.
- `scripts/autoload/run_manager.gd`: nó atual, rota, escolha, recompensa, save/migração,
  `zone_plan` por tipo, rota automática.
- `scenes/ui/WorldMap.tscn` + `scripts/ui/world_map.gd` (novos): a tela de mapa.
- `tools/map6/MapQA.tscn` (QA headless) e `tools/map6/MapShot.tscn` (captura em run).
- `tools/balance_bot.gd` (2 linhas + relatório): `rota=N`. *Arquivo de QA fora da minha
  lista — mudança mínima, pedida no briefing ("o bot precisa percorrer o mapa").*
- `assets/i18n/en/12_mapa6.tsv` + `strings.csv`/`en_table.gd` regenerados (build --strict).

## 3. Fluxo
`Level` → `RunManager.advance_and_reload()` (nada mudou no level.gd): paga a recompensa do
nó vencido; se a próxima camada tem **uma** saída, carrega a tela (a recompensa vira toast
no HUD ~1,8 s depois); se tem **mais de uma**, abre `WorldMap` (`choosing = true`), que
mostra o grafo do Éon, a rota feita (ouro), a faísca no nó vencido, as saídas pulsando,
segredos selados com cadeado, a Estela de cada camada e a legenda. Setas/D-pad/analógico
escolhem, confirmar → `RunManager.choose_node(id)` → `Level01`. Mouse: clicar 2×.
Fora de run a cena abre uma PRÉVIA (`GNOSIS_MAP_EON`, `GNOSIS_MAP_LAYER`).

## 4. API para os outros diretores
| Chamada | Para quê |
|---|---|
| `RunManager.node_kind(screen=-1)` | **level6**: o TIPO da tela — `arrival/combat/hazard/platform/sanctuary/challenge/secret/trial/antechamber/archon/king/center/final` |
| `RunManager.node_at(screen)` / `current_node` | dados do nó (`id, eon, layer, row, kind, screen, next, requires, reward`) |
| `RunManager.node_rng(salt)` | RNG por NÓ (duas trilhas da mesma camada sorteiam diferente) |
| `RunManager.is_optional_node()` | Arena/segredo (HUD, narrativa) |
| `RunManager.node_title()` | nome legível do tipo ("Passagem perigosa") |
| `RunManager.has_double_jump()` | lê `Progression.has_double_jump()` se existir (contrato da onda) |
| `RunManager.beat_slot(screen)` / `screen_for_slot(slot)` | **narrativa6**: tabela de compatibilidade |
| sinal `RunManager.node_entered(id)` | entrou num nó |
| `RunManager.map_route_seed` | -1 jogador · 0 trilha do meio · N rota sorteada (bot/QAs) |
| `screen_role(screen)` | **inalterado** (tipos do mapa respondem "travel") — eon_rule, HUD, Narrative seguem iguais |

### Tabela de compatibilidade dos beats (narrativa por nó)
Slot = `e<Éon>.L<camada>` ⇔ tela legada = `2 + 9×Éon + camada` (fora dos Éons: `s<tela>`).
Como toda rota passa por um nó de cada camada, **um beat preso ao número da tela continua
tocando em qualquer caminho**. Exemplos: `e0.L1`=3 (Estela Pleroma) · `e1.L6`=17 (Soter #1)
· `e3.L6`=35 (Soter #2) · `e5.L6`=53 (Soter #3) · `e6.L5`=61 (Velkar) · `e6.L8`=64 (roubo).
Beat novo que dependa do TIPO (ex.: fala só no santuário) → `RunManager.node_kind(screen)`.

## 5. Save / continuar / checkpoints
- `run_snapshot()` ganhou `map_v: 1`, `node` (nó do checkpoint) e `path` (rota até o
  checkpoint). `screen` continua o checkpoint (o menu "Continuar" não mudou).
- `continue_run()` → `_restore_map`: ids inválidos, fora de ordem ou depois do checkpoint
  são descartados. **Save antigo** (sem as chaves) → rota vazia + nó padrão do checkpoint.
  `SAVE_VERSION` **não** mudou (nenhum run antigo é descartado).
- Morte → checkpoint (nó único) e a rota é cortada até ele. Fechar o jogo NA tela de mapa
  = o "Continuar" volta ao último checkpoint (como fechar no meio de uma tela).

## 6. Validação
- MapQA: 22 PASS (grafo dos 7 Éons, variedade, slots, planos de todos os nós, fluxo real
  chegada→mapa→perigo, recompensa, morte, segredo trancado, snapshot/continuar, save
  antigo, rota estragada, rota automática determinística).
- i18n: `build.py --strict` 1350/1350, 0 alertas; LangQA 12 ok.
- validate.ps1: ver o relatório final ao chefe.
- Capturas: `C:\gnosis-wt\_caps\mapa6\map_run_e0_L1.png` (1ª escolha do Torpor),
  `map_run_e3_L5.png` (rota feita, depois do Desafio), `map_run_e2_L2_en.png` (inglês),
  `map_preview_e1.png`/`map_preview_e2.png` (prévia). "Antes" não existe: não havia mapa.

## 7. Limites honestos
- O **layout** de perigo/escalada/segredo é do level6: até ele ler `node_kind()`, esses nós
  são telas de combate mais leves (só muda a densidade). A sala secreta ainda não exige
  pulo duplo DENTRO da tela — só no mapa.
- Sem `Progression.has_double_jump()` (progressao6/combate6) os segredos ficam selados.
- Não há telas extras opcionais (salas laterais que somam telas): decidi não fazer porque
  os baús/Adormecidos/Selos/Estela são por NÚMERO de tela e duplicariam. Próximo passo
  possível quando o level6 tiver extras por nó.
- O mapa não é revisitável (sem backtracking entre Éons) — é ramificação, não metroidvania.
- Playtest humano da tela de mapa não feito (navegação por teclado/pad testada só por QA).
