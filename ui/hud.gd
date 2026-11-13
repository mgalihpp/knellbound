class_name Hud
extends CanvasLayer
## In-run HUD. View only: Game calls refresh(game) once per frame (and once
## more before showing a screen while the tree is paused); nothing here
## changes gameplay state.
##
## Layout (ui/hud.tscn, theme ui/theme/game_theme.tres):
##   top        %XpBar full width + %LevelLabel inside it
##   top-left   HP (heart, %HpBar, %HpLabel), %Loadout: one row of
##              Player.MAX_WEAPONS weapon slots and one of MAX_PASSIVES
##              passive slots (built here), each slot = frame + icon + pips
##   top-centre %TimeLabel, %BossPanel (active boss / end-of-night warning)
##   top-right  kills and run coins
##   edges      %Arrows: pointers to the boss and to chests off screen
##   bottom     %DebugPanel (debug builds; H toggles the key help)
## The world-space HP bar under the player is Player.hp_bar (WorldHpBar).
##
## Cheap with 1000+ enemies: numbers are only re-formatted when the integer
## changes, slot styles / pips / colour overrides only when they change.

const SLOT_SIZE := 44
const PIP_ROW := 5
const TIME_COLOR := Color(0.925, 0.902, 0.961)
const FINAL_TIME_COLOR := Color(1.0, 0.3, 0.35)
const FINAL_TITLE := "THE KNELL TOLLS — the night is over"
const ARROW_TEX := preload("res://art/ui/icon_arrow.png")
const CHEST_TEX := preload("res://art/ui/icon_chest.png")
const SKULL_TEX := preload("res://art/ui/icon_skull.png")
const MAX_ARROWS := 4
const BOSS_ARROW := Color(1.0, 0.35, 0.4)
const CHEST_ARROW := Color(1.0, 0.85, 0.4)
## Arrows sit this far inside the screen edge.
const ARROW_INSET := 34.0
const ARROW_TOP := 96.0
## Debug key help, one group per line (keys handled in Game._unhandled_input).
const DEBUG_KEYS := "[F1] +500 enemies   [F2] clear enemies   [F3] vacuum gems   [F4] +1 level\n[F5] max weapons   [F6] chest   [F7] evo relics   [E] elite   [B] breakables\n[PgUp] +1 min   [1] [2] [3] jump to 10 / 20 / 30 min   [H] hide keys"

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var level_label: Label = %LevelLabel
@onready var time_label: Label = %TimeLabel
@onready var kills_label: Label = %KillsLabel
@onready var coins_label: Label = %CoinsLabel
@onready var debug_panel: Control = %DebugPanel
@onready var debug_label: Label = %DebugLabel
@onready var debug_keys: Label = %DebugKeys
@onready var loadout: VBoxContainer = %Loadout
@onready var boss_panel: Control = %BossPanel
@onready var boss_name: Label = %BossName
@onready var boss_bar: ProgressBar = %BossBar
@onready var arrows_root: Control = %Arrows

var _weapon_slots: Array[Panel] = []
var _passive_slots: Array[Panel] = []
var _arrows: Array[Control] = []
# Last shown values (-1 = never shown).
var _level := -1
var _seconds := -1
var _kills := -1
var _coins := -1
var _hp := -1
var _max_hp := -1


func _ready() -> void:
	debug_panel.visible = OS.is_debug_build()
	debug_keys.text = DEBUG_KEYS
	_weapon_slots = _make_row(Player.MAX_WEAPONS)
	_passive_slots = _make_row(Player.MAX_PASSIVES)
	for k in MAX_ARROWS:
		_arrows.append(_make_arrow())


func refresh(game: Game) -> void:
	var p := game.player
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	p.hp_bar.set_fraction(p.hp / p.max_hp)
	var hp_i := ceili(p.hp)
	var max_i := roundi(p.max_hp)
	if hp_i != _hp or max_i != _max_hp:
		_hp = hp_i
		_max_hp = max_i
		hp_label.text = "%d/%d" % [hp_i, max_i]
	xp_bar.value = game.leveling.progress()
	if game.leveling.level != _level:
		_level = game.leveling.level
		level_label.text = "LV %d" % _level
	var secs := int(game.elapsed)
	if secs != _seconds:
		_seconds = secs
		time_label.text = fmt_time(secs)
	if game.kills != _kills:
		_kills = game.kills
		kills_label.text = str(_kills)
	if game.coins != _coins:
		_coins = game.coins
		coins_label.text = str(_coins)
	_refresh_boss(game)
	_refresh_loadout(p)
	_refresh_arrows(game)
	if debug_panel.visible:
		debug_label.text = "FPS %d   enemies %d   shots %d   projectiles %d\ngems %d   pickups %d   numbers %d   effects %d" % [
			Engine.get_frames_per_second(), game.swarm.count, game.enemy_shots.count,
			game.projectiles.count, game.gems.count, game.pickups.count,
			game.numbers.count, game.effects.count]


func _refresh_boss(game: Game) -> void:
	var final := game.director.final_phase
	var color := FINAL_TIME_COLOR if final else TIME_COLOR
	if time_label.get_theme_color(&"font_color") != color:
		time_label.add_theme_color_override(&"font_color", color)
	var boss := game.director.active_boss()
	boss_panel.visible = final or boss != null
	if final:
		boss_name.text = FINAL_TITLE
		boss_bar.visible = false
	elif boss != null:
		boss_name.text = boss.data.title
		boss_bar.visible = true
		boss_bar.value = boss.hp / boss.max_hp


func _refresh_loadout(p: Player) -> void:
	for i in _weapon_slots.size():
		if i < p.weapons.size():
			var w := p.weapons[i]
			_set_slot(_weapon_slots[i], w.data.icon, w.level, w.data.max_level, w.data.is_evolution)
		else:
			_set_slot(_weapon_slots[i], null, 0, 0, false)
	var i := 0
	for passive in p.passives:
		if i >= _passive_slots.size():
			break
		_set_slot(_passive_slots[i], passive.icon, p.passives[passive], passive.max_level, false)
		i += 1
	while i < _passive_slots.size():
		_set_slot(_passive_slots[i], null, 0, 0, false)
		i += 1


## Pointers at the screen edge toward the boss and chests that are off screen.
func _refresh_arrows(game: Game) -> void:
	var cam := game.camera_rig.camera
	var view := arrows_root.get_rect()
	var used := 0
	var boss := game.director.active_boss()
	if boss != null:
		used += _point(_arrows[used], cam, view, boss.pos, BOSS_ARROW, SKULL_TEX)
	var pk := game.pickups
	for k in pk.count:
		if used >= MAX_ARROWS:
			break
		if pk.types[pk.kind[k]].effect == PickupData.Effect.CHEST:
			used += _point(_arrows[used], cam, view, pk.pos[k], CHEST_ARROW, CHEST_TEX)
	for k in range(used, MAX_ARROWS):
		_arrows[k].visible = false


## Places `arrow` toward ground point `at`; returns 1 if shown (off screen).
func _point(arrow: Control, cam: Camera3D, view: Rect2, at: Vector2, tint: Color,
		icon: Texture2D) -> int:
	var sp := cam.unproject_position(Vector3(at.x, 0.5, at.y))
	if view.grow(-8.0).has_point(sp):
		arrow.visible = false
		return 0
	var c := view.get_center()
	var d := sp - c
	# Distance from the centre to the edge band on the side d points to;
	# the top band sits below the XP bar / timer / counters.
	var reach_x := view.size.x * 0.5 - ARROW_INSET
	var reach_y := (c.y - view.position.y - ARROW_TOP) if d.y < 0.0 else (view.end.y - c.y - ARROW_INSET)
	var t := minf(reach_x / maxf(absf(d.x), 0.001), reach_y / maxf(absf(d.y), 0.001))
	arrow.visible = true
	arrow.position = c + d * t
	arrow.modulate = tint
	var pointer: TextureRect = arrow.get_child(0)
	pointer.rotation = d.angle()
	var badge: TextureRect = arrow.get_child(1)
	badge.texture = icon
	badge.position = -d.normalized() * 30.0 - badge.size * 0.5
	return 1


## Debug: adds a key-help line for the pickups keys 4..9 drop (Game).
func set_debug_pickups(types: Array[PickupData]) -> void:
	var parts: PackedStringArray = []
	for k in mini(types.size(), 6):
		parts.append("[%d] %s" % [k + 4, types[k].display_name])
	debug_keys.text = DEBUG_KEYS + "\n" + "   ".join(parts)


## Debug: show / hide the key help under the stats line.
func toggle_debug_keys() -> void:
	debug_keys.visible = not debug_keys.visible
	# Let the panel shrink back to the stats line (it grows upward).
	debug_panel.reset_size()
	debug_panel.position.y = debug_panel.get_parent_area_size().y - 8.0 - debug_panel.size.y


func _set_slot(slot: Panel, icon: Texture2D, level: int, max_level: int, evolved: bool) -> void:
	var tex: TextureRect = slot.get_child(0)
	var pips: LevelPips = slot.get_parent().get_child(1)
	tex.texture = icon
	var style := &"SlotPanel"
	if icon != null and evolved:
		style = &"SlotEvo"
	elif icon != null and level >= max_level:
		style = &"SlotMax"
	# Re-theming is not free: only touch the variation when it changes.
	if slot.theme_type_variation != style:
		slot.theme_type_variation = style
	if icon == null:
		pips.set_levels(0, 0)
	else:
		pips.set_levels(level, max_level, 0, evolved)


func _make_row(n: int) -> Array[Panel]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loadout.add_child(row)
	var slots: Array[Panel] = []
	for k in n:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 2)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cell)
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.theme_type_variation = &"SlotPanel"
		cell.add_child(slot)
		var tex := TextureRect.new()
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex)
		var pips := LevelPips.new()
		pips.custom_minimum_size = Vector2(SLOT_SIZE, PIP_ROW)
		cell.add_child(pips)
		slots.append(slot)
	return slots


func _make_arrow() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var pointer := TextureRect.new()
	pointer.texture = ARROW_TEX
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pointer.size = ARROW_TEX.get_size() * 1.5
	pointer.position = -pointer.size * 0.5
	pointer.pivot_offset = pointer.size * 0.5
	root.add_child(pointer)
	var badge := TextureRect.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.size = Vector2(24, 24)
	root.add_child(badge)
	arrows_root.add_child(root)
	return root


static func fmt_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]
