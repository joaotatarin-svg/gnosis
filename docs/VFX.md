# VFX do GNOSIS — `VfxLibrary` (partículas sobre a arte pintada)

`scripts/fx/vfx_library.gd` (`class_name VfxLibrary`, só funções estáticas) cria
**CPUParticles2D** (roda no `gl_compatibility`) e sprites de clarão com os PNG
CC0 do Kenney Particle Pack em `assets/vfx/` (licenças: `assets/LICENSES.md`).
Nada é autoload e nada muda o `project.godot`: cada função recebe o nó-pai e a
posição global, pendura os nós e eles se **auto-removem** (`finished` →
`queue_free`, com timer de segurança). Teto de instâncias simultâneas:
`MAX_LIVE = 40` (grupo `vfx_live`) — acima disso os efeitos pequenos (`hit`,
`cast`, `dust`, `spark_pickup`) são pulados; os grandes (mortes, chefe, parry,
nova) sempre tocam.

Os desenhos vetoriais antigos (`ImpactBurst`, `AoeNova`, `Gib`, `Projectile`)
continuam — as partículas entram **por cima**, reforçando.

## Funções e onde tocam

| Função | O que faz | Chamada em |
|---|---|---|
| `hit(parent, pos, heavy, cor)` | fagulhas + clarão; pesado = mais fagulhas, talho de luz e poeira | `ImpactBurst.spawn` (todo golpe leve via Hitbox) · `player.register_hit` (pesado) · `enemy._on_hit_received` (pesado/magia) · `projectile` ao explodir |
| `parry(parent, pos)` | anel branco-azul + fagulhas geladas | `player._parry` |
| `dodge_perfect(parent, pos)` | brilho azul + runas dispersando | `player._perfect_dodge` |
| `enemy_death(parent, pos, cor)` | luz da faísca escapando + fumaça escura | `enemy._on_died` (criatura comum) |
| `elite_death(parent, pos, cor)` | `enemy_death` + anel de choque + estrelas | `enemy._on_died` (Elite e Campeão) |
| `boss_death(parent, pos, cor)` | 2 estágios: implosão de luz → 0,35 s → anel gigante, chamas, fumaça, estrelas, **clarão de tela** e `Juice.shake(1.4)` | `enemy._on_died` (Arconte / Rei / Colosso) |
| `boss_phase2(parent, pos, cor)` | onda de choque, espiral, chamas subindo, clarão curto | `enemy._enter_phase2` · `enemy.revive` (forma do Demiurgo se refaz) |
| `boss_appear(parent, pos, cor)` | coluna de luz + anel + poeira no chão | `enemy._boss_intro_fx` (deferred no `_ready` de chefe/campeão) |
| `cast(parent, pos, cor_do_anel)` | círculo rúnico girando + runas subindo na cor do Anel | `player._cast_skill` (toda magia; cor = `SkillData.color`) |
| `nova_ring(parent, pos, raio, cor)` | anel que cresce até o raio + fagulhas na borda | `AoeNova` (primeiro frame; cobre Fúria, Queda Estelar, Anéis, slam de Arconte) |
| `projectile_trail(proj, cor)` | rastro contínuo de luz (filho do projétil) | `Projectile._ready` |
| `spark_pickup(parent, pos)` | estrelinha estourando | disponível (o `SparkOrb` já tem `ImpactBurst` → `hit`) |
| `dust(parent, pos)` | poeirinha | `Gib` no primeiro quique (mesmo rate-limit do som) |
| `portal(parent, pos, cor, dur)` | espiral girando + motes subindo (contínuo) | **disponível** — gancho pra `level.gd` na fenda de saída (ver abaixo) |
| `screen_flash(parent, cor, dur)` | clarão de tela (CanvasLayer 5) | usado por `boss_death` / `boss_phase2` |
| `ambient(parent, eon, tamanho)` | partículas de fundo do Éon, em coordenadas de tela, idempotente (`VfxAmbient`) | `Scenery.build` (uma vez por tela) |

### Ambiente por Éon (`ambient`)
0 Torpor: motes azuis subindo devagar · 1 Fome: brasas tremendo · 2 Corrente:
faíscas de forja caindo · 3 Silêncio: poeira pálida quase parada · 4 Espelho:
cacos prateados girando · 5 Praga: esporos verdes · 6 Coroa: cinzas douradas ·
7 Centro: orbes mornos flutuando · 8 Mente: farrapos escuros à deriva (o vazio).

## Sons ligados junto (em `enemy.gd`)
`boss_appear` (entrada de chefe/campeão) · `boss_phase2` · `form_revive` ·
`enemy_hurt` (posicional, todo dano) · morte por porte: `boss_die` /
`champion_die` / `elite_die` / `enemy_die`.

## Ferramenta de calibração
`res://tools/VfxShowcase.tscn` — monta o cenário de um Éon, dispara todos os
efeitos numa fileira e salva 3 capturas (0,13 s / 0,37 s / 0,83 s):
```
& $godot --path . --resolution 1280x720 --position 4000,4000 res://tools/VfxShowcase.tscn -- shots/vfx_show <eon>
```
Leia `shots/vfx_show_a.png`, `_b.png`, `_c.png`. Ajuste escalas em
`vfx_library.gd` (viewport lógico 640×360: sprite de 128 px × 0,1 = 13 px).
Texturas: `assets/_packs/build_assets.py` (`VFX`) recorta do Particle Pack;
`shots/particle_sheet.png` mostra as 80 opções.

## Ganchos que faltam (arquivos de outros donos)
- `level.gd`: `VfxLibrary.portal(self, pos_da_fenda, Color(0.8, 0.9, 1.0))`
  quando a fenda de saída aparece (junto do `portal_open`), e
  `VfxLibrary.screen_flash(self, Color(1,1,1,0.4), 0.3)` na entrada da fenda.
- `level.gd` / objetos: `spark_pickup` no baú abrindo e nos Selos certos.
- `tools/shot.gd`: um parâmetro `[frames_depois]` pra capturar N frames após
  o `kill`/`hurt` (hoje o evento é no meio e a captura no fim — os efeitos de
  0,3–0,8 s já sumiram na foto).
