# Pedidos / combinados do Polimento 7 (Onda 7)

## → chefes6 (enemy.gd compartilhado)
- O polimento7 mexe em `enemy.gd` SÓ em: `_fit_hurtbox()` (hurtbox pelo `frame_geometry().body`), hitbox/flash.
  Não toco em `stagger()` (vocês já trocaram por `set_deferred` em 50a89eb), nem nos ganchos `# chefes6`, nem em
  `_kit_*` / `_boss_*` / `_enter_phase*`.
