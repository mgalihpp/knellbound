extends CanvasLayer
## Autoload `SceneFader`: every scene change goes through here so it fades to
## black, swaps the scene (unpausing the tree), then fades back in. Input is
## blocked while a fade runs, so a double press cannot start two changes.

const FADE_OUT := 0.22
const FADE_IN := 0.3

var busy := false

var _rect := ColorRect.new()


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect.color = Color(0.02, 0.01, 0.04, 1.0)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	# The first scene fades in from black too.
	_fade_in()


func change_scene(path: String) -> void:
	if busy:
		return
	busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_rect, "color:a", 1.0, FADE_OUT)
	await t.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	# change_scene_to_file swaps at the end of the frame: wait for the new one.
	await get_tree().scene_changed
	_fade_in()


func reload() -> void:
	change_scene(get_tree().current_scene.scene_file_path)


func _fade_in() -> void:
	busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.color.a = 1.0
	var t := create_tween()
	t.tween_property(_rect, "color:a", 0.0, FADE_IN)
	await t.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


func _input(event: InputEvent) -> void:
	# Swallow input while fading so nothing reacts mid-transition.
	if busy and not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()
