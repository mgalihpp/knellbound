class_name SpawnDirector
extends Node
## Data-driven spawning from a WaveTable (data/waves/*.tres):
##  - every active WaveEntry spawns clusters on a ring just outside the camera
##    at its own rate (own accumulator), while EnemySwarm.count < its max_alive;
##  - WaveEvents fire once when the clock passes their minute (rings, lines,
##    bursts, elites, bosses); bosses get a BossBrain, ticked here;
##  - at final_minute every enemy and enemy shot is removed and the table's
##    reaper comes, then another every reaper_interval. No other spawns after.
##
## Game.elapsed is the clock. skip_to() jumps it (debug) without replaying the
## events in between, so the event at the target minute still fires.

@export var table: WaveTable
@export var spawn_radius := 20.0
## Camera shake when a boss arrives.
@export var boss_shake := 0.55

var bosses: Array[BossBrain] = []
var final_phase := false
var _acc := PackedFloat32Array()
var _next_event := 0
var _reaper_t := 0.0
var _minute := 0.0


func _ready() -> void:
	_acc.resize(table.entries.size())


func hp_scale() -> float:
	return table.hp_scale(_minute)


func tick(dt: float, game: Game) -> void:
	_minute = game.elapsed / 60.0
	var i := 0
	while i < bosses.size():
		if bosses[i].tick(dt, game):
			i += 1
		else:
			bosses.remove_at(i)

	if final_phase:
		_reaper_t -= dt
		if _reaper_t <= 0.0:
			_reaper_t += table.reaper_interval
			_spawn_reaper(game)
		return
	if _minute >= table.final_minute:
		_begin_final(game)
		return

	while _next_event < table.events.size() and table.events[_next_event].minute <= _minute:
		_fire_event(table.events[_next_event], game)
		_next_event += 1

	var hp_base := hp_scale()
	for k in table.entries.size():
		var e := table.entries[k]
		if not e.is_active(_minute) or e.enemies.is_empty():
			continue
		_acc[k] += e.rate_at(_minute) * dt
		while _acc[k] >= 1.0:
			if game.swarm.count >= e.max_alive:
				_acc[k] = 0.0
				break
			var n := randi_range(e.cluster_min, e.cluster_max)
			_acc[k] -= n
			spawn_cluster(game, e.pick(), n, randf() * TAU, hp_base * e.hp_mult)


## Debug: jump the clock to `seconds`. Events before it are skipped.
func skip_to(game: Game, seconds: float) -> void:
	game.elapsed = maxf(game.elapsed, seconds)
	_minute = game.elapsed / 60.0
	while _next_event < table.events.size() and table.events[_next_event].minute < _minute:
		_next_event += 1


## The boss whose bar the HUD shows (oldest alive), or null.
func active_boss() -> BossBrain:
	return bosses[0] if not bosses.is_empty() else null


func spawn_cluster(game: Game, data: EnemyData, n: int, angle: float, hp_mult: float = 1.0) -> void:
	var center := game.player.pos2 + Vector2.from_angle(angle) * spawn_radius
	for k in n:
		var jitter := Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		game.swarm.spawn(data, center + jitter, hp_mult)


## Debug/stress: spawn `n` enemies evenly on the ring, from every entry active now.
func spawn_ring(game: Game, n: int) -> void:
	var pool: Array[EnemyData] = []
	for e in table.entries:
		if e.is_active(_minute):
			pool.append_array(e.enemies)
	if pool.is_empty():
		pool.append_array(table.entries[0].enemies)
	for k in n:
		var a := TAU * k / n
		var r := spawn_radius + randf() * 6.0
		game.swarm.spawn(pool.pick_random(), game.player.pos2 + Vector2.from_angle(a) * r, hp_scale())


func _fire_event(ev: WaveEvent, game: Game) -> void:
	var center := game.player.pos2
	var hp_mult := hp_scale() * ev.hp_mult
	match ev.kind:
		WaveEvent.Kind.RING:
			# Every member heads for the player's position at spawn time: the
			# circle tightens, crosses in the middle, then the survivors expire.
			var life := ev.enemy.drift_life
			if life <= 0.0:
				life = 2.0 * ev.radius / ev.enemy.move_speed
			for k in ev.count:
				var a := TAU * k / ev.count
				var off := Vector2.from_angle(a) * ev.radius
				game.swarm.spawn(ev.enemy, center + off, hp_mult, 0, -off / ev.radius, life)
		WaveEvent.Kind.LINE:
			# A column perpendicular to the heading, entering from off screen.
			var heading := Vector2.from_angle(randf() * TAU)
			var side := Vector2(-heading.y, heading.x)
			var start := center - heading * ev.radius
			var life := ev.enemy.drift_life
			if life <= 0.0:
				life = 2.0 * ev.radius / ev.enemy.move_speed
			var spacing := 1.1
			for k in ev.count:
				var lateral := (k - (ev.count - 1) * 0.5) * spacing
				var stagger := heading * randf_range(-0.4, 0.4)
				game.swarm.spawn(ev.enemy, start + side * lateral + stagger, hp_mult, 0, heading, life)
		WaveEvent.Kind.BURST:
			var a := randf() * TAU
			for k in ev.count:
				var spread := a + randf_range(-0.35, 0.35)
				var r := ev.radius + randf_range(0.0, 3.0)
				game.swarm.spawn(ev.enemy, center + Vector2.from_angle(spread) * r, hp_mult)
		WaveEvent.Kind.ELITE:
			for k in ev.count:
				var at := center + Vector2.from_angle(randf() * TAU) * spawn_radius
				game.swarm.spawn(ev.enemy, at, hp_mult * table.elite_hp_mult, EnemySwarm.ELITE,
					Vector2.ZERO, 0.0, table.elite_scale)
		WaveEvent.Kind.BOSS:
			spawn_boss(game, ev.enemy as BossData, hp_mult)


func spawn_boss(game: Game, data: BossData, hp_mult: float) -> void:
	if data == null:
		push_error("WaveEvent BOSS needs a BossData")
		return
	var at := game.player.pos2 + Vector2.from_angle(randf() * TAU) * (spawn_radius * 0.75)
	var i := game.swarm.spawn(data, at, hp_mult, EnemySwarm.BOSS)
	if i >= 0:
		bosses.append(BossBrain.new(data, game.swarm.uid[i], game.swarm.hp[i]))
		game.camera_rig.add_shake(boss_shake)
		Audio.play_sfx(&"boss_spawn")


## Elite of `data` near the player (debug).
func spawn_elite(game: Game, data: EnemyData) -> void:
	var at := game.player.pos2 + Vector2.from_angle(randf() * TAU) * 8.0
	game.swarm.spawn(data, at, hp_scale() * table.elite_hp_mult, EnemySwarm.ELITE,
		Vector2.ZERO, 0.0, table.elite_scale)


func _begin_final(game: Game) -> void:
	final_phase = true
	bosses.clear()
	game.swarm.clear()
	game.enemy_shots.clear()
	_reaper_t = table.reaper_interval
	_spawn_reaper(game)


func _spawn_reaper(game: Game) -> void:
	if table.reaper == null:
		return
	var at := game.player.pos2 + Vector2.from_angle(randf() * TAU) * spawn_radius
	game.swarm.spawn(table.reaper, at)
