# Pedidos do Técnico2 (Onda 2b) a outros agentes

Tudo abaixo já existe no branch `dir2/tecnico2` (QA: `res://tools/tecnico/TecnicoQA.tscn`).
Chame com `has_method`/`has_signal` para compilar sem este branch.

## UI-MENUS2
1. **Desbloqueios (#26)** — `CodexSession.is_unlocked(boss_index) -> bool` e
   `CodexSession.unlocked_bosses() -> Array[int]` (Provação só lista vencidos na CAMPANHA;
   Provação não libera nada). Bestiário/Galeria: `Bestiary.seen(id) -> bool`,
   `Bestiary.seen_ids()`, sinal `Bestiary.seen_changed(id)`. Chefes: `Progression.is_boss_beaten(id)`
   (ids: `rei`, `arconte_sono` … `arconte_coroa`, `demiurgo`). Save antigo sem a chave:
   deduzido da melhor tela.
2. **Opções novas (#34)** — chaves JÁ no `GameManager.SETTINGS_DEFAULT` (sem isto o load
   descartava): `text_speed` (float: 0.5 / 1.0 / 2.0; **0.0 = instantâneo**), `damage_numbers`
   (bool), `window_mode` (int: 0 janela · 1 tela cheia exclusiva · 2 tela cheia sem borda) e
   `bindings` (Dictionary ação → o formato que o `input_rebind.gd` quiser; precisa sobreviver a
   JSON: números voltam float). Modo de janela: use **`GameManager.set_window_mode(m)`** (acerta
   também o `fullscreen` antigo e aplica). O `apply_settings()` chama
   `scripts/ui/input_rebind.gd` → `apply_bindings(dict)` (instância nova; função estática serve)
   quando `bindings` não está vazio. Depois grave com `SaveManager.save_game()`.
3. **Fim da demo (#27)** — sinal `GameManager.demo_finished` (emitido UMA vez, ao sair da tela 10
   depois do Athoth; o run já foi encerrado e o "Continuar" apagado). `GameManager.demo` diz se é
   demo. Quem liga o card precisa estar vivo nessa hora (sugestão: autoload/overlay criado no
   `_ready` do menu ou ligar em `SceneManager`); **sem nenhum ligado** o GameManager cai na
   `EndScreen.tscn` com `end_title = "Fim da demo"`. URL da loja: `ProjectSettings
   gnosis/store_url` (hoje `""` — o João define; esconda o botão se vazio).
   O fallback (EndScreen) mostra hoje o cabeçalho "A faísca se apagou" e "Tentar de novo"
   (`/home/user/caps/tecnico2/demo_fim_fallback.png`): com `GameManager.demo`, a EndScreen
   deveria trocar o cabeçalho e o botão (é arquivo da UI).
4. **Conquistas (#49)** — `Achievements.entries()` ([{id,title,desc,hidden,unlocked}]),
   `unlocked_count()/total()`, sinal `Achievements.unlocked(id)` (para um toast; o HUD tem
   `toast(msg)` no grupo `hud`). Tela de conquistas é opcional (a Steam mostra as dela).

## UI-HUD2
- Toast de conquista: ligar `Achievements.unlocked(id)` → `AchievementData.find(id).title`.
  Não liguei daqui para não mexer no HUD.

## ENCENACAO2 (`final_battle.gd`)
- `RunManager.screen_rng(68)` → `RandomNumberGenerator` próprio da tela (mesma sequência todo
  run, imune ao `randi()` global do Áudio/VFX). Pegue UMA vez no `_ready` e use no lugar do
  `randi()`/`randf()` (BALANCE §3). `screen_rng(tela, sal)` dá sequências independentes.

## BALANCE
- Checkpoint (#3) mudou: morte volta para chegada (offset 0), Desafio/santuário (4) ou antessala
  (7), o maior já alcançado. Morrer no Arconte agora custa 1 tela (antessala), não 8. Vale medir
  de novo o custo da morte com o bot (os −20% de faíscas continuam).

## COMBATE2
- Feito: `ComboData.hitstop: float = 0.0` (pedido 5 da Onda 2).

## Chefe / João (decisões)
- **Steam** (o que falta para conquistas/Cloud/rich presence) está no topo de
  `scripts/autoload/achievements.gd`: plugin GodotSteam (lib externa → decisão), App ID da demo
  e do jogo, cadastrar os API names `ACH_<ID>` e ícones, Auto-Cloud nas pastas do user dir.
- `gnosis/store_url` vazio no `project.godot`.
- Preset "Windows Demo" (`custom_features="demo"`, `builds/demo/GNOSIS-Demo.exe`) — não exportei
  o .exe (sem templates aqui); o `.pck` da demo foi exportado e, rodado, liga a demo.
