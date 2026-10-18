# DUBLAGEM â€” vozes reais para GNOSIS (PT-BR + EN-US, local, grÃ¡tis, uso comercial)

> Diretor de Dublagem Â· Onda 2 Â· branch `dir7/dublagem` Â· 18/10/2026.
> Status: **PESQUISA + MOTOR + ELENCO DE AMOSTRA + PIPELINE**. O jogo inteiro
> NÃƒO foi dublado â€” espera o JoÃ£o aprovar o elenco.

## 0. BILHETE PARA O SUCESSOR (manter sempre atualizado)

- **Estado:** pesquisa de licenÃ§as feita (Â§1); venv local pronto em
  `C:\Users\jmtat\gnosis-tools\voice\venv` (Python 3.12, torch 2.6 CPU,
  chatterbox-tts 0.1.7, kokoro 0.9.4, faster-whisper); modelos em
  `C:\Users\jmtat\gnosis-tools\voice\hf` (sempre `HF_HOME` = essa pasta e
  `HF_HUB_OFFLINE=1`). Extrator de falas pronto (`tools/voice/extract_lines.py`,
  525 falas, 523 dublÃ¡veis). QA por ASR pronto (`tools/voice/asr_check.py`).
- **PrÃ³ximo passo:** ver Â§9 (atualizado no fim de cada etapa).
- **Armadilhas:** PowerShell come aspas em `python -c` â†’ sempre escreva .py.
  `av` 19 quebrou o `decode_audio` do faster-whisper (contornado com librosa).
  Chatterbox na CPU Ã© LENTO (RTF 10â€“20Ã—) e Ã s vezes inventa um "Ah!" no fim â†’
  todo Ã¡udio dele passa por corte de cauda + ASR. Kokoro Ã© estÃ¡vel e rÃ¡pido.
  NUNCA toque Ã¡udio nos alto-falantes (regra do PC).

## 1. Pesquisa de motores e licenÃ§as

CritÃ©rio: o jogo serÃ¡ VENDIDO (Steam). SÃ³ entra o que tem **cÃ³digo E pesos** com
uso comercial permitido. O motor roda sÃ³ OFFLINE, como ferramenta de produÃ§Ã£o:
o jogo distribui apenas os .ogg gerados (nenhum motor vai no executÃ¡vel).

| Modelo | LicenÃ§a cÃ³digo | LicenÃ§a pesos | PT-BR? | EN-US? | CPU / AMD | Qualidade / controle | Veredito |
|---|---|---|---|---|---|---|---|
| **Kokoro-82M** v1.0 (hexgrad) | Apache-2.0 (`kokoro`, `misaki`) | **Apache-2.0** (card HF: treinado sÃ³ com Ã¡udio permissivo/domÃ­nio pÃºblico + sintÃ©tico de TTS fechado) | sim: `pf_dora`, `pm_alex`, `pm_santa` (sem nota no VOICES.md; G2P via espeak-ng) | sim: 20 vozes (af_heart A, af_bella A-, am_fenrir/am_michael/am_puck C+â€¦) | CPU Ã³timo (RTF ~0,5â€“1,0 medido); ONNX p/ DirectML | muito estÃ¡vel, natural, **pouca emoÃ§Ã£o** (sÃ³ velocidade + voz) | **USAR** (vozes-base e falas calmas) |
| **Chatterbox Multilingual V3** (Resemble AI) | **MIT** (`chatterbox-tts` 0.1.7) | **MIT** (card HF `ResembleAI/chatterbox`) | sim (23 lÃ­nguas) + **finetune dedicado `Chatterbox-Multilingual-pt-br` (MIT)** | sim | CPU funciona mas lento (RTF 10â€“20Ã— medido); GPU AMD via ROCm-Windows em teste | **controle de emoÃ§Ã£o (`exaggeration`)**, `cfg_weight`, temperatura; clona timbre de 5â€“10 s de referÃªncia | **USAR** (falas emotivas) â€” com QA ASR |
| Piper (rhasspy â†’ OHF-Voice) | MIT (repo antigo, arquivado 10/2025); **GPL-3.0** no `piper1-gpl` atual | por voz: `pt_BR-faber` = **CC0** (MODEL_CARD); outras variam | sim (cadu, edresson, faber, jeff) | sim | CPU muito rÃ¡pido | robÃ³tico perto dos outros; sem emoÃ§Ã£o | reserva (GPL sÃ³ importa se embutir; offline ok) |
| XTTS v2 (Coqui) | MPL-2.0 | **Coqui Public Model License = NÃƒO comercial** | sim | sim | â€” | â€” | **PROIBIDO** |
| F5-TTS | MIT | **CC-BY-NC-4.0** | via finetunes | sim | â€” | â€” | **PROIBIDO** |
| Fish-Speech / OpenAudio S1-mini | Apache | **CC-BY-NC-SA** | â€” | â€” | â€” | â€” | **PROIBIDO** |
| Spark-TTS | Apache | **CC-BY-NC-SA** | nÃ£o | sim | â€” | â€” | **PROIBIDO** |
| Bark (Suno) | MIT | MIT | sim (vozes "pt_speaker") | sim | lento, instÃ¡vel (inventa sons/mÃºsica) | ruim p/ centenas de falas consistentes | nÃ£o |
| StyleTTS2 | MIT | LibriTTS (exige avisar que Ã© sintÃ©tico se a voz nÃ£o for autorizada) | nÃ£o | sim | CPU ok | boa, sÃ³ inglÃªs | nÃ£o (sÃ³ EN, clÃ¡usula de aviso) |
| OpenVoice v2 | MIT | MIT | sÃ³ como conversor de timbre (base MeloTTS sem PT) | sim | CPU ok | conversÃ£o de timbre mÃ©dia | nÃ£o necessÃ¡rio |
| MeloTTS | MIT | MIT | **nÃ£o** (EN/ES/FR/ZH/JA/KO) | sim | CPU ok | neutra | nÃ£o |
| CosyVoice2 | Apache-2.0 | Apache-2.0 | nÃ£o oficial | sim | CUDA na prÃ¡tica | boa | nÃ£o (sem PT) |
| Zonos v0.1 (Zyphra) | Apache-2.0 | Apache-2.0 | nÃ£o oficial | sim | **sÃ³ CUDA** na prÃ¡tica | emoÃ§Ã£o boa | nÃ£o (sem CUDA aqui) |
| IndexTTS2 / Higgs Audio v2 | licenÃ§as prÃ³prias (uso comercial restrito/precisa contato) | idem | â€” | â€” | â€” | â€” | nÃ£o |
| Edge-TTS | (serviÃ§o Microsoft por via nÃ£o oficial) | â€” | â€” | â€” | online | â€” | **proibido em produto** |

Conferido NESTA sessÃ£o nos cards oficiais: Kokoro (HF + VOICES.md), Chatterbox
(README HF, METADATA do wheel = MIT), Chatterbox pt-br (HF: `license: mit`),
Piper faber (MODEL_CARD: CC0) e a troca do Piper para GPL. Os demais vÃªm de
conhecimento prÃ©vio â€” sÃ³ servem para EXCLUIR; nenhum deles entra no jogo.

**Watermark:** o Chatterbox embute em todo Ã¡udio uma marca d'Ã¡gua neural
inaudÃ­vel (Perth, MIT). Mantemos â€” Ã© uma boa prÃ¡tica de IA responsÃ¡vel e nÃ£o
afeta o jogo.

**Ã‰tica das vozes:** nenhuma voz Ã© de pessoa real/famosa. As referÃªncias do
Chatterbox sÃ£o geradas pelo **prÃ³prio Kokoro** (vozes sintÃ©ticas Apache-2.0) ou
sÃ£o a voz embutida do Chatterbox (`conds.pt`, MIT). Cadeia limpa: Kokoro â†’
referÃªncia sintÃ©tica â†’ Chatterbox (emoÃ§Ã£o) â†’ pÃ³s-processamento.

**LicenÃ§as auxiliares (sÃ³ ferramenta, nÃ£o vÃ£o no jogo):** espeak-ng (GPL-3, G2P
do Kokoro/Piper â€” uso offline, o Ã¡udio gerado nÃ£o herda GPL), faster-whisper +
pesos Whisper (MIT, sÃ³ QA), ffmpeg/rubberband (pÃ³s), pyloudnorm (MIT).

## 2. Escolha do motor (decisÃ£o)

**Um motor para os dois idiomas, com papÃ©is diferentes:**
1. **Chatterbox Multilingual (MIT)** faz a ATUAÃ‡ÃƒO de todas as falas:
   PT-BR com o finetune `Chatterbox-Multilingual-pt-br`, EN-US com o V3.
   Por quÃª: Ã© o Ãºnico candidato com licenÃ§a comercial limpa que tem controle
   de emoÃ§Ã£o (`exaggeration` 0,25â€“1,0 por fala, ligado ao `mood` do roteiro),
   clona timbre de uma referÃªncia curta (= elenco consistente por centenas de
   falas: mesma referÃªncia, mesmos parÃ¢metros, semente fixa) e fala portuguÃªs
   brasileiro nativo.
2. **Kokoro-82M (Apache-2.0)** cria as **referÃªncias de timbre** do elenco
   (vozes sintÃ©ticas, nenhuma pessoa real) e Ã© o **fallback** estÃ¡vel/rÃ¡pido
   (se uma fala do Chatterbox falhar 3Ã— no QA, dÃ¡ para gerar no Kokoro).
3. **QA automÃ¡tico por ASR (Whisper)**: cada fala Ã© transcrita e comparada com
   o texto (CER). Corta o "Ah!" que o Chatterbox Ã s vezes inventa no fim e
   refaz (atÃ© 3 sementes) se CER > 0,2. Ã‰ o que garante estabilidade em massa.

**Controle "nÃ­vel Remotion":** tudo Ã© script. Roteiro (`narrative.gd` etc.) â†’
`extract_lines.py` â†’ `cast.json` (quem fala como) â†’ `dub_all.py` â†’ `.ogg` +
`manifest.json`. Mudou uma fala no cÃ³digo â†’ roda de novo â†’ sÃ³ ela Ã© refeita.

## 3. Elenco (casting) â€” `tools/voice/cast.json`

ReferÃªncia = 8â€“10 s do Kokoro lendo uma frase neutra no idioma, com o tom
ajustado (rubberband; "formant shifted" = corpo maior/menor). O Chatterbox
copia esse timbre e atua o texto. Depois, a cadeia de pÃ³s (voicelib.apply_fx).

| Personagem | Voz-base (Kokoro) PT / EN | Tom da ref. | AtuaÃ§Ã£o (ex / cfg) | PÃ³s-processamento | Ideia |
|---|---|---|---|---|---|
| **Sophia** | pf_dora / af_heart | 0 | 0,50 / 0,40 | sala curta 8% Â· **pensamento**: passa-faixa + sala 18%, âˆ’2 dB | voz limpa, perto; o pensamento soa "por dentro" |
| **A Voz** | pm_alex / am_michael | âˆ’2 st | 0,45 / 0,40 | **dobra** (2 cÃ³pias Â±7 cents, 14 ms) + placa 16% | calorosa, mas sem corpo: dentro da cabeÃ§a |
| **O Rei** | pm_santa / bm_george | âˆ’1 st | 0,40 / 0,45 | salÃ£o 22% | rÃ©gio, cerimonial; outro timbre (nÃ£o entrega a virada) |
| **Yaldabaoth** | = referÃªncia da Voz | âˆ’4 st, formantes â†“ | 0,65 / 0,35 | **oitava abaixo** 28% + **distorÃ§Ã£o** leve + catedral 30% | a MESMA voz da Voz sem o veludo â€” o jogador reconhece |
| **O Cego** (crianÃ§a) | = referÃªncia da Voz | **+6 st, formantes â†‘** | 0,35 / 0,45 | sala 20%, âˆ’2 dB | o monstro encolhido: a voz dele virou de crianÃ§a |
| **Athoth** (Torpor) | af_nicole (sussurrada) | âˆ’3 st | 0,30 / 0,50 | 10% mais lento Â· passa-baixas Â· **sussurro** 35% Â· salÃ£o 30% | sonolento, canÃ§Ã£o de ninar |
| **Harmas** (Fome) | am_onyx | âˆ’3 st, formantes â†“ | 0,70 / 0,30 | **distorÃ§Ã£o** + graves +4 dB Â· sala | gutural, guloso |
| **Galila** (Corrente) | bm_daniel | âˆ’1 st | 0,30 / 0,60 | seco (5%) Â· **brilho metÃ¡lico** (pente 3/7 ms) | legalista, frio, elos |
| **Yabel** (SilÃªncio) | am_echo | âˆ’1 st | 0,30 / 0,50 | **sussurro 90%** Â· catedral | sÃ³ a fala da morte Ã© dita (o resto Ã© rubrica muda) |
| **Astaphaios** (Espelho) | = referÃªncia da **Sophia** | âˆ’3 st, formantes â†“ | 0,50 / 0,40 | **espelho**: dobra +3 st + prÃ©-eco invertido Â· salÃ£o | ele devolve a voz DELA ("nÃ³s") |
| **Belias** (Praga) | am_eric | âˆ’2 st, formantes â†“ | 0,25 / 0,50 | 7% mais lento Â· abafado Â· **oscilaÃ§Ã£o Ãºmida** Â· "pÃ¢ntano" | cansado, Ãºmido, fatalista |
| **Armupiel** (Coroa) | am_fenrir | âˆ’4 st, formantes â†“ | 0,55 / 0,40 | oitava abaixo 15% Â· graves Â· salÃ£o 28% | grave, majestoso |
| **Soter** | bm_fable | âˆ’1 st | 0,35 / 0,50 | capela 15% | sereno, caloroso |
| **Velkar** | am_puck | âˆ’2 st, formantes â†“ | 0,35 / 0,45 | rouquidÃ£o (saturaÃ§Ã£o leve) Â· sala | cansado, arrependido |
| **Narrador** (cards, rubricas) | bf_emma | 0 | 0,30 / 0,50 | capela 12% | impessoal, ensaio claro |
| **Estela** | = Narrador | 0 | 0,30 / 0,50 | catedral 16% | a mesma voz, mais distante (pedra) |
| Adormecida / Adormecido | af_sky / am_liam | 0 | 0,40 / 0,50 | sala | gente comum acordando |
| Uma voz nos AnÃ©is | = Sophia | 0 | 0,30 / 0,50 | sussurro 40% Â· passa-faixa Â· catedral 35% | a Sophia antiga, de longe |

**Mood â†’ atuaÃ§Ã£o** (campo `mood` do roteiro, `_moods` no cast): medo/choque
+0,15â€“0,2 de exaggeration; grito (palavra em CAIXA ALTA ou "!") +0,25;
triste/arrependido/quebrado âˆ’0,1; serena âˆ’0,15; revelado +0,2.
ObservaÃ§Ã£o: as vozes EN do Kokoro lendo PT na referÃªncia tÃªm sotaque, mas o
Chatterbox pt-br fala com a prÃ³pria pronÃºncia â€” o ASR confirma (Â§5).

## 4. Pipeline â€” `tools/voice/`

| Arquivo | O que faz |
|---|---|
| `extract_lines.py` | lÃª `narrative.gd` (`_l/_c/_m`), cards do prÃ³logo/epÃ­logo, Estelas e `en_table.gd`; gera `out/roteiro.json` com id estÃ¡vel, falante, mood, cue, texto PT/EN e o **texto falado** (sem rubrica; pensamento/narraÃ§Ã£o marcados; "..." sozinho e rubricas mudas ficam fora). Hoje: **525 falas, 520 dublÃ¡veis** (A Voz 168, Sophia 157, Estelas 107â€¦) |
| `cast.json` | o elenco (tabela Â§3) |
| `voicelib.py` | motores (Kokoro, Chatterbox local), referÃªncias, efeitos (reverbs sintÃ©ticos, dobra, oitava, distorÃ§Ã£o, sussurro STFT, espelho, metal, oscilaÃ§Ã£o), corte de silÃªncio, **âˆ’18 LUFS** (pyloudnorm) + teto âˆ’1 dBFS, `.ogg` Vorbis q5 |
| `render.py` | uma fala: gera â†’ ASR com tempo por palavra â†’ corta cauda â†’ refaz se CER > 0,2 (atÃ© 3 sementes) â†’ pÃ³s â†’ loudness â†’ ogg |
| `make_refs.py` | gera as referÃªncias do elenco (+ prÃ©via do pÃ³s em cada uma) |
| `samples.py` | as amostras do elenco (este pacote para o JoÃ£o) |
| `dub_all.py` | **o jogo inteiro** (nÃ£o rodado): incremental por chave (texto + elenco), grava `assets/audio/voice/<pt\|en>/<id>.ogg` e `assets/audio/voice/manifest.json`; `--dry-run` estima o tempo |
| `asr_check.py` | QA avulso de uma pasta/manifesto (CER por arquivo) |
| `analyze.py` | tom (F0), LUFS, brilho e prancha de espectrogramas das amostras |

**ID da fala** = `sha1(falante_do_jogo + "|" + texto_pt)[:12]`, onde o falante
Ã© exatamente o `speaker` da linha (`""` para o narrador da caixa), `"card"`
para prÃ³logo/epÃ­logo e `"estela"` para as pedras. Em GDScript:
`(speaker + "|" + text).sha1_text().left(12)` â€” sem tabela extra; se o texto
muda, o id muda, e a fala antiga cai no blip atÃ© ser regerada.

**Manifesto** (`assets/audio/voice/manifest.json`):
```json
{"version": 1, "lufs": -18.0, "lines": {
  "3f9a0c21b7de": {"speaker": "A Voz", "mood": "", "source": "narrative.intro",
    "pt": {"file": "res://assets/audio/voice/pt/3f9a0c21b7de.ogg", "dur": 2.9, "cer": 0.0, "key": "â€¦"},
    "en": {"file": "res://assets/audio/voice/en/3f9a0c21b7de.ogg", "dur": 2.6, "cer": 0.0, "key": "â€¦"}}}}
```
Tamanho estimado do jogo inteiro: ~1.040 arquivos, ~25â€“35 MB (Vorbis 24 kHz mono).

## 5. Rodar (comandos)

```powershell
$env:HF_HOME="C:\Users\jmtat\gnosis-tools\voice\hf"; $env:HF_HUB_OFFLINE="1"
$py="C:\Users\jmtat\gnosis-tools\voice\venv\Scripts\python.exe"
cd C:\gnosis-wt\dublagem
& $py -I tools\voice\extract_lines.py            # roteiro
& $py -I tools\voice\make_refs.py                # referÃªncias do elenco
& $py -I tools\voice\samples.py                  # amostras (PT e EN)
& $py -I tools\voice\dub_all.py --dry-run        # estimativa do jogo inteiro
& $py -I tools\voice\dub_all.py --lang pt --speaker Sophia --limit 10   # lote pequeno
```
InstalaÃ§Ã£o do venv (do zero): `py -3.12 -m venv venv`; `pip install torch==2.6.0
torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cpu`; `pip install
chatterbox-tts==0.1.7 kokoro soundfile pyloudnorm faster-whisper "matplotlib<3.11"
"numpy<2"`; baixar os pesos com `huggingface_hub.snapshot_download` (lista em Â§0).

## 7. IntegraÃ§Ã£o no jogo (desenho para os diretores de Ãudio e UI)

Nada disto foi implementado aqui (arquivos de outros donos) â€” pedidos em
`docs/pedidos/dublagem.md`.

1. **`Audio.play_voice(line: Dictionary) -> float`** (audio_manager.gd): calcula o
   id da fala com o texto **PT** (a DialogueBox guarda o PT em `l["text"]` e sÃ³
   traduz na exibiÃ§Ã£o), escolhe o idioma (`settings["voice_lang"]`: `""` = igual ao
   texto, `"pt_BR"`, `"en"`), carrega o `.ogg` do manifesto e toca num
   `AudioStreamPlayer` prÃ³prio. Devolve a duraÃ§Ã£o (0 = nÃ£o hÃ¡ voz â†’ blips).
   `Audio.stop_voice()` corta (ao avanÃ§ar a fala). PrÃ©-carregar a PRÃ“XIMA fala com
   `ResourceLoader.load_threaded_request` para nÃ£o engasgar.
2. **Bus "Voice" direto no Master** (hoje Ã© filho de SFX): senÃ£o o volume de efeitos
   e o passa-baixas da cÃ¢mera lenta (SLOW_BUSES) pegam a voz. Volume prÃ³prio
   (`settings["voice_volume"]`).
3. **DialogueBox sincronizada**: em `_show_line()`, `var dur := Audio.play_voice(l)`.
   Se `dur > 0`: sem blips nessa fala; a mÃ¡quina de escrever usa um CPS prÃ³prio
   `cps = total_letras / max(0.4, dur * 0.9 âˆ’ pausas_de_pontuaÃ§Ã£o)` (com piso
   para nunca ficar mais lenta que 0,6Ã— a velocidade normal) â€” o texto termina de
   aparecer junto com a Ãºltima palavra. Apertar "continuar" com a voz tocando:
   primeiro mostra tudo (como hoje), segundo aperto corta a voz e avanÃ§a.
   `text_speed` instantÃ¢neo: texto inteiro na hora, voz toca normalmente.
4. **Legendas (CaptionBar)**: mesma chamada; o tempo de tela da legenda vira
   `max(atual, dur + 0.4 s)` e a prÃ³xima da fila sÃ³ entra quando a voz acaba
   (duas vozes nunca se sobrepÃµem). Legenda de luta (fase 2 de Arconte) toca a
   voz no bus Voice com prioridade sobre blips.
5. **Cards (prÃ³logo/epÃ­logo)** â€” `Cinematic`: id com falante `"card"`;
   `time = max(time, dur + 0.6)`. **Estelas**: botÃ£o opcional "ouvir a pedra"
   tocando as linhas em sequÃªncia (id com `"estela"`).
6. **Ducking**: o Audio jÃ¡ abaixa a mÃºsica âˆ’9 dB com DialogueBox aberta. Com voz
   tocando, mais âˆ’3 dB (envelope 0,15 s / 0,5 s); nas legendas (sem caixa), o
   prÃ³prio `play_voice` pede `duck_music` enquanto a voz dura. Nas cenas
   musicais (roubo, anagnÃ³rise: `SCENE_DUCK_SCALE`) manter a regra deles.
7. **OpÃ§Ãµes** (menu de Ã¡udio): "Vozes: Ligado/Desligado", "Idioma das vozes:
   Igual ao texto / PortuguÃªs / English", "Volume das vozes". PadrÃ£o: ligado,
   igual ao texto. Desligado = blips de hoje.
8. **Fallback = blips**: sem arquivo (fala nova, dinÃ¢mica com `%s`, rubrica muda),
   vozes desligadas ou manifesto ausente â†’ o comportamento atual, sem erro.
9. **Falas dinÃ¢micas** (ex.: "(...) O %s Anel. A paixÃ£o dele agora te obedece:
   %s.", "%d faÃ­scas escorrem"): nÃ£o sÃ£o dubladas. Pedido ao Roteiro: separar a
   parte fixa (dublÃ¡vel) da parte variÃ¡vel, ou prÃ©-listar as 7 variantes.
