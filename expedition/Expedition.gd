class_name Expedition
extends RefCounted
## The rules of one trip, with no UI. One adventurer rolls, walks, lands, fights, eats and
## tries to get home. The player plays a trip through ExpeditionScreen, which runs the steps
## of a day one at a time and asks for each choice:
##     if trip.start_day():
##         trip.begin_walk(trip.roll())
##         while trip.steps_left > 0:
##             trip.step_to(<one of trip.next_spaces()>)
##         trip.land()
##         if trip.fight != null:
##             trip.finish_fight(await battle_screen.run(trip.fight))
##         if trip.may_go_home() and <they want to>:
##             trip.go_home()
##     trip.end_day()
##
## With `by_hand` off, an ExpeditionBrain makes those choices, for the sim and the tests.
## walk() and play_day() are its shortcuts. The bot never runs in the game.
##
## The way home is the Portal, and only an exact landing counts. Walking across it does
## nothing. A roll starts from 0, and a 0 lands on the space they stand on, except on the
## Portal on the first turn, so that nobody goes home by accident.
##
## A roll must be walked in full, and a walk can't turn back. A dead end takes the exact
## number, and if no road is long enough the walk is void: they stay put and lose the turn.
##
## Every random result uses GameState.rng, so a seed replays the same trip.

enum Ending { NONE, HOME, BEATEN, STARVED, WARPED }

## How much of the gold on an island is really theirs to bring home.
const GOLD_SHARE := 0.5
## How much of their HP and MP a Shrine, a Magic space or a blessing gives back.
const REST_SHARE := 0.4
## Food counts as short when it covers less than this many days for each day the walk
## home should take. The walk is an average, so 1.0 would run out on about half of trips.
const FOOD_CAUTION := 1.3
## Below this share of HP, with nothing in the bag to heal with, they are badly hurt.
const HURT_SHARE := 0.3
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

## Who is on the trip, and their sheet for the road.
var person: Adventurer
var player: PlayerData
var map: IslandMap
## Who makes the choices when nobody does by hand, or null if the player does.
var brain: ExpeditionBrain
## The current day, starting at 1 once start_day() is called.
var day := 0
## Days of food still in the pack.
var food_left := 0
## True when the player makes every choice, and false when the brain does.
var by_hand := false
var ending := Ending.NONE
var space_id := -1
## The space stepped off last, or -1. It only matters during a walk.
var came_from := -1
## Steps of the walk under way still to be taken.
var steps_left := 0
## True once the bot has been told to land on the Portal, which ends the trip. A player is
## asked at the Portal instead.
var heading_home := false
## On this day the bot heads home, or never if it is 0, so tools can replay a known trip.
var recall_day := 0
## A fight waiting to be played, or null.
var fight: Battle
## An item found with the bag full, waiting for the player to choose, or "".
var found_item := ""
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
## Days the bot lost trying to land: every day after the Portal first came in reach of the
## die on the way home, not counting the day they landed.
var landing_days := 0

# False if today's roll doesn't count as landing anywhere.
var _lands := true
# True once the Portal has been in reach of the die while heading home.
var _portal_in_reach := false
# Their level when today's fight began.
var _level_before_fight := 1
# What a chest holds while its guardian is fought.
var _prize: SpaceEffects.Result
# Space id -> the fewest steps from the Portal.
var _depth := {}


## Starts a trip by `new_person` to `stage`. A `seed_value` of 0 picks a new random seed.
## With `hand` on, the player makes every choice and no brain is made.
func _init(new_person: Adventurer, stage: Stage, seed_value := 0, hand := false) -> void:
	person = new_person
	by_hand = hand
	map = IslandMap.open(stage.map_file)
	player = _make_player(person, hand)
	food_left = stage.food_for(person)
	space_id = map.portal
	player.space_id = space_id
	_depth = map.steps_from(map.portal)
	GameState.start_expedition(player, seed_value, map.portal)
	if not by_hand:
		brain = ExpeditionBrain.new(self)


func is_over() -> bool:
	return ending != Ending.NONE


## Sets the bot on the way home. It counts from this moment, and uses no dice.
func head_home() -> void:
	heading_home = true
	if brain != null:
		brain.refresh()


## The gold that reaches the town. A defeat loses the lot (D2 in EXPEDITION_PLAN.md).
func gold_home() -> int:
	return player.gold if ending == Ending.HOME else 0


## How long food lasts, in words, such as "1 turn" or "3 turns".
static func turns_words(count: int) -> String:
	return "1 turn" if count == 1 else "%d turns" % count


## How many days the walk home should take from where they stand, on average. From the
## Portal itself, that means going out and landing on it again.
func days_home() -> float:
	if space_id == map.portal:
		return map.days_around(map.portal, person.die_top)
	return map.days_to(map.portal, person.die_top)[space_id]


## True when the food left may not last the walk home. The first day never counts.
func food_is_short() -> bool:
	return day > 1 and food_left <= days_home() * FOOD_CAUTION


## True when a bad fight could end the trip and nothing in the bag can help.
func badly_hurt() -> bool:
	if day <= 1 or player.hp >= player.get_stat("max_hp") * HURT_SHARE:
		return false
	for id in player.inventory:
		if Database.get_item(id).heal_hp > 0:
			return false
	return true


## True when they have landed on the Portal, so going home is on offer.
func may_go_home() -> bool:
	return not is_over() and _lands and space_id == map.portal


## Steps through the Portal. Only an exact landing gets here: see may_go_home().
func go_home() -> void:
	if may_go_home():
		_step_through()


## Ends the trip where it stands, because the player gave it up. This is a failed trip: the
## Warp Stone saves the adventurer and nothing else. Only the Portal brings anything home.
## A trip that has already ended stays as it ended.
func warp_home() -> void:
	if is_over():
		return
	ending = Ending.WARPED
	note("warp", "%s used the Warp Stone." % player.player_name)


## Plays every step of one day, with the brain's choices.
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
	if not by_hand:
		_bot_morning()
	_eat()
	if is_over():
		return false
	if not by_hand:
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


## Starts a walk of `steps` spaces, and returns true if they can set out. They may turn
## back at the start of a roll, but not after that. If no road is `steps` long, the walk is
## void: they stay put and the turn is lost.
func begin_walk(steps: int) -> bool:
	came_from = -1
	steps_left = steps
	_lands = steps > 0 or day > 1 or space_id != map.portal
	if map.landings(space_id, -1, steps).is_empty():
		_lands = false
		steps_left = 0
		note("stuck", "%s can't walk %d spaces, and loses the turn." % [player.player_name, steps])
		return false
	return true


## Where the next step of the walk may go. More than one means a fork.
func next_spaces() -> Array[int]:
	return map.ways(space_id, came_from, steps_left)


## Every space the walk under way can still end on.
func landing_spaces() -> Array[int]:
	return map.landings(space_id, came_from, steps_left)


## Takes one step of the walk, onto one of next_spaces().
func step_to(next: int) -> void:
	came_from = space_id
	space_id = next
	steps_left -= 1
	if steps_left == 0:
		player.space_id = space_id
		furthest = maxi(furthest, depth_of(space_id))


## Walks `steps` spaces with the brain choosing at each fork, and returns the ids stepped on
## in order. If no road is `steps` long, the path is empty.
func walk(steps: int) -> Array[int]:
	var path: Array[int] = []
	if not begin_walk(steps):
		return path
	while steps_left > 0:
		var options := next_spaces()
		step_to(options[0] if options.size() == 1 else brain.choose_path(options, space_id, steps_left))
		path.append(space_id)
	return path


## Does what the space under them does, even if a 0 left them on it. Leaves `fight` set
## if a monster must be fought first.
func land() -> void:
	if not _lands:
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


## Plays `fight` with no screen, as the bot would.
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


# What the bot does first thing, before it eats.
func _bot_morning() -> void:
	if day == recall_day:
		head_home()
	for item_name in CpuBrain.tidy(player):
		note("item", "%s uses a %s." % [player.player_name, item_name])


# Ends the bot's trip if it stands on the Portal and was told to come home.
func _stop_at_portal() -> bool:
	if space_id != map.portal or not heading_home:
		return false
	_step_through()
	return true


func _step_through() -> void:
	ending = Ending.HOME
	note("end", "%s steps through the Portal with %d gold." % [player.player_name, player.gold])


func _can_reach_portal() -> bool:
	for steps in range(1, person.die_top + 1):
		if map.landings(space_id, -1, steps).has(map.portal):
			return true
	return false


func _open_chest() -> void:
	if not SpaceEffects.chest_is_full(space_id):
		return
	if not by_hand and not CpuBrain.will_open_chest(player):
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


## The player has them use `item_id`. Returns false if it would do nothing.
func use_by_hand(item_id: String) -> bool:
	if not player.use_item(item_id):
		return false
	note("item", "%s uses a %s." % [player.player_name, Database.get_item(item_id).display_name])
	return true


## The player has them wear `item_id`, and what it replaces goes in the bag.
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


# Puts an item in the bag. With the bag full, the player chooses what to do, and the bot
# drops the cheapest thing if that's worth doing.
func _give(item_id: String) -> void:
	if player.add_item(item_id):
		return
	if by_hand:
		found_item = item_id
	elif SpaceEffects.cpu_make_room(player, item_id) != "":
		player.add_item(item_id)


static func _make_player(who: Adventurer, hand: bool) -> PlayerData:
	var made := PlayerData.new(who.display_name, Color.WHITE, not hand)
	made.character_sheet = who.sheet
	made.choose_class(who.class_id)
	while made.level < who.level:
		made.add_experience(made.exp_to_next_level())
	made.gold = 0
	made.gold_share = GOLD_SHARE
	made.rest_share = REST_SHARE
	made.heal_fully()
	return made
