extends Node
## Tests the battle rules, then prints win rates from thousands of simulated
## fights. Run from the project root:
##   godot --headless --path . res://tools/test_battle.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

## How many fights are simulated for each class against each monster.
const FIGHTS := 300
## What a player of a level has had to spend, going by tools/sim_game.gd.
const GEAR_BUDGET_BASE := 200
const GEAR_BUDGET_PER_LEVEL := 120

var _failures := 0


func _ready() -> void:
	GameState.rng.seed = 12345
	_test_damage_table()
	_test_counter_knockout()
	_test_turn_order_and_rounds()
	_test_spells_and_items()
	_test_flee()
	_test_rewards()
	_test_pvp_rewards()
	_test_repeatable()
	_test_encounters()
	_report_balance()
	await _test_game_flow()
	if _failures == 0:
		print("TESTS OK")
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", what)


func _player(class_id: String, level := 1) -> PlayerData:
	var player := PlayerData.new(class_id)
	player.choose_class(class_id)
	player.level = level
	player.spells.clear()
	player.add_experience(0)
	player._learn_spells()
	player.hp = player.get_stat("max_hp")
	player.mp = player.get_stat("max_mp")
	return player


# All the EXP a level 1 player has earned, counting what levels used up.
func _total_exp(player: PlayerData) -> int:
	var total := player.experience
	for level in range(1, player.level):
		total += level * PlayerData.EXP_PER_LEVEL
	return total


func _duel() -> Battle:
	return Battle.new(Fighter.from_player(_player("warrior")), Fighter.from_player(_player("warrior")))


func _average_damage(offense: Battle.Offense, defense: Battle.Defense) -> float:
	var total := 0
	for index in 200:
		var battle := _duel()
		total += battle.resolve(Battle.Choice.new(offense), defense).damage
	return total / 200.0


func _test_damage_table() -> void:
	# Warrior against warrior: 15 attack, 9 defense, so a force of 10.5.
	_expect(absf(_average_damage(Battle.Offense.ATTACK, Battle.Defense.GUARD) - 5.25) < 0.8, "guard halves an attack")
	_expect(absf(_average_damage(Battle.Offense.ATTACK, Battle.Defense.COUNTER) - 13.1) < 0.8, "a counter misread takes 1.25x")
	_expect(absf(_average_damage(Battle.Offense.SMASH, Battle.Defense.GUARD) - 15.75) < 0.8, "smash breaks guard")

	var battle := _duel()
	var attacker := battle.attacker
	var defender := battle.defender
	var outcome := battle.resolve(Battle.Choice.new(Battle.Offense.SMASH), Battle.Defense.COUNTER)
	_expect(outcome.damage == 0 and defender.hp == defender.get_stat("max_hp"), "counter takes no damage")
	_expect(outcome.reflected >= 9 and attacker.hp == attacker.get_stat("max_hp") - outcome.reflected,
			"counter hurts the smasher")

	var slow := Fighter.from_player(_player("cleric"))
	var quick := Fighter.from_player(_player("rogue"))
	var pair := Battle.new(slow, quick)
	_expect(pair.dodge_chance(quick, slow, Battle.Offense.ATTACK) > pair.dodge_chance(slow, quick, Battle.Offense.ATTACK),
			"speed helps dodging")
	_expect(pair.dodge_chance(quick, slow, Battle.Offense.SMASH) > pair.dodge_chance(quick, slow, Battle.Offense.ATTACK),
			"smash is easier to dodge")

	var dodges := 0
	for index in 400:
		var trial := _duel()
		if trial.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.DODGE).dodged:
			dodges += 1
	_expect(dodges > 80 and dodges < 160, "equal speed dodges about 30%% (got %d of 400)" % dodges)


func _test_counter_knockout() -> void:
	var battle := _duel()
	var smasher := battle.attacker
	var countering := battle.defender
	smasher.hp = 1
	battle.resolve(Battle.Choice.new(Battle.Offense.SMASH), Battle.Defense.COUNTER)
	_expect(battle.ending == Battle.Ending.KNOCKOUT, "a counter can end the fight")
	_expect(battle.winner == countering and battle.loser == smasher, "the counter's owner wins")


func _test_turn_order_and_rounds() -> void:
	var slow := Fighter.from_player(_player("cleric"))
	var quick := Fighter.from_player(_player("rogue"))
	var battle := Battle.new(slow, quick)
	_expect(battle.attacker == quick, "the faster fighter goes first")
	battle.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.GUARD)
	_expect(battle.attacker == slow and battle.round_number == 1, "then the other, same round")
	battle.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.GUARD)
	_expect(battle.attacker == quick and battle.round_number == 2, "then a new round")

	var long_fight := Battle.new(Fighter.from_player(_player("cleric", 30)),
			Fighter.from_player(_player("cleric", 30)))
	var actions := 0
	while not long_fight.is_over():
		long_fight.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.GUARD)
		actions += 1
	_expect(long_fight.ending == Battle.Ending.DRAW, "a fight that drags on is a draw")
	_expect(actions == Battle.MAX_ROUNDS * 2, "a draw takes MAX_ROUNDS rounds")
	_expect(long_fight.conclude().size() == 1, "a draw gives nothing")


func _test_spells_and_items() -> void:
	var mage := Fighter.from_player(_player("mage"))
	var target := Fighter.from_player(_player("warrior"))
	var battle := Battle.new(mage, target)
	battle.attacker = mage
	battle.defender = target
	var spark := Battle.Choice.new(Battle.Offense.SPELL, "spark")
	_expect(battle.needs_defense(spark), "attack spells can be defended")
	var mp_before := mage.mp
	var outcome := battle.resolve(spark, Battle.Defense.COUNTER)
	_expect(mage.mp == mp_before - 3, "a spell costs MP")
	_expect(outcome.damage > 0 and outcome.reflected == 0, "a spell cannot be countered")

	var cleric := Fighter.from_player(_player("cleric"))
	var pair := Battle.new(cleric, target)
	pair.attacker = cleric
	pair.defender = target
	_expect(not pair.can_cast(cleric, "mend"), "no healing at full HP")
	cleric.hp = 5
	_expect(pair.can_cast(cleric, "mend"), "healing when hurt")
	var heal := Battle.Choice.new(Battle.Offense.SPELL, "mend")
	_expect(not pair.needs_defense(heal), "healing is not defended")
	var healed := pair.resolve(heal)
	_expect(healed.healed > 0 and cleric.hp == 5 + healed.healed, "mend restores HP")

	var fighter := Fighter.from_player(_player("warrior"))
	var with_item := Battle.new(fighter, target)
	with_item.attacker = fighter
	with_item.defender = target
	fighter.hp = 10
	_expect(fighter.get_items() == ["herb"], "the bag's healing items are listed")
	var used := with_item.resolve(Battle.Choice.new(Battle.Offense.ITEM, "herb"))
	_expect(used.healed > 0 and fighter.player.inventory.is_empty(), "an item heals and is used up")

	fighter.player.mp = 0
	_expect(not with_item.can_cast(fighter, "spark"), "no MP, no spell")


func _test_flee() -> void:
	var escapes := 0
	for index in 400:
		var battle := _duel()
		if battle.resolve(Battle.Choice.new(Battle.Offense.FLEE)).fled:
			escapes += 1
			_expect(battle.ending == Battle.Ending.FLED, "fleeing ends the battle")
			_expect(battle.conclude().size() == 1, "fleeing gives nothing")
	_expect(escapes > 160 and escapes < 240, "equal speed flees about half the time (got %d)" % escapes)


func _test_rewards() -> void:
	var hero := _player("warrior")
	hero.gold = 100
	var slime := Database.get_monster("slime")
	var battle := Battle.new(Fighter.from_player(hero), Fighter.from_monster(slime))
	battle.opponent.hp = 1
	battle.attacker = battle.challenger
	battle.defender = battle.opponent
	battle.resolve(Battle.Choice.new(Battle.Offense.SMASH), Battle.Defense.GUARD)
	_expect(battle.winner == battle.challenger, "the hero beats the slime")
	battle.conclude()
	_expect(hero.gold == 100 + slime.gold_reward, "monster gold is paid")
	_expect(_total_exp(hero) == slime.exp_reward, "monster EXP is paid")

	var victim := _player("mage")
	victim.gold = 100
	var fight := Battle.new(Fighter.from_player(victim), Fighter.from_monster(slime))
	fight.challenger.hp = 1
	fight.attacker = fight.opponent
	fight.defender = fight.challenger
	fight.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.GUARD)
	var lines := fight.conclude()
	_expect(fight.loser == fight.challenger, "the slime knocks out the hero")
	_expect(victim.gold == 75, "a knockout costs a quarter of the gold")
	_expect(victim.hp == victim.get_stat("max_hp"), "the loser wakes up healed")
	_expect(victim.turns_to_skip == PlayerData.KO_TURNS_LOST, "the loser sits out a turn")
	_expect(lines.size() == 3, "knockout lines: %s" % lines)

	var full_hero := _player("warrior")
	while full_hero.inventory.size() < PlayerData.INVENTORY_SIZE:
		full_hero.inventory.append("herb")
	var line_list := PackedStringArray()
	var drop_test := Battle.new(Fighter.from_player(full_hero), Fighter.from_monster(slime))
	var rich := MonsterData.new()
	rich.loot = ["potion"]
	rich.loot_chance = 1.0
	drop_test._roll_for_loot(full_hero, rich, line_list)
	_expect(line_list[0].ends_with("bag is full."), "a full bag refuses loot")
	_expect(not full_hero.inventory.has("potion"), "refused loot stays out of the bag")


func _test_pvp_rewards() -> void:
	var red := _player("warrior")
	var blue := _player("mage")
	red.gold = 0
	blue.gold = 200
	blue.level = 3
	blue.hp = 1
	var battle := Battle.new(Fighter.from_player(red), Fighter.from_player(blue))
	battle.attacker = battle.challenger
	battle.defender = battle.opponent
	battle.opponent.level = 3
	battle.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.COUNTER)
	battle.conclude()
	_expect(red.gold == 50, "the winner takes the loser's dropped gold")
	_expect(blue.gold == 150, "the loser pays it")
	_expect(_total_exp(red) == Battle.PVP_EXP_PER_LEVEL * 3, "PvP EXP depends on the loser's level")


func _test_repeatable() -> void:
	_expect(_transcript(99) == _transcript(99), "the same seed replays the same fight")
	_expect(_transcript(99) != _transcript(100), "another seed gives another fight")


func _transcript(seed_value: int) -> String:
	GameState.rng.seed = seed_value
	var battle := Battle.new(Fighter.from_player(_player("rogue")), Fighter.from_monster(Database.get_monster("orc_grunt")))
	var text := ""
	while not battle.is_over():
		var choice := battle.cpu_offense()
		var defense := battle.cpu_defense() if battle.needs_defense(choice) else Battle.Defense.NONE
		var outcome := battle.resolve(choice, defense)
		text += "%s %s;" % [outcome.opening, outcome.result]
	return text


func _test_encounters() -> void:
	for level in range(1, PlayerData.MAX_LEVEL + 1):
		_expect(not Database.monster_ids_for_level(level).is_empty(), "a monster for level %d" % level)


# --- A real game ------------------------------------------------------------

## Plays Main.tscn as two people pressing random buttons. Every landing puts the
## rival on the same space, so the challenge, PvP, knockout and rest paths all run.
func _test_game_flow() -> void:
	Engine.time_scale = 30.0
	var presses := RandomNumberGenerator.new()
	presses.seed = 5
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.game_seed = 777
	add_child(main)
	await get_tree().process_frame
	main.setup_menu.player_count_chosen.emit(2)

	var battles := 0
	var knockouts := 0
	var rests := 0
	var last_phase := TurnManager.Phase.IDLE
	var hooked := false
	var skipping := {}
	while GameState.day <= 40:
		await get_tree().process_frame
		if main.class_menu.visible:
			main.class_menu.class_chosen.emit("warrior")
			continue
		if not hooked and main.turn_manager.phase != TurnManager.Phase.IDLE:
			hooked = true
			for token: PlayerMovement in main.players:
				token.step_finished.connect(_bring_rival.bind(main))
		var phase := main.turn_manager.phase
		if phase != last_phase and phase == TurnManager.Phase.BATTLE:
			battles += 1
		last_phase = phase
		for player in GameState.players:
			var waiting := player.turns_to_skip > 0
			if waiting and not skipping.get(player, false):
				knockouts += 1
				var castle := main.board.get_starting_node().node_id
				var snared: bool = main._tokens[player].current_node.node_type == BoardNode.NodeType.TRAP
				_expect(player.space_id == castle or phase == TurnManager.Phase.BATTLE or snared,
						"a knocked out player goes to the castle")
			if skipping.get(player, false) and not waiting:
				rests += 1
			skipping[player] = waiting
		_press_something(main, presses)
	Engine.time_scale = 1.0
	print("Played: %d battles, %d knockouts, %d rests" % [battles, knockouts, rests])
	_expect(battles > 5, "battles happen in a real game")
	_expect(knockouts > 0, "someone was knocked out")
	_expect(rests > 0, "a knocked out player sat out a turn")
	for player in GameState.players:
		_expect(main._tokens[player].current_node.node_id == player.space_id or
				main.turn_manager.phase != TurnManager.Phase.ACTION, "tokens match their data")
	main.queue_free()


# Puts the other player on the space the active token has just stopped on.
func _bring_rival(node: BoardNode, steps_remaining: int, main: GameController) -> void:
	if steps_remaining > 0 or node.node_type == BoardNode.NodeType.CASTLE:
		return
	for player in GameState.players:
		if player != main.turn_manager.current_player():
			player.space_id = node.node_id
			main._tokens[player].spawn_at(node)


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


# --- Balance ----------------------------------------------------------------

## Prints the share of fights each class wins at the levels each monster is met,
## with both sides playing like a CPU. A person who reads the habits does better.
func _report_balance() -> void:
	_report_table(false)
	_report_table(true)


## `geared` swaps starting gear for what a shop budget would buy.
func _report_table(geared: bool) -> void:
	var classes := Database.sorted_ids(Database.classes)
	print("\n%s" % ("Shop gear, %d + %d gold per level" % [GEAR_BUDGET_BASE, GEAR_BUDGET_PER_LEVEL]
			if geared else "Starting gear"))
	print("monster       lv  ", "  ".join(classes), "   rounds")
	for monster_id in _monsters_by_level():
		var monster := Database.get_monster(monster_id)
		for level: int in [monster.min_level, monster.max_level]:
			var row := PackedStringArray()
			var rounds := 0
			for class_id in classes:
				var result := _simulate(class_id, level, monster, geared)
				row.append("%3d%%" % result[0])
				rounds += result[1]
			print("%-13s %2d  %s   %.1f" % [monster.display_name, level, "    ".join(row),
					float(rounds) / (FIGHTS * classes.size())])
			if monster.min_level == monster.max_level:
				break
	print("")


func _monsters_by_level() -> Array[String]:
	var ids := Database.sorted_ids(Database.monsters)
	ids.sort_custom(func(a: String, b: String) -> bool:
			return Database.get_monster(a).level < Database.get_monster(b).level)
	return ids


# Returns [percent won, total rounds]. Fights start at full health.
func _simulate(class_id: String, level: int, monster: MonsterData, geared: bool) -> Array[int]:
	var wins := 0
	var rounds := 0
	for index in FIGHTS:
		var hero := _player(class_id, level)
		if geared:
			hero.gold = GEAR_BUDGET_BASE + GEAR_BUDGET_PER_LEVEL * level
			Shop.cpu_shop(hero, Database.sorted_ids(Database.items))
			hero.heal_fully()
		var battle := Battle.new(Fighter.from_player(hero), Fighter.from_monster(monster))
		while not battle.is_over():
			var choice := battle.cpu_offense()
			var defense := battle.cpu_defense() if battle.needs_defense(choice) else Battle.Defense.NONE
			battle.resolve(choice, defense)
		rounds += battle.round_number
		if battle.winner == battle.challenger:
			wins += 1
	return [wins * 100 / FIGHTS, rounds]
