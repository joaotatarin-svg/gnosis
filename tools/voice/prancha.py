"""Escreve PRANCHA_AMOSTRAS.md (lista das amostras para o João ouvir) a partir
de _amostras.json (samples.py) e, se existir, _asr.json (asr_check.py rodado
nos .ogg FINAIS = inteligibilidade depois dos efeitos).

Uso: python tools/voice/prancha.py [<pasta_amostras>]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import voicelib as V  # noqa: E402

# As 6 para ouvir primeiro (cada uma mostra uma decisão de elenco).
OUCA_PRIMEIRO = [
	("a_voz_pt_1.ogg", "A Voz — a primeira fala do jogo: calorosa, dobrada, \"dentro da cabeça\"."),
	("yaldabaoth_pt_2.ogg", "Yaldabaoth — a MESMA voz da Voz, sem o veludo (oitava abaixo, catedral). Ouça logo depois da anterior."),
	("sophia_pt_2.ogg", "Sophia — \"Eu chorei por eles.\" (a fala mais curta e pesada do roubo)."),
	("astaphaios_pt_1.ogg", "Astaphaios — o Espelho fala com a voz DELA, dobrada e com pré-eco."),
	("athoth_pt_1.ogg", "Athoth — o Torpor: sussurro sonolento, quase canção de ninar."),
	("narrador_pt_1.ogg", "Narrador — o prólogo (\"No princípio havia o Um\")."),
]


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"C:\gnosis-wt\_caps\dublagem\amostras")
	res = json.loads((d / "_amostras.json").read_text(encoding="utf-8"))
	pos = {}
	if (d / "_asr.json").exists():
		pos = {r["file"]: r for r in json.loads((d / "_asr.json").read_text(encoding="utf-8"))}
	for f, r in res.items():
		if "cer_pos" not in r and f in pos:
			r["cer_pos"], r["asr_pos"] = pos[f]["cer"], pos[f]["asr"]
	order = list(V.CAST["characters"].keys())
	by: dict = {}
	for f, r in res.items():
		by.setdefault(r["char"], []).append(r)
	L = ["# PRANCHA DAS AMOSTRAS — elenco de vozes de GNOSIS", "",
		"Pasta: `%s` — abra os `.ogg` no player de sua preferência (VLC, navegador)." % d,
		"Nome: `<personagem>_<pt|en>_<n>.ogg` — o mesmo número em `pt` e `en` é a mesma fala.", "",
		"Cada personagem: voz-base sintética (Kokoro, Apache-2.0) + atuação (Chatterbox, MIT) + pós-processamento.",
		"Tudo gerado LOCALMENTE, sem custo, com licença comercial. Nenhuma voz é de pessoa real.", "",
		"## Ouça primeiro (6)", ""]
	for f, why in OUCA_PRIMEIRO:
		L.append("1. `%s` — %s (versão em inglês: `%s`)" % (f, why, f.replace("_pt_", "_en_")))
	L += ["", "**O que dizer ao aprovar:** para cada papel, \"aprovado\" ou \"trocar\" (mais grave/agudo, "
		"mais/menos efeito, outra voz-base). Trocar um papel regera só as falas dele.", "",
		"Colunas: **CER** = erro por caractere do reconhecimento de fala (Whisper) na voz crua · "
		"**após efeitos** = o mesmo medido no arquivo final (efeito que embola a fala aparece aqui) · "
		"0 = perfeito; > 0,25 = conferir. A IA não ouve áudio: estes números são o \"ouvido\" dela.", ""]
	tot_gen = tot_dur = 0.0
	for ch in order:
		rs = by.get(ch)
		if not rs:
			continue
		c = V.CAST["characters"][ch]
		L.append("## %s" % ch)
		L.append("*%s*" % c["desc"])
		L.append("")
		L.append("| arquivo | fala | dur | CER | após efeitos | ASR ouviu (final) |")
		L.append("|---|---|---|---|---|---|")
		for r in sorted(rs, key=lambda r: r["file"]):
			cp = r.get("cer_pos")
			L.append("| `%s` | %s | %.1f s | %.2f | %s | %s |" % (
				r["file"], r.get("text", r["said"]).replace("|", "/").replace("\n", " "), r["dur"], r["cer"],
				"—" if cp is None else "%.2f" % cp, str(r.get("asr_pos", r["asr"])).replace("|", "/")))
			tot_gen += r["gen_s"]
			tot_dur += r["dur"]
		L.append("")
	n = len(res)
	L.append("---")
	L.append("%d amostras · %.0f s de áudio · %.0f min de geração (CPU e, nas refeitas, GPU; ≈ %.0f s por fala com QA)." % (
		n, tot_dur, tot_gen / 60, tot_gen / max(1, n)))
	L.append("Loudness −18 LUFS por fala; true peak ≤ −1 dBTP medido no .ogg (limitador; `tools/voice/tp_fix.py`).")
	ruins = [r["file"] for r in res.values() if r["cer"] > 0.2 or (r.get("cer_pos") or 0) > 0.25]
	L.append("")
	L.append("**Conferir com atenção:** " + (", ".join(sorted(ruins)) if ruins else "nenhuma acima do limite."))
	(d / "PRANCHA_AMOSTRAS.md").write_text("\n".join(L) + "\n", encoding="utf-8")
	print("ok:", d / "PRANCHA_AMOSTRAS.md", n, "amostras; conferir:", ruins)
	return 0


if __name__ == "__main__":
	sys.exit(main())
