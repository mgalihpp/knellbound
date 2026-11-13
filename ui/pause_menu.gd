class_name PauseMenu
extends CanvasLayer
## View only: the pause screen. Game pauses the tree and calls open(game);
## this reads the player's stats and loadout and emits what was chosen.
## Game unpauses / restarts / leaves. Options swaps in the shared
## OptionsPanel; ui_cancel (or `pause`) backs out of it, then resumes.

signal resume_requested
signal restart_requested
signal quit_requested

## Stats listed on the right, in two columns.
const SHOWN_STATS: Array[Stats.Id] = [
	Stats.Id.MAX_HP, Stats.Id.MIGHT,
	Stats.Id.RECOVERY, Stats.Id.AREA,
	Stats.Id.ARMOR, Stats.Id.COOLDOWN,
	Stats.Id.MOVE_SPEED, Stats.Id.AMOUNT,
	Stats.Id.MAGNET, Stats.Id.PROJECTILE_SPEED,
	Stats.Id.LUCK, Stats.Id.DURATION,
	Stats.Id.GROWTH, Stats.Id.CRIT_CHANCE,
	Stats.Id.REROLL, Stats.Id.CRIT_DAMAGE,
]
## Shown as a percentage of the base 1.0 (1.15 -> 115%).
const AS_PERCENT := [Stats.Id.MIGHT, Stats.Id.AREA, Stats.Id.COOLDOWN, Stats.Id.PROJECTILE_SPEED,
	Stats.Id.DURATION, Stats.Id.LUCK, Stats.Id.GROWTH, Stats.Id.CRIT_CHANCE, Stats.Id.CRIT_DAMAGE]

var is_open := false
var _stat_values: Array[Label] = []

@onready var menu: Control = %Menu
@onready var options: OptionsPanel = %Options
@onready var info: Control = %Info
@onready var run_label: Label = %RunLabel
@onready var resume_button: Button = %ResumeButton
@onready var options_button: Button = %OptionsButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton
@onready var stats_grid: GridContainer = %StatsGrid
@onready var weapons_grid: GridContainer = %WeaponsGrid
@onready var passives_row: HBoxContainer = %PassivesRow


func _ready() -> void:
	visible = false
	options.visible = false
	resume_button.pressed.connect(resume_requested.emit)
	options_button.pressed.connect(_show_options)
	restart_button.pressed.connect(restart_requested.emit)
	quit_button.pressed.connect(quit_requested.emit)
	options.closed.connect(_hide_options)
	for b in [resume_button, options_button, restart_button, quit_button]:
		b.mouse_entered.connect(b.grab_focus)
	for id in SHOWN_STATS:
		var name_label := Label.new()
		name_label.theme_type_variation = &"MutedLabel"
		name_label.text = _stat_name(id)
		name_label.custom_minimum_size.x = 200
		stats_grid.add_child(name_label)
		var value := Label.new()
		value.custom_minimum_size.x = 96
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats_grid.add_child(value)
		_stat_values.append(value)


func open(game: Game) -> void:
	is_open = true
	visible = true
	var p := game.player
	run_label.text = "%s  ·  LV %d  ·  %d kills" % [
		Hud.fmt_time(game.elapsed), game.leveling.level, game.kills]
	for k in SHOWN_STATS.size():
		_stat_values[k].text = format_stat(SHOWN_STATS[k], p.stats.value(SHOWN_STATS[k]))
	_fill_loadout(p)
	options.visible = false
	menu.visible = true
	info.visible = true
	resume_button.grab_focus()


func close() -> void:
	is_open = false
	visible = false
	options.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or options.visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func _show_options() -> void:
	menu.visible = false
	info.visible = false
	options.open()


func _hide_options() -> void:
	options.visible = false
	menu.visible = true
	info.visible = true
	options_button.grab_focus()


func _fill_loadout(p: Player) -> void:
	for c in weapons_grid.get_children():
		c.queue_free()
	for c in passives_row.get_children():
		c.queue_free()
	for w in p.weapons:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		row.custom_minimum_size.x = 330
		row.add_child(_icon_slot(w.data.icon, w.data.is_evolution))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override(&"separation", 4)
		var name_label := Label.new()
		name_label.text = w.data.display_name
		name_label.theme_type_variation = &"GoldLabel" if w.data.is_evolution else &""
		col.add_child(name_label)
		var pips := LevelPips.new()
		pips.pip_scale = 2
		pips.centered = false
		pips.custom_minimum_size = Vector2(120, 10)
		pips.set_levels(w.level, w.data.max_level, 0, w.data.is_evolution)
		col.add_child(pips)
		row.add_child(col)
		weapons_grid.add_child(row)
	for passive in p.passives:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 3)
		cell.add_child(_icon_slot(passive.icon, false))
		var pips := LevelPips.new()
		pips.custom_minimum_size = Vector2(44, 5)
		pips.set_levels(p.passives[passive], passive.max_level)
		cell.add_child(pips)
		cell.tooltip_text = passive.display_name
		passives_row.add_child(cell)


func _icon_slot(tex: Texture2D, evolved: bool) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(44, 44)
	slot.theme_type_variation = &"SlotEvo" if evolved else &"SlotPanel"
	var icon := TextureRect.new()
	icon.texture = tex
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	slot.add_child(icon)
	return slot


static func _stat_name(id: int) -> String:
	var s: String = Stats.LABELS[id]
	return s.substr(0, 1).to_upper() + s.substr(1)


## Current value of a stat as the pause / summary screens show it.
static func format_stat(id: int, v: float) -> String:
	if AS_PERCENT.has(id):
		return "%d%%" % roundi(v * 100.0)
	match id:
		Stats.Id.AMOUNT:
			return "+%d" % int(v)
		Stats.Id.RECOVERY:
			return "%.1f/s" % v
		Stats.Id.MOVE_SPEED, Stats.Id.MAGNET:
			return "%.1f" % v
	return str(roundi(v))
