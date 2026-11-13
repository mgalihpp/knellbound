class_name BreakableSpawner
extends Node
## Keeps a few breakable props (BreakableData) around the player: every
## `interval` seconds it drops those that fell far behind (silently) and, while
## fewer than `max_alive` remain, places one on a ring around the player,
## mostly ahead of where the player walks. Props are EnemySwarm PROP slots,
## tracked here by uid (slots move on removal; uids do not).

@export var types: Array[BreakableData] = []
@export var max_alive := 8
@export var interval := 2.5
@export var min_distance := 9.0
@export var max_distance := 15.0
@export var despawn_distance := 32.0
## Chance a new prop is placed within +-70 degrees of the walk direction.
@export_range(0.0, 1.0) var ahead_chance := 0.7

var _uids := PackedInt32Array()
var _timer := 0.5


func tick(dt: float, game: Game) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	_timer += interval
	var swarm := game.swarm
	var center := game.player.pos2
	var far2 := despawn_distance * despawn_distance
	var i := 0
	while i < _uids.size():
		var s := swarm.slot_of(_uids[i])
		if s < 0 or swarm.hp[s] <= 0.0:
			_uids.remove_at(i)
			continue
		if swarm.pos[s].distance_squared_to(center) > far2:
			swarm.despawn(s)
			_uids.remove_at(i)
			continue
		i += 1
	if game.director.final_phase or types.is_empty() or _uids.size() >= max_alive:
		return
	var angle := randf() * TAU
	if randf() < ahead_chance:
		angle = game.player.aim.angle() + randf_range(-1.2, 1.2)
	spawn(game, types.pick_random(),
		center + Vector2.from_angle(angle) * randf_range(min_distance, max_distance))


func spawn(game: Game, data: BreakableData, at: Vector2) -> void:
	var s := game.swarm.spawn(data, at, 1.0, EnemySwarm.PROP)
	if s >= 0:
		_uids.append(game.swarm.uid[s])
