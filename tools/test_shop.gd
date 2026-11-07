extends "res://tools/test_kit.gd"
## Tests the Shop, the town's stock and materials, with no window. Run with:
##   godot --headless --path . res://tools/test_shop.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const SHOP := "res://shop/ShopScreen.tscn"


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	_test_kit_at_hire()
	_test_buying()
	_test_selling_and_giving()
	_test_bag_comes_home()
	_test_defeat_loses_the_bag()
	_test_bag_pays_a_bill()
	_test_materials_on_a_trip()
	_test_full_materials_bag()
	_test_deep_chest()
	await _test_shop_screen()
	await _test_shop_with_keys()
	await _test_town_shows_materials()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _town(gold := 1000) -> TownData:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 10000
	town.hire(Database.get_adventurer("bram"))
	town.gold = gold
	# A full Smithy, so that every piece of gear is on sale. test_upgrades.gd tests less.
	town.buildings["smithy"] = 2
	return town


func _test_kit_at_hire() -> void:
	var town := _town()
	var one := town.roster[0]
	var data := Database.get_class_data(one.person.class_id)
	_expect(one.equipment[ItemData.Kind.WEAPON] == data.starting_equipment[0], "a new hire wears their class's gear")
	_expect(one.pack == data.starting_items, "and packs their class's items")
	var trip := Expedition.new(one.person, town.stage, 7, true, 3, one)
	_expect(trip.player.inventory == one.pack, "a trip sets out with the pack")
	_expect(trip.player.equipment == one.equipment, "and the gear")


func _test_buying() -> void:
	var town := _town(1000)
	var one := town.roster[0]
	var old_weapon: String = one.equipment[ItemData.Kind.WEAPON]
	var sword := Database.get_item("iron_sword")
	_expect(TownData.shop_goods().has("iron_sword") and TownData.shop_goods().has("potion"), "the Shop sells gear and things to use")
	_expect(not TownData.shop_goods().has("tome_hex"), "but not tomes")
	_expect(Database.get_item(TownData.shop_goods()[0]).kind == ItemData.Kind.WEAPON, "weapons come first")
	_expect(town.buy("iron_sword", one), "gear can be bought")
	_expect(town.gold == 1000 - sword.price, "at its price")
	_expect(one.equipment[ItemData.Kind.WEAPON] == "iron_sword", "and is worn at once")
	_expect(town.stock_count(old_weapon) == 1, "and what it replaced goes to the stock")
	var pack_before := one.pack.size()
	_expect(town.buy("potion", one) and one.pack.size() == pack_before + 1, "a potion goes in the pack")
	while one.pack_has_room():
		one.pack.append("herb")
	_expect(town.buy_problem("potion", one) == "Pack is full", "a full pack can't take more")
	_expect(not town.buy("potion", one), "so nothing is bought")
	town.gold = 10
	_expect(town.buy_problem("plate_armor", one).begins_with("Need"), "nobody buys without the gold")
	var before := one.equipment.duplicate()
	_expect(not town.buy("plate_armor", one) and one.equipment == before and town.gold == 10, "and nothing changes")


func _test_selling_and_giving() -> void:
	var town := _town(0)
	var one := town.roster[0]
	town.add_stock("chain_mail")
	town.add_stock("herb", 2)
	_expect(town.sell("herb") and town.gold == Database.get_item("herb").price / 2, "selling pays half the price")
	_expect(town.stock_count("herb") == 1, "and takes one from the stock")
	_expect(town.goods_worth() >= TownData.sell_price("chain_mail") + TownData.sell_price("herb"), "the stock counts toward what the town is worth")
	var old_armor: String = one.equipment[ItemData.Kind.ARMOR]
	_expect(town.give("chain_mail", one), "stock gear can be given")
	_expect(one.equipment[ItemData.Kind.ARMOR] == "chain_mail" and town.stock_count("chain_mail") == 0, "and is worn")
	_expect(town.stock_count(old_armor) == 1, "and the old armor goes to the stock")
	var size := one.pack.size()
	_expect(town.give("herb", one) and one.pack.size() == size + 1, "a herb from the stock goes in the pack")
	_expect(town.unpack(one, one.pack.size() - 1) and town.stock_count("herb") == 1, "and can be taken out again")
	_expect(not town.sell("elixir"), "nothing sells that isn't there")
	town.materials = {"wood": 2}
	var gold := town.gold
	_expect(town.sell_material("wood") and town.gold == gold + TownData.material_price("wood"), "materials sell for half")
	_expect(town.materials["wood"] == 1, "one at a time")


func _home_trip(town: TownData, ending: Expedition.Ending) -> Expedition:
	var one := town.roster[0]
	var trip := Expedition.new(one.person, town.stage, 11, true, 3, one)
	trip.player.inventory.assign(["potion", "tome_hex"])
	trip.materials.assign(["wood", "wood", "starstone"])
	trip.player.gold = 80
	trip.ending = ending
	return trip


func _test_bag_comes_home() -> void:
	var town := _town(0)
	var trip := _home_trip(town, Expedition.Ending.HOME)
	town.bring_home(trip)
	_expect(town.stock_count("potion") == 1 and town.stock_count("tome_hex") == 1, "the bag goes into the stock")
	_expect(town.materials == {"wood": 2, "starstone": 1}, "and the materials to the town")
	_expect(town.roster[0].pack.is_empty(), "and the pack is used up")
	var report := TripReport.new(trip)
	_expect(report.items_home.size() == 2 and report.materials_home["wood"] == 2, "the report lists what came home")


func _test_defeat_loses_the_bag() -> void:
	var town := _town(0)
	var trip := _home_trip(town, Expedition.Ending.BEATEN)
	town.bring_home(trip)
	_expect(town.stock.is_empty() and town.materials.is_empty(), "a defeat loses the bag and the materials")
	_expect(town.roster[0].pack.is_empty(), "and the pack")
	var report := TripReport.new(trip)
	_expect(report.loss.contains("2 items") and report.loss.contains("3 materials"), "and the report says so: %s" % report.loss)


func _test_bag_pays_a_bill() -> void:
	var town := _town(0)
	town.day = Calendar.DAYS_IN_MONTH + 2
	var trip := _home_trip(town, Expedition.Ending.HOME)
	trip.player.inventory.assign(["iron_sword", "plate_armor", "elixir"])
	town.bring_home(trip)
	_expect(town.pay_problem() != "", "the bill can't be paid from the gold alone")
	for id in town.stock_ids():
		while town.stock_count(id) > 0:
			town.sell(id)
	for id: String in town.materials.keys():
		while town.materials.get(id, 0) > 0:
			town.sell_material(id)
	_expect(town.pay_problem() == "" and town.pay_bill(), "but selling what came home pays it")


func _test_materials_on_a_trip() -> void:
	var bram := Database.get_adventurer("bram")
	var trip := Expedition.new(bram, Database.get_stage(TownData.FIRST_STAGE), 5, false)
	trip.play_to_end()
	_expect(trip.materials.size() <= Expedition.MATERIAL_ROOM, "the materials bag holds at most %d" % Expedition.MATERIAL_ROOM)
	for id in trip.materials:
		_expect(Database.get_material(id) != null, "a trip only finds real materials")
	var found := 0
	for line in trip.diary:
		if line["kind"] == "material":
			found += 1
	_expect(found >= trip.materials.size(), "every material found is in the diary")


func _test_full_materials_bag() -> void:
	var bram := Database.get_adventurer("bram")
	var trip := Expedition.new(bram, Database.get_stage(TownData.FIRST_STAGE), 5, true)
	for index in Expedition.MATERIAL_ROOM:
		trip.materials.append("wood")
	trip._gain_material("starstone")
	_expect(trip.found_material == "starstone" and trip.materials.size() == Expedition.MATERIAL_ROOM, "a full bag asks the player")
	trip.keep_material("wood")
	_expect(trip.materials.has("starstone") and trip.materials.count("wood") == Expedition.MATERIAL_ROOM - 1, "and one can be left behind")
	_expect(trip.found_material == "", "and the question is answered")
	trip._gain_material("ore")
	trip.keep_material("")
	_expect(not trip.materials.has("ore"), "or the new one left instead")
	var bot := Expedition.new(bram, Database.get_stage(TownData.FIRST_STAGE), 5, false)
	for index in Expedition.MATERIAL_ROOM:
		bot.materials.append("wood")
	bot._gain_material("starstone")
	_expect(bot.materials.has("starstone") and bot.found_material == "", "the bot keeps the better one by itself")


func _test_deep_chest() -> void:
	var bram := Database.get_adventurer("bram")
	var trip := Expedition.new(bram, Database.get_stage(TownData.FIRST_STAGE), 5, false)
	var deep := -1
	for id in trip.map.spaces():
		if trip.is_deep_chest(id):
			deep = id
	_expect(deep >= 0, "the map has a chest at the deep end of a spur")
	_expect(trip.map.neighbors(deep).size() == 1, "at a dead end")
	trip.space_id = deep
	var result := SpaceEffects.Result.new()
	result.text = "test"
	trip._take(result)
	var rare := trip.materials.filter(func(id: String) -> bool: return Database.get_material(id).rare)
	_expect(rare.size() == 1, "its chest holds a rare material")
	trip.materials.clear()
	trip.space_id = trip.map.portal
	trip._take(result)
	_expect(trip.materials.size() == 1 and not Database.get_material(trip.materials[0]).rare, "other chests hold a common one")


func _test_shop_screen() -> void:
	var town := _town(1000)
	town.hire(Database.get_adventurer("wren"))
	town.add_stock("herb", 2)
	var shop: TownShop = await _open(SHOP)
	_expect(shop.tab == TownShop.Tab.BUY and shop.tiles.size() == TownData.current().on_sale().size(), "the Shop opens on what it sells")
	_expect(shop.arrow.target == shop.sell_tab, "the arrow shows there is something to sell")
	shop.pick_on_shelf("iron_sword")
	_expect(shop.action.text.contains("300"), "the card shows the price")
	_expect(shop._moves.get_child_count() == Database.get_item("iron_sword").moves.size(), "and the moves the gear gives")
	shop.action.pressed.emit()
	await _wait()
	_expect(town.roster[0].equipment[ItemData.Kind.WEAPON] == "iron_sword", "Buy puts it on")
	_expect(shop.gold_chip.amount == town.gold, "and the gold goes down")
	shop.next_person.pressed.emit()
	await _wait()
	_expect(shop.shopper() == town.roster[1], "the arrows choose who to shop for")
	shop.show_tab(TownShop.Tab.SELL)
	await _wait()
	_expect(shop.tiles.size() == town.stock_ids().size(), "Sell shows the town's stock")
	shop.pick_on_shelf("herb")
	var gold := town.gold
	shop.action.pressed.emit()
	await _wait()
	_expect(town.gold == gold + TownData.sell_price("herb") and town.stock_count("herb") == 1, "Sell sells one")
	shop.give.pressed.emit()
	await _wait()
	_expect(town.roster[1].pack.has("herb") and town.stock_count("herb") == 0, "Pack it gives it to who is shopped for")
	shop.back.pressed.emit()
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Back goes to town")


func _test_shop_with_keys() -> void:
	_town(1000)
	var shop: TownShop = await _open(SHOP)
	_expect(_focused() is ShopTile, "the shelves have focus")
	await _tap("ui_right")
	_expect(_focused() == shop.tiles[1], "the arrows walk the shelves")
	_expect(shop.picked.get("id", "") == shop.tiles[1].id, "and the card follows")
	await _tap("ui_cancel")
	await _until_settled()
	_expect(get_tree().current_scene is TownScreen, "Esc goes back to town")


func _test_town_shows_materials() -> void:
	var town := _town()
	town.materials = {"ore": 3}
	var screen: TownScreen = await _open(TOWN)
	_expect(screen.material_chips.size() == 1 and screen.material_chips["ore"].amount == 3, "the town's top bar shows its materials")
	_expect(screen.buildings.has("shop"), "and the Shop stands in town")
