# Pedidos da NARRATIVA (branch `dir5/encenacao5`, 29/10/2026) — reescrita do Limiar

Texto fechado: `C:\gnosis-wt\_caps\narrativa\AMOSTRA_LIMIAR.md` (v3). Já no jogo: prólogo, despertar, Cena A,
falas do duelo C1–C6, queda do Rei (F1a/b…F11), morte na tela 1, Torpor em legenda depois de 10 s.

## chefes6 — a mecânica da Mentira do Rei — ATENDIDO em 5b076cb (sinais ligados; provisório removido)
O duelo liga sozinho: `Gnosis.boss_card("rei")` → `Narrative.rei_duel_attach(rei)`. A Narrativa escuta o
que existir no `BossBrain` do Rei (`rei.brain`), por nome, sem depender de vocês:
- **`signal lie_exposed(id: String)`** — o Desmentido: 1º golpe no olho com `_low == true`, 1 vez por luta.
  Enquanto não existir, uso um PROVISÓRIO: conecto em `_eye_box.hit_received` e leio `_low` (campos privados
  de vocês — troquem pelo sinal e eu tiro o provisório). É também o que liga as variantes da queda (F1a/F2a).
- **`signal move_will_start(id: String, lead: float)`** — opcional: emitam quando o golpe for ESCOLHIDO, com o
  tempo `lead` até a preparação. Se `lead ≥ 1 s`, C2 (Raio) e C3 (Mão) tocam ANTES do golpe; sem o sinal, tocam
  na recuperação dele (é o que roda hoje). Não atrasem o golpe por causa da fala.
- O ajoelhar eu leio por polling (`estate == RECOVER` e `mv.expose`), o mesmo critério do olho.
- Fases: `Narrative.archon_phase2/3("rei")` agora contam no orçamento do duelo e devolvem `[]` (a fala sai
  por mim). Não mudem o `_enter_phase`.
- Seu lado (mecânica): card com a frase "“Um rei jamais se curva.”" (o título está em `Gnosis.BOSS_TITLES`, que é
  meu — me digam o formato e eu troco), 8 s sem guarda (= o Rei PARADO, ajoelhado e sem atacar: sem escolher golpe,
  sem telégrafo, sem "sai de cima"; olho embaixo, janelas ×1,3/×1,35), aviso do HUD "MENTIRA EXPOSTA · o Rei fica
  8 s sem guarda".
- Sonda: `tools/encenacao/ReiDuelProbe.tscn` (headless) simula os eventos: 0 falhas.

## UI
- Opções → "Dicas" (liga/desliga o degrau 2, padrão ligado): exponham `GameManager.hints_enabled: bool`; eu leio por
  `GameManager.get("hints_enabled")` (sem a variável = ligado).
- Bestiário: "O que ele diz: 'Um rei jamais se curva.'" + "Repare nele depois da Mão." · Crônicas: "Mentiras
  desvendadas N/8".

## level6 / ritmo da tela 1
- A caminhada da tela 1 tem ~660 px (≈ 3,6 s correndo): a Cena A corta as legendas pendentes. O trio da névoa foi
  para dentro da Cena A; a fala da Estela (D7) só aparece para quem anda devagar. Se quiserem alongar o Limiar
  (mais 400–600 px antes do duelo), as legendas D3–D7 cabem inteiras.

## audio7 / Dublagem
- `tools/audio/voice_probe.gd`: troquei as agulhas e os ids fixos para os textos novos (intro "Ei. Ei! Acorda…",
  id 9c8e9fd7cd28; card do prólogo 7bce0dcd8a25). Conferir com o roteiro do pipeline quando a Dublagem entregar.

## estab5 / QA
- `tools/gnose_qa.gd`: a regra "sem 'você' no diegético" caiu (decisão do chefe). Segue proibida a aspa simples.

## REGISTRO DE DELEGAÇÃO (30/10, pedido do Guardião via chefe) — opção "Dicas"
Mexi, com mudança mínima, em arquivos de outros donos (avisem se quiserem outro formato):
- `scripts/autoload/game_manager.gd` (Técnico): `SETTINGS_DEFAULT.lie_hints = true` + espelho `var lie_hints`
  (atualizado em `apply_settings`). O SaveManager já grava/lê toda chave de `SETTINGS_DEFAULT` (sem mudança nele).
- `scripts/ui/options_menu.gd` (UI): linha "Dicas: Ligadas/Desligadas" na coluna JOGO (`_toggle` com meta
  `plural`); separação das colunas 4 → 2 e amostra da legenda 26 → 20 px para caber (captura
  `_caps\narrativa\dicas\opcoes_antes.png` × `opcoes_depois.png`).
- Efeito: desliga o degrau 2 (a pergunta da Sophia, que o Chefes6 já gateia por `lie_hints`) e o degrau 3 que já
  existe no jogo (a pista da Voz na 1ª morte, M2). **UI/Bestiário:** quando a linha "Repare nele depois da Mão"
  entrar no Bestiário (degrau 3, `lie_hint_step(3)`), ela deve respeitar `GameManager.lie_hints`.
