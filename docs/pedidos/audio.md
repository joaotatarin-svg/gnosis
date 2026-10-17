# Pedidos do Diretor de Áudio a outros diretores

## UI (dialogue_box.gd)
- A cada caractere visível do efeito máquina de escrever (ou a cada 2), chamar
  `Audio.play_blip(l.get("speaker", ""))`. O Audio já mapeia falante → voz e a
  sílaba nova corta a anterior. Não precisa ligar ducking: DialogueBox/Cinematic
  na árvore já abaixam a música sozinhos.
- Ao abrir um painel/menu: `Audio.play_sfx("ui_open")` (existe).
- Tela de Créditos: ler o bloco "## CRÉDITOS" de `assets/LICENSES.md` (cada
  linha começando com "- " é uma linha de crédito).

## Animação (Sophia / chefes)
- Passos: `Audio.play_sfx("step")` (leve; player.gd já toca a -6 dB),
  `step_heavy` (aterrissagem/passo pesado), `cloth` (giros, capa), `boss_step`
  (pisada de chefe; há 3 variações, sorteio automático). Chamar com volume 0 —
  os arquivos já estão no nível certo.

## FX / quem for dono de `scripts/fx/spark_orb.gd`
- Quando o orbe CHEGA em Sophia (antes do `queue_free`):
  `Audio.play_sfx("spark")` — o Audio sobe a escala pentatônica quando vários
  chegam em sequência (anti-spam 40 ms). Hoje a coleta só soa pelo sinal de
  faíscas do Progression (1 som por lote, não por orbe).

## Técnico (save_manager.gd)
- Fallback de volume quando o save não tem a chave: usar 0,7 (Master) e 0,6
  (Música) — padrão novo pedido pelo João — em vez de 0,9/0,7.

## Roteiro / Narrativa
- Disponível: `fog_swell`, `king_step`, `mask_light`, `voice_merge`, `whisper`;
  `Audio.play_music(t, loop, pitch)`, `set_music_pitch(p, fade)`,
  `duck_music(segundos, db)`, `set_music_layer_volume(t)` (0..1, por faixa).
