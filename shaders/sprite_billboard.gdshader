// Y-axis billboard sprite for MultiMesh instances.
// INSTANCE_CUSTOM: x = animation phase (frame offset; with fps = 0 it is the
// frame index), y = facing * (1 + tint): sign = +1 right / -1 left,
// |y| - 1 = elite tint 0..1 (outline pixels glow `elite_color`, body warms),
// z = hit flash 0..1, w = sheet row.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform sampler2D sheet : source_color, filter_nearest;
uniform int hframes = 4;
uniform int vframes = 1;
uniform float fps = 8.0;
uniform float y_stretch = 1.55;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// The generator's outline colour (tools/gen_sprites.py OUTLINE).
uniform vec4 outline_color : source_color = vec4(0.094, 0.063, 0.118, 1.0);
// > 1 so the glow pass picks the elite outline up.
uniform vec4 elite_color : source_color = vec4(1.0, 0.18, 0.22, 1.0);
uniform float elite_energy = 1.6;
uniform vec4 elite_body : source_color = vec4(1.0, 0.7, 0.75, 1.0);

varying vec2 v_uv;
varying float v_flash;
varying float v_tint;

void vertex() {
	float frame = floor(mod(TIME * fps + INSTANCE_CUSTOM.x, float(hframes)));
	vec2 uv = UV;
	if (INSTANCE_CUSTOM.y < 0.0) {
		uv.x = 1.0 - uv.x;
	}
	v_uv = (uv + vec2(frame, INSTANCE_CUSTOM.w)) / vec2(float(hframes), float(vframes));
	v_flash = INSTANCE_CUSTOM.z;
	v_tint = clamp(abs(INSTANCE_CUSTOM.y) - 1.0, 0.0, 1.0);

	VERTEX.y *= y_stretch;
	// Rotate around world Y to face the camera, keep instance scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(sheet, v_uv);
	vec3 col = c.rgb;
	if (v_tint > 0.0) {
		bool is_outline = distance(c.rgb, outline_color.rgb) < 0.004;
		float pulse = 0.8 + 0.2 * sin(TIME * 7.0);
		col = is_outline ? elite_color.rgb * elite_energy * pulse * v_tint
				: mix(col, col * elite_body.rgb, 0.6 * v_tint);
	}
	ALBEDO = mix(col, flash_color.rgb, v_flash);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
