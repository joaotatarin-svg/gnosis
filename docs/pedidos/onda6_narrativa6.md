# Pedidos para narrativa6 (de: arte / dir2/arte-gpt)

## Máscara/rachadura/olho do Rei presos ao quadro ("a máscara não parece colada")
`staging.gd` `_King._draw_over()` desenha a rachadura, o rosto preto com olho (o "disco preto") e a máscara
caindo em `Staging.HEAD` FIXO, enquanto o Rei agora troca de quadro desenhado (anda, respira) — o desenho
desliza em relação ao corpo. Duas opções (preferida a 1):
1. Usar os ESTADOS PINTADOS do atlas do Rei: `art.set_anim("mask_crack")` → `"revealed"` (sem desenhar o
   bloco `_blind`), `"dominion"` no roubo, `"triumph"`, `"sinking"` no colapso (detalhes em
   docs/onda2/ARTE_GPT.md, Pedido 8).
2. Se mantiver algum desenho por cima: prender na cabeça DO QUADRO com
   `var hp: Vector2 = art.head_point()` (coordenadas locais do `art`; `Vector2.INF` se faltar) →
   `over` em coordenadas de `_King`: `art.position + hp * art.scale` (respeitando `body.scale.x`).
Retrato do "…mãe?": `res://assets/painted/derived/portraits/cego_pequeno_olhando.png`.