extends Node
## Tests the character rules, then plays a short CPU game through Main.tscn.
## Run from the project root:
##   godot --headless --path . res://tools/test_character.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

var _failures := 0


func _ready() -> void:
	_test_class_setup()
	_test_levels()
	_test_bag_and_equipment()
	await _test_cpu_game()
	if _failures == 0:
		print("TESTS OK")
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)


func _test_class_setup() -> void:
	for id in Database.sorted_ids(Database.classes):
		var player := PlayerData.new()
		player.choose_class(id)
		_expect(player.hp == player.get_stat("max_hp"), "%s starts at full HP" % id)
		_expect(player.mp == player.get_stat("max_mp"), "%s starts at full MP" % id)
		_expect(not player.equipment.is_empty(), "%s starts with equipment" % id)
	var warrior := PlayerData.new()
	warrior.choose_class("warrior")
	_expect(warrior.get_stat("attack") == 15, "warrior attack is 12 + 3 from the sword")


func _test_levels() -> void:
	var mage := PlayerData.new()
	mage.choose_class("mage")
	var signals := [0]
	mage.leveled_up.connect(func(_level: int) -> void: signals[0] += 1)
	var start_hp := mage.hp
	_expect(mage.spells == ["spark"], "mage knows only spark at level 1")
	_expect(mage.add_experience(29) == 0, "29 EXP is no level")
	# 1 more reaches level 2; 60 reaches 3, with 15 left over.
	_expect(mage.add_experience(76) == 2, "76 EXP gives two levels")
	_expect(mage.level == 3 and mage.experience == 15, "leftover EXP is kept")
	_expect(signals[0] == 2, "leveled_up fires once per level")
	_expect(mage.hp == start_hp + 8, "levels add growth to current HP")
	_expect(mage.spells.has("frost_shard"), "mage learns frost_shard at level 3")
	mage.add_experience(1000000)
	_expect(mage.level == PlayerData.MAX_LEVEL, "level stops at the maximum")
	_expect(mage.add_experience(500) == 0 and mage.experience == 0, "no EXP at the maximum")


func _test_bag_and_equipment() -> void:
	var warrior := PlayerData.new()
	warrior.choose_class("warrior")
	warrior.inventory.clear()

	_expect(warrior.add_item("iron_sword"), "bag takes an item")
	_expect(warrior.equip("iron_sword"), "equip from the bag")
	_expect(warrior.get_stat("attack") == 18, "iron sword replaces the short sword")
	_expect(warrior.inventory == ["short_sword"], "old weapon returns to the bag")
	_expect(not warrior.equip("iron_sword"), "cannot equip what is not in the bag")

	warrior.add_item("life_pendant")
	warrior.equip("life_pendant")
	var max_hp := warrior.get_stat("max_hp")
	warrior.hp = max_hp
	warrior.unequip(ItemData.Kind.ACCESSORY)
	_expect(warrior.hp == max_hp - 20, "HP follows max HP down")

	warrior.add_item("war_hammer")
	warrior.add_item("plate_armor")
	warrior.equip("plate_armor")
	_expect(warrior.get_stat("speed") == 4, "armor lowers speed")

	warrior.inventory.clear()
	warrior.add_item("herb")
	_expect(not warrior.use_item("short_sword"), "cannot use equipment")
	warrior.hp = warrior.get_stat("max_hp")
	_expect(not warrior.use_item("herb"), "herb is kept at full HP")
	warrior.hp = warrior.get_stat("max_hp") - 5
	_expect(warrior.use_item("herb"), "herb is used when hurt")
	_expect(warrior.hp == warrior.get_stat("max_hp"), "healing stops at max HP")
	_expect(warrior.inventory.is_empty(), "used item leaves the bag")

	for index in PlayerData.INVENTORY_SIZE:
		_expect(warrior.add_item("herb"), "bag has room")
	_expect(not warrior.add_item("herb"), "full bag refuses")
	_expect(not warrior.unequip(ItemData.Kind.WEAPON), "cannot unequip into a full bag")


func _test_cpu_game() -> void:
	Engine.time_scale = 30.0
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.cpu_players = 4
	main.game_seed = 4242
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.player_count_chosen.emit(4)
	var rounds_wanted := 15
	while GameState.day <= rounds_wanted:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	for player in GameState.players:
		_expect(player.class_id != "", "CPU %s has a class" % player.player_name)
		_expect(player.hp > 0, "CPU %s has HP" % player.player_name)
		print("%s: %s Lv %d, %d gold, bag %s" % [player.player_name,
				player.get_class_name_text(), player.level, player.gold, player.inventory])
