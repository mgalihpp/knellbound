class_name StatModifier
extends Resource
## One additive change to a Stats entry. Passives, characters and (phase 8)
## shop power-ups are lists of these.

@export var stat: Stats.Id
@export var flat := 0.0
## 0.1 = +10%. All percents on a stat are summed before multiplying.
@export var percent := 0.0


## Card text for this modifier applied `times` times ("+20% area").
func describe(times: int = 1, with_label: bool = true) -> String:
	return Stats.describe(stat, flat * times, percent * times, with_label)
