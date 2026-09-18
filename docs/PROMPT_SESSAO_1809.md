# PROMPT-MESTRE — sessão 18/09/2026 (escrito pela IA para si mesma, a pedido de João)

> João escreveu (resumo fiel): "Quando chego na tela 3 e mato o boss, volta pro
> começo. O jogo está MUITO curto, não tem história, sem apelo narrativo, não
> ensina nada sobre gnosticismo (como GoW ensina sobre grego e nórdico); em 3
> telas já estou de cara com 1 boss. Pode baixar packs do GitHub de elementos
> visuais (explosões, efeitos) e sons — lota meu PC de porcaria, eu autorizo.
> Escreva um prompt pra si mesmo com tudo isso, execute em cima do próprio
> prompt e me entregue uma versão comercializável. Pode disparar agentes."

## Diagnóstico (verificado com capturas)
1. **"Tela 3 → boss → volta ao começo" NÃO é bug da campanha.** O botão em
   destaque do menu ("ENTRAR NO DESAFIO") abre o *Desafio Codex*: 3 encontros
   com chefe e volta ao menu. A Campanha (botão pequeno) tem 54 telas — e a
   sessão anterior já tinha pronto, em branches nunca integradas, o run de
   **68 telas** com travessias por zonas, 64 ganchos de áudio e poses novas da
   Sophia. **Integrado hoje** (3 merges limpos, headless OK, CodexQA PASS).
2. **História/pedagogia:** só há caixas de diálogo que pausam. O autoload
   `Gnosis` (Estelas, legendas de caminhada, Crônicas) está vazio.
3. **Sem VFX de impacto nem um único som.** Catálogo de 64 SFX + 14 músicas já
   existe em código (`audio_manager.gd CATALOG`), sem arquivos.
4. **Acabamento de versão final ausente:** menu prioriza a demo, sem prólogo,
   sem card de chefe, sem tela de golpes, opções só com volume, fim nu.

## Ordem de execução (esta sessão)
- **Onda 0 (feita):** merge das branches órfãs; validação; capturas.
- **Onda 1 (3 agentes em paralelo, worktrees, arquivos disjuntos):**
  - **GNOSE** — conteúdo que ENSINA o gnosticismo: 18 Estelas em ordem
    pedagógica (Mônada, Pleroma, Éons, Sophia, o aborto cego, Yaldabaoth,
    Arcontes, a faísca, a gnose como saber-lembrar, Nag Hammadi/Pistis Sophia
    como fontes reais), legendas de caminhada sem pausar, prólogo em cards,
    card de chefe com letterbox, epílogo, tela Crônicas persistente.
  - **ASSETS** — baixar packs CC0/CC-BY (Kenney etc.): explosões, partículas,
    impactos, UI; **preencher os 64 SFX + músicas** do catálogo; biblioteca
    `VfxLibrary` (morte, chefe, golpes, magias por Anel, ambiente por Éon).
    Licenças registradas em `assets/LICENSES.md`. Nada NC.
  - **UX** — menu de versão final (Continuar · Nova campanha · Provação ·
    Ateliê · Crônicas · Opções · Sair), tela de golpes, opções completas,
    HUD por papel de tela, save com versão, fim de jogo digno.
- **Onda 2 (integração):** merge, validação, capturas, bot de balance nas 68
  telas, QA de fluxo, build `GNOSIS.exe` + instalador, docs, commit.

## Regras
- Um agente por conjunto de arquivos; contrato entre eles definido no prompt.
- Zero `SCRIPT ERROR`; capturar tela após mudança visual; commitar na branch.
- Regra de ouro narrativa: a virada (Voz = Yaldabaoth) não vaza antes da 64.
- Respeito: nomes sagrados de fés vivas nunca como vilão.
- Honestidade: "comercializável" = jogável do início ao fim, com som, VFX,
  história, menus e instalador. Playtest humano e arte adicional ficam pra João.
