# Pedidos do diretor de UI (Onda 3, branch `dir3/ui3`)

## 1. ENCENAÇÃO3 — campo `mood` nas falas (PUBLICADO CEDO; já funciona em `dir3/ui3`)
A `DialogueBox` (e a legenda de caminhada) aceita um campo OPCIONAL `mood` em cada fala, que
escolhe o retrato por emoção. Sem `mood`, vale o neutro do falante. Nada quebra se o campo
faltar ou vier com valor desconhecido (cai no neutro).

```gdscript
{"speaker": "Sophia", "text": "...Não.", "mood": "choque"}
{"speaker": "Yaldabaoth", "text": "Agora vês.", "mood": "revelado"}
{"speaker": "Soter", "text": "Senta.", "mood": "triste"}
```

| Falante (o nome CONTÉM) | `mood` aceitos | neutro (sem mood) |
|---|---|---|
| `Sophia` | `neutra` · `determinada` · `triste` · `raiva` · `medo` · `ternura` · `choque` · `serena` | `neutra` |
| `Rei` / `Yaldabaoth` | `regio` · `ironico` · `revelado` · `quebrado` | `regio` |
| `Soter` | `sereno` · `triste` | `sereno` |
| `Velkar` | `elmo` · `arrependido` | `elmo` |

- Aceita acento e o outro gênero (`régio`, `irônico`, `sereno`/`serena`) e os nomes em inglês do
  manifesto do GPT (`shock`, `regal`, `ironic`, `revealed`, `broken`, `repentant`, `fear`, `tender`...).
- Arcontes, A Voz, Estela e desconhecidos ignoram o campo (retrato único ou nenhum).
- Arquivos: `assets/ui/portraits/<falante>_<mood>.png` (128×128, máscara circular), gerados por
  `python -I assets/ui/build_mood_portraits.py` a partir de `artes/gpt/portraits/`.
- Sugestão de uso (Roteiro/Narrativa Emocional): Sophia `choque` no "...Não." do roubo (cena B),
  `raiva` na tentação, `ternura`/`serena` na anagnórise e nos finais; Rei `ironico` nas falas de
  escárnio, `revelado` quando a máscara racha/cai, `quebrado` na queda final; Soter `triste` na
  despedida; Velkar `arrependido` quando ele baixa a cabeça.

## 2. ENCENAÇÃO3 — `Staging.is_active() -> bool` (opcional)
O HUD agora esconde as dicas de controle, o combo e as faíscas/arma enquanto houver CENA no ar
(QA C2). Hoje ele detecta: `DialogueBox` aberta OU `Cinematic` na raiz — isso cobre as cenas 64/68.
Se alguma encenação rodar SEM caixa aberta (câmera/efeito com o mundo andando), exponham em
`staging.gd`:
```gdscript
## Há cena dirigida no ar (entre play() e o fim do _on_finished)?
func is_active() -> bool:
	return _scene != ""
```
O HUD já chama `is_active()` por `has_method` (compila sem ele).

## 3. COMBATE3 — número de dano congelado (QA C1)
Não é da UI (`scripts/fx/damage_number.gd`). O HUD já some com as dicas na cena; o número de dano
continua parado na tela durante o diálogo. Sugestão: o número ignora a pausa
(`process_mode = ALWAYS` só para o fade) ou some quando `DialogueBox`/`Cinematic` abre.

## 4. TÉCNICO3 — nada obrigatório
A legenda de caminhada mudou de lugar (agora no TOPO, abaixo das dicas). Se alguma sonda de
outra área conferia a legenda "acima da barra do chefe" (`boss_area_top`), ela continua existindo
no HUD, mas a legenda não a usa mais; o retângulo atual sai em `CaptionBar.band_rect()`.
