# Onda 2 — TÉCNICO (dir2/tecnico) — relatório

Continuação de um agente derrubado pelo reinício das 06:05 UTC. O trabalho que ele
deixou sem commit (save tolerante a tipos, REVISAO #5) foi revisado, corrigido (a QA
travava ao trocar de cena: `add_child` dentro do `_ready`) e commitado.

## 1. Commits
- `fdd8942` B1: controle confirma (A) e volta (B) em todos os menus; CodexQA checa o mapa e aceita user dir de worktree (agente anterior)
- `a3e399f` Save atômico com .bak (REVISAO #3) e SaveQA isolado em user://qa/ (REVISAO #9) (agente anterior)
- `4b38fb5` Save tolerante a tipos errados (REVISAO #5)
- `9ba1795` WIP: export/instalador/patches/Provação/SceneManager/opções na Provação/reduce_flashes/volumes
- `af90344` QAs cobrindo tudo isso
- `8c3cf8a` Código morto removido, filtro de textura com mipmaps (REVERTIDO depois), QA da fila de cenas sem tempo fixo
- `ab2f5eb` relatório + pedidos
- (último) CodexQA da Provação por estado (resultado em até ~3 s em quadros, null protegido); `default_texture_filter` volta a 1

## 2. O que mudou
- **B1** `game_manager.gd`: `ui_accept`+A, `ui_cancel`+B, `ui_*` com D-pad e analógico (sem tirar teclas). O motor 4.7.1 só traz teclado em `ui_accept`/`ui_cancel` (conferido) — a checagem do CodexQA falha sem isso.
- **#3 save atômico** `save_manager.gd`/`gnosis.gd`: `.tmp` → flush/close → confere tamanho → atual (se legível) vira `.bak` → rename; leitura tenta principal → `.tmp` → `.bak`. SaveQA: truncado 0 bytes, cortado no meio, principal corrompido não apaga `.bak` bom, `.tmp` órfão, Crônicas truncadas.
- **#5 tipos errados** novo `scripts/data/save_coerce.gd` (`SaveCoerce`): `continue_run` campo a campo, opções só se o tipo bater com `SETTINGS_DEFAULT` (int/float intercambiáveis), `gnosis.gd` com `str(id)`, `has_saved_run` tolerante. SaveQA com todos os casos da revisão.
- **#2/#4/#6 export** `export_presets.cfg`: `include_filter` = LICENSES.md, OFL das fontes, `assets/input/*.txt`; `exclude_filter` = `tools/*, artes/*, docs/*, assets/_packs/*, shots/*, builds/*, installer/*`. Conferido com `--export-pack` (não precisa de template) + `tools/revisao/pck_list.py`: 736 arquivos, licenças e o banco de controles dentro, nada de tools/artes/docs/_packs. CodexQA também varre `scripts/ scenes/ assets/` e confirma que nada carrega `res://tools|artes|docs|shots`.
- **Instalador** `installer/gnosis.iss`: AppVersion 1.1.0, copia `assets/LICENSES.md` e `LICENSE_godot.txt`; AppPublisher/AppId NÃO mudados (anotado como decisão pendente). Novo `LICENSE_godot.txt` na raiz (MIT do Godot + componentes de terceiros, gerado pelo próprio motor 4.7.1).
- **#7 patches** `game_manager.gd`: só `patch_<config/version>_*.pck`, o resto ignorado com print; função pura `patch_files_for()` testada no CodexQA.
- **#8 Provação** `codex_session.gd`: `screen_for(boss, stage)` = `FIRST_EON_SCREEN + boss*EON_LEN` (+`EON_LEN-1` no Arconte), igual ao `codex_trial.gd`.
- **#9** SaveQA em `user://qa/` (já feito) e CodexQA aceita `GNOSIS-WT-*` exigindo que a pasta real bata com a configurada.
- **#12** `scene_manager.gd`: pedido no meio do fade não se perde (véu descendo: vira o destino; véu abrindo: roda em seguida); `PauseStack.clear()` na troca; `is_busy()`.
- **#13** `save_manager.gd`: `persist_run` separado; a Provação desliga só o run — opções/volumes gravam, run/melhor tela/finais do disco ficam intactos.
- **#10** `reduce_flashes` (bool, false) em `SETTINGS_DEFAULT`, espelhado no Juice se o campo existir; volumes da 1ª execução / chave ausente: Master 0,7, SFX 0,9, Música 0,6.
- **#11** removidos `scripts/data/enemy_data.gd` e `upgrade_data.gd` (sem uso: grep em .gd/.tscn/.tres e pelos uid). `default_texture_filter` 1 → 3 foi testado e **REVERTIDO** (fica como proposta, ver §3/§5).
- **CodexQA** (pedido do revisor): a Provação espera por ESTADO — fase no ar, resultado+pausa em até ~3 s em quadros, morte com `result_layer` — e protege o null (antes: espera fixa, falhava sob carga e dava SCRIPT ERROR em `result_layer.get_children()`). Nenhuma condição foi afrouxada (a da morte ficou mais exigente).

## 3. Capturas (em /home/user/caps/tecnico/)
- `antes_t3.png`/`depois_t3.png`, `antes_t12.png`/`depois_t12.png`, `antes_menu.png`/`depois_menu.png` (filtro 1 vs 3).
- `crop_prop2x.png` (altar da tela 3, 2×): com mipmaps o prop reduzido fica menos serrilhado, um pouco mais macio. `crop_t3.png`/`crop_menu.png`: HUD e textos iguais. A diferença é sutil e as capturas também diferem por animação (chuva/partículas). NÃO testei emendas de 1 px com o zoom 1,2 da câmera nova (não está neste branch) — prova insuficiente para mudar a imagem do jogo inteiro: **revertido para 1**, fica como PROPOSTA (testar com a câmera nova na integração).

## 4. Validação
Rodada completa (`TIMEOUT=900 tools/validate.sh`, container com carga alta, antes da reversão do filtro):
```
Scripts        OK        31s  pass=0  code=0
ScriptCheck    OK         3s  pass=0  code=0
CodexQA        OK       232s  pass=53  code=0
AudioQA        FALHOU   206s  pass=23  code=1   (bug conhecido do ducking — do Áudio; igual à base)
GnoseQA        OK        17s  pass=18  code=0
SaveQA         OK        52s  pass=41  code=0
PuppetQA       OK         2s  pass=0  code=0
HeroQA         OK        18s  pass=0  code=0
WaveQA         OK       110s  pass=0  code=0
```
Depois da reversão do filtro + CodexQA por estado (`--only "Scripts CodexQA"`): Scripts OK, CodexQA OK pass=53 — TUDO VERDE.

## 5. O que não ficou bom / não deu tempo
- Não exportei o .exe/instalador (não há templates nem Inno Setup aqui): só o `.pck` via `--export-pack`. O instalador não foi compilado.
- Sob carga (load 40–60) o CodexQA falhava nos trechos antigos com espera fixa; agora a Provação espera por estado. O resto do CodexQA (ateliê/perfis) ainda usa `wait()` fixo, mas não falhou nas rodadas.
- Filtro com mipmaps: só proposta (sem prova de que não cria emenda com o zoom 1,2).
- `reduce_flashes` só existe como opção/espelho: nenhum efeito visual ainda (depende do Juice/UI — pedidos).
- Melhor tela pode ser alterada em memória pela Provação via `level.gd` (não é meu arquivo; não verifiquei a fundo).

## 6. Pedidos
`docs/pedidos/onda2_tecnico.md` (Juice `reduce_flashes`, botão nas Opções, `codex_trial` usar `screen_for`, Áudio #8, BUILD.md com o novo nome de patch e filtros, decisão AppPublisher/AppId).
