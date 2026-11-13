extends Weapon
## Hallowed Vial: lobs vials of holy water at random enemies on screen. Each
## vial shatters into a pool (radius area(), lasting duration()) that damages
## every enemy inside it every data.hit_interval.
##
## Font of Saints (evolution): each vial splashes into `splash_count` pools
## that creep toward the player at `drift_speed`.
##
## The vial in flight is a NO_HIT | ARC projectile in the ProjectileField; the
## pools are packed arrays drawn by this weapon's own MultiMesh (top_level, so
## they stay on the ground while the player moves).

const STRIDE := 16
const DECAL_SHADER := preload("res://shaders/ground_decal.gdshader")
const MAX_POOLS := 96

@export var sprite_row := 3
@export var flight_time := 0.55
@export var target_range := 9.0
@export var pool_sheet: Texture2D
## Pool texture: circle diameter / texture width (art has a transparent border).
@export var pool_fill := 46.0 / 48.0
@export var splash_time := 0.12
@export var fade_time := 0.35
@export var splash_count := 1
## Extra pools land this far (times area()) from the first one.
@export var splash_spread := 1.1
## World units / second toward the player; 0 = pools stay put.
@export var drift_speed := 0.0

var _timer := 0.3
var _shot := ProjectileField.Shot.new()
# Vials in flight: landing spot + seconds left.
var _land_pos := PackedVector2Array()
var _land_t := PackedFloat32Array()
# Pools.
var _count := 0
var _pos := PackedVector2Array()
var _life := PackedFloat32Array()
var _life0 := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _tick_t := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _buf := PackedFloat32Array()
var _mm: MultiMesh


func _ready() -> void:
	_pos.resize(MAX_POOLS)
	_life.resize(MAX_POOLS)
	_life0.resize(MAX_POOLS)
	_radius.resize(MAX_POOLS)
	_tick_t.resize(MAX_POOLS)
	_phase.resize(MAX_POOLS)
	_buf.resize(MAX_POOLS * STRIDE)

	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = DECAL_SHADER
	mat.set_shader_parameter("sheet", pool_sheet)
	plane.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = plane
	_mm.instance_count = MAX_POOLS
	_mm.visible_instance_count = 0
	_mm.custom_aabb = AABB(Vector3(-10000, -10, -10000), Vector3(20000, 50, 20000))
	var mmi := MultiMeshInstance3D.new()
	mmi.top_level = true
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func tick(dt: float, game: Game) -> void:
	_timer -= dt
	if _timer <= 0.0:
		_timer += cooldown()
		_throw(game)

	var k := 0
	while k < _land_t.size():
		_land_t[k] -= dt
		if _land_t[k] <= 0.0:
			_splash(_land_pos[k])
			_land_pos.remove_at(k)
			_land_t.remove_at(k)
		else:
			k += 1

	_tick_pools(dt, game.swarm, game.player.pos2)
	_upload()


func _throw(game: Game) -> void:
	var origin := game.player.pos2
	var near := game.swarm.query_circle(origin, target_range)
	var s := _shot
	s.life = flight_time
	s.hits = 0
	s.size = ProjectileField.CELL_WORLD
	s.row = sprite_row
	s.glow = 1.1
	s.flags = ProjectileField.NO_HIT | ProjectileField.ARC
	s.source = self
	for n in amount():
		var target: Vector2
		if near.is_empty():
			target = origin + Vector2.from_angle(randf() * TAU) * randf_range(2.0, 6.0)
		else:
			target = game.swarm.pos[near[randi() % near.size()]]
		s.pos = origin
		s.vel = (target - origin) / flight_time
		s.angle = randf() * TAU
		s.spin = randf_range(-9.0, 9.0)
		game.projectiles.spawn(s)
		_land_pos.append(target)
		_land_t.append(flight_time)


func _splash(at: Vector2) -> void:
	_add_pool(at)
	var spread := area() * splash_spread
	var a0 := randf() * TAU
	for c in splash_count - 1:
		_add_pool(at + Vector2.from_angle(a0 + TAU * c / (splash_count - 1)) * spread)


func _add_pool(at: Vector2) -> void:
	var i := _count
	if i >= MAX_POOLS:
		i = randi() % MAX_POOLS
	else:
		_count += 1
	_pos[i] = at
	_life[i] = duration()
	_life0[i] = _life[i]
	_radius[i] = area()
	_tick_t[i] = 0.0
	_phase[i] = randf() * 4.0


func _tick_pools(dt: float, swarm: EnemySwarm, player_pos: Vector2) -> void:
	var dmg := damage()
	var drift := drift_speed * dt
	var i := 0
	while i < _count:
		_life[i] -= dt
		if _life[i] <= 0.0:
			_remove_at(i)
			continue
		if drift > 0.0:
			_pos[i] = _pos[i].move_toward(player_pos, drift)
		_tick_t[i] -= dt
		if _tick_t[i] <= 0.0:
			_tick_t[i] += data.hit_interval
			for j in swarm.query_circle(_pos[i], _radius[i]):
				swarm.damage_enemy(j, roll_damage(dmg), Vector2.ZERO, last_crit, self)
		i += 1


func _remove_at(i: int) -> void:
	var last := _count - 1
	_pos[i] = _pos[last]
	_life[i] = _life[last]
	_life0[i] = _life0[last]
	_radius[i] = _radius[last]
	_tick_t[i] = _tick_t[last]
	_phase[i] = _phase[last]
	_count = last


func _upload() -> void:
	for i in _count:
		var o := i * STRIDE
		var age := _life0[i] - _life[i]
		var grow := minf(1.0, age / splash_time)
		var s := _radius[i] * 2.0 / pool_fill * (0.6 + 0.4 * grow)
		var p := _pos[i]
		_buf[o] = s
		_buf[o + 3] = p.x
		_buf[o + 5] = 1.0
		_buf[o + 7] = 0.025 + 0.001 * i  # avoid z-fighting between overlapping pools
		_buf[o + 10] = s
		_buf[o + 11] = p.y
		_buf[o + 12] = _phase[i]
		_buf[o + 13] = minf(1.0, _life[i] / fade_time)
		_buf[o + 14] = 1.0 + 0.6 * (1.0 - grow)
		_buf[o + 15] = 0.0
	RenderingServer.multimesh_set_buffer(_mm.get_rid(), _buf)
	_mm.visible_instance_count = _count
