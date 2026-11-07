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
	_test_magic_and_items()
	_test_moves_from_gear()
	_test_specials()
	_test_learning()
	_test_many_fights()
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
		var move := "spark" if offense == Battle.Offense.MAGIC else ""
		total += battle.resolve(Battle.Choice.new(offense, move), defense).damage
	return total / 200.0


# Every row of the table in Battle.gd, for fighters who hit with a force of 9: 15 attack
# against 12 defense. Spark is 2 magic + 6 against the same, so a force of 2.
func _test_damage_table() -> void:
	var cases := [
		[Battle.Offense.ATTACK, Battle.Defense.GUARD, 4.5, "Guard takes less from an Attack"],
		[Battle.Offense.ATTACK, Battle.Defense.COUNTER, 9.0, "Counter takes all of an Attack"],
		[Battle.Offense.ATTACK, Battle.Defense.WARD, 9.0, "Ward takes all of an Attack"],
		[Battle.Offense.SMASH, Battle.Defense.GUARD, 13.5, "a Smash breaks a Guard"],
		[Battle.Offense.SMASH, Battle.Defense.WARD, 13.5, "a Smash breaks a Ward"],
	]
	for case: Array in cases:
		_expect(absf(_average_damage(case[0], case[1]) - case[2]) < 0.7, case[3])

	_expect(Battle.hit_share(Battle.Offense.MAGIC, Battle.Defense.GUARD) == 1.0, "Guard takes all of Magic")
	_expect(Battle.hit_share(Battle.Offense.MAGIC, Battle.Defense.COUNTER) == 1.0, "Counter takes all of Magic")
	_expect(Battle.hit_share(Battle.Offense.MAGIC, Battle.Defense.WARD) == 0.5, "Ward takes less from Magic")
	_expect(Battle.hit_share(Battle.Offense.SMASH, Battle.Defense.COUNTER) == 0.0, "a Counter stops a Smash")
	_expect(_ward_share() < _guard_share(), "a real Ward takes less Magic than a Guard does")

	var battle := _duel()
	var attacker := battle.attacker
	var defender := battle.defender
	var outcome := battle.resolve(Battle.Choice.new(Battle.Offense.SMASH), Battle.Defense.COUNTER)
	_expect(outcome.damage == 0 and defender.hp == defender.get_stat("max_hp"), "counter takes no damage")
	_expect(outcome.reflected >= 7 and attacker.hp == attacker.get_stat("max_hp") - outcome.reflected,
			"counter hurts the smasher")

	var special := _duel()
	_expect(not special.needs_defense(Battle.Choice.new(Battle.Offense.SPECIAL, "rally")), "a Special asks for no defense")
	_expect(not Battle.Defense.has("DODGE"), "Dodge is gone")


func _ward_share() -> float:
	return _magic_damage(Battle.Defense.WARD)


func _guard_share() -> float:
	return _magic_damage(Battle.Defense.GUARD)


func _magic_damage(defense: Battle.Defense) -> float:
	var total := 0
	for index in 100:
		var mage := Fighter.from_player(_player("mage", 12))
		var target := Fighter.from_player(_player("mage", 12))
		var battle := Battle.new(mage, target)
		battle.attacker = mage
		battle.defender = target
		total += battle.resolve(Battle.Choice.new(Battle.Offense.MAGIC, "spark"), defense).damage
	return total / 100.0


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


func _test_magic_and_items() -> void:
	var mage := Fighter.from_player(_player("mage"))
	var target := Fighter.from_player(_player("warrior"))
	var battle := Battle.new(mage, target)
	battle.attacker = mage
	battle.defender = target
	var spark := Battle.Choice.new(Battle.Offense.MAGIC, "spark")
	_expect(battle.needs_defense(spark), "Magic can be answered")
	var mp_before := mage.mp
	var outcome := battle.resolve(spark, Battle.Defense.COUNTER)
	_expect(mage.mp == mp_before - 3, "Magic costs MP")
	_expect(outcome.damage > 0 and outcome.reflected == 0, "Magic cannot be countered")

	var fighter := Fighter.from_player(_player("warrior"))
	var with_item := Battle.new(fighter, target)
	with_item.attacker = fighter
	with_item.defender = target
	fighter.hp = 10
	_expect(fighter.get_items() == ["herb"], "the bag's healing items are listed")
	var used := with_item.resolve(Battle.Choice.new(Battle.Offense.ITEM, "herb"))
	_expect(used.healed > 0 and fighter.player.inventory.is_empty(), "an item heals and is used up")

	mage.mp = 0
	_expect(not battle.can_use(mage, "spark"), "no MP, no Magic")
	_expect(battle.can_use(mage, "bonk"), "and the free moves cost nothing")


func _test_moves_from_gear() -> void:
	var hero := _player("warrior")
	var fighter := Fighter.from_player(hero)
	_expect(fighter.moves_in(MoveData.Category.ATTACK) == ["slash"], "the weapon gives its Attack")
	_expect(fighter.moves_in(MoveData.Category.SMASH) == ["cleave"], "and its Smash")
	_expect(fighter.moves_in(MoveData.Category.GUARD) == ["block"], "the armor gives its Guard")
	_expect(fighter.moves_in(MoveData.Category.COUNTER) == ["riposte"], "and its Counter")
	_expect(fighter.moves_in(MoveData.Category.WARD) == ["ward_off"], "and its Ward")

	var long_sword: ItemData = Database.get_item("iron_sword").duplicate()
	long_sword.id = "test_sword"
	long_sword.moves = ["slash", "stab", "bonk", "pound", "cleave", "lunge", "crack", "crush"]
	Database.items["test_sword"] = long_sword
	hero.equipment[ItemData.Kind.WEAPON] = "test_sword"
	_expect(fighter.moves_in(MoveData.Category.ATTACK).size() == 4, "a weapon can hold 4 moves in a category")
	_expect(fighter.moves_in(MoveData.Category.SMASH).size() == 4, "in each category")
	var battle := _duel()
	battle.attacker.player.equipment[ItemData.Kind.WEAPON] = "test_sword"
	var picked := battle.resolve(Battle.Choice.new(Battle.Offense.ATTACK, "pound"), Battle.Defense.GUARD)
	_expect(picked.move.id == "pound", "the move picked is the move played")
	Database.items.erase("test_sword")

	var weak := Battle.new(Fighter.from_player(_player("warrior")), Fighter.from_player(_player("warrior")))
	var bare := weak.attacker
	bare.player.equipment.clear()
	_expect(bare.moves_in(MoveData.Category.ATTACK) == ["punch"], "no weapon still leaves Punch")
	_expect(bare.moves_in(MoveData.Category.SMASH).is_empty(), "but no Smash")
	_expect(bare.moves_in(MoveData.Category.GUARD) == ["brace"], "no armor still leaves Brace")
	_expect(bare.moves_in(MoveData.Category.COUNTER).is_empty() and bare.moves_in(MoveData.Category.WARD).is_empty(),
			"but no Counter or Ward")
	_expect(weak.usable_defenses(bare) == [Battle.Defense.GUARD], "so Guard is the only answer")
	_expect(weak.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.GUARD).move.id == "punch", "Punch lands")

	var braced := 0
	var blocked := 0
	for index in 100:
		var trial := _duel()
		var target := trial.defender
		target.player.equipment.erase(ItemData.Kind.ARMOR)
		braced += trial.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.GUARD).damage
		var other := _duel()
		blocked += other.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.GUARD).damage
	_expect(braced > blocked, "Brace does less than a real Guard")

	for monster_id in Database.sorted_ids(Database.monsters):
		var monster := Fighter.from_monster(Database.get_monster(monster_id))
		_expect(monster.moves_in(MoveData.Category.ATTACK)[0] != Battle.BARE_ATTACK, "%s has its own Attack" % monster_id)
		_expect(monster.moves_in(MoveData.Category.GUARD)[0] != Battle.BARE_GUARD, "%s has its own Guard" % monster_id)


func _test_specials() -> void:
	var cleric := Fighter.from_player(_player("cleric"))
	var target := Fighter.from_player(_player("warrior"))
	var pair := Battle.new(cleric, target)
	pair.attacker = cleric
	pair.defender = target
	_expect(not pair.can_use(cleric, "mend"), "no healing at full HP")
	cleric.hp = 5
	_expect(pair.can_use(cleric, "mend"), "healing when hurt")
	var mp_before := cleric.mp
	var healed := pair.resolve(Battle.Choice.new(Battle.Offense.SPECIAL, "mend"))
	_expect(healed.healed > 0 and cleric.hp == 5 + healed.healed, "Mend restores HP")
	_expect(cleric.mp == mp_before, "a Special costs no MP")
	cleric.hp = 5
	_expect(not pair.can_use(cleric, "mend"), "a Special works once per fight")
	_expect(pair.usable_moves(cleric, MoveData.Category.SPECIAL).is_empty(), "so it leaves the list")

	# Rally: the user's next 3 turns are up 20%, and the enemy's turns don't count.
	var bram := Fighter.from_player(_player("warrior", 30))
	var foe := Fighter.from_monster(Database.get_monster("orc_warlord"))
	var fight := Battle.new(bram, foe)
	fight.attacker = bram
	fight.defender = foe
	var usual := bram.get_stat("attack")
	fight.resolve(Battle.Choice.new(Battle.Offense.SPECIAL, "rally"))
	var raised := ceili(usual * 1.2)
	_expect(bram.get_stat("attack") == raised, "Rally raises Attack by 20%")
	for turn in 3:
		_expect(bram.get_stat("attack") == raised, "and lasts on the enemy's turn %d" % turn)
		fight.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.GUARD)
		_expect(bram.get_stat("attack") == raised, "still up before their own turn %d" % turn)
		fight.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.GUARD)
	_expect(bram.get_stat("attack") == usual, "and ends after their own 3 turns")

	# Sure Strike hits in full, with nothing to answer it.
	var wren := Fighter.from_player(_player("rogue"))
	var slime := Fighter.from_monster(Database.get_monster("slime"))
	var strike := Battle.new(wren, slime)
	strike.attacker = wren
	strike.defender = slime
	var outcome := strike.resolve(Battle.Choice.new(Battle.Offense.SPECIAL, "sure_strike"))
	_expect(outcome.damage > 0 and outcome.defense == Battle.Defense.NONE, "Sure Strike lands with no answer")


func _test_learning() -> void:
	var hero := _player("warrior")
	hero.inventory.clear()
	_expect(hero.learned == ["rally"], "a warrior starts with Rally alone")
	_expect(Fighter.from_player(hero).moves_in(MoveData.Category.MAGIC).is_empty(), "and no Magic")
	hero.add_item("tome_spark")
	_expect(not hero.equip("tome_spark"), "a tome can't be worn")
	_expect(not hero.use_item("tome_spark"), "or used up like a potion")
	_expect(hero.read_tome("tome_spark"), "a tome is read")
	_expect(hero.learned.has("spark") and hero.inventory.is_empty(), "it teaches, and it is gone")
	hero.add_item("tome_spark")
	_expect(not hero.read_tome("tome_spark") and hero.inventory.size() == 1, "a known move stays a tome")

	hero.inventory.clear()
	hero.learned.assign(["rally", "focus"])
	hero.add_item("tome_mend")
	_expect(not hero.has_room_for("mend"), "two Specials fill the slots")
	_expect(not hero.read_tome("tome_mend"), "so a third needs one forgotten")
	_expect(hero.read_tome("tome_mend", "focus"), "name one and it is replaced")
	_expect(hero.learned.has("mend") and not hero.learned.has("focus"), "the new for the old")
	hero.learned.assign(["spark", "smite", "frost_shard", "thunderbolt"])
	_expect(not hero.has_room_for("inferno"), "four Magic fill the slots")
	_expect(hero.has_room_for("rally"), "and Magic has no say over Special")


# Thousands of fights, across everyone and everything, must all end with no error.
func _test_many_fights() -> void:
	var fights := 0
	for class_id in Database.sorted_ids(Database.classes):
		for monster_id in Database.sorted_ids(Database.monsters):
			var monster := Database.get_monster(monster_id)
			for index in 60:
				var hero := _player(class_id, monster.min_level)
				hero.difficulty = CpuBrain.Level.HARD if index % 2 == 0 else CpuBrain.Level.EASY
				var battle := Battle.new(Fighter.from_player(hero), Fighter.from_monster(monster))
				var turns := 0
				while not battle.is_over() and turns < 40:
					var choice := battle.cpu_offense()
					var defense := battle.cpu_defense() if battle.needs_defense(choice) else Battle.Defense.NONE
					battle.resolve(choice, defense)
					turns += 1
				_expect(battle.is_over(), "a fight always ends")
				_expect(battle.round_number <= Battle.MAX_ROUNDS + 1, "within the round limit")
				battle.conclude()
				fights += 1
	print("Fought %d fights." % fights)
	_expect(fights >= 2000, "thousands of fights were played")


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
	_expect(red.gold == 0 and blue.gold == 200, "a rival's spoils are left to Rivalry")
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
			CpuBrain.shop(hero, Database.sorted_ids(Database.items))
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
