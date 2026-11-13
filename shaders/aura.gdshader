// Ground aura disc: pixel-quantised rim, rotating rune ring, outward ripples.
// Drawn on a 2x2 PlaneMesh scaled by the aura radius.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float intensity = 1.4;
uniform float pulse = 0.0;
uniform float pixel_steps = 64.0;
uniform float rune_count = 14.0;

void fragment() {
	vec2 uv = (floor(UV * pixel_steps) + 0.5) / pixel_steps;
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x) / 6.28318 + 0.5;
	float rim = smoothstep(0.86, 0.94, r);
	float runes = step(0.55, fract(ang * rune_count + TIME * 0.35))
		* step(0.66, r) * (1.0 - step(0.74, r));
	float ripple = step(0.82, fract(r * 3.0 - TIME * 0.8)) * 0.35;
	float fill = 0.08 + 0.18 * r * r;
	float a = rim * 0.9 + runes * 0.55 + ripple * r + fill + pulse * 0.35 * (1.0 - r * 0.5);
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp(a, 0.0, 1.0);
}
