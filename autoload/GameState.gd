extends Node
## All the data of the game in progress. Registered as the "GameState" autoload,
## so every script can read it and it will be easy to save in Section 10.
##
## This script only holds data. TurnManager decides when things change.
##
## Every random result that affects the game must use GameState.rng, never
## randi(). Starting a game with the same seed then replays the same game, which
## makes bugs repeatable. Purely visual randomness may keep using randi().

const DAYS_PER_WEEK := 7

## The generator for all game-affecting randomness.
var rng := RandomNumberGenerator.new()

## The seed of the current game. Printed to Output when a game starts.
var game_seed := 0

## Every player, in turn order.
var players: Array[PlayerData] = []

## The current day, starting at 1. A day is one turn by each player.
var day := 1

## Town space ID -> {"name", "steps"}: its name and how far it is from the castle.
## It comes from the map, so it does not need saving.
var towns := {}

## Town space ID -> owning PlayerData. A town with no owner is held by monsters.
var town_owners := {}

## Town space ID -> its level, for towns with an owner. See Town.
var town_levels := {}

## This week's royal quest. See Quest.
var quest := {}

## Treasure space ID -> the day its chest was emptied. See SpaceEffects.
var emptied_chests := {}

## Who wears the Shadow Crown and until when. Empty if nobody does. See ShadowCrown.
var shadow_crown := {}

## The week the Shadow Crown last left someone, or 0 if it never has.
var crown_left_week := 0

## The castle's space ID. It comes from the map, so it does not need saving.
var castle_id := -1


## Resets everything for a new game and decides the turn order at random.
## A `seed_value` of 0 picks a new random seed.
func start_new_game(new_players: Array[PlayerData], seed_value := 0) -> void:
	game_seed = seed_value if seed_value != 0 else randi_range(1, 2147483647)
	rng.seed = game_seed
	players = _shuffled(new_players)
	day = 1
	towns = {}
	town_owners.clear()
	town_levels.clear()
	quest = {}
	emptied_chests.clear()
	shadow_crown = {}
	crown_left_week = 0
	castle_id = -1
	print("New game: seed %d, turn order %s" % [game_seed, ", ".join(get_player_names())])


func get_player_names() -> PackedStringArray:
	var names := PackedStringArray()
	for player in players:
		names.append(player.player_name)
	return names


## The current week, starting at 1.
func get_week() -> int:
	@warning_ignore("integer_division")
	return (day - 1) / DAYS_PER_WEEK + 1


## The day within the current week, from 1 to DAYS_PER_WEEK.
func get_day_of_week() -> int:
	return (day - 1) % DAYS_PER_WEEK + 1


# Fisher-Yates shuffle. Array.shuffle() would ignore our seeded rng.
func _shuffled(list: Array[PlayerData]) -> Array[PlayerData]:
	var result: Array[PlayerData] = list.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swapped := result[index]
		result[index] = result[other]
		result[other] = swapped
	return result
