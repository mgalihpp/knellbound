// Y-axis billboard for projectile MultiMesh instances, rotated in the screen
// plane. The quad is centred (not feet-aligned) and floats at the instance Y.
// INSTANCE_CUSTOM: x = animation phase (frame offset; fps = 0 -> frame index),
// y = screen angle in radians (counter-clockwise, sprite art points right),
// z = brightness (> 1 feeds the glow pass), w = sheet row.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform sampler2D sheet : source_color, filter_nearest;
uniform int hframes = 4;
uniform int vframes = 4;
uniform float fps = 10.0;
uniform float y_stretch = 1.55;

varying vec2 v_uv;
varying float v_glow;

void vertex() {
	float frame = floor(mod(TIME * fps + INSTANCE_CUSTOM.x, float(hframes)));
	v_uv = (UV + vec2(frame, INSTANCE_CUSTOM.w)) / vec2(float(hframes), float(vframes));
	v_glow = INSTANCE_CUSTOM.z;

	// Rotate in the quad plane first, then stretch: with the stretch undoing
	// the camera pitch, the angle reads the same on screen.
	float a = INSTANCE_CUSTOM.y;
	float c = cos(a);
	float s = sin(a);
	VERTEX.xy = vec2(c * VERTEX.x - s * VERTEX.y, (s * VERTEX.x + c * VERTEX.y) * y_stretch);

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
	ALBEDO = c.rgb * v_glow;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
