# Onda 2 — Áudio (branch `dir2/audio`) — relatório

## 1. Commits (sobre `integracao/onda1`)
- `5e1c7a7` ducking por relógio real, Provação antes do run, encerramento limpo, tom exato, slow-mo, pan, limite de vozes (agente anterior, antes do reinício)
- `516b19b` tema da Voz e API das cenas (`voice_theme`, `cue`, `ring_note`) + `heartbeat`/`clap`/`child_breath`
- `e28bc66` corte do roubo e `duck_music` por relógio real; a gema da cena não repete no sinal; opções do tema do menu
- `dd37beb` cues alinhados à Staging, curva do Centro igual à do Level, pedidos da Onda 2
- `bed4e55` AUDIO.md (estado + pipeline)
- (este relatório)

## 2. O que mudou
- `scripts/autoload/audio_manager.gd`
  - Tarefa 1–3 e 5 (anterior): bug do ducking (era do teste), REVISAO #8 e #15, `play_sfx_pitched`, faísca na chegada do orbe, slow-mo, R11–R14.
  - Tarefa 4 (esta sessão):
    - **Tema da Voz.** `voice_theme("santuario"|"roubo"|"sozinha"|"")`. No roubo: corte seco para `theme` a 0,75 por 3 s de relógio REAL, depois corte seco para `roubo` sem loop. Trocar de tela, voltar ao menu ou abrir a Provação cancela.
    - **API das cenas.** `cue(nome)` cobre os 18 cues de `narrative.gd` e devolve false para cue desconhecido. `ring_note(i, devolvendo)` sobe 1 semitom por gema no roubo e desce 1 semitom na volta. Depois de um `ring_note`, o sinal de Anel fica 1,5 s sem tocar o próprio som.
    - **Menu.** `menu_track()` usa `menu` se o arquivo existir (opcional), senão `theme`.
    - **Ducking.** Em cena musical (roubo, tema sozinho) o ducking de diálogo vale 35 %.
    - **Robustez sob carga.** `duck_music` e o corte do roubo saíram de Tween/Timer para envelope por relógio real. Com o load em ~60, o Tween atrasava e o Timer disparava cerca de 0,4 s cedo; os dois casos foram pegos pelo AudioQA.
    - **Centro.** A curva agora é 0,35 + 0,65·k/6, a mesma do `level.gd`, então os dois não brigam mais pelo volume.
- `tools/audio_qa.gd`: 45 checagens (eram 24). Novas: tema da Voz, cancelamento, ducking de cena, névoa, todos os cues tratados, semitons, sinal de Anel após `ring_note`, menu opcional. A varredura de nomes literais agora inclui `play_sfx_pitched`, o que deixa o teste mais rígido, não mais frouxo.
- `tools/audio_synth/story.py` (+`build_sfx.py`): `heartbeat` (2 lub-dub, com conteúdo entre 80 e 400 Hz para não sumir em caixinha de notebook), `clap` e `child_breath`, todos por síntese.
- `tools/audio_synth/menu_theme.py` (novo): 3 temas de menu, loop de 64 s perfeito por construção, −16 LUFS. `--install <x>` grava a escolha como `music/menu.ogg`.
- `assets/audio/sfx/{heartbeat,clap,child_breath}.ogg`, `assets/LICENSES.md`, `docs/AUDIO.md`, `docs/pedidos/onda2_audio.md`.

## 3. Medições (não há captura: é áudio)
- Corte do roubo: 3008–3479 ms em 4 rodadas, com load ~60. O atraso vem da duração do quadro. Antes era um Timer que chegou a disparar com 2603 ms.
- Temas do menu, loudness por bloco de 8 s (LUFS) e emenda (3 s finais → 3 s iniciais):
  - A Esferas: −17,6 … −14,6; TP −1,9; LRA 4,7; emenda −16,1 → −17,0.
  - B Coro: −13,9 … −15,4; TP −3,2; LRA 5,2; emenda −15,8 → −12,3. O salto de 3,5 LU é musical: o tempo forte do compasso 1 volta com a solista. Na amostra não há degrau.
  - C Caixinha: −15,5 … −14,8; TP −3,7; LRA 3,9; emenda −15,8 → −15,2.
- Espectrogramas: `/home/user/caps/audio/novos_sfx.png` e `/home/user/caps/audio/menu_opcoes.png`.

## 4. Validação
AudioQA: 45/45 (`tools/validate.sh --only "Scripts ScriptCheck AudioQA"` = TUDO VERDE). Resumo completo do `validate.sh` na resposta final.

## 5. O que NÃO ficou bom / não deu tempo
- **Ninguém ouviu nada.** Os temas do menu são síntese aditiva e podem soar "de computador". Nenhum foi instalado: o menu continua com `theme`.
- O áudio das cenas hoje é tocado pela Staging da Encenação, direto. Meu `cue()` bate com ela, mas só vale se ela trocar as chamadas. Há bugs do lado de lá (ver pedidos).
- Não testei com o jogo rodando cena a cena, só pelo AudioQA headless e por medição offline.
- O aviso do chefe sobre M5/zoom 1,2/filtro de textura não se aplica ao Áudio. Não tenho conserto de M5 (é do Cenário) e não mexi em render nem em `project.godot`.

## 6. Pedidos (detalhe em `docs/pedidos/onda2_audio.md`)
- **Encenação:**
  - `roubo` está sendo tocado em LOOP sem ponto de loop. É bug: use `voice_theme("roubo")` ou `play_music("roubo", false)`.
  - O `heartbeat` está sendo chamado 2×; chame 1×.
  - O santuário fica a −19 dB, quase inaudível.
  - Usar `ring_note`, `clap` e `child_breath`.
  - As linhas do Centro no `level.gd` são redundantes.
- **UI-HUD:** `detach_ring` deve usar `ring_note`, e a caixa de diálogo deve usar `play_blip`.
- **Técnico:** fallback de volume 0,7/0,6.

## Amostras para o João ouvir
Pasta `/home/user/caps/audio/opcoes/` (fora do git):
- `menu_a.ogg` (Esferas), `menu_b.ogg` (Coro), `menu_c.ogg` (Caixinha): escolher um, ou nenhum.
- `menu_a_emenda.ogg`, `menu_b_emenda.ogg`, `menu_c_emenda.ogg`: 8 s finais + 8 s iniciais. Tem de soar contínuo.
- `voz_santuario.ogg`: Éon → tema da Voz baixo.
- `voz_roubo.ogg`: tema a 0,75 por 3 s, depois corte para `roubo`.
- `voz_sozinha.ogg`: tema a 0,85, entrando devagar.

No jogo (`assets/audio/sfx/`): `heartbeat.ogg`, `clap.ogg`, `child_breath.ogg`.

Da Onda 1, ainda sem ninguém ter ouvido: magias `cast_*`, `spark*`, `blip_*` e as ambiências `amb/*`.
