# Briefs — Onda 2b (segunda rodada; base integracao/onda1 @ Onda 2 integrada)
Fonte: `docs/onda2/BACKLOG_CRITICO.md` (o crítico capturou ANTES da Onda 2: muitos itens já estão resolvidos —
confira no código atual antes de mexer), relatórios `docs/onda2/*.md`, pedidos `docs/pedidos/onda2_*.md`.
Regras: `docs/handoff/REGRAS_NUVEM.md`. Donos de arquivos iguais aos da Onda 2 (briefs anteriores), com as notas abaixo.
NÃO mexer agora em textos para inglês (`tr()`): a ligação do inglês será uma rodada própria no fim.

## TECNICO2 (dir2/tecnico2) — autoloads do Técnico, project.godot, export, installer, scripts/data
1. Checkpoint (backlog #3): além do início do Éon, checkpoint no santuário (offset 4) e na antessala do Arconte (offset 7);
   "Continuar" retoma da última tela de checkpoint alcançada. Custo da morte continua −20% de faíscas. Teste automatizado.
2. Tela cheia por padrão na 1ª execução (#24) — só quando não há save.
3. Modo DEMO (#27): `GameManager.demo` (flag por `--demo` na linha de comando OU `ProjectSettings` custom `gnosis/demo=true`
   num preset de export "Demo"): campanha termina após o Athoth (tela 10) chamando um hook `GameManager.demo_finished`
   (sinal) que a UI usa; save da demo separado (`user://demo/`). Preset "Windows Demo" no export_presets.cfg.
4. Desbloqueios (#26): `Progression`/save guarda chefes já vencidos na campanha (`bosses_beaten`); `CodexSession` expõe
   `is_unlocked(boss_index)` (Provação só lista vencidos; a UI usa). Bestiário: `Bestiary.seen(id)` gravado ao encontrar.
5. Determinismo (Balance): o sorteio global usado na batalha final deve ter RNG próprio — exponha
   `RunManager.screen_rng(screen) -> RandomNumberGenerator` semeado pela tela (a Encenação usa em final_battle).
6. Conquistas (#49): só a LISTA e um autoload leve `Achievements` (grava local, sinal `unlocked(id)`, ~20 conquistas sem sorte
   nem "volte amanhã"); integração Steam fica para depois (anote o que falta).

## UI-MENUS2 (dir2/ui-menus2) — mesmos arquivos da UI-MENUS
1. Ateliê vira "Galeria" (#17): botões de dev (Receita visual, Ver articulações, Arma +, Paleta) só com `OS.is_debug_build()`;
   entradas liberadas por encontro (use `Bestiary.seen`/`CodexSession.is_unlocked` se existirem — has_method).
2. Bestiário (#35): 2 linhas de lore + 1 dica tática por criatura (texto novo seu num arquivo de dados NOVO
   `scripts/data/bestiary_lore.gd`; siga ESTILO_TEXTO), liberado por encontro; Provação só lista chefes vencidos (#26).
3. Opções (#34): velocidade do texto (0,5×/1×/2×/instantâneo → `settings["text_speed"]`), números de dano liga/desliga
   (`settings["damage_numbers"]`), modo de janela (janela/tela cheia/borderless). Remapeamento de teclas e botões: tela
   "Controles" com rebind por ação gravado em `settings["bindings"]` (o Técnico aplica no load — deixe a função
   `apply_bindings(dict)` pronta num arquivo NOVO `scripts/ui/input_rebind.gd`, chamada se existir).
4. Glifos de botão (#33): arquivo NOVO `scripts/ui/input_glyphs.gd` (`class_name InputGlyphs`): último dispositivo
   (teclado/Xbox/PlayStation pelo nome do joypad) e texto/ícone por ação; use nos seus menus.
5. Economia (Balance P1/P2): +20 vida máx. custa 60×(n+1), no máximo 10 compras; Restauração só no santuário e no pós-chefe.
6. Pré-jogo (#52) sem spoiler: "Sete Éons · Sete Arcontes · ~2–3 h". Fim da DEMO: tela/card "Fim da demo — obrigado por jogar"
   + botão "Lista de desejos" (abre URL configurável `gnosis/store_url`) ligada ao sinal `GameManager.demo_finished` se existir.

## UI-HUD2 (dir2/ui-hud2) — hud.gd, caption_bar.gd, dialogue_box.gd
1. Use `InputGlyphs` (do ui-menus2; has_method/`ClassDB`… se não existir, fallback atual) nas dicas e rodapés.
2. Rubricas (#22): falas cujo texto é só rubrica entre parênteses e falante narrador → tela escura + texto centralizado em
   itálico, sem caixa (modo `narration` da DialogueBox). Velocidade do texto lendo `settings["text_speed"]`.
3. Números de dano respeitam `settings["damage_numbers"]` se o dano for desenhado por você; senão, pedido ao Combate.
4. Legenda nunca durante luta de chefe ativa (#21) — se for decisão da UI, faça; senão anote para a Encenação.

## ENCENACAO2 (dir2/encenacao2) — level.gd, final_battle.gd, staging.gd, cinematic.gd, narrative.gd, sleeper, npc, etc.
1. Abertura (#6): prólogo em 3 cards (≤20 s); "Acorda." e controle; o resto da intro vira legenda andando; primeiro comando
   em ≤45 s após "Começar". Mantenha a Cena A (≤9 s).
2. Duelo do Rei ensina (#10): no 1º telegrafo aparável do Rei, câmera lenta 0,3 s + dica "apare" (use a API de dica do HUD se
   houver; senão Gnosis.captions); no 1º imparável, "esquive".
3. Tentação com o Arconte em cena (#18); nome do Campeão por Éon (#20); sem legendas de chegada durante luta de chefe (#21).
4. Balance P4: o Elite da antessala da Coroa não pode ser o Invocador (level.gd:369-372). final_battle usa
   `RunManager.screen_rng(68)` se existir (determinismo).
5. Registro do português (#54): uniformize o "tu" mítico (Voz/Rei/Arcontes) e o "você" da UI conforme ESTILO_TEXTO; sem
   mudar sentido.
6. Centro sem música até o 1º caco (pedido da Encenação ao Áudio — confira com o Áudio2; o dono da música é o Áudio).

## COMBATE2 (dir2/combate2) — player.gd, enemy.gd, juice, camera_shake, fx de combate, combat/, components/
1. Gibs (#23): somem em 3–4 s, máx. 30 vivos, nunca atravessam tela.
2. Tamanho dos chefes (#42): Arconte ≥ ~1,8× a altura da Sophia (exceto Espelho, de propósito) — ajuste por escala no
   lado do Enemy (Bestiary é do Técnico2: se precisar, pedido).
3. Balance P3: poças de Belias 5,0→3,0 s, raio fase 2 48→40.
4. Números de dano respeitam `GameManager.settings.get("damage_numbers", true)`.
5. Leitura dos inimigos (#30/NEURO R18): sombra de contato e um contorno/rim discreto SEM tocar no CharacterArt (que é da
   sessão local): ex. um nó irmão de sombra no Enemy; se só der pelo shader do CharacterArt, escreva o pedido.
6. Telegrafo com som: o Áudio2 cria `tell_parry`/`tell_unblock`; chame-os no brilho do telegrafo (has no catálogo).
7. Repetição (#41): proponha (doc) uma regra de travessia por Éon com as mecânicas existentes; implemente 2 (Torpor: névoa
   que fecha a visão; Corrente: correntes no cenário) se couber nos seus arquivos.

## AUDIO2 (dir2/audio2) — audio_manager.gd, assets/audio, tools/audio_synth
1. `tell_parry` / `tell_unblock` (síntese; curtos, distintos, legíveis sob música); `heartbeat` no catálogo para o aviso de
   vida baixa (R22) do HUD.
2. Centro sem música até o 1º caco; voltar da pausa não religa (pedido da Encenação).
3. Música de chefe (#40): avalie variações por Arconte a partir do material existente (tom/arranjo/camadas) por síntese; gere
   opções para o João ouvir, sem trocar a padrão sem aprovação. Liste no relatório.
4. NEURO R9 (silêncio de 0,6–1 s antes do card de chefe) se não existir.
