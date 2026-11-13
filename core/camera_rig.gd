class_name CameraRig
extends Node3D
## Rig origin follows the player on the ground; the child camera sits on a
## pitched arm. Switch projection with `use_orthographic`.

@export_range(20.0, 80.0) var pitch_degrees := 50.0
@export var distance := 30.0
@export var use_orthographic := true
@export var ortho_size := 13.0
@export_range(10.0, 60.0) var perspective_fov := 28.0
@export var follow_sharpness := 12.0
@export var max_shake_offset := 0.35

## Off = add_shake() does nothing (Options > Screen shake; set by Game).
var shake_enabled := true

var _trauma := 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	apply_settings()


func apply_settings() -> void:
	var p := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(p) * distance, cos(p) * distance)
	camera.rotation = Vector3(-p, 0.0, 0.0)
	camera.far = distance * 4.0
	if use_orthographic:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = ortho_size
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = perspective_fov


func snap_to(target: Vector3) -> void:
	global_position = target


func tick(dt: float, target: Vector3) -> void:
	global_position = global_position.lerp(target, 1.0 - exp(-follow_sharpness * dt))
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - dt * 2.5)
		var s := _trauma * _trauma * max_shake_offset
		camera.h_offset = randf_range(-s, s)
		camera.v_offset = randf_range(-s, s)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Ground rect (x, z) visible around the rig, for the orthographic camera.
func ground_view_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var half := Vector2(ortho_size * 0.5 * vp.x / vp.y,
		ortho_size * 0.5 / sin(deg_to_rad(pitch_degrees)))
	return Rect2(Vector2(global_position.x, global_position.z) - half, half * 2.0)


## amount in 0..1; trauma is squared so small hits stay subtle.
func add_shake(amount: float) -> void:
	if not shake_enabled:
		return
	_trauma = minf(1.0, _trauma + amount)
