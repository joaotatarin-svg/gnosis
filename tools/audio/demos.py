# -*- coding: utf-8 -*-
"""
Amostras para o João OUVIR (a IA não ouve): monta, offline, o que o jogo faria
com os volumes padrão (Master 0,7 · Música 0,6 · SFX 0,9; Éon −3 dB; ambiência
do Arconte −5 dB; ducking de card −9 dB). Nada aqui vai para o jogo.

  python3 tools/audio/demos.py [saida_dir]     (padrão /home/user/caps/audio2/opcoes)

  avisos_sob_musica.ogg   música de chefe + 3 avisos amarelos (tell_parry → parry
                          0,18 s depois) e 3 vermelhos (tell_unblock → dodge)
  vida_baixa.ogg          música de chefe + 8 s de batida (low_health_pulse, 0,9 Hz,
                          batida −3 dB e a música abrindo −3 dB em cada uma)
  intro_coracao.ogg       o cue `heartbeat` da intro: 2 batidas no escuro
  silencio_pre_chefe.ogg  R9: Éon → some em 0,6 s → só ambiência → stinger →
                          chefe entra 0,3 s depois (abaixado pelo card 1,8 s)
  morte_do_chefe.ogg      R9: música de chefe → boss_die → música some 150 ms e volta
  boss_comparar.ogg       o MESMO trecho de 10 s: original e as 7 variações, em fila
"""
import os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "audio_synth"))
import common as C
from common import SR, db

OUT = sys.argv[1] if len(sys.argv) > 1 else "/home/user/caps/audio2/opcoes"
MASTER = 20 * np.log10(0.7)
MUSIC = 20 * np.log10(0.6)
SFX = 20 * np.log10(0.9)


def st(x):
	return np.stack([x, x], axis=1) if x.ndim == 1 else x


def mus(name):
	return st(C.load(os.path.join(C.MUSIC_DIR, name + ".ogg"), mono=False))


def sfx(name):
	return st(C.load(os.path.join(C.SFX_DIR, name + ".ogg"), mono=False))


def amb(name):
	return st(C.load(os.path.join(C.AMB_DIR, name + ".ogg"), mono=False))


def env_db(n, points):
	"""Curva de ganho (dB) por pontos (s, dB), linear entre eles."""
	t = C.tvec(n)
	xs = [p[0] for p in points]
	ys = [p[1] for p in points]
	return db(np.interp(t, xs, ys))[:, None]


def save(name, x):
	x = x * db(MASTER)
	x = C.limit(x, -1.0)
	C.write_ogg(os.path.join(OUT, name), x.astype(np.float32), 4)
	print("amostra:", os.path.join(OUT, name), "%.1f s" % (len(x) / SR))


def main():
	os.makedirs(OUT, exist_ok=True)
	# 1) avisos sob a música de chefe
	d = 16.0
	n = int(d * SR)
	o = mus("boss")[int(20 * SR):int(20 * SR) + n] * db(MUSIC)
	for k, at in enumerate([2.0, 4.5, 7.0]):
		C.place(o, sfx("tell_parry"), at, SFX)
		C.place(o, sfx("parry"), at + 0.18, SFX)
	for k, at in enumerate([9.5, 12.0, 14.0]):
		C.place(o, sfx("tell_unblock"), at, SFX)
		C.place(o, sfx("dodge"), at + 0.18, SFX)
	save("avisos_sob_musica.ogg", o)
	# 2) vida baixa: 8 s de batida a 0,9 Hz, −6 dB
	d = 12.0
	n = int(d * SR)
	o = mus("boss")[int(30 * SR):int(30 * SR) + n] * db(MUSIC)
	pts = [(0, 0)]
	t = 1.1
	beats_at = []
	while t < 9.1:
		beats_at.append(t)
		pts += [(t, 0), (t + 0.06, -3), (t + 0.36, -3), (t + 0.66, 0)]
		t += 1.0 / 0.9
	o *= env_db(n, pts + [(d, 0)])
	C.place(o, sfx("hit_heavy"), 1.0, SFX)
	C.place(o, sfx("player_hurt"), 1.0, SFX)
	for t in beats_at:
		C.place(o, sfx("heartbeat"), t, SFX - 3.0)
	save("vida_baixa.ogg", o)
	# 3) intro: 2 batidas no escuro (sem música)
	o = np.zeros((int(3.0 * SR), 2))
	C.place(o, sfx("heartbeat"), 0.2, SFX)
	C.place(o, sfx("heartbeat"), 1.3, SFX - 2.0)
	save("intro_coracao.ogg", o)
	# 4) silêncio antes do chefe
	d = 14.0
	n = int(d * SR)
	eon = mus("eon_torpor")[int(40 * SR):int(40 * SR) + n] * db(MUSIC - 3.0)
	eon *= env_db(n, [(0, 0), (3.0, 0), (3.6, -60), (d, -60)])
	ambx = amb("amb_torpor")
	ambx = np.tile(ambx, (int(np.ceil(n / len(ambx))) + 1, 1))[:n] * db(MUSIC - 5.0)
	stinger_at = 5.5
	card = [(0, 0), (stinger_at, 0), (stinger_at + 0.25, -9.0), (stinger_at + 1.8, -9.0), (stinger_at + 2.6, 0), (d, 0)]
	ambx *= env_db(n, [(0, 0), (stinger_at, 0), (stinger_at + 0.25, -5.0), (stinger_at + 1.8, -5.0), (stinger_at + 2.6, 0), (d, 0)])
	boss = mus("boss")
	start = stinger_at + 0.3
	bo = np.zeros((n, 2))
	C.place(bo, boss[: n - int(start * SR)], start)
	bo *= env_db(n, [(0, -60), (start, -60), (start + 0.25, 0), (d, 0)]) * env_db(n, card)
	o = eon + ambx + bo * db(MUSIC)
	C.place(o, sfx("boss_appear"), stinger_at, SFX)
	save("silencio_pre_chefe.ogg", o)
	# 5) morte do chefe
	d = 9.0
	n = int(d * SR)
	o = mus("boss")[int(50 * SR):int(50 * SR) + n] * db(MUSIC)
	kill = 3.0
	o *= env_db(n, [(0, 0), (kill, 0), (kill + 0.15, -30), (kill + 1.75, -30), (kill + 2.75, 0), (d, 0)])
	C.place(o, sfx("hit_heavy"), kill - 0.02, SFX)
	C.place(o, sfx("boss_die"), kill, SFX)
	save("morte_do_chefe.ogg", o)
	# 6) comparação das variações de chefe: mesmo trecho (24–34 s do original;
	#    na fita ±1 semitom o trecho equivalente é escalado)
	parts = []
	gap = np.zeros((int(0.6 * SR), 2))
	for name, rate in [("boss", 1.0), ("boss_torpor", 2 ** (-1 / 12)), ("boss_fome", 1.0), ("boss_corrente", 1.0),
			("boss_silencio", 1.0), ("boss_espelho", 1.0), ("boss_praga", 1.0), ("boss_coroa", 2 ** (1 / 12))]:
		path = os.path.join(C.MUSIC_DIR if name == "boss" else OUT, name + ".ogg")
		if not os.path.exists(path):
			continue
		x = st(C.load(path, mono=False))
		a = int(24.0 / rate * SR)
		seg = x[a:a + int(10.0 / rate * SR)].copy()
		seg = C.fade(seg, 0.05, 0.4) * db(MUSIC)
		parts += [seg, gap]
	save("boss_comparar.ogg", np.concatenate(parts))


if __name__ == "__main__":
	main()
