# Chefes articulados — 17/09/2026

Atualização somente em Gnosis-Codex. João cancelou a alteração dos nomes e
confirmou que o lançador funciona. Nenhum dos dois foi alterado.

## Ver e jogar

Abra o Ateliê, escolha um Arconte e avance a pose até **Ciclo de combate**.
O ciclo alterna caminhada, preparação, golpe forte e recuperação.
**Ver articulações** mostra os ossos; **Pausar / animar** permite examinar a
pose congelada. **Testar em combate** abre o desafio com o chefe escolhido.

## Movimento

- Harmas, Galila, Astaphaios, Armupiel e Colosso usam partes rígidas presas aos
  ossos. Ombros, cotovelos, punhos, quadris, joelhos e cabeça giram separados.
- Athoth, Yabel e Yaldabaoth usam pele com pesos, movimento de tecido e corpo.
  As asas de Yabel têm ossos independentes; o orbe do Rei continua separado.
- Belias tem quatro patas, joelhos, mandíbula e cauda, com ciclo de passada.
- Preparação, ataque, recuperação e reação ao dano usam os estados do Enemy.
  O progresso vem do temporizador real; a passada acompanha a velocidade e
  acelera na segunda fase. Dano, alcance e duração das janelas não mudaram.
- Transições suavizam a troca de pose. Espadas são peças rígidas; não recebem
  a deformação de tecido. Os inimigos que usam a mesma família visual também
  herdam as articulações na sua escala.

## Implementação

`scripts/fx/boss_puppet.gd` contém pivôs por pintura, ossos e recortes UV.
Armaduras usam Polygon2D subordinado a Bone2D; tecidos e fera usam uma malha de
48 × 64 células com até quatro influências normalizadas por vértice.
As imagens originais não foram regravadas. São recortes feitos pelo renderizador.
`PaintedLibrary` seleciona o boneco; `CharacterArt` controla tempo, escala,
cor e pausa; `Enemy._sync_anim` fornece o estado e o progresso reais.

Referência de API: [Bone2D](https://docs.godotengine.org/en/stable/classes/class_bone2d.html)
e [Polygon2D](https://docs.godotengine.org/en/stable/classes/class_polygon2d.html).

## Validação

- Editor headless: sem SCRIPT ERROR.
- PuppetQA: nove chefes × três poses; pesos normalizados, vínculos de peças
  válidos, articulações móveis; zero falhas. Pranchas inspecionadas em shots/.
- CodexQA: dez modos do ateliê, troca de perfil, pausa, encontros, morte,
  reinício e checkpoint preservado; zero falhas.
- CodexPlaytest: três encontros vencidos usando inputs reais, 27,8 s,
  combo 13, dano recebido e fase 2 observados.
- Capturas do ateliê, articulações e combate inspecionadas no renderer real.

É animação de bonecos 2D. Partes anteriormente ocultas pelas armas são
reconstruídas com forro; recortes, junções e sobreposições ainda podem melhorar
com pinturas específicas de cada peça. O teste automatizado verifica o fluxo;
a sensação dos golpes ainda depende do playtest humano.
