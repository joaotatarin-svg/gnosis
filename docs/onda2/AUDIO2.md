# Onda 2b — Áudio2 (branch `dir2/audio2`) — relatório

## 1. Commits (sobre `integracao/onda1`)
- `2b4e294`: `tell_parry` e `tell_unblock` (bus `Tell`, fora do slow-mo); `heartbeat` com UMA batida e
  `low_health_pulse()`; Centro mudo até o 1º caco; RNG próprio.
- `43e792d`: silêncio antes do chefe (R9); a morte do chefe tira a música; gancho opcional `boss_<éon>`.
- `aa9f6a0`: 7 variações da música de chefe (opções); `tell_parry` com "xing" de lâmina; medição de leitura.
- `5d34775`: pulso de vida baixa audível sob a música de chefe; amostras para ouvir.
- (este relatório + pedidos + AUDIO.md)

## 2. O que mudou
- `scripts/autoload/audio_manager.gd`
  - **Avisos R5.** `tell_parry` e `tell_unblock` estão no CATALOG. Tom fixo (família 0). Tocam num bus
    novo, `Tell` (→ Master, segue o slider de SFX), com degraus de pan `Tell_L2…R2`. Esse bus fica FORA
    do passa-baixas da câmera lenta, então o aviso não some numa esquiva perfeita.
  - **Coração.** O `heartbeat` agora tem UMA batida. O cue `heartbeat` da intro toca 2 batidas:
    `play_sfx_later` agenda a 2ª por relógio real, 1,1 s depois. `low_health_pulse()` é a API do HUD:
    batida a −3 dB, música −3 dB por ~0,6 s (só se não houver outra abaixada ativa), no máximo 1 a cada
    0,6 s.
  - **Centro (pedido da Encenação).** `track_for_screen()` devolve `""` sem cacos. Voltar da pausa não
    religa.
  - **R9.** Na tela do Arconte e no 3º encontro da Provação, a música do Éon sai em 0,6 s e a de chefe
    fica pendente. O `boss_appear` solta a música de chefe 0,3 s depois. A pausa não refaz o silêncio;
    recomeçar a tela refaz. Rede de segurança: 25 s. No `boss_die`, a música cai −30 dB em 150 ms, fica
    1,6 s assim e volta em 1 s. Telas 1 e 68 não mudaram (são da Encenação).
  - **#40.** `boss_track(éon)`: usa `boss_<éon>` se o arquivo existir (está em OPTIONAL_MUSIC); senão
    usa `boss`.
  - **Balance.** Os sorteios (tom, variação, ponto da ambiência) usam um `RandomNumberGenerator` próprio
    e não consomem mais o global.
- `tools/audio_qa.gd`: 7 checagens novas, todas verdes:
  - Centro: voltar da pausa não religa.
  - R9: entrada 0,3 s após o stinger; a pausa mantém; morte do chefe; recomeço da tela.
  - Avisos: tom fixo, bus sem passa-baixas, pan.
  - Pulso: volume, abaixada da música, anti-metralha.
  - Intro: 2 batidas a ~1,1 s.

  O teste (e) aceita `""` só no Centro sem caco e só faixa opcional que exista. Ficou mais preciso, não
  mais frouxo: agora testa as duas situações, com caco e sem caco.
- `tools/audio_synth/tells.py` (novo), `story.py` (heartbeat de uma batida), `build_sfx.py` (categorias
  `tell` −17 e `tell_low` −14 M-max), `boss_variants.py` (novo).
- `tools/audio/tell_check.py` (medição), `tools/audio/demos.py` (amostras).
- `assets/audio/sfx/{tell_parry,tell_unblock,heartbeat}.ogg`, `assets/LICENSES.md`, `docs/AUDIO.md`,
  `docs/pedidos/onda2_audio2.md`.

## 3. Medições (não há captura de tela: é áudio)
- **Leitura sob a música** (`tell_check.py`). Níveis padrão do jogo, 40 trechos por faixa, bandas de
  1/3 de oitava, critério "≥ +6 dB em ≥ 2 bandas":
  - `tell_parry`: 98 % dos trechos de `boss` e 100 % dos 7 Éons. Pior caso (p10) da melhor banda:
    +17 dB em `boss`, +18 dB em `eon_praga`.
  - `tell_unblock`: 100 % em todas as faixas; p10 ≥ +19,5 dB.
- **Distinção.** Centro espectral 2110 Hz contra 330 Hz; ataque 7 ms contra 157 ms; distância MFCC
  entre os dois = 39,5 (a mediana entre variações do MESMO som é 3,8).
  - `tell_parry` está longe de `spark` (33,9) e de `parry` (43).
  - `tell_unblock` está perto de `hit` (6,0) e `boss_step` (6,9) no timbre médio. A diferença é o
    envelope: ele CRESCE por 0,16 s, e os dois decaem. É o ponto mais fraco; ver §5.
- **Pulso de vida baixa sob a música** (mesmo método):
  - −6 dB, sem abrir espaço: a batida passava a música só em 28 % dos trechos de `boss` e 12 % de
    `eon_coroa`.
  - Por isso: −3 dB + a música abrindo −3 dB. Medido assim, a batida passa a música em 68 % dos
    trechos de `boss` (mediana +13 dB, p10 +5 dB), 68 % de `eon_coroa`, 92 % de `eon_fome` e 100 % de
    `eon_praga`. Continua discreta: em ~1/3 dos trechos mais cheios ela é mais sentida que ouvida.
- **Variações de chefe** (`/home/user/caps/audio2/opcoes/boss_variantes.json`):
  - Todas a −16 LUFS (corrente −16,3), TP ≤ −1,1 dBTP, salto da emenda < 1 passo típico (contínuo).
  - Camadas presas às batidas detectadas: 156,6 bpm, força de ataque 3,6× a média nas batidas.
  - Centros espectrais: original 287 Hz; torpor 195; fome 267; corrente 492; silencio 479 (LRA 10);
    espelho 293 (largura S/M 0,70 contra 0,46); praga 358; coroa 261.
- Espectrogramas: `/home/user/caps/audio2/avisos.png` (avisos × parry/spark/boss_step) e
  `/home/user/caps/audio2/boss_variantes.png`.

## 4. Validação
`TIMEOUT=900 tools/validate.sh` completo (load ~10–13):
```
Scripts        OK   ScriptCheck OK
CodexQA        OK   pass=53
AudioQA        OK   pass=54   (eram 45; +7 checagens novas, mais as que já existiam)
GnoseQA        OK   pass=18   SaveQA OK pass=41   PuppetQA OK   HeroQA OK   WaveQA OK
TUDO VERDE
```
O AudioQA também rodou avulso 4 vezes durante o trabalho; as 2 últimas deram 0 falhas.

## 5. O que NÃO ficou bom / não deu tempo
- **Ninguém ouviu nada.** Tudo foi avaliado por medição e espectrograma.
- O `tell_unblock` tem timbre médio parecido com o de golpe e pisada. O que o separa é o crescendo. Se
  o João confundir, o próximo passo é mais aspereza ou uma subida de tom mais longa.
- **R9 depende do stinger.** Se a Encenação puser conversa antes de o chefe nascer, a conversa fica sem
  música, só com ambiência (é de propósito). Não testei no jogo rodando, só no AudioQA headless.
- As 7 variações são processamento + camadas sobre a MESMA faixa. Mudam a cor, não a composição. Fome,
  corrente e coroa somam percussão síntese que pode soar "colada". Torpor e coroa mudam o tom em ±1
  semitom (fita).
- A integração depende dos outros: o Combate2 tem de chamar `tell_*` e o HUD2 tem de chamar
  `low_health_pulse` (pedidos).

## 6. Pedidos (`docs/pedidos/onda2_audio2.md`)
- **Combate2:** `play_sfx("tell_unblock" if unb else "tell_parry", -1, 0, pos)` em `_tell_glint()`.
  Aviso: o `boss_appear` pode estar soando dobrado (card + inimigo).
- **UI-HUD2:** `Audio.low_health_pulse()` (via `has_method`) a cada pulso. Sem dB, sem
  `play_sfx("heartbeat")`.
- **Encenação2:** Centro e R9 (como ficou); o cue `heartbeat` continua 1 chamada.
- **João:** escolher (ou recusar) as variações de chefe.

## Amostras para o João ouvir (`/home/user/caps/audio2/opcoes/`, fora do git)
- `avisos_sob_musica.ogg`: música de chefe; 3 avisos amarelos (cada um seguido do parry) e 3 vermelhos
  (cada um seguido da esquiva).
- `vida_baixa.ogg`: golpe, depois 8 s de batida a 0,9 Hz sob a música de chefe.
- `intro_coracao.ogg`: as 2 batidas da intro.
- `silencio_pre_chefe.ogg`: R9 (Éon some → ambiência → stinger → chefe).
- `morte_do_chefe.ogg`: R9 na morte.
- `boss_comparar.ogg`: o MESMO trecho de 10 s, na ordem original → torpor → fome → corrente → silencio →
  espelho → praga → coroa. É o mais rápido para escolher.
- `boss_<éon>.ogg` (loop inteiro) e `boss_<éon>_emenda.ogg` (8 s finais + 8 s iniciais; tem de soar
  contínuo), para torpor, fome, corrente, silencio, espelho, praga e coroa.

No jogo: `assets/audio/sfx/tell_parry.ogg`, `tell_unblock.ogg`, `heartbeat.ogg`.
