class_name PickupField
extends Node3D
## World pickups other than gems (chest, food, magnet, bomb, coins...) as
## parallel packed arrays + one MultiMesh, same 16-float buffer layout as
## GemField. Each pickup kind is a PickupData (.tres) listed in `types`;
## a slot stores the index into `types`. Sheet row = PickupData.sprite_row,
## columns = shine / spin frames.
##
## The field only moves, draws and collects: tick() returns the type indices
## the player touched this frame (positions in `collected_at`) and Game
## decides what each PickupData.effect does. Magnetic pickups (coins) fly in
## like gems once inside the player's magnet radius, or after attract_all().

const STRIDE := 16
const CELL_WORLD := 18.0 / 16.0
const SPRITE_SHADER := preload("res://shaders/sprite_billboard.gdshader")

@export var types: Array[PickupData] = []
@export var sheet: Texture2D
@export var hframes := 4
@export var vframes := 7
@export var anim_fps := 6.0
@export var y_stretch := 1.55
@export var capacity := 256
@export var collect_radius := 0.8
## Seconds a fresh drop takes to land (small hop, cannot be picked up yet).
@export var drop_time := 0.45
@export var drop_height := 1.4
@export var pull_accel := 60.0
@export var max_pull_speed := 24.0
## Periodic white glint (sprite flash) on top of the sheet's shine frames.
@export var glint_strength := 0.45
@export var glint_period := 1.6

var count := 0
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var kind := PackedInt32Array()
var age := PackedFloat32Array()
var phase := PackedFloat32Array()
var pulled := PackedByteArray()
## Positions of the pickups returned by the last tick() (same order).
var collected_at := PackedVector2Array()

var _collected := PackedInt32Array()
var _t_scale := PackedFloat32Array()
var _t_row := PackedFloat32Array()
var _t_magnetic := PackedByteArray()
var _buf := PackedFloat32Array()
var _mm: MultiMesh
var _time := 0.0


func _ready() -> void:
	pos.resize(capacity)
	vel.resize(capacity)
	kind.resize(capacity)
	age.resize(capacity)
	phase.resize(capacity)
	pulled.resize(capacity)
	_buf.resize(capacity * STRIDE)
	for t in types:
		_t_scale.append(CELL_WORLD * t.scale)
		_t_row.append(float(t.sprite_row))
		_t_magnetic.append(1 if t.magnetic else 0)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	mat.set_shader_parameter("sheet", sheet)
	mat.set_shader_parameter("hframes", hframes)
	mat.set_shader_parameter("vframes", vframes)
	mat.set_shader_parameter("fps", anim_fps)
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


## Returns false when the field is full (drop is lost) or `data` is not in `types`.
func drop(at: Vector2, data: PickupData) -> bool:
	var t := types.find(data)
	if t < 0:
		push_error("PickupField.types is missing %s" % data.resource_path)
		return false
	if count >= capacity:
		return false
	var i := count
	count += 1
	pos[i] = at
	vel[i] = Vector2.ZERO
	kind[i] = t
	age[i] = 0.0
	phase[i] = randf() * hframes
	pulled[i] = 0
	return true


## Every magnetic pickup flies to the player (MAGNET pickup).
func attract_all() -> void:
	for i in count:
		if _t_magnetic[kind[i]]:
			pulled[i] = 1


## Ages drops, pulls magnetic ones within `magnet` and collects those touching
## `target`. Returns the type indices collected this frame (reused array:
## read it, and `collected_at`, before the next tick).
func tick(dt: float, target: Vector2, magnet: float) -> PackedInt32Array:
	_time += dt
	_collected.clear()
	collected_at.clear()
	var r2 := collect_radius * collect_radius
	var m2 := magnet * magnet
	var i := 0
	while i < count:
		age[i] += dt
		if age[i] < drop_time:
			i += 1
			continue
		var d := target - pos[i]
		var l2 := d.length_squared()
		if l2 <= r2:
			_collect(i)
			continue
		if pulled[i] == 0 and _t_magnetic[kind[i]] and l2 < m2:
			pulled[i] = 1
		if pulled[i]:
			var dist := sqrt(l2)
			var v := (vel[i] + d * (pull_accel * dt / dist)).limit_length(max_pull_speed)
			if v.length() * dt >= dist:
				_collect(i)
				continue
			vel[i] = v
			pos[i] += v * dt
		i += 1
	return _collected


func _collect(i: int) -> void:
	_collected.append(kind[i])
	collected_at.append(pos[i])
	_remove_at(i)


func clear() -> void:
	count = 0


func _remove_at(i: int) -> void:
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		vel[i] = vel[last]
		kind[i] = kind[last]
		age[i] = age[last]
		phase[i] = phase[last]
		pulled[i] = pulled[last]
	count = last


func upload() -> void:
	for i in count:
		var o := i * STRIDE
		var p := pos[i]
		var k := kind[i]
		var s := _t_scale[k]
		var t := minf(1.0, age[i] / drop_time)
		var hop := 4.0 * drop_height * t * (1.0 - t)
		var glint := pow(maxf(0.0, sin((_time + phase[i]) * TAU / glint_period)), 12.0)
		_buf[o] = s
		_buf[o + 3] = p.x
		_buf[o + 5] = s
		_buf[o + 7] = hop + 0.04 * sin(_time * 2.5 + phase[i])
		_buf[o + 10] = s
		_buf[o + 11] = p.y
		_buf[o + 12] = phase[i]
		_buf[o + 13] = 1.0
		_buf[o + 14] = glint * glint_strength
		_buf[o + 15] = _t_row[k]
	RenderingServer.multimesh_set_buffer(_mm.get_rid(), _buf)
	_mm.visible_instance_count = count
