extends Node
## Tests towns, royal quests and net worth, then plays a game through Main.tscn
## with tokens steered onto towns. Run from the project root:
##   godot --headless --path . res://tools/test_towns.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const NEAR := 1
const FAR := 2

var _failures := 0


func _ready() -> void:
	_test_numbers()
	_test_guards()
	_test_ownership()
	_test_income_and_worth()
	_test_cpu_choices()
	_test_quests()
	await _test_full_game()
	if _failures == 0:
		print("TESTS OK")
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)


func _player(player_name: String, level := 1) -> PlayerData:
	var player := PlayerData.new(player_name)
	player.choose_class("warrior")
	player.level = level
	player.heal_fully()
	player.gold = 0
	return player


## A new game with two towns: 3 steps and 13 steps from the castle.
func _new_game(players: Array[PlayerData]) -> void:
	GameState.start_new_game(players, 77)
	Town.setup({NEAR: {"name": "Near", "steps": 3}, FAR: {"name": "Far", "steps": 13}})


func _test_numbers() -> void:
	var hero := _player("Hero")
	_new_game([hero])
	_expect(Town.value(NEAR) == 190 and Town.value(FAR) == 490, "far towns are worth more")
	_expect(Town.income(NEAR) == 38, "an unclaimed town shows its first level's pay")
	_expect(Town.level(NEAR) == 0 and Town.owner_of(NEAR) == null, "towns start with monsters")
	Town.claim(NEAR, hero)
	_expect(Town.level(NEAR) == 1 and Town.owner_of(NEAR) == hero, "freeing a town gives it to you")
	_expect(Town.invest_cost(NEAR) == 142, "level 2 costs 3/4 of the town's value")
	_expect(Town.income(NEAR, 2) == 76, "income can be previewed at another level")


func _test_guards() -> void:
	var hero := _player("Hero")
	_new_game([hero])
	_expect(Town.guard_level(NEAR) == 1, "the nearest towns have the weakest guards")
	_expect(Town.guard_level(FAR) == 11, "far towns have strong guards")
	_expect(Town.guard(FAR).level >= 8, "a far guard is really strong (%d)" % Town.guard(FAR).level)
	var state := GameState.rng.state
	var first := Town.guard(FAR)
	_expect(Town.guard(FAR) == first, "a town keeps its guard")
	_expect(GameState.rng.state == state, "picking a guard uses no numbers from rng")
	Town.claim(FAR, hero)
	GameState.town_levels[FAR] = 3
	_expect(Town.guard_level(FAR) == 15, "growing a town toughens its guard")
	GameState.town_levels[FAR] = Town.MAX_LEVEL
	_expect(Town.guard(FAR) != null, "the top guard exists")
	Town.setup({NEAR: {"name": "Near", "steps": 90}})
	GameState.town_levels[NEAR] = Town.MAX_LEVEL
	_expect(Town.guard_level(NEAR) == PlayerData.MAX_LEVEL, "guard levels have a limit")
	_expect(Town.guard(NEAR) != null, "the strongest possible guard exists")


func _test_ownership() -> void:
	var hero := _player("Hero")
	var rival := _player("Rival")
	_new_game([hero, rival])
	Town.claim(NEAR, hero)

	_expect(Town.why_not_invest(hero, NEAR) == "Not enough gold.", "investing costs gold")
	_expect(not Town.invest(hero, NEAR), "no gold, no investing")
	hero.gold = 142
	_expect(Town.why_not_invest(rival, NEAR) != "", "only the owner can invest")
	_expect(Town.invest(hero, NEAR), "investing works")
	_expect(hero.gold == 0 and Town.level(NEAR) == 2, "investing raises the level and takes the gold")
	_expect(Town.income(NEAR) == 76, "a level 2 town pays double")

	GameState.town_levels[NEAR] = Town.MAX_LEVEL
	hero.gold = 99999
	_expect(Town.why_not_invest(hero, NEAR) != "", "towns stop growing")
	GameState.town_levels[NEAR] = 2
	hero.gold = 0

	rival.gold = 500
	_expect(Town.pay_toll(rival, NEAR) == 76, "the toll is a week of income")
	_expect(rival.gold == 424 and hero.gold == 76, "the toll goes to the owner")
	rival.gold = 10
	_expect(Town.pay_toll(rival, NEAR) == 10 and rival.gold == 0, "a poor visitor pays what they have")
	_expect(Town.pay_toll(rival, NEAR) == 0 and hero.gold == 86, "a penniless visitor pays nothing")

	Town.seize(NEAR, rival)
	_expect(Town.owner_of(NEAR) == rival and Town.level(NEAR) == 1, "a stormed town changes hands and drops a level")
	Town.seize(NEAR, hero)
	_expect(Town.level(NEAR) == 1, "a town never drops below level 1")


func _test_income_and_worth() -> void:
	var hero := _player("Hero")
	var rival := _player("Rival")
	_new_game([hero, rival])
	var gear := Town.gear_value(hero)
	_expect(gear > 0, "starting gear counts")
	_expect(Town.net_worth(hero) == gear, "a new player is worth their gear")
	hero.gold = 50
	_expect(Town.ranking()[0] == hero, "more gold means a higher place")
	hero.gold = 0
	var first_in_order := GameState.players[0]
	_expect(Town.ranking()[0] == first_in_order, "ties stay in turn order")

	Town.claim(NEAR, hero)
	Town.claim(FAR, hero)
	GameState.town_levels[FAR] = 2
	_expect(Town.towns_of(hero).size() == 2 and Town.unclaimed().is_empty(), "towns are counted")
	var paid := Town.collect_income()
	_expect(paid.size() == 1 and paid[hero] == 38 + 196, "income adds up (%s)" % paid)
	_expect(hero.gold == 234, "income is paid")
	var worth := hero.gold + gear + 190 + 490 + 367
	_expect(Town.net_worth(hero) == worth, "net worth counts gold, gear, towns and investment")

	hero.gold = Town.invest_cost(FAR)
	var before := Town.net_worth(hero)
	Town.invest(hero, FAR)
	_expect(Town.net_worth(hero) == before, "investing does not lower net worth")
	var buyer := _player("Buyer")
	buyer.gold = 100
	var bought_at := Town.net_worth(buyer)
	Shop.buy(buyer, "herb")
	_expect(Town.net_worth(buyer) == bought_at, "buying an item does not lower net worth")


func _test_cpu_choices() -> void:
	var hero := _player("Hero")
	_new_game([hero])
	_expect(CpuBrain.will_fight_guard(hero, NEAR), "a CPU player fights a weak guard")
	_expect(not CpuBrain.will_fight_guard(hero, FAR), "a CPU player avoids a strong guard")
	hero.equipment.erase(ItemData.Kind.ARMOR)
	hero.hp = 1
	_expect(not CpuBrain.will_fight_guard(hero, NEAR), "a hurt CPU player avoids fights")
	Town.claim(NEAR, hero)
	hero.gold = Town.invest_cost(NEAR)
	_expect(not CpuBrain.will_invest(hero, NEAR), "a CPU player keeps some gold back")
	hero.gold += CpuBrain.KEEP_GOLD_BASE + CpuBrain.KEEP_GOLD_PER_LEVEL * hero.level
	_expect(CpuBrain.will_invest(hero, NEAR), "a CPU player invests spare gold")


func _test_quests() -> void:
	var hero := _player("Hero")
	var rival := _player("Rival")
	_new_game([hero, rival])
	var seen := {}
	for index in 200:
		Quest.new_week()
		seen[GameState.quest["kind"]] = true
		_expect(Quest.task_text() != "", "every quest can be described")
	_expect(seen.size() == Quest.Kind.size(), "every kind of quest turns up")

	GameState.quest = {"kind": Quest.Kind.HUNT, "target": -1, "place": "", "needed": 2,
			"reward": 200, "winner": ""}
	_expect(Quest.record(hero, Quest.Kind.FREE) == 0, "the wrong deed does not count")
	_expect(hero.quest_progress == 0, "the wrong deed adds no progress")
	_expect(Quest.record(hero, Quest.Kind.HUNT) == 0, "the first of two monsters pays nothing")
	_expect(Quest.status_text(hero).contains("1/2"), "progress is shown")
	_expect(Quest.record(rival, Quest.Kind.HUNT) == 0, "progress is kept per player")
	_expect(Quest.record(hero, Quest.Kind.HUNT) == 200, "finishing pays the reward")
	_expect(Quest.record(rival, Quest.Kind.HUNT) == 0, "only the first to finish is paid")
	_expect(Quest.status_text(rival).contains(hero.player_name), "the winner is shown")

	GameState.quest = {"kind": Quest.Kind.VISIT, "target": FAR, "place": "Far", "needed": 1,
			"reward": 200, "winner": ""}
	_expect(Quest.record(hero, Quest.Kind.VISIT, NEAR) == 0, "the wrong town does not count")
	_expect(Quest.record(hero, Quest.Kind.VISIT, FAR) == 200, "the right town does")

	Town.claim(NEAR, hero)
	Town.claim(FAR, hero)
	hero.quest_progress = 1
	for index in 100:
		Quest.new_week()
		_expect(GameState.quest["kind"] != Quest.Kind.FREE, "no quest to free towns when all are free")
	_expect(hero.quest_progress == 0, "a new week clears progress")

	var loner := _player("Loner")
	_new_game([loner])
	for index in 100:
		Quest.new_week()
		_expect(GameState.quest["kind"] != Quest.Kind.DUEL, "nobody duels alone")
	GameState.players = [] as Array[PlayerData]
	GameState.quest = {}
	_expect(Quest.status_text(loner) == "" and Quest.record(loner, Quest.Kind.HUNT) == 0, "no quest is safe")


## Two people pressing random buttons and two CPU players.
func _test_full_game() -> void:
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.game_seed = 4242
	main.cpu_players = 2
	add_child(main)
	await get_tree().process_frame
	Engine.time_scale = 60.0
	var presses := RandomNumberGenerator.new()
	presses.seed = 99
	main.setup_menu.hide()
	main.setup_menu.player_count_chosen.emit(4)

	var hooked := false
	var quests := {}
	var tolls := 0
	var invested := 0
	var seized := 0
	var last_owner := {}
	var opened_standings := false
	var income_seen := false
	while GameState.day <= 60:
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
		if not GameState.quest.is_empty() and GameState.quest["winner"] != "":
			quests[GameState.get_week()] = GameState.quest["winner"]
		income_seen = income_seen or main.status_label.text.contains("Town income")
		tolls += 1 if main.status_label.text.contains("a toll of") and main.status_label.visible_ratio == 0.0 else 0
		for id: int in GameState.town_owners:
			if last_owner.has(id) and last_owner[id] != GameState.town_owners[id]:
				seized += 1
			last_owner[id] = GameState.town_owners[id]
		for id: int in GameState.town_levels:
			invested = maxi(invested, GameState.town_levels[id])
		if not opened_standings and hooked and main.turn_manager.phase == TurnManager.Phase.ACTION \
				and not Town.towns_of(GameState.players[0]).is_empty():
			opened_standings = true
			main._open_standings()
			_expect(main.standings_screen.visible, "the standings open")
			main.standings_screen.hide()
		_press_something(main, presses)
	Engine.time_scale = 1.0

	print("Played: %d towns owned, best level %d, %d seized, %d quests won, %d tolls" % [
			GameState.town_owners.size(), invested, seized, quests.size(), tolls])
	_expect(GameState.town_owners.size() >= 4, "towns get freed")
	_expect(invested >= 2, "towns get invested in")
	_expect(seized > 0, "a town gets stormed")
	_expect(quests.size() >= 2, "quests get won")
	_expect(income_seen, "towns pay income")
	_expect(tolls > 0, "someone paid a toll")
	for id: int in GameState.town_owners:
		var space := main.board.get_board_node(id)
		_expect(space.town_guard == null and space.town_level == Town.level(id), "an owned town shows its owner")
		_expect(space.town_flag == Town.owner_of(id).token_color, "the flag has the owner's color")
	for id in Town.unclaimed():
		_expect(main.board.get_board_node(id).town_guard != null, "an unclaimed town shows its guard")
	for player in Town.ranking():
		print("%s: %s Lv %d, %d gold, %d towns, worth %d" % [player.player_name, player.get_class_name_text(),
				player.level, player.gold, Town.towns_of(player).size(), Town.net_worth(player)])
	main.queue_free()


# When a move ends, often jumps the token to a town, so a short test sees them all.
func _steer(_node: BoardNode, steps_remaining: int, main: GameController, presses: RandomNumberGenerator) -> void:
	if steps_remaining > 0 or presses.randf() > 0.7:
		return
	var towns := Town.ids()
	var space := main.board.get_board_node(towns[presses.randi_range(0, towns.size() - 1)])
	main._active_player().spawn_at(space)
	main.turn_manager.current_player().space_id = space.node_id


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
