# UI-MENUS2 — relatório da Onda 2b (branch `dir2/ui-menus2`)

## 1. Commits
- `0f88436` InputGlyphs (#33) + seção `glifos` da sonda (commit cedo para o UI-HUD2)
- `541fbee` Galeria (#17), Bestiário com lore (#35), Provação só com Arcontes vencidos (#26)
- `1820c2b` Opções (#34): modo de janela, velocidade do texto, números de dano; tela Controles (remapeamento)
- `2b36a08` Loja (Balance P1/P2)
- `240dbad` Pré-jogo sem spoiler (#52), card "Fim da demo" + "Lista de desejos", "Continuar" com o nome da tela
- `f0e42cc` Glifos nos menus (Golpes & Controles, Provação, Estela, Crônicas, Créditos)
- `50a6924` Fim da demo sem URL esconde o botão; sonda da lista da Provação; pedidos
- (+ este relatório)

## 2. O que mudou
- NOVO `scripts/ui/input_glyphs.gd` (`InputGlyphs`): último dispositivo (teclado · Xbox · PlayStation ·
  Nintendo · Steam Deck, pelo nome/vendor do joypad), `label(ação)`, `hint(pares)`, `draw_icon(...)`
  (tecla, botão de face com cor/forma, ombro, D-pad, analógico — tudo por código), Control `InputGlyphs.Hint`
  (rodapé que se redesenha ao trocar de dispositivo), `listener().device_changed`. A fonte não tem ✕○□△:
  no texto o PlayStation vira "Cruz/Círculo/Quadrado/Triângulo"; nos ícones, as formas são desenhadas.
- NOVO `scripts/ui/input_rebind.gd` (`InputRebind`): `apply_bindings(dict)` (instância, como o Técnico2 chama),
  `rebind()` com TROCA quando o atalho já é de outra ação, recusa de Esc/Start/analógico e dos atalhos fixos
  (pausa, 1–7), `reset()`, JSON tolerante (números float, lixo ignorado). Fábrica guardada serializada.
- NOVO `scripts/ui/controls_menu.gd` (`ControlsMenu`): tela "Controles" (13 ações × teclado/controle),
  captura com Esc/Start/6 s para cancelar, "Restaurar padrão", grava `settings["bindings"]` pelo SaveManager.
- `options_menu.gd`: Vídeo (Modo de janela: Janela/Tela cheia/Sem bordas via `set_window_mode` se existir;
  VSync; Tremor; Reduzir flashes) · Áudio · Jogo (Velocidade do texto 0,5×/1×/2×/Instantâneo → `text_speed`;
  Legendas; Números de dano → `damage_numbers`; Vibração) · Controles › "Teclas e botões".
- NOVO `scripts/data/bestiary_lore.gd` (`BestiaryLore`): 36 fichas (2 linhas de lore + 1 dica, ESTILO_TEXTO) e
  as regras de desbloqueio: `Bestiary.seen` / `CodexSession.is_unlocked` / `Progression.is_boss_beaten` se
  existirem; senão (ou save antigo) dedução pela `best_screen`; um final visto abre tudo.
- `gallery.gd` + `Gallery.tscn` (agora `Control`): grade 4×N focável + ficha (arte grande, nome, categoria,
  lore, DICA); não encontrado = silhueta "???" e "Continue a subida."; "Encontrados N / 36".
- `character_atelier.gd` → "Galeria": Arconte só aparece depois de encontrado; "Testar em combate" só se
  vencido ("Vença-o na campanha para treinar"); Receita visual, Ver articulações, Arma +, Paleta só com
  `OS.is_debug_build()` (e não com `--galeria-jogador`, usado nas capturas). Jogador vê a DICA no lugar.
- `codex_menu.gd`: "Galeria & Bestiário"; "Provação" abre a lista dos Arcontes vencidos (Athoth sempre: é o
  treino); com só o Athoth, começa direto. "Continuar · Torpor · Travessia II" (sem "tela N").
- `upgrade_menu.gd`: +20 de vida máx. = 60×(n+1), máx. 10 ("n / 10", "no máximo"); n deduzido do
  `bonus_max_health` (20·n + 25·k dos dons do Soter, exato) ou de `Progression.hp_buys` se existir.
  Restauração só com `pending_advance` (santuário/pós-chefe) ou fora do run; pela pausa, trancada.
- `pregame.gd`: "Sete Éons · Sete Arcontes · ~2–3 horas" (demo: "Demo · o Limiar e o Torpor · ~20 minutos").
- `end_screen.gd` (`class_name EndScreen`): card "Fim da demo / Obrigado por jogar" + "Lista de desejos"
  (`gnosis/store_url`; sem URL o botão some). Gancho `ensure_demo_hook()` (menu e pré-jogo) liga
  `GameManager.demo_finished`; o fallback do GameManager (end_title) também cai no card.
- Glifos: `moves_screen.gd` (sequências e tabela com as teclas/botões ATUAIS e o tipo do controle),
  `codex_trial.gd` (faixa de dicas), `stela.gd` ("J · ler a Estela" / "X · …", "Esc fechar"),
  `chronicles.gd` e `credits.gd` (rodapés com ícones).
- Sonda `tools/ui_menus/menu_probe.gd`: novas seções `glifos controles demo provacao_lista`, e
  `loja`, `opcoes`, `bestiario`, `estela` ampliadas.

## 3. Capturas (`/home/user/caps/ui-menus2/`)
- Antes: `antes/CharacterAtelier.png` (botões de dev, 7 Arcontes abertos), `antes/Gallery.png` (grade sem texto,
  tudo aberto), `antes/OptionsMenu.png`, `antes/PreGame.png`, `antes/EndScreen.png`.
- Depois: `depois/galeria_jogador.png` (Arcontes "? ? ?", sem ferramentas de dev, DICA), `depois/galeria_dev.png`;
  `depois/bestiario_topo.png` (save novo: silhuetas) e `depois/tudo/bestiario_ficha.png`, `bestiario_fim.png`
  (tudo aberto: ficha com lore + dica); `depois/opcoes_novas.png`; `depois/controles.png`,
  `controles_captura.png`; `depois/demo_fim.png`; `depois/pregame_info.png`; `depois/tudo/provacao_lista.png`;
  `depois/probe/*` (rodada completa da sonda com janela: loja com teto, Provação com dicas por dispositivo,
  Estela, Crônicas e Créditos com rodapé de ícones).
- O que provam: layout cabe em 640×360, nada de spoiler num save novo, textos e ícones seguem o dispositivo.

## 4. Validação
`TIMEOUT=900 tools/validate.sh`:
```
Scripts OK · ScriptCheck OK · CodexQA OK pass=53 · AudioQA OK pass=46 · GnoseQA OK pass=18
SaveQA OK pass=41 · PuppetQA OK · HeroQA OK · WaveQA OK  →  TUDO VERDE
```
`tools/regressao/run_all.sh` → **PASS 10/10** (B1 A1 A2 A3 A4 A5 A6 R1 R3 R10).
Sonda: `godot --headless --audio-driver Dummy --path . res://tools/ui_menus/MenuProbe.tscn -- <pasta>` →
**110 ok, 0 falha(s)**; com janela (xvfb) → **112 ok, 0 falha(s)**.
Integração testada numa CÓPIA descartável (meu branch + arquivos do `dir2/tecnico2` @ `1bae04f`, sem tocar no
worktree dele): sonda **111 ok, 0 falha(s)** (inclui `demo_finished` → card), TecnicoQA 36 PASS / 0 FAIL, e
`GameManager.apply_settings()` do Técnico aplicando `bindings` do JSON pelo `input_rebind.gd` (J↔K, RB).

## 5. O que NÃO ficou bom / limites
- Sem o merge do Técnico2, as opções novas e o remapeamento valem só na sessão (a base não tem as chaves no
  SETTINGS_DEFAULT); "Tela cheia" exclusiva vira "sem bordas" na base. Com o merge, tudo grava (testado na cópia).
- Velocidade do texto e números de dano só GRAVAM a opção: quem lê é a UI-HUD2/Combate2.
- Bestiário: o reúso de sprite (#35, "Larva do Kenoma"/"Sombra Errante"/"Larva Ardente" iguais; Rei e
  Yaldabaoth iguais) continua — é arte. A lore ajuda a diferenciar, não resolve.
- Provação: o Athoth fica sempre liberado (é o treino do menu principal). Se o chefe quiser "nada antes de
  vencer", é uma linha em `codex_menu._open_trial`.
- Remapeamento: só a 1ª tecla de cada ação é trocada (a 2ª, ex. setas/Shift, continua); andar no controle e a
  pausa não se remapeiam (de propósito). Mouse não é capturado. Não testei com teclado e controles físicos
  (Xbox/PS/Switch/Deck): a detecção do tipo foi testada só pelo nome/vendor.
- PlayStation em texto aparece por extenso ("Quadrado") porque a fonte não tem os símbolos; só os ícones
  desenhados mostram a forma. Telas que usam `hint()` em texto (faixa da Provação) ficam mais longas no PS.
- Tela de conquistas (#49) não feita (o Técnico2 diz que é opcional).
- `tools/qa_ux/pad_probe.gd` (não é meu) procura "Ateliê" no menu — vai precisar de "Galeria".

## 6. Pedidos
`docs/pedidos/onda2_ui-menus2.md` — Técnico2 (contratos usados, formato do `bindings`, `hp_buys` opcional,
`mark_seen` para Soter/Velkar), UI-HUD2 (API do InputGlyphs), QA (pad_probe), I18N (textos novos).
