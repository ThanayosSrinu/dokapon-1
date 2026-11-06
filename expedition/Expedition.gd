class_name Expedition
extends RefCounted
## The rules of one trip, with no UI. One adventurer rolls, walks, lands, fights, eats and
## tries to get home. tools/sim_expedition.gd runs hundreds of these with no window, and
## ExpeditionScreen plays the same steps on screen.
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
## The lord can give an order at any moment with give_order(). It counts from that moment,
## and nothing in the dice changes because of it. Nobody comes home without the Return
## order. They warn when food runs low or a wound is bad, then go on until something stops
## them, so timing that order is the lord's job.
##
## Every random result uses GameState.rng, so a seed replays the same trip.

## Says a line out loud. The same line goes in the diary as kind "say".
signal said(line: String)

enum Ending { NONE, HOME, BEATEN, STARVED, WARPED }
## ROAM: go where the road looks best. HOME: land on the Portal. ZONE: go to order_zone,
## then look around in it until told otherwise.
enum Order { ROAM, HOME, ZONE }

## How much of the gold on an island is really theirs to bring home.
const GOLD_SHARE := 0.5
## How much of their HP and MP a Shrine, a Magic space or a blessing gives back.
const REST_SHARE := 0.4
const SAY_BETTER := "My lord, this %s looks better than what I wear."
## With no food left, this share of max HP is lost each day. This can kill, so a trip
## always ends, however badly the dice go.
const HUNGER_SHARE := 0.1
## The events that make sense for someone alone on an island, and how often they come.
const EVENT_WEIGHTS := {"festival": 3, "merchant": 3, "blessing": 3, "storm": 2, "ambush": 2, "portal": 2}
## How much a won fight counts as a moment for the report, per gold it paid. The closer
## the call, the more it counts, up to twice this.
const FIGHT_MOMENT := 1.0
## A level gained counts as this much gold in the report.
const LEVEL_MOMENT := 150
## A win with this share of HP gone is worth telling as a close call.
const CLOSE_CALL := 0.7
## After this many days lost trying to land, they say so.
const SO_CLOSE_DAYS := 3

const SAY_HOME := "Yes, my lord. Heading home."
const SAY_ROAM := "Yes, my lord. I'll look around."
const SAY_ZONE := "Yes, my lord. On to %s."
const SAY_THERE := "%s at last."
const SAY_SO_CLOSE := "The Portal is so close..."
const SAY_CLOSE_CALL := "That was too close!"

## Who is on the trip, and their sheet for the road.
var person: Adventurer
var player: PlayerData
var map: IslandMap
var brain: ExpeditionBrain
## The current day, starting at 1 once start_day() is called.
var day := 0
## Days of food still in the pack.
var food_left := 0
## True when the lord chooses what is worn, so the bot only points out what is better.
var by_hand := false
var ending := Ending.NONE
var space_id := -1
## The space stepped off last, or -1. It only matters during a walk.
var came_from := -1
## What the lord told them to do, or ROAM if nobody did.
var order := Order.ROAM
## The zone of a ZONE order, as the map lists it, or empty.
var order_zone := {}
## On this day they are called home before they set out, or never if it is 0. It stands in
## for a player, so tools can replay a trip with the Return order on a known day.
var recall_day := 0
## The day they first stood in order_zone, or 0 if they have not.
var zone_reached_day := 0
## True once they have said they should come home, for food or for a wound.
var asked_home := false
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
## The trip's finest moment, for the report: {"day", "text", "worth"}. Empty if nothing
## good happened. See _remember().
var best_moment := {}
## Days lost trying to land: every day after the Portal first came in reach of the die
## on the way home, not counting the day they landed.
var landing_days := 0

# True once the Portal has been in reach of the die while heading home.
var _portal_in_reach := false
# Their level when today's fight began.
var _level_before_fight := 1
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


## Tells them what to do, from this moment. A trip that has ended takes no orders.
func give_order(new_order: Order, zone_id := "") -> void:
	if is_over():
		return
	order = new_order
	order_zone = map.zone(zone_id) if new_order == Order.ZONE else {}
	zone_reached_day = 0
	match new_order:
		Order.HOME:
			note("recall", "You called %s home." % player.player_name)
			say(SAY_HOME)
		Order.ZONE:
			say(SAY_ZONE % order_zone["name"])
			_check_zone()
		Order.ROAM:
			say(SAY_ROAM)
	brain.refresh()


## Says `line` out loud.
func say(line: String) -> void:
	note("say", line)
	said.emit(line)


## The gold that reaches the town. A defeat loses the lot (D2 in EXPEDITION_PLAN.md).
func gold_home() -> int:
	return player.gold if ending == Ending.HOME else 0


## Ends the trip where it stands, because the lord gave it up. This is a failed trip: the
## Warp Stone saves the adventurer and nothing else. Only the Portal brings anything home.
## A trip that has already ended stays as it ended.
func warp_home() -> void:
	if is_over():
		return
	ending = Ending.WARPED
	note("warp", "%s used the Warp Stone." % player.player_name)


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
	if day == recall_day:
		give_order(Order.HOME)
	for item_name in CpuBrain.tidy(player, not by_hand):
		note("item", "%s uses a %s." % [player.player_name, item_name])
	_eat()
	if is_over():
		return false
	brain.plan_day()
	if order == Order.HOME:
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
	_check_zone()
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
	var monster := fight.opponent.monster
	var level_before := _level_before_fight
	var won := fight.winner != null and fight.winner.player == player
	var lost := fight.loser != null and fight.loser.player == player
	fight = null
	fights += 1
	note("fight", " ".join(lines))
	if won:
		fights_won += 1
		_remember_win(monster, level_before)
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
		if landing_days == SO_CLOSE_DAYS:
			say(SAY_SO_CLOSE)


## Adds a line to the diary. The Portal took the castle's place, so older lines shared
## with the board game say so here.
func note(kind: String, text: String) -> void:
	diary.append({"day": day, "kind": kind, "text": text.replace("the castle", "the Portal")})


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


# Marks the day they reach the zone they were sent to.
func _check_zone() -> void:
	if order != Order.ZONE or zone_reached_day > 0 or not order_zone["spaces"].has(space_id):
		return
	zone_reached_day = maxi(day, 1)
	say(SAY_THERE % order_zone["name"])


# Ends the trip if they stand on the Portal and were told to come home.
func _stop_at_portal() -> bool:
	if space_id != map.portal or order != Order.HOME:
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
	if chest.guardian != null:
		note("find", chest.text)
		_prize = chest
		_meet(chest.guardian)
	else:
		SpaceEffects.empty_chest(space_id)
		_take(chest)


func _meet(monster: MonsterData) -> void:
	note("meet", "%s meets a %s." % [player.player_name, monster.display_name])
	fight = Battle.new(Fighter.from_player(player), Fighter.from_monster(monster))
	fight.carried_to = "the Portal"
	_level_before_fight = player.level


# Keeps `text` as the trip's finest moment if it beats the one so far.
func _remember(text: String, worth: float) -> void:
	if worth > 0.0 and worth > best_moment.get("worth", 0.0):
		best_moment = {"day": day, "text": text, "worth": worth}


func _remember_win(monster: MonsterData, level_before: int) -> void:
	if monster == null:
		return
	var hurt := 1.0 - float(player.hp) / player.get_stat("max_hp")
	var worth := monster.gold_reward * FIGHT_MOMENT * (1.0 + hurt)
	var levels := player.level - level_before
	worth += levels * LEVEL_MOMENT
	var text := "%s beat a %s" % [player.player_name, monster.display_name]
	if hurt > CLOSE_CALL:
		text += " with only %d HP left" % player.hp
		say(SAY_CLOSE_CALL)
	if levels > 0:
		text += " and reached level %d" % player.level
	_remember(text + ".", worth)


# Pays out what a space or an event did.
func _take(result: SpaceEffects.Result) -> void:
	note("find", result.text)
	_remember(result.text.replace("the castle", "the Portal"), _worth_of(result))
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


func _worth_of(result: SpaceEffects.Result) -> float:
	var worth := float(result.gold)
	if result.item_id != "":
		worth += Database.get_item(result.item_id).price
	return worth


## The lord has them use `item_id`. Returns false if it would do nothing.
func use_by_hand(item_id: String) -> bool:
	if not player.use_item(item_id):
		return false
	note("item", "%s uses a %s." % [player.player_name, Database.get_item(item_id).display_name])
	return true


## The lord has them wear `item_id`, and what it replaces goes in the bag.
func wear_by_hand(item_id: String) -> bool:
	if not player.equip(item_id):
		return false
	note("item", "%s puts on the %s." % [player.player_name, Database.get_item(item_id).display_name])
	return true


# Pulls them to a space, which does nothing to them.
func _move_to(id: int) -> void:
	space_id = id
	came_from = -1
	player.space_id = id
	furthest = maxi(furthest, depth_of(id))
	_check_zone()


# Puts an item in the bag, or drops the cheapest thing to fit it if that's worth doing.
func _give(item_id: String) -> void:
	if not player.add_item(item_id):
		if SpaceEffects.cpu_make_room(player, item_id) == "":
			return
		player.add_item(item_id)
	var item := Database.get_item(item_id)
	if by_hand and item.kind != ItemData.Kind.CONSUMABLE and CpuBrain.is_upgrade(player, item_id):
		say(SAY_BETTER % item.display_name)


static func _make_player(who: Adventurer) -> PlayerData:
	var made := PlayerData.new(who.display_name, Color.WHITE, true)
	made.character_sheet = who.sheet
	made.choose_class(who.class_id)
	while made.level < who.level:
		made.add_experience(made.exp_to_next_level())
	made.gold = 0
	made.gold_share = GOLD_SHARE
	made.rest_share = REST_SHARE
	made.heal_fully()
	return made
