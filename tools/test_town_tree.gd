extends "res://tools/test_kit.gd"
## Tests the Castle's town tree (E22): its shape, costs, every perk reaching the town, a
## trip and a fight, the save, and the Castle screen. Run with:
##   godot --headless --path . res://tools/test_town_tree.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const CASTLE := "res://castle/CastleScreen.tscn"
const ACADEMY := "res://academy/AcademyScreen.tscn"


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	TownData.delete_save()
	_test_shape()
	_test_building()
	_test_logistics()
	_test_training()
	_test_safety()
	_test_saving()
	await _test_castle_screen()
	await _test_academy_slots()
	TownData.delete_save()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _town() -> TownData:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 10000
	town.hire(Database.get_adventurer("bram"))
	town.gold = 100000
	town.materials = {"wood": 50, "ore": 50, "wild_herbs": 50, "starstone": 10}
	return town


# Builds every space on the way to `id`, then `id`.
func _grow_to(town: TownData, id: String) -> void:
	var path: Array[String] = []
	var step := id
	while step != "":
		path.push_front(step)
		if TownTree.is_root(step):
			break
		var back := ""
		for other: String in TownTree.links(step):
			if TownTree.space(other)["depth"] < TownTree.space(step)["depth"]:
				back = other
		step = back
	for one in path:
		if not town.tree.has(one):
			_expect(town.grow(one), "%s can be built" % one)


func _player(town: TownData) -> PlayerData:
	return town.roster[0].sheet()


func _test_shape() -> void:
	var ids := TownTree.ids()
	_expect(ids.size() == 3 * TownTree.branch_size() and ids.size() == 33, "the tree has 33 spaces")
	var cells := {}
	for id in ids:
		var found := TownTree.space(id)
		_expect(not cells.has(found["cell"]), "%s has a cell of its own" % id)
		cells[found["cell"]] = id
		for perk_name: String in found["perks"]:
			_expect(perk_name in TownTree.TRIP_PERKS or perk_name in [TownTree.FOOD_TIMES, TownTree.FOOD_PRICE,
					TownTree.STORE, TownTree.SLOTS, TownTree.TAX, TownTree.DAYS_OUT, TownTree.RESCUE,
					TownTree.SAFE_WARP], "%s's perk %s is read somewhere" % [id, perk_name])
		var cost := TownTree.cost(id)
		_expect(cost["gold"] > 0, "%s costs gold" % id)
	for branch in 3:
		var letter := TownTree.BRANCH_LETTERS[branch]
		_expect(TownTree.space(letter + "M3")["size"] == TownTree.Size.KEYSTONE, "branch %d ends in a keystone" % branch)
		_expect(TownTree.space(letter + "M2")["size"] == TownTree.Size.NOTABLE, "with a notable before it")
		_expect(TownTree.cost(letter + "M3")["materials"].has("starstone"), "a keystone needs Starstone")
	_expect(TownTree.can_take([], "a1") and not TownTree.can_take([], "a2"), "only a branch's first space opens it")
	_expect(TownTree.can_take(["a1", "a2"], "aL1") and TownTree.can_take(["a1", "a2"], "aR1"), "the trunk forks into lanes")


func _test_building() -> void:
	var town := _town()
	town.gold = 10
	_expect(town.grow_problem("a1") == "Need 60 more gold", "a space costs gold")
	_expect(not town.grow("a1") and town.tree.is_empty(), "and can't be built without it")
	_expect(town.grow_problem("a2") == "Build a space joined to it first", "nor before what joins it")
	town.gold = 1000
	town.materials = {}
	_expect(town.grow("a1") and town.gold == 930 and town.tree == (["a1"] as Array[String]), "building pays its gold")
	_expect(not town.grow("a1") and town.grow_problem("a1") == "Built already", "a space is built once")
	town.grow("a2")
	_expect(town.grow_problem("aL1") == "Need 1 more Wood", "deeper spaces need materials")
	town.materials = {"wood": 1}
	_expect(town.grow("aL1") and not town.materials.has("wood"), "and use them up")
	_expect(town.history[-1]["text"].contains("town tree"), "the town remembers it")


func _test_logistics() -> void:
	var town := _town()
	var food := town.max_food(town.roster[0].person)
	var bag := _player(town).bag_size
	_grow_to(town, "a2")
	_expect(town.max_food(town.roster[0].person) == food + 2, "Max Food +1 twice")
	_grow_to(town, "aL3")
	var room := town.store_room()
	_expect(room == TownPlans.STOREHOUSE_FOOD[0] + 10, "the Cellar keeps 10 days even with no Storehouse")
	_grow_to(town, "aM2")
	_expect(_player(town).bag_size == bag + 1, "Pack Frames hold one more item")
	var before := town.max_food(town.roster[0].person)
	_expect(town.food_price() == TownData.FOOD_PRICE, "food costs what it did")
	_grow_to(town, "aM3")
	_expect(town.max_food(town.roster[0].person) == floori(before * 1.25), "Supply Train: Max Food x1.25")
	_expect(town.food_price() == TownData.FOOD_PRICE + 1 and town.food_cost(10) == 10 * (TownData.FOOD_PRICE + 1),
			"but food costs 1 more gold a day")
	_grow_to(town, "aR3")
	_expect(is_equal_approx(_player(town).perk(SkillTree.FOOD_SAVED), 0.1), "Trail Rations save a day in ten")
	_expect(is_equal_approx(_player(town).rest_share, Expedition.CAMP_SHARE + 0.06), "and the lane's Camp space heals more")
	var stranger := Expedition.make_player(Database.get_adventurer("wren"), true, null)
	_expect(stranger.perk(SkillTree.FOOD_SAVED) == 0.0 and stranger.bag_size == PlayerData.INVENTORY_SIZE,
			"someone not on the roster gets nothing from the town")


func _test_training() -> void:
	var town := _town()
	var plain := _player(town)
	_grow_to(town, "bL3")
	var drilled := _player(town)
	for stat in ["attack", "defense", "magic"]:
		_expect(drilled.get_stat(stat) == plain.get_stat(stat) + 2, "Drill Yard gives %s +2" % stat)
	_expect(drilled.get_stat("max_hp") == plain.get_stat("max_hp") + 10, "and its lane gives HP")
	_expect(is_equal_approx(drilled.perk(SkillTree.EXP), 0.1), "the trunk gives 10% EXP")
	_expect(town.move_slots() == MoveData.MOST_LEARNED, "two move slots")
	_grow_to(town, "bM2")
	_expect(town.move_slots() == MoveData.MOST_LEARNED + 1 and _player(town).learn_slots == 3, "the Library gives a third")
	var tax := town.king_tax()
	_grow_to(town, "bM3")
	_expect(is_equal_approx(_player(town).perk(SkillTree.EXP), 0.65), "War College: 50% more EXP")
	_expect(town.king_tax() == tax + 100 and town.bill_lines()[0]["amount"] == TownData.KING_TAX + 100,
			"but the King's tax rises by 100")
	_grow_to(town, "bR3")
	_expect(is_equal_approx(_player(town).perk(SkillTree.FLEE), 0.1), "Retreat Drill: fleeing works more often")
	# A fight reads the town's EXP.
	_expect(Fighter.from_player(_player(town)).perk(SkillTree.FLEE) > 0.0, "a fighter carries the town's perks")


func _ended(town: TownData, ending: Expedition.Ending) -> Expedition:
	var one := town.roster[0]
	var trip := Expedition.new(one.person, town.stage, 11, true, 3, one)
	trip.day = 3
	trip.materials.assign(["wood", "ore"])
	trip.ending = ending
	return trip


func _test_safety() -> void:
	var town := _town()
	town.materials = {}
	town.bring_home(_ended(town, Expedition.Ending.BEATEN))
	_expect(town.materials.is_empty(), "with no Rescue Party, a defeat loses the bag")
	_expect(town.roster[0].days_out(town.day) == TownData.OUT_AFTER_DEFEAT, "and rests a week")
	town.roster[0].ready_on = 0
	town.materials = {"ore": 50, "wild_herbs": 50, "wood": 50, "starstone": 10}
	_grow_to(town, "cL3")
	_expect(town.days_out_after_defeat() == TownData.OUT_AFTER_DEFEAT - 4, "the Field Hospital: 4 fewer days")
	_grow_to(town, "cM2")
	town.materials = {}
	var gold := town.gold
	town.bring_home(_ended(town, Expedition.Ending.BEATEN))
	_expect(town.materials == {"wood": 1, "ore": 1} and town.gold == gold - TownTree.RESCUE_PRICE,
			"the Rescue Party brings the bag home, for 50 gold")
	_expect(town.roster[0].days_out(town.day) == 3, "and the beaten rest 3 days")
	town.roster[0].ready_on = 0
	town.gold = 10
	town.materials = {}
	town.bring_home(_ended(town, Expedition.Ending.STARVED))
	_expect(town.materials.is_empty() and town.gold == 10, "with no gold for it, nothing comes")
	town.roster[0].ready_on = 0
	town.gold = 100000
	town.bring_home(_ended(town, Expedition.Ending.WARPED))
	_expect(town.materials.is_empty(), "a warp brings nothing home")
	town.materials = {"ore": 50, "starstone": 10}
	_grow_to(town, "cR3")
	town.materials = {}
	gold = town.gold
	town.bring_home(_ended(town, Expedition.Ending.WARPED))
	_expect(town.materials == {"wood": 1, "ore": 1} and town.gold == gold, "the Safe Road brings it, free")
	town.materials = {"ore": 50, "starstone": 10}
	_grow_to(town, "cM3")
	var player := _player(town)
	_expect(player.perk(SkillTree.SEE_MONSTERS) > 0.0 and player.perk(SkillTree.SEE_CHESTS) > 0.0,
			"Watchtowers show monsters and chests")
	var trip := Expedition.new(town.roster[0].person, town.stage, 11, true, 3, town.roster[0])
	_expect(trip.player.perk(SkillTree.SEE_MONSTERS) > 0.0, "on a real trip")
	_expect(town.king_tax() == TownData.KING_TAX + 100, "for 100 more tax")


func _test_saving() -> void:
	var town := _town()
	_grow_to(town, "bM2")
	town.save()
	_expect(TownData.load_saved(), "the town loads")
	_expect(TownData.current().tree == town.tree, "with its tree")
	var saved := town.to_save()
	saved.erase("tree")
	_expect(TownData.from_save(saved).tree.is_empty(), "an older save has no tree")
	saved["tree"] = ["aM3", "a1"]
	_expect(TownData.from_save(saved).tree == (["a1"] as Array[String]), "spaces with nothing before them are dropped")


func _test_castle_screen() -> void:
	var town := _town()
	town.gold = 1000
	town.materials = {}
	var castle: CastleScreen = await _open(CASTLE)
	_expect(not castle.tree_open and not castle.tree_grid.visible, "the Castle opens on the plans")
	castle.tree_tab.pressed.emit()
	await _wait()
	_expect(castle.tree_open and castle.tree_grid.visible and castle.tree_tab.lit, "the Town Tree tab shows the tree")
	_expect(castle.tree_grid.spots.size() == 33, "with every space")
	castle.pick_space("a2")
	await _wait()
	_expect(castle.action.disabled and castle.shown_hint() == "Build a space joined to it first.", "a closed space can't be built")
	castle.pick_space("a1")
	await _wait()
	_expect(not castle.action.disabled and castle.action.text == "Build it", "the first space can")
	castle.action.pressed.emit()
	await _wait()
	_expect(town.tree.has("a1") and town.gold == 930, "pressing Build it builds it")
	_expect(castle.action.text == "Built" and castle.action.disabled, "and the card says so")
	castle.pick_space("a2")
	await _wait()
	castle.tree_grid.chosen.emit("a2")
	await _wait()
	_expect(town.tree.has("a2"), "clicking a picked space builds it")
	castle.pick_space("aM3")
	await _wait()
	_expect(castle.shown_hint() == "Build a space joined to it first.", "the keystone waits")
	castle.plans_tab.pressed.emit()
	await _wait()
	_expect(not castle.tree_open and castle.tiles.size() > 0 and castle.tiles[0].is_visible_in_tree(), "Town Plans come back")


func _test_academy_slots() -> void:
	var town := _town()
	town.buildings["academy"] = 2
	var one := town.roster[0]
	while one.learned.size() < MoveData.MOST_LEARNED:
		one.learned.append("spark" if not one.learned.has("spark") else "hex")
	var tome := ""
	for id in town.teachable():
		if not one.learned.has(Database.get_item(id).teaches):
			tome = id
			break
	_expect(town.teach_problem(tome, one) == "Choose a move to forget", "with two slots full, a move must go")
	_grow_to(town, "bM2")
	_expect(town.teach_problem(tome, one) == "", "the Library makes room for a third")
	_expect(town.teach(tome, one) and one.learned.size() == 3, "and a third is learned")
	_expect(_player(town).learned.size() == 3, "and taken on a trip")
	var academy: AcademyScreen = await _open(ACADEMY)
	_expect(academy.swaps.size() == 3, "the Academy offers 3 moves to forget")
