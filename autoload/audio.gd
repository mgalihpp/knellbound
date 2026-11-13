extends Node
## Autoload `Audio`: sound effects and music by id (data/sound_bank.tres).
##
## SFX play on a fixed pool of VOICES AudioStreamPlayers on the SFX bus.
## Three limits keep mass combat cheap and listenable:
##   - per id `min_interval` (cooldown between starts, checked first: O(1)),
##   - per id `max_concurrent` voices,
##   - the global pool; when full, a sound takes the oldest voice of an
##     equal or lower priority, else it is dropped.
## Positional plays fade with distance from `listener` (Game sets it to the
## player every frame) and are skipped past HEAR_RADIUS.
##
## Music: two players on the BGM bus, crossfaded by play_music().
## UI sounds are hooked globally: every BaseButton plays `ui_select` when
## pressed (unless it has the meta `no_press_sound`), every button / slider
## `ui_move` when it gains focus, and
## ui_cancel over a focused control plays `ui_back`.

const BANK: SoundBank = preload("res://data/sound_bank.tres")
const VOICES := 24
## World units; positional sounds farther than this from the listener are skipped.
const HEAR_RADIUS := 24.0
## Extra attenuation at HEAR_RADIUS (linear in between).
const FAR_DB := -10.0
const SILENT_DB := -60.0
## No UI focus sounds this long after a scene change (initial grab_focus).
const UI_QUIET_MS := 250

var listener := Vector2.ZERO
## Counters for tests / the debug panel.
var played := 0
var dropped := 0

var _defs: Dictionary[StringName, SoundDef] = {}
var _music_defs: Dictionary[StringName, SoundDef] = {}
var _voices: Array[AudioStreamPlayer] = []
var _voice_def: Array[SoundDef] = []
var _voice_start := PackedInt64Array()
## Earliest usec each id may start again.
var _next_ok: Dictionary[StringName, int] = {}
var _music: Array[AudioStreamPlayer] = []
var _music_idx := 0
var _music_id: StringName = &""
var _music_tween: Tween
var _ui_quiet_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for d in BANK.sfx:
		_defs[d.id] = d
	for d in BANK.music:
		_music_defs[d.id] = d
	for k in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_voices.append(p)
		_voice_def.append(null)
	_voice_start.resize(VOICES)
	for k in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"BGM"
		m.volume_db = SILENT_DB
		add_child(m)
		_music.append(m)
	get_tree().node_added.connect(_on_node_added)
	get_tree().scene_changed.connect(_quiet_ui)
	_quiet_ui()


## Plays sound `id`. `at` = world position (x, z) for distance fade, or
## Vector2.INF for a flat sound. `pitch_jitter` < 0 uses the SoundDef's.
func play_sfx(id: StringName, at: Vector2 = Vector2.INF, pitch_jitter: float = -1.0) -> void:
	var now := Time.get_ticks_usec()
	if now < _next_ok.get(id, 0):
		dropped += 1
		return
	var def: SoundDef = _defs.get(id)
	if def == null or def.streams.is_empty():
		return
	var vol := def.volume_db
	if at.is_finite():
		var d := at.distance_to(listener)
		if d > HEAR_RADIUS:
			return
		vol += FAR_DB * d / HEAR_RADIUS
	var same := 0
	var free := -1
	var steal := -1
	for k in VOICES:
		if _voices[k].playing:
			var other := _voice_def[k]
			if other == def:
				same += 1
			elif other.priority <= def.priority and (steal < 0 or _voice_start[k] < _voice_start[steal]):
				steal = k
		elif free < 0:
			free = k
	var k := free if free >= 0 else steal
	if same >= def.max_concurrent or k < 0:
		dropped += 1
		return
	_next_ok[id] = now + int(def.min_interval * 1.0e6)
	var p := _voices[k]
	p.stream = def.streams[randi() % def.streams.size()]
	p.volume_db = vol
	var j := def.pitch_jitter if pitch_jitter < 0.0 else pitch_jitter
	p.pitch_scale = 1.0 + randf_range(-j, j)
	p.play()
	_voice_def[k] = def
	_voice_start[k] = now
	played += 1


## Voices playing right now (all ids, or one id).
func active_voices(id: StringName = &"") -> int:
	var n := 0
	for k in VOICES:
		if _voices[k].playing and (id == &"" or _voice_def[k].id == id):
			n += 1
	return n


## Crossfades to music `id` over `fade` seconds (no-op if already playing).
func play_music(id: StringName, fade: float = 1.2) -> void:
	if id == _music_id:
		return
	var def: SoundDef = _music_defs.get(id)
	if def == null or def.streams.is_empty():
		return
	_music_id = id
	var old := _music[_music_idx]
	_music_idx = 1 - _music_idx
	var nw := _music[_music_idx]
	nw.stream = def.streams[0]
	nw.volume_db = SILENT_DB
	nw.play()
	_crossfade(nw, def.volume_db, old, fade)


func stop_music(fade: float = 1.0) -> void:
	_music_id = &""
	_crossfade(null, 0.0, _music[_music_idx], fade)


func _crossfade(into: AudioStreamPlayer, into_db: float, out: AudioStreamPlayer, fade: float) -> void:
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel()
	if into != null:
		_music_tween.tween_method(_set_linear.bind(into), db_to_linear(into.volume_db),
			db_to_linear(into_db), fade)
	if out != null and out.playing:
		_music_tween.tween_method(_set_linear.bind(out), db_to_linear(out.volume_db), 0.0, fade)
		_music_tween.chain().tween_callback(out.stop)


func _set_linear(v: float, p: AudioStreamPlayer) -> void:
	p.volume_db = linear_to_db(maxf(v, 0.0001))


# ---------------------------------------------------------------- UI hooks

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(_on_pressed.bind(node))
	if node is BaseButton or node is Range:
		node.focus_entered.connect(_on_focus)


## Buttons with the meta `no_press_sound` play their own sound (shop, select).
func _on_pressed(button: BaseButton) -> void:
	if not button.has_meta(&"no_press_sound"):
		play_sfx(&"ui_select")


func _on_focus() -> void:
	if Time.get_ticks_msec() >= _ui_quiet_until:
		play_sfx(&"ui_move")


func _quiet_ui() -> void:
	_ui_quiet_until = Time.get_ticks_msec() + UI_QUIET_MS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and get_viewport().gui_get_focus_owner() != null:
		play_sfx(&"ui_back")
