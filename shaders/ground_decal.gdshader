// Flat animated decal lying on the ground (holy water pools, ...), for
// MultiMesh instances of a 1x1 PlaneMesh scaled to the decal size.
// INSTANCE_CUSTOM: x = animation phase, y = opacity 0..1,
// z = brightness (> 1 feeds the glow pass), w = sheet row.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D sheet : source_color, filter_nearest;
uniform int hframes = 4;
uniform int vframes = 1;
uniform float fps = 6.0;

varying vec2 v_uv;
varying vec3 v_custom;

void vertex() {
	float frame = floor(mod(TIME * fps + INSTANCE_CUSTOM.x, float(hframes)));
	v_uv = (UV + vec2(frame, INSTANCE_CUSTOM.w)) / vec2(float(hframes), float(vframes));
	v_custom = INSTANCE_CUSTOM.xyz;
}

void fragment() {
	vec4 c = texture(sheet, v_uv);
	ALBEDO = c.rgb * v_custom.z;
	ALPHA = c.a * v_custom.y;
}
