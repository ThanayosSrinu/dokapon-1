extends Node
## Tests what spaces and shops do, then plays a game through Main.tscn with every
## kind of space. Run from the project root:
##   godot --headless --path . res://tools/test_spaces.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const TRIALS := 400

var _failures := 0


func _ready() -> void:
	GameState.rng.seed = 2468
	GameState.game_seed = 2468
	GameState.day = 1
	GameState.emptied_chests.clear()
	_test_gold_and_items()
	_test_magic()
	_test_shrine()
	_test_traps()
	_test_chests()
	_test_shop_stock()
	_test_buying_and_selling()
	_test_cpu_shopping()
	_test_bag_full_for_cpu()
	await _test_shop_screen()
	await _test_bag_prompt()
	await _test_full_game()
	if _failures == 0:
		print("TESTS OK")
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)


func _player(class_id := "warrior", level := 1) -> PlayerData:
	var player := PlayerData.new(class_id)
	player.choose_class(class_id)
	player.level = level
	player.heal_fully()
	return player


func _test_gold_and_items() -> void:
	for level: int in [1, 15, 30]:
		var player := _player("warrior", level)
		var gold := SpaceEffects.gold_space(player).gold
		var expected: int = SpaceEffects.GOLD_BASE + SpaceEffects.GOLD_PER_LEVEL * level
		_expect(gold >= expected * 0.74 and gold <= expected * 1.26, "gold scales with level (%d)" % gold)
	var beginner := _player()
	for index in TRIALS:
		var item := Database.get_item(SpaceEffects.item_space(beginner).item_id)
		_expect(item.price <= 140, "a beginner finds nothing grand (%s)" % item.id)


func _test_magic() -> void:
	var mage := _player("mage")
	mage.mp = 1
	var taught := 0
	for index in TRIALS:
		var trial := _player("warrior", 3)
		var known := trial.spells.size()
		var result := SpaceEffects.magic_space(trial)
		if trial.spells.size() > known:
			taught += 1
			_expect(result.text.contains("Learned"), "the message names the new spell")
	_expect(taught > TRIALS * 0.4 and taught < TRIALS * 0.6, "spells are taught about half the time (%d)" % taught)
	SpaceEffects.magic_space(mage)
	_expect(mage.mp == mage.get_stat("max_mp"), "magic refills MP")

	var learner := _player("warrior", 3)
	var spells := SpaceEffects.learnable_spells(learner)
	_expect(spells.has("mend") and spells.has("spark"), "low spells can be taught")
	_expect(not spells.has("inferno"), "high spells cannot be taught early")
	var master := _player("mage", 30)
	for spell_id in Database.sorted_ids(Database.spells):
		master.learn_spell(spell_id)
	var known_before := master.spells.size()
	SpaceEffects.magic_space(master)
	_expect(master.spells.size() == known_before, "knowing every spell is safe")


func _test_shrine() -> void:
	var cleric := _player("cleric")
	cleric.hp = 1
	cleric.mp = 0
	SpaceEffects.shrine_space(cleric)
	_expect(cleric.hp == cleric.get_stat("max_hp") and cleric.mp == cleric.get_stat("max_mp"), "shrine heals in full")


func _test_traps() -> void:
	var seen := {"dodged": 0, "spikes": 0, "thief": 0, "snare": 0, "trapdoor": 0}
	for index in TRIALS:
		var player := _player("warrior")
		player.gold = 1000
		var result := SpaceEffects.trap_space(player)
		if not result.harmful:
			seen["dodged"] += 1
		elif result.gold < 0:
			seen["thief"] += 1
			_expect(result.gold >= -200 and result.gold <= -100, "a thief takes 10-20%")
		elif result.to_castle:
			seen["trapdoor"] += 1
		elif player.turns_to_skip > 0:
			seen["snare"] += 1
		else:
			seen["spikes"] += 1
			_expect(player.hp < player.get_stat("max_hp"), "spikes hurt")
	for kind: String in seen:
		_expect(seen[kind] > 0, "trap outcome %s happens" % kind)

	var frail := _player("mage")
	frail.hp = 1
	frail.take_damage(500)
	_expect(frail.hp == 1, "traps never knock anyone out")

	var broke := _player()
	broke.gold = 0
	for index in 60:
		var result := SpaceEffects.trap_space(broke)
		_expect(result.gold == 0, "nothing is stolen from the penniless")

	var slow := _player("warrior")
	var quick := _player("rogue")
	_expect(SpaceEffects.trap_dodge_chance(quick) > SpaceEffects.trap_dodge_chance(slow), "speed helps with traps")


func _test_chests() -> void:
	GameState.day = 5
	_expect(SpaceEffects.chest_is_full(70), "chests start full")
	SpaceEffects.empty_chest(70)
	_expect(not SpaceEffects.chest_is_full(70), "an emptied chest is empty")
	_expect(SpaceEffects.chest_days_left(70) == SpaceEffects.CHEST_REFILL_DAYS, "it says when it refills")
	GameState.day = 5 + SpaceEffects.CHEST_REFILL_DAYS
	_expect(SpaceEffects.chest_is_full(70), "a chest fills again")
	GameState.day = 1
	GameState.emptied_chests.clear()

	var player := _player("warrior", 5)
	var guarded := 0
	for index in TRIALS:
		var chest := SpaceEffects.roll_chest(player)
		_expect((chest.gold > 0) != (chest.item_id != ""), "a chest holds gold or an item")
		if chest.item_id != "":
			var price := Database.get_item(chest.item_id).price
			_expect(price >= 150 and price <= 600, "chest items are good ones (%d)" % price)
		if chest.guardian != null:
			guarded += 1
	_expect(guarded > TRIALS * 0.17 and guarded < TRIALS * 0.33, "about a quarter are guarded (%d)" % guarded)
	var veteran := _player("warrior", PlayerData.MAX_LEVEL)
	for index in TRIALS:
		SpaceEffects.roll_chest(veteran)


func _test_shop_stock() -> void:
	var first := Shop.stock(7, 1)
	_expect(first == Shop.stock(7, 1), "stock is the same all week")
	_expect(first.size() == Shop.EQUIPMENT_STOCK + Shop.CONSUMABLE_STOCK, "stock is full")
	var unique := {}
	for id in first:
		unique[id] = true
	_expect(unique.size() == first.size(), "nothing is on the shelf twice")
	_expect(first != Shop.stock(7, 2), "stock changes by the week")
	_expect(first != Shop.stock(11, 1), "shops differ")
	var state := GameState.rng.state
	Shop.stock(99, 3)
	_expect(GameState.rng.state == state, "looking at a shop uses no game randomness")


func _test_buying_and_selling() -> void:
	var player := _player()
	player.inventory.clear()
	player.gold = 100
	_expect(Shop.why_not_buy(player, "iron_sword") == "Not enough gold.", "the price matters")
	_expect(not Shop.buy(player, "iron_sword") and player.gold == 100, "a refused sale changes nothing")
	_expect(Shop.buy(player, "herb") and player.gold == 70 and player.inventory == ["herb"], "buying pays and fills the bag")
	_expect(Shop.sell(player, "herb") and player.gold == 85 and player.inventory.is_empty(), "selling pays half")
	_expect(not Shop.sell(player, "herb"), "cannot sell what is not there")

	player.gold = 9999
	for index in PlayerData.INVENTORY_SIZE:
		player.add_item("herb")
	_expect(Shop.why_not_buy(player, "potion").contains("full"), "a full bag stops buying")
	_expect(player.get_stat_with("iron_sword", "attack") == player.get_stat("attack") + 3, "comparison replaces the worn item")


func _test_cpu_shopping() -> void:
	var shelves: Array[String] = ["war_hammer", "rune_wand", "herb", "potion"]
	var warrior := _player("warrior")
	warrior.gold = 700
	var bought := CpuBrain.shop(warrior, shelves)
	_expect(warrior.equipment[ItemData.Kind.WEAPON] == "war_hammer", "a warrior buys the hammer")
	_expect(bought.has("War Hammer"), "the purchase is reported")
	_expect(not warrior.inventory.has("short_sword"), "old gear is sold")

	var mage := _player("mage")
	mage.gold = 700
	CpuBrain.shop(mage, shelves)
	_expect(mage.equipment[ItemData.Kind.WEAPON] == "rune_wand", "a mage buys the wand")

	var poor := _player("warrior")
	poor.gold = 40
	CpuBrain.shop(poor, shelves)
	_expect(poor.gold >= 0, "a CPU cannot go into debt")


func _test_bag_full_for_cpu() -> void:
	var player := _player()
	player.inventory.clear()
	for index in PlayerData.INVENTORY_SIZE:
		player.add_item("herb")
	_expect(SpaceEffects.cpu_make_room(player, "elixir") == "herb", "a CPU swaps a herb for an elixir")
	_expect(player.inventory.size() == PlayerData.INVENTORY_SIZE - 1, "that makes room")
	player.inventory.clear()
	for index in PlayerData.INVENTORY_SIZE:
		player.add_item("potion")
	_expect(SpaceEffects.cpu_make_room(player, "herb") == "", "a cheaper item is not worth a swap")


func _test_shop_screen() -> void:
	var screen := ShopScreen.new()
	add_child(screen)
	var player := _player()
	player.gold = 1000
	player.inventory.clear()
	var shelves: Array[String] = ["iron_sword", "potion"]
	var state := [""]
	var running := func() -> void: state[0] = await screen.run(player, shelves, "Shop")
	running.call()
	await get_tree().process_frame
	_expect(screen.visible, "the shop opens")
	_expect(screen._selected == "iron_sword", "the first item is selected")
	_expect(screen._wear_button.visible and not screen._wear_button.disabled, "gear can be worn at once")

	screen._wear_button.pressed.emit()
	_expect(player.equipment[ItemData.Kind.WEAPON] == "iron_sword", "Buy & Wear equips it")
	_expect(player.gold == 700 and player.inventory == ["short_sword"], "and the old sword is in the bag")

	screen._on_row_pressed("potion")
	_expect(not screen._wear_button.visible, "consumables cannot be worn")
	screen._main_button.pressed.emit()
	_expect(player.inventory.has("potion"), "Buy puts it in the bag")

	screen._sell_tab.pressed.emit()
	_expect(screen._selling and screen._selected == "short_sword", "the sell tab lists the bag")
	screen._main_button.pressed.emit()
	_expect(player.gold == 620 + 60, "selling the sword pays half of 120")
	screen._main_button.pressed.emit()
	_expect(player.inventory.is_empty(), "the bag can be emptied")
	_expect(not screen._main_button.visible, "nothing left to sell, and that is safe")

	screen._leave.pressed.emit()
	await get_tree().process_frame
	_expect(state[0].contains("bought 2 and sold 2"), "the shop sums up the visit (%s)" % state[0])
	_expect(not screen.visible, "the shop closes")
	screen.queue_free()


func _test_bag_prompt() -> void:
	var prompt := BagPrompt.new()
	add_child(prompt)
	var player := _player()
	player.inventory.clear()
	for id: String in ["herb", "potion", "dagger", "herb", "herb", "herb"]:
		player.add_item(id)
	var state := [false]
	var asking := func(item_id: String) -> void: state[0] = await prompt.ask(player, item_id)

	asking.call("elixir")
	await get_tree().process_frame
	prompt.get_buttons()[2].pressed.emit()
	await get_tree().process_frame
	_expect(state[0], "dropping something keeps the new item")
	_expect(player.inventory.has("elixir") and not player.inventory.has("potion"), "the choice is respected")

	asking.call("war_hammer")
	await get_tree().process_frame
	prompt.get_buttons()[0].pressed.emit()
	await get_tree().process_frame
	_expect(not state[0] and not player.inventory.has("war_hammer"), "the new item can be left behind")
	prompt.queue_free()


## Two people play and press buttons at random, so every kind of space and window
## gets used. Tokens are moved along to reach the rarer spaces.
func _test_full_game() -> void:
	Engine.time_scale = 30.0
	var presses := RandomNumberGenerator.new()
	presses.seed = 11
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.game_seed = 31337
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.player_count_chosen.emit(2)

	var shops := 0
	var chests := 0
	var prompts := 0
	var was_in_shop := false
	var was_in_prompt := false
	var hooked := false
	var seen_types := {}
	var last_turn := {}
	while GameState.day <= 45:
		await get_tree().process_frame
		if main.class_menu.visible:
			for child in main.class_menu.find_children("*", "Button", true, false):
				child.pressed.emit()
				break
			continue
		if not hooked and not main._tokens.is_empty():
			hooked = true
			for token: PlayerMovement in main._tokens.values():
				token.step_finished.connect(_steer.bind(main, presses))
		if main.shop_screen.visible and not was_in_shop:
			shops += 1
		was_in_shop = main.shop_screen.visible
		if main.bag_prompt.visible and not was_in_prompt:
			prompts += 1
		was_in_prompt = main.bag_prompt.visible
		if main.turn_manager.phase == TurnManager.Phase.SPACE_EVENT and GameState.players.size() > 0:
			var data := main.turn_manager.current_player()
			seen_types[main._tokens[data].current_node.node_type] = true
			if last_turn.get(data, -1) != GameState.day and GameState.emptied_chests.size() > chests:
				chests = GameState.emptied_chests.size()
				last_turn[data] = GameState.day
		_press_something(main, presses)
	Engine.time_scale = 1.0
	print("Played: %d shop visits, %d chests, %d full bags, %d kinds of space" % [
			shops, chests, prompts, seen_types.size()])
	_expect(shops > 0, "someone went shopping")
	_expect(chests > 0, "someone opened a chest")
	_expect(prompts > 0, "someone had a full bag")
	for kind: BoardNode.NodeType in [BoardNode.NodeType.GOLD, BoardNode.NodeType.ITEM, BoardNode.NodeType.MAGIC,
			BoardNode.NodeType.SHRINE, BoardNode.NodeType.TRAP, BoardNode.NodeType.SHOP, BoardNode.NodeType.TREASURE]:
		_expect(seen_types.has(kind), "a game reaches space type %s" % BoardNode.NodeType.keys()[kind])
	for player in GameState.players:
		_expect(player.inventory.size() <= PlayerData.INVENTORY_SIZE, "the bag never overflows")
		_expect(player.hp > 0 and player.gold >= 0, "%s is still healthy on paper" % player.player_name)
		print("%s: %s Lv %d, %d gold, bag %s, worn %s" % [player.player_name, player.get_class_name_text(),
				player.level, player.gold, player.inventory, player.equipment.values()])
	main.queue_free()


# When a move ends, jumps the token to a random space of an interesting type, so
# that a short test sees all of them.
func _steer(node: BoardNode, steps_remaining: int, main: GameController, presses: RandomNumberGenerator) -> void:
	if steps_remaining > 0 or presses.randf() > 0.8:
		return
	var wanted: Array[BoardNode.NodeType] = [BoardNode.NodeType.SHOP, BoardNode.NodeType.TREASURE,
			BoardNode.NodeType.TRAP, BoardNode.NodeType.ITEM, BoardNode.NodeType.MAGIC,
			BoardNode.NodeType.GOLD, BoardNode.NodeType.SHRINE]
	var kind := wanted[presses.randi_range(0, wanted.size() - 1)]
	var token := main._active_player()
	for other in main.board.get_children():
		if other is BoardNode and other.node_type == kind and other != node:
			token.spawn_at(other)
			main.turn_manager.current_player().space_id = other.node_id
			return


# Does what a person would: presses a random button that is on offer.
func _press_something(main: GameController, presses: RandomNumberGenerator) -> void:
	if main.turn_manager.phase == TurnManager.Phase.ACTION and not main.roll_button.disabled:
		main._on_roll_button_pressed()
		return
	var buttons: Array[Button] = []
	if main.shop_screen.visible:
		buttons = main.shop_screen.get_buttons()
	elif main.bag_prompt.visible:
		buttons = main.bag_prompt.get_buttons()
	else:
		var box: Container = main.battle_screen._choices if main.battle_screen.visible else main.choice_box
		for child in box.get_children():
			if child is Button and not child.disabled:
				buttons.append(child)
	if not buttons.is_empty():
		buttons[presses.randi_range(0, buttons.size() - 1)].pressed.emit()
