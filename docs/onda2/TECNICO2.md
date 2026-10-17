# Onda 2b — TÉCNICO2 (dir2/tecnico2) — relatório

## 1. Commits
- `ba39787` WIP: checkpoints no santuário/antessala, demo, desbloqueios, screen_rng, conquistas, tela cheia na 1ª execução
- `3d27ef7` TecnicoQA (checkpoints com morte real, Continuar, 1ª execução, demo, desbloqueios, screen_rng, conquistas) no validate.sh
- `3897f67` TecnicoQA no validate.ps1 + pedidos da Onda 2b
- `6985032` ferramenta de captura do fim da demo (fallback) + pedido à UI
- (último) Bestiário não grava no meio da tela; este relatório

## 2. O que mudou
- **#3 Checkpoint** `run_manager.gd`: `checkpoint_for()` devolve o último checkpoint ALCANÇADO no
  Éon: chegada (offset 0), Desafio/santuário (4) e antessala (7). Morrer no Arconte 19 volta para
  18, não para 11. "Continuar" usa a mesma conta (o run é linear). O custo continua −20% de
  faíscas (no `level.gd`, sem mudança). `is_checkpoint(tela)` novo; o texto da pausa
  ("ponto de retorno salvo") já usa `checkpoint_for` e mostra a tela certa.
- **#24 Tela cheia na 1ª execução** `game_manager.gd`/`save_manager.gd`: sem nenhum save
  (nem .tmp/.bak), `window_mode = 2` (tela cheia sem borda) + `fullscreen = true`. Com save,
  nada muda. Ferramentas (cena na linha de comando ou argumentos depois de `--`) ficam em janela,
  para o Shot/QA não abrirem em tela cheia na máquina do João.
- **Opções novas** em `SETTINGS_DEFAULT` (sem isso o load descartava o que a UI gravasse):
  `window_mode`, `text_speed`, `damage_numbers`, `bindings`. `set_window_mode(m)` mantém
  `fullscreen` (menu antigo) e `window_mode` (menu novo) coerentes. `apply_settings()` chama
  `scripts/ui/input_rebind.gd → apply_bindings(dict)` se o arquivo existir.
- **#27 DEMO** `game_manager.gd`: `GameManager.demo` liga por `--demo` (antes ou depois de `--`),
  pela feature de export `demo` ou por `gnosis/demo=true`. Passar da tela 10 (Athoth) encerra o
  run, apaga o "Continuar" e emite `GameManager.demo_finished`; sem ninguém ligado, cai na
  EndScreen com "Fim da demo". Save, Crônicas e conquistas da demo em `user://demo/`.
  `project.godot`: seção `[gnosis]` (`demo=false`, `demo.demo=true`, `store_url=""`).
  `export_presets.cfg`: preset "Windows Demo" (`custom_features="demo"`,
  `builds/demo/GNOSIS-Demo.exe`).
- **#26 Desbloqueios**: `Progression.bosses_beaten` (meta, não zera no `reset_run`), sinal
  `boss_beaten`, `record_boss_beaten()` (ignora Provação e fora de run), marcado no `add_ring` e ao
  sair de tela de chefe (Rei incluído; Demiurgo na vitória final). `CodexSession.is_unlocked(i)` /
  `unlocked_bosses()`. `Bestiary.seen(id)`/`mark_seen`/`seen_ids`: todo `Enemy` que entra na árvore
  durante a campanha marca o tipo (via `node_added`, sem tocar no enemy.gd). Os dois vão ao save
  (`bosses_beaten`, `bestiary_seen`) e ficam intactos na Provação. Save antigo sem a chave:
  deduzido da melhor tela e dos finais.
- **Determinismo**: `RunManager.screen_rng(tela, sal=0)` → `RandomNumberGenerator` semeado pela tela.
- **#49 Conquistas**: `scripts/data/achievement_data.gd` (21 conquistas: Rei, 7 Arcontes, Athoth
  sem cair, Arconte sem dano, arma no máximo, 4 Adormecidos, 1ª Estela, 18 Estelas, Bestiário,
  7 cacos, 3 finais, os 3 finais, final no Difícil+; nada de sorte nem de "volte amanhã") e autoload
  `Achievements` (`scripts/autoload/achievements.gd`, registrado no `project.godot`): grava em
  `user://achievements.json`, sinal `unlocked(id)`. O que falta para a Steam está no topo do arquivo.
- `ComboData.hitstop` (pedido do Combate). `gnosis.gd`: caminho da demo + aviso às conquistas.
- QA nova `tools/tecnico/TecnicoQA.tscn` (36 verificações; no `validate.sh` e no `validate.ps1`,
  com `--fixed-fps 60`). Grava só em `user://qa/tecnico/` e confere no fim que o save real ficou
  igual byte a byte.

## 3. Capturas
- `/home/user/caps/tecnico2/demo_fim_fallback.png`: fim da demo SEM a UI ligada — a EndScreen com
  "Fim da demo / Obrigado por jogar…". Prova que não trava; também mostra o problema: o cabeçalho
  "A faísca se apagou" e o botão "Tentar de novo" são da tela de morte (pedido à UI).
- O resto não tem mudança visual (checkpoint, save, desbloqueios, RNG, conquistas). Não capturei
  a tela cheia: sem monitor de verdade a captura não prova nada.

## 4. Validação
`TIMEOUT=900 tools/validate.sh` (rodada completa):
```
Scripts        OK        11s  pass=0  code=0
ScriptCheck    OK         8s  pass=0  code=0
CodexQA        OK        16s  pass=53  code=0
AudioQA        OK        19s  pass=46  code=0
GnoseQA        OK        20s  pass=18  code=0
SaveQA         OK         3s  pass=41  code=0
PuppetQA       OK         2s  pass=0  code=0
HeroQA         OK         2s  pass=0  code=0
WaveQA         OK         2s  pass=0  code=0
TecnicoQA      OK         4s  pass=36  code=0
TUDO VERDE
```
`tools/regressao/run_all.sh`: **PASS: 10/10** (B1 A1 A2 A3 A4 A5 A6 R1 R3 R10; R1 continua PASS com o
checkpoint novo — a morte no Arconte 10 volta para a antessala 9).
Depois do último ajuste no Bestiário: `--only "Scripts ScriptCheck CodexQA SaveQA TecnicoQA"` tudo verde.
Demo conferida também à mão: `--demo` e `-- --demo` ligam a demo (log "GNOSIS DEMO: … save em
user://demo/save.json"); sem flag, não liga; o `.pck` exportado pelo preset "Windows Demo"
(`--export-pack`) e rodado com `--main-pack` liga a demo pela feature.

## 5. O que NÃO ficou bom / não deu tempo
- Não exportei o .exe da demo (sem templates aqui): só o `.pck`. O instalador não tem versão demo
  (na Steam a demo não precisa de instalador).
- `demo_finished` só funciona se a UI ligar num nó VIVO na hora (o menu já foi liberado); senão
  vale o fallback da EndScreen, com textos de morte (pedido à UI).
- "Intocada" conta qualquer queda de vida da Sophia na tela do Arconte (inclusive veneno depois
  da queda do chefe); é mais exigente, nunca mais fácil.
- O Bestiário grava os vistos só no próximo save (fim da tela, morte ou opções): sair no meio da
  tela perde o registro daquela tela. Gravar na hora gravaria também as faíscas ganhas no meio
  da tela com a retomada no checkpoint (dava para repetir e acumular) — preferi não.
- Checkpoint mais perto torna "morrer e repetir o trecho" mais barato; as faíscas da morte
  continuam −20% e a regra de faíscas é do Balance (pedido para medir de novo).
- Toast/tela de conquistas e integração Steam: não feitos (UI e decisão do João).

## 6. Pedidos
`docs/pedidos/onda2_tecnico2.md`: UI-MENUS2 (API de desbloqueio, chaves das Opções,
`set_window_mode`, `demo_finished` + EndScreen da demo, `store_url`), UI-HUD2 (toast de
conquista), ENCENACAO2 (`screen_rng(68)` no final_battle), BALANCE (medir o custo da morte com
o checkpoint novo), decisões do João (Steam, URL da loja).
