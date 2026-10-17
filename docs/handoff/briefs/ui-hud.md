# Brief — UI-HUD (dir2/ui-hud)
Leia: REGRAS_NUVEM.md, docs/QA_UX_BUGS.md, docs/UI.md, docs/pedidos/{roteiro,audio,combate}.md, docs/ROTEIRO.md §2 e §5, docs/handoff/NEURO_SATISFACAO.md R21/R22.

ARQUIVOS SEUS: scripts/ui/hud.gd, scripts/ui/caption_bar.gd, scripts/ui/dialogue_box.gd e as .tscn que só usam esses scripts, novos em tools/ui_hud/, docs/onda2/UI_HUD.md.

TAREFAS (commit a cada uma; captura antes/depois):
1. dialogue_box usa PauseStack.push/pop(self).
2. A6: escolha final (tela 68, 3 opções) sempre dentro de 640×360; opção bloqueada ("Semente") mostra o motivo visível. Testar 2 opções (tela 10) e só teclado/controle (foco no 1º, setas, ui_accept).
3. DialogueBox: emitir `line_shown(index, line)` no início de cada fala; `cue == "wait_2s"` = 2 s sem aceitar avanço; `lock_advance(on: bool)`; blips `Audio.play_blip(speaker)` a cada 2 caracteres se existir. Documentar API no topo.
4. A2/M1/L4: legenda abaixo de pausa/loja/opções/golpes; fora da área dos pés/telegrafos; some com a Sophia morta.
5. A3: hud.show_boss suporta 2 chefes (2 barras com nome/vida/FASE II do chefe certo; boss_phase aceita o chefe mantendo boss_phase(n)); quem cai mostra "refazendo-se". Contraste da barra e o "II" longe da borda.
6. M2: toast em área própria. M4: durante o card de chefe da Cinemática, HUD e legenda recuam.
7. A7: dica de controles nas telas 1–3 e na 1ª vez de cada mecânica, com as teclas do dispositivo em uso (último InputEvent); some sozinha; sem pausar.
8. `spark_orb_arrived()` (contador sobe 1 a 1, pop 1,0→1,15→1,0 em 120 ms); `restore_ring(i)` (inverso do detach_ring, animação curta); "Arma Nv. %d"; R21/R22 se der tempo.
