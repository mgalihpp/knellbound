class_name Game
extends Node3D
## Root of a run. Owns the frame order so every system updates exactly once,
## in a known sequence, from one place:
##   player -> enemies + props move (behaviours; ranged enemies fire) + grid
##   -> contact damage -> enemy shots move + hit player -> weapons
##   -> projectiles move + hit -> remove dead (gems, pickup drops, kill
##   effects; elites/bosses chests; props drop a pickup) -> gems collect
##   -> pickups collect (effects) -> director (bosses, waves, events)
##   -> breakable spawner -> numbers + effects age -> GPU upload
##   -> camera/world -> HUD -> open level-up / chest if pending
##
## Screens are views: HUD, LevelUpScreen, ChestScreen, PauseMenu and
## GameOverScreen read Game / Player and emit signals; Game acts on them
## (unpause, restart, leave through SceneFader). Options live in the
## `Settings` autoload; Game applies the gameplay ones (screen shake,
## damage numbers) to CameraRig / DamageNumberField.
##
## Meta (SaveData autoload): the run uses `SaveData.selected_character()` and
## starts with the Reliquary upgrades applied to the player's Stats. When the
## run ends (death, or leaving it from the pause menu) `_end_run()` banks the
## coins once and keeps the RunReward for the summary. Sounds go through the
## `Audio` autoload (hooks below; Audio rate-limits them).
##
## Level-ups queue in `pending_levels`, chests in `pending_chests`; each screen
## is shown with the tree paused until its queue is empty (levels first).
## Hit-stop (`hit_stop()`) freezes the simulation for a few frames while the
## camera keeps shaking.

@export var character: CharacterData
@export var upgrade_pool: UpgradePool
@export var contact_shake := 0.35
## Chance (times LUCK) that a level-up offers a 4th choice.
@export var extra_choice_chance := 0.1
## A chest drops where every Nth enemy dies (0 = never). Elites and bosses
## always drop one.
@export var chest_every_kills := 0
## Chance (times LUCK) that a chest holds 5 / 3 items instead of 1.
@export var chest_five_chance := 0.04
@export var chest_three_chance := 0.12

@export_group("Pickups")
## The chest dropped by elites, bosses and `chest_every_kills`.
@export var chest_pickup: PickupData
## Rolled for every normal enemy kill (chance x LUCK).
@export var enemy_drops: DropTable
## Reach of a bomb pickup around the player (covers the screen).
@export var bomb_radius := 18.0
## Bosses take this fraction of the bomb damage.
@export var bomb_boss_fraction := 0.15
@export var bomb_knockback := 7.0

@export_group("Game feel")
@export var bomb_shake := 0.75
@export var bomb_hit_stop := 0.08
@export var boss_death_shake := 0.8
@export var boss_death_hit_stop := 0.16
## Crits on a boss freeze the game this long, at most once per cooldown.
@export var boss_crit_hit_stop := 0.035
@export var boss_crit_cooldown := 0.6
## A revival restores this fraction of max HP and shoves enemies away.
@export var revive_hp := 0.5
@export var revive_radius := 7.0
@export var revive_invuln := 2.0
## Kill effect size: elites and bosses burst bigger.
@export var elite_effect_scale := 1.6
@export var boss_effect_scale := 3.0

var elapsed := 0.0
var kills := 0
var is_over := false
var leveling := Leveling.new()
var pending_levels := 0
var rerolls_left := 0
var skips_left := 0
var banishes_left := 0
var banished: Array[Resource] = []
var pending_chests := 0
## Coins picked up this run (times GREED); banked into SaveData at the end.
var coins := 0
var revivals_left := 0
## Set once by _end_run(): what banking this run gave (summary screen).
var run_reward: RunReward
## Kills per enemy type this run (run summary: most slain).
var kills_by_type: Dictionary[EnemyData, int] = {}

var _hit_stop := 0.0
var _boss_crit_cd := 0.0
var _coin_frac := 0.0

@onready var player: Player = $Player
@onready var swarm: EnemySwarm = $EnemySwarm
@onready var gems: GemField = $GemField
@onready var pickups: PickupField = $PickupField
@onready var breakables: BreakableSpawner = $BreakableSpawner
@onready var numbers: DamageNumberField = $DamageNumberField
@onready var effects: EffectField = $EffectField
@onready var projectiles: ProjectileField = $ProjectileField
@onready var enemy_shots: EnemyShotField = $EnemyShotField
@onready var director: SpawnDirector = $SpawnDirector
@onready var camera_rig: CameraRig = $CameraRig
@onready var ground: MeshInstance3D = $Ground
@onready var decor: DecorField = $Decor
@onready var hud: Hud = $HUD
@onready var level_up: LevelUpScreen = $LevelUpScreen
@onready var chest_screen: ChestScreen = $ChestScreen
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var game_over: GameOverScreen = $GameOverScreen


func _ready() -> void:
	# Game must receive input while paused (to unpause); _process checks pause itself.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	var picked := SaveData.selected_character()
	if picked != null:
		character = picked
	player.setup(character)
	SaveData.apply_upgrades(player.stats)
	player.died.connect(_on_player_died)
	player.weapon_replaced.connect(projectiles.replace_source)
	swarm.enemy_died.connect(_on_enemy_died)
	swarm.numbers = numbers
	if OS.is_debug_build():
		hud.set_debug_pickups(debug_pickup_types())
	rerolls_left = player.stats.int_value(Stats.Id.REROLL)
	skips_left = player.stats.int_value(Stats.Id.SKIP)
	banishes_left = player.stats.int_value(Stats.Id.BANISH)
	revivals_left = player.stats.int_value(Stats.Id.REVIVAL)
	level_up.picked.connect(_on_offer_picked)
	level_up.reroll_requested.connect(_on_reroll)
	level_up.skip_requested.connect(_on_skip)
	level_up.banish_requested.connect(_on_banish)
	chest_screen.closed.connect(_on_chest_closed)
	pause_menu.resume_requested.connect(_set_paused.bind(false))
	pause_menu.restart_requested.connect(restart)
	pause_menu.quit_requested.connect(quit_to_title)
	game_over.retry_requested.connect(restart)
	game_over.title_requested.connect(quit_to_title)
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	camera_rig.snap_to(player.global_position)
	hud.refresh(self)
	Audio.play_music(&"night")


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _hit_stop > 0.0:
		_hit_stop -= delta
		camera_rig.tick(delta, player.global_position)
		return
	var dt := minf(delta, 1.0 / 20.0)
	elapsed += dt
	_boss_crit_cd -= dt

	player.tick(dt)
	Audio.listener = player.pos2
	swarm.tick(dt, player.pos2, enemy_shots)

	var contact := swarm.collide_player(player.pos2, player.radius)
	contact = maxf(contact, enemy_shots.tick(dt, player.pos2, player.radius))
	if contact > 0.0 and not player.is_dead:
		var before := player.hp
		player.take_damage(contact)
		if player.hp < before:
			camera_rig.add_shake(contact_shake)
			numbers.add(player.pos2, before - player.hp, DamageNumberField.HURT)
			Audio.play_sfx(&"player_hurt")

	for w in player.weapons:
		w.tick(dt, self)
	projectiles.view_rect = camera_rig.ground_view_rect()
	projectiles.tick(dt, swarm, player.pos2)
	if swarm.boss_crit:
		swarm.boss_crit = false
		if _boss_crit_cd <= 0.0:
			_boss_crit_cd = boss_crit_cooldown
			hit_stop(boss_crit_hit_stop)

	# One hit sound per frame at most (Audio rate-limits it further).
	if swarm.hits_this_frame > 0:
		swarm.hits_this_frame = 0
		Audio.play_sfx(&"hit")
	swarm.flush_dead()
	var magnet := player.stats.value(Stats.Id.MAGNET)
	var xp := gems.tick(dt, player.pos2, magnet)
	if xp > 0.0:
		Audio.play_sfx(&"gem")
		pending_levels += leveling.add(xp * player.stats.value(Stats.Id.GROWTH))
	var got := pickups.tick(dt, player.pos2, magnet)
	for k in got.size():
		_on_pickup(pickups.types[got[k]], pickups.collected_at[k])
	director.tick(dt, self)
	breakables.tick(dt, self)
	numbers.tick(dt)
	effects.tick(dt)
	swarm.upload()
	gems.upload()
	pickups.upload()
	projectiles.upload()
	enemy_shots.upload()
	effects.upload()
	numbers.upload()

	camera_rig.tick(dt, player.global_position)
	ground.position = Vector3(player.pos2.x, 0.0, player.pos2.y)
	decor.tick(player.pos2)
	hud.refresh(self)

	if is_over:
		return
	if pending_levels > 0:
		get_tree().paused = true
		Audio.play_sfx(&"level_up")
		_offer_choices()
	elif pending_chests > 0:
		get_tree().paused = true
		_open_chest()


func _unhandled_input(event: InputEvent) -> void:
	if level_up.is_open or chest_screen.is_open or SceneFader.busy:
		return
	if event.is_action_pressed(&"pause") and not is_over and not pause_menu.is_open:
		get_viewport().set_input_as_handled()
		_set_paused(true)
	elif event.is_action_pressed(&"restart") and pause_menu.is_open:
		restart()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				director.spawn_ring(self, 500)
			KEY_F2:
				swarm.clear()
			KEY_F3:
				gems.attract_all()
			KEY_F4:
				pending_levels += leveling.add(leveling.xp_to_next - leveling.xp)
			KEY_F5:
				debug_max_weapons()
			KEY_F6:
				pickups.drop(player.pos2 + player.aim * 2.0, chest_pickup)
			KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var list := debug_pickup_types()
				var n: int = event.keycode - KEY_4
				if n < list.size():
					pickups.drop(player.pos2 + player.aim * 2.0, list[n])
			KEY_B:
				debug_breakables()
			KEY_F7:
				debug_evolution_passives()
			KEY_PAGEUP:
				director.skip_to(self, elapsed + 60.0)
			KEY_1:
				director.skip_to(self, 10.0 * 60.0 - 3.0)
			KEY_2:
				director.skip_to(self, 20.0 * 60.0 - 3.0)
			KEY_3:
				director.skip_to(self, director.table.final_minute * 60.0 - 3.0)
			KEY_E:
				director.spawn_elite(self, director.table.entries[0].enemies[0])
			KEY_H:
				hud.toggle_debug_keys()


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	if on:
		pause_menu.open(self)
	else:
		pause_menu.close()


func restart() -> void:
	_end_run()
	SceneFader.reload()


func quit_to_title() -> void:
	_end_run()
	SceneFader.change_scene("res://scenes/title.tscn")


## Banks the run into SaveData exactly once (death, restart or quitting).
func _end_run() -> RunReward:
	if run_reward == null:
		run_reward = SaveData.bank_run(coins, elapsed, kills, director.final_phase)
	return run_reward


func _apply_settings() -> void:
	camera_rig.shake_enabled = Settings.screen_shake
	numbers.enabled = Settings.damage_numbers


## Debug: the pickups keys 4..9 drop (every type except the chest, F6).
func debug_pickup_types() -> Array[PickupData]:
	var out: Array[PickupData] = []
	for t in pickups.types:
		if t != chest_pickup:
			out.append(t)
	return out


## Debug: one of each breakable on a small arc ahead of the player.
func debug_breakables() -> void:
	var n := breakables.types.size()
	for k in n:
		var a := player.aim.angle() + (k - (n - 1) * 0.5) * 0.45
		breakables.spawn(self, breakables.types[k], player.pos2 + Vector2.from_angle(a) * 4.0)


## Debug: every weapon in the pool (while slots last) at max level.
func debug_max_weapons() -> void:
	for data in upgrade_pool.weapons:
		if upgrade_pool.owns_line(player, data) and player.weapon_for(data) == null:
			continue  # already evolved
		var w := player.weapon_for(data)
		if w == null:
			if player.weapons.size() >= Player.MAX_WEAPONS:
				continue
			w = player.add_weapon(data)
		w.level = data.max_level


## Debug: the passive each evolution needs, for weapons the player holds
## (while passive slots last).
func debug_evolution_passives() -> void:
	for evo in upgrade_pool.evolutions:
		if player.weapon_for(evo.base) == null or player.passives.has(evo.passive):
			continue
		if player.passives.size() >= Player.MAX_PASSIVES:
			return
		player.add_passive(evo.passive)


## Level the current screen is for: with several queued, the oldest first.
func level_being_chosen() -> int:
	return leveling.level - pending_levels + 1


func _offer_choices() -> void:
	var n := 3
	if randf() < extra_choice_chance * player.stats.value(Stats.Id.LUCK):
		n = 4
	var offers := upgrade_pool.roll(player, banished, n)
	level_up.present(offers, level_being_chosen(), rerolls_left, skips_left, banishes_left)


func _finish_level() -> void:
	pending_levels -= 1
	if pending_levels > 0:
		_offer_choices()
	else:
		level_up.close()
		get_tree().paused = false


func _on_offer_picked(offer: UpgradeOffer) -> void:
	offer.apply(player)
	_finish_level()


func _on_reroll() -> void:
	if rerolls_left > 0:
		rerolls_left -= 1
		_offer_choices()


func _on_skip() -> void:
	if skips_left > 0:
		skips_left -= 1
		_finish_level()


func _on_banish(offer: UpgradeOffer) -> void:
	if banishes_left > 0 and offer.item != null:
		banishes_left -= 1
		banished.append(offer.item)
		_offer_choices()


func _on_enemy_died(at: Vector2, data: EnemyData, flags: int) -> void:
	var luck := player.stats.value(Stats.Id.LUCK)
	if flags & EnemySwarm.PROP:
		effects.spawn(at, data.death_effect, 1.3)
		effects.spawn(at, EffectField.Fx.SMOKE, 1.0)
		var loot := (data as BreakableData).drops
		if loot != null:
			var item := loot.roll(luck)
			if item != null:
				pickups.drop(at, item)
		return
	kills += 1
	kills_by_type[data] = kills_by_type.get(data, 0) + 1
	Audio.play_sfx(&"kill", at)
	var xp := data.xp_value
	if flags & EnemySwarm.ELITE:
		xp *= director.table.elite_xp_mult
	gems.drop(at, xp)
	var fx_scale := data.scale * (2.0 if data.large_sprite else 1.0)
	if flags & EnemySwarm.BOSS:
		fx_scale *= boss_effect_scale
		effects.spawn(at, EffectField.Fx.EXPLOSION, 5.0, 0.6)
		camera_rig.add_shake(boss_death_shake)
		hit_stop(boss_death_hit_stop)
	elif flags & EnemySwarm.ELITE:
		fx_scale *= elite_effect_scale
	effects.spawn(at, data.death_effect, fx_scale)
	if flags & (EnemySwarm.ELITE | EnemySwarm.BOSS):
		pickups.drop(at, chest_pickup)
	elif chest_every_kills > 0 and kills % chest_every_kills == 0:
		pickups.drop(at, chest_pickup)
	elif enemy_drops != null:
		var item := enemy_drops.roll(luck)
		if item != null:
			pickups.drop(at, item)


func _on_pickup(data: PickupData, at: Vector2) -> void:
	effects.spawn(at, data.collect_effect, 1.0, 0.35, 0.2)
	match data.effect:
		PickupData.Effect.CHEST:
			pending_chests += 1
			Audio.play_sfx(&"pickup")
		PickupData.Effect.HEAL:
			var before := player.hp
			player.heal(player.max_hp * data.amount)
			numbers.add(player.pos2, player.hp - before, DamageNumberField.HEAL)
			Audio.play_sfx(&"heal")
		PickupData.Effect.MAGNET:
			gems.attract_all()
			pickups.attract_all()
			Audio.play_sfx(&"pickup")
		PickupData.Effect.BOMB:
			detonate_bomb(player.pos2, data.amount * director.hp_scale())
		PickupData.Effect.COIN:
			add_coins(data.amount)
			Audio.play_sfx(&"coin")


## Run coins, scaled by GREED; fractions carry over to the next pickup.
func add_coins(amount: float) -> void:
	_coin_frac += amount * player.stats.value(Stats.Id.GREED)
	var whole := floori(_coin_frac + 0.0001)
	coins += whole
	_coin_frac -= whole


## Blessed bomb: `damage` to every enemy and prop within bomb_radius (bosses
## take bomb_boss_fraction of it), clears enemy shots, big blast + shake.
func detonate_bomb(at: Vector2, damage: float) -> void:
	for j in swarm.query_circle(at, bomb_radius):
		var d := damage * (bomb_boss_fraction if swarm.flags[j] & EnemySwarm.BOSS else 1.0)
		var push := (swarm.pos[j] - at).normalized() * bomb_knockback
		swarm.damage_enemy(j, d, push)
	enemy_shots.clear()
	effects.spawn(at, EffectField.Fx.EXPLOSION, 7.0, 0.55)
	for k in 12:
		var p := at + Vector2.from_angle(randf() * TAU) * randf_range(2.0, bomb_radius * 0.55)
		effects.spawn(p, EffectField.Fx.EXPLOSION, randf_range(2.0, 3.5), randf_range(0.35, 0.55))
	camera_rig.add_shake(bomb_shake)
	hit_stop(bomb_hit_stop)
	Audio.play_sfx(&"bomb")


## Freezes the simulation for `seconds` (rendering and camera shake go on).
func hit_stop(seconds: float) -> void:
	_hit_stop = maxf(_hit_stop, seconds)


## Rolls and applies one chest's rewards, then shows them.
func _open_chest() -> void:
	var rewards: Array[UpgradeOffer] = []
	for k in chest_item_count():
		var offer := upgrade_pool.chest_reward(player, banished)
		if offer == null:
			break
		offer.apply(player)
		rewards.append(offer)
	if rewards.is_empty():
		var heal := UpgradeOffer.for_heal(upgrade_pool.heal_icon)
		heal.apply(player)
		rewards.append(heal)
	hud.refresh(self)  # the tree is paused: show the new loadout behind the screen
	Audio.play_sfx(&"chest_open")
	chest_screen.present(rewards)


func chest_item_count() -> int:
	var luck := player.stats.value(Stats.Id.LUCK)
	var r := randf()
	if r < chest_five_chance * luck:
		return 5
	if r < (chest_five_chance + chest_three_chance) * luck:
		return 3
	return 1


func _on_chest_closed() -> void:
	pending_chests -= 1
	if pending_chests > 0:
		_open_chest()
	else:
		chest_screen.close()
		get_tree().paused = false


func _on_player_died() -> void:
	if revivals_left > 0:
		_revive()
		return
	is_over = true
	get_tree().paused = true
	_end_run()
	hud.refresh(self)
	Audio.stop_music(0.6)
	Audio.play_sfx(&"game_over")
	game_over.present(self)


## Spends a REVIVAL charge: back on your feet, nearby enemies and shots blown away.
func _revive() -> void:
	revivals_left -= 1
	player.revive(revive_hp, revive_invuln)
	for j in swarm.query_circle(player.pos2, revive_radius):
		if not swarm.flags[j] & (EnemySwarm.BOSS | EnemySwarm.PROP):
			swarm.knock[j] = (swarm.pos[j] - player.pos2).normalized() * swarm.max_knock
	enemy_shots.clear()
	effects.spawn(player.pos2, EffectField.Fx.HEAL, 5.0, 0.7)
	effects.spawn(player.pos2, EffectField.Fx.SPARKLE, 4.0, 0.6)
	camera_rig.add_shake(bomb_shake * 0.6)
	hit_stop(bomb_hit_stop)
	Audio.play_sfx(&"revive")
