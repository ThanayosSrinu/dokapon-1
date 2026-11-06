class_name Expedition
extends RefCounted
## The rules of one trip, with no UI. One adventurer rolls, walks, lands, fights, eats and
## tries to get home. tools/sim_expedition.gd runs hundreds of these with no window, and
## E6 plays the same steps on screen.
##
## A day has steps, so a screen can show each one:
##     if trip.start_day():
##         trip.walk(trip.roll())
##         trip.land()
##         if trip.fight != null:
##             trip.finish_fight(await battle_screen.run(trip.fight))
##     trip.end_day()
## play_day() does all of that at once.
##
## The way home is the Portal, and only an exact landing counts. Walking across it does
## nothing. A roll starts from 0, and a 0 spends the day standing still.
##
## Every random result uses GameState.rng, so a seed replays the same trip.

enum Ending { NONE, HOME, BEATEN, STARVED }

## With no food left, this share of max HP is lost each day. This can kill, so a trip
## always ends, however badly the dice go.
const HUNGER_SHARE := 0.1
## The events that make sense for someone alone on an island, and how often they come.
const EVENT_WEIGHTS := {"festival": 3, "merchant": 3, "blessing": 3, "storm": 2, "ambush": 2, "portal": 2}

## Who is on the trip, and their sheet for the road.
var person: Adventurer
var player: PlayerData
var map: IslandMap
var brain: ExpeditionBrain
## The current day, starting at 1 once start_day() is called.
var day := 0
## Days of food still in the pack.
var food_left := 0
var ending := Ending.NONE
var space_id := -1
## The space stepped off last, or -1. It only matters during a walk.
var came_from := -1
## True once they have turned for home. This never turns off.
var heading_home := false
## A fight waiting to be played, or null.
var fight: Battle
## Each thing that happened: {"day", "kind", "text"}. The report is written from this.
var diary: Array[Dictionary] = []
## Space id -> how many times they landed there.
var visits := {}
## The most steps they ever stood from the Portal.
var furthest := 0
var fights := 0
var fights_won := 0
## Days lived with no food.
var hungry_days := 0
## Days lost trying to land: every day after the Portal first came in reach of the die
## on the way home, not counting the day they landed.
var landing_days := 0

# True once the Portal has been in reach of the die while heading home.
var _portal_in_reach := false
# What a chest holds while its guardian is fought.
var _prize: SpaceEffects.Result
# Space id -> the fewest steps from the Portal.
var _depth := {}


## Starts a trip by `new_person` to `stage`. A `seed_value` of 0 picks a new random seed.
func _init(new_person: Adventurer, stage: Stage, seed_value := 0) -> void:
	person = new_person
	map = IslandMap.open(stage.map_file)
	player = _make_player(person)
	food_left = stage.food_for(person)
	space_id = map.portal
	player.space_id = space_id
	_depth = map.steps_from(map.portal)
	GameState.start_expedition(player, seed_value, map.portal)
	brain = ExpeditionBrain.new(self)


func is_over() -> bool:
	return ending != Ending.NONE


## The gold that reaches the town. A defeat loses the lot (D2 in EXPEDITION_PLAN.md).
func gold_home() -> int:
	return player.gold if ending == Ending.HOME else 0


## Plays every step of one day.
func play_day() -> void:
	if start_day():
		walk(roll())
		land()
		if fight != null:
			auto_fight()
	end_day()


## Plays days until the trip ends.
func play_to_end() -> void:
	while not is_over():
		play_day()


## Morning: tidy the bag, eat, and decide where today leads. Returns true if they get to
## roll today. It is false when the trip ended or a snare is holding them.
func start_day() -> bool:
	day += 1
	GameState.day = day
	for item_name in CpuBrain.tidy(player):
		note("item", "%s uses a %s." % [player.player_name, item_name])
	_eat()
	if is_over():
		return false
	brain.plan_day()
	if heading_home:
		_portal_in_reach = _portal_in_reach or _can_reach_portal()
	if _stop_at_portal():
		return false
	if player.turns_to_skip > 0:
		player.turns_to_skip -= 1
		note("stuck", "%s can't move today." % player.player_name)
		return false
	return true


## Rolls the die. The result can be 0.
func roll() -> int:
	var steps := maxi(GameState.rng.randi_range(0, person.die_top) + player.take_roll_bonus(), 0)
	note("roll", "%s rolled %d." % [player.player_name, steps])
	return steps


## Walks `steps` spaces, choosing at each fork, and returns the ids stepped on in order.
## They may turn back at the start of a roll, the same as a token on the board.
func walk(steps: int) -> Array[int]:
	var path: Array[int] = []
	came_from = -1
	for steps_left in range(steps, 0, -1):
		var options := map.exits(space_id, came_from)
		var next := options[0]
		if options.size() > 1:
			next = brain.choose_path(options, space_id, steps_left)
		came_from = space_id
		space_id = next
		path.append(next)
	player.space_id = space_id
	furthest = maxi(furthest, depth_of(space_id))
	return path


## Does what the space under them does. Standing still after a 0 does nothing. Leaves
## `fight` set if a monster must be fought first.
func land() -> void:
	if came_from == -1:
		return
	visits[space_id] = visits.get(space_id, 0) + 1
	if _stop_at_portal():
		return
	match map.type_of(space_id):
		BoardNode.NodeType.GOLD:
			_take(SpaceEffects.gold_space(player))
		BoardNode.NodeType.ITEM:
			_take(SpaceEffects.item_space(player))
		BoardNode.NodeType.MAGIC:
			_take(SpaceEffects.magic_space(player))
		BoardNode.NodeType.SHRINE:
			_take(SpaceEffects.shrine_space(player))
		BoardNode.NodeType.TRAP:
			_take(SpaceEffects.trap_space(player))
		BoardNode.NodeType.EVENT:
			_take(Events.run(SpaceEffects.weighted_pick(EVENT_WEIGHTS), player, map.spaces()))
		BoardNode.NodeType.TREASURE:
			_open_chest()
		BoardNode.NodeType.BATTLE:
			var ids := Database.monster_ids_for_level(player.level)
			_meet(Database.get_monster(ids[GameState.rng.randi_range(0, ids.size() - 1)]))


## Plays `fight` with no screen.
func auto_fight() -> void:
	while not fight.is_over():
		var choice := fight.cpu_offense()
		var defense := fight.cpu_defense() if fight.needs_defense(choice) else Battle.Defense.NONE
		fight.resolve(choice, defense)
	finish_fight(fight.conclude())


## Settles `fight`. `lines` are what Battle.conclude() returned.
func finish_fight(lines: PackedStringArray) -> void:
	var won := fight.winner != null and fight.winner.player == player
	var lost := fight.loser != null and fight.loser.player == player
	fight = null
	fights += 1
	note("fight", " ".join(lines))
	if won:
		fights_won += 1
		if _prize != null:
			SpaceEffects.empty_chest(space_id)
			_prize.guardian = null
			_take(_prize)
	elif lost:
		ending = Ending.BEATEN
	_prize = null


## Evening: counts the day if it was lost trying to land.
func end_day() -> void:
	if _portal_in_reach and not is_over():
		landing_days += 1


## Adds a line to the diary.
func note(kind: String, text: String) -> void:
	diary.append({"day": day, "kind": kind, "text": text})


## The fewest steps from the Portal to space `id`.
func depth_of(id: int) -> int:
	return _depth[id]


# --- The steps of a day ------------------------------------------------------

func _eat() -> void:
	if food_left > 0:
		food_left -= 1
		return
	hungry_days += 1
	player.weak = true
	player.hp = maxi(player.hp - maxi(int(player.get_stat("max_hp") * HUNGER_SHARE), 1), 0)
	player.changed.emit()
	note("hunger", "%s has no food, and grows weak." % player.player_name)
	if player.hp == 0:
		ending = Ending.STARVED
		note("end", "%s collapses from hunger." % player.player_name)


# Ends the trip if they stand on the Portal and want to go home.
func _stop_at_portal() -> bool:
	if space_id != map.portal or not brain.wants_to_stop():
		return false
	ending = Ending.HOME
	note("end", "%s steps through the Portal with %d gold." % [player.player_name, player.gold])
	return true


func _can_reach_portal() -> bool:
	for steps in range(1, person.die_top + 1):
		if map.landings(space_id, -1, steps).has(map.portal):
			return true
	return false


func _open_chest() -> void:
	if not SpaceEffects.chest_is_full(space_id) or not CpuBrain.will_open_chest(player):
		return
	var chest := SpaceEffects.roll_chest(player)
	note("find", chest.text)
	if chest.guardian != null:
		_prize = chest
		_meet(chest.guardian)
	else:
		SpaceEffects.empty_chest(space_id)
		_take(chest)


func _meet(monster: MonsterData) -> void:
	note("fight", "%s meets a %s." % [player.player_name, monster.display_name])
	fight = Battle.new(Fighter.from_player(player), Fighter.from_monster(monster))


# Pays out what a space or an event did.
func _take(result: SpaceEffects.Result) -> void:
	note("find", result.text)
	player.add_gold(result.gold)
	for changed_player: PlayerData in result.gold_changes:
		changed_player.add_gold(result.gold_changes[changed_player])
	if result.item_id != "":
		_give(result.item_id)
	if result.warp_to >= 0:
		_move_to(result.warp_to)
	if result.to_castle:
		_move_to(map.portal)
		_stop_at_portal()
	if result.guardian != null:
		_meet(result.guardian)


# Pulls them to a space, which does nothing to them.
func _move_to(id: int) -> void:
	space_id = id
	came_from = -1
	player.space_id = id
	furthest = maxi(furthest, depth_of(id))


# Puts an item in the bag, or drops the cheapest thing to fit it if that's worth doing.
func _give(item_id: String) -> void:
	if player.add_item(item_id):
		return
	if SpaceEffects.cpu_make_room(player, item_id) != "":
		player.add_item(item_id)


static func _make_player(who: Adventurer) -> PlayerData:
	var made := PlayerData.new(who.display_name, Color.WHITE, true)
	made.character_sheet = who.sheet
	made.choose_class(who.class_id)
	while made.level < who.level:
		made.add_experience(made.exp_to_next_level())
	made.gold = 0
	made.heal_fully()
	return made
