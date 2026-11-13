class_name GameOverScreen
extends CanvasLayer
## View only: the end-of-run summary. Game calls present(game) when the
## player dies; this reads the run (time, level, kills, coins, damage per
## weapon from Weapon.damage_dealt, Game.kills_by_type, what banking gave
## from Game.run_reward: coins added to the purse, new best, new hunters) and emits
## retry / title. A death after the final minute (the Knellwraith) is shown as
## having outlasted the night instead of as a plain death.

signal retry_requested
signal title_requested

const FALLEN_COLOR := Color(0.92, 0.25, 0.3)
const DAWN_COLOR := Color(0.914, 0.725, 0.286)
const INPUT_GRACE_MS := 700
const MAX_WEAPON_ROWS := 6

var is_open := false
var _accept_after := 0

@onready var panel: PanelContainer = %Panel
@onready var title: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var time_value: Label = %TimeValue
@onready var level_value: Label = %LevelValue
@onready var kills_value: Label = %KillsValue
@onready var coins_value: Label = %CoinsValue
@onready var foe_icon: TextureRect = %FoeIcon
@onready var foe_label: Label = %FoeLabel
@onready var damage_rows: VBoxContainer = %DamageRows
@onready var retry_button: Button = %RetryButton
@onready var title_button: Button = %TitleButton
@onready var bank_label: Label = %BankLabel
@onready var best_label: Label = %BestLabel
@onready var unlocks: HBoxContainer = %Unlocks


func _ready() -> void:
	visible = false
	retry_button.pressed.connect(_guarded.bind(retry_requested.emit))
	title_button.pressed.connect(_guarded.bind(title_requested.emit))
	for b in [retry_button, title_button]:
		b.mouse_entered.connect(b.grab_focus)


func present(game: Game) -> void:
	is_open = true
	visible = true
	_accept_after = Time.get_ticks_msec() + INPUT_GRACE_MS
	var dawn := game.director.final_phase
	title.text = "THE NIGHT IS OVER" if dawn else "FALLEN"
	title.add_theme_color_override(&"font_color", DAWN_COLOR if dawn else FALLEN_COLOR)
	subtitle.text = "You held out until the Knell. Dawn finds you at last." if dawn \
		else "The night claims another hunter."
	panel.theme_type_variation = &"" if dawn else &"BloodPanel"
	time_value.text = Hud.fmt_time(game.elapsed)
	level_value.text = str(game.leveling.level)
	kills_value.text = str(game.kills)
	coins_value.text = str(game.coins)
	_show_top_foe(game)
	_show_damage(game)
	_show_reward(game.run_reward)

	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	var t := create_tween().set_parallel()
	t.tween_property(panel, "modulate:a", 1.0, 0.35).set_delay(0.25)
	t.tween_property(panel, "scale", Vector2.ONE, 0.35).set_delay(0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	retry_button.grab_focus()


func _show_reward(r: RunReward) -> void:
	for c in unlocks.get_children():
		c.queue_free()
	bank_label.get_parent().visible = r != null
	best_label.visible = r != null and r.new_best_time
	if r == null:
		return
	bank_label.text = "+%d coins banked  ·  %d in the purse" % [r.coins_banked, r.total_coins]
	for c in r.new_unlocks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		var face := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = c.sprite_sheet
		atlas.region = Rect2(0, 0, 18, 18)
		face.texture = atlas
		face.custom_minimum_size = Vector2(54, 54)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(face)
		var text := Label.new()
		text.theme_type_variation = &"GoldLabel"
		text.text = "New hunter: %s" % c.display_name
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(text)
		unlocks.add_child(row)
	if not r.new_unlocks.is_empty():
		Audio.play_sfx(&"unlock")


func _show_top_foe(game: Game) -> void:
	var best: EnemyData = null
	var n := 0
	for data in game.kills_by_type:
		if game.kills_by_type[data] > n:
			n = game.kills_by_type[data]
			best = data
	if best == null:
		foe_label.text = "none"
		foe_icon.texture = null
		return
	foe_label.text = "%s  ×%d" % [best.display_name, n]
	# First animation frame of its row in the enemy sheet.
	var sheet := game.swarm.large_sheet if best.large_sprite else game.swarm.sheet
	var cell := 34.0 if best.large_sprite else 18.0
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0.0, best.sprite_row * cell, cell, cell)
	foe_icon.texture = atlas


func _show_damage(game: Game) -> void:
	for c in damage_rows.get_children():
		c.queue_free()
	var weapons := game.player.weapons.duplicate()
	weapons.sort_custom(func(a: Weapon, b: Weapon) -> bool: return a.damage_dealt > b.damage_dealt)
	var top := 1.0
	if not weapons.is_empty():
		top = maxf(1.0, weapons[0].damage_dealt)
	var secs := maxf(1.0, game.elapsed)
	for k in mini(weapons.size(), MAX_WEAPON_ROWS):
		var w: Weapon = weapons[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(44, 44)
		slot.theme_type_variation = &"SlotEvo" if w.data.is_evolution else &"SlotPanel"
		var icon := TextureRect.new()
		icon.texture = w.data.icon
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		slot.add_child(icon)
		row.add_child(slot)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override(&"separation", 4)
		var head := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = w.data.display_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		var value := Label.new()
		value.theme_type_variation = &"GoldLabel"
		value.text = _short(w.damage_dealt)
		head.add_child(value)
		col.add_child(head)
		var bar_row := HBoxContainer.new()
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = w.damage_dealt / top
		bar.custom_minimum_size = Vector2(0, 12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar_row.add_child(bar)
		var dps := Label.new()
		dps.theme_type_variation = &"SmallLabel"
		var per_sec := w.damage_dealt / secs
		dps.text = ("%.1f/s" % per_sec) if per_sec < 10.0 else "%s/s" % _short(per_sec)
		dps.custom_minimum_size.x = 72
		dps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bar_row.add_child(dps)
		col.add_child(bar_row)
		row.add_child(col)
		damage_rows.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		_guarded(retry_requested.emit)


func _guarded(action: Callable) -> void:
	if Time.get_ticks_msec() >= _accept_after:
		action.call()


## 950 -> "950", 12345 -> "12.3K", 4.2e6 -> "4.20M".
static func _short(v: float) -> String:
	if v >= 1.0e6:
		return "%.2fM" % (v / 1.0e6)
	if v >= 1.0e4:
		return "%.1fK" % (v / 1.0e3)
	return str(roundi(v))
