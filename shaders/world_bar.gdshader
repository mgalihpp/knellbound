shader_type spatial;
// Small HP bar under the player: a camera-facing quad drawn in art pixels
// (`pixels` = bar size incl. outline), no depth test so it is never hidden.
// Set `fill` (0..1) only when it changes (WorldHpBar).
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, blend_mix;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec2 pixels = vec2(20.0, 4.0);
uniform vec4 fill_color : source_color = vec4(0.82, 0.16, 0.23, 1.0);
uniform vec4 fill_light : source_color = vec4(1.0, 0.48, 0.52, 1.0);
uniform vec4 back_color : source_color = vec4(0.16, 0.06, 0.1, 1.0);
uniform vec4 outline_color : source_color = vec4(0.094, 0.063, 0.118, 1.0);

void vertex() {
	// Billboard: keep the model origin, face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = floor(UV * pixels);
	ALBEDO = outline_color.rgb;
	bool edge = p.x < 1.0 || p.y < 1.0 || p.x > pixels.x - 2.0 || p.y > pixels.y - 2.0;
	if (!edge) {
		float inner = pixels.x - 2.0;
		// Round up so any HP left shows at least one pixel.
		bool filled = p.x - 1.0 < ceil(fill * inner);
		ALBEDO = filled ? (p.y < 1.5 ? fill_light.rgb : fill_color.rgb) : back_color.rgb;
	}
	ALPHA = 1.0;
}
