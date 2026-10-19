shader_type canvas_item;
// PINTURA FLEXÍVEL (CharacterArt): a malha em grade da pintura chega com os
// vértices em px da folha RELATIVOS AO PÉ (y = 0 no chão, negativo pra cima).
//  - vertex: inclinação/curvatura do corpo inteiro: desloca x ∝ (altura)², os
//    pés ficam pregados (substitui girar o cartão). `hem_wave` = ondulação da
//    barra (espectros), mais forte embaixo.
//  - fragment: vento no cabelo/manto por MÁSCARA gerada offline (R = cabelo,
//    G = barras do manto; mesma UV da folha) e dissolução com borda luminosa.
// Folhas derivadas já têm alfa real: nada de chave cromática aqui.

uniform float body_h = 256.0;          // altura do corpo em pé (unidades do VERTEX)
uniform float bend = 0.0;              // deslocamento x no topo da cabeça (unidades do VERTEX)
uniform float hem_wave = 0.0;          // amplitude da ondulação da barra (unidades do VERTEX)
uniform float wind_time = 0.0;
uniform bool use_flex = false;
uniform sampler2D flex_mask : filter_linear_mipmap, hint_default_black;
uniform float hair_amp = 0.0;          // px da folha
uniform float cloth_amp = 0.0;         // px da folha
uniform vec2 texel = vec2(0.0005);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
// LEITURA (NEURO R18, auditoria do Guardião): luz de contorno fina na cor do
// Éon, no estilo das pinturas — `rim_amt` acende a borda POR DENTRO (luz de
// recorte) e `halo_amt` põe um halo de ~1 px POR FORA (separa a silhueta do
// fundo cheio). `rim_px` = raio em texels do atlas.
uniform vec4 rim_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float rim_amt = 0.0;
uniform float halo_amt = 0.0;
uniform float rim_px = 3.0;

varying vec2 body_pos;                 // posição no corpo (0..1 de altura), pra o ruído
// COR DO VÉRTICE guardada: no Godot 4 o COLOR de entrada do fragment JÁ vem
// multiplicado pela textura — `texture(...) * COLOR` dava a cor AO QUADRADO
// (Sophia e criaturas mais escuras e saturadas que a pintura). Igual ao
// painted_boss.gdshader: amostra uma vez (com o vento) × cor do vértice.
varying vec4 vert_col;

void vertex() {
	float h = clamp(-VERTEX.y / body_h, 0.0, 1.6);
	VERTEX.x += bend * h * h;
	float low = clamp(1.0 - h * 1.6, 0.0, 1.0);
	VERTEX.x += hem_wave * low * low * sin(wind_time * 3.1 + VERTEX.y * 0.045);
	body_pos = VERTEX / body_h;
	vert_col = COLOR;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	if (use_flex) {
		vec2 m = texture(flex_mask, UV).rg;
		if (m.r + m.g > 0.002) {
			// cabelo: ondas que correm pra trás (−x da folha) e sobem/descem um pouco
			float wh = sin(wind_time * 5.3 - UV.x / texel.x * 0.045 + UV.y / texel.y * 0.02);
			float wc = sin(wind_time * 4.1 + UV.x / texel.x * 0.03 - UV.y / texel.y * 0.05);
			vec2 off = vec2(0.6 + 0.4 * wh, 0.35 * wh) * m.r * hair_amp;
			off += vec2(0.55 * wc, 0.25 * wc) * m.g * cloth_amp;
			uv += off * texel;
		}
	}
	vec4 c = texture(TEXTURE, uv);
	if (rim_amt > 0.0 || halo_amt > 0.0) {
		float mn = 1.0;
		float mx = 0.0;
		vec3 ncol = vec3(1.0);
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.785398;
			vec4 nb = texture(TEXTURE, uv + vec2(cos(ang), sin(ang)) * texel * rim_px);
			mn = min(mn, nb.a);
			if (nb.a > mx) {
				mx = nb.a;
				ncol = nb.rgb;
			}
		}
		if (c.a > 0.05) {
			// só acende onde a borda é ESCURA (botas, calça, cabelo na sombra): o
			// branco do manto já salta; luz nele só lavaria a pintura
			float dark = 1.0 - clamp(dot(c.rgb, vec3(0.299, 0.587, 0.114)) * 1.4, 0.0, 1.0);
			c.rgb += rim_color.rgb * clamp(c.a - mn, 0.0, 1.0) * rim_amt * dark;
		}
		// halo mais forte junto das partes escuras (onde ela some no fundo escuro)
		float ndark = 1.0 - clamp(dot(ncol, vec3(0.299, 0.587, 0.114)) * 1.4, 0.0, 1.0);
		float h = clamp(mx - c.a, 0.0, 1.0) * halo_amt * mix(0.3, 1.0, ndark);
		if (h > 0.0) {
			c.rgb = mix(c.rgb, rim_color.rgb, h / max(c.a + h, 0.001));
			c.a = max(c.a, h);
		}
	}
	if (dissolve > 0.0) {
		float n = vnoise(body_pos * 18.0) * 0.7 + vnoise(body_pos * 47.0) * 0.3;
		// de cima pra baixo levemente: a forma se desfaz a partir da cabeça
		n = mix(n, 1.0 - clamp(body_pos.y * -1.0, 0.0, 1.0), 0.25);
		float edge = dissolve * 1.15 - 0.05;
		if (n < edge - 0.0) {
			c.a = 0.0;
		} else if (n < edge + 0.07) {
			c.rgb = mix(c.rgb, glow_color.rgb * 2.2, 0.85);
		}
	}
	COLOR = c * vert_col;
}
