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

## How much a CPU player cares about each stat. Its main stat counts as well.
const CPU_STAT_WEIGHTS := {"defense": 2.0, "speed": 1.0, "max_hp": 0.25, "max_mp": 0.25}
const CPU_MAIN_STAT_WEIGHT := 3.0
## CPU players try to carry this many healing items.
const CPU_HEALING_ITEMS := 2


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
	if player.inventory.size() >= PlayerData.INVENTORY_SIZE:
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


## Shops for a CPU player: better gear first, then healing. Returns the names of
## what it bought. Section 9 replaces this with real thinking.
static func cpu_shop(player: PlayerData, shelves: Array[String]) -> PackedStringArray:
	var bought := PackedStringArray()
	_cpu_tidy_bag(player)
	while true:
		var upgrade := _best_upgrade(player, shelves)
		if upgrade == "":
			break
		buy(player, upgrade)
		player.equip(upgrade)
		bought.append(Database.get_item(upgrade).display_name)
		_cpu_tidy_bag(player)
	while _healing_items(player) < CPU_HEALING_ITEMS:
		var cure := _cheapest_cure(player, shelves)
		if cure == "":
			break
		buy(player, cure)
		bought.append(Database.get_item(cure).display_name)
	return bought


# Fisher-Yates, then the first few. Array.shuffle() would ignore `dice`.
static func _first_few(list: Array[String], count: int, dice: RandomNumberGenerator) -> Array[String]:
	var mixed: Array[String] = list.duplicate()
	for index in range(mixed.size() - 1, 0, -1):
		var other := dice.randi_range(0, index)
		var swapped := mixed[index]
		mixed[index] = mixed[other]
		mixed[other] = swapped
	return mixed.slice(0, count)


# Wears whatever in the bag beats what is worn, then sells the rest of the gear.
static func _cpu_tidy_bag(player: PlayerData) -> void:
	for item_id in player.inventory.duplicate():
		if Database.get_item(item_id).kind != ItemData.Kind.CONSUMABLE and _upgrade_value(player, item_id) > 0.0:
			player.equip(item_id)
	for item_id in player.inventory.duplicate():
		if Database.get_item(item_id).kind != ItemData.Kind.CONSUMABLE:
			sell(player, item_id)


static func _best_upgrade(player: PlayerData, shelves: Array[String]) -> String:
	var best := ""
	var best_value := 0.0
	for item_id in shelves:
		if Database.get_item(item_id).kind == ItemData.Kind.CONSUMABLE or why_not_buy(player, item_id) != "":
			continue
		var value := _upgrade_value(player, item_id)
		if value > best_value:
			best = item_id
			best_value = value
	return best


# How much better the item is than what is worn in its slot.
static func _upgrade_value(player: PlayerData, item_id: String) -> float:
	var item := Database.get_item(item_id)
	var worn: String = player.equipment.get(item.kind, "")
	var value := _item_value(player, item)
	if worn != "":
		value -= _item_value(player, Database.get_item(worn))
	return value


static func _item_value(player: PlayerData, item: ItemData) -> float:
	var data := Database.get_class_data(player.class_id)
	var main_stat := "magic" if data.base_stats["magic"] > data.base_stats["attack"] else "attack"
	var value := 0.0
	for stat: String in item.bonuses:
		var weight: float = CPU_MAIN_STAT_WEIGHT if stat == main_stat else CPU_STAT_WEIGHTS.get(stat, 0.0)
		value += item.bonuses[stat] * weight
	return value


static func _healing_items(player: PlayerData) -> int:
	var count := 0
	for item_id in player.inventory:
		if Database.get_item(item_id).heal_hp > 0:
			count += 1
	return count


static func _cheapest_cure(player: PlayerData, shelves: Array[String]) -> String:
	var cheapest := ""
	for item_id in shelves:
		if Database.get_item(item_id).heal_hp <= 0 or why_not_buy(player, item_id) != "":
			continue
		if cheapest == "" or Database.get_item(item_id).price < Database.get_item(cheapest).price:
			cheapest = item_id
	return cheapest
