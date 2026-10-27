// A água do chão dos cenários (#140), na linguagem pintada dos cards (water_painted.gdshaderinc): sem luz própria,
// com a cor do clima e da hora como os cards de fundo. A margem da frente (front_z, onde a água encosta no cais ou na
// ponte) e as linhas de margem (foam_lines, em z) ganham espuma, e as estacas e os barcos (foam_points: x, z e o raio)
// também.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/water_painted.gdshaderinc"

uniform float front_z = 0.0;
uniform float brightness = 1.0;
uniform vec4 weather = vec4(1.0);
uniform float wet = 0.0;
uniform float foam_width = 0.9;
uniform vec4 foam_lines = vec4(-9999.0);
uniform vec4 foam_points[16];
uniform int foam_count = 0;
// Um balanço de poucos centímetros na malha, só para a água não ficar dura.
uniform float bob = 0.03;
// A névoa da distância: longe da câmera, a água vai para a cor do horizonte (a água de longe não fica preta).
uniform vec3 horizon_color : source_color = vec3(0.42, 0.52, 0.55);
uniform float fog_near = 18.0;
uniform float fog_far = 160.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * flow;
	VERTEX.y += bob * sin(world.x * 0.35 + t * 0.9) * sin(world.z * 0.5 - t * 0.7) / max(length(MODEL_MATRIX[1].xyz), 0.001);
}

void fragment() {
	vec2 p = vec2(world.x, abs(front_z - world.z));
	float foam = smoothstep(foam_width, 0.0, abs(p.y));
	for (int i = 0; i < 4; i++) {
		if (foam_lines[i] > -9000.0) {
			foam = max(foam, smoothstep(foam_width, 0.0, abs(world.z - foam_lines[i])));
		}
	}
	for (int i = 0; i < foam_count; i++) {
		vec4 point = foam_points[i];
		float d = length(vec2(world.x - point.x, (world.z - point.y) * 1.6));
		foam = max(foam, smoothstep(point.z + 0.6, point.z, d));
	}
	float glint;
	vec3 color = painted_water(p, foam, glint);
	float fog = smoothstep(fog_near, fog_far, length(world - CAMERA_POSITION_WORLD));
	color = mix(color, horizon_color, fog * 0.85);
	ALBEDO = color * brightness * weather.rgb;
}
