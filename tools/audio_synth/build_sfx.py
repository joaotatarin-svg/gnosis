# -*- coding: utf-8 -*-
"""
Constrói TODOS os SFX do GNOSIS (assets/audio/sfx/) — packs CC0/CC-BY +
camadas sintetizadas aqui (numpy) — com loudness coerente por categoria.

  python tools/audio_synth/build_sfx.py              # tudo
  python tools/audio_synth/build_sfx.py hit blip_rei # só alguns (nome-base)

Substitui o antigo assets/_packs/build_assets.py (parte SFX). Packs brutos:
pasta em common.PACKS (variável GNOSIS_PACKS).

Cada entrada de RECIPES é: nome -> (categoria, [receita, receita_2, ...]).
Uma lista com N receitas gera nome.ogg, nome_2.ogg ... nome_N.ogg — o
autoload Audio sorteia entre elas sem repetir a anterior.

Normalização: maior loudness momentânea (M-max, janela 400 ms, mono medido
como dual-mono) no alvo da CATEGORIA + limitador com teto −1 dBFS. Pico
normalizado (o método antigo, tudo a −3 dBFS) deixava clique curto e
estrondo longo com volumes percebidos muito diferentes.
"""
import os, sys, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import SR, db

# Alvo de M-max (LUFS) por categoria. Música fica em −16 LUFS integrado
# (−19 efetivo com o slider padrão 0,7); golpes ~6 dB acima disso.
CAT = {
	"hit": -12.0, "hit_heavy": -10.0, "defense": -13.0, "swing": -18.0, "swing_big": -16.0,
	"move": -20.0, "step": -20.0, "step_heavy": -22.0, "cloth": -26.0, "boss_step": -14.0,
	"hurt": -15.0, "die": -13.0,
	"magic": -13.0, "magic_big": -11.0, "fail": -20.0,
	"creature": -17.0, "creature_die": -15.0, "elite": -13.0, "champion": -12.0,
	"boss": -10.0, "boss_soft": -14.0, "revive": -14.0,
	"proj_fire": -18.0, "proj_hit": -16.0, "nova": -12.0, "gib": -22.0,
	"object": -16.0, "object_big": -14.0,
	"structure": -15.0, "reward": -13.0, "spark": -25.0, "lore": -18.0, "tick": -30.0,
	"ui": -22.0, "ui_soft": -27.0, "ui_big": -18.0, "shop": -18.0,
	"blip": -25.0,
	"story": -15.0, "story_soft": -17.0, "story_whisper": -21.0, "story_heart": -18.0,
	# avisos do combate (R5): curtos, têm de atravessar a música do chefe
	"tell": -17.0, "tell_low": -14.0,
}
CEIL = -1.0


# ----------------------------------------------------------------------------
# Peças
# ----------------------------------------------------------------------------

def P(name, pitch=1.0, rev=False, start=0.0, dur=None, gain=0.0, lp=None, hp=None):
	"""Arquivo do pack → mono (corta silêncio do começo, tom, reverso)."""
	x = C.load(C.find(name), mono=True).astype(np.float64)
	if start > 0:
		x = x[int(start * SR):]
	x = C.trim_start(x)
	if rev:
		x = C.trim_start(x[::-1])
	x = C.resample_pitch(x, pitch)
	if lp:
		x = C.lp(x, lp)
	if hp:
		x = C.hp(x, hp)
	if dur:
		x = cut(x, dur)
	return x * db(gain)


def cut(x, dur, fade_s=0.06):
	n = int(dur * SR)
	if len(x) > n:
		x = x[:n].copy()
		f = min(int(fade_s * SR), n)
		sh = (slice(None),) + ((None,) if x.ndim == 2 else ())
		x[-f:] *= np.linspace(1, 0, f)[sh]
	return x


def layers(dur, *items, stereo=False):
	"""Soma camadas: (sinal, início_s, ganho_dB). Mono ou estéreo."""
	n = int(dur * SR)
	out = np.zeros((n, 2)) if stereo else np.zeros(n)
	for (x, at, g) in items:
		if stereo and x.ndim == 1:
			x = np.stack([x, x], axis=1)
		if not stereo and x.ndim == 2:
			x = x.mean(axis=1)
		C.place(out, x, at, g)
	return out


def thump(f0=70, f1=38, dur=0.35, decay=0.11, seed=0):
	"""Soco grave: seno com queda de tom + clique."""
	n = int(dur * SR)
	t = C.tvec(n)
	f = f1 + (f0 - f1) * np.exp(-t / 0.05)
	x = np.sin(C.osc_phase(f, n)) * np.exp(-t / decay)
	x += C.lp(C.noise(n, seed) * np.exp(-t / 0.006), 2500) * 0.25
	return C.fade(x * np.clip(t / 0.0015, 0, 1), 0, 0.01)


def sweep_filter(x, f_from, f_to, q=1.2, kind="band", block=256):
	"""Filtro com corte varrendo (exponencial) — blocos com estado contínuo."""
	from scipy import signal
	n = len(x)
	out = np.zeros(n)
	zi = np.zeros(2)
	for i in range(0, n, block):
		fr = f_from * (f_to / f_from) ** (i / max(1, n - 1))
		fr = min(fr, SR * 0.45)
		if kind == "band":
			b, a = signal.iirpeak(fr, q, fs=SR)
		elif kind == "low":
			b, a = signal.butter(2, fr, "low", fs=SR)
		else:
			b, a = signal.butter(2, fr, "high", fs=SR)
		seg, zi = signal.lfilter(b, a, x[i:i + block], zi=zi * 1.0 if zi.shape == (2,) else np.zeros(2))
		out[i:i + block] = seg
	return out


def whoosh(dur, f_from, f_to, peak=0.4, seed=0, q=1.0):
	n = int(dur * SR)
	w = C.noise(n, seed)
	x = sweep_filter(w, f_from, f_to, q)
	return x * C.env_swell(n, peak * dur, dur * 0.25)


def choir(notes, dur, vowel="a", vowel2=None, seed=0, attack=0.3, release=0.6, vib=0.006, stereo=True, shift=1.0, breath=0.15):
	"""Coro aditivo: várias vozes por nota (levemente desafinadas), pan aberto."""
	n = int(dur * SR)
	r = C.rng(seed)
	out = np.zeros((n, 2))
	for i, f in enumerate(notes):
		for v in range(3):
			fd = f * (1 + r.uniform(-0.004, 0.004))
			x = C.voice(fd, n, vowel, shift=shift, vowel2=vowel2, breath=breath, seed=seed + 10 * i + v,
				vib=(r.uniform(4.6, 5.8), vib), nh=40)
			out += C.pan(x, r.uniform(-0.7, 0.7))
	t = C.tvec(n)
	e = np.clip(t / attack, 0, 1) ** 1.5 * np.clip((dur - t) / release, 0, 1)
	return out * e[:, None] / (len(notes) * 3)


def note(midi):
	return 440.0 * 2 ** ((midi - 69) / 12)


def sat(x, drive=2.0):
	return np.tanh(x * drive) / np.tanh(drive)


# ----------------------------------------------------------------------------
# Receitas sintetizadas (identidade gnóstica)
# ----------------------------------------------------------------------------

def boss_stinger():
	"""Card de chefe: metal grave crescendo → impacto → coro em trítono + rosnado."""
	dur = 2.6
	n = int(dur * SR)
	t = C.tvec(n)
	# metal grave (dente-de-serra filtrado, abre o filtro até o impacto)
	brass = C.saw_bl(note(26), n, 60) + 0.8 * C.saw_bl(note(38) * 1.003, n, 60) + 0.5 * C.saw_bl(note(45) * 0.997, n, 40)
	brass = sweep_filter(brass, 140, 1600, kind="low")
	brass *= C.env_swell(n, 0.55, 0.9) * 0.5
	brass = sat(brass, 1.6)
	# respiro reverso (ruído subindo até o impacto)
	rise = C.hp(C.noise(n, 3), 1500) * np.clip(t / 0.55, 0, 1) ** 3 * (t < 0.56) * 0.25
	# impacto (tambor fundo + metal)
	hitn = int(1.6 * SR)
	imp = thump(62, 30, 1.6, 0.35, seed=4) + C.lp(C.metal_clang(98, 1.6, seed=5, decay=0.9), 1500) * 0.35
	# coro em trítono (D4–G#4 + A3), vogal "a"→"o"
	ch = choir([note(57), note(62), note(68)], 2.0, "a", "o", seed=7, attack=0.25, release=0.9, vib=0.008)
	growl = P("Dragon_Growl_00.mp3", pitch=0.72, dur=1.6, lp=2500)
	mono = layers(dur, (brass, 0.0, 0), (rise, 0.0, 0), (imp, 0.55, 2.0), (growl, 0.6, -10.0))
	st = np.stack([mono, mono], axis=1)
	C.place(st, ch, 0.5, 3.0)
	return C.reverb(st, rt60=2.8, wet=0.32, predelay=0.03, seed=11, lp_hz=6000, tail=False)


def boss_phase2():
	dur = 1.6
	n = int(dur * SR)
	t = C.tvec(n)
	f = note(33) * 2 ** (np.clip(t / 0.85, 0, 1) * 1.0)
	surge = sum(C.saw_bl(f * d, n, 40) for d in (1.0, 1.007, 0.994, 1.5)) * 0.25
	surge = sat(C.lp(surge, 2400) * C.env_swell(n, 0.85, 0.35), 2.5)
	crack = C.hp(C.noise(n, 21), 2500) * (np.random.default_rng(22).random(n) < 0.004) * 0.9
	crack = C.lp(crack, 9000) * np.clip(t / 0.85, 0, 1)
	boom = thump(70, 32, 0.7, 0.25, seed=23)
	growl = P("Dragon_Growl_01.mp3", dur=1.4)
	return layers(dur, (growl, 0.0, 0), (surge, 0.0, -4), (crack, 0.0, -10), (boom, 0.85, -1))


def boss_die():
	base = layers(2.4, (P("BoneSplosion.ogg", pitch=0.85), 0.0, 0), (P("bfh1_rock_breaking_02.ogg", pitch=0.8), 0.1, -3))
	sigh = choir([note(45), note(52), note(57)], 2.2, "o", "u", seed=31, attack=0.4, release=1.2, vib=0.004)
	t = C.tvec(len(sigh))
	sigh *= (1 - 0.06 * t / 2.2)[:, None]
	st = np.stack([base, base], axis=1)
	C.place(st, sigh, 0.2, -4)
	return C.reverb(st, rt60=2.4, wet=0.25, seed=12, tail=False)


def level_clear():
	dur = 1.8
	b = layers(dur, (P("bell_ding4.wav"), 0.0, 0), (P("bell_ding1.wav"), 0.25, -2))
	st = np.stack([b, b], axis=1)
	ch = choir([note(50), note(57), note(62), note(66)], 1.6, "a", seed=41, attack=0.35, release=0.8)
	C.place(st, ch, 0.0, -2)
	return C.reverb(st, 2.0, 0.25, seed=13, tail=False)


def ring_gain():
	dur = 1.8
	b = layers(dur, (P("magical_6.ogg"), 0.0, 0), (P("bell_ding3.wav"), 0.3, -2))
	st = np.stack([b, b], axis=1)
	ch = choir([note(62), note(69), note(74)], 1.5, "o", "a", seed=51, attack=0.4, release=0.7)
	C.place(st, ch, 0.15, -3)
	return C.reverb(st, 2.2, 0.3, seed=14, tail=False)


# --- os 7 Anéis + Esfera: base do pack + camada de caráter ---------------------

def cast_solar():
	dur = 0.8
	sh = np.zeros(int(dur * SR))
	for i, m in enumerate([72, 76, 79, 84]):     # Dó maior subindo (sol morno)
		C.place(sh, C.bell(note(m), 0.6, decay=0.35, seed=60 + i, bright=0.6), 0.03 * i, -3 * i * 0.3)
	warm = (np.sin(C.osc_phase(note(48), int(0.6 * SR))) + 0.5 * np.sin(C.osc_phase(note(55), int(0.6 * SR)))) * C.env_swell(int(0.6 * SR), 0.08, 0.15)
	return layers(dur, (P("magical_1.ogg", dur=0.7), 0.0, 0), (sh, 0.0, -9), (warm, 0.0, -10))


def cast_torpor():
	dur = 1.0
	n = int(dur * SR)
	breath = C.bp(C.noise(n, 70), 300, 1600) * C.env_swell(n, 0.18, 0.3)
	bells = np.zeros(n)
	for i, m in enumerate([79, 76, 72]):         # caixinha de música abafada, descendo
		C.place(bells, C.lp(C.bell(note(m), 0.7, 0.5, seed=71 + i, bright=0.3), 1800), 0.12 + 0.17 * i)
	return layers(dur, (P("freeze.wav", pitch=0.78, dur=0.95), 0.0, -2), (breath, 0.0, -4), (bells, 0.0, -8))


def cast_fome():
	dur = 0.95
	n = int(0.42 * SR)
	pull = whoosh(0.42, 180, 2200, peak=0.95, seed=80, q=2.0)
	pull *= np.linspace(0.2, 1, n)
	bite = thump(120, 50, 0.25, 0.05, seed=81) + C.hp(C.noise(int(0.25 * SR), 82) * np.exp(-C.tvec(int(0.25 * SR)) / 0.01), 1800) * 0.5
	return layers(dur, (pull, 0.0, -2), (P("eat_01.ogg", pitch=0.85, dur=0.6), 0.36, 0), (bite, 0.4, -3))


def cast_corrente():
	dur = 0.85
	lock = C.metal_clang(410, 0.45, seed=90, decay=0.25) + 0.6 * C.metal_clang(173, 0.45, seed=91, decay=0.3)
	anvil = thump(110, 60, 0.3, 0.07, seed=92)
	return layers(dur, (P("chain_02.ogg", dur=0.7), 0.0, 0), (lock, 0.42, -7), (anvil, 0.42, -6))


def cast_silencio():
	dur = 1.0
	n = int(dur * SR)
	t = C.tvec(n)
	drop = np.sin(C.osc_phase(95 * np.exp(-t / 0.35) + 28, n)) * C.env_swell(n, 0.15, 0.4)
	air = C.hp(C.noise(n, 100), 3000) * np.clip(t / 0.45, 0, 1) * (t < 0.5) * 0.4   # ar sugado... e corta
	muted = C.lp(thump(55, 30, 0.4, 0.15, seed=101), 300)
	return layers(dur, (P("GhostOhh.ogg", rev=True, dur=0.95), 0.0, -3), (drop, 0.0, -5), (air, 0.0, -6), (muted, 0.52, 0))


def cast_espelho():
	dur = 0.9
	# palíndromo: o cristal toca ao contrário e depois pra frente (o reflexo)
	g = sum(C.bell(note(m), 0.4, 0.22, seed=110 + i, bright=1.2) for i, m in enumerate([88, 91, 95]))
	pal = np.r_[g[::-1], g]
	return layers(dur, (P("magical_6.ogg", pitch=1.12, dur=0.8), 0.05, -3), (pal, 0.0, -6))


def cast_praga():
	dur = 0.95
	n = int(dur * SR)
	t = C.tvec(n)
	r = C.rng(120)
	swarm = np.zeros(n)
	for i in range(12):                           # moscas: serra com batida de asa
		f = r.uniform(150, 280) * (1 + 0.03 * np.sin(2 * np.pi * r.uniform(2, 6) * t + r.uniform(0, 6)))
		wing = 0.5 + 0.5 * np.sin(2 * np.pi * r.uniform(28, 55) * t)
		swarm += C.saw_bl(f, n, 30) * wing * r.uniform(0.4, 1.0)
	swarm = C.bp(swarm, 300, 3200) * C.env_swell(n, 0.25, 0.35) / 6
	hum = (np.sin(C.osc_phase(55, n)) + np.sin(C.osc_phase(58.3, n))) * C.env_swell(n, 0.2, 0.4) * 0.3
	return layers(dur, (P("creature_slime_02.ogg", pitch=0.8, dur=0.9), 0.0, 0), (swarm, 0.05, -3), (hum, 0.0, -8))


def cast_coroa():
	dur = 1.6
	base = P("Healing Full.wav", dur=1.5)
	boom = thump(60, 30, 1.0, 0.35, seed=130)
	b = layers(dur, (base, 0.0, 0), (boom, 0.08, -2))
	st = np.stack([b, b], axis=1)
	ch = choir([note(48), note(55), note(60), note(64), note(67)], 1.4, "a", seed=131, attack=0.12, release=0.8, vib=0.007)
	C.place(st, ch, 0.0, 0)
	for i, m in enumerate([84, 79, 76]):
		C.place(st, C.pan(C.bell(note(m), 1.0, 0.8, seed=132 + i, bright=0.8), (-0.5, 0.5, 0)[i]), 0.1 + 0.08 * i, -10)
	return C.reverb(st, 2.6, 0.3, seed=15, tail=False)


# --- movimento / contrato da Animação -----------------------------------------

def step_heavy(src, seed):
	return layers(0.32, (P(src, pitch=0.8, dur=0.3), 0.0, 0), (thump(90, 48, 0.25, 0.05, seed=seed), 0.0, -5))


def boss_step(src, seed, pitch=0.5):
	dur = 0.9
	n = int(dur * SR)
	t = C.tvec(n)
	rumble = C.lp(C.noise(n, seed), 160) * np.exp(-t / 0.25) * 3.0
	debris = P("impactGeneric_light_00%d.ogg" % (seed % 5), pitch=0.8, hp=800)
	return layers(dur, (thump(52, 27, 0.8, 0.22, seed=seed), 0.0, 0), (P(src, pitch=pitch, lp=1400), 0.0, -4),
		(rumble, 0.0, -6), (debris, 0.12, -16))


def ui_open():
	dur = 0.45
	a = C.bell(note(81), 0.45, 0.25, seed=140, bright=0.5)
	b = C.bell(note(88), 0.4, 0.2, seed=141, bright=0.5)
	air = whoosh(0.25, 600, 3500, peak=0.8, seed=142)
	return C.lp(layers(dur, (air, 0.0, -8), (a, 0.03, -2), (b, 0.09, -6)), 7000)


# --- "gromelô": sílabas curtas por falante ------------------------------------

def _blip_env(n, attack=0.004, rel=0.45):
	t = np.arange(n) / n
	e = np.clip(np.arange(n) / (attack * SR), 0, 1)
	k = 1 - rel
	e *= np.where(t < k, 1.0, 0.5 + 0.5 * np.cos(np.pi * (t - k) / rel))
	return e


def blip_voice(f0, vowel, dur, shift=1.0, glide=0.0, breath=0.05, seed=0, vowel2=None):
	n = int(dur * SR)
	f = f0 * (1 + glide * np.linspace(0, 1, n))
	x = C.voice(f, n, vowel, shift=shift, vowel2=vowel2, breath=breath, seed=seed, nh=40)
	return x * _blip_env(n)


def blip_sophia(i):
	v = [("a", "e"), ("e", "i"), ("o", "a"), ("i", "e")][i]
	f0 = [300, 330, 285, 315][i]
	x = blip_voice(f0, v[0], 0.055, shift=1.12, glide=[0.05, -0.03, 0.06, 0.02][i], breath=0.04, seed=200 + i, vowel2=v[1])
	n = len(x)
	glow = np.sin(C.osc_phase(f0 * 4, n)) * _blip_env(n) * 0.06     # brilho (ela é luz)
	return x + glow


def blip_rei(i):
	v = [("o", "a"), ("a", "o"), ("u", "o"), ("o", "u")][i]
	f0 = [98, 92, 104, 88][i]
	n = int(0.075 * SR)
	x = blip_voice(f0, v[0], 0.075, shift=0.85, glide=-0.06, breath=0.03, seed=210 + i, vowel2=v[1])
	sub = C.voice(f0 / 2, n, "o", shift=0.8, nh=30) * _blip_env(n) * 0.35    # rouquidão grave
	return sat(x + sub, 1.8)


def blip_voz(i):
	v = ["u", "o", "a", "o"][i]
	base = [220, 247, 196, 233][i]
	dur = 0.08
	n = int(dur * SR)
	x = np.zeros(n)
	for k, ratio in enumerate([1.0, 1.5, 2.0]):        # quinta + oitava: voz "de cima"
		x += C.voice(base * ratio * (1 + 0.003 * k), n, v, shift=1.05, breath=0.35, seed=220 + 3 * i + k, nh=30) * (0.8 ** k)
	x *= _blip_env(n, attack=0.012, rel=0.6)
	st = C.reverb(x, rt60=0.5, wet=0.35, predelay=0.008, seed=16, lp_hz=8000, tail=True)
	return cut(st, 0.14, 0.05)


def blip_estela(i):
	f = [170, 196, 150, 220][i]
	dur = 0.06
	n = int(dur * SR)
	stone = [(1.0, 1.0, 1.0), (2.32, 0.5, 0.6), (4.25, 0.3, 0.4), (6.8, 0.15, 0.3)]
	x = C.bell(f, dur, decay=0.04, seed=230 + i, partials=stone)
	grit = C.bp(C.noise(n, 235 + i), 1500, 6000) * np.exp(-C.tvec(n) / 0.008) * 0.4
	return (x + grit) * _blip_env(n, 0.001, 0.5)


def blip_npc(i):
	v = [("e", "a"), ("a", "o"), ("o", "e"), ("u", "a")][i]
	f0 = [165, 150, 175, 158][i]
	x = blip_voice(f0, v[0], 0.05, shift=1.0, glide=[0.03, -0.04, 0.0, 0.05][i], breath=0.06, seed=240 + i, vowel2=v[1])
	return C.resonator(x, 260, 3.0) * 0.4 + x      # um pouco anasalado


# ----------------------------------------------------------------------------
# RECEITAS: nome -> (categoria, [variações...]). Cada variação é uma função
# sem argumento (lambda) que devolve o sinal.
# ----------------------------------------------------------------------------

def _hit(src, edge, seed):
	return lambda: layers(0.3, (P(src, dur=0.25), 0.0, 0), (P(edge, dur=0.2, hp=1500), 0.0, -14))


def _hit_heavy(src, seed, pitch=1.0):
	return lambda: layers(0.5, (P(src, pitch=pitch, dur=0.45), 0.0, 0), (thump(80, 40, 0.35, 0.09, seed=seed), 0.0, -4))


RECIPES = {
	# --- Sophia: golpes ---
	"swing_light": ("swing", [lambda: P("swing.wav", dur=0.3), lambda: P("swing2.wav", dur=0.3), lambda: P("swing.wav", pitch=1.1, dur=0.3)]),
	"swing_heavy": ("swing", [lambda: P("swish_2.wav", pitch=0.82, dur=0.5), lambda: P("swish_4.wav", pitch=0.8, dur=0.5), lambda: P("swish_2.wav", pitch=0.74, dur=0.5)]),
	"swing_air": ("swing", [lambda: P("swish_3.wav", dur=0.5)]),
	"launcher": ("swing_big", [lambda: layers(0.45, (P("swing3.wav", pitch=1.12, dur=0.4), 0, 0), (whoosh(0.35, 300, 3000, 0.7, seed=300), 0, -8))]),
	"dive": ("swing_big", [lambda: P("blade_01.ogg", pitch=0.9, dur=0.45)]),
	"hit": ("hit", [_hit("impactPunch_medium_000.ogg", "impactMetal_light_000.ogg", 1),
		_hit("impactPunch_medium_001.ogg", "impactMetal_light_001.ogg", 2),
		_hit("impactPunch_medium_003.ogg", "impactMetal_light_003.ogg", 3)]),
	"hit_heavy": ("hit_heavy", [_hit_heavy("HeavyHit.ogg", 11), _hit_heavy("impactPunch_heavy_000.ogg", 12, 0.9), _hit_heavy("impactPunch_heavy_002.ogg", 13, 0.88)]),
	# --- Sophia: defesa / movimento ---
	"parry": ("defense", [lambda: layers(0.6, (P("impactBell_heavy_001.ogg", dur=0.6), 0, 0), (C.bell(note(93), 0.5, 0.3, seed=310, bright=1.0), 0.0, -12))]),
	"block": ("defense", [lambda: P("impactSoft_heavy_000.ogg", dur=0.3), lambda: P("impactSoft_heavy_001.ogg", dur=0.3), lambda: P("impactSoft_heavy_002.ogg", dur=0.3)]),
	"dodge": ("move", [lambda: P("cloth1.ogg", dur=0.35)]),
	"dodge_perfect": ("defense", [lambda: layers(0.7, (P("bell_ding2.wav", rev=True), 0.0, -2), (P("glass_002.ogg"), 0.42, -4))]),
	"jump": ("move", [lambda: P("cloth2.ogg", dur=0.3)]),
	"land": ("move", [lambda: P("impactSoft_medium_000.ogg", dur=0.3), lambda: P("impactSoft_medium_001.ogg", dur=0.3)]),
	"step": ("step", [lambda: P("footstep_concrete_000.ogg", dur=0.2), lambda: P("footstep_concrete_001.ogg", dur=0.2), lambda: P("footstep_concrete_002.ogg", dur=0.2)]),
	"step_heavy": ("step_heavy", [lambda: step_heavy("footstep_concrete_003.ogg", 320), lambda: step_heavy("footstep_concrete_004.ogg", 321), lambda: step_heavy("footstep_concrete_001.ogg", 322)]),
	"cloth": ("cloth", [lambda: P("cloth3.ogg", dur=0.35), lambda: P("cloth4.ogg", dur=0.35), lambda: P("clothBelt.ogg", dur=0.35)]),
	"rooted": ("magic", [lambda: P("chain_01.ogg", dur=0.55)]),
	"player_hurt": ("hurt", [lambda: P("gasp1.wav", dur=0.45)]),
	"player_die": ("die", [lambda: P("qubodup-PowerDrain.ogg", dur=1.6)]),
	# --- magias ---
	"cast_solar": ("magic", [cast_solar]),
	"cast_torpor": ("magic", [cast_torpor]),
	"cast_fome": ("magic", [cast_fome]),
	"cast_corrente": ("magic", [cast_corrente]),
	"cast_silencio": ("magic", [cast_silencio]),
	"cast_espelho": ("magic", [cast_espelho]),
	"cast_praga": ("magic", [cast_praga]),
	"cast_coroa": ("magic_big", [cast_coroa]),
	"cast_fail": ("fail", [lambda: P("error_006.ogg", dur=0.35)]),
	# --- inimigos / chefes ---
	"enemy_hurt": ("creature", [lambda: P("hurt_01.ogg", dur=0.35), lambda: P("hurt_02.ogg", dur=0.35), lambda: P("hurt_03.ogg", dur=0.35)]),
	"enemy_die": ("creature_die", [lambda: P("creature_die_01.ogg", dur=0.8)]),
	"elite_die": ("elite", [lambda: P("roar_02.ogg", pitch=0.8, dur=1.0)]),
	"champion_die": ("champion", [lambda: layers(1.4, (P("giant4.wav", pitch=0.72), 0.0, 0), (P("gong_02.ogg"), 0.15, -7))]),
	"boss_appear": ("boss", [boss_stinger]),
	"boss_phase2": ("boss", [boss_phase2]),
	"boss_die": ("boss", [boss_die]),
	"boss_step": ("boss_step", [lambda: boss_step("impactPlate_heavy_000.ogg", 330), lambda: boss_step("impactMining_001.ogg", 331, 0.45), lambda: boss_step("impactPlate_heavy_003.ogg", 332, 0.55)]),
	"revive": ("revive", [lambda: P("Cure3.wav", dur=1.6)]),
	"form_revive": ("boss_soft", [lambda: P("dm.mp3", pitch=0.8, dur=1.6)]),
	# --- projéteis / área / pedaços ---
	"proj_fire": ("proj_fire", [lambda: P("magical_4.ogg", dur=0.35)]),
	"proj_hit": ("proj_hit", [lambda: P("ElectricSpark.ogg", dur=0.3)]),
	"nova": ("nova", [lambda: layers(0.8, (P("lowFrequency_explosion_000.ogg", dur=0.8), 0, 0), (C.bell(note(84), 0.5, 0.2, seed=340, bright=1.0), 0.0, -14))]),
	"gib_bounce": ("gib", [lambda: P("plop_01.ogg", dur=0.15)]),
	# --- objetos da tela ---
	"chest_hit": ("object", [lambda: P("impactWood_medium_000.ogg", dur=0.3), lambda: P("impactWood_medium_002.ogg", dur=0.3)]),
	"chest_open": ("object", [lambda: layers(1.0, (P("wooded_box_open.ogg"), 0.0, 0), (P("item_gem_03.ogg"), 0.2, -3))]),
	"sleeper_wake": ("object_big", [lambda: P("Cure1.wav", dur=1.2)]),
	"seal_right": ("object", [lambda: P("bell_01.ogg", dur=0.6)]),
	"seal_wrong": ("object", [lambda: P("bfh1_rock_hit_01.ogg", pitch=0.8, dur=0.5)]),
	"seal_solved": ("object_big", [lambda: P("Jingle_Achievement_00.mp3", dur=1.6)]),
	"portal_open": ("object_big", [lambda: P("1.mp3", dur=1.4)]),
	"portal_enter": ("object_big", [lambda: P("teleport.wav", dur=1.0)]),
	# --- estrutura do run ---
	"zone_lock": ("structure", [lambda: P("slam_02.ogg", pitch=0.8, dur=0.9)]),
	"zone_clear": ("structure", [lambda: P("bell_ding2.wav", dur=1.0)]),
	"level_clear": ("reward", [level_clear]),
	"spark": ("spark", [lambda: P("item_gem_01.ogg", dur=0.2)]),
	"weapon_upgrade": ("reward", [lambda: layers(1.2, (P("metal-ringing.wav"), 0.0, 0), (P("magical_6.ogg"), 0.1, -2))]),
	"ring_gain": ("reward", [ring_gain]),
	"ring_steal": ("reward", [None]),        # gerado em gen_ring_steal
	"shard": ("structure", [lambda: P("item_gem_02.ogg", dur=0.8)]),
	"stele_open": ("lore", [lambda: layers(1.0, (P("bookOpen.ogg"), 0.0, 0), (P("stones_01.ogg", pitch=0.7), 0.0, -8))]),
	"stele_unlock": ("lore", [lambda: layers(1.0, (P("bookFlip2.ogg"), 0.0, 0), (P("bell_ding3.wav"), 0.3, -6))]),
	"subtitle_tick": ("tick", [lambda: P("tick_004.ogg", dur=0.12)]),
	# --- loja / interface ---
	"shop_buy": ("shop", [lambda: layers(0.6, (P("handleCoins.ogg"), 0.0, 0), (P("item_gem_04.ogg"), 0.2, -3))]),
	"shop_fail": ("ui", [lambda: P("error_005.ogg", dur=0.4)]),
	"ui_click": ("ui", [lambda: P("click_001.ogg", dur=0.15)]),
	"ui_move": ("ui_soft", [lambda: P("rollover2.ogg", dur=0.10)]),
	"ui_advance": ("ui", [lambda: P("bookFlip1.ogg", dur=0.15)]),
	"ui_choice": ("ui_big", [lambda: P("gong_02.ogg", dur=0.7)]),
	"ui_confirm": ("ui", [lambda: P("confirmation_001.ogg", dur=0.4)]),
	"ui_back": ("ui", [lambda: P("back_001.ogg", dur=0.3)]),
	"ui_open": ("ui", [ui_open]),
	# --- vozes "gromelô" (UI chama por caractere/sílaba) ---
	"blip_sophia": ("blip", [lambda i=i: blip_sophia(i) for i in range(4)]),
	"blip_rei": ("blip", [lambda i=i: blip_rei(i) for i in range(4)]),
	"blip_voz": ("blip", [lambda i=i: blip_voz(i) for i in range(4)]),
	"blip_estela": ("blip", [lambda i=i: blip_estela(i) for i in range(4)]),
	"blip_npc": ("blip", [lambda i=i: blip_npc(i) for i in range(4)]),
}


def gen_ring_steal():
	"""Sete sinos arrancados em reverso, cada um mais grave — e silêncio."""
	dur = 2.5
	bell = cut(P("bell_ding1.wav", rev=True), 0.6)
	out = np.zeros(int(dur * SR))
	for i in range(7):
		p = 1.0 - i * 0.09
		b = C.resample_pitch(bell, p) * (1.0 - i * 0.07)
		C.place(out, b, i * 0.27)
	f = int(0.5 * SR)
	out[-f:] *= np.linspace(1, 0, f)
	return out


RECIPES["ring_steal"] = ("reward", [gen_ring_steal])

# Magias, projéteis, nova e faísca: 100 % sintetizados em magic.py (refeitos
# após o retorno do João, 17/10/2026). As receitas de pack acima ficam só como
# histórico/alternativa; vale o que está aqui.
import magic as M
for _n in M.SOUNDS:
	RECIPES[_n] = (RECIPES[_n][0], M.variants(_n))

# SFX de roteiro (cena "o Rei sai da névoa") — story.py
import story as S
RECIPES.update(S.SOUNDS)

# Avisos do combate (R5) — tells.py
import tells as T
RECIPES.update(T.SOUNDS)


def finish(x, cat):
	x = np.asarray(x, dtype=np.float64)
	x = C.trim_start(x, -50.0, pre_ms=1.0)
	x = C.trim_end(x, -60.0, keep_ms=15.0)
	x = C.fade(x, 0.002, 0.012)
	return C.to_loudness(x, CAT[cat], "momentary", CEIL)


def build(names=None):
	report = []
	for name, (cat, variants) in RECIPES.items():
		if names and name not in names:
			continue
		for i, fn in enumerate(variants):
			fname = name if i == 0 else "%s_%d" % (name, i + 1)
			x = finish(fn(), cat)
			C.write_ogg(os.path.join(C.SFX_DIR, fname + ".ogg"), x.astype(np.float32), quality=5)
			r = dict(name=fname, cat=cat, dur=round(len(x) / SR, 2), ch=1 if x.ndim == 1 else 2,
				Mmax=round(float(C.max_momentary(x)), 1), peak=round(float(C.sample_peak_db(x)), 1))
			report.append(r)
			print("sfx %-16s %-11s %5.2fs %dch  M-max %6.1f  pico %5.1f" % (fname, cat, r["dur"], r["ch"], r["Mmax"], r["peak"]))
	return report


if __name__ == "__main__":
	names = set(sys.argv[1:]) or None
	rep = build(names)
	path = os.path.join(C.HERE, "sfx_report.json")
	old = {}
	if os.path.exists(path):
		with open(path, encoding="utf-8") as f:
			old = {d["name"]: d for d in json.load(f)}
	for d in rep:
		old[d["name"]] = d
	with open(path, "w", encoding="utf-8") as f:
		json.dump(sorted(old.values(), key=lambda d: d["name"]), f, ensure_ascii=False, indent=1)
