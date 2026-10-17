# UI-HUD — relatório da Onda 2 (dir2/ui-hud)

Continuação do agente derrubado às 06:05. O trabalho que ele deixou sem commit
(DialogueBox, tarefas 1–3, e a sonda `tools/ui_hud/`) foi revisado, testado e aproveitado.

## 1. Commits (branch dir2/ui-hud, sobre integracao/onda1)
- f2ac69f DialogueBox: PauseStack, escolha dentro de 640×360 com motivo visível, line_shown/wait_2s/lock_advance/blip; sonda
- dc229dc sonda dialog_api medida por estado
- 80c0cfd legenda abaixo dos pés / acima da barra do chefe, some na pausa e com a Sophia morta; 2 barras de chefe
- 32d3977 toast em faixa própria; HUD recua no card da Cinemática
- 7a34603 dicas de controle; spark_orb_arrived; restore_ring; "Arma Nv. N"
- bcb4c2c (revisor) relógio por delta na caixa; boss_bars(); redesenho com o mundo pausado; ring_note no restore
- af658e4 R21 + R22
- 45a9175 merge de integracao/onda1 (autorizado, para pegar a API do Áudio)
- cf3787d detach_ring usa Audio.ring_note(i)

## 2. O que mudou
- `scripts/ui/dialogue_box.gd`: `PauseStack.push/pop(self)` (solta também no `_exit_tree`); `line_shown(i, fala)` no
  INÍCIO de cada fala; `cue == "wait_2s"` = 2 s sem aceitar aperto; `lock_advance(on)` / `is_advance_locked()`;
  blip por `Audio.play_blip(falante)` a cada 2 letras. Escolha: a caixa cresce para cima (base fixa), botões numa
  linha que encolhe a fonte para caber; opção bloqueada mostra o motivo ESCRITO na caixa (acende ao receber foco);
  foco no 1º habilitado, ←/→ circulam, guarda de 0,25 s contra aperto acidental; botão A escolhe. Tempos medidos por
  `delta` no `_process` (funciona com `--fixed-fps`). API documentada no topo.
- `scripts/ui/caption_bar.gd`: faixa na base (y ≈300–354), abaixo dos pés (y≈242); com barra de chefe ela sobe e
  termina acima dela (`hud.boss_area_top()`); some com árvore pausada OU `PauseStack.is_held()`; Sophia morta =
  fila descartada e a faixa some na hora.
- `scripts/ui/hud.gd`:
  - até 2 barras de chefe lado a lado (`show_boss` por chefe, vida/fase/nome de cada um; `boss_phase(n[, chefe])`
    acha o chefe certo pela propriedade `phase` quando vem sem chefe); quem cai e é `revivable` mostra barra cinza
    enchendo + "refazendo-se" (lê `down_since` do FinalBattle sem depender da classe); placa escura atrás para
    contraste, medalhão I/II à esquerda da barra, "FASE II" por dentro; `boss_bars()` para a QA;
  - toast em `TOAST_RECT` (120,88,400×30), fonte encolhe para caber, tween anterior é morto;
  - HUD inteiro recua (α→0) enquanto houver `Cinematic` na tela; segue redesenhando com o mundo pausado;
  - dicas de controle no topo central: telas 1–3 (mover/pular, golpes, esquiva/aparar, sequência, Esfera Solar,
    telegrafos, pausa) e 1ª vez de Anel, troca de Anel, Arma Nv. 2 (lançador) e Nv. 3 (no ar); teclas tiradas do
    InputMap no formato do último InputEvent (teclado ou controle); 4,2 s cada, encurtam quando o jogador usa as
    teclas; nunca pausam; `show_hint(segmentos)` público;
  - `spark_orb_arrived()` (sobe 1 a 1, pop 120 ms; segura a contagem automática enquanto os orbes voam);
    `restore_ring(i, origem)` + sinal `ring_restore_finished`; `detach_ring`/`restore_ring` tocam `Audio.ring_note`;
  - "Arma Nv. N" aparece ao lado dos losangos quando a arma sobe;
  - R21: faíscas/arma vão a α 0,6 após 4 s sem combate (inimigo vivo a 380 px, dano, golpe), voltam em 150 ms;
  - R22: abaixo de 25 % após dano, vinheta vermelho-escura α 0,12–0,18 a 0,9 Hz, no máximo 8 s por dano;
  - corrigido o "Invalid polygon data" da barra fantasma estreita (aparecia no log do CodexQA).
- `tools/ui_hud/` (sonda HudProbe + montage.py), `docs/pedidos/onda2_ui-hud.md`.

## 3. Capturas (em /home/user/caps/ui-hud/; antes = base, depois = este branch)
- `cmp_choices_s.png`: tela 68 com 3 opções e tela 10 com 2 — tudo dentro da tela, motivo do "Semente" escrito.
  Sonda: botões x 101..538, y 302..328, `fora_da_tela=0`; foco no 1º; ←/→ e controle funcionam.
- `cmp_a_s.png` (antes) × `cmp_d_s.png` (depois): legenda saiu de cima dos pés para a base; some na pausa e na morte
  (`crop_death.png`).
- `cmp_b_s.png` (antes) × `cmp_c_s.png` + `crop_bars.png` (depois): batalha final com 2 barras, FASE II no Rei,
  "refazendo-se" quando ele cai e o Colosso segue cheio.
- `cmp_e_s.png`: card do Athoth sem o HUD cortado pela tarja; toast fora da fileira de Anéis.
- `crop_hints.png`: dicas com teclado (A D / Espaço) e controle (X / Y), "Arma Nv. 2", gema voltando.
- `depois/respiro_calmo.png`, `depois/vida_baixa.png`: R21/R22 (sonda: α 1,00 → 0,60 após 5 s calmo; volta com dano).

## 4. Validação (`TIMEOUT=900 tools/validate.sh`, depois do merge da base)
```
Scripts        OK        19s  pass=0  code=0
ScriptCheck    OK         2s  pass=0  code=0
CodexQA        OK        16s  pass=53  code=0
AudioQA        OK        18s  pass=45  code=0
GnoseQA        OK        78s  pass=18  code=0
SaveQA         OK         3s  pass=41  code=0
PuppetQA       OK        10s  pass=0  code=0
HeroQA         OK         1s  pass=0  code=0
WaveQA         OK         2s  pass=0  code=0
TUDO VERDE
```
Antes do merge, com a máquina em carga ~56, o CodexQA reprovou às vezes por tempo (passos de `wait(1.0)` da
troca de cena) — o mesmo teste passava em rodadas seguidas sem mudança; tratei como instabilidade de carga.

## 5. O que NÃO ficou bom / não testado
- Feel não testado por humano: duração das dicas (4,2 s), posição no topo central e o recuo a 0,6 (R21).
- Com Legendas "G" e barra de chefe no ar, a faixa da legenda chega a y≈252, perto dos pés (242).
- O foco do controle PODE parar na opção bloqueada (de propósito, para ler o motivo); apertar nela não faz nada.
- Na batalha final, se a forma caída nunca for achada no FinalBattle, a barra "refazendo-se" enche por 14 s fixos.
- R22 sem som (falta `heartbeat` no catálogo — pedido ao Áudio). A vinheta no α da recomendação (0,12–0,18) quase não
  aparece na captura sobre o cenário escuro; se o João quiser mais leitura, subir para ~0,25.
- A caixa com escolhas fica mais alta mesmo quando não há motivo de bloqueio (espaço vazio na tela 10).
- A sonda (`hud_probe.gd`) depende de tempo real; sob xvfb lento os tempos absolutos variam.

## 6. Pedidos (em `docs/pedidos/onda2_ui-hud.md`)
spark_orb.gd chamar `spark_orb_arrived`; enemy.gd (opcional) `boss_phase(2, self)`; Encenação não tocar outra nota
por cima de detach/restore; Áudio criar `heartbeat`; final_battle "JUNTAS" → "juntas".
