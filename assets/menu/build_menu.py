"""Fundo do menu principal a partir de artes/gpt/menu/menu_bg_a.png (GPT, 1536x1024).
Pipeline versionado da UI. Uso (na raiz):  python -I assets/menu/build_menu.py
Saída: assets/menu/menu_bg.jpg (1536x1024, JPEG q92 — a pintura não precisa de alfa
e o JPEG pesa ~1/6 do PNG no .pck). A metade esquerda (escura, calma) recebe os botões;
o jogo escurece mais um pouco por código (sombra em degradê)."""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "artes", "gpt", "menu", "menu_bg_a.png")
OUT = os.path.join(ROOT, "assets", "menu", "menu_bg.jpg")

im = Image.open(SRC).convert("RGB")
im.save(OUT, quality=92, optimize=True, progressive=False)
print("menu:", OUT, im.size, os.path.getsize(OUT) // 1024, "KB")
