class_name EnemyShotField
extends Node3D
## Enemy projectiles (acolyte orbs, boss rings): parallel packed arrays + one
## MultiMesh, same 16-float buffer and shaders/projectile.gdshader as
## ProjectileField. Kept separate from ProjectileField because the rules are
## different: no weapon source, no hit memory, the only target is the player
## (a plain circle test per shot, no spatial hash needed).
##
## INSTANCE_CUSTOM: x = anim phase, y = screen angle, z = brightness, w = sheet
## row (art/sprites/enemy_shots.png, row = EnemyData.shot_row).

const STRIDE := 16
const SHADER := preload("res://shaders/projectile.gdshader")

@export var capacity := 1024
@export var sheet: Texture2D
@export var hframes := 4
@export var vframes := 3
@export var anim_fps := 10.0
@export var y_stretch := 1.55
@export var height := 0.7
@export var pitch_degrees := 50.0
## Brightness > 1 feeds the glow pass so shots read against the swarm.
@export var glow := 1.7
## Shots spin (rad/s) when their row does not face its velocity.
@export var spin_rows: PackedInt32Array = [1]
@export var spin_speed := 12.0

var count := 0
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat32Array()
var damage := PackedFloat32Array()
var radius := PackedFloat32Array()
var size := PackedFloat32Array()
var row := PackedFloat32Array()
var phase := PackedFloat32Array()
var angle := PackedFloat32Array()
var spin := PackedFloat32Array()

var _screen_k := 0.766
var _buf := PackedFloat32Array()
var _mm: MultiMesh


func _ready() -> void:
	_screen_k = sin(deg_to_rad(pitch_degrees))
	pos.resize(capacity)
	vel.resize(capacity)
	life.resize(capacity)
	damage.resize(capacity)
	radius.resize(capacity)
	size.resize(capacity)
	row.resize(capacity)
	phase.resize(capacity)
	angle.resize(capacity)
	spin.resize(capacity)
	_buf.resize(capacity * STRIDE)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
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


## `sprite_size` in world units (1.0 = one 18 px cell).
func fire(at: Vector2, velocity: Vector2, dmg: float, sheet_row: int,
		sprite_size: float = 0.8, seconds: float = 4.0) -> void:
	if count >= capacity:
		return
	var i := count
	count += 1
	pos[i] = at
	vel[i] = velocity
	life[i] = seconds
	damage[i] = dmg
	radius[i] = sprite_size * 0.3
	size[i] = sprite_size * (18.0 / 16.0)
	row[i] = sheet_row
	phase[i] = randf() * hframes
	if spin_rows.has(sheet_row):
		spin[i] = spin_speed
		angle[i] = randf() * TAU
	else:
		spin[i] = 0.0
		angle[i] = atan2(-velocity.y * _screen_k, velocity.x)


## Moves every shot; shots touching the circle (center, r) are removed.
## Returns the highest damage among them (0 = no hit).
func tick(dt: float, center: Vector2, r: float) -> float:
	var hit := 0.0
	var i := 0
	while i < count:
		life[i] -= dt
		var p := pos[i] + vel[i] * dt
		pos[i] = p
		angle[i] += spin[i] * dt
		var rr := r + radius[i]
		if p.distance_squared_to(center) <= rr * rr:
			hit = maxf(hit, damage[i])
			life[i] = 0.0
		if life[i] <= 0.0:
			_remove_at(i)
			continue
		i += 1
	return hit


func clear() -> void:
	count = 0


func _remove_at(i: int) -> void:
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		vel[i] = vel[last]
		life[i] = life[last]
		damage[i] = damage[last]
		radius[i] = radius[last]
		size[i] = size[last]
		row[i] = row[last]
		phase[i] = phase[last]
		angle[i] = angle[last]
		spin[i] = spin[last]
	count = last


func upload() -> void:
	var h := height
	var g := glow
	for i in count:
		var o := i * STRIDE
		var s := size[i]
		var p := pos[i]
		_buf[o] = s
		_buf[o + 3] = p.x
		_buf[o + 5] = s
		_buf[o + 7] = h
		_buf[o + 10] = s
		_buf[o + 11] = p.y
		_buf[o + 12] = phase[i]
		_buf[o + 13] = angle[i]
		_buf[o + 14] = g
		_buf[o + 15] = row[i]
	RenderingServer.multimesh_set_buffer(_mm.get_rid(), _buf)
	_mm.visible_instance_count = count
