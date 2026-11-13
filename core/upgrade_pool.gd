class_name UpgradePool
extends Resource
## Everything a run can offer. roll() builds level-up cards from the player's
## loadout (level up owned items, add new ones while slots are free), drops
## banished items and picks `count` at random. chest_reward() is one chest
## item: a ready evolution first, else a level for something already owned.

@export var weapons: Array[WeaponData] = []
@export var passives: Array[PassiveData] = []
@export var evolutions: Array[EvolutionData] = []
@export var heal_icon: Texture2D


func roll(player: Player, banished: Array[Resource], count: int) -> Array[UpgradeOffer]:
	var pool := owned_upgrades(player, banished)
	if player.weapons.size() < Player.MAX_WEAPONS:
		for data in weapons:
			if not owns_line(player, data) and not banished.has(data):
				pool.append(UpgradeOffer.for_weapon(data, 0))
	if player.passives.size() < Player.MAX_PASSIVES:
		for p in passives:
			if not player.passives.has(p) and not banished.has(p):
				pool.append(UpgradeOffer.for_passive(p, 0))

	pool.shuffle()
	pool.resize(mini(count, pool.size()))
	if pool.is_empty():
		pool.append(UpgradeOffer.for_heal(heal_icon))
	return pool


## One chest item, or null when nothing can be evolved or levelled.
## The caller applies it before asking for the next one.
func chest_reward(player: Player, banished: Array[Resource]) -> UpgradeOffer:
	var evos := evolutions.duplicate()
	evos.shuffle()
	for evo: EvolutionData in evos:
		if evo.is_ready(player):
			return UpgradeOffer.for_evolution(evo)
	var pool := owned_upgrades(player, banished)
	return null if pool.is_empty() else pool.pick_random()


## Next level of every owned weapon / passive that is not maxed or banished.
func owned_upgrades(player: Player, banished: Array[Resource]) -> Array[UpgradeOffer]:
	var pool: Array[UpgradeOffer] = []
	for w in player.weapons:
		if w.level < w.data.max_level and not banished.has(w.data):
			pool.append(UpgradeOffer.for_weapon(w.data, w.level))
	for p in player.passives:
		var lv: int = player.passives[p]
		if lv < p.max_level and not banished.has(p):
			pool.append(UpgradeOffer.for_passive(p, lv))
	return pool


## True if the player holds `data` or the weapon it evolved into.
func owns_line(player: Player, data: WeaponData) -> bool:
	if player.weapon_for(data) != null:
		return true
	for evo in evolutions:
		if evo.base == data and player.weapon_for(evo.result) != null:
			return true
	return false
