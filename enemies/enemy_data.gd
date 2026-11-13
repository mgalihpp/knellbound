class_name EnemyData
extends Resource
## One enemy archetype. Values are copied into EnemySwarm's packed arrays on
## spawn (behaviour parameters into per-type arrays), so the hot loop never
## touches this Resource.

## How EnemySwarm.tick moves the enemy. Stored as int in .tres: append only.
enum Behavior {
	CHASE,     ## straight at the player
	WEAVE,     ## chase with a sideways sine wobble (bats)
	RANGED,    ## hold `preferred_range`, strafe, fire enemy shots
	DRIFT,     ## fixed direction set at spawn, despawns after its life (rings, lines)
	SCRIPTED,  ## velocity written from outside each frame (BossBrain)
	STATIC,    ## never moves, never pushed (breakable props, see BreakableData)
}

@export var id: StringName
@export var display_name := ""
@export var behavior := Behavior.CHASE
## Row in the enemy sheet: art/sprites/enemies.png (18 px cells), or
## art/sprites/enemies_large.png (34 px cells) when `large_sprite` is on.
@export var sprite_row := 0
@export var large_sprite := false
@export var max_hp := 10.0
@export var move_speed := 2.0
@export var contact_damage := 5.0
## Collision radius on the gameplay plane (world units).
@export var radius := 0.4
## Multiplier on the billboard size (1.0 = one cell at 16 px per unit).
@export var scale := 1.0
@export_range(0.0, 1.0) var knockback_resist := 0.0
@export var xp_value := 1.0
## Row in art/sprites/effects.png played where it dies (EffectField.Fx).
@export var death_effect := 1

@export_group("Weave")
## Sideways speed as a fraction of move_speed.
@export var weave_amount := 0.8
## Wobbles per second.
@export var weave_frequency := 1.5

@export_group("Ranged")
@export var preferred_range := 7.0
## Seconds between shots (each enemy starts at a random point of the cycle).
@export var fire_interval := 2.5
@export var shot_speed := 6.0
@export var shot_damage := 8.0
## Row in art/sprites/enemy_shots.png.
@export var shot_row := 0
@export var shot_size := 0.8

@export_group("Drift")
## Seconds before a drifting enemy despawns (no drop). 0 = computed by the spawner.
@export var drift_life := 0.0
