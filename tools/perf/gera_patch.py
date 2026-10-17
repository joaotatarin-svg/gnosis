#!/usr/bin/env python3
"""Gera os patches prontos para os donos a partir das propostas do agente de Desempenho.

  tools/perf/patches/vfx_prewarm.patch         (scripts/fx/vfx_library.gd + scripts/levels/level.gd)
  tools/perf/patches/character_art_alloc.patch (scripts/fx/character_art.gd — REVISAO #16)

Uso: python3 tools/perf/gera_patch.py [--proj .] [--aplicar-em <copia_do_projeto>]
  --aplicar-em  também grava os arquivos alterados numa CÓPIA do projeto (para testar).
Aplicar no jogo (dono do arquivo):  git apply tools/perf/patches/<nome>.patch
"""
import argparse
import difflib
import os
import re


def prewarm_body(proj):
    src = open(os.path.join(proj, "tools/perf/prewarm_proposta.gd"), encoding="utf-8").read()
    body = src[src.index("## Texturas de VFX que o combate carrega sob demanda"):]
    body = body.replace("VfxLibrary.tex(n)", "tex(n)")
    body = re.sub(r"\bVfxLibrary\.", "", body)
    header = (
        "\n\n# ===========================================================================\n"
        "# PRÉ-AQUECIMENTO (agente de Desempenho, Onda 2 — docs/onda2/PERF.md)\n"
        "# ===========================================================================\n"
        "## Chamado 1x no load da fase (Level._ready). Desenha por 3 quadros, no centro\n"
        "## da câmera e QUASE TRANSPARENTE (alfa 0,01 em escala 0,25), o visual real\n"
        "## das criaturas da tela, os gibs, o afterimage, o esqueleto e os efeitos do\n"
        "## combate, e carrega (segurando a referência) as texturas da 1ª criatura/efeito.\n"
        "## O driver compila as variantes de shader e sobe as texturas AGORA, e não no\n"
        "## 1º golpe/1ª morte/1ª esquiva. Sem som, sem tremor, fora dos grupos do jogo.\n"
        "## Medido: um SubViewport invisível NÃO serve (as variantes de lá não valem\n"
        "## para a tela); alfa < 0,007 é descartado pelo Godot antes de desenhar.\n\n"
    )
    return header + body


def vfx_library(proj):
    s = open(os.path.join(proj, "scripts/fx/vfx_library.gd"), encoding="utf-8").read()
    return s.rstrip("\n") + "\n" + prewarm_body(proj)


def level(proj):
    s = open(os.path.join(proj, "scripts/levels/level.gd"), encoding="utf-8").read()
    old = "\t_spawn_extras()\n\tawait _play_narrative_beats()"
    new = ("\t_spawn_extras()\n"
           "\t# Compila shaders e sobe texturas do combate AGORA (atrás do card de\n"
           "\t# abertura), e não no 1º golpe/morte/esquiva (docs/onda2/PERF.md).\n"
           "\tVfxLibrary.prewarm(self)\n"
           "\tawait _play_narrative_beats()")
    assert old in s, "level.gd mudou: ponto de inserção não encontrado"
    return s.replace(old, new)


def character_art(proj):
    s = open(os.path.join(proj, "scripts/fx/character_art.gd"), encoding="utf-8").read()
    chain = ('\tvar chain := {\n'
             '\t\t"walk": ["run"], "charge": ["run"], "dodge_back": ["dodge"], "attack_up": ["attack_heavy", "attack"],\n'
             '\t\t"attack_air": ["attack_heavy", "attack"], "attack_dive": ["attack_air", "attack_heavy", "attack"],\n'
             '\t\t"windup_heavy": ["windup"], "windup_cast": ["cast"], "fall": ["jump"], "dead": ["hurt"],\n'
             '\t\t"recover": ["idle"], "attack_heavy": ["attack"],\n'
             '\t}\n')
    reps = [
        (chain, ""),
        ("\tfor alt in chain.get(st, []):", "\tfor alt in HERO_CHAIN.get(st, []):"),
        ("## Estado de animação → sequência do banco (com cadeia de reserva).\nfunc _hero_seq(states: Dictionary) -> String:",
         "## Cadeia de reserva estado → sequências (const: antes era um dicionário\n"
         "## montado a cada quadro — REVISAO #16).\n"
         "const HERO_CHAIN := {\n"
         '\t"walk": ["run"], "charge": ["run"], "dodge_back": ["dodge"], "attack_up": ["attack_heavy", "attack"],\n'
         '\t"attack_air": ["attack_heavy", "attack"], "attack_dive": ["attack_air", "attack_heavy", "attack"],\n'
         '\t"windup_heavy": ["windup"], "windup_cast": ["cast"], "fall": ["jump"], "dead": ["hurt"],\n'
         '\t"recover": ["idle"], "attack_heavy": ["attack"],\n'
         "}\n"
         "## Âncoras (pés) das 6 poses antigas da Sophia (reserva sem banco de quadros).\n"
         "const HERO_FALLBACK_ANCHORS := [Vector2(269,492),Vector2(268,488),Vector2(267,493),Vector2(265,453),Vector2(239,455),Vector2(236,468)]\n\n\n"
         "## Estado de animação → sequência do banco (com cadeia de reserva).\nfunc _hero_seq(states: Dictionary) -> String:"),
        ("\t\t\tvar anchors := [Vector2(269,492),Vector2(268,488),Vector2(267,493),Vector2(265,453),Vector2(239,455),Vector2(236,468)]\n"
         "\t\t\trect = Rect2((frame % 3) * 512, (frame / 3) * 512, 512, 512)\n"
         "\t\t\tanchor = rect.position + anchors[frame]",
         "\t\t\trect = Rect2((frame % 3) * 512, (frame / 3) * 512, 512, 512)\n"
         "\t\t\tanchor = rect.position + HERO_FALLBACK_ANCHORS[frame]"),
        ('\t\tmesh = grid_mesh("%s:%s@%s:%s" % [painted.get("sheet", "sophia"), rect, anchor, painted.get("flip", false)], rect, anchor, Vector2(tex.get_width(), tex.get_height()), painted.get("flip", false))',
         "\t\t# Criatura: folha/recorte fixos até o próximo set_profile → a malha fica\n"
         "\t\t# guardada na instância (a chave formatada custava ~10 µs/quadro cada).\n"
         "\t\tif not hero and not _painted_mesh.is_empty():\n"
         "\t\t\tmesh = _painted_mesh\n"
         "\t\telse:\n"
         '\t\t\tmesh = grid_mesh("%s:%s@%s:%s" % [painted.get("sheet", "sophia"), rect, anchor, painted.get("flip", false)], rect, anchor, Vector2(tex.get_width(), tex.get_height()), painted.get("flip", false))\n'
         "\t\t\tif not hero:\n"
         "\t\t\t\t_painted_mesh = mesh"),
        ("func set_profile(p: ArtProfile) -> void:\n\tprofile = p\n\tpainted = PaintedLibrary.character(p)",
         "func set_profile(p: ArtProfile) -> void:\n\tprofile = p\n\tpainted = PaintedLibrary.character(p)\n\t_painted_mesh = {}"),
        ("var _body_xform := Transform2D.IDENTITY   # último transform do corpo (afterimage)",
         "var _painted_mesh: Dictionary = {}        # malha da pintura da criatura (cache por instância)\n"
         "var _body_xform := Transform2D.IDENTITY   # último transform do corpo (afterimage)"),
    ]
    for old, new in reps:
        assert old in s, "character_art.gd mudou: trecho não encontrado:\n" + old[:120]
        s = s.replace(old, new, 1)
    return s


def udiff(proj, rel, new):
    old = open(os.path.join(proj, rel), encoding="utf-8").read()
    return "".join(difflib.unified_diff(old.splitlines(True), new.splitlines(True), "a/" + rel, "b/" + rel))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--proj", default=".")
    ap.add_argument("--aplicar-em", default="")
    a = ap.parse_args()
    out = os.path.join(a.proj, "tools/perf/patches")
    os.makedirs(out, exist_ok=True)
    files = {
        "scripts/fx/vfx_library.gd": vfx_library(a.proj),
        "scripts/levels/level.gd": level(a.proj),
        "scripts/fx/character_art.gd": character_art(a.proj),
    }
    with open(os.path.join(out, "vfx_prewarm.patch"), "w", encoding="utf-8") as f:
        f.write(udiff(a.proj, "scripts/fx/vfx_library.gd", files["scripts/fx/vfx_library.gd"]))
        f.write(udiff(a.proj, "scripts/levels/level.gd", files["scripts/levels/level.gd"]))
    with open(os.path.join(out, "character_art_alloc.patch"), "w", encoding="utf-8") as f:
        f.write(udiff(a.proj, "scripts/fx/character_art.gd", files["scripts/fx/character_art.gd"]))
    if a.aplicar_em:
        for rel, txt in files.items():
            open(os.path.join(a.aplicar_em, rel), "w", encoding="utf-8").write(txt)
        for rel in ("tools/perf/prewarm_proposta.gd", "tools/perf/hitch_probe.gd", "tools/perf_probe.gd"):
            open(os.path.join(a.aplicar_em, rel), "w", encoding="utf-8").write(open(os.path.join(a.proj, rel), encoding="utf-8").read())
    print("patches em", out)


if __name__ == "__main__":
    main()
