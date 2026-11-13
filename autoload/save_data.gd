extends Node
## Autoload `SaveData`: everything that outlives a run, in user://save.json.
##
## Holds permanent coins, Reliquary levels (MetaUpgrade.id -> level), unlocked
## hunters, the selected hunter, options (owned by the `Settings` autoload,
## stored here as a plain dictionary) and lifetime records. Ids are saved as
## strings, never indexes, so content can be reordered.
##
## Robustness: writes go to save.json.tmp, the old file becomes save.json.bak,
## then the tmp is renamed into place, so a crash mid-write leaves either the
## old or the new save. Loading tries save.json, then the .bak, then defaults;
## a file that does not parse is kept as save.json.corrupt and never crashes
## the game. Every field is type-checked and clamped on load.
##
## Meta rules live here too (buying, refunding, unlocking, banking a run), so
## the shop / select / summary screens stay views.

signal changed

const PATH := "user://save.json"
const VERSION := 2
## Phase 7 kept options in their own file; version 1 saves import it.
const LEGACY_SETTINGS := "user://settings.cfg"
const CATALOG: MetaCatalog = preload("res://data/meta.tres")
## Coalesces bursts of option changes (slider drags) into one write.
const SAVE_DELAY := 0.4

var coins := 0
## MetaUpgrade.id -> bought level.
var upgrade_levels: Dictionary[StringName, int] = {}
var unlocked: Array[StringName] = []
var selected: StringName = &""
## Settings' values (keys and defaults belong to the Settings autoload).
var options: Dictionary = {}
var best_time := 0.0
var total_kills := 0
var runs := 0
var nights_survived := 0
var lifetime_coins := 0
## How the last load went: "ok", "backup", "new" or "corrupt" (debug / tests).
var load_status := ""

var _save_queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _save_queued:
		save_game()


# ---------------------------------------------------------------- persistence

func load_game() -> void:
	_reset()
	var d: Variant = _read(PATH)
	load_status = "ok"
	if d == null and FileAccess.file_exists(PATH):
		push_warning("SaveData: %s is unreadable, kept as .corrupt" % PATH)
		DirAccess.copy_absolute(PATH, PATH + ".corrupt")
		load_status = "corrupt"
	if d == null:
		d = _read(PATH + ".bak")
		if d != null:
			load_status = "backup"
	if d == null:
		if load_status != "corrupt":
			load_status = "new"
		d = {}
	_from_dict(_migrate(d))
	_unlock_free()


func save_game() -> bool:
	_save_queued = false
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveData: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(_to_dict(), "\t"))
	f.close()
	if FileAccess.file_exists(PATH):
		if FileAccess.file_exists(PATH + ".bak"):
			DirAccess.remove_absolute(PATH + ".bak")
		DirAccess.rename_absolute(PATH, PATH + ".bak")
	var err := DirAccess.rename_absolute(tmp, PATH)
	if err != OK:
		push_warning("SaveData: rename failed (%s)" % error_string(err))
		return false
	return true


## Saves a moment later; many calls in a row write once.
func queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(SAVE_DELAY, true, false, true).timeout.connect(
		func() -> void:
			if _save_queued:
				save_game())


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	# Binary garbage (not a JSON object) is rejected before UTF-8 decoding,
	# which would log an error per invalid byte.
	if bytes.is_empty() or bytes[0] != 0x7B or bytes.has(0):
		return null
	var text := bytes.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	return json.data


func _reset() -> void:
	coins = 0
	upgrade_levels.clear()
	unlocked.clear()
	selected = &""
	options = {}
	best_time = 0.0
	total_kills = 0
	runs = 0
	nights_survived = 0
	lifetime_coins = 0


## Brings an older save dictionary up to VERSION, one step at a time.
func _migrate(d: Dictionary) -> Dictionary:
	var v := int(_num(d, "version", 1))
	if v < 2:
		# v1 -> v2: options moved from settings.cfg into the save.
		if not d.get("options") is Dictionary:
			d["options"] = _legacy_options()
		v = 2
	d["version"] = v
	return d


func _legacy_options() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_SETTINGS) != OK:
		return {}
	var out := {}
	for k in ["master", "sfx", "bgm"]:
		if cfg.has_section_key("audio", k):
			out["volume_" + k] = cfg.get_value("audio", k)
	for k in ["screen_shake", "damage_numbers"]:
		if cfg.has_section_key("game", k):
			out[k] = cfg.get_value("game", k)
	if cfg.has_section_key("video", "fullscreen"):
		out["fullscreen"] = cfg.get_value("video", "fullscreen")
	return out


func _to_dict() -> Dictionary:
	var levels := {}
	for id in upgrade_levels:
		if upgrade_levels[id] > 0:
			levels[String(id)] = upgrade_levels[id]
	var ids: Array[String] = []
	for id in unlocked:
		ids.append(String(id))
	return {
		"version": VERSION,
		"coins": coins,
		"upgrades": levels,
		"unlocked": ids,
		"selected": String(selected),
		"options": options,
		"records": {
			"best_time": best_time,
			"total_kills": total_kills,
			"runs": runs,
			"nights_survived": nights_survived,
			"lifetime_coins": lifetime_coins,
		},
	}


func _from_dict(d: Dictionary) -> void:
	coins = maxi(0, int(_num(d, "coins", 0)))
	var levels: Variant = d.get("upgrades")
	if levels is Dictionary:
		for key in levels:
			var u := CATALOG.upgrade(StringName(str(key)))
			if u != null and (levels[key] is float or levels[key] is int):
				upgrade_levels[u.id] = clampi(int(levels[key]), 0, u.max_level)
	var ids: Variant = d.get("unlocked")
	if ids is Array:
		for id in ids:
			var c := CATALOG.character(StringName(str(id)))
			if c != null and not unlocked.has(c.id):
				unlocked.append(c.id)
	selected = StringName(str(d.get("selected", "")))
	if d.get("options") is Dictionary:
		options = d["options"]
	var rec: Variant = d.get("records")
	if rec is Dictionary:
		best_time = maxf(0.0, _num(rec, "best_time", 0.0))
		total_kills = maxi(0, int(_num(rec, "total_kills", 0)))
		runs = maxi(0, int(_num(rec, "runs", 0)))
		nights_survived = maxi(0, int(_num(rec, "nights_survived", 0)))
		lifetime_coins = maxi(0, int(_num(rec, "lifetime_coins", 0)))


## A finite number from `d[key]`, else `fallback` (JSON numbers are floats).
static func _num(d: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = d.get(key)
	if (v is float or v is int) and is_finite(float(v)):
		return float(v)
	return fallback


func _unlock_free() -> void:
	for c in CATALOG.characters:
		if c.unlock == CharacterData.Unlock.FREE and not unlocked.has(c.id):
			unlocked.append(c.id)
	if selected_character() == null:
		selected = CATALOG.default_character.id


# ---------------------------------------------------------------- hunters

## The hunter the next run uses (always an unlocked one).
func selected_character() -> CharacterData:
	var c := CATALOG.character(selected)
	return c if c != null and is_unlocked(c) else null


func is_unlocked(c: CharacterData) -> bool:
	return unlocked.has(c.id)


func select_character(c: CharacterData) -> void:
	if is_unlocked(c) and selected != c.id:
		selected = c.id
		save_game()
		changed.emit()


## Progress toward an unlock condition as (current, target).
func unlock_progress(c: CharacterData) -> Vector2:
	var target := float(c.unlock_value)
	match c.unlock:
		CharacterData.Unlock.SURVIVE_SECONDS:
			return Vector2(minf(best_time, target), target)
		CharacterData.Unlock.TOTAL_KILLS:
			return Vector2(mini(total_kills, c.unlock_value), target)
		CharacterData.Unlock.NIGHTS_SURVIVED:
			return Vector2(mini(nights_survived, c.unlock_value), target)
		CharacterData.Unlock.BUY:
			return Vector2(mini(coins, c.unlock_value), target)
	return Vector2(1.0, 1.0)


func can_buy_character(c: CharacterData) -> bool:
	return not is_unlocked(c) and c.unlock == CharacterData.Unlock.BUY and coins >= c.unlock_value


func buy_character(c: CharacterData) -> bool:
	if not can_buy_character(c):
		return false
	coins -= c.unlock_value
	unlocked.append(c.id)
	save_game()
	changed.emit()
	return true


## Unlocks every hunter whose record condition is met; returns the new ones.
func _check_unlocks() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for c in CATALOG.characters:
		if is_unlocked(c):
			continue
		var met := false
		match c.unlock:
			CharacterData.Unlock.SURVIVE_SECONDS:
				met = best_time >= c.unlock_value
			CharacterData.Unlock.TOTAL_KILLS:
				met = total_kills >= c.unlock_value
			CharacterData.Unlock.NIGHTS_SURVIVED:
				met = nights_survived >= c.unlock_value
		if met:
			unlocked.append(c.id)
			out.append(c)
	return out


# ---------------------------------------------------------------- Reliquary

func upgrade_level(u: MetaUpgrade) -> int:
	return upgrade_levels.get(u.id, 0)


func can_buy_upgrade(u: MetaUpgrade) -> bool:
	var lv := upgrade_level(u)
	return lv < u.max_level and coins >= u.cost(lv)


func buy_upgrade(u: MetaUpgrade) -> bool:
	if not can_buy_upgrade(u):
		return false
	var lv := upgrade_level(u)
	coins -= u.cost(lv)
	upgrade_levels[u.id] = lv + 1
	save_game()
	changed.emit()
	return true


## Every coin spent on upgrades back, all levels to 0. Returns the refund.
func refund_all() -> int:
	var back := 0
	for u in CATALOG.upgrades:
		back += u.spent(upgrade_level(u))
	upgrade_levels.clear()
	coins += back
	save_game()
	changed.emit()
	return back


## Run start: the bought levels as StatModifiers on the player's stats.
func apply_upgrades(stats: Stats) -> void:
	for u in CATALOG.upgrades:
		var lv := upgrade_level(u)
		if lv > 0:
			for m in u.modifiers:
				stats.add_modifier(m, lv)


# ---------------------------------------------------------------- runs

## End of a run (death, dawn, or leaving it): run coins go to the bank,
## records update, record-based unlocks are checked. Saves immediately.
func bank_run(run_coins: int, seconds: float, kills: int, survived_night: bool) -> RunReward:
	var r := RunReward.new()
	r.coins_banked = maxi(0, run_coins)
	coins += r.coins_banked
	lifetime_coins += r.coins_banked
	runs += 1
	total_kills += maxi(0, kills)
	if survived_night:
		nights_survived += 1
	r.new_best_time = seconds > best_time
	best_time = maxf(best_time, seconds)
	r.new_unlocks = _check_unlocks()
	r.total_coins = coins
	save_game()
	changed.emit()
	return r
