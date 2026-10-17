# Pedidos da ENCENAÇÃO (Onda 3, branch `dir3/encenacao3`)

## 1. UI3 — campo `mood` nas falas (FEITO do meu lado; formato = o de `docs/pedidos/ui3.md` da UI)
Cada fala é `{speaker, text, cue?, mood?}`. `mood` é OPCIONAL; sem ele vale o neutro do falante.
Anotado em `scripts/autoload/narrative.gd` pelo helper `_m(fala, mood)`. Valores que uso (todos
da tabela da UI, sem acento):

| Falante | moods usados | onde |
|---|---|---|
| `Sophia` | `choque` · `triste` · `medo` · `determinada` · `ternura` · `serena` | roubo ("...Não." choque; "Eu chorei por eles." triste) · tentação da Fome "(Como ele sabe da janela?)" medo · Centro (medo → determinada) · Mente `final_pre` (medo → determinada) · 7º Anel (determinada, ternura) · anagnórise (determinada, triste, ternura ×3, determinada) · falas dos 3 finais (serena) · Velkar "...Tu choras por ele?" triste |
| `O Rei` | `regio` · `ironico` | tela 1: "Faísca perdida..." régio; "Mostra-me a tua" e a queda "(a máscara racha)" irônico |
| `Yaldabaoth` | `revelado` · `quebrado` | roubo depois da máscara cair e `final_pre` = revelado; "...mãe?" = quebrado |
| `Soter` | `triste` | 3º encontro (despedida) |
| `Velkar` | `arrependido` | o pai, "Todo dia. Era meu pai.", despedida |

- **A Voz NUNCA leva `mood`** (regra de ouro: retrato nenhum, nada a liga ao Rei antes da 64). As
  falas "A Voz" que saem da boca do Rei na cena B também ficam sem mood (o rótulo ainda é "A Voz").
- Legendas (`Gnosis.captions`) também podem trazer `mood` (7º Anel); a UI disse que a legenda aceita.

## 2. UI3 — `Staging.is_active()` (FEITO)
`scripts/levels/staging.gd`: `is_active() -> bool` = há cena dirigida (entre `play()` e o fim do
`_on_finished`), a descida do Centro (cena C, SEM caixa) ou uma ilustração de cena na tela. O
`Level` cria o nó como filho `Staging` (`level.stage()`); o HUD acha com
`get_tree().current_scene.get_node_or_null("Staging")`.

## 3. UI3 — dicas do HUD durante cena (C2)
Ainda visível nas minhas capturas de base (sem o branch da UI): "Q E trocar de Anel" e
"brilho amarelo: apare no tempo" por cima das cenas 64/68. A UI já esconde no `dir3/ui3`; conferir
depois do merge com o `is_active()`.

## 4. COMBATE3 — número de dano (C1)
Do meu lado a cena agora apaga os `DamageNumber` do Level ao abrir e na 1ª fala (o golpe final cria o
número DEPOIS de a morte do chefe abrir a cena). Se o Combate fizer o número ignorar a pausa, os dois
convivem.

## 5. TÉCNICO / QA — captura
`--position 4000,4000` NÃO esconde a janela nesta máquina: o Godot recoloca a janela dentro da área
dos monitores (medido: abriu em L=1486,T=761, metade em cada monitor). O João disse que gosta de ver
as capturas "no cantinho" — usar `--position 1200,600`.

## 6. CENÁRIO/TÉCNICO — pilar de primeiro plano sobre o Soter (tela 17)
Na tela 17 o Soter (no descanso do meio) fica atrás de um pilar escuro de primeiro plano (`fgcol` do
`scenery.gd`). Sugestão: não pôr pilar de primeiro plano a ±80 px de um `NpcEncounter`/`Sleeper`.
Prova: `C:\gnosis-wt\_caps\encenacao3\gif\npc_soter_depois.png`.

## 7. BALANCE — tela 68
A Mente agora é uma arena trancada de 940 px (antes a tela inteira) e o Rei pisca para o outro lado
quando as formas se empilham. Rodar o bot da 68 de novo.
