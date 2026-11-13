class_name SoundDef
extends Resource
## One named sound in the SoundBank (data/sound_bank.tres). Gameplay asks the
## `Audio` autoload for an id; the limits here keep a 1000-enemy fight from
## stacking hundreds of voices.

@export var id: StringName
## One is picked at random per play (variations). Music uses the first.
@export var streams: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.5) var volume_db := 0.0
## Voices of this id playing at once; further plays are dropped.
@export_range(1, 32) var max_concurrent := 4
## Seconds after a play before this id can start again (dropped meanwhile).
@export_range(0.0, 1.0, 0.005) var min_interval := 0.03
## Random pitch spread (0.05 = +-5%) unless the caller passes its own.
@export_range(0.0, 0.5, 0.01) var pitch_jitter := 0.05
## With every voice busy, a sound may take over the oldest voice of an
## equal or lower priority (UI and stingers > pickups > hits).
@export var priority := 0
