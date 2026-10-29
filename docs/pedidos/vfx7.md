# Pedidos do VFX7 (ataques premium) — 18/10/2026

A API está em `scripts/fx/vfx_library.gd` (resumo em `docs/onda2/VFX7.md`). Nada abaixo é
obrigatório para o visual novo funcionar: o `projectile.gd` já chama `projectile_look` e
tudo que é Projectile ganhou núcleo/fita/impacto. Os pedidos ligam a ANTECIPAÇÃO e afinam
a família de alguns tiros.

## inimigos6 (enemy.gd / projectile.gd) — FEITO pelo VFX7 na fase 2 (19/10)
A antecipação dos tiros e o rastro dos golpes corpo a corpo foram ligados pela EnemyOverlay
(sem mexer no enemy.gd); HazardZone e Projectile agora são do VFX7. Itens abaixo ficam como histórico.
1. **Antecipação dos tiros** — no começo do wind-up de golpe à distância (`_begin_windup`,
   ou onde o move "shot"/"burst" começa):
   ```gdscript
   if attack_style == "ranged" or String(_mv.get("kind", "")) in ["shot", "burst"]:
       _charge = VfxLibrary.charge_up(self, Vector2(16.0 * atk_dir, -14.0 * _art_scale), eye_color, wind_up, "dark")
   ```
   e `if _charge and is_instance_valid(_charge): _charge.cancel()` quando o golpe é
   interrompido (stagger/parry/morte). Ele estala sozinho no fim de `wind_up`.
2. `projectile.gd` linha `return r != null and r != false`: funciona porque o VFX7 devolve
   **bool**; se um dia trocarem, use só `return r == true`.
3. (opcional) `HazardZone` sono/veneno: dá para usar `VfxLibrary.ground_decal` +
   `shock_ring(..., squash 0.3)` no surgimento para casar com os impactos novos.

## chefes6 (boss_brain.gd / boss_*.gd)
1. `BossBrain.ground_wave`: `p.look = "spike"` antes do `add_child` (sem isso a onda vira um
   orbe corrompido comum — a vida mudou de 1,8 para 2,2 s e a dedução antiga não pega).
2. `BossBrain._fire`: antecipação no wind-up do move de tiro:
   `VfxLibrary.charge_up(e, Vector2(24.0 * dir * e._art_scale, ground_y() - e.global_position.y - 34.0), cor, wind_up, "king" if e.kit == "rei" else "dark")`
   (mesmo ponto de onde o tiro sai). O orbe do Rei já é reconhecido pela luz dourada
   `LIGHT` (família `king`); para forçar: `p.set_meta("vfx_kind", "king")`.
3. Astaphaios `_bounce_volley`: se quiser cara de vidro, `p.look = "page"` ou
   `set_meta("vfx_kind", "chain")`.

## combate6 (player.gd)
1. **Antecipação das magias** (decisão de gameplay de vocês): chamar
   `VfxLibrary.charge_up(self, Vector2(18.0 * facing, -6.0), skill.color, 0.2, "light")` no
   instante do cast e soltar o projétil 0,2 s depois (Esfera/Corrente) — ou só chamar com
   0,12 s sem atrasar nada (fica um "piscar" de carga). Hoje o cast é instantâneo.
2. A assinatura de cada Anel e a aura do Reflexo já tocam via `VfxLibrary.cast` (pela cor).

## Áudio
Dois sons curtos (0,2–0,5 s, sobem de tom): `charge_light` (Sophia: cristalino) e
`charge_dark` (Arcontes: grave, com chiado). O `ChargeFX` já toca se o nome existir no
`CATALOG`; enquanto não existe, usa `proj_fire` grave a −9 dB.

## Desempenho
Com 20 projéteis no ar, ~4–6 ms do quadro não é desenho (escondendo os projéteis o quadro
cai de ~8 para ~2,8 ms). Vale perfilar `Projectile` (física da Area2D, `queue_redraw`
mesmo com `_premium`, impactos com `Juice.hit_stop`) — ver `tools/VfxShowcase7 perf`.

## polimento7 (enemy.gd) — fase 2
- Nada obrigatório. Se mexerem em `attack_hitbox` (nome, `_active`, `box_size()`) ou nos estados
  WINDUP/STRIKE, avisem: a `EnemyOverlay._watch_attack` lê esses campos para ligar a carga e o rastro.

## combate6 (hitbox.gd) — fase 2
- R15 completo no acerto de inimigo: se o `ImpactBurst.spawn` receber o lado do golpe (ex.: um
  parâmetro `dirx`), o `claw_impact` passa a soltar as faíscas no sentido do golpe. Hoje sai em 360°.

## QA7 (19/10) — o que o VFX7 já fez e o que depende de outros

Feito nos meus arquivos: #8 (poça arma 0,5 s, `hazard_zone.gd`), #9 (`BLINK_WIND` 0,6 s em
`enemy_moves.gd` + marca visível/sonora da aparição na `EnemyOverlay`), #15 (repulsa até 90 px — ainda
não basta, ver polimento7 item 2), coleira pronta em `EnemyAggro.leash_x/retreat_dir` (#10, falta a chamada).

### polimento7 (`enemy.gd`) — patches exatos
1. **#10 coleira (R21).** Em `_desired_x`, ramo `"shooter"` e ramo `"flyer"`: embrulhar o retorno em
   `EnemyAggro.leash_x(self, …)`. Ex.: `return EnemyAggro.leash_x(self, px + side * 175.0)`; no
   `return global_position.x` do atirador também (`EnemyAggro.leash_x(self, global_position.x)`: puxa de
   volta quem já está fora). No RECUO (`_start_move`, `kind == "retreat"`): depois de calcular `away`,
   `away = EnemyAggro.retreat_dir(self, away)`.
2. **#15 repulsa nunca sai.** O atirador guarda a INTENÇÃO (`_intent`, 2,5 s) escolhida de longe ("orbe");
   quando a Sophia cola, o orbe não cabe e ele só foge. Em `_chase_moves`, no bloco
   `if role == "shooter" and adx < 70.0:` acrescentar `_intent = {}` (o `_pick_move(…, true)` devolve o
   golpe de reação "nova" na hora). Medido com `tools/inimigos6/EnemyProbe.tscn`: `repulsa=0` em 40 s.
3. **#19 Elite fúria corta o aviso abaixo de 0,4 s (R5).** Em `_start_move`:
   `wind_up = float(mv.wind) * (0.85 if fast else 1.0)` →
   `wind_up = maxf(float(mv.wind) * 0.85, minf(float(mv.wind), 0.42)) if fast else float(mv.wind)`.
4. **R15 (Guardião) — direção do golpe no impacto.** `ImpactBurst.spawn(parent, pos, col, heavy, dir)`
   ganhou `dir: Vector2` (quem bate → quem apanha). No `hitbox.gd` (linha do `ImpactBurst.spawn`):
   passar `Vector2(signf(area.global_position.x - owner.global_position.x), 0.0)` (ou a direção que vocês
   já calculam, com y para o launcher/mergulho). Sem `dir`, o ImpactBurst DEDUZ pelo lado da Sophia (já
   funciona para golpes no chão), mas a direção certa é a de vocês. O mesmo vale para
   `VfxLibrary.hit(parent, pos, true, cor, dir)` em `player.register_hit` (pesado) e em
   `enemy._on_hit_received` (pesado/magia): passem a direção do golpe.
5. **Arte (baixa prioridade):** quando `visual.has_own_art()` for verdadeiro, pular a tinta do tipo e a
   graduação (`GRADE_SHADER`) do interino — hoje o CharacterArt desfaz sozinho.
6. Avisem se mudarem `attack_hitbox._active`, `box_size()`, os estados WINDUP/STRIKE ou `_mv`: a
   `EnemyOverlay._watch_attack` lê esses campos (carga dos tiros, rastro dos golpes, marca da aparição).

### level6 (`level.gd`) + narrativa6 — #12 Campeão fora da tela
- O Campeão é o `eon_bot` da última wave do Desafio; da 2ª wave em diante a wave nasce na BORDA
  (`from_edge`: `c + ZONE_TRIGGER − 10 − i·34`) ou, se voa, em `AIR_SPAWN_Y` com ±200 px — por isso
  x≈888 no ar, >4 s para entrar. E o `_champion_card()` é chamado no MESMO quadro do spawn.
  Pedido: (a) o Campeão nasce DENTRO do enquadramento (ex.: `c ± 120`, no chão, mesmo voador) e
  (b) o card só sai quando ele estiver na tela (ou atrasar o card ~0,6 s e entrar com `VfxLibrary.boss_appear`).

### Áudio7 — um som por evento nos tiros (FEITO na fonte, 19/10, merge de 6df9411)
- Seguindo o `docs/pedidos/audio7.md` (decisão do chefe): `projectile.gd` toca `proj_fire` SÓ no tiro da
  Sophia; o tiro hostil soa pelo `atk_*` do observador no strike; a carga soa `charge_light`/`charge_dark`/
  `charge_king` no INÍCIO (ChargeFX, sem fallback). Durações reais da carga: criaturas = o wind-up do golpe
  de tiro (0,5–0,6 s); Sophia/Rei só quando combate6/chefes6 ligarem (pedido: Rei ~0,9 s). O pedido
  anterior "tirar atk_* dos tiros" fica CANCELADO.
