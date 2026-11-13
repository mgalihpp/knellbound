extends Weapon
## Damages every enemy inside a circle around the player on a fixed tick,
## pushing them outward. Seraph's Halo (evolution) reuses this script with a
## gold tint and heals the player on every pulse that hits something.

## HP restored per pulse that hits at least one enemy.
@export var heal_per_pulse := 0.0

var _timer := 0.0
var _pulse := 0.0
var _shown_area := -1.0

@onready var visual: MeshInstance3D = $Visual
@onready var _mat: ShaderMaterial = visual.material_override


func tick(dt: float, game: Game) -> void:
	var r := area()
	if r != _shown_area:
		_shown_area = r
		visual.scale = Vector3(r, 1.0, r)
		_mat.set_shader_parameter("pixel_steps", r * 2.0 * 16.0)

	_pulse = maxf(0.0, _pulse - dt * 4.0)
	_timer -= dt
	if _timer <= 0.0:
		_timer += cooldown()
		var origin := game.player.pos2
		var swarm := game.swarm
		var hits := swarm.query_circle(origin, r)
		var dmg := damage()
		for i in hits:
			var dir := (swarm.pos[i] - origin).normalized()
			swarm.damage_enemy(i, roll_damage(dmg), dir * data.knockback, last_crit, self)
		if not hits.is_empty():
			_pulse = 1.0
			if heal_per_pulse > 0.0:
				game.player.heal(heal_per_pulse)
	_mat.set_shader_parameter("pulse", _pulse)
