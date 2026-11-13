class_name WeaponData
extends Resource
## Static definition of a weapon. Behaviour lives in `scene` (a Weapon
## subclass); numbers live here so new weapons are mostly new .tres files.
## Level 1 uses the base stats; `levels` holds what each level 2..max adds.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
## Scene whose root script extends Weapon.
@export var scene: PackedScene
## Evolved weapons only come from chests (EvolutionData) and are never offered
## on level up; the HUD frames them in gold.
@export var is_evolution := false

@export_group("Base stats")
@export var damage := 5.0
@export var cooldown := 1.0
## Radius / size in world units (meaning depends on the weapon).
@export var area := 1.0
@export var knockback := 1.0
@export var amount := 1
## World units / second (orbiting weapons: radians / second).
@export var projectile_speed := 10.0
## Seconds (projectile lifetime, zone lifetime, orbit active time).
@export var duration := 1.0
## Extra enemies a projectile can hit before it is spent (bounces for ricochets).
@export var pierce := 0
## Seconds before the same projectile / zone can hit the same enemy again.
@export var hit_interval := 0.5

@export_group("Levels")
## levels[0] = level 2 ... levels[n-1] = level n + 1.
@export var levels: Array[WeaponLevel] = []

var max_level: int:
	get:
		return levels.size() + 1


## Text for the card offering `next_level` (2..max_level).
func level_up_text(next_level: int) -> String:
	var k := next_level - 2
	if k < 0 or k >= levels.size():
		return description
	return levels[k].text()
