class_name CharacterSelect
extends Control
## Hunter select (scenes/character_select.tscn), between the title and a run.
## View only: unlock state, buying and the selection live in SaveData. One
## card per hunter (SaveData.CATALOG order) with a walking portrait; the
## focused one fills the detail panel. Pressing an unlocked hunter selects it
## and starts the run; pressing a BUY hunter recruits it if affordable.
## Locked hunters show as silhouettes with their unlock condition + progress.

const TITLE_SCENE := "res://scenes/title.tscn"
const RUN_SCENE := "res://scenes/main.tscn"
const CELL := 18
const WALK_FPS := 8.0
const LOCKED_TINT := Color(0.08, 0.06, 0.12, 1.0)

var _cards: Array[Button] = []
## One AtlasTexture per card + the detail portrait, all stepped together.
var _atlases: Array[AtlasTexture] = []
var _card_name: Array[Label] = []
var _card_note: Array[Label] = []
var _card_portrait: Array[TextureRect] = []
var _detail_atlas := AtlasTexture.new()
var _selected := 0
var _anim_t := 0.0
var _starting := false

@onready var list: VBoxContainer = %List
@onready var coins_label: Label = %CoinsLabel
@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %Name
@onready var epithet: Label = %Epithet
@onready var desc: Label = %Desc
@onready var weapon_icon: TextureRect = %WeaponIcon
@onready var weapon_name: Label = %WeaponName
@onready var weapon_desc: Label = %WeaponDesc
@onready var traits: Label = %Traits
@onready var lock_box: Control = %LockBox
@onready var lock_label: Label = %LockLabel
@onready var lock_bar: ProgressBar = %LockBar
@onready var lock_progress: Label = %LockProgress
@onready var action_button: Button = %ActionButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	Audio.play_music(&"title")
	var chars := SaveData.CATALOG.characters
	for k in chars.size():
		list.add_child(_make_card(k))
	portrait.texture = _detail_atlas
	action_button.set_meta(&"no_press_sound", true)
	action_button.pressed.connect(func() -> void: _choose(_selected))
	back_button.pressed.connect(SceneFader.change_scene.bind(TITLE_SCENE))
	for b: Button in [action_button, back_button]:
		b.mouse_entered.connect(b.grab_focus)
	_refresh()
	var start := maxi(0, chars.find(SaveData.selected_character()))
	_cards[start].grab_focus()
	_select(start)


func _make_card(k: int) -> Button:
	var c := SaveData.CATALOG.characters[k]
	var card := Button.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size = Vector2(400, 88)
	card.set_meta(&"no_press_sound", true)
	card.pressed.connect(_choose.bind(k))
	card.focus_entered.connect(_select.bind(k))
	card.mouse_entered.connect(card.grab_focus)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -14
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var atlas := AtlasTexture.new()
	atlas.atlas = c.sprite_sheet
	atlas.region = Rect2(0, 0, CELL, CELL)
	_atlases.append(atlas)
	var face := TextureRect.new()
	face.texture = atlas
	face.custom_minimum_size = Vector2(72, 72)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var title := Label.new()
	title.text = c.display_name
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	var note := Label.new()
	note.theme_type_variation = &"SmallLabel"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(note)
	var weapon := TextureRect.new()
	weapon.texture = c.starting_weapon.icon
	weapon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	weapon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(weapon)

	_cards.append(card)
	_card_name.append(title)
	_card_note.append(note)
	_card_portrait.append(face)
	return card


func _process(delta: float) -> void:
	_anim_t += delta * WALK_FPS
	var x := float((int(_anim_t) % 4) * CELL)
	for a in _atlases:
		a.region.position.x = x
	_detail_atlas.region.position.x = x


func _refresh() -> void:
	coins_label.text = str(SaveData.coins)
	var chars := SaveData.CATALOG.characters
	for k in chars.size():
		var c := chars[k]
		var open := SaveData.is_unlocked(c)
		_card_portrait[k].modulate = Color.WHITE if open else LOCKED_TINT
		_card_name[k].theme_type_variation = &"GoldLabel" if c == SaveData.selected_character() else &""
		_card_name[k].modulate = Color.WHITE if open else Color(0.6, 0.56, 0.68)
		if open:
			_card_note[k].text = c.epithet
		elif c.unlock == CharacterData.Unlock.BUY:
			_card_note[k].text = "Recruit · %d coins" % c.unlock_value
		else:
			_card_note[k].text = "Locked"
	_show_detail()


func _select(k: int) -> void:
	_selected = k
	_show_detail()


func _show_detail() -> void:
	var c := SaveData.CATALOG.characters[_selected]
	var open := SaveData.is_unlocked(c)
	_detail_atlas.atlas = c.sprite_sheet
	_detail_atlas.region = Rect2(_detail_atlas.region.position.x, 0, CELL, CELL)
	portrait.modulate = Color.WHITE if open else LOCKED_TINT
	name_label.text = c.display_name
	epithet.text = c.epithet
	desc.text = c.description
	weapon_icon.texture = c.starting_weapon.icon
	weapon_name.text = c.starting_weapon.display_name
	weapon_desc.text = c.starting_weapon.description
	traits.text = traits_text(c)
	lock_box.visible = not open
	if not open:
		lock_label.text = c.unlock_text()
		var p := SaveData.unlock_progress(c)
		lock_bar.value = p.x / maxf(1.0, p.y)
		lock_progress.text = _progress_text(c, p)
	if open:
		action_button.text = "Begin the Hunt"
	elif c.unlock == CharacterData.Unlock.BUY:
		action_button.text = "Recruit  (%d)" % c.unlock_value
	else:
		action_button.text = "Locked"
	action_button.disabled = not open and not SaveData.can_buy_character(c)


## "Max HP 140  ·  Speed 4.4" + one line of the character's modifiers.
static func traits_text(c: CharacterData) -> String:
	var lines := ["Max HP %d  ·  Move speed %.1f" % [roundi(c.max_hp), c.move_speed]]
	var parts: PackedStringArray = []
	for m in c.stat_modifiers:
		parts.append(m.describe())
	if not parts.is_empty():
		lines.append(", ".join(parts))
	return "\n".join(lines)


static func _progress_text(c: CharacterData, p: Vector2) -> String:
	if c.unlock == CharacterData.Unlock.SURVIVE_SECONDS:
		return "Best: %s / %s" % [Hud.fmt_time(p.x), Hud.fmt_time(p.y)]
	return "%d / %d" % [int(p.x), int(p.y)]


func _choose(k: int) -> void:
	if _starting:
		return
	_selected = k
	var c := SaveData.CATALOG.characters[k]
	if SaveData.is_unlocked(c):
		_starting = true
		SaveData.select_character(c)
		Audio.play_sfx(&"ui_select")
		SceneFader.change_scene(RUN_SCENE)
	elif SaveData.buy_character(c):
		Audio.play_sfx(&"unlock")
		_refresh()
		_cards[k].grab_focus()
	else:
		Audio.play_sfx(&"deny")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		SceneFader.change_scene(TITLE_SCENE)
