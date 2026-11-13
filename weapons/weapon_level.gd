class_name WeaponLevel
extends Resource
## What one weapon level adds on top of the previous ones. WeaponData.levels[0]
## is level 2, levels[1] level 3, ... Deltas stack: Weapon sums every entry up
## to its current level.
##
## damage / amount / pierce are flat; the rest are fractions of the base value
## (0.1 = +10%, cooldown -0.1 = 10% faster).

## Shown on the level-up card. Empty = generated from the numbers.
@export var description := ""
@export var damage := 0.0
@export var area := 0.0
@export var cooldown := 0.0
@export var amount := 0
@export var projectile_speed := 0.0
@export var duration := 0.0
@export var pierce := 0


func text() -> String:
	if description != "":
		return description
	var parts: PackedStringArray = []
	if damage != 0.0:
		parts.append("%+d damage" % roundi(damage))
	if area != 0.0:
		parts.append("%+d%% area" % roundi(area * 100.0))
	if cooldown != 0.0:
		parts.append("%+d%% cooldown" % roundi(cooldown * 100.0))
	if amount != 0:
		parts.append("%+d amount" % amount)
	if projectile_speed != 0.0:
		parts.append("%+d%% speed" % roundi(projectile_speed * 100.0))
	if duration != 0.0:
		parts.append("%+d%% duration" % roundi(duration * 100.0))
	if pierce != 0:
		parts.append("%+d pierce" % pierce)
	return ", ".join(parts)
