class_name GemField
extends Node3D
## XP gems as parallel packed arrays + one MultiMesh, same buffer layout as
## EnemySwarm (16 floats: 3x4 transform + INSTANCE_CUSTOM). Removal is
## swap-with-last.
##
## A gem rests until the player's magnet radius reaches it, then hops away
## briefly and accelerates into the player. Above `max_gems`, new drops are
## merged into one "bank" gem, so the count stays bounded and the bank gem
## climbs to the higher tiers.

const STRIDE := 16
const CELL_WORLD := 18.0 / 16.0
const SPRITE_SHADER := preload("res://shaders/sprite_billboard.gdshader")

@export var sheet: Texture2D
@export var hframes := 4
@export var vframes := 4
@export var anim_fps := 6.0
@export var y_stretch := 1.55
@export var gem_scale := 0.8
@export var max_gems := 400
## Minimum XP value of each tier (= sheet row), ascending.
@export var tier_min_value: PackedFloat32Array = [0.0, 5.0, 20.0, 100.0]
@export var pop_speed := 4.0
@export var pull_accel := 70.0
@export var max_pull_speed := 26.0
@export var collect_radius := 0.55

var count := 0
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var value := PackedFloat32Array()
var tier := PackedFloat32Array()
var phase := PackedFloat32Array()
var pulled := PackedByteArray()

var _buf := PackedFloat32Array()
var _mm: MultiMesh
var _bank := -1
var _time := 0.0


func _ready() -> void:
	pos.resize(max_gems)
	vel.resize(max_gems)
	value.resize(max_gems)
	tier.resize(max_gems)
	phase.resize(max_gems)
	pulled.resize(max_gems)
	_buf.resize(max_gems * STRIDE)

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
	_mm.instance_count = max_gems
	_mm.visible_instance_count = 0
	_mm.custom_aabb = AABB(Vector3(-10000, -10, -10000), Vector3(20000, 50, 20000))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func drop(at: Vector2, xp: float) -> void:
	if xp <= 0.0:
		return
	if count >= max_gems:
		if _bank < 0:
			_bank = randi() % count
		value[_bank] += xp
		tier[_bank] = _tier_of(value[_bank])
		return
	var i := count
	count += 1
	pos[i] = at
	vel[i] = Vector2.ZERO
	value[i] = xp
	tier[i] = _tier_of(xp)
	phase[i] = randf() * hframes
	pulled[i] = 0


## Pull every gem toward the player regardless of distance (vacuum pickup).
func attract_all() -> void:
	for i in count:
		pulled[i] = 1


## Moves gems, collects those touching `target`; returns collected XP.
func tick(dt: float, target: Vector2, magnet: float) -> float:
	_time += dt
	var collected := 0.0
	var m2 := magnet * magnet
	var c2 := collect_radius * collect_radius
	var i := 0
	while i < count:
		var d := target - pos[i]
		var l2 := d.length_squared()
		if pulled[i] == 0:
			if l2 >= m2:
				i += 1
				continue
			pulled[i] = 1
			if l2 > 0.0001:
				vel[i] = -d * (pop_speed / sqrt(l2))
		if l2 <= c2:
			collected += value[i]
			_remove_at(i)
			continue
		var dist := sqrt(l2)
		var v := (vel[i] + d * (pull_accel * dt / dist)).limit_length(max_pull_speed)
		if v.dot(d) > 0.0 and v.length() * dt >= dist:
			collected += value[i]
			_remove_at(i)
			continue
		vel[i] = v
		pos[i] += v * dt
		i += 1
	return collected


func clear() -> void:
	count = 0
	_bank = -1


func _tier_of(xp: float) -> float:
	var t := 0
	for k in tier_min_value.size():
		if xp >= tier_min_value[k]:
			t = k
	return float(t)


func _remove_at(i: int) -> void:
	var last := count - 1
	if _bank == i:
		_bank = -1
	elif _bank == last:
		_bank = i
	if i != last:
		pos[i] = pos[last]
		vel[i] = vel[last]
		value[i] = value[last]
		tier[i] = tier[last]
		phase[i] = phase[last]
		pulled[i] = pulled[last]
	count = last


func upload() -> void:
	var s := CELL_WORLD * gem_scale
	for i in count:
		var o := i * STRIDE
		var p := pos[i]
		var ph := phase[i]
		_buf[o] = s
		_buf[o + 3] = p.x
		_buf[o + 5] = s
		_buf[o + 7] = 0.08 + 0.06 * sin(_time * 4.0 + ph * 1.7)
		_buf[o + 10] = s
		_buf[o + 11] = p.y
		_buf[o + 12] = ph
		_buf[o + 13] = 1.0
		_buf[o + 14] = 0.0
		_buf[o + 15] = tier[i]
	RenderingServer.multimesh_set_buffer(_mm.get_rid(), _buf)
	_mm.visible_instance_count = count
