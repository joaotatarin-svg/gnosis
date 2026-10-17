shader_type canvas_item;
render_mode blend_add;
// AFTERIMAGE: silhueta da pintura em luz aditiva tingida (cor/força no modulate).
void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(COLOR.rgb * a * COLOR.a, a * COLOR.a);
}
