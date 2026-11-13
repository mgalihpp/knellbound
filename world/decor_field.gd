class_name DecorField
extends Node3D
## Endless ground decoration: one random tile of props repeated 3x3 around
## the player. Instances are rewritten only when the player crosses a tile.

const CELL_WORLD := 18.0 / 16.0
const SPRITE_SHADER := preload("res://shaders/sprite_billboard.gdshader")

@export var sheet: Texture2D
## Frame weights, one per column of the decor sheet.
@export var frame_weights: PackedFloat32Array = [10.0, 4.0, 3.0, 2.0, 1.5, 0.6]
@export var tile_size := 40.0
@export var per_tile := 110
@export var y_stretch := 1.55
@export var random_seed := 1337

var _mm: MultiMesh
var _base := PackedVector3Array()  # x, z, frame index
var _flip := PackedFloat32Array()
var _tile := Vector2i(2147483647, 0)


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	mat.set_shader_parameter("sheet", sheet)
	mat.set_shader_parameter("hframes", frame_weights.size())
	mat.set_shader_parameter("vframes", 1)
	mat.set_shader_parameter("fps", 0.0)
	mat.set_shader_parameter("y_stretch", y_stretch)
	quad.material = mat

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = quad
	_mm.instance_count = per_tile * 9
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	for k in per_tile:
		var frame := rng.rand_weighted(frame_weights)
		_base.append(Vector3(rng.randf() * tile_size, rng.randf() * tile_size, frame))
		_flip.append(1.0 if rng.randf() < 0.5 else -1.0)


func tick(player_pos: Vector2) -> void:
	var t := Vector2i(floori(player_pos.x / tile_size), floori(player_pos.y / tile_size))
	if t == _tile:
		return
	_tile = t
	var basis := Basis.from_scale(Vector3.ONE * CELL_WORLD)
	var k := 0
	for ty in range(-1, 2):
		for tx in range(-1, 2):
			var ox := (t.x + tx) * tile_size
			var oz := (t.y + ty) * tile_size
			for b in per_tile:
				var p := _base[b]
				_mm.set_instance_transform(k, Transform3D(basis, Vector3(ox + p.x, 0.0, oz + p.y)))
				_mm.set_instance_custom_data(k, Color(p.z, _flip[b], 0.0, 0.0))
				k += 1
