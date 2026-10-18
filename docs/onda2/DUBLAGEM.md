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
  525 falas, 523 dubláveis). QA por ASR pronto (`tools/voice/asr_check.py`).
- **Próximo passo:** ver §9 (atualizado no fim de cada etapa).
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
