class_name WorldHpBar
extends MeshInstance3D
## View only: the player's small HP bar in the world (shaders/world_bar).
## Hud.refresh() calls set_fraction() every frame; the shader parameter is
## written only when the drawn pixel count changes.

## Bar size in art pixels (16 px = 1 world unit), outline included.
@export var pixels := Vector2i(20, 4)

var _shown := -1


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(pixels.x, pixels.y) / 16.0
	mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/world_bar.gdshader")
	mat.set_shader_parameter(&"pixels", Vector2(pixels))
	mat.render_priority = 10
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_fraction(f: float) -> void:
	var inner := pixels.x - 2
	var px := ceili(clampf(f, 0.0, 1.0) * inner)
	if px == _shown:
		return
	_shown = px
	(material_override as ShaderMaterial).set_shader_parameter(&"fill", float(px) / inner)
