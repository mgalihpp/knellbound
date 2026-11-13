class_name MetaCatalog
extends Resource
## Everything the meta layer knows about (data/meta.tres): the hunters in
## select-screen order and the Reliquary upgrades in shop order. SaveData
## stores ids only, so entries can be reordered or added freely.

@export var characters: Array[CharacterData] = []
@export var upgrades: Array[MetaUpgrade] = []
## Picked when the save names no (or an unknown) hunter.
@export var default_character: CharacterData


func character(id: StringName) -> CharacterData:
	for c in characters:
		if c.id == id:
			return c
	return null


func upgrade(id: StringName) -> MetaUpgrade:
	for u in upgrades:
		if u.id == id:
			return u
	return null
