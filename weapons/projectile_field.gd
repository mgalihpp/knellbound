class_name ProjectileField
extends Node3D
## Every projectile (thrown knives, orbiting beads, ricocheting crosses, lobbed
## vials) is one slot in parallel packed arrays, drawn by one MultiMesh with
## one buffer upload per frame. Removal is swap-with-last.
##
## Weapons fill a reusable `Shot` and call spawn(); tick() moves everything,
## hits enemies through EnemySwarm.query_circle and drops spent projectiles.
## Each projectile remembers the uids of the last HIT_MEMORY enemies it hit so
## piercing shots don't hit the same enemy every frame; with `rehit` > 0 the
## memory is wiped on that interval (orbiting weapons hit again on each pass).
##
## Buffer layout: same 16 floats as EnemySwarm; INSTANCE_CUSTOM = anim phase,
## screen angle, brightness, sheet row (see shaders/projectile.gdshader).

## Motion / behaviour flags.
const ORBIT := 1          ## circles `center` (radius = orbit_r, vel = (angle, rad/s))
const FACE_VELOCITY := 2  ## sprite points along its travel direction
const BOUNCE_ENEMY := 4   ## after a hit, retarget the nearest unhit enemy
const BOUNCE_SCREEN := 8  ## reflect off the edges of `view_rect`
const NO_HIT := 16        ## visual only (e.g. a vial in flight)
const ARC := 32           ## parabolic height over its lifetime

const STRIDE := 16
const CELL_WORLD := 18.0 / 16.0
const HIT_MEMORY := 4
const SHADER := preload("res://shaders/projectile.gdshader")


## Spawn parameters; weapons keep one and refill it (no per-shot allocation).
class Shot:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var orbit_r := 0.0
	var life := 1.0
	var damage := 1.0
	var radius := 0.3
	## Enemies it may hit; -1 = unlimited. For BOUNCE_ENEMY each hit is a bounce.
	var hits := 1
	var knockback := 0.0
	var rehit := 0.0
	var size := 1.0
	var row := 0
	var spin := 0.0
	var angle := 0.0
	var glow := 1.0
	var flags := 0
	var source: Weapon


@export var capacity := 2048
@export var sheet: Texture2D
@export var hframes := 4
@export var vframes := 4
@export var anim_fps := 10.0
@export var y_stretch := 1.55
## Height above the ground of every projectile.
@export var height := 0.6
@export var arc_height := 2.2
## Must match CameraRig.pitch_degrees: turns ground directions into screen angles.
@export var pitch_degrees := 50.0
@export var bounce_search_radius := 7.0

## World rect on screen, set by Game each frame (for BOUNCE_SCREEN).
var view_rect := Rect2(-20, -12, 40, 24)
var count := 0
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var orbit_r := PackedFloat32Array()
var life := PackedFloat32Array()
var life0 := PackedFloat32Array()
var damage := PackedFloat32Array()
var radius := PackedFloat32Array()
var hits := PackedInt32Array()
var knock := PackedFloat32Array()
var rehit := PackedFloat32Array()
var rehit_t := PackedFloat32Array()
var size := PackedFloat32Array()
var row := PackedFloat32Array()
var phase := PackedFloat32Array()
var spin := PackedFloat32Array()
var angle := PackedFloat32Array()
var glow := PackedFloat32Array()
var flags := PackedInt32Array()
var source: Array[Weapon] = []
var memory := PackedInt32Array()  # capacity * HIT_MEMORY enemy uids, 0 = empty
var mem_head := PackedInt32Array()

var _screen_k := 0.766
var _buf := PackedFloat32Array()
var _mm: MultiMesh


func _ready() -> void:
	_screen_k = sin(deg_to_rad(pitch_degrees))
	pos.resize(capacity)
	vel.resize(capacity)
	orbit_r.resize(capacity)
	life.resize(capacity)
	life0.resize(capacity)
	damage.resize(capacity)
	radius.resize(capacity)
	hits.resize(capacity)
	knock.resize(capacity)
	rehit.resize(capacity)
	rehit_t.resize(capacity)
	size.resize(capacity)
	row.resize(capacity)
	phase.resize(capacity)
	spin.resize(capacity)
	angle.resize(capacity)
	glow.resize(capacity)
	flags.resize(capacity)
	source.resize(capacity)
	memory.resize(capacity * HIT_MEMORY)
	mem_head.resize(capacity)
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


func spawn(s: Shot) -> int:
	if count >= capacity:
		return -1
	var i := count
	count += 1
	pos[i] = s.pos
	vel[i] = s.vel
	orbit_r[i] = s.orbit_r
	life[i] = s.life
	life0[i] = s.life
	damage[i] = s.damage
	radius[i] = s.radius
	hits[i] = s.hits
	knock[i] = s.knockback
	rehit[i] = s.rehit
	rehit_t[i] = s.rehit
	size[i] = s.size
	row[i] = s.row
	phase[i] = randf() * hframes
	spin[i] = s.spin
	angle[i] = s.angle
	glow[i] = s.glow
	flags[i] = s.flags
	source[i] = s.source
	mem_head[i] = 0
	var m := i * HIT_MEMORY
	for k in HIT_MEMORY:
		memory[m + k] = 0
	if s.flags & FACE_VELOCITY:
		angle[i] = _screen_angle(s.vel)
	return i


## Move, hit, expire. `center` is the orbit centre (the player).
func tick(dt: float, swarm: EnemySwarm, center: Vector2) -> void:
	var i := 0
	while i < count:
		life[i] -= dt
		if life[i] <= 0.0:
			_remove_at(i)
			continue
		var f := flags[i]
		var p: Vector2
		if f & ORBIT:
			var v := vel[i]
			v.x += v.y * dt
			vel[i] = v
			p = center + Vector2(cos(v.x), sin(v.x)) * orbit_r[i]
		else:
			p = pos[i] + vel[i] * dt
			if f & BOUNCE_SCREEN:
				p = _bounce_screen(i, p)
		pos[i] = p
		if f & FACE_VELOCITY:
			angle[i] = _screen_angle(vel[i])
		else:
			angle[i] += spin[i] * dt

		if f & NO_HIT:
			i += 1
			continue
		if rehit[i] > 0.0:
			rehit_t[i] -= dt
			if rehit_t[i] <= 0.0:
				rehit_t[i] += rehit[i]
				var m := i * HIT_MEMORY
				for k in HIT_MEMORY:
					memory[m + k] = 0
		if _hit_enemies(i, swarm, center):
			_remove_at(i)
			continue
		i += 1


## Returns true when the projectile is spent.
func _hit_enemies(i: int, swarm: EnemySwarm, center: Vector2) -> bool:
	var p := pos[i]
	var f := flags[i]
	for j in swarm.query_circle(p, radius[i]):
		var u := swarm.uid[j]
		if _remembers(i, u):
			continue
		_remember(i, u)
		var dir: Vector2
		if f & ORBIT:
			dir = (swarm.pos[j] - center).normalized()
		else:
			dir = vel[i].normalized()
		var src := source[i]
		swarm.damage_enemy(j, src.roll_damage(damage[i]), dir * knock[i], src.last_crit, src)
		if hits[i] > 0:
			hits[i] -= 1
			if hits[i] == 0:
				return true
		if f & BOUNCE_ENEMY:
			_retarget(i, swarm)
			return false
	return false


func _retarget(i: int, swarm: EnemySwarm) -> void:
	var p := pos[i]
	var best := -1
	var best_d2 := INF
	for j in swarm.query_circle(p, bounce_search_radius):
		if _remembers(i, swarm.uid[j]):
			continue
		var d2 := swarm.pos[j].distance_squared_to(p)
		if d2 < best_d2:
			best_d2 = d2
			best = j
	if best >= 0:
		vel[i] = (swarm.pos[best] - p).normalized() * vel[i].length()


func _bounce_screen(i: int, p: Vector2) -> Vector2:
	var v := vel[i]
	var r := view_rect
	if (p.x < r.position.x and v.x < 0.0) or (p.x > r.end.x and v.x > 0.0):
		v.x = -v.x
	if (p.y < r.position.y and v.y < 0.0) or (p.y > r.end.y and v.y > 0.0):
		v.y = -v.y
	vel[i] = v
	return p


func _remembers(i: int, u: int) -> bool:
	var m := i * HIT_MEMORY
	for k in HIT_MEMORY:
		if memory[m + k] == u:
			return true
	return false


func _remember(i: int, u: int) -> void:
	var h := mem_head[i]
	memory[i * HIT_MEMORY + h] = u
	mem_head[i] = (h + 1) % HIT_MEMORY


## Screen-space angle of a ground direction (x right, z toward the camera).
func _screen_angle(v: Vector2) -> float:
	return atan2(-v.y * _screen_k, v.x)


func clear() -> void:
	count = 0


## Live projectiles of `old` now belong to `new` (weapon evolved, old is freed).
func replace_source(old: Weapon, new: Weapon) -> void:
	for i in count:
		if source[i] == old:
			source[i] = new


func _remove_at(i: int) -> void:
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		vel[i] = vel[last]
		orbit_r[i] = orbit_r[last]
		life[i] = life[last]
		life0[i] = life0[last]
		damage[i] = damage[last]
		radius[i] = radius[last]
		hits[i] = hits[last]
		knock[i] = knock[last]
		rehit[i] = rehit[last]
		rehit_t[i] = rehit_t[last]
		size[i] = size[last]
		row[i] = row[last]
		phase[i] = phase[last]
		spin[i] = spin[last]
		angle[i] = angle[last]
		glow[i] = glow[last]
		flags[i] = flags[last]
		source[i] = source[last]
		mem_head[i] = mem_head[last]
		var m := i * HIT_MEMORY
		var ml := last * HIT_MEMORY
		for k in HIT_MEMORY:
			memory[m + k] = memory[ml + k]
	source[last] = null
	count = last


func upload() -> void:
	var h := height
	for i in count:
		var o := i * STRIDE
		var s := size[i]
		var p := pos[i]
		var y := h
		if flags[i] & ARC:
			var t := 1.0 - life[i] / life0[i]
			y += 4.0 * arc_height * t * (1.0 - t)
		_buf[o] = s
		_buf[o + 3] = p.x
		_buf[o + 5] = s
		_buf[o + 7] = y
		_buf[o + 10] = s
		_buf[o + 11] = p.y
		_buf[o + 12] = phase[i]
		_buf[o + 13] = angle[i]
		_buf[o + 14] = glow[i]
		_buf[o + 15] = row[i]
	RenderingServer.multimesh_set_buffer(_mm.get_rid(), _buf)
	_mm.visible_instance_count = count
