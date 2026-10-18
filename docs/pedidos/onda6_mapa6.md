# Pedidos do diretor de MAPA (Onda 6) — dir6/mapa6

Detalhes da API em `docs/onda2/MAPA6.md` §4.

## → level6 (layout)
1. Ler `RunManager.node_kind()` no layout da tela e dar CARA a cada tipo:
   - `hazard` (Passagem perigosa): chão traiçoeiro/espinhos/poças — o plano já vem com uma
     criatura a menos por wave.
   - `platform` (Escalada): plataformas e altura; espaço vertical para voadores (inimigos6).
   - `secret` (Sala secreta): só entra no grafo com o pulo duplo; a sala pode EXIGIR o pulo
     duplo dentro dela (baú alto). Nunca obrigatório antes do Soter.
   - `sanctuary`: um lugar de repouso visível (altar/fonte) — a cura é paga pelo mapa.
   - `challenge` (Arena): arena fechada, sem perigos gratuitos.
2. `_spawn_extras` usa `screen % k` — continua certo (uma tela por camada), mas se quiser
   extras POR TIPO, use `RunManager.node_kind()` e `RunManager.node_rng(salt)`.

## → narrativa6
1. Beats continuam por número de tela (toda rota passa por um nó de cada camada). Tabela
   de compatibilidade: `RunManager.beat_slot(screen)` ⇔ `screen_for_slot(slot)`.
2. Sugestão: 1 fala curta da Voz/Sophia ao entrar num santuário, Arena ou segredo
   (`RunManager.node_kind()`); e uma fala do Soter na cena do pulo duplo apontando que
   "há passagens que só se alcançam com asas" (o mapa mostra os segredos selados com
   cadeado desde o Torpor — texto do mapa: "Selado: exige o pulo duplo. Quem dá asas não luta.").

## → progressao6
1. Expor `Progression.has_double_jump()` (contrato da onda). O mapa já o consulta.
2. Calibrar `EonMap.REWARDS` (scripts/levels/map/eon_map.gd — pode editar só a tabela ou me
   pedir): hoje combate +6+3×Éon faíscas; Arena +30+10×Éon e +8 vida; segredo
   +20+6×Éon, +10 vida, +10 Éter; perigo +5 vida; escalada +5 Éter; santuário cura.
   As de vida/Éter usam `buy_max_health/mana(n, 0)` — se mudar a regra dos bônus, me avise.

## → ui5
1. HUD/pausa: mostrar o tipo do nó (`RunManager.node_title()`), ex.: "Fome · Arena".
   `GameManager.screen_title` hoje diz "Travessia II" para qualquer tipo.
2. Pausa: botão "Mapa" que abre `WorldMap` em modo leitura seria bem-vindo (hoje a tela
   só aparece quando há escolha).

## → estab5 (QA)
1. Incluir `res://tools/map6/MapQA.tscn` no `tools/validate.ps1` (headless, ~30 s, usar
   `--fixed-fps 60`).
2. Ferramentas que percorrem o run (`reg_r1`, `sonda_corrida`…) param na tela de mapa:
   setar `RunManager.map_route_seed = 0` nelas (rota do meio = run de antes).
