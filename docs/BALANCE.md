# BALANCE — histórico das rodadas do bot (tools/BalanceBot.tscn)

> O bot joga o run inteiro sozinho (persegue, bate, esquiva telegrafo, conjura,
> compra na loja) e mede POR TELA: tempo, dano tomado e "quase-mortes" (vida
> < 45% → conta 1 morte e cura, pra medição nunca parar). **O bot NÃO bloqueia
> nem faz parry** — o dano dele é TETO, não média: um humano mediano toma ~1/3.
> Rodar: `& $godot --headless --path . res://tools/BalanceBot.tscn -- 1 54 4`

## Rodada 1 (2026-09-11, antes do balance) — moedor de carne
- **Morte real na tela 17.** 19 quase-mortes até lá. Tela 8 (1º Arconte): 208
  de dano vs 90 de HP máximo. Causa raiz: **não havia NENHUMA cura no run**.
- Também revelou: dava pra **cair pra fora do mundo** (chão acaba ~x1900, sem
  paredes) — era a causa dos stalls determinísticos das telas 9–13.

## Rodada 2 (após cura estrutural + nerfs r1) — atravessa, mas pântano
- Run completo (54 telas), mas **timeout em 18 telas** (inimigo com vida demais
  pro dano do jogador no fim do run) e 224 quase-mortes.
- Diagnóstico: +3%/tela em vida E dano dos inimigos = tela 50 com 2.5x de tudo,
  enquanto a arma do jogador dava só +3 de dano por nível.

## Rodada 3 (r2: curvas separadas + arma valendo + paredes) — FORMA DE JOGO
- Run completo, **vitória na batalha dupla**. 42 min de jogo (bot a 4x).
- Dano total 18502 → **10638 (-43%)** · quase-mortes 224 → **126 (-44%)** ·
  timeouts 18 → **3** (e os 3 são limitação do bot, não do jogo: tela 32 =
  micro-dança com 26 de dano; 43 = Belias, o bot fica PARADO na poça de veneno;
  50 = Armupiel blindado, o bot ignora os servos).
- Curva: telas 1–11 saudáveis (0–1 morte) · meio 100–250 de dano de bot
  (~35–85 de humano, com 120 HP + recomposição de 30%/tela + cura por Éon +
  Restauração na loja = desafiador e viável) · pico no clímax (tela 54: 843 —
  é a batalha dupla, DEVE ser o pico).

## O que mudou no jogo (r1+r2)
- **Cura:** Anel de Arconte = cura cheia · início de tela recompõe 30% do
  perdido · loja vende Restauração (50 faíscas). Sophia 90 → **120 HP**.
- **Curvas:** vida dos inimigos +2%/tela · dano +1.2%/tela (era 3% em ambos).
- **Arma:** +6 de dano/nível (era +3) · magias +12/nível (era +8).
- **Waves:** teto de 4 por tela (era 5). Salva de chefe: 65% de dano/projétil.
- Dano base: waves tier 2–4 e bots de Éon −2 · Arcontes −3..−6 · Rei-tutorial
  12→8 · formas finais 24/30→20/24.
- **Paredes na arena** + resgate do vazio (player e inimigo não caem mais).

## Próximo passo
Playtest HUMANO (feel, parry, uso dos Anéis). Só então mexer de novo em número.
