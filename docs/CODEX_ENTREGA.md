# GNOSIS — O Despertar / edição Codex
Atualização: 17/09/2026. Feito para João em uma cópia independente.

A campanha existente de 54 telas, o combate, a narrativa, a progressão e seus
personagens são a base herdada. Esta sessão acrescenta a reformulação visual
integrada, o ateliê e o desafio curto; não reivindica a criação da campanha.

## Abrir e jogar
Execute **Jogar GNOSIS Codex.bat** nesta pasta. Usa o Godot 4.7.1 instalado e
funciona sem conexão durante o jogo.

- **Entrar no desafio:** três encontros, arma nível 3, um Anel, recuperação de
  vida entre encontros, resultado, derrota e revanche.
- **Ateliê:** Sophia e sete Arcontes, dez modos, pausar/animar, espelhar,
  três estudos de cor e níveis da arma. “Testar em combate” enfrenta o chefe escolhido.
- **Bestiário:** no ateliê, catálogo dos perfis da campanha, incluindo criaturas,
  variantes, formas do Rei, Soter e Velkar. W/S ou setas rolam.
- **Campanha:** campanha herdada com o novo visual. “Continuar” aparece quando
  há checkpoint nesta cópia; sem checkpoint, esse lugar abre “Crônicas”.

| Ação | Teclado | Controle Xbox |
|---|---|---|
| Mover | A/D ou setas | Analógico esquerdo |
| Saltar | Espaço | A |
| Golpes leve / forte | J / K | X / Y |
| Esquivar | Shift ou L | B |
| Bloquear / aparar | I | LB |
| Anel / Esfera Solar | U / O | RB / RT |
| Trocar Anel | Q/E, 1–7 | LT |
| Pausa | Esc | Start |

J → J → K experimenta o lançador com arma nível 3. Amarelo avisa golpe
aparável; vermelho exige esquiva. O teste automatizado usa as ações de teclado;
não houve teste com controle físico.

## Direção visual
Fantasia sombria ilustrada: pedra entalhada e metal envelhecido. Sophia usa
marfim, prata e ciano; inimigos combinam aço escuro com a cor do Éon; interativos
usam ouro e cristal. Arquitetura distante tem menos contraste. Pilares, braseiros,
névoa e destroços ocupam camadas separadas de paralaxe. Interface em azul
profundo, marfim e ouro, com títulos serifados.

As seis folhas PNG novas totalizam aproximadamente 13,2 MiB e contêm:

- Sophia: repouso, duas poses de corrida, preparação, golpe e conjuração.
- Sete Arcontes e Colosso Oco.
- Seis bases de criaturas, Soter, Velkar e Adormecido.
- Yaldabaoth redesenhado a partir da referência de João, com orbe separado.
- Nove ambientes: sete Éons, Centro e Mente.
- Pilar, baú, obelisco, destroços, braseiro e plataforma.

Os 22 tipos de wave herdados usam essas bases e variantes. Criaturas temáticas
herdam a família de seu Arconte. Não são 22 folhas de animação exclusivas.
A Sombra da Sophia usa a silhueta da protagonista escurecida.

## Ecossistema de criação
1. Conceito e identidade vêm do bestiário e da história existentes.
2. Ilustrações usam **imagegen**, ferramenta integrada. Prompts registrados e
   referência estão em [ARTE_PROMPTS.md](ARTE_PROMPTS.md).
3. **PaintedLibrary** registra folhas, recortes, pivôs e material de transparência.
4. **ArtProfile / Bestiary** ligam identidade, escala e características à arte.
5. **CharacterArt** recebe o estado real do combate. Sophia troca seis poses;
   **BossPuppet** articula os chefes com ossos, recortes rígidos de armadura e
   pele para tecidos/fera. Mãos, cotovelos, ombros, pernas e cabeça acompanham
   preparação, ataque e recuperação. O orbe do Rei mantém a origem dos tiros.
6. **Ateliê, desafio e capturas** permitem examinar e testar os mesmos perfis
   usados na campanha.

As paletas do ateliê são estudos temporários. A progressão da arma ilumina novos
sinais ao redor de Sophia; a roupa não ganha cinco conjuntos de armadura.
Estados sem desenho exclusivo reutilizam poses e transformações. Animação
quadro a quadro completa das criaturas permanece como melhoria futura.

## Implementado
- Novo menu, ateliê e desafio de três encontros com seleção de chefe.
- Reformulação visual de pré-jogo, pausa, opções, resultados, loja, diálogos,
  bestiário e HUD. Loja com rolagem e saída visível.
- Câmera mais próxima, com antecipação suave na direção do movimento.
- Fundos por Éon, arquitetura em paralaxe, névoa, primeiro plano, chão texturizado
  e plataformas ilustradas. Colisões e regras de interação preservadas.
- Baús, selos e NPCs com novas artes.
- Revisão de golpes, impactos, projéteis, áreas de magia, portais e transições.
- Fragmentos de morte recortam a própria pintura e usam a física existente.
- Repositório, save, opções e lançadores independentes do original.

## Arquivos principais
| Grupo | Arquivos |
|---|---|
| Arte nova | assets/painted/{sophia,archons,inhabitants,yaldabaoth,eons,architecture}.png |
| Catálogo e material | scripts/fx/painted_library.gd; assets/shaders/painted_key.gdshader |
| Personagens | scripts/data/art_profile.gd; scripts/autoload/bestiary.gd; scripts/fx/character_art.gd; scripts/entities/{player,enemy,npc_encounter,sleeper}.gd |
| Cenário e objetos | scripts/levels/{scenery,level}.gd; scripts/entities/{chest,seal_puzzle,exit_portal}.gd |
| Efeitos | scripts/fx/{codex_combat_aura,codex_sanctum,camera_shake,gib,impact_burst,projectile,aoe_nova}.gd |
| Desafio | scripts/autoload/codex_session.gd; scripts/levels/codex_trial.gd; scenes/levels/CodexTrial.tscn |
| Menu e ateliê | scripts/ui/{codex_menu,character_atelier,codex_style}.gd; scenes/ui/{MainMenu,CharacterAtelier}.tscn |
| Interface | scripts/ui/{hud,pregame,options_menu,pause_menu,upgrade_menu,end_screen,dialogue_box,gallery}.gd |
| Testes | tools/{CodexQA,CodexPlaytest,PaintedAudit}.tscn e scripts correspondentes |
| Outros | project.godot; scenes/entities/Player.tscn; icon.svg; lançadores .bat; documentação |

O Git da cópia contém a relação exata de alterações. Capturas ficam em shots/,
excluída do Git conforme a regra herdada.

## Verificação
- Importação/editor headless e execução real para procurar erros de script.
- QA de integração: oito perfis, dez modos, congelamento dos ossos, troca de
  perfil sem acumular bonecos, três encontros, resultados,
  morte, reinício e restauração de checkpoint sem gravar o progresso do desafio.
- Partida após a articulação: três encontros vencidos em **27,8 s**, combo **13**,
  dano recebido e segunda fase confirmados, sem cura extra nem dano sintético.
- Capturas e inspeção de menus, NPCs, sete chefes em fase 2 e telas
  1, 8, 15, 22, 29, 36, 43, 50, 51 e 54. A inspeção de fase 2 usa dano sintético
  somente para colocar os chefes no estado visual a ser verificado.
- Renderer Compatibility, Radeon RX 7600. Leituras instantâneas de FPS/memória
  estão em shots/painted-audit.log; incluem aquecimento e não são benchmark.

## Pendências e limites
Detalhes da articulação: [ANIMACAO_CHEFES.md](ANIMACAO_CHEFES.md). Os recortes
preservam o aspecto de boneco 2D; junções de armadura e pano ainda podem receber
acabamento manual em assets desenhados especificamente por parte do corpo.
Áudio final, executável independente/instalador, playtest humano de sensação
dos golpes e passagem manual integral pelas 54 telas continuam pendentes.
As criaturas precisam de animações exclusivas mais extensas. Algumas bordas
de ilustrações ampliadas ainda merecem refinamento. As nove pinturas de fundo
são recortes de uma folha; telas grandes evidenciam sua resolução limitada.
O ateliê não grava alterações na campanha. Não há dependências externas novas.

## Isolamento
- Original preservado: C:\Users\jmtat\OneDrive\Desktop\Gnosis.
- Entrega: C:\Users\jmtat\OneDrive\Desktop\Gnosis-Codex.
- Branch própria: codex/despertar; user:// personalizado: GNOSIS-Codex.
- O desafio restaura o checkpoint anterior em memória ao sair.
- Os lançadores usam sua própria pasta. A cópia de trabalho isolada do Codex
  foi sincronizada para a pasta de entrega.
