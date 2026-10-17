# GNOSIS: o que dá satisfação visual e sonora (neurociência e psicologia do jogador)

> Pesquisador de Neurociência/Psicologia do Jogador. Onda 1, 17/10/2026. **Somente leitura no jogo.**
> Base lida: `Gnosis-Codex - Copia` (branch `codex/despertar`). Linhas citadas como `arquivo:linha`.
> Pedido do dono: características **sutis**, que o jogador **sente sem perceber o truque**.
> Meta: satisfação, não vício.

## 0. Como ler este documento

**Nível de evidência** (marcado em cada item):
- **[P]** estudo revisado por pares (psicologia, neurociência, IHC) ou norma técnica (W3C/ITU)
- **[I]** dado da indústria: GDC, postmortem, desenvolvedor descrevendo o próprio jogo, dados de frame de jogo publicado
- **[H]** heurística de designer: consenso de prática, sem estudo controlado

Seja honesto com o peso de cada um. Quase tudo de "game feel" fino (quantos ms de hitstop, quantos px de tremor)
é **[I]/[H]**. A ciência dá o *porquê* (predição de recompensa, integração multissensorial, saliência,
habituação). Os *números* finos vêm da indústria e **têm de ser confirmados no playtest do João**.

**Os 5 princípios que sustentam tudo:**
1. **Contingência e sincronia.** O cérebro funde som e imagem num único "evento" só quando eles chegam juntos
   (janela de integração de algumas dezenas de ms; som atrasado é mais tolerado que som adiantado [P]).
   Impacto que "não bate junto" parece de plástico.
2. **Proporcionalidade.** O tamanho do feedback tem de seguir o peso da ação. Golpe leve e pesado com o mesmo
   congelamento soam iguais pro corpo. Sakurai: golpe mais forte, hitstop mais longo [I].
3. **Dose média vence dose máxima.** No maior estudo controlado sobre "juice" (Kao 2020, RPG de ação),
   juice médio e alto **superaram** tanto o zero quanto o **extremo** em experiência, motivação intrínseca,
   tempo de jogo e desempenho [P]. Kao et al. 2024 viram que **amplificar** o feedback chegou a *reduzir* a
   motivação, e que feedback **dependente do sucesso** (que responde à habilidade) aumentou todos os motivos [P].
   → Juice que **informa** o desempenho, não juice que só enfeita.
4. **Erro de predição e habituação.** A dopamina fásica responde mais ao que é *melhor que o previsto*
   (Schultz, Dayan & Montague 1997) [P]. O estímulo idêntico repetido perde força. → Os efeitos grandes
   (slow-mo, clarão, silêncio) têm de ser **raros**, e os pequenos precisam de **microvariação**.
5. **Competência, autonomia, vínculo (SDT).** O prazer duradouro em jogos acompanha a sensação de competência
   e de autonomia (Ryan, Rigby & Przybylski 2006) [P]. → O melhor feedback é o que **ensina e confirma a
   habilidade**: parry, esquiva perfeita, combo. Não o que só "dá coisa".

---

## 1. Retrato do que existe hoje (valores medidos no código)

| Sistema | Onde | Valor atual | Leitura |
|---|---|---|---|
| Hitstop de todo acerto | `scripts/combat/hitbox.gd:32` | **50 ms fixo** (time_scale 0,05) | Leve ok; o **pesado não ganha mais** |
| Hitstop novo enquanto outro roda | `scripts/autoload/juice.gd:28-29` | **ignorado** | Pesado que acerta durante um leve perde o congelamento |
| Hitstop: queda aérea / parry / fase 2 / morte de chefe | `player.gd:396`, `player.gd:502`, `enemy.gd:661`, `enemy.gd:897` | 80 / 120 / 150 / 120 ms | Bons |
| Hitstop de projétil | `scripts/fx/projectile.gd:69` | 40 ms | Bom (Sakurai: projétil congela menos) |
| Tremor por acerto | `hitbox.gd:33` | trauma 0,18 + dano×0,006 (dano 20 → 0,30) | Sutil sozinho, mas **soma por inimigo atingido** |
| Tremor: curva e teto | `scripts/fx/camera_shake.gd:5-6,37-41` | trauma², teto 9×7 px (em 640×360), decai 1,4/s | Boa base |
| Ruído do tremor | `camera_shake.gd:38-41` | `randf()` **novo a cada quadro** (o `noise_speed` não é usado) | Treme "chiado", não "rola" |
| Flash do alvo | `enemy.gd:912-917`, `player.gd:802-807` | tween até branco em **30 ms de tempo de jogo** | No hitstop (escala 0,05), 30 ms de jogo = **600 ms reais** → o flash quase **não aparece** durante o congelamento |
| Slow-mo de finalização | `enemy.gd:771,774`, `player.gd:644,721`, `final_battle.gd:55` | 0,22× por 0,55 s (último inimigo vivo); chefe 0,15× por 1,1 s; esquiva perfeita 0,3× por 0,35 s | Doses boas, mas **volta seca** para 1,0 (`juice.gd:49-51`) e dispara a **cada fim de onda** |
| Telegrafo inimigo | `enemy.gd:40-41,447` | sprite inteiro multiplicado por amarelo (1, 0,85, 0,2) ou vermelho (1, 0,25, 0,25); **sem som** | Cor + pose; **sem forma e sem som** |
| Bug do telegrafo | `enemy.gd:778` → `_flash` termina em branco | acertar elite/chefe **durante o wind-up** (eles têm armadura) **apaga a cor do aviso** | Perde-se a leitura justamente do golpe perigoso |
| Golpe pesado: VFX | `hitbox.gd:41` (ImpactBurst → `VfxLibrary.hit` leve) + `player.gd:451` (hit pesado) + `enemy.gd:781` (hit pesado) | **3 explosões por acerto** (~41 fagulhas, 3 clarões, 2 talhos) | Excesso: o "extremo" de Kao |
| Golpe pesado: som | `hitbox.gd:34` "hit" + `player.gd:449` "hit_heavy" + `enemy.gd:779` "enemy_hurt" (+ swing) | 3–4 camadas **por acidente** | Soma de picos, embola o grave, cansa |
| Variação de tom | `audio_manager.gd:66-69,140` | ±8 % (≈ ±1,3 semitom) em golpes; 1 arquivo por som | Ok, falta round-robin |
| Anti-spam | `audio_manager.gd:16` | mesmo som não repete em < 40 ms | Bom |
| Som posicional | `audio_manager.gd:147-153` | só atenua (> 380 px), **sem pan** | Falta lado esquerdo/direito |
| Som da faísca | `audio_manager.gd:286-290` | toca **quando a faísca é creditada** (na morte); o orbe voa por 0,3–1,5 s e **chega mudo** (`spark_orb.gd:33-36`) | **Dessincronia** entre som e recompensa visual |
| Combo | `hud.gd:216-224` | texto "N COMBO" + pop 1,1→1,0 em 180 ms; some após 1,4 s | Sem som, sem marco |
| Números de dano | `scripts/fx/damage_number.gd:9,33` | vida 0,7 s, tamanho 11/13/16 px | Bons, mas um por golpe (multi-hit vira "chuva") |
| Clarão de tela | `vfx_library.gd:127-141,300,346` | morte de chefe α 0,6 por 0,5 s; fase 2 α 0,35 por 0,3 s | Eventos únicos: ok pela WCAG |
| Opções | `scripts/ui/options_menu.gd:41-44` | slider de tremor + vibração | **Falta "reduzir flashes"** |
| Ducking / silêncio / filtro | `audio_manager.gd` (todo) | **não existe** | Música e efeitos competem |
| Buffer de entrada durante hitstop | `player.gd:417-421` | botão apertado no congelamento é guardado | **Manter**: é o que faz o hitstop não "travar" o jogador |

---

## 2. Recomendações priorizadas (22)

Ordem: **impacto ÷ esforço**. "Diretor" = quem implementa.
Quadros a 60 fps: 1 quadro = 16,7 ms.

### R1. O alvo pisca e treme DURANTE o congelamento (não depois)
- **Princípio:** no hitstop, o golpe "acontece" no quadro congelado. Sakurai: a vítima **vibra**
  (no chão, para os lados; no ar, para cima e para baixo), com amplitude que **começa grande e encolhe**
  durante o congelamento. O atacante quase não vibra e as hurtboxes ficam paradas [I]. A análise de God of War
  (2018) descreve o mesmo: alvo "salta" para a pose de dor e os dois ficam presos naquele primeiro quadro [I].
- **Hoje:** `enemy.gd:912-917` / `player.gd:802-807` fazem o tween de entrada do flash com o tempo de jogo, então
  ele quase não progride enquanto `Engine.time_scale = 0.05`. Não há vibração da vítima.
- **Recomendado:**
  - flash **instantâneo**: `modulate = cor` no mesmo quadro, mantido durante todo o hitstop e depois apagado
    em **100–120 ms reais** (`tween.set_ignore_time_scale(true)`, Godot 4.3+);
  - vibrar só o `visual` da vítima: **±3 px** (golpe pesado) / **±1,5 px** (leve) na horizontal, trocando de
    lado a cada **~33 ms reais**, com a amplitude caindo linearmente até 0 no fim do hitstop. Usar relógio real
    (`Time.get_ticks_msec()`) e não mexer em hurtbox nem colisão.
- **Por que é sutil:** dura 50–130 ms. Ninguém "vê" a vibração, mas todo mundo sente o golpe "entrar".
  E tira peso do tremor de tela (bom para R3 e para acessibilidade).
- **Diretor:** Combate/juice (+ Animação para a pose de dor no 1º quadro).

### R2. Hitstop proporcional ao peso, e o maior vence
- **Princípio:** golpe mais forte, hitstop mais longo, com teto; projétil congela menos [I, Sakurai].
  Fórmulas publicadas do Smash: Melee ≈ ⌊dano/3 + 3⌋ quadros; Ultimate ≈ dano×0,65 + 6 [I, SSBWiki].
  Num beat-em-up com 4–8 golpes/s, use a ponta curta dessas escalas.
- **Hoje:** 50 ms para todo acerto (`hitbox.gd:32`). `juice.gd:28-29` **ignora** um pedido novo quando já há
  hitstop ativo.
- **Recomendado (60 fps):**

  | Evento | Quadros | ms |
  |---|---|---|
  | leve 1º/2º da string | 3 | 50 (manter) |
  | leve final da string / launcher | 5–6 | 83–100 |
  | pesado | 6–7 | 100–117 |
  | queda aérea (já 80) | 6 | 100 |
  | **golpe que mata** (não o último da tela) | +2 sobre o golpe | +33 |
  | Sophia tomando dano | 4–5 | 67–83 |
  | multi-hit (Giro), ticks intermediários | 1–2 | 17–33; o último tick vira "final" |
  | parry (já 120) | 7–9 | 120–150 (manter) |
  | fase 2 / morte de chefe | 9–12 | 150–200 (manter) |
  | **teto** | — | **200** |

  Em `Juice.hit_stop`, se já houver hitstop, **estender até `max(restante, novo)`** em vez de ignorar.
  Um golpe que pega 3+ inimigos ganha **+1 quadro** (não um por inimigo).
- **Por que é sutil:** a diferença entre 50 e 100 ms não é percebida como pausa, e sim como "esse pesou".
- **Diretor:** Combate/juice. Os valores por golpe ficam no `ComboData`.

### R3. Tremor de câmera: deduplicar, suavizar e dar direção
- **Princípio:** o modelo de *trauma* (forte = trauma², decai com o tempo) usa **ruído contínuo (Perlin)**, não
  aleatório por quadro, para o tremor "rolar" em vez de "chiar" (Eiserloh, GDC 2016) [I]. Tremor com direção
  (chute para o lado do impacto) informa mais que tremor aleatório (survey Pichlmair & Johansen) [P-survey/I].
  God of War 2018 **reduziu muito** o tremor de câmera e passou o impacto para áudio e animação [I].
  A Supergiant pôs uma opção para desligar o tremor em Hades depois de pedidos de acessibilidade [I].
- **Hoje:** `camera_shake.gd:38-41` sorteia `randf()` a cada quadro. `hitbox.gd:33` chama `shake` **uma vez por
  inimigo atingido**: um leve que pega 4 inimigos soma ~1,2 → satura em 1,0 → tremor máximo de 9 px.
  O pesado ainda soma 0,4 no wind-up (`player.gd:380`).
- **Recomendado:**
  - `Juice.shake`: **no mesmo quadro, fica o maior pedido, não a soma**. Entre quadros diferentes, soma normal.
  - Ruído suave: `FastNoiseLite` (Perlin/Simplex), frequência equivalente a **12–18 Hz**, eixos x e y com sementes
    diferentes. Manter trauma², teto 9×7 px e decaimento 1,4/s.
  - **Chute direcional** nos golpes da Sophia: deslocar a câmera **2 px (leve) / 4 px (pesado)** no sentido do
    golpe e voltar em **90–120 ms** (ease-out). Isso substitui o trauma de acertos leves (leve = trauma 0).
  - Trauma recomendado: leve 0 (só chute), pesado 0,30, queda aérea 0,5, parry 0,35, dano recebido 0,35,
    fase 2 0,7, morte de chefe 0,9 → 1,0. O ápice é raro.
  - Durante o hitstop, **congelar o offset do tremor** (a vibração fica na vítima, R1).
- **Por que é sutil:** a tela quase não se mexe em golpes comuns, e a direção do chute "empurra" junto com a
  espada. O tremor grande fica guardado para o que importa.
- **Diretor:** Combate/juice.

### R4. Um acerto = um evento de impacto (fim do VFX e do som triplicados)
- **Princípio:** dose média > extrema (Kao 2020) [P]. Redundância de feedback ajuda até o ponto em que vira
  ruído visual e carga cognitiva (Sweller) [P]. Sons empilhados sem desenho somam picos e embolam o grave [H].
- **Hoje:** um pesado gera ImpactBurst (com `VfxLibrary.hit` leve), mais `VfxLibrary.hit` pesado no ponto da
  Sophia (`player.gd:451`), mais `VfxLibrary.hit` pesado no inimigo (`enemy.gd:781`). No som: "hit" + "hit_heavy"
  + "enemy_hurt".
- **Recomendado:**
  - **VFX:** um único `VfxLibrary.hit(pos_de_contato, heavy)` por par atacante-alvo. Leve: 6–9 fagulhas;
    pesado: 12–16 + talho + poeira.
  - **Som em camadas, de propósito:** (a) **transiente** de 5–20 ms com energia em 2–5 kHz (o "estalo"); (b)
    **corpo** de 80–250 Hz com decaimento de 80–200 ms; (c) no pesado, um **sub** de 50–90 Hz (ver R12).
    Pesado = "hit_heavy" no lugar de "hit", não por cima.
  - "enemy_hurt" (voz) em **no máximo 1 a cada 2–3 acertos** no mesmo inimigo, ou 1 a cada ≥ 250 ms. Voz
    repetida cansa mais rápido que impacto.
- **Por que é sutil:** o jogador não nota que tem "menos". A tela fica limpa e cada pesado parece mais forte,
  porque o leve deixou de competir com ele.
- **Diretor:** Combate/juice (onde cada coisa é chamada) + Cenário/VFX (o burst) + Áudio (camadas).

### R5. Telegrafo que ensina o parry: brilho no tempo certo + forma + som (e consertar o bug)
- **Princípio:** God of War usa anéis de cor para golpe aparável e imparável, e Ghost of Tsushima herdou isso
  como **brilhos azul/vermelho** [I]. A diretriz de acessibilidade pede "nenhuma informação essencial só por
  cor" e "sons distintos para eventos-chave" [P-norma/diretriz]. ~8 % dos homens têm alguma deficiência de
  cor (vermelho-verde é a mais comum) [H-estatística secundária].
- **Hoje:** `enemy.gd:447` pinta o sprite inteiro de amarelo/vermelho (multiplicação forte: o vermelho
  (1, 0,25, 0,25) escurece a arte pintada), sem som e sem forma. `PARRY_WINDOW` = 180 ms (`player.gd:20`).
  O wind-up dura 0,5–0,9 s (`enemy.gd:108-129`). **Bug:** `_flash` em `enemy.gd:778` acaba em
  `Color(1,1,1)` e apaga o aviso quando o elite/chefe com armadura é atingido no wind-up.
- **Recomendado:**
  - Tingir **40–50 %** em direção à cor (lerp), em vez de multiplicar 100 %, e somar um **brilho de contorno
    aditivo** pulsando a **2 Hz** (abaixo de 3 Hz).
  - **Brilho de aviso ("glint")** em `strike − 180 ms`, que é exatamente quando a janela de parry abre: estrela
    de 120 ms no ponto da arma.
    - Amarelo (aparável): **forma redonda** + "tink" curto (3–5 kHz, 40 ms, −14 dB).
    - Vermelho (imparável): **forma pontiaguda/losango** + "whoom" grave crescente (80–150 Hz, 250 ms, −10 dB).
    Amarelo e vermelho já diferem em luminância (~0,85 vs ~0,40). Forma e som fecham o caso de daltonismo e de
    golpe fora da tela.
  - `_flash` passa a voltar para a **cor-base do estado** (telegrafo, se em WINDUP), não para branco.
  - O glint fica **acima** de todo VFX de impacto (z-index): aviso nunca pode ser coberto por fagulha.
- **Por que é sutil:** ninguém lê "o brilho marca a janela". Depois de 3–4 lutas, o jogador **aprende o ritmo**
  e sente que "ficou bom de parry". É competência pura (SDT).
- **Diretor:** Combate/juice (timing, bug) + Cenário/VFX (glint, contorno) + Áudio (2 sons novos no CATALOG).

### R6. Faísca: o som chega junto com o orbe e sobe em escala
- **Princípio:** som e imagem só se fundem num evento dentro de uma janela curta; a norma de broadcast tolera o
  som **até ~45 ms adiantado e ~125 ms atrasado** antes de alguém notar (ITU-R BT.1359) [P-norma], e as
  pesquisas de janela de integração audiovisual dão ordens parecidas [P]. Sons de coleta em intervalo
  consonante (a moeda do Mario é uma quarta justa) e "escalas que sobem" (Peggle: o acerto em cada pino toca
  uma escala ascendente afinada com a música) [I]. A consonância é preferida de forma robusta e ligada à
  harmonicidade (McDermott et al. 2010) [P].
- **Hoje:** `audio_manager.gd:286-290` toca "spark" uma vez na morte (crédito). Os 3–9 orbes chegam depois,
  **mudos** (`spark_orb.gd:33-36`). O HUD pula o número na hora (`hud.gd:277-278`).
- **Recomendado:**
  - Tirar o "spark" do crédito e tocar **um tique por orbe na chegada**, a **−10 a −14 dB**, com tom seguindo a
    **pentatônica maior**: semitons `[0, 2, 4, 7, 9, 12, 14, 16, 19]` no índice do orbe dentro do burst
    (`pitch_scale = pow(2, s/12.0)`), sem variação aleatória (essa escala é a "variação").
  - Espaçar as chegadas em **40–70 ms** (variar a força de atração por orbe), formando um arpejo curto.
  - O contador do HUD **conta de 1 em 1 na chegada** de cada orbe, com pop 1,0→1,15→1,0 em 120 ms.
- **Por que é sutil:** o jogador ouve um "brilho musical" de meio segundo, sem perceber que é uma escala. A
  recompensa é previsível (sempre a mesma quantidade por inimigo, sem sorteio) e só fica **gostosa de receber**.
- **Diretor:** Áudio (tique) + Combate/juice (`spark_orb.gd`) + UI (contador).

### R7. Combo com "adoçante" tonal discreto
- **Princípio:** subida de tom acompanhando sequência acertada sinaliza progresso; é o mesmo princípio de R6 [I/H].
  Feedback que depende do sucesso aumenta motivação (Kao et al. 2024) [P].
- **Hoje:** `hud.gd:216-224` só mostra texto; não há som de combo.
- **Recomendado:**
  - A partir do **3º acerto**, tocar por cima do impacto um "tique" brilhante a **−14 a −18 dB** com pitch
    `pow(2, s/12)`, `s` = pentatônica `[0,2,4,7,9,12,14,16]` limitada em +16. Volta a 0 quando o combo zera.
    O impacto em si **não muda de tom** (impacto agudo soa fraco).
  - Marcos em **10, 25 e 50**: pop maior no texto (1,0→1,3 em 80 ms, volta em 200 ms) e o texto esquenta
    (branco → dourado do Éon).
  - Mostrar a "validade" do combo (1,4 s) como **filete que esvazia** sob o número.
- **Por que é sutil:** a −16 dB o tique fica "dentro" do impacto. O jogador sente que a sequência "está
  subindo" sem identificar a nota.
- **Diretor:** Áudio + UI.

### R8. Slow-mo: abafar o som, sair em rampa e racionar
- **Princípio:** câmera lenta comunica o que seria rápido demais para perceber [survey P/I]. Mas o mesmo estímulo
  repetido habitua (predição de recompensa) [P]. Abafar o som (passa-baixas) junto com a lentidão vende a
  "bolha de tempo" [H/I].
- **Hoje:** slow-mo em todo "último inimigo vivo" (`enemy.gd:772-775`), ou seja, **a cada fim de onda**. O retorno
  para 1,0 é seco (`juice.gd:49-51`). O áudio não muda.
- **Recomendado:**
  - Enquanto `time_scale < 0,5`: `AudioEffectLowPassFilter` nos barramentos SFX + Music, corte **20 kHz → 1,5 kHz**
    em 60 ms, volta em 250 ms; música **−4 dB**. Na esquiva perfeita, corte em **2,5 kHz** (mais leve).
  - Saída: rampa de `scale` até 1,0 em **150–200 ms reais** (ease-in), não degrau.
  - **Racionar:** slow-mo de fim de onda só se (a) o golpe final for pesado, aéreo ou magia, **ou** (b) for o fim
    da **tela** (zona limpa). Senão, só +33 ms de hitstop de morte (R2). Meta: **≤ 1 slow-mo de finalização a
    cada 60–90 s** de jogo comum. Chefe e batalha final ficam como estão.
- **Por que é sutil:** o abafamento passa por "sensação de tempo parado", ninguém nomeia o filtro. Racionar faz o
  slow-mo voltar a surpreender.
- **Diretor:** Combate/juice + Áudio.

### R9. Ducking e silêncio antes dos grandes momentos
- **Princípio:** a dopamina participa da **antecipação** (caudado) e do **pico** (accumbens) em música
  (Salimpoor et al. 2011) [P]. Contraste dinâmico (tensão e alívio) é como o RE Village descreve o próprio
  combate de perto [I]. Abrir espaço para o som importante melhora a clareza [H, prática padrão de mixagem].
- **Hoje:** não há ducking nem silêncio programado.
- **Recomendado:**
  - **Ducking** da música (offset sobre o volume do jogador): `boss_appear`, `ring_gain`, `ring_steal`,
    `level_clear`, `weapon_upgrade` → **−6 a −8 dB**, ataque 40 ms, release 600 ms. Parry → **−3 dB** por 250 ms.
    (Via tween no volume do barramento Music, ou `AudioEffectCompressor` com `sidechain` num barramento
    "SFX_Key".)
  - **Silêncio antes do chefe:** 1,0 s antes do `boss_appear`, a música desce a **−24 dB** em 0,6 s. O stinger
    entra no vazio e a faixa de chefe começa 0,3 s depois.
  - **Golpe que mata o chefe:** música corta em 150 ms durante o slow-mo, `boss_die` toca sozinho, a música
    volta **1,5–2,5 s** depois.
- **Por que é sutil:** o jogador não percebe a música baixar, só sente que "o momento ficou enorme".
- **Diretor:** Áudio.

### R10. Fotossensibilidade: no máximo 3 flashes/s e opção "Reduzir flashes"
- **Princípio:** WCAG 2.3.1: nada pisca mais de **3 vezes por segundo**, a menos que fique abaixo dos limiares
  de flash geral e de vermelho. A área de risco é ~25 % de um campo de 10°, que equivale a um retângulo de
  **341×256 px a 1024×768** (≈ **427×240 px a 1280×720**, ≈ 1/9 da tela). Transições para ou de **vermelho
  saturado** são mais perigosas [P-norma].
- **Hoje:** cada acerto pisca o inimigo de (3,3,3) (`enemy.gd:778`). Com 4–6 acertos/s num **chefe grande**, o
  sprite pode passar da área do limiar e piscar acima de 3 Hz. O dano na Sophia pisca (4,1,1), vermelho forte
  (`player.gd:707`). Não há opção de flash.
- **Recomendado:**
  - Por inimigo: **flash cheio no máximo a cada 333 ms**. Os acertos no meio usam flash de **1,4** (meia força).
    Chefes (sprite grande): flash cheio de **2,0**, não 3,0.
  - Dano na Sophia: (2,2, 0,9, 0,9) em vez de (4,1,1), menos vermelho saturado.
  - Opção **"Reduzir flashes"** (padrão desligada): `screen_flash` α × 0,35, flash de sprite × 0,5 e glint (R5)
    mantido (é informação). Somar ao slider de tremor existente.
- **Por que é sutil:** quase ninguém nota a diferença entre 3 e 6 flashes/s, mas quem é fotossensível nota. E a
  luta com chefe fica menos cansativa para todo mundo.
- **Diretor:** Combate/juice (limites) + UI (opção).

### R11. Variação real: round-robin, limite de vozes e limitador
- **Princípio:** som idêntico repetido é o maior causador de fadiga auditiva em jogo de ação [H, prática
  consolidada]. O Godot tem `AudioStreamRandomizer` com `PLAYBACK_RANDOM_NO_REPEATS`, `random_pitch` e
  `random_volume_offset_db` [I-doc].
- **Hoje:** 1 arquivo por som (`audio_manager.gd:342-351`), ±8 % de tom, 16 vozes, anti-spam de 40 ms.
- **Recomendado:**
  - **3–5 variações** para `hit`, `hit_heavy`, `swing_*`, `step`, `enemy_hurt`, `land`, em `AudioStreamRandomizer`
    sem repetição, volume ±1,5 dB. Tom: impactos **±4 %** (≈ ±0,7 semitom; com várias amostras não precisa de
    ±8 %), passos ±6 %.
  - **No máximo 3 instâncias simultâneas do mesmo som** (rouba a mais velha).
  - `AudioEffectHardLimiter` no Master com teto de **−1 dBTP**.
- **Por que é sutil:** ninguém percebe a variação. Só percebem que, depois de uma hora, o som "não enjoou".
- **Diretor:** Áudio.

### R12. Peso no grave que sobrevive em alto-falante de notebook
- **Princípio:** música com mais grave aumentou a sensação de poder em experimento controlado (Hsu et al. 2015) [P].
  Tons graves dão melhor percepção de tempo/ritmo (Hove et al. 2014, PNAS) [P]. A análise de God of War: o
  machado tem um baque grave de força bruta que termina num corte agudo [I].
- **Hoje:** depende dos .ogg atuais. Não medi o espectro (não toquei áudio).
- **Recomendado:**
  - `hit_heavy`, `dive`, `nova`, `boss_*`: fundamental **50–90 Hz** + **harmônicos em 120–250 Hz** (leve
    saturação). Quem joga em notebook (que não toca < 150 Hz) "ouve" o grave pela fundamental ausente.
  - **Transiente** curto em 2–5 kHz para o "estalo". Evitar energia **sustentada** em 2–5 kHz em sons
    repetitivos (UI, combo, passos): é a faixa onde o ouvido é mais sensível (ISO 226) e a que cansa primeiro [P-norma].
  - Leve = sem sub. O grave fica reservado para o peso real.
- **Por que é sutil:** é timbre, não volume. O pesado "pesa" sem ser mais alto.
- **Diretor:** Áudio.

### R13. Volume integrado e fadiga
- **Princípio:** a referência de console para jogos é **−24 LUFS integrados (±2)** com **true peak ≤ −1 dBTP**
  (IESD/IASIG; a Sony usa a mesma ordem) [I]. Jogos de PC costumam ficar um pouco mais altos.
- **Recomendado:** medir **10 min de combate gravado** (ffmpeg `ebur128`): alvo **−20 a −23 LUFS integrados**,
  true peak ≤ −1 dBTP. Faixa de loudness da música de Éon **mais baixa que a de chefe** (≈ 3 LU) para sobrar
  espaço dinâmico no chefe.
- **Por que é sutil:** ninguém percebe loudness certo. Só percebem quando está errado e cansa.
- **Diretor:** Áudio.

### R14. Estéreo discreto pela posição na tela
- **Princípio:** o som espacial ajuda a localizar ameaças fora da tela e "cola" o som no objeto [H]. A diretriz
  de acessibilidade pede sons distintos por evento [diretriz].
- **Hoje:** `play_sfx_at` só atenua, sem pan (`audio_manager.gd:147-153`).
- **Recomendado:** pan = `clamp((x − centro_cam) / 320, −1, 1) × 0,5` (nunca 100 % num lado). Via
  `AudioStreamPlayer2D` com `panning_strength ≈ 0,5`, ou `AudioEffectPanner` por voz. Aplicar a inimigos,
  projéteis e telegrafos (R5), não à Sophia nem à UI.
- **Diretor:** Áudio.

### R15. Fagulhas que saem na direção do golpe
- **Princípio:** hit sparks comunicam **direção** e força. Efeito com direção semântica informa mais que efeito
  aleatório [I, Sakurai; survey].
- **Hoje:** `vfx_library.gd:153-154` (spread 180°, círculo inteiro) e `impact_burst.gd:23-26` (ângulos
  aleatórios em 360°).
- **Recomendado:** cone de **±50°** no sentido do golpe (`direction = Vector2(facing, −0,25)`), com 20 % das
  fagulhas em 360° para não parecer "jato". O talho do pesado alinhado ao arco do golpe (±15°), não aleatório
  (±40° hoje).
- **Diretor:** Cenário/VFX.

### R16. Números de dano: agrupar, "pop" e opção de esconder
- **Princípio:** números confirmam competência (SDT), mas em excesso viram ruído e carga cognitiva [P-teoria/H].
- **Hoje:** um número por acerto (`damage_number.gd`). Multi-hit e golpes em grupo viram chuva.
- **Recomendado:**
  - Acertos no **mesmo inimigo em até 300 ms** somam no número que já está na tela (ele cresce e dá pop).
  - Entrada com escala **1,35 → 1,0 em 80 ms** (ease-out-back). No pesado, tamanho +2 px.
  - No máximo **6 números vivos**. Opção "Números de dano: ligado/desligado".
- **Diretor:** UI.

### R17. "Confirmação de morte" distinta do acerto comum
- **Princípio:** o jogador precisa saber **na hora** que o golpe matou, sem conferir a barra. Isso é feedback
  dependente de sucesso [P, Kao 2024].
- **Recomendado:** no golpe que mata: +33 ms de hitstop (R2), impacto **2 semitons abaixo** e +2 dB (mais "baque"),
  1 quadro de **contorno branco** no corpo antes de cair ou desmembrar. Não usar slow-mo nisso (R8).
- **Diretor:** Combate/juice + Áudio.

### R18. Legibilidade: personagem sempre "salta" do fundo
- **Princípio:** o olho vai primeiro para **contraste, movimento e rostos** (modelos de saliência de Itti & Koch;
  rostos atraem o olhar, Cerf et al. 2008) [P]. A WCAG 1.4.11 pede **contraste ≥ 3:1** para objetos gráficos
  essenciais [P-norma; adaptado a jogo].
- **Recomendado:**
  - Teste do apertar de olhos: captura em **escala de cinza**. Sophia, inimigos e telegrafos com **≥ 3:1** de
    luminância contra o fundo local.
  - Fundo do plano de jogo **10–25 % menos saturado e com menos contraste interno** que os personagens
    (perspectiva atmosférica). Saturação máxima **reservada** para: telegrafos, faíscas e golpes da Sophia.
  - **Luz de contorno** de 1 px (cor do Éon, α 0,5) nas bordas de personagens contra fundos escuros.
- **Por que é sutil:** ninguém nota a hierarquia; só notam que "dá pra ler a luta" mesmo com caos.
- **Diretor:** Cenário/VFX + Animação (contorno).

### R19. Arco de golpe ("smear") que esconde as emendas das peças
- **Princípio:** antecipação, ação e continuidade (os 12 princípios da Disney, Thomas & Johnston) [H-clássico].
  O God of War usa arcos amplos com continuidade forte [I]. Em 2D pintado, um **arco de movimento** de 1–3 quadros
  substitui o borrão de movimento e esconde transições bruscas de pose. Isso também ataca a queixa do João
  ("foto cortada movida em peças").
- **Recomendado:**
  - Rastro em arco aditivo de **60–90 ms**, α 0,6 → 0, cor clara da arma, cobrindo o caminho da lâmina entre
    a pose de wind-up e a pose de impacto.
  - **Segurar a pose de impacto 2–4 quadros** (33–67 ms) antes da recuperação.
  - Antecipação: leve **50–80 ms**, pesado **150–250 ms** (conferir com `windup_time()` do ComboData).
- **Diretor:** Animação (+ VFX para o sprite do arco).

### R20. Squash & stretch moderado e com volume preservado
- **Princípio:** squash e stretch dão peso, mas em arte pintada (não cartum) o excesso parece borracha [H].
- **Hoje:** `player.gd:358` (1,18/0,86 leve; 1,32/0,80 pesado), `player.gd:397` (pouso 1,40/0,70), `player.gd:470`
  (esquiva 0,80/1,18), duração 60 + 160 ms (`player.gd:794-799`).
- **Recomendado:** leve **1,08/0,93**, pesado **1,15/0,87**, pouso **1,22/0,82**, esquiva **0,90/1,10**, mantendo
  x·y ≈ 1. Entrada em **40 ms**, volta em **140 ms** com leve overshoot (ease-out-back 1,2).
- **Diretor:** Animação.

### R21. Respiro: pausas curtas e HUD que recua fora de combate
- **Princípio:** flow pede alternância entre desafio e habilidade, não pressão constante (Csikszentmihalyi) [P-teoria].
  O espaço negativo e a pausa aumentam o impacto do evento seguinte (contraste) [H].
- **Recomendado:**
  - **2–4 s** de calma entre ondas (sem spawn, música um pouco mais rala se o Áudio tiver camadas).
  - HUD (faíscas, arma) em **α 0,6** após **4 s** sem combate, volta a 1,0 em 150 ms ao entrar em combate.
    Vida e Éter sempre visíveis.
- **Diretor:** UI + Cenário (ritmo das ondas, se for do Combate, avisar).

### R22. Aviso de vida baixa que não irrita
- **Princípio:** sinal contínuo e repetitivo cansa e vira ruído (o bip de vida baixa de Zelda é o
  contraexemplo clássico) [H].
- **Recomendado:** abaixo de **25 % de vida**: vinheta escura-avermelhada **α 0,12–0,18** pulsando a **0,8–1 Hz**,
  com batida grave de coração a **−18 dB** (60–80 Hz). Toca por **no máximo 8 s** e só volta se ela tomar
  dano de novo. Nunca acima de 3 Hz.
- **Diretor:** UI + Áudio.

### Tabela-resumo (impacto × esforço)

| # | Recomendação | Impacto | Esforço | Diretor |
|---|---|---|---|---|
| R1 | Flash instantâneo + vítima vibra no hitstop | Alto | Baixo | Combate |
| R2 | Hitstop por peso + "o maior vence" | Alto | Baixo | Combate |
| R3 | Tremor deduplicado, Perlin, chute direcional | Alto | Baixo | Combate |
| R4 | Um acerto = um evento (VFX e som) | Alto | Médio | Combate + VFX + Áudio |
| R5 | Telegrafo com glint/forma/som + bug | Alto | Médio | Combate + VFX + Áudio |
| R6 | Faísca: som na chegada, pentatônica, contador | Alto | Baixo | Áudio + UI |
| R10 | ≤ 3 flashes/s + "Reduzir flashes" | Alto (seg.) | Baixo | Combate + UI |
| R7 | Adoçante tonal do combo + marcos | Médio | Baixo | Áudio + UI |
| R8 | Slow-mo: filtro, rampa, racionar | Médio | Baixo | Combate + Áudio |
| R11 | Round-robin, 3 vozes/som, limitador | Médio | Baixo | Áudio |
| R17 | Confirmação de morte | Médio | Baixo | Combate + Áudio |
| R15 | Fagulhas direcionais | Médio | Baixo | VFX |
| R16 | Números agrupados + opção | Médio | Baixo | UI |
| R9 | Ducking + silêncio pré-chefe | Médio | Médio | Áudio |
| R12 | Grave com harmônicos | Médio | Médio | Áudio |
| R18 | Contraste 3:1, fundo dessaturado, contorno | Alto | Médio | Cenário + Animação |
| R19 | Arco de golpe + segurar pose | Alto | Médio | Animação |
| R13 | Loudness −20 a −23 LUFS | Médio | Baixo | Áudio |
| R14 | Pan estéreo × 0,5 | Baixo-médio | Baixo | Áudio |
| R20 | Squash moderado | Baixo | Baixo | Animação |
| R21 | Respiro + HUD recua | Médio | Médio | UI |
| R22 | Vida baixa discreta | Baixo | Baixo | UI + Áudio |

---

## 3. Neurociência da recompensa aplicada, e onde fica o limite ético

**O que a ciência diz (resumo honesto):**
- A dopamina fásica codifica **erro de predição**: sobe com o melhor que o esperado e cai com o pior (Schultz,
  Dayan & Montague 1997) [P]. Jogar videogame libera dopamina no estriado de forma mensurável (Koepp et al.
  1998, *Nature*) [P].
- A **antecipação** tem circuito próprio (caudado), separado do pico de prazer (accumbens) (Salimpoor 2011) [P].
  Por isso silêncio e preparação (R9) funcionam.
- **Recompensa variável** (sorteio) mantém comportamento com muita força e resiste à extinção. É o motor das
  loot boxes e caça-níqueis. **Quase-acerto** ("near miss") ativa circuitos de vitória e **aumenta a vontade de
  continuar mesmo sendo menos agradável** (Clark et al. 2009, *Neuron*, n pequeno) [P].
- Para um jogo **premium**, o prazer que dura vem de **competência e autonomia** (SDT), não de compulsão [P].

**Ético para o GNOSIS (use):**
- Variação **na apresentação** (tom, brilho, ordem das fagulhas, variações de som), com **quantidade fixa e
  determinística**. O jogo já faz isso: `spark_reward` por inimigo e balanceamento determinístico por tela. **Manter.**
- Surpresas **ganhas por habilidade**: parry, esquiva perfeita, combo alto e finalização pesada têm feedback
  melhor que o "normal". O "erro de predição positivo" vem de o jogador ter ido bem, não de sorte.
- Pontos naturais de parada: fim de Éon com save, sem punição por sair.
- (Opcional, decidir com o João) Misericórdia oculta: a Sophia sobrevive com 1 de vida a um golpe letal **uma
  vez por luta**, só com mais de 30 % de vida antes. Muitos jogos fazem isso. É a favor do jogador, mas é
  invisível. Se usar, que seja coerente e sem esconder morte "roubada".

**Não ético / evitar:**
- Sorteio de recompensa (baús com valor aleatório) amarrado a progressão. Nada pago, nunca loot box.
- Quase-acerto **fabricado** (chefe que "quase morreu" de propósito, barra que engana).
- Timers de "volte amanhã", sequências diárias com perda, aversão à perda como motor.
- Escalar o feedback **sem** ligação com o desempenho (Kao 2024: amplificação pura reduziu a motivação).

---

## 4. O que NÃO fazer (excessos que cansam)

1. **Tremor em todo acerto leve.** Habitua em minutos, dá enjoo em parte dos jogadores e esconde o telegrafo.
   GoW 2018 reduziu o tremor de propósito; Hades deu opção de desligar. Tremor é para o **raro**.
2. **Somar tremor por inimigo atingido** (bug atual, R3). Num grupo, golpe leve vira terremoto.
3. **Empilhar 3 VFX e 3 sons no mesmo acerto** (estado atual, R4). Em Kao 2020, o extremo perdeu para o médio.
4. **Clarão de tela cheia frequente.** Reservar para morte de chefe e fase 2 (≤ 1 por minuto). Nunca vermelho
   saturado de tela cheia. Nunca acima de 3 Hz em área grande.
5. **Slow-mo em todo fim de onda.** Vira espera. Racionar (R8).
6. **Hitstop longo em golpes rápidos.** Acima de ~100 ms no leve, o combo "gruda" e a entrada parece atrasada.
   Teto de 200 ms em qualquer caso. **Nunca descartar a entrada apertada durante o hitstop.**
7. **Mesmo arquivo de som repetido** dezenas de vezes por minuto (passos, golpes, voz de dor). Round-robin (R11).
8. **Voz de dor a cada acerto.** É o som que mais cansa. Rarear (R4).
9. **Energia sustentada em 2–5 kHz** em sons de UI e combo, e "bips" contínuos de vida baixa.
10. **Pitch do impacto subindo com o combo.** Impacto agudo soa fraco. A subida vai no adoçante, não no corpo (R7).
11. **Cor como único aviso** (amarelo vs vermelho sem forma e sem som). R5.
12. **Recompensa variável manipulativa** (seção 3).
13. **Mexer em tudo de uma vez.** Implementar em blocos e playtestar (o feel é cumulativo; dois ajustes bons
    somados podem passar do ponto).

---

## 5. Checklist de playtest para o João (10 itens, ~20 min)

Jogue 1 Éon inteiro + 1 chefe. Depois responda **sim / não / "mais ou menos"**.
Se possível, peça a 1 pessoa que nunca jogou para jogar também.

1. **Peso:** fechando os olhos e só ouvindo, dá para distinguir golpe leve de pesado? E abrindo, o pesado
   "pesa" sem a tela tremer muito?
2. **Golpe "entra":** quando o golpe acerta, você sente que **conectou** (o inimigo pisca e treme), ou parece
   que a espada atravessa o vento?
3. **Responsividade:** em algum momento o comando demorou ou "sumiu" depois de um acerto (sobretudo nos
   pesados e no fim de combo)?
4. **Cansaço visual:** depois de 15 min, a tela parece poluída ou cansativa? Teve vontade de baixar o tremor?
5. **Parry:** depois de 3 lutas, você aprendeu **quando** apertar o bloqueio só pelo aviso (brilho/som), sem
   adivinhar? Dá para distinguir aviso amarelo de vermelho **de relance**?
6. **Telegrafo coberto:** algum golpe inimigo te acertou "sem aviso" porque fagulhas ou explosões cobriam o
   inimigo?
7. **Faíscas:** o "tlin-tlin" das faíscas chegando dá vontade de recolher? Ou irrita depois de um tempo?
8. **Finalização:** a câmera lenta ainda surpreende no fim do Éon, ou virou rotina?
9. **Ouvido:** depois de 20 min, algum som ficou **chato** (sempre igual, agudo demais, voz de dor)? Qual?
10. **Momento grande:** a entrada e a morte do chefe deram arrepio (silêncio → estouro), ou passaram como
    mais uma luta?

**Bônus (acessibilidade, 2 min):** com tremor em 0 e "Reduzir flashes" ligado, o jogo ainda é legível e
gostoso? (Ele tem de ser.)

---

## 6. Fontes

**Revisado por pares / norma**
- Kao, D. (2020). *The effects of juiciness in an action RPG.* Entertainment Computing 34. Resumo dos achados
  em: Pichlmair & Johansen, *Designing Game Feel: A Survey* (IEEE ToG), https://arxiv.org/pdf/2011.09201
- Kao et al. (2024, CHI). *How does juicy game feedback motivate? Testing curiosity, competence, and effectance.*
  https://spiral.imperial.ac.uk/entities/publication/253c32f5-d124-4a23-88b5-9aaaf114608d
- Hicks, Gerling, Dickinson, Vanden Abeele (2019). *Juicy Game Design: Understanding the Impact of Visual
  Embellishments on Player Experience.* CHI PLAY. doi:10.1145/3311350.3347171
- Lin, Duan, Wen, Cai (2022). *What Features Influence Impact Feel? A Study of Impact Feedback in Action Games*
  (hitstop, coerência sonora e câmera como os 3 fatores-chave). https://arxiv.org/abs/2208.06155
- Ryan, Rigby & Przybylski (2006). *The motivational pull of video games: A self-determination theory approach.*
  Motivation and Emotion 30:347–363. https://www.rochester.edu/warner/lida/wp-content/uploads/2022/11/02bfe513dd59366750000000.pdf
- Schultz, Dayan & Montague (1997). *A neural substrate of prediction and reward.* Science 275:1593.
- Koepp et al. (1998). *Evidence for striatal dopamine release during a video game.* Nature 393:266 (PMID 9607763).
- Salimpoor et al. (2011). *Anatomically distinct dopamine release during anticipation and experience of peak
  emotion to music.* Nat Neurosci 14:257. https://www.zlab.mcgill.ca/publications/docs/salimpoor_2011_nn.pdf
- Clark et al. (2009). *Gambling near-misses enhance motivation to gamble and recruit win-related brain
  circuitry.* Neuron 61:481. https://pmc.ncbi.nlm.nih.gov/articles/PMC2658737/
- Hsu, Huang, Nordgren, Rucker & Galinsky (2015). *The music of power.* Soc Psychol Personal Sci 6:75.
  https://insight.kellogg.northwestern.edu/article/pump_up_the_jams_and_feel_powerful
- Hove et al. (2014). *Superior time perception for lower musical pitch explains why bass-ranged instruments
  lay down musical rhythms.* PNAS 111:10383.
- McDermott, Lehr & Oxenham (2010). *Individual differences reveal the basis of consonance.* Curr Biol 20:1035.
- Zhou et al. (2018). *Multisensory temporal binding window…: meta-analysis.* Neurosci Biobehav Rev 86:66
  (janela de integração audiovisual); Vroomen & Keetels (2010), revisão sobre sincronia intersensorial.
- ITU-R BT.1359 (detecção de dessincronia: som ~45 ms adiantado / ~125 ms atrasado).
  https://en.wikipedia.org/wiki/Audio-to-video_synchronization
- W3C WCAG 2.3.1 *Three Flashes or Below Threshold* (3/s; 341×256 px a 1024×768; flash vermelho).
  https://www.w3.org/WAI/WCAG21/Understanding/three-flashes-or-below-threshold ; WCAG 1.4.11 (contraste 3:1).
- ISO 226 (curvas de igual audibilidade: sensibilidade máxima em ~2–5 kHz).
- Itti & Koch (2001), *Computational modelling of visual attention*, Nat Rev Neurosci; Cerf et al. (2008),
  rostos e saliência no olhar.
- Csikszentmihalyi (1990), *Flow*. Sweller (1988), carga cognitiva.

**Indústria**
- Sakurai, coluna Famitsu sobre hitstop (tradução Source Gaming): https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/
- Fórmulas de hitlag do Smash (comunidade): https://www.ssbwiki.com/Hitlag
- PlayStation Blog: desenvolvedores sobre o combate de God of War (2018) (tremor reduzido, hitstop no 1º quadro,
  grave + agudo no machado; glints de Ghost of Tsushima): https://blog.playstation.com/?p=370399
- Sheth, M. *Evolving Combat in God of War for a New Perspective* (GDC 2019). https://gdcvault.com/play/1026423/Evolving-Combat-in-God-of
- Eiserloh, S. *Juicing Your Cameras With Math* (GDC 2016) (trauma², ruído Perlin). https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math ;
  implementação de referência: https://bevy.org/examples/camera/2d-screen-shake/
- Nijman, J. W. *The Art of Screenshake* (2013); Jonasson & Purho, *Juice it or lose it* (2012).
- Supergiant/Hades: opção de desligar tremor por acessibilidade. https://www.pcgamer.com/uk/a-journey-through-early-access-helped-make-hades-a-masterpiece/
- PopCap/Peggle: acertos de pino em escala ascendente afinada com a música.
  https://www.audiokinetic.com/blog/scoring-peggle-blast-new-dog-old-tricks ; https://www.audiogang.org/peggle2-sonic-joy/
- IESD/IASIG, níveis de mixagem: −24 LUFS ±2, true peak ≤ −1 dBTP. https://www.audiogang.org/wp-content/uploads/2015/04/IESD-Mix-Ref-Levels-v03.02.pdf
- Godot `AudioStreamRandomizer`: https://docs.godotengine.org/en/4.3/classes/class_audiostreamrandomizer.html

**Diretrizes de acessibilidade**
- Game Accessibility Guidelines (cor sozinha, sons distintos, volumes separados, legendas): https://gameaccessibilityguidelines.com/full-list/

**Limitações deste trabalho:** não toquei o jogo nem ouvi os .ogg (regra de silêncio). As recomendações de
áudio sobre espectro e loudness (R12, R13) são **alvos a medir offline** pelo diretor de Áudio, não diagnóstico.
Os números de hitstop, tremor e squash são **[I]/[H]** e devem ser ajustados no playtest. Os achados de Hicks 2019
não foram lidos no texto completo (só o enquadramento).
