class_name BossBrain
extends RefCounted
## Drives one boss: an EnemySwarm slot with behavior SCRIPTED, found each tick
## by its stable uid (slots move when other enemies die). The brain only
## writes the slot's velocity (`swarm.dir`) and flash, and fires shots /
## spawns minions; damage, death and drops go through the normal swarm path.
##
## Loop: CHASE (chase_time) -> TELEGRAPH (stand, flash) -> attack -> CHASE...
## Attacks come from BossData.pattern in order.

enum State { CHASE, TELEGRAPH, DASH, RADIAL }

var data: BossData
var uid := 0
var max_hp := 1.0
var hp := 1.0
## Last known position (read by the HUD's off-screen arrow).
var pos := Vector2.ZERO
var state := State.CHASE
var _t := 0.0
var _attack_index := 0
var _volleys_left := 0
var _dash_dir := Vector2.RIGHT


func _init(boss: BossData, boss_uid: int, full_hp: float) -> void:
	data = boss
	uid = boss_uid
	max_hp = full_hp
	hp = full_hp
	_t = boss.chase_time


## Returns false once the boss is gone (killed or cleared).
func tick(dt: float, game: Game) -> bool:
	var swarm := game.swarm
	var i := swarm.slot_of(uid)
	if i < 0 or swarm.hp[i] <= 0.0:
		hp = 0.0
		return false
	hp = swarm.hp[i]
	var p := swarm.pos[i]
	pos = p
	var to_player := game.player.pos2 - p
	_t -= dt
	match state:
		State.CHASE:
			swarm.dir[i] = to_player.normalized() * data.move_speed
			if _t <= 0.0:
				state = State.TELEGRAPH
				_t = data.telegraph_time
		State.TELEGRAPH:
			swarm.dir[i] = Vector2.ZERO
			swarm.flash[i] = 0.5 + 0.5 * sin(_t * 30.0)
			_dash_dir = to_player.normalized()
			if _t <= 0.0:
				_attack(i, game)
		State.DASH:
			swarm.dir[i] = _dash_dir * data.dash_speed
			if _t <= 0.0:
				_chase()
		State.RADIAL:
			swarm.dir[i] = Vector2.ZERO
			if _t <= 0.0:
				_fire_ring(p, game.enemy_shots, _volleys_left)
				_volleys_left -= 1
				_t = data.radial_interval
				if _volleys_left <= 0:
					_chase()
	return true


func _attack(i: int, game: Game) -> void:
	var attack: BossData.Attack = data.pattern[_attack_index % data.pattern.size()]
	_attack_index += 1
	match attack:
		BossData.Attack.DASH:
			state = State.DASH
			_t = data.dash_time
			game.camera_rig.add_shake(0.25)
		BossData.Attack.RADIAL:
			state = State.RADIAL
			_volleys_left = data.radial_volleys
			_t = 0.0
		BossData.Attack.SUMMON:
			if data.summon:
				var p := game.swarm.pos[i]
				var hp_mult := game.director.hp_scale()
				for k in data.summon_count:
					var a := TAU * k / data.summon_count
					game.swarm.spawn(data.summon, p + Vector2.from_angle(a) * data.summon_radius, hp_mult)
			_chase()


func _chase() -> void:
	state = State.CHASE
	_t = data.chase_time


## One ring of shots; odd volleys are rotated half a step so rings interleave.
func _fire_ring(p: Vector2, shots: EnemyShotField, volley: int) -> void:
	var n := data.radial_count
	var offset := (PI / n) * (volley % 2)
	for k in n:
		var dir := Vector2.from_angle(TAU * k / n + offset)
		shots.fire(p + dir * data.radius, dir * data.shot_speed, data.shot_damage,
			data.shot_row, data.shot_size, 5.0)
