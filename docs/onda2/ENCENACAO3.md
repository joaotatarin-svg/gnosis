# ENCENAÇÃO 3 — relatório da Onda 3 (dir3/encenacao3, 17/10/2026, sessão local)

Base `origin/integracao/onda1` @ ab250ea. Capturas em `C:\gnosis-wt\_caps\encenacao3\` (fora do git);
GIF + folha de contato em `gif\`, quadros crus em `antes\`, `depois1..4\`.

## 1. O que mudou
- **Cego pequeno (pedido 7 da arte)** — `staging.gd`: `_Little` (disco desenhado) → `CegoPequeno`
  (pintado, `scripts/fx/cego_pequeno.gd`); a classe `_Little` saiu. Ele vira para a Sophia e muda de pose
  pela fala: "...mãe?" olha pra cima, "Fui eu que fechei" treme, "Levanta." estende a mão, `reclaim`
  volta ao automático (erguido → aninhado).
- **C1** — a cena apaga os números de dano ao abrir e de novo na 1ª fala (o golpe final cria o número
  DEPOIS de a morte do chefe abrir a cena).
- **F2 tela 68** — `level._lock_final_arena()`: a Mente vira arena trancada desde a chegada (paredes e
  véus da zona, câmera c±470); a Sophia acorda a 70 px da parede esquerda e a câmera já está no quadro
  da luta. `FinalBattle`: Rei nasce a +215 (esquerda-centro), Colosso a +420 (direita), virados para ela —
  os dois DENTRO do quadro no card "Yaldabaoth". Na luta, se as formas ficam < 120 px por 0,5 s, o Rei
  (ranged) pisca (`_blink_to`) para o outro lado da Sophia (ou além do Colosso, se ela está na parede);
  recarga 3,5 s.
- **C3** — Athoth (tela 10) e o Rei (tela 1) já estão no quadro durante o card nesta base (tentação em
  cena + figurante do Rei). Yaldabaoth: resolvido pelo F2.
- **H3** — `level._on_screen_cleared` espera o card (Cinematic) acabar antes de santuário/loja/caixa.
- **Ilustrações** — `assets/cinematic/cine_01..12` (cópia de `artes/gpt/cinematic`, import padrão).
  `cinematic.gd`: card com `art: [nº]`; prólogo = 3 cards × 2 ilustrações (01→02, 03→04, 05→06, fusão de
  0,8 s no meio do card, tempos iguais aos de antes: ~19,9 s); epílogo = 10/11/12 sob o título e os cards
  do final (a pintura fica entre os cards, sem piscar); Crônicas/créditos seguem na pintura do Éon.
  Ken Burns 1,00→1,06 com deriva acoplada ao zoom (a borda nunca aparece); legenda no terço inferior
  sobre uma faixa escura em gradiente. Sem o arquivo, o card cai no `bg` antigo.
  `staging.gd`: B = 07 no clarão da máscara (dura a fala "a máscara cai"); C = 08 na queda (do preto,
  ~3 s, antes da câmera descer); D = 09 1,3 s depois de "Levanta. Eu te seguro." (dura a fala).
- **NPCs** — `npc_encounter.gd`: o encontro anima com o mundo pausado; Soter/Velkar `talk` nas próprias
  falas e `idle` nas da Sophia; Soter `bless` na escolha e `fade` ao partir; Velkar `kneel` ao falar do pai
  ("Lá em cima..." até "Era meu pai."), `rise` → `talk`, `farewell` na despedida, `walk` mancando 46 px.
  Achado: a caixa de diálogo ESCONDIA os NPCs (pés a 76 % da tela, caixa a ~65 %) — agora a cena
  "soter"/"velkar" sobe o quadro (D_LIFT) e centra os dois, como na tentação.
- **Retratos por emoção** — `narrative.gd`: helper `_m()` + constantes `M_*` (o AudioQA lê cues por
  regex e confundia mood literal com cue). Tabela em `docs/pedidos/encenacao3.md`. A Voz nunca leva mood.
- **UI3** — `Staging.is_active()` (cena no ar, descida do Centro ou ilustração na tela).

## 2. Capturas (C:\gnosis-wt\_caps\encenacao3\gif\)
- Cena D: `cenaD_antes.gif` (disco preto) × `cenaD_depois.gif`; `cenaD_poses_crop.png` (olha · treme · estende a mão).
- Tela 68: `t68_luta_antes.gif` (Rei/Colosso fora do quadro no card) × `t68_luta_depois.gif`
  (`depois2\t68\c_004_livre01.png`: card com os dois no quadro; o Rei pisca no quadro ~seq 210).
- Prólogo: `prologo_antes.gif` × `prologo_depois.gif` (+ `_sheet.png`).
- Epílogos: `epilogo_{ascensao,ruptura,semente}_depois.gif`.
- Cenas: `cenaB_roubo_antes/depois.gif`, `cenaC_descida_antes/depois.gif`, `cenaD_anagnorise_ilustr_depois.gif`.
- NPCs: `npc_t61_antes_depois.png`, `npc_t17_antes_depois.png` (antes: escondidos atrás da caixa),
  `npc_velkar_poses_crop.png`, `npc_soter_depois.png`.

## 3. Validação
`tools/validate.ps1` TUDO VERDE em cada commit (CodexQA 53, AudioQA 54, GnoseQA 18, SaveQA 41,
TecnicoQA 36, Puppet/Hero/Wave OK). `tools/regressao/run_all.sh` 10/10 PASS. `SondaEncenacao2` 8/8 PASS.

## 4. O que NÃO ficou bom / não testei
- O balance da tela 68 mudou (arena 940 px em vez da tela inteira; o Rei pisca): NÃO rodei o bot de balance.
- H3 não foi reproduzido (morte do Campeão durante o card): corrigido por leitura.
- Soter na tela 17 fica atrás de um pilar de primeiro plano do cenário (fgcol) no ponto de descanso — é do
  cenário, não da câmera (pedido).
- O enquadramento dos NPCs foi filmado com sonda que teletransporta a Sophia; o tempo real (andando) não.
- A ilustração cobre o palco na fala dela: o movimento da máscara (B) e a mão estendida (D, 1,3 s) ficam
  antes; quem avança rápido vê a pintura por pouco tempo.
- O retrato da caixa nas capturas ainda é o antigo (o `mood` só aparece com o branch da UI3).
- Feel e ritmo precisam do João.
- `--position 4000,4000` não esconde a janela nesta máquina (o Godot recoloca na área dos monitores).
  Passei a usar `--position 1200,600` (pedido do João via chefe).

## 5. Pedidos — `docs/pedidos/encenacao3.md`
