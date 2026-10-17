# Pedidos do agente UI-MENUS2 (Onda 2b) a outros agentes

## Técnico2
1. **Contratos usados (já batem com o WIP `ba39787` do dir2/tecnico2)** — chamados com
   `has_method`/`has_signal`/`in`, compilam sem eles:
   - `Bestiary.seen(id) -> bool` e `Bestiary.seen_ids()` (Bestiário e Galeria);
   - `CodexSession.is_unlocked(i) -> bool` (Galeria e escolha da Provação);
   - `Progression.is_boss_beaten(id)` (Bestiário, chefes);
   - `GameManager.demo` + sinal `GameManager.demo_finished` (card "Fim da demo");
   - `GameManager.set_window_mode(m)` (Opções › Modo de janela; 0 janela · 1 tela cheia
     exclusiva · 2 sem bordas — igual ao seu `window_mode_for`);
   - `settings["text_speed"]` (0.5/1.0/2.0; 0.0 = instantâneo), `settings["damage_numbers"]`,
     `settings["bindings"]`.
2. **`apply_bindings`**: está em `scripts/ui/input_rebind.gd` (`class_name InputRebind`,
   `RefCounted` instanciável, método de instância `apply_bindings(dict)`), como o seu
   `_apply_bindings` espera. Formato: `{ação: [{"k": physical_keycode} | {"b": botão} |
   {"a": eixo, "v": ±1.0} | {"m": botão do mouse}]}`; ação ausente = fábrica. Atenção: o seu
   `_apply_bindings` só chama quando o dicionário NÃO está vazio — está certo para o boot
   (fábrica já é o padrão); o "Restaurar padrão" das Opções restaura sozinho.
   Sem o seu merge, o remapeamento vale na sessão mas não volta ao reabrir o jogo
   (`text_speed`/`damage_numbers`/`window_mode`/`bindings` não estão no SETTINGS_DEFAULT da base).
3. **Bestiário de save antigo**: `bestiary_seen` não tem migração; quando a lista está vazia,
   o `BestiaryLore` deduz o que foi visto pela `best_screen` (mesmas faixas de tier do
   `types_for_screen`). Se preferir migrar no SaveManager, o `BestiaryLore` continua certo.
4. **`Progression.hp_buys`** (opcional): a loja deduz as compras de vida do
   `bonus_max_health` (20·n + 25·k, k = dons do Soter, conta exata). Se criar o contador,
   a loja passa a lê-lo (`"hp_buys" in Progression`) — e ele precisa subir a cada compra
   em `buy_max_health` e zerar em `reset_run`/ir no snapshot do run.
5. **Soter/Velkar no Bestiário**: são NPCs (não `Enemy`), então o `mark_seen` não os marca;
   o `BestiaryLore` deduz pela tela (17 e 61). Se quiser, `mark_seen("soter")` no encontro.

## UI-HUD2
- `InputGlyphs` (commit `0f88436`, `scripts/ui/input_glyphs.gd`): `label(ação)`,
  `hint([[ação, texto], ...])`, `is_pad()`, `device()`, `pad_kind()`,
  `listener().device_changed`, `draw_icon(ci, centro, ação, altura)` e o Control pronto
  `InputGlyphs.Hint` (rodapé ícone + texto que se atualiza sozinho). Pseudoações `@move`,
  `@nav`, `@scroll`. A fonte do jogo NÃO tem ✕○□△: no texto o PlayStation vira
  "Cruz/Círculo/Quadrado/Triângulo"; os ícones (`draw_icon`/`Hint`) desenham as formas.
- Leia `settings["text_speed"]` (0.0 = instantâneo) e `settings["damage_numbers"]`.

## QA
- `tools/qa_ux/pad_probe.gd:67` procura o botão "Ateliê" no menu: agora é
  "Galeria & Bestiário" (`_btn("Galeria")`).
- `tools/ux_shots.gd` fotografa `Gallery.tscn` como antes (a cena agora é `Control`).

## I18N
- Textos novos (sem `tr()`, conforme o brief): `scripts/data/bestiary_lore.gd` (36 fichas),
  `scripts/ui/controls_menu.gd`, `scripts/ui/input_rebind.gd` (nomes das ações e recusas),
  `scripts/ui/input_glyphs.gd` (nomes de teclas/botões), Opções (Modo de janela, Velocidade
  do texto, Números de dano, Teclas e botões), card "Fim da demo", escolha da Provação.
