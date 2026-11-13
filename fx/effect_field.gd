class_name EffectField
extends Node3D
## One-shot sprite effects (kill bursts, explosions, pickup sparkles, debris)
## as parallel packed arrays + one MultiMesh. Each effect plays the frames of
## its row in art/sprites/effects.png once over its life and is removed
## (swap-with-last). The sprite_billboard shader runs with fps = 0, so
## INSTANCE_CUSTOM.x is the frame index; y = random flip (+-1), z = 0, w = row.

## Rows of art/sprites/effects.png (= EnemyData.death_effect,
## PickupData.collect_effect).
enum Fx { SMOKE, BLOOD, ECTO, EXPLOSION, SPARKLE, HEAL, WOOD, IRON, STONE, BONE }

const STRIDE := 16
const CELL_WORLD := 18.0 / 16.0
const SPRITE_SHADER := preload("res://shaders/sprite_billboard.gdshader")

@export var sheet: Texture2D
@export var hframes := 6
@export var vframes := 10
@export var y_stretch := 1.55
@export var capacity := 768
@export var default_life := 0.4

var count := 0
var pos := PackedVector2Array()
var lift := PackedFloat32Array()
var age := PackedFloat32Array()
var life := PackedFloat32Array()
var size := PackedFloat32Array()
var row := PackedFloat32Array()
var flip := PackedFloat32Array()

var _buf := PackedFloat32Array()
var _mm: MultiMesh


func _ready() -> void:
	pos.resize(capacity)
	lift.resize(capacity)
	age.resize(capacity)
	life.resize(capacity)
	size.resize(capacity)
	row.resize(capacity)
	flip.resize(capacity)
	_buf.resize(capacity * STRIDE)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	mat.set_shader_parameter("sheet", sheet)
	mat.set_shader_parameter("hframes", hframes)
	mat.set_shader_parameter("vframes", vframes)
	mat.set_shader_parameter("fps", 0.0)
	mat.set_shader_parameter("y_stretch", y_stretch)
	quad.material = mat

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = quad
	_mm.instance_count = capacity
	_mm.visible_instance_count = 0
	_mm.custom_aabb = AABB(Vector3(-10000, -10, -10000), Vector3(20000, 50, 20000))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## `scale` 1 = one 16 px cell. `seconds` 0 = default_life. `height` lifts the
## effect off the ground (world units). Dropped when the field is full.
func spawn(at: Vector2, fx: int, scale: float = 1.0, seconds: float = 0.0,
		height: float = 0.0) -> void:
	if fx < 0 or count >= capacity:
		return
	var i := count
	count += 1
	pos[i] = at
	lift[i] = height
	age[i] = 0.0
	life[i] = seconds if seconds > 0.0 else default_life
	size[i] = CELL_WORLD * scale
	row[i] = float(fx)
	flip[i] = 1.0 if randf() < 0.5 else -1.0


func tick(dt: float) -> void:
	var i := 0
	while i < count:
		age[i] += dt
		if age[i] >= life[i]:
			var last := count - 1
			pos[i] = pos[last]
			lift[i] = lift[last]
			age[i] = age[last]
			life[i] = life[last]
			size[i] = size[last]
			row[i] = row[last]
			flip[i] = flip[last]
			count = last
			continue
		i += 1


func clear() -> void:
	count = 0


func upload() -> void:
	var frames := float(hframes)
	for i in count:
		var o := i * STRIDE
		var s := size[i]
		var p := pos[i]
		_buf[o] = s
		_buf[o + 3] = p.x
		_buf[o + 5] = s
		_buf[o + 7] = lift[i]
		_buf[o + 10] = s
		_buf[o + 11] = p.y
		_buf[o + 12] = minf(frames - 1.0, floorf(age[i] / life[i] * frames))
		_buf[o + 13] = flip[i]
		_buf[o + 14] = 0.0
		_buf[o + 15] = row[i]
	RenderingServer.multimesh_set_buffer(_mm.get_rid(), _buf)
	_mm.visible_instance_count = count
