# ENCENAÇÃO 2: relatório da Onda 2b (dir2/encenacao2, 17/10/2026)

## 1. Commits (sobre integracao/onda1 @ b04f413)
b6c38b6 WIP (abertura, tentação, Campeão, dicas, Elite, RNG, registro) · 4e253fe uid da AberturaShot ·
(pedidos) · Arconte de cena se monta antes da caixa · dica do 1º telegrafo cede o lugar ·
sonda headless · sonda cobre o imparável. Ver `git log --oneline integracao/onda1..dir2/encenacao2`.

## 2. O que mudou
- **Abertura (#6)**: `cinematic.gd`: o prólogo passa de 6 cards para 3 (o Um e os Éons → Sophia, o filho e a nuvem → o Kenoma e as faíscas, "Uma delas acaba de sentir dor."). Entrada e saída ficam mais curtas (0,45/0,3 s, por card) e o total dá 19,9 s sem apertar nada.
  `narrative.gd intro()` agora é só o escuro (rubrica com o coração) e "Acorda. ...Isso. Devagar. Eu estou aqui.", e depois disso o jogador já controla a Sophia. O resto da intro ("Onde...? Quem...?", as cinzas, a dor, "Chama-me Voz", "Anda") virou a **legenda de chegada da tela 1** (`walk_arrival`, papel king). O GnoseQA já mede essas legendas.
  `level.gd`: na tela 1 a Sophia acorda em x = −470, com a Estela "logo adiante". A **Cena A** não abre mais logo depois da intro. Ela abre quando a Sophia chega ao gatilho do duelo (`_play_king_scene`) e descarta as legendas que ainda não tocaram, para nada falar por cima do duelo.
  `king_intro()` caiu para **3 falas**: a Voz ("...eu o conheço. É um rei antigo, e gentil. Não te quer mal."), o Rei com a lei do limiar e "(ergue o orbe...) Mostra-me a tua. Vem.". A fala "É um rito. Bate nele de coração leve." saiu; o sentido ficou na lei do Rei e no "não te quer mal".
- **O duelo ensina (#10)**: `level._tutor_watch()` vale uma vez por run e usa `Narrative.seen`, então não repete no checkpoint.
  - No 1º telegrafo **aparável** de um chefe (o Rei), quando o brilho de aviso acende: 0,3 s de câmera lenta (0,25×) e a dica do HUD "brilho amarelo: [bloquear] apare no tempo".
  - No 1º **imparável** do run (na prática, o Elite do fim da tela 2, porque o Rei não tem golpe vermelho): a mesma câmera lenta e "brilho vermelho não se apara: [esquiva] esquive".
  - Usa `hud.show_hint_now` se existir. Sem ela, a dica fura a fila do `hud.hints` e tira da tela a que estiver lá. O fallback final é o toast.
- **Tentação em cena (#18)**: `_stage_archon()`. O Arconte nasce antes da caixa, no mesmo ponto onde nasceria, virado para ela. Ele tem 2 quadros para montar o boneco e a caixa congela o mundo. A Sophia fica a 10 px do gatilho.
  A fala de chegada da tela, de Sophia olhando para ele ("Um trono num quarto de sonho. E ele nem abriu os olhos."), abre a caixa em vez de virar legenda.
  Depois da escolha, o Arconte espera parado (process desligado) até ela cruzar o gatilho. Então **o mesmo corpo** entra na luta e o card de chefe aparece.
  `staging.gd` ("tentacao") enquadra os dois e desce o quadro (D_LIFT) para os dois ficarem acima da caixa.
- **Campeão com nome (#20)**: `Narrative.CHAMPION_CARDS`/`champion_card(eon)` e `level._champion_card()`. Os cards ficam assim: "O SONÂMBULO · Guardião do santuário do Torpor", "O GLUTÃO", "O CARCEREIRO", "O BIBLIOTECÁRIO", "O REFLEXO", "O PORTADOR DE ESPOROS" e "O PRETORIANO". A palavra "Campeão" saiu do card, porque também é o nome de uma dificuldade.
- **Sem legenda de chegada na luta de chefe (#21)**:
  - Rei: a Cena A esvazia a fila de legendas.
  - Arcontes: a fala de chegada vai para a caixa da tentação.
  - Mente (68): a fala de chegada entra na caixa do `final_pre`, depois do clarão (`_take_arrival_lines`).
  - As legendas da fase 2 dos Arcontes e do 7º Anel continuam durante a luta, porque fazem parte dela.
- **Balance P4**: na última wave, o Elite pula o Invocador e passa para o anterior (tela 63: Fantasma Elite no lugar de Invocador Elite).
- **Determinismo (68)**: `final_battle.gd` usa `RunManager.screen_rng(68)` se existir. Se não existir, usa um RNG próprio semeado por `hash("final_68")`, em vez do `randi()` global.
- **Registro (#54)**: na fala solene (Voz, Rei, Arcontes, Yaldabaoth), o pronome fica em ênclise quando nada o atrai. Mantive a próclise depois de negação, "que", interrogativo e advérbio. A Sophia continua livre. Foram 16 falas, sem mudar o sentido:
  - "Tenho-te."
  - "e eu refaço-te"
  - "e mostro-te" (2×, era o "eu te mostro" do crítico)
  - "vai oferecer-te" (2×)
  - "eu poupo-te"
  - "Dá-me uma!"
  - "Ele costurou-me"
  - "Galila classificou-te"
  - "Aqui me calo."
  - "Dei-te um luto"
  - "tu trouxeste-me"
  - "Classifica-te."
  - "Achei-te."
  - "vai dar-te"

  As rubricas do narrador ficaram como estavam (o ESTILO usa "A luz te costura" como exemplo). Também corrigi o "uma faísca escorre" depois de ponto, que agora sai com maiúscula (pedido do i18n).
- **Centro sem música até o 1º caco (item 6)**: conferi o código. O `Audio._update_center_music()` já segura a faixa, e a Staging/Level não tocam música no Centro. Não há nada a mudar do meu lado.
- Ferramentas novas:
  - `tools/encenacao/AberturaShot.tscn`: cronometra e filma a abertura como um jogador novo (cards sem pular, 2,5 s por fala, `walk=N` para apressado ou paciente).
  - `tools/encenacao/SondaEncenacao2.tscn`: sonda headless com 8 checks.

## 3. Capturas (`/home/user/caps/encenacao2/`)
- **Abertura, tempos** (AberturaShot com `--fixed-fps 60` e 2,5 s por fala, que é uma leitura rápida):

  | | antes (`antes/ab.log`) | depois (`depois/ab.log`) |
  |---|---|---|
  | fim do prólogo | 34,6 s | 19,9 s |
  | primeiro comando | 62,1 s | **24,9 s** |

  - Apressado: a Cena A abre aos 29,0 s e o duelo aos 38,6 s.
  - Paciente (`depois_paciente/ab.log`): ouve 5 das 6 legendas e a Cena A abre aos 58,5 s, só quando ele anda.
- `antes_abertura.png`: antes, 11 falas em caixa até o duelo, e a legenda "As cinzas ainda estão quentes..." por cima da barra do Rei (o #21).
- `depois_abertura_a.png`: os 3 cards, a caixa com o coração, "Acorda." e o controle com a Estela à frente.
- `depois_abertura_b.png`: a legenda andando, a Cena A (silhueta → Rei → máscara), o card e a câmera lenta no telegrafo.
- `depois_paciente_duelo200_s.png`: a dica "brilho amarelo: [I] apare no tempo" na tela durante o duelo.
- `cmp_tentacao_campeao.png`:
  - Tentação: antes, "Portadora..." na arena vazia. Depois, Athoth em cena à direita, a Sophia à esquerda e os dois acima da caixa.
  - Card: "O CAMPEÃO" virou "O SONÂMBULO".
- Sonda (`godot --headless ... res://tools/encenacao/SondaEncenacao2.tscn`): 8/8 PASS.
  - Mente: a chegada vai para a caixa e não para a legenda.
  - Arconte em cena, sem card antes da escolha, parado até o gatilho; o mesmo corpo acorda e o card aparece.
  - Tela 63: Elite = fantasma (a wave é pretoriano, arauto, fantasma, invocador).
  - Imparável: câmera lenta mais a dica "esquive".

## 4. Validação
`TIMEOUT=900 tools/validate.sh` (último commit):
```
Scripts OK · ScriptCheck OK · CodexQA OK (53) · AudioQA OK (46) · GnoseQA OK (18) · SaveQA OK (41) · PuppetQA OK · HeroQA OK · WaveQA OK — TUDO VERDE
```
`tools/regressao/run_all.sh`: PASS 10/10 (B1 A1 A2 A3 A4 A5 A6 R1 R3 R10).

## 5. O que NÃO ficou bom / não deu tempo
- Quem corre direto para a direita (cerca de 3,5 s até o gatilho) só vê a 1ª legenda ("Onde...? Quem...?"). A Cena A descarta o resto, inclusive "Chama-me Voz". Escolhi não segurar o jogador. Se o João quiser que todos ouçam, a alternativa é a Cena A esperar a legenda atual acabar, com risco de ela passar do ponto do duelo.
- O prólogo tem cerca de 110–140 caracteres por card em 5,4–6,4 s. Para quem lê devagar é apertado: o card não espera o jogador (só avança antes, com qualquer tecla) e a meta de 20 s não deixa folga.
- A "regra do nome" (#16) não foi decidida: o card 2 continua dizendo "Sophia". A decisão é do João.
- O Rei-tutorial só tem golpe aparável. A dica "esquive" aparece no 1º Elite (tela 2), não no duelo do Rei. A onda rasteira da fase 2 do Rei (que pede pulo) não ganhou dica.
- A dica do aparar aparece no brilho do Rei, mas o golpe dele é um orbe lento: o tempo do aparar é na chegada do orbe, não no brilho. A dica ensina o código de cor; a sincronia fina não.
- A barra do chefe aparece durante a tentação, porque o Enemy chama `show_boss` no `_ready`. Não achei ruim. O card do Campeão e a barra ainda falam coisas diferentes (pedido ao Combate2).
- "O PORTADOR DE ESPOROS" tem 21 caracteres (o ESTILO pede no máximo 18). Cabe no letterbox, mas não capturei esse card específico (só o do Sonâmbulo).
- Não joguei com controle de verdade: tudo foi visto por captura e sonda. O feel da câmera lenta de 0,3 s e o ritmo da abertura precisam do João.
- O determinismo da 68 com o RNG próprio não foi conferida pelo bot de balance (só por leitura).

## 6. Pedidos
`docs/pedidos/onda2_encenacao2.md`:
- UI-HUD2: `show_hint_now`; a dica da tela 3 diz "apara" e deveria dizer "apare"; combinar se as legendas de fase 2 e do 7º Anel continuam com chefe vivo.
- Combate2: o `display_name` do Campeão; uma futura animação de entrada só quando o Arconte acordar.
- Técnico2: o `screen_rng` já é chamado se existir.
