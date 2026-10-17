# -*- coding: utf-8 -*-
"""
Base comum do pipeline de áudio do GNOSIS (tools/audio_synth/).

Tudo aqui é determinístico (sementes fixas) e só usa numpy/scipy/soundfile +
ffmpeg (encoder Vorbis). Nada disto roda no jogo: é ferramenta de pipeline
que GERA os .ogg versionados em assets/audio/.

  · I/O (carregar pack, gravar OGG Vorbis via ffmpeg)
  · loudness BS.1770-4 (K-weighting, momentânea, integrada com gating, true peak)
  · limitador com lookahead
  · primitivas de síntese (osciladores, ruído, sino modal, voz por formantes,
    reverb sintético linear e circular)

Convenção de loudness: arquivo MONO é medido como dual-mono (+3,01 dB), porque
o Godot toca mono igual nos dois canais — assim SFX mono e música estéreo ficam
na mesma régua.
"""
import os, sys, glob, subprocess, tempfile
import numpy as np
import soundfile as sf
from scipy import signal
from scipy.ndimage import minimum_filter1d

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
AUDIO = os.path.join(ROOT, "assets", "audio")
SFX_DIR = os.path.join(AUDIO, "sfx")
MUSIC_DIR = os.path.join(AUDIO, "music")
AMB_DIR = os.path.join(AUDIO, "amb")
# Packs brutos (fora do git — só existem na cópia original do projeto).
PACKS = os.environ.get(
	"GNOSIS_PACKS",
	r"C:\Users\jmtat\OneDrive\Desktop\Gnosis-Codex - Copia\assets\_packs",
)
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")


def rng(seed):
	"""Gerador determinístico (toda síntese usa semente fixa)."""
	return np.random.default_rng(seed)


def db(x):
	return 10.0 ** (x / 20.0)


def to_db(x):
	return 20.0 * np.log10(max(float(x), 1e-12))


# ----------------------------------------------------------------------------
# I/O
# ----------------------------------------------------------------------------

_index = None


def find(basename):
	"""Acha um arquivo dos packs pelo nome-base (ignora __MACOSX)."""
	global _index
	if _index is None:
		if not os.path.isdir(PACKS):
			raise SystemExit("Packs não encontrados em %s (defina GNOSIS_PACKS)" % PACKS)
		_index = {}
		for p in glob.glob(os.path.join(PACKS, "**", "*"), recursive=True):
			if "__MACOSX" in p or not os.path.isfile(p) or p.endswith(".import"):
				continue
			_index.setdefault(os.path.basename(p), p)
	if basename not in _index:
		raise FileNotFoundError(basename)
	return _index[basename]


def load(path, mono=True):
	"""Carrega qualquer áudio (wav/ogg/mp3) em float32 a 44,1 kHz.
	mono=True → (n,) ; mono=False → (n,2)."""
	data, sr = sf.read(path, dtype="float32", always_2d=True)
	if sr != SR:
		g = np.gcd(int(sr), SR)
		data = signal.resample_poly(data, SR // g, int(sr) // g, axis=0).astype(np.float32)
	if mono:
		return data.mean(axis=1)
	if data.shape[1] == 1:
		data = np.repeat(data, 2, axis=1)
	return data[:, :2]


def write_ogg(path, x, quality=5):
	"""Grava OGG Vorbis (44,1 kHz) via ffmpeg/libvorbis. x: (n,) ou (n,2)."""
	x = np.asarray(x, dtype=np.float32)
	os.makedirs(os.path.dirname(path), exist_ok=True)
	fd, tmp = tempfile.mkstemp(suffix=".wav")
	os.close(fd)
	try:
		sf.write(tmp, x, SR, subtype="FLOAT")
		cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", tmp,
			"-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", str(quality), path]
		subprocess.run(cmd, check=True)
	finally:
		os.remove(tmp)


# ----------------------------------------------------------------------------
# Loudness (ITU-R BS.1770-4)
# ----------------------------------------------------------------------------

def _k_sos(sr=SR):
	# Estágio 1: prateleira alta (+4 dB ~1,7 kHz) — fórmula do pyloudnorm/ITU.
	G, Q, fc = 3.999843853973347, 0.7071752369554196, 1681.974450955533
	A = 10 ** (G / 40.0)
	w0 = 2 * np.pi * fc / sr
	al = np.sin(w0) / (2 * Q)
	c = np.cos(w0)
	b = [A * ((A + 1) + (A - 1) * c + 2 * np.sqrt(A) * al),
		-2 * A * ((A - 1) + (A + 1) * c),
		A * ((A + 1) + (A - 1) * c - 2 * np.sqrt(A) * al)]
	a = [(A + 1) - (A - 1) * c + 2 * np.sqrt(A) * al,
		2 * ((A - 1) - (A + 1) * c),
		(A + 1) - (A - 1) * c - 2 * np.sqrt(A) * al]
	s1 = np.r_[np.array(b) / a[0], np.array(a) / a[0]]
	# Estágio 2: passa-altas RLB (~38 Hz).
	fc2, Q2 = 38.13547087602444, 0.5003270373238773
	w0 = 2 * np.pi * fc2 / sr
	al = np.sin(w0) / (2 * Q2)
	c = np.cos(w0)
	a = [1 + al, -2 * c, 1 - al]
	s2 = np.r_[np.array([1.0, -2.0, 1.0]) / a[0], np.array(a) / a[0]]
	return np.vstack([s1, s2])


_KSOS = _k_sos()


def _as2(x):
	x = np.asarray(x, dtype=np.float64)
	if x.ndim == 1:
		return np.stack([x, x], axis=1)   # mono = dual-mono
	return x


def _block_power(x, win_s=0.4, hop_s=0.1):
	"""Potência K-ponderada por bloco (soma dos canais)."""
	x = _as2(x)
	y = signal.sosfilt(_KSOS, x, axis=0)
	p = (y ** 2).sum(axis=1)
	w = int(win_s * SR)
	h = max(1, int(hop_s * SR))
	if len(p) < w:
		p = np.r_[p, np.zeros(w - len(p))]
	c = np.r_[0.0, np.cumsum(p)]
	starts = np.arange(0, len(p) - w + 1, h)
	return (c[starts + w] - c[starts]) / w


def _lufs(power):
	return -0.691 + 10 * np.log10(np.maximum(power, 1e-12))


def integrated_lufs(x):
	"""Loudness integrada com gating absoluto (-70) e relativo (-10 LU)."""
	pw = _block_power(x, 0.4, 0.1)
	l = _lufs(pw)
	g = pw[l > -70]
	if len(g) == 0:
		return -70.0
	rel = _lufs(g.mean()) - 10
	g2 = pw[(l > -70) & (l > rel)]
	return float(_lufs(g2.mean())) if len(g2) else -70.0


def max_momentary(x):
	"""Maior loudness momentânea (janela 400 ms, passo 10 ms) — régua dos SFX."""
	return float(_lufs(_block_power(x, 0.4, 0.01)).max())


def short_term_lufs(x, hop_s=1.0):
	return _lufs(_block_power(x, 3.0, hop_s))


def lra(x):
	"""Faixa de loudness (EBU 3342) aproximada."""
	st = short_term_lufs(x, 0.1)
	st = st[st > -70]
	if len(st) == 0:
		return 0.0
	pw = 10 ** ((st + 0.691) / 10)
	rel = _lufs(pw.mean()) - 20
	st = st[st > rel]
	return float(np.percentile(st, 95) - np.percentile(st, 10)) if len(st) else 0.0


def true_peak_db(x):
	x = np.asarray(x, dtype=np.float64)
	if x.ndim == 1:
		x = x[:, None]
	up = signal.resample_poly(x, 4, 1, axis=0)
	return to_db(np.abs(up).max())


def sample_peak_db(x):
	return to_db(np.abs(np.asarray(x)).max())


# ----------------------------------------------------------------------------
# Dinâmica
# ----------------------------------------------------------------------------

def limit(x, ceiling_db=-1.0, lookahead_ms=1.5, release_ms=80.0, block=32):
	"""Limitador de pico com lookahead (ganho por bloco, release exponencial).
	Garante |x| <= teto (com clip de segurança no fim)."""
	x = np.asarray(x, dtype=np.float64)
	st = x.ndim == 2
	a = np.abs(x).max(axis=1) if st else np.abs(x)
	c = db(ceiling_db)
	n = len(a)
	nb = (n + block - 1) // block
	pad = np.r_[a, np.zeros(nb * block - n)]
	bmax = pad.reshape(nb, block).max(axis=1)
	g = np.minimum(1.0, c / np.maximum(bmax, 1e-12))
	la = max(1, int(lookahead_ms * SR / 1000 / block))
	g = minimum_filter1d(g, size=2 * la + 1, mode="nearest")
	k = np.exp(-block / (release_ms * SR / 1000))
	out = np.empty_like(g)
	cur = 1.0
	for i in range(nb):                 # release: sobe devagar, desce na hora
		gi = g[i]
		cur = gi if gi < cur else gi + (cur - gi) * k
		out[i] = cur
	centers = np.arange(nb) * block + block / 2
	gs = np.interp(np.arange(n), centers, out)
	y = x * (gs[:, None] if st else gs)
	return np.clip(y, -c, c)


def fade(x, fin=0.004, fout=0.004):
	x = np.array(x, dtype=np.float64, copy=True)
	n = len(x)
	a = min(int(fin * SR), n // 2)
	b = min(int(fout * SR), n // 2)
	sh = (slice(None),) + ((None,) if x.ndim == 2 else ())
	if a > 0:
		x[:a] *= np.linspace(0, 1, a)[sh]
	if b > 0:
		x[-b:] *= np.linspace(1, 0, b)[sh]
	return x


def trim_start(x, thresh_db=-45.0, pre_ms=3.0):
	t = db(thresh_db)
	a = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
	idx = int(np.argmax(a > t))
	if idx > 0:
		idx = max(0, idx - int(pre_ms / 1000 * SR))
	return x[idx:]


def trim_end(x, thresh_db=-60.0, keep_ms=20.0):
	t = db(thresh_db)
	a = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
	nz = np.nonzero(a > t)[0]
	if len(nz) == 0:
		return x
	end = min(len(x), nz[-1] + int(keep_ms / 1000 * SR))
	return x[:end]


def resample_pitch(x, pitch):
	"""Muda o tom reamostrando (pitch>1 = mais agudo e mais curto)."""
	if pitch == 1.0:
		return x
	n = int(len(x) / pitch)
	if n < 2:
		return x
	src = np.linspace(0.0, len(x) - 1, n)
	if x.ndim == 1:
		return np.interp(src, np.arange(len(x)), x)
	return np.stack([np.interp(src, np.arange(len(x)), x[:, c]) for c in range(x.shape[1])], axis=1)


def place(dst, src, at_s, gain_db=0.0):
	"""Soma `src` em `dst` a partir de at_s segundos (corta o que passar)."""
	at = int(round(at_s * SR))
	if at >= len(dst):
		return dst
	n = min(len(src), len(dst) - at)
	if n > 0:
		dst[at:at + n] += src[:n] * db(gain_db)
	return dst


def mix_to(n, *layers):
	out = np.zeros(n)
	for (x, at, g) in layers:
		place(out, x, at, g)
	return out


# ----------------------------------------------------------------------------
# Filtros
# ----------------------------------------------------------------------------

def lp(x, fc, order=2):
	return signal.sosfilt(signal.butter(order, min(fc, SR * 0.45), "low", fs=SR, output="sos"), x, axis=0)


def hp(x, fc, order=2):
	return signal.sosfilt(signal.butter(order, fc, "high", fs=SR, output="sos"), x, axis=0)


def bp(x, lo, hi, order=2):
	return signal.sosfilt(signal.butter(order, [lo, min(hi, SR * 0.45)], "band", fs=SR, output="sos"), x, axis=0)


def resonator(x, f, q):
	"""Ressonador (pico) de 2ª ordem."""
	b, a = signal.iirpeak(f, q, fs=SR)
	return signal.lfilter(b, a, x, axis=0)


def fft_shape(x, gain_fn):
	"""Filtro CIRCULAR no domínio da frequência (sinal periódico continua
	periódico — base das ambiências em loop perfeito). gain_fn(freqs)->ganho."""
	X = np.fft.rfft(x, axis=0)
	f = np.fft.rfftfreq(len(x), 1 / SR)
	g = gain_fn(f)
	if X.ndim == 2:
		g = g[:, None]
	return np.fft.irfft(X * g, n=len(x), axis=0)


# ----------------------------------------------------------------------------
# Síntese
# ----------------------------------------------------------------------------

def tvec(n):
	return np.arange(n) / SR


def env_ad(n, attack, decay_tau, hold=0.0):
	"""Envelope ataque linear + decaimento exponencial (tau em s)."""
	t = tvec(n)
	a = np.clip(t / max(attack, 1e-4), 0, 1)
	d = np.where(t < attack + hold, 1.0, np.exp(-(t - attack - hold) / max(decay_tau, 1e-4)))
	return a * d


def env_swell(n, peak_at, fall):
	"""Sobe em curva (seno²) até peak_at e cai exponencial."""
	t = tvec(n)
	up = np.sin(np.clip(t / max(peak_at, 1e-4), 0, 1) * np.pi / 2) ** 2
	return np.where(t < peak_at, up, np.exp(-(t - peak_at) / max(fall, 1e-4)))


def osc_phase(freq, n):
	"""Fase integrada (freq escalar ou curva por amostra)."""
	f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
	return 2 * np.pi * np.cumsum(f) / SR


def additive(phase, amps):
	"""Soma de harmônicos k=1..K com amplitudes `amps` (K,) ou (n,K)."""
	amps = np.asarray(amps)
	K = amps.shape[-1]
	out = np.zeros(len(phase))
	for k in range(1, K + 1):
		a = amps[..., k - 1]
		if np.all(np.asarray(a) == 0):
			continue
		out += a * np.sin(k * phase)
	return out


def saw_bl(freq, n, nh=40, tilt=1.0):
	"""Dente-de-serra limitado em banda (aditivo; tilt=1 → 1/k)."""
	ph = osc_phase(freq, n)
	f0 = float(np.max(np.asarray(freq)))
	K = max(1, min(nh, int((SR * 0.45) / max(f0, 1))))
	return additive(ph, np.array([1.0 / k ** tilt for k in range(1, K + 1)]))


def noise(n, seed, stereo=False):
	r = rng(seed)
	return r.standard_normal((n, 2) if stereo else n)


def pink(n, seed, stereo=False):
	"""Ruído rosa (1/f) por moldagem FFT — circular (loopa perfeito)."""
	w = noise(n, seed, stereo)
	return fft_shape(w, lambda f: 1.0 / np.sqrt(np.maximum(f, 20.0))) * 8.0


def band_noise(n, seed, lo, hi, stereo=False, circular=True):
	w = noise(n, seed, stereo)
	if circular:
		def g(f):
			r = np.zeros_like(f)
			m = (f >= lo) & (f <= hi)
			r[m] = 1.0
			# bordas suaves (meia oitava)
			lo2 = (f > lo / 1.41) & (f < lo)
			r[lo2] = ((f[lo2] - lo / 1.41) / (lo - lo / 1.41))
			hi2 = (f > hi) & (f < hi * 1.41)
			r[hi2] = 1 - ((f[hi2] - hi) / (hi * 1.41 - hi))
			return r
		return fft_shape(w, g)
	return bp(w, lo, hi)


# Sino modal: razões típicas de sino de igreja (hum, prime, terça menor, quinta,
# nominal, ...), com decaimentos maiores nos graves.
BELL_PARTIALS = [(0.5, 0.55, 1.0), (1.0, 1.0, 0.8), (1.19, 0.6, 0.55), (1.5, 0.45, 0.45),
	(2.0, 0.65, 0.4), (2.52, 0.3, 0.3), (3.0, 0.25, 0.22), (4.07, 0.18, 0.15), (5.4, 0.1, 0.1)]


def bell(f, dur, decay=2.5, seed=0, bright=1.0, partials=None):
	"""Sino por síntese modal. f = nota 'prime'."""
	n = int(dur * SR)
	t = tvec(n)
	r = rng(seed)
	out = np.zeros(n)
	for (ratio, amp, dk) in (partials or BELL_PARTIALS):
		fr = f * ratio * (1 + r.uniform(-0.002, 0.002))
		if fr > SR * 0.45:
			continue
		a = amp * (bright if ratio > 2 else 1.0)
		beat = 1 + 0.08 * np.sin(2 * np.pi * r.uniform(0.3, 1.5) * t)   # batimento
		out += a * beat * np.sin(2 * np.pi * fr * t + r.uniform(0, 6.28)) * np.exp(-t / (decay * dk))
	strike = noise(n, seed + 1) * np.exp(-t / 0.004) * 0.15
	return fade((out + hp(strike, 2000)) * np.clip(t / 0.002, 0, 1), 0, 0.01)


def metal_clang(f, dur, seed=0, decay=0.6):
	"""Metal inarmônico (elo de corrente, bigorna): parciais de barra livre."""
	ratios = [1.0, 2.756, 5.404, 8.933, 13.34, 1.47, 3.9]
	n = int(dur * SR)
	t = tvec(n)
	r = rng(seed)
	out = np.zeros(n)
	for i, ra in enumerate(ratios):
		fr = f * ra * (1 + r.uniform(-0.01, 0.01))
		if fr > SR * 0.45:
			continue
		out += (0.9 ** i) * np.sin(2 * np.pi * fr * t + r.uniform(0, 6.28)) * np.exp(-t / (decay / (1 + 0.3 * i)))
	click = hp(noise(n, seed + 7) * np.exp(-t / 0.002), 3000) * 0.4
	return fade(out + click, 0, 0.01)


# Formantes (F, ganho dB, largura Hz) por vogal — tabela Csound (soprano/baixo).
VOWELS = {
	"a": [(800, 0, 80), (1150, -6, 90), (2900, -32, 120), (3900, -20, 130)],
	"e": [(350, 0, 60), (2000, -20, 100), (2800, -15, 120), (3600, -40, 150)],
	"i": [(270, 0, 60), (2140, -12, 90), (2950, -26, 100), (3900, -26, 120)],
	"o": [(450, 0, 70), (800, -11, 80), (2830, -22, 100), (3800, -22, 130)],
	"u": [(325, 0, 50), (700, -16, 60), (2700, -35, 170), (3800, -40, 180)],
}


def formant_gain(freqs, vowel, shift=1.0):
	"""Envelope espectral da vogal (Lorentzianas somadas)."""
	g = np.zeros_like(freqs, dtype=np.float64)
	for (F, gdb, B) in VOWELS[vowel]:
		F *= shift
		g += db(gdb) / (1 + ((freqs - F) / (B * 0.5 * shift)) ** 2)
	return g


def voice(f0, n, vowel="a", shift=1.0, vowel2=None, breath=0.0, seed=0, nh=60, vib=(5.0, 0.0)):
	"""Voz cantada por síntese aditiva com formantes.
	f0: escalar ou curva; vowel2: morfa de vowel → vowel2 ao longo do som;
	vib=(taxa Hz, profundidade em fração)."""
	t = tvec(n)
	f0c = np.broadcast_to(np.asarray(f0, dtype=np.float64), (n,)).copy()
	if vib[1] > 0:
		f0c *= 1 + vib[1] * np.sin(2 * np.pi * vib[0] * t)
	ph = osc_phase(f0c, n)
	out = np.zeros(n)
	K = max(1, min(nh, int(SR * 0.45 / max(f0c.max(), 1))))
	mix = np.linspace(0, 1, n) if vowel2 else None
	for k in range(1, K + 1):
		fk = k * f0c
		g = formant_gain(fk, vowel, shift)
		if vowel2:
			g = g * (1 - mix) + formant_gain(fk, vowel2, shift) * mix
		g = g / k ** 0.6     # inclinação da fonte glotal (já com radiação)
		g[fk > SR * 0.45] = 0
		out += g * np.sin(k * ph)
	if breath > 0:
		w = noise(n, seed + 99)
		nb = np.zeros(n)
		for (F, gdb, B) in VOWELS[vowel]:
			nb += resonator(w, min(F * shift, SR * 0.4), max(2.0, F * shift / B)) * db(gdb)
		out += nb * breath
	return out


def ir(rt60=2.0, predelay=0.02, seed=5, lp_hz=7000, stereo=True, damp_hz=None):
	"""Resposta ao impulso sintética (ruído com decaimento exponencial)."""
	n = int((predelay + rt60 * 1.1) * SR)
	t = tvec(n)
	r = rng(seed)
	w = r.standard_normal((n, 2) if stereo else n)
	e = np.exp(-6.9 * np.clip(t - predelay, 0, None) / rt60) * (t >= predelay)
	h = w * (e[:, None] if stereo else e)
	h = lp(h, lp_hz)
	if damp_hz:   # agudos morrem antes
		late = lp(h, damp_hz)
		k = np.clip((t - predelay) / (rt60 * 0.5), 0, 1)
		k = k[:, None] if stereo else k
		h = h * (1 - k) + late * k
	h /= np.sqrt((h ** 2).sum(axis=0).mean())
	return h


def reverb(x, rt60=2.0, wet=0.3, predelay=0.02, seed=5, lp_hz=7000, tail=True):
	"""Reverb linear (convolução). Mono entra → estéreo sai."""
	h = ir(rt60, predelay, seed, lp_hz)
	xm = x if x.ndim == 1 else x.mean(axis=1)
	wetsig = np.stack([signal.fftconvolve(xm, h[:, c]) for c in range(2)], axis=1)
	dry = np.stack([x, x], axis=1) if x.ndim == 1 else x
	n = len(wetsig) if tail else len(dry)
	out = np.zeros((n, 2))
	out[:len(dry)] += dry * (1 - wet * 0.5)
	out += wetsig[:n] * wet
	return out


def reverb_circular(x, rt60=3.0, wet=0.3, predelay=0.03, seed=5, lp_hz=6000):
	"""Reverb por convolução CIRCULAR: num sinal periódico (loop), o rabo do
	fim cai no começo — exatamente como soaria tocando em loop infinito."""
	n = len(x)
	h = ir(rt60, predelay, seed, lp_hz)
	if len(h) > n:
		h = h[:n]
	H = np.fft.rfft(h, n=n, axis=0)
	xs = np.stack([x, x], axis=1) if x.ndim == 1 else x
	X = np.fft.rfft(xs, axis=0)
	w = np.fft.irfft(X * H, n=n, axis=0)
	return xs * (1 - wet * 0.5) + w * wet


def pan(x, p):
	"""Pan de potência constante: p=-1 esq, 0 centro, 1 dir."""
	a = (p + 1) * np.pi / 4
	return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def periodic_freq(f, loop_s):
	"""Arredonda f pra caber um nº inteiro de ciclos no loop (fase contínua)."""
	return max(1, round(f * loop_s)) / loop_s


def normalize_peak(x, peak_db=-1.0):
	p = np.abs(x).max()
	return x * (db(peak_db) / p) if p > 0 else x


def to_loudness(x, target, mode="momentary", ceiling_db=-1.0):
	"""Leva o som ao alvo de loudness (LUFS) e limita o pico no teto."""
	cur = max_momentary(x) if mode == "momentary" else integrated_lufs(x)
	y = x * db(target - cur)
	for _ in range(3):     # o limitador derruba um pouco — compensa
		if np.abs(y).max() > db(ceiling_db):
			y = limit(y, ceiling_db)
		now = max_momentary(y) if mode == "momentary" else integrated_lufs(y)
		if abs(now - target) < 0.3:
			break
		y = y * db(target - now)
	if np.abs(y).max() > db(ceiling_db):
		y = limit(y, ceiling_db)
	return y
