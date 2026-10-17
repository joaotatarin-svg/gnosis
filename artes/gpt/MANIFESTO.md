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
