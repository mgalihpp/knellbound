extends Weapon
## Vesper Beads: blessed beads circle the player for duration(), then rest for
## cooldown(). Orbit radius = area(), angular speed = projectile_speed() (rad/s).
## Each bead can hit the same enemy again every data.hit_interval.
## Eternal Rosary (evolution): `continuous` beads never rest, and `rings` > 1
## adds inner rings (radius * inner_ring_scale^k) turning the other way.

@export var sprite_row := 1
@export var sprite_scale := 1.0
@export var hit_radius := 0.5
## Sprite brightness (> 1 blooms).
@export var glow := 1.8
@export var rings := 1
@export var inner_ring_scale := 0.55
## Never rest: the set is re-spawned every `refresh` seconds (picking up stat
## changes) at the angle the previous set had reached, so the motion is seamless.
@export var continuous := false
@export var refresh := 1.0

var _timer := 0.0
var _phase := 0.0
var _shot := ProjectileField.Shot.new()


func tick(dt: float, game: Game) -> void:
	var speed := projectile_speed()
	_phase = fmod(_phase + speed * dt, TAU)
	_timer -= dt
	if _timer > 0.0:
		return
	var active: float
	var start: float
	if continuous:
		_timer += refresh
		# a few frames of overlap so the old set never vanishes before the new one
		active = refresh + 0.05
		start = _phase
	else:
		active = duration()
		_timer += active + cooldown()
		start = randf() * TAU
	var n := amount()
	var s := _shot
	s.life = active
	s.damage = damage()
	s.radius = hit_radius * area_scale()
	s.hits = -1
	s.knockback = knockback()
	s.rehit = data.hit_interval
	s.size = ProjectileField.CELL_WORLD * sprite_scale * sqrt(area_scale())
	s.row = sprite_row
	s.glow = glow
	s.flags = ProjectileField.ORBIT
	s.source = self
	for ring in rings:
		var dir := 1.0 if ring % 2 == 0 else -1.0
		var beads := n if ring == 0 else maxi(2, ceili(n * 0.5))
		s.orbit_r = area() * pow(inner_ring_scale, ring)
		for k in beads:
			s.vel = Vector2(dir * start + TAU * k / beads, dir * speed)
			s.pos = game.player.pos2
			game.projectiles.spawn(s)
