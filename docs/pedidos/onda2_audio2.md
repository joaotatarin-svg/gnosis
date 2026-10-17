# Pedidos do Áudio2 (Onda 2b, branch `dir2/audio2`)

## Combate2 (`scripts/entities/enemy.gd`)
1. **Som do telegrafo (R5).** Em `_tell_glint()`, depois do `VfxLibrary.tell_glint(...)`:
   ```gdscript
   Audio.play_sfx("tell_unblock" if unb else "tell_parry", -1.0, 0.0, pos)
   ```
   Use `pos` (o ponto do brilho), que dá o pan pela tela. Use `play_sfx`, não `play_sfx_at`: o aviso é
   informação e não deve ser atenuado pela distância. O tom é fixo (o Áudio já zera a variação de `tell_*`).
   Os dois tocam num bus próprio (`Tell`), que fica de fora do abafado da câmera lenta.
   - `tell_parry`: o pico vem no 1º ms, junto com o brilho, que é quando a janela de parry abre.
   - `tell_unblock`: cresce por 0,2 s, até perto do golpe.
2. (Só um aviso.) O `boss_appear` toca 2× quando o chefe nasce: no `Cinematic._run_boss` e no
   `enemy._boss_intro_fx`, os dois adiados. Se caírem a mais de 40 ms um do outro, o stinger soa
   dobrado. Não medi. Se ouvirem em dobro, deixem só o do card.

## UI-HUD2 (`scripts/ui/hud.gd`, R22)
- A cada pulso da vinheta de vida baixa (no máximo 8 s):
  ```gdscript
  if Audio.has_method("low_health_pulse"):
  	Audio.call("low_health_pulse")
  ```
  Não passem dB e não chamem `play_sfx("heartbeat", …, -18)`. O `heartbeat` agora é UMA batida, e o
  volume fica com o Áudio: batida a −3 dB e a música abre −3 dB por ~0,6 s. Sem essa abertura, a batida
  some sob a música de chefe (medido). O Áudio barra chamadas a menos de 0,6 s uma da outra.

## Encenação2
1. **Centro:** `Audio.track_for_screen(65..)` agora devolve `""` (silêncio) enquanto nenhum caco voltou.
   Voltar da pausa também não religa mais. O `Audio.stop_music(0.0)` do `descend()` pode ficar (é
   inofensivo).
2. **Silêncio antes do chefe (R9):** na tela do Arconte, a música do Éon sai em 0,6 s ao chegar e a
   faixa de chefe só entra 0,3 s depois do stinger `boss_appear` (card de chefe). Se a Tentação com o
   Arconte em cena (#18) acontecer ANTES de o chefe nascer, essa conversa fica sem música, só com a
   ambiência. É de propósito. Se a cena quiser música ali, peçam ao Áudio. Não toquem `boss` direto.
   Rede de segurança: sem stinger em 25 s, a faixa entra mesmo assim. As telas 1 (Rei) e 68 (final)
   não mudaram.
3. **Intro:** o cue `heartbeat` agora toca 2 batidas (1,1 s entre elas) a partir de UM arquivo de uma
   batida. Continuem chamando `Audio.cue("heartbeat")` uma vez só.

## Chefe / João
- Música de chefe por Arconte (#40): há 7 opções em `/home/user/caps/audio2/opcoes/boss_<éon>.ogg`
  (lista no relatório `docs/onda2/AUDIO2.md`). Nenhuma está instalada. Para instalar uma:
  `python3 tools/audio_synth/boss_variants.py --install <éon>`, depois rodar o AudioQA e pôr no
  `assets/LICENSES.md` a linha da obra derivada (Volatile Reaction, CC-BY).
