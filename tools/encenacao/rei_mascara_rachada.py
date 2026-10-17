"""ENCENAÇÃO 5 (pipeline, não roda no jogo): recorta o ROSTO do retrato
`assets/ui/portraits/rei_revelado.png` (máscara rachada + olho cego aceso) num
oval com borda suave, para o Rei-figurante da cena B (tela 64) usar DEPOIS de
"a máscara cai" — no lugar do disco preto provisório. Quando a arte entregar o
Rei sem máscara (estado `revealed` no atlas), este recorte deixa de ser usado.
Uso: python -I tools/encenacao/rei_mascara_rachada.py  (na raiz do projeto)
Saída: assets/cinematic/rei_mascara_rachada.png"""
import sys
from PIL import Image, ImageDraw, ImageFilter

SRC = "assets/ui/portraits/rei_revelado.png"
OUT = "assets/cinematic/rei_mascara_rachada.png"
# Caixa do rosto no retrato de 128 px (máscara + a borda do capuz em volta).
BOX = (26, 8, 82, 96)
UP = 3            # amplia (o recorte é pequeno; o filtro linear do Godot agradece)
FEATHER = 5       # px (já ampliado) de borda suave

def main() -> int:
    im = Image.open(SRC).convert("RGBA").crop(BOX)
    w, h = im.size
    im = im.resize((w * UP, h * UP), Image.LANCZOS)
    W, H = im.size
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    pad = FEATHER * 2
    d.ellipse((pad, pad, W - pad, H - pad), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(FEATHER))
    a = im.getchannel("A")
    from PIL import ImageChops
    im.putalpha(ImageChops.multiply(a, m))
    im.save(OUT)
    print(OUT, im.size)
    return 0

if __name__ == "__main__":
    sys.exit(main())
