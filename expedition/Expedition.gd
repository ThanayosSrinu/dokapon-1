class_name Expedition
extends RefCounted
## The rules of one trip, with no UI. One adventurer rolls, walks, lands, fights, eats and
## tries to get home. The player plays a trip through ExpeditionScreen, which runs the steps
## of a day one at a time and asks for each choice:
##     if trip.start_day():
##         if <they want to camp>:
##             trip.camp()
##         else:
##             trip.begin_walk(trip.roll())
##             while trip.steps_left > 0:
##                 trip.step_to(<one of trip.next_spaces()>)
##             trip.land()
##             if trip.fight != null:
##                 trip.finish_fight(await battle_screen.run(trip.fight))
##             if trip.may_go_home() and <they want to>:
##                 trip.go_home()
##     trip.end_day()
##
## With `by_hand` off, an ExpeditionBrain makes those choices, for the sim and the tests.
## walk() and play_day() are its shortcuts. The bot never runs in the game.
##
## The way home is the Portal, and only an exact landing counts. Walking across it does
## nothing, unless the town has the Portal Beacon (`beacon`): then the Portal is one of
## the landings of any roll that can walk across it, and a walk that picks it stops there. A roll starts from 0, and a 0 lands on the space they stand on, except on the
## Portal on the first turn, so that nobody goes home by accident.
##
## A roll must be walked in full, and a walk can't turn back. A dead end takes the exact
## number, and if no road is long enough the walk is void: they stay put and lose the turn.
##
## The board is made for each trip: the stage says how many monsters and chests there are,
## and the seed says where. A monster and a chest both take an exact landing: walking past
## one does nothing (D18). A beaten monster or an opened chest leaves an empty space. A monster
## stays if the fight ends any other way.
##
## The player picks where a roll lands from landing_spaces(), and path_to() finds the way.
##
## Every random result uses GameState.rng, so a seed replays the same trip.

## A monster was beaten or a chest was opened on space `id`, which is now empty.
signal space_emptied(id: int)
## The materials bag changed.
signal materials_changed

enum Ending { NONE, HOME, BEATEN, STARVED, WARPED }

## How much of the gold on an island is really theirs to bring home.
const GOLD_SHARE := 0.5
## How much of their HP and MP a day at camp gives back.
const CAMP_SHARE := 0.2
## Food counts as short when it covers less than this many days for each day the walk
## home should take. The walk is an average, so 1.0 would run out on about half of trips.
const FOOD_CAUTION := 1.3
## Below this share of HP, with nothing in the bag to heal with, they are badly hurt.
const HURT_SHARE := 0.3
## With no food left, this share of max HP is lost each day. This can kill, so a trip
## always ends, however badly the dice go.
const HUNGER_SHARE := 0.1
## How much a won fight counts as a moment for the report, per gold it paid. The closer
## the call, the more it counts, up to twice this.
const FIGHT_MOMENT := 1.0
## A level gained counts as this much gold in the report.
const LEVEL_MOMENT := 150
## A win with this share of HP gone is worth telling as a close call.
const CLOSE_CALL := 0.7
## How many materials the materials bag holds. It is apart from the bag for items.
const MATERIAL_ROOM := 8
## The chance that a beaten monster leaves a material behind. Every chest holds one.
const MATERIAL_DROP_CHANCE := 0.5

## Who is on the trip, and their sheet for the road.
var person: Adventurer
var player: PlayerData
var map: IslandMap
## Who makes the choices when nobody does by hand, or null if the player does.
var brain: ExpeditionBrain
## The current day, starting at 1 once start_day() is called.
var day := 0
## Their level on setting out.
var level_at_start := 1
## Days of food they set out with.
var food_taken := 0
## Days on the town's calendar this trip takes, whatever happens on it. See Stage.days.
var trip_days := 0
## Days of food still in the pack.
var food_left := 0
## True when the player makes every choice, and false when the brain does.
var by_hand := false
## True with the Portal Beacon. See the top of this file.
var beacon := false
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
## The materials they carry, one id for each, at most MATERIAL_ROOM.
var materials: Array[String] = []
## A material found with the materials bag full, waiting for the player to choose, or "".
var found_material := ""
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
# True if they ate this morning.
var _fed_today := false
# Space id -> what stands on it on this trip, as a BoardNode.NodeType.
var _board := {}
# The spaces that hold a monster right now, as keys.
var _monsters := {}
# Their level when today's fight began.
var _level_before_fight := 1
# What a chest holds while its guardian is fought.
var _prize: SpaceEffects.Result
# Space id -> the fewest steps from the Portal.
var _depth := {}
# Where the walk under way was chosen to end, or -1.
var _aim := -1


## Starts a trip by `new_person` to `stage`. A `seed_value` of 0 picks a new random seed.
## With `hand` on, the player makes every choice and no brain is made. `food` is the days of
## food bought, or -1 for all they can carry. `kept` is who they are on the roster, for the
## level, gear and moves they have from earlier trips.
func _init(new_person: Adventurer, stage: Stage, seed_value := 0, hand := false, food := -1, kept: Member = null) -> void:
	person = new_person
	by_hand = hand
	map = IslandMap.open(stage.map_file)
	trip_days = stage.days
	player = make_player(person, hand, kept)
	level_at_start = player.level
	food_taken = person.food_at(0 if kept == null else kept.level) if food < 0 else food
	food_left = food_taken
	space_id = map.portal
	player.space_id = space_id
	_depth = map.steps_from(map.portal)
	GameState.start_expedition(player, seed_value, map.portal)
	_set_up_board(stage)
	if not by_hand:
		brain = ExpeditionBrain.new(self)


func is_over() -> bool:
	return ending != Ending.NONE


## What stands on space `id` on this trip, as a BoardNode.NodeType.
func type_at(id: int) -> BoardNode.NodeType:
	return _board[id]


## True if a day at camp would do something, and today's food was there to pay for it.
func can_camp() -> bool:
	if is_over() or not _fed_today:
		return false
	return player.hp < player.get_stat("max_hp") or player.mp < player.get_stat("max_mp")


## Spends the day at camp instead of rolling. Today's food pays for it.
func camp() -> void:
	if can_camp():
		player.rest()
		note("camp", "%s makes camp, and rests." % player.player_name)


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
		if brain.wants_camp():
			camp()
		else:
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
	_aim = -1
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
	return landings_from(space_id, came_from, steps_left)


## Every space a walk of `steps` from `id` can end on, as the board stands now. With the
## Beacon, that is also the Portal if the walk can cross it.
func landings_from(id: int, from: int, steps: int) -> Array[int]:
	var found := map.landings(id, from, steps)
	if beacon and not found.has(map.portal) and _steps_to_portal(id, from, steps) > 0:
		# The map keeps its answers, so this adds to a copy.
		found = found.duplicate()
		found.append(map.portal)
	return found


# The fewest steps, under `steps`, in which a walk from `id` can cross the Portal, or 0
# if none can.
func _steps_to_portal(id: int, from: int, steps: int) -> int:
	for count in range(1, steps):
		if map.landings(id, from, count).has(map.portal):
			return count
	return 0


## The spaces the walk under way steps on to end on `landing`, which must be one of
## landing_spaces(). Where two roads lead there, it takes the first.
func path_to(landing: int) -> Array[int]:
	var path: Array[int] = []
	var here := space_id
	var from := came_from
	var left := steps_left
	if landing == map.portal and beacon and not map.landings(here, from, left).has(landing):
		left = _steps_to_portal(here, from, left)
	while left > 0:
		var found := -1
		for next in map.exits(here, from):
			if map.landings(next, here, left - 1).has(landing):
				found = next
				break
		if found < 0:
			return []
		path.append(found)
		from = here
		here = found
		left -= 1
	return path


## Takes one step of the walk, onto one of next_spaces(). With the Beacon, a step onto
## the Portal ends the walk if the walk was chosen to end there with choose_landing().
func step_to(next: int) -> void:
	came_from = space_id
	space_id = next
	steps_left -= 1
	if beacon and _aim == map.portal and space_id == map.portal:
		steps_left = 0
	if steps_left == 0:
		player.space_id = space_id
		furthest = maxi(furthest, depth_of(space_id))


## Settles where the walk under way ends, out of landing_spaces(), and returns the spaces
## it steps on, as path_to() does. Call this before walking them.
func choose_landing(landing: int) -> Array[int]:
	_aim = landing
	return path_to(landing)


## Walks `steps` spaces to where the brain chooses to land, and returns the ids stepped on
## in order. If no road is `steps` long, the path is empty.
func walk(steps: int) -> Array[int]:
	var path: Array[int] = []
	if not begin_walk(steps):
		return path
	for next in choose_landing(brain.choose_landing(landing_spaces())):
		step_to(next)
		path.append(next)
	return path


## Does what the space under them does, even if a 0 left them on it. Leaves `fight` set
## if a monster must be fought first.
func land() -> void:
	if not _lands:
		return
	visits[space_id] = visits.get(space_id, 0) + 1
	if _stop_at_portal():
		return
	match type_at(space_id):
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
		_clear_space(space_id)
		if monster != null and _prize == null and GameState.rng.randf() < MATERIAL_DROP_CHANCE:
			_gain_material(_common_material())
		if _prize != null:
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

# Puts this trip's monsters and chests on the map, from the seed. What the file fixes in
# place stays, and the rest go on empty road.
func _set_up_board(stage: Stage) -> void:
	var road: Array[int] = []
	for id in map.spaces():
		_board[id] = map.type_of(id)
		if _board[id] == BoardNode.NodeType.NORMAL:
			road.append(id)
		elif _board[id] == BoardNode.NodeType.BATTLE:
			_monsters[id] = true
	_shuffle(road)
	for index in stage.chests - map.fixed_chests():
		_board[road.pop_back()] = BoardNode.NodeType.TREASURE
	for index in stage.monsters - _monsters.size():
		var id: int = road.pop_back()
		_board[id] = BoardNode.NodeType.BATTLE
		_monsters[id] = true


# Array.shuffle() ignores GameState.rng, so it wouldn't follow the seed.
func _shuffle(list: Array[int]) -> void:
	for index in range(list.size() - 1, 0, -1):
		var other := GameState.rng.randi_range(0, index)
		var held := list[index]
		list[index] = list[other]
		list[other] = held


func _clear_space(id: int) -> void:
	_board[id] = BoardNode.NodeType.NORMAL
	_monsters.erase(id)
	space_emptied.emit(id)


func _eat() -> void:
	_fed_today = food_left > 0
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
	for item_id in player.inventory.duplicate():
		read_by_hand(item_id)


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
		if landings_from(space_id, -1, steps).has(map.portal):
			return true
	return false


func _open_chest() -> void:
	if not by_hand and not CpuBrain.will_open_chest(player):
		return
	var chest := SpaceEffects.roll_chest(player)
	if chest.guardian != null:
		note("find", chest.text)
		_prize = chest
		_meet(chest.guardian)
	else:
		_clear_space(space_id)
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


# Pays out what a chest held. Every chest holds a material too, and the chest at the deep
# end of a spur, which the map fixes in place, also holds a rare one.
func _take(result: SpaceEffects.Result) -> void:
	note("find", result.text)
	_remember(result.text.replace("the castle", "the Portal"), _worth_of(result))
	player.add_gold(result.gold)
	if result.item_id != "":
		_give(result.item_id)
	if is_deep_chest(space_id):
		var rare := Database.material_ids(true)
		var id := rare[GameState.rng.randi_range(0, rare.size() - 1)]
		_remember("%s found %s at the end of the road." % [player.player_name, Database.get_material(id).display_name],
				Database.get_material(id).price)
		_gain_material(id)
	_gain_material(_common_material())


## True if space `id` is a chest at the deep end of a spur, which holds a rare material.
## The map fixes those in place, and they are the ends of dead-end roads.
func is_deep_chest(id: int) -> bool:
	return map.type_of(id) == BoardNode.NodeType.TREASURE and map.neighbors(id).size() == 1


## What the materials they carry would sell for, in gold.
func materials_worth() -> int:
	var worth := 0
	for id in materials:
		worth += TownData.material_price(id)
	return worth


## The player answers a material found with the materials bag full: `dropped` is the one to
## leave behind to make room, or "" to leave the new one.
func keep_material(dropped: String) -> void:
	if found_material == "":
		return
	if dropped != "" and materials.has(dropped):
		materials.erase(dropped)
		materials.append(found_material)
		note("item", "%s leaves the %s behind." % [player.player_name, Database.get_material(dropped).display_name])
	found_material = ""
	materials_changed.emit()


func _common_material() -> String:
	var common := Database.material_ids()
	return common[GameState.rng.randi_range(0, common.size() - 1)]


# Puts a material in the materials bag. With it full, the player chooses, and the bot drops
# the cheapest if the new one is worth more.
func _gain_material(id: String) -> void:
	note("material", "%s picks up %s." % [player.player_name, Database.get_material(id).display_name])
	if materials.size() < MATERIAL_ROOM:
		materials.append(id)
		materials_changed.emit()
		return
	if by_hand:
		found_material = id
		return
	var cheapest := materials[0]
	for held in materials:
		if Database.get_material(held).price < Database.get_material(cheapest).price:
			cheapest = held
	if Database.get_material(cheapest).price < Database.get_material(id).price:
		materials.erase(cheapest)
		materials.append(id)
		materials_changed.emit()


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


## The player has them read the tome `item_id`. With that kind of move full, `forgotten` is
## the move it replaces.
func read_by_hand(item_id: String, forgotten := "") -> bool:
	if not player.read_tome(item_id, forgotten):
		return false
	note("item", "%s learns %s." % [player.player_name, Database.get_move(Database.get_item(item_id).teaches).display_name])
	return true


## The player has them wear `item_id`, and what it replaces goes in the bag.
func wear_by_hand(item_id: String) -> bool:
	if not player.equip(item_id):
		return false
	note("item", "%s puts on the %s." % [player.player_name, Database.get_item(item_id).display_name])
	return true


# Puts an item in the bag. With the bag full, the player chooses what to do, and the bot
# drops the cheapest thing if that's worth doing.
func _give(item_id: String) -> void:
	if player.add_item(item_id):
		return
	if by_hand:
		found_item = item_id
	elif SpaceEffects.cpu_make_room(player, item_id) != "":
		player.add_item(item_id)


## Who `who` is on the road: their class, with the level, gear, moves and pack that `kept`
## holds, if they are on the roster.
static func make_player(who: Adventurer, hand: bool, kept: Member) -> PlayerData:
	var made := PlayerData.new(who.display_name, Color.WHITE, not hand)
	made.character_sheet = who.sheet
	made.learns_by_level = false
	made.choose_class(who.class_id)
	var level := who.level if kept == null else kept.level
	while made.level < level:
		made.add_experience(made.exp_to_next_level())
	if kept != null:
		made.experience = kept.experience
		made.equipment = kept.equipment.duplicate()
		made.learned = kept.learned.duplicate()
		made.inventory = kept.pack.duplicate()
	made.gold = 0
	made.gold_share = GOLD_SHARE
	made.rest_share = CAMP_SHARE
	made.heal_fully()
	return made
