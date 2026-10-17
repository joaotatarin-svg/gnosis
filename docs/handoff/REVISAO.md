# GNOSIS — Revisão de código / pentest geral (onda 1)

Revisor: cargo `revisao` · branch `dir/revisao` (base `codex/despertar`, d291db0) · 17/10/2026
Escopo: segurança (I/O externo, patches, export, instalador), correção/robustez, desempenho/vazamentos, qualidade.
Regra: cada achado é **CONFIRMADO** (prova anexada: sonda headless, listagem do .pck real ou cálculo executado) ou **PLAUSÍVEL** (leitura de código, sem reprodução).

Sondas (todas em `tools/revisao/`, commitadas no branch):

| Sonda | O que faz | Log |
|---|---|---|
| `pck_list.py` | lista o `builds/GNOSIS.pck` 1.1.0 REAL (parser do formato PCK v4) e procura segredos | `pck_1.1.0_lista.txt` |
| `SondaSave.tscn` | saves/crônicas com tipos errados, truncados, JSON profundo/gigante | `sonda_save.log` |
| `SondaCorrida.tscn -- <tela> <a\|b>` | Sophia morre e o chefe cai em sequência curta | `sonda_corrida_*.log` |
| `SondaVazamento.tscn -- 2 66` | atravessa as telas 2→68 matando tudo; mede objetos/nós/órfãos por tela | `sonda_vazamento.log` |
| `SondaAvisos.tscn` | recompila todos os .gd com um aviso do GDScript elevado a erro (36 categorias, 1 rodada cada) | `avisos/*.log` |
| `SondaProvacao.tscn` | música que a Provação toca vs. a do Éon certo | `sonda_provacao.log` |

**Isolamento do save do João:** as sondas de save/corrida exigem um `override.cfg` (NÃO versionado) na raiz do worktree com
`[application]` / `config/custom_user_dir_name="GNOSIS-Revisao-Sonda"` — o `user://` vira `%APPDATA%\GNOSIS-Revisao-Sonda\`.
`SondaSave` aborta se o `user://` não contiver `Revisao-Sonda`. O `%APPDATA%\GNOSIS-Codex\` real não foi tocado.
Todo Godot rodou com `--audio-driver Dummy`. Logs em `C:\gnosis-wt\_caps\revisao\`.

---

## Resumo por severidade

| # | Sev. | Achado | Status | Dono |
|---|---|---|---|---|
| 1 | **Alta** | Arconte/Campeão cai logo depois (ou junto) da morte da Sophia → ela volta ao INÍCIO do Éon com o Anel já ganho | CONFIRMADO | Combate (level.gd) |
| 2 | **Alta** | Atribuições CC-BY (Kevin MacLeod, Little Robot Sound Factory) e licença do Godot NÃO vão na build | CONFIRMADO | Técnico + Roteiro |
| 3 | **Alta** | Save não-atômico: fechar/cair durante a gravação zera melhor tela, finais e "Continuar" (sem .bak) | CONFIRMADO (efeito) | Técnico (+ Roteiro p/ gnosis.gd) |
| 4 | Média | `gamecontrollerdb.txt` não é exportado — o banco de controles não carrega na build | CONFIRMADO | Técnico |
| 5 | Média | Save com JSON válido e tipos errados: "Continuar" não faz nada; opções-lixo persistem; Crônicas zeradas | CONFIRMADO | Combate / Técnico / Roteiro |
| 6 | Média | Ferramentas de dev (18 cenas, 24 scripts) e arte bruta (`artes/`) dentro do `GNOSIS.pck` | CONFIRMADO | Técnico |
| 7 | Média | Patches `patch_*.pck`: sem validação, sobrevivem a updates e podem REVERTER correções; não alcançam autoloads | PLAUSÍVEL | Técnico |
| 8 | Média | Provação usa o mapa velho (`2 + boss*7`): música do Éon errada em 6 de 7 Arcontes; música de chefe só no da Praga | CONFIRMADO | Técnico (codex_session) + Áudio |
| 9 | Média | Todos os worktrees usam o `user://` REAL do João; SaveQA sobrescreve/apaga o save real se rodar concorrente ou cair | CONFIRMADO (leitura) | Técnico |
| 10 | Média | Pausa é um booleano global: quem fecha despausa tudo; o timer de morte roda mesmo pausado | CONFIRMADO | UI + Combate |
| 11 | Baixa | `HealthComponent.heal()` ressuscita morto; `take_damage(negativo)` cura | CONFIRMADO | Combate |
| 12 | Baixa | `SceneManager.change_scene` descarta pedidos durante o fade em silêncio | PLAUSÍVEL | Técnico |
| 13 | Baixa | Opções alteradas DENTRO da Provação não são gravadas | PLAUSÍVEL | Técnico / UI |
| 14 | Baixa | Instalador: versão padrão 1.0.0 (projeto 1.1.0), publisher placeholder, AppId não-GUID | CONFIRMADO | Técnico |
| 15 | Baixa | "Vazamentos" ao sair (42 objetos / 20 recursos): playbacks OGG ativos no quit — inofensivo | CONFIRMADO | Áudio |
| 16 | Baixa | Alocação por quadro em `_draw_painted` (string-chave + arrays literais) — sem impacto medido | CONFIRMADO | Anim-Sophia |
| 17 | Info | Avisos do GDScript: poucos e quase todos intencionais (resumo por categoria) | CONFIRMADO | vários |

O que foi verificado e está **OK** está no fim (seção "Sem achado").

---

## ALTA

### 1. Morte da Sophia × queda do Arconte/Campeão → volta ao início do Éon com o Anel no bolso
- **Onde:** `scripts/levels/level.gd:417-447` (`_on_screen_cleared` não olha se a Sophia está morta) e `level.gd:518-542` (`_on_player_died` não olha se a tela já foi vencida); agrava: `level.gd:537` (`create_timer(1.5)` com `process_always=true` padrão) e `scripts/components/health_component.gd:31` (`heal` não checa morte; `_grant_ring` cura a Sophia morta em `level.gd:484`).
- **Cenário:** Sophia morre com uma Esfera Solar/veneno/reflexo ainda em jogo; o Arconte cai < 1,5 s depois (ou os dois no mesmo frame). O Anel é concedido, a loja pós-chefe abre com `pending_advance=true`, e 1,5 s depois o diálogo de morte ("LEVANTA.") abre POR CIMA da loja; ao fechá-lo, `respawn_at_checkpoint()` zera `pending_advance` e manda para a tela 2 (início do Éon). O jogador refaz 9 telas e enfrenta de novo um Arconte que já derrotou.
- **Prova** (`sonda_corrida_a.log`, tela 10, modo a = morte e 20 frames depois o chefe):
  ```
  f=124 MATA a Sophia
  f=144 MATA o chefe (golpe em voo)
  f=145 ... tela_run=10 pending_advance=true aneis=["arconte_sono"]   ← loja aberta
  f=324 dialogo fechado: 'Não. Não, não, não. LEVANTA.'
  f=324 ... tela_run=2 tela_level=10 pending_advance=false aneis=["arconte_sono"]
  f=596 FINAL: tela_run=2 tela_level=2 aneis=["arconte_sono"] snapshot.screen=2
  ```
  Modo b (mesmo frame) dá o mesmo resultado (`sonda_corrida_b.log`). Nas telas 1 (Rei) e 64 (roubo) o resultado é o contrário — a Sophia MORTA avança de tela (`sonda_corrida_t1.log`, `_t64.log`), mas a morte ainda conta e as faíscas (−20%) já foram descontadas.
- **Correção:** um único "desfecho" por tela no Level: `var _resolved := false`; `_on_screen_cleared` e `_on_player_died` saem se já resolvido (quem chegar primeiro manda). Se a regra for "chefe caiu = vitória", em `_on_player_died` checar `zone_index`/vivos == 0 e não respawnar. E `health.heal()` com `if is_dead(): return`.

### 2. Atribuições CC-BY e licença do Godot não estão na build
- **Onde:** `export_presets.cfg` (`export_filter="all_resources"`, `include_filter=""`), `installer/gnosis.iss` ([Files] só `GNOSIS.exe` + `GNOSIS.pck`), créditos em `scripts/fx/cinematic.gd:75` ("ver assets/LICENSES.md").
- **Cenário:** `.md`/`.txt` não são recursos → não entram no .pck nem no instalador. `assets/LICENSES.md` lista músicas de **Kevin MacLeod (CC-BY 4.0)** e SFX da **Little Robot Sound Factory (CC-BY 3.0)**, que EXIGEM atribuição junto da obra distribuída. O crédito final aponta para um arquivo que o jogador não tem. O Godot (MIT) também exige o aviso de copyright nas cópias.
- **Prova:** `pck_1.1.0_lista.txt` (678 arquivos do .pck 1.1.0 real): nenhum `.md`, nenhum `LICENSE*`. Instalador: só exe+pck.
- **Correção:** escrever as atribuições (autor, obra, licença, link) DENTRO do jogo (card de créditos/tela "Licenças" lendo um `.tres`/const) e copiar `LICENSES.md` + `LICENSE_godot.txt` no instalador (`Source: "..\assets\LICENSES.md"`).

### 3. Save não-atômico — queda no meio da gravação apaga o progresso
- **Onde:** `scripts/autoload/save_manager.gd:43-46` e `scripts/autoload/gnosis.gd:314-318` (`FileAccess.open(..., WRITE)` trunca o arquivo antes de gravar; sem arquivo temporário, sem `.bak`).
- **Cenário:** o jogo grava a cada troca de tela, morte e opção (~70+ gravações por run). Fechar à força / queda de energia / crash entre o `open` e o `store_string` deixa `save.json` com 0 bytes ou cortado → no boot: "O arquivo de save estava ilegível", `best_screen=1`, finais vistos e "Continuar" somem; o próximo save sobrescreve de vez (o texto "arquivo preservado até o próximo save" não ajuda: o próximo save chega na próxima tela).
- **Prova** (`sonda_save.log`, caso `truncado`): `antes: best=40 continuar=true` → arquivo truncado → `depois: tamanho=0 load_game=false best=1 continuar=false aviso='O arquivo de save estava ilegível...' backup_existe=false`.
- **Correção:** gravar em `save.json.tmp`, `flush/close`, copiar o atual para `save.json.bak` e `DirAccess.rename_absolute(tmp, save)`; no `load_game`, se o principal falhar, tentar o `.bak`. Mesmo esquema em `gnosis.gd`.

## MÉDIA

### 4. Banco de controles (SDL GameControllerDB) não vai na build
- **Onde:** `scripts/autoload/game_manager.gd:187-203` lê `res://assets/input/gamecontrollerdb.txt`; `export_presets.cfg` não tem `include_filter` para `.txt`.
- **Cenário:** no editor imprime "Gamepad DB: 869 mapeamentos" (ver `sonda_save.log`, linha 2); na build exportada `FileAccess.file_exists` dá falso e a função sai em silêncio. Sobra só o DB embutido do Godot — controles genéricos/novos que o projeto prometeu suportar ficam sem mapeamento.
- **Prova:** `pck_1.1.0_lista.txt` não contém `gamecontrollerdb.txt`.
- **Correção:** `include_filter="assets/input/*.txt"` no preset (e incluir o `LICENSE_gamecontrollerdb.txt`), ou converter o DB em `.tres`/const.

### 5. JSON válido com tipos errados quebra "Continuar", opções e Crônicas
- **Onde:** `scripts/autoload/run_manager.gd:111-128` (`int()/bool()/String()` em Variant cru; `var sl: Dictionary = ...`); `scripts/autoload/save_manager.gd:84-89` (copia `settings` sem checar tipo); `scripts/autoload/game_manager.gd:46,59` (`float()`/`bool()` no valor cru); `scripts/autoload/gnosis.gd:306-307` (`String(id)` com número).
- **Cenário/prova** (`sonda_save.log`): run com `skill_levels: [1,2]`, `rings_stolen: "sim"`, `seen: [1,2]` ou `orbs: [5]` → `SCRIPT ERROR` em `run_manager.gd:123/116/128/111`, `continue_run` aborta ANTES de trocar de cena (`continue_run_chegou_ao_fim=false`) — o botão "Continuar" não faz nada, e a progressão já foi zerada por `reset_run()`. `settings.shake=[1]` → erro em `game_manager.gd:46` e o lixo é regravado no próximo save (persistente); `fullscreen:"sim"` cai em `bool("sim")` (linha 59, só fora do headless). Crônicas com `unlocked:[3,"x"]` → erro e **todas** as Crônicas lidas somem (`unlocked=[]`); o próximo `unlock` grava a lista vazia.
- Origem realista: edição manual, ferramenta de terceiros, ou um save de versão futura com outro formato. JSON quebrado já é tratado (bom).
- **Correção:** usar os helpers tolerantes `_int/_float` do SaveManager também no `continue_run`, mais `_bool` e `_str_array`; em `load_game`, aceitar cada opção só se `typeof` bater com `SETTINGS_DEFAULT[k]`; em `gnosis.gd` usar `str(id)`.

### 6. Ferramentas de desenvolvimento e arte bruta dentro do `GNOSIS.pck`
- **Onde:** `export_presets.cfg` (`exclude_filter=""`).
- **Prova:** `pck_1.1.0_lista.txt`: `tools/*.tscn` (18 cenas: Shot, BalanceBot, SaveQA, Showcase, PuppetQA…), 24 `tools/*.gdc`, `artes/sophia_raw.png`, `artes/arconte final.png`, `tools/_assembled.png`, `tools/_preview.png` (~2,3 MB). O jogador pode rodar `GNOSIS.exe res://tools/Showcase.tscn` (vitrine com todos os chefes = spoiler) ou o BalanceBot.
- **Correção:** `exclude_filter="tools/*, artes/*, docs/*, assets/_packs/*"` e conferir o .pck novo com `python -I tools/revisao/pck_list.py builds/GNOSIS.pck`.

### 7. Sistema de patches (`patch_*.pck`)
- **Onde:** `scripts/autoload/game_manager.gd:108-120`.
- **Cenário:** (a) qualquer `patch_*.pck` na pasta do executável é montado com `replace_files=true` por cima do jogo, sem assinatura/versão — pode trocar QUALQUER script (execução de código no processo). Não é escalonamento de privilégio (quem grava ali poderia trocar o `GNOSIS.pck`), mas na Steam a pasta é do usuário e um patch antigo deixado por instalação manual sobrevive a updates do depot e **reverte correções** da versão nova. (b) Ele roda no `_ready` do 2º autoload: os 13 scripts de autoload (run_manager, save_manager, narrative, gnosis…) e tudo que eles referenciam já foram carregados — um patch NÃO consegue corrigir essa lógica (recurso já carregado não é recarregado).
- **Status:** PLAUSÍVEL (comportamento documentado do `ProjectSettings.load_resource_pack`; não exportei um patch para provar).
- **Correção:** remover (a Steam já distribui updates pelo depot) ou usar o recurso nativo `patches=` do export do Godot 4.4+, aplicado no boot pelo motor. Se mantiver: exigir versão no nome (`patch_1.1.0_*.pck` igual a `config/version`) e ignorar o resto.

### 8. Provação toca a música do Éon errado (resto do mapa antigo de 7 telas)
- **Onde:** `scripts/autoload/codex_session.gd:36` (`RunManager.current_screen = 2 + boss_index * 7`; `EON_LEN` é 9); `scripts/autoload/audio_manager.gd:271-276` (`RunManager.begin()` liga `run_active`, então o ramo `elif CodexSession.active` nunca roda — código morto).
- **Prova** (`sonda_provacao.log`): Fome→`eon_torpor`, Corrente→`eon_fome`, Silêncio→`eon_corrente`, Espelho→`eon_silencio`, Praga→`boss` nos 3 encontros, Coroa→`eon_espelho`; o 3º encontro (o Arconte) nunca toca `boss`, salvo na Praga. O `codex_trial.gd:13,61` usa a fórmula certa só para o Level.
- **Correção:** `RunManager.current_screen = RunManager.FIRST_EON_SCREEN + boss_index * RunManager.EON_LEN` (e `+ EON_LEN - 1` no estágio 2, sincronizado com o `codex_trial`), e testar `CodexSession.active` ANTES de `run_active` no `audio_manager`.

### 9. Os worktrees dos diretores usam o save REAL do João (risco desta onda)
- **Onde:** `project.godot` (`custom_user_dir_name="GNOSIS-Codex"`) é igual em todos os worktrees → todos gravam em `%APPDATA%\GNOSIS-Codex\`. `tools/save_qa.gd:20-64` sobrescreve o `save.json` real com variantes de teste e "restaura" do backup em memória; se a falta de save inicial, **apaga** (linha 64). `tools/balance_bot.gd:261` grava `balance.txt` lá.
- **Cenário:** dois diretores rodam o SaveQA ao mesmo tempo (ou um é morto por timeout no meio): o 2º faz backup do JSON de TESTE do 1º e o restaura por último → o save real do João vira `{"save_version":2,"run":{"screen":90}}` ou some. As capturas com janela também aplicam o `fullscreen` do save do João.
- **Prova:** leitura (não reproduzi para não tocar no save real); `tools/codex_qa.gd:33` confirma que o QA espera esse diretório.
- **Correção:** cada worktree com um `override.cfg` (não versionado) apontando `custom_user_dir_name` para `GNOSIS-<cargo>` (como as sondas desta revisão), e o SaveQA gravar em `user://qa/` (tornar `SAVE_PATH` uma `var`).

### 10. Pausa como booleano global e timer de morte que ignora a pausa
- **Onde:** `scripts/ui/dialogue_box.gd:122`, `scripts/entities/stela.gd:227`, `scripts/ui/upgrade_menu.gd:127,134`, `scripts/ui/pause_menu.gd:44,109` — todos fazem `paused = false` incondicionalmente; `scripts/levels/level.gd:524,537` usam `create_timer` com `process_always=true` (padrão).
- **Prova:** na `sonda_corrida_a.log` o diálogo de morte nasceu (f=324) com a loja pós-chefe aberta e o mundo pausado; ao fechar o diálogo o mundo despausa com a loja ainda na tela. O mesmo vale para diálogo × card de chefe × Estela.
- **Correção:** pilha de pausa no GameManager (`push_pause()/pop_pause()`, despausa quando o contador chega a 0) e `create_timer(1.5, false)` no fluxo de morte.

## BAIXA

### 11. `HealthComponent.heal()` revive morto; dano negativo cura
- `scripts/components/health_component.gd:22-33`. Na corrida do item 1, `_grant_ring` (level.gd:484) pôs a Sophia morta com vida cheia (estado continua DEAD). `_advance_via_exit` (level.gd:463) confia em `is_dead()` — um morto curado passaria. **Correção:** `if is_dead() or amount <= 0: return` em `heal`; `amount = maxi(0, amount)` em `take_damage`.

### 12. `SceneManager.change_scene` descarta pedidos durante o fade
- `scripts/autoload/scene_manager.gd:21-24`: `if _busy: return` sem aviso. Quem chama (ex.: `run_manager.gd:329-335`) já incrementou `current_screen` e salvou ANTES; se o pedido cair durante outro fade, número da tela e cena divergem. Não reproduzi em fluxo normal (as travas atuais seguram — a travessia 2→68 passou limpa). **Correção:** guardar o último pedido e executá-lo ao fim do fade, ou devolver `bool` para o chamador desfazer.

### 13. Opções mudadas dentro da Provação não são gravadas
- `scripts/autoload/codex_session.gd:23` desliga `SaveManager.persist_enabled`; `scripts/ui/options_menu.gd:133-136` chama `save_game()`, que vira no-op. Sair do jogo direto da Provação perde volume/tremor/legenda. **Correção:** separar `persist_run` de `persist_settings` (opções sempre gravam).

### 14. Instalador (`installer/gnosis.iss`)
- `AppVersion` padrão `1.0.0` (projeto e `export_presets` = 1.1.0; comentário fala em 0.1.0); `AppPublisher "Estudio Jogo"` é placeholder; `AppId` não é um GUID (funciona, mas NUNCA pode mudar depois de publicado). Positivo: instala em `{autopf}` com admin → a pasta (e os `patch_*.pck`) não é gravável por usuário comum. `encrypt_pck=false`: scripts legíveis (normal na indústria; só ciência).

### 15. Objetos "vazados" ao fechar
- `sonda_corrida_t64_verbose.log`: `AudioStreamPlaybackOggVorbis` / `OggPacketSequence` "still in use at exit" (42 objetos, 20 recursos na travessia longa). São players de música/SFX ainda tocando no `quit`. Só no encerramento; sem efeito em jogo. **Correção:** parar os players do Audio em `NOTIFICATION_WM_CLOSE_REQUEST`.

### 16. Alocação por quadro no desenho das ilustrações
- `scripts/fx/character_art.gd:1288-1305` (`_draw_painted`, chamado todo frame por personagem via `_process` → `queue_redraw`): cria os arrays `anchors`/`body_heights` e chama `PaintedLibrary.region()` que monta a chave `file + str(rect)` (formatação de Rect2) a cada quadro (`painted_library.gd:19-27`). **Medido:** 144 FPS (teto do vsync) nas telas mais cheias — 63 (antessala, 4+ inimigos), 64 (Coroa) e 68 (batalha dupla) — com janela 1280×720 nesta máquina (RX 7600). Em PC fraco não medido. **Correção (barata):** `const` para os arrays e cache da `AtlasTexture` por quadro na própria instância.

### 17. Avisos do GDScript (por categoria)
A validação padrão (`--editor --quit`) saiu com **0 SCRIPT ERROR / 0 Parse Error / 0 WARNING**. Para ver os avisos, a `SondaAvisos` recompilou os 64 `.gd` de `scripts/` com cada categoria elevada a erro (36 categorias). Ocorrências únicas (arquivo:linha):

| Categoria | Qtde | Leitura |
|---|---|---|
| `missing_await` (desligada por padrão) | 51 | quase tudo "dispare e esqueça" intencional (`SceneManager.change_scene`, `Juice.hit_stop/slow_mo`) |
| `shadowed_variable_base_class` | 12 | `name`, `layer`, `scale`, `show`, `tr` como local/parâmetro (bestiary:162, game_content:20/38, scenery:60/124/606/608, options_menu:111, enemy:879, character_art:170/179, moves_screen:202) — risco de confusão, não bug |
| `integer_division` | 12 | todas intencionais (índices, minutos:segundos) |
| `int_as_enum_without_cast` | 4 | bestiary:148, codex_session:52, gallery:113, pregame:80 |
| `unused_parameter` / `shadowed_global_identifier` (`len`) / `incompatible_ternary` (boss_puppet:307-308) / `confusable_local_declaration` | 2 cada | cosmético |
| `unused_variable` (seal_puzzle:131 `stone`) / `unused_private_class_variable` (scenery `_t`) | 1 cada | código morto pequeno |

Nenhum em: variável não atribuída, código inalcançável, expressão solta, `assert` constante, `narrowing_conversion`. Qualidade boa.

---

## Sem achado (verificado)
- **Desserialização / execução:** nenhum `str_to_var`, `bytes_to_var`, `Expression`, `OS.execute`, `OS.shell_open` no jogo. Saves são JSON (`JSON.parse_string` nunca devolve Object). Nenhum `load()` com caminho vindo de dado do usuário (todos são constantes ou montados de ids internos) → sem path traversal.
- **JSON hostil:** 100 000 colchetes aninhados → recusado em 24 ms ("structure is too deep"); save de 7 MB com 2 milhões de itens → carregou em 1,3 s sem travar.
- **Segredos/caminhos pessoais:** nenhum `C:\Users\jmtat`, e-mail ou chave em scripts/cenas/recursos exportáveis (só em `.godot/editor/project_metadata.cfg`, que não é exportado). O nome do autor aparece nos créditos de propósito.
- **Mapa de 68 telas / índices:** a travessia 2→68 (`sonda_vazamento.log`) rodou com **0 SCRIPT ERROR**; tabelas por Éon/tela são clampadas (`eon_index`, `EON_BOTS`, `_roman`).
- **Vazamentos em jogo:** a cada tela, nós 145–296 (estável), órfãos 0–1 (transitório), filhos do root 15–17, objetos 2050→2522 em 67 telas (só cache de recursos, 71→147). Lambdas ligadas a sinais de autoload (`player.gd:111`, `hud.gd:54`) não acumulam (sem erro de captura liberada em 66 trocas de cena). VFX tem teto (`MAX_LIVE=40`) e autolimpeza.
- **Juice / time_scale:** hit-stop e câmera lenta usam timers em tempo real e restauram a escala de fundo — sem `time_scale` preso.

## Pedidos aos diretores (resumo por dono)
- **Técnico:** itens 2 (export/instalador), 3, 4, 6, 7, 9, 12, 13, 14; item 5 (save_manager/game_manager); item 8 (codex_session).
- **Combate (onda 2):** itens 1, 5 (run_manager.continue_run), 10 (timers de morte), 11.
- **UI:** item 10 (pausa em dialogue_box/upgrade_menu/pause_menu), 13 (options_menu).
- **Roteiro:** item 2 (créditos em cinematic.gd com as atribuições reais), 3/5 (gnosis.gd: gravação atômica e `str(id)`), 10 (StelaPanel).
- **Áudio:** item 8 (ordem dos ramos em `_on_state_changed`), 15.
- **Anim-Sophia:** item 16 (opcional).
