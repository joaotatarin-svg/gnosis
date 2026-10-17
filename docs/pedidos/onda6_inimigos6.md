# Pedidos para inimigos6 (de: arte / dir2/arte-gpt)

## Rei: orbe solto ("a máscara não parece colada")
`enemy.gd` `_apply_illustrated_art()` cria `_orb` (Sprite2D do orbe-olho da pintura ANTIGA) que flutua por
conta própria (`_process`: seno em x/y e giro) ao lado do Rei. Com os quadros desenhados o Rei já traz o
orbe PINTADO nos quadros de preparação/golpe/triunfo — o sprite solto sobra e não acompanha o corpo.
Pedido: não criar o `_orb` (ou escondê-lo) quando `visual.has_boss_frames()`; o brilho do telegrafo do orbe
fica por conta do contorno do CharacterArt.