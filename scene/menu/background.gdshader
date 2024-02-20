shader_type canvas_item;

uniform vec2 tile_times = vec2(40.85106, 7.65957);

void fragment() {
	vec2 tile_offset;
	//COLOR = vec4(UV * tile_times * vec2(8, 8), 0.0, 1.0);
	COLOR = texture(TEXTURE, UV * tile_times);
}
