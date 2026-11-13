class_name PassiveData
extends Resource
## A passive relic: every level applies `modifiers` once more.
## Evolution requirements live in EvolutionData (data/evolutions/).

@export var id: StringName
@export var display_name := ""
## Flavour + effect, shown on the card that offers the relic for the first time.
## Keep it to one line: level-up cards have a fixed height.
@export_multiline var description := ""
@export var icon: Texture2D
@export var max_level := 5
@export var modifiers: Array[StatModifier] = []


## Text for the card offering `next_level`: level 1 = description, later
## levels = what one level adds and the total it reaches.
func level_up_text(next_level: int) -> String:
	if next_level <= 1:
		return description
	var parts: PackedStringArray = []
	for m in modifiers:
		parts.append("%s (total %s)" % [m.describe(1), m.describe(next_level, false)])
	return ", ".join(parts)
