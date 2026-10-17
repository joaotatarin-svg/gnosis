"""Recorta as 18 ilustrações das Estelas (folhas 3x2 do GPT em artes/gpt/stelae/)
em um PNG por Estela, na ordem de Gnosis.STELAS. Pipeline versionado da UI.
Uso (na raiz do projeto):  python -I assets/stelae/build_stelae.py
Saída: assets/stelae/<id>.png (lado maior 320 px, RGB; a moldura de pedra fica
na imagem — o jogo só põe um filete dourado por fora).

Como acha os painéis: as margens entre eles são quase pretas; as colunas/linhas
com luminância média baixa separam as 6 células, e dentro de cada célula o
recorte é a caixa dos pixels claros (a pedra da moldura)."""
import os
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "artes", "gpt", "stelae")
OUT = os.path.join(ROOT, "assets", "stelae")
MAX_SIDE = 320

# folha -> ids na ordem das células (linha a linha, 3 colunas x 2 linhas)
SHEETS = {
    "stelae_1_a.png": ["monada", "pleroma", "sophia", "cego", "kenoma", "arcontes"],
    "stelae_2_a.png": ["heimarmene", "barro", "gnose", "nag_hammadi", "apocrifo", "pistis"],
    "stelae_3_a.png": ["mestres", "tome", "perola", "chamado", "docetismo", "retorno"],
}


def _splits(profile: np.ndarray, parts: int) -> list:
    """Divide o eixo em `parts` faixas pelas corridas escuras internas."""
    dark = profile < 25.0
    n = len(profile)
    runs = []
    s = None
    for i, d in enumerate(dark):
        if d and s is None:
            s = i
        if not d and s is not None:
            runs.append((s, i - 1))
            s = None
    if s is not None:
        runs.append((s, n - 1))
    # só as corridas internas (não as bordas) e as maiores
    inner = [r for r in runs if r[0] > 20 and r[1] < n - 20]
    inner.sort(key=lambda r: r[1] - r[0], reverse=True)
    cuts = sorted([(r[0] + r[1]) // 2 for r in inner[: parts - 1]])
    if len(cuts) != parts - 1:
        cuts = [n * k // parts for k in range(1, parts)]
    return [0] + cuts + [n]


def build_sheet(name: str, ids: list) -> None:
    im = Image.open(os.path.join(SRC, name)).convert("RGB")
    lum = np.asarray(im.convert("L")).astype(np.float32)
    xs = _splits(lum.mean(0), 3)
    ys = _splits(lum.mean(1), 2)
    k = 0
    for r in range(2):
        for c in range(3):
            x0, x1, y0, y1 = xs[c], xs[c + 1], ys[r], ys[r + 1]
            cell = lum[y0:y1, x0:x1]
            # caixa dos pixels da pedra: colunas/linhas com bastante pixel claro
            colf = (cell > 40).mean(0)
            rowf = (cell > 40).mean(1)
            cx = np.where(colf > 0.25)[0]
            cy = np.where(rowf > 0.25)[0]
            bx0, bx1 = x0 + int(cx[0]), x0 + int(cx[-1]) + 1
            by0, by1 = y0 + int(cy[0]), y0 + int(cy[-1]) + 1
            crop = im.crop((bx0, by0, bx1, by1))
            w, h = crop.size
            s = MAX_SIDE / float(max(w, h))
            crop = crop.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
            crop.save(os.path.join(OUT, ids[k] + ".png"), optimize=True)
            print("estela:", ids[k], (bx0, by0, bx1, by1), crop.size)
            k += 1


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, ids in SHEETS.items():
        build_sheet(name, ids)


if __name__ == "__main__":
    main()
