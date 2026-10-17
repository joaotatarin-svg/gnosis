# -*- coding: utf-8 -*-
"""
TEMA DO MENU do GNOSIS — 3 opções 100 % sintetizadas (numpy), para o João
escolher de ouvido. Motivo: `theme` (Gregorian Chant) virou o TEMA DA VOZ
(ROTEIRO §5 #8 — santuário, roubo, anagnórise); o menu precisa de um tema
próprio para a Voz não "gastar" a música dela antes da hora.

  python tools/audio_synth/menu_theme.py               # grava as 3 opções em
                                                       # /home/user/caps/audio/opcoes/ (ou GNOSIS_OPCOES)
  python tools/audio_synth/menu_theme.py --install b   # grava a opção B como
                                                       # assets/audio/music/menu.ogg (o jogo passa a usá-la)

Tudo em Ré menor natural — as 7 notas dos 7 Anéis (Ré Mi Fá Sol Lá Si♭ Dó,
uma por Éon; ver magic.py). Mesma harmonia e melodia nas 3 opções, muda a
orquestração:
  A "Esferas"  harpa de vidro em arpejo + coro 'u' + no 2º meio as 7 notas dos
               Anéis subindo, uma por compasso, em sinos de cristal (a escada
               dos Éons) — leve, luminoso, o mais "menu".
  B "Coro"     órgão + coro em 4 vozes + uma voz solista (soprano em 'a→o')
               cantando a melodia; sino grave a cada 16 s — sacro, irmão do
               canto gregoriano sem copiá-lo.
  C "Caixinha" caixinha de música tocando a melodia sobre vento escuro, baixo
               arqueado e um coração lento — íntimo, sombrio (eco do Torpor).

LOOP PERFEITO POR CONSTRUÇÃO (mesma técnica de build_ambience.py): 64 s
(16 compassos de 4 tempos a 60 bpm); caudas de nota que passam do fim "dão a
volta" para o começo; drones com nº inteiro de ciclos; reverb circular.
Loudness: −16 LUFS integrado, pico ≤ −1 dBFS (igual às outras músicas).
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import SR, db
import magic as M

L = 64.0
N = int(L * SR)
T = C.tvec(N)
BAR = 4.0
TARGET = -16.0
OUT_DIR = os.environ.get("GNOSIS_OPCOES", "/home/user/caps/audio/opcoes")

# Harmonia (1 acorde por compasso): i–i–VI–VI–iv–iv–V–V | i–i–III–III–VI–VII–iv–V
CHORD_SEQ = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A", "Dm", "Dm", "F", "F", "Bb", "C", "Gm", "A"]
VOICING = {   # midi (baixo → agudo), posição fechada perto de Ré3
	"Dm": [50, 57, 62, 65], "Bb": [46, 53, 58, 62], "Gm": [43, 50, 55, 58],
	"A": [45, 52, 57, 61], "F": [41, 48, 53, 57], "C": [48, 55, 60, 64],
}
# Melodia (midi, tempos; None = pausa) — 64 tempos. O Lá dominante (V) usa Dó♯.
MELODY = [
	(69, 2), (74, 2), (72, 1), (69, 1), (67, 2),          # Dm  — o chamado
	(65, 3), (67, 1), (69, 2), (70, 2),                   # B♭
	(67, 2), (74, 2), (72, 1), (70, 1), (69, 2),          # Gm
	(64, 2), (69, 2), (73, 3), (None, 1),                 # A   — pergunta
	(None, 2), (69, 1), (74, 1), (77, 2), (76, 2),        # Dm  — sobe
	(72, 2), (77, 2), (81, 3), (79, 1),                   # F
	(77, 2), (74, 2), (76, 2), (72, 2),                   # B♭ · C
	(70, 2), (74, 2), (76, 2), (73, 2),                   # Gm · A — volta ao começo
]
# As 7 notas dos Anéis (Ré5 → Dó6), uma por compasso, nos compassos 9–15.
RINGS = [74, 76, 77, 79, 81, 82, 84]


def note(m):
	return 440.0 * 2 ** ((m - 69) / 12)


def chord_spans():
	"""[(acorde, início s, duração s)] juntando compassos iguais seguidos."""
	out = []
	for i, c in enumerate(CHORD_SEQ):
		if out and out[-1][0] == c:
			out[-1][2] += BAR
		else:
			out.append([c, i * BAR, BAR])
	return out


def melody_events():
	at = 0.0
	for m, beats in MELODY:
		if m is not None:
			yield m, at, float(beats)
		at += beats
	assert abs(at - L) < 1e-6, at


def wput(dst, x, at, g=0.0, p=0.0):
	"""Soma com VOLTA: o que passa do fim do loop entra no começo."""
	x = C.fade(np.asarray(x, dtype=np.float64), 0, 0.005)
	if x.ndim == 1:
		x = C.pan(x, p)
	x = x * db(g)
	i0 = int(round(at * SR)) % N
	k = 0
	while k < len(x):
		take = min(len(x) - k, N - i0)
		dst[i0:i0 + take] += x[k:k + take]
		k += take
		i0 = 0
	return dst


def pf(f):
	return C.periodic_freq(f, L)


def lfo(rate, phase=0.0):
	return 0.5 + 0.5 * np.sin(2 * np.pi * pf(rate) * T + phase)


def drone(m, bright=0.3, seed=0):
	"""Órgão/drone contínuo e periódico (nº inteiro de ciclos em L)."""
	f = pf(note(m))
	ph = 2 * np.pi * f * T
	x = np.sin(ph) + bright * 0.5 * np.sin(2 * ph) + bright * 0.25 * np.sin(3 * ph) + bright * 0.12 * np.sin(4 * ph)
	# segunda "flauta" levemente desafinada (batimento lento, periódico)
	f2 = pf(f * 1.0015)
	x += 0.5 * np.sin(2 * np.pi * f2 * T + seed)
	return x * (0.75 + 0.25 * lfo(1 / 16.0, seed))


def pad_chord(chord, dur, vowel="u", shift=1.0, up=12, voices=2, seed=0, attack=1.6, release=2.2):
	notes = [note(m + up) for m in VOICING[chord][1:]]
	return M.choir(notes, dur + release, vowel=vowel, shift=shift, attack=attack, release=release,
		seed=seed, vib=0.005, voices=voices)


def music_box(f, dur=2.2):
	"""Lâmina de caixinha: fundamental + parcial inarmônico (~5,9) + estalo."""
	x = M.tone(f, dur, 0.002, 0.9, harm=((1, 1.0), (2.0, 0.08), (5.93, 0.22), (8.6, 0.05)))
	n = len(x)
	click = C.hp(C.noise(n, int(f)) * np.exp(-C.tvec(n) / 0.0015), 3000) * 0.15
	return x + click


# ----------------------------------------------------------------------------
# Opção A — "Esferas": harpa de vidro, coro 'u', escada dos 7 Anéis
# ----------------------------------------------------------------------------
def option_a():
	o = np.zeros((N, 2))
	o += C.pan(drone(38, 0.25, 1) * 0.16, 0)
	o += C.pan(drone(45, 0.15, 2) * 0.06, 0.2)
	for k, (c, at, dur) in enumerate(chord_spans()):
		wput(o, pad_chord(c, dur, "u", 1.0, 12, 2, 700 + k), at, -9)
	# arpejo de vidro em colcheias (0,5 s): 1-5-8-10-8-5-... do acorde, oitava 5
	pattern = [0, 1, 2, 3, 2, 1, 2, 1]
	for b, c in enumerate(CHORD_SEQ):
		tones = [VOICING[c][0] + 12, VOICING[c][1] + 12, VOICING[c][0] + 24, VOICING[c][3] + 12]
		for s in range(8):
			m = tones[pattern[s]] + 12
			g = -17 + (2 if s == 0 else 0) - (3 if s % 2 else 0)
			wput(o, M.glass(note(m), 2.0, 0.7, seed=710 + b * 8 + s, bright=0.6), b * BAR + s * 0.5, g,
				[-0.35, 0.35][s % 2])
	# 2º meio: as 7 notas dos Anéis sobem, uma por compasso (sino de cristal longo)
	for i, m in enumerate(RINGS):
		at = (8 + i) * BAR
		wput(o, M.glass(note(m), 5.0, 2.2, seed=760 + i, bright=1.0), at, -11, (i - 3) * 0.12)
		wput(o, M.glass(note(m - 12), 4.0, 1.6, seed=770 + i, bright=0.5), at + 0.01, -19, -(i - 3) * 0.12)
	return C.reverb_circular(o, rt60=3.2, wet=0.35, seed=780, lp_hz=8000)


# ----------------------------------------------------------------------------
# Opção B — "Coro": órgão, coro em 4 vozes, solista
# ----------------------------------------------------------------------------
def option_b():
	o = np.zeros((N, 2))
	o += C.pan(drone(38, 0.6, 3) * 0.14, -0.1)
	o += C.pan(drone(50, 0.4, 4) * 0.05, 0.1)
	for k, (c, at, dur) in enumerate(chord_spans()):
		vow = "o" if k % 2 == 0 else "a"
		wput(o, pad_chord(c, dur, vow, 0.85, 0, 2, 800 + k, attack=1.2, release=1.8), at, -6)   # vozes graves
		wput(o, pad_chord(c, dur, "u", 1.1, 12, 2, 820 + k, attack=1.8, release=2.2), at, -12)   # vozes agudas
	# solista: 'a' que fecha para 'o' em cada nota, legato (a nota seguinte entra
	# antes da anterior acabar), vibrato que cresce
	for j, (m, at, beats) in enumerate(melody_events()):
		dur = beats + 0.25
		n = M.n_(dur)
		t = C.tvec(n)
		vib_depth = 0.004 + 0.010 * np.clip(t / 1.2, 0, 1)
		f0 = note(m) * (1 + vib_depth * np.sin(2 * np.pi * 5.4 * t))
		x = C.voice(f0, n, "a", shift=1.12, vowel2="o", breath=0.06, seed=840 + j, nh=28)
		e = np.clip(t / 0.09, 0, 1) * np.clip((dur - t) / 0.3, 0, 1)
		wput(o, x * e / 9.0, at, -1, 0.05)
	# sino grave e distante a cada 16 s (Ré3)
	for i in range(4):
		wput(o, C.lp(C.bell(note(50), 7.0, 3.0, seed=860 + i, bright=0.5), 2500), i * 16.0, -17, [-0.4, 0.4][i % 2])
	return C.reverb_circular(o, rt60=4.5, wet=0.45, seed=880, lp_hz=6000)


# ----------------------------------------------------------------------------
# Opção C — "Caixinha": caixinha de música no escuro, coração lento
# ----------------------------------------------------------------------------
def option_c():
	import story as S
	o = np.zeros((N, 2))
	wind = C.band_noise(N, 900, 150, 900, stereo=True)
	wind = wind / np.abs(wind).max() * (0.4 + 0.6 * lfo(1 / 8.0))[:, None]
	o += wind * 0.05
	o += C.pan(drone(38, 0.15, 5) * 0.10, 0)
	# baixo arqueado: a fundamental do acorde, inchando a cada troca
	for k, (c, at, dur) in enumerate(chord_spans()):
		m = VOICING[c][0] - 12
		n = M.n_(dur + 1.5)
		t = C.tvec(n)
		x = C.lp(C.saw_bl(note(m) * (1 + 0.002 * np.sin(2 * np.pi * 4.6 * t)), n, 24), 420)
		e = np.sin(np.clip(t / 1.4, 0, 1) * np.pi / 2) ** 2 * np.clip((dur + 1.5 - t) / 1.5, 0, 1)
		wput(o, x * e, at, -17, 0)
	# coração: 1 batida dupla por compasso, bem baixa
	for b in range(16):
		wput(o, S._thump(60, 0.32, 900 + b), b * BAR, -15)
		wput(o, S._thump(72, 0.24, 950 + b), b * BAR + 0.27, -20)
	# caixinha: a melodia uma oitava acima, com um "eco" de acompanhamento
	for j, (m, at, beats) in enumerate(melody_events()):
		wput(o, music_box(note(m + 12), 2.2 + beats * 0.3), at, -9, 0.1)
	for b, c in enumerate(CHORD_SEQ):
		for s, idx in enumerate([1, 3, 2]):           # 3 notas de acompanhamento por compasso
			wput(o, music_box(note(VOICING[c][idx] + 12), 1.8), b * BAR + 1.0 + s * 1.0, -19, -0.25)
	# sino muito longe a cada 16 s
	for i in range(4):
		wput(o, C.lp(C.bell(note(38 + 12), 8.0, 3.5, seed=990 + i, bright=0.3), 1800), i * 16.0 + 8.0, -20, 0.3)
	return C.reverb_circular(o, rt60=2.6, wet=0.38, seed=995, lp_hz=7000)


OPTIONS = {"a": ("Esferas", option_a), "b": ("Coro", option_b), "c": ("Caixinha", option_c)}


def master(x):
	"""−16 LUFS integrado; limitador CIRCULAR (aquece com o fim do loop)."""
	x = x - x.mean(axis=0)
	y = x * db(TARGET - C.integrated_lufs(x))
	for _ in range(3):
		if np.abs(y).max() > db(-1.0):
			w = 2 * SR
			y = C.limit(np.concatenate([y[-w:], y]), -1.0)[w:]
		now = C.integrated_lufs(y)
		if abs(now - TARGET) < 0.2:
			break
		y = y * db(TARGET - now)
	if np.abs(y).max() > db(-1.0):
		w = 2 * SR
		y = C.limit(np.concatenate([y[-w:], y]), -1.0)[w:]
	return y


def seam_report(y):
	"""Degrau na emenda: loudness de curto prazo dos 3 s finais × 3 s iniciais e
	salto da amostra (fim → começo) comparado ao salto típico entre amostras."""
	w = 3 * SR
	a = C.integrated_lufs(y[-w:])
	b = C.integrated_lufs(y[:w])
	jump = np.abs(y[0] - y[-1]).max()
	typ = np.percentile(np.abs(np.diff(y, axis=0)).max(axis=1), 99)
	return a, b, jump, typ


def build(key):
	name, fn = OPTIONS[key]
	y = master(fn())
	a, b, jump, typ = seam_report(y)
	print("menu_%s (%s): %.1f s  I %.1f LUFS  TP %.1f dB  LRA %.1f  emenda %.1f → %.1f LUFS (salto %.4f, típico %.4f)" % (
		key, name, len(y) / SR, C.integrated_lufs(y), C.true_peak_db(y), C.lra(y), a, b, jump, typ))
	return y


if __name__ == "__main__":
	args = sys.argv[1:]
	if args[:1] == ["--install"]:
		key = args[1].lower()
		y = build(key)
		dst = os.path.join(C.MUSIC_DIR, "menu.ogg")
		C.write_ogg(dst, y.astype(np.float32), quality=6)
		print("instalado:", dst, "(o menu passa a tocar `menu`; rode o AudioQA)")
	else:
		os.makedirs(OUT_DIR, exist_ok=True)
		for key in (args or list(OPTIONS)):
			y = build(key)
			C.write_ogg(os.path.join(OUT_DIR, "menu_%s.ogg" % key), y.astype(np.float32), quality=6)
			# emenda para ouvir: 8 s finais + 8 s iniciais (tem de soar contínuo)
			w = 8 * SR
			C.write_ogg(os.path.join(OUT_DIR, "menu_%s_emenda.ogg" % key), np.concatenate([y[-w:], y[:w]]).astype(np.float32), quality=6)
		print("opções em", OUT_DIR)
