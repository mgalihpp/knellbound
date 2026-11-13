// One quad per damage number; the digits are picked in the fragment shader
// from a 0-9 strip (art/sprites/damage_digits.png), so a number of any length
// is a single MultiMesh instance. Y-axis billboard, centred quad, drawn on top
// of the world (no depth test) with alpha fade.
// Instance scale: x = digit count * digit width, y = digit height.
// INSTANCE_CUSTOM: x = value (integer), y = alpha 0..1,
// z = kind (0 normal, 1 crit, 2 heal, 3 hurt; DamageNumberField), w = digit count.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform sampler2D digits : source_color, filter_nearest;
uniform float y_stretch = 1.55;
uniform vec4 normal_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 crit_color : source_color = vec4(1.0, 0.78, 0.18, 1.0);
uniform vec4 heal_color : source_color = vec4(0.42, 1.0, 0.5, 1.0);
uniform vec4 hurt_color : source_color = vec4(1.0, 0.28, 0.3, 1.0);
// > 1 feeds the glow pass: crits shine.
uniform float crit_energy = 1.7;

varying vec4 v_data;

void vertex() {
	v_data = INSTANCE_CUSTOM;
	VERTEX.y *= y_stretch;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float n = v_data.w;
	float x = UV.x * n;
	float k = floor(x);
	// +0.001: pow() may land a hair off the exact power of ten.
	float d = mod(floor(v_data.x / pow(10.0, n - 1.0 - k) + 0.001), 10.0);
	vec4 c = texture(digits, vec2((d + fract(x)) / 10.0, UV.y));
	int kind = int(v_data.z + 0.5);
	vec3 tint = normal_color.rgb;
	if (kind == 1) {
		tint = crit_color.rgb * crit_energy;
	} else if (kind == 2) {
		tint = heal_color.rgb;
	} else if (kind == 3) {
		tint = hurt_color.rgb;
	}
	// White glyph pixels take the tint; the dark outline stays dark.
	ALBEDO = c.rgb * tint * (1.0 - 0.25 * UV.y);
	ALPHA = c.a * v_data.y;
}
