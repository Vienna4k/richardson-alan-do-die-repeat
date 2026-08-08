shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(fill_color.rgb, tex.a);
}
