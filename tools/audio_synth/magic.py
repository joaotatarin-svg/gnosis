# -*- coding: utf-8 -*-
"""
MAGIAS, PROJÉTEIS E FAÍSCAS do GNOSIS — 100 % sintetizados (sem sample).

Refeitos do zero (17/10/2026) após o retorno do João: "esses sons de ataque
mágico e orbe caindo tá bem paia". Estrutura de toda magia:
  ATAQUE (transiente curto) → CORPO tonal (coro com formantes ou sino/metal
  afinado na NOTA do Anel) → CAUDA (reverb + brilho/shimmer).

Cada Anel tem uma nota (as 7 esferas, Ré → Dó) e um timbre do seu Arconte:
  Torpor  Ré   sonolento, abafado, sinos de caixinha que "caem de sono"
  Fome    Mi   sucção que sobe → duas mordidas mastigadas, rosnado
  Corrente Fá  elos de ferro chacoalhando → cadeado metálico afinado
  Silêncio Sol sopro que cresce e CORTA o som (silêncio de verdade) → zumbido
  Espelho Lá   cristal + o mesmo som ao contrário (eco invertido, lado oposto)
  Praga   Si♭  bolhas orgânicas, gosma, enxame miúdo
  Coroa   Dó   coro grave majestoso + estrondo + sinos
  Esfera Solar (inata): Mi maior morno, brilho que se espalha.

Cada função recebe `opt` (0, 1, 2) = 3 opções de mistura/timbre. O
build_sfx.py usa a escolhida em CHOICE; `python magic.py` grava TODAS as
opções em _caps/audio/opcoes/ pra comparar de ouvido.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import SR, db

# opção escolhida por som (0/1/2). Ver docs/AUDIO.md §Magias.
CHOICE = {
	"cast_solar": 1, "cast_torpor": 1, "cast_fome": 1, "cast_corrente": 1, "cast_silencio": 1,
	"cast_espelho": 1, "cast_praga": 1, "cast_coroa": 1, "cast_fail": 1,
	"proj_fire": 1, "proj_hit": 1, "nova": 1, "spark": 1,
}


def note(m):
	return 440.0 * 2 ** ((m - 69) / 12)


def n_(s):
	return int(s * SR)


def buf(dur):
	return np.zeros((n_(dur), 2))


def put(dst, x, at, g=0.0, p=0.0):
	"""Soma (mono → pan p) em dst estéreo. Toda camada ganha fade de 5 ms no
	fim — camada que termina "no meio" do decaimento vira clique."""
	x = C.fade(x, 0, 0.005)
	if x.ndim == 1:
		x = C.pan(x, p)
	C.place(dst, x, at, g)
	return dst


def env(n, a, d, hold=0.0):
	return C.env_ad(n, a, d, hold)


def sweep_bp(x, f0, f1, q=2.0, block=128):
	from scipy import signal
	out = np.zeros(len(x))
	zi = np.zeros(2)
	for i in range(0, len(x), block):
		fr = min(f0 * (f1 / f0) ** (i / max(1, len(x) - 1)), SR * 0.45)
		b, a = signal.iirpeak(fr, q, fs=SR)
		out[i:i + block], zi = signal.lfilter(b, a, x[i:i + block], zi=zi)
	return out


def tone(f, dur, a=0.004, d=0.3, harm=((1, 1.0),), glide=0.0, vib=(0, 0)):
	"""Tom aditivo com envelope AD; glide = fração de variação de tom no fim."""
	n = n_(dur)
	t = C.tvec(n)
	fc = f * (1 + glide * t / max(dur, 1e-3))
	if vib[1]:
		fc = fc * (1 + vib[1] * np.sin(2 * np.pi * vib[0] * t))
	ph = C.osc_phase(fc, n)
	x = sum(g * np.sin(k * ph) for k, g in harm if f * k < SR * 0.45)
	return x * env(n, a, d)


def glass(f, dur, decay=0.5, seed=0, bright=1.0):
	"""Cristal: parciais de taça (1, 2.32, 4.25, 6.63) — puro, sem ruído."""
	parts = [(1.0, 1.0, 1.0), (2.32, 0.45 * bright, 0.55), (4.25, 0.25 * bright, 0.35), (6.63, 0.12 * bright, 0.25)]
	return C.bell(f, dur, decay, seed=seed, bright=1.0, partials=parts) * 1.0


def shimmer(x_st, amount=0.3, rt=1.2, seed=3):
	"""Cauda brilhante: reverb do sinal passado num passa-altas, um pouco mais longo."""
	h = C.hp(x_st, 2500)
	w = C.reverb(h, rt60=rt, wet=1.0, predelay=0.02, seed=seed, lp_hz=12000, tail=True)
	out = np.zeros((max(len(w), len(x_st)), 2))
	out[:len(x_st)] += x_st
	out[:len(w)] += w * amount
	return out


def sat(x, d=2.0):
	return np.tanh(x * d) / np.tanh(d)


def choir(notes, dur, vowel="a", shift=1.0, attack=0.1, release=0.5, seed=0, vib=0.006, voices=2, vowel2=None):
	r = C.rng(seed)
	out = np.zeros((n_(dur), 2))
	for i, f in enumerate(notes):
		for v in range(voices):
			x = C.voice(f * (1 + r.uniform(-0.004, 0.004)), n_(dur), vowel, shift=shift, vowel2=vowel2,
				breath=0.12, seed=seed + 9 * i + v, nh=36, vib=(r.uniform(4.8, 5.8), vib))
			out += C.pan(x, r.uniform(-0.6, 0.6))
	t = C.tvec(n_(dur))
	e = np.clip(t / attack, 0, 1) * np.clip((dur - t) / release, 0, 1)
	return out * e[:, None] / (len(notes) * voices)


def finish_tail(x, rt=1.0, wet=0.25, seed=7, lp=7000):
	return C.reverb(x, rt60=rt, wet=wet, predelay=0.012, seed=seed, lp_hz=lp, tail=True)


# ----------------------------------------------------------------------------
# Esfera Solar (inata): brilho morno que se espalha
# ----------------------------------------------------------------------------

def cast_solar(opt=1):
	d = 0.9
	o = buf(d)
	# ataque: "fwump" de luz (ruído varrendo pra cima)
	w = sweep_bp(C.noise(n_(0.18), 1), 500, 4000, 1.5) * env(n_(0.18), 0.01, 0.06)
	put(o, w, 0, -4)
	# corpo: Mi maior morno (pad aditivo) — opções: pad / coro / sinos
	chord = [note(64), note(68), note(71), note(76)]
	if opt in (0, 1):
		for i, f in enumerate(chord):
			x = tone(f, 0.7, 0.015, 0.22, harm=((1, 1), (2, 0.35), (3, 0.15), (4, 0.06)))
			put(o, x, 0.01, -6, (-0.5, -0.15, 0.15, 0.5)[i])
	if opt in (1, 2):
		for i, m in enumerate([76, 80, 83, 88, 92]):      # faíscas subindo
			put(o, glass(note(m), 0.5, 0.18, seed=10 + i, bright=0.6), 0.02 + 0.035 * i, -9 - i, (-0.6, 0.6)[i % 2])
	if opt == 2:
		put(o, choir([note(52), note(59), note(64)], 0.7, "a", attack=0.03, release=0.4, seed=12).mean(axis=1), 0, -2)
	# calor grave
	put(o, tone(note(40), 0.5, 0.01, 0.12, harm=((1, 1), (2, 0.3))), 0, -10)
	return shimmer(finish_tail(o, 0.9, 0.22), 0.25)


# ----------------------------------------------------------------------------
# Anel do Torpor (Ré): sonolento, abafado
# ----------------------------------------------------------------------------

def cast_torpor(opt=1):
	d = 1.2
	o = buf(d)
	# ataque macio: sopro abafado
	puff = C.lp(C.noise(n_(0.35), 20), 1100) * C.env_swell(n_(0.35), 0.05, 0.1)
	put(o, puff, 0, -6)
	# sinos de caixinha que "caem de sono": Ré-Lá-Fá#-Ré, tom caindo, filtrados
	for i, m in enumerate([86, 81, 78, 74]):
		b = C.bell(note(m), 0.9, 0.45, seed=21 + i, bright=0.25)
		b = C.resample_pitch(b, 1.0 - 0.012 * i)                  # cada vez mais "lento"
		b = C.lp(b, 1700 if opt != 0 else 2600)
		put(o, b, 0.03 + 0.14 * i, -4 - 1.5 * i, (-0.4, 0.3, -0.2, 0.2)[i])
	# coro em "u" fechado, quase bocejo
	if opt in (1, 2):
		ch = choir([note(50), note(57)], 1.0, "u", shift=0.9, attack=0.15, release=0.6, seed=24, vib=0.004)
		t = C.tvec(len(ch))
		ch = C.lp(ch, 900) * (1 - 0.05 * t)[:, None]
		put(o, ch, 0.05, -1 if opt == 1 else 2)
	if opt == 2:     # bocejo descendente
		put(o, C.voice(note(50) * (1 - 0.12 * C.tvec(n_(0.8)) / 0.8), n_(0.8), "o", shift=0.85, vowel2="u", nh=30) * env(n_(0.8), 0.12, 0.25), 0.1, -6)
	return finish_tail(o, 2.2, 0.38, lp=3000)


# ----------------------------------------------------------------------------
# Anel da Fome (Mi): sucção que sobe → mordidas mastigadas
# ----------------------------------------------------------------------------

def chomp(seed, dur=0.14, low=95):
	n = n_(dur)
	t = C.tvec(n)
	r = C.rng(seed)
	thump = np.sin(C.osc_phase(low * np.exp(-t / 0.03) + 40, n)) * np.exp(-t / 0.04)
	crunch = C.bp(C.noise(n, seed) * (r.random(n) < 0.12), 900, 5000) * np.exp(-t / 0.035) * 2.5
	return (thump + crunch) * np.clip(t / 0.001, 0, 1)


def cast_fome(opt=1):
	d = 1.0
	o = buf(d)
	# sucção: ruído com ressonância subindo + "slurp" tonal subindo
	n = n_(0.42)
	t = C.tvec(n)
	suck = sweep_bp(C.noise(n, 30), 160, 1900, 4.0) * (t / t[-1]) ** 1.5
	put(o, suck, 0, -2)
	if opt in (1, 2):
		slurp = np.sin(C.osc_phase(note(40) * (1 + 1.5 * (t / t[-1]) ** 2), n)) * (t / t[-1]) ** 2
		put(o, sat(slurp, 1.5), 0, -10)
	# duas mordidas (mastigado)
	put(o, chomp(31), 0.4, 0)
	put(o, chomp(32, low=80), 0.56, -3)
	if opt == 2:
		put(o, chomp(33, low=70), 0.68, -7)
	# rosnado em Mi grave, boca abrindo "a"→"o"
	g = C.voice(note(40) * (1 + 0.02 * np.sin(2 * np.pi * 23 * C.tvec(n_(0.45)))), n_(0.45), "a", shift=0.8, vowel2="o", nh=40, breath=0.2, seed=34)
	g = sat(g * env(n_(0.45), 0.02, 0.15), 2.5)
	put(o, g, 0.38, -6 if opt != 0 else -12)
	return finish_tail(o, 0.8, 0.18, lp=5000)


# ----------------------------------------------------------------------------
# Anel da Corrente (Fá): elos de ferro → cadeado afinado
# ----------------------------------------------------------------------------

def cast_corrente(opt=1):
	d = 1.0
	o = buf(d)
	r = C.rng(40)
	# elos chacoalhando, acelerando (a corrente sendo lançada)
	times = np.cumsum(np.linspace(0.06, 0.022, 11))
	times = times - times[0]
	for i, at in enumerate(times):
		f = r.uniform(1300, 2300) if opt != 0 else r.uniform(900, 1600)
		link = C.metal_clang(f, 0.12, seed=41 + i, decay=0.05)
		put(o, link, at, -10 + r.uniform(-3, 2), r.uniform(-0.5, 0.5))
	lock_at = times[-1] + 0.05
	# cadeado: metal AFINADO em Fá (barra livre + oitava) + soco grave
	lock = C.metal_clang(note(65), 0.7, seed=55, decay=0.45) + 0.7 * C.metal_clang(note(53), 0.7, seed=56, decay=0.5)
	put(o, lock, lock_at, -2)
	put(o, tone(note(41), 0.35, 0.002, 0.08, harm=((1, 1), (2, 0.5)), glide=-0.3), lock_at, -3)
	if opt in (1, 2):    # anel de metal sustentado (o elo vibrando) — Fá + Dó
		put(o, tone(note(77), 0.6, 0.003, 0.35, harm=((1, 1), (2.76, 0.4))), lock_at, -14, -0.3)
		put(o, tone(note(84), 0.6, 0.003, 0.3, harm=((1, 1), (2.76, 0.3))), lock_at + 0.01, -17, 0.3)
	if opt == 2:
		put(o, C.lp(C.noise(n_(0.3), 57), 300) * env(n_(0.3), 0.002, 0.08), lock_at, -6)
	return finish_tail(o, 1.3, 0.22, lp=8000)


# ----------------------------------------------------------------------------
# Anel do Silêncio (Sol): sopro que cresce e CORTA o som
# ----------------------------------------------------------------------------

def cast_silencio(opt=1):
	d = 1.15
	o = buf(d)
	cut_at = 0.48
	n = n_(cut_at)
	t = C.tvec(n)
	# sopro/inspiração subindo + coro em Sol subindo junto
	breath = sweep_bp(C.noise(n, 60), 400, 3500, 1.2) * (t / t[-1]) ** 2
	put(o, breath, 0, -1)
	ch = choir([note(67), note(74)], cut_at, "a", attack=cut_at * 0.9, release=0.002, seed=61, vib=0.01)
	put(o, ch, 0, -3 if opt != 0 else -9)
	if opt == 2:
		rise = tone(note(55), cut_at, cut_at * 0.9, 9.0, harm=((1, 1), (2, 0.5), (3, 0.3)), glide=0.5)
		put(o, rise, 0, -10)
	# CORTE: tudo some (rampa de 4 ms — sem clique)
	k = n_(0.004)
	o[n - k:n] *= np.linspace(1, 0, k)[:, None]
	o[n:] = 0.0
	# no vácuo: baque surdo e um zumbido agudo de ouvido (tinnitus) que some
	thud = C.lp(tone(52, 0.5, 0.004, 0.14, harm=((1, 1), (2, 0.2)), glide=-0.4), 220)
	put(o, thud, cut_at + 0.08, -1)
	ring = tone(5274.0, 0.6, 0.05, 0.25) * (0.5 if opt == 0 else 1.0)
	put(o, ring, cut_at + 0.1, -24)
	return o


# ----------------------------------------------------------------------------
# Anel do Espelho (Lá): cristal + eco invertido do outro lado
# ----------------------------------------------------------------------------

def cast_espelho(opt=1):
	d = 1.1
	o = buf(d)
	notes = [81, 88, 93] if opt != 0 else [81, 85, 88]
	crystal = sum(glass(note(m), 0.55, 0.3, seed=70 + i, bright=1.0) * db(-3 * i) for i, m in enumerate(notes))
	tap = C.hp(C.noise(n_(0.01), 71), 4000) * np.exp(-C.tvec(n_(0.01)) / 0.002)
	rev = crystal[::-1]
	# o reflexo chega ANTES (ao contrário, lado esquerdo) e o real responde à direita
	put(o, rev, 0.0, -4, -0.7)
	at = len(rev) / SR
	put(o, tap, at, -8, 0.7)
	put(o, crystal, at, 0, 0.7)
	if opt in (1, 2):   # eco pingue-pongue de volta pro lado do reflexo
		put(o, crystal, at + 0.19, -10, -0.6)
		put(o, crystal, at + 0.38, -17, 0.4)
	if opt == 2:
		put(o, tone(note(57), 0.8, 0.2, 0.3, harm=((1, 1), (2, 0.3))), 0.2, -14)
	return shimmer(finish_tail(o, 1.6, 0.3, lp=11000), 0.2, 1.5)


# ----------------------------------------------------------------------------
# Anel da Praga (Si♭): bolhas orgânicas, gosma, enxame miúdo
# ----------------------------------------------------------------------------

def bubble(f, seed, dur=0.06):
	n = n_(dur)
	t = C.tvec(n)
	ph = C.osc_phase(f * (1 + 4.0 * t), n)            # bolha: tom sobe ao estourar
	return np.sin(ph) * np.exp(-t / (dur * 0.35)) * np.clip(t / 0.002, 0, 1)


def cast_praga(opt=1):
	d = 1.1
	o = buf(d)
	r = C.rng(80)
	# gosma: "squelch" com formante que abre e fecha
	n = n_(0.5)
	sq = C.voice(note(34) * (1 + 0.3 * np.sin(2 * np.pi * 6 * C.tvec(n))), n, "o", shift=0.7, vowel2="a", breath=0.6, seed=81, nh=40)
	sq = C.lp(sat(sq, 2.0), 1800) * C.env_swell(n, 0.06, 0.12)
	put(o, sq, 0, -5)
	# bolhas borbulhando (densas no começo, rareando)
	cnt = 34 if opt != 0 else 22
	for i in range(cnt):
		at = 0.03 + (r.random() ** 1.6) * 0.8
		f = r.uniform(220, 900)
		put(o, bubble(f, 82 + i, r.uniform(0.03, 0.08)), at, -6 - r.uniform(0, 8), r.uniform(-0.7, 0.7))
	# enxame miúdo (moscas) — só nas opções 1 e 2
	if opt in (1, 2):
		n2 = n_(0.9)
		t2 = C.tvec(n2)
		sw = np.zeros(n2)
		for k in range(8):
			f = r.uniform(170, 300)
			sw += C.saw_bl(f, n2, 20) * (0.5 + 0.5 * np.sin(2 * np.pi * r.uniform(30, 50) * t2))
		sw = C.bp(sw, 400, 3000) * C.env_swell(n2, 0.35, 0.2) / 8
		put(o, sw, 0.1, -10 if opt == 1 else -5)
	# zumbido doente em Si♭ desafinado
	put(o, tone(note(34), 0.9, 0.1, 0.3, harm=((1, 1), (2, 0.4), (3, 0.2))) + tone(note(34) * 1.03, 0.9, 0.1, 0.3), 0, -12)
	return finish_tail(o, 1.0, 0.2, lp=5000)


# ----------------------------------------------------------------------------
# Anel da Coroa (Dó): coro grave majestoso + estrondo + sinos
# ----------------------------------------------------------------------------

def cast_coroa(opt=1):
	d = 2.0
	o = buf(d)
	# ataque: estrondo grave + brilho
	boom = tone(62, 1.2, 0.002, 0.35, harm=((1, 1), (2, 0.3)), glide=-0.5)
	put(o, boom, 0, 0)
	crash = C.hp(C.noise(n_(0.6), 90), 3000) * env(n_(0.6), 0.002, 0.12)
	put(o, crash, 0, -14)
	# coro grave masculino (Dó maior aberto) "o" → "a"
	ch = choir([note(36), note(43), note(48), note(52), note(55)], 1.7, "o", shift=0.85, attack=0.08, release=0.9,
		seed=91, vib=0.006, voices=3, vowel2="a")
	put(o, ch, 0.02, 4)
	if opt in (1, 2):   # metal grave (trompas) por baixo
		br = sum(C.saw_bl(note(m) * (1 + 0.002 * i), n_(1.4), 30) for i, m in enumerate([36, 43, 48]))
		br = C.lp(br, 900) * C.env_swell(n_(1.4), 0.12, 0.45)
		put(o, br, 0.02, -14)
	# sinos dourados no alto
	for i, m in enumerate([84, 79, 76] if opt != 2 else [84, 88, 91]):
		put(o, C.bell(note(m), 1.5, 0.9, seed=92 + i, bright=0.8), 0.05 + 0.09 * i, -13, (-0.6, 0.6, 0)[i])
	return shimmer(finish_tail(o, 2.8, 0.32, lp=6500), 0.18, 2.2)


# ----------------------------------------------------------------------------
# Falha (sem Éter / calado pelo Silêncio): chiado seco que morre
# ----------------------------------------------------------------------------

def cast_fail(opt=1):
	d = 0.4
	o = buf(d)
	n = n_(0.3)
	t = C.tvec(n)
	f = 420 * (1 - 0.55 * t / t[-1])
	x = C.saw_bl(f, n, 12) * env(n, 0.003, 0.09)
	x = C.lp(x, 1600)
	put(o, x, 0, -4)
	r = C.rng(100)
	spt = C.bp(C.noise(n, 101) * (r.random(n) < (0.03 if opt != 0 else 0.06)), 1500, 6000) * np.exp(-t / 0.1)
	put(o, spt, 0.01, -2 if opt != 2 else -6)
	if opt == 2:
		put(o, tone(220, 0.15, 0.002, 0.04), 0.0, -8)
	return o


# ----------------------------------------------------------------------------
# Projéteis e nova
# ----------------------------------------------------------------------------

def proj_fire(opt=1, var=0):
	d = 0.35
	o = buf(d)
	n = n_(0.09)
	t = C.tvec(n)
	base = [1.0, 1.06, 0.94][var]
	zip_ = np.sin(C.osc_phase(900 * base * (1 + 1.6 * t / t[-1]), n)) * env(n, 0.003, 0.03)
	put(o, zip_, 0, -6)
	air = sweep_bp(C.noise(n_(0.16), 110 + var), 1200, 5000, 1.5) * env(n_(0.16), 0.004, 0.05)
	put(o, air, 0, -4)
	if opt in (1, 2):
		put(o, glass(note(88) * base, 0.25, 0.09, seed=112 + var, bright=0.5), 0.02, -12)
	return finish_tail(o, 0.4, 0.15)


def proj_hit(opt=1, var=0):
	d = 0.35
	o = buf(d)
	r = C.rng(120 + var)
	n = n_(0.12)
	t = C.tvec(n)
	burst = C.bp(C.noise(n, 121 + var), 1500, 7000) * np.exp(-t / 0.025)
	put(o, burst, 0, -3)
	crackle = C.hp(C.noise(n_(0.2), 122 + var) * (r.random(n_(0.2)) < 0.02), 2500) * np.exp(-C.tvec(n_(0.2)) / 0.06)
	put(o, crackle, 0.005, -4)
	put(o, tone(140, 0.12, 0.001, 0.03, glide=-0.4), 0, -6)
	if opt in (1, 2):
		put(o, glass(note([84, 86, 81][var]), 0.25, 0.08, seed=124 + var, bright=0.8), 0.0, -10)
	return finish_tail(o, 0.5, 0.15)


def nova(opt=1):
	d = 1.0
	o = buf(d)
	put(o, tone(85, 0.6, 0.002, 0.16, harm=((1, 1), (2, 0.25)), glide=-0.5), 0, 0)
	# onda saindo: ruído com banda DESCENDO (afasta) e abrindo no estéreo
	n = n_(0.6)
	t = C.tvec(n)
	wl = sweep_bp(C.noise(n, 130), 4000, 500, 1.2) * C.env_swell(n, 0.04, 0.18)
	wr = sweep_bp(C.noise(n, 131), 4200, 520, 1.2) * C.env_swell(n, 0.04, 0.18)
	wide = np.stack([wl, wr], axis=1)
	C.place(o, wide, 0.0, -3)
	if opt in (1, 2):
		put(o, glass(note(88), 0.6, 0.25, seed=132, bright=0.8), 0.0, -12)
		put(o, glass(note(95), 0.5, 0.2, seed=133, bright=0.8), 0.03, -16)
	if opt == 2:
		put(o, C.bell(note(64), 0.8, 0.4, seed=134, bright=0.5), 0, -10)
	return finish_tail(o, 1.0, 0.22)


# ----------------------------------------------------------------------------
# Faísca coletada: tilintar cristalino, pentatônico, não cansativo
# ----------------------------------------------------------------------------

SPARK_SCALE = [88, 91, 93, 95, 98]     # Mi pentatônica menor (Mi Sol Lá Si Ré) na 6ª oitava


def spark(opt=1, var=0):
	m = SPARK_SCALE[var]
	f = note(m)
	d = 0.3
	n = n_(d)
	t = C.tvec(n)
	if opt == 0:      # seno puro
		x = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.07)
	elif opt == 1:    # cristal: fundamental + parcial de taça + leve 2ª voz uma 5ª acima
		x = (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2.32 * t) * np.exp(-t / 0.03)
			+ 0.18 * np.sin(2 * np.pi * f * 1.5 * t + 1.0)) * np.exp(-t / 0.08)
	else:             # sininho (2 parciais desafinados = brilho)
		x = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 1.004 * t)) * np.exp(-t / 0.1)
	x *= np.clip(t / 0.004, 0, 1) ** 2                 # ataque suave: sem clique
	x = C.fade(x, 0, 0.03)
	o = C.pan(x, (var - 2) * 0.15)
	return finish_tail(o, 0.6, 0.18, lp=12000)


# ----------------------------------------------------------------------------
# Tabela: nome -> (função, nº de variações). Variações = arquivos _2, _3...
# ----------------------------------------------------------------------------

SOUNDS = {
	"cast_solar": (cast_solar, 1), "cast_torpor": (cast_torpor, 1), "cast_fome": (cast_fome, 1),
	"cast_corrente": (cast_corrente, 1), "cast_silencio": (cast_silencio, 1), "cast_espelho": (cast_espelho, 1),
	"cast_praga": (cast_praga, 1), "cast_coroa": (cast_coroa, 1), "cast_fail": (cast_fail, 1),
	"proj_fire": (proj_fire, 3), "proj_hit": (proj_hit, 3), "nova": (nova, 1), "spark": (spark, 5),
}


# duração máxima do arquivo (a cauda de reverb é cortada com fade longo)
MAXDUR = {"cast_torpor": 1.7, "cast_coroa": 2.4, "cast_espelho": 1.6, "cast_solar": 1.2, "cast_fome": 1.1,
	"cast_corrente": 1.3, "cast_silencio": 1.2, "cast_praga": 1.3, "cast_fail": 0.4,
	"proj_fire": 0.4, "proj_hit": 0.4, "nova": 1.1, "spark": 0.45}


def render(name, opt, var=0):
	fn, nv = SOUNDS[name]
	x = fn(opt) if nv == 1 else fn(opt, var)
	n = int(MAXDUR[name] * SR)
	if len(x) > n:
		x = x[:n].copy()
		f = int(min(0.25, MAXDUR[name] * 0.3) * SR)
		x[-f:] *= (np.linspace(1, 0, f) ** 2)[:, None]
	return x


def variants(name):
	"""Lista de lambdas (uma por arquivo) com a opção escolhida."""
	fn, nv = SOUNDS[name]
	opt = CHOICE[name]
	return [lambda name=name, opt=opt, v=v: render(name, opt, v) for v in range(nv)]


if __name__ == "__main__":
	# grava as 3 opções de cada som (variação 0) pra comparar de ouvido
	sys.path.insert(0, C.HERE)
	import build_sfx as B
	outdir = os.path.join(os.path.dirname(C.ROOT), "_caps", "audio", "opcoes")
	os.makedirs(outdir, exist_ok=True)
	names = sys.argv[1:] or list(SOUNDS.keys())
	for name in names:
		fn, nv = SOUNDS[name]
		cat = B.RECIPES[name][0]
		for opt in range(3):
			x = B.finish(render(name, opt, 0), cat)
			C.write_ogg(os.path.join(outdir, "%s_op%d.ogg" % (name, opt + 1)), x.astype(np.float32))
	print("opções gravadas em", outdir)
