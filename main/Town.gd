class_name Town
extends RefCounted
## The rules of towns and of what everyone is worth, with no UI. GameController
## asks the questions and shows the answers.
##
## A town starts in the hands of monsters. Beat its guard and it is yours, and it
## pays you every week. Pay to raise its level and it pays more, and its guard grows
## tougher. Anyone else who stops there pays a toll, or storms the guard to take it.
##
## How far a town is from the castle decides what it is worth and what guards it,
## so a new map needs no new numbers. Guards come from the game's seed and the town,
## like a shop's stock: no numbers are used from GameState.rng, and none are saved.

const MAX_LEVEL := 5

## A town is worth this, plus this much per step from the castle.
const VALUE_BASE := 100
const VALUE_PER_STEP := 30
## Each level pays this share of the town's value every week.
const INCOME_SHARE := 0.2
## Raising a town costs this share of its value, times its level.
const INVEST_SHARE := 0.75
## A guard's level is the town's steps from the castle, minus this.
const GUARD_STEPS_FREE := 2
## An owner's guard is this many levels tougher per level of the town above 1.
const GUARD_LEVELS_PER_TOWN_LEVEL := 2

## CPU players fight guards up to this many levels above their own, if their health
## is at least this share. Section 9 replaces these with real thinking.
const CPU_LEVELS_AHEAD := 2
const CPU_HEALTH_SHARE := 0.6
## CPU players keep this much gold after investing.
const CPU_KEEP_GOLD := 100


## Reads where the towns are. `towns` is BoardManager.get_town_info().
static func setup(towns: Dictionary) -> void:
	GameState.towns = towns


## Every town's space id, sorted so that seeded picks are repeatable.
static func ids() -> Array[int]:
	var found: Array[int] = []
	found.assign(GameState.towns.keys())
	found.sort()
	return found


static func town_name(id: int) -> String:
	return GameState.towns[id]["name"]


static func owner_of(id: int) -> PlayerData:
	return GameState.town_owners.get(id)


## The town's level, or 0 while monsters hold it.
static func level(id: int) -> int:
	return GameState.town_levels.get(id, 0)


## The towns this player owns.
static func towns_of(player: PlayerData) -> Array[int]:
	return ids().filter(func(id: int) -> bool: return owner_of(id) == player)


## The towns no player owns yet.
static func unclaimed() -> Array[int]:
	return ids().filter(func(id: int) -> bool: return owner_of(id) == null)


## What the town itself is worth, before anything is invested.
static func value(id: int) -> int:
	return VALUE_BASE + VALUE_PER_STEP * GameState.towns[id]["steps"]


## What the town pays its owner every week, at its level or at `at_level`. An
## unclaimed town shows what its first level would pay.
static func income(id: int, at_level := -1) -> int:
	var paying_level := maxi(level(id), 1) if at_level < 0 else at_level
	return int(value(id) * INCOME_SHARE * paying_level)


## What someone else pays for stopping here.
static func toll(id: int) -> int:
	return income(id)


## What the next level costs a town at `from_level`.
static func invest_cost(id: int, from_level := -1) -> int:
	var current := level(id) if from_level < 0 else from_level
	return int(value(id) * INVEST_SHARE * current)


## What the town counts for in a player's net worth: its value and all invested.
static func worth(id: int) -> int:
	var total := value(id)
	for from_level in range(1, level(id)):
		total += invest_cost(id, from_level)
	return total


static func guard_level(id: int) -> int:
	var steps: int = GameState.towns[id]["steps"]
	var extra := GUARD_LEVELS_PER_TOWN_LEVEL * maxi(level(id) - 1, 0)
	return clampi(steps - GUARD_STEPS_FREE + extra, 1, PlayerData.MAX_LEVEL)


## The monster guarding the town.
static func guard(id: int) -> MonsterData:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([GameState.game_seed, id, level(id)])
	var monsters := Database.monster_ids_for_level(guard_level(id))
	return Database.get_monster(monsters[dice.randi_range(0, monsters.size() - 1)])


## Hands a town freed from its monsters to `player`.
static func claim(id: int, player: PlayerData) -> void:
	GameState.town_owners[id] = player
	GameState.town_levels[id] = 1
	player.changed.emit()


## Why this player cannot raise the town, or "" if they can.
static func why_not_invest(player: PlayerData, id: int) -> String:
	if owner_of(id) != player:
		return "That is not your town."
	if level(id) >= MAX_LEVEL:
		return "It cannot grow any more."
	if player.gold < invest_cost(id):
		return "Not enough gold."
	return ""


static func invest(player: PlayerData, id: int) -> bool:
	if why_not_invest(player, id) != "":
		return false
	player.add_gold(-invest_cost(id))
	GameState.town_levels[id] = level(id) + 1
	player.changed.emit()
	return true


## Moves the toll to the owner, or all `player` has if that is less. Returns how
## much was paid.
static func pay_toll(player: PlayerData, id: int) -> int:
	var paid := mini(toll(id), player.gold)
	player.add_gold(-paid)
	owner_of(id).add_gold(paid)
	return paid


## The guard was beaten, so the town changes hands and drops a level.
static func seize(id: int, player: PlayerData) -> void:
	var old_owner := owner_of(id)
	GameState.town_owners[id] = player
	GameState.town_levels[id] = maxi(level(id) - 1, 1)
	old_owner.changed.emit()
	player.changed.emit()


## Monsters attack a town: it drops a level, or falls to them from level 1. Returns
## true if its owner lost it.
static func raid(id: int) -> bool:
	var old_owner := owner_of(id)
	var lost := level(id) <= 1
	if lost:
		GameState.town_owners.erase(id)
		GameState.town_levels.erase(id)
	else:
		GameState.town_levels[id] = level(id) - 1
	old_owner.changed.emit()
	return lost


## Pays every owner for the week, except the wearer of the Shadow Crown. Returns
## PlayerData -> gold, for those paid.
static func collect_income() -> Dictionary:
	var paid := {}
	for id in ids():
		var town_owner := owner_of(id)
		if town_owner != null and not ShadowCrown.is_worn_by(town_owner):
			paid[town_owner] = paid.get(town_owner, 0) + income(id)
	for player: PlayerData in paid:
		player.add_gold(paid[player])
	return paid


## Worn and carried items at the price they were bought for, so that buying gear
## never lowers a player's place in the standings.
static func gear_value(player: PlayerData) -> int:
	var total := 0
	for item_id: String in player.equipment.values():
		total += Database.get_item(item_id).price
	for item_id in player.inventory:
		total += Database.get_item(item_id).price
	return total


static func town_value(player: PlayerData) -> int:
	var total := 0
	for id in towns_of(player):
		total += worth(id)
	return total


static func net_worth(player: PlayerData) -> int:
	return player.gold + gear_value(player) + town_value(player)


## Every player, richest first. Ties stay in turn order.
static func ranking() -> Array[PlayerData]:
	var order: Array[PlayerData] = GameState.players.duplicate()
	order.sort_custom(func(a: PlayerData, b: PlayerData) -> bool:
			var first := net_worth(a)
			var second := net_worth(b)
			if first != second:
				return first > second
			return GameState.players.find(a) < GameState.players.find(b))
	return order


## True if a CPU player thinks it can beat this town's guard.
static func cpu_will_fight(player: PlayerData, id: int) -> bool:
	return (guard(id).level <= player.level + CPU_LEVELS_AHEAD
			and player.hp >= player.get_stat("max_hp") * CPU_HEALTH_SHARE)


static func cpu_will_invest(player: PlayerData, id: int) -> bool:
	return (why_not_invest(player, id) == ""
			and player.gold - invest_cost(id) >= CPU_KEEP_GOLD)
