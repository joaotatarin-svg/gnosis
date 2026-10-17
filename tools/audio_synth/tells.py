# -*- coding: utf-8 -*-
"""
Sons de AVISO do combate (NEURO R5 / pedido do Combate, Onda 2b) e o pulso de
vida baixa (R22). 100 % síntese, determinístico.

  tell_parry    brilho AMARELO (golpe aparável): "tim" redondo e agudo, curto
                (~0,15 s). Parciais de barra pequena (1 : 2,76) em Lá6/Lá7 com
                subida mínima de tom no ataque (o "brilho" da lâmina). Toca
                quando a janela de parry ABRE: o pico vem no 1º milissegundo.
  tell_unblock  losango VERMELHO (imparável): "vuum" ÁSPERO e GRAVE que cresce
                até o golpe (~0,32 s): dente-de-serra 75→140 Hz + outra um trítono
                acima, saturadas, com rugosidade (AM 33 Hz) e chiado 350–1500 Hz;
                o corpo fica em 200–2000 Hz para não sumir em caixinha de notebook
                e NÃO parecer o passo do chefe (que é grave limpo).

Os dois são o OPOSTO um do outro em tudo o que dá para medir (centro espectral,
envelope, duração, aspereza) — ninguém precisa da cor para separar.
Medição de leitura sob música: tools/audio/tell_check.py.
"""
import os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C
from common import SR
import magic as M


def tell_parry():
	d = 0.16
	o = M.buf(d)
	n = M.n_(d)
	t = C.tvec(n)
	# ataque: o tom sobe 2 % em 25 ms e assenta — o "tim" acende
	glide = 1.0 + 0.02 * np.clip(t / 0.025, 0, 1)
	def part(f, tau, amp):
		return np.sin(C.osc_phase(f * glide, n)) * C.env_ad(n, 0.0015, tau) * amp
	core = part(1760.0, 0.045, 1.0)               # Lá6: o corpo "redondo"
	core += part(1760.0 * 2.76, 0.022, 0.42)      # parcial de barra: o brilho
	core += part(3520.0, 0.030, 0.30)             # Lá7: oitava, puro
	core += part(1760.0 * 5.40, 0.010, 0.10)      # faísca de cima, some logo
	# transiente de 3 ms (4–9 kHz): dá a "borda" que corta a música
	m = M.n_(0.004)
	click = C.bp(C.noise(m, 700), 4000, 9000) * C.env_ad(m, 0.0003, 0.0012)
	# "xing" de lâmina: sopro 3→7 kHz de 60 ms por baixo — separa o aviso do
	# tilintar de vidro da faísca (que é tom puro)
	k = M.n_(0.06)
	shing = M.sweep_bp(C.noise(k, 702), 3000, 7000, 3.0) * C.env_swell(k, 0.012, 0.018)
	M.put(o, core, 0.0, 0.0, 0.0)
	M.put(o, click, 0.0, -14.0, 0.0)
	M.put(o, shing, 0.0, -15.0, 0.0)
	# cauda brilhante curtíssima (a sala não pode borrar o ritmo)
	return C.reverb(C.hp(o, 900), rt60=0.35, wet=0.12, seed=701, lp_hz=11000, tail=True)


def tell_unblock():
	d = 0.34
	n = M.n_(d)
	t = C.tvec(n)
	peak = 0.20                                    # cresce até ~o golpe (glint = golpe − 0,18 s)
	e = C.env_swell(n, peak, 0.06)
	f = 75.0 * (140.0 / 75.0) ** np.clip(t / peak, 0, 1)
	# serra + serra um TRÍTONO acima: zumbido áspero, de ameaça (nada de grave
	# limpo — grave limpo é o passo do chefe, e o aviso não pode parecer passo)
	saw = C.saw_bl(f, n, nh=30, tilt=0.9) + 0.55 * C.saw_bl(f * 1.414, n, nh=20, tilt=0.9)
	rough = 1.0 - 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 33.0 * t))   # aspereza (AM 33 Hz)
	growl = M.sat(C.bp(saw, 180, 2200) * 2.2, 2.6) * rough
	sub = np.sin(C.osc_phase(f, n)) * 0.25
	rasp = M.sweep_bp(C.noise(n, 710), 350, 1500, 2.2) * 0.7 * rough
	x = (growl + sub + rasp) * e
	o = np.stack([x, x], axis=1)
	return C.reverb(C.lp(o, 3200), rt60=0.4, wet=0.10, seed=711, lp_hz=2600, tail=False)


SOUNDS = {
	"tell_parry": ("tell", [tell_parry]),
	"tell_unblock": ("tell_low", [tell_unblock]),
}
