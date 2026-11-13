class_name ShopScreen
extends Control
## The Reliquary (scenes/shop.tscn): permanent upgrades bought with banked
## coins. View only: prices, levels and the buying itself come from
## MetaUpgrade + SaveData (buy_upgrade / refund_all). One card per upgrade in
## SaveData.CATALOG order; the focused card fills the detail panel. Pressing a
## card (or Buy) buys its next level. Refund All asks for a second press.

const TITLE_SCENE := "res://scenes/title.tscn"
const COIN_ICON := preload("res://art/ui/icon_coin.png")
const CARD_SIZE := Vector2(124, 132)
const CONFIRM_SECONDS := 3.0
const AFFORD_COLOR := Color(1, 0.878, 0.541)
const TOO_DEAR_COLOR := Color(0.75, 0.38, 0.42)

var _cards: Array[Button] = []
var _card_pips: Array[LevelPips] = []
var _card_price: Array[Label] = []
var _card_coin: Array[TextureRect] = []
var _selected := 0
var _refund_armed := false

@onready var grid: GridContainer = %Grid
@onready var coins_label: Label = %CoinsLabel
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_level: Label = %DetailLevel
@onready var detail_pips: LevelPips = %DetailPips
@onready var detail_desc: Label = %DetailDesc
@onready var detail_now: Label = %DetailNow
@onready var detail_next: Label = %DetailNext
@onready var price_icon: TextureRect = %PriceIcon
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton
@onready var toast: Label = %Toast
@onready var back_button: Button = %BackButton
@onready var refund_button: Button = %RefundButton


func _ready() -> void:
	Audio.play_music(&"title")
	for k in SaveData.CATALOG.upgrades.size():
		grid.add_child(_make_card(k))
	buy_button.set_meta(&"no_press_sound", true)
	buy_button.pressed.connect(func() -> void: _buy(_selected))
	back_button.pressed.connect(_leave)
	refund_button.pressed.connect(_on_refund)
	for b: Button in [buy_button, back_button, refund_button]:
		b.mouse_entered.connect(b.grab_focus)
	refund_button.focus_exited.connect(_disarm_refund)
	_refresh()
	_cards[0].grab_focus()


func _make_card(k: int) -> Button:
	var u := SaveData.CATALOG.upgrades[k]
	var card := Button.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size = CARD_SIZE
	card.set_meta(&"no_press_sound", true)
	card.pressed.connect(_buy.bind(k))
	card.focus_entered.connect(_select.bind(k))
	card.mouse_entered.connect(card.grab_focus)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 10
	col.offset_bottom = -10
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	var icon := TextureRect.new()
	icon.texture = u.icon
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(0, 38)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	var name_label := Label.new()
	name_label.text = u.display_name
	name_label.theme_type_variation = &"SmallLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	var pips := LevelPips.new()
	pips.pip_scale = 2
	pips.custom_minimum_size = Vector2(0, 10)
	col.add_child(pips)
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override(&"separation", 6)
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(price_row)
	var coin := TextureRect.new()
	coin.texture = COIN_ICON
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(coin)
	var price := Label.new()
	price.theme_type_variation = &"SmallLabel"
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_child(price)

	_cards.append(card)
	_card_pips.append(pips)
	_card_price.append(price)
	_card_coin.append(coin)
	return card


## Redraws every card and the detail panel from SaveData.
func _refresh() -> void:
	coins_label.text = str(SaveData.coins)
	var spent := 0
	for k in _cards.size():
		var u := SaveData.CATALOG.upgrades[k]
		var lv := SaveData.upgrade_level(u)
		spent += u.spent(lv)
		_card_pips[k].set_levels(lv, u.max_level)
		var maxed := lv >= u.max_level
		_card_coin[k].visible = not maxed
		_card_price[k].text = "MAX" if maxed else str(u.cost(lv))
		_card_price[k].add_theme_color_override(&"font_color",
			AFFORD_COLOR if maxed or SaveData.coins >= u.cost(lv) else TOO_DEAR_COLOR)
	refund_button.disabled = spent == 0
	refund_button.focus_mode = Control.FOCUS_NONE if spent == 0 else Control.FOCUS_ALL
	if not _refund_armed:
		refund_button.text = "Refund All" if spent == 0 else "Refund All (%d)" % spent
	_show_detail()


func _select(k: int) -> void:
	_selected = k
	_show_detail()


func _show_detail() -> void:
	var u := SaveData.CATALOG.upgrades[_selected]
	var lv := SaveData.upgrade_level(u)
	var maxed := lv >= u.max_level
	detail_icon.texture = u.icon
	detail_name.text = u.display_name
	detail_level.text = "Level %d / %d" % [lv, u.max_level]
	detail_pips.set_levels(lv, u.max_level, mini(lv + 1, u.max_level))
	detail_desc.text = u.description
	detail_now.text = "Now: %s" % (u.effect_text(lv) if lv > 0 else "nothing yet")
	detail_next.text = "Fully blessed." if maxed else "Next: %s" % u.effect_text(lv + 1)
	price_icon.visible = not maxed
	price_label.text = "" if maxed else str(u.cost(lv))
	buy_button.disabled = maxed
	buy_button.text = "Maxed" if maxed else ("Buy" if SaveData.coins >= u.cost(lv) else "Not enough coins")


func _buy(k: int) -> void:
	_selected = k
	var u := SaveData.CATALOG.upgrades[k]
	if SaveData.buy_upgrade(u):
		Audio.play_sfx(&"buy")
		_pop(_cards[k])
		_pop(coins_label)
		_say("%s  →  level %d" % [u.display_name, SaveData.upgrade_level(u)])
	else:
		Audio.play_sfx(&"deny")
		_say("Already at its peak." if SaveData.upgrade_level(u) >= u.max_level else "Not enough coins.")
	_refresh()


func _on_refund() -> void:
	if not _refund_armed:
		_refund_armed = true
		refund_button.text = "Press again to refund"
		get_tree().create_timer(CONFIRM_SECONDS).timeout.connect(_disarm_refund)
		return
	_refund_armed = false
	var back := SaveData.refund_all()
	Audio.play_sfx(&"coin")
	_pop(coins_label)
	_say("Refunded %d coins." % back)
	_refresh()
	_cards[_selected].grab_focus()


func _disarm_refund() -> void:
	if _refund_armed:
		_refund_armed = false
		_refresh()


func _say(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_property(toast, "modulate:a", 0.0, 0.5)


func _pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(1.12, 1.12)
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _leave() -> void:
	SceneFader.change_scene(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()
