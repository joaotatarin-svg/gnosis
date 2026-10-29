# -*- coding: utf-8 -*-
"""
Onda 7 (Áudio7) — som com IDENTIDADE para todo o conteúdo novo das Ondas 5–6:
golpes dos inimigos por TIPO (`atk_*`), voadores, Campeões, golpes-assinatura
dos 7 Arcontes + Rei + Colosso (`bs_*`), quebra de guarda, ponto fraco do
olho, morte do chefe em 5 passos, Sophia (pulo duplo, Queda Estelar,
contra-ataque), cargas de tiro (pedido do VFX7), os 17 perigos do level6
(`hz_*`), UI nova (mapa, loja, objetivo, conquista) e o roubo.

100 % síntese própria (numpy), determinístico (semente fixa por som). Entra
pelo build_sfx.py como os outros (`RECIPES.update(O7.SOUNDS)`):

  python tools/audio_synth/build_sfx.py atk_swing chain     # só alguns
  python tools/audio_synth/onda7.py --list                   # nomes e categorias

Paleta (a "cara" do jogo): o lado da LUZ (Sophia, Mônada, Soter) é vidro,
sino, coro aberto em Mi maior; o lado das TREVAS (Arcontes, criaturas) é
serra grave desafinada, formantes 'o/u', rugosidade (AM 25–40 Hz), pedra e
ferro. O Rei/Yaldabaoth mistura os dois: coro masculino grave + metal
dourado + sub (luz roubada).
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import SR, db
import magic as M

N = M.n_
note = M.note


# ----------------------------------------------------------------------------
# Peças
# ----------------------------------------------------------------------------

def st(x):
	return np.stack([x, x], axis=1) if x.ndim == 1 else x


def mono(x):
	return x.mean(axis=1) if x.ndim == 2 else x


def thump(f0=80, f1=38, dur=0.4, decay=0.12, seed=0, click=0.25):
	"""Soco grave: seno com queda de tom + clique."""
	n = N(dur)
	t = C.tvec(n)
	f = f1 + (f0 - f1) * np.exp(-t / 0.05)
	x = np.sin(C.osc_phase(f, n)) * np.exp(-t / decay)
	x += C.lp(C.noise(n, seed) * np.exp(-t / 0.006), 2500) * click
	return C.fade(x * np.clip(t / 0.0015, 0, 1), 0, 0.01)


def whoosh(dur, f0, f1, peak=0.4, seed=0, q=1.4, fall=0.25):
	"""Sopro com filtro varrendo f0→f1; pico em peak·dur."""
	n = N(dur)
	x = M.sweep_bp(C.noise(n, seed), f0, f1, q)
	return x * C.env_swell(n, max(peak * dur, 0.005), dur * fall)


def rumble(dur, seed, lo=28, hi=170, att=0.05, tau=0.4, rough=0.0):
	n = N(dur)
	t = C.tvec(n)
	x = C.bp(C.noise(n, seed), lo, hi) * 3.0
	if rough:
		x *= 1.0 - 0.5 * (0.5 + 0.5 * np.sin(2 * np.pi * rough * t))
	return x * C.env_ad(n, att, tau)


def grains(dur, seed, count, lo, hi, spread, g_dur=(0.004, 0.03), decay_tau=None):
	"""Estalos granulares (pedra rachando, cascalho): ruído em banda, curto."""
	n = N(dur)
	r = C.rng(seed)
	out = np.zeros(n)
	for i in range(count):
		at = r.uniform(0, spread) if decay_tau is None else min(r.exponential(decay_tau), spread)
		gd = r.uniform(*g_dur)
		m = N(gd)
		f = r.uniform(lo, hi)
		g = C.bp(C.noise(m, seed * 31 + i), f * 0.7, min(f * 1.4, SR * 0.45)) * C.env_ad(m, 0.0004, gd * 0.35)
		C.place(out, g * r.uniform(0.4, 1.0), at)
	return out


def shards(dur, seed, count=14, fmin=2200, fmax=7500, spread=0.35, tau=0.12):
	"""Vidro estilhaçando: parciais de taça curtas em alturas soltas, estéreo."""
	o = M.buf(dur)
	r = C.rng(seed)
	for i in range(count):
		at = min(r.exponential(spread * 0.4), spread)
		f = r.uniform(fmin, fmax)
		g = M.glass(f, r.uniform(0.08, 0.35), decay=r.uniform(0.05, 0.25), seed=seed + i, bright=0.8)
		M.put(o, g, at, -r.uniform(0, 9), r.uniform(-0.8, 0.8))
	k = N(0.06)
	burst = C.hp(C.noise(k, seed + 500), 3000) * C.env_ad(k, 0.0005, 0.015)
	M.put(o, burst, 0.0, -6)
	return o


def links(dur, seed, count=8, f=1700, spread=0.4, accel=False, decay=0.12):
	"""Elos de corrente chacoalhando (metal inarmônico curto)."""
	n = N(dur)
	r = C.rng(seed)
	out = np.zeros(n)
	for i in range(count):
		if accel:
			at = spread * (1 - (1 - i / max(count - 1, 1)) ** 0.5)
		else:
			at = r.uniform(0, spread)
		c = C.metal_clang(f * r.uniform(0.8, 1.35), 0.15, seed=seed + i, decay=decay * r.uniform(0.6, 1.2))
		C.place(out, c * r.uniform(0.4, 1.0), at)
	return out


def growl(f0, f1, dur, seed, vowel="o", vowel2=None, rough=31.0, drive=2.4, shift=0.8, breath=0.4):
	"""Voz de criatura: formantes graves + aspereza + saturação."""
	n = N(dur)
	t = C.tvec(n)
	f = f0 * (f1 / f0) ** (t / dur)
	v = C.voice(f, n, vowel, shift=shift, vowel2=vowel2, breath=breath, seed=seed, nh=50, vib=(6.0, 0.012))
	v /= max(np.abs(v).max(), 1e-9)
	am = 1.0 - 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * rough * t))
	return M.sat(v * am, drive) * np.clip(t / 0.03, 0, 1) * np.clip((dur - t) / 0.12, 0, 1)


def dark_cluster(notes, dur, seed, att=0.3, rel=0.4, lp_hz=1400):
	"""Massa escura: serras desafinadas (2ª menor / trítono), abafadas."""
	n = N(dur)
	t = C.tvec(n)
	r = C.rng(seed)
	o = np.zeros((n, 2))
	for i, f in enumerate(notes):
		for v in range(2):
			fd = f * (1 + r.uniform(-0.006, 0.006))
			x = C.lp(C.saw_bl(fd * (1 + 0.003 * np.sin(2 * np.pi * r.uniform(0.2, 0.7) * t)), n, 30), lp_hz)
			o += C.pan(x, r.uniform(-0.7, 0.7))
	e = np.clip(t / att, 0, 1) ** 1.5 * np.clip((dur - t) / rel, 0, 1)
	return o * e[:, None] / (2 * len(notes))


def glass_gliss(f0, f1, dur, seed, count=6, spread=None, tau=0.18):
	"""Arpejo de vidro subindo (ou descendo) de f0 a f1 — o lado da LUZ."""
	o = M.buf(dur + 0.4)
	r = C.rng(seed)
	spread = dur if spread is None else spread
	for i in range(count):
		k = i / max(count - 1, 1)
		f = f0 * (f1 / f0) ** k
		g = M.glass(f, 0.5, decay=tau, seed=seed + i, bright=0.9)
		M.put(o, g, spread * k, -2 * k * 0 - r.uniform(0, 3), (k - 0.5) * 1.2)
	return o


def light_rise(dur, seed, f_lo=330, f_hi=1320, choir=True, sparkle=True):
	"""Carga de LUZ: coro 'a' que se abre + brilho subindo + sopro claro."""
	o = M.buf(dur + 0.3)
	n = N(dur)
	t = C.tvec(n)
	sw = whoosh(dur, 500, 7000, peak=0.92, seed=seed, q=1.2, fall=0.08)
	M.put(o, sw, 0.0, -8)
	if choir:
		ch = M.choir([note(64), note(68), note(71), note(76)], dur, "a", attack=dur * 0.85, release=0.08, seed=seed + 3)
		M.put(o, ch, 0.0, 2)
	# tom que sobe (fio de luz)
	f = f_lo * (f_hi / f_lo) ** (t / dur) ** 1.5
	fio = np.sin(C.osc_phase(f, n)) * (t / dur) ** 2 * 0.5
	M.put(o, fio + 0.3 * np.sin(C.osc_phase(f * 2.0, n)) * (t / dur) ** 3, 0.0, -6)
	if sparkle:
		M.put(o, glass_gliss(note(88), note(100), dur * 0.5, seed + 9, count=5, tau=0.1), dur * 0.5, -10)
	return C.reverb(o, rt60=1.0, wet=0.22, seed=seed + 7, lp_hz=10000)


def suck(dur, seed, f0=3000, f1=200):
	"""Inspiração / sucção (ruído varrendo para baixo e CRESCENDO)."""
	n = N(dur)
	x = M.sweep_bp(C.noise(n, seed), f0, f1, 1.6)
	return x * C.env_swell(n, dur * 0.95, 0.02)


def reverse(x):
	return x[::-1].copy()


def ear_ring(dur, f=6200, seed=0):
	n = N(dur)
	t = C.tvec(n)
	return np.sin(C.osc_phase(f * (1 + 0.002 * np.sin(2 * np.pi * 0.7 * t)), n)) * C.env_swell(n, 0.05, dur * 0.4)


def wing(dur, seed, f=600):
	"""Uma batida de asa: sopro grave encorpado com 'flap' de pano."""
	n = N(dur)
	t = C.tvec(n)
	gust = M.sweep_bp(C.noise(n, seed), f * 0.5, f * 1.6, 0.9) * C.env_swell(n, dur * 0.35, dur * 0.3)
	flap = C.bp(C.noise(n, seed + 1), 200, 1500) * C.env_ad(n, 0.002, 0.025) * 1.5
	return gust + flap


def stone_hit(seed, f=110, dur=0.5):
	return thump(f * 1.6, f * 0.5, dur, 0.1, seed, click=0.4) + grains(dur, seed + 3, 18, 600, 4000, 0.2, decay_tau=0.05) * 0.8


def zip_(dur, f0, f1, seed, q=3.0):
	"""Zunido de projétil (tom + sopro varrendo)."""
	n = N(dur)
	t = C.tvec(n)
	f = f0 * (f1 / f0) ** (t / dur)
	tone = np.sin(C.osc_phase(f, n)) * 0.5 + 0.25 * np.sin(C.osc_phase(f * 1.5, n))
	air = M.sweep_bp(C.noise(n, seed), f0 * 2, f1 * 2, q)
	return (tone + air) * C.env_ad(n, 0.004, dur * 0.4)


def bite(seed, low=85, wet=True):
	b = M.chomp(seed, 0.16, low) * 1.4
	if wet:
		m = N(0.18)
		sq = M.sweep_bp(C.noise(m, seed + 5), 1800, 500, 2.0) * C.env_ad(m, 0.002, 0.05) * 0.8
		b = np.concatenate([b, np.zeros(max(0, m - len(b)))]) if len(b) < m else b
		b[:m] += sq[:len(b[:m])]
	return b


def tail(x, rt=0.6, wet=0.18, seed=7, lp=7000):
	return C.reverb(st(x) if x.ndim == 1 else x, rt60=rt, wet=wet, seed=seed, lp_hz=lp, tail=True)


# ----------------------------------------------------------------------------
# Kit dos chefes já chamado no código (BossBrain.sfx): `chain`, `glass`
# ----------------------------------------------------------------------------

def chain(v=0):
	"""Galila: o laço pega — elos acelerando + PUXÃO (sopro) + trava de ferro."""
	d = 0.7
	o = M.buf(d)
	M.put(o, C.lp(links(0.45, 900 + v * 13, 9, 1000 + 120 * v, 0.28, accel=True), 3500), 0.0, -2)   # elos sem agudo cansativo (R12)
	M.put(o, whoosh(0.3, 300, 1800, 0.7, 910 + v, 1.0), 0.05, -6)
	M.put(o, C.metal_clang(320 + 30 * v, 0.5, seed=920 + v, decay=0.25), 0.3, -4)
	M.put(o, thump(110, 50, 0.3, 0.06, 930 + v, 0.5), 0.3, -4)
	return C.lp(tail(o, 0.5, 0.15, 940 + v, 6000), 2800)   # ferro escuro: sem 2–5 kHz sustentado (R12)


def glass(v=0):
	"""Astaphaios: a guarda de espelho devolve o golpe — vidro 'ping' que se
	espelha (o mesmo som ao contrário do outro lado) + lascas."""
	d = 0.8
	o = M.buf(d)
	f = note(81 + [0, 3, -2][v % 3])
	ping = M.glass(f, 0.6, decay=0.3, seed=950 + v)
	M.put(o, reverse(M.glass(f * 1.5, 0.2, decay=0.08, seed=951 + v)), 0.0, -8, -0.7)
	M.put(o, ping, 0.18, 0, 0.5)
	M.put(o, ping * 0.6, 0.27, -6, -0.5)
	M.put(o, shards(0.4, 960 + v, 6, 3000, 7000, 0.1), 0.18, -12)
	return C.reverb(o, rt60=1.2, wet=0.25, seed=970 + v, lp_hz=11000)


# ----------------------------------------------------------------------------
# Cargas de tiro (pedido do VFX7): luz × trevas × Rei
# ----------------------------------------------------------------------------

def charge_light():
	"""Sophia carrega: coro em Mi maior que abre, fio de luz subindo, faíscas."""
	return light_rise(0.62, 1000)


def charge_dark():
	"""Arconte carrega: serras graves desafinadas inspirando (sucção), sub que
	cresce e um sussurro 'u' — a escuridão puxa o ar antes do tiro."""
	d = 0.62
	o = M.buf(d + 0.2)
	n = N(d)
	t = C.tvec(n)
	M.put(o, dark_cluster([note(38), note(39), note(44)], d, 1010, att=d * 0.9, rel=0.05, lp_hz=900), 0.0, 4)
	M.put(o, suck(d, 1011, 4000, 300), 0.0, -6)
	sub = np.sin(C.osc_phase(36 * (1 + 0.3 * t / d), n)) * (t / d) ** 2
	M.put(o, sub, 0.0, -2)
	M.put(o, growl(70, 90, d, 1012, "u", rough=27, drive=1.6) * (t / d) ** 2, 0.0, -10)
	return C.reverb(o, rt60=0.8, wet=0.18, seed=1013, lp_hz=4000)


def charge_king():
	"""O Rei carrega: luz ROUBADA — coro masculino grave 'o' + gongo ao
	contrário + sino dourado no topo; mais longo e mais largo."""
	d = 0.9
	o = M.buf(d + 0.4)
	ch = M.choir([note(38), note(45), note(50)], d, "o", shift=0.85, attack=d * 0.8, release=0.06, seed=1020, voices=3)
	M.put(o, ch, 0.0, 3)
	gong = reverse(C.metal_clang(98, d, seed=1021, decay=0.9))
	M.put(o, gong, 0.0, -6)
	M.put(o, light_rise(d, 1022, 220, 880, choir=False, sparkle=False), 0.0, -6)
	M.put(o, C.bell(note(74), 0.5, 0.6, seed=1023, bright=1.2), d - 0.03, -10)
	return C.reverb(o, rt60=1.6, wet=0.22, seed=1024, lp_hz=7000)


# ----------------------------------------------------------------------------
# Sophia
# ----------------------------------------------------------------------------

def double_jump(v=0):
	"""2º pulo (dom do Soter): sopro para cima + ANEL de luz (vidro em Mi-Si)."""
	d = 0.55
	o = M.buf(d)
	M.put(o, whoosh(0.22, 400, 3500, 0.5, 1100 + v, 1.2), 0.0, -2)
	base = [note(76), note(83)][v % 2]
	M.put(o, M.glass(base, 0.45, decay=0.18, seed=1101 + v), 0.03, -4, -0.3)
	M.put(o, M.glass(base * 1.5, 0.4, decay=0.14, seed=1102 + v), 0.07, -8, 0.3)
	M.put(o, M.glass(base * 2.0, 0.35, decay=0.1, seed=1103 + v), 0.11, -12, 0.0)
	return C.reverb(o, rt60=0.7, wet=0.2, seed=1104, lp_hz=11000)


def star_charge():
	"""Queda Estelar carregando (paira): estrelas se juntando, sobe e segura."""
	d = 0.5
	o = M.buf(d + 0.2)
	M.put(o, light_rise(d, 1110, 440, 1760, choir=False), 0.0, 0)
	n = N(d)
	t = C.tvec(n)
	sub = np.sin(C.osc_phase(55 * (1 + 0.5 * t / d), n)) * (t / d)
	M.put(o, sub, 0.0, -8)
	return o


def star_impact():
	"""Queda Estelar pousa — CAMADA de estrelas sobre a `nova` (que já é o baque,
	R4: um impacto por evento): chuva de estrelas caindo + cascalho + sino."""
	d = 1.1
	o = M.buf(d)
	M.put(o, grains(0.5, 1121, 24, 600, 4000, 0.35, decay_tau=0.08), 0.0, -6)
	M.put(o, glass_gliss(note(100), note(84), 0.35, 1122, count=6, tau=0.12), 0.02, -2)
	M.put(o, C.bell(note(64), 0.9, 0.5, seed=1123), 0.0, -8)
	return C.reverb(o, rt60=1.1, wet=0.25, seed=1124, lp_hz=9000)


def riposte_ready():
	"""Aparo perfeito → a janela do contra-ataque ABRIU: dois 'tins' de lâmina
	subindo (Si6→Mi7), curtos — o ouvido aprende 'agora!'."""
	d = 0.4
	o = M.buf(d)
	M.put(o, M.glass(note(95), 0.25, decay=0.07, seed=1130), 0.0, -2)
	M.put(o, M.glass(note(100), 0.3, decay=0.09, seed=1131), 0.07, 0)
	k = N(0.08)
	M.put(o, M.sweep_bp(C.noise(k, 1132), 4000, 9000, 3.0) * C.env_swell(k, 0.01, 0.02), 0.07, -14)
	return C.reverb(o, rt60=0.5, wet=0.15, seed=1133, lp_hz=12000)


def riposte():
	"""Contra-ataque: estocada — sopro rasgado + 'xing' de lâmina + peso."""
	d = 0.5
	o = M.buf(d)
	M.put(o, whoosh(0.25, 300, 5000, 0.6, 1140, 1.6), 0.0, 0)
	k = N(0.2)
	M.put(o, M.sweep_bp(C.noise(k, 1141), 3500, 8000, 4.0) * C.env_swell(k, 0.03, 0.06), 0.1, -6)
	M.put(o, C.metal_clang(1200, 0.3, seed=1142, decay=0.12), 0.12, -14)
	M.put(o, thump(140, 60, 0.25, 0.05, 1143, 0.2), 0.12, -8)
	return tail(o, 0.4, 0.12, 1144, 9000)


# ----------------------------------------------------------------------------
# Inimigos: golpe por TIPO (Audio.move_sfx). Escuro, curto, abaixo dos golpes
# da Sophia (categoria eatk −19 / eatk_big −16).
# ----------------------------------------------------------------------------

def atk_swing(v=0):
	"""Garra/osso cortando o ar: sopro médio + estalo ósseo."""
	d = 0.3
	o = M.buf(d)
	M.put(o, whoosh(0.2, 1800 - 300 * v, 500, 0.45, 1200 + v, 1.8), 0.0, 0)
	M.put(o, grains(0.08, 1203 + v, 3, 1500, 3500, 0.02), 0.08, -10)
	M.put(o, growl(120 - 10 * v, 90, 0.18, 1206 + v, "a", drive=2.0) * 0.5, 0.0, -14)
	return o


def atk_combo(v=0):
	"""Duas garradas coladas (a 2ª mais grave)."""
	d = 0.45
	o = M.buf(d)
	M.put(o, whoosh(0.15, 2000, 600, 0.4, 1210 + v, 2.0), 0.0, 0)
	M.put(o, whoosh(0.18, 1500, 400, 0.4, 1212 + v, 2.0), 0.13, 1)
	M.put(o, growl(140, 100, 0.3, 1214 + v, "a", drive=2.2), 0.0, -14)
	return o


def atk_rush(v=0):
	"""Investida: pé que firma + sopro acelerando + rosnado."""
	d = 0.6
	o = M.buf(d)
	M.put(o, thump(90, 45, 0.25, 0.05, 1220 + v), 0.0, -4)
	M.put(o, whoosh(0.5, 200, 1600, 0.7, 1221 + v, 0.9, 0.15), 0.03, 0)
	M.put(o, growl(90 + 10 * v, 140, 0.45, 1222 + v, "o", "a", drive=2.6), 0.04, -6)
	return o


def atk_leap(v=0):
	"""Bote: sibilo + sopro para cima (o bicho salta)."""
	d = 0.45
	o = M.buf(d)
	k = N(0.2)
	M.put(o, C.hp(C.noise(k, 1230 + v), 3500) * C.env_swell(k, 0.05, 0.06), 0.0, -8)
	M.put(o, whoosh(0.35, 300, 2400, 0.5, 1231 + v, 1.0), 0.05, 0)
	M.put(o, growl(160, 220, 0.2, 1232 + v, "a", drive=2.4), 0.03, -10)
	return o


def atk_slam(v=0):
	"""Pancada no chão: soco grave + cascalho."""
	d = 0.6
	o = M.buf(d)
	M.put(o, stone_hit(1240 + v, 95 - 10 * v, 0.55), 0.0, 0)
	return tail(o, 0.5, 0.12, 1242, 5000)


def atk_wave(v=0):
	"""Onda pelo chão: pedra rolando que se afasta (grave rugoso + estalos)."""
	d = 0.8
	o = M.buf(d)
	n = N(0.75)
	t = C.tvec(n)
	r = rumble(0.75, 1250 + v, 40, 300, 0.02, 0.35, rough=18) * (1 - t / 0.75)
	M.put(o, r, 0.0, 0)
	M.put(o, grains(0.7, 1252 + v, 26, 400, 2500, 0.6), 0.0, -6)
	M.put(o, thump(80, 40, 0.3, 0.06, 1254 + v), 0.0, -4)
	return o


def atk_shot(v=0):
	"""Tiro das trevas: 'thum' grave + zunido descendo (não o zip claro da Sophia)."""
	d = 0.4
	o = M.buf(d)
	M.put(o, thump(160, 70, 0.2, 0.04, 1260 + v, 0.2), 0.0, -4)
	M.put(o, zip_(0.3, 900 - 120 * v, 300, 1261 + v), 0.0, -2)
	M.put(o, C.hp(C.noise(N(0.15), 1262 + v), 2500) * C.env_ad(N(0.15), 0.002, 0.03), 0.0, -14)
	return o


def atk_shot_air(v=0):
	"""Tiro de CIMA (voador): o mesmo tiro com 'queda' de tom e sopro de asa."""
	d = 0.45
	o = M.buf(d)
	M.put(o, wing(0.25, 1270 + v, 500), 0.0, -6)
	M.put(o, zip_(0.35, 1400, 350, 1271 + v), 0.04, 0)
	return o


def atk_fan():
	"""Leque: 3 zunidos abrindo em leque (esq → centro → dir)."""
	d = 0.5
	o = M.buf(d)
	for i, p in enumerate([-0.6, 0.0, 0.6]):
		M.put(o, zip_(0.28, 1000 - 80 * i, 320, 1280 + i), 0.03 * i, -2, p)
	M.put(o, thump(150, 60, 0.2, 0.05, 1283, 0.2), 0.0, -6)
	return o


def atk_burst():
	"""Rajada: catraca de 4 disparos secos (o arco do atirador)."""
	d = 0.7
	o = M.buf(d)
	for i in range(4):
		M.put(o, zip_(0.12, 1300 - 60 * i, 500, 1290 + i, 4.0), 0.14 * i, -2)
		M.put(o, grains(0.03, 1294 + i, 2, 2000, 4000, 0.005), 0.14 * i, -8)
	return o


def atk_homing():
	"""Teleguiado: fogo-fátuo que ondula (vibrato largo) + sussurro."""
	d = 0.8
	n = N(d)
	t = C.tvec(n)
	f = 520 * (1 + 0.08 * np.sin(2 * np.pi * 7 * t))
	x = (np.sin(C.osc_phase(f, n)) + 0.4 * np.sin(C.osc_phase(f * 1.51, n))) * C.env_swell(n, 0.1, 0.35)
	w = M.sweep_bp(C.noise(n, 1301), 1200, 3000, 2.0) * C.env_swell(n, 0.15, 0.3) * 0.6
	o = M.buf(d)
	M.put(o, x + w, 0.0, 0)
	return C.reverb(o, rt60=0.9, wet=0.3, seed=1302, lp_hz=6000)


def atk_lob():
	"""Arco: arremesso 'fuup' para cima + giro (bamboleio) no ar."""
	d = 0.6
	n = N(d)
	t = C.tvec(n)
	o = M.buf(d)
	M.put(o, whoosh(0.25, 300, 1500, 0.4, 1310, 1.2), 0.0, 0)
	f = 300 * (1 + 0.4 * t / d)
	wob = M.sweep_bp(C.noise(n, 1311), 600, 1100, 3.0) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)) * C.env_swell(n, 0.2, 0.25)
	M.put(o, wob + 0.2 * np.sin(C.osc_phase(f, n)) * C.env_swell(n, 0.15, 0.2), 0.05, -6)
	return o


def atk_pillar():
	"""Coluna de luz (profana) brotando: sub crescendo → explosão de coro rachado."""
	d = 0.9
	o = M.buf(d + 0.3)
	n = N(0.35)
	t = C.tvec(n)
	M.put(o, np.sin(C.osc_phase(45 + 40 * t / 0.35, n)) * (t / 0.35) ** 2, 0.0, -2)
	M.put(o, whoosh(0.5, 300, 6000, 0.08, 1320, 0.8, 0.5), 0.3, -4)
	ch = M.choir([note(57), note(58), note(64)], 0.6, "a", attack=0.02, release=0.4, seed=1321)
	M.put(o, ch, 0.3, 0)
	M.put(o, C.bell(note(69), 0.6, 0.4, seed=1322, bright=1.3), 0.3, -10)
	return C.reverb(o, rt60=1.2, wet=0.22, seed=1323, lp_hz=8000)


def atk_fissure():
	"""Lâmina rasteira pelo chão: raspar de pedra que corre + rachaduras."""
	d = 0.8
	n = N(0.7)
	t = C.tvec(n)
	o = M.buf(d)
	scrape = M.sweep_bp(C.noise(n, 1330), 2500, 900, 2.5) * C.env_ad(n, 0.01, 0.35) * (1 + 0.5 * np.sin(2 * np.pi * 40 * t))
	M.put(o, scrape, 0.0, 0)
	M.put(o, grains(0.7, 1331, 22, 800, 4000, 0.6), 0.0, -4)
	M.put(o, C.metal_clang(700, 0.3, seed=1332, decay=0.1), 0.0, -12)
	return o


def atk_grab():
	"""Agarrão: avanço + mão que fecha (pano/carne) + puxão."""
	d = 0.5
	o = M.buf(d)
	M.put(o, whoosh(0.2, 600, 1800, 0.6, 1340, 1.4), 0.0, -2)
	k = N(0.12)
	M.put(o, C.bp(C.noise(k, 1341), 300, 2500) * C.env_ad(k, 0.001, 0.03) * 2, 0.15, 0)
	M.put(o, thump(120, 60, 0.2, 0.04, 1342, 0.3), 0.15, -6)
	M.put(o, growl(110, 80, 0.3, 1343, "o", drive=2.2), 0.15, -12)
	return o


def atk_blink():
	"""Aparece ATRÁS: sucção ao contrário + estalo + sussurro do outro lado."""
	d = 0.5
	o = M.buf(d)
	M.put(o, suck(0.25, 1350, 5000, 400), 0.0, -2, -0.6)
	M.put(o, thump(400, 120, 0.1, 0.02, 1351, 0.6), 0.25, -6, 0.6)
	M.put(o, C.hp(C.noise(N(0.2), 1352), 3000) * C.env_ad(N(0.2), 0.002, 0.05), 0.25, -12, 0.6)
	return C.reverb(o, rt60=0.6, wet=0.2, seed=1353, lp_hz=7000)


def atk_summon():
	"""Invocação: canto grave 'u' + borbulho do chão + rachadura."""
	d = 1.1
	o = M.buf(d + 0.3)
	ch = M.choir([note(36), note(42)], d, "u", attack=0.3, release=0.4, seed=1360, voices=2)
	M.put(o, ch, 0.0, 2)
	r = C.rng(1361)
	for i in range(8):
		M.put(o, M.bubble(r.uniform(150, 400), 1362 + i, 0.08), 0.3 + r.uniform(0, 0.6), -8, r.uniform(-0.5, 0.5))
	M.put(o, grains(0.4, 1370, 14, 300, 1500, 0.3), 0.5, -6)
	return C.reverb(o, rt60=1.2, wet=0.25, seed=1371, lp_hz=5000)


def atk_nova():
	"""Pulso escuro: ar sendo puxado → estouro grave."""
	d = 0.7
	o = M.buf(d)
	M.put(o, suck(0.25, 1380, 3000, 300), 0.0, -6)
	M.put(o, thump(110, 35, 0.45, 0.14, 1381, 0.4), 0.25, 0)
	M.put(o, whoosh(0.4, 2000, 300, 0.05, 1382, 0.8, 0.4), 0.25, -6)
	return o


def atk_dive(v=0):
	"""Mergulho do voador: guincho descendo + vento rasgando."""
	d = 0.7
	o = M.buf(d)
	M.put(o, growl(700 - 60 * v, 300, 0.5, 1390 + v, "i", "a", rough=40, drive=2.0, shift=1.2), 0.0, -4)
	M.put(o, whoosh(0.6, 3000, 500, 0.75, 1392 + v, 1.0, 0.1), 0.0, 0)
	return o


def atk_glide():
	"""Planar: 2 batidas de asa + sopro longo."""
	d = 0.8
	o = M.buf(d)
	M.put(o, wing(0.3, 1400, 500), 0.0, 0)
	M.put(o, wing(0.3, 1401, 450), 0.18, -2)
	M.put(o, whoosh(0.6, 400, 1200, 0.5, 1402, 0.8), 0.15, -6)
	return o


def fly_fall(v=0):
	"""Voador atingido cai: asas descompassadas + assobio de queda + baque."""
	d = 0.9
	o = M.buf(d)
	r = C.rng(1410 + v)
	for i in range(4):
		M.put(o, wing(0.12, 1411 + i + v * 7, 700 + 100 * r.random()), 0.05 * i + r.uniform(0, 0.02), -4 - 2 * i)
	n = N(0.55)
	t = C.tvec(n)
	f = 1400 * (350 / 1400) ** (t / 0.55)
	M.put(o, np.sin(C.osc_phase(f, n)) * C.env_swell(n, 0.25, 0.2) * 0.4, 0.1, -8)
	M.put(o, growl(400, 200, 0.3, 1415 + v, "a", drive=2.0, shift=1.1), 0.0, -10)
	M.put(o, thump(90, 40, 0.25, 0.05, 1416 + v), 0.62, -4)
	return o


# ----------------------------------------------------------------------------
# Campeões
# ----------------------------------------------------------------------------

def champion_enter():
	"""Campeão entra: trompa de guerra grave (serra em 5ª) + ferro arrastado + rugido."""
	d = 1.6
	o = M.buf(d + 0.4)
	n = N(1.3)
	t = C.tvec(n)
	f = note(38) * (1 + 0.03 * np.clip(t / 0.2, 0, 1))
	horn = C.lp(C.saw_bl(f, n, 30) + 0.7 * C.saw_bl(f * 1.5, n, 20), 1100) * C.env_swell(n, 0.25, 0.7)
	M.put(o, horn, 0.0, 0)
	M.put(o, links(1.0, 1420, 10, 900, 0.9, decay=0.2), 0.1, -10)
	M.put(o, growl(80, 70, 1.0, 1421, "o", rough=26, drive=3.0), 0.3, -4)
	M.put(o, thump(70, 30, 0.6, 0.2, 1422), 0.0, -4)
	return C.reverb(o, rt60=1.8, wet=0.25, seed=1423, lp_hz=5000)


def champion_fury():
	"""Fúria do Campeão: rugido que acende (sobe) + labareda."""
	d = 1.1
	o = M.buf(d + 0.3)
	M.put(o, growl(90, 160, 0.9, 1430, "o", "a", rough=34, drive=3.2), 0.0, 0)
	M.put(o, whoosh(0.8, 200, 4000, 0.6, 1431, 0.7, 0.3), 0.05, -4)
	M.put(o, thump(80, 35, 0.4, 0.12, 1432), 0.0, -6)
	return C.reverb(o, rt60=1.2, wet=0.2, seed=1433, lp_hz=6000)


# ----------------------------------------------------------------------------
# Chefes: fase 3, guarda, olho, morte em 5 passos
# ----------------------------------------------------------------------------

def boss_phase3():
	"""Fase 3 (desespero): rugido duplo + coro em cluster que racha + impacto."""
	d = 2.0
	o = M.buf(d + 0.5)
	M.put(o, reverse(whoosh(0.6, 300, 4000, 0.1, 1440, 0.8, 0.5)), 0.0, -6)
	M.put(o, thump(70, 28, 0.9, 0.3, 1441, 0.5), 0.6, 2)
	M.put(o, growl(70, 55, 1.2, 1442, "o", "u", rough=29, drive=3.4), 0.6, 0)
	M.put(o, growl(105, 82, 1.1, 1443, "a", "o", rough=37, drive=3.0) * 0.7, 0.62, -3)
	ch = M.choir([note(45), note(46), note(51), note(52)], 1.3, "a", attack=0.05, release=0.6, seed=1444)
	M.put(o, ch, 0.6, -2)
	M.put(o, C.metal_clang(90, 1.2, seed=1445, decay=0.8), 0.6, -8)
	return C.reverb(o, rt60=2.2, wet=0.25, seed=1446, lp_hz=5000)


def guard_break():
	"""Quebra de guarda: armadura racha (pedra+vidro) + ar escapando + sino abafado."""
	d = 1.1
	o = M.buf(d)
	M.put(o, thump(180, 60, 0.35, 0.07, 1450, 0.6), 0.0, 0)
	M.put(o, grains(0.3, 1451, 30, 1200, 6000, 0.12, decay_tau=0.03), 0.0, -2)
	M.put(o, shards(0.6, 1452, 10, 1800, 5000, 0.25), 0.02, -6)
	M.put(o, whoosh(0.6, 2500, 300, 0.1, 1453, 0.9, 0.5), 0.05, -8)
	M.put(o, C.bell(note(48), 0.9, 0.5, seed=1454, bright=0.4), 0.0, -8)
	return C.reverb(o, rt60=1.0, wet=0.2, seed=1455, lp_hz=8000)


def eye_hit(v=0):
	"""Olho do Rei atingido (ponto fraco): vidro perfurado (ping desafinado) +
	chiado molhado + guincho de coro curto — dói e soa como ACERTO CRÍTICO."""
	d = 0.7
	o = M.buf(d)
	f = note(86 + 2 * v)
	M.put(o, M.glass(f, 0.5, decay=0.2, seed=1460 + v), 0.0, -2, -0.2)
	M.put(o, M.glass(f * 1.06, 0.5, decay=0.2, seed=1461 + v), 0.0, -4, 0.2)
	k = N(0.2)
	M.put(o, M.sweep_bp(C.noise(k, 1462 + v), 2500, 900, 3.0) * C.env_ad(k, 0.002, 0.05), 0.0, -6)
	M.put(o, growl(420, 300, 0.35, 1463 + v, "i", "a", rough=40, drive=2.0, shift=1.2), 0.03, -8)
	M.put(o, thump(160, 60, 0.2, 0.04, 1464 + v, 0.3), 0.0, -6)
	return C.reverb(o, rt60=0.9, wet=0.22, seed=1465, lp_hz=10000)


def boss_death_impact():
	"""Morte 0 — IMPACTO: golpe final que PARA o tempo (baque + metal + ar sugado)."""
	d = 1.2
	o = M.buf(d)
	M.put(o, thump(90, 26, 1.0, 0.35, 1470, 0.6), 0.0, 2)
	M.put(o, C.metal_clang(140, 1.0, seed=1471, decay=0.6), 0.0, -6)
	M.put(o, grains(0.2, 1472, 20, 1000, 6000, 0.05), 0.0, -4)
	air = C.hp(C.noise(N(0.4), 1473), 2000) * C.env_ad(N(0.4), 0.001, 0.05)
	M.put(o, reverse(mono(C.lp(C.reverb(st(air), 1.2, 1.0, seed=1474), 6000))[:N(0.9)]), 0.15, -14)   # ar sugado (o tempo para)
	return C.reverb(o, rt60=1.4, wet=0.22, seed=1475, lp_hz=6000)


def boss_death_stagger():
	"""Morte 1 — CAMBALEIA: gemido grave descendo + rangido de armadura."""
	d = 1.0
	o = M.buf(d)
	M.put(o, growl(95, 60, 0.85, 1480, "o", "u", rough=22, drive=1.8), 0.0, 0)
	n = N(0.6)
	t = C.tvec(n)
	creak = C.bp(C.saw_bl(28 + 10 * np.sin(2 * np.pi * 1.5 * t), n, 40), 400, 2500) * C.env_swell(n, 0.3, 0.2)
	M.put(o, creak, 0.15, -10)
	return C.reverb(o, rt60=1.2, wet=0.2, seed=1481, lp_hz=4000)


def boss_death_collapse():
	"""Morte 2 — COLAPSO: joelho, corpo, pedra (3 baques) + estrondo baixo."""
	d = 1.3
	o = M.buf(d)
	M.put(o, thump(110, 50, 0.3, 0.06, 1490), 0.0, -4)
	M.put(o, thump(85, 35, 0.5, 0.12, 1491), 0.28, 0)
	M.put(o, thump(70, 30, 0.6, 0.18, 1492), 0.55, 2)
	M.put(o, grains(0.8, 1493, 30, 300, 3000, 0.7), 0.25, -6)
	M.put(o, rumble(1.0, 1494, 25, 120, 0.1, 0.5), 0.3, -4)
	return C.reverb(o, rt60=1.4, wet=0.18, seed=1495, lp_hz=4000)


def boss_death_hush():
	"""Morte 3 — PAUSA: quase nada. Um sopro que sai do corpo + zumbido de ouvido."""
	d = 0.7
	o = M.buf(d)
	n = N(0.6)
	ex = M.sweep_bp(C.noise(n, 1500), 900, 300, 1.2) * C.env_swell(n, 0.1, 0.25)
	M.put(o, ex, 0.0, 0)
	M.put(o, ear_ring(0.6, 5800, 1501), 0.05, -16)
	return o


def boss_death_shatter():
	"""Morte 4 — ESTILHAÇO: o corpo vira cacos de luz (vidro em cascata) +
	coro que sobe (a centelha sai) + sino grave."""
	d = 2.2
	o = M.buf(d + 0.3)
	M.put(o, reverse(shards(0.4, 1510, 8, 2000, 6000, 0.2))[-N(0.3):], 0.0, -10)
	M.put(o, shards(1.2, 1511, 40, 1500, 8000, 0.8), 0.3, 0)
	M.put(o, thump(120, 40, 0.4, 0.1, 1512, 0.5), 0.3, -4)
	ch = M.choir([note(64), note(71), note(76), note(80)], 1.6, "a", attack=0.4, release=0.8, seed=1513)
	M.put(o, ch, 0.35, -2)
	M.put(o, C.bell(note(52), 1.6, 1.2, seed=1514), 0.3, -8)
	return C.reverb(o, rt60=2.4, wet=0.3, seed=1515, lp_hz=10000)


# ----------------------------------------------------------------------------
# Chefes: golpes-assinatura (Audio.move_sfx resolve id → som; o resto cai no tipo)
# ----------------------------------------------------------------------------

def bs_melee(v=0):
	"""Golpe pesado de chefe (reserva do tipo melee): lâmina larga + peso."""
	d = 0.6
	o = M.buf(d)
	M.put(o, whoosh(0.35, 1500, 250, 0.5, 1600 + v, 1.2, 0.2), 0.0, 0)
	M.put(o, thump(100, 45, 0.3, 0.07, 1601 + v, 0.2), 0.15, -6)
	M.put(o, growl(85, 70, 0.35, 1602 + v, "o", drive=2.4), 0.0, -10)
	return tail(o, 0.6, 0.15, 1603, 5000)


def bs_cast(v=0):
	"""Feitiço de chefe (reserva do tipo cast): canto escuro que cresce."""
	d = 0.9
	o = M.buf(d + 0.3)
	M.put(o, dark_cluster([note(40), note(41), note(47)], d, 1610 + v, att=0.6, rel=0.2), 0.0, 2)
	M.put(o, M.choir([note(52), note(53)], d, "u", attack=0.5, release=0.25, seed=1611 + v), 0.0, -2)
	M.put(o, whoosh(0.5, 400, 3000, 0.9, 1612 + v, 1.0, 0.1), 0.4, -8)
	return C.reverb(o, rt60=1.4, wet=0.25, seed=1613, lp_hz=5000)


def bs_leap():
	"""Salto do chefe: tomada de impulso + sopro subindo e sumindo."""
	d = 0.8
	o = M.buf(d)
	M.put(o, thump(90, 40, 0.4, 0.1, 1620, 0.5), 0.0, 0)
	M.put(o, whoosh(0.7, 200, 2500, 0.3, 1621, 0.8, 0.4), 0.02, -2)
	return o


def bs_land():
	"""Queda do chefe: estrondo + rachadura de chão."""
	d = 1.0
	o = M.buf(d)
	M.put(o, reverse(whoosh(0.25, 3000, 600, 0.1, 1630, 1.0, 0.6)), 0.0, -8)
	M.put(o, stone_hit(1631, 80, 0.8), 0.22, 2)
	M.put(o, rumble(0.7, 1632, 25, 140, 0.02, 0.35), 0.22, -2)
	return C.reverb(o, rt60=1.0, wet=0.18, seed=1633, lp_hz=5000)


def bs_yawn():
	"""Athoth (Torpor) — bocejo: voz gigante 'a→o' descendo, com ar."""
	d = 1.6
	o = M.buf(d + 0.4)
	M.put(o, growl(110, 70, 1.5, 1640, "a", "o", rough=12, drive=1.4, breath=0.8), 0.0, 0)
	M.put(o, M.sweep_bp(C.noise(N(1.4), 1641), 1200, 300, 1.0) * C.env_swell(N(1.4), 0.5, 0.5), 0.0, -8)
	return C.reverb(o, rt60=2.0, wet=0.3, seed=1642, lp_hz=4000)


def bs_lullaby():
	"""Athoth — canção de ninar: caixinha de música desafinada que desacelera."""
	d = 2.0
	o = M.buf(d + 0.6)
	mel = [76, 79, 74, 76, 72, 71]
	at = 0.0
	for i, m in enumerate(mel):
		f = note(m) * (1 - 0.012 * i)
		M.put(o, C.bell(f, 0.8, 0.5, seed=1650 + i, bright=0.6) * 0.8, at, -i * 0.5, (i % 2 - 0.5) * 0.6)
		at += 0.24 + 0.05 * i
	return C.reverb(M.sat(C.lp(o, 5000), 1.2), rt60=1.8, wet=0.35, seed=1656, lp_hz=5000)


def bs_rain():
	"""Athoth — chuva de orbes: pingos de sono caindo de cima, espalhados."""
	d = 1.4
	o = M.buf(d + 0.4)
	r = C.rng(1660)
	for i in range(12):
		f = note(r.choice([72, 74, 76, 79, 81]))
		M.put(o, M.glass(f, 0.4, decay=0.12, seed=1661 + i, bright=0.5), r.uniform(0, 1.2), -r.uniform(0, 8), r.uniform(-0.9, 0.9))
	return C.reverb(C.lp(o, 6000), rt60=1.6, wet=0.35, seed=1680, lp_hz=5000)


def bs_suck():
	"""Harmas (Fome) — sucção: inspiração enorme e úmida que cresce."""
	d = 1.2
	o = M.buf(d)
	M.put(o, suck(1.1, 1690, 5000, 150), 0.0, 0)
	M.put(o, growl(60, 90, 1.1, 1691, "u", "o", rough=20, drive=1.6) * np.linspace(0.2, 1, N(1.1)), 0.0, -8)
	r = C.rng(1692)
	for i in range(6):
		M.put(o, M.bubble(r.uniform(200, 500), 1693 + i, 0.06), 0.3 + 0.12 * i, -12)
	return o


def bs_bite():
	"""Harmas/Belias — mordida: duas dentadas pesadas e molhadas + rosnado."""
	d = 0.7
	o = M.buf(d)
	M.put(o, bite(1700, 75), 0.0, 0)
	M.put(o, bite(1701, 65), 0.2, 1)
	M.put(o, growl(80, 60, 0.6, 1702, "o", rough=30, drive=3.0), 0.0, -8)
	return tail(o, 0.5, 0.12, 1703, 5000)


def bs_breath():
	"""Sopro (Harmas/Yabel): rajada rugindo, grave e larga."""
	d = 1.2
	o = M.buf(d)
	n = N(1.1)
	t = C.tvec(n)
	g = M.sweep_bp(C.noise(n, 1710), 300, 1500, 0.8) * C.env_swell(n, 0.25, 0.5) * (1 - 0.4 * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t)))
	M.put(o, g, 0.0, 0)
	M.put(o, growl(70, 60, 1.0, 1711, "a", "o", rough=23, drive=2.0) * 0.6, 0.0, -6)
	return C.reverb(o, rt60=1.0, wet=0.2, seed=1712, lp_hz=5000)


def bs_cage():
	"""Galila (Corrente) — prisão: 3 grades de ferro descendo + correntes."""
	d = 1.4
	o = M.buf(d)
	for i in range(3):
		M.put(o, C.metal_clang(180 - 20 * i, 0.8, seed=1720 + i, decay=0.4), 0.18 * i, -2, (i - 1) * 0.6)
		M.put(o, thump(100, 45, 0.3, 0.06, 1723 + i, 0.4), 0.18 * i, -6, (i - 1) * 0.6)
	M.put(o, links(0.9, 1726, 12, 1400, 0.8, decay=0.15), 0.1, -10)
	return C.reverb(o, rt60=1.6, wet=0.25, seed=1727, lp_hz=5000)


def bs_scream():
	"""Yabel (Silêncio) — grito: guincho que sobe e CORTA seco → zumbido."""
	d = 1.6
	o = M.buf(d)
	g = growl(500, 900, 0.7, 1730, "a", "i", rough=40, drive=2.8, shift=1.25)
	M.put(o, g, 0.0, 0)
	M.put(o, whoosh(0.7, 800, 6000, 0.98, 1731, 1.0, 0.01), 0.0, -6)
	M.put(o, ear_ring(0.9, 7000, 1732), 0.72, -14)
	return o


def bs_pages():
	"""Yabel — pergaminhos: revoada de papel + sussurros."""
	d = 1.1
	o = M.buf(d)
	r = C.rng(1740)
	for i in range(14):
		k = N(0.05)
		fl = C.bp(C.noise(k, 1741 + i), 1500, 6000) * C.env_ad(k, 0.002, 0.012)
		M.put(o, fl, r.uniform(0, 0.8), -r.uniform(0, 8), r.uniform(-0.8, 0.8))
	M.put(o, whoosh(0.9, 800, 3000, 0.4, 1760, 1.0), 0.0, -8)
	return C.reverb(o, rt60=0.9, wet=0.25, seed=1761, lp_hz=8000)


def bs_wings():
	"""Yabel — asas: duas batidas grandes (corpo de pano + vento)."""
	d = 1.0
	o = M.buf(d)
	M.put(o, wing(0.45, 1770, 350), 0.0, 0)
	M.put(o, wing(0.45, 1771, 320), 0.35, 0)
	return C.reverb(o, rt60=1.2, wet=0.2, seed=1772, lp_hz=5000)


def bs_split():
	"""Astaphaios (Espelho) — reflexos: acorde de vidro que se DIVIDE nos dois lados."""
	d = 1.4
	o = M.buf(d)
	for i, m in enumerate([69, 72, 76, 81]):
		M.put(o, M.glass(note(m), 1.0, decay=0.5, seed=1780 + i), 0.08 * i, -2, -0.8)
		M.put(o, M.glass(note(m) * 1.003, 1.0, decay=0.5, seed=1790 + i), 0.08 * i + 0.12, -4, 0.8)
	return C.reverb(o, rt60=1.8, wet=0.3, seed=1799, lp_hz=11000)


def bs_swap():
	"""Astaphaios — troca: vidro ao contrário de um lado, estalo do outro."""
	d = 0.7
	o = M.buf(d)
	M.put(o, reverse(M.glass(note(84), 0.35, decay=0.12, seed=1800)), 0.0, 0, -0.8)
	M.put(o, suck(0.3, 1801, 6000, 800), 0.0, -8, -0.4)
	M.put(o, thump(500, 150, 0.1, 0.02, 1802, 0.5), 0.33, -4, 0.8)
	M.put(o, M.glass(note(84), 0.35, decay=0.12, seed=1803), 0.33, -2, 0.8)
	return C.reverb(o, rt60=1.0, wet=0.25, seed=1804, lp_hz=10000)


def bs_spores():
	"""Belias (Praga) — esporos: sopros úmidos espalhados + bolhas."""
	d = 1.2
	o = M.buf(d)
	r = C.rng(1810)
	for i in range(7):
		k = N(0.18)
		puff = C.bp(C.noise(k, 1811 + i), 400, 2500) * C.env_ad(k, 0.003, 0.05)
		M.put(o, puff, 0.12 * i, -r.uniform(0, 4), r.uniform(-0.8, 0.8))
		M.put(o, M.bubble(r.uniform(180, 420), 1820 + i, 0.07), 0.12 * i + 0.03, -8)
	return C.reverb(o, rt60=0.9, wet=0.2, seed=1830, lp_hz=5000)


def bs_cloud():
	"""Belias — nuvem: gás sibilando que cresce + enxame miúdo."""
	d = 1.6
	o = M.buf(d)
	n = N(1.5)
	t = C.tvec(n)
	M.put(o, C.bp(C.noise(n, 1840), 2000, 7000) * C.env_swell(n, 0.6, 0.6) * 0.8, 0.0, 0)
	sw = sum(np.sin(C.osc_phase(f * (1 + 0.02 * np.sin(2 * np.pi * (5 + i) * t)), n)) for i, f in enumerate([220, 233, 247, 262]))
	M.put(o, sw * C.env_swell(n, 0.7, 0.5) * 0.25, 0.0, -6)
	return o


def bs_burrow():
	"""Belias — enterrar: escavar descendo (terra + grave que afunda)."""
	d = 1.0
	o = M.buf(d)
	M.put(o, grains(0.8, 1850, 40, 300, 2500, 0.7), 0.0, 0)
	n = N(0.9)
	t = C.tvec(n)
	M.put(o, np.sin(C.osc_phase(90 * (0.4 ** (t / 0.9)), n)) * C.env_ad(n, 0.05, 0.4), 0.0, -2)
	M.put(o, rumble(0.9, 1851, 30, 200, 0.05, 0.4), 0.0, -4)
	return o


def bs_decree():
	"""Armupiel (Coroa) — decreto: gongo + coro masculino em uníssono que proclama."""
	d = 1.8
	o = M.buf(d + 0.4)
	M.put(o, C.metal_clang(110, 1.6, seed=1860, decay=1.2), 0.0, -2)
	ch = M.choir([note(43), note(50), note(55)], 1.4, "o", vowel2="a", shift=0.85, attack=0.1, release=0.5, seed=1861, voices=3)
	M.put(o, ch, 0.05, 2)
	return C.reverb(o, rt60=2.4, wet=0.3, seed=1862, lp_hz=5000)


def bs_coronation():
	"""Armupiel — coroação: coro que sobe + sinos dourados + metal da coroa."""
	d = 2.2
	o = M.buf(d + 0.5)
	ch = M.choir([note(48), note(55), note(60), note(64)], 2.0, "a", attack=0.8, release=0.6, seed=1870, voices=2)
	M.put(o, ch, 0.0, 2)
	for i, m in enumerate([72, 76, 79, 84]):
		M.put(o, C.bell(note(m), 1.0, 0.8, seed=1871 + i, bright=1.1), 0.9 + 0.12 * i, -8, (i - 1.5) * 0.4)
	M.put(o, C.metal_clang(260, 1.0, seed=1876, decay=0.8), 0.9, -10)
	return C.reverb(o, rt60=2.6, wet=0.3, seed=1877, lp_hz=8000)


def bs_royal_cut():
	"""Armupiel — corte real: lâmina dourada pesada (shing longo) + ar cortado."""
	d = 0.8
	o = M.buf(d)
	M.put(o, whoosh(0.4, 2500, 300, 0.45, 1880, 1.4, 0.2), 0.0, 0)
	k = N(0.5)
	M.put(o, M.sweep_bp(C.noise(k, 1881), 3000, 7000, 5.0) * C.env_ad(k, 0.01, 0.15), 0.12, -6)
	M.put(o, C.metal_clang(600, 0.6, seed=1882, decay=0.35), 0.15, -10)
	M.put(o, thump(110, 45, 0.3, 0.06, 1883), 0.15, -6)
	return tail(o, 0.9, 0.18, 1884, 8000)


def bs_sweep():
	"""Armupiel — varredura: sopro LARGO e longo de um lado ao outro."""
	d = 0.9
	o = M.buf(d)
	w = whoosh(0.8, 300, 1800, 0.5, 1890, 0.8, 0.25)
	n = len(w)
	p = np.linspace(-0.8, 0.8, n)
	a = (p + 1) * np.pi / 4
	o[:n, 0] += w * np.cos(a)
	o[:n, 1] += w * np.sin(a)
	M.put(o, growl(80, 70, 0.6, 1891, "o", drive=2.0), 0.1, -12)
	return o


def bs_ray():
	"""Rei — raio: zumbido de luz roubada (serra brilhante em coro) + estouro."""
	d = 1.1
	o = M.buf(d + 0.3)
	n = N(1.0)
	t = C.tvec(n)
	f = note(57)
	hum = sum(C.saw_bl(f * k * (1 + 0.004 * i), n, 20) for i, k in enumerate([1.0, 1.5, 2.0]))
	hum = C.bp(hum, 300, 4000) * C.env_ad(n, 0.02, 0.5, 0.3) * (1 + 0.3 * np.sin(2 * np.pi * 31 * t))
	M.put(o, hum * 0.4, 0.0, 0)
	M.put(o, thump(120, 40, 0.4, 0.1, 1900, 0.5), 0.0, -4)
	M.put(o, M.choir([note(69), note(76)], 0.9, "a", attack=0.02, release=0.5, seed=1901), 0.0, -6)
	return C.reverb(o, rt60=1.4, wet=0.22, seed=1902, lp_hz=8000)


def bs_hand():
	"""Rei — mão: mão gigante descendo (sopro grave) + pancada enorme."""
	d = 1.2
	o = M.buf(d)
	M.put(o, whoosh(0.45, 2000, 200, 0.9, 1910, 1.0, 0.05), 0.0, -4)
	M.put(o, stone_hit(1911, 70, 0.9), 0.42, 2)
	M.put(o, C.metal_clang(80, 0.8, seed=1912, decay=0.6), 0.42, -10)
	return C.reverb(o, rt60=1.4, wet=0.2, seed=1913, lp_hz=5000)


def bs_rings():
	"""Rei — anéis: os 7 tons dos Anéis girando em volta (espiral estéreo)."""
	d = 1.6
	o = M.buf(d + 0.4)
	ring_notes = [62, 64, 65, 67, 69, 70, 72]   # Ré Mi Fá Sol Lá Si♭ Dó (os 7 Éons)
	for i, m in enumerate(ring_notes):
		p = np.sin(i * 0.9)
		M.put(o, M.glass(note(m + 12), 0.6, decay=0.25, seed=1920 + i), 0.12 * i, -2, p)
		M.put(o, C.metal_clang(note(m), 0.4, seed=1930 + i, decay=0.2), 0.12 * i, -14, -p)
	return C.reverb(o, rt60=1.8, wet=0.3, seed=1940, lp_hz=9000)


def bs_collapse():
	"""Colosso — desabamento: rochas caindo do teto em cascata."""
	d = 1.8
	o = M.buf(d)
	r = C.rng(1950)
	for i in range(7):
		M.put(o, stone_hit(1951 + i, r.uniform(70, 140), 0.5), 0.1 + 0.2 * i + r.uniform(0, 0.08), -r.uniform(0, 6), r.uniform(-0.8, 0.8))
	M.put(o, rumble(1.6, 1960, 25, 160, 0.2, 0.8), 0.0, -2)
	return C.reverb(o, rt60=1.6, wet=0.2, seed=1961, lp_hz=4000)


# ----------------------------------------------------------------------------
# Perigos do level6 (`hz_*`) — o perigo SE ANUNCIA pelo som próprio; o aviso
# padrão (tell_unblock) continua para a leitura do combate.
# ----------------------------------------------------------------------------

def hz_tide_wake():
	"""Maré escura acorda: muralha de treva subindo + sussurros de olhos."""
	d = 2.4
	o = M.buf(d)
	M.put(o, dark_cluster([note(31), note(32), note(37)], 2.2, 2000, att=1.2, rel=0.8, lp_hz=600), 0.0, 4)
	M.put(o, rumble(2.2, 2001, 25, 120, 1.0, 1.0), 0.0, 0)
	M.put(o, M.sweep_bp(C.noise(N(2.0), 2002), 300, 1200, 1.0) * C.env_swell(N(2.0), 1.4, 0.5), 0.2, -8)
	return C.reverb(o, rt60=2.0, wet=0.3, seed=2003, lp_hz=3000)


def hz_tide_tick():
	"""Maré corroendo (tique de dano): chiado ácido curto."""
	d = 0.3
	k = N(0.25)
	# repete a cada 0,45 s: chiado em 600–2400 Hz, sem agudo cansativo (R12)
	x = C.bp(C.noise(k, 2010), 600, 2400) * C.env_ad(k, 0.005, 0.07) * (1 + 0.5 * np.sin(2 * np.pi * 60 * C.tvec(k)))
	return st(x + thump(90, 50, 0.25, 0.05, 2011, 0.0) * 0.5)


def hz_guillotine():
	"""Guilhotina cai: ferro raspando no trilho (rápido) + CHOP pesado."""
	d = 0.8
	o = M.buf(d)
	k = N(0.12)
	M.put(o, M.sweep_bp(C.noise(k, 2020), 4000, 1500, 4.0) * C.env_swell(k, 0.1, 0.01), 0.0, -4)
	M.put(o, C.metal_clang(240, 0.6, seed=2021, decay=0.3), 0.11, -2)
	M.put(o, thump(120, 45, 0.4, 0.08, 2022, 0.6), 0.11, 0)
	return tail(o, 0.6, 0.15, 2023, 6000)


def hz_winch():
	"""Guilhotina sobe: catraca de manivela."""
	d = 0.35
	o = M.buf(d)
	for i in range(5):
		M.put(o, C.metal_clang(1800, 0.06, seed=2030 + i, decay=0.02), 0.06 * i, -2)
	return o


def hz_maw_bite():
	"""Boca do chão morde: dentada de pedra molhada + rosnado da fenda."""
	d = 0.8
	o = M.buf(d)
	M.put(o, bite(2040, 70), 0.0, 0)
	M.put(o, grains(0.3, 2041, 12, 400, 2500, 0.1), 0.0, -6)
	M.put(o, growl(65, 50, 0.6, 2042, "o", rough=25, drive=2.6), 0.02, -8)
	return tail(o, 0.6, 0.15, 2043, 4000)


def hz_maw_warn():
	"""Boca acordando (aviso): rosnado grave subindo da rachadura."""
	d = 0.8
	n = N(0.75)
	t = C.tvec(n)
	g = growl(55, 75, 0.75, 2050, "u", "o", rough=21, drive=2.0) * (t / 0.75)
	return st(C.lp(g, 1500))


def hz_beam_on():
	"""Feixe do espelho acende: zumbido de vidro em laser (1,2 s)."""
	d = 1.3
	o = M.buf(d)
	n = N(1.2)
	t = C.tvec(n)
	f = note(81)
	hum = (np.sin(C.osc_phase(f, n)) + 0.6 * np.sin(C.osc_phase(f * 2.32, n)) + 0.3 * np.sin(C.osc_phase(f * 1.007, n))) * (1 + 0.25 * np.sin(2 * np.pi * 37 * t))
	e = np.clip(t / 0.03, 0, 1) * np.clip((1.2 - t) / 0.08, 0, 1)
	M.put(o, hum * e * 0.4, 0.0, 0)
	M.put(o, M.glass(f * 2, 0.4, decay=0.15, seed=2060), 0.0, -6)
	M.put(o, C.hp(C.noise(n, 2061), 5000) * e * 0.15, 0.0, -10)
	return o


def hz_beam_off():
	"""Feixe apaga: vidro que esfria (tom caindo curto)."""
	d = 0.3
	n = N(0.25)
	t = C.tvec(n)
	x = np.sin(C.osc_phase(note(81) * (0.6 ** (t / 0.25)), n)) * C.env_ad(n, 0.002, 0.06)
	return st(x)


def hz_mirror_warn():
	"""Plataforma-reflexo vai sumir: vidro tremendo (trêmulo 12 Hz)."""
	d = 0.6
	n = N(0.6)
	t = C.tvec(n)
	f = note(88)
	x = (np.sin(C.osc_phase(f, n)) + 0.4 * np.sin(C.osc_phase(f * 2.32, n))) * (0.5 + 0.5 * np.sin(2 * np.pi * 12 * t)) * C.env_swell(n, 0.4, 0.1)
	return C.reverb(st(x), rt60=0.6, wet=0.2, seed=2070, lp_hz=11000)


def hz_mirror_flip():
	"""Plataforma-reflexo troca de lado: sopro de vidro de um canal ao outro."""
	d = 0.5
	o = M.buf(d)
	M.put(o, reverse(M.glass(note(83), 0.25, decay=0.08, seed=2080)), 0.0, -2, -0.6)
	M.put(o, M.glass(note(90), 0.3, decay=0.1, seed=2081), 0.25, -4, 0.6)
	return C.reverb(o, rt60=0.8, wet=0.25, seed=2082, lp_hz=11000)


def hz_mist_breath():
	"""Névoa do Torpor respira: inspira-expira lento e sonolento + caixinha abafada."""
	d = 2.6
	o = M.buf(d)
	n = N(2.4)
	t = C.tvec(n)
	breath = M.sweep_bp(C.noise(n, 2090), 250, 900, 0.8) * np.sin(np.pi * t / 2.4) ** 2
	M.put(o, breath, 0.0, 0)
	M.put(o, C.lp(C.bell(note(74) * 0.99, 1.5, 0.8, seed=2091, bright=0.3), 2000), 0.9, -12)
	return C.reverb(o, rt60=1.8, wet=0.3, seed=2092, lp_hz=3000)


def hz_chain_swing(v=0):
	"""Pêndulo de corrente: rangido do elo no topo + lâmina cortando o ar."""
	d = 0.8
	o = M.buf(d)
	n = N(0.35)
	t = C.tvec(n)
	creak = C.bp(C.saw_bl(40 + 25 * np.sin(2 * np.pi * 2 * t), n, 40), 500, 3000) * C.env_swell(n, 0.15, 0.1)
	M.put(o, creak, 0.0, -10)
	M.put(o, links(0.3, 2100 + v, 4, 800, 0.2, decay=0.08), 0.0, -10)
	M.put(o, whoosh(0.5, 300 + 80 * v, 1500, 0.5, 2105 + v, 1.4, 0.2), 0.12, 0)
	return C.lp(o, 3000)   # repete a cada meio período: corpo grave, sem 2–5 kHz sustentado (R12)


def hz_bell_toll():
	"""Badalo do Silêncio (o sino MUDO): baque de bronze abafado, sem brilho,
	com o ar sendo puxado depois — o som que 'apaga' o som."""
	d = 1.6
	o = M.buf(d)
	b = C.lp(C.bell(note(40), 1.4, 0.7, seed=2110, bright=0.1), 700)
	M.put(o, b, 0.0, 0)
	M.put(o, thump(90, 45, 0.4, 0.1, 2111, 0.2), 0.0, -4)
	M.put(o, suck(0.6, 2112, 4000, 300), 0.4, -10)
	return C.reverb(o, rt60=1.6, wet=0.25, seed=2113, lp_hz=2000)


def hz_ether_drain():
	"""Éter arrancado: vidro sugado para baixo + crepitar azul."""
	d = 0.8
	o = M.buf(d)
	M.put(o, glass_gliss(note(96), note(72), 0.4, 2120, count=6, tau=0.08), 0.0, -2)
	M.put(o, suck(0.5, 2121, 7000, 1000), 0.0, -8)
	M.put(o, grains(0.4, 2122, 14, 3000, 8000, 0.35), 0.0, -12)
	return o


def hz_silence_in():
	"""Entrar no campo de silêncio: o som é SUGADO (sopro crescente) e corta;
	sobra só um zumbido de ouvido baixinho."""
	d = 1.2
	o = M.buf(d)
	burst = C.hp(C.noise(N(0.2), 2130), 800) * C.env_ad(N(0.2), 0.001, 0.04)
	swell = reverse(mono(C.reverb(st(burst), 0.6, 1.0, seed=2131)))[-N(0.45):]   # reverb ao contrário: o som é puxado
	M.put(o, swell, 0.0, -2)
	M.put(o, ear_ring(0.7, 6500, 2132), 0.45, -12)
	return o


def hz_silence_out():
	"""Sair do campo: ouvido destampando (estalo grave + ar de volta)."""
	d = 0.5
	o = M.buf(d)
	M.put(o, thump(220, 90, 0.12, 0.03, 2140, 0.1), 0.0, -2)
	M.put(o, whoosh(0.4, 300, 4000, 0.3, 2141, 0.8, 0.4), 0.02, -6)
	return o


def hz_sink_start():
	"""Pedra adormecida afunda: ranger de pedra grave + bolhas de lodo."""
	d = 1.2
	o = M.buf(d)
	n = N(1.1)
	t = C.tvec(n)
	grind = C.bp(C.noise(n, 2150), 80, 600) * (1 + 0.6 * np.sin(2 * np.pi * 14 * t)) * C.env_swell(n, 0.4, 0.4) * 2
	M.put(o, grind, 0.0, 0)
	r = C.rng(2151)
	for i in range(5):
		M.put(o, M.bubble(r.uniform(120, 300), 2152 + i, 0.1), 0.2 + 0.18 * i, -6)
	return o


def hz_sink_gone():
	"""Pedra some no fundo: 'plof' grave e abafado."""
	d = 0.6
	o = M.buf(d)
	M.put(o, M.bubble(110, 2160, 0.25), 0.0, 0)
	M.put(o, C.lp(thump(70, 35, 0.4, 0.1, 2161, 0.0), 400), 0.0, -2)
	return C.reverb(o, rt60=0.8, wet=0.2, seed=2162, lp_hz=2000)


def hz_sink_return():
	"""Pedra volta: subida suave (pedra + caixinha)."""
	d = 0.7
	o = M.buf(d)
	n = N(0.5)
	t = C.tvec(n)
	M.put(o, C.bp(C.noise(n, 2170), 100, 500) * C.env_swell(n, 0.35, 0.1), 0.0, -4)
	M.put(o, C.lp(C.bell(note(79), 0.5, 0.3, seed=2171, bright=0.3), 3000), 0.35, -10)
	return o


def hz_spears(v=0):
	"""Lanças da guarda brotam: 3 'shink' de ferro em cascata + estalo de pedra."""
	d = 0.6
	o = M.buf(d)
	for i in range(3):
		k = N(0.12)
		sh = M.sweep_bp(C.noise(k, 2180 + i + v * 5), 2000, 6500, 4.0) * C.env_ad(k, 0.002, 0.04)
		M.put(o, sh, 0.035 * i, -2, (i - 1) * 0.5)
		M.put(o, C.metal_clang(900 + 120 * i, 0.25, seed=2185 + i + v * 5, decay=0.08), 0.035 * i, -12, (i - 1) * 0.5)
	M.put(o, grains(0.2, 2190 + v, 8, 800, 3000, 0.05), 0.0, -8)
	return o


def hz_shackles():
	"""Grilhões do chão: correntes saltando + argola que FECHA (clank)."""
	d = 0.7
	o = M.buf(d)
	M.put(o, links(0.3, 2200, 7, 1300, 0.18, accel=True), 0.0, -2)
	M.put(o, C.metal_clang(380, 0.5, seed=2201, decay=0.2), 0.2, 0)
	M.put(o, thump(140, 70, 0.2, 0.04, 2202, 0.5), 0.2, -8)
	return tail(o, 0.5, 0.15, 2203, 6000)


def hz_spore_swell():
	"""Cápsula de esporos incha: rangido orgânico úmido subindo."""
	d = 0.8
	n = N(0.75)
	t = C.tvec(n)
	x = M.sweep_bp(C.noise(n, 2210), 200, 900, 2.0) * (t / 0.75) ** 1.5 * (1 + 0.5 * np.sin(2 * np.pi * 9 * t))
	x += np.sin(C.osc_phase(80 + 60 * t / 0.75, n)) * (t / 0.75) ** 2 * 0.3
	return st(x)


def hz_spore_burst():
	"""Cápsula estoura: 'plop' molhado + sopro de nuvem chiando."""
	d = 1.0
	o = M.buf(d)
	M.put(o, M.bubble(160, 2220, 0.15) * 1.5, 0.0, 0)
	M.put(o, thump(200, 80, 0.15, 0.03, 2221, 0.4), 0.0, -4)
	n = N(0.8)
	M.put(o, C.bp(C.noise(n, 2222), 1200, 5000) * C.env_ad(n, 0.01, 0.25) * 0.8, 0.02, -4)
	return o


def hz_spore_pop():
	"""Cápsula destruída: estalo seco + sopro fraco."""
	d = 0.5
	o = M.buf(d)
	M.put(o, M.chomp(2230, 0.12, 120), 0.0, 0)
	M.put(o, C.bp(C.noise(N(0.4), 2231), 1000, 4000) * C.env_ad(N(0.4), 0.005, 0.1) * 0.5, 0.02, -8)
	return o


def hz_shard_warn():
	"""Céu rachando (sombra no chão): vidro estalando lá no alto."""
	d = 0.6
	o = M.buf(d)
	M.put(o, grains(0.5, 2240, 10, 3000, 8000, 0.4), 0.0, -2)
	M.put(o, M.glass(note(96), 0.4, decay=0.1, seed=2241, bright=0.5), 0.1, -12)
	return C.reverb(o, rt60=1.4, wet=0.35, seed=2242, lp_hz=10000)


def hz_shard_fall():
	"""Caco caindo: assobio de vidro descendo (0,18 s)."""
	d = 0.25
	n = N(0.2)
	t = C.tvec(n)
	f = 4500 * (1500 / 4500) ** (t / 0.2)
	x = np.sin(C.osc_phase(f, n)) * C.env_swell(n, 0.15, 0.03) * 0.5 + M.sweep_bp(C.noise(n, 2250), 6000, 2000, 3.0) * C.env_swell(n, 0.15, 0.03)
	return st(x)


def hz_shard_impact(v=0):
	"""Caco se espatifa no chão."""
	d = 0.8
	o = M.buf(d)
	M.put(o, shards(0.7, 2260 + v * 3, 16, 2000, 7000, 0.15), 0.0, 0)
	M.put(o, thump(220, 90, 0.15, 0.03, 2261 + v, 0.6), 0.0, -6)
	return C.reverb(o, rt60=0.8, wet=0.2, seed=2262, lp_hz=10000)


def hz_totem_arm():
	"""Totem profano acorda: zumbido grave em trítono acendendo."""
	d = 1.2
	o = M.buf(d)
	M.put(o, dark_cluster([note(33), note(39)], 1.1, 2270, att=0.4, rel=0.5, lp_hz=1200), 0.0, 4)
	M.put(o, thump(60, 30, 0.5, 0.2, 2271, 0.2), 0.0, -4)
	return C.reverb(o, rt60=1.2, wet=0.2, seed=2272, lp_hz=3000)


def hz_totem_summon():
	"""Totem chama reforço: canto invertido + rasgo (portal escuro)."""
	d = 1.2
	o = M.buf(d)
	ch = M.choir([note(41), note(47)], 0.8, "u", attack=0.6, release=0.05, seed=2280)
	M.put(o, ch, 0.0, 0)
	M.put(o, suck(0.7, 2281, 3000, 200), 0.0, -6)
	M.put(o, thump(100, 40, 0.4, 0.1, 2282, 0.4), 0.72, -2)
	M.put(o, grains(0.3, 2283, 10, 500, 2500, 0.2), 0.72, -8)
	return C.reverb(o, rt60=1.2, wet=0.25, seed=2284, lp_hz=4000)


def hz_totem_hit(v=0):
	"""Totem atingido: pedra oca ressoando (não madeira)."""
	d = 0.5
	o = M.buf(d)
	M.put(o, thump(180 - 15 * v, 80, 0.3, 0.05, 2290 + v, 0.5), 0.0, 0)
	M.put(o, C.resonator(C.noise(N(0.4), 2292 + v) * C.env_ad(N(0.4), 0.001, 0.01), 340 - 20 * v, 30) * 3, 0.0, -6)
	return o


def hz_totem_break():
	"""Totem desaba: pedra rachando em cascata + o mal expirando."""
	d = 1.6
	o = M.buf(d)
	M.put(o, grains(1.0, 2300, 40, 300, 4000, 0.8, decay_tau=0.2), 0.0, 0)
	M.put(o, thump(90, 35, 0.6, 0.2, 2301, 0.4), 0.0, 0)
	M.put(o, growl(90, 50, 0.9, 2302, "o", "u", rough=18, drive=1.6), 0.2, -8)
	M.put(o, C.bell(note(64), 1.0, 0.8, seed=2303, bright=0.8), 0.4, -10)
	return C.reverb(o, rt60=1.4, wet=0.22, seed=2304, lp_hz=6000)


def hz_ward_drain():
	"""Luz do Adormecido sendo drenada: chama tremeluzindo, chiado frio."""
	d = 0.5
	n = N(0.45)
	t = C.tvec(n)
	# banda 900–2500 Hz: repete enquanto drena — nada de 2–5 kHz sustentado (R12)
	x = C.bp(C.noise(n, 2310), 900, 2500) * (0.5 + 0.5 * np.sin(2 * np.pi * 17 * t)) * C.env_swell(n, 0.15, 0.2)
	x += np.sin(C.osc_phase(note(84) * (1 - 0.05 * t / 0.45), n)) * C.env_swell(n, 0.1, 0.2) * 0.2
	return st(x)


def hz_ward_out():
	"""A luz apaga: vela soprada + sino de vidro descendo e morrendo."""
	d = 1.2
	o = M.buf(d)
	M.put(o, whoosh(0.25, 2000, 600, 0.3, 2320, 1.0), 0.0, -2)
	M.put(o, glass_gliss(note(84), note(64), 0.6, 2321, count=4, tau=0.25), 0.1, -4)
	return C.reverb(o, rt60=1.6, wet=0.3, seed=2322, lp_hz=6000)


def hz_ward_saved():
	"""A luz resistiu: acorde de coro em Mi maior que respira aliviado."""
	d = 1.8
	o = M.buf(d + 0.3)
	M.put(o, M.choir([note(64), note(68), note(71)], 1.6, "a", attack=0.3, release=0.8, seed=2330), 0.0, 2)
	M.put(o, C.bell(note(76), 1.2, 0.8, seed=2331), 0.1, -8)
	return C.reverb(o, rt60=2.0, wet=0.3, seed=2332, lp_hz=9000)


def hz_altar():
	"""Altar do Santuário cura: água de luz + acorde sacro (Mi maior aberto)."""
	d = 2.2
	o = M.buf(d + 0.3)
	M.put(o, M.choir([note(52), note(59), note(64), note(68)], 2.0, "o", vowel2="a", attack=0.4, release=1.0, seed=2340), 0.0, 2)
	M.put(o, glass_gliss(note(76), note(88), 0.6, 2341, count=5, tau=0.3), 0.15, -6)
	r = C.rng(2342)
	for i in range(5):
		M.put(o, M.bubble(r.uniform(600, 1200), 2343 + i, 0.05), 0.1 + 0.15 * i, -14, r.uniform(-0.6, 0.6))
	return C.reverb(o, rt60=2.6, wet=0.35, seed=2350, lp_hz=10000)


def hz_altar_hum():
	"""Coluna de luz do altar (presença, perto dele): zumbido sacro baixinho."""
	d = 2.0
	n = N(2.0)
	t = C.tvec(n)
	x = sum(np.sin(C.osc_phase(note(m) * (1 + 0.002 * np.sin(2 * np.pi * 0.5 * t)), n)) / (i + 1) for i, m in enumerate([52, 59, 64, 71]))
	x *= np.sin(np.pi * t / 2.0) ** 2
	return C.reverb(st(x * 0.4), rt60=2.0, wet=0.3, seed=2360, lp_hz=6000)


def hz_secret_mark():
	"""Marca do segredo acende (pulo duplo): brilho dourado de 2 notas."""
	d = 0.9
	o = M.buf(d)
	M.put(o, M.glass(note(83), 0.6, decay=0.25, seed=2370), 0.0, 0, -0.2)
	M.put(o, M.glass(note(88), 0.6, decay=0.3, seed=2371), 0.12, -2, 0.2)
	return C.reverb(o, rt60=1.2, wet=0.3, seed=2372, lp_hz=11000)


def hz_secret_open():
	"""Sala secreta / selo abre: pedra deslizando + correntes caindo + coro."""
	d = 2.6
	o = M.buf(d + 0.3)
	n = N(1.4)
	t = C.tvec(n)
	slide = C.bp(C.noise(n, 2380), 80, 900) * (1 + 0.4 * np.sin(2 * np.pi * 11 * t)) * C.env_swell(n, 0.5, 0.5) * 2
	M.put(o, slide, 0.0, 0)
	M.put(o, links(0.8, 2381, 10, 1100, 0.6, decay=0.2), 0.2, -8)
	M.put(o, thump(80, 35, 0.6, 0.2, 2382), 1.3, -2)
	M.put(o, M.choir([note(64), note(71), note(76)], 1.2, "a", attack=0.2, release=0.8, seed=2383), 1.3, -2)
	M.put(o, glass_gliss(note(76), note(95), 0.5, 2384, count=6, tau=0.2), 1.35, -8)
	return C.reverb(o, rt60=2.2, wet=0.3, seed=2385, lp_hz=9000)


def hz_column():
	"""Perigo de chefe golpeia (coluna/arena): estouro de energia escura vertical."""
	d = 0.8
	o = M.buf(d)
	M.put(o, thump(100, 35, 0.5, 0.14, 2390, 0.5), 0.0, 0)
	M.put(o, whoosh(0.5, 400, 5000, 0.05, 2391, 0.8, 0.4), 0.0, -4)
	M.put(o, dark_cluster([note(45), note(46)], 0.5, 2392, att=0.01, rel=0.4, lp_hz=3000), 0.0, -2)
	return o


def hz_saw():
	"""Serra-Anel girando (perigo do chefe): zunido metálico com giro (AM 18 Hz)."""
	d = 1.0
	n = N(1.0)
	t = C.tvec(n)
	f = 380
	x = C.bp(C.saw_bl(f, n, 40) + 0.5 * C.saw_bl(f * 1.47, n, 30), 400, 5000) * (0.6 + 0.4 * np.sin(2 * np.pi * 18 * t))
	x *= np.clip(t / 0.05, 0, 1) * np.clip((1.0 - t) / 0.1, 0, 1)
	return st(x * 0.4)


# ----------------------------------------------------------------------------
# UI nova + roubo
# ----------------------------------------------------------------------------

def map_open():
	"""Mapa abre: pergaminho desenrolando + sino grave longe."""
	d = 1.2
	o = M.buf(d)
	r = C.rng(2400)
	for i in range(8):
		k = N(0.06)
		M.put(o, C.bp(C.noise(k, 2401 + i), 1000, 5000) * C.env_ad(k, 0.003, 0.02), 0.04 * i + r.uniform(0, 0.02), -4 - i, (i / 7 - 0.5))
	M.put(o, C.lp(C.bell(note(52), 1.0, 0.8, seed=2410, bright=0.4), 2500), 0.1, -8)
	return C.reverb(o, rt60=1.2, wet=0.25, seed=2411, lp_hz=8000)


def map_select():
	"""Nó escolhido: carimbo de cera + sino em Mi (o caminho foi decidido)."""
	d = 1.0
	o = M.buf(d)
	M.put(o, thump(220, 100, 0.12, 0.03, 2420, 0.6), 0.0, 0)
	M.put(o, C.bell(note(64), 0.9, 0.6, seed=2421, bright=0.8), 0.03, -4)
	M.put(o, M.glass(note(76), 0.5, decay=0.25, seed=2422), 0.08, -10)
	return C.reverb(o, rt60=1.2, wet=0.25, seed=2423, lp_hz=9000)


def map_locked():
	"""Nó trancado: batida surda em pedra + corrente curta."""
	d = 0.4
	o = M.buf(d)
	M.put(o, thump(140, 70, 0.2, 0.04, 2430, 0.3), 0.0, 0)
	M.put(o, links(0.2, 2431, 3, 1000, 0.08, decay=0.06), 0.02, -10)
	return o


def shop_seal():
	"""Loja: SELO aberto — cera estalando + luz que sai (vidro subindo) + coro curto."""
	d = 1.4
	o = M.buf(d + 0.3)
	M.put(o, grains(0.12, 2440, 8, 1500, 5000, 0.06), 0.0, 0)
	M.put(o, thump(260, 110, 0.1, 0.02, 2441, 0.5), 0.0, -4)
	M.put(o, glass_gliss(note(76), note(88), 0.35, 2442, count=4, tau=0.25), 0.08, -2)
	M.put(o, M.choir([note(64), note(71)], 0.9, "a", attack=0.1, release=0.6, seed=2443), 0.1, -8)
	return C.reverb(o, rt60=1.4, wet=0.25, seed=2444, lp_hz=10000)


def relic_equip():
	"""Relíquia equipada: metal antigo assentando + brilho de 2 notas."""
	d = 0.9
	o = M.buf(d)
	M.put(o, C.metal_clang(520, 0.5, seed=2450, decay=0.25), 0.0, -2)
	M.put(o, thump(180, 80, 0.12, 0.03, 2451, 0.4), 0.0, -6)
	M.put(o, M.glass(note(80), 0.5, decay=0.2, seed=2452), 0.06, -6)
	M.put(o, M.glass(note(87), 0.5, decay=0.25, seed=2453), 0.14, -8)
	return C.reverb(o, rt60=1.0, wet=0.2, seed=2454, lp_hz=10000)


def zone_objective():
	"""Objetivo da zona: trompa grave curta + sino (chama a atenção, sem alarme)."""
	d = 1.4
	o = M.buf(d + 0.3)
	n = N(0.9)
	f = note(52)
	horn = C.lp(C.saw_bl(f, n, 20) + 0.6 * C.saw_bl(f * 1.5, n, 14), 1400) * C.env_swell(n, 0.15, 0.4)
	M.put(o, horn, 0.0, -2)
	M.put(o, C.bell(note(64), 1.0, 0.8, seed=2460, bright=0.7), 0.1, -6)
	return C.reverb(o, rt60=1.6, wet=0.25, seed=2461, lp_hz=7000)


def achievement():
	"""Conquista: arpejo sacro de vidro (Mi-Sol#-Si-Mi) + sino — 'você entendeu algo'."""
	d = 1.6
	o = M.buf(d + 0.3)
	for i, m in enumerate([76, 80, 83, 88]):
		M.put(o, M.glass(note(m), 0.8, decay=0.35, seed=2470 + i), 0.09 * i, -2, (i - 1.5) * 0.3)
	M.put(o, C.bell(note(64), 1.2, 1.0, seed=2475), 0.3, -8)
	M.put(o, M.choir([note(64), note(71)], 0.9, "a", attack=0.2, release=0.6, seed=2476), 0.3, -10)
	return C.reverb(o, rt60=1.8, wet=0.3, seed=2477, lp_hz=11000)


def soter_gift():
	"""O Soter concede o pulo duplo: coro alto que se abre + anel de luz em espiral."""
	d = 2.6
	o = M.buf(d + 0.4)
	M.put(o, M.choir([note(64), note(68), note(71), note(76), note(80)], 2.4, "a", attack=0.6, release=1.0, seed=2480), 0.0, 2)
	M.put(o, glass_gliss(note(76), note(100), 1.0, 2481, count=9, tau=0.3), 0.4, -4)
	M.put(o, C.bell(note(52), 2.0, 1.4, seed=2482), 0.0, -8)
	return C.reverb(o, rt60=2.8, wet=0.35, seed=2483, lp_hz=11000)


def crack_open():
	"""Roubo — a rachadura abre: pedra/vidro rasgando devagar + luz vazando (zumbido)."""
	d = 2.4
	o = M.buf(d + 0.3)
	M.put(o, grains(2.0, 2490, 70, 300, 6000, 1.8), 0.0, 0)
	n = N(2.0)
	t = C.tvec(n)
	M.put(o, C.bp(C.noise(n, 2491), 60, 400) * C.env_swell(n, 1.5, 0.4) * 2, 0.0, -2)
	leak = sum(np.sin(C.osc_phase(note(m), n)) / (i + 1) for i, m in enumerate([76, 83, 88])) * (t / 2.0) ** 2
	M.put(o, leak * 0.3, 0.0, -8)
	M.put(o, thump(70, 30, 0.6, 0.2, 2492, 0.5), 1.8, -4)
	return C.reverb(o, rt60=2.0, wet=0.28, seed=2493, lp_hz=8000)


def king_sink():
	"""Roubo — o Rei afunda: estrondo descendo de tom + gemido de metal + coro que cai."""
	d = 3.2
	o = M.buf(d + 0.4)
	n = N(3.0)
	t = C.tvec(n)
	M.put(o, np.sin(C.osc_phase(70 * (0.45 ** (t / 3.0)), n)) * C.env_swell(n, 0.4, 1.4), 0.0, 0)
	M.put(o, rumble(3.0, 2500, 25, 200, 0.3, 1.4), 0.0, -2)
	creak = C.bp(C.saw_bl(30 * (0.6 ** (t / 3.0)), n, 40), 300, 2000) * C.env_swell(n, 1.0, 1.0)
	M.put(o, creak, 0.0, -12)
	ch = M.choir([note(50), note(57)], 2.6, "o", vowel2="u", shift=0.85, attack=0.3, release=1.2, seed=2501)
	M.put(o, ch, 0.2, -4)
	return C.reverb(o, rt60=2.6, wet=0.3, seed=2502, lp_hz=4000)


# ----------------------------------------------------------------------------
# Catálogo: nome -> (categoria do build_sfx.CAT, [variações])
# ----------------------------------------------------------------------------

def _vars(fn, k):
	return [lambda v=v: fn(v) for v in range(k)]


SOUNDS = {
	# kit dos chefes (já chamado: BossBrain.sfx)
	"chain": ("eatk_big", _vars(chain, 3)),
	"glass": ("eatk_big", _vars(glass, 3)),
	# cargas (VFX7)
	"charge_light": ("charge", [charge_light]),
	"charge_dark": ("charge", [charge_dark]),
	"charge_king": ("charge_big", [charge_king]),
	# Sophia
	"double_jump": ("sophia", _vars(double_jump, 2)),
	"star_charge": ("charge", [star_charge]),
	"star_impact": ("sophia_layer", [star_impact]),
	"riposte_ready": ("tell", [riposte_ready]),
	"riposte": ("swing_big", [riposte]),
	# inimigos (por tipo)
	"atk_swing": ("eatk", _vars(atk_swing, 3)),
	"atk_combo": ("eatk", _vars(atk_combo, 2)),
	"atk_rush": ("eatk", _vars(atk_rush, 2)),
	"atk_leap": ("eatk", _vars(atk_leap, 2)),
	"atk_slam": ("eatk_big", _vars(atk_slam, 2)),
	"atk_wave": ("eatk", _vars(atk_wave, 2)),
	"atk_shot": ("eatk", _vars(atk_shot, 3)),
	"atk_shot_air": ("eatk", _vars(atk_shot_air, 2)),
	"atk_fan": ("eatk", [atk_fan]),
	"atk_burst": ("eatk", [atk_burst]),
	"atk_homing": ("eatk", [atk_homing]),
	"atk_lob": ("eatk", [atk_lob]),
	"atk_pillar": ("eatk_big", [atk_pillar]),
	"atk_fissure": ("eatk", [atk_fissure]),
	"atk_grab": ("eatk", [atk_grab]),
	"atk_blink": ("eatk", [atk_blink]),
	"atk_summon": ("eatk_big", [atk_summon]),
	"atk_nova": ("eatk_big", [atk_nova]),
	"atk_dive": ("eatk", _vars(atk_dive, 2)),
	"atk_glide": ("eatk", [atk_glide]),
	"fly_fall": ("eatk", _vars(fly_fall, 2)),
	# Campeões
	"champion_enter": ("champion", [champion_enter]),
	"champion_fury": ("champion", [champion_fury]),
	# chefes
	"boss_phase3": ("boss", [boss_phase3]),
	"guard_break": ("elite", [guard_break]),
	"eye_hit": ("hit", _vars(eye_hit, 2)),
	"boss_death_impact": ("boss", [boss_death_impact]),
	"boss_death_stagger": ("boss_soft", [boss_death_stagger]),
	"boss_death_collapse": ("boss_mid", [boss_death_collapse]),
	"boss_death_hush": ("death_hush", [boss_death_hush]),
	"boss_death_shatter": ("boss_mid", [boss_death_shatter]),
	"bs_melee": ("bsig", _vars(bs_melee, 2)),
	"bs_cast": ("bsig_soft", _vars(bs_cast, 2)),
	"bs_leap": ("bsig", [bs_leap]),
	"bs_land": ("bsig", [bs_land]),
	"bs_yawn": ("bsig_soft", [bs_yawn]),
	"bs_lullaby": ("bsig_soft", [bs_lullaby]),
	"bs_rain": ("bsig_soft", [bs_rain]),
	"bs_suck": ("bsig", [bs_suck]),
	"bs_bite": ("bsig", [bs_bite]),
	"bs_breath": ("bsig", [bs_breath]),
	"bs_cage": ("bsig", [bs_cage]),
	"bs_scream": ("bsig", [bs_scream]),
	"bs_pages": ("bsig_soft", [bs_pages]),
	"bs_wings": ("bsig", [bs_wings]),
	"bs_split": ("bsig_soft", [bs_split]),
	"bs_swap": ("bsig_soft", [bs_swap]),
	"bs_spores": ("bsig_soft", [bs_spores]),
	"bs_cloud": ("bsig_soft", [bs_cloud]),
	"bs_burrow": ("bsig", [bs_burrow]),
	"bs_decree": ("bsig", [bs_decree]),
	"bs_coronation": ("bsig", [bs_coronation]),
	"bs_royal_cut": ("bsig", [bs_royal_cut]),
	"bs_sweep": ("bsig", [bs_sweep]),
	"bs_ray": ("bsig", [bs_ray]),
	"bs_hand": ("bsig", [bs_hand]),
	"bs_rings": ("bsig_soft", [bs_rings]),
	"bs_collapse": ("bsig", [bs_collapse]),
	# perigos
	"hz_tide_wake": ("hazard_big", [hz_tide_wake]),
	"hz_tide_tick": ("hazard_soft", [hz_tide_tick]),
	"hz_guillotine": ("hazard_big", [hz_guillotine]),
	"hz_winch": ("hazard_soft", [hz_winch]),
	"hz_maw_bite": ("hazard_big", [hz_maw_bite]),
	"hz_maw_warn": ("hazard", [hz_maw_warn]),
	"hz_beam_on": ("hazard", [hz_beam_on]),
	"hz_beam_off": ("hazard_soft", [hz_beam_off]),
	"hz_mirror_warn": ("hazard_soft", [hz_mirror_warn]),
	"hz_mirror_flip": ("hazard_soft", [hz_mirror_flip]),
	"hz_mist_breath": ("hazard_soft", [hz_mist_breath]),
	"hz_chain_swing": ("hazard", _vars(hz_chain_swing, 2)),
	"hz_bell_toll": ("hazard_big", [hz_bell_toll]),
	"hz_ether_drain": ("hazard", [hz_ether_drain]),
	"hz_silence_in": ("hazard", [hz_silence_in]),
	"hz_silence_out": ("hazard_soft", [hz_silence_out]),
	"hz_sink_start": ("hazard_soft", [hz_sink_start]),
	"hz_sink_gone": ("hazard_soft", [hz_sink_gone]),
	"hz_sink_return": ("hazard_soft", [hz_sink_return]),
	"hz_spears": ("hazard_big", _vars(hz_spears, 2)),
	"hz_shackles": ("hazard_big", [hz_shackles]),
	"hz_spore_swell": ("hazard_soft", [hz_spore_swell]),
	"hz_spore_burst": ("hazard", [hz_spore_burst]),
	"hz_spore_pop": ("hazard", [hz_spore_pop]),
	"hz_shard_warn": ("hazard_soft", [hz_shard_warn]),
	"hz_shard_fall": ("hazard_soft", [hz_shard_fall]),
	"hz_shard_impact": ("hazard", _vars(hz_shard_impact, 3)),
	"hz_totem_arm": ("hazard", [hz_totem_arm]),
	"hz_totem_summon": ("hazard", [hz_totem_summon]),
	"hz_totem_hit": ("hazard", _vars(hz_totem_hit, 2)),
	"hz_totem_break": ("hazard_big", [hz_totem_break]),
	"hz_ward_drain": ("hazard_soft", [hz_ward_drain]),
	"hz_ward_out": ("hazard", [hz_ward_out]),
	"hz_ward_saved": ("reward", [hz_ward_saved]),
	"hz_altar": ("reward", [hz_altar]),
	"hz_altar_hum": ("hazard_amb", [hz_altar_hum]),
	"hz_secret_mark": ("hazard_soft", [hz_secret_mark]),
	"hz_secret_open": ("reward", [hz_secret_open]),
	"hz_column": ("hazard_big", [hz_column]),
	"hz_saw": ("hazard", [hz_saw]),
	# UI nova
	"map_open": ("ui_big", [map_open]),
	"map_select": ("ui_big", [map_select]),
	"map_locked": ("ui", [map_locked]),
	"shop_seal": ("shop", [shop_seal]),
	"relic_equip": ("shop", [relic_equip]),
	"zone_objective": ("structure", [zone_objective]),
	"achievement": ("ui_big", [achievement]),
	"soter_gift": ("reward", [soter_gift]),
	# roubo
	"crack_open": ("story", [crack_open]),
	"king_sink": ("story", [king_sink]),
}

# Categorias novas (entram no CAT do build_sfx.py). M-max alvo (LUFS).
CATS = {
	"eatk": -19.0,        # golpe de inimigo comum: abaixo do swing da Sophia (−18) e do acerto (−12)
	"eatk_big": -16.0,    # pancada/coluna/invocação de inimigo
	"charge": -19.0,      # carga antes do tiro (cresce; o tiro é que pesa)
	"charge_big": -16.0,  # carga do Rei
	"sophia": -19.0,      # pulo duplo (perto de jump −20)
	"sophia_layer": -17.0,  # Queda Estelar: camada de estrelas POR BAIXO da nova (−12), não outro baque
	"boss_mid": -12.0,    # passos da morte que somam com boss_die
	"death_hush": -24.0,  # a pausa: quase nada
	"bsig": -13.0,        # golpe-assinatura de chefe
	"bsig_soft": -15.0,   # feitiço/efeito longo de chefe
	"hazard": -18.0,      # perigo de tela
	"hazard_big": -15.0,  # perigo que fere (guilhotina, boca, lanças, coluna)
	"hazard_soft": -22.0, # aviso/presença de perigo
	"hazard_amb": -28.0,  # presença contínua (altar), no nível da ambiência
}


if __name__ == "__main__":
	if "--list" in sys.argv:
		for k, (c, v) in SOUNDS.items():
			print("%-20s %-12s %d" % (k, c, len(v)))
