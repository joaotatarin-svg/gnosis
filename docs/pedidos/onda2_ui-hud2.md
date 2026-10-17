# Pedidos do UI-HUD2 (Onda 2b)

## Para o UI-MENUS2
- `settings["text_speed"]`: a DialogueBox e a legenda leem como MULTIPLICADOR (0,5 / 1 / 2) e tratam
  `0`, valor ≥ 10 ou texto começando com "inst" como instantâneo (também aceitam "2x"). Se a Opção gravar
  outro formato (ex.: índice 0..3), avise: a leitura está em `DialogueBox.text_speed()`.
- `InputGlyphs`: uso (por `load()`, compila sem o arquivo) `label(ação, dev)`, `is_pad()`, `device()`,
  `note_event(ev)`, `icon_width(ação, h, null, dev)`, `draw_icon(ci, centro, ação, h, null, dev, alpha)`.
  Testado com a cópia de 07:42 do seu worktree. Se mudar essas assinaturas, avise.

## Para a ENCENACAO2
- #21 (feito na UI, `caption_bar.gd`): na 1ª vez que uma barra de chefe/Campeão aparece na tela, a legenda no
  ar sai e a fila enfileirada ANTES (chegada da tela) é DESCARTADA. Consequência: as falas de chegada das telas
  de chefe (ex.: tela 1, "As cinzas ainda estão quentes. Anda: a névoa não espera ninguém.") não aparecem mais
  se o chefe entra antes de elas tocarem. Se quiser alguma delas depois da queda, enfileire no gancho da morte do chefe.
  Falas que nascem DURANTE a luta (fase 2, 7º Anel, ecos) passam normalmente.
- #22 (modo `narration` da DialogueBox): fala sem falante com o texto todo entre parênteses vira rubrica sem caixa,
  em itálico, sem os parênteses. Escura (tela ~preta) só na 1ª fala da caixa com cue vazio/"heartbeat"/"wait_2s"
  (abertura `intro()`, Centro); nas outras, véu leve na base e a cena visível (roubo, anagnórise, finais).
  Para forçar: campo `dark: true/false` na fala; `mode: "narration"` força o modo mesmo com falante.
- Dica do duelo do Rei (seu item 2): use `hud.show_hint([{keys:["block"], text:"apare"}])` (grupo "hud") — já mostra o
  ícone do dispositivo em uso. Legenda durante a luta também aparece (nasce na luta), mas compete com o combate.

## Para o COMBATE2
- Números de dano são desenhados em `scripts/fx/damage_number.gd` (seu). Respeitar
  `GameManager.settings.get("damage_numbers", true)` fica com você (item 4 do seu brief); a UI não desenha dano.
