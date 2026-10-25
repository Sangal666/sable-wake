shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 abyss_color : source_color = vec4(0.008, 0.068, 0.098, 1.0);
uniform vec4 deep_color : source_color = vec4(0.010, 0.135, 0.175, 1.0);
uniform vec4 face_color : source_color = vec4(0.032, 0.305, 0.335, 1.0);
uniform vec4 foam_color : source_color = vec4(0.78, 0.90, 0.84, 1.0);
uniform float ambient_lift : hint_range(0.0, 1.2) = 0.02;
uniform float simulation_time = 0.0;
uniform vec2 wind_direction = vec2(0.85, -0.35);
uniform float sea_state = 1.0;
uniform float wave_speed : hint_range(0.2, 2.2) = 1.0;
uniform float wave_chop : hint_range(0.1, 2.8) = 0.9;
uniform float foam_strength : hint_range(0.0, 2.8) = 0.85;

varying float wave_height;
varying float wave_steepness;
varying float long_swell;
varying float normalized_crest_height;
varying vec2 ocean_position;

void vertex() {
	vec2 p = VERTEX.xz;
	float t = simulation_time * wave_speed;
	vec2 d1 = normalize(wind_direction);
	vec2 d2 = normalize(vec2(-d1.y, d1.x) * 0.58 + d1 * 0.42);
	vec2 d3 = normalize(vec2(d1.y, -d1.x) * 0.78 + d1 * 0.22);
	vec2 d4 = normalize(-d1 * 0.16 + vec2(0.33, 0.94));
	vec2 d5 = normalize(d1 * 0.72 + vec2(-0.68, 0.22));
	vec2 d6 = normalize(d2 * 0.35 - d1 * 0.65);

	float p1 = dot(p, d1) * 0.045 + t * 0.50;
	float p2 = dot(p, d2) * 0.082 + t * 0.75 + 1.7;
	float p3 = dot(p, d3) * 0.145 + t * 1.08 + 3.2;
	float p4 = dot(p, d4) * 0.029 + t * 0.34 + 0.8;
	float p5 = dot(p, d5) * 0.245 + t * 1.48 + 4.4;
	float p6 = dot(p, d6) * 0.380 + t * 1.92 + 2.3;

	// Real swell arrives in uneven sets. Keep this envelope identical to the
	// WaveFluidArea3D solver so the hull rides the crest that is actually drawn.
	vec2 group_cross = vec2(-d1.y, d1.x);
	vec2 group_d3 = normalize(d1 * 0.68 + group_cross * 0.32);
	float set_strength = clamp((sea_state - 0.88) / 1.92, 0.0, 1.0) * clamp(wave_chop / 1.82, 0.0, 1.0);
	float gp1 = dot(p, d1) * 0.0105 + t * 0.075 + 0.35;
	float gp2 = dot(p, group_cross) * 0.0160 - t * 0.055 + 2.10;
	float gp3 = dot(p, group_d3) * 0.0072 + t * 0.038 + 4.20;
	float group_delta = set_strength * (sin(gp1) * 0.24 + sin(gp2) * 0.12 + sin(gp3) * 0.07);
	vec2 group_gradient = set_strength * (
		d1 * cos(gp1) * 0.24 * 0.0105
		+ group_cross * cos(gp2) * 0.12 * 0.0160
		+ group_d3 * cos(gp3) * 0.07 * 0.0072
	);
	float e1 = 1.0 + group_delta;
	float e2 = 1.0 + group_delta * 0.62;
	float e3 = 1.0 + group_delta * 0.24;
	float e4 = 1.0 + group_delta * 0.88;
	vec2 eg1 = group_gradient;
	vec2 eg2 = group_gradient * 0.62;
	vec2 eg3 = group_gradient * 0.24;
	vec2 eg4 = group_gradient * 0.88;
	float crest_strength = 0.22 * set_strength;
	float c1 = crest_strength;
	float c2 = crest_strength * 0.42;
	float c4 = crest_strength * 0.78;
	float s1 = sin(p1);
	float s2 = sin(p2);
	float s3 = sin(p3);
	float s4 = sin(p4);
	float s5 = sin(p5);
	float s6 = sin(p6);
	float h1 = s1 + c1 * (s1 * s1 - 0.5);
	float h2 = s2 + c2 * (s2 * s2 - 0.5);
	float h3 = s3;
	float h4 = s4 + c4 * (s4 * s4 - 0.5);
	float h5 = s5;
	float h6 = s6;
	float hd1 = cos(p1) * (1.0 + 2.0 * c1 * s1);
	float hd2 = cos(p2) * (1.0 + 2.0 * c2 * s2);
	float hd3 = cos(p3);
	float hd4 = cos(p4) * (1.0 + 2.0 * c4 * s4);
	float hd5 = cos(p5);
	float hd6 = cos(p6);

	float a1 = 0.42 * sea_state;
	float a2 = 0.24 * sea_state * mix(0.64, 1.12, wave_chop * 0.5);
	float a3 = 0.12 * sea_state * wave_chop;
	float a4 = 0.30 * sea_state;
	float a5 = 0.065 * sea_state * wave_chop;
	float a6 = 0.032 * sea_state * wave_chop;

	float height = h1 * a1 * e1 + h2 * a2 * e2 + h3 * a3 * e3;
	height += h4 * a4 * e4 + h5 * a5 + h6 * a6;
	vec2 slope = a1 * (d1 * hd1 * 0.045 * e1 + eg1 * h1);
	slope += a2 * (d2 * hd2 * 0.082 * e2 + eg2 * h2);
	slope += a3 * (d3 * hd3 * 0.145 * e3 + eg3 * h3);
	slope += a4 * (d4 * hd4 * 0.029 * e4 + eg4 * h4);
	slope += d5 * hd5 * a5 * 0.245;
	slope += d6 * hd6 * a6 * 0.380;

	float horizontal_scale = mix(0.38, 1.22, wave_chop * 0.5);
	vec2 horizontal = d1 * cos(p1) * a1 * 0.72 * e1;
	horizontal += d2 * cos(p2) * a2 * 0.50 * e2;
	horizontal += d4 * cos(p4) * a4 * 0.42 * e4;
	horizontal += d3 * cos(p3) * a3 * 0.24 * e3;
	VERTEX.xz += horizontal * horizontal_scale;
	VERTEX.y += height;

	// Derive the normal from the same choppy displacement used by physics.
	// Exaggerating only the shader normal made the rendered crest much steeper
	// than the surface the hull was actually riding.
	vec2 hg1 = a1 * 0.72 * horizontal_scale * (eg1 * cos(p1) - d1 * s1 * 0.045 * e1);
	vec2 hg2 = a2 * 0.50 * horizontal_scale * (eg2 * cos(p2) - d2 * s2 * 0.082 * e2);
	vec2 hg3 = a3 * 0.24 * horizontal_scale * (eg3 * cos(p3) - d3 * s3 * 0.145 * e3);
	vec2 hg4 = a4 * 0.42 * horizontal_scale * (eg4 * cos(p4) - d4 * s4 * 0.029 * e4);
	float j00 = 1.0 + d1.x * hg1.x + d2.x * hg2.x + d3.x * hg3.x + d4.x * hg4.x;
	float j01 = d1.x * hg1.y + d2.x * hg2.y + d3.x * hg3.y + d4.x * hg4.y;
	float j10 = d1.y * hg1.x + d2.y * hg2.x + d3.y * hg3.x + d4.y * hg4.x;
	float j11 = 1.0 + d1.y * hg1.y + d2.y * hg2.y + d3.y * hg3.y + d4.y * hg4.y;
	vec3 tangent_x = vec3(j00, slope.x, j10);
	vec3 tangent_z = vec3(j01, slope.y, j11);
	NORMAL = normalize(cross(tangent_z, tangent_x));

	wave_height = height;
	wave_steepness = length(slope);
	long_swell = h1 * e1 * 0.58 + h4 * e4 * 0.42;
	normalized_crest_height = height / max(sea_state, 0.08);
	ocean_position = p;
}

void fragment() {
	float detail_time = simulation_time * wave_speed;
	vec2 primary_direction = normalize(wind_direction);
	vec2 cross_direction = vec2(-primary_direction.y, primary_direction.x);
	float along_wave = dot(ocean_position, primary_direction);
	float across_wave = dot(ocean_position, cross_direction);
	float detail_x = sin(along_wave * 0.82 + across_wave * 0.19 + detail_time * 1.12);
	detail_x += sin(along_wave * 1.71 - across_wave * 0.43 - detail_time * 1.58) * 0.44;
	detail_x += sin(along_wave * 3.08 + across_wave * 0.72 + detail_time * 2.10) * 0.18;
	float detail_z = cos(across_wave * 0.74 - along_wave * 0.16 - detail_time * 0.96);
	detail_z += cos(across_wave * 1.52 + along_wave * 0.31 + detail_time * 1.46) * 0.40;
	detail_z += cos(across_wave * 2.84 - along_wave * 0.61 - detail_time * 2.22) * 0.16;
	float detail_strength = mix(0.018, 0.052, clamp(sea_state / 2.65, 0.0, 1.0));
	NORMAL = normalize(NORMAL + vec3(detail_x * detail_strength, 0.0, detail_z * detail_strength));
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.2);
	float crest_mask = smoothstep(0.58, 0.86, normalized_crest_height);
	float steep_mask = smoothstep(0.035, 0.19, wave_steepness);
	float foam_breakup = sin(along_wave * 0.86 - detail_time * 0.78 + sin(across_wave * 0.22) * 1.35);
	foam_breakup += sin(along_wave * 1.67 + across_wave * 0.38 - detail_time * 1.16) * 0.48;
	foam_breakup += sin(along_wave * 3.40 - across_wave * 0.91 + detail_time * 1.54) * 0.18;
	float broken_crest = smoothstep(0.14, 0.72, foam_breakup * 0.5 + 0.34);
	float hairline = smoothstep(0.90, 0.995, sin(along_wave * 2.26 + across_wave * 0.24 - detail_time * 1.36) * 0.5 + 0.5);
	float foam = crest_mask * steep_mask * (broken_crest * 0.32 + hairline * 0.12) * foam_strength;
	foam = clamp(foam, 0.0, 0.72);

	vec3 water = mix(abyss_color.rgb, deep_color.rgb, clamp(facing * 0.31 + 0.24, 0.0, 1.0));
	water = mix(water, face_color.rgb, fresnel * 0.46 + max(long_swell, 0.0) * 0.055);
	water *= mix(0.76, 1.06, smoothstep(-0.78, 0.82, normalized_crest_height));
	ALBEDO = mix(water, foam_color.rgb, foam * 0.72);
	ROUGHNESS = mix(0.07, 0.38, clamp(foam + wave_steepness * 0.44, 0.0, 1.0));
	SPECULAR = 0.96;
	METALLIC = 0.025;
	EMISSION = water * ambient_lift + foam_color.rgb * foam * 0.010;
}
