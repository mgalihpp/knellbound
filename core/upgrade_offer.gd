class_name UpgradeOffer
extends RefCounted
## One reward: a card on the level-up screen or a row on the chest screen.
## `item` is the WeaponData / PassiveData it upgrades (the evolved WeaponData
## for EVOLUTION, null for HEAL, the fallback once everything is maxed).

enum Kind { NEW_WEAPON, WEAPON_LEVEL, NEW_PASSIVE, PASSIVE_LEVEL, HEAL, EVOLUTION }

const HEAL_FRACTION := 0.3

var kind: Kind
var item: Resource
var evolution: EvolutionData
var next_level := 1
## Levels the item can reach (1 for evolutions and heal): the card's pips.
var max_level := 1
## Item name, and the tag shown next to it ("NEW", "LV 3", "EVOLVED").
var title := ""
var badge := ""
var description := ""
var icon: Texture2D


static func for_weapon(data: WeaponData, current_level: int) -> UpgradeOffer:
	var o := UpgradeOffer.new()
	o.item = data
	o.icon = data.icon
	o.next_level = current_level + 1
	if current_level == 0:
		o.kind = Kind.NEW_WEAPON
		o.badge = "NEW"
		o.description = data.description
	else:
		o.kind = Kind.WEAPON_LEVEL
		o.badge = "LV %d" % o.next_level
		o.description = data.level_up_text(o.next_level)
	o.title = data.display_name
	o.max_level = data.max_level
	return o


static func for_passive(data: PassiveData, current_level: int) -> UpgradeOffer:
	var o := UpgradeOffer.new()
	o.item = data
	o.icon = data.icon
	o.next_level = current_level + 1
	o.kind = Kind.NEW_PASSIVE if current_level == 0 else Kind.PASSIVE_LEVEL
	o.title = data.display_name
	o.badge = "NEW" if current_level == 0 else "LV %d" % o.next_level
	o.max_level = data.max_level
	o.description = data.level_up_text(o.next_level)
	return o


static func for_evolution(evo: EvolutionData) -> UpgradeOffer:
	var o := UpgradeOffer.new()
	o.kind = Kind.EVOLUTION
	o.evolution = evo
	o.item = evo.result
	o.icon = evo.result.icon
	o.title = evo.result.display_name
	o.badge = "EVOLVED"
	o.description = "%s + %s:  %s" % [evo.base.display_name, evo.passive.display_name, evo.result.description]
	return o


static func for_heal(heal_icon: Texture2D) -> UpgradeOffer:
	var o := UpgradeOffer.new()
	o.kind = Kind.HEAL
	o.icon = heal_icon
	o.title = "Hearty Meal"
	o.description = "Restore %d%% of max HP." % roundi(HEAL_FRACTION * 100.0)
	return o


func apply(player: Player) -> void:
	match kind:
		Kind.NEW_WEAPON:
			player.add_weapon(item)
		Kind.WEAPON_LEVEL:
			player.weapon_for(item).level = next_level
		Kind.NEW_PASSIVE, Kind.PASSIVE_LEVEL:
			player.add_passive(item)
		Kind.HEAL:
			player.heal(player.max_hp * HEAL_FRACTION)
		Kind.EVOLUTION:
			player.evolve(evolution)
