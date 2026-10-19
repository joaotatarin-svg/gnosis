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

## BILHETE PARA O SUCESSOR
- Branch `dir7/vfx7` (worktree `C:\gnosis-wt\vfx7`), já com merge de origin/integracao/onda1
  (18/10). Último estado: relatório fechado, validate -Repeat 2 verde.
- Arquivos-chave: `scripts/fx/attack_fx/*`, `assets/shaders/vfx_{orb,trail,ring}.gdshader`,
  `scripts/fx/vfx_library.gd` (bloco VFX7 depois de `nova_ring`), `tools/vfx_showcase7.gd`.
- Armadilhas: (1) no fragment de canvas o `COLOR` já vem × textura → use o `varying vcol`;
  (2) `projectile.gd` compara o retorno de `projectile_look` com `false` → tem que ser bool;
  (3) substituições por texto em `STYLES` — "0.4" casa com "0.45" (já mordeu uma vez);
  (4) o scratchpad é compartilhado entre agentes: use subpasta própria.
- Próximo: quando inimigos6/chefes6/combate6 ligarem `charge_up`, filmar de novo no jogo
  (Shot `act=magic`) e ajustar duração/intensidade.
