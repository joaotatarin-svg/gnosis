# MANIFESTO — folhas de animação da Sophia (ChatGPT, 17/10/2026)

Chat de origem: https://chatgpt.com/c/6ad2fe7b-b2dc-83e9-8d58-209255b8f4af
Todas: 1536x1024, fundo magenta #FF00FF, Sophia olhando para a DIREITA.
Ordem dos quadros: esquerda→direita, linha de cima → linha de baixo.

## S1 — poses avulsas (gerada antes, aprovada pelo chefe)
- `s1_a.png`, `s1_b.png` — grade 2×3: dodge, hurt, down (caída), jump, block, run_contact.

## S2 — CORRIDA (aprovada)
- Arquivo: `s2_a.png` — grade 2×4 (8 quadros, 1 geração).
- Quadros: run_0 (contato D), run_1 (recuo), run_2 (passagem), run_3 (impulso), run_4 (contato E), run_5 (recuo), run_6 (passagem), run_7 (impulso).
- Nota de consistência: 7.5/10. Figurino, escala (alturas 369–414 px) e direita OK; todos os quadros distintos.
- Observações: o cajado fica sempre na mão de trás e o punho livre sempre à frente (braços não alternam — escolha de design aceitável).
  A alternância de pernas entre linha 1 e linha 2 é sutil (linha 2 parece "repetição variada" da 1). Espaço entre quadros apertado
  (~12–40 px entre o cristal de um quadro e a bota do anterior), mas não se tocam — recorte por componente conectado funciona.
  Alturas variam ~10% (bob vertical natural da corrida + variação da IA): alinhar pelos pés no recorte.

## S3 — PARADA/RESPIRAÇÃO + PRONTIDÃO (aprovada)
- Arquivo: `s3_a.png` — grade 2×3 (6 quadros, 1 geração).
- Quadros: idle_0 (neutro/expira), idle_1 (inspira), idle_2 (inspiração máxima), idle_3 (expira, volta ao 0), ready_0 (base baixa, cajado diagonal), ready_1 (respiração da prontidão).
- Nota de consistência: 7.5/10. Idle muito parecidos entre si (bom p/ loop sutil); escala idle h≈495 px, ready h≈410–420 px (base baixa).
- Observações: idle_1 (meio de cima) muda um pouco mais (mão do cajado/pernas) — pode "pular" no loop; se pular, usar idle_0→idle_2→idle_3.
  Cristal do cajado encosta quase no topo da imagem (y=4) na linha de cima, mas não está cortado.

## S4 — GOLPE LEVE, COMBO DE 3 (aprovada)
- Arquivo: `s4_a.png` — grade 2×3 (6 quadros, 1 geração).
- Quadros: light1_wind (prep. 1, cajado atrás), light1_hit (varredura horizontal), light2_wind (cajado alto sobre o ombro), light2_hit (varredura de volta diagonal p/ baixo), light3_wind (cajado na cintura, lança), light3_hit (estocada, cristal brilhando).
- Nota de consistência: 8/10. Poses claras e distintas, figurino fiel, base comum por linha.
- Observações: o cristal do light3_hit chega na borda direita (x≈1533) — pode estar rente/cortado 1–2 px; os quadros 5 e 6 da linha de baixo
  ficam próximos (caixas se sobrepõem em x, mas os pixels não se tocam). Comprimento do cajado varia um pouco entre quadros.

## S5 — GOLPE FORTE (aprovada)
- Arquivo: `s5_a.png` — grade 2×3 (6 quadros, 1 geração).
- Quadros: heavy_0 (agacha/gira o cajado p/ trás), heavy_1 (pico, cajado acima da cabeça), heavy_2 (descendo, cristal à frente), heavy_3 (impacto no chão), heavy_4 (segue-se), heavy_5 (recuperação, cajado diagonal).
- Nota de consistência: 7.5/10. Arco do golpe legível; figurino fiel.
- Observações: no heavy_1 a ponta do cristal encosta na borda superior (y=0), mas o cristal aparece inteiro. O brilho/explosão ciano no impacto
  NÃO veio (cristal normal) — fazer o flash por código/FX. heavy_3 e heavy_4 são bem parecidos (bom como "hold" do impacto).

## S6 — MAGIA (aprovada: variante B)
- Arquivo APROVADO: `s6_b.png` — grade 2×3 (6 quadros). Rejeitada: `s6_a.png` (cajado trocava de mão entre quadros: frente nos 1-3/6, atrás nos 4-5).
- Quadros (s6_b): cast_0 (base), cast_1 (mão recua, faíscas na palma), cast_2 (orbe cresce), cast_3 (empurra e solta a esfera), cast_4 (braço estendido, faíscas), cast_5 (retorno).
- Nota de consistência: 8/10. Cajado SEMPRE vertical na mão de trás; luz só na mão livre. Escala estável (h 470–495 px).
- Observações: cristal encosta perto do topo (y≈4) na linha de cima; as faíscas são pixels soltos — ao recortar por componente conectado,
  juntar componentes pequenos ao quadro mais próximo (ou descartar e fazer faíscas por FX). 2 gerações.
- Nota técnica: a partir da S6 as imagens foram salvas via "Copiar imagem" + área de transferência (o download pelo Chrome não gravava arquivo);
  o PNG sai RGBA 1536x1024 (alfa opaco), mesmo conteúdo.

## S7 — AÉREO (aprovada: variante B)
- Arquivo APROVADO: `s7_b.png` — grade 2×3 (6 quadros). Alternativa válida: `s7_a.png` (mesmo prompt, A/B do ChatGPT; nota 7).
- Quadros (s7_b): air_0 (lançador, cajado subindo), air_1 (salto subindo, cajado acima), air_2 (golpe aéreo horizontal), air_3 (golpe aéreo 2, de volta, cristal p/ trás), air_4 (mergulho, cajado p/ baixo), air_5 (aterrissagem agachada, cristal no chão).
- Nota de consistência: 8/10. Figurino fiel; poses aéreas legíveis.
- Observações: escala aparente varia (launcher h≈521 em pé; aterrissagem h≈297 agachada — normal). air_2 tem o cajado comprido até x≈1525 (rente à borda).
  Os quadros "no ar" estão desenhados em alturas diferentes dentro da célula — no jogo, ancorar pelo centro do corpo, não pelos pés.
  No s7_a o air_3 é menos claro (cajado diagonal p/ frente-baixo) e o launcher encosta no topo.

## S8 — ESQUIVA EM SEQUÊNCIA + DANO (aprovada)
- Arquivo: `s8_a.png` — grade 2×3 (6 quadros, 1 geração).
- Quadros: dodge_0 (impulso agachada), dodge_1 (no ar p/ trás, inclinada), dodge_2 (aterrissa deslizando, mão perto do chão), dodge_3 (recupera, cajado diagonal), hurt_0 (impacto, cabeça p/ trás), hurt_1 (recuo, curvada).
- Nota de consistência: 7.5/10. Todos olhando p/ direita; figurino fiel; escala coerente (h 344–439 conforme a pose).
- Observações: o cajado alterna entre "atrás" e "à frente" do corpo em alguns quadros (dodge_0/dodge_3 cruzado à frente; dodge_1/hurt_* atrás) —
  como são ações curtas, passa. dodge_1 está desenhada mais alta na célula (no ar) — ancorar pelo centro.

## S9 — MORTE E LEVANTAR (aprovada: variante A)
- Arquivo APROVADO: `s9_a.png` — grade 2×3 (6 quadros). Alternativa: `s9_b.png` (A/B do ChatGPT; nota 7 — cambaleio menos legível, cajado embaixo do corpo deitado).
- Quadros (s9_a): die_0 (cambaleia, cajado escorregando), die_1 (cai de joelhos), die_2 (tomba p/ trás), die_3 (deitada de costas, cajado ao lado), rise_0 (levantando de joelho apoiada no cajado), rise_1 (de pé, cajado vertical).
- Nota de consistência: 7.5/10. Sequência lê bem; figurino fiel.
- Observações: die_3 (deitada) fica no canto inferior-esquerdo da célula, com cabeça p/ ESQUERDA (cai p/ trás). Nota: o script de QA ordena
  esse quadro por último por causa da altura — a ordem visual correta é a do texto acima. die_2 parece "sentada caindo" (pernas p/ cima) —
  aceitável. rise_1 tem escala um pouco maior (h≈471) que die_0 (h≈417).

## S10 — PULO (aprovada)
- Arquivo: `s10_a.png` — grade 2×3 (6 quadros, 1 geração).
- Quadros: jump_0 (agacha), jump_1 (impulso, braço livre p/ cima), jump_2 (subindo, joelho alto), jump_3 (ápice, encolhida), jump_4 (caindo, pernas estendidas), jump_5 (aterrissagem agachada).
- Nota de consistência: 8/10. Cajado sempre na mão de trás com cristal p/ cima-trás (contínuo entre quadros); figurino fiel.
- Observações: quadros aéreos em alturas diferentes dentro da célula (jump_3 bem compacto, h≈309) — ancorar pelo centro do corpo no ar.
  O cabelo não inverte muito entre subida/queda (pedido no prompt), mas há variação.

## Resumo
- Aprovadas: S2 (s2_a), S3 (s3_a), S4 (s4_a), S5 (s5_a), S6 (s6_b), S7 (s7_b), S8 (s8_a), S9 (s9_a), S10 (s10_a).
- Extras guardadas (não aprovadas como principal): s6_a (erro de continuidade do cajado), s7_a, s9_b.
- Pedidos ao ChatGPT: 10 (S6 precisou de 1 correção); imagens recebidas: 12 (S7 e S9 vieram em A/B). Nenhum aviso de limite.
- Fundo: magenta com ~2–5 mil pixels "quase-magenta" (franja antisserrilhada nas bordas) — usar chave com tolerância/despill no recorte.

# CHEFES (um chat por chefe, ref anexada; grade 2×4)
Quadros por célula (padrão): 0 idle_0 · 1 idle_1 · 2 walk_0 · 3 walk_1 · 4 windup · 5 strike · 6 hurt · 7 death.
Downloads voltaram a funcionar no Chrome (Browser 2) com <a download>.

## Chefe 1 — Athoth (Torpor)
- REFEITO (ver abaixo: APROVADO `boss_1_athoth_c.png`). Versão antiga:
- Arquivo: `boss_1_athoth_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad306c4-77ac-83e9-8a1e-bd5c7f47dfa5
- Nota: 7/10. Fiel à ref (capuz, rosto pálido, halo com argolas, trapos navy). Vista 3/4 voltada p/ direita (não perfil puro).
- Observações: a névoa/orbes roxos do windup/strike se misturam com o magenta (franja rosada maior: ~9,8 mil px quase-magenta) —
  recorte precisa de cuidado ou refazer a névoa por FX. As esferas do strike (q5) chegam perto do q6 (caixas se sobrepõem, pixels não).
  death = desmoronando no chão (h≈306).

## Chefe 2 — Harmas (Fome)
- Arquivo: `boss_2_harmas_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32079-c4c4-83ea-9bdb-6090af4e51b5
- ATENÇÃO: veio com FUNDO TRANSPARENTE (RGBA, alfa real) em vez de magenta — melhor para o recorte.
- Nota: 7.5/10. Figurino idêntico à ref (elmo com chifres, bocarra no torso, placas e correntes). Vista ~3/4 virada p/ direita
  (o prompt pediu perfil verdadeiro; a bocarra do torso força um ângulo mais frontal). Windup (punhos ao alto, boca abrindo), strike
  (punhos no chão, boca aberta), hurt e death (de joelhos) legíveis. Sem efeitos.

## Chefe 3 — Galila (Corrente)
- Arquivo APROVADO: `boss_3_galila_b.png` — 2×4. Rejeitada: `boss_3_galila_a.png` (espada do strike invadia a célula do hurt).
  Chat: https://chatgpt.com/c/6ad32126-5f34-83e9-90b0-3c7567370899 (2 gerações)
- Nota: 8.5/10. PERFIL lateral de verdade, olhando p/ direita; figurino idêntico (elmo-coroa com chifres, correntes com gaiolas-lanterna,
  trapos, espadão). windup (agachado, espada atrás, corrente na mão), strike (estocada com espada), hurt, death (de joelhos apoiado na espada).
  8 quadros separados, sem efeitos. Fundo magenta.

## Chefe 4 — Yabel (Silêncio)
- Arquivo: `boss_4_yabel_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad3228b-6d58-83e9-8479-f9995814a72a
- Nota: 7.5/10. Fiel (máscara pálida, coroa + halo, asas escuras, pergaminhos e faixas). Perfil/3-4 leve p/ direita; o windup
  (asas abertas, braços erguidos) é frontal. strike = asas p/ frente + palmas, só 2–3 linhas finas de onda (efeito mínimo, ok).
- Observações: as asas do windup e do strike chegam muito perto uma da outra (separadas por ~12 px); a ponta da asa do windup encosta
  na borda esquerda (x≈8).

## Chefe 5 — Astaphaios (Espelho)
- Arquivo: `boss_5_astaphaios_a.png` — 2×4, 1 geração (a 1ª mensagem saiu sem anexo; reenviei a ref no mesmo chat).
  Chat: https://chatgpt.com/c/6ad3230b-ff1c-83e9-a0c2-672e9b3ca59e
- Nota: 8/10. PERFIL verdadeiro p/ direita; armadura prateada, halo, cajado-espelho e cristais fiéis. windup (cajado recuado na horizontal),
  strike (estocada com o espelho à frente), hurt, death (de joelhos, espelho no chão).
- Observações: os VÉUS são translúcidos e misturam com o magenta (~29 mil px "quase-magenta") — recorte com chroma simples vai deixar
  véu rosado; usar despill/recolorir véu ou aceitar véu mais opaco. Cristais flutuantes = pixels soltos ao redor (poucos).

## Chefe 6 — Belias (Praga)
- Arquivo: `boss_6_belias_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32401-26c8-83e9-8f37-2a7ca039529f
- Nota: 8/10. Quadrúpede em PERFIL, virado p/ DIREITA (a ref olhava p/ esquerda — invertido corretamente); cogumelos, espinhos,
  chifres e cauda fiéis. walk_0/walk_1 com passada de fera; windup (agachado, boca abrindo), strike (bote com mandíbula aberta),
  hurt (empinando), death (deitado de lado).
- Observações: walk_1 e death encostam na borda DIREITA da imagem (x≈1535) e idle_0 na esquerda (x≈4) — pode ter 1–3 px do focinho/cauda
  cortados. Cogumelos com hastes finas = detalhe fino no recorte.

## Chefe 7 — Armupiel (Coroa)
- Arquivo: `boss_7_armupiel_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32493-254c-83ea-8ac9-af7fe095a44b
- Nota: 8/10. PERFIL p/ direita; armadura dourada, elmo-coroa espinhoso, capa azul com estrelas, correntes e espadão fiéis.
  windup (espadão acima da cabeça), strike (golpe descendente, lâmina no chão à frente), hurt, death (de joelhos apoiado na espada).
  Sem efeitos, fundo magenta limpo (139 px quase-magenta), 8 quadros separados.

## Chefe 8 — Colosso Oco
- Arquivo APROVADO: `boss_8_colosso_b.png` — 2×4. Rejeitada: `boss_8_colosso_a.png` (punhos do windup encostavam nos pés do quadro de cima; windup frontal).
  Chat: https://chatgpt.com/c/6ad32512-c6ac-83e9-8cae-b2d6e29bff0f (2 gerações)
- Nota: 8/10. Perfil p/ direita (leve 3/4 p/ mostrar o núcleo oco brilhando); pedra + placas douradas, tecido azul-cinza fiéis.
  windup (punho erguido atrás do ombro, perfil), strike (punhos no chão, poucas pedrinhas), hurt (lascas), death (desmoronando de joelhos).
  Fundo magenta limpo; 8 quadros separados (pedrinhas soltas = pixels pequenos ao redor).

## Chefe 9 — Rei / Yaldabaoth
- Arquivo: `boss_9_rei_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32602-4348-83e8-a85a-0befbca24e16
- ATENÇÃO: o fundo veio ROSA-MAGENTA (≈ RGB 248,3,185, igual ao da ref), NÃO #FF00FF — chapado e uniforme; chavear por essa cor.
- Nota: 8/10. Perfil p/ direita; manto marfim com faixa dourada, máscara branca com fendas, capuz-coroa fiéis. windup (braço erguido
  com o orbe-olho dourado), strike (gesto régio à frente com o orbe), hurt (mangas p/ cima), death (afundando de joelhos, manto no chão).
  8 quadros separados; mantos encostam nas bordas laterais (x≈4 e x≈1534).

## Chefe 1 — Athoth REFEITO (perfil verdadeiro, névoa mínima)
- Arquivo APROVADO: `boss_1_athoth_c.png` — 2×4. Intermediária: `boss_1_athoth_b.png` (névoa mínima ok, mas rosto ainda 3/4; nota 7.5).
  Chat: https://chatgpt.com/c/6ad32699-2dc0-83e9-a69b-44ce03def36a (2 gerações)
- Nota: 8/10. PERFIL estrito p/ direita (capuz e rosto apontando p/ direita, halo de lado), trapos navy (sem roxo), só 2–3 orbes
  pequenos no windup/strike. Fundo magenta limpo (270 px quase-magenta, vs 9,8 mil na versão a).
- Observações: os trapos da linha de cima descem até y≈526 (passam um pouco da metade da imagem, 512) — separar linhas pelos
  componentes, não por corte fixo em y=512.

# CRIATURAS (um chat por tipo; ref = recorte da criaturas_folha.png; grade 2×4)
Quadros por célula (padrão): 0 idle_0 · 1 walk_0 · 2 walk_1 · 3 walk_2 · 4 windup · 5 strike · 6 hurt · 7 death.
Numeração = posição na criaturas_folha.png (3×3, esq→dir, cima→baixo). Recortes enviados: scratchpad\refs\cri_<n>.png.

## Criatura 1 — Larva espectral (grub com mortalha verde)
- Arquivo: `cri_1_larva_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad327b1-911c-83e9-af53-7b82906538bb
- Nota: 8/10. Perfil p/ direita, olho âmbar, mortalha verde fiel; walk = ondulação flutuando; windup enrolada, strike bote esticado,
  hurt, death (murcha no chão). Fundo limpo; idle_0 encosta na borda esquerda (x≈4).

## Criatura 2 — Espadachim oco (soldado de ferro, olho laranja)
- Arquivo: `cri_2_espadachim_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32831-7748-83e8-acf5-b3988606ab48
- Nota: 8/10. Perfil p/ direita, armadura, capa rasgada e espada fiéis; walk de 3 quadros legível; windup espada sobre o ombro,
  strike corte diagonal baixo, hurt, death (caído de joelhos, espada solta no chão — componente separado).

## Criatura 3 — Bruto de ferro (armadura vermelha enferrujada)
- Arquivo APROVADO: `cri_3_bruto_b.png` — 2×4. Rejeitada: `cri_3_bruto_a.png` (windup e strike se tocavam; soco invadia a célula seguinte).
  Chat: https://chatgpt.com/c/6ad328b1-9c00-83e8-bbb0-5dc9e7f9f848 (2 gerações)
- Nota: 8/10. Perfil p/ direita, fiel à ref; walk de 3 quadros; windup punho atrás, strike soco estendido, hurt, death (de joelhos/caído).
  Figuras um pouco menores (h≈385) — todas dentro das células.

## Criatura 4 — Cão-esqueleto (pelo negro, costelas expostas, crânio com chifres)
- Arquivo: `cri_4_cao_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad329a1-d56c-83e9-bd0b-449eb52a9e02
- Nota: 8/10. Quadrúpede em perfil p/ direita, fiel; walk de 3 quadros; windup agachado, strike bote com mandíbula, hurt empinando,
  death caído de lado (ossinhos soltos = pixels pequenos). Quadros dentro das células.

## Criatura 5 — Escudeiro (escudo de bronze com sol + lança)
- Arquivo: `cri_5_escudeiro_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32a23-b868-83e9-800c-a3b0f08b48ba
- Nota: 7.5/10. Perfil p/ direita, fiel; o escudo fica no braço do lado do espectador (cobre o corpo p/ a câmera, não à frente
  do inimigo) — igual à ref. windup lança acima do ombro, strike estocada, hurt, death (escudo caído no chão, lança solta).

## Criatura 6 — Conjurador de crânio (manto verde-petróleo, máscara de crânio, cajado de anel)
- Arquivo: `cri_6_conjurador_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32aa4-0640-83ea-ab1a-f6cff168f18d
- Nota: 8/10. Perfil p/ direita, fiel; walk 3 quadros; windup cajado acima da cabeça, strike cajado à frente com 1 orbe pequeno
  (componente solto), hurt, death (de joelhos, cajado no chão). Brilho mínimo.

# NPCs (não lutam; template próprio 2×4)

## NPC — Soter (ancião de branco, messiânico) — ref cri_7
- Arquivo APROVADO: `npc_soter_a.png` — 2×4. Alternativa: `npc_soter_b.png` (A/B do ChatGPT; nota 7 — bênção sem luz, fade menos claro).
  Chat: https://chatgpt.com/c/6ad32b24-2868-83e9-9b38-7002673cf088 (1 pedido, 2 imagens)
- Quadros: 0 idle_0 · 1 idle_1 · 2 talk_0 · 3 talk_1 · 4 bless_0 · 5 bless_1 · 6 turn_away · 7 fade.
- Nota: 8/10. Perfil p/ direita, fiel (cabelo/barba brancos, manto creme com sol dourado). FUNDO TRANSPARENTE (RGBA real) — as duas
  variantes vieram assim; o fade é translúcido de verdade (alfa), e o brilho dourado da bênção é pequeno.

## NPC — Velkar (Arconte arrependido, cavaleiro de capa lilás) — ref cri_8
- Arquivo: `npc_velkar_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32bb6-e384-83e9-ae15-84c8352d4a53
- Quadros: 0 idle_0 · 1 idle_1 · 2 talk_0 · 3 talk_1 · 4 kneel · 5 rise · 6 gesture_farewell · 7 walk_away.
- Nota: 8/10. Perfil p/ direita, fiel (armadura escura, elmo com chifrinhos, capa lilás rasgada, correntes). Postura curvada e pesarosa.
  A capa lilás é próxima do magenta mas separou bem (426 px quase-magenta). gesture_farewell sobe até y≈508 (perto da linha de cima, sem tocar).

## NPC — Adormecido (alma presa, camponês) — ref cri_9
- Arquivo: `npc_adormecido_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32c36-43d4-83e9-bcf5-2c5b9cd1ae8d
- Quadros (9 estados pedidos não cabem em 8; ficou sem idle_1): 0 asleep_0 · 1 asleep_1 · 2 waking · 3 awake · 4 grateful · 5 idle_0 · 6 talk_0 · 7 talk_1.
- Nota: 7.5/10. Perfil p/ direita, fiel (turbante cinza-azul, túnica rasgada, sandálias). Sequência acordar → de pé → reverência legível.
- Observações: awake (q3) encosta no topo da imagem (y≈3); as figuras da linha de baixo estão um pouco maiores (h≈500) que o awake
  (h≈459) — normalizar escala no recorte. Fundo magenta limpo.

## Resumo da rodada noturna (chefes + criaturas + NPCs)
- Chefes aprovados: boss_1_athoth_c, boss_2_harmas_a (fundo transparente), boss_3_galila_b, boss_4_yabel_a, boss_5_astaphaios_a,
  boss_6_belias_a, boss_7_armupiel_a, boss_8_colosso_b, boss_9_rei_a (fundo rosa 248,3,185).
- Criaturas aprovadas: cri_1_larva_a, cri_2_espadachim_a, cri_3_bruto_b, cri_4_cao_a, cri_5_escudeiro_a, cri_6_conjurador_a.
- NPCs aprovados: npc_soter_a (fundo transparente), npc_velkar_a, npc_adormecido_a.
- Rejeitadas/alternativas mantidas no disco: boss_1_athoth_a/b, boss_3_galila_a, boss_8_colosso_a, cri_3_bruto_a, npc_soter_b.
- Pedidos de geração nesta rodada: 22 (5 foram correções) + 1 resposta sem imagem (anexo não chegou). Nenhum aviso de limite.

# EXTRAS

## Retratos da Sophia (diálogo)
- Arquivo: `portrait_sophia_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32d03-5f20-83e8-9370-a4c17676c38c
- Células: 0 neutral · 1 determined · 2 sad · 3 anger (contida) · 4 fear · 5 tender · 6 shock ("...Não.") · 7 serene.
- Nota: 8.5/10. Busto 3/4 virado p/ direita, enquadramento idêntico nas 8 células (mesma posição da cabeça, h≈440), rosto/trança/
  colete fiéis; expressões distintas e legíveis (choque com boca entreaberta, serena de olhos fechados). Base do busto cortada reta.

## Retratos de NPCs (Rei/Voz, Soter, Velkar)
- Arquivo APROVADO: `portrait_npcs_a.png` — 2×4. Alternativa: `portrait_npcs_b.png` (A/B do ChatGPT).
  Chat: https://chatgpt.com/c/6ad32dc7-6964-83e9-9759-8c36bf891f24 (1 pedido, 2 imagens)
- Células: 0 rei_regal · 1 rei_ironic (mão na máscara) · 2 rei_revealed (máscara rachada, olho dourado) · 3 rei_broken ·
  4 soter_serene · 5 soter_sad · 6 velkar_helm · 7 velkar_repentant (cabeça baixa, mão no peito).
- Nota: 7.5/10. Fiel às refs (Rei com capuz-máscara branco SEM coroa dourada, como na ref). Defeitos: os bustos vêm recortados em
  "cartões" de cantos arredondados que ocupam a célula inteira (encostam nas bordas da célula); o Rei está mais FRONTAL que 3/4.
- A alternativa b tem silhuetas limpas e 3/4 p/ esquerda melhor, mas pôs uma COROA dourada no Rei (não existe na ref); nota 7.
  Se o jogo preferir silhueta recortada, usar b. Ambas viradas p/ ESQUERDA (falam com a Sophia).

## Key art Steam (sem texto)
- Chat: https://chatgpt.com/c/6ad32ebc-f810-83e9-826e-765ea8ed5729 (refs: 1_sophia_folha, 9_rei_yaldabaoth, assets/painted/eons.png). 2 gerações.
- `keyart_wide_a.png` — 1536x1024. Nota 8.5/10. Sophia no primeiro plano (perfil/3-4, cristal ciano aceso) numa ponte quebrada, Rei
  colossal mascarado segurando o orbe-olho dourado, 7 anéis luminosos no céu, ruínas góticas de Kenoma, luz fria + faíscas douradas.
  Céu escuro VAZIO no terço superior-esquerdo para o título. Sem texto.
- `keyart_vertical_a.png` — 1024x1536 (2:3). Nota 8/10. Mesma cena recomposta; faixa de céu escuro no TOPO para o título (um pouco
  estreita — o título talvez precise sobrepor nuvens). Sem texto.
- Observações: resolução nativa do ChatGPT; para a cápsula Steam (ex.: 3840x1240 / 600x900) precisa de upscale/recorte.

## S11 — Corrida com cruzamento de pernas (pedido do animador)
- Arquivo: `s11_run_cross_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32fd5-1254-83e9-993b-a2f7e95cfa44 (refs: 1_sophia_folha + s2_a)
- Células: 0 contact_R · 1 pass · 2 contact_L · 3 pass · 4 contact_R · 5 pass · 6 contact_L · 7 pass (2 ciclos).
- Nota: 8/10. Mesma escala/estilo da s2_a (h≈410–420). Pernas bem desenhadas (bota de perto x de longe distinguíveis, joelhos claros);
  as passagens mostram o cruzamento. Cajado na mão de trás. O cristal de cada quadro fica perto da bota do quadro anterior (não se tocam).

## S12 — Transição de morte
- Arquivo APROVADO: `s12_die_trans_b.png` — 2×3. Rejeitada: `s12_die_trans_a.png` (no q5 ela caía p/ trás com a cabeça à ESQUERDA, quebrando a continuidade).
  Mesmo chat da S11 (2 gerações).
- Células: 0 struck (atingida em pé) · 1 stagger · 2 one_knee · 3 hand_ground · 4 topple (cabeça p/ direita) · 5 down (deitada).
- Nota: 8/10. Sequência contínua 0→5, cajado escorregando e caindo ao lado; mesma escala.
  struck encosta na metade da imagem (y≈524).

## Resumo Fila 2
- Aprovadas: portrait_sophia_a, portrait_npcs_a (alt. b), keyart_wide_a, keyart_vertical_a, s11_run_cross_a, s12_die_trans_b.
- Gerações: 7 pedidos (8 imagens; 1 correção na S12). Nenhum aviso de limite.

# CINEMÁTICAS (cards 1536x1024, sem texto, terço inferior calmo p/ legenda)
Prólogo — chat: https://chatgpt.com/c/6ad3319f-2d74-83e9-84ca-57c9bfd7b136 (refs: 1_sophia_folha + painted/eons.png)
- `cine_01_monada_a.png` — Mônada: fonte de luz branco-dourada infinita, halos concêntricos, sem figura. Terço inferior escuro. Nota 8.5.
- `cine_02_eons_a.png` — Éons em pares: sizígias de luz de mãos dadas em arco ao redor da fonte, catedral de luz (Pleroma). Nota 8.5.
- `cine_03_sophia_nuvem_a.png` — Sophia sozinha se inclina na borda da luz; da mão dela, uma nuvem de luz com um trono vago (sem o Demiurgo nítido); Éons ao fundo. Sophia reconhecível (cabelo prateado, marfim/ouro, sem cajado). Nota 8.
- `cine_04_cego_a.png` — O Cego nasce: leão com corpo de serpente enrolado num trono escuro, coroa, chamas/brasas, solidão. A cegueira (olhos leitosos) quase não se lê em tamanho pequeno. Nota 8.
- `cine_05_kenoma_a.png` — Kenoma: mundo-prisão de sete anéis/esferas concêntricos acorrentados, carcereiros sombrios nas bordas, luz branca distante no canto. Nota 8.
- `cine_06_faisca_a.png` — A faísca acorda: Sophia deitada nas cinzas entre estátuas/mãos de barro com faíscas presas; uma faísca ciano no peito, cajado com cristal ao lado. Sophia pequena no quadro (legível em 640×360, mas pouco detalhe). Nota 8.
Cenas — chat: https://chatgpt.com/c/6ad3341a-5d64-83e9-9381-c9f54cf7857d (refs: 1_sophia_folha + 9_rei_yaldabaoth + eons)
- `cine_07_roubo_a.png` — O roubo: no salão dourado, os 7 anéis voam da Sophia (caída, braço estendido, cristal ciano) para a mão do Rei; a máscara branca cai revelando escuridão. Nota 9. (Sophia ocupa o meio-baixo; terço inferior é chão escuro, ok p/ legenda.)
- `cine_08_descida_a.png` — Descida ao Centro: Sophia caindo de cabeça num abismo de cacos de luz, engrenagens lá embaixo, cajado com cristal. Nota 8.5. Terço inferior tem pedras escuras com algum detalhe (menos "calmo" que os outros, mas escuro).
- `cine_09_anagnorise_a.png` — Anagnórise: Sophia ajoelhada abraça o Cego encolhido como criança, máscara quebrada ao lado, cajado com cristal no chão, luz suave de cima. Nota 9.
Finais — chat: https://chatgpt.com/c/6ad33557-42c8-83e8-ab1d-2167215ba4aa (refs: 1_sophia_folha + cri_9 Adormecido + eons)
- `cine_10_ascensao_a.png` — Ascensão: os Adormecidos sobem em colunas de luz dourada; Sophia por último, de costas/3-4, cajado erguido com cristal aceso. Nota 8.5. As pernas da Sophia chegam ao terço inferior (escuro).
- `cine_11_ruptura_a.png` — Ruptura: mundo rachado por uma fenda de luz, Sophia de guarda na borda com o cajado fincado e o cristal aceso, cúpula ciano protegendo Adormecidos encolhidos. Nota 8.5.
- `cine_12_semente_a.png` — Semente: Sophia ajoelhada planta uma semente de luz ciano; broto luminoso; cajado com cristal ao lado; Adormecidos começando a se mexer ao fundo. Nota 8.5.
- Resumo cinemáticas: 12/12 aprovadas na 1ª geração (12 pedidos). Todas sem texto/marca d'água. Sophia reconhecível em 3, 6–12.

## S13 — Corrida: poses intermediárias (in-betweens)
- Arquivo APROVADO: `s13_run_between_b.png` — 2×4. Alternativa: `s13_run_between_a.png` (A/B do ChatGPT, muito parecida; h≈403–408).
  Chat: https://chatgpt.com/c/6ad32fd5-1254-83e9-993b-a2f7e95cfa44 (mesmo da S11/S12; 1 pedido, 2 imagens)
- Células: 0 R_pushoff (pé de trás saindo) · 1 R_knee_high · 2 R_reach (antes do contato) · 3 R_down (recebe o peso) ·
  4 L_pushoff · 5 L_knee_high · 6 L_reach · 7 L_down.
- Nota: 7.5/10. Mesma escala da s11 (h≈401–421) e mesmo estilo; pernas legíveis. Como em perfil as pernas D/E são quase simétricas,
  a linha de baixo é parecida com a de cima (diferença está em qual perna fica à frente/sombreada). Encaixar entre os quadros da s11:
  contact_R → R_down → R_pushoff(L)… — conferir no motor qual perna é qual.

# FILA 4

## S14 — Aparo e contra-ataque
- Arquivo: `s14_parry_a.png` — 2×4, 1 geração. Chat: https://chatgpt.com/c/6ad32fd5-1254-83e9-993b-a2f7e95cfa44 (chat da Sophia S11–S14)
- Células: 0 guard · 1 parry_hit (faísca pequena) · 2 deflect (cajado girando p/ cima, arco fino) · 3 opening · 4 counter_1 (estocada) ·
  5 counter_2 (giro, arco fino) · 6 follow_through · 7 back_to_guard.
- Nota: 8/10. Mesmo estilo; escala ~igual à s11 (figuras h≈330–430 conforme a base). Cajado horizontal na guarda.
- Observações: a ponta do cajado encosta nas bordas da imagem em counter_1 (x=0) e back_to_guard (x=1536) — pode faltar 1–3 px da ponta.
  Arcos de movimento finos em deflect e counter_2 (componentes soltos; dá p/ apagar ou manter).

## Estelas (3 folhas 3×2, estilo gravura/afresco em pedra iluminada, sem texto)
Chat: https://chatgpt.com/c/6ad33822-6c1c-83e9-9539-4ac389a72382 (refs: painted/eons.png + 1_sophia_folha). Ordem = STELAS em gnosis.gd.
- `stelae_1_a.png` — células: monada · pleroma · sophia · cego · kenoma · arcontes. Nota 8.5. Painéis de pedra com moldura dourada, margens escuras entre eles, sem inscrições.
- `stelae_2_a.png` — células: heimarmene · barro · gnose · nag_hammadi · apocrifo · pistis. Nota 8.5.
- `stelae_3_a.png` — células: mestres (Valentino e Basílides) · tome · perola · chamado · docetismo · retorno. Nota 8.5.
  Alternativa `stelae_3_b.png` (A/B; nota 8 — docetismo com figura de luz nua/translúcida, menos sóbria). Sem texto em nenhuma das folhas
  (o rolo do q1 tem só traços, sem letras legíveis).

## Fundo do menu
- Arquivo: `menu_bg_a.png` — 1536x1024, 1 geração. Chat: https://chatgpt.com/c/6ad339bd-3e54-83ea-860d-8fed19858d48
- Nota: 8.5/10. Sophia de costas à DIREITA numa ponte/balcão em ruínas góticas, cajado com cristal ciano, olhando cidade gótica e céu
  com anéis dourados; metade ESQUERDA escura e calma (luminância média 33 vs 69 na direita) p/ os botões. Sem texto.
- Observação: os anéis saíram CONCÊNTRICOS em volta da lua (não 7 anéis separados em arco); dá para contar ~5–7. Se precisar
  dos 7 bem separados, pedir correção no mesmo chat.

## Resumo Fila 4
- Aprovadas: s14_parry_a, stelae_1_a, stelae_2_a, stelae_3_a (alt. b), menu_bg_a. 6 pedidos (7 imagens). Nenhum aviso de limite.

# FILA 5

## Cego pequeno (anagnórise, tela 68)
- Arquivo: `cego_pequeno_a.png` — 2×3 (células 512×512), 1 geração. Chat das cenas: https://chatgpt.com/c/6ad3341a-5d64-83e9-9381-c9f54cf7857d (design do cine_09)
- Células: 0 curled (abraça os joelhos, máscara caída ao lado — só aqui) · 1 tremble (encolhe mais) · 2 look_up (rosto cego p/ cima) ·
  3 reach (mão estendida p/ direita) · 4 lifted (braços p/ cima, como criança) · 5 nestled (encostado de lado, olhos fechados).
- Nota: 8/10. Figura frágil, cabelo grisalho, olhos leitosos/vendados, restos do manto marfim/ouro rasgado grandes demais; perfil p/ direita.
  Fundo magenta limpo (885 px quase-magenta).
- Observações: a linha de baixo está um pouco maior (h≈410–450) que a de cima (h≈330–390, poses agachadas) — conferir escala no recorte;
  o manto do q3 encosta na borda esquerda (x=0); os braços erguidos do q4 sobem até y≈498 (perto da linha de cima, sem tocar).

# FILA 6 — Bots de Éon (servos dos Arcontes; 2×4: idle_0 · walk_0 · walk_1 · walk_2 · windup · strike · hurt · death)

## Bot 1 — Sonâmbulo (servo de Athoth)
- Arquivo: `bot_1_sonambulo_a.png` — 1 geração. Chat: https://chatgpt.com/c/6ad37d01-a368-83e9-9723-f3937a9c2469 (ref: 1_athoth_torpor)
- Nota: 8/10. Encapuzado navy com argolas douradas e halo pequeno (claramente da família de Athoth), olhos fechados, braços à frente,
  pés descalços; windup/strike com orbe violeta pequeno (componente solto no strike). Perfil p/ direita. death = desmoronado no chão.

## Bot 2 — Glutão (servo de Harmas)
- Arquivo: `bot_2_glutao_a.png` — 1 geração. Chat: https://chatgpt.com/c/6ad37d8e-2090-83e9-8e3d-db4dc1408e45 (ref: 2_harmas_fome)
- Nota: 7.5/10. Perfil p/ direita, baixo e inchado, pele vermelha, placas enferrujadas, elmo com chifres, boca dentada no ventre.
  Ressalva: ainda lembra MUITO o Harmas (versão atarracada) — a silhueta mais baixa/redonda ajuda a distinguir, mas a paleta/elmo são iguais.
  windup (boca da barriga escancarada), strike (bote de barriga), hurt, death (de costas).

## Bot 3 — Carcereiro (servo de Galila)
- Arquivo: `bot_3_carcereiro_a.png` — 1 geração. Chat: https://chatgpt.com/c/6ad37e1b-3ce0-83e9-845f-6f1c2f63aa4d (ref: 3_galila_corrente)
- Nota: 8/10. Perfil p/ direita, magro e curvado, ferro escuro + trapos marfim (família Galila), chaves douradas na cintura, corrente com gancho.
  windup (corrente girando acima da cabeça), strike (corrente arremessada reta), hurt, death.
- Observações: a corrente do strike passa da célula (até x≈935, entra na coluna do hurt) mas não toca o vizinho — recortar por componente,
  não por grade; o arco da corrente do windup sobe até y≈508.

## Bot 4 — Bibliotecário Mudo (servo de Yabel)
- Arquivo: `bot_4_mudo_a.png` — 1 geração. Chat: https://chatgpt.com/c/6ad37eb7-70cc-83e9-b59f-7be3113a3b08 (ref: 4_yabel_silencio)
- Nota: 8/10. Perfil p/ direita, escriba curvado de máscara pálida (boca costurada), diadema dourado, manto navy com correntes,
  faixas de pergaminho, pena na mão, rolos flutuando. windup (anel fino de silêncio), strike (onda fina + rolo voando), hurt, death.
- Observações: os rolos flutuantes e a onda são componentes SOLTOS (o QA contou 11 peças) — agrupar com o corpo mais próximo no recorte.

## Bot 5 — Reflexo (servo de Astaphaios)
- Arquivo: `bot_5_reflexo_a.png` — 1 geração. Chat: https://chatgpt.com/c/6ad37f44-d9f0-83e9-8370-0cd4f655a7b1 (ref: 5_astaphaios_espelho)
- Nota: 8/10. Humanoide esguio de vidro espelhado prateado com rachaduras douradas, rosto liso, lâmina curva de vidro; perfil p/ direita.
  windup agachado, strike estocada/corte, hurt = salto p/ trás, death = estilhaçando em cacos (muitos componentes soltos).
- Observação: o espelho reflete um pouco do magenta (tons rosados no corpo) — conferir o despill no recorte.

## Bot 6 — Portador de Esporos (servo de Belias)
- Arquivo: `bot_6_esporos_a.png` — 1 geração. Chat: https://chatgpt.com/c/6ad37fcf-5e20-83e8-97f1-a4b9028063d5 (ref: 6_belias_praga)
- Nota: 8/10. Corcunda bípede de pele verde-acinzentada, espinhos e cogumelos na corcunda (família Belias), garras; perfil p/ direita.
  windup (corcunda inchando), strike (nuvem de esporos esverdeada PEQUENA + garra), hurt, death (de bruços numa poça verde).
- Observação: a nuvem do strike chega a ~8 px do quadro do hurt (x 864 vs 872) — não toca, mas é justo.

## Bot 7 — Pretoriano da Coroa (servo de Armupiel)
- Arquivo: `bot_7_pretoriano_a.png` — 1 geração. Chat: https://chatgpt.com/c/6ad3805b-dcc8-83e8-a61a-38b34fe02115 (ref: 7_armupiel_coroa)
- Nota: 8/10. Guarda compacto de armadura dourada gravada e tabardo navy com estrelas, elmo com 3 pontas, BROQUEL grande à frente
  (lado direito), lança curta; perfil p/ direita. windup lança acima do ombro, strike estocada por cima do escudo, hurt, death sobre o escudo.
  Fundo limpo (51 px quase-magenta).

## Bot 2 — Glutão REFEITO
- Arquivo APROVADO: `bot_2_glutao_b.png` — 2×4. Mesmo chat do Glutão (https://chatgpt.com/c/6ad37d8e-2090-83e9-8e3d-db4dc1408e45).
  1ª tentativa de refação foi BLOQUEADA pelo ChatGPT ("pode violar diretrizes sobre violência" — o prompt falava em pele translúcida com veias,
  piercings e mordida); reformulei como criatura estilizada sem gore e passou. 2 pedidos, 1 imagem.
- Nota: 8/10. Silhueta NOVA: criatura-saco baixa, curvada/de quatro, sem armadura nem elmo, pele rosa-avermelhada inchada, braços finos e
  longos, cabeça careca pequena, bocarra dentada no ventre (assinatura), argolas e corrente de ouro sujo (paleta do Harmas). Mais baixa que
  humano (h≈265–275 andando). windup (empina, boca escancarada), strike (bote baixo), hurt, death (murcho de lado).
- `bot_2_glutao_a.png` fica como versão antiga (muito parecida com o Harmas).

## Resumo Fila 6
- Aprovadas: bot_1_sonambulo_a, bot_2_glutao_b, bot_3_carcereiro_a, bot_4_mudo_a, bot_5_reflexo_a, bot_6_esporos_a, bot_7_pretoriano_a.
- 9 pedidos (8 imagens; 1 recusa por diretriz de violência). Nenhum aviso de limite.
