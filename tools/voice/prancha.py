"""Escreve PRANCHA_AMOSTRAS.md (lista das amostras para o João ouvir) a partir
de _amostras.json (samples.py).

Uso: python tools/voice/prancha.py [<pasta_amostras>]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import voicelib as V  # noqa: E402


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"C:\gnosis-wt\_caps\dublagem\amostras")
	res = json.loads((d / "_amostras.json").read_text(encoding="utf-8"))
	order = list(V.CAST["characters"].keys())
	by: dict = {}
	for f, r in res.items():
		by.setdefault(r["char"], []).append(r)
	L = ["# PRANCHA DAS AMOSTRAS — elenco de vozes de GNOSIS", "",
		"Pasta: `%s` — abra os `.ogg` no player de sua preferência (VLC, navegador)." % d, "",
		"Cada personagem: voz-base sintética (Kokoro, Apache-2.0) + atuação (Chatterbox, MIT) + pós-processamento.",
		"Tudo gerado LOCALMENTE, sem custo, com licença comercial. Nenhuma voz é de pessoa real.",
		"`ASR` = o que o reconhecimento de fala (Whisper) entendeu — confere a dicção; CER = erro por caractere (0 = perfeito).", ""]
	tot_gen = tot_dur = 0.0
	for ch in order:
		rs = by.get(ch)
		if not rs:
			continue
		c = V.CAST["characters"][ch]
		L.append("## %s" % ch)
		L.append("*%s*" % c["desc"])
		L.append("")
		L.append("| arquivo | fala | dur | CER | ASR ouviu |")
		L.append("|---|---|---|---|---|")
		for r in sorted(rs, key=lambda r: r["file"]):
			L.append("| `%s` | %s | %.1f s | %.2f | %s |" % (r["file"], r.get("text", r["said"]).replace("|", "/").replace("\n", " "), r["dur"], r["cer"], r["asr"].replace("|", "/")))
			tot_gen += r["gen_s"]
			tot_dur += r["dur"]
		L.append("")
	n = len(res)
	L.append("---")
	L.append("%d amostras · %.0f s de áudio · %.0f min de geração na CPU (≈ %.0f s por fala; %.1f× o tempo real, com QA)." % (
		n, tot_dur, tot_gen / 60, tot_gen / max(1, n), tot_gen / max(1, tot_dur)))
	ruins = [r["file"] for r in res.values() if r["cer"] > 0.2]
	if ruins:
		L.append("")
		L.append("**Atenção (CER > 0,2 — ouvir com cuidado):** " + ", ".join(ruins))
	(d / "PRANCHA_AMOSTRAS.md").write_text("\n".join(L) + "\n", encoding="utf-8")
	print("ok:", d / "PRANCHA_AMOSTRAS.md", n, "amostras")
	return 0


if __name__ == "__main__":
	sys.exit(main())
