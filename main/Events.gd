class_name Events
extends RefCounted
## What Event spaces do, with no UI. Each draw picks one event at random from those
## that can happen right now, and returns a SpaceEffects.Result for GameController
## to pay out. An event's `title` is shown on a banner.
##
## Some events touch every player, which is what makes them chaos. Every random
## result uses GameState.rng, so a seed replays the same game.

## Festival pays everyone this, plus this much per week.
const FESTIVAL_BASE := 40
const FESTIVAL_PER_WEEK := 20
const TAX_SHARE := 0.1
const MERCHANT_VALUE_BASE := 200
const MERCHANT_VALUE_PER_LEVEL := 50
const BLESSING_STEPS := 2
## Storms take this share of everyone's max HP. They never knock anyone out.
const STORM_SHARE := 0.15
## The outlaw hero moves this share of the richest player's gold to the poorest.
const HERO_SHARE := 0.1
## An ambusher is picked as if the player were this many levels higher.
const AMBUSH_LEVELS_AHEAD := 1

## How often each event comes up.
const WEIGHTS := {
	"festival": 3, "tax": 2, "merchant": 3, "blessing": 3, "storm": 2,
	"raid": 2, "ambush": 2, "portal": 2, "hero": 2, "tutor": 2,
}


## Picks an event for `player`. `spaces` is every space id on the board.
static func draw(player: PlayerData, spaces: Array[int]) -> SpaceEffects.Result:
	var weights := {}
	for event: String in WEIGHTS:
		if can_happen(event, player):
			weights[event] = WEIGHTS[event]
	return run(SpaceEffects.weighted_pick(weights), player, spaces)


static func can_happen(event: String, player: PlayerData) -> bool:
	match event:
		"tax":
			return not _gold_holders().is_empty()
		"raid":
			return not GameState.town_owners.is_empty()
		"hero":
			return _richest() != _poorest() and _richest().gold > 0
		"tutor":
			return not _unknown_field_spells(player).is_empty()
	return true


## Makes `event` happen.
static func run(event: String, player: PlayerData, spaces: Array[int]) -> SpaceEffects.Result:
	match event:
		"festival":
			return _festival()
		"tax":
			return _tax()
		"merchant":
			return _merchant(player)
		"blessing":
			return _blessing(player)
		"storm":
			return _storm()
		"raid":
			return _raid(player)
		"ambush":
			return _ambush(player)
		"portal":
			return _portal(player, spaces)
		"hero":
			return _hero()
	return _tutor(player)


static func _result(title: String, text: String) -> SpaceEffects.Result:
	var result := SpaceEffects.Result.new(text)
	result.title = title
	return result


static func _festival() -> SpaceEffects.Result:
	var amount := FESTIVAL_BASE + FESTIVAL_PER_WEEK * GameState.get_week()
	var result := _result("Harvest Feast", "The whole realm celebrates! Everyone gets %d gold." % amount)
	for player in GameState.players:
		result.gold_changes[player] = amount
	return result


static func _tax() -> SpaceEffects.Result:
	var result := _result("Royal Tax", "The crown's collectors ride out. Everyone pays a tenth of their gold.")
	result.harmful = true
	for player in _gold_holders():
		result.gold_changes[player] = -maxi(int(player.gold * TAX_SHARE), 1)
	return result


static func _merchant(player: PlayerData) -> SpaceEffects.Result:
	var limit := MERCHANT_VALUE_BASE + MERCHANT_VALUE_PER_LEVEL * player.level
	var item_id := SpaceEffects.pick_item(0, limit)
	var result := _result("Kind Merchant", "A merchant you once helped gives you a %s."
			% Database.get_item(item_id).display_name)
	result.item_id = item_id
	return result


static func _blessing(player: PlayerData) -> SpaceEffects.Result:
	player.heal_fully()
	player.add_roll_bonus(BLESSING_STEPS)
	return _result("Road Blessing", "HP and MP restored, and your next roll gets +%d." % BLESSING_STEPS)


static func _storm() -> SpaceEffects.Result:
	for player in GameState.players:
		player.take_damage(maxi(int(player.get_stat("max_hp") * STORM_SHARE), 1))
	var result := _result("Wild Storm", "Lightning lashes the island! Everyone is hurt.")
	result.harmful = true
	return result


# Monsters go for the leader's finest town. A town at level 1 falls to them.
static func _raid(player: PlayerData) -> SpaceEffects.Result:
	var id := -1
	for rich in Town.ranking():
		id = Rivalry.best_town(rich)
		if id >= 0:
			break
	var town_owner := Town.owner_of(id)
	var lost := Town.raid(id)
	var result := _result("Monster Raid", "Monsters storm %s!" % Town.town_name(id))
	if lost:
		result.text += " %s loses the town." % town_owner.player_name
	else:
		result.text += " It falls to level %d." % Town.level(id)
	result.town_id = id
	result.harmful = town_owner == player
	return result


static func _ambush(player: PlayerData) -> SpaceEffects.Result:
	var level := mini(player.level + AMBUSH_LEVELS_AHEAD, PlayerData.MAX_LEVEL)
	var ids := Database.monster_ids_for_level(level)
	var monster := Database.get_monster(ids[GameState.rng.randi_range(0, ids.size() - 1)])
	var result := _result("Ambush", "A %s leaps out of hiding!" % monster.display_name)
	result.guardian = monster
	return result


static func _portal(player: PlayerData, spaces: Array[int]) -> SpaceEffects.Result:
	var places := spaces.filter(func(id: int) -> bool:
			return id != player.space_id and id != GameState.castle_id)
	var result := _result("Strange Portal", "The air tears open and pulls %s through." % player.player_name)
	result.warp_to = places[GameState.rng.randi_range(0, places.size() - 1)]
	return result


static func _hero() -> SpaceEffects.Result:
	var rich := _richest()
	var poor := _poorest()
	var amount := maxi(int(rich.gold * HERO_SHARE), 1)
	var result := _result("Outlaw Hero", "An outlaw robs %s and leaves %d gold at %s's door." % [
			rich.player_name, amount, poor.player_name])
	result.gold_changes = {rich: -amount, poor: amount}
	return result


static func _tutor(player: PlayerData) -> SpaceEffects.Result:
	var unknown := _unknown_field_spells(player)
	var spell := Database.get_spell(unknown[GameState.rng.randi_range(0, unknown.size() - 1)])
	player.learn_spell(spell.id)
	return _result("Wandering Sage", "A sage teaches you %s, a spell for the road." % spell.display_name)


static func _gold_holders() -> Array[PlayerData]:
	return GameState.players.filter(func(player: PlayerData) -> bool: return player.gold > 0)


static func _unknown_field_spells(player: PlayerData) -> Array[String]:
	return FieldMagic.all_ids().filter(func(id: String) -> bool: return not player.spells.has(id))


static func _richest() -> PlayerData:
	var best: PlayerData = GameState.players[0]
	for player in GameState.players:
		if player.gold > best.gold:
			best = player
	return best


static func _poorest() -> PlayerData:
	var worst: PlayerData = GameState.players[0]
	for player in GameState.players:
		if player.gold < worst.gold:
			worst = player
	return worst
