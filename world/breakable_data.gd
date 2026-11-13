class_name BreakableData
extends EnemyData
## A destructible prop (lantern, brazier, crate, grave cross). It lives in
## EnemySwarm as a PROP slot with behavior STATIC, so every weapon (aura,
## projectiles, orbit, ground zones) hits it through the same queries as
## enemies, with the same hit flash and damage numbers. It deals no contact
## damage, is not pushed, gives no XP and does not count as a kill; on death
## it plays `death_effect` (its debris, the "broken" frames) and drops one
## pickup from `drops` (BreakableSpawner keeps a few around the player).

@export var drops: DropTable
