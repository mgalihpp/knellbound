class_name Player
extends Node3D
## Gameplay position is `pos2` on the (x, z) plane; the node transform only
## mirrors it for rendering. Weapons are children of $Weapons.

signal died
signal health_changed(hp: float, max_hp: float)
## An evolution swapped `old` for `new` in the same slot; `old` is freed
## at the end of the frame (Game moves its live projectiles over to `new`).
signal weapon_replaced(old: Weapon, new: Weapon)

const MAX_WEAPONS := 6
const MAX_PASSIVES := 6

@export var radius := 0.45
@export var invuln_time := 0.5
@export var walk_anim_fps := 10.0

var character: CharacterData
var stats := Stats.new()
var pos2 := Vector2.ZERO
var hp := 100.0
var max_hp: float:
	get:
		return stats.value(Stats.Id.MAX_HP)
var facing := 1.0
## Last non-zero move direction (unit), for weapons aimed "where you face".
var aim := Vector2.RIGHT
var weapons: Array[Weapon] = []
var passives: Dictionary[PassiveData, int] = {}
var is_dead := false

var _invuln := 0.0
var _anim_t := 0.0
var _known_max_hp := 0.0

@onready var sprite: Sprite3D = $Sprite
@onready var weapons_root: Node3D = $Weapons
## Small HP bar under the sprite (view only, refreshed by Hud).
@onready var hp_bar: WorldHpBar = $HpBar


func setup(c: CharacterData) -> void:
	character = c
	stats.set_base(Stats.Id.MAX_HP, c.max_hp)
	stats.set_base(Stats.Id.MOVE_SPEED, c.move_speed)
	for m in c.stat_modifiers:
		stats.add_modifier(m)
	hp = max_hp
	_known_max_hp = max_hp
	stats.changed.connect(_on_stats_changed)
	if c.sprite_sheet:
		sprite.texture = c.sprite_sheet
	if c.starting_weapon:
		add_weapon(c.starting_weapon)
	health_changed.emit(hp, max_hp)


func add_weapon(data: WeaponData) -> Weapon:
	var w := _make_weapon(data)
	weapons.append(w)
	return w


## Replaces evo.base with evo.result in the same slot (see EvolutionData).
func evolve(evo: EvolutionData) -> Weapon:
	var old := weapon_for(evo.base)
	if old == null:
		return null
	var w := _make_weapon(evo.result)
	w.damage_dealt = old.damage_dealt  # the run summary counts the whole line
	weapons[weapons.find(old)] = w
	weapons_root.move_child(w, old.get_index())
	weapon_replaced.emit(old, w)
	old.queue_free()
	return w


func _make_weapon(data: WeaponData) -> Weapon:
	var w: Weapon = data.scene.instantiate()
	w.data = data
	w.stats = stats
	weapons_root.add_child(w)
	return w


func weapon_for(data: WeaponData) -> Weapon:
	for w in weapons:
		if w.data == data:
			return w
	return null


func add_passive(p: PassiveData) -> void:
	passives[p] = passives.get(p, 0) + 1
	for m in p.modifiers:
		stats.add_modifier(m)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)


func tick(dt: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	pos2 += input * stats.value(Stats.Id.MOVE_SPEED) * dt
	position = Vector3(pos2.x, 0.0, pos2.y)

	var regen := stats.value(Stats.Id.RECOVERY)
	if regen > 0.0 and not is_dead:
		hp = minf(max_hp, hp + regen * dt)

	if input != Vector2.ZERO:
		aim = input.normalized()
	if input.x > 0.1:
		facing = 1.0
	elif input.x < -0.1:
		facing = -1.0
	sprite.flip_h = facing < 0.0
	if input != Vector2.ZERO:
		_anim_t += dt * walk_anim_fps
		sprite.frame = int(_anim_t) % sprite.hframes
	else:
		_anim_t = 0.0
		sprite.frame = 0

	if _invuln > 0.0:
		_invuln -= dt
		var blink := int(_invuln * 20.0) % 2 == 0
		sprite.modulate = Color(1.0, 0.35, 0.35) if blink else Color.WHITE
	else:
		sprite.modulate = Color.WHITE


func take_damage(amount: float) -> void:
	if is_dead or _invuln > 0.0 or amount <= 0.0:
		return
	hp = maxf(0.0, hp - maxf(1.0, amount - stats.value(Stats.Id.ARMOR)))
	_invuln = invuln_time
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		is_dead = true
		died.emit()


## Back from death (a REVIVAL charge) with `hp_fraction` of max HP.
func revive(hp_fraction: float, invuln: float) -> void:
	is_dead = false
	hp = max_hp * hp_fraction
	_invuln = invuln
	health_changed.emit(hp, max_hp)


## Raising max HP heals by the same amount; lowering it clamps.
func _on_stats_changed() -> void:
	var m := max_hp
	if m > _known_max_hp:
		hp += m - _known_max_hp
	hp = minf(hp, m)
	_known_max_hp = m
	health_changed.emit(hp, max_hp)
