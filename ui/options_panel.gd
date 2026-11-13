class_name OptionsPanel
extends PanelContainer
## Options, shared by the title screen and the pause menu. Reads and writes
## the `Settings` autoload only (volumes drive the Master / SFX / BGM buses;
## Settings stores everything in the save). Moving the SFX slider plays a
## sample. ui_cancel or Back emits `closed`.

signal closed

const BUS_NAMES := ["Master", "SFX", "Music"]

var _sliders: Array[HSlider] = []
var _values: Array[Label] = []

@onready var grid: GridContainer = %VolumeGrid
@onready var shake_box: CheckBox = %ShakeBox
@onready var numbers_box: CheckBox = %NumbersBox
@onready var fullscreen_box: CheckBox = %FullscreenBox
@onready var back_button: Button = %BackButton


func _ready() -> void:
	for k in BUS_NAMES.size():
		var name_label := Label.new()
		name_label.text = BUS_NAMES[k]
		name_label.custom_minimum_size.x = 120
		grid.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(260, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_volume.bind(k))
		slider.mouse_entered.connect(slider.grab_focus)
		grid.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 72
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
		_sliders.append(slider)
		_values.append(value)
	shake_box.toggled.connect(Settings.set_screen_shake)
	numbers_box.toggled.connect(Settings.set_damage_numbers)
	fullscreen_box.toggled.connect(Settings.set_fullscreen)
	back_button.pressed.connect(closed.emit)
	for c: Control in [shake_box, numbers_box, fullscreen_box, back_button]:
		c.mouse_entered.connect(c.grab_focus)
	# The embedded editor window cannot switch to fullscreen.
	fullscreen_box.disabled = Engine.is_embedded_in_editor()


## Shows the panel with the current settings and focuses the first control.
func open() -> void:
	for k in _sliders.size():
		_sliders[k].set_value_no_signal(Settings.volumes[k])
		_values[k].text = "%d%%" % roundi(Settings.volumes[k] * 100.0)
	shake_box.set_pressed_no_signal(Settings.screen_shake)
	numbers_box.set_pressed_no_signal(Settings.damage_numbers)
	fullscreen_box.set_pressed_no_signal(Settings.fullscreen)
	visible = true
	_sliders[0].grab_focus()


func _on_volume(v: float, k: int) -> void:
	Settings.set_volume(k, v)
	_values[k].text = "%d%%" % roundi(v * 100.0)
	if k == 1:
		Audio.play_sfx(&"gem")


func _unhandled_input(event: InputEvent) -> void:
	if visible and is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
