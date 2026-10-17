# -*- coding: utf-8 -*-
"""
Masteriza as 14 músicas do GNOSIS a partir dos MP3 originais (Kevin MacLeod,
incompetech.com, CC-BY 4.0) e conserta a EMENDA do loop.

  python tools/audio_synth/build_music.py            # todas
  python tools/audio_synth/build_music.py boss rei   # só algumas

O que faz, por faixa:
 1. Lê o MP3 do pack (fonte de 1ª geração — não re-encoda o OGG antigo).
 2. Corta silêncio das pontas.
 3. ACHA O PONTO DE LOOP: entre 55 % da faixa e (fim − 5 s), procura o instante
    `s` cujo trecho [s, s+X] mais se parece com o começo [0, X] (cromagrama +
    timbre MFCC + força de ataque, quadro a quadro, e loudness parecida).
    O final da peça (acorde final / fade) fica de fora.
 4. Ajuste fino por correlação de forma de onda (±25 ms) pra casar a fase.
 5. Loop = x[0:s]; os primeiros X segundos viram crossfade de x[s:s+X] → x[0:X],
    com ganho compensado pela correlação (nem buraco nem calombo). Na volta,
    a última amostra (x[s-1]) emenda na primeira (≈ x[s]) — contínuo por
    construção. Sem loop_offset (o Godot volta no 0).
 6. Normaliza a −16 LUFS integrado (ver TARGET), true peak ≤ −1 dBTP com
    limitador de lookahead, e grava OGG Vorbis q4.
`roubo` toca uma vez (sem loop): só corte de cauda + normalização.
"""
import os, sys, json
import numpy as np
import librosa
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C

MUSIC = {
	"theme":        "Gregorian Chant",
	"rei":          "Lord of the Land",
	"eon_torpor":   "Ossuary 1 - A Beginning",
	"eon_fome":     "Ritual",
	"eon_corrente": "Oppressive Gloom",
	"eon_silencio": "Ossuary 5 - Rest",
	"eon_espelho":  "Ossuary 6 - Air",
	"eon_praga":    "Unseen Horrors",
	"eon_coroa":    "Crossing the Chasm",
	"boss":         "Volatile Reaction",
	"roubo":        "Anguish",
	"centro":       "Echoes of Time",
	"mente":        "Night of Chaos",
	"epilogo":      "Bittersweet",
}
NO_LOOP = {"roubo"}
TARGET = -16.0                 # LUFS integrado
TARGET_OVERRIDE = {"eon_silencio": -17.5}   # "quase silêncio": um pouco abaixo
MAX_GR = 3.0                   # corte máximo do limitador nos picos (dB)
CEIL_DB = -1.5                 # teto de amostra do limitador (→ TP ≲ −1 dBTP)
MAX_LOOP_S = 285.0             # tamanho máximo do loop (arquivo)
XFADE = {"default": 2.5, "eon_silencio": 4.0, "eon_espelho": 4.0, "eon_torpor": 4.0, "centro": 3.5}
HOP = 1024


def features(m):
	"""Matriz de features por quadro (T × d), normalizada por linha."""
	chroma = librosa.feature.chroma_stft(y=m, sr=C.SR, hop_length=HOP, n_fft=4096)
	mfcc = librosa.feature.mfcc(y=m, sr=C.SR, hop_length=HOP, n_mfcc=13)
	mfcc = (mfcc - mfcc.mean(axis=1, keepdims=True)) / (mfcc.std(axis=1, keepdims=True) + 1e-6)
	onset = librosa.onset.onset_strength(y=m, sr=C.SR, hop_length=HOP)[None, :]
	onset = (onset - onset.mean()) / (onset.std() + 1e-6)
	T = min(chroma.shape[1], mfcc.shape[1], onset.shape[1])
	ch = chroma[:, :T] / (np.linalg.norm(chroma[:, :T], axis=0, keepdims=True) + 1e-6)
	mf = mfcc[:, :T] / (np.linalg.norm(mfcc[:, :T], axis=0, keepdims=True) + 1e-6)
	rms = librosa.feature.rms(y=m, frame_length=4096, hop_length=HOP)[0, :T]
	return ch.T, mf.T, onset[0, :T], 20 * np.log10(rms + 1e-9)


def find_loop(x, xf_s):
	"""Acha (a, s): o loop é x[a:s] e o trecho [s, s+X] deve soar como [a, a+X].
	`a` (início do loop) pode pular a introdução (até 25 % / 40 s) quando isso
	dá emenda muito melhor; s fica entre 55 % da faixa e (fim − 5 s)."""
	from scipy import signal as sg
	m = x.mean(axis=1).astype(np.float32)
	ch, mf, on, rdb = features(m)
	T = len(rdb)
	W = int(xf_s * C.SR / HOP)
	fps = C.SR / HOP
	dur = len(m) / C.SR
	# features combinadas (pesos 1,0 / 0,8 / 0,5), cada bloco já com norma 1
	onz = (on / (np.sqrt(W) + 1e-6))[:, None]
	G = np.hstack([ch * 1.0, mf * np.sqrt(0.8), onz * 0.0])
	a_max = int(min(40.0, 0.25 * dur) * fps)
	s_lo = int(max(0.55 * dur, 40.0) * fps)
	s_hi = int(min(dur - 5.0, MAX_LOOP_S) * fps) - W
	if s_hi <= s_lo:
		s_hi = T - W - 1
		s_lo = max(W + 1, s_hi // 2)
	r_win = np.convolve(rdb, np.ones(W) / W, mode="valid")      # loudness média por janela
	best = (-1e9, 0, s_lo)
	for a in range(0, a_max + 1, max(1, int(0.25 * fps))):
		head = G[a:a + W]
		sim = np.zeros(T - W + 1)
		for d in range(G.shape[1]):
			sim += sg.correlate(G[:, d], head[:, d], mode="valid", method="fft")
		sim /= W
		oh = on[a:a + W] - on[a:a + W].mean()
		ss = np.arange(s_lo, s_hi)
		if len(ss) == 0:
			continue
		sc = sim[ss].copy()
		# força de ataque (ritmo alinhado): correlação normalizada
		seg = np.lib.stride_tricks.sliding_window_view(on, W)[ss]
		seg = seg - seg.mean(axis=1, keepdims=True)
		den = np.linalg.norm(seg, axis=1) * (np.linalg.norm(oh) + 1e-9) + 1e-9
		sc += 0.5 * (seg @ oh) / den
		sc -= np.abs(r_win[ss] - r_win[a]) / 6.0
		sc += 0.25 * (ss - s_lo) / max(1, s_hi - s_lo)          # leve preferência por loop longo
		sc -= 0.01 * (a / fps)                                  # e por manter a introdução
		i = int(np.argmax(sc))
		if sc[i] > best[0]:
			best = (float(sc[i]), a, int(ss[i]))
	score, a_f, s_f = best
	a_samp, s_samp = a_f * HOP, s_f * HOP
	# ajuste fino: correlação de forma de onda nos graves (onde a fase importa)
	N = int(0.25 * C.SR)
	R = int(0.025 * C.SR)
	low = C.lp(m, 1200)
	ref = low[a_samp:a_samp + N]
	bestc, off = -1e18, 0
	for d in list(range(-R, R + 1, 4)):
		q = s_samp + d
		if q < 0 or q + N > len(low):
			continue
		c = float(np.dot(low[q:q + N], ref))
		if c > bestc:
			bestc, off = c, d
	for d in range(off - 4, off + 5):
		q = s_samp + d
		if q < 0 or q + N > len(low):
			continue
		c = float(np.dot(low[q:q + N], ref))
		if c > bestc:
			bestc, off = c, d
	return a_samp, s_samp + off, score


def loop_crossfade(x, a, s, xf_s):
	"""Loop = x[a:s]; os primeiros X segundos viram x[s:s+X] → x[a:a+X]."""
	X = int(xf_s * C.SR)
	head = x[a:a + X].astype(np.float64)
	tail = x[s:s + X].astype(np.float64)
	hm, tm = head.mean(axis=1), tail.mean(axis=1)
	rho = float(np.clip(np.dot(hm, tm) / (np.linalg.norm(hm) * np.linalg.norm(tm) + 1e-9), 0, 1))
	t = np.linspace(0, 1, X)
	p = 0.5 - 0.5 * np.cos(np.pi * t)      # entra (cabeça)
	q = 1 - p                               # sai (cauda)
	norm = 1 / np.sqrt(p ** 2 + q ** 2 + 2 * rho * p * q)
	y = x[a:s].astype(np.float64).copy()
	y[:X] = (head * p[:, None] + tail * q[:, None]) * norm[:, None]
	return y, rho


def limit_loop(y, looped):
	"""Limitador; em faixa de loop, processa com contexto circular (1 s de cada
	lado) pra que o ganho no fim case com o ganho no começo — sem degrau na volta."""
	if not looped:
		return C.limit(y, CEIL_DB, lookahead_ms=3.0, release_ms=150.0)
	N = min(len(y) // 2, C.SR)
	ext = np.concatenate([y[-N:], y, y[:N]])
	z = C.limit(ext, CEIL_DB, lookahead_ms=3.0, release_ms=150.0)
	return z[N:N + len(y)]


def master(name, title):
	src = os.path.join(C.PACKS, "incompetech", title + ".mp3")
	x = C.load(src, mono=False).astype(np.float64)
	x = C.trim_start(x, -50.0, pre_ms=0.0)
	x = C.trim_end(x, -55.0, keep_ms=50.0)
	info = {"name": name, "src": title + ".mp3", "src_dur": round(len(x) / C.SR, 1)}
	if name in NO_LOOP:
		if len(x) > MAX_LOOP_S * C.SR:
			x = x[: int(MAX_LOOP_S * C.SR)]
		y = C.fade(x, 0.002, 3.0)
		info["loop"] = False
	else:
		xf = XFADE.get(name, XFADE["default"])
		a, s, score = find_loop(x, xf)
		y, rho = loop_crossfade(x, a, s, xf)
		info.update(loop=True, loop_from_s=round(a / C.SR, 2), loop_to_s=round(s / C.SR, 2), xfade_s=xf,
			score=round(score, 2), rho=round(rho, 2))
	tgt = TARGET_OVERRIDE.get(name, TARGET)
	pre = C.integrated_lufs(y)
	# faixa muito "pontuda" (tambor solto, crescendos): se pra chegar no alvo o
	# limitador precisaria cortar mais que MAX_GR, a faixa fica mais baixa que o
	# alvo em vez de ser esmagada.
	over = (C.sample_peak_db(y) + tgt - pre) - CEIL_DB
	if over > MAX_GR:
		tgt -= over - MAX_GR
	info["target"] = round(tgt, 1)
	g = tgt - pre
	y = y * C.db(g)
	peak_before = C.sample_peak_db(y)
	if peak_before > CEIL_DB:
		y = limit_loop(y, info.get("loop", False))
	# o limitador tira um pouco de loudness — compensa 1x e relimita
	post = C.integrated_lufs(y)
	if abs(post - tgt) > 0.2:
		y = y * C.db(tgt - post)
		if C.sample_peak_db(y) > CEIL_DB:
			y = limit_loop(y, info.get("loop", False))
	info.update(gain_db=round(g, 1), limiter_over_db=round(max(0.0, peak_before - CEIL_DB), 1))
	out = os.path.join(C.MUSIC_DIR, name + ".ogg")
	C.write_ogg(out, y.astype(np.float32), quality=4)
	info["out_dur"] = round(len(y) / C.SR, 1)
	return info


if __name__ == "__main__":
	names = sys.argv[1:] or list(MUSIC.keys())
	log = []
	for n in names:
		inf = master(n, MUSIC[n])
		log.append(inf)
		print(json.dumps(inf, ensure_ascii=False))
	path = os.path.join(C.HERE, "music_loops.json")
	old = {}
	if os.path.exists(path):
		with open(path, encoding="utf-8") as f:
			old = {d["name"]: d for d in json.load(f)}
	for d in log:
		old[d["name"]] = d
	with open(path, "w", encoding="utf-8") as f:
		json.dump([old[k] for k in MUSIC if k in old], f, ensure_ascii=False, indent=1)
