shader_type canvas_item;
render_mode unshaded;
varying vec4 node_tint;
void vertex() { node_tint = COLOR; }
// Remove somente o fundo cromático das folhas; a imagem original é preservada.
void fragment() {
 vec4 c = texture(TEXTURE, UV);
 float key = min(c.r, c.b) - c.g;
 float cut = smoothstep(0.20, 0.48, key);
 float spill = max(0.0,key-0.08) * 0.8;
 c.r = max(0.0,c.r-spill);
 c.b = max(0.0,c.b-spill);
 c.a *= 1.0-cut;
 c.a = smoothstep(0.10, 0.85, c.a);
 COLOR = node_tint * c;
}
