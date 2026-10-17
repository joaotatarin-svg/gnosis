#!/usr/bin/env python3
"""GNOSIS — agrega VÁRIAS rodadas do bot (ruido=N) e compara dois grupos.

Uso:
  python tools/balance/agrega.py A1.csv A2.csv ... [-- B1.csv B2.csv ...] [--telas 20,55,68]
Mostra, por trecho (Limiar, 7 Éons, Centro, Mente) e para as telas pedidas:
média ± desvio do dano (e quase-mortes) em cada grupo e a diferença B−A em
unidades do erro padrão (|z| < 2 = dentro do ruído). Com --pares, as rodadas de
A e B na mesma ordem são pareadas (mesmo ruido=N) e conta quantos pares caíram.
"""
import statistics as st
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare import load, trecho, by_trecho  # noqa: E402


def agg(runs, keys_of):
    vals = []
    for r in runs:
        vals.append(sum(r[s]["dmg"] for s in keys_of(r) if s in r))
    return vals


def ms(v):
    if not v:
        return 0.0, 0.0
    return st.mean(v), (st.stdev(v) if len(v) > 1 else 0.0)


def line(name, va, vb, pares):
    ma, sa = ms(va)
    out = "%-14s %7.0f ±%4.0f" % (name, ma, sa)
    if vb:
        mb, sb = ms(vb)
        se = ((sa * sa / max(1, len(va))) + (sb * sb / max(1, len(vb)))) ** 0.5
        z = (mb - ma) / se if se > 0 else 0.0
        d = (mb - ma) * 100.0 / ma if ma else 0.0
        out += "   %7.0f ±%4.0f   %+5.0f%%  z=%+5.1f" % (mb, sb, d, z)
        if pares and len(va) == len(vb):
            down = sum(1 for a, b in zip(va, vb) if b < a)
            out += "  pares↓ %d/%d" % (down, len(va))
    print(out)


def main():
    argv = sys.argv[1:]
    pares = "--pares" in argv
    telas = []
    if "--telas" in argv:
        telas = [int(x) for x in argv[argv.index("--telas") + 1].split(",")]
    files = [a for a in argv if a.endswith(".csv")]
    if "--" in argv:
        i = argv.index("--")
        fa = [a for a in argv[:i] if a.endswith(".csv")]
        fb = [a for a in argv[i + 1:] if a.endswith(".csv")]
    else:
        fa, fb = files, []
    A = [load(f) for f in fa]
    B = [load(f) for f in fb]
    print("A: %d rodadas%s" % (len(A), ("   B: %d rodadas" % len(B)) if B else ""))
    print("%-14s %13s   %13s   %6s" % ("trecho", "A dano", "B dano" if B else "", "B−A" if B else ""))
    line("TOTAL", agg(A, lambda r: r.keys()), agg(B, lambda r: r.keys()), pares)
    names = list(by_trecho(A[0]).keys())
    for n in names:
        f = (lambda name: (lambda r: [s for s in r if trecho(s) == name]))(n)
        line(n, agg(A, f), agg(B, f), pares)
    if telas:
        print("-- telas")
    for t in telas:
        line("tela %d" % t, agg(A, lambda r, t=t: [t]), agg(B, lambda r, t=t: [t]), pares)
    qa = [sum(r[s]["deaths"] for s in r) for r in A]
    qb = [sum(r[s]["deaths"] for s in r) for r in B]
    print("quase-mortes   A %.1f ±%.1f%s" % (ms(qa) + (("   B %.1f ±%.1f" % ms(qb)) if B else "",)))


if __name__ == "__main__":
    main()
