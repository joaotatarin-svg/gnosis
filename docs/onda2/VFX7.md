# VFX7 — ataques à distância com cara de jogo premium (Onda 6/7, 18/10/2026)

Queixa do João (playtest 2, item 5): "os ataques/bolas da Sophia e dos mobs estão
preguiçosinhos — quero brilho, cara de jogo PREMIUM".

## O que mudou
**Linguagem visual por família** (`scripts/fx/attack_fx/attack_style.gd`):
- LUZ DA SOPHIA (`light`, `solar`, `chain_light`): redonda, miolo branco-quente, plasma
  na cor do Anel, fita clara.
- LUZ CORROMPIDA (`dark`, `king`, `chain`, `sleep`, `wave`): miolo ESCURO com borda acesa,
  coroa pontiaguda (espinhos do shader), fita com veio escuro. Forma além da cor
  (daltonismo/R5): um tiro inimigo nunca se confunde com um da Sophia.
- FORMAS do Projectile (campo `look`, onda 6): `orb` · `bolt` (seta orientada pelo voo) ·
  `wisp` (chama ondulando) · `seed` (gira) · `page` (gira, runas) · `spike` (= onda rasteira)
  — mudam a silhueta por cima da família.

**Peças** (todas novas, meus arquivos):
- `assets/shaders/vfx_orb.gdshader` — núcleo de plasma procedural (premultiplicado: soma
  luz E escurece o miolo corrompido num passe só). `vfx_trail.gdshader` — fita do Line2D
  (ruído correndo, veio branco/escuro, elos de corrente). `vfx_ring.gdshader` — anel de choque.
  Os três leem a cor do VÉRTICE por `varying` (o `COLOR` do fragment já vem multiplicado
  pela textura do quad — era o que escondia tudo na 1ª versão).
- `scripts/fx/attack_fx/projectile_fx.gd` (`ProjectileFX`): pendurado no projétil — núcleo,
  halo aditivo, raios, fita com gradiente e afinamento (top_level, 1 ponto a cada 4 px),
  partículas secundárias, clarão de saída, IMPACTO por família, DISSIPAÇÃO no fim da vida
  (a fita recolhe em 0,22 s em vez de sumir seca). Materiais compartilhados por família.
- `scripts/fx/attack_fx/charge_fx.gd` (`ChargeFX`): ANTECIPAÇÃO — motes convergindo, círculo
  (runas/espinhos) fechando e girando cada vez mais rápido, núcleo inchando, estalo no fim;
  som curto (`charge_light`/`charge_dark` se o Áudio criar; senão `proj_fire` grave e baixo).
- `vfx_library.gd`: `attack_impact` (clarão no orçamento + anel + faíscas DIRECIONAIS +
  decalque no chão + tempero por família: explosão solar, coroa dourada do Rei, estalo de
  corrente, borrifo corrompido, bolhas do sono, terra da onda), `attack_fizzle`,
  `shock_ring`, `ground_decal`, `aura` (Reflexo: cacos orbitando 5 s), `flash_budget`.
- **As 8 magias**: `cast()` ganhou a ASSINATURA de cada Anel (reconhecida pela cor =
  `skill.color`): disco de sol, bafejo de névoa, redemoinho que suga, estrela de forja,
  anéis que se FECHAM (silêncio), cacos + aura do espelho, esporos, coroa de raios.
  `nova_ring`/`AoeNova`: frente quente fina + corpo colorido (shader), pegada elíptica no
  chão, motes subindo, pilar de luz nas novas ≥ 140 px (Coroa). `SparkOrb`: cauda + halo aditivos.
- **R4 (um acerto = um evento)**: `ImpactBurst.spawn` pergunta `ProjectileFX.find_at(pos)` e
  delega o impacto premium; o `hit` genérico do mesmo ponto/quadro é suprimido (`_claim`).
- **R10 (≤ 3 flashes/s)**: `flash_budget()` — os 3 primeiros clarões fortes do último
  segundo saem inteiros, os seguintes a 30 %; "Reduzir flashes" corta tudo pela metade.
- **Pré-aquecimento**: `prewarm` instancia as 8 famílias, os 7 impactos, a dissipação, as 3
  antecipações (mudas) e a aura — os shaders compilam no load da fase. O orçamento de flash
  é zerado depois.

## API para os outros diretores
```gdscript
VfxLibrary.projectile_look(proj, kind_ou_forma := "", cor = null) -> bool
    # já chamada pelo projectile.gd (com `look`); família deduzida de team/root/slow/cor.
    # Forçar família: proj.set_meta("vfx_kind", "king") ANTES do add_child, ou
    # ProjectileFX.attach(proj, "king") (devolve o nó).
VfxLibrary.charge_up(host, offset, cor, duracao, "light"|"dark"|"king") -> ChargeFX
    # chame no INÍCIO do wind-up/conjuração; .cancel() se o golpe for interrompido.
VfxLibrary.attack_impact(pai, pos, cor, "light"|"explosion"|"chain"|"dark"|"king"|"sleep"|"wave", dirx, chao_y)
VfxLibrary.shock_ring(pai, pos, raio, cor, dur, dark, squash, espessura)
VfxLibrary.ground_decal(pai, pos, cor, largura, luz, dur)
VfxLibrary.aura(host, cor, dur)            # buff visível (Reflexo usa sozinho)
VfxLibrary.flash_budget() -> float          # multiplique o alfa de qualquer clarão forte
```
Famílias: `light solar chain_light` (Sophia) · `dark king chain sleep wave` (inimigos).
Dedução (`AttackStyle.kind_for`): tiro da Sophia → explode=`solar`, prende=`chain_light`;
inimigo → `look` "spike"=`wave`, prende=`chain`, lentidão=`sleep`, cor dourada
(1,0.85,0.5)=`king`, senão `dark` na cor do olho. A família é re-deduzida no 1º quadro
(quem cria pode mudar cor/forma depois do `add_child`).

## Medidas
- Desempenho (`VfxShowcase7 perf`, SubViewport 1280×720, 20/40 projéteis no ar com ~20
  impactos/s, `--fixed-fps 60`, vsync off, RX 7600). GPU/CPU de render medidos pelo
  `RenderingServer.viewport_get_measured_render_time_*`:

  | caso | quadro médio | p95 | GPU render | CPU render |
  |---|---|---|---|---|
  | antes, n=0 | 1,19 ms | 1,95 | 0,23 | 0,23 |
  | antes, n=20 | 9,73 ms | 13,7 | 2,01 | 1,64 |
  | depois, n=20 | 8,34 ms | 10,2 | 1,93 | 1,42 |
  | antes, n=40 | 13,5 ms | 16,9 | 3,14 | 2,33 |
  | depois, n=40 | 12,8 ms | 16,7 | 3,35 | 2,24 |

  O visual novo custa o mesmo que o antigo (diferença dentro do ruído de ±1 ms entre
  rodadas). Achado lateral: ~4–6 ms do quadro com 20 projéteis NÃO é desenho (escondendo os
  projéteis cai para ~2,8 ms) — é lógica/física do Projectile+impactos; vale o Desempenho olhar.
- Validação: `tools/validate.ps1 -Repeat 2` → TUDO VERDE (11 etapas, 2/2).
- Jogo real (Shot, tela 1 do Rei, `act=magic`, 0 SCRIPT ERROR): `C:\gnosis-wt\_caps\vfx7\jogo\rei_grid.png`.

## Capturas (C:\gnosis-wt\_caps\vfx7\)
- `antes_depois_<ataque>.gif` (ANTES em cima, DEPOIS embaixo) para solar, corrente, coroa,
  rei, salva, galila; `antes_*.gif`/`depois_*.gif` separados; quadros 1280×720 em
  `antes/<ataque>/` e `depois/<ataque>/`. O "antes" foi filmado num worktree temporário no
  commit-base ce14c55 com a MESMA vitrine (sem antecipação, que não existia).
- `depois/familias.png`: catálogo das 8 famílias + 4 formas (zoom 2,4).
- Atenção: nos GIFs "depois" a antecipação aparece porque a vitrine chama `charge_up`; no
  jogo ela só aparece quando os donos chamarem (pedidos em `docs/pedidos/vfx7.md`).

## O que NÃO ficou bom / falta
- Antecipação ainda não ligada no jogo (precisa de enemy.gd/boss_brain.gd/player.gd — pedidos).
- `chefes6` `ground_wave` (vida 2,2 s, sem `look`) cai na família `dark` em vez de `wave`
  até setar `look = "spike"` (pedido).
- Zonas de chão (`HazardZone` sono/veneno) seguem com o desenho antigo (arquivo do inimigos6).
- A nova da Coroa (raio 210) é um domo grande — forte, mas pode cansar; vale o João ver.
- Golpes corpo a corpo (`VfxLibrary.hit`) não foram redesenhados (foco era projétil/magia).
- Sem áudio novo (pedido ao Áudio). Feel em 60 fps reais só o João jogando dirá.

## Ferramentas
`tools/VfxShowcase7.tscn` — `gif <pasta> <ataque|all>` · `still <png>` · `perf <txt> [n] [noimpact]`
(ver cabeçalho do .gd). `tools/VfxShowcase.tscn` ganhou a fileira de impactos e antecipações.

## FASE 2 (19/10) — dono também de `scripts/entities/enemies/**`, `projectile.gd`, `hazard_zone.gd`
1. **Antecipação dos tiros dos inimigos — LIGADA no jogo.** A `EnemyOverlay` (frente) observa o
   estado do inimigo sem tocar no enemy.gd: ao ENTRAR em WINDUP com golpe `shot`/`burst`/`lob`
   (ou o antigo `attack_style == "ranged"`) chama `charge_up(inimigo, (16·dir, −8·escala), eye_color,
   tempo restante do wind-up, "dark")`; ao sair do WINDUP: `release()` se foi para STRIKE, `cancel()`
   se foi atordoado/parry/morte. Núcleo da carga corrompida menor (0,15) para não tapar o corpo.
   Chefes (BossBrain) não têm EnemyOverlay → pedido ao chefes6.
2. **Golpes CORPO A CORPO dos inimigos** — a mesma Overlay detecta a borda de subida da caixa do
   golpe (`attack_hitbox._active`) e chama `VfxLibrary.melee_slash(...)`: meia-lua que VARRE a caixa
   em 70 ms e some em 160 ms (swing/combo/grab/blink), riscos de velocidade (rush/dive/glide), anel
   deitado + poeira (leap/slam). Imparável = borda vermelha (forma + cor, R5). Cada golpe de combo
   ganha o seu rastro. O acerto na Sophia (`hitbox.gd` pinta com `Color(1, 0.45, 0.35)`) vira
   `VfxLibrary.claw_impact`: três garras de luz, anel corrompido, faíscas e borrifo escuro.
3. **HazardZone premium** (sono, veneno, coluna): anel deitado no surgimento; chão com 3 camadas de
   luz macia e borda que CINTILA; sono = névoa aditiva + bolhas lentas; veneno = bolhas que sobem +
   fumaça tóxica; zonas da Sophia ganham 6 pontos de luz girando; coluna = aviso que enche + pilar de
   luz aditivo que desce, anel, decalque e faíscas (no orçamento de flashes). Lógica intocada.
4. **Desempenho — os "4–6 ms" eram o DESENHO VETORIAL do próprio Projectile**: antes do gancho do
   inimigos6, o `_draw` antigo (8 círculos de rastro + halo + aro, por tiro) continuava rodando por
   baixo do visual novo (só ficava transparente). Prova: escondendo os projéteis o quadro caía de ~8 ms
   para ~2,8 ms; com o gancho `projectile_look` (o Projectile pula o `_draw` quando o VFX7 desenha) as
   chamadas de desenho caíram de 339 para ~127 e o quadro de **8,3 → 4,2–4,3 ms** (n=20, ~20
   impactos/s, médias de 2 rodadas). Somei: com visual premium o Projectile nem acumula rastro nem
   pede `queue_redraw`; o teto de VFX conta o grupo sem montar Array (`get_node_count_in_group`).
   Essas duas micro-otimizações NÃO deram ganho mensurável (A/B intercalado 4×4, dentro do ruído de
   ±0,7 ms) — ficam porque são trabalho a menos, sem mudar comportamento.

   | n projéteis | quadro médio | p95 | física | process | envio do desenho | GPU |
   |---|---|---|---|---|---|---|
   | 0 | 1,0 ms | 1,4 | 0,01 | 0,21 | 0,44 | 0,29 |
   | 20 | 4,2–4,3 ms | 4,9–6,1 | 0,12 | 0,82 | 1,15 | 0,72 |
   | 40 | 7,0–7,4 ms | 10,1–10,8 | 0,26 | 1,48 | 2,0 | 1,68 |

   (antes da fase: n=20 = 8,3 ms, n=40 = 12,8 ms.) O modo `perf` agora imprime essas fatias.
5. Capturas: `antes_depois_zonas.gif`, `antes_depois_garra.gif` (antes = commit e99ff1d, mesma
   vitrine); jogo real com criaturas atirando/carregando: `C:\gnosis-wt\_caps\vfx7\jogo2\t3_grid.png`,
   `t3_zoom.png`, `t5_grid.png` (0 SCRIPT ERROR). Os 6 GIFs de ataque foram refeitos com as faíscas do R15.

## QA7 (19/10) — bugs de inimigo que viraram meus (R5/R21) + ressalva R15 do Guardião
- **#8 poça fere no quadro em que nasce** → `HazardZone` hostil à Sophia ARMA por 0,5 s (`ARM_TIME`):
  cresce do centro com o contorno FINAL piscando rápido e só então fere/prende. As da Sophia valem na
  hora. Vale para a morte do Portador, o rastro de Belias, a névoa do Torpor e as sementes (`lob`).
  Captura: `C:\gnosis-wt\_caps\vfx7\f2_qa\zonas_strip.png`.
- **#9 aparição por trás com 0,25 s** → `EnemyMoves.BLINK_WIND = 0,6 s` (0,51 s com fúria) e a
  `EnemyOverlay` marca a aparição (redemoinho, anel deitado na cor do aviso, motes) + som do telegrafo.
- **#15 repulsa nunca sai** → alcance 60 → 90 px. Antes do último merge a EnemyProbe ainda media
  `repulsa=0` (intenção "orbe" guardada 2,5 s no enemy.gd); depois do merge de 19/10 mede
  `orbe=2 pilar=1 repulsa=1` e a sonda fica toda VERDE (111 PASS, 0 FAIL). O patch do `_intent` segue
  pedido ao polimento7 como reforço (1 uso em 7 s ainda é pouco).
- **#10 atiradores fogem para a borda** → coleira pronta (`EnemyAggro.leash_x`, `retreat_dir`: ≤ 230 px da
  Sophia e dentro de `arena_bounds` − 48); falta a chamada em `_desired_x`/recuo (enemy.gd, polimento7).
- **#12 Campeão fora da tela** e **#19 fúria < 0,4 s** → pedidos (level6/narrativa6 e polimento7).
- **R15 (ressalva do Guardião)** → `ImpactBurst.spawn(…, dir)` e `VfxLibrary.hit(…, dir)`: fagulhas em
  cone de ±50° no sentido do golpe (+20 % em 360°), talho alinhado ±15°, riscos vetoriais no cone. Sem
  `dir`, o ImpactBurst DEDUZ pelo lado da Sophia — o acerto corpo a corpo dela já sai direcional sem
  esperar ninguém; o polimento7 passa a direção exata pelo hitbox.gd (pedido).
- **Som (R4, Áudio7 6df9411, troca na fonte)** → um som por evento: carga = `charge_light/dark/king` no
  início (ChargeFX, sem fallback; agora no CATÁLOGO); tiro da Sophia = `proj_fire`; tiro hostil = só o
  `atk_*` do observador no strike (o `projectile.gd` não toca mais `proj_fire` nele).

## CHECAGEM DE SATISFAÇÃO (docs/handoff/NEURO_SATISFACAO.md)
- **R1 (alvo pisca/treme no hitstop):** não é VFX7 (flash/vibração ficam no enemy.gd/player.gd). Nada
  aqui atrasa ou cobre o flash do alvo: o clarão de impacto dura 100–160 ms, é aditivo e o corpo
  continua visível.
- **R4 (um acerto = um evento):** o impacto premium SUBSTITUI o genérico — `ImpactBurst` delega ao
  `ProjectileFX`/`claw_impact` e o `hit` do mesmo ponto/quadro é suprimido (`_claim`). Explosão da
  Esfera: 1 impacto + a onda do AoeNova (que é o raio do dano: informação).
- **R5 (telegrafo com forma + cor + som):** a carga dos tiros tem FORMA (círculo de espinhos fechando,
  motes convergindo) e som; o `tell_glint` continua ACIMA de todo VFX (Z+8 > Z). Rastro de golpe
  imparável = borda vermelha + mesma forma. Tiro inimigo ≠ tiro da Sophia pela forma (miolo escuro e
  espinhos × redondo e miolo branco), não só pela cor.
- **R10 (≤ 3 flashes/s, "Reduzir flashes"):** a borda da poça armando pisca a 2,9 Hz (`sin(_t*18)`). `flash_budget()` em todo clarão forte (impactos, coluna,
  coroa, nova grande): 3 inteiros por segundo, o resto a 30 %; a opção corta pela metade. O VFX7 não
  usa `screen_flash`.
- **R15 (faíscas na direção do golpe):** `_spray` e `hit(…, dir)` = cone de ±50° no sentido do golpe,
  levemente para cima, + ~20 % em 360°; talho do pesado alinhado (±15°). Vale para tiros, garras e o
  acerto corpo a corpo da Sophia (direção deduzida até o hitbox.gd passar a exata).
- **R17 (confirmação de morte):** `VfxLibrary.kill_confirm` abre o `enemy_death` (comum e Elite): estrela
  branca de 4 pontas em X + anel fino que abre em 140 ms + risco vertical de luz (a faísca saindo), ~120 ms,
  no orçamento de flashes. O acerto comum é fagulha/clarão redondo — o golpe que mata se lê diferente.
  (Hitstop +33 ms, som 2 semitons abaixo e contorno branco de 1 quadro continuam com combate/áudio.)
- **R18 (legibilidade):** medido nas capturas (luminância relativa, 90º percentil do efeito × mediana do
  fundo local): tiros novos **10,2–12,7 : 1** contra **6,0–9,0 : 1** antes (meta ≥ 3:1). Saturação forte só
  nos tiros/telegrafos; zonas de chão são translúcidas e ficam ATRÁS dos personagens (z −1).
- **§4 (excessos):** sem tremor novo (o VFX7 não chama `Juice.shake`; o da coluna já existia); sem
  empilhar VFX (R4); sem clarão de tela; cor nunca é o único aviso; nada de recompensa variável.
  Risco a observar no playtest: a nova da Coroa (domo de 210 px) e muitos tiros com rastro ao mesmo
  tempo — se cansar, baixar `halo_a`/`trail_w` em `AttackStyle.STYLES`.

## BILHETE PARA O SUCESSOR
- Branch `dir7/vfx7` (worktree `C:\gnosis-wt\vfx7`), com merge de origin/integracao/onda1 (19/10).
  Fase 2 fechada: antecipação/rastro dos inimigos (EnemyOverlay), HazardZone premium, perf medido.
- Arquivos-chave: `scripts/fx/attack_fx/*`, `assets/shaders/vfx_{orb,trail,ring}.gdshader`,
  `scripts/fx/vfx_library.gd` (blocos VFX7 depois de `nova_ring`: impactos, melee_slash, claw_impact),
  `scripts/entities/enemies/enemy_overlay.gd` (`_watch_attack`), `scripts/fx/hazard_zone.gd`,
  `scripts/fx/projectile.gd`, `tools/vfx_showcase7.gd` (`gif … all|fase2`, `still`, `perf`).
- Armadilhas: (1) no fragment de canvas o `COLOR` já vem × textura → use o `varying vcol`;
  (2) `projectile.gd` compara o retorno de `projectile_look` com `false` → tem que ser bool;
  (3) substituições por texto em `STYLES` — "0.4" casa com "0.45" (já mordeu uma vez);
  (4) o scratchpad é compartilhado entre agentes: use subpasta própria; (5) a vitrine roda também no
  commit antigo: chame função nova da VfxLibrary por `(VfxLibrary as Script).call(...)`;
  (6) medidas de quadro variam ±1 ms entre rodadas (outros agentes usam a máquina) — compare A/B intercalado.
- Próximo: conferir quando o polimento7 aplicar os patches (#10/#15/#19/R15) — rodar
  `tools/inimigos6/EnemyProbe.tscn` (repulsa > 0) e o QA7Bot (sem timeout nas telas 14/32/43/49);
  chefes6 ligar `charge_up` no BossBrain; ajustar depois do playtest do João.
