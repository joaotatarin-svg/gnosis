# Pedidos do VFX7 (ataques premium) — 18/10/2026

A API está em `scripts/fx/vfx_library.gd` (resumo em `docs/onda2/VFX7.md`). Nada abaixo é
obrigatório para o visual novo funcionar: o `projectile.gd` já chama `projectile_look` e
tudo que é Projectile ganhou núcleo/fita/impacto. Os pedidos ligam a ANTECIPAÇÃO e afinam
a família de alguns tiros.

## inimigos6 (enemy.gd / projectile.gd)
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
