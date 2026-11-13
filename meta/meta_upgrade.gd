class_name MetaUpgrade
extends Resource
## One Reliquary (permanent shop) upgrade. Bought levels are saved by `id` in
## SaveData; at run start `modifiers` are applied once per bought level to the
## player's Stats (SaveData.apply_upgrades).

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
## Applied `level` times.
@export var modifiers: Array[StatModifier] = []
@export_range(1, 10) var max_level := 5
## Price of the first level.
@export var base_cost := 100
## Each further level costs this much times the previous one.
@export var cost_growth := 1.5


## Price of going from `level` to `level + 1`, rounded to 5 coins.
func cost(level: int) -> int:
	return maxi(5, roundi(base_cost * pow(cost_growth, level) / 5.0) * 5)


## Everything spent on the first `level` levels (what a refund gives back).
func spent(level: int) -> int:
	var total := 0
	for l in level:
		total += cost(l)
	return total


## "+10% damage" for `level` bought levels ("" at level 0).
func effect_text(level: int) -> String:
	if level <= 0:
		return ""
	var parts: PackedStringArray = []
	for m in modifiers:
		parts.append(m.describe(level))
	return ", ".join(parts)
