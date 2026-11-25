shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 ocean_color : source_color = vec4(0.018, 0.20, 0.27, 1.0);
uniform vec4 ocean_fresnel_color : source_color = vec4(0.10, 0.42, 0.49, 1.0);
uniform float roughness : hint_range(0.02, 1.0) = 0.24;

uniform float wave_time = 0.0;
uniform float wave_amplitude = 0.35;
uniform float secondary_wave_amplitude = 0.16;
uniform float wave_frequency = 0.12;
uniform float secondary_wave_frequency = 0.21;
uniform vec2 wave_direction = vec2(1.0, 0.25);
uniform vec2 secondary_wave_direction = vec2(-0.35, 1.0);
uniform float wave_speed = 1.0;
uniform float secondary_wave_speed = 1.35;

uniform sampler2DArray displacement_maps : filter_linear;
uniform bool use_fft_displacement = false;
uniform vec4 grid_tile_lengths_x = vec4(512.0, 128.0, 32.0, 8.0);
uniform vec4 grid_tile_lengths_y = vec4(512.0, 128.0, 32.0, 8.0);
uniform vec4 grid_displacement_scales = vec4(1.0);

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	if (use_fft_displacement) {
		vec3 fft_displacement = vec3(0.0);
		for (int grid_index = 0; grid_index < 4; grid_index++) {
			vec2 tile_length = vec2(grid_tile_lengths_x[grid_index], grid_tile_lengths_y[grid_index]);
			vec2 grid_uv = fract(world_position.xz / max(tile_length, vec2(0.001)));
			vec3 grid_displacement = textureLod(displacement_maps, vec3(grid_uv, float(grid_index)), 0.0).xyz;
			fft_displacement += grid_displacement * grid_displacement_scales[grid_index];
		}
		VERTEX += fft_displacement;
	} else {
		vec2 dir_a = normalize(wave_direction);
		vec2 dir_b = normalize(secondary_wave_direction);
		float wave_a = sin(dot(world_position.xz, dir_a) * wave_frequency + wave_time * wave_speed);
		float wave_b = sin(dot(world_position.xz, dir_b) * secondary_wave_frequency + wave_time * secondary_wave_speed);
		VERTEX.y += (wave_a * wave_amplitude) + (wave_b * secondary_wave_amplitude);
	}
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	ALBEDO = mix(ocean_color.rgb, ocean_fresnel_color.rgb, fresnel);
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
