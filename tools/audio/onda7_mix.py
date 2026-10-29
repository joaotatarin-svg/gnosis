# -*- coding: utf-8 -*-
"""
R13 OFFLINE (Onda 7): renderiza a MIXAGEM de uma sessão jogada pelo bot, sem
tocar nada no PC, e mede loudness e fadiga.

  1) jogar com log:  GNOSIS_AUDIO_LOG=C:/.../mix.json  godot --headless --audio-driver Dummy
                     --fixed-fps 60 --path . res://tools/BalanceBot.tscn -- 23 28 1
     (vel 1: o anti-spam do Áudio é em ms REAIS; com vel > 1 sairiam menos sons)
  2) medir:          python tools/audio/onda7_mix.py C:/.../mix.events.json [saida_base]

O log (`audio_manager.gd`, GNOSIS_AUDIO_LOG) tem cada SFX tocado (tempo de jogo,
arquivo, dB do player, tom, bus) e, a cada 0,1 s, a música/ambiência (arquivo,
posição, dB) e o volume dos buses (sliders, ducking, R9). Aqui tudo é somado
como o AudioServer somaria: SFX → bus (pan fixo) → SFX → Master; música e
ambiência → seus buses → Master; o limitador do Master (−1 dB) no fim.
Não reproduz o passa-baixas do slow-mo (fica um pouco mais brilhante que o real).

Saída: <base>.ogg (os 10 min, para ouvir depois), <base>.json (números):
  · LUFS integrado, LRA, true peak, M-max (R13: −20 a −23 LUFS, TP ≤ −1)
  · música sozinha × SFX sozinhos (quanto o combate passa por cima da música)
  · fadiga: sons por minuto, o MESMO arquivo repetido em 10 s (pior caso),
    tempo com 2–5 kHz dominando (R12), e os 15 sons mais tocados.
"""
import os, sys, json
import numpy as np
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "audio_synth"))
import common as C

SR = 44100
PAN = {"SFX_L2": -0.25, "SFX_L1": -0.125, "SFX_R1": 0.125, "SFX_R2": 0.25,
	"Tell_L2": -0.25, "Tell_L1": -0.125, "Tell_R1": 0.125, "Tell_R2": 0.25}
# cadeia de buses → quem soma (o volume de cada um vem do log)
CHAIN = {"SFX": ["SFX"], "UI": ["UI", "SFX"], "Voice": ["Voice", "SFX"], "Tell": ["Tell"]}
_cache = {}


def res_to_path(r):
	return os.path.join(ROOT, r.replace("res://", "").replace("/", os.sep))


def load(r):
	if r not in _cache:
		x, sr = sf.read(res_to_path(r), dtype="float64", always_2d=True)
		if sr != SR:
			x = signal.resample_poly(x, SR, sr, axis=0)
		if x.shape[1] == 1:
			x = np.repeat(x, 2, axis=1)
		_cache[r] = x
	return _cache[r]


def bus_db_at(beds_t, beds_b, t, chain):
	i = max(0, np.searchsorted(beds_t, t) - 1)
	b = beds_b[i]
	return sum(float(b.get(k, 0.0)) for k in chain) + float(b.get("Master", 0.0))


def main():
	src = sys.argv[1]
	base = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(src)[0].replace(".events", "") + "_mix"
	d = json.load(open(src, encoding="utf-8"))
	sfx, beds = d["sfx"], d["beds"]
	beds_t = np.array([b[0] for b in beds])
	beds_b = [b[3] for b in beds]
	t0 = min(beds_t[0] if len(beds_t) else 0.0, sfx[0][0] if sfx else 0.0)
	T = max(beds_t[-1] if len(beds_t) else 0.0, sfx[-1][0] if sfx else 0.0) - t0 + 3.0
	n = int(T * SR)
	fx = np.zeros((n, 2))
	bed = np.zeros((n, 2))
	# vfx7 (a63c40b, integrado depois): o disparo HOSTIL é mudo — o som do tiro é o
	# atk_* do observador. Este worktree ainda toca proj_fire em todo tiro; para
	# medir a mixagem integrada, tira o proj_fire que sai junto (≤ 80 ms) de um
	# golpe de tiro inimigo.
	shot_t = np.array(sorted(t for (t, r, *_x) in sfx if any(k in r for k in
		("atk_shot", "atk_fan", "atk_burst", "atk_homing", "atk_lob", "atk_fissure"))))
	def hostile(t):
		if len(shot_t) == 0:
			return False
		i = np.searchsorted(shot_t, t + 1e-6)
		return i > 0 and t - shot_t[i - 1] <= 0.08
	n_before = len(sfx)
	sfx = [e for e in sfx if not ("/proj_fire" in e[1] and hostile(e[0]))]
	removed_pf = n_before - len(sfx)
	# --- SFX
	names = {}
	for (t, r, vdb, pitch, bus) in sfx:
		x = load(r)
		if abs(pitch - 1.0) > 0.002:
			x = np.stack([C.resample_pitch(x[:, 0], pitch), C.resample_pitch(x[:, 1], pitch)], axis=1)
		root = bus.split("_")[0] if bus.startswith(("SFX_", "Tell_")) else bus
		g = vdb + bus_db_at(beds_t, beds_b, t, CHAIN.get(root, ["SFX"]))
		if bus in PAN:
			a = (PAN[bus] + 1) * np.pi / 4
			x = x * np.array([np.cos(a), np.sin(a)]) * np.sqrt(2)
		C.place(fx, x, t - t0, g)
		nm = os.path.basename(r).rsplit(".", 1)[0]
		names.setdefault(nm, []).append(t - t0)
	# --- música e ambiência: segmentos de 0,1 s na posição registrada
	for k, busname in ((1, "Music"), (2, "Ambience")):
		for i in range(len(beds) - 1):
			e = beds[i][k]
			if not e:
				continue
			r, pos, vdb, pitch = e
			x = load(r)
			ta, tb = beds[i][0] - t0, beds[i + 1][0] - t0
			m = int((tb - ta) * SR)
			if m <= 0 or m > SR:
				continue
			p0 = int(pos * SR)
			seg = np.take(x, np.arange(p0, p0 + m) % len(x), axis=0)
			g0 = vdb + bus_db_at(beds_t, beds_b, beds[i][0], [busname])
			e1 = beds[i + 1][k]
			g1 = (e1[2] if e1 and e1[0] == r else vdb) + bus_db_at(beds_t, beds_b, beds[i + 1][0], [busname])
			gl = 10 ** (np.linspace(g0, g1, m) / 20)
			C.place(bed, seg * gl[:, None], ta)
	trim = float(os.environ.get("SFX_TRIM_DB", "0"))   # simulação: trim extra no bus SFX (dB)
	if trim:
		fx *= 10 ** (trim / 20)
	mix = C.limit(fx + bed, -1.0)
	C.write_ogg(base + ".ogg", mix.astype(np.float32), quality=4)
	# --- medidas
	dur_min = T / 60.0
	per_min = len(sfx) / dur_min
	worst = {}
	for nm, ts in names.items():
		ts = np.array(ts)
		c = max(int(((ts >= t) & (ts < t + 10.0)).sum()) for t in ts)
		worst[nm] = c
	top = sorted(((len(v), k) for k, v in names.items()), reverse=True)[:15]
	b, a = signal.butter(4, [2000, 5000], "band", fs=SR)
	mm = mix.mean(axis=1)
	pres = signal.lfilter(b, a, mm)
	hop = int(0.4 * SR)
	dom = 0
	loud = 0
	for i in range(len(mm) // hop):
		et = (mm[i * hop:(i + 1) * hop] ** 2).mean() + 1e-20
		if 10 * np.log10(et) < -50:
			continue
		loud += 1
		ep = (pres[i * hop:(i + 1) * hop] ** 2).mean() + 1e-20
		if 10 * np.log10(ep / et) > -6:
			dom += 1
	out = {
		"duracao_min": round(dur_min, 2), "sfx_tocados": len(sfx), "sfx_por_minuto": round(per_min, 1),
		"proj_fire_hostil_removido": removed_pf,
		"mix": {"LUFS_I": round(float(C.integrated_lufs(mix)), 1), "LRA": round(float(C.lra(mix)), 1),
			"TP": round(float(C.true_peak_db(mix)), 1), "M_max": round(float(C.max_momentary(mix)), 1)},
		"so_musica_amb": {"LUFS_I": round(float(C.integrated_lufs(bed)), 1)},
		"so_sfx": {"LUFS_I": round(float(C.integrated_lufs(fx)), 1)},
		"fadiga": {
			"pct_tempo_2_5k_dominando": round(100.0 * dom / max(loud, 1), 1),
			"pior_repeticao_em_10s": sorted(worst.items(), key=lambda kv: -kv[1])[:10],
			"mais_tocados": [[k, c] for c, k in top],
		},
	}
	json.dump(out, open(base + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
	print(json.dumps(out, ensure_ascii=False, indent=1))


if __name__ == "__main__":
	main()
