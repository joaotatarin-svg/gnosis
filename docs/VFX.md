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

---

# CENÁRIO v3 (Diretor de Cenário, onda 1 — 17/10/2026)

Arquivos: `scripts/levels/scenery.gd` (reescrito), `scripts/fx/scenery_library.gd`
(novo, `SceneryLibrary`), `assets/shaders/scenery_{floor,rays,fog,prop}.gdshader`,
`assets/backgrounds/eon_<i>_{far,mid,near,floor,fgcol}.png` + `fg_rubble/fg_pillar.png`
(23 MB), `tools/scenery/` (pipeline e ferramentas).

## Pipeline offline — `python tools/scenery/build_backgrounds.py [--no-ai] [--only 0,3]`
- Recorta as 9 pinturas de `assets/painted/eons.png` (bordas medidas: COLS/ROWS).
- Upscale: Real-ESRGAN ncnn-vulkan (modelo `realesrgan-x4plus`, roda na RX 7600;
  exe em `C:\Users\jmtat\gnosis-tools\realesrgan\`, release oficial BSD-3) 4× →
  Lanczos até 3× + 15% de Lanczos misturado (devolve textura de pincel). Sem o exe:
  Lanczos + unsharp adaptativo. Cache em `%LOCALAPPDATA%\gnosis_scenery_cache`.
- Camadas: GrabCut guiado por faixas (ASAS = bordas laterais → `mid`; ENTULHO da
  base → `near`), refinado com guided filter. `far` = pintura com as asas
  preenchidas por reflexo + névoa. `floor` = chão pintado abaixo da linha.
  `fgcol` = asa esquerda escurecida/desfocada (coluna de primeiro plano).
- Reescreve o bloco `# >>> GERADO` de `scenery_library.gd` (tamanhos, névoa, céu).
- Profundidade por IA (MiDaS small) foi testada e descartada: borrões inúteis nessas pinturas.

## Montagem em runtime (scenery.gd)
ParallaxBackground: céu → FAR (0,03) → raios (shader, foco no astro do Éon; Mente =
raios de VAZIO) → névoa longe → MID asas (0,14) → névoa perto → NEAR (0,32) → props
pintados integrados (0,55/0,75; shader `prop`: névoa por distância, borda de cima
acesa, chama ciano recolorida p/ cor do Éon, sombra de contato). Camadas espelhadas
([ladrilho][invertido]) = sem emenda. Ganchos do Level (sem mexer em level.gd):
- `build_ground`: FloorBand (shader: chão pintado em perspectiva, 1:1 nos pés,
  reflexo do fundo via screen texture, névoa no horizonte, poça de luz na faixa de
  luta, escurece p/ a câmera), névoa rasteira sobre os pés, FloorDecor (entulho no
  chão à frente da luta, em perspectiva), arena simétrica de chefe (obeliscos +
  braseiros com luz), e `_integrate_platforms` (deferred: sombra projetada, sombra
  no chão, borda acesa, coluna de luz, poeira).
- `build_foreground`: entulho desfocado (parallax 1,35), colunas da pintura nos
  descansos (não em chefe), bokeh (na Mente, sombra).
Constantes de enquadramento: FLOOR_Y 292 (horizonte), FEET_Y 310, PAINT_H 280, CAM_TOP 44.

## Ferramentas
- `tools/scenery/caps.sh <prefixo> [telas]` — capturas de aceite (SHOT=... troca a cena;
  `res://tools/scenery/CleanShot.tscn` esconde legendas; arg `nohud` esconde HUD).
- `tools/scenery/bench.sh [telas]` — tempo de quadro. ATENÇÃO: nesta máquina trava em
  144 fps (6,94 ms) antes E depois; só prova "≥144 fps", não mede o custo real.

## ESTADO PARA A PRÓXIMA SESSÃO
Feito (validado: editor headless 0 SCRIPT ERROR; capturas):
- Entregáveis 1 (pipeline + camadas), 2 (chão/primeiro plano), 3 (plataformas),
  4 parcial (raios, névoa em camadas, faíscas em órbita no Centro, vazio na Mente;
  partículas por Éon continuam as de `VfxLibrary.ambient`), 5 (arena simétrica;
  código vetorial morto `_build_far/_build_mid/_make_prop/_build_near/_ring`,
  CelestialBody e FogPuff removidos).
- Capturas: antes `C:\gnosis-wt\_caps\cenario\antes_<tela>.png` (+`antes_grid.png`);
  depois `c3_<tela>.png` (`c3_grid0/1.png`, sem legenda) e `c4_22.png` (com FloorDecor).
Falta:
1. Entregável 6 (marketing `assets/store/`: ícone 512, cápsulas 460×215 e 616×353,
   hero 1920×620) — NÃO feito.
2. Faixa `near` tem bordas retas/blocadas em Silêncio e Centro (GrabCut); melhorar
   a máscara (ex.: trimap mais justo por Éon) ou suavizar o topo.
3. Na arena de chefe, o obelisco esquerdo aparece no meio da tela no início (câmera
   ainda não centrada na arena); considerar pôr a cenografia numa ParallaxLayer.
4. Partículas novas por profundidade (motes longe/perto por Éon) além do bokeh.
5. Medir custo real de GPU (bench precisa vsync de fato desligado ou contador de GPU).
6. Atualizar `assets/backgrounds/README.txt` (ainda descreve só o PNG único).
Próximos passos exatos: rodar `python tools/scenery/build_backgrounds.py` só se mudar
`eons.png`; depois `tools/scenery/caps.sh depois` (todas as 8 telas) e comparar com `antes_*`.
