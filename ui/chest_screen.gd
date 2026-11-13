class_name ChestScreen
extends CanvasLayer
## View only: shows the rewards Game already applied from one chest, revealing
## them one by one, then emits `closed`. Each row is an OfferView; evolutions
## get the gold frame and badge. Runs while the tree is paused
## (process_mode ALWAYS, tweens bound to it).

signal closed

const MAX_ROWS := 5
const REVEAL_DELAY := 0.3
const INPUT_GRACE_MS := 400

var is_open := false
var _rows: Array[PanelContainer] = []
var _views: Array[OfferView] = []
var _accept_after := 0
var _tween: Tween

@onready var title: Label = %Title
@onready var chest_icon: TextureRect = %ChestIcon
@onready var rows_box: VBoxContainer = %Rows
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	visible = false
	for i in MAX_ROWS:
		_make_row()
	continue_button.pressed.connect(_on_continue)


func present(rewards: Array[UpgradeOffer]) -> void:
	is_open = true
	visible = true
	_accept_after = Time.get_ticks_msec() + INPUT_GRACE_MS
	var evolved := rewards.any(func(o: UpgradeOffer) -> bool: return o.kind == UpgradeOffer.Kind.EVOLUTION)
	title.text = "EVOLUTION!" if evolved else "RELIQUARY OPENED"
	for i in MAX_ROWS:
		var row := _rows[i]
		row.visible = i < rewards.size()
		row.modulate.a = 0.0
		if row.visible:
			_views[i].show_offer(rewards[i])

	if _tween:
		_tween.kill()
	_tween = create_tween()
	chest_icon.pivot_offset = chest_icon.size * 0.5
	chest_icon.scale = Vector2(0.6, 0.6)
	_tween.tween_property(chest_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in rewards.size():
		_tween.tween_interval(REVEAL_DELAY)
		_tween.tween_property(_rows[i], "modulate:a", 1.0, 0.15)
	continue_button.grab_focus()


func close() -> void:
	is_open = false
	visible = false
	if _tween:
		_tween.kill()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_continue()


func _on_continue() -> void:
	if Time.get_ticks_msec() < _accept_after:
		return
	# First press skips the reveal, the second one closes.
	if _tween and _tween.is_running():
		_tween.custom_step(100.0)
		return
	closed.emit()


func _make_row() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"InsetPanel"
	panel.custom_minimum_size = Vector2(620, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := OfferView.new()
	panel.add_child(view)
	rows_box.add_child(panel)
	_rows.append(panel)
	_views.append(view)
