"""jitter_csv.py — QA-VISUAL: lê o CSV da JitterProbe e acha SALTOS de câmera e de Sophia na tela.
Salto = |velocidade do quadro| > 3× a mediana da fase "anda" (px/ms, espaço 640×360).
Uso: python tools/qa_visual/jitter_csv.py <arquivo.csv>"""
import csv, sys, statistics as st
rows = list(csv.DictReader(open(sys.argv[1]), delimiter=';'))
for fase in ('anda', 'parada'):
    rs = [r for r in rows if r['fase'] == fase]
    if len(rs) < 5: continue
    def vel(key):
        out = []
        for i in range(1, len(rs)):
            dt = max(0.001, float(rs[i]['dt_ms']))
            out.append(((float(rs[i][key]) - float(rs[i-1][key])) / dt, float(rs[i]['t_ms']), float(rs[i][key]) - float(rs[i-1][key]), dt))
        return out
    for key, nome in (('cam_x', 'camera'), ('tela_x', 'sophia_na_tela')):
        v = vel(key)
        med = st.median([abs(a[0]) for a in v]) or 1e-6
        saltos = [a for a in v if abs(a[0]) > 3 * med and abs(a[2]) > 0.5]
        dts = [float(r['dt_ms']) for r in rs]
        print('%s %-15s quadros=%d dt_med=%.2fms dt_max=%.1fms vel_med=%.4f saltos(>3x e >0,5px)=%d  piores=%s' % (
            fase, nome, len(v), st.median(dts), max(dts), med, len(saltos),
            [(round(a[1]), round(a[2], 2), round(a[3], 2)) for a in sorted(saltos, key=lambda a: -abs(a[2]))[:4]]))
