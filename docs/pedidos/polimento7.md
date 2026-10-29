# Pedidos / combinados do Polimento 7 (Onda 7)

## → chefes6 (enemy.gd compartilhado)
- O polimento7 mexe em `enemy.gd` SÓ em: `_fit_hurtbox()` / `_fit_hurtbox_geometry()` (hurtbox pelo
  `frame_geometry().body`), `FLASH_ADD`/`_flash` e o desligar das caixas em `die()`. Não toco nos ganchos
  `# chefes6`, nem em `_kit_*` / `_boss_*` / `_enter_phase*`.
- `stagger()`: o `set_deferred("monitoring", false)` de vocês (50a89eb) não é mais preciso — `Hitbox.deactivate()`
  agora é seguro dentro de sinal (corta o dano na hora com `_off` e desliga adiado). Se integrarem o de vocês,
  prefiram manter `attack_hitbox.deactivate()`: o `set_deferred` sozinho deixa o golpe ferir até o fim do quadro.
- **`_enter_phase()` (de vocês)**: `attack_hitbox.set_deferred("monitoring", false)` → trocar por
  `attack_hitbox.deactivate()` pelo mesmo motivo (QA7 #1).
- `boss_brain.gd` liga/desliga a `ContactHitbox` com `set_deferred("monitoring", …)` — continua funcionando
  (a ContactHitbox nunca passa por `deactivate()`).

## → audio7
- `player.gd`: 2º pulo toca `double_jump` (reserva `jump`), Queda Estelar `star_charge` (reserva `dive`),
  contra-ataque `riposte` no lugar do swing (reserva `_swing_sfx()`). A reserva só toca se `play_sfx` devolver
  false (som ainda fora do catálogo). Tirem os três do observador de vocês para não tocar 2×.

## → estab5 / técnico (`validate.ps1`)
- Entraram `FeelProbe` e `HitboxProbe` (modo rápido, `--fixed-fps 60`). Sugestão: pôr "Function blocked during
  in/out signal" no padrão `$fatal` para o bug do QA7 #1 não voltar calado.

## → vfx7 (`scripts/fx/projectile.gd`, arquivo de vocês) — ressalva R4 do Guardião (28/10)
- `projectile.gd:55` `Audio.play_sfx("proj_fire")` toca para TODO projétil. O tiro HOSTIL já soa na fonte
  (`atk_shot`/`atk_*` 1× por salva no enemy.gd/kit) → som em dobro (R4). Trocar por:
  ```gdscript
  if target_team == "enemy":          # só o tiro da Sophia; o hostil soa na salva (atk_*)
  	Audio.play_sfx("proj_fire")
  ```
- O cast da Sophia: a carga visual (`ChargeFX`) saiu MUDA no player.gd (silent antes do add_child). Se o
  `VfxLibrary.charge_up` ganhar um parâmetro `silent`, eu volto a usar a função.
