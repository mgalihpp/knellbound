class_name EnemySwarm
extends Node3D
## Every enemy lives here as one slot in a set of parallel packed arrays.
## Slots 0..count-1 are alive; removal is swap-with-last.
##
## Movement per slot follows EnemyData.Behavior (CHASE, WEAVE, RANGED, DRIFT,
## SCRIPTED), branched inside the one tick loop. Behaviour parameters live in
## per-type arrays (`_t_*`, indexed by type_idx) so the loop never reads a
## Resource. RANGED enemies fire through EnemyShotField; SCRIPTED ones move by
## `dir` (a velocity written each frame by BossBrain).
##
## Rendering: small sprites (18 px sheet) and large sprites (34 px sheet) are
## two MultiMeshes, each with a blob-shadow MultiMesh sharing its buffer.
## Per-instance buffer layout (16 floats, MultiMesh TRANSFORM_3D + custom):
##   [0..11]  3x4 transform rows: size,0,0,x | 0,size,0,0 | 0,0,size,z
##   [12..15] INSTANCE_CUSTOM: anim phase, facing * (1 + tint), flash, sheet row
## |custom.y| - 1 = elite tint 0..1 (glowing outline, see sprite_billboard).
##
## Breakable props (BreakableData) are PROP slots with behavior STATIC: they
## share every hit path with enemies but never move, are never pushed and
## never touch the player. Each hit reports to `numbers` (damage numbers).

## `flags` = this enemy's ELITE / BOSS bits (SILENT removals never emit).
signal enemy_died(position: Vector2, data: EnemyData, flags: int)

## Per-enemy flag bits (`flags` array).
const ELITE := 1
const BOSS := 2
const SILENT := 4  ## removed without enemy_died (drift timeout)
const LARGE := 8   ## drawn from the large sheet
const PROP := 16   ## breakable prop (no contact, not separated, not a kill)

const STRIDE := 16
const CELL_WORLD := 18.0 / 16.0  # sprite cell px / pixels per unit
const LARGE_CELL_WORLD := 34.0 / 16.0
const WEAVE := EnemyData.Behavior.WEAVE
const RANGED := EnemyData.Behavior.RANGED
const DRIFT := EnemyData.Behavior.DRIFT
const SPRITE_SHADER := preload("res://shaders/sprite_billboard.gdshader")
const SHADOW_SHADER := preload("res://shaders/blob_shadow.gdshader")

@export var capacity := 4000
@export var sheet: Texture2D
@export var hframes := 4
@export var vframes := 11
@export var large_capacity := 64
@export var large_sheet: Texture2D
@export var large_vframes := 4
@export var anim_fps := 8.0
## Vertical stretch compensating the camera pitch (≈ 1 / cos(pitch)).
@export var y_stretch := 1.55
@export var grid_cell_size := 1.2
## Separation runs on 1/N of the enemies each frame (staggered).
@export_range(1, 4) var separation_stride := 2
@export var max_neighbors_checked := 12
## Chasing enemies farther than this get relocated in front of the player.
@export var relocate_distance := 34.0
@export var relocate_radius := 20.0
## Knockback velocity decays by exp(-knock_decay * dt); stacked hits are capped.
@export var knock_decay := 9.0
@export var max_knock := 9.0

## Floating damage numbers (set by Game). Every damage_enemy() reports to it.
var numbers: DamageNumberField
## A crit landed on a boss since Game last cleared it (hit-stop trigger).
var boss_crit := false

var types: Array[EnemyData] = []
var count := 0
var large_count := 0
var pos := PackedVector2Array()
var knock := PackedVector2Array()
## Hits since Game last read it (one hit sound per frame).
var hits_this_frame := 0
var hp := PackedFloat32Array()
var speed := PackedFloat32Array()
var radius := PackedFloat32Array()
var damage := PackedFloat32Array()
var size := PackedFloat32Array()
var kb_resist := PackedFloat32Array()
var flash := PackedFloat32Array()
var facing := PackedFloat32Array()
var phase := PackedFloat32Array()
var row := PackedFloat32Array()
var type_idx := PackedInt32Array()
var behavior := PackedInt32Array()
var flags := PackedInt32Array()
## DRIFT: unit direction. SCRIPTED: velocity (world units/s).
var dir := PackedVector2Array()
## WEAVE: wobble clock. RANGED: seconds to next shot. DRIFT: seconds left.
var timer := PackedFloat32Array()
## Stable id per spawned enemy (slots move on removal; ids do not).
var uid := PackedInt32Array()

var _t_weave_amt := PackedFloat32Array()
var _t_weave_freq := PackedFloat32Array()
var _t_range := PackedFloat32Array()
var _t_interval := PackedFloat32Array()
var _grid: SpatialHash
var _stamp := PackedInt32Array()
var _query_id := 0
var _dead := PackedInt32Array()
var _buf := PackedFloat32Array()
var _large_buf := PackedFloat32Array()
var _sep_offset := 0
var _max_radius := 0.5
var _next_uid := 0
var _mm: MultiMesh
var _shadow_mm: MultiMesh
var _large_mm: MultiMesh
var _large_shadow_mm: MultiMesh


func _ready() -> void:
	_grid = SpatialHash.new(grid_cell_size)
	# Packed arrays are copy-on-write values: resize each member directly.
	pos.resize(capacity)
	knock.resize(capacity)
	hp.resize(capacity)
	speed.resize(capacity)
	radius.resize(capacity)
	damage.resize(capacity)
	size.resize(capacity)
	kb_resist.resize(capacity)
	flash.resize(capacity)
	facing.resize(capacity)
	phase.resize(capacity)
	row.resize(capacity)
	type_idx.resize(capacity)
	behavior.resize(capacity)
	flags.resize(capacity)
	dir.resize(capacity)
	timer.resize(capacity)
	uid.resize(capacity)
	_stamp.resize(capacity)
	_buf.resize(capacity * STRIDE)
	_large_buf.resize(large_capacity * STRIDE)

	var blob := PlaneMesh.new()
	blob.size = Vector2(0.8, 0.45)
	blob.center_offset = Vector3(0.0, 0.015, 0.0)
	var smat := ShaderMaterial.new()
	smat.shader = SHADOW_SHADER
	blob.material = smat

	_mm = _make_multimesh(_sprite_quad(sheet, vframes), capacity)
	_shadow_mm = _make_multimesh(blob, capacity)
	_large_mm = _make_multimesh(_sprite_quad(large_sheet, large_vframes), large_capacity)
	_large_shadow_mm = _make_multimesh(blob, large_capacity)


func _sprite_quad(tex: Texture2D, rows: int) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	mat.set_shader_parameter("sheet", tex)
	mat.set_shader_parameter("hframes", hframes)
	mat.set_shader_parameter("vframes", rows)
	mat.set_shader_parameter("fps", anim_fps)
	mat.set_shader_parameter("y_stretch", y_stretch)
	quad.material = mat
	return quad


func _make_multimesh(mesh: Mesh, n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	# Fixed huge AABB: skips per-frame AABB recompute and frustum-cull surprises.
	mm.custom_aabb = AABB(Vector3(-10000, -10, -10000), Vector3(20000, 50, 20000))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


func _type_index(data: EnemyData) -> int:
	var t := types.find(data)
	if t == -1:
		types.append(data)
		t = types.size() - 1
		_max_radius = maxf(_max_radius, data.radius)
		_t_weave_amt.append(data.weave_amount)
		_t_weave_freq.append(data.weave_frequency * TAU)
		_t_range.append(data.preferred_range)
		_t_interval.append(data.fire_interval)
	return t


## `extra_flags`: ELITE / BOSS. `direction`: DRIFT heading (unit) or initial
## SCRIPTED velocity. `life`: DRIFT seconds (0 = data.drift_life).
## `scale_mult` grows the sprite and (by its square root) the collision radius.
## Returns the slot, or -1 when full.
func spawn(data: EnemyData, at: Vector2, hp_mult: float = 1.0, extra_flags: int = 0,
		direction: Vector2 = Vector2.ZERO, life: float = 0.0, scale_mult: float = 1.0) -> int:
	var large := data.large_sprite
	if count >= capacity or (large and large_count >= large_capacity):
		return -1
	var i := count
	count += 1
	var t := _type_index(data)
	var r := data.radius * sqrt(scale_mult)
	_max_radius = maxf(_max_radius, r)
	type_idx[i] = t
	pos[i] = at
	knock[i] = Vector2.ZERO
	hp[i] = data.max_hp * hp_mult
	speed[i] = data.move_speed * randf_range(0.9, 1.1)
	radius[i] = r
	damage[i] = data.contact_damage
	size[i] = (LARGE_CELL_WORLD if large else CELL_WORLD) * data.scale * scale_mult
	kb_resist[i] = data.knockback_resist
	flash[i] = 0.0
	facing[i] = 1.0
	phase[i] = randf() * hframes
	row[i] = data.sprite_row
	behavior[i] = data.behavior
	dir[i] = direction
	var f := extra_flags
	if large:
		f |= LARGE
		large_count += 1
	if f & ELITE:
		kb_resist[i] = maxf(kb_resist[i], 0.85)
		damage[i] *= 1.5
	flags[i] = f
	match data.behavior:
		RANGED:
			timer[i] = randf() * data.fire_interval
		DRIFT:
			timer[i] = life if life > 0.0 else data.drift_life
		_:
			timer[i] = randf() * 10.0
	_next_uid += 1
	uid[i] = _next_uid
	return i


## Slot of the enemy with this uid, or -1 if it is gone. A live uid is unique
## within 0..count-1; stale copies only exist past `count`.
func slot_of(id: int) -> int:
	var i := uid.find(id)
	return i if i >= 0 and i < count else -1


## Move every enemy by its behaviour, rebuild the grid, then separate.
## RANGED enemies in range fire into `shots`.
func tick(dt: float, target: Vector2, shots: EnemyShotField) -> void:
	var decay := exp(-knock_decay * dt)
	var far2 := relocate_distance * relocate_distance
	var flash_drop := dt * 8.0
	for i in count:
		var p := pos[i]
		var d := target - p
		var l2 := d.length_squared()
		var b := behavior[i]
		var v := Vector2.ZERO
		if b <= RANGED:  # CHASE, WEAVE, RANGED: steer at the player
			if l2 > far2:
				# Left behind: wrap around to the side the player is heading to.
				pos[i] = target + d.normalized() * relocate_radius
				continue
			if l2 > 0.0001:
				var inv := 1.0 / sqrt(l2)
				v = d * (speed[i] * inv)
				if b == WEAVE:
					var t := type_idx[i]
					var w := timer[i] + dt
					timer[i] = w
					v += Vector2(-v.y, v.x) * (_t_weave_amt[t] * sin(w * _t_weave_freq[t]))
				elif b == RANGED:
					v = _ranged(i, dt, p, d, l2 * inv, v, shots)
			if d.x > 0.05:
				facing[i] = 1.0
			elif d.x < -0.05:
				facing[i] = -1.0
		else:  # DRIFT, SCRIPTED: move along `dir` (STATIC: dir stays zero)
			if b == DRIFT:
				v = dir[i] * speed[i]
				timer[i] -= dt
				if timer[i] <= 0.0 and hp[i] > 0.0:
					hp[i] = 0.0
					flags[i] |= SILENT
					_dead.append(i)
			else:
				v = dir[i]
			if v.x > 0.05:
				facing[i] = 1.0
			elif v.x < -0.05:
				facing[i] = -1.0
		var k := knock[i]
		pos[i] = p + (v + k) * dt
		knock[i] = k * decay
		if flash[i] > 0.0:
			flash[i] = maxf(0.0, flash[i] - flash_drop)
	_grid.build(pos, count)
	_separate()


## Keep `preferred_range` (approach / back off / strafe) and fire when the
## cooldown is up and the player is within reach. `chase_v` = full-speed
## velocity toward the player, `dist` = distance to it.
func _ranged(i: int, dt: float, p: Vector2, d: Vector2, dist: float, chase_v: Vector2,
		shots: EnemyShotField) -> Vector2:
	var t := type_idx[i]
	var want := _t_range[t]
	var v: Vector2
	if dist > want + 0.75:
		v = chase_v
	elif dist < want - 1.5:
		v = chase_v * -0.6
	else:
		# Strafe around the player; direction per enemy from uid parity.
		v = Vector2(-chase_v.y, chase_v.x) * (0.35 if uid[i] & 1 else -0.35)
	var cd := timer[i] - dt
	if cd <= 0.0:
		if dist < want + 4.0:
			var data := types[t]
			shots.fire(p, d * (data.shot_speed / dist), data.shot_damage, data.shot_row,
				data.shot_size, (want + 6.0) / data.shot_speed)
			flash[i] = 0.6
		cd += _t_interval[t]
	timer[i] = cd
	return v


func _separate() -> void:
	_sep_offset = (_sep_offset + 1) % separation_stride
	var starts := _grid.cell_start
	var items := _grid.items
	var inv := _grid.inv_cell
	var cap := max_neighbors_checked
	var px := SpatialHash.PRIME_X
	var py := SpatialHash.PRIME_Y
	var mask := SpatialHash.MASK
	for i in range(_sep_offset, count, separation_stride):
		if flags[i] & PROP:
			continue  # props are pushed by nothing; enemies slide around them
		var p := pos[i]
		var ri := radius[i]
		var fx := p.x * inv
		var fy := p.y * inv
		var cx := int(floorf(fx))
		var cy := int(floorf(fy))
		# Only the 2x2 block of cells nearest to p: with cell >= 2 * radius,
		# every overlapping neighbour is inside it.
		var nx := cx + (1 if fx - cx >= 0.5 else -1)
		var ny := cy + (1 if fy - cy >= 0.5 else -1)
		var push := Vector2.ZERO
		var checked := 0
		for q in 4:
			var h := (((nx if q & 1 else cx) * px) ^ ((ny if q & 2 else cy) * py)) & mask
			for s in range(starts[h], starts[h + 1]):
				var j := items[s]
				if j == i:
					continue
				var dd := p - pos[j]
				var r := ri + radius[j]
				var d2 := dd.length_squared()
				if d2 < r * r:
					if d2 > 0.000001:
						# Weighted by the other's share of the overlap: big enemies
						# shove small ones aside and barely move (equal sizes: 1).
						var dist := sqrt(d2)
						push += dd * ((r - dist) / dist * 2.0 * radius[j] / r)
					else:
						push.x += randf() - 0.5
				checked += 1
				if checked >= cap:
					break
			if checked >= cap:
				break
		if push != Vector2.ZERO:
			pos[i] = p + (push * 0.5).limit_length(0.3)


## Alive enemies whose collision circle overlaps the circle (center, r).
func query_circle(center: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	if count == 0:
		return out
	_query_id += 1
	var qid := _query_id
	var inv := _grid.inv_cell
	var reach := r + _max_radius
	var x0 := int(floorf((center.x - reach) * inv))
	var x1 := int(floorf((center.x + reach) * inv))
	var y0 := int(floorf((center.y - reach) * inv))
	var y1 := int(floorf((center.y + reach) * inv))
	var starts := _grid.cell_start
	var items := _grid.items
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var h := ((cx * SpatialHash.PRIME_X) ^ (cy * SpatialHash.PRIME_Y)) & SpatialHash.MASK
			for s in range(starts[h], starts[h + 1]):
				var j := items[s]
				if j >= count or _stamp[j] == qid:
					continue
				_stamp[j] = qid
				if hp[j] <= 0.0:
					continue
				var rr := r + radius[j]
				if pos[j].distance_squared_to(center) <= rr * rr:
					out.append(j)
	return out


## Closest alive enemy within `max_r` of `center`, or -1.
func nearest(center: Vector2, max_r: float) -> int:
	var best := -1
	var best_d2 := INF
	for j in query_circle(center, max_r):
		var d2 := pos[j].distance_squared_to(center)
		if d2 < best_d2:
			best_d2 = d2
			best = j
	return best


## The one damage path for enemies and props: hit flash, knockback, damage
## number, and the damage tally of `source` (overkill not counted).
## Returns true if this hit killed it (removed in flush_dead()).
func damage_enemy(i: int, amount: float, knockback: Vector2 = Vector2.ZERO,
		crit: bool = false, source: Weapon = null) -> bool:
	if hp[i] <= 0.0:
		return false
	hits_this_frame += 1
	if source != null:
		source.damage_dealt += minf(amount, hp[i])
	hp[i] -= amount
	var f := flags[i]
	# Bosses take hits constantly: a light flash keeps their art readable.
	flash[i] = maxf(flash[i], 0.3) if f & BOSS else 1.0
	if knockback != Vector2.ZERO:
		knock[i] = (knock[i] + knockback * (1.0 - kb_resist[i])).limit_length(max_knock)
	if numbers != null:
		numbers.add(pos[i], amount, DamageNumberField.CRIT if crit else DamageNumberField.NORMAL)
	if crit and f & BOSS:
		boss_crit = true
	if hp[i] <= 0.0:
		_dead.append(i)
		return true
	return false


## Push touching enemies out of the player's circle; returns the highest
## contact damage among them (0 if none).
func collide_player(center: Vector2, r: float) -> float:
	var hits := query_circle(center, r)
	var dmg := 0.0
	for j in hits:
		if flags[j] & PROP:
			continue
		dmg = maxf(dmg, damage[j])
		var dd := pos[j] - center
		var dist := dd.length()
		if dist > 0.0001:
			pos[j] = center + dd * ((r + radius[j]) / dist)
	return dmg


func flush_dead() -> void:
	if _dead.is_empty():
		return
	_dead.sort()
	for k in range(_dead.size() - 1, -1, -1):
		var i := _dead[k]
		var f := flags[i]
		if not f & SILENT:
			enemy_died.emit(pos[i], types[type_idx[i]], f)
		_remove_at(i)
	_dead.clear()


## Removes slot i at the next flush_dead() without enemy_died (no drop).
func despawn(i: int) -> void:
	if hp[i] > 0.0:
		hp[i] = 0.0
		flags[i] |= SILENT
		_dead.append(i)


## Removes every enemy, without drops.
func clear() -> void:
	count = 0
	large_count = 0
	_dead.clear()


func _remove_at(i: int) -> void:
	if flags[i] & LARGE:
		large_count -= 1
	var last := count - 1
	if i != last:
		pos[i] = pos[last]
		knock[i] = knock[last]
		hp[i] = hp[last]
		speed[i] = speed[last]
		radius[i] = radius[last]
		damage[i] = damage[last]
		size[i] = size[last]
		kb_resist[i] = kb_resist[last]
		flash[i] = flash[last]
		facing[i] = facing[last]
		phase[i] = phase[last]
		row[i] = row[last]
		type_idx[i] = type_idx[last]
		behavior[i] = behavior[last]
		flags[i] = flags[last]
		dir[i] = dir[last]
		timer[i] = timer[last]
		uid[i] = uid[last]
	count = last


## Write instance data and send it to the GPU (one call per MultiMesh).
func upload() -> void:
	var n := 0
	var nl := 0
	for i in count:
		var f := flags[i]
		var s := size[i]
		var p := pos[i]
		var fy := facing[i] * (2.0 if f & ELITE else 1.0)
		if f & LARGE:
			# Writes duplicated per buffer: a local alias of a packed array copies it.
			var o := nl * STRIDE
			nl += 1
			_large_buf[o] = s
			_large_buf[o + 3] = p.x
			_large_buf[o + 5] = s
			_large_buf[o + 10] = s
			_large_buf[o + 11] = p.y
			_large_buf[o + 12] = phase[i]
			_large_buf[o + 13] = fy
			_large_buf[o + 14] = flash[i]
			_large_buf[o + 15] = row[i]
		else:
			var o := n * STRIDE
			n += 1
			_buf[o] = s
			_buf[o + 3] = p.x
			_buf[o + 5] = s
			_buf[o + 10] = s
			_buf[o + 11] = p.y
			_buf[o + 12] = phase[i]
			_buf[o + 13] = fy
			_buf[o + 14] = flash[i]
			_buf[o + 15] = row[i]
	RenderingServer.multimesh_set_buffer(_mm.get_rid(), _buf)
	RenderingServer.multimesh_set_buffer(_shadow_mm.get_rid(), _buf)
	_mm.visible_instance_count = n
	_shadow_mm.visible_instance_count = n
	if nl > 0 or _large_mm.visible_instance_count > 0:
		RenderingServer.multimesh_set_buffer(_large_mm.get_rid(), _large_buf)
		RenderingServer.multimesh_set_buffer(_large_shadow_mm.get_rid(), _large_buf)
	_large_mm.visible_instance_count = nl
	_large_shadow_mm.visible_instance_count = nl
