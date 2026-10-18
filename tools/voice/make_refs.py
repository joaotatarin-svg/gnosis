"""Gera as referências de timbre de todo o elenco (Kokoro + tom) e, com --fx,
uma prévia de cada cadeia de pós-processamento aplicada à própria referência.

Uso: python tools/voice/make_refs.py [--fx <pasta_previa>] [--force]
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import soundfile as sf  # noqa: E402
import voicelib as V  # noqa: E402


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	refs = HERE / "out" / "refs"
	prev = Path(sys.argv[sys.argv.index("--fx") + 1]) if "--fx" in sys.argv else None
	if "--force" in sys.argv and refs.exists():
		for f in refs.glob("*.wav"):
			f.unlink()
	for char, c in V.CAST["characters"].items():
		for lang in ("pt", "en"):
			t0 = time.time()
			p = V.make_ref(char, lang, refs)
			x, _ = sf.read(p, dtype="float32")
			msg = "%-20s %s %.1fs (%.1fs)" % (char, lang, len(x) / V.SR, time.time() - t0)
			if prev:
				y = V.finalize(V.apply_fx(x, c["fx"]))
				V.write_ogg(y, prev / ("%s_%s.ogg" % (V.ref_path(char, lang, refs).stem, "fx")))
			print(msg, flush=True)
	return 0


if __name__ == "__main__":
	sys.exit(main())
