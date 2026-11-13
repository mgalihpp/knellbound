// Soft pixel-stepped ellipse under characters. Works on a plain PlaneMesh and
// inside a MultiMesh (instance custom data is ignored).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 shadow_color : source_color = vec4(0.04, 0.03, 0.08, 1.0);
uniform float opacity = 0.45;
uniform float steps = 8.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = 1.0 - smoothstep(0.55, 1.0, r);
	a = floor(a * steps) / steps;
	ALBEDO = shadow_color.rgb;
	ALPHA = a * opacity;
}
