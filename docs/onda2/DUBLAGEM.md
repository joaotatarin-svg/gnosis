# DUBLAGEM — vozes reais para GNOSIS (PT-BR + EN-US, local, grátis, uso comercial)

> Diretor de Dublagem · Onda 2 · branch `dir7/dublagem` · 18/10/2026.
> Status: **PESQUISA + MOTOR + ELENCO DE AMOSTRA + PIPELINE**. O jogo inteiro
> NÃO foi dublado — espera o João aprovar o elenco.

## 0. BILHETE — A/B DE SOTAQUE (29/10/2026, sucessor; PARADO, nada rodando)

- O João ouviu a R3 (Qwen + grafia BR) e disse "Portugal". **O Qwen3-TTS foi DESCARTADO como base.**
- Entreguei o A/B: `C:\gnosis-wt\_caps\dublagem\ab_sotaque\` (`AB.md` e `ab_sotaque_todas.ogg`). São 5 opções comerciais e a régua Piper. **Esperando o João escolher.**
  - 1 = Kokoro pt-BR;
  - 2 = Kokoro + ChatterboxVC;
  - 3 = Kokoro + OpenVoice v2;
  - 4 = Chatterbox pt-BR;
  - 5 = Chatterbox pt-BR + ChatterboxVC.
- **Piper pt_BR NÃO é comercial.** O dataset é CC0, mas os pesos foram ajustados do `lessac` (Blizzard, só pesquisa) ou do `ryan` (CC-BY-NC-SA). A tabela §1 abaixo está errada nisso.
- **O medidor de fonemas da R3 (`fonemas.py`/`sotaque_br.py`) falhou na calibração:** deu Piper BR = 0,06 e Piper PT = 0,44, e a nota muda com o timbre. Não use a nota como critério.
- Ferramentas novas:
  - `C:\Users\jmtat\gnosis-tools\voice\venv-piper` (piper-tts 1.8, GPL; só régua);
  - `piper_voices\`;
  - `openvoice\` (src + converter v2, MIT; roda no venv principal com stubs; veja `ab_sotaque\_scripts\gen_ov.py`).
- **Próximo passo:** com a opção escolhida, refazer as vozes-base e a amostra Limiar v2 nesse motor.

## 0z. BILHETE R3 PT-BR (histórico, 29/10/2026 noite)

- **Problema:** o João ouviu sotaque de PORTUGAL.
  - Medido com fonemas: Kokoro PT = europeu (nota 0,12) e Qwen com descrição "brasileira" = leitura neutra (0,1–0,5).
  - **Correção:** o TTS lê o "texto falado" em GRAFIA BRASILEIRA (`tools/voice/r3/brasil.py`: ti/di → tchi/dji, -e átono → -i, -o átono → -u). A legenda continua com o texto certo.
  - Resultado: 0,80 de média em 41 falas depois dos efeitos. Doc: `C:\gnosis-wt\_caps\dublagem\r3_ptbr\R3_PTBR.md`.
- **Checagem de sotaque (obrigatória em todo lote novo):**
  1. `venv-qwen\python -I fonemas.py @mapa.json --out x_fon.json` (mapa = `{wav: texto}`; roda na GPU em segundos; na CPU travou ~30 min, NÃO use CPU).
  2. `venv\python -I sotaque_br.py x_fon.json --out x_sotaque.json`.
  3. Grave a `nota_br` no `.json` de cada tomada (`"br"`): o `r3/post_qa.py` prefere a tomada mais brasileira.
- **Vozes-base PT-BR novas** (projetadas com o texto em grafia BR):
  - Sophia/Narradora = `r3/refs/sophia_s43.wav`;
  - Demiurgo (Voz, Rei, Yaldabaoth) = `r3/refs/demiurgo_sonda_s44.wav`;
  - texto ICL em `refs_br_escolhidas.json` (já em grafia BR).
  - As outras 11 vozes (Arcontes etc.) ainda NÃO foram refeitas em grafia BR: repita o passo de `refs_br` (VoiceDesign, 4 sementes, escolher por nota BR + CER + tom) ao gravar o texto novo delas.
- **Amostra v2 da Narrativa** (`C:\gnosis-wt\_caps\narrativa\AMOSTRA_LIMIAR.md`):
  - 48 falas + 1 extra do Rei na final, em `C:\gnosis-wt\_caps\dublagem\r3_ptbr\amostra_limiar\`;
  - faixa única `amostra_limiar_corrida.ogg`;
  - os jobs e scripts estão em `r3_ptbr\_scripts\` (`job_clone_amostra.json`, `job_post_amostra.json`).
- **NÃO gerar os lotes 2–7:** o texto do jogo está sendo REESCRITO (decisão: "você" no jogo todo; o Rei usa "nós").
- **O lote limiar-1 do `dir7/dublagem-lote` (4920893) tem o sotaque ERRADO e o texto ANTIGO:** substituir pelo texto novo quando a Narrativa fechar.
- **Pendente:** C2/C5 (Rei em luta) duram 3,3–3,7 s, acima do limite de 2,5 s. É preciso texto mais curto ou o Rei mais rápido só na luta.

## 0a. BILHETE R2 (histórico — receita Qwen, pipeline de lotes)

**Mudança de motor (R2):** o João achou as vozes PT da R1 "de professora". A receita nova é
**Qwen3-TTS (Apache-2.0)**:
- a voz de cada personagem é PROJETADA uma vez por descrição de texto (VoiceDesign, sintética, ninguém clonado);
- todas as falas são ditas com essa voz fixa (modelo Base, clonagem ICL da referência projetada);
- depois vem o pós por personagem (`post_qa.py`: legião, dobra, espelho...), com QA por ASR DEPOIS dos efeitos.

Amostras e comparação: `C:\gnosis-wt\_caps\dublagem\r2\R2_AMOSTRAS.md`. A R1 (Kokoro + Chatterbox) virou só referência.

- **Estado:**
  - Lote **limiar-1** (11 falas: prólogo, intro, `king_intro`, `king_fall`) entregue no branch
    **`dir7/dublagem-lote`** (worktree `C:\gnosis-wt\dublagem-lote`, base `integracao/onda1` f1fe98a), commit `4920893`, push feito.
  - VoiceProbe 0 falhas; validate.ps1 TUDO VERDE.
  - Tabela do Guardião: `C:\gnosis-wt\_caps\dublagem\r2\entregas\limiar-1.md`.
- **Falta** (535 falas, PT), em lotes ENCADEADOS no mesmo branch (cada lote = 1 commit só com voice/*.ogg, .import e o manifest acrescentado):
  - **eon-1:** `eon_intro`, `walk_arrival`, `walk_cleared`, `node_arrival`, `sleeper_line`.
  - **arcontes:** `temptation`, `archon_phase2`, `archon_phase3`, `_archon_death`, `ring_gained`, `echo_memory`.
  - **encontros:** `soter_*`, `velkar_*`, `after_soter`, `concession_response`, `refusal_response`.
  - **clímax:** `sanctuary`, `seventh_ring`, `theft`, `final_pre`, `center_intro`, `final_lines`, `ending_lines`, `epilogue_cards`, `death_revive`.
  - **pools:** `_arrival_pool`, `_cleared_pool` (176).
  - **estelas:** `gnosis.stela` (107; o jogo ainda não as toca).
  - EN não foi gerado (mesma receita com `lang en`; a voz fixa fala EN).
- **Receita por personagem:** `tools/voice/r2/elenco_r2.json` (descrição de cada voz-base + preset de pós).
  - As vozes-base estão em `tools/voice/r2/refs/<voz>_ref_24.wav`, com o texto em `escolhidas.json`.
  - Sementes escolhidas: sophia s11, demiurgo s13, narrador s13, athoth s12, harmas s11, galila s12, yabel s12, belias s12, armupiel s13, soter s13, velkar s11, adormecida s13, adormecido s11.
  - **NÃO regere as refs:** são a identidade fixa das vozes.
  - Rei, Yaldabaoth, A Voz e O Cego usam a voz-base `demiurgo` (o mesmo ser); Astaphaios e "Uma voz nos Anéis" usam `sophia`; Estela usa `narrador`.
  - Intensidade do Demiurgo (`mk_lote.preset`):
    - O Rei = `legiao1` (nível 2);
    - Yaldabaoth em cena = `legiao3`, ou `legiao4` com grito;
    - batalha final (`final_*`/`center`/`ending`) = `legiao4`, ou `legiao5` com grito.
- **Rodar um lote** (`P=C:\gnosis-wt\_caps\dublagem\r2\_scripts\prod` — cópia versionada em `tools/voice/r2/`):
  1. `venv\python -I mk_lote.py <nome> <fontes,...> --seeds 1,2,3` (o roteiro é `P\roteiro.json`; re-extraia com `extract_lines.py --root C:\gnosis-wt\dublagem-lote --out P\roteiro.json` se o texto mudar).
  2. `venv-qwen\python -I gen_qwen.py job_clone_<nome>.json --batch 6 --prio normal` (GPU, RTF ~1,5 em lote; retomável: pula o wav existente).
  3. `venv\python -I post_qa.py job_post_<nome>.json` (CPU; escolhe o melhor dos 3 por CER + similaridade ≥ 0,90; reprova com CER pós > 0,15, ou > 0,20 na legião).
  4. Reprovadas: novas sementes (`--seeds 4,5`, mas mantenha 1,2,3 nos `cands`) + `--retry`.
  5. `venv\python -I entrega.py <nome>` (copia para `dublagem-lote` e acrescenta o manifest).
  6. Godot `--headless --audio-driver Dummy --editor --quit`, VoiceProbe, `tools\validate.ps1`.
  7. Commit SÓ de `assets/audio/voice` (o reimport suja outros `.import`: NÃO os adicione) + push + avisar o chefe.
- **venvs:** `C:\Users\jmtat\gnosis-tools\voice\venv-qwen` (qwen-tts 0.1.1, torch 2.9.1+rocm7.2.1 de repo.radeon.com, `constraints.txt`); `venv` (ASR/pós); `venv-rocm` (Chatterbox, só a abordagem A).
- **Armadilhas:**
  - heredoc no Bash desta máquina come `\\`: escreva JSON com `/`.
  - `cudnn.enabled=False` no ROCm.
  - Em `HF_HUB_OFFLINE` o modelo é carregado pelo caminho do snapshot.
  - Lote misto (`--batch 6`) é ~2,5× mais rápido que 1 por vez.
  - O grito da voz fixa é CONTIDO (o tom sobe só 15–25%); o berro real só sai no VoiceDesign (outro timbre). A decisão é do João (R2_AMOSTRAS.md).
  - Gritos de combate devem ter ≤ 2 s (Guardião §12) e falas de luta ≤ 2,5 s: `post_qa` acelera até 20%; acima disso, a fala é reprovada.

## 0b. BILHETE R1 (histórico, 18/10)

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

**GPU (venv-rocm):** mesmos scripts com `--device cuda`. Lote SEMPRE em
`BelowNormal`, `VOICE_THREADS=2` (torch na CPU) e `VOICE_ASR_THREADS=2` (Whisper)
— regra do PC: ≤ 4 threads, 1 job de GPU por vez, GPU ≤ 60% média
(`tools/voice/gpu_usage.ps1` mede). O `dub_all` roda em PIPELINE: a thread
principal só gera na GPU; o QA (Whisper/pós/ogg) roda em paralelo numa thread.

## 6. CHECAGEM DE SATISFAÇÃO (docs/handoff/NEURO_SATISFACAO.md)

**R2 / REGRAS_GUARDIAO.md (29/10), conferido no lote limiar-1:**
- **§21 R13:** −21 LUFS integrado (short-term máx. −19,1), true peak ≤ −1,6 dBTP no .ogg. O grito sai a −18, ou seja +3 LU, dentro do limite de +4.
- **§16 legião:** a principal fica ≥ 6,5 dB acima do bus de ecos; ecos com tom e formante diferentes, atrasos de 25–58 ms e passa-altas de 150 Hz; de-esser no grito. No começo (Rei, tela 1) a legião é nível 1: só 2 ecos a −13 dB. A legião cheia fica para a final (§15).
- **§17:** reverbs novos ≤ 1,75 s em cena; em combate o IR é trocado por 0,7 s.
- **§9/§13:** cena ≤ 12 s (máx. 10,4 s no lote); a fala de luta é acelerada até 20% para caber em 2,5 s, ou é reprovada.
- **Inteligibilidade:** ASR depois dos efeitos (CER ≤ 0,15; ≤ 0,20 na legião).
- **Uma voz fixa por personagem:** similaridade de locutor ≥ 0,90 (medida 0,97–0,99).
- **§4:** nenhum truque de recompensa; voz não é aviso de golpe (R5).
- **Pendente** (não é da Dublagem): QA de skip, de morte e de Voz 0% (Áudio/Integrador). Gritos de combate ≤ 2 s (§12): as amostras de grito têm 4,7–7 s porque são falas de cena; ainda não foi gerado nenhum grito de combate.

| Regra | Como a dublagem cumpre | Estado |
|---|---|---|
| **R13 volume/fadiga** | cada fala a −18 LUFS (voz fica ~4–6 LU acima da mixagem de −20/−23 do jogo = inteligível sem gritar); **true peak ≤ −1 dBTP medido no .ogg decodificado** (limitador com antecipação a −2 dBTP antes do Vorbis + conferência e recodificação — `voicelib.tp_limit/write_ogg`, `tp` no manifesto). Pedido do Guardião: 29/72 amostras antigas passavam de −1 dBTP → `tp_fix.py` corrige as amostras; o rascunho novo já sai certo (`PIPE_VER = 2` refaz o que foi gerado antes). | código pronto; amostras: rodar `tp_fix.py --fix` (foi interrompido pela pausa de CPU) |
| **R9 ducking** | a voz pede ducking da música (−9 dB do diálogo + −3 dB enquanto a voz soa); nos grandes momentos (roubo, anagnórise) a regra das cenas musicais manda (`SCENE_DUCK_SCALE`). Legendas com voz pedem `duck_music` só durante a fala. | pedido ao Áudio |
| **tell_unblock (Guardião)** | o aviso de ataque inbloqueável NÃO pode ser mascarado por voz grave (Yaldabaoth, Armupiel, Harmas têm energia forte < 300 Hz). Pedido: enquanto `tell_unblock` toca, o bus Voice desce −8 dB com corte de graves (passa-altas 250 Hz, ataque 10 ms, soltura 300 ms); e nenhuma voz de luta começa nos 400 ms depois de um tell. | pedido ao Áudio |
| **Bus Voice → Master** (Guardião) | hoje `Voice` é filho de `SFX` (pega volume de efeitos e o passa-baixas da câmera lenta). Mudar o send para `Master` + volume próprio. | pedido ao Áudio |
| **R21 respiro / voz não atropela combate** | só falam durante a luta as legendas de **fase 2** dos Arcontes (1 fala curta por luta, 1,8–6 s) — nada de bordão repetido; as falas longas ficam em caixa de diálogo (jogo pausado) ou caminhada sem inimigos. A fila da CaptionBar não sobrepõe vozes. | desenho (§7) |
| **§4 repetição irritante** | toda fala é única no run (regra do ESTILO §6.3); **nenhuma voz de dor/esforço** foi gerada (os "argh" de golpe seguem como SFX com round-robin — R11, do Áudio). `death_revive` tem variações por número de quedas. | ok |

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
