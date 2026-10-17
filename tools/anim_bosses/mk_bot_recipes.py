import json, os, shutil, glob
ROOT = r"C:\gnosis-wt\arte-gpt"
OUT = r"C:\gnosis-wt\_gpt\out"
# id do bot → (nº da folha, Arconte da família = camada antiga do boneco, tipo)
bots = {
	"sonambulo": (1, "athoth", "spirit"),
	"glutao": (2, "harmas", "biped"),
	"carcereiro": (3, "galila", "biped"),
	"mudo": (4, "yabel", "spirit"),
	"reflexo": (5, "astaphaios", "biped"),
	"esporos": (6, "belias", "beast"),
	"pretoriano": (7, "armupiel", "biped"),
}
VARIANT = {"glutao": "b"}     # folha aprovada quando há mais de uma (MANIFESTO do produtor)
KEEP = ["size_fix", "fit_override", "kind", "states", "anchors", "anchor_fix", "flex", "hem_wave", "recolor"]
done = []
for bid, (n, archon, kind) in bots.items():
	cands = sorted(glob.glob(os.path.join(OUT, "bot_%d_%s_*.png" % (n, bid))))
	if not cands:
		continue
	src = cands[0]
	want = os.path.join(OUT, "bot_%d_%s_%s.png" % (n, bid, VARIANT.get(bid, "a")))
	if os.path.exists(want):
		src = want
	name = os.path.basename(src)[:-4]
	shutil.copy(src, os.path.join(ROOT, "artes", "gpt", name + ".png"))
	p = os.path.join(ROOT, "tools", "anim_bosses", "recipes", "bot_" + bid + ".json")
	walk = ["walk_0", "walk_0-walk_1_50", "walk_1", "walk_1-walk_2_50", "walk_2", "walk_2-walk_0_50"]
	R = {
		"_doc": "Bot de Éon %s (servo de %s) — arte própria, substitui a miniatura do Arconte. Folha %s (2x4: idle_0, walk_0, walk_1, walk_2, windup, strike, hurt, death). Tamanho em tela = o da família antiga (camada do boneco do Arconte)." % (bid, archon, name),
		"group": "creatures",
		"sheet": "artes/gpt/%s.png" % name,
		"grid": [4, 2],
		"cells": ["idle_0", "walk_0", "walk_1", "walk_2", "windup", "strike", "hurt", "death"],
		"old_body": "assets/painted/derived/puppets/%s_body.png" % archon,
		"old_flip": True,
		"kind": kind,
		"body_px": 220,
		"anchors": {"death": "lying"},
		"anchor_fix": {},
		"inbetween": {"w1": ["walk_0", "walk_1", 1], "w2": ["walk_1", "walk_2", 1], "w3": ["walk_2", "walk_0", 1]},
		"flex": {"cloth_top": 0.5, "cloth_amp": 1.5} if kind == "spirit" else {},
		"hem_wave": 1.0 if kind == "spirit" else 0.0,
		"states": {
			"idle": {"frames": ["idle_0"]},
			"walk": ({"frames": walk, "loop": True, "fps": 7.0} if kind == "spirit" else {"frames": walk, "cycle_bodies": 0.9}),
			"windup": {"frames": ["windup"]},
			"attack": {"frames": ["strike"]},
			"recover": {"frames": ["strike", "idle_0"], "at": [0.0, 0.4]},
			"hurt": {"frames": ["hurt"]},
			"dead": {"frames": ["hurt", "death"], "dur": [0.12]},
		},
	}
	if os.path.exists(p):
		# receita já ajustada à mão: mantém os ajustes, troca só a folha
		old = json.load(open(p, encoding="utf-8"))
		for k in KEEP:
			if k in old:
				R[k] = old[k]
	if bid == "glutao" and "size_fix" not in R:
		R["size_fix"] = 0.8      # folha _b: criatura-saco de quatro, mais baixa que o Harmas
	json.dump(R, open(p, "w", encoding="utf-8", newline="\n"), indent=1, ensure_ascii=False)
	done.append("bot_" + bid)
print(" ".join(done))
