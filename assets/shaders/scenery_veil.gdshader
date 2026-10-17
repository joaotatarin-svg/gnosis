shader_type canvas_item;
render_mode blend_add, unshaded;
// VÉU DA ARENA (cenário · P2). Cortina de luz na cor do Éon onde fica a
// parede de uma zona trancada: um fio claro no x da parede, brilho que vaza
// para DENTRO da arena, filetes subindo (ruído) e runas curtas que sobem.
// Coordenadas locais: x = 0 na parede, y = 0 na linha dos pés, y < 0 = alto.
// `amt` faz o fade (0 = some); `side` = +1 parede à direita, -1 à esquerda.

uniform vec4 col : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float amt = 1.0;
uniform float side = 1.0;
uniform float height = 300.0;

varying vec2 p;

void vertex() {
	p = VERTEX;
}

float h1(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

float vn(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	float a = h1(i.x + i.y * 57.0);
	float b = h1(i.x + 1.0 + i.y * 57.0);
	float c = h1(i.x + (i.y + 1.0) * 57.0);
	float d = h1(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float x = p.x;
	float y = p.y;
	float inward = (x * side < 0.0) ? 1.0 : 0.35;        // vaza mais para dentro
	float ax = abs(x);
	// filetes que sobem (ruído esticado na vertical)
	float n = vn(vec2(x * 0.22, y * 0.035 + TIME * 0.9)) * 0.6 + vn(vec2(x * 0.5 + 7.0, y * 0.08 + TIME * 1.7)) * 0.4;
	float core = exp(-pow(ax / 2.2, 2.0)) * 0.32;
	float glow = exp(-ax / 16.0) * inward * (0.07 + 0.26 * n * n);
	// runas: tracinhos horizontais curtos subindo devagar pelo fio
	float ry = y * 0.045 + TIME * 0.35;
	float rune = step(0.86, fract(ry)) * step(0.55, h1(floor(ry))) * exp(-pow(ax / 4.0, 2.0)) * 0.30;
	// perfil vertical: forte no chão, some no alto; clarão na base
	float vert = pow(smoothstep(-height, 0.0, y), 1.6) * (1.0 - smoothstep(4.0, 12.0, y));
	float base = exp(-pow(y / 5.0, 2.0)) * exp(-ax / 18.0) * 0.40;
	float a = ((core + glow + rune) * vert + base) * amt;
	COLOR = vec4(col.rgb * a, 1.0);
}
