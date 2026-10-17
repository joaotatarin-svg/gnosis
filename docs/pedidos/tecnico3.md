# Pedidos do TÉCNICO3 (Onda 3)

## ARTE (painted_library / assets/painted)
- O export 1.2.0 EXCLUI as 5 folhas cromáticas originais (`assets/painted/{sophia,archons,
  yaldabaoth,architecture,inhabitants}.png`) e `assets/characters/*`. O jogo depende das
  versões em `assets/painted/derived/` — não apague/renomeie nenhuma derivada desses 5 nomes.
  Folha NOVA sem derivada (como `eons.png`) fica no .pck normalmente. A TecnicoQA
  (`derivadas_existem`, `folhas_originais_nao_carregadas`) fica vermelha se o catálogo voltar a
  carregar uma original.

## UI3 (options_menu)
- Nada obrigatório. O VSync agora nasce DESLIGADO; o botão "VSync" continua valendo e o teto de
  qps (taxa do monitor) é reaplicado em `GameManager.apply_settings()`. Se o menu ganhar um texto
  de ajuda, sugestão: "Desligado = fluido (limitado à taxa do monitor); Ligado = sem rasgo de imagem".

## CHEFE / João
- Medir em TELA CHEIA (F3 = contador) para confirmar que a queda a ~21 qps sumiu — em janela não se
  reproduziu nem com VSync ligado (docs/onda2/TECNICO3.md §2).
- Build 1.2.0 (.exe + instalador) só com o OK do João; Inno Setup precisa ser reinstalado
  (`winget install JRSoftware.InnoSetup`).
