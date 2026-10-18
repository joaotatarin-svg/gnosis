# Pedidos da UI 6 (branch `dir6/ui6`, 18/10/2026)

Tudo o que a UI6 fez lê as APIs de vocês por `has_method`/`get` — funciona sem
vocês e liga sozinho quando os branches entram na integração.

## → mapa6
1. **Modo leitura oficial do WorldMap.** A pausa abre `WorldMap.tscn` por cima dela para só OLHAR.
   Hoje faço por fora (sem tocar no `world_map.gd`): troco o `_sub`, desligo o mouse do `_canvas`,
   troco o rodapé `InputGlyphs.Hint` e a pausa engole `ui_accept` no `_input` antes do mapa.
   Se vocês criarem `var read_only: bool` (o mapa não chama `choose_node`, rodapé "voltar", e
   talvez destaque o NÓ ATUAL em vez das saídas), eu já seto `read_only = true` se a propriedade
   existir. Sonda: `tools/UxShots6.tscn -- <pasta> mapa` (confirmar não troca de tela).
2. O título da tela no HUD/pausa usa `RunManager.node_kind()`/`node_title()` para
   `hazard/platform/sanctuary/challenge/secret` ("Fome · Arena"); Travessia comum segue "Travessia II".

## → level6
1. O ícone do objetivo lê `Level.zone_objective(zone_index)` com `zone_active`. Aceito
   `"totem"`, `"proteger"` e — se vier — `"mare"`/`"fuga"` (fuja da maré). Se o nome do objetivo
   da maré for outro, me digam (é uma linha em `scripts/ui/run_labels.gd`).
2. Os toasts de objetivo continuam valendo (o ícone fica enquanto a zona estiver trancada).

## → chefes6
- Barra lê `phase_marks` (um marcador por limiar; vira brasa quando a fase passa) e mostra
  "FASE III"/medalhão "III" com `boss_phase(3)`. `boss_bars()` agora devolve `marks` também.

## → narrativa6 (encenação)
- `hud.show_hint_now(segs)` existe (também aceita `show_hint_now(texto, teclas)`): fura a fila,
  dura 6 s, não encurta quando ela aperta a tecla, a dica interrompida volta para a fila.
  O `Staging.hint_now`/`level._tutor_hint` de vocês já chamam por `has_method` — nada a mudar.
- Retratos: "O Cego" (4 humores) e o Rei `revelado` (busto novo) já saem na DialogueBox.

## → progressao6
- HUD: emblema da relíquia em uso ao lado dos losangos da arma (acende quando a Brasa/Lâmpada
  agem numa faísca e quando troca); pausa mostra "Relíquia em uso · <nome>".
- Toast "Selo aberto · Arma Nv. N na loja" / "· <relíquia> na loja" / "· mais Vida e Éter na loja"
  quando `progress_tier()` sobe (sobrevive à troca de tela). Leio `WEAPON_TIER`, `has_relic`.

## → estab5 (QA)
- Incluir `res://tools/UxShots6.tscn` no `validate.ps1` (headless, ~25 s, `UX6 RESULT: N ok, 0 falha(s)`).
