# R4 (29/10/2026) — motor escolhido pelo João no A/B: Kokoro pt-BR (pronúncia e melodia brasileiras) + conversão de
# timbre para a voz fixa de cada personagem. Conversor por personagem: ChatterboxVC (opção 2, padrão) ou OpenVoice v2
# (opção 3) quando o ChatterboxVC escurece o "s" (vira chiado) — medido em `base_mede.py`.
# Tudo offline, nada toca no PC. Licenças: Kokoro Apache-2.0; chatterbox MIT; OpenVoice v2 MIT; alvos de timbre =
# vozes PROJETADAS no Qwen3-TTS (Apache-2.0, sintéticas, ninguém clonado).
import os, re, json
W = "C:/gnosis-wt/_caps/dublagem/r4_limiar2/"
R3 = "C:/gnosis-wt/_caps/dublagem/r3_ptbr/refs_br/"
R2 = "C:/gnosis-wt/dublagem/tools/voice/r2/refs/"
DIAG = "Você sabe que a gente precisa de tempo de verdade. Hoje à noite, todos os dias parecem iguais, e as pedras do monte não dizem nada."
# voz-base: (kokoro, velocidade base, alvo de timbre, frase de referência)
VOZES = {
	"sophia":     ("pf_dora", 1.00, R3 + "sophia_s43.wav", "Eu não lembro do meu nome. Lembro de cinza na boca, e de alguém chorando. Talvez fosse eu. Tanto faz. Agora eu vou subir, de verdade."),
	"demiurgo":   ("pm_santa", 0.90, R3 + "demiurgo_sonda_s44.wav", "Calma, pequena faísca. Eu tô aqui, sempre estive. Tudo o que você perdeu, eu guardei pra você. Vem comigo. Não precisa ter medo."),
	"narrador":   ("pm_alex", 0.90, R2 + "narrador_ref_24.wav", "Houve um tempo antes do tempo. A luz ainda não tinha nome, e ninguém precisava lembrar de nada. Depois veio a queda."),
	"athoth":     ("pm_alex", 0.80, R2 + "athoth_ref_24.wav", "Devagar. Ninguém precisa de você agora. Fecha os olhos, o mundo pode esperar. Eu fico acordado por você."),
	"harmas":     ("pm_santa", 0.88, R2 + "harmas_ref_24.wav", "Ah, que cheiro bom tem a sua saudade. Me dá. Só um pouquinho. Eu guardo tudo, bem quentinho, aqui dentro de mim."),
	"galila":     ("pm_alex", 0.95, R2 + "galila_ref_24.wav", "Consta nos autos. Cada coisa no seu lugar, cada elo na sua corrente. Fora da lei, nada fica de pé. Nada, de verdade."),
	"yabel":      ("pm_alex", 0.80, R2 + "yabel_ref_24.wav", "Faz muito tempo que eu não escuto a minha própria voz. Ela dói. Mas eu lembro de uma resposta."),
	"belias":     ("pm_santa", 0.85, R2 + "belias_ref_24.wav", "Tudo apodrece, sabe? A semente, a raiz, a mão que planta. Eu vi. Não adianta correr. A terra espera por todos nós."),
	"armupiel":   ("pm_santa", 0.85, R2 + "armupiel_ref_24.wav", "Curvem-se diante da Coroa! Eu sou o fim de todas as escadas, e mesmo assim, ninguém sobe pra me ver."),
	"soter":      ("pm_alex", 0.90, R2 + "soter_ref_24.wav", "Senta um pouco, Portadora. O caminho não foge. Quem anda com pressa no escuro só tropeça mais depressa, sabia?"),
	"velkar":     ("pm_santa", 0.90, R2 + "velkar_ref_24.wav", "Eu servi. Por eras. Achei que era lealdade. Era só medo. Agora não sobra nada de mim, só isto."),
	"adormecida": ("pf_dora", 0.95, R2 + "adormecida_ref_24.wav", "Onde eu tava? Eu sonhei com uma janela, e com um rio. Parecia de verdade. Você também viu?"),
	"adormecido": ("pm_alex", 0.95, R2 + "adormecido_ref_24.wav", "Que frio. Faz quanto tempo que eu tô deitado aqui? Ninguém veio me chamar. Ninguém."),
}
# quem usa qual voz-base (falante do jogo -> voz)
FALANTE_VOZ = {"Sophia": "sophia", "Narradora": "sophia", "A Voz": "demiurgo", "Voz": "demiurgo", "O Rei": "demiurgo", "Rei": "demiurgo",
	"Yaldabaoth": "demiurgo", "O Cego": "demiurgo", "Astaphaios": "sophia", "Uma voz nos Anéis": "sophia", "Estela": "narrador"}
ELENCO = W + "elenco_r4.json"   # escrito por base_mede.py: {voz: {"conv": "cbx"|"ov", ...}}


def elenco():
	return json.load(open(ELENCO, encoding="utf-8"))


# --- atuação: o texto vira PEDAÇOS só nas reticências -------------------------------------------
# Kokoro lê "..." como um som estranho ("tô-as") e erra palavra solta ("Ei.", "Tocar."): então só a reticência
# corta o texto (pausa de suspensão posta por nós); ". ? ! :" ficam com o próprio modelo, que dá a entonação.
# Trecho que começa com "#" é FONEMA cru (ex.: "#ʃːːː." para o "Shh", que o espeak soletra).
PAUSA_RETIC = 0.45


def pedacos(texto):
	t = re.sub(r"[\"“”()]", "", texto.replace("…", "...").replace("—", ","))
	partes = [x.strip() for x in t.split("...")]
	out = []
	for k, s in enumerate(partes):
		if not s:
			continue
		if k < len(partes) - 1 and not re.search(r"[.?!:,]$", s):
			s = s + ","   # suspensão: não fecha a frase
		out.append((s, PAUSA_RETIC))
	if out:
		out[-1] = (out[-1][0], 0.0)
	return out
