# Pedidos do UI7 (Onda 7) a outros diretores

## mapa7 — sons do mapa (pedido do Áudio7, `docs/pedidos/audio7.md` §"UI do integrador")
O `world_map.gd` está sendo mexido no `dir7/mapa7` (104 linhas de diferença); para não brigar no merge, o UI7
NÃO tocou nele. Peço ao mapa7 (ou a quem integrar depois dele) as 3 trocas de som, todas de 1 linha:
1. `_ready`: `CodexStyle.pop_in(_canvas, "ui_open", …)` → `"map_open"`.
2. `_confirm` (escolher nó): `ui_confirm` → `"map_select"` (as 2 chamadas).
3. `_confirm` (nó trancado): `ui_back` → `"map_locked"`.
A parte do `upgrade_menu.gd` (tirar o `shop_buy` do `_equip_relic`) foi feita no `dir7/ui7`.

## chefes6 / arte (QA7 #24, lado do mundo)
O HUD agora fica na CanvasLayer 20 (acima do mundo, da vinheta do cenário e do clarão de tela) e tem uma
sombra de leitura atrás do medalhão/barras e do nome do Éon. Se ainda assim algum anel/orbe de chefe
passar MUITO tempo atrás do medalhão (Rei na 68), o ideal é ele não nascer em y < 70 na faixa x < 230.

## Cinemática (QA7 #17/#23) — aviso ao dono de `scripts/fx/cinematic.gd`
Mexi SÓ em `_build_boss`/`_run_boss` (layout do card de chefe): faixa escura macia atrás do nome e do
subtítulo e subtítulo com quebra de linha. Pedido do chefe; o resto do arquivo ficou intocado.

## Estela (QA7 #30) — aviso ao dono de `scripts/entities/stela.gd`
Nada mudou no arquivo: o `StelaPanel` já usava `PauseStack.push/pop` (pedido da narrativa6 atendido). A sonda
`tools/ui7` confirma: árvore pausada, Sophia parada com velocidade forçada e despausa ao fechar.
O "paused=false" do MiscProbe provavelmente é da sonda (na tela 3 o J pode virar golpe se há inimigo perto; `can_read()` recusa) — não verifiquei a fundo.
