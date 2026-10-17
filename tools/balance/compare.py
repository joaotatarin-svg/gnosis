#!/usr/bin/env python3
"""GNOSIS — compara duas rodadas do bot de balance (CSV do tools/balance_bot.gd).

Uso:
  python3 tools/balance/compare.py A.csv B.csv [--telas]   (A = antes, B = depois)
  python3 tools/balance/compare.py A.csv                    (resumo de uma rodada)

Mostra: totais, curva por trecho (Limiar, 7 Éons, Centro, Mente), telas que mais
mudaram, dano por FONTE (quem bateu) e se as duas rodadas são IDÊNTICAS
(teste de determinismo: mesma semente + --fixed-fps 60 deve dar igual).
"""
import csv
import sys

EONS = ["Torpor", "Fome", "Corrente", "Silencio", "Espelho", "Praga", "Coroa"]


def trecho(s: int) -> str:
    if s <= 1:
        return "Limiar(Rei)"
    if s <= 64:
        i = (s - 2) // 9
        return "%d.%s" % (i + 1, EONS[i])
    if s <= 67:
        return "Centro"
    return "Mente"


def load(path: str) -> dict:
    rows = {}
    with open(path, newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            s = int(r["screen"])
            src = {}
            for part in (r.get("sources") or "").split(";"):
                if ":" in part:
                    k, v = part.rsplit(":", 1)
                    src[k] = src.get(k, 0) + int(v)
            rows[s] = {
                "time": float(r["time"]), "dmg": int(r["dmg"]), "deaths": int(r["deaths"]),
                "timeout": int(r["timeout"]), "hits": int(r.get("hits") or 0),
                "maxhit": int(r.get("maxhit") or 0), "boss": r.get("boss") or "", "src": src,
                "earned": int(r.get("earned") or 0), "orbs": int(r.get("orbs") or 0), "maxhp": int(r.get("maxhp") or 0),
            }
    return rows


def tot(rows: dict, keys=None) -> dict:
    ks = rows.keys() if keys is None else [k for k in keys if k in rows]
    return {
        "time": sum(rows[k]["time"] for k in ks) / 60.0,
        "dmg": sum(rows[k]["dmg"] for k in ks),
        "deaths": sum(rows[k]["deaths"] for k in ks),
        "timeout": sum(rows[k]["timeout"] for k in ks),
    }


def by_trecho(rows: dict) -> dict:
    out = {}
    for s in sorted(rows):
        out.setdefault(trecho(s), []).append(s)
    return out


def src_total(rows: dict) -> dict:
    t = {}
    for r in rows.values():
        for k, v in r["src"].items():
            t[k] = t.get(k, 0) + v
    return t


def pct(a: float, b: float) -> str:
    if a == 0:
        return "   -  "
    return "%+5.0f%%" % ((b - a) * 100.0 / a)


def resumo(a: dict) -> None:
    t = tot(a)
    print("TOTAL: %.1f min | dano %d | quase-mortes %d | timeouts %d" % (t["time"], t["dmg"], t["deaths"], t["timeout"]))
    print("\n%-14s %6s %7s %6s %4s" % ("trecho", "min", "dano", "q-mort", "TO"))
    for name, ks in by_trecho(a).items():
        x = tot(a, ks)
        print("%-14s %6.1f %7d %6d %4d" % (name, x["time"], x["dmg"], x["deaths"], x["timeout"]))
    print("\nFaíscas: ganhas no run %d · sobrando no fim %d · vida máx. na última tela %d" % (
        sum(r["earned"] for r in a.values()), a[max(a)]["orbs"], a[max(a)]["maxhp"]))
    st = src_total(a)
    print("\nDano por fonte (top 15):")
    for k, v in sorted(st.items(), key=lambda kv: -kv[1])[:15]:
        print("  %-24s %6d  (%4.1f%%)" % (k, v, v * 100.0 / max(1, t["dmg"])))


def main() -> int:
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    a = load(args[0])
    if len(args) == 1:
        resumo(a)
        return 0
    b = load(args[1])
    same = a == b
    print("A = %s\nB = %s" % (args[0], args[1]))
    print("IDÊNTICAS: %s" % ("SIM (determinístico)" if same else "NÃO"))
    if not same:
        diff = [s for s in sorted(set(a) | set(b)) if a.get(s) != b.get(s)]
        print("  1ª tela diferente: %s · telas diferentes: %d de %d" % (diff[0], len(diff), len(set(a) | set(b))))
    ta, tb = tot(a), tot(b)
    print("\n%-14s %15s %17s %13s %9s" % ("", "min (A→B)", "dano (A→B)", "q-mortes", "timeouts"))
    print("%-14s %6.1f→%-6.1f   %6d→%-6d %s %4d→%-4d %3d→%-3d" % ("TOTAL", ta["time"], tb["time"], ta["dmg"], tb["dmg"],
          pct(ta["dmg"], tb["dmg"]), ta["deaths"], tb["deaths"], ta["timeout"], tb["timeout"]))
    ga, gb = by_trecho(a), by_trecho(b)
    for name in list(dict.fromkeys(list(ga) + list(gb))):
        xa, xb = tot(a, ga.get(name, [])), tot(b, gb.get(name, []))
        print("%-14s %6.1f→%-6.1f   %6d→%-6d %s %4d→%-4d %3d→%-3d" % (name, xa["time"], xb["time"], xa["dmg"], xb["dmg"],
              pct(xa["dmg"], xb["dmg"]), xa["deaths"], xb["deaths"], xa["timeout"], xb["timeout"]))
    common = sorted(set(a) & set(b))
    if "--telas" in sys.argv:
        print("\ntela  trecho          dano A→B        tempo A→B   q-mortes  TO")
        for s in common:
            ra, rb = a[s], b[s]
            print("%4d  %-14s %5d→%-5d %s %6.1f→%-6.1f %3d→%-3d %d→%d" % (s, trecho(s), ra["dmg"], rb["dmg"], pct(ra["dmg"], rb["dmg"]),
                  ra["time"], rb["time"], ra["deaths"], rb["deaths"], ra["timeout"], rb["timeout"]))
    else:
        moved = sorted(common, key=lambda s: -abs(b[s]["dmg"] - a[s]["dmg"]))[:10]
        print("\nTelas que mais mudaram (dano):")
        for s in moved:
            print("  %3d %-14s %5d→%-5d %s  %s" % (s, trecho(s), a[s]["dmg"], b[s]["dmg"], pct(a[s]["dmg"], b[s]["dmg"]), b[s]["boss"]))
    sa, sb = src_total(a), src_total(b)
    keys = sorted(set(sa) | set(sb), key=lambda k: -max(sa.get(k, 0), sb.get(k, 0)))[:15]
    print("\nDano por fonte (A→B):")
    for k in keys:
        print("  %-24s %6d→%-6d %s" % (k, sa.get(k, 0), sb.get(k, 0), pct(sa.get(k, 0), sb.get(k, 0))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
