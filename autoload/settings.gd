extends Node
## Autoload `Settings`: player options. Stored inside the save file
## (`SaveData.options`, so SaveData must load first in the autoload list).
## UI screens write through the setters; Game reads `screen_shake` and
## `damage_numbers` on start and on `changed`. Volumes drive the Master / SFX /
## BGM buses (default_bus_layout.tres).

signal changed

const BUSES := [&"Master", &"SFX", &"BGM"]

## Linear 0..1, indexed like BUSES.
var volumes: Array[float] = [1.0, 0.8, 0.7]
var screen_shake := true
var damage_numbers := true
var fullscreen := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply()


func set_volume(bus: int, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	_apply_bus(bus)
	_save_and_emit()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_save_and_emit()


func set_damage_numbers(on: bool) -> void:
	damage_numbers = on
	_save_and_emit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()
	_save_and_emit()


func _save_and_emit() -> void:
	var o := SaveData.options
	for k in BUSES.size():
		o["volume_" + String(BUSES[k]).to_lower()] = volumes[k]
	o["screen_shake"] = screen_shake
	o["damage_numbers"] = damage_numbers
	o["fullscreen"] = fullscreen
	SaveData.queue_save()
	changed.emit()


func _load() -> void:
	var o := SaveData.options
	for k in BUSES.size():
		var v: Variant = o.get("volume_" + String(BUSES[k]).to_lower())
		if v is float or v is int:
			volumes[k] = clampf(v, 0.0, 1.0)
	screen_shake = _flag(o, "screen_shake", screen_shake)
	damage_numbers = _flag(o, "damage_numbers", damage_numbers)
	fullscreen = _flag(o, "fullscreen", fullscreen)


static func _flag(o: Dictionary, key: String, fallback: bool) -> bool:
	var v: Variant = o.get(key)
	return v if v is bool else fallback


func _apply() -> void:
	for k in BUSES.size():
		_apply_bus(k)
	_apply_window()


func _apply_bus(k: int) -> void:
	var idx := AudioServer.get_bus_index(BUSES[k])
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(volumes[k]))
		AudioServer.set_bus_mute(idx, volumes[k] <= 0.001)


func _apply_window() -> void:
	# The embedded game window in the editor cannot go fullscreen.
	if Engine.is_embedded_in_editor() or DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
