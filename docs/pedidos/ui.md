# Pedidos do diretor de UI/UX a outros diretores

## Áudio
1. Criar os sons de interface que a UI já chama (sem arquivo ficam mudos):
   - `ui_open` — abrir painel/overlay (pausa, loja, golpes, confirmação). Suave, ~150 ms.
   - `blip_voz`, `blip_rei`, `blip_sophia`, `blip_estela`, `blip_npc` — "voz" da
     máquina de escrever, tocados a cada 2 letras (~20–23 por segundo). Curtos
     (30–40 ms), timbres distintos (Voz etérea/aguda; Rei e Arcontes graves;
     Sophia clara; Estela pedra/sino; NPC neutro). O `SPAM_MS = 40` do Audio
     já segura repetição.
2. Pôr os 6 nomes no `CATALOG` do `audio_manager.gd` e em `docs/AUDIO.md` (o AudioQA cobra).

## Técnico
1. `export_presets.cfg` → `include_filter`: incluir `assets/LICENSES.md` e
   `assets/fonts/*/OFL.txt`. A tela de Créditos LÊ o `LICENSES.md` em tempo de
   execução; sem o filtro, a build cai no texto de atribuição embutido (que
   cobre o CC-BY, mas não a lista completa de packs) e a OFL exige que o texto
   da licença acompanhe a fonte distribuída.
2. Nada no `project.godot` foi necessário (o tema global é instalado por código
   no `SceneManager`).

## Dono de `scripts/fx/cinematic.gd`
- `CodexStyle.serif()` agora é a **Alegreya** (leitura). Para os títulos
  (`_title`, `_boss_name`) use `CodexStyle.display()` (Cinzel, versalete) — o
  `_text`/`_boss_title` podem continuar em `serif()`.
- A apresentação do Arconte (tarja preta) cobre o HUD por ~4 s; ok, mas a barra
  do chefe só aparece depois. Se quiserem a barra subindo junto com o nome,
  chamem `hud.show_boss(e)` no fim da tarja (já é chamado ao nascer).

## Dono de `scripts/entities/stela.gd`
- O painel da Estela já herda o tema novo. Sugestão: `head`/`title` com
  `CodexStyle.display()`, corpo `body()`; trocar `▸ fechar` e `✦ nova Crônica`
  (glifos que a Alegreya não tem → caem na fonte do sistema) por `·`.

## Roteiro
- Aplicadas as 10 correções de `docs/pedidos/roteiro.md` que tocam `scripts/ui/**`.
- Textos de interface novos que passaram pelo guia: "Abandonar a jornada?",
  "Você volta ao menu. O ponto de retorno salvo permanece: …", "Pontos de
  retorno a cada Éon", "Obrigado por despertar." (Créditos). Revisem se quiserem.
