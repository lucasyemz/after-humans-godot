// Água com ondas dos cenários (port do M_AHWaterWaves da Unreal, Docs/Systems/water.md): duas ondas cruzadas que
// sobem e descem a malha (a grade de 1 m da Unreal), a normal das ondas mais as ondinhas finas, espuma nas cristas e a
// cor da água. As medidas vêm em cm, como na Unreal.
shader_type spatial;
render_mode cull_disabled;

uniform float amplitude = 60.0;
uniform float wavelength = 1500.0;
uniform float speed = 1.2;
uniform float foam = 0.1;
uniform float ripple = 0.04;
uniform float roughness_value = 0.22;
uniform float specular_value = 0.45;
uniform vec3 water_tint : source_color = vec3(0.035, 0.1, 0.12);
uniform vec3 foam_tint : source_color = vec3(0.28, 0.33, 0.28);

varying vec2 cm;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Plano da Unreal: x e y no chão (a Godot é x e z), em cm.
	vec2 p = vec2(world.x, world.z) * 100.0;
	float k = 6.283185 / max(wavelength, 100.0);
	float a = (p.x + 0.36 * p.y) * k + TIME * speed;
	float b = (1.73 * p.x - 0.71 * p.y) * k - TIME * speed * 0.8;
	vec3 offset_world = vec3(0.0, amplitude * (sin(a) + 0.4 * sin(b)) * 0.01, 0.0);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_world, 0.0)).xyz;
	cm = p;
}

void fragment() {
	float k = 6.283185 / max(wavelength, 100.0);
	vec2 p = cm;
	float a = (p.x + 0.36 * p.y) * k + TIME * speed;
	float b = (1.73 * p.x - 0.71 * p.y) * k - TIME * speed * 0.8;
	float c = p.x * 0.07 + p.y * 0.11 + TIME * 1.8;
	float d = p.x * 0.13 - p.y * 0.06 - TIME * 1.4;
	vec3 n = normalize(vec3(-amplitude * k * (cos(a) + 0.692 * cos(b)) - ripple * (cos(c) + 0.7 * cos(d)), 1.0,
		-amplitude * k * (0.36 * cos(a) - 0.284 * cos(b)) - ripple * (0.5 * cos(c) - 0.3 * cos(d))));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float crest = pow(clamp((sin(a) + 0.4 * sin(b) - 0.75) * 3.0, 0.0, 1.0), 3.0) * foam;
	ALBEDO = mix(water_tint, foam_tint, crest);
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	METALLIC = 0.0;
}
