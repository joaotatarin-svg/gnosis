FUNDOS EM PNG (opcional) — a arte final dos cenários dos Éons.

Coloque aqui uma imagem por Éon, com estes nomes EXATOS:

  eon_0.png   Torpor
  eon_1.png   Fome
  eon_2.png   Corrente
  eon_3.png   Silencio
  eon_4.png   Espelho
  eon_5.png   Praga
  eon_6.png   Coroa

Como funciona:
- Se o arquivo existir, o jogo usa o SEU PNG como fundo daquele Éon e ignora o
  cenario procedural (e o tint) — a imagem manda.
- Se nao existir, cai no fundo procedural (silhuetas geradas por codigo).
- Nao precisa mexer em codigo: e so soltar o PNG aqui e rodar.

Resolucao recomendada:
- A tela base do jogo e 640x360 (16:9). O PNG e esticado pra cobrir a tela.
- Faca em alta resolucao mantendo 16:9 (ex.: 1920x1080 ou 2560x1440). O Godot
  reduz com qualidade. Pode ser maior; evite proporcao diferente de 16:9 pra nao
  distorcer.
- PNG (com ou sem transparencia). Se quiser paralaxe/profundidade real depois, me
  peca que eu separo em camadas (ceu / fundo / frente).
