# Lista o conteúdo de um .pck do Godot 4 (formato v3/v4, diretório não criptografado)
# e procura strings sensíveis (caminhos pessoais, e-mails) nos arquivos.
# Uso: python -I pck_list.py <arquivo.pck> [--scan]
import struct, sys, re
path = sys.argv[1]
d = open(path, 'rb').read()
assert d[:4] == b'GDPC'
ver, major, minor, patch, flags = struct.unpack_from('<5I', d, 4)
file_base, dir_off = struct.unpack_from('<QQ', d, 24)
if flags & 2:  # base relativa
	pass
p = dir_off
n, = struct.unpack_from('<I', d, p); p += 4
entries = []
for _ in range(n):
	ln, = struct.unpack_from('<I', d, p); p += 4
	name = d[p:p+ln].rstrip(b'\0').decode('utf-8', 'replace'); p += ln
	off, size = struct.unpack_from('<QQ', d, p); p += 16
	p += 16  # md5
	fl, = struct.unpack_from('<I', d, p); p += 4
	entries.append((name, off, size, fl))
print('versao pck', ver, 'godot', major, minor, patch, 'flags', flags, 'arquivos', n)
for name, off, size, fl in entries:
	print(f'{size:>10} {name}')
if '--scan' in sys.argv:
	pat = re.compile(rb'(jmtat|joaotatarin|C:\\Users|C:/Users|OneDrive|gmail\.com|Desktop\\|api[_-]?key|secret|token)', re.I)
	for name, off, size, fl in entries:
		blob = d[file_base + off: file_base + off + size] if not (flags & 2) else d[file_base + off: file_base + off + size]
		for m in set(pat.findall(blob)):
			i = blob.find(m)
			ctx = blob[max(0, i-60): i+80]
			print('ACHADO', name, m, ctx)
