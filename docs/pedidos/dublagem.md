# Pedidos do Diretor de Dublagem (dir7/dublagem) — 18/10/2026

Contexto: `docs/onda2/DUBLAGEM.md` §7 (desenho completo). Só vale DEPOIS de o
João aprovar o elenco e de `tools/voice/dub_all.py` gerar
`assets/audio/voice/manifest.json` + `assets/audio/voice/<pt|en>/<id>.ogg`.
ID da fala: `(speaker + "|" + text_pt).sha1_text().left(12)` (`""` = narrador
da caixa; `"card"` = prólogo/epílogo; `"estela"` = pedras).

## Áudio (`scripts/autoload/audio_manager.gd`)
1. `play_voice(line: Dictionary) -> float` e `stop_voice()` (lê o manifesto uma
   vez; idioma por `settings["voice_lang"]`; devolve a duração ou 0).
2. Bus `Voice` direto no `Master` (fora do SFX e do passa-baixas da câmera lenta),
   volume próprio `settings["voice_volume"]`.
3. Ducking extra de −3 dB na música enquanto uma voz toca; `duck_music` nas
   legendas (sem DialogueBox).
3b. (Guardião) **Proteger o `tell_unblock`**: enquanto ele toca, bus Voice −8 dB +
   passa-altas 250 Hz (ataque 10 ms, soltura 300 ms); nenhuma voz de luta começa
   nos 400 ms seguintes a um tell. Vozes graves (Yaldabaoth, Armupiel, Harmas)
   são as que mascaram.
3c. (Guardião) Bus `Voice` com send para `Master` (não `SFX`) — já é o item 2.

## UI (`scripts/ui/dialogue_box.gd`, `scripts/ui/caption_bar.gd`, menu de opções)
4. DialogueBox: `_show_line()` chama `Audio.play_voice(l)`; com voz, sem blips e
   máquina de escrever com CPS calculado pela duração (termina junto com a voz);
   avançar corta a voz.
5. CaptionBar: tempo da legenda = `max(atual, dur + 0.4)`; fila espera a voz acabar.
6. Opções: "Vozes: Ligado/Desligado", "Idioma das vozes: Igual ao texto /
   Português / English", "Volume das vozes".

## Encenação (`scripts/fx/cinematic.gd`)
7. Cards de prólogo/epílogo: `time = max(time, dur + 0.6)` quando houver voz.

## Roteiro (`scripts/autoload/narrative.gd`)
8. Falas com `%s`/`%d` (ex.: `(...) O %s Anel...`, `_faiscas`) não são dubladas.
   Se quiserem voz nelas: separar a parte fixa da variável, ou listar as variantes.
9. Mudança de texto depois da dublagem = rodar `dub_all.py` de novo (só as falas
   alteradas são refeitas, ~1 min cada na CPU). Avisar o Dublagem.
