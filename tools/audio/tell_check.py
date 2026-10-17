# -*- coding: utf-8 -*-
"""
Mede, sem ouvir, se os avisos do combate (tell_parry / tell_unblock) são
LEGÍVEIS sob a música e DISTINTOS do resto do catálogo.

  python3 tools/audio/tell_check.py [saida.json]

1) Leitura sob música: mistura cada aviso por cima de 40 trechos sorteados
   (semente fixa) de `boss` e das 7 músicas de Éon, nos níveis do jogo
   (slider padrão: Música 0,6, SFX 0,9; Éon −3 dB) e compara, banda a banda
   (1/3 de oitava, 100 Hz–12 kHz), a energia do aviso com a da música na
   janela do aviso. Regra prática de mascaramento: um som curto é ouvido e
   reconhecido quando passa a música por ≥ +6 dB em pelo menos uma banda
   crítica; usamos "≥ +6 dB em ≥ 2 bandas" para ter folga (alto-falante ruim
   perde uma banda).
2) Distinção: vetor de MFCC médio (13 coef., sem o C0) + centro espectral e
   duração; lista os 3 vizinhos mais próximos de cada aviso no catálogo.
"""
import os, sys, glob, json
import numpy as np
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
AUDIO = os.path.join(ROOT, "assets", "audio")
SR = 44100
MUSIC_VOL = 0.6
SFX_VOL = 0.9
EON_DB = -3.0
TELLS = {"tell_parry": 0.15, "tell_unblock": 0.30}   # janela de leitura (s)


def load(path):
	x, sr = sf.read(path, dtype="float64", always_2d=True)
	x = x.mean(axis=1)
	if sr != SR:
		x = signal.resample_poly(x, SR, sr)
	return x


def bands():
	c = 100.0 * 2 ** (np.arange(0, 22) / 3.0)
	return [(f / 2 ** (1 / 6), f * 2 ** (1 / 6), f) for f in c if f * 2 ** (1 / 6) < 13000]


BANDS = bands()


def band_energy(x):
	X = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
	f = np.fft.rfftfreq(len(x), 1 / SR)
	return np.array([X[(f >= lo) & (f < hi)].sum() + 1e-18 for lo, hi, _ in BANDS])


def legibility(tell, music, win, rnd, n=40):
	w = int(win * SR)
	t = tell[:w] * 10 ** (20 * np.log10(SFX_VOL) / 20)
	et = band_energy(np.r_[t, np.zeros(max(0, w - len(t)))])
	best, good = [], []
	for _ in range(n):
		a = rnd.integers(0, len(music) - w)
		em = band_energy(music[a:a + w])
		snr = 10 * np.log10(et / em)
		best.append(float(snr.max()))
		good.append(int((snr >= 6.0).sum()))
	best = np.array(best)
	good = np.array(good)
	return {
		"melhor_banda_dB_mediana": round(float(np.median(best)), 1),
		"melhor_banda_dB_p10": round(float(np.percentile(best, 10)), 1),
		"bandas_6dB_mediana": int(np.median(good)),
		"trechos_ok_pct": round(100.0 * float((good >= 2).mean()), 0),
		"banda_mais_forte_Hz": int(BANDS[int(np.argmax(et))][2]),
	}


def mel_fb(nfft, nmel=26):
	def hz2m(h): return 2595 * np.log10(1 + h / 700)
	def m2hz(m): return 700 * (10 ** (m / 2595) - 1)
	pts = m2hz(np.linspace(hz2m(60), hz2m(12000), nmel + 2))
	bins = np.floor((nfft + 1) * pts / SR).astype(int)
	fb = np.zeros((nmel, nfft // 2 + 1))
	for i in range(1, nmel + 1):
		l, c, r = bins[i - 1], bins[i], bins[i + 1]
		fb[i - 1, l:c] = (np.arange(l, c) - l) / max(c - l, 1)
		fb[i - 1, c:r] = (r - np.arange(c, r)) / max(r - c, 1)
	return fb


FB = mel_fb(2048)


def features(x):
	f, t, Z = signal.stft(x, SR, nperseg=2048, noverlap=1536)
	P = np.abs(Z) ** 2
	e = P.sum(axis=0)
	act = e > e.max() * 1e-3
	P = P[:, act] if act.any() else P
	mel = np.log(FB @ P + 1e-12)
	from scipy.fft import dct
	mf = dct(mel, axis=0, norm="ortho")[1:14].mean(axis=1)
	cent = float((f[:, None] * P).sum() / (P.sum() + 1e-18))
	env = np.abs(signal.hilbert(x))
	dur = float((env > env.max() * 0.1).sum() / SR)
	sm = np.convolve(env, np.ones(441) / 441, mode="same")     # 10 ms
	start = int(np.argmax(sm > sm.max() * 0.1))
	att = float((int(np.argmax(sm)) - start) / SR)             # s até o pico
	return mf, cent, dur, att


def main():
	out_path = sys.argv[1] if len(sys.argv) > 1 else None
	rnd = np.random.default_rng(2026)
	mus = {"boss": 0.0}
	for e in ["torpor", "fome", "corrente", "silencio", "espelho", "praga", "coroa"]:
		mus["eon_" + e] = EON_DB
	music = {k: load(os.path.join(AUDIO, "music", k + ".ogg")) * 10 ** ((20 * np.log10(MUSIC_VOL) + g) / 20)
		for k, g in mus.items()}
	rep = {"leitura": {}, "vizinhos": {}, "medidas": {}}
	for name, win in TELLS.items():
		x = load(os.path.join(AUDIO, "sfx", name + ".ogg"))
		rep["leitura"][name] = {k: legibility(x, m, win, rnd) for k, m in music.items()}
	feats = {}
	for p in sorted(glob.glob(os.path.join(AUDIO, "sfx", "*.ogg"))):
		feats[os.path.basename(p)[:-4]] = features(load(p))
	for name in TELLS:
		mf, cent, dur, att = feats[name]
		rep["medidas"][name] = {"centro_Hz": int(cent), "dur_s": round(dur, 2), "ataque_s": round(att, 3)}
		d = []
		for k, (mf2, c2, d2, a2) in feats.items():
			if k == name:
				continue
			d.append((float(np.linalg.norm(mf - mf2)), k, int(c2), round(a2, 3)))
		d.sort()
		rep["vizinhos"][name] = [{"som": k, "dist": round(v, 1), "centro_Hz": c, "ataque_s": a} for v, k, c, a in d[:3]]
	rep["confundiveis"] = {}
	for name in TELLS:
		rep["confundiveis"][name] = {k: round(float(np.linalg.norm(feats[name][0] - feats[k][0])), 1)
			for k in ["spark", "parry", "block", "hit", "boss_step", "ui_confirm", "shard", "heartbeat"] if k in feats}
	a, b = feats["tell_parry"][0], feats["tell_unblock"][0]
	rep["dist_parry_unblock"] = round(float(np.linalg.norm(a - b)), 1)
	# mediana das distâncias entre variações do mesmo som (régua do "parecido")
	same = []
	for k in feats:
		if k.endswith("_2") and k[:-2] in feats:
			same.append(float(np.linalg.norm(feats[k][0] - feats[k[:-2]][0])))
	rep["dist_mediana_entre_variacoes"] = round(float(np.median(same)), 1) if same else None
	txt = json.dumps(rep, ensure_ascii=False, indent=1)
	print(txt)
	if out_path:
		with open(out_path, "w", encoding="utf-8") as f:
			f.write(txt)


if __name__ == "__main__":
	main()
