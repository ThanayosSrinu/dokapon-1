class_name SpaceEffects
extends RefCounted
## What each kind of space does, with no animation or UI. GameController asks for
## a Result and shows it, and tools/test_spaces.gd runs these with no window.
##
## Healing, spells and trap damage happen here. Gold, items and trips to the castle
## wait in the Result, because a chest's prize must not be paid until its guardian
## is beaten, and a full bag needs a person to choose what to drop.
##
## Every random result uses GameState.rng, so a seed replays the same game.

## Gold spaces pay this, plus this much per level, give or take the spread.
const GOLD_BASE := 40
const GOLD_PER_LEVEL := 15
const GOLD_SPREAD := 0.25

## Item spaces give things worth up to this, plus this much per level.
const ITEM_VALUE_BASE := 100
const ITEM_VALUE_PER_LEVEL := 40
## How much more often a consumable turns up than a piece of equipment.
const CONSUMABLE_WEIGHT := 3

## The chance that a Magic space teaches a spell.
const MAGIC_SPELL_CHANCE := 0.5
## A Magic space can teach spells this many levels before a class would learn them.
const MAGIC_LEVELS_AHEAD := 2

## The chance to step around a trap, per point of speed, and its limit.
const TRAP_DODGE_PER_SPEED := 0.02
const TRAP_DODGE_MAX := 0.4
## Spikes take this share of max HP. They never knock anyone out.
const SPIKE_MIN_SHARE := 0.15
const SPIKE_MAX_SHARE := 0.25
## A thief takes this share of the player's gold.
const THIEF_MIN_SHARE := 0.1
const THIEF_MAX_SHARE := 0.2
## How often each trap is sprung.
const TRAP_WEIGHTS := {"spikes": 4, "thief": 3, "snare": 2, "trapdoor": 1}

## A chest fills again this many days after it is emptied.
const CHEST_REFILL_DAYS := 7
## The chance that a monster guards a chest.
const CHEST_GUARDIAN_CHANCE := 0.25
## A guardian is picked as if the player were this many levels higher.
const GUARDIAN_LEVELS_AHEAD := 2
## The chance that a chest holds an item. Otherwise it holds gold.
const CHEST_ITEM_CHANCE := 0.45
const CHEST_GOLD_BASE := 150
const CHEST_GOLD_PER_LEVEL := 40
## Chest items are worth at least this, and up to the value below.
const CHEST_ITEM_MIN_VALUE := 150
const CHEST_ITEM_VALUE_BASE := 300
const CHEST_ITEM_VALUE_PER_LEVEL := 60


## What a space did, for GameController to pay out and show.
class Result:
	## A sentence for the message window.
	var text := ""
	## Gold to add, or to take away when negative.
	var gold := 0
	## An item to put in the bag.
	var item_id := ""
	var to_castle := false
	## Something hurt or trapped the player, so the screen should shake.
	var harmful := false
	## A chest's guardian. Its prize is only paid if the player wins.
	var guardian: MonsterData

	func _init(new_text := "") -> void:
		text = new_text


static func gold_space(player: PlayerData) -> Result:
	var amount := _spread(GOLD_BASE + GOLD_PER_LEVEL * player.level)
	var result := Result.new("Found %d gold." % amount)
	result.gold = amount
	return result


static func item_space(player: PlayerData) -> Result:
	var item_id := pick_item(0, ITEM_VALUE_BASE + ITEM_VALUE_PER_LEVEL * player.level)
	var result := Result.new("Found a %s." % Database.get_item(item_id).display_name)
	result.item_id = item_id
	return result


## Refills MP, and sometimes teaches a spell the player does not know yet.
static func magic_space(player: PlayerData) -> Result:
	player.refill_mp()
	var result := Result.new("Old magic fills you. MP restored.")
	var spells := learnable_spells(player)
	if not spells.is_empty() and GameState.rng.randf() < MAGIC_SPELL_CHANCE:
		var spell_id := spells[GameState.rng.randi_range(0, spells.size() - 1)]
		player.learn_spell(spell_id)
		result.text += " Learned %s!" % Database.get_spell(spell_id).display_name
	return result


static func shrine_space(player: PlayerData) -> Result:
	player.heal_fully()
	return Result.new("A quiet prayer. HP and MP fully restored.")


## Springs a trap on the player, unless they are quick enough to step around it.
static func trap_space(player: PlayerData) -> Result:
	if GameState.rng.randf() < trap_dodge_chance(player):
		return Result.new("%s steps around it just in time." % player.player_name)
	var trap := _weighted_pick(TRAP_WEIGHTS)
	# Someone with no gold has nothing to steal.
	if trap == "thief" and player.gold <= 0:
		trap = "spikes"
	var result := Result.new()
	result.harmful = true
	match trap:
		"spikes":
			var share := GameState.rng.randf_range(SPIKE_MIN_SHARE, SPIKE_MAX_SHARE)
			var damage := maxi(int(player.get_stat("max_hp") * share), 1)
			player.take_damage(damage)
			result.text = "Spikes shoot up! Lost %d HP." % damage
		"thief":
			var share := GameState.rng.randf_range(THIEF_MIN_SHARE, THIEF_MAX_SHARE)
			var stolen := maxi(int(player.gold * share), 1)
			result.gold = -stolen
			result.text = "A thief darts past! Lost %d gold." % stolen
		"snare":
			player.lose_turn()
			result.text = "A snare! %s loses a turn." % player.player_name
		"trapdoor":
			result.to_castle = true
			result.text = "A trapdoor! %s slides all the way to the castle." % player.player_name
	return result


static func trap_dodge_chance(player: PlayerData) -> float:
	return minf(player.get_stat("speed") * TRAP_DODGE_PER_SPEED, TRAP_DODGE_MAX)


## True if the chest on space `space_id` has something in it.
static func chest_is_full(space_id: int) -> bool:
	return chest_days_left(space_id) <= 0


## How many days until an emptied chest fills again.
static func chest_days_left(space_id: int) -> int:
	if not GameState.emptied_chests.has(space_id):
		return 0
	return GameState.emptied_chests[space_id] + CHEST_REFILL_DAYS - GameState.day


static func empty_chest(space_id: int) -> void:
	GameState.emptied_chests[space_id] = GameState.day


## Decides what is in a chest. Call empty_chest() once the prize is really won.
static func roll_chest(player: PlayerData) -> Result:
	var result := Result.new()
	if GameState.rng.randf() < CHEST_ITEM_CHANCE:
		result.item_id = pick_item(CHEST_ITEM_MIN_VALUE,
				CHEST_ITEM_VALUE_BASE + CHEST_ITEM_VALUE_PER_LEVEL * player.level)
		result.text = "The chest holds a %s!" % Database.get_item(result.item_id).display_name
	else:
		result.gold = _spread(CHEST_GOLD_BASE + CHEST_GOLD_PER_LEVEL * player.level)
		result.text = "The chest holds %d gold!" % result.gold
	if GameState.rng.randf() < CHEST_GUARDIAN_CHANCE:
		var level := mini(player.level + GUARDIAN_LEVELS_AHEAD, PlayerData.MAX_LEVEL)
		var ids := Database.monster_ids_for_level(level)
		result.guardian = Database.get_monster(ids[GameState.rng.randi_range(0, ids.size() - 1)])
	return result


## Picks an item priced from `min_value` up to `max_value`.
static func pick_item(min_value: int, max_value: int) -> String:
	var weights := {}
	for id in Database.sorted_ids(Database.items):
		var item := Database.get_item(id)
		if item.price >= min_value and item.price <= max_value:
			weights[id] = CONSUMABLE_WEIGHT if item.kind == ItemData.Kind.CONSUMABLE else 1
	return _weighted_pick(weights)


## The spells a Magic space could teach this player, sorted like sorted_ids().
static func learnable_spells(player: PlayerData) -> Array[String]:
	var found: Array[String] = []
	for class_id in Database.sorted_ids(Database.classes):
		var spells_by_level := Database.get_class_data(class_id).spells_by_level
		for learned_at: int in spells_by_level:
			var spell_id: String = spells_by_level[learned_at]
			if (learned_at <= player.level + MAGIC_LEVELS_AHEAD
					and not player.spells.has(spell_id) and not found.has(spell_id)):
				found.append(spell_id)
	found.sort()
	return found


## Decides what a CPU player does with an item that will not fit: it drops the
## cheapest thing in the bag if the new item is worth more. Returns what it dropped,
## or "" if it left the new item behind.
static func cpu_make_room(player: PlayerData, item_id: String) -> String:
	var cheapest: String = player.inventory[0]
	for id in player.inventory:
		if Database.get_item(id).price < Database.get_item(cheapest).price:
			cheapest = id
	if Database.get_item(cheapest).price >= Database.get_item(item_id).price:
		return ""
	player.remove_item(cheapest)
	return cheapest


# An amount of gold, a little above or below `amount`.
static func _spread(amount: int) -> int:
	return int(amount * GameState.rng.randf_range(1.0 - GOLD_SPREAD, 1.0 + GOLD_SPREAD))


static func _weighted_pick(weights: Dictionary) -> String:
	var total := 0
	for weight: int in weights.values():
		total += weight
	var roll := GameState.rng.randi_range(1, total)
	for key: String in weights:
		roll -= weights[key]
		if roll <= 0:
			return key
	return ""
