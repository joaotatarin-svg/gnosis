# -*- coding: utf-8 -*-
"""
Sintetiza as AMBIÊNCIAS por Éon do GNOSIS (assets/audio/amb/amb_<nome>.ogg),
100 % numpy — nenhum sample de terceiros, nenhuma IA. Licença: própria do jogo.

  python tools/audio_synth/build_ambience.py            # todas
  python tools/audio_synth/build_ambience.py torpor     # só uma

LOOP PERFEITO POR CONSTRUÇÃO: cada ambiência é um sinal periódico de L
segundos —
  · osciladores e LFOs têm nº inteiro de ciclos em L (common.periodic_freq);
  · ruídos são filtrados no domínio da frequência (FFT = circular);
  · eventos (sinos, golpes) que passam do fim "dão a volta" pro começo;
  · o reverb é convolução CIRCULAR (o rabo do fim cai no começo).
Logo a última amostra emenda na primeira como se o som nunca parasse.

Tema por obra alquímica: nigredo (Torpor, Fome, Corrente — grave, pesado),
albedo (Silêncio, Espelho — branco, vazio, vítreo), rubedo (Praga, Coroa —
febril, falso ouro). + Limiar (sala do Rei) e Centro (memória).
Loudness: −28 LUFS integrado (Silêncio −31), por baixo da música (−16).
"""
import os, sys
import numpy as np
from scipy import signal
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import SR, db

L = 48.0                     # segundos de loop
N = int(L * SR)
T = C.tvec(N)
TARGET = -28.0
TARGET_OVERRIDE = {"silencio": -31.0}


def pf(f):
	return C.periodic_freq(f, L)


def lfo(rate, phase=0.0):
	"""LFO senoidal periódico em L (0..1)."""
	return 0.5 + 0.5 * np.sin(2 * np.pi * pf(rate) * T + phase)


def note(m):
	return 440.0 * 2 ** ((m - 69) / 12)


def sine(f, phase=0.0):
	return np.sin(2 * np.pi * pf(f) * T + phase)


def drone(f, nh=12, tilt=1.4, beat=0.0):
	"""Drone aditivo (harmônicos 1/k^tilt); beat = Hz de batimento (2ª cópia)."""
	f = pf(f)
	out = np.zeros(N)
	for k in range(1, nh + 1):
		if f * k > SR * 0.4:
			break
		out += np.sin(2 * np.pi * f * k * T) / k ** tilt
		if beat:
			out += np.sin(2 * np.pi * pf(f * k + beat) * T + 1.0) / k ** tilt
	return out


def choir_pad(notes, vowel="a", seed=0, shift=1.0, breath=0.1, voices=2, vib_depth=0.005):
	"""Coro aditivo periódico (vibrato com nº inteiro de ciclos)."""
	r = C.rng(seed)
	out = np.zeros((N, 2))
	for i, m in enumerate(notes):
		for v in range(voices):
			f0 = pf(note(m) * (1 + r.uniform(-0.003, 0.003)))
			vr = pf(r.uniform(4.5, 5.8))
			x = C.voice(f0, N, vowel, shift=shift, breath=0.0, seed=seed + i * 7 + v, nh=30, vib=(vr, vib_depth))
			out += C.pan(x, r.uniform(-0.8, 0.8))
	if breath > 0:   # sopro: ruído periódico moldado pela vogal
		w = C.noise(N, seed + 500, stereo=True)
		out += C.fft_shape(w, lambda f: C.formant_gain(f, vowel, shift)) * breath * 0.05
	return out / (len(notes) * voices)


def wind(seed, lo, hi, gust=(0.05, 0.11), depth=0.6, stereo=True):
	"""Vento: ruído em banda (circular) com rajadas periódicas."""
	w = C.band_noise(N, seed, lo, hi, stereo=stereo)
	e = (1 - depth) + depth * lfo(gust[0], seed) * (0.6 + 0.4 * lfo(gust[1], seed * 2))
	return w * (e[:, None] if stereo else e)


def resonant_noise(seed, peaks, stereo=True):
	"""Ruído com ressonâncias (vento em osso, sala oca): picos (f, Q, ganho)."""
	w = C.noise(N, seed, stereo)

	def g(f):
		out = np.zeros_like(f)
		for (fc, q, gd) in peaks:
			out += db(gd) / (1 + ((f - fc) / (fc / q / 2)) ** 2)
		return out
	return C.fft_shape(w, g)


def place_wrap(buf, x, at_s, gain_db=0.0):
	"""Soma um evento; o que passa do fim do loop volta pro começo."""
	at = int(at_s * SR) % len(buf)
	x = x * db(gain_db)
	if buf.ndim == 2 and x.ndim == 1:
		x = np.stack([x, x], axis=1)
	n = len(x)
	end = at + n
	if end <= len(buf):
		buf[at:end] += x
	else:
		k = len(buf) - at
		buf[at:] += x[:k]
		rest = x[k:]
		while len(rest) > 0:
			m = min(len(rest), len(buf))
			buf[:m] += rest[:m]
			rest = rest[m:]
	return buf


def pluck(f, dur=2.5, decay=0.996, seed=0, bright=0.6):
	"""Karplus-Strong (harpa de vidro) via lfilter."""
	n = int(dur * SR)
	P = max(2, int(round(SR / f)))
	exc = np.zeros(n)
	b = C.noise(P, seed)
	exc[:P] = C.lp(b, 2000 + 6000 * bright)
	a = np.zeros(P + 2)
	a[0] = 1.0
	a[P] = -decay * 0.5
	a[P + 1] = -decay * 0.5
	return signal.lfilter([1.0], a, exc)


def thud(f0=50, f1=32, dur=0.4, decay=0.1, seed=0):
	n = int(dur * SR)
	t = C.tvec(n)
	f = f1 + (f0 - f1) * np.exp(-t / 0.04)
	return np.sin(C.osc_phase(f, n)) * np.exp(-t / decay) * np.clip(t / 0.003, 0, 1)


def st(x):
	return np.stack([x, x], axis=1) if x.ndim == 1 else x


# ----------------------------------------------------------------------------
# Os Éons
# ----------------------------------------------------------------------------

def amb_torpor():
	"""Névoa do sono: sub grave que respira, sopro lento, caixinha de música
	abafada ao longe, coro em 'u' quase dormindo."""
	breath_e = (0.5 - 0.5 * np.cos(2 * np.pi * pf(1 / 8.0) * T)) ** 2
	sub = (sine(41.2) * 0.9 + C.lp(drone(82.4, 8, 1.6), 300) * 0.5) * (0.65 + 0.35 * breath_e)
	breath = C.band_noise(N, 11, 200, 900, stereo=True) * (0.15 + 0.85 * breath_e)[:, None]
	hum = choir_pad([40, 47], "u", seed=12, shift=0.9, breath=0.4, voices=2)
	box = np.zeros((N, 2))
	r = C.rng(13)
	for i, m in enumerate([76, 79, 83, 86, 79, 74]):
		b = C.lp(C.bell(note(m), 2.5, 0.9, seed=14 + i, bright=0.2), 1300)
		place_wrap(box, C.pan(b, r.uniform(-0.6, 0.6)), 3.0 + i * 7.6 + r.uniform(-1, 1))
	mix = st(sub) * 0.5 + breath * 0.18 + hum * 0.9 + box * 0.12
	return C.reverb_circular(mix, rt60=4.0, wet=0.35, seed=21, lp_hz=3500)


def amb_fome():
	"""Fome: pulso que lateja (lub-dub), vento oco em osso, drone em 2ª menor
	que range, raspadas de algo roendo."""
	beat = np.zeros(N)
	period = L / 50                                     # ~0,96 s, divide o loop
	r = C.rng(31)
	for i in range(50):
		a = 0.7 + 0.3 * r.random()
		place_wrap(beat, thud(55, 34, 0.35, 0.08, seed=i) * a, i * period)
		place_wrap(beat, thud(48, 30, 0.35, 0.07, seed=i + 60) * a * 0.6, i * period + 0.22)
	bone = resonant_noise(32, [(310, 18, 0), (470, 22, -3), (820, 25, -8)]) * (0.4 + 0.6 * lfo(1 / 12.0))[:, None]
	grind = C.lp(drone(note(36), 10, 1.0) + drone(note(37), 10, 1.0), 450) * 0.25
	gnaw = np.zeros((N, 2))
	for i in range(9):
		n = int(r.uniform(0.25, 0.6) * SR)
		t = C.tvec(n)
		g = C.bp(C.noise(n, 40 + i), 1200, 5000) * (r.random(n) < 0.03) * np.sin(np.pi * t / t[-1])
		place_wrap(gnaw, C.pan(C.lp(g, 6000), r.uniform(-0.9, 0.9)), r.uniform(0, L))
	mix = st(C.lp(beat, 200)) * 0.55 + bone * 0.05 + st(grind) * 0.45 + gnaw * 0.6
	return C.reverb_circular(mix, rt60=2.5, wet=0.3, seed=22, lp_hz=5000)


def amb_corrente():
	"""Corrente da Lei: pedal de órgão, bigorna e elos de ferro ao longe em
	compasso rígido (a cada 4 s), vento baixo de masmorra."""
	organ = (drone(note(24), 16, 0.9) * 0.6 + drone(note(36), 12, 1.1) * 0.4 + drone(note(43), 10, 1.3) * 0.25)
	organ = C.lp(organ, 900) * (0.7 + 0.3 * lfo(1 / 16.0))
	clank = np.zeros((N, 2))
	r = C.rng(41)
	for i in range(12):
		f = 210 if i % 2 == 0 else 315
		c = C.lp(C.metal_clang(f, 2.0, seed=42 + i, decay=0.8), 3500)
		place_wrap(clank, C.pan(c, -0.4 if i % 2 == 0 else 0.4), i * 4.0, -2 if i % 4 == 0 else -6)
		if i % 3 == 1:     # chocalho de elos
			for k in range(4):
				place_wrap(clank, C.pan(C.metal_clang(r.uniform(900, 1400), 0.3, seed=60 + i * 4 + k, decay=0.08), 0.7), i * 4.0 + 1.6 + k * 0.07, -14)
	low = wind(43, 60, 400, depth=0.5)
	mix = st(organ) * 0.3 + clank * 0.12 + low * 0.35
	return C.reverb_circular(mix, rt60=4.5, wet=0.4, seed=23, lp_hz=4500)


def amb_silencio():
	"""Silêncio (albedo): ar branco e alto, harmônicos de vidro que acendem e
	somem devagar, quase nada — um sino muito longe três vezes."""
	air = wind(51, 2500, 9000, gust=(0.04, 0.09), depth=0.8)
	glass = np.zeros((N, 2))
	for i, f in enumerate([2093.0, 2637.0, 3136.0, 3951.0, 4699.0]):
		e = lfo(1 / [48.0, 24.0, 16.0, 48.0, 12.0][i], i * 1.7) ** 4
		glass += C.pan(sine(f, i) * e, [-0.7, 0.5, -0.2, 0.8, 0.0][i])
	far = np.zeros((N, 2))
	for i, at in enumerate([5.0, 21.0, 37.0]):
		far = place_wrap(far, C.pan(C.lp(C.bell(note(69 + [0, 7, -5][i]), 5.0, 2.5, seed=52 + i, bright=0.3), 2500), (-0.5, 0.4, 0.0)[i]), at)
	mix = air * 0.08 + glass * 0.012 + far * 0.06
	return C.reverb_circular(mix, rt60=6.0, wet=0.5, seed=24, lp_hz=8000)


def amb_espelho():
	"""Espelho (albedo): pad prateado e seu gêmeo desafinado do outro lado,
	sinos ao contrário que respondem pra frente no lado oposto."""
	pad = np.zeros((N, 2))
	for i, m in enumerate([57, 61, 64, 71]):
		f = note(m)
		e = 0.6 + 0.4 * lfo(1 / 24.0, i)
		pad[:, 0] += sine(f, i) * e
		pad[:, 1] += sine(f + 0.25 * (i + 1) / 2, i + 2) * e      # o reflexo, levemente fora
	echo = np.zeros((N, 2))
	for i in range(6):
		m = [81, 88, 76, 85, 83, 80][i]
		b = C.bell(note(m), 2.0, 0.7, seed=61 + i, bright=1.0)
		side = -0.7 if i % 2 == 0 else 0.7
		place_wrap(echo, C.pan(b[::-1], side), i * 8.0)              # ao contrário, termina em i*8+2
		place_wrap(echo, C.pan(b, -side), i * 8.0 + 2.0, -3)          # e pra frente, do outro lado
	air = wind(62, 4000, 10000, depth=0.5) * 0.5
	mix = pad * 0.06 + echo * 0.1 + air * 0.05
	return C.reverb_circular(mix, rt60=5.0, wet=0.45, seed=25, lp_hz=9000)


def amb_praga():
	"""Praga (rubedo): enxame que vai e volta, drone doente em batimento,
	gemidos de coro em 'o' por baixo."""
	r = C.rng(71)
	swarm = np.zeros((N, 2))
	for i in range(16):
		f = pf(r.uniform(140, 300))
		wob = 1 + 0.02 * np.sin(2 * np.pi * pf(r.uniform(0.2, 1.0)) * T + r.uniform(0, 6))
		x = C.saw_bl(f * wob, N, 20) * (0.5 + 0.5 * np.sin(2 * np.pi * pf(r.uniform(30, 55)) * T))
		amp = lfo(1 / r.choice([6.0, 8.0, 12.0, 16.0]), r.uniform(0, 6)) ** 3
		p = np.sin(2 * np.pi * pf(1 / r.choice([12.0, 16.0, 24.0])) * T + r.uniform(0, 6)) * 0.8
		a = (p + 1) * np.pi / 4
		swarm[:, 0] += x * amp * np.cos(a)
		swarm[:, 1] += x * amp * np.sin(a)
	swarm = C.bp(swarm, 300, 3500) / 8
	sick = C.lp(drone(55.0, 8, 1.2, beat=3.3), 500) * 0.4
	moan = choir_pad([45, 46, 52], "o", seed=72, shift=0.85, breath=0.3, voices=2, vib_depth=0.012) * (0.4 + 0.6 * lfo(1 / 16.0))[:, None]
	mix = swarm * 0.5 + st(sick) * 0.35 + moan * 0.8
	return C.reverb_circular(mix, rt60=3.0, wet=0.35, seed=26, lp_hz=5000)


def amb_coroa():
	"""Coroa (rubedo, falso ouro): coro grande em Ré maior com uma nota
	errada por baixo, metal grave, sinos de catedral ao longe."""
	ch = choir_pad([50, 57, 62, 66, 69], "a", seed=81, shift=1.0, breath=0.15, voices=2) * (0.55 + 0.45 * lfo(1 / 24.0))[:, None]
	crack = choir_pad([68], "a", seed=82, voices=1, vib_depth=0.01) * (lfo(1 / 16.0, 2.0) ** 6)[:, None]   # a rachadura
	brass = C.lp(drone(note(38), 20, 1.0) + drone(note(45), 16, 1.0) * 0.6, 700) * (0.6 + 0.4 * lfo(1 / 48.0))
	bells = np.zeros((N, 2))
	for i in range(4):
		b = C.bell(note(50), 8.0, 3.0, seed=83 + i, bright=0.6)
		place_wrap(bells, C.pan(b, (-0.5, 0.5)[i % 2]), i * 12.0 + 1.0)
		place_wrap(bells, C.pan(C.bell(note(62 + (i % 2) * 5), 4.0, 1.5, seed=90 + i, bright=0.7), (0.6, -0.6)[i % 2]), i * 12.0 + 6.0, -6)
	mix = ch * 1.0 + crack * 0.35 + st(brass) * 0.1 + bells * 0.05
	return C.reverb_circular(mix, rt60=5.5, wet=0.45, seed=27, lp_hz=6000)


def amb_limiar():
	"""O Limiar (sala do Rei): salão oco, vento baixo, um sino que dobra a
	cada 16 s, drone em Sol grave."""
	hall = resonant_noise(91, [(95, 10, 0), (190, 14, -4), (380, 16, -10)]) * (0.5 + 0.5 * lfo(1 / 16.0))[:, None]
	dr = C.lp(drone(note(31), 12, 1.2, beat=0.5), 400)
	toll = np.zeros((N, 2))
	for i in range(3):
		toll = place_wrap(toll, C.bell(note(43), 9.0, 3.5, seed=92 + i, bright=0.4), i * 16.0 + 2.0)
	mix = hall * 0.06 + st(dr) * 0.25 + toll * 0.12 + wind(93, 150, 1200, depth=0.6) * 0.15
	return C.reverb_circular(mix, rt60=5.0, wet=0.45, seed=28, lp_hz=4000)


def amb_centro():
	"""O Centro (memória): coração lento, harpa de vidro com sete notas (uma
	por Éon) que ecoam, pad íntimo."""
	beat = np.zeros(N)
	period = L / 40     # 1,2 s
	for i in range(40):
		place_wrap(beat, thud(50, 34, 0.3, 0.07, seed=i), i * period)
		place_wrap(beat, thud(45, 30, 0.3, 0.06, seed=i + 50) * 0.55, i * period + 0.25)
	harp = np.zeros((N, 2))
	r = C.rng(101)
	notes = [62, 64, 65, 67, 69, 70, 72]
	for i, m in enumerate(notes):
		p = pluck(note(m), 3.0, 0.997, seed=102 + i)
		at = 2.0 + i * 6.5
		place_wrap(harp, C.pan(p, r.uniform(-0.6, 0.6)), at)
		place_wrap(harp, C.pan(p, r.uniform(-0.6, 0.6)), at + 0.75, -9)     # eco
	pad = choir_pad([50, 57, 65], "u", seed=103, voices=1, breath=0.2) * (0.5 + 0.5 * lfo(1 / 24.0))[:, None]
	mix = st(C.lp(beat, 160)) * 0.4 + harp * 0.1 + pad * 0.6
	return C.reverb_circular(mix, rt60=3.5, wet=0.4, seed=29, lp_hz=7000)


AMBS = {
	"torpor": amb_torpor, "fome": amb_fome, "corrente": amb_corrente, "silencio": amb_silencio,
	"espelho": amb_espelho, "praga": amb_praga, "coroa": amb_coroa,
	"limiar": amb_limiar, "centro": amb_centro,
}


def finish(x, name):
	x = x - x.mean(axis=0)                     # sem DC
	tgt = TARGET_OVERRIDE.get(name, TARGET)
	x = x * db(tgt - C.integrated_lufs(x))
	if C.sample_peak_db(x) > -3.0:             # limitador circular (sem degrau na volta)
		M = SR
		ext = np.concatenate([x[-M:], x, x[:M]])
		x = C.limit(ext, -3.0, 3.0, 200.0)[M:M + len(x)]
	return x


if __name__ == "__main__":
	names = sys.argv[1:] or list(AMBS.keys())
	for n in names:
		x = finish(AMBS[n](), n)
		C.write_ogg(os.path.join(C.AMB_DIR, "amb_%s.ogg" % n), x.astype(np.float32), quality=4)
		print("amb %-9s %5.1fs  I %6.1f LUFS  pico %5.1f dB" % (n, len(x) / SR, C.integrated_lufs(x), C.sample_peak_db(x)))
