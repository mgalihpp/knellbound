class_name EvolutionData
extends Resource
## Recipe: `base` at its max level + `passive` at `passive_level` or higher
## turns into `result` when a chest is opened. The evolved weapon takes the
## base weapon's slot. Listed in UpgradePool.evolutions.

@export var base: WeaponData
@export var passive: PassiveData
@export var passive_level := 1
@export var result: WeaponData


func is_ready(player: Player) -> bool:
	var w := player.weapon_for(base)
	return w != null and w.level >= base.max_level \
		and player.passives.get(passive, 0) >= passive_level \
		and player.weapon_for(result) == null
