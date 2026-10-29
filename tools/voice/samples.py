"""AMOSTRAS DO ELENCO para o João aprovar: 1–3 falas REAIS por personagem, em
PT-BR e EN-US, com o pós-processamento de cada um.

Saída: C:\\gnosis-wt\\_caps\\dublagem\\amostras\\<personagem>_<pt|en>_<n>.ogg
       + PRANCHA_AMOSTRAS.md + _amostras.json (CER do ASR, tempo por fala).
Uso:   python tools/voice/samples.py [--lang pt|en] [--only Sophia,A Voz] [--out <pasta>]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import voicelib as V  # noqa: E402
from extract_lines import extract  # noqa: E402
from render import render  # noqa: E402

# (falante, trecho do texto PT que identifica a fala)
PICKS = [
	("Sophia", "Eu também queria deitar"),
	("Sophia", "Eu chorei por eles."),
	("Sophia", "(Uma pedra escrita, logo adiante"),
	("A Voz", "Acorda. ...Isso. Devagar."),
	("A Voz", "Não. Não, não, não. LEVANTA."),
	("A Voz", "...Sim. Comigo. Sempre."),
	("O Rei", "Faísca perdida... que bom que acordaste"),
	("O Rei", "A tua luz é maior do que eu lembrava"),
	("Yaldabaoth", "Chama-me pelo nome que nunca te disse"),
	("Yaldabaoth", "Nunca houve rio."),
	("Yaldabaoth", "Eu os forjei! Eles são MEUS!"),
	("O Cego", "...mãe? eu não queria ser cego"),
	("Athoth", "Portadora... tu também não dormes"),
	("Athoth", "Ah... então é isto, estar acordado"),
	("Harmas", "A tua casa. A janela para o rio"),
	("Harmas", "Dá-me uma! Uma lembrança"),
	("Galila", "Consta que estás fora do teu lugar"),
	("Galila", "Leve... é assim, sem elo?"),
	("Yabel", "(os pontos se rompem) Alguém respondeu"),
	("Astaphaios", "Olha: somos nós, antes das cinzas"),
	("Astaphaios", "Esse não! Esse reflexo"),
	("Belias", "Tudo apodrece, Portadora"),
	("Belias", "...Brotou? Não olhes para mim"),
	("Armupiel", "O Cego nunca olhou para mim"),
	("Armupiel", "Corte! Ao rei!"),
	("Soter", "Paz, Portadora. Baixa o cajado"),
	("Soter", "Ina. Padeira."),
	("Velkar", "Lá em cima não há tirano"),
	("Velkar", "Todo dia. Era meu pai."),
	("Narrador", "No princípio havia o Um"),
	("Narrador", "Cego para a Luz, ele se acreditou"),
	("Estela", "Antes dos mundos, antes de o tempo contar"),
	("Estela", "Quem acorda no Kenoma acorda longe dele"),
	("Uma voz nos Anéis", "...espera... eu... lembro..."),
	("Adormecida", "Dói. Por que acordar dói?"),
	("Adormecido", "Meu filho dorme duas ruas para lá"),
]


def slug(s: str) -> str:
	import unicodedata
	s = unicodedata.normalize("NFKD", s.lower())
	s = "".join(c for c in s if not unicodedata.combining(c))
	return re.sub(r"[^a-z0-9]+", "_", s).strip("_")


def pick_lines(root: Path) -> list[dict]:
	lines = extract(root)
	out, count = [], {}
	for spk, frag in PICKS:
		hit = [l for l in lines if l["speaker"] == spk and frag in l["text_pt"]]
		if not hit:
			print("!! fala não achada:", spk, frag)
			continue
		count[spk] = count.get(spk, 0) + 1
		l = dict(hit[0])
		l["n"] = count[spk]
		out.append(l)
	return out


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	V.low_priority()
	ap = argparse.ArgumentParser()
	ap.add_argument("--lang", default="pt,en")
	ap.add_argument("--only", default="")
	ap.add_argument("--out", default=r"C:\gnosis-wt\_caps\dublagem\amostras")
	ap.add_argument("--refs", default=str(HERE / "out" / "refs"))
	ap.add_argument("--device", default="cpu")
	ap.add_argument("--force", action="store_true", help="refaz mesmo as que já existem")
	a = ap.parse_args()
	out, refs = Path(a.out), Path(a.refs)
	out.mkdir(parents=True, exist_ok=True)
	root = HERE.parents[1]
	picks = pick_lines(root)
	if a.only:
		keep = set(a.only.split(","))
		picks = [p for p in picks if p["speaker"] in keep]
	log_path = out / "_amostras.json"
	results = json.loads(log_path.read_text(encoding="utf-8")) if log_path.exists() else {}
	for lang in a.lang.split(","):
		t0 = time.time()
		cb = V.Chatterbox(lang, a.device)
		print("Chatterbox %s carregado em %.0fs" % (lang, time.time() - t0), flush=True)
		for l in picks:
			said = l["said_" + lang]
			if not said:
				print("!! sem texto %s: %s" % (lang, l["text_pt"]))
				continue
			f = out / ("%s_%s_%d.ogg" % (slug(l["speaker"]), lang, l["n"]))
			if f.exists() and f.name in results and not a.force:
				continue
			info = render(cb, l["speaker"], l["mood"], l["mode"], l["text_pt"], said, lang, refs, f)
			info["id"] = l["id"]
			info["text"] = l["text_" + lang]
			results[f.name] = info
			log_path.write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding="utf-8")
		cb.close()
		del cb
	return 0


if __name__ == "__main__":
	sys.exit(main())
