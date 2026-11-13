class_name OfferView
extends HBoxContainer
## Content of one UpgradeOffer, shared by the level-up cards and the chest
## rows: icon in a slot frame, name, badge (NEW / LV n / EVOLVED), level pips
## (current levels + the one this offer grants) and the description.
## Built in code; every child ignores the mouse so the parent button gets it.

var icon_frame := Panel.new()
var icon := TextureRect.new()
var title := Label.new()
var badge := PanelContainer.new()
var badge_label := Label.new()
var pips := LevelPips.new()
var desc := Label.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 14)

	icon_frame.custom_minimum_size = Vector2(52, 52)
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_frame.theme_type_variation = &"SlotPanel"
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_frame)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	title.theme_type_variation = &"GoldLabel"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(badge)
	badge_label.theme_type_variation = &"SmallLabel"
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(badge_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(spacer)
	pips.pip_scale = 3
	pips.centered = false
	pips.custom_minimum_size = Vector2(150, 15)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(pips)

	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 380
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(desc)


func show_offer(o: UpgradeOffer) -> void:
	icon.texture = o.icon
	title.text = o.title
	desc.text = o.description
	badge.visible = o.badge != ""
	badge_label.text = o.badge
	var evo := o.kind == UpgradeOffer.Kind.EVOLUTION
	match o.kind:
		UpgradeOffer.Kind.NEW_WEAPON, UpgradeOffer.Kind.NEW_PASSIVE:
			badge.theme_type_variation = &"BadgeNew"
		UpgradeOffer.Kind.EVOLUTION:
			badge.theme_type_variation = &"BadgeEvo"
		_:
			badge.theme_type_variation = &"BadgeLevel"
	icon_frame.theme_type_variation = &"SlotEvo" if evo else &"SlotPanel"
	pips.visible = o.max_level > 1
	pips.set_levels(o.next_level - 1, o.max_level, o.next_level)
