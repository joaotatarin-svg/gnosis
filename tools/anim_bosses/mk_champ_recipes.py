"""Receitas dos 7 CAMPEÕES de Éon (champ_<id>.json) a partir das folhas do GPT.

O campeão ocupa o lugar do bot da família (o jogo já o aumenta 1,35×): herda do
bot correspondente old_body/old_flip/kind/flex/hem_wave/fit_override; o
`size_fix` é medido à parte (prancha comparada com a do bot).
Folha 1536x1024, grade 4x2 (idle, walk_0..2, windup, strike, hurt, death),
olhando para a DIREITA. Andar = 3 quadros + meios do RIFE (6 quadros).

Uso: python tools/anim_bosses/mk_champ_recipes.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
REC = os.path.join(HERE, "recipes")
sys.path.insert(0, os.path.join(HERE, "..", "anim"))
from clean_sheets import key_array  # noqa: E402

TILE = 3


def haze_rects(sheet: str, wipe: list, keep: list, thin: list) -> list:
	"""Névoa pintada (nuvem de esporos) → retângulos `erase` em ladrilhos de 4 px.
	`wipe`: zonas [x0,y0,x1,y1] apagadas inteiras, menos os polígonos `keep`
	(arma/corpo que atravessam a nuvem). `thin`: zonas onde só some o que é
	que é fumaça (translúcido ou rosado), o resto (cogumelos, corpo) fica; dentro
	dos `keep` vale a mesma regra.
	Ladrilhos vizinhos na mesma linha viram um retângulo só."""
	c = np.asarray(Image.open(sheet).convert("RGB")).astype(np.float32)
	_, a, _ = key_array(c)
	H, W = a.shape
	km = Image.new("L", (W, H), 0)
	d = ImageDraw.Draw(km)
	for poly in keep:
		d.polygon([tuple(p) for p in poly], fill=255)
	km = np.asarray(km) > 0
	F, _, _ = key_array(c)

	def hazy(sl) -> bool:
		# fumaça: translúcida (alfa < 0,95) ou rosada (verde pintado sobre o
		# magenta: R bem acima do G e B perto do G; corpo/cogumelo têm B baixo)
		t = a[sl]
		if t.max() < 0.95:
			return True
		f = F[sl][t > 0.3]
		r, g, b = f[:, 0].mean(), f[:, 1].mean(), f[:, 2].mean()
		return (r - g) > 35.0 and b > 0.78 * g and f.min(1).min() > 60.0
	kill = np.zeros((H // TILE + 1, W // TILE + 1), bool)
	for (x0, y0, x1, y1) in wipe:
		for ty in range(y0 // TILE, (y1 + TILE - 1) // TILE):
			for tx in range(x0 // TILE, (x1 + TILE - 1) // TILE):
				sl = (slice(ty * TILE, ty * TILE + TILE), slice(tx * TILE, tx * TILE + TILE))
				if a[sl].max() > 0.0 and (not km[sl].any() or hazy(sl)):
					kill[ty, tx] = True
	for (x0, y0, x1, y1) in thin:
		for ty in range(y0 // TILE, (y1 + TILE - 1) // TILE):
			for tx in range(x0 // TILE, (x1 + TILE - 1) // TILE):
				sl = (slice(ty * TILE, ty * TILE + TILE), slice(tx * TILE, tx * TILE + TILE))
				if a[sl].max() > 0.0 and hazy(sl):
					kill[ty, tx] = True
	out = []
	for ty in range(kill.shape[0]):
		tx = 0
		while tx < kill.shape[1]:
			if kill[ty, tx]:
				t0 = tx
				while tx < kill.shape[1] and kill[ty, tx]:
					tx += 1
				out.append([t0 * TILE, ty * TILE, tx * TILE, ty * TILE + TILE])
			else:
				tx += 1
	return out

# id → nº da folha
CHAMPS = {"sonambulo": 1, "glutao": 2, "carcereiro": 3, "mudo": 4, "reflexo": 5, "esporos": 6, "pretoriano": 7}
# do bot da família: o campeão fica no mesmo lugar/tamanho-base
INHERIT = ["old_body", "old_flip", "kind", "flex", "hem_wave", "fit_override"]
# ajustes por campeão (medidos nas pranchas)
TUNE = {
	"sonambulo": {"size_fix": 1.12},     # halo largo conta na altura: capuz ficava ~12% menor que o bot
	"glutao": {"size_fix": 0.8, "grid_only": True,
		"erase": [[772, 798, 815, 832]]},           # respingos do cutelo que caíam no quadro hurt
	"carcereiro": {"size_fix": 1.0},
	"mudo": {"size_fix": 1.0,
		# anel de choque do strike (cruza a grade e grudava no hurt) → FX; poupa a pena
		"erase": [[765, 585, 822, 688], [765, 724, 822, 835]]},
	"reflexo": {"size_fix": 1.0},
	"esporos": {"size_fix": 1.35},

	"pretoriano": {"size_fix": 1.1, "grid_only": True,   # alabarda erguida conta na altura
		"erase": [[857, 706, 864, 720]]},          # ponta da alabarda do strike encostava no ombro do hurt
}
# nuvem de esporos do champ_6 (vira FX por código): ligava o strike ao hurt e
# ficava um borrão rosado (verde translúcido sobre o magenta)
HAZE = {
	"esporos": {
		"wipe": [[655, 600, 898, 860]],
		"keep": [
			# leque (chapéu de cogumelo) + haste do cajado do strike
			[[740, 676], [758, 663], [778, 666], [792, 678], [803, 692], [809, 708], [805, 728], [797, 743], [787, 753], [783, 763],
				[773, 763], [769, 752], [752, 750], [746, 742], [700, 740], [664, 764], [618, 766], [618, 688], [700, 676]],
			# cajado do hurt (do chapéu até a mão)
			[[782, 560], [866, 560], [870, 600], [910, 700], [908, 730], [878, 730], [828, 640], [782, 612]],
		],
		"thin": [[898, 540, 1016, 612], [30, 532, 232, 604], [232, 736, 294, 812]],
	},
}
WALK = ["walk_0", "walk_1", "walk_2"]   # só desenhados: a PuppetQA proíbe meio do RIFE no andar (lê como fantasma)

done = []
for cid, n in CHAMPS.items():
	name = "champ_%d_%s_a" % (n, cid)
	if not os.path.exists(os.path.join(ROOT, "artes", "gpt", name + ".png")):
		continue
	bot = json.load(open(os.path.join(REC, "bot_%s.json" % cid), encoding="utf-8-sig"))
	kind = bot.get("kind", "biped")
	R = {
		"_doc": "Campeão de Éon %s — arte própria (folha %s, 2x4: idle_0, walk_0, walk_1, walk_2, windup, strike, hurt, death). Ocupa o lugar do bot_%s (mesma camada antiga do boneco; o jogo aumenta 1,35×). Gerada por mk_champ_recipes.py." % (cid, name, cid),
		"group": "creatures",
		"sheet": "artes/gpt/%s.png" % name,
		"grid": [4, 2],
		"cells": ["idle_0", "walk_0", "walk_1", "walk_2", "windup", "strike", "hurt", "death"],
		"body_px": 220,
		"anchors": {"death": "lying"},
		"anchor_fix": {},
		"inbetween": {},
		"states": {
			"idle": {"frames": ["idle_0"]},
			"walk": ({"frames": WALK, "loop": True, "fps": 7.0} if kind == "spirit" else {"frames": WALK, "cycle_bodies": 0.9}),
			"windup": {"frames": ["windup"]},
			"attack": {"frames": ["strike"]},
			"recover": {"frames": ["strike", "idle_0"], "at": [0.0, 0.4]},
			"hurt": {"frames": ["hurt"]},
			"dead": {"frames": ["hurt", "death"], "dur": [0.12]},
		},
	}
	for k in INHERIT:
		if k in bot:
			R[k] = bot[k]
	R.update(TUNE.get(cid, {}))
	if cid in ("carcereiro", "esporos"):
		R["despill_full"] = True     # franja rosada nos panos finos (sem violeta legítimo nessas folhas)
	if cid in HAZE:
		hz = HAZE[cid]
		R["erase"] = R.get("erase", []) + haze_rects(os.path.join(ROOT, R["sheet"]), hz["wipe"], hz["keep"], hz["thin"])
	json.dump(R, open(os.path.join(REC, "champ_%s.json" % cid), "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
	done.append("champ_" + cid)
print(" ".join(done))
