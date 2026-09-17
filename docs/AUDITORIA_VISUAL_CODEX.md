# Auditoria visual — cópia Codex

Base examinada: BIBLIA.md, ROADMAP.md, docs/GDD.md, docs/LORE.md, cenas,
controladores, desenhos, imagens e hooks de sprites. Os dois textos anexados
por João orientam o overhaul. A imagem do Arconte é referência visual;
não altera a história ou as mecânicas por si só.

## Constatações
- Godot 4.7.1, GDScript, viewport 640×360 e janela 1280×720, Compatibility.
- Uma protagonista, 22 tipos de wave, sete Arcontes, formas especiais e NPCs.
- Level01 é reutilizada nas 54 telas; regras e narrativa ficam nos autoloads.
- CharacterArt concentra desenho e poses; Bestiary fornece perfis e atributos.
- Cenários anteriores eram principalmente polígonos em Scenery; havia hook
  para PNG, mas não uma coleção ilustrada por Éon.
- Imagens prévias concentravam-se em Sophia e Rei/Demiurgo. Documentos
  guardavam decisões contraditórias; a autorização recente permite novos PNGs.
- HUD e menus usavam vários controles padrão. Não foi encontrado sistema de
  tileset a substituir, nem fonte própria empacotada.
- Colisões e controles são separados do desenho, permitindo mudar a camada
  visual sem reescrever o combate.

## Prioridades aplicadas
Sophia → criaturas/chefes/NPCs → ambientes e profundidade → objetos e efeitos
→ interface → inspeção dentro do Godot e correções.

## Inventário após a integração
71 scripts GDScript, 23 cenas, dois shaders, 16 PNGs de assets e um SVG,
excluindo capturas e artes de referência. Materiais e outros recursos são
construídos em memória; não há arquivos .tres/.res neste inventário.
Nenhuma biblioteca externa foi adicionada.

Veja CODEX_ENTREGA.md para mudanças, validação e pendências; ARTE_PROMPTS.md
registra os prompts das ilustrações. O histórico Git da cópia é a lista exata
dos arquivos alterados.
