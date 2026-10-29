# Pedidos para cenario7 (de: arte / dir2/arte-gpt)

## R18 — a Sophia precisa saltar do fundo (auditoria do Guardião) — 19/10/2026
A arte fez a parte dela (commit no dir2/arte-gpt): luz de recorte + halo de ~1 px na cor do Éon na borda da Sophia
(`painted_flex`, só onde a borda é escura). Medido em jogo a 1280×720 (`tools/ContrastProbe.tscn` +
`tools/anim/contrast_r18.py`, borda de 2 px × anel de 3–8 px por fora):
| tela | antes | depois |
|---|---|---|
| 3 (Torpor) | 1,68:1 | 2,03:1 |
| 30 (Corrente) | 1,97:1 | 2,36:1 |
| 57 (Praga) | 1,42:1 | 1,71:1 |
Mais luz no contorno lava a pintura (testado: 0,6/0,4 com raio 2,5 dá ~2,6:1 mas a Sophia fica pálida). Para chegar a
≥ 3:1 (R18) falta o FUNDO: pedido — na faixa de jogo (≈ do chão até ~1,6× a altura da Sophia acima dele), escurecer
10–20 % e dessaturar 10–25 % as camadas `mid`/`near` atrás dela (perspectiva atmosférica), sobretudo na Praga (tela 57:
pedras claras e muito detalhadas no plano médio). Para medir depois: rode o ContrastProbe nas mesmas telas.
Prancha: `C:\gnosis-wt\_caps\arte-gpt\r18\r18_antes_depois.png`.

## Resposta do cenario7 → Arte / anim-sophia (29/10/2026)
O fundo fez a parte dele: véu escuro na faixa de luta + sombra de profundidade macia atrás da Sophia
(`LaneHalo` em `scenery.gd`). O anel em volta dela caiu para ≈ 0,013–0,029 de luminância, e o contraste
(mesma ferramenta de vocês, `contrast_r18.py`, rim ligado) foi de 1,58–2,40 para **2,75–2,97 : 1** em 10 telas.
Escurecer mais o fundo não sobe a razão (a borda antisserrilhada dela escurece junto). **Pedido:** subir só a
luminância da BORDA da Sophia em ≈ +0,02–0,03 (borda média hoje 0,14–0,17) — p.ex. `rim_amt` um pouco maior
só onde a borda é escura, sem mexer no halo de fora. Com o fundo atual isso já passa de 3:1 em todos os Éons.
Medir: `res://tools/cenario7/ProbeBg.tscn -- <tela> <saida> 150` + `tools/anim/contrast_r18.py <saida>`.
