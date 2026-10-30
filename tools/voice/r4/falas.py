# Falas da AMOSTRA_LIMIAR.md (v2 + v3 de C2/C5) para o lote "limiar-2".
# (num, falante NO JOGO (vai no id), texto_pt EXATO do jogo (vai no id), quem atua, onde, modo, vel, nota de atuação)
# id = sha1(falante + "|" + texto_pt)[:12]  (CONTRATO_AUDIO §2). Cards do prólogo: falante "card", " / " do roteiro = "\n".
# Rubrica sem falante (D1) = "". Rubricas "( … )" ficam no texto do id e NÃO são faladas (exceto pensamento/rubrica narrada).
import os, json
V, R, S = "A Voz", "O Rei", "Sophia"
F = [
 ("P1", "card", "No começo havia uma Luz tão cheia que transbordava.\nCada gota que caía virava alguém.", "Narradora", "card", "narracao", 0.93, "imagem concreta, sem pressa"),
 ("P2", "card", "Uma das gotas quis ver a Fonte sozinha, sem pedir licença.\nDo que ela fez, nasceu um filho.\nEla teve vergonha. E o escondeu.", "Narradora", "card", "narracao", 0.92, "fala da gota como de alguém que conheceu"),
 ("P3", "card", "O filho cresceu no escuro, certo de que era o único.\nFez um mundo e pôs um rei em cada andar.\nTodos eles mentem.\n\nNo fundo das cinzas, alguém acaba de sentir dor.", "Narradora", "card", "narracao", 0.92, "'Todos eles mentem' isolado"),
 ("D1", "", "(Escuro. Um coração batendo. Depois, gosto de cinza.)", "Narradora", "cena", "narracao", 0.90, "rubrica narrada, baixa"),
 ("D2", V, "Ei. Ei! Acorda. ...Isso, devagar. Eu tô aqui.", "Voz", "cena", "fala", 0.95, "no ouvido, cuidado"),
 ("D3", S, "Onde eu tô? ...Pior: quem sou eu?", "Sophia", "leg", "fala", 1.02, "seca, ri de si"),
 ("D4", V, "Uma pergunta por vez. Primeiro, ande. Pra direita, de preferência.", "Voz", "leg", "fala", 0.98, "guia bem-humorada"),
 ("D5", V, "Essas cinzas eram gente. A sua gente.", "Voz", "leg", "fala", 0.92, "doce (a mentira)"),
 ("D6", S, "Não lembro de nenhum rosto. Isso devia doer mais, não?", "Sophia", "leg", "fala", 1.0, "dúvida"),
 ("D7", V, "Uma pedra escrita. Leia, se quiser. Só não acredite em tudo.", "Voz", "leg", "fala", 0.98, ""),
 ("D8", S, "\"Antes de tudo, havia o Um.\" Um o quê? Um alguém?", "Sophia", "leg", "fala", 1.02, "lê, depois ironiza"),
 ("D9", V, "A névoa está engrossando. Fica perto de mim.", "Voz", "leg", "fala", 0.95, "tensão"),
 ("D10", S, "Você é uma voz. Perto como?", "Sophia", "leg", "fala", 1.04, "humor"),
 ("D11", V, "...Perto da minha voz, então.", "Voz", "leg", "fala", 0.90, "hesita antes"),
 ("A1", V, "Vem alguém. Calma, esse eu conheço. Muita pose, joelho fraco.", "Voz", "cena", "fala", 0.98, "pista do joelho"),
 ("A2", R, "Ah. Acordou. Nós estávamos esperando.", "Rei", "cena", "fala", 0.86, "régio, contido"),
 ("A3", S, "Nós quem? Só tem você aí.", "Sophia", "cena", "fala", 1.04, ""),
 ("A4", R, "Rei fala no plural. Somos importantes demais para o singular.", "Rei", "cena", "fala", 0.88, "irônico, sério"),
 ("A5", R, "Lei do Limiar: só passa quem nos tocar com a própria luz.", "Rei", "cena", "fala", 0.86, "régio"),
 ("A6", S, "Tocar. Com o cajado serve?", "Sophia", "cena", "fala", 1.02, ""),
 ("A7", R, "Tente. E não tema: um rei jamais se curva.", "Rei", "cena", "fala", 0.86, "A MENTIRA, séria"),
 ("C1", S, "Amarelo... da próxima, eu aparo.", "Sophia", "combate", "fala", 1.08, "luta"),
 ("C2", R, "Nossa luz rasteja. Pule.", "Rei", "combate", "fala", 0.95, "gabolice"),
 ("C3", R, "Esta mão, nem você apara.", "Rei", "combate", "fala", 0.95, ""),
 ("C4", R, "Chega de cortesia. Olhe o chão.", "Rei", "combate", "fala", 0.98, "fase 2"),
 ("C5", R, "Sempre atrás de você.", "Rei", "combate", "fala", 0.86, "quase sussurro (ameaça)"),
 ("C6a", S, "Ele se curvou? Jamais, né?", "Sophia", "combate", "fala", 1.05, "pergunta"),
 ("C6b", S, "Jamais, né?", "Sophia", "combate", "fala", 0.98, "baixo, com prazer"),
 ("F1a", R, "Aquela reverência de antes? Foi proposital.", "Rei", "cena", "fala", 0.88, "se contradiz com dignidade"),
 ("F2a", S, "Claro. Superproposital.", "Sophia", "cena", "fala", 1.0, ""),
 ("F1b", R, "Nós não estamos ajoelhados. Estamos... descansando.", "Rei", "cena", "fala", 0.88, ""),
 ("F2b", S, "De joelhos. Na minha frente. Jamais, né?", "Sophia", "cena", "fala", 1.0, ""),
 ("F3", R, "(a máscara racha) Sua luz... é maior do que nós lembrávamos.", "Rei", "cena", "fala", 0.84, "quebrado"),
 ("F4", S, "Lembravam? Eu acordei agora há pouco.", "Sophia", "cena", "fala", 1.02, ""),
 ("F5", R, "Pergunte aos sete. Eles lembram por nós.", "Rei", "cena", "fala", 0.84, "baixo, dá medo"),
 ("F6", V, "Sentiu? O selo dele rachou. Sete tronos acabaram de acordar.", "Voz", "cena", "fala", 0.97, ""),
 ("F7", S, "Isso é bom ou é muito ruim?", "Sophia", "cena", "fala", 1.05, "respiro"),
 ("F8", V, "Sete Arcontes, um por andar. Cada um guarda um Anel.", "Voz", "cena", "fala", 0.96, ""),
 ("F9", S, "E se eu juntar os sete?", "Sophia", "cena", "fala", 1.0, ""),
 ("F10", V, "A gente quebra esta prisão. Você e eu.", "Voz", "cena", "fala", 0.94, "afeto"),
 ("F11", S, "(Lembravam. Quem lembra de alguém que acabou de acordar?)", "Sophia", "cena", "pensamento", 0.96, "pensa"),
 ("T1", V, "O Torpor. Aqui os mortos ainda não sabem que morreram.", "Voz", "leg", "fala", 0.95, ""),
 ("T2", V, "Não odeie quem dorme. Até agora há pouco, você dormia.", "Voz", "leg", "fala", 0.95, ""),
 ("T3", S, "Confesso: deitar parece ótimo. ...Não vou.", "Sophia", "leg", "fala", 1.0, ""),
 ("T4", S, "(Dormir é esquecer de onde veio. Acordar dói porque é lembrar.)", "Sophia", "leg", "pensamento", 0.96, "pensa"),
 ("M1", V, "Shh. Já passou. Ele bate forte pra quem fala tão bonito.", "Voz", "cena", "fala", 0.95, "consolo + humor"),
 ("M2", V, "Levanta. E repara no tal rei que jamais se curva.", "Voz", "cena", "fala", 0.97, "dica"),
 ("G1", V, "Isso é uma faísca. Luz presa no barro. Agora é sua.", "Voz", "leg", "fala", 0.97, ""),
]
# o que o TTS LÊ quando difere do falado (o ASR confere com "said"): "|" = trechos com pausa curta; "#" = fonema cru
TTS = {"F2a": "Claro. Super proposital.", "M1": "#ʃːːː.|Já passou. Ele bate forte pra quem fala tão bonito."}
# o que o ASR deve ouvir quando a grafia junta palavras (o corte de cauda casa pela última palavra)
SAID = {"F2a": "Claro. Super proposital."}
FX = {"Narradora": "narradora", "Voz": "a_voz", "Rei": "legiao1", "Sophia": "sophia"}
VOZ = {"Narradora": "sophia", "Voz": "demiurgo", "Rei": "demiurgo", "Sophia": "sophia"}
import re, hashlib
def falado(texto, modo):
	t = texto
	if modo not in ("pensamento", "narracao"):
		t = re.sub(r"^\([^)]*\)\s*", "", t)   # rubrica de ação no começo não é falada
	return re.sub(r"\s*\n+\s*", " ", t.replace("(", "").replace(")", "")).strip()
out = []
for num, fal, txt, quem, onde, modo, vel, nota in F:
	out.append({"num": num, "falante": fal, "texto_pt": txt, "id": hashlib.sha1((fal + "|" + txt).encode("utf-8")).hexdigest()[:12],
		"quem": quem, "voz": VOZ[quem], "fx": FX[quem], "onde": onde, "modo": modo, "vel": vel, "nota": nota, "said": SAID.get(num, falado(txt, modo)), "tts": TTS.get(num, falado(txt, modo))})
W = "C:/gnosis-wt/_caps/dublagem/r4_limiar2/"
json.dump(out, open(W + "falas_limiar2.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(out), len({o["id"] for o in out}))
for o in out[:4] + [x for x in out if x["num"] in ("F3", "F11", "D8")]:
	print(o["num"], o["id"], repr(o["said"]))
