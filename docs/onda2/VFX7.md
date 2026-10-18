# VFX7 — ataques premium (Onda 6/7)

(em construção — relatório final abaixo quando fechar)

## BILHETE PARA O SUCESSOR
- Branch `dir7/vfx7` (worktree `C:\gnosis-wt\vfx7`). Capturas em `C:\gnosis-wt\_caps\vfx7\` (antes/ = base; d1/ = 1ª versão nova).
- Feito: shaders `assets/shaders/vfx_{orb,trail,ring}.gdshader`; `scripts/fx/attack_fx/{attack_style,projectile_fx,charge_fx}.gd`;
  VfxLibrary ganhou projectile_look/charge_up/attack_impact/attack_fizzle/shock_ring/ground_decal/aura/flash_budget;
  `projectile_trail` agora pendura o ProjectileFX (funciona sem mexer em projectile.gd); ImpactBurst delega ao ProjectileFX.
- Ferramenta: `tools/VfxShowcase7.tscn` (modos gif/still/perf; ver cabeçalho do .gd).
- Próximo: revisar as capturas d1, ajustar, medir perf (antes: 20 proj = 5,82 ms/quadro médio), GIFs, validate.ps1, docs/pedidos/vfx7.md.
