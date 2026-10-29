# -*- coding: utf-8 -*-
"""
Onda 7 — amostras para o João OUVIR depois (nada toca no PC agora: só grava).

  python tools/audio/onda7_demos.py [pasta]     (padrão: C:/gnosis-wt/_caps/audio7/amostras)

Monta 10 arquivos, cada um com os sons no tempo em que o jogo os toca, e um
mosaico de espectrogramas (amostras.png) para conferir sem ouvir.
"""
import os, sys
import numpy as np
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "audio_synth"))
import common as C

SFX = os.path.join(ROOT, "assets", "audio", "sfx")
SR = 44100
SFX_VOL_DB = 20 * np.log10(0.9) + 20 * np.log10(0.7)   # slider padrão SFX 0,9 × Master 0,7


def load(name):
	x, sr = sf.read(os.path.join(SFX, name + ".ogg"), dtype="float64", always_2d=True)
	if sr != SR:
		x = signal.resample_poly(x, SR, sr, axis=0)
	return x if x.shape[1] == 2 else np.repeat(x, 2, axis=1)


def seq(events, tail=1.5):
	"""events = [(t_s, nome, dB)] → estéreo no nível do jogo (sliders padrão)."""
	end = max(t + len(load(n)) / SR for t, n, _ in events) + tail
	out = np.zeros((int(end * SR), 2))
	for t, n, g in events:
		C.place(out, load(n), t, g + SFX_VOL_DB)
	return C.limit(out, -1.0)


DEMOS = {
	"01_cargas_luz_trevas_rei": [(0.0, "charge_light", 0), (1.6, "charge_dark", 0), (3.2, "charge_king", 0)],
	"02_morte_do_chefe_5_passos": [(0.0, "boss_death_impact", 0), (0.35, "boss_death_stagger", 0),
		(0.9, "boss_death_collapse", 0), (1.85, "boss_death_hush", 0), (2.45, "boss_death_shatter", 0), (2.45, "boss_die", 0)],
	"03_fase3_rugido": [(0.0, "boss_phase3", 0)],
	"04_arcontes_assinaturas": [(0.0, "bs_yawn", 0), (3.0, "bs_lullaby", 0), (6.5, "bs_suck", 0), (7.6, "bs_bite", 0),
		(9.0, "chain", 0), (10.3, "bs_cage", 0), (12.5, "bs_scream", 0), (14.5, "bs_split", 0), (16.8, "glass", 0),
		(18.3, "bs_spores", 0), (19.9, "bs_cloud", 0), (21.8, "bs_decree", 0), (24.0, "bs_coronation", 0)],
	"05_rei_luz_roubada": [(0.0, "charge_king", 0), (0.9, "bs_ray", 0), (2.6, "bs_hand", 0), (4.2, "bs_rings", 0),
		(6.4, "eye_hit", 0), (7.2, "eye_hit_2", 0)],
	"06_inimigos_repertorio": [(0.0, "atk_swing", 0), (0.5, "atk_combo", 0), (1.2, "atk_rush", 0), (2.0, "atk_leap", 0),
		(2.7, "atk_slam", 0), (3.5, "atk_wave", 0), (4.5, "atk_shot", 0), (5.0, "atk_fan", 0), (5.7, "atk_burst", 0),
		(6.6, "atk_homing", 0), (7.8, "atk_lob", 0), (8.6, "atk_pillar", 0), (10.0, "atk_fissure", 0),
		(11.0, "atk_grab", 0), (11.8, "atk_blink", 0), (12.8, "atk_summon", 0)],
	"07_voadores_e_campeao": [(0.0, "atk_dive", 0), (1.0, "atk_glide", 0), (2.0, "atk_shot_air", 0), (2.8, "fly_fall", 0),
		(4.5, "champion_enter", 0), (8.0, "champion_fury", 0), (10.0, "guard_break", 0)],
	"08_perigos_tour": [(0.0, "hz_mist_breath", 0), (2.8, "hz_sink_start", 0), (4.0, "hz_maw_warn", 0), (4.8, "hz_maw_bite", 0),
		(6.2, "hz_chain_swing", 0), (7.2, "hz_bell_toll", 0), (7.7, "hz_ether_drain", 0), (9.6, "hz_silence_in", 0),
		(11.2, "hz_beam_on", 0), (12.8, "hz_spore_swell", 0), (13.5, "hz_spore_burst", 0), (14.8, "hz_guillotine", 0),
		(15.9, "hz_spears", 0), (16.6, "hz_shackles", 0), (17.8, "hz_shard_warn", 0), (18.6, "hz_shard_fall", 0),
		(18.8, "hz_shard_impact", 0), (20.0, "hz_tide_wake", 0), (23.5, "hz_totem_summon", 0), (25.2, "hz_totem_break", 0)],
	"09_luz_sophia_e_recompensas": [(0.0, "double_jump", 0), (0.9, "star_charge", 0), (1.4, "nova", 0), (1.4, "star_impact", 0),
		(3.0, "parry", 0), (3.0, "riposte_ready", 0), (3.5, "riposte", 0), (4.6, "hz_altar", 0), (8.0, "soter_gift", 0),
		(12.4, "achievement", 0), (15.0, "shop_seal", 0), (17.0, "relic_equip", 0), (18.4, "map_open", 0),
		(20.0, "map_select", 0), (21.5, "zone_objective", 0)],
	"10_roubo_rei_afunda": [(0.0, "king_sink", 0), (0.5, "crack_open", -2)],
}


def main():
	out_dir = sys.argv[1] if len(sys.argv) > 1 else "C:/gnosis-wt/_caps/audio7/amostras"
	os.makedirs(out_dir, exist_ok=True)
	paths = []
	for name, ev in DEMOS.items():
		x = seq(ev)
		p = os.path.join(out_dir, name + ".ogg")
		C.write_ogg(p, x.astype(np.float32), quality=6)
		paths.append(p)
		print("%-34s %5.1fs  M-max %6.1f  TP %5.1f" % (name, len(x) / SR, C.max_momentary(x), C.true_peak_db(x)))
	import subprocess
	subprocess.run([sys.executable, os.path.join(ROOT, "tools", "audio_synth", "spectro.py"),
		os.path.join(out_dir, "amostras.png")] + paths + ["--cols", "2"], check=False)


if __name__ == "__main__":
	main()
