extends Weapon
## Silverthorn Knives: a quick burst of silver knives thrown straight at the
## nearest enemy (or the way the player faces), with a small spread.
## pierce = extra enemies each knife passes through.
## Thornstorm (evolution): every throw is a fan of `fan` knives.

@export var sprite_row := 0
@export var sprite_scale := 1.0
@export var burst_interval := 0.07
@export var spread_degrees := 7.0
@export var target_range := 9.0
## Knives per throw, spread `fan_degrees` apart around the aim.
@export var fan := 1
@export var fan_degrees := 14.0

var _timer := 0.0
var _left := 0
var _burst_t := 0.0
var _aim := Vector2.RIGHT
var _shot := ProjectileField.Shot.new()


func tick(dt: float, game: Game) -> void:
	_timer -= dt
	if _timer <= 0.0:
		_timer += cooldown()
		_left = amount()
		_burst_t = 0.0
		var target := game.swarm.nearest(game.player.pos2, target_range)
		if target >= 0:
			_aim = (game.swarm.pos[target] - game.player.pos2).normalized()
		else:
			_aim = game.player.aim
	if _left <= 0:
		return
	_burst_t -= dt
	while _left > 0 and _burst_t <= 0.0:
		_burst_t += burst_interval
		_left -= 1
		_throw(game)


func _throw(game: Game) -> void:
	var s := _shot
	var aim := _aim.rotated(deg_to_rad(randf_range(-spread_degrees, spread_degrees)))
	s.life = duration()
	s.damage = damage()
	s.radius = area()
	s.hits = pierce() + 1
	s.knockback = knockback()
	s.size = ProjectileField.CELL_WORLD * sprite_scale * area_scale()
	s.row = sprite_row
	s.glow = 1.15
	s.flags = ProjectileField.FACE_VELOCITY
	s.source = self
	var speed := projectile_speed()
	for f in fan:
		var dir := aim.rotated(deg_to_rad((f - (fan - 1) * 0.5) * fan_degrees))
		s.pos = game.player.pos2 + dir * 0.4
		s.vel = dir * speed
		game.projectiles.spawn(s)
