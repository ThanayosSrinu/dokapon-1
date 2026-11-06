class_name Shop
extends RefCounted
## The rules of buying and selling, with no UI. ui/ShopScreen.gd shows them.
##
## Each shop has its own stock, which changes every week. The stock comes from the
## game's seed, the shop and the week, so it never uses up numbers from
## GameState.rng, and it needs no saving: the same week gives the same shelves.

const EQUIPMENT_STOCK := 5
const CONSUMABLE_STOCK := 3
## Shops pay this share of an item's price.
const SELL_SHARE := 0.5

## The ids on sale at `space_id` in `week`: equipment first, then cheapest first.
static func stock(space_id: int, week: int) -> Array[String]:
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([GameState.game_seed, space_id, week])
	var equipment: Array[String] = []
	var consumables: Array[String] = []
	for id in Database.sorted_ids(Database.items):
		if Database.get_item(id).kind == ItemData.Kind.CONSUMABLE:
			consumables.append(id)
		else:
			equipment.append(id)
	var shelves := _first_few(equipment, EQUIPMENT_STOCK, dice)
	shelves.append_array(_first_few(consumables, CONSUMABLE_STOCK, dice))
	shelves.sort_custom(func(a: String, b: String) -> bool:
			var first := Database.get_item(a)
			var second := Database.get_item(b)
			if first.kind != second.kind:
				return first.kind > second.kind
			if first.price != second.price:
				return first.price < second.price
			return a < b)
	return shelves


static func sell_price(item_id: String) -> int:
	return int(Database.get_item(item_id).price * SELL_SHARE)


## Why this player cannot buy the item, or "" if they can.
static func why_not_buy(player: PlayerData, item_id: String) -> String:
	if player.gold < Database.get_item(item_id).price:
		return "Not enough gold."
	if player.inventory.size() >= player.bag_size:
		return "Your bag is full. Sell something first."
	return ""


static func buy(player: PlayerData, item_id: String) -> bool:
	if why_not_buy(player, item_id) != "":
		return false
	player.add_gold(-Database.get_item(item_id).price)
	return player.add_item(item_id)


static func sell(player: PlayerData, item_id: String) -> bool:
	if not player.remove_item(item_id):
		return false
	player.add_gold(sell_price(item_id))
	return true


# Fisher-Yates, then the first few. Array.shuffle() would ignore `dice`.
static func _first_few(list: Array[String], count: int, dice: RandomNumberGenerator) -> Array[String]:
	var mixed: Array[String] = list.duplicate()
	for index in range(mixed.size() - 1, 0, -1):
		var other := dice.randi_range(0, index)
		var swapped := mixed[index]
		mixed[index] = mixed[other]
		mixed[other] = swapped
	return mixed.slice(0, count)
