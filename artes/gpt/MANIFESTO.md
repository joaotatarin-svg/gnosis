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
