class_name Leveling
extends RefCounted
## Player level and XP. Overflow carries into the next level, so one big gem
## can grant several levels; add() returns how many.

var level := 1
var xp := 0.0
var xp_to_next := xp_required(1)


## XP needed to go from `lv` to `lv + 1`: +10 per level until 20,
## +13 until 40, +16 after that.
static func xp_required(lv: int) -> float:
	if lv < 20:
		return 5.0 + 10.0 * (lv - 1)
	if lv < 40:
		return 195.0 + 13.0 * (lv - 20)
	return 455.0 + 16.0 * (lv - 40)


func add(amount: float) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		gained += 1
		xp_to_next = xp_required(level)
	return gained


func progress() -> float:
	return xp / xp_to_next
