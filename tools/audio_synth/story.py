# -*- coding: utf-8 -*-
"""
SFX de roteiro (pedido do Roteiro, 17/10/2026) — cena "o Rei sai da névoa"
(tela 1). 100 % síntese (exceto a pedra do passo, Kenney CC0).

  fog_swell   névoa adensando: sopro grave crescente (~3 s)
  king_step   passo pesado e régio: metal + pedra (3 variações)
  mask_light  máscara acendendo: brilho tonal FRIO (~1 s)
  voice_merge a Voz se fundindo ao Rei: vozes espalhadas que convergem pro
              uníssono (~2 s, sem palavras)
  whisper     sussurro ininteligível: ruído em formantes, sílabas sem sentido
              (~1,5 s) — nenhuma voz real

Onda 2 (sons ★ do ROTEIRO §2, 100 % síntese):
  heartbeat     UMA batida lub-dub abafada (~0,7 s), como ouvida de DENTRO (sem
                agudo). Intro: o Audio toca 2 (cue `heartbeat`); HUD: 1 por pulso
  clap          cena B #4: duas palmas secas e lentas do Rei numa sala de pedra
                (~1,6 s)
  child_breath  cena D #3: respiração pequena (inspira–expira, trato vocal
                curto = formantes ~35 % acima do adulto), quase um soluço
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import SR, db
import magic as M


def fog_swell():
	d = 3.2
	n = M.n_(d)
	t = C.tvec(n)
	grow = (t / d) ** 1.6 * np.clip((d - t) / 0.5, 0, 1)
	breath = M.sweep_bp(C.noise(n, 500), 180, 900, 1.0) * grow
	hiss = C.lp(C.hp(C.noise(n, 501), 2500), 6000) * grow * 0.07
	sub = np.sin(C.osc_phase(36.7 * (1 + 0.04 * t / d), n)) * grow * 0.8
	low = C.lp(C.saw_bl(73.4 * (1 + 0.003 * np.sin(2 * np.pi * 0.3 * t)), n, 20), 300) * grow * 0.3
	o = np.stack([breath * 0.9 + sub + low, breath * 0.9 + sub + low], axis=1)
	o += np.stack([hiss, np.roll(hiss, 900)], axis=1)
	return C.reverb(o, rt60=3.0, wet=0.4, seed=502, lp_hz=4000, tail=False)


def king_step(var=0):
	d = 0.9
	o = M.buf(d)
	src = ["footstep_concrete_002.ogg", "footstep_concrete_004.ogg", "footstep_concrete_000.ogg"][var]
	stone = C.resample_pitch(C.trim_start(C.load(C.find(src)).astype(np.float64)), 0.62)
	M.put(o, C.lp(stone, 2500), 0, 0)
	M.put(o, M.tone(62 - 4 * var, 0.5, 0.002, 0.13, harm=((1, 1), (2, 0.3)), glide=-0.45), 0, -1)
	# armadura: placa de metal + elos (régio, pesado)
	M.put(o, C.lp(C.metal_clang([310, 345, 290][var], 0.5, seed=510 + var, decay=0.3), 4000), 0.012, -9, 0.2)
	r = C.rng(520 + var)
	for k in range(3):
		M.put(o, C.metal_clang(r.uniform(1800, 2600), 0.12, seed=530 + 3 * var + k, decay=0.04), 0.03 + 0.035 * k, -20, r.uniform(-0.4, 0.4))
	return M.finish_tail(o, 1.4, 0.25, lp=5000)


def mask_light():
	d = 1.3
	o = M.buf(d)
	# acender: sopro curto subindo
	M.put(o, M.sweep_bp(C.noise(M.n_(0.25), 540), 1500, 7000, 2.0) * C.env_swell(M.n_(0.25), 0.18, 0.05), 0, -8)
	# brilho frio: Si-Fá#-Si cristalinos, ataque lento, vibrato fino; sem graves
	for i, m in enumerate([83, 90, 95]):
		x = M.tone(M.note(m), 1.1, 0.12 + 0.04 * i, 0.4, harm=((1, 1), (2.32, 0.25), (4.25, 0.1)), vib=(6.5, 0.003))
		M.put(o, x, 0.03 * i, -4 - 3 * i, (-0.5, 0.5, 0)[i])
	M.put(o, M.glass(M.note(102), 0.6, 0.2, seed=541, bright=0.5), 0.1, -16)
	return M.shimmer(M.finish_tail(C.hp(o, 400), 1.6, 0.3, lp=12000), 0.25, 1.8)


def voice_merge():
	d = 2.2
	n = M.n_(d)
	t = C.tvec(n)
	o = np.zeros((n, 2))
	target = M.note(50)                    # Ré2/Ré3: Voz + Rei em uníssono
	r = C.rng(550)
	offsets = [-5, -3, -2, 2, 3, 6, 12, -12]
	conv = np.clip(t / 1.6, 0, 1)
	conv = conv * conv * (3 - 2 * conv)     # converge suave
	for i, semi in enumerate(offsets):
		start = target * 2 ** (semi / 12)
		end = target * (2 if semi == 12 else (0.5 if semi == -12 else 1.0))
		f = start + (end - start) * conv
		f *= 1 + 0.01 * (1 - conv) * np.sin(2 * np.pi * r.uniform(4, 7) * t)
		vow = ["a", "e", "i", "u", "a", "e", "o", "u"][i]
		x = C.voice(f, n, vow, shift=0.9 if semi < 0 else 1.0, vowel2="o", breath=0.15, seed=551 + i, nh=36)
		p = r.uniform(-0.9, 0.9) * (1 - conv)    # o espaço também converge pro centro
		a = (p + 1) * np.pi / 4
		o[:, 0] += x * np.cos(a)
		o[:, 1] += x * np.sin(a)
	e = np.clip(t / 0.3, 0, 1) * np.clip((d - t) / 0.35, 0, 1)
	o *= e[:, None] / len(offsets)
	return C.reverb(o, rt60=2.2, wet=0.35, seed=560, lp_hz=6000, tail=False)


def whisper():
	d = 1.6
	n = M.n_(d)
	o = np.zeros((n, 2))
	r = C.rng(570)
	at = 0.05
	k = 0
	while at < d - 0.2:
		dur = r.uniform(0.09, 0.17)
		m = M.n_(dur)
		tt = C.tvec(m)
		vow = r.choice(list(C.VOWELS.keys()))
		w = C.noise(m, 571 + k)
		syl = np.zeros(m)
		for (F, gdb, B) in C.VOWELS[vow]:
			syl += C.resonator(w, min(F * 1.1, SR * 0.4), max(2.0, F / B)) * db(gdb)
		syl *= np.sin(np.pi * tt / tt[-1]) ** 1.5
		if r.random() < 0.45:     # consoante sibilante (s/x)
			s = C.bp(C.noise(M.n_(0.05), 600 + k), 4000, 9000) * np.sin(np.pi * C.tvec(M.n_(0.05)) / 0.05)
			M.put(o, s, at, -10, r.uniform(-0.5, 0.5))
			at += 0.04
		M.put(o, syl, at, r.uniform(-4, 0), r.uniform(-0.6, 0.6))
		at += dur + r.uniform(0.0, 0.05)
		k += 1
	o = C.hp(o, 250)
	return C.reverb(o, rt60=0.9, wet=0.3, seed=580, lp_hz=9000, tail=False)


def _thump(f0, dur, seed):
	"""Uma batida: tom grave com queda de altura + corpo de ruído grave."""
	n = M.n_(dur)
	t = C.tvec(n)
	body = M.tone(f0, dur, 0.008, 0.075, harm=((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.12)), glide=-0.3)
	# "toque" de 120–350 Hz: sem ele a batida some em caixinha de notebook/TV
	thud = C.bp(C.noise(n, seed), 110, 350) * C.env_ad(n, 0.003, 0.03) * 1.4
	return C.lp(body + thud, 450) * np.clip(t / 0.006, 0, 1)


def heartbeat():
	"""UMA batida lub-dub (~0,7 s). Onda 2b: o HUD toca uma por pulso da vinheta
	de vida baixa (R22, ~0,9 Hz) e a intro (cue `heartbeat`) toca duas, 1,1 s
	uma da outra (o Audio agenda a 2ª) — antes o arquivo tinha as duas batidas
	coladas e não servia ao HUD."""
	d = 0.75
	o = M.buf(d)
	M.put(o, _thump(66, 0.32, 600), 0.02, 0)        # "lub"
	M.put(o, _thump(80, 0.24, 610), 0.28, -5)       # "dub", mais curto
	# pressão/sangue: ruído grave pulsando junto, quase subsônico
	n = len(o)
	t = C.tvec(n)
	puls = np.exp(-((t - 0.14) / 0.12) ** 2)
	M.put(o, C.lp(C.noise(n, 620), 90) * puls * 0.35, 0, -6)
	return C.reverb(C.lp(o, 700), rt60=0.5, wet=0.12, seed=621, lp_hz=800, tail=False)


def _clap_hit(seed):
	"""Palma: 3 microestalos (os dedos) + estouro de ruído 900–2,5 kHz."""
	n = M.n_(0.12)
	r = C.rng(seed)
	x = np.zeros(n)
	for k in range(3):
		at = int((k * 0.007 + r.uniform(0, 0.002)) * C.SR)
		m = M.n_(0.03)
		burst = C.noise(m, seed + k) * C.env_ad(m, 0.0005, 0.006)
		x[at:at + m] += burst[:n - at] * (0.7 + 0.3 * k)
	m = n - int(0.018 * C.SR)
	tail = C.noise(m, seed + 7) * C.env_ad(m, 0.001, 0.028)
	x[int(0.018 * C.SR):] += tail
	return C.bp(x, 850, 2600) + C.bp(x, 300, 600) * 0.25


def clap():
	d = 1.0
	o = M.buf(d)
	M.put(o, _clap_hit(640), 0.0, 0, -0.08)
	M.put(o, _clap_hit(650), 0.78, -1, 0.08)      # a 2ª um pouco depois: lenta, irônica
	# sala de pedra (o Limiar): reverb curto e escuro, cauda longa e baixa
	return C.reverb(o, rt60=1.6, wet=0.28, seed=660, lp_hz=5000, tail=True)


def child_breath():
	d = 2.3
	n = M.n_(d)
	t = C.tvec(n)
	o = np.zeros((n, 2))
	shift = 1.35                                   # trato vocal pequeno
	w = C.noise(n, 670)
	def breath_part(vowel, lo, hi, a, rel):
		x = np.zeros(n)
		for (F, gdb, B) in C.VOWELS[vowel]:
			# banda 4× mais larga que a da vogal cantada: sopro, não apito
			x += C.resonator(w, min(F * shift, C.SR * 0.4), max(1.5, F * shift / (4.0 * B))) * db(gdb)
		e = np.clip((t - lo) / a, 0, 1) * np.clip((hi - t) / rel, 0, 1)
		return C.hp(x, 300) * e ** 1.5
	inhale = breath_part("i", 0.05, 0.85, 0.45, 0.12)            # inspira curto, agudo
	exhale = breath_part("a", 1.0, 2.2, 0.08, 0.9)               # expira longo, cansado
	# um fio de voz no fim da expiração (quase um "mm" de criança) — bem baixo
	f0 = 330 * (1 - 0.06 * np.clip((t - 1.05) / 0.9, 0, 1))
	hum = C.voice(f0, n, "u", shift=shift, breath=0.3, seed=671, nh=20, vib=(5.5, 0.01))
	he = np.clip((t - 1.05) / 0.25, 0, 1) * np.clip((1.75 - t) / 0.5, 0, 1)
	o += C.pan(inhale * 0.9, -0.05)
	o += C.pan(exhale + hum * he * 0.05, 0.05)
	return C.reverb(o, rt60=1.2, wet=0.2, seed=672, lp_hz=7000, tail=False)


SOUNDS = {
	"fog_swell": ("story_soft", [fog_swell]),
	"king_step": ("story", [lambda v=v: king_step(v) for v in range(3)]),
	"mask_light": ("story_soft", [mask_light]),
	"voice_merge": ("story", [voice_merge]),
	"whisper": ("story_whisper", [whisper]),
	"heartbeat": ("story_heart", [heartbeat]),
	"clap": ("story", [clap]),
	"child_breath": ("story_whisper", [child_breath]),
}
