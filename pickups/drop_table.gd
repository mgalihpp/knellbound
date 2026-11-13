class_name DropTable
extends Resource
## Weighted pickup roll (data/drops/*.tres): `chance` (x LUCK) that anything
## drops, then one of `items` by PickupData.drop_weight (x LUCK for
## luck_weighted items).

@export_range(0.0, 1.0, 0.0001) var chance := 0.01
@export var items: Array[PickupData] = []


## A pickup to drop, or null.
func roll(luck: float) -> PickupData:
	if items.is_empty() or randf() >= chance * luck:
		return null
	var total := 0.0
	for it in items:
		total += _weight(it, luck)
	var r := randf() * total
	for it in items:
		r -= _weight(it, luck)
		if r < 0.0:
			return it
	return items[-1]


static func _weight(it: PickupData, luck: float) -> float:
	return it.drop_weight * (luck if it.luck_weighted else 1.0)
