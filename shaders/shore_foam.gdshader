shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 foam_color : source_color = vec4(0.88, 0.94, 0.86, 1.0);
uniform float simulation_time = 0.0;
uniform vec2 wind_direction = vec2(0.85, -0.35);
uniform float sea_state = 1.0;

varying vec2 foam_uv;

float ocean_height_at(vec2 p, float t) {
	vec2 d1 = normalize(wind_direction);
	vec2 d2 = normalize(vec2(-d1.y, d1.x) * 0.58 + d1 * 0.42);
	vec2 d3 = normalize(vec2(d1.y, -d1.x) * 0.78 + d1 * 0.22);
	vec2 d4 = normalize(-d1 * 0.16 + vec2(0.33, 0.94));
	vec2 d5 = normalize(d1 * 0.72 + vec2(-0.68, 0.22));
	vec2 d6 = normalize(d2 * 0.35 - d1 * 0.65);
	float h = sin(dot(p, d1) * 0.045 + t * 0.50) * 0.42;
	h += sin(dot(p, d2) * 0.082 + t * 0.75 + 1.7) * 0.24;
	h += sin(dot(p, d3) * 0.145 + t * 1.08 + 3.2) * 0.12;
	h += sin(dot(p, d4) * 0.029 + t * 0.34 + 0.8) * 0.30;
	h += sin(dot(p, d5) * 0.245 + t * 1.48 + 4.4) * 0.065;
	h += sin(dot(p, d6) * 0.380 + t * 1.92 + 2.3) * 0.032;
	return h * sea_state;
}

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += ocean_height_at(world_position.xz, simulation_time);
	foam_uv = UV;
}

void fragment() {
	float soft_ring = sin(clamp(foam_uv.x, 0.0, 1.0) * 3.14159265);
	soft_ring = pow(max(soft_ring, 0.0), 0.72);
	float sweep = sin(foam_uv.y * 38.0 - simulation_time * 1.65 + foam_uv.x * 8.0);
	float breakup = sin(foam_uv.y * 91.0 + simulation_time * 0.48) * 0.5 + 0.5;
	float bands = smoothstep(-0.38, 0.66, sweep + breakup * 0.42);
	ALBEDO = foam_color.rgb;
	EMISSION = foam_color.rgb * 0.10;
	ALPHA = soft_ring * mix(0.10, 0.46, bands);
}
