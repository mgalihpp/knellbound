class_name DamageNumberField
extends Node3D
## Floating damage / heal numbers as parallel packed arrays + one MultiMesh.
## A number of any length is ONE instance: shaders/damage_number.gdshader
## picks the digits from the value in INSTANCE_CUSTOM, so 300 live numbers
## cost 300 instances and one buffer upload.
##
## Kept cheap under 1000+ enemies:
##  - a hit close to a recent number of the same kind is merged into it
##    (value adds up, the number pops again) instead of adding one;
##  - above `soft_cap` live numbers, NORMAL hits are dropped (crits, heals and
##    hurts still show); at `capacity` everything new is dropped.
##
## Buffer: 3x4 transform (x scale = digits * digit width, y scale = height)
## + INSTANCE_CUSTOM: value, alpha, kind, digit count.

## Kind (also the shader's colour index).
const NORMAL := 0
const CRIT := 1
const HEAL := 2
const HURT := 3

const STRIDE := 16
const SHADER := preload("res://shaders/damage_number.gdshader")
## Glyph cell (5x7 digit + 1 px outline) at 16 px per unit.
const CELL_W := 7.0 / 16.0
const CELL_H := 9.0 / 16.0
const MAX_VALUE := 9999999.0
## How many of the newest numbers a hit is checked against for merging.
const MERGE_SCAN := 8

@export var digits: Texture2D
@export var capacity := 300
@export var soft_cap := 220
@export var y_stretch := 1.55
## Overall size (1 = 16 px per unit, like sprites).
@export var number_scale := 0.75
@export var crit_scale := 1.4
@export var life := 0.6
@export var crit_life := 0.85
## Start height above the hit point, and how far a number rises.
@export var height := 1.2
@export var rise := 0.9
@export var merge_radius := 0.7
@export var merge_window := 0.15
## Seconds of the "pop" (a number starts 60% larger and settles).
@export var pop_time := 0.12

## Off = add() does nothing (Options > Damage numbers; set by Game).
var enabled := true
var count := 0
var pos := PackedVector2Array()
var value := PackedFloat32Array()
var age := PackedFloat32Array()
var life_of := PackedFloat32Array()
var kind := PackedInt32Array()
var jitter := PackedFloat32Array()

var _buf := PackedFloat32Array()
var _mm: MultiMesh


func _ready() -> void:
	pos.resize(capacity)
	value.resize(capacity)
	age.resize(capacity)
	life_of.resize(capacity)
	kind.resize(capacity)
	jitter.resize(capacity)
	_buf.resize(capacity * STRIDE)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("digits", digits)
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


func add(at: Vector2, amount: float, k: int = NORMAL) -> void:
	if amount <= 0.0 or not enabled:
		return
	var r2 := merge_radius * merge_radius
	for j in range(count - 1, maxi(0, count - MERGE_SCAN) - 1, -1):
		if kind[j] == k and age[j] < merge_window and pos[j].distance_squared_to(at) < r2:
			value[j] = minf(MAX_VALUE, value[j] + amount)
			age[j] = 0.0  # pops again
			return
	if count >= capacity or (k == NORMAL and count >= soft_cap):
		return
	var i := count
	count += 1
	pos[i] = at
	value[i] = minf(MAX_VALUE, amount)
	age[i] = 0.0
	life_of[i] = crit_life if k == CRIT else life
	kind[i] = k
	jitter[i] = randf_range(-0.35, 0.35)


func tick(dt: float) -> void:
	var i := 0
	while i < count:
		age[i] += dt
		if age[i] >= life_of[i]:
			var last := count - 1
			pos[i] = pos[last]
			value[i] = value[last]
			age[i] = age[last]
			life_of[i] = life_of[last]
			kind[i] = kind[last]
			jitter[i] = jitter[last]
			count = last
			continue
		i += 1


func clear() -> void:
	count = 0


func upload() -> void:
	for i in count:
		var o := i * STRIDE
		var v := maxf(1.0, roundf(value[i]))
		var n := 1.0
		var tens := 10.0
		while v >= tens:
			n += 1.0
			tens *= 10.0
		var t := age[i] / life_of[i]
		var k := kind[i]
		var s := number_scale * (crit_scale if k == CRIT else 1.0)
		s *= 1.0 + 0.6 * maxf(0.0, 1.0 - age[i] / pop_time)
		var up := 1.0 - (1.0 - t) * (1.0 - t)  # ease-out rise
		var p := pos[i]
		_buf[o] = CELL_W * n * s
		_buf[o + 3] = p.x + jitter[i] * t
		_buf[o + 5] = CELL_H * s
		_buf[o + 7] = height + rise * up
		_buf[o + 10] = 1.0
		_buf[o + 11] = p.y
		_buf[o + 12] = v
		_buf[o + 13] = clampf((1.0 - t) * 3.0, 0.0, 1.0)  # fades over the last third
		_buf[o + 14] = float(k)
		_buf[o + 15] = n
	RenderingServer.multimesh_set_buffer(_mm.get_rid(), _buf)
	_mm.visible_instance_count = count
