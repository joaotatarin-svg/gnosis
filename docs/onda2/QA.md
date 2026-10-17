# Onda 2 — QA (branch `dir2/qa`)

Sou a continuação do agente derrubado às 06:05; ele não deixou commit nem diff (só `/home/user/caps/qa/test/s02*`).

## 1. Commits
d0b0dfd sondas portadas para Linux · 612ba60 base das regressões + B1 · d093488 A1–A5 · 97c101b A6, R1, R3 ·
9f61329 R10 + `run_all.sh` · 489ccaa `.uid` · d9e6b57 UiProbe/MiscProbe atualizadas · c97b754 achados do revisor
(A1 conforme a especificação, A3 só por `boss_bars()`, esperas em quadros) · 89ef156 QA_UX.md · 40ad2e0 QA_UX_BUGS passada 2.

## 2. O que mudou
- `tools/qa_ux/run_all.sh`: Linux (`godot` no PATH), `RENDER=headless|xvfb|window`, `RESUMO.txt` com TOTAL; não conta "resources still in use at exit".
- `tools/qa_ux/{run,ui,pad,misc}_probe.gd`: não tiram foto no headless (antes davam `ERROR` do renderizador dummy). A RunProbe conta a barra de chefe do HUD novo. UiProbe: com 0 faíscas apertava Enter em "Voltar ao jogo" e travava (`SCRIPT ERROR`). MiscProbe: lia campos do HUD antigo.
- `tools/regressao/`: `Reg.tscn` + `reg_runner.gd` + `reg_base.gd` (veredito `REG|ID|PASS/FAIL/BROKEN`, esperas em quadros, modo `autoteste`), um teste por bug (`reg_b1, a1…a6, r1, r3, r10`), `run_all.sh` (tabela; código 0 só com tudo PASS).
- `docs/QA_UX.md` (seção Linux + regressão), `docs/QA_UX_BUGS.md` (passada 2 com a tabela bug→teste→estado).

## 3. Capturas e o que provam
- `/home/user/caps/qa/run_x2/s68_arrive.png`: Rei na tela, barra "O Colosso Oco — a Verdade" (A3). A legenda cobre os pés do Rei (M1).
- `/home/user/caps/qa/ui/ui09_loja_pela_pausa.png`: loja nova (preço e itens apagados); foco em "Voltar ao jogo" (A1 ainda fora da especificação).
- `/home/user/caps/qa/ui/ui25_Gallery_navegado.png`: os nomes do Bestiário agora quebram de linha (L2 resolvido).
- Pranchas: `/home/user/caps/qa/pranchas/` (telas 1–13), `/home/user/caps/qa/pranchas_chefes/prancha_19-68.png`.
- Não fiz "antes/depois": não mudei o jogo.

## Baseline (integracao/onda1)
RunProbe headless nas 68 telas: **68/68 avançam**, 0 `BUG?`, 0 `SCRIPT ERROR` (`/home/user/caps/qa/run_h/RESUMO.txt`). Em xvfb rodei 21 telas, todas avançam.

## Regressão (2 rodadas idênticas: `/home/user/caps/qa/reg_tab3.txt` = `reg_tab4.txt`)
```
B1   FAIL  6/6   A1  FAIL 2/8   A2  PASS 0/4   A3  FAIL 6/9   A4  FAIL 3/3
A5   FAIL  4/8   A6  FAIL 1/3   R1  FAIL 6/6   R3  FAIL 3/4   R10 FAIL 3/5     PASS: 1/10
```
- **A2 passa:** já corrigido na onda 1 (a legenda some quando a árvore está pausada). O teste fica como guarda.
- **Parcialmente corrigidos:** A1 (falta só o foco no 1º item) e A6 (o estouro sumiu; falta o motivo visível do "Semente").
- **B1 autoteste** (o teste adiciona A/B ao InputMap): PASS 6/6, ou seja, o teste consegue passar. Nos outros testes não há autoteste; não provei que passam depois da correção.

## 4. Validação (`tools/validate.sh`, depois do último commit)
```
Scripts OK · ScriptCheck OK · CodexQA FALHOU (diretório de save independente — falso conhecido) ·
AudioQA FALHOU (duck — bug conhecido do Áudio) · GnoseQA OK · SaveQA OK · PuppetQA OK · HeroQA OK · WaveQA OK
```
É igual à base, nada piorou.

## 5. O que NÃO ficou bom / não deu tempo
- O xvfb roda a 1–2 fps nesta máquina compartilhada, por isso a passada com PNG ficou parcial (21 de 68 telas). Nessa velocidade a UiProbe registrou um "checkpoint errado" que no headless não acontece: é efeito do fps baixo.
- A3 depende do contrato `hud.boss_bars()` (o ui-hud está criando). Enquanto ele não existir, o teste falha com "contrato ausente".
- R3 corta o `save.json` principal, então só passa quem lê uma cópia de segurança no load. Gravar em tmp e renomear sem `.bak` não passa, e isso é de propósito.
- R1 cobre só a tela 10 (cenários a/b). As telas 1 e 64 (a Sophia morta avança) ficaram de fora porque a regra certa é decisão de design.
- Não rodei as sondas de `tools/revisao/` (não são minhas).

## 6. Pedidos
- **ui-hud:** expor `boss_bars() -> Array` de `{node, ratio, phase}` (A3) e mostrar o motivo do "Semente" fora do tooltip (A6).
- **ui-menus:** foco no 1º item da loja também com 0 faíscas (A1). B voltar em Crônicas, Ateliê, Opções e Bestiário (L1).
- **Técnico/UI:** A/B em `ui_accept`/`ui_cancel` (B1). Save com .bak lido no load, também nas Crônicas (R3).
- **Combate:** morte no ar e anim "dead" (A4). Um desfecho por tela (R1). Fluxo de morte respeitando o PauseStack e esperas em quadros (R10).
- **Dono da câmera (`camera_shake.gd`):** a antecipação de ±90 px não pode passar dos limites (A5).
