class_name Rivalry
extends RefCounted
## What a fight between two players leaves behind, with no UI. GameController asks
## the winner which spoil to take, then calls after_duel().
##
## Spoils: the winner takes a share of the loser's gold or the best thing in their
## bag. Only the wearer of the Shadow Crown can take a town.
## Grudges: whoever is knocked out by a rival holds a grudge. Beating that rival
## back earns double EXP and settles it.
## Bullying: challenge and beat someone far below your level and you earn no EXP,
## and the crown fines you. Revenge and the Shadow Crown are never bullying.
##
## Grudges are stored as player names, so that Section 10 can save them directly.

enum Spoil { GOLD, ITEM, TOWN }

const GOLD_SHARE := 0.25
## Beating someone this many levels below you is bullying.
const BULLY_LEVEL_GAP := 4
## The bully pays this share of their gold to the loser.
const BULLY_FINE_SHARE := 0.2
const REVENGE_EXP_TIMES := 2


static func has_grudge(player: PlayerData, rival: PlayerData) -> bool:
	return player.grudges.has(rival.player_name)


## True if `winner` beating `loser` counts as bullying, if `winner` started it.
static func is_bullying(winner: PlayerData, loser: PlayerData) -> bool:
	return (winner.level - loser.level >= BULLY_LEVEL_GAP and not has_grudge(winner, loser)
			and not ShadowCrown.is_worn_by(winner))


## The EXP a duel's winner earns, from the amount it would normally be.
static func duel_exp(winner: PlayerData, loser: PlayerData, winner_challenged: bool, amount: int) -> int:
	if has_grudge(winner, loser):
		return amount * REVENGE_EXP_TIMES
	if winner_challenged and is_bullying(winner, loser):
		return 0
	return amount


## What `winner` could take: Dictionaries of "kind", "text", "value" and, for an item
## or a town, "item" or "town". Empty if the loser has nothing.
static func spoils(winner: PlayerData, loser: PlayerData) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var gold := int(loser.gold * GOLD_SHARE)
	if gold > 0:
		options.append({"kind": Spoil.GOLD, "text": "%d gold" % gold, "value": gold})
	var item_id := best_item(loser)
	if item_id != "" and winner.inventory.size() < PlayerData.INVENTORY_SIZE:
		var item := Database.get_item(item_id)
		options.append({"kind": Spoil.ITEM, "text": item.display_name, "value": item.price, "item": item_id})
	if ShadowCrown.is_worn_by(winner):
		var town := best_town(loser)
		if town >= 0:
			options.append({"kind": Spoil.TOWN, "text": Town.town_name(town), "value": Town.worth(town), "town": town})
	return options


## The most valuable thing in the bag, or "".
static func best_item(player: PlayerData) -> String:
	var best := ""
	for item_id in player.inventory:
		if best == "" or Database.get_item(item_id).price > Database.get_item(best).price:
			best = item_id
	return best


## The player's most valuable town, or -1.
static func best_town(player: PlayerData) -> int:
	var best := -1
	for id in Town.towns_of(player):
		if best < 0 or Town.worth(id) > Town.worth(best):
			best = id
	return best


## Moves the spoil to the winner. Returns a sentence about it.
static func take(winner: PlayerData, loser: PlayerData, spoil: Dictionary) -> String:
	match spoil["kind"]:
		Spoil.GOLD:
			loser.add_gold(-spoil["value"])
			winner.add_gold(spoil["value"])
		Spoil.ITEM:
			loser.remove_item(spoil["item"])
			winner.add_item(spoil["item"])
		Spoil.TOWN:
			Town.seize(spoil["town"], winner)
	return "%s takes %s from %s." % [winner.player_name, spoil["text"], loser.player_name]


## The CPU's choice: whatever is worth the most. Section 9 can make this smarter.
static func cpu_spoil(options: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = options[0]
	for option in options:
		if option["value"] > best["value"]:
			best = option
	return best


## Fines a bully and updates the grudges. Returns a sentence about it, or "".
## Call it after the EXP is paid and the spoil is taken.
static func after_duel(winner: PlayerData, loser: PlayerData, winner_challenged: bool) -> String:
	var line := ""
	if winner_challenged and is_bullying(winner, loser):
		var fine := int(winner.gold * BULLY_FINE_SHARE)
		winner.add_gold(-fine)
		loser.add_gold(fine)
		line = "The crown fines %s %d gold for bullying." % [winner.player_name, fine]
	elif has_grudge(winner, loser):
		line = "%s has settled the score." % winner.player_name
	winner.grudges.erase(loser.player_name)
	if not has_grudge(loser, winner):
		loser.grudges.append(winner.player_name)
	return line


## A warning for someone about to challenge `rival`, or "".
static func warning(challenger: PlayerData, rival: PlayerData) -> String:
	if has_grudge(challenger, rival):
		return "You owe %s for a defeat: beat them for double EXP." % rival.player_name
	if is_bullying(challenger, rival):
		return "Beating %s would be bullying: no EXP, and a fine." % rival.player_name
	return ""


## Everyone's grudges as one line, or "" if there are none.
static func grudge_text() -> String:
	var parts := PackedStringArray()
	for player in GameState.players:
		for rival in player.grudges:
			parts.append("%s against %s" % [player.player_name, rival])
	return "" if parts.is_empty() else "Grudges: %s." % ", ".join(parts)
