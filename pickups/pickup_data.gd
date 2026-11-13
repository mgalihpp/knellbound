class_name PickupData
extends Resource
## One kind of world pickup (data/pickups/*.tres). PickupField draws and
## collects it; Game._on_pickup() applies `effect`. A new pickup = a .tres +
## a row in art/sprites/pickups.png (+ an Effect branch if it does something new)
## + an entry in PickupField.types (main.tscn) and in a DropTable.

## Stored as int in .tres: append only.
enum Effect {
	CHEST,   ## opens the chest screen (Game.pending_chests)
	HEAL,    ## heals `amount` x max HP
	MAGNET,  ## every gem (and magnetic pickup) flies to the player
	BOMB,    ## `amount` x wave HP scale to every enemy in Game.bomb_radius (bosses less)
	COIN,    ## +`amount` coins (Game.coins, kept by the meta shop in phase 8)
}

@export var id: StringName
@export var display_name := ""
@export var effect := Effect.HEAL
@export var amount := 0.0
## Row in art/sprites/pickups.png (4 frames: shine / spin).
@export var sprite_row := 0
@export var scale := 1.0
## Relative weight inside a DropTable.
@export var drop_weight := 1.0
## Weight is multiplied by LUCK (rare finds get likelier).
@export var luck_weighted := false
## Pulled in by the player's magnet radius like gems, and by MAGNET pickups.
@export var magnetic := false
## Row in art/sprites/effects.png played where it is collected (-1 = none).
@export var collect_effect := 4
