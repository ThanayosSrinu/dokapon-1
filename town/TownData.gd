class_name TownData
extends RefCounted
## The town of the current game: its gold, buildings, date, roster and debts. It has no
## UI. It saves itself to one file whenever the town is shown and after each trip, and
## the file is deleted when the town is lost (D11).
##     TownData.current().gold
##
## Time stands still in town. It moves only when a trip ends, by the trip's own days
## (Stage.days), however it ended: a trip's time is spent even if it is cut short. A bill or a loan can be paid
## on its due day, and the game is lost once that day has passed with it unpaid (D11 in
## EXPEDITION_PLAN.md), or once nobody can go and no gold can be found to hire anyone.

enum Alert { NONE, WARN, ALARM }
## What a forecast's color means. SAFE: the trip is home by the due day. LATE: it is not.
enum Forecast { SAFE, LATE }

const START_GOLD := 300
## Gold for one day of food.
const FOOD_PRICE := 3
## Where the Portal leads in a new game. A stage id from data/stages.
const FIRST_STAGE := "grass_s"
const ROSTER_ROOM := 3
const KING_TAX := 300
## Months with no bill at the start of a game. The first bill comes as the next one begins.
const BILL_FREE_MONTHS := 1
## The sums on offer at the Bank, and what a loan costs. Interest is flat.
const LOAN_SIZES: Array[int] = [100, 250, 500]
const LOAN_INTEREST := 0.2
const LOAN_DAYS := 28
## Days out of work after dying (D2). Nothing else costs days of work.
const OUT_AFTER_DEFEAT := 7
## Warnings: how many days before a due day each step starts.
const WARN_DAYS := 7
const ALARM_DAYS := 3
## The order of kinds on the Shop's shelves.
const SHOP_ORDER: Array[ItemData.Kind] = [ItemData.Kind.WEAPON, ItemData.Kind.ARMOR,
		ItemData.Kind.ACCESSORY, ItemData.Kind.CONSUMABLE, ItemData.Kind.TOME]

## What a building is called and what it does, in words for its sign. Every building
## here can be pointed at and visited, so a new one needs an entry, a place in TownArt and
## a picture for each level. "start" is its level in a new town, and 0 means not built.
## "built" is what its sign says once it stands, if that differs from "job".
const BUILDINGS := {
	"castle": {"name": "Castle", "job": "Your home. Read the King's letter, and buy upgrades from the Town Plans.", "start": 1},
	"academy": {"name": "Academy", "job": "Not built yet. Its plans come in a Royal Letter.",
		"built": "Teaches Magic and Special moves, for gold.", "start": 0},
	"storehouse": {"name": "Storehouse", "job": "Not built yet. Build it from the Town Plans at the Castle.",
		"built": "Keeps the food left over from a trip.", "start": 0},
	"smithy": {"name": "Smithy", "job": "Not built yet. Build it from the Town Plans at the Castle.",
		"built": "Forges better gear for the Shop to sell.", "start": 0},
	"tavern": {"name": "Tavern", "job": "Hire adventurers and look after your roster.", "start": 1},
	"bank": {"name": "Bank", "job": "Pay the month's bills, and borrow gold.", "start": 1},
	"shop": {"name": "Shop", "job": "Buy gear for your people, and sell what trips bring home.", "start": 1},
	"portal": {"name": "Portal", "job": "Send your adventurer off to explore, and bring them home.", "start": 1},
}
## The files towns are kept in, in SaveGame.folder(): one per save slot.
const SAVE_FILE := "town_%d.save"
## Where saves were kept before there were slots. Moved into slot 1 when found.
const OLD_SAVE_FILE := "town.save"
## How many save slots there are.
const SLOT_COUNT := 3
## The slot kept for testing: made afresh with plenty of everything each time the game opens.
const TEST_SLOT := 3
const TEST_GOLD := 999999
const TEST_MATERIALS := 999
## Raise this when what a town saves changes. Older files are then refused.
const SAVE_VERSION := 1

static var _current: TownData
## The save slot the current town is kept in.
static var slot := 1
## Whether the test slot has been made afresh since the game opened.
static var _test_slot_ready := false

var gold := START_GOLD
## Today. See Calendar.
var day := 1
## Building id -> its level. See BUILDINGS for where each starts, and TownPlans for what
## raises it.
var buildings := {}
## The people on the books, in the order they joined.
var roster: Array[Member] = []
## Who goes through the Portal next, or null if nobody can.
var going: Adventurer
## Where the Portal leads, and how big a trip. The Portal screen changes this.
var stage: Stage = Database.get_stage(FIRST_STAGE)
## Days of food to buy for the next trip. The Portal screen changes this.
var food := 0
## How many months of bills have been paid.
var months_paid := 0
## What the current loan must repay, or 0 with no loan.
var loan_owed := 0
## The day the current loan must be repaid by.
var loan_due := 0
## What happened, for the game over screen: {"day", "text"}.
var history: Array[Dictionary] = []
## The strongest warning shown for each due day: due day -> an Alert.
var warned := {}
## What the town owns and nobody carries: item id -> how many. Trips fill it, and the Shop
## buys from it.
var stock := {}
## Materials brought home: material id -> how many.
var materials := {}
## Days of food the Storehouse keeps from earlier trips. It is eaten before any is bought.
var food_store := 0
## The King's letter now open, as a place in TownPlans.LETTERS.
var letter_index := 0
## How far the open letter's goal has come.
var letter_progress := 0
## The buildings whose plans letters have opened, besides those built from the start.
var opened: Array[String] = []
## The Castle's town tree spaces built, as TownTree ids.
var tree: Array[String] = []


func _init() -> void:
	for id: String in BUILDINGS:
		buildings[id] = BUILDINGS[id]["start"]


## The town of the current game.
static func current() -> TownData:
	if _current == null:
		start_new()
	return _current


## Throws the current town away and starts again.
static func start_new() -> void:
	_current = TownData.new()


## The building a player should go to next (rule U6). With nobody able to go, that is the
## Tavern, or the Bank for the gold to hire someone. Time never passes by itself.
func next_step() -> String:
	if alert() != Alert.NONE:
		return "bank"
	if letter_done():
		return "castle"
	if going != null:
		return "portal"
	return "tavern" if cheapest_fee() <= gold else "bank"


## What the cheapest adventurer asks. Anyone on the roster can be dismissed and hired back
## for their fee, so this is the price of having someone who can go.
func cheapest_fee() -> int:
	return Database.adventurers_by_fee()[0].fee


# --- The roster -------------------------------------------------------------

func member(person: Adventurer) -> Member:
	for one in roster:
		if one.person == person:
			return one
	return null


## Why `person` can't be hired, in a few words for a button, or "" if they can.
func hire_problem(person: Adventurer) -> String:
	if member(person) != null:
		return "On your roster"
	if roster.size() >= ROSTER_ROOM:
		return "Roster is full"
	if person.fee > gold:
		return "Need %d more gold" % (person.fee - gold)
	return ""


## Pays `person` and takes them on. Returns false, changing nothing, if that can't be done.
func hire(person: Adventurer) -> bool:
	if hire_problem(person) != "":
		return false
	gold -= person.fee
	roster.append(Member.new(person))
	remember("Hired %s for %d gold." % [person.display_name, person.fee])
	_pick_going()
	return true


## Lets `person` go, so that they are not on the next bill. Nothing is paid back.
func dismiss(person: Adventurer) -> bool:
	var one := member(person)
	if one == null:
		return false
	roster.erase(one)
	remember("Dismissed %s." % person.display_name)
	_pick_going()
	return true


## Chooses who goes next. Returns false, changing nothing, if they aren't ready.
func pick(person: Adventurer) -> bool:
	if not ready_people().has(person):
		return false
	going = person
	return true


## Everyone on the roster who can work today.
func ready_people() -> Array[Adventurer]:
	var found: Array[Adventurer] = []
	for one in roster:
		if one.is_ready(day):
			found.append(one.person)
	return found


# Keeps whoever is going if they can still go, or takes the first who can.
func _pick_going() -> void:
	var ready := ready_people()
	if not ready.has(going):
		going = null if ready.is_empty() else ready[0]


## Why nobody can go through the Portal, in a few words for a button, or "" if they can.
func send_problem() -> String:
	if roster.is_empty():
		return "Hire someone first"
	return "" if going != null else "Nobody is ready"


## What selling everything the town owns would raise: its stock, its materials, and what
## waits in the packs. Worn gear doesn't count, because nobody can go without it.
func goods_worth() -> int:
	var worth := 0
	for id: String in stock:
		worth += sell_price(id) * stock[id]
	for id: String in materials:
		worth += material_price(id) * materials[id]
	for one in roster:
		for id in one.pack:
			worth += sell_price(id)
	return worth


# The most gold that could be raised from `cash`, with the biggest loan taken. A loan in
# the way counts only if it can be repaid first.
func _most_gold(cash: int) -> int:
	var biggest: int = LOAN_SIZES[-1]
	if loan_owed == 0:
		return cash + biggest
	return maxi(cash, cash - loan_owed + biggest) if cash >= loan_owed else cash


func _out_of_money(cash: int) -> bool:
	return _most_gold(cash + goods_worth()) < cheapest_fee()


## True when nobody can go and all that could be borrowed and sold can't hire anyone. No
## time passes in town, so nothing would ever change: the town is lost.
func stranded() -> bool:
	return going == null and _out_of_money(gold)


## True if letting `person` go would leave the town stranded.
func dismiss_strands(person: Adventurer) -> bool:
	var others := ready_people()
	others.erase(person)
	return others.is_empty() and _out_of_money(gold)


## True if paying the bill now would leave the town stranded.
func bill_strands() -> bool:
	return going == null and _out_of_money(gold - bill_amount())


## True when nobody can go and there isn't the gold to hire anyone yet.
func short_to_hire() -> bool:
	return going == null and gold < cheapest_fee()


## True once the town can't go on, for whatever reason.
func lost() -> bool:
	return stranded() or not overdue().is_empty()


# --- Time -------------------------------------------------------------------

## Takes in what `trip` brought home. Call this once, when the trip is over.
func bring_home(trip: Expedition) -> void:
	var one := member(trip.person)
	gold += trip.gold_home()
	day += trip.trip_days
	one.trips += 1
	one.keep(trip.player)
	# The pack went out with them. What comes back belongs to the town.
	one.pack.clear()
	if trip.ending == Expedition.Ending.HOME:
		_take_bag(trip)
		food_store = mini(food_store + trip.food_left, store_room())
		one.trips_home += 1
		one.gold_home += trip.gold_home()
		remember("%s came home with %d gold." % [trip.person.display_name, trip.gold_home()])
	elif trip.ending == Expedition.Ending.WARPED and tree_perk(TownTree.SAFE_WARP) > 0.0:
		_take_bag(trip)
		remember("%s warped home, and the Safe Road brought the bag." % trip.person.display_name)
	elif trip.ending == Expedition.Ending.WARPED:
		remember("%s warped home, with nothing." % trip.person.display_name)
	elif tree_perk(TownTree.RESCUE) > 0.0 and gold >= TownTree.RESCUE_PRICE:
		gold -= TownTree.RESCUE_PRICE
		_take_bag(trip)
		one.ready_on = day + days_out_after_defeat()
		remember("%s came back hurt. The Rescue Party brought the bag home, for %d gold." % [
				trip.person.display_name, TownTree.RESCUE_PRICE])
	else:
		one.ready_on = day + days_out_after_defeat()
		remember("%s came back hurt, with nothing." % trip.person.display_name)
	_pick_going()


# What a trip carried comes to the town: its items and its materials.
func _take_bag(trip: Expedition) -> void:
	for id in trip.player.inventory:
		add_stock(id)
	for id in trip.materials:
		materials[id] = materials.get(id, 0) + 1
	_count_toward_letter("materials", trip.materials.size())
	_count_toward_letter("starstone", trip.materials.count("starstone"))


## The days someone beaten rests before they can work again.
func days_out_after_defeat() -> int:
	return maxi(OUT_AFTER_DEFEAT - roundi(tree_perk(TownTree.DAYS_OUT)), 1)


## What a day of food costs.
func food_price() -> int:
	return FOOD_PRICE + roundi(tree_perk(TownTree.FOOD_PRICE))


## The most days of food `person` can carry, on any trip: their Max Food at their level now.
func max_food(person: Adventurer) -> int:
	var one := member(person)
	return person.food_at() if one == null else one.max_food()


## The most days of food `person` can take, by what they carry, what the Storehouse keeps,
## and what the town can pay for.
func food_limit(person: Adventurer) -> int:
	return mini(max_food(person), food_store + gold / food_price())


## What `amount` days of food cost, after what the Storehouse keeps is used. -1 is the food
## chosen for the next trip.
func food_cost(amount := -1) -> int:
	return maxi((food if amount < 0 else amount) - food_store, 0) * food_price()


## The most days of food the Storehouse keeps, by its level.
func store_room() -> int:
	return TownPlans.STOREHOUSE_FOOD[level("storehouse")] + roundi(tree_perk(TownTree.STORE))


## Sets the food to all that the trip can take.
func fill_food() -> void:
	food = 0 if going == null else food_limit(going)


## Sets the food to `amount`, or as near as the trip allows.
func choose_food(amount: int) -> void:
	food = 0 if going == null else clampi(amount, 0, food_limit(going))


## Pays for the food, using what the Storehouse keeps first. Leftovers are lost unless the
## Storehouse keeps them, so this is never paid back.
func buy_food() -> void:
	gold -= food_cost()
	food_store -= mini(food, food_store)


## Notes that the adventurer has left, for the game over screen.
func remember_leaving() -> void:
	remember("%s left, with %d gold in town." % [going.display_name, gold])


func remember(text: String) -> void:
	history.append({"day": day, "text": text})


## `count` as words, such as "1 day" or "3 days".
static func days_words(count: int) -> String:
	return "1 day" if count == 1 else "%d days" % count


# --- The Shop ---------------------------------------------------------------

## What the Shop could sell: gear up to `dearest` gold, and every thing to use, by kind and
## then by price. Tomes are taught at the Academy, so the Shop only buys them.
static func shop_goods(dearest := 1 << 30) -> Array[String]:
	var goods: Array[String] = []
	for id in Database.sorted_ids(Database.items):
		var item := Database.get_item(id)
		if (item.is_gear() and item.price <= dearest) or item.kind == ItemData.Kind.CONSUMABLE:
			goods.append(id)
	goods.sort_custom(func(a: String, b: String) -> bool:
			var first := Database.get_item(a)
			var second := Database.get_item(b)
			if first.kind != second.kind:
				return SHOP_ORDER.find(first.kind) < SHOP_ORDER.find(second.kind)
			if first.price != second.price:
				return first.price < second.price
			return a < b)
	return goods


## What the Shop sells now. The Smithy's level says how dear its gear may be.
func on_sale() -> Array[String]:
	return shop_goods(TownPlans.SMITHY_GEAR[level("smithy")])


## What the Shop pays for one `item_id`.
static func sell_price(item_id: String) -> int:
	return int(Database.get_item(item_id).price * Shop.SELL_SHARE)


## What the Shop pays for one material `material_id`.
static func material_price(material_id: String) -> int:
	return int(Database.get_material(material_id).price * Shop.SELL_SHARE)


func stock_count(item_id: String) -> int:
	return stock.get(item_id, 0)


func add_stock(item_id: String, count := 1) -> void:
	stock[item_id] = stock_count(item_id) + count


# Takes one `item_id` out of the stock. Returns false if there is none.
func _take_stock(item_id: String) -> bool:
	if stock_count(item_id) == 0:
		return false
	stock[item_id] -= 1
	if stock[item_id] == 0:
		stock.erase(item_id)
	return true


## The stock's item ids in the Shop's order, each once.
func stock_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(stock.keys())
	ids.sort_custom(func(a: String, b: String) -> bool:
			var first := Database.get_item(a)
			var second := Database.get_item(b)
			if first.kind != second.kind:
				return SHOP_ORDER.find(first.kind) < SHOP_ORDER.find(second.kind)
			return first.price < second.price if first.price != second.price else a < b)
	return ids


## Why `item_id` can't be bought for `one`, in a few words for a button, or "" if it can.
## Gear is worn at once, and anything else goes in their pack.
func buy_problem(item_id: String, one: Member) -> String:
	var item := Database.get_item(item_id)
	if not on_sale().has(item_id):
		return "Not for sale"
	if not item.is_gear() and not one.pack_has_room():
		return "Pack is full"
	if item.price > gold:
		return "Need %d more gold" % (item.price - gold)
	return ""


## Buys `item_id` for `one`. What it replaces goes to the stock. Returns false, changing
## nothing, if that can't be done.
func buy(item_id: String, one: Member) -> bool:
	if buy_problem(item_id, one) != "":
		return false
	var item := Database.get_item(item_id)
	gold -= item.price
	_hand_over(item_id, one)
	remember("Bought a %s for %s." % [item.display_name, one.person.display_name])
	return true


## Why `item_id` from the stock can't go to `one`, in a few words, or "" if it can.
func give_problem(item_id: String, one: Member) -> String:
	if stock_count(item_id) == 0:
		return "None left"
	if Database.get_item(item_id).is_gear():
		return ""
	return "" if one.pack_has_room() else "Pack is full"


## Gives `one` the `item_id` from the stock, to wear or to pack.
func give(item_id: String, one: Member) -> bool:
	if give_problem(item_id, one) != "":
		return false
	_take_stock(item_id)
	_hand_over(item_id, one)
	return true


## Takes the item at `index` out of `one`'s pack and puts it in the stock.
func unpack(one: Member, index: int) -> bool:
	if index < 0 or index >= one.pack.size():
		return false
	add_stock(one.pack[index])
	one.pack.remove_at(index)
	return true


## Sells one `item_id` from the stock for half its price.
func sell(item_id: String) -> bool:
	if not _take_stock(item_id):
		return false
	gold += sell_price(item_id)
	return true


## Sells one material `material_id` for half its price.
func sell_material(material_id: String) -> bool:
	if materials.get(material_id, 0) == 0:
		return false
	materials[material_id] -= 1
	if materials[material_id] == 0:
		materials.erase(material_id)
	gold += material_price(material_id)
	return true


func _hand_over(item_id: String, one: Member) -> void:
	if Database.get_item(item_id).is_gear():
		var old := one.wear(item_id)
		if old != "":
			add_stock(old)
	else:
		one.pack.append(item_id)


# --- Buildings and the Town Plans ---------------------------------------------

func level(id: String) -> int:
	return buildings.get(id, 0)


## True once `id` stands, so that it can be used for what it does.
func is_built(id: String) -> bool:
	return level(id) > 0


## True with the Portal Beacon: walking past the Portal counts as landing on it.
func has_beacon() -> bool:
	return level("portal") >= 2


## What the sign of `id` says it does, as it stands now.
func job_words(id: String) -> String:
	var about: Dictionary = BUILDINGS[id]
	return about.get("built", about["job"]) if is_built(id) else about["job"]


# --- The town tree --------------------------------------------------------------

## The town tree perk `perk_name`, summed over the spaces built. See TownTree.
func tree_perk(perk_name: String) -> float:
	return TownTree.perk(tree, perk_name)


## The King's tax each month, with what the town tree's keystones add.
func king_tax() -> int:
	return KING_TAX + roundi(tree_perk(TownTree.TAX))


## How many Magic and Special moves one person can know.
func move_slots() -> int:
	return MoveData.MOST_LEARNED + roundi(tree_perk(TownTree.SLOTS))


## Why town tree space `id` can't be built, in a few words, or "" if it can.
func grow_problem(id: String) -> String:
	if tree.has(id):
		return "Built already"
	if not TownTree.can_take(tree, id):
		return "Build a space joined to it first"
	var found := TownTree.cost(id)
	if found["gold"] > gold:
		return "Need %d more gold" % (found["gold"] - gold)
	for material_id: String in found["materials"]:
		var short: int = found["materials"][material_id] - materials.get(material_id, 0)
		if short > 0:
			return "Need %d more %s" % [short, Database.get_material(material_id).display_name]
	return ""


## Builds town tree space `id`, paying for it. Returns false, changing nothing, if it can't.
func grow(id: String) -> bool:
	if grow_problem(id) != "":
		return false
	var found := TownTree.cost(id)
	gold -= found["gold"]
	for material_id: String in found["materials"]:
		materials[material_id] -= found["materials"][material_id]
		if materials[material_id] == 0:
			materials.erase(material_id)
	tree.append(id)
	remember("Built %s on the town tree." % TownTree.space(id)["name"])
	return true


## Gives `player`, who sets out from this town, what the town tree gives everyone.
func dress(player: PlayerData) -> void:
	player.town_stats.clear()
	player.town_perks.clear()
	for stat: String in ["attack", "defense", "magic", "speed", "max_hp", "max_mp"]:
		var add := TownTree.stat_add(tree, stat)
		if add != 0:
			player.town_stats[stat] = add
	for perk_name in TownTree.TRIP_PERKS:
		var value := tree_perk(perk_name)
		if value != 0.0:
			player.town_perks[perk_name] = value
	player.learn_slots = move_slots()


## True if a letter has opened the plans of `id`, or it stood from the start.
func is_opened(id: String) -> bool:
	return BUILDINGS[id]["start"] > 0 or opened.has(id)


## The plan that raises `id` next, or {} if there is none.
func next_plan(id: String) -> Dictionary:
	return TownPlans.plan(id, level(id))


## The buildings the Castle shows plans for, in the order shown: every one with a plan
## left, opened or not.
func plan_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in TownPlans.PLANS:
		if not next_plan(id).is_empty():
			ids.append(id)
	return ids


## Why the next plan for `id` can't be built, in a few words for a button, or "" if it can.
func plan_problem(id: String) -> String:
	var found := next_plan(id)
	if found.is_empty():
		return "Fully built"
	if not is_opened(id):
		return "Plans come in a Royal Letter"
	if found["gold"] > gold:
		return "Need %d more gold" % (found["gold"] - gold)
	for material_id: String in found["materials"]:
		var short: int = found["materials"][material_id] - materials.get(material_id, 0)
		if short > 0:
			return "Need %d more %s" % [short, Database.get_material(material_id).display_name]
	return ""


## Builds the next plan for `id`. Returns false, changing nothing, if that can't be done.
func build(id: String) -> bool:
	if plan_problem(id) != "":
		return false
	var found := next_plan(id)
	gold -= found["gold"]
	for material_id: String in found["materials"]:
		materials[material_id] -= found["materials"][material_id]
		if materials[material_id] == 0:
			materials.erase(material_id)
	buildings[id] = level(id) + 1
	var name: String = BUILDINGS[id]["name"]
	remember("Built the %s." % name if level(id) == 1 else "Raised the %s to level %d." % [name, level(id)])
	_count_toward_letter("built", 1)
	return true


# --- The King's letters -------------------------------------------------------

## The letter now open, or {} once the King has written all he means to.
func letter() -> Dictionary:
	return TownPlans.letter(letter_index)


## True when the open letter's goal is met and its reward waits at the Castle.
func letter_done() -> bool:
	var found := letter()
	return not found.is_empty() and letter_progress >= found["count"]


## Takes the reward of a finished letter, opens its plans, and opens the next letter.
## Returns false, changing nothing, if the goal is not met yet.
func claim_letter() -> bool:
	if not letter_done():
		return false
	var found := letter()
	gold += found["gold"]
	for id: String in found["opens"]:
		if not opened.has(id):
			opened.append(id)
	remember("Did what the King asked in \"%s\", for %d gold." % [found["title"], found["gold"]])
	letter_index += 1
	letter_progress = 0
	return true


func _count_toward_letter(goal: String, amount: int) -> void:
	var found := letter()
	if not found.is_empty() and found["goal"] == goal:
		letter_progress = mini(letter_progress + amount, found["count"])


# --- The Academy --------------------------------------------------------------

## The tomes whose moves the Academy teaches now, cheapest first. A move costs what its
## tome costs.
func teachable() -> Array[String]:
	var ids: Array[String] = []
	var dearest: int = TownPlans.ACADEMY_MOVES[level("academy")]
	for id in Database.sorted_ids(Database.items):
		var item := Database.get_item(id)
		if item.kind == ItemData.Kind.TOME and item.price <= dearest:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
			var first := Database.get_item(a).price
			var second := Database.get_item(b).price
			return first < second if first != second else a < b)
	return ids


## Why `one` can't be taught the move of `tome_id`, in a few words, or "" if they can.
## With both slots full, `forgotten` must name a move they know.
func teach_problem(tome_id: String, one: Member, forgotten := "") -> String:
	var item := Database.get_item(tome_id)
	if not teachable().has(tome_id):
		return "Not taught here"
	if one.learned.has(item.teaches):
		return "Knows it already"
	if item.price > gold:
		return "Need %d more gold" % (item.price - gold)
	if one.learned.size() >= move_slots() and not one.learned.has(forgotten):
		return "Choose a move to forget"
	return ""


## Teaches `one` the move of `tome_id`, forgetting `forgotten` if both slots are full.
func teach(tome_id: String, one: Member, forgotten := "") -> bool:
	if teach_problem(tome_id, one, forgotten) != "":
		return false
	var item := Database.get_item(tome_id)
	gold -= item.price
	if one.learned.size() >= move_slots():
		one.learned.erase(forgotten)
	one.learned.append(item.teaches)
	remember("%s learned %s." % [one.person.display_name, Database.get_move(item.teaches).display_name])
	return true


## Why `one`'s skill tree points can't be taken back at the Academy, or "".
func reset_problem(one: Member) -> String:
	if one.tree.is_empty():
		return "No points spent"
	if one.reset_price() > gold:
		return "Need %d more gold" % (one.reset_price() - gold)
	return ""


## Takes back every skill tree point `one` has spent, for gold, so they can spend them again.
func reset_tree(one: Member) -> bool:
	if reset_problem(one) != "":
		return false
	gold -= one.reset_price()
	one.tree.clear()
	remember("%s took back their skill tree points." % one.person.display_name)
	return true


# --- Saving -------------------------------------------------------------------

## The file of save slot `which`, or of the current slot.
static func save_path(which := 0) -> String:
	_move_old_save()
	return SaveGame.folder().path_join(SAVE_FILE % (slot if which == 0 else which))


static func has_save(which := 0) -> bool:
	return FileAccess.file_exists(save_path(which))


static func delete_save(which := 0) -> void:
	if has_save(which):
		DirAccess.remove_absolute(save_path(which))


## Writes the town to its slot's file. A lost town is never kept: its file is deleted instead.
func save() -> void:
	if lost():
		delete_save()
		return
	var file := FileAccess.open(save_path(), FileAccess.WRITE)
	if file != null:
		file.store_var(to_save())


## Makes the town saved in slot `which` (or the current slot) the current one, and that
## slot the current slot. Returns false, changing nothing, if there is no save or it
## can't be read.
static func load_saved(which := 0) -> bool:
	var saved := read_slot(which)
	if saved.is_empty():
		return false
	var town := from_save(saved)
	if town == null:
		return false
	if which != 0:
		slot = which
	_current = town
	return true


## What slot `which` holds, as plain values, or {} if it is empty or can't be read.
static func read_slot(which := 0) -> Dictionary:
	if not has_save(which):
		return {}
	var file := FileAccess.open(save_path(which), FileAccess.READ)
	if file == null:
		return {}
	var saved: Variant = file.get_var(false)
	if not saved is Dictionary or saved.get("version", 0) != SAVE_VERSION:
		return {}
	return saved


## The slot of ordinary play saved to most recently, or 0 if they are all empty.
static func newest_slot() -> int:
	var found := 0
	var latest := 0
	for which in range(1, SLOT_COUNT + 1):
		if which == TEST_SLOT or not has_save(which):
			continue
		var saved_at := FileAccess.get_modified_time(save_path(which))
		if saved_at > latest:
			latest = saved_at
			found = which
	return found


## Throws away whatever the test slot holds and puts a new town there with the King's
## first letter already done and claimed (so its plans are open), TEST_GOLD gold and
## TEST_MATERIALS of every material. Done once each time the game opens. The current
## town and slot are left as they were.
static func reset_test_slot() -> void:
	var town := TownData.new()
	town.letter_progress = town.letter()["count"]
	town.claim_letter()
	town.gold = TEST_GOLD
	for id: String in Database.materials:
		town.materials[id] = TEST_MATERIALS
	var file := FileAccess.open(save_path(TEST_SLOT), FileAccess.WRITE)
	if file != null:
		file.store_var(town.to_save())
	_test_slot_ready = true


## Resets the test slot if that has not been done since the game opened.
static func ready_test_slot() -> void:
	if not _test_slot_ready:
		reset_test_slot()


## A town saved before there were slots goes into slot 1, unless slot 1 is taken.
static func _move_old_save() -> void:
	var folder := SaveGame.folder()
	var old := folder.path_join(OLD_SAVE_FILE)
	var first := folder.path_join(SAVE_FILE % 1)
	if FileAccess.file_exists(old) and not FileAccess.file_exists(first):
		DirAccess.rename_absolute(old, first)


## The town as plain values, which hold no objects and so can't run code when read.
func to_save() -> Dictionary:
	var people := []
	for one in roster:
		people.append({
			"person": one.person.id, "ready_on": one.ready_on, "trips": one.trips,
			"trips_home": one.trips_home, "gold_home": one.gold_home, "level": one.level,
			"experience": one.experience, "equipment": one.equipment.duplicate(),
			"learned": one.learned.duplicate(), "pack": one.pack.duplicate(), "tree": one.tree.duplicate(),
		})
	return {
		"version": SAVE_VERSION, "gold": gold, "day": day, "buildings": buildings.duplicate(),
		"roster": people, "going": "" if going == null else going.id, "stage": stage.id,
		"food": food, "months_paid": months_paid, "loan_owed": loan_owed, "loan_due": loan_due,
		"history": history.duplicate(true), "warned": warned.duplicate(), "stock": stock.duplicate(),
		"materials": materials.duplicate(), "food_store": food_store, "letter_index": letter_index,
		"letter_progress": letter_progress, "opened": opened.duplicate(), "tree": tree.duplicate(),
	}


## A town made from what to_save() wrote, or null if it names someone who is gone.
static func from_save(saved: Dictionary) -> TownData:
	var town := TownData.new()
	town.gold = saved["gold"]
	town.day = saved["day"]
	for id: String in saved["buildings"]:
		if BUILDINGS.has(id):
			town.buildings[id] = saved["buildings"][id]
	for kept: Dictionary in saved["roster"]:
		var person := Database.get_adventurer(kept["person"])
		if person == null:
			return null
		var one := Member.new(person)
		for key: String in ["ready_on", "trips", "trips_home", "gold_home", "level", "experience"]:
			one.set(key, kept[key])
		one.equipment = kept["equipment"].duplicate()
		one.learned.assign(kept["learned"])
		one.pack.assign(kept["pack"])
		for id: String in kept.get("tree", []):
			if SkillTree.can_take(person.class_id, one.tree, id):
				one.tree.append(id)
		town.roster.append(one)
	var found_stage := Database.get_stage(saved["stage"])
	if found_stage != null:
		town.stage = found_stage
	town.food = saved["food"]
	town.months_paid = saved["months_paid"]
	town.loan_owed = saved["loan_owed"]
	town.loan_due = saved["loan_due"]
	town.history.assign(saved["history"])
	town.warned = saved["warned"].duplicate()
	town.stock = saved["stock"].duplicate()
	town.materials = saved["materials"].duplicate()
	town.food_store = saved["food_store"]
	town.letter_index = saved["letter_index"]
	town.letter_progress = saved["letter_progress"]
	town.opened.assign(saved["opened"])
	for id: String in saved.get("tree", []):
		if TownTree.can_take(town.tree, id):
			town.tree.append(id)
	for one in town.roster:
		if one.person.id == saved["going"]:
			town.going = one.person
	town._pick_going()
	return town


# --- Bills ------------------------------------------------------------------

## The last day to pay the next bill.
func bill_due() -> int:
	return Calendar.DAYS_IN_MONTH * (months_paid + BILL_FREE_MONTHS + 1)


## True once the next bill is on the Bank's list, which is all through its month.
func bill_open() -> bool:
	return day > bill_due() - Calendar.DAYS_IN_MONTH


## Who is on the roster right now is on the bill. Each line is {"text", "amount"}.
func bill_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = [{"text": "The King's tax", "amount": king_tax()}]
	for one in roster:
		lines.append({"text": "%s's wage" % one.person.display_name, "amount": one.person.wage})
	return lines


func bill_amount() -> int:
	var total := 0
	for line in bill_lines():
		total += line["amount"]
	return total


## Why the bill can't be paid, in a few words for a button, or "" if it can.
func pay_problem() -> String:
	if not bill_open():
		if months_paid == 0:
			return "No bill yet"
		return "Paid until %s" % Calendar.date(bill_due() - Calendar.DAYS_IN_MONTH)
	if bill_amount() > gold:
		return "Need %d more gold" % (bill_amount() - gold)
	return ""


## Pays the whole bill. Returns false, changing nothing, if that can't be done.
func pay_bill() -> bool:
	if pay_problem() != "":
		return false
	var amount := bill_amount()
	gold -= amount
	months_paid += 1
	remember("Paid the bill of %d gold." % amount)
	return true


# --- Loans ------------------------------------------------------------------

## What borrowing `amount` costs to repay.
static func loan_repays(amount: int) -> int:
	return amount + roundi(amount * LOAN_INTEREST)


## Why a loan can't be taken, in a few words for a button, or "" if it can.
func borrow_problem() -> String:
	return "One loan at a time" if loan_owed > 0 else ""


## The day a loan taken today must be repaid by.
func new_loan_due() -> int:
	return day + LOAN_DAYS


## Takes a loan of `amount`. Returns false, changing nothing, if that can't be done.
func borrow(amount: int) -> bool:
	if borrow_problem() != "" or not LOAN_SIZES.has(amount):
		return false
	gold += amount
	loan_owed = loan_repays(amount)
	loan_due = new_loan_due()
	remember("Borrowed %d gold, to repay %d by %s." % [amount, loan_owed, Calendar.date(loan_due)])
	return true


## Why the loan can't be repaid, in a few words for a button, or "" if it can.
func repay_problem() -> String:
	if loan_owed == 0:
		return "No loan"
	return "Need %d more gold" % (loan_owed - gold) if loan_owed > gold else ""


## Repays the whole loan. Returns false, changing nothing, if that can't be done.
func repay() -> bool:
	if repay_problem() != "":
		return false
	gold -= loan_owed
	remember("Repaid the loan of %d gold." % loan_owed)
	loan_owed = 0
	loan_due = 0
	return true


# --- What is owed -----------------------------------------------------------

## Whatever falls due first, as {"what", "amount", "due"}. There is always a next bill.
func next_debt() -> Dictionary:
	var bill := {"what": "bill", "amount": bill_amount(), "due": bill_due()}
	if loan_owed > 0 and loan_due < bill["due"]:
		return {"what": "loan", "amount": loan_owed, "due": loan_due}
	return bill


## The next due day of anything unpaid.
func next_due() -> int:
	return next_debt()["due"]


## How worried to be on `on_day`, which is today unless a trip is under way.
func alert(on_day := -1) -> Alert:
	var left := next_due() - (day if on_day < 0 else on_day)
	if left <= ALARM_DAYS:
		return Alert.ALARM
	return Alert.WARN if left <= WARN_DAYS else Alert.NONE


## Records that the player has been shown the warning for `on_day`, and returns its
## Alert. Every screen that warns calls this, so a test can prove a warning came first.
func show_alert(on_day := -1) -> Alert:
	var level := alert(on_day)
	var due := next_due()
	warned[due] = maxi(warned.get(due, Alert.NONE), level)
	return level


## What has gone past its due day unpaid, as next_debt() gives it, or {} if nothing has.
func overdue() -> Dictionary:
	var debt := next_debt()
	return debt if day > debt["due"] else {}


## The last `lines` things that happened, ending with what lost the town.
func final_story(lines: int) -> Array[Dictionary]:
	var story: Array[Dictionary] = history.slice(-lines)
	var debt := overdue()
	if not debt.is_empty():
		var words := "The %s of %d gold was not paid." % [debt["what"], debt["amount"]]
		story.append({"day": debt["due"], "text": words})
	elif stranded():
		story.append({"day": day, "text": "Nobody could work, and no gold could be found to hire anyone."})
	return story


## What a trip to `trip_stage` looks like against the next due day: {"home", "due", "fit"}.
## "home" is the day they are back, as every trip there takes the same days, and "fit" is a
## Forecast. Being home on the due day is in time, as it can still be paid that day.
func forecast(trip_stage: Stage) -> Dictionary:
	var home: int = day + trip_stage.days
	var due := next_due()
	return {"home": home, "due": due, "fit": Forecast.LATE if home > due else Forecast.SAFE}
