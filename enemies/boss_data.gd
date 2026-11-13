class_name BossData
extends EnemyData
## A boss is an ordinary EnemySwarm slot (weapons hit it like any enemy) with
## behavior SCRIPTED; a BossBrain owned by SpawnDirector moves it through
## `pattern`: chase -> telegraph -> attack -> chase -> next attack...

enum Attack { DASH, RADIAL, SUMMON }

## Shown above the HUD health bar.
@export var title := ""
## Attack order, looped. Stored as int in .tres.
@export var pattern: Array[Attack] = [Attack.DASH, Attack.RADIAL, Attack.SUMMON]
## Seconds walking at the player between attacks.
@export var chase_time := 2.5
## Seconds standing still and flashing before each attack.
@export var telegraph_time := 0.7

@export_group("Dash")
@export var dash_speed := 15.0
@export var dash_time := 0.55

@export_group("Radial")
## Shots per ring (uses shot_row / shot_speed / shot_damage / shot_size).
@export var radial_count := 16
@export var radial_volleys := 3
@export var radial_interval := 0.35

@export_group("Summon")
@export var summon: EnemyData
@export var summon_count := 10
@export var summon_radius := 3.0
