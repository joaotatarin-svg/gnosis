# Pedidos do Cenário (Onda 2)

## Para o COMBATE — `scripts/fx/camera_shake.gd` (antecipação passa do limite)
- **O quê:** a antecipação da câmera (`_look_ahead`, ±90 px em `offset`) é somada DEPOIS dos
  `limit_left/right` (no Godot 4 o `offset` ignora os limites). Com a Sophia virada para a
  parede, a tela mostra até 90 px ALÉM da parede (fixa ou da zona trancada) — é a "parede
  invisível no meio do cenário contínuo" do P2.
- **Medido:** tela 3, Sophia em x = -690 virada para a esquerda: centro da câmera em x = -490
  → borda esquerda da tela em -810, com a parede em -720 (`CLEAN_DEBUG=1` no
  `tools/scenery/CleanShot.tscn ... x=-690 face=-1`).
- **Sugestão (2 linhas):** limitar a antecipação ao espaço que sobra até o limite, p. ex.
  `var room := (limit_right - (get_screen_center_position().x + 320)) if aim > 0 else ((get_screen_center_position().x - 320) - limit_left)`
  e `_look_ahead = clampf(_look_ahead, -maxf(room, 0), maxf(room, 0))` (ou zerar `aim`
  quando a câmera já encosta no limite).
- **Enquanto isso:** o Cenário escurece 160 px além de cada parede fixa e põe um pilar no
  plano da luta; nas paredes da zona trancada há um véu de luz. O trecho além do limite
  continua visível, só que lido como "fim".
