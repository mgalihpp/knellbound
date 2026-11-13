class_name WaveEntry
extends Resource
## One stream of continuous spawns, active from `start_minute` to `end_minute`.
## Several entries may overlap; each keeps its own spawn accumulator.

@export var start_minute := 0.0
@export var end_minute := 1.0
@export var enemies: Array[EnemyData] = []
## Relative pick weight per enemy (same order). Empty = equal weights.
@export var weights: PackedFloat32Array = []
## Spawns per second at start_minute, ramping linearly to `rate_end`.
@export var rate_start := 2.0
@export var rate_end := 4.0
## This entry stops spawning while EnemySwarm.count is at or above this.
@export var max_alive := 300
## Multiplies WaveTable's time-based HP growth.
@export var hp_mult := 1.0
@export var cluster_min := 3
@export var cluster_max := 6


func is_active(minute: float) -> bool:
	return minute >= start_minute and minute < end_minute


func rate_at(minute: float) -> float:
	var t := inverse_lerp(start_minute, end_minute, minute)
	return lerpf(rate_start, rate_end, clampf(t, 0.0, 1.0))


func pick() -> EnemyData:
	if weights.size() != enemies.size():
		return enemies.pick_random()
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	for k in enemies.size():
		r -= weights[k]
		if r <= 0.0:
			return enemies[k]
	return enemies[-1]
