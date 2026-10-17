# LOJA — arte de loja (Steam), Onda 2

Agente LOJA (branch `dir2/loja`). Continuação do agente derrubado pelo reinício das 06:05 UTC:
o anterior deixou o script, a ferramenta de captura e parte das peças sem commit; revisei,
completei o que faltava (hero, biblioteca, ícones, variantes B, capturas) e commitei.

## 1. Commits
Ver `git log --oneline integracao/onda1..dir2/loja` (todos com prefixo "loja").

## 2. O que existe (arquivos)
- `tools/store/build_store.py` — **regera tudo** (determinístico: rodei duas vezes, mesmos MD5).
  `python3 tools/store/build_store.py` (tudo, ~3 min) ou `--only header,small,main,vertical,library,hero,logo,icon,screens,board`.
  Compõe com PIL a partir de `assets/painted/` (Sophia, Rei, Olho), `assets/backgrounds/eon_8_far.png`
  (a Mente) e `eon_0_far.png` (o Limiar), fonte Cinzel Decorative (OFL, já no projeto). Sem IA nova.
- `tools/store/capture.sh` + `StoreShot.tscn` + `store_shot.gd` — capturas REAIS 1920×1080 do jogo
  (Shot.tscn sem legenda nem contador de FPS; "piloto" leva a Sophia até o chefe e golpeia; `god`
  impede a morte durante a foto). Ferramenta, não entra no jogo. Os quadros brutos ficam fora do git
  (`/home/user/caps/loja/raw`); a lista dos escolhidos está em `SHOTS` no build_store.py.
- `assets/store/` (com `.gdignore`; não entra no .pck):

| Peça (Steamworks) | Arquivo para subir | Tamanho do pedido (1x) |
|---|---|---|
| Header capsule | `capsule_header_920x430[_b].png` | `capsule_header_460x215[_b].png` |
| Small capsule | `capsule_small_462x174[_b].png` | `capsule_small_231x87[_b].png` |
| Main capsule | `capsule_main_1232x706[_b].png` | `capsule_main_616x353[_b].png` |
| Vertical capsule | `capsule_vertical_748x896[_b].png` | `capsule_vertical_374x448[_b].png` |
| Library capsule | `library_capsule_600x900[_b].png` | — |
| Library hero (sem texto) | `hero_3840x1240[_b].png` | — |
| Library logo (transparente) | `logo_library_1280x720.png` | — |
| Logo avulso (transparente) | `logo_1600.png` (1604×565) | — |
| Ícone | `icon_eye_512.png` + `icon_eye.ico` **ou** `icon_spark_512.png` + `icon_spark.ico` | .ico com 256/128/64/48/32/16 |
| Capturas (mín. 5) | `screenshot_01..06_*.jpg` (1920×1080) | — |
| Prancha para escolher | `board.png`; teste de miniatura a 50%: `half_test.png`; ícones em todos os tamanhos: `icon_*_sizes.png` | — |

**Sobre 231×87 × 462×174 (e os outros "2x"):** o pedido foi 231×87, 460×215, 616×353, 374×448 — são os
tamanhos antigos da Steam. Desde 2024 o Steamworks pede o DOBRO (462×174, 920×430, 1232×706, 748×896) e
reduz sozinho. Entreguei os dois: os 1x pedidos e os 2x para subir. Cada 1x é renderizado em 2x e reduzido
(título mais limpo), e o arquivo 231×87 tem exatamente 231×87. Se a Steam recusar um tamanho, use o outro.

**Variantes A/B:** sem sufixo = A, "a Mente" (céu carmim com o Olho, mais marcante na vitrine);
`_b` = B, "o Limiar" (catedral azul da lua, onde o jogo começa — combina com a 1ª captura).
O João escolhe por peça na `board.png`. Opinião: A para as cápsulas (o carmim destaca numa grade de
lojas azuladas), B para o hero (é a primeira tela do jogo).

**Capturas escolhidas** (quadros reais; HUD do jogo visível, sem legendas):
01 Rei no Limiar · 02 magia contra Athoth · 03 Galila entre gaiolas · 04 Astaphaios nos espelhos ·
05 golpe contra Armupiel · 06 o Centro com criaturas. Seis cenários diferentes.

## 3. Capturas / provas
- Prancha: `assets/store/board.png` (todas as peças lado a lado, A/B, ícones, logo, hero, capturas).
- Legibilidade em miniatura: `assets/store/half_test.png` (título lê bem até na small capsule).
- Brutos e folhas de contato: `/home/user/caps/loja/raw/`, `/home/user/caps/loja/cs_s*.png`.

## 4. Validação
(ver relatório final — colado lá)

## 5. O que NÃO ficou bom / limites (honesto)
- **A Sophia é pequena nas capturas** (o enquadramento real do jogo, câmera aberta). São fiéis, mas
  vendem menos que as cápsulas. Se quiser capturas mais "de perto", isso é decisão de câmera do jogo,
  não da loja — não recortei/ampliei para não mostrar algo que o jogo não mostra.
- A key art mostra a Sophia e o Rei juntos num céu que é de outro Éon (composição de loja, não uma
  cena do jogo). Isso é normal em cápsula, mas as CAPTURAS é que mostram o jogo de verdade.
- Sem ondas de criaturas comuns boas: a tela 3 mostrou um inimigo só; a 6ª captura (Centro) é a que
  tem mais criaturas. Faltam capturas de horda grande e da Sophia em close.
- Ícone "faísca" é mais simples/gráfico; o "Olho" lê melhor pequeno mas é o símbolo do vilão.
- Os pés da Sophia saem cortados na borda inferior em algumas cápsulas (escolha de enquadramento).
- Não fiz: ícone da comunidade 184×184, fundo da página (page background), trailer/GIF.
- Nada de texto promocional nas imagens (sem "em breve", notas, prêmios) — sem promessas falsas.

## 6. Pedidos a outros agentes
Nenhum obrigatório. Sugestão ao chefe: quando houver build com áudio/animação nova, rodar de novo
`tools/store/capture.sh` + `build_store.py --only screens,board`.
