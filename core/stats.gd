class_name Stats
extends RefCounted
## Player stats. Every stat is `(base + flat) * (1 + percent)`, where flat and
## percent are the sums of all active StatModifiers. Characters set the base,
## passives / power-ups only add modifiers.
##
## Ids are saved as ints inside .tres files: append new ids, never reorder.

signal changed

enum Id {
	MIGHT,             ## damage multiplier
	AREA,              ## weapon size multiplier
	COOLDOWN,          ## weapon cooldown multiplier (lower = faster)
	AMOUNT,            ## extra projectiles (flat)
	PROJECTILE_SPEED,  ## multiplier
	DURATION,          ## multiplier
	MOVE_SPEED,        ## world units / second
	MAX_HP,
	RECOVERY,          ## hp / second
	ARMOR,             ## flat damage reduction per hit
	LUCK,              ## multiplier on lucky rolls (extra level-up choice, ...)
	MAGNET,            ## gem pickup radius, world units
	CRIT_CHANCE,       ## 0..1
	CRIT_DAMAGE,       ## damage multiplier on crit
	GROWTH,            ## XP multiplier
	REROLL,            ## level-up charges per run
	SKIP,
	BANISH,
	GREED,             ## coin pickup multiplier
	REVIVAL,           ## extra lives per run
}

const DEFAULT_BASE := [
	1.0,   # MIGHT
	1.0,   # AREA
	1.0,   # COOLDOWN
	0.0,   # AMOUNT
	1.0,   # PROJECTILE_SPEED
	1.0,   # DURATION
	5.0,   # MOVE_SPEED
	100.0, # MAX_HP
	0.0,   # RECOVERY
	0.0,   # ARMOR
	1.0,   # LUCK
	1.8,   # MAGNET
	0.0,   # CRIT_CHANCE
	1.5,   # CRIT_DAMAGE
	1.0,   # GROWTH
	2.0,   # REROLL
	2.0,   # SKIP
	2.0,   # BANISH
	1.0,   # GREED
	0.0,   # REVIVAL
]
const MIN_COOLDOWN := 0.1
## Card / tooltip names, indexed by Id.
const LABELS := [
	"damage", "area", "cooldown", "projectiles", "projectile speed", "duration",
	"move speed", "max HP", "HP/s recovery", "armor", "luck", "pickup range",
	"crit chance", "crit damage", "XP gain", "rerolls", "skips", "banishes",
	"coin gain", "revivals",
]
## Stats whose flat value is a fraction, shown as a percent (0.05 -> +5%).
const FLAT_AS_PERCENT := [Id.CRIT_CHANCE, Id.CRIT_DAMAGE]

var _base := PackedFloat32Array(DEFAULT_BASE)
var _flat := PackedFloat32Array()
var _percent := PackedFloat32Array()
var _value := PackedFloat32Array()


func _init() -> void:
	var n := DEFAULT_BASE.size()
	_flat.resize(n)
	_percent.resize(n)
	_value.resize(n)
	for id in n:
		_recompute(id)


func value(id: Id) -> float:
	return _value[id]


func int_value(id: Id) -> int:
	return int(_value[id])


func set_base(id: Id, v: float) -> void:
	_base[id] = v
	_recompute(id)
	changed.emit()


## Pass `times = -1` to remove a modifier added earlier.
func add_modifier(m: StatModifier, times: int = 1) -> void:
	_flat[m.stat] += m.flat * times
	_percent[m.stat] += m.percent * times
	_recompute(m.stat)
	changed.emit()


func _recompute(id: int) -> void:
	var v := (_base[id] + _flat[id]) * (1.0 + _percent[id])
	_value[id] = maxf(v, MIN_COOLDOWN) if id == Id.COOLDOWN else maxf(v, 0.0)


## "+10% damage", "+1 projectiles", "+0.2 HP/s recovery" (no label: "+10%").
static func describe(id: int, flat: float, percent: float, with_label: bool = true) -> String:
	var label: String = (" " + LABELS[id]) if with_label else ""
	var parts: PackedStringArray = []
	if flat != 0.0:
		if FLAT_AS_PERCENT.has(id):
			parts.append("%+d%%%s" % [roundi(flat * 100.0), label])
		elif is_equal_approx(flat, roundf(flat)):
			parts.append("%+d%s" % [roundi(flat), label])
		else:
			parts.append("%+.1f%s" % [flat, label])
	if percent != 0.0:
		parts.append("%+d%%%s" % [roundi(percent * 100.0), label])
	return ", ".join(parts)
