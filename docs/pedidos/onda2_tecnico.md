# Pedidos do Técnico (Onda 2) a outros agentes

1. **Juice (dono do `scripts/autoload/juice.gd`)**: criar `var reduce_flashes: bool = false`.
   O `GameManager.apply_settings()` já espelha a opção nele (`if "reduce_flashes" in juice`).
   Quem desenha clarão/flash de tela cheia (hit-flash de tela, relâmpago, morte do chefe)
   deve cortar ou atenuar muito quando `Juice.reduce_flashes` for verdadeiro.
2. **UI-Menus (`scripts/ui/options_menu.gd`)**: botão "Reduzir clarões" (liga/desliga)
   gravando `GameManager.settings["reduce_flashes"]` + `GameManager.apply_settings()` +
   `SaveManager.save_game()`. A gravação agora funciona também dentro da Provação
   (`SaveManager.persist_run` separado; REVISAO #13).
3. **Dono do `scripts/levels/codex_trial.gd`**: trocar a fórmula duplicada da tela por
   `CodexSession.screen_for(CodexSession.boss_index, CodexSession.stage)` (mesmo resultado;
   evita que as duas cópias divirjam de novo — REVISAO #8).
4. **Áudio (`audio_manager.gd`)**: REVISAO #8 — a Provação agora põe `RunManager.current_screen`
   na tela certa do Éon (e na tela do Arconte no 3º encontro), então a música já sai certa pelo
   ramo `run_active`. O ramo `elif CodexSession.active` continua morto; testar
   `CodexSession.active` antes de `run_active` só se a Provação precisar de música própria.
5. **Chefe (docs)**: `docs/BUILD.md` ainda fala em `patch_01.pck`. O jogo agora só monta
   `patch_<config/version>_*.pck` (ex.: `patch_1.1.0_01.pck`) e ignora o resto com print.
   O export inclui `assets/LICENSES.md`, os `OFL.txt` das fontes e `assets/input/*.txt`, e
   exclui `tools/*, artes/*, docs/*, assets/_packs/*, shots/*, builds/*, installer/*`.
6. **Decisão do João (anotado no `installer/gnosis.iss`, NÃO mudado)**: `AppPublisher`
   ("Estudio Jogo" é provisório) e `AppId` (não é GUID; nunca pode mudar depois do 1º
   instalador publicado).
