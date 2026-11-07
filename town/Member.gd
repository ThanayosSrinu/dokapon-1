class_name Member
extends RefCounted
## One person on the town's roster: who they are, and what has happened to them since
## they joined. TownData keeps these.

var person: Adventurer
## The first day they can work again.
var ready_on := 0
var trips := 0
var trips_home := 0
## The gold they have brought home.
var gold_home := 0
## What stays with them between trips, won or lost.
var level := 1
var experience := 0
## ItemData.Kind -> the id of what they wear. It starts as their class's gear.
var equipment := {}
## The ids of the Magic and Special moves they know.
var learned: Array[String] = []
## The items they set out with next time, at most PlayerData.INVENTORY_SIZE. It starts as
## their class's items, and after that only what the town gives them goes in. A trip takes
## it all, and what comes home goes to the town's stock, so it is empty after each trip.
var pack: Array[String] = []
## The skill tree spaces they have taken, as SkillTree ids. A level gives a point.
var tree: Array[String] = []


func _init(who: Adventurer) -> void:
	person = who
	level = who.level
	var data := Database.get_class_data(who.class_id)
	for item_id in data.starting_equipment:
		equipment[Database.get_item(item_id).kind] = item_id
	learned = data.starting_moves.duplicate()
	pack = data.starting_items.duplicate()


## Takes back what `player` still has at the end of a trip. The bag is not theirs to keep.
func keep(player: PlayerData) -> void:
	level = player.level
	experience = player.experience
	equipment = player.equipment.duplicate()
	learned = player.learned.duplicate()


## Skill tree points they have and have not spent.
func points_free() -> int:
	return SkillTree.points_at(level) - tree.size()


## True if they can take the space `id` now.
func can_take(id: String) -> bool:
	return points_free() > 0 and SkillTree.can_take(person.class_id, tree, id)


## Takes the space `id` with a point. Returns false if they can't.
func take(id: String) -> bool:
	if not can_take(id):
		return false
	tree.append(id)
	return true


## Spends every free point on the branches in `order`, as the sim does.
func spend_points(order: Array[int]) -> void:
	while points_free() > 0:
		var id := SkillTree.next_in(person.class_id, tree, order)
		if id == "":
			return
		tree.append(id)


## What taking back every point costs at the Academy.
func reset_price() -> int:
	return tree.size() * SkillTree.RESET_PRICE_PER_POINT


## The most days of food they can carry on a trip: their Max Food at their level, with
## what the skill tree adds.
func max_food() -> int:
	var food := person.food_at(level) + SkillTree.stat_add(person.class_id, tree, "food")
	return floori(food * (1.0 + SkillTree.perk(person.class_id, tree, SkillTree.FOOD_SHARE)))


## Puts on the gear `item_id`, and returns the id of what it replaces, or "".
func wear(item_id: String) -> String:
	var kind := Database.get_item(item_id).kind
	var old: String = equipment.get(kind, "")
	equipment[kind] = item_id
	return old


## True if the pack has room for one more item.
func pack_has_room() -> bool:
	return pack.size() < PlayerData.INVENTORY_SIZE


## Who they would be on a trip that starts now, for showing stats in town.
func sheet() -> PlayerData:
	return Expedition.make_player(person, true, self)


func is_ready(today: int) -> bool:
	return today >= ready_on


## How many days until they can work again, or 0.
func days_out(today: int) -> int:
	return maxi(ready_on - today, 0)
