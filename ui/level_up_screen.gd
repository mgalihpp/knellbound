class_name LevelUpScreen
extends CanvasLayer
## View only: shows offers and emits what the player chose. Game owns the
## rules (charges, banish list, the queue of pending levels).
##
## Each card is a Button (theme variation "Card") holding an OfferView.
## Input: mouse hover/click, arrows / d-pad + Enter / A (focus navigation),
## number keys 1-4 pick a card directly, ui_cancel leaves banish mode.
## A short grace period after each present() swallows presses held over from
## gameplay or the previous screen. The pop-in tween runs while the tree is
## paused (this layer is PROCESS_MODE_ALWAYS).

signal picked(offer: UpgradeOffer)
signal reroll_requested
signal skip_requested
signal banish_requested(offer: UpgradeOffer)

const MAX_CARDS := 4
const INPUT_GRACE_MS := 300
const CARD_SIZE := Vector2(700, 104)
const BANISH_TINT := Color(1.0, 0.55, 0.55)
const CARD_PAD := Vector2(16, 10)
## Pop-in: the panel scales up, cards slide in one after another.
const PANEL_POP := 0.16
const CARD_DELAY := 0.05
const CARD_SLIDE := 28.0

var is_open := false
var _offers: Array[UpgradeOffer] = []
var _cards: Array[Button] = []
var _views: Array[OfferView] = []
var _banish_mode := false
var _banishes := 0
var _level_text := ""
var _accept_after := 0
var _tween: Tween

@onready var panel: Control = %Panel
@onready var subtitle: Label = %Subtitle
@onready var cards_box: VBoxContainer = %Cards
@onready var reroll_button: Button = %RerollButton
@onready var skip_button: Button = %SkipButton
@onready var banish_button: Button = %BanishButton


func _ready() -> void:
	visible = false
	for i in MAX_CARDS:
		_make_card(i)
	reroll_button.pressed.connect(_guarded.bind(reroll_requested.emit))
	skip_button.pressed.connect(_guarded.bind(skip_requested.emit))
	banish_button.pressed.connect(_guarded.bind(_toggle_banish))
	# Explicit neighbours: the wide cards would otherwise catch left/right
	# from the action row.
	var row: Array[Button] = [reroll_button, skip_button, banish_button]
	for k in row.size():
		var b := row[k]
		b.mouse_entered.connect(b.grab_focus)
		b.focus_neighbor_left = row[maxi(k - 1, 0)].get_path()
		b.focus_neighbor_right = row[mini(k + 1, row.size() - 1)].get_path()
		b.focus_neighbor_bottom = b.get_path()
	for c in _cards:
		c.focus_neighbor_left = c.get_path()
		c.focus_neighbor_right = c.get_path()


func present(offers: Array[UpgradeOffer], level: int, rerolls: int, skips: int, banishes: int) -> void:
	var was_open := is_open
	_offers = offers
	_banishes = banishes
	is_open = true
	visible = true
	_accept_after = Time.get_ticks_msec() + INPUT_GRACE_MS
	_level_text = "Level %d  ·  choose an upgrade" % level
	reroll_button.text = "Reroll %d" % rerolls
	reroll_button.disabled = rerolls <= 0
	skip_button.text = "Skip %d" % skips
	skip_button.disabled = skips <= 0
	banish_button.text = "Banish %d" % banishes
	banish_button.disabled = banishes <= 0
	_set_banish_mode(false)
	for i in MAX_CARDS:
		var shown := i < offers.size()
		_cards[i].visible = shown
		if shown:
			_views[i].show_offer(offers[i])
	for c in _cards:
		c.focus_neighbor_bottom = NodePath()
	var last := _cards[offers.size() - 1]
	last.focus_neighbor_bottom = skip_button.get_path()
	for b in [reroll_button, skip_button, banish_button]:
		b.focus_neighbor_top = last.get_path()
	_cards[0].grab_focus()
	_animate(not was_open)


func close() -> void:
	is_open = false
	visible = false
	_set_banish_mode(false)
	if _tween:
		_tween.kill()


func _animate(pop_panel: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	if pop_panel:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.92, 0.92)
		panel.modulate.a = 0.0
		_tween.tween_property(panel, "scale", Vector2.ONE, PANEL_POP) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(panel, "modulate:a", 1.0, PANEL_POP * 0.7)
	for i in _offers.size():
		var card := _cards[i]
		var view := _views[i]
		card.modulate.a = 0.0
		view.position.x = CARD_PAD.x + CARD_SLIDE
		var delay := (PANEL_POP * 0.5 if pop_panel else 0.0) + i * CARD_DELAY
		_tween.tween_property(card, "modulate:a", 1.0, 0.12).set_delay(delay)
		_tween.tween_property(view, "position:x", CARD_PAD.x, 0.18).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel") and _banish_mode:
		get_viewport().set_input_as_handled()
		_set_banish_mode(false)
		banish_button.grab_focus()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var i: int = event.keycode - KEY_1
	if i >= 0 and i < _offers.size():
		get_viewport().set_input_as_handled()
		_on_card_pressed(i)


func _on_card_pressed(i: int) -> void:
	if Time.get_ticks_msec() < _accept_after:
		return
	var offer := _offers[i]
	if _banish_mode:
		if offer.item != null:
			banish_requested.emit(offer)
	else:
		picked.emit(offer)


func _guarded(action: Callable) -> void:
	if Time.get_ticks_msec() >= _accept_after:
		action.call()


func _toggle_banish() -> void:
	if _banishes > 0:
		_set_banish_mode(not _banish_mode)
		_cards[0].grab_focus()


func _set_banish_mode(on: bool) -> void:
	_banish_mode = on
	cards_box.modulate = BANISH_TINT if on else Color.WHITE
	subtitle.text = "Choose an upgrade to BANISH for this run" if on else _level_text
	banish_button.set_pressed_no_signal(on)


func _make_card(i: int) -> void:
	var b := Button.new()
	b.theme_type_variation = &"Card"
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	var view := OfferView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_left = CARD_PAD.x
	view.offset_right = -CARD_PAD.x
	view.offset_top = CARD_PAD.y
	view.offset_bottom = -CARD_PAD.y
	b.add_child(view)
	b.pressed.connect(_on_card_pressed.bind(i))
	b.mouse_entered.connect(b.grab_focus)
	cards_box.add_child(b)
	_cards.append(b)
	_views.append(view)
