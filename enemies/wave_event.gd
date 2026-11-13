class_name WaveEvent
extends Resource
## A one-shot spawn at `minute` (fires once when the run clock passes it).

## Stored as int in .tres: append only.
enum Kind {
	RING,   ## `count` enemies on a circle of `radius` around the player, closing in
	LINE,   ## a column of `count` enemies crossing the screen in a straight line
	BURST,  ## `count` enemies packed in one arc at `radius`, from a random side
	ELITE,  ## one elite `enemy` (bigger, glowing, high HP, drops a chest)
	BOSS,   ## `enemy` must be a BossData; gets a BossBrain and the HUD bar
}

@export var minute := 1.0
@export var kind := Kind.RING
@export var enemy: EnemyData
@export var count := 24
@export var radius := 15.0
@export var hp_mult := 1.0
