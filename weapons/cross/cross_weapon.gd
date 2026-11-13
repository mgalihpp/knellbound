extends Weapon
## Pilgrim's Cross: a spinning silver cross that ricochets from enemy to enemy
## (pierce = number of bounces) and rebounds off the screen edges until its
## duration() runs out.
## Radiant Crucifix (evolution): `endless` ricochets, and each volley also
## bursts `burst_count` small crosses outward in a ring.

@export var sprite_row := 2
@export var sprite_scale := 1.0
@export var spin_speed := 12.0
@export var target_range := 10.0
## Ricochet until duration() ends instead of spending pierce() + 1 hits.
@export var endless := false
@export var burst_count := 0
@export var burst_damage_scale := 0.5
@export var burst_scale := 0.6
@export var burst_speed := 9.0
@export var burst_life := 0.9
@export var burst_pierce := 2

var _timer := 0.5
var _shot := ProjectileField.Shot.new()


func tick(dt: float, game: Game) -> void:
	_timer -= dt
	if _timer > 0.0:
		return
	_timer += cooldown()
	var origin := game.player.pos2
	var target := game.swarm.nearest(origin, target_range)
	var aim := game.player.aim
	if target >= 0:
		aim = (game.swarm.pos[target] - origin).normalized()
	var n := amount()
	var s := _shot
	s.life = duration()
	s.damage = damage()
	s.radius = area()
	s.hits = -1 if endless else pierce() + 1
	s.knockback = knockback()
	s.size = ProjectileField.CELL_WORLD * sprite_scale * area_scale()
	s.row = sprite_row
	s.glow = 1.3
	s.flags = ProjectileField.BOUNCE_ENEMY | ProjectileField.BOUNCE_SCREEN
	s.source = self
	for k in n:
		# First cross at the target, the rest fanned evenly around the player.
		var dir := aim.rotated(TAU * k / n)
		s.pos = origin + dir * 0.4
		s.vel = dir * projectile_speed()
		s.angle = randf() * TAU
		s.spin = spin_speed if k % 2 == 0 else -spin_speed
		game.projectiles.spawn(s)
	if burst_count > 0:
		_burst(origin, aim, game)


func _burst(origin: Vector2, aim: Vector2, game: Game) -> void:
	var s := _shot
	s.life = burst_life
	s.damage = damage() * burst_damage_scale
	s.radius = area() * burst_scale
	s.hits = burst_pierce + 1
	s.size = ProjectileField.CELL_WORLD * sprite_scale * burst_scale * area_scale()
	s.flags = 0
	var speed := burst_speed * projectile_speed() / data.projectile_speed
	for k in burst_count:
		var dir := aim.rotated(TAU * (k + 0.5) / burst_count)
		s.pos = origin + dir * 0.4
		s.vel = dir * speed
		s.angle = randf() * TAU
		s.spin = spin_speed * 1.5
		game.projectiles.spawn(s)
