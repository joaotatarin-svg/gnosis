# Pedidos do agente UI-MENUS (Onda 2) a outros agentes

Os menus já reagem às AÇÕES (`ui_accept`, `ui_cancel`, `pause`); estes pedidos
fecham o que depende de arquivos de outros donos. Tudo abaixo já está no brief
de quem recebe — aqui só fica registrado o contrato que o código dos menus usa.

## Técnico
1. **B1** — `ui_accept` += `JOY_BUTTON_A`, `ui_cancel` += `JOY_BUTTON_B`. Sem
   isso o B não volta em nenhum menu (a sonda `tools/ui_menus/MenuProbe.tscn`
   mapeia os dois SÓ dentro dela para testar; imprime "UIM nota: … mapeado só
   nesta sonda" enquanto o InputMap não tiver).
   A Estela ignora `ui_accept` quando o evento também é `jump` (A/Espaço), então
   mapear o A em `ui_accept` não faz o pulo abrir a pedra.
2. **`reduce_flashes`** em `GameManager.SETTINGS_DEFAULT` (bool, false). Hoje o
   `SaveManager.load_game()` só lê chaves do SETTINGS_DEFAULT: a opção é gravada
   pelo menu mas VOLTA a "Desligada" ao reabrir o jogo até a chave existir lá.
   `apply_settings()` espelhar em `Juice.reduce_flashes` (o menu já espelha na hora).
3. **REVISAO #13** — o menu de Opções grava SÓ com `SaveManager.save_game()`
   (sem caminho direto). Opções mudadas na Provação dependem do SaveManager
   gravar as opções com o save do run desligado. Conferir com
   `MenuProbe.tscn -- <pasta> opcoes_provacao` depois da integração.
4. **SceneManager** — `PauseStack.clear()` ao trocar de cena (o brief já pede).
   A pausa/loja/Provação já chamam `clear()` antes de sair para o menu.

## UI-HUD (`dialogue_box.gd`) e Encenação (`cinematic.gd`)
- Enquanto esses dois escreverem `get_tree().paused` direto, um diálogo que
  fecha com a loja ou a pausa abertas DESPAUSA o mundo por baixo delas (REVISAO
  #10). Pausa, loja, Estela e Provação já estão na `PauseStack`.

## Combate (`juice.gd`)
- Campo `reduce_flashes: bool` no Juice. O menu escreve com
  `if "reduce_flashes" in Juice: Juice.set(...)`.
