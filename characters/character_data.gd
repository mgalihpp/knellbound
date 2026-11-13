class_name CharacterData
extends Resource
## A playable hunter: look, starting weapon, base stats and how it unlocks.
## Listed in data/meta.tres (MetaCatalog); SaveData keeps which are unlocked.

## How a locked hunter is earned (int in .tres: append, never reorder).
enum Unlock {
	FREE,             ## unlocked from the start
	SURVIVE_SECONDS,  ## best single-run time >= unlock_value seconds
	TOTAL_KILLS,      ## lifetime kills >= unlock_value
	NIGHTS_SURVIVED,  ## runs that reached the final minute >= unlock_value
	BUY,              ## bought on the select screen for unlock_value coins
}

@export var id: StringName
@export var display_name := ""
## One line under the name ("Wandering hunter").
@export var epithet := ""
@export_multiline var description := ""
## 4-frame walk cycle, 18x18 cells, facing right.
@export var sprite_sheet: Texture2D
@export var max_hp := 100.0
@export var move_speed := 5.0
@export var starting_weapon: WeaponData
## Character-specific bonuses on top of Stats.DEFAULT_BASE.
@export var stat_modifiers: Array[StatModifier] = []

@export_group("Unlock")
@export var unlock := Unlock.FREE
@export var unlock_value := 0


## "Survive 10:00 in one run", "Buy for 750 coins" ("" when free).
func unlock_text() -> String:
	match unlock:
		Unlock.SURVIVE_SECONDS:
			return "Survive %d:%02d in a single night." % [unlock_value / 60, unlock_value % 60]
		Unlock.TOTAL_KILLS:
			return "Slay %d creatures in total." % unlock_value
		Unlock.NIGHTS_SURVIVED:
			return "Outlast the night %d time%s." % [unlock_value, "" if unlock_value == 1 else "s"]
		Unlock.BUY:
			return "Recruit for %d coins." % unlock_value
	return ""
