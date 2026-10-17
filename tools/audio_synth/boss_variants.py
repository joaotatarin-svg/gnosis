# -*- coding: utf-8 -*-
"""
Variações da música de chefe POR ARCONTE (#40), a partir da faixa existente
(`music/boss.ogg` = "Volatile Reaction", Kevin MacLeod, CC-BY 4.0 — obra
derivada: tom, arranjo e camadas mudados; crédito em assets/LICENSES.md se
alguma for instalada). 100 % processamento + síntese, sem IA.

  python3 tools/audio_synth/boss_variants.py [saida_dir]        # gera as 7 opções
  python3 tools/audio_synth/boss_variants.py --install torpor   # grava music/boss_torpor.ogg

NÃO troca a música padrão: o jogo só usa `boss_<éon>.ogg` se o arquivo
existir (Audio.boss_track). Sem aprovação do João, nada é instalado.

Toda transformação é CIRCULAR (o sinal é tratado como periódico): o loop de
boss.ogg já emenda perfeito e continua emendando — filtros e limitador rodam
em [fim | loop | começo] e só o miolo fica; LFOs têm nº inteiro de ciclos no
loop; atrasos são `np.roll`; mudança de tom (fita) é reamostragem por FFT do
loop inteiro. Camadas rítmicas caem nas BATIDAS detectadas da própria faixa
(librosa, 156,6 bpm), então andam junto com a música.

Por Arconte (tema do Éon):
  torpor     Athoth     fita 1 semitom ABAIXO (mais lenta, pesada) + abafado que "respira" (LFO de 16 s)
  fome       Harmas     pulso grave mastigado em cada batida (acento no tempo 1) + saturação leve
  corrente   Galila     elos de corrente metálicos nos contratempos + brilho 1–3 kHz
  silencio   Yabel      fina (grave −10 dB) + "buracos": a última batida de cada 4 compassos some + sala longa
  espelho    Astaphaios eco-espelho: cada lado repete o OUTRO lado uma batida depois + estéreo largo
  praga      Belias     doente: tom oscilando ±12 cents (coro desafinado) + zumbido de enxame baixo
  coroa      Armupiel   fita 1 semitom ACIMA (mais rápida, régia) + tímpano no tempo 1 + brilho
"""
import os, sys, json
import numpy as np
import soundfile as sf
from scipy import signal
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import SR
import magic as M

SRC = os.path.join(C.MUSIC_DIR, "boss.ogg")
OUT_DEFAULT = "/home/user/caps/audio2/opcoes"
TARGET = -16.0
PAD = 6.0                    # s de contexto circular nos filtros/limitador
ARCONTES = {
	"torpor": "Athoth", "fome": "Harmas", "corrente": "Galila", "silencio": "Yabel",
	"espelho": "Astaphaios", "praga": "Belias", "coroa": "Armupiel",
}


# ----------------------------------------------------------------------------
# Ferramentas circulares
# ----------------------------------------------------------------------------

def circ(fn, x, pad_s=PAD):
	"""Aplica fn (filtro com memória < pad) como se x tocasse em loop."""
	p = int(pad_s * SR)
	y = fn(np.concatenate([x[-p:], x, x[:p]]))
	return y[p:p + len(x)]


def tape(x, rate):
	"""Fita: tom e andamento juntos (rate > 1 = mais agudo e rápido). FFT = circular."""
	n = int(round(len(x) / rate))
	return signal.resample(x, n, axis=0)


def lfo(n, period_s, phase=0.0):
	"""Seno com nº INTEIRO de ciclos no loop (fase contínua na emenda)."""
	L = n / SR
	f = C.periodic_freq(1.0 / period_s, L)
	return np.sin(2 * np.pi * f * C.tvec(n) + phase)


def beats(x):
	"""Batidas da faixa (s), detectadas no sinal em loop e trazidas para [0, L)."""
	import librosa
	p = int(10 * SR)
	m = np.concatenate([x[-p:], x, x[:p]]).mean(axis=1).astype(np.float32)
	_, fr = librosa.beat.beat_track(y=m, sr=SR, hop_length=512)
	t = librosa.frames_to_time(fr, sr=SR, hop_length=512) - 10.0
	L = len(x) / SR
	t = np.sort(np.mod(t[(t >= -0.05) & (t < L - 0.05)], L))
	keep = np.r_[True, np.diff(t) > 0.15]
	return t[keep]


def place_circ(dst, src, at_s, gain_db=0.0):
	"""Soma src em dst a partir de at_s; o que passa do fim volta no começo."""
	n = len(dst)
	a = int(round(at_s * SR)) % n
	src = np.asarray(src) * C.db(gain_db)
	if src.ndim == 1 and dst.ndim == 2:
		src = np.stack([src, src], axis=1)
	m = min(len(src), n)
	end = a + m
	if end <= n:
		dst[a:end] += src[:m]
	else:
		k = n - a
		dst[a:] += src[:k]
		dst[:m - k] += src[k:m]


def master(x):
	"""−16 LUFS integrado + teto de pico, com o limitador também circular."""
	y = x * C.db(TARGET - C.integrated_lufs(x))
	for _ in range(3):
		if np.abs(y).max() > C.db(-1.5):
			y = circ(lambda z: C.limit(z, -1.5, lookahead_ms=3.0, release_ms=120.0), y, 1.0)
		now = C.integrated_lufs(y)
		if abs(now - TARGET) < 0.2:
			break
		y = y * C.db(TARGET - now)
	if np.abs(y).max() > C.db(-1.0):
		y = circ(lambda z: C.limit(z, -1.0, lookahead_ms=3.0, release_ms=120.0), y, 1.0)
	tp = C.true_peak_db(y)              # pico REAL (entre amostras) ≤ −1 dBTP:
	if tp > -1.0:                       # prefere ficar um pouco mais baixa a esmagar
		y = y * C.db(-1.1 - tp)
	return y


# ----------------------------------------------------------------------------
# Peças sintetizadas (curtas; somadas nas batidas)
# ----------------------------------------------------------------------------

def thump(f0=52.0, dur=0.32, seed=0, chomp=True):
	n = M.n_(dur)
	t = C.tvec(n)
	body = M.tone(f0, dur, 0.003, 0.09, harm=((1, 1.0), (2, 0.4), (3, 0.15)), glide=-0.35)
	x = body
	if chomp:     # "mordida": estalo grave de ruído 150–600 Hz
		x = x + C.bp(C.noise(n, seed), 150, 600) * C.env_ad(n, 0.001, 0.025) * 0.8
	return C.lp(x, 900) * np.clip(t / 0.003, 0, 1)


def chain_link(seed):
	r = C.rng(seed)
	m = C.metal_clang(r.uniform(1900, 3200), 0.16, seed=seed, decay=0.05)
	m2 = C.metal_clang(r.uniform(900, 1400), 0.12, seed=seed + 1, decay=0.035) * 0.6
	n = max(len(m), len(m2))
	o = np.zeros(n)
	o[:len(m)] += m
	o[:len(m2)] += m2
	return C.hp(o, 600)


def timpani(f=73.4, dur=1.2, seed=0):
	n = M.n_(dur)
	x = M.tone(f, dur, 0.004, 0.45, harm=((1, 1.0), (1.5, 0.45), (1.99, 0.3), (2.44, 0.18)), glide=-0.02)
	x += C.lp(C.noise(n, seed), 400) * C.env_ad(n, 0.002, 0.03) * 0.5
	return x


# ----------------------------------------------------------------------------
# As 7 variações
# ----------------------------------------------------------------------------

def v_torpor(x, bt):
	y = tape(x, 2 ** (-1 / 12))
	n = len(y)
	dark = circ(lambda z: C.lp(z, 1100, order=2), y)
	g = (0.5 + 0.5 * lfo(n, 16.0))[:, None]          # respira: 16 s abafado ↔ aberto
	y = dark * (1 - 0.75 * g) + y * (0.75 * g)
	return y


def v_fome(x, bt):
	y = circ(lambda z: M.sat(z * 1.3, 1.4), x)
	lay = np.zeros_like(y)
	for i, b in enumerate(bt):
		acc = (i % 4 == 0)
		place_circ(lay, thump(52.0 if acc else 58.0, 0.32, seed=800 + i % 7), b, -3.0 if acc else -9.0)
	return y + lay * 0.55


def v_corrente(x, bt):
	y = x.copy()
	presence = circ(lambda z: C.bp(z, 1000, 3000), y)
	y = y + presence * 0.25
	lay = np.zeros_like(y)
	r = C.rng(900)
	for i in range(len(bt)):
		b0 = bt[i]
		b1 = bt[(i + 1) % len(bt)] + (len(y) / SR if i + 1 == len(bt) else 0.0)
		off = b0 + (b1 - b0) * 0.5                       # contratempo
		if i % 2 == 1:
			place_circ(lay, C.pan(chain_link(910 + i % 11), r.uniform(-0.5, 0.5)), off, -10.0)
	return y + lay * 0.5


def v_silencio(x, bt):
	# fina: o grave (< 180 Hz) cai ~10 dB — sem tirar de vez (as partes graves
	# da faixa sumiriam a −30 LUFS)
	low = circ(lambda z: C.lp(z, 180, order=2), x)
	y = x - 0.68 * low
	y = C.reverb_circular(y, rt60=3.2, wet=0.35, seed=950, lp_hz=5000)
	n = len(y)
	gate = np.ones(n)
	ramp = int(0.025 * SR)
	for i in range(len(bt)):
		if i % 16 == 15:                                  # a última batida de cada 4 compassos some
			a = int(bt[i] * SR)
			b = int(bt[(i + 1) % len(bt)] * SR) if i + 1 < len(bt) else n
			b = max(a + 2 * ramp, b - ramp)
			seg = np.ones(max(0, b - a))
			seg[:ramp] = np.linspace(1, 0.08, ramp)
			seg[ramp:-ramp] = 0.08
			seg[-ramp:] = np.linspace(0.08, 1, ramp)
			gate[a:b] = np.minimum(gate[a:b], seg[:len(gate[a:b])])
	return y * gate[:, None]


def v_espelho(x, bt):
	d = int(np.median(np.diff(bt)) * SR)                  # uma batida
	L, R = x[:, 0], x[:, 1]
	echoL = np.roll(R, d)
	echoR = np.roll(L, d)
	y = np.stack([L + 0.38 * echoL, R + 0.38 * echoR], axis=1)
	mid = (y[:, 0] + y[:, 1]) / 2
	side = (y[:, 0] - y[:, 1]) / 2
	side = side * 1.5
	return np.stack([mid + side, mid - side], axis=1)


def v_praga(x, bt):
	n = len(x)
	base = 0.012 * SR
	out = np.zeros_like(x)
	for k, (per, depth, ph) in enumerate([(3.3, 0.0069, 0.0), (4.7, 0.0069, 2.1)]):   # ±12 cents
		mod = lfo(n, per, ph)
		dly = base * (1 + 0.4 * mod)                       # atraso variando = tom oscilando
		idx = (np.arange(n) - dly) % n
		i0 = np.floor(idx).astype(int)
		fr = (idx - i0)[:, None]
		out += x[i0] * (1 - fr) + x[(i0 + 1) % n] * fr
	y = x * 0.55 + out * 0.45
	# enxame: ruído em banda 250–700 Hz, modulado por zumbido de asas (periódico)
	t = C.tvec(n)
	f_w = C.periodic_freq(170.0, n / SR)
	buzz = C.bp(C.noise(n, 990), 250, 700) * (0.6 + 0.4 * np.sin(2 * np.pi * f_w * t))
	buzz = circ(lambda z: z, buzz) * (0.5 + 0.5 * lfo(n, 12.0)) * 0.05
	return y + np.stack([buzz, np.roll(buzz, 777)], axis=1)


def v_coroa(x, bt):
	rate = 2 ** (1 / 12)
	y = tape(x, rate)
	bt = bt / rate
	shine = circ(lambda z: C.hp(z, 4000, order=2), y)
	y = y + shine * 0.35
	lay = np.zeros_like(y)
	for i, b in enumerate(bt):
		if i % 4 == 0:
			place_circ(lay, timpani(73.4 * rate, 1.0, seed=1000 + i % 5), b, -4.0 if i % 16 == 0 else -9.0)
	return y + lay * 0.5


VARIANTS = {
	"torpor": v_torpor, "fome": v_fome, "corrente": v_corrente, "silencio": v_silencio,
	"espelho": v_espelho, "praga": v_praga, "coroa": v_coroa,
}


def seam_ok(y):
	"""Salto na emenda em múltiplos do passo típico (≈1 = contínuo)."""
	m = y.mean(axis=1)
	d = np.abs(np.diff(m))
	typ = float(np.median(d[d > 0]))
	return abs(float(m[0]) - float(m[-1])) / max(typ, 1e-9)


def describe(x):
	m = x.mean(axis=1)
	f, P = signal.welch(m, SR, nperseg=8192)
	cent = float((f * P).sum() / P.sum())
	low = 10 * np.log10(P[f < 150].sum() / P.sum())
	high = 10 * np.log10(P[f > 4000].sum() / P.sum())
	width = float(np.sqrt(np.mean((x[:, 0] - x[:, 1]) ** 2)) / (np.sqrt(np.mean((x[:, 0] + x[:, 1]) ** 2)) + 1e-12))
	return {"centro_Hz": int(cent), "grave_<150Hz_dB": round(low, 1), "agudo_>4kHz_dB": round(high, 1),
		"largura_S/M": round(width, 2)}


def main():
	args = sys.argv[1:]
	x = C.load(SRC, mono=False).astype(np.float64)
	if args and args[0] == "--install":
		eon = args[1]
		bt = beats(x)
		y = master(VARIANTS[eon](x, bt))
		dst = os.path.join(C.MUSIC_DIR, "boss_%s.ogg" % eon)
		C.write_ogg(dst, y.astype(np.float32), quality=4)
		print("instalado:", dst)
		return
	out = args[0] if args else OUT_DEFAULT
	os.makedirs(out, exist_ok=True)
	bt = beats(x)
	ibi = np.diff(bt)
	rep = {"fonte": "music/boss.ogg", "dur_s": round(len(x) / SR, 2), "batidas": len(bt),
		"bpm": round(60.0 / float(np.median(ibi)), 1), "boss": describe(x), "variacoes": {}}
	print("boss.ogg: %.1f s, %d batidas, %.1f bpm" % (len(x) / SR, len(bt), rep["bpm"]))
	for eon, fn in VARIANTS.items():
		y = master(fn(x, bt))
		path = os.path.join(out, "boss_%s.ogg" % eon)
		C.write_ogg(path, y.astype(np.float32), quality=4)
		# prévia: 20 s do começo + emenda (8 s finais → 8 s iniciais)
		k = 8 * SR
		C.write_ogg(os.path.join(out, "boss_%s_emenda.ogg" % eon), np.concatenate([y[-k:], y[:k]]).astype(np.float32), 4)
		d = describe(y)
		d.update({"arconte": ARCONTES[eon], "dur_s": round(len(y) / SR, 2),
			"LUFS": round(C.integrated_lufs(y), 1), "TP_dBTP": round(C.true_peak_db(y), 1),
			"LRA": round(C.lra(y), 1), "emenda_salto": round(seam_ok(y), 2)})
		rep["variacoes"][eon] = d
		print(eon, d)
	with open(os.path.join(out, "boss_variantes.json"), "w", encoding="utf-8") as f:
		json.dump(rep, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
	main()
