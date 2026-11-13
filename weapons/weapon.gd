class_name Weapon
extends Node3D
## Base class for weapon behaviours. Weapons are children of Player/Weapons,
## so they follow the player. Game calls tick() once per frame in a fixed order.
## Subclasses read their numbers only through the helpers below, which combine
## WeaponData base stats, the WeaponLevel deltas up to `level`, and Stats.

var data: WeaponData
var stats: Stats
## Whether the last roll_damage() was a critical hit (read right after it).
var last_crit := false
## Damage this weapon (and the weapon it evolved from) has dealt this run,
## added by EnemySwarm.damage_enemy() when the hit passes `source`.
var damage_dealt := 0.0
var level := 1:
	set(v):
		level = clampi(v, 1, data.max_level)
		_sum_levels()

# Sum of data.levels[0 .. level-2].
var _damage := 0.0
var _area := 0.0
var _cooldown := 0.0
var _amount := 0
var _speed := 0.0
var _duration := 0.0
var _pierce := 0


func tick(_dt: float, _game: Game) -> void:
	pass


func damage() -> float:
	return (data.damage + _damage) * stats.value(Stats.Id.MIGHT)


func area() -> float:
	return data.area * (1.0 + _area) * stats.value(Stats.Id.AREA)


## area() relative to the base area: scale for sprites and secondary radii.
func area_scale() -> float:
	return area() / data.area


func cooldown() -> float:
	return data.cooldown * maxf(0.2, 1.0 + _cooldown) * stats.value(Stats.Id.COOLDOWN)


func amount() -> int:
	return data.amount + _amount + stats.int_value(Stats.Id.AMOUNT)


func projectile_speed() -> float:
	return data.projectile_speed * (1.0 + _speed) * stats.value(Stats.Id.PROJECTILE_SPEED)


func duration() -> float:
	return data.duration * (1.0 + _duration) * stats.value(Stats.Id.DURATION)


func pierce() -> int:
	return data.pierce + _pierce


func knockback() -> float:
	return data.knockback


## `base` is usually damage(), computed once per volley.
## Sets `last_crit`, which callers pass on to EnemySwarm.damage_enemy().
func roll_damage(base: float) -> float:
	last_crit = randf() < stats.value(Stats.Id.CRIT_CHANCE)
	if last_crit:
		return base * stats.value(Stats.Id.CRIT_DAMAGE)
	return base


func _sum_levels() -> void:
	_damage = 0.0
	_area = 0.0
	_cooldown = 0.0
	_amount = 0
	_speed = 0.0
	_duration = 0.0
	_pierce = 0
	for k in level - 1:
		var l := data.levels[k]
		_damage += l.damage
		_area += l.area
		_cooldown += l.cooldown
		_amount += l.amount
		_speed += l.projectile_speed
		_duration += l.duration
		_pierce += l.pierce
