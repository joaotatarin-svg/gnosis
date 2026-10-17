#!/usr/bin/env python3
"""FERRAMENTA (fora do jogo): peso do .pck por pasta.

Lê o diretório do .pck exportado (formato GDPC v2/v3 do Godot 4) e soma o
tamanho de cada arquivo pela pasta de ORIGEM (o .ctex de
res://.godot/imported/x.png-<hash>.ctex é atribuído ao x.png do projeto, via os
.import). Também lista os maiores arquivos e o que parece não ser usado em
runtime (fontes de arte em src/, PNG cromático com derivada, etc.).

Uso: python3 tools/perf/pck_peso.py <arquivo.pck> [--proj .] [--prof 2] [--top 25] [--json saida.json]
"""
import argparse
import json
import os
import struct
import sys
from collections import defaultdict


def read_pck(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, ver = struct.unpack_from("<4sI", data, 0)
    if magic != b"GDPC":
        sys.exit("não é um .pck GDPC: %r" % magic)
    major, minor, patch, flags = struct.unpack_from("<4I", data, 8)
    pos = 24
    file_base = struct.unpack_from("<Q", data, pos)[0]
    pos += 8
    if ver >= 3:
        dir_off = struct.unpack_from("<Q", data, pos)[0]
        pos = dir_off
    else:
        pos += 16 * 4
    count = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    entries = []
    for _ in range(count):
        plen = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        p = data[pos:pos + plen].rstrip(b"\0").decode("utf-8")
        pos += plen
        off, size = struct.unpack_from("<QQ", data, pos)
        pos += 16 + 16 + 4  # offset,size + md5 + flags
        if not p.startswith("res://"):
            p = "res://" + p
        entries.append((p, size))
    return {"versao_pck": ver, "godot": "%d.%d.%d" % (major, minor, patch), "arquivos": entries,
            "total": os.path.getsize(path)}


def imported_map(proj):
    """res://.godot/imported/<nome>-<hash>.<ext> -> res://<fonte>"""
    m = {}
    for root, dirs, files in os.walk(proj):
        dirs[:] = [d for d in dirs if d not in (".godot", ".git", "builds")]
        for fn in files:
            if not fn.endswith(".import"):
                continue
            src = os.path.join(root, fn)[:-len(".import")]
            rel = "res://" + os.path.relpath(src, proj).replace(os.sep, "/")
            try:
                txt = open(os.path.join(root, fn), encoding="utf-8").read()
            except OSError:
                continue
            for line in txt.splitlines():
                if line.startswith("path") and "res://.godot/imported/" in line:
                    dest = line.split("=", 1)[1].strip().strip('"')
                    m[dest] = rel
                elif line.startswith("dest_files="):
                    for d in line.split("=", 1)[1].strip("[]").split(","):
                        d = d.strip().strip('"')
                        if d:
                            m[d] = rel
    return m


def folder(p, depth):
    parts = p[len("res://"):].split("/")
    return "/".join(parts[:min(depth, len(parts) - 1)]) or "(raiz)"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pck")
    ap.add_argument("--proj", default=".")
    ap.add_argument("--prof", type=int, default=2)
    ap.add_argument("--top", type=int, default=25)
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    pk = read_pck(a.pck)
    imp = imported_map(a.proj)
    by = defaultdict(int)
    nfiles = defaultdict(int)
    rows = []
    for p, size in pk["arquivos"]:
        src = imp.get(p, p.replace(".remap", ""))
        rows.append((size, p, src))
        k = folder(src, a.prof)
        by[k] += size
        nfiles[k] += 1
    tot = sum(s for s, _, _ in rows)
    mb = lambda b: b / 1048576.0
    print("PCK %s  (formato v%d, Godot %s)  arquivo=%.1f MB  conteúdo=%.1f MB  %d arquivos" % (
        a.pck, pk["versao_pck"], pk["godot"], mb(pk["total"]), mb(tot), len(rows)))
    print("\n| Pasta (origem) | MB | % | arquivos |\n|---|---:|---:|---:|")
    for k, v in sorted(by.items(), key=lambda kv: -kv[1]):
        print("| %s | %.1f | %.1f | %d |" % (k, mb(v), 100.0 * v / tot, nfiles[k]))
    print("\nMaiores arquivos:\n| MB | origem | no pck |\n|---:|---|---|")
    for size, p, src in sorted(rows, reverse=True)[:a.top]:
        print("| %.2f | %s | %s |" % (mb(size), src, p.split("/")[-1][:60]))
    if a.json:
        json.dump({"total_mb": mb(pk["total"]), "pastas": {k: mb(v) for k, v in by.items()},
                   "maiores": [{"mb": mb(s), "origem": src, "pck": p} for s, p, src in sorted(rows, reverse=True)[:200]]},
                  open(a.json, "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
