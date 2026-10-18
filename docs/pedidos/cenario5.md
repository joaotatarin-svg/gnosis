# Pedidos do CENÁRIO 5 (branch `dir5/cenario5`)

## 1. LEVEL6 / NARRATIVA6 — tela 17: Estela, Selos e Soter no MESMO descanso (QA2 #3, 2ª metade)
O cenário já não põe pilar sobre ninguém, mas a 17 continua amontoada: Estela em `rest-200`
(`Gnosis._stela_pos`), Soter no descanso do meio (`level.gd` `_spawn_extras`) e Selos em
`último descanso +170` — na 17 (2 zonas) os três caem no descanso x=1370 (Estela 1170, Soter 1370,
Selos 1460–1630) e o texto "OS TRÊS SELOS / golpeie na ordem…" fica em cima da cabeça do Soter.
Sugestão: com encontro de NPC na tela, Selos vão para o descanso 0 (ou a tela não sorteia Selos) e a
Estela para o outro lado do descanso. Prova: `C:\gnosis-wt\_caps\cenario5\depois_17.png`.

## 2. LEVEL6 — como avisar o cenário de "faixas proibidas para primeiro plano"
Sem editar `scenery.gd`, o layout informa o que a coluna de primeiro plano não pode cobrir:
- pôr o nó (Node2D) no grupo **`fg_guard`** (meia-largura em `set_meta("fg_half", px)`, padrão 80);
- ou definir no Level a variável **`fg_forbidden: Array`** de `Vector2(x0, x1)` (x de mundo).
Tem de estar pronto até o fim do quadro do `_ready` do Level (o cenário escolhe as colunas
com `call_deferred`). O que nascer depois não move a coluna — só a faz sumir quando passa por cima.
Detalhes: `docs/onda2/CENARIO5.md`.
