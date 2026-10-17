# LOJA 2 — pacote Steam com a key art pintada (Onda 4)

Branch `dir4/loja2` (base `integracao/onda1` eb46164). Não toca em nada do jogo: só
`tools/store/build_store2.py`, `assets/store/v2/**`, `assets/store/board2.png` e este doc.

## Para o João escolher
**Prancha: `assets/store/board2.png`.** Cada linha é uma peça, com 3 colunas:
NOVA com título OURO · NOVA com título MARFIM · ANTERIOR (variante A, "a Mente", carmim).
No fim, o teste de legibilidade no tamanho real em que a Steam mostra (231×87 etc.).

Decisões pendentes: (1) título ouro ou marfim; (2) por peça, nova ou anterior;
(3) ícone da comunidade (olho pintado, cristal pintado ou faísca desenhada).

## Como regerar
`python tools/store/build_store2.py` (tudo, ~40 s) ou `--only main,header,small,vertical,library,logo,hero,page,icon,board`.
Determinístico (MD5 iguais em duas rodadas). Fonte: `artes/gpt/steam/keyart_wide_a_x4.jpg` e
`keyart_vertical_a_x4.jpg` (o x4 do Real-ESRGAN que já existia; não precisei ampliar mais nada),
fonte Cinzel Decorative Bold (OFL). Reaproveita as utilidades do `build_store.py` (v1).

## Peças (assets/store/v2/)
| Peça | Arquivo(s) | Fonte / recorte |
|---|---|---|
| Header 920×430 | `capsule_header_920x430_{ouro,marfim}.png` | key art larga, largura inteira; título no céu vazio |
| Small 462×174 | `capsule_small_462x174_{ouro,marfim}.png` | só o Rei + céu; título ocupa 60% da largura |
| Main 1232×706 | `capsule_main_1232x706_{ouro,marfim}.png` | key art larga quase inteira |
| Vertical 748×896 | `capsule_vertical_748x896_{ouro,marfim}.png` | key art vertical, título no topo |
| Library 600×900 | `library_capsule_600x900_{ouro,marfim}.png` | key art vertical inteira (mesmo aspecto 2:3) + filete |
| Library hero 3840×1240 | `hero_3840x1240.png` | SEM texto/logo; faixa da key art larga |
| Library logo 1280×720 | `logo_library_1280x720_{ouro,marfim}.png` | transparente (conferido sobre cinza) |
| Page background 1438×810 | `page_background_1438x810.png` | key art escurecida, dessaturada, desfocada; centro e base mais escuros |
| Community icon 184×184 | `community_icon_184_{olho,cristal,faisca}.png` | olho e cristal recortados da pintura; faísca = desenho da v1 |

Títulos: **ouro** = ouro envelhecido (degradê bronze + pátina granulada) com a faísca de 4 pontas
SOLTA acima do "I", como o pingo de um "i" (1ª tentativa punha a faísca no topo do I e, pequena,
lia "GNOSTS" — corrigido). **marfim** = papel do Códex com contorno de tinta grosso e filete de ouro.
Só o título nas cápsulas (sem frases, notas, "em breve").

## Opinião (honesta)
- A key art nova é melhor que a composição anterior: é uma pintura única (luz, escala do Rei, a
  Sophia no chão de verdade), em vez de recortes colados sobre um fundo. Recomendo NOVA em todas as peças.
- Título: **marfim** é o mais legível em 231×87; o ouro é mais bonito grande. Sugestão: marfim nas
  cápsulas pequenas (small/header) e ouro no resto — ou marfim em tudo, pela unidade.
- Ícone: olho pintado lê melhor em 184 (mas é o símbolo do vilão); cristal = a faísca da Sophia.

## Limites / o que não ficou bom
- **Hero:** a key art é 3:2 e o hero é 3,1:1. Para não cortar a máscara do Rei nem a Sophia, a faixa
  central é a pintura real e as laterais (~15% de cada lado) são ESPELHO borrado e escurecido. De perto
  dá para ver o espelhamento (esq.: estandartes; dir.: torres). Os anéis do topo e as botas da Sophia ficam
  cortados. Se incomodar, a alternativa é a hero anterior ou pedir ao GPT uma key art panorâmica 3:1.
- Header: a ponta do capuz do Rei encosta na borda de cima e a Sophia sai cortada nas pernas (aspecto 2,14:1).
- Vertical/library: o título fica sobre a fileira de anéis (o céu vazio do topo da vertical é estreito,
  como o manifesto já dizia); a penumbra atrás dele garante leitura.
- A key art tem a mesma composição em todas as peças — é a prática da Steam, mas não há variedade.
- Não regerei as capturas (screenshot_*), nem 1x antigos (460×215 etc.): a Steam hoje pede os 2x.
- Não testei upload no Steamworks.
