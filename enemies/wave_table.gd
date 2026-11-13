class_name WaveTable
extends Resource
## The whole run's spawn schedule (data/waves/*.tres), read by SpawnDirector.
## `entries` = continuous streams, `events` = one-shot spawns sorted by
## minute, `final_minute` = when the night ends and `reaper` comes.

@export var entries: Array[WaveEntry] = []
@export var events: Array[WaveEvent] = []
## Every enemy's HP is multiplied by (1 + hp_growth_per_minute * minute)
## on top of the entry / event hp_mult.
@export var hp_growth_per_minute := 0.12
## Elite = this HP multiplier, size and XP on top of the base enemy.
@export var elite_hp_mult := 25.0
@export var elite_scale := 1.6
@export var elite_xp_mult := 10.0
@export var final_minute := 30.0
## Spawned at final_minute (after every other enemy is removed), then again
## every `reaper_interval` seconds.
@export var reaper: EnemyData
@export var reaper_interval := 60.0


func hp_scale(minute: float) -> float:
	return 1.0 + hp_growth_per_minute * minute
