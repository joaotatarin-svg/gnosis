#!/usr/bin/env python3
"""Resumo em Markdown das medições de tools/perf/run.sh (perfil, engasgos, alocação).

Uso: python3 tools/perf/resumo.py <pasta_de_saida>
Regra de ruído: a máquina da nuvem é compartilhada; para tempos usa-se o MÍNIMO
entre as repetições (ruído só soma tempo). Contagens (shaders compilados,
texturas novas, draw calls) não têm ruído.
"""
import glob
import json
import os
import re
import sys


def load(p):
    try:
        return json.load(open(p))
    except Exception:
        return None


def papel(t):
    if t == 1:
        return "Rei"
    if t >= 68:
        return "final (dupla)"
    if 65 <= t <= 67:
        return "Centro"
    off = (t - 2) % 9
    return {0: "chegada", 4: "desafio", 7: "antessala", 8: "Arconte"}.get(off, "travessia") + (" + roubo" if t == 64 else "")


def perfil(out):
    rows = {}
    for p in glob.glob(os.path.join(out, "perfil_t*_*.json")):
        m = re.search(r"perfil_t(\d+)_n(\d+)_(cpu|gl)\.json", p)
        if not m:
            continue
        d = load(p)
        if d:
            rows.setdefault(int(m.group(1)), {})[(int(m.group(2)), m.group(3))] = d
    if not rows:
        return
    print("## Perfil por tela\n")
    print("CPU = headless (sem render; tempo de CPU do jogo nesta máquina compartilhada). "
          "GL = janela 320×180 no llvmpipe: só as CONTAGENS valem (draw calls/objetos/nós).\n")
    print("| Tela | Papel | CPU n=0 ms mediana / p99 / máx | CPU n=extra ms mediana / p99 / máx | vivos | process ms | física ms | GL draw calls | GL objetos | nós |")
    print("|---:|---|---|---|---:|---:|---:|---:|---:|---:|")
    for t in sorted(rows):
        r = rows[t]
        c0 = next((v for (n, k), v in r.items() if k == "cpu" and n == 0), None)
        cn = next((v for (n, k), v in r.items() if k == "cpu" and n > 0), None)
        g = next((v for (n, k), v in r.items() if k == "gl"), None)
        f = lambda d: "%.2f / %.2f / %.1f" % (d["ms_mediana"], d["ms_p99"], d["ms_max"]) if d else "-"
        print("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            t, papel(t), f(c0), f(cn),
            cn["inimigos_vivos_medio"] if cn else "-",
            cn.get("process_ms_medio", "-") if cn else "-",
            cn.get("fisica_ms_medio", "-") if cn else "-",
            g["draw_calls_medio"] if g else "-", g["objetos_medio"] if g else "-",
            (g or cn or {}).get("nos", "-")))
    print()


def engasgos(out):
    runs = {}
    for p in glob.glob(os.path.join(out, "hitch_*_pw*_r*.json")):
        m = re.search(r"hitch_(cpu|gl)_pw(\d)_r(\d+)\.json", p)
        d = load(p)
        if m and d:
            runs.setdefault((m.group(1), int(m.group(2))), []).append(d)
    if not runs:
        return
    events = []
    for lst in runs.values():
        for row in lst[0]["resumo"]:
            if row["evento"] not in events:
                events.append(row["evento"])

    def agg(kind, pw, ev, key):
        vals = [r[key] for d in runs.get((kind, pw), []) for r in d["resumo"] if r["evento"] == ev]
        return min(vals) if vals else None

    def excess(kind, pw, ev):
        a, b = agg(kind, pw, ev, "pico1_ms"), agg(kind, pw, ev, "pico2_ms")
        if a is None or b is None:
            return None
        return max(0.0, a - b)

    def shaders(pw, ev):
        vals = [r["shaders1"] for d in runs.get(("gl", pw), []) for r in d["resumo"] if r["evento"] == ev]
        return max(vals) if vals else None

    def lista(pw, ev):
        s = set()
        for d in runs.get(("gl", pw), []):
            for r in d["resumo"]:
                if r["evento"] == ev:
                    s.update(r.get("shaders1_lista", []))
        return ", ".join(sorted(s))

    def tex(pw, ev):
        vals = [r.get("textura_mb1", 0) for d in runs.get(("gl", pw), []) for r in d["resumo"] if r["evento"] == ev]
        return max(vals) if vals else None

    n = {k: len(v) for k, v in runs.items()}
    print("## Engasgos de primeira vez (tela %s)\n" % (runs[next(iter(runs))][0]["tela"]))
    print("Repetições: %s. Excesso = pico da 1ª vez − pico da 2ª vez (mínimo entre repetições, ms). "
          "Shaders = variantes compiladas no evento (arquivos novos/crescidos em user://shader_cache, cache frio). "
          "Tex = MB de textura enviados à GPU no evento.\n" % ", ".join("%s/prewarm=%d: %d" % (k[0], k[1], v) for k, v in sorted(n.items())))
    print("| Evento | CPU excesso sem → com prewarm | GL excesso sem → com | shaders sem → com | tex MB sem → com | shaders (sem prewarm) |")
    print("|---|---|---|---|---|---|")
    fmt = lambda v: "-" if v is None else ("%.0f" % v if isinstance(v, float) else str(v))
    fmt1 = lambda v: "-" if v is None else "%.1f" % v
    for ev in events:
        print("| %s | %s → %s | %s → %s | %s → %s | %s → %s | %s |" % (
            ev, fmt(excess("cpu", 0, ev)), fmt(excess("cpu", 1, ev)),
            fmt(excess("gl", 0, ev)), fmt(excess("gl", 1, ev)),
            fmt(shaders(0, ev)), fmt(shaders(1, ev)), fmt1(tex(0, ev)), fmt1(tex(1, ev)), lista(0, ev)))
    pw = [d.get("prewarm_ms", -1) for k, lst in runs.items() if k[1] == 1 for d in lst]
    pwc = [d.get("prewarm_ms", -1) for d in runs.get(("cpu", 1), [])]
    pwg = [d.get("prewarm_ms", -1) for d in runs.get(("gl", 1), [])]
    print()
    if pwc:
        print("- Custo do prewarm no load (chamada, CPU headless, mínimo): %.0f ms" % min(pwc))
    if pwg:
        print("- Custo do prewarm no load (chamada, janela llvmpipe, mínimo): %.0f ms" % min(pwg))
    for kind in ("gl",):
        for p in (0, 1):
            tot = [sum(r["shaders1"] for r in d["resumo"]) for d in runs.get((kind, p), [])]
            ab = [d.get("shaders_no_cache_ao_abrir") for d in runs.get((kind, p), [])]
            if tot:
                print("- prewarm=%d: variantes compiladas DURANTE a luta (soma dos eventos): %s; no cache ao abrir a fase: %s" % (p, tot, ab))
    q = load(os.path.join(out, "hitch_gl_quente.json"))
    if q:
        tot = sum(r["shaders1"] for r in q["resumo"])
        print("- Cache QUENTE (2ª sessão, sem prewarm): variantes compiladas durante a luta = %d" % tot)
    print()


def alloc(out):
    d = load(os.path.join(out, "alloc.json"))
    if not d:
        return
    print("## Alocação por quadro no desenho das ilustrações (REVISAO #16)\n")
    print("µs por chamada (melhor de 5, n=%d). Hoje cada criatura paga a chave formatada + grid_mesh a cada quadro.\n" % d.get("n", 0))
    print("| Medida | µs/chamada |\n|---|---:|")
    for k, v in d.items():
        if k != "n":
            print("| %s | %.3f |" % (k, v))
    print()


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    print("# Desempenho — resumo (%s)\n" % out)
    perfil(out)
    engasgos(out)
    alloc(out)
    if os.path.exists(os.path.join(out, "pck.md")):
        print("## Peso do .pck\n")
        print(open(os.path.join(out, "pck.md")).read())


if __name__ == "__main__":
    main()
