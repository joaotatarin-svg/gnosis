# DUBLAGEM — vozes reais para GNOSIS (PT-BR + EN-US, local, grátis, uso comercial)

> Diretor de Dublagem · Onda 2 · branch `dir7/dublagem` · 18/10/2026.
> Status: **PESQUISA + MOTOR + ELENCO DE AMOSTRA + PIPELINE**. O jogo inteiro
> NÃO foi dublado — espera o João aprovar o elenco.

## 0. BILHETE PARA O SUCESSOR (manter sempre atualizado)

- **Estado:** pesquisa de licenças feita (§1); venv local pronto em
  `C:\Users\jmtat\gnosis-tools\voice\venv` (Python 3.12, torch 2.6 CPU,
  chatterbox-tts 0.1.7, kokoro 0.9.4, faster-whisper); modelos em
  `C:\Users\jmtat\gnosis-tools\voice\hf` (sempre `HF_HOME` = essa pasta e
  `HF_HUB_OFFLINE=1`). Extrator de falas pronto (`tools/voice/extract_lines.py`,
  525 falas, 522 dubláveis). QA por ASR pronto (`tools/voice/asr_check.py`).
  GPU: venv `C:\Users\jmtat\gnosis-tools\voice\venv-rocm` (torch 2.9.1+rocm7.2.1,
  RX 7600 funciona com `torch.backends.cudnn.enabled=False`; RTF ~3,6 PT / 4,3 EN,
  ~2–3× a CPU; `setuptools==78.1.0` obrigatório). Falta nele: kokoro/faster-whisper.
- **PAUSA 18/10 ~17h50 (pedido do João, jogo competitivo):** nenhum processo meu
  rodando. Amostras em `C:\gnosis-wt\_caps\dublagem\amostras\` — PT completas
  (36) e EN completas EXCETO **Yaldabaoth EN 1–3** (apagadas ao reescalar o
  Yaldabaoth; regerar com `samples.py --only Yaldabaoth --lang en`). Depois:
  `prancha.py` (PRANCHA_AMOSTRAS.md) + `analyze.py` + avisar o chefe.
- **Próximo passo depois da aprovação:** `dub_all.py --dry-run`, depois lotes.
- **Armadilhas:** PowerShell come aspas em `python -c` → sempre escreva .py.
  `av` 19 quebrou o `decode_audio` do faster-whisper (contornado com librosa).
  Chatterbox na CPU é LENTO (RTF 10–20×) e às vezes inventa um "Ah!" no fim →
  todo áudio dele passa por corte de cauda + ASR. Kokoro é estável e rápido.
  NUNCA toque áudio nos alto-falantes (regra do PC).

## 1. Pesquisa de motores e licenças

Critério: o jogo será VENDIDO (Steam). Só entra o que tem **código E pesos** com
uso comercial permitido. O motor roda só OFFLINE, como ferramenta de produção:
o jogo distribui apenas os .ogg gerados (nenhum motor vai no executável).

| Modelo | Licença código | Licença pesos | PT-BR? | EN-US? | CPU / AMD | Qualidade / controle | Veredito |
|---|---|---|---|---|---|---|---|
| **Kokoro-82M** v1.0 (hexgrad) | Apache-2.0 (`kokoro`, `misaki`) | **Apache-2.0** (card HF: treinado só com áudio permissivo/domínio público + sintético de TTS fechado) | sim: `pf_dora`, `pm_alex`, `pm_santa` (sem nota no VOICES.md; G2P via espeak-ng) | sim: 20 vozes (af_heart A, af_bella A-, am_fenrir/am_michael/am_puck C+…) | CPU ótimo (RTF ~0,5–1,0 medido); ONNX p/ DirectML | muito estável, natural, **pouca emoção** (só velocidade + voz) | **USAR** (vozes-base e falas calmas) |
| **Chatterbox Multilingual V3** (Resemble AI) | **MIT** (`chatterbox-tts` 0.1.7) | **MIT** (card HF `ResembleAI/chatterbox`) | sim (23 línguas) + **finetune dedicado `Chatterbox-Multilingual-pt-br` (MIT)** | sim | CPU funciona mas lento (RTF 10–20× medido); GPU AMD via ROCm-Windows em teste | **controle de emoção (`exaggeration`)**, `cfg_weight`, temperatura; clona timbre de 5–10 s de referência | **USAR** (falas emotivas) — com QA ASR |
| Piper (rhasspy → OHF-Voice) | MIT (repo antigo, arquivado 10/2025); **GPL-3.0** no `piper1-gpl` atual | por voz: `pt_BR-faber` = **CC0** (MODEL_CARD); outras variam | sim (cadu, edresson, faber, jeff) | sim | CPU muito rápido | robótico perto dos outros; sem emoção | reserva (GPL só importa se embutir; offline ok) |
| XTTS v2 (Coqui) | MPL-2.0 | **Coqui Public Model License = NÃO comercial** | sim | sim | — | — | **PROIBIDO** |
| F5-TTS | MIT | **CC-BY-NC-4.0** | via finetunes | sim | — | — | **PROIBIDO** |
| Fish-Speech / OpenAudio S1-mini | Apache | **CC-BY-NC-SA** | — | — | — | — | **PROIBIDO** |
| Spark-TTS | Apache | **CC-BY-NC-SA** | não | sim | — | — | **PROIBIDO** |
| Bark (Suno) | MIT | MIT | sim (vozes "pt_speaker") | sim | lento, instável (inventa sons/música) | ruim p/ centenas de falas consistentes | não |
| StyleTTS2 | MIT | LibriTTS (exige avisar que é sintético se a voz não for autorizada) | não | sim | CPU ok | boa, só inglês | não (só EN, cláusula de aviso) |
| OpenVoice v2 | MIT | MIT | só como conversor de timbre (base MeloTTS sem PT) | sim | CPU ok | conversão de timbre média | não necessário |
| MeloTTS | MIT | MIT | **não** (EN/ES/FR/ZH/JA/KO) | sim | CPU ok | neutra | não |
| CosyVoice2 | Apache-2.0 | Apache-2.0 | não oficial | sim | CUDA na prática | boa | não (sem PT) |
| Zonos v0.1 (Zyphra) | Apache-2.0 | Apache-2.0 | não oficial | sim | **só CUDA** na prática | emoção boa | não (sem CUDA aqui) |
| IndexTTS2 / Higgs Audio v2 | licenças próprias (uso comercial restrito/precisa contato) | idem | — | — | — | — | não |
| Edge-TTS | (serviço Microsoft por via não oficial) | — | — | — | online | — | **proibido em produto** |

Conferido NESTA sessão nos cards oficiais: Kokoro (HF + VOICES.md), Chatterbox
(README HF, METADATA do wheel = MIT), Chatterbox pt-br (HF: `license: mit`),
Piper faber (MODEL_CARD: CC0) e a troca do Piper para GPL. Os demais vêm de
conhecimento prévio — só servem para EXCLUIR; nenhum deles entra no jogo.

**Watermark:** o Chatterbox embute em todo áudio uma marca d'água neural
inaudível (Perth, MIT). Mantemos — é uma boa prática de IA responsável e não
afeta o jogo.

**Ética das vozes:** nenhuma voz é de pessoa real/famosa. As referências do
Chatterbox são geradas pelo **próprio Kokoro** (vozes sintéticas Apache-2.0) ou
são a voz embutida do Chatterbox (`conds.pt`, MIT). Cadeia limpa: Kokoro →
referência sintética → Chatterbox (emoção) → pós-processamento.

**Licenças auxiliares (só ferramenta, não vão no jogo):** espeak-ng (GPL-3, G2P
do Kokoro/Piper — uso offline, o áudio gerado não herda GPL), faster-whisper +
pesos Whisper (MIT, só QA), ffmpeg/rubberband (pós), pyloudnorm (MIT).

## 2. Escolha do motor (decisão)

**Um motor para os dois idiomas, com papéis diferentes:**
1. **Chatterbox Multilingual (MIT)** faz a ATUAÇÃO de todas as falas:
   PT-BR com o finetune `Chatterbox-Multilingual-pt-br`, EN-US com o V3.
   Por quê: é o único candidato com licença comercial limpa que tem controle
   de emoção (`exaggeration` 0,25–1,0 por fala, ligado ao `mood` do roteiro),
   clona timbre de uma referência curta (= elenco consistente por centenas de
   falas: mesma referência, mesmos parâmetros, semente fixa) e fala português
   brasileiro nativo.
2. **Kokoro-82M (Apache-2.0)** cria as **referências de timbre** do elenco
   (vozes sintéticas, nenhuma pessoa real) e é o **fallback** estável/rápido
   (se uma fala do Chatterbox falhar 3× no QA, dá para gerar no Kokoro).
3. **QA automático por ASR (Whisper)**: cada fala é transcrita e comparada com
   o texto (CER). Corta o "Ah!" que o Chatterbox às vezes inventa no fim e
   refaz (até 3 sementes) se CER > 0,2. É o que garante estabilidade em massa.

**Controle "nível Remotion":** tudo é script. Roteiro (`narrative.gd` etc.) →
`extract_lines.py` → `cast.json` (quem fala como) → `dub_all.py` → `.ogg` +
`manifest.json`. Mudou uma fala no código → roda de novo → só ela é refeita.

## 3. Elenco (casting) — `tools/voice/cast.json`

Referência = 8–10 s do Kokoro lendo uma frase neutra no idioma, com o tom
ajustado (rubberband; "formant shifted" = corpo maior/menor). O Chatterbox
copia esse timbre e atua o texto. Depois, a cadeia de pós (voicelib.apply_fx).

| Personagem | Voz-base (Kokoro) PT / EN | Tom da ref. | Atuação (ex / cfg) | Pós-processamento | Ideia |
|---|---|---|---|---|---|
| **Sophia** | pf_dora / af_heart | 0 | 0,50 / 0,40 | sala curta 8% · **pensamento**: passa-faixa + sala 18%, −2 dB | voz limpa, perto; o pensamento soa "por dentro" |
| **A Voz** | pm_alex / am_michael | −2 st | 0,45 / 0,40 | **dobra** (2 cópias ±7 cents, 14 ms) + placa 16% | calorosa, mas sem corpo: dentro da cabeça |
| **O Rei** | pm_santa / bm_george | −1 st | 0,40 / 0,45 | salão 22% | régio, cerimonial; outro timbre (não entrega a virada) |
| **Yaldabaoth** | = referência da Voz | −4 st, formantes ↓ | 0,65 / 0,35 | **oitava abaixo** 28% + **distorção** leve + catedral 30% | a MESMA voz da Voz sem o veludo — o jogador reconhece |
| **O Cego** (criança) | = referência da Voz | **+6 st, formantes ↑** | 0,35 / 0,45 | sala 20%, −2 dB | o monstro encolhido: a voz dele virou de criança |
| **Athoth** (Torpor) | af_nicole (sussurrada) | −3 st | 0,30 / 0,50 | 10% mais lento · passa-baixas · **sussurro** 35% · salão 30% | sonolento, canção de ninar |
| **Harmas** (Fome) | am_onyx | −3 st, formantes ↓ | 0,70 / 0,30 | **distorção** + graves +4 dB · sala | gutural, guloso |
| **Galila** (Corrente) | bm_daniel | −1 st | 0,30 / 0,60 | seco (5%) · **brilho metálico** (pente 3/7 ms) | legalista, frio, elos |
| **Yabel** (Silêncio) | am_echo | −1 st | 0,30 / 0,50 | **sussurro 90%** · catedral | só a fala da morte é dita (o resto é rubrica muda) |
| **Astaphaios** (Espelho) | = referência da **Sophia** | −3 st, formantes ↓ | 0,50 / 0,40 | **espelho**: dobra +3 st + pré-eco invertido · salão | ele devolve a voz DELA ("nós") |
| **Belias** (Praga) | am_eric | −2 st, formantes ↓ | 0,25 / 0,50 | 7% mais lento · abafado · **oscilação úmida** · "pântano" | cansado, úmido, fatalista |
| **Armupiel** (Coroa) | am_fenrir | −4 st, formantes ↓ | 0,55 / 0,40 | oitava abaixo 15% · graves · salão 28% | grave, majestoso |
| **Soter** | bm_fable | −1 st | 0,35 / 0,50 | capela 15% | sereno, caloroso |
| **Velkar** | am_puck | −2 st, formantes ↓ | 0,35 / 0,45 | rouquidão (saturação leve) · sala | cansado, arrependido |
| **Narrador** (cards, rubricas) | bf_emma | 0 | 0,30 / 0,50 | capela 12% | impessoal, ensaio claro |
| **Estela** | = Narrador | 0 | 0,30 / 0,50 | catedral 16% | a mesma voz, mais distante (pedra) |
| Adormecida / Adormecido | af_sky / am_liam | 0 | 0,40 / 0,50 | sala | gente comum acordando |
| Uma voz nos Anéis | = Sophia | 0 | 0,30 / 0,50 | sussurro 40% · passa-faixa · catedral 35% | a Sophia antiga, de longe |

**Mood → atuação** (campo `mood` do roteiro, `_moods` no cast): medo/choque
+0,15–0,2 de exaggeration; grito (palavra em CAIXA ALTA ou "!") +0,25;
triste/arrependido/quebrado −0,1; serena −0,15; revelado +0,2.
Observação: as vozes EN do Kokoro lendo PT na referência têm sotaque, mas o
Chatterbox pt-br fala com a própria pronúncia — o ASR confirma (§5).

## 4. Pipeline — `tools/voice/`

| Arquivo | O que faz |
|---|---|
| `extract_lines.py` | lê `narrative.gd` (`_l/_c/_m`), cards do prólogo/epílogo, Estelas e `en_table.gd`; gera `out/roteiro.json` com id estável, falante, mood, cue, texto PT/EN e o **texto falado** (sem rubrica; pensamento/narração marcados; "..." sozinho e rubricas mudas ficam fora). Hoje: **525 falas, 520 dubláveis** (A Voz 168, Sophia 157, Estelas 107…) |
| `cast.json` | o elenco (tabela §3) |
| `voicelib.py` | motores (Kokoro, Chatterbox local), referências, efeitos (reverbs sintéticos, dobra, oitava, distorção, sussurro STFT, espelho, metal, oscilação), corte de silêncio, **−18 LUFS** (pyloudnorm) + teto −1 dBFS, `.ogg` Vorbis q5 |
| `render.py` | uma fala: gera → ASR com tempo por palavra → corta cauda → refaz se CER > 0,2 (até 3 sementes) → pós → loudness → ogg |
| `make_refs.py` | gera as referências do elenco (+ prévia do pós em cada uma) |
| `samples.py` | as amostras do elenco (este pacote para o João) |
| `dub_all.py` | **o jogo inteiro** (não rodado): incremental por chave (texto + elenco), grava `assets/audio/voice/<pt\|en>/<id>.ogg` e `assets/audio/voice/manifest.json`; `--dry-run` estima o tempo |
| `asr_check.py` | QA avulso de uma pasta/manifesto (CER por arquivo) |
| `analyze.py` | tom (F0), LUFS, brilho e prancha de espectrogramas das amostras |

**ID da fala** = `sha1(falante_do_jogo + "|" + texto_pt)[:12]`, onde o falante
é exatamente o `speaker` da linha (`""` para o narrador da caixa), `"card"`
para prólogo/epílogo e `"estela"` para as pedras. Em GDScript:
`(speaker + "|" + text).sha1_text().left(12)` — sem tabela extra; se o texto
muda, o id muda, e a fala antiga cai no blip até ser regerada.

**Manifesto** (`assets/audio/voice/manifest.json`):
```json
{"version": 1, "lufs": -18.0, "lines": {
  "3f9a0c21b7de": {"speaker": "A Voz", "mood": "", "source": "narrative.intro",
    "pt": {"file": "res://assets/audio/voice/pt/3f9a0c21b7de.ogg", "dur": 2.9, "cer": 0.0, "key": "…"},
    "en": {"file": "res://assets/audio/voice/en/3f9a0c21b7de.ogg", "dur": 2.6, "cer": 0.0, "key": "…"}}}}
```
Tamanho estimado do jogo inteiro: ~1.040 arquivos, ~25–35 MB (Vorbis 24 kHz mono).

## 5. Rodar (comandos)

```powershell
$env:HF_HOME="C:\Users\jmtat\gnosis-tools\voice\hf"; $env:HF_HUB_OFFLINE="1"
$py="C:\Users\jmtat\gnosis-tools\voice\venv\Scripts\python.exe"
cd C:\gnosis-wt\dublagem
& $py -I tools\voice\extract_lines.py            # roteiro
& $py -I tools\voice\make_refs.py                # referências do elenco
& $py -I tools\voice\samples.py                  # amostras (PT e EN)
& $py -I tools\voice\dub_all.py --dry-run        # estimativa do jogo inteiro
& $py -I tools\voice\dub_all.py --lang pt --speaker Sophia --limit 10   # lote pequeno
```
Instalação do venv (do zero): `py -3.12 -m venv venv`; `pip install torch==2.6.0
torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cpu`; `pip install
chatterbox-tts==0.1.7 kokoro soundfile pyloudnorm faster-whisper "matplotlib<3.11"
"numpy<2"`; baixar os pesos com `huggingface_hub.snapshot_download` (lista em §0).

## 7. Integração no jogo (desenho para os diretores de Áudio e UI)

Nada disto foi implementado aqui (arquivos de outros donos) — pedidos em
`docs/pedidos/dublagem.md`.

1. **`Audio.play_voice(line: Dictionary) -> float`** (audio_manager.gd): calcula o
   id da fala com o texto **PT** (a DialogueBox guarda o PT em `l["text"]` e só
   traduz na exibição), escolhe o idioma (`settings["voice_lang"]`: `""` = igual ao
   texto, `"pt_BR"`, `"en"`), carrega o `.ogg` do manifesto e toca num
   `AudioStreamPlayer` próprio. Devolve a duração (0 = não há voz → blips).
   `Audio.stop_voice()` corta (ao avançar a fala). Pré-carregar a PRÓXIMA fala com
   `ResourceLoader.load_threaded_request` para não engasgar.
2. **Bus "Voice" direto no Master** (hoje é filho de SFX): senão o volume de efeitos
   e o passa-baixas da câmera lenta (SLOW_BUSES) pegam a voz. Volume próprio
   (`settings["voice_volume"]`).
3. **DialogueBox sincronizada**: em `_show_line()`, `var dur := Audio.play_voice(l)`.
   Se `dur > 0`: sem blips nessa fala; a máquina de escrever usa um CPS próprio
   `cps = total_letras / max(0.4, dur * 0.9 − pausas_de_pontuação)` (com piso
   para nunca ficar mais lenta que 0,6× a velocidade normal) — o texto termina de
   aparecer junto com a última palavra. Apertar "continuar" com a voz tocando:
   primeiro mostra tudo (como hoje), segundo aperto corta a voz e avança.
   `text_speed` instantâneo: texto inteiro na hora, voz toca normalmente.
4. **Legendas (CaptionBar)**: mesma chamada; o tempo de tela da legenda vira
   `max(atual, dur + 0.4 s)` e a próxima da fila só entra quando a voz acaba
   (duas vozes nunca se sobrepõem). Legenda de luta (fase 2 de Arconte) toca a
   voz no bus Voice com prioridade sobre blips.
5. **Cards (prólogo/epílogo)** — `Cinematic`: id com falante `"card"`;
   `time = max(time, dur + 0.6)`. **Estelas**: botão opcional "ouvir a pedra"
   tocando as linhas em sequência (id com `"estela"`).
6. **Ducking**: o Audio já abaixa a música −9 dB com DialogueBox aberta. Com voz
   tocando, mais −3 dB (envelope 0,15 s / 0,5 s); nas legendas (sem caixa), o
   próprio `play_voice` pede `duck_music` enquanto a voz dura. Nas cenas
   musicais (roubo, anagnórise: `SCENE_DUCK_SCALE`) manter a regra deles.
7. **Opções** (menu de áudio): "Vozes: Ligado/Desligado", "Idioma das vozes:
   Igual ao texto / Português / English", "Volume das vozes". Padrão: ligado,
   igual ao texto. Desligado = blips de hoje.
8. **Fallback = blips**: sem arquivo (fala nova, dinâmica com `%s`, rubrica muda),
   vozes desligadas ou manifesto ausente → o comportamento atual, sem erro.
9. **Falas dinâmicas** (ex.: "(...) O %s Anel. A paixão dele agora te obedece:
   %s.", "%d faíscas escorrem"): não são dubladas. Pedido ao Roteiro: separar a
   parte fixa (dublável) da parte variável, ou pré-listar as 7 variantes.
