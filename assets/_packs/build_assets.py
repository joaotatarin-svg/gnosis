#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Constrói os arquivos FINAIS de áudio/VFX do GNOSIS a partir dos packs brutos
em assets/_packs/ (CC0 / CC-BY — ver assets/LICENSES.md).

  python assets/_packs/build_assets.py            # tudo
  python assets/_packs/build_assets.py sfx|music|vfx

SFX: acha o arquivo pelo nome-base dentro de _packs, mixa pra mono, corta o
silêncio inicial, limita a duração, aplica tom/reverso/camadas, normaliza o
pico em -3 dBFS e grava OGG Vorbis em assets/audio/sfx/<nome>.ogg.
Música: transcodifica o MP3 (incompetech) pra OGG estéreo em assets/audio/music/.
VFX: recorta/redimensiona os PNG do Kenney Particle Pack pra assets/vfx/.

Requer: pip install soundfile numpy pillow
"""
import sys, os, glob, math
import numpy as np
import soundfile as sf

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PACKS = os.path.join(ROOT, "assets", "_packs")
SFX_OUT = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_OUT = os.path.join(ROOT, "assets", "audio", "music")
VFX_OUT = os.path.join(ROOT, "assets", "vfx")
SR = 44100

# ----------------------------------------------------------------------------
# MAPA DOS SFX: nome do catálogo -> receita.
#   src: nome-base do arquivo no pack (ou lista de camadas [(src, offset_s, gain_db, pitch)])
#   dur: duração máxima (s)   pitch: fator de tom (1.0 = original; <1 grave/longo)
#   rev: inverte             gain: dB extra depois da normalização
#   start: pula os primeiros N segundos da fonte
# ----------------------------------------------------------------------------
SFX = {
	# --- Sophia: golpes ---
	"swing_light":   dict(src="swing.wav", dur=0.30),
	"swing_heavy":   dict(src="swish_2.wav", dur=0.50, pitch=0.82),
	"swing_air":     dict(src="swish_3.wav", dur=0.50),
	"launcher":      dict(src="swing3.wav", dur=0.40, pitch=1.12),
	"dive":          dict(src="blade_01.ogg", dur=0.45, pitch=0.9),
	"hit":           dict(src="impactPunch_medium_000.ogg", dur=0.25),
	"hit_heavy":     dict(src="HeavyHit.ogg", dur=0.45),
	# --- Sophia: defesa / movimento ---
	"parry":         dict(src="impactBell_heavy_001.ogg", dur=0.60),
	"block":         dict(src="impactSoft_heavy_000.ogg", dur=0.30),
	"dodge":         dict(src="cloth1.ogg", dur=0.35),
	"dodge_perfect": dict(src=[("bell_ding2.wav", 0.0, -2.0, 1.0, True), ("glass_002.ogg", 0.42, -4.0, 1.0, False)], dur=0.70),
	"jump":          dict(src="cloth2.ogg", dur=0.30),
	"land":          dict(src="impactSoft_medium_000.ogg", dur=0.30),
	"step":          dict(src="footstep_concrete_000.ogg", dur=0.20, gain=-4.0),
	"rooted":        dict(src="chain_01.ogg", dur=0.55),
	"player_hurt":   dict(src="gasp1.wav", dur=0.45),
	"player_die":    dict(src="qubodup-PowerDrain.ogg", dur=1.6),
	# --- magias ---
	"cast_solar":    dict(src="magical_1.ogg", dur=0.70),
	"cast_torpor":   dict(src="freeze.wav", dur=0.95, pitch=0.78),
	"cast_fome":     dict(src="eat_01.ogg", dur=0.80, pitch=0.85),
	"cast_corrente": dict(src="chain_02.ogg", dur=0.70),
	"cast_silencio": dict(src="GhostOhh.ogg", dur=0.95, rev=True),
	"cast_espelho":  dict(src="magical_6.ogg", dur=0.80, pitch=1.12),
	"cast_praga":    dict(src="creature_slime_02.ogg", dur=0.90, pitch=0.8),
	"cast_coroa":    dict(src="Healing Full.wav", dur=1.5),
	"cast_fail":     dict(src="error_006.ogg", dur=0.35),
	# --- inimigos / chefes ---
	"enemy_hurt":    dict(src="hurt_01.ogg", dur=0.35),
	"enemy_die":     dict(src="creature_die_01.ogg", dur=0.80),
	"elite_die":     dict(src="roar_02.ogg", dur=1.0, pitch=0.8),
	"champion_die":  dict(src=[("giant4.wav", 0.0, 0.0, 0.72, False), ("gong_02.ogg", 0.15, -7.0, 1.0, False)], dur=1.4),
	"boss_appear":   dict(src="Dragon_Growl_00.mp3", dur=1.8, pitch=0.85),
	"boss_phase2":   dict(src="Dragon_Growl_01.mp3", dur=1.4),
	"boss_die":      dict(src=[("BoneSplosion.ogg", 0.0, 0.0, 0.85, False), ("bfh1_rock_breaking_02.ogg", 0.1, -3.0, 0.8, False)], dur=2.0),
	"revive":        dict(src="Cure3.wav", dur=1.6),
	"form_revive":   dict(src="dm.mp3", dur=1.6, pitch=0.8),
	# --- projéteis / área / pedaços ---
	"proj_fire":     dict(src="magical_4.ogg", dur=0.35),
	"proj_hit":      dict(src="ElectricSpark.ogg", dur=0.30),
	"nova":          dict(src="lowFrequency_explosion_000.ogg", dur=0.80),
	"gib_bounce":    dict(src="plop_01.ogg", dur=0.15),
	# --- objetos da tela ---
	"chest_hit":     dict(src="impactWood_medium_000.ogg", dur=0.30),
	"chest_open":    dict(src=[("wooded_box_open.ogg", 0.0, 0.0, 1.0, False), ("item_gem_03.ogg", 0.2, -3.0, 1.0, False)], dur=1.0),
	"sleeper_wake":  dict(src="Cure1.wav", dur=1.2),
	"seal_right":    dict(src="bell_01.ogg", dur=0.6),
	"seal_wrong":    dict(src="bfh1_rock_hit_01.ogg", dur=0.5, pitch=0.8),
	"seal_solved":   dict(src="Jingle_Achievement_00.mp3", dur=1.6),
	"portal_open":   dict(src="1.mp3", dur=1.4),
	"portal_enter":  dict(src="teleport.wav", dur=1.0),
	# --- estrutura do run ---
	"zone_lock":     dict(src="slam_02.ogg", dur=0.9, pitch=0.8),
	"zone_clear":    dict(src="bell_ding2.wav", dur=1.0),
	"level_clear":   dict(src=[("bell_ding4.wav", 0.0, 0.0, 1.0, False), ("bell_ding1.wav", 0.25, -2.0, 1.0, False)], dur=1.6),
	"spark":         dict(src="item_gem_01.ogg", dur=0.2),
	"weapon_upgrade": dict(src=[("metal-ringing.wav", 0.0, 0.0, 1.0, False), ("magical_6.ogg", 0.1, -2.0, 1.0, False)], dur=1.2),
	"ring_gain":     dict(src=[("magical_6.ogg", 0.0, 0.0, 1.0, False), ("bell_ding3.wav", 0.3, -2.0, 1.0, False)], dur=1.6),
	"ring_steal":    dict(gen="ring_steal", dur=2.5),
	"shard":         dict(src="item_gem_02.ogg", dur=0.8),
	"stele_open":    dict(src=[("bookOpen.ogg", 0.0, 0.0, 1.0, False), ("stones_01.ogg", 0.0, -8.0, 0.7, False)], dur=1.0),
	"stele_unlock":  dict(src=[("bookFlip2.ogg", 0.0, 0.0, 1.0, False), ("bell_ding3.wav", 0.3, -6.0, 1.0, False)], dur=1.0),
	"subtitle_tick": dict(src="tick_004.ogg", dur=0.12, gain=-8.0),
	# --- loja / interface ---
	"shop_buy":      dict(src=[("handleCoins.ogg", 0.0, 0.0, 1.0, False), ("item_gem_04.ogg", 0.2, -3.0, 1.0, False)], dur=0.6),
	"shop_fail":     dict(src="error_005.ogg", dur=0.4),
	"ui_click":      dict(src="click_001.ogg", dur=0.15),
	"ui_move":       dict(src="rollover2.ogg", dur=0.10, gain=-6.0),
	"ui_advance":    dict(src="bookFlip1.ogg", dur=0.15),
	"ui_choice":     dict(src="gong_02.ogg", dur=0.7, gain=-3.0),
	"ui_confirm":    dict(src="confirmation_001.ogg", dur=0.4),
	"ui_back":       dict(src="back_001.ogg", dur=0.3),
}

# Músicas: nome do catálogo -> arquivo em _packs/incompetech (Kevin MacLeod, CC-BY 4.0)
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
MUSIC_MAX_S = 300.0     # faixas maiores que isto são cortadas com fade (tamanho do jogo)

# VFX: nome final -> (arquivo no Kenney Particle Pack "PNG (Transparent)", tamanho)
VFX = {
	"circle":  ("circle_05.png", 128),
	"glow":    ("light_01.png", 128),
	"halo":    ("light_02.png", 128),
	"spark":   ("spark_04.png", 128),
	"spark2":  ("spark_06.png", 128),
	"star":    ("star_07.png", 128),
	"star2":   ("star_09.png", 128),
	"smoke":   ("smoke_04.png", 128),
	"smoke2":  ("smoke_08.png", 128),
	"flame":   ("flame_04.png", 128),
	"flame2":  ("flame_06.png", 128),
	"magic":   ("magic_03.png", 128),
	"magic2":  ("magic_05.png", 128),
	"twirl":   ("twirl_02.png", 128),
	"scorch":  ("scorch_01.png", 128),
	"slash":   ("slash_03.png", 128),
	"symbol":  ("symbol_02.png", 128),
	"dirt":    ("dirt_02.png", 128),
	"trace":   ("trace_06.png", 128),
	"flare":   ("flare_01.png", 128),
	"window":  ("window_02.png", 128),
}

_index = None
def find(basename):
	"""Acha um arquivo pelo nome-base dentro de _packs (ignora __MACOSX)."""
	global _index
	if _index is None:
		_index = {}
		for p in glob.glob(os.path.join(PACKS, "**", "*"), recursive=True):
			if "__MACOSX" in p or not os.path.isfile(p):
				continue
			_index.setdefault(os.path.basename(p), p)
	if basename not in _index:
		raise FileNotFoundError(basename)
	return _index[basename]


def load_mono(path):
	data, sr = sf.read(path, dtype="float32", always_2d=True)
	mono = data.mean(axis=1)
	if sr != SR:
		mono = resample(mono, SR / sr)
	return mono


def resample(x, factor):
	"""Reamostra por interpolação linear (factor>1 = mais amostras = mais lento/grave)."""
	n = int(len(x) * factor)
	if n < 2:
		return x
	src = np.linspace(0.0, len(x) - 1, n)
	return np.interp(src, np.arange(len(x)), x).astype(np.float32)


def trim_start(x, thresh_db=-45.0):
	t = 10 ** (thresh_db / 20)
	idx = np.argmax(np.abs(x) > t)
	if idx > 0:
		idx = max(0, idx - int(0.003 * SR))   # 3 ms antes do ataque
	return x[idx:]


def cut(x, dur):
	n = int(dur * SR)
	if len(x) > n:
		x = x[:n].copy()
		f = min(int(0.08 * SR), n)          # fade de 80 ms no corte
		x[-f:] *= np.linspace(1, 0, f, dtype=np.float32)
	return x


def fade_edges(x, ms=4):
	f = min(int(ms / 1000 * SR), len(x) // 2)
	if f > 0:
		x[:f] *= np.linspace(0, 1, f, dtype=np.float32)
		x[-f:] *= np.linspace(1, 0, f, dtype=np.float32)
	return x


def normalize(x, peak_db=-3.0):
	p = float(np.max(np.abs(x))) if len(x) else 0.0
	if p > 1e-6:
		x = x * (10 ** (peak_db / 20) / p)
	return x


def layer_one(src, start=0.0, pitch=1.0, rev=False):
	x = load_mono(find(src))
	if start > 0:
		x = x[int(start * SR):]
	x = trim_start(x)
	if rev:
		x = x[::-1]
		x = trim_start(x)
	if pitch != 1.0:
		x = resample(x, 1.0 / pitch)
	return x


def gen_ring_steal(dur):
	"""Sete sinos arrancados em reverso, cada um mais grave — e silêncio."""
	bell = layer_one("bell_ding1.wav", rev=True)
	bell = cut(bell, 0.6)
	out = np.zeros(int(dur * SR), dtype=np.float32)
	for i in range(7):
		p = 1.0 - i * 0.09
		b = resample(bell, 1.0 / p) * (1.0 - i * 0.07)
		at = int(i * 0.27 * SR)
		n = min(len(b), len(out) - at)
		if n > 0:
			out[at:at + n] += b[:n]
	f = int(0.5 * SR)
	out[-f:] *= np.linspace(1, 0, f, dtype=np.float32)
	return out


def build_sfx():
	os.makedirs(SFX_OUT, exist_ok=True)
	used = {}
	for name, r in SFX.items():
		dur = r.get("dur", 1.0)
		if "gen" in r:
			x = globals()["gen_" + r["gen"]](dur)
			used[name] = ["bell_ding1.wav"]
		else:
			srcs = r["src"]
			if isinstance(srcs, str):
				x = layer_one(srcs, r.get("start", 0.0), r.get("pitch", 1.0), r.get("rev", False))
				used[name] = [srcs]
			else:
				total = int(dur * SR)
				x = np.zeros(total, dtype=np.float32)
				used[name] = []
				for (s, off, g, p, rv) in srcs:
					y = layer_one(s, 0.0, p, rv) * (10 ** (g / 20))
					at = int(off * SR)
					n = min(len(y), total - at)
					if n > 0:
						x[at:at + n] += y[:n]
					used[name].append(s)
		x = cut(x, dur)
		x = normalize(x, -3.0 + r.get("gain", 0.0))
		x = fade_edges(x)
		out = os.path.join(SFX_OUT, name + ".ogg")
		sf.write(out, x, SR, format="OGG", subtype="VORBIS")
		print("sfx  %-15s %5.2fs  <- %s" % (name, len(x) / SR, ", ".join(os.path.relpath(find(s), PACKS) for s in used[name])))
	return used


def build_music():
	os.makedirs(MUSIC_OUT, exist_ok=True)
	total = 0
	for name, title in MUSIC.items():
		src = os.path.join(PACKS, "incompetech", title + ".mp3")
		data, sr = sf.read(src, dtype="float32", always_2d=True)
		if len(data) > MUSIC_MAX_S * sr:
			data = data[: int(MUSIC_MAX_S * sr)].copy()
			f = int(3.0 * sr)
			data[-f:] *= np.linspace(1, 0, f, dtype=np.float32)[:, None]
		# tira silêncio nas pontas (o loop emenda melhor)
		env = np.abs(data).max(axis=1)
		t = 10 ** (-50 / 20)
		nz = np.nonzero(env > t)[0]
		if len(nz):
			data = data[nz[0]: nz[-1] + 1]
		out = os.path.join(MUSIC_OUT, name + ".ogg")
		# grava em blocos (libsndfile trava com buffers de minutos inteiros)
		with sf.SoundFile(out, "w", samplerate=sr, channels=data.shape[1], format="OGG", subtype="VORBIS", compression_level=0.55) as f:
			for s in range(0, len(data), 65536):
				f.write(data[s:s + 65536])
		kb = os.path.getsize(out) // 1024
		total += kb
		print("music %-13s %6.1fs %6d KB <- %s" % (name, len(data) / sr, kb, title))
	print("música total: %.1f MB" % (total / 1024))


def build_vfx():
	from PIL import Image
	os.makedirs(VFX_OUT, exist_ok=True)
	base = os.path.join(PACKS, "kenney_particle-pack", "PNG (Transparent)")
	for name, (fname, size) in VFX.items():
		img = Image.open(os.path.join(base, fname)).convert("RGBA")
		img = img.resize((size, size), Image.LANCZOS)
		img.save(os.path.join(VFX_OUT, name + ".png"), optimize=True)
		print("vfx  %-8s %dpx <- %s" % (name, size, fname))


if __name__ == "__main__":
	what = sys.argv[1] if len(sys.argv) > 1 else "all"
	if what in ("all", "sfx"):
		build_sfx()
	if what in ("all", "music"):
		build_music()
	if what in ("all", "vfx"):
		build_vfx()
