class_name TitleScreen
extends Control
## Main scene. Start (-> hunter select -> run) / Reliquary (permanent shop) /
## Options / Quit, the banked coins top right and lifetime records at the
## bottom (both read from SaveData). Scene changes go through SceneFader.

const SELECT_SCENE := "res://scenes/character_select.tscn"
const SHOP_SCENE := "res://scenes/shop.tscn"

@onready var menu: Control = %Menu
@onready var logo: Control = %Logo
@onready var start_button: Button = %StartButton
@onready var shop_button: Button = %ShopButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var options: OptionsPanel = %Options
@onready var coins_label: Label = %CoinsLabel
@onready var records: Label = %Records


func _ready() -> void:
	get_tree().paused = false
	Audio.play_music(&"title")
	options.visible = false
	start_button.pressed.connect(SceneFader.change_scene.bind(SELECT_SCENE))
	shop_button.pressed.connect(SceneFader.change_scene.bind(SHOP_SCENE))
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(get_tree().quit)
	options.closed.connect(_hide_options)
	for b in [start_button, shop_button, options_button, quit_button]:
		b.mouse_entered.connect(b.grab_focus)
	quit_button.visible = not OS.has_feature("web")
	coins_label.text = str(SaveData.coins)
	records.text = records_text()
	start_button.grab_focus()
	# Logo drifts in.
	logo.modulate.a = 0.0
	menu.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(logo, "modulate:a", 1.0, 0.6).set_delay(0.15)
	t.tween_property(menu, "modulate:a", 1.0, 0.4).set_delay(0.5)


static func records_text() -> String:
	if SaveData.runs == 0:
		return ""
	return "Longest night %s  ·  %d slain  ·  %d hunt%s  ·  %d dawn%s" % [
		Hud.fmt_time(SaveData.best_time), SaveData.total_kills,
		SaveData.runs, "" if SaveData.runs == 1 else "s",
		SaveData.nights_survived, "" if SaveData.nights_survived == 1 else "s"]


func _show_options() -> void:
	menu.visible = false
	options.open()


func _hide_options() -> void:
	options.visible = false
	menu.visible = true
	options_button.grab_focus()
