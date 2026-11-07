extends "res://tools/test_kit.gd"
## Tests the class skill trees (E20): the data, spending and keeping points, what every
## kind of space does in a fight and on a trip, the wheel on the details page, and the
## reset at the Academy. Run with:
##   godot --headless --path . res://tools/test_trees.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const TAVERN := "res://tavern/TavernScreen.tscn"
const ACADEMY := "res://academy/AcademyScreen.tscn"
const CLASSES: Array[String] = ["warrior", "mage", "rogue", "cleric"]


func _ready() -> void:
	SaveGame.folder_name = "saves_test"
	get_tree().current_scene = null
	_test_data()
	_test_points()
	_test_stats()
	_test_fight_perks()
	_test_trip_perks()
	await _test_wheel()
	await _test_academy()
	print("TESTS OK" if _failures == 0 else "%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# A stand-in of `class_id` at `level`, with the spaces `tree` taken whatever their points.
func _member(class_id: String, tree: Array[String], level := 10) -> Member:
	var person := Adventurer.new()
	person.id = "test_" + class_id
	person.display_name = class_id.capitalize()
	person.class_id = class_id
	person.die_top = 6
	person.max_food = 25
	var one := Member.new(person)
	one.level = level
	one.tree = tree.duplicate()
	return one


func _hero(class_id: String, tree: Array[String], level := 10) -> PlayerData:
	var one := _member(class_id, tree, level)
	return Expedition.make_player(one.person, false, one)


# Every space on the way from the hero to each of `goals`, of class `class_id`.
func _path(class_id: String, goals: Array) -> Array[String]:
	var found: Array[String] = []
	for goal: String in goals:
		for id in SkillTree.path_to(class_id, goal):
			if not found.has(id):
				found.append(id)
	return found


# A fight between `player` and the first monster of level 5, with `player` acting first.
func _battle(player: PlayerData, monster_id := "") -> Battle:
	var monster := Database.get_monster(monster_id if monster_id != "" else Database.monster_ids_for_level(5)[0])
	var battle := Battle.new(Fighter.from_player(player), Fighter.from_monster(monster))
	battle.attacker = battle.challenger
	battle.defender = battle.opponent
	return battle


func _test_data() -> void:
	var perks: Array = []
	var constants := (load("res://tavern/SkillTree.gd") as Script).get_script_constant_map()
	for name: String in constants:
		var value: Variant = constants[name]
		if value is String and name == name.to_upper() and not name.begins_with("RESET"):
			perks.append(value)
	for class_id in CLASSES:
		_expect(Database.get_class_data(class_id) != null, "%s is a class" % class_id)
		var branches := SkillTree.branches(class_id)
		_expect(branches.size() == 3, "%s has 3 branches" % class_id)
		var all := SkillTree.ids(class_id)
		_expect(all.size() == 3 * SkillTree.branch_size() and all.size() > SkillTree.points_at(PlayerData.MAX_LEVEL) + 15,
				"%s has many more spaces (%d) than points" % [class_id, all.size()])
		var cells := {}
		var sizes := {}
		var trip_branch := false
		for id in all:
			var space := SkillTree.space(class_id, id)
			var size: SkillTree.Size = space["size"]
			sizes[size] = sizes.get(size, 0) + 1
			_expect(not cells.has(space["cell"]), "%s %s has a cell of its own" % [class_id, id])
			cells[space["cell"]] = id
			_expect(SkillTree.path_to(class_id, id).back() == id, "%s %s can be reached" % [class_id, id])
			_expect(space["name"] != "" and space["text"] != "", "%s %s has a name and words" % [class_id, id])
			if size == SkillTree.Size.SMALL:
				_expect(SkillTree.SMALL.has(space["stat"]), "%s %s raises a stat" % [class_id, id])
			else:
				_expect(not space["perks"].is_empty() or not space["mult"].is_empty(), "%s %s does something" % [class_id, id])
				_expect(Kit.ICON_NAMES.has(space["icon"]), "%s %s has a picture" % [class_id, id])
			for perk: String in space["perks"]:
				_expect(perks.has(perk), "%s %s has a known perk %s" % [class_id, id, perk])
				trip_branch = trip_branch or (SkillTree.TRIP_PERKS.has(perk) and SkillTree.branch_of(id) == 2)
			for stat: String in space["mult"]:
				_expect(Database.STATS.has(stat), "%s %s multiplies a real stat" % [class_id, id])
			if size == SkillTree.Size.KEYSTONE:
				var costs := false
				for stat: String in space["mult"]:
					costs = costs or space["mult"][stat] < 1.0
				_expect(costs, "%s %s, a keystone, has a cost" % [class_id, id])
		_expect(sizes.get(SkillTree.Size.NOTABLE, 0) == 9 and sizes.get(SkillTree.Size.KEYSTONE, 0) == 3,
				"%s has 3 notables and a keystone a branch" % class_id)
		_expect(trip_branch, "%s's third branch changes the trip" % class_id)
		for branch in 3:
			var letter := SkillTree.BRANCH_LETTERS[branch]
			var forks := SkillTree.links(class_id, letter + "2").size()
			_expect(forks == 4, "%s branch %s splits into 3 lanes" % [class_id, letter])
	var warrior := Database.get_class_data("warrior")
	_expect(warrior.growth["attack"] == 2 and warrior.growth["max_hp"] == 4, "growth a level was halved")


func _test_points() -> void:
	var one := _member("warrior", [], 1)
	_expect(one.points_free() == 1, "level 1 has a point to spend")
	one.level = 4
	_expect(one.points_free() == 4, "a level gives a point")
	_expect(not one.take("a2"), "a branch starts from the middle")
	_expect(one.take("a1") and one.take("a2") and one.take("aL1") and one.take("b1"), "spaces joined to taken ones can be taken")
	_expect(one.points_free() == 0 and not one.take("aL2"), "no points, no space")
	var rung: Array[String] = ["a1", "a2", "aM1", "aM2"]
	_expect(SkillTree.can_take("warrior", rung, "aL2") and SkillTree.can_take("warrior", rung, "aR2"), "a rung joins the lanes")
	_expect(not SkillTree.can_take("warrior", rung, "aL3"), "but only next to it")
	one.level = PlayerData.MAX_LEVEL
	one.tree.clear()
	one.spend_points([2, 0, 1])
	_expect(one.points_free() == 0 and one.tree.size() == 30, "the sim spends all 30 points at level 30")
	_expect(one.tree.has("cM7") and one.tree.has("cL4"), "it heads for the keystone of the branch it was told first")
	_expect(one.tree.size() < SkillTree.ids("warrior").size(), "and 30 points never fill the tree")
	# The town keeps them, through a save and a defeat.
	TownData.start_new()
	var town := TownData.current()
	town.gold = 1000
	var person := Database.adventurers_by_fee()[0]
	town.hire(person)
	var kept := town.member(person)
	kept.level = 6
	for id in ["a1", "a2", "c1"]:
		kept.take(id)
	var again := TownData.from_save(town.to_save())
	_expect(again.member(person).tree == kept.tree, "a save keeps the tree")
	var saved := town.to_save()
	saved["roster"][0]["tree"] = ["a1", "a3", "zz"]
	_expect(TownData.from_save(saved).member(person).tree == ["a1"], "a save can't hold spaces that can't be taken")
	var trip := Expedition.new(person, town.stage, 3, true, -1, kept)
	trip.ending = Expedition.Ending.BEATEN
	town.bring_home(trip)
	_expect(kept.tree.size() == 3, "points stay after a defeat")
	_expect(town.reset_problem(kept) == "", "the Academy can take them back")
	var gold := town.gold
	_expect(town.reset_tree(kept) and kept.tree.is_empty() and town.gold == gold - 3 * SkillTree.RESET_PRICE_PER_POINT,
			"a reset costs gold a point")
	_expect(kept.points_free() == 6, "and gives the points back")
	_expect(town.reset_problem(kept) == "No points spent", "nothing to take back twice")


func _test_stats() -> void:
	var plain := _hero("warrior", [])
	var built := _hero("warrior", _path("warrior", ["aR1"]))
	_expect(built.get_stat("attack") == plain.get_stat("attack") + 6, "two ATK spaces add 6")
	_expect(built.get_stat("max_hp") == plain.get_stat("max_hp") + 10, "an HP space adds 10")
	var berserker := _hero("warrior", _path("warrior", ["aM7"]))
	var nine := _hero("warrior", _path("warrior", ["aM6"]))
	_expect(berserker.get_stat("attack") == floori(nine.get_stat("attack") * 1.5), "Berserker multiplies ATK")
	_expect(berserker.get_stat("defense") == floori(nine.get_stat("defense") * 0.5), "and halves DEF")
	var one := _member("warrior", _path("warrior", ["a2"]))
	var words := HeroFacts.stat_tip(one.person, one.sheet(), "attack")
	_expect(words.contains("Skill tree: +6"), "the stat tip names the tree")
	_expect(HeroFacts.stat_tip(one.person, _member("warrior", _path("warrior", ["aM7"])).sheet(), "attack").contains("Keystone: x1.5"),
			"and the keystone")
	_expect(one.sheet().get_stat_with("iron_sword", "attack") > 1, "gear can be compared with a tree")
	var food := _member("warrior", _path("warrior", ["cM1"]))
	_expect(food.max_food() == food.person.food_at(food.level) + 2, "a food space adds Max Food")
	var haul := _member("warrior", _path("warrior", ["cM7"]))
	_expect(haul.max_food() == floori((food.person.food_at(10) + SkillTree.stat_add("warrior", haul.tree, "food")) * 1.5),
			"Long Haul multiplies it")


func _test_fight_perks() -> void:
	GameState.rng.seed = 7
	# Heavy, Guard and Ward.
	var outcome := Battle.Outcome.new()
	outcome.kind = Battle.Kind.HEAVY
	outcome.defense = Battle.Defense.GUARD
	outcome.attacker = Fighter.from_player(_hero("warrior", _path("warrior", ["aL4"])))
	outcome.defender = Fighter.from_monster(Database.get_monster("slime"))
	_expect(is_equal_approx(Battle.share_of(outcome), 2.0), "Breaker lands a heavy hit double through a Guard")
	outcome.attacker = Fighter.from_player(_hero("warrior", []))
	_expect(is_equal_approx(Battle.share_of(outcome), 1.5), "without it, 1.5x")
	outcome.kind = Battle.Kind.PLAIN
	outcome.defender = Fighter.from_player(_hero("warrior", _path("warrior", ["bM3"])))
	_expect(is_equal_approx(Battle.share_of(outcome), 0.35), "Stand Firm takes off more")
	outcome.kind = Battle.Kind.MAGIC
	outcome.defense = Battle.Defense.WARD
	outcome.defender = Fighter.from_player(_hero("mage", _path("mage", ["bL4"])))
	_expect(is_equal_approx(Battle.share_of(outcome), 0.3), "Spell Shield takes off more")
	outcome.kind = Battle.Kind.HEAVY
	outcome.defender = Fighter.from_player(_hero("mage", _path("mage", ["bM3"])))
	_expect(is_equal_approx(Battle.share_of(outcome), 1.0), "Steady Ward holds a heavy hit")

	# First Blow, fleeing, MP.
	for index in 20:
		var slow := _hero("warrior", _path("warrior", ["cL4"]))
		var battle := Battle.new(Fighter.from_player(slow), Fighter.from_monster(Database.get_monster("orc_scout")))
		_expect(battle.attacker == battle.challenger, "First Blow acts first")
	var runner := _battle(_hero("rogue", _path("rogue", ["aL4"]), 1), "stormcaller")
	var plain_runner := _battle(_hero("rogue", [], 1), "stormcaller")
	_expect(runner.flee_chance(runner.attacker, runner.defender) > plain_runner.flee_chance(plain_runner.attacker, plain_runner.defender),
			"Escape Artist flees more")
	var thrifty := Fighter.from_player(_hero("mage", _path("mage", ["aM3"])))
	_expect(thrifty.mp_cost(Database.get_move("thunderbolt")) < Database.get_move("thunderbolt").mp_cost, "Thrift costs less MP")

	# Harder hits.
	_expect(_hit(_hero("warrior", _path("warrior", ["aM3"])), "slash") > _hit(_hero("warrior", _path("warrior", ["aM2"])), "slash"), "Weapon Master hits harder")
	_expect(_hit(_hero("mage", _path("mage", ["aL4"])), "spark") > _hit(_hero("mage", _path("mage", ["aL3"])), "spark"), "Spellpower hits harder")
	var opener := _battle(_hero("rogue", _path("rogue", ["bM3"])))
	var first := opener.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.NONE)
	_expect(first.critical and first.result.begins_with("Critical!"), "Backstab's first hit is critical")
	var crits := 0
	var dodges := 0
	for index in 200:
		GameState.rng.seed = index
		var keen := _battle(_hero("rogue", _path("rogue", ["bL4"])))
		crits += 1 if keen.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.NONE).critical else 0
		var evasive := _battle(_hero("rogue", _path("rogue", ["aM3"])))
		evasive.attacker = evasive.opponent
		evasive.defender = evasive.challenger
		var hit := evasive.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.NONE)
		dodges += 1 if hit.dodged else 0
	_expect(crits > 10 and crits < 60, "Keen Edge is critical about 15%% of the time (%d of 200)" % crits)
	_expect(dodges > 10 and dodges < 60, "Evasion dodges about 15%% of the time (%d of 200)" % dodges)

	# Answers.
	var smash_on := func(defender: PlayerData) -> Battle.Outcome:
		var battle := _battle(defender, "orc_warlord")
		battle.attacker = battle.opponent
		battle.defender = battle.challenger
		var heavy := ""
		for id in Battle.offense_moves(battle.attacker):
			if Database.get_move(id).has(MoveData.HEAVY):
				heavy = id
		GameState.rng.seed = 3
		return battle.resolve(Battle.move_choice(heavy), Battle.Defense.COUNTER)
	var countered: Battle.Outcome = smash_on.call(_hero("warrior", _path("warrior", ["bL4"])))
	var plain_counter: Battle.Outcome = smash_on.call(_hero("warrior", _path("warrior", ["bL3"])))
	_expect(countered.reflected > plain_counter.reflected, "Iron Answer sends back more (%d, %d)" % [countered.reflected, plain_counter.reflected])
	var status_on := func(defender: PlayerData, defense: Battle.Defense) -> Battle.Outcome:
		var battle := _battle(defender, "slime")
		battle.attacker = battle.opponent
		battle.defender = battle.challenger
		return battle.resolve(Battle.move_choice("goo"), defense)
	_expect((status_on.call(_hero("cleric", _path("cleric", ["bL4"])), Battle.Defense.GUARD) as Battle.Outcome).blocked, "Pure Heart's Guard blocks status")
	_expect(not (status_on.call(_hero("cleric", _path("cleric", ["bL3"])), Battle.Defense.GUARD) as Battle.Outcome).blocked, "a Guard alone shortens it")
	var long_one: Battle.Outcome = status_on.call(_hero("cleric", _path("cleric", ["bL3"])), Battle.Defense.COUNTER)
	var short_one: Battle.Outcome = status_on.call(_hero("cleric", _path("cleric", ["bM3"])), Battle.Defense.COUNTER)
	_expect(short_one.turns < long_one.turns, "Steadfast shortens status")
	var mirror := _battle(_hero("mage", _path("mage", ["bM7"])), "hedge_mage")
	mirror.attacker = mirror.opponent
	mirror.defender = mirror.challenger
	var spell := ""
	for id in Battle.offense_moves(mirror.attacker):
		if Database.get_move(id).has(MoveData.MAGIC):
			spell = id
	if spell != "":
		var mirrored := mirror.resolve(Battle.move_choice(spell), Battle.Defense.WARD)
		_expect(mirrored.reflected > 0, "Mirror sends magic back")

	# Heals.
	var healer := _battle(_hero("cleric", _path("cleric", ["aM3"])))
	healer.attacker.hp = 1
	healer.attacker.add_poison(3, 4)
	healer.resolve(Battle.move_choice("mend"))
	_expect(healer.attacker.poison_turns == 0, "Purify ends poison")
	_expect(_heal(_hero("cleric", _path("cleric", ["aL4"]))) > _heal(_hero("cleric", _path("cleric", ["aL3"]))), "Blessed Hands heals more")

	# EXP.
	var scholar := _hero("mage", _path("mage", ["cM7"]))
	var plain := _hero("mage", [])
	var won := _battle(scholar)
	won.opponent.hp = 0
	won._end_by_knockout(won.challenger, won.opponent)
	var plain_won := _battle(plain)
	plain_won._end_by_knockout(plain_won.challenger, plain_won.opponent)
	var before := scholar.experience + scholar.level * 1000
	var plain_before := plain.experience + plain.level * 1000
	won.conclude()
	plain_won.conclude()
	_expect(scholar.experience + scholar.level * 1000 - before > plain.experience + plain.level * 1000 - plain_before,
			"Scholar earns more EXP")


func _hit(player: PlayerData, move_id: String) -> int:
	GameState.rng.seed = 11
	var battle := _battle(player, "orc_warlord")
	return battle.resolve(Battle.move_choice(move_id), Battle.Defense.NONE).damage


func _heal(player: PlayerData) -> int:
	GameState.rng.seed = 11
	var battle := _battle(player)
	battle.attacker.hp = 1
	return battle.resolve(Battle.move_choice("mend")).healed


func _test_trip_perks() -> void:
	var stage := Database.get_stage("grass_m")
	var sure := _member("rogue", _path("rogue", ["cL4"]))
	var trip := Expedition.new(sure.person, stage, 4, true, -1, sure)
	var zeros := 0
	for index in 300:
		zeros += 1 if trip.roll() == 0 else 0
	_expect(zeros == 0, "Sure Step never rolls 0")
	_expect(trip.player.bag_size == PlayerData.INVENTORY_SIZE, "a bag stays its size without Deep Pockets")
	var pockets := _member("rogue", _path("rogue", ["cM3"]))
	_expect(Expedition.make_player(pockets.person, true, pockets).bag_size == PlayerData.INVENTORY_SIZE + 2, "Deep Pockets holds 2 more")
	var fortune := _member("rogue", _path("rogue", ["cM7"]))
	_expect(is_equal_approx(Expedition.make_player(fortune.person, true, fortune).gold_share, Expedition.GOLD_SHARE * 1.5), "Fortune finds more gold")
	var medic := _member("cleric", _path("cleric", ["cM3"]))
	_expect(is_equal_approx(Expedition.make_player(medic.person, true, medic).rest_share, Expedition.CAMP_SHARE + 0.2), "Field Medic camps better")
	for pair: Array in [[[], 8], [_path("cleric", ["cL4"]), 6], [_path("cleric", ["cL4", "cM7"]), 4]]:
		var spaces: Array[String] = []
		spaces.assign(pair[0])
		var eater := _member("cleric", spaces)
		var eating := Expedition.new(eater.person, stage, 4, true, 20, eater)
		for day in 8:
			eating.start_day()
		_expect(eating.food_left == 20 - pair[1], "8 days eat %d meals with %d Pilgrim spaces" % [pair[1], pair[0].size()])
	var seer := _member("mage", _path("mage", ["cM3", "cL4"]))
	var seen := Expedition.new(seer.person, stage, 9, true, -1, seer)
	var chest_told := false
	var monster_told := ""
	var monster_space := -1
	for id in seen.map.spaces():
		if seen.type_at(id) == BoardNode.NodeType.TREASURE:
			chest_told = chest_told or SpaceNotes.of(seen, id)["text"].begins_with("It holds")
		elif seen.type_at(id) == BoardNode.NodeType.BATTLE and monster_space < 0:
			monster_space = id
			monster_told = SpaceNotes.of(seen, id)["title"]
	_expect(chest_told, "Scrying tells what a chest holds")
	_expect(monster_space >= 0 and Database.monsters.values().any(func(m: MonsterData) -> bool: return m.display_name == monster_told),
			"Foresight names the monster")
	seen.space_id = monster_space
	seen.land()
	_expect(seen.fight != null and seen.fight.opponent.display_name == monster_told, "and that monster is the one fought")
	var blind := _member("mage", _path("mage", ["cL3"]))
	var unseen := Expedition.new(blind.person, stage, 9, true, -1, blind)
	for id in unseen.map.spaces():
		if unseen.type_at(id) == BoardNode.NodeType.TREASURE:
			_expect(not SpaceNotes.of(unseen, id)["text"].begins_with("It holds"), "without Scrying a chest is a guess")


func _test_wheel() -> void:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 1000
	var person := Database.adventurers_by_fee()[0]
	town.hire(person)
	var one := town.member(person)
	one.level = 3
	var tavern: TavernScreen = await _open(TAVERN)
	tavern.roster_tab.pressed.emit()
	await _wait()
	tavern.open_details()
	await _wait()
	var page := tavern.page
	_expect(page.tabs[HeroPage.Tab.TREE].text == "Skill tree (3)", "the tab counts points to spend, 1 a level from level 1")
	page.tabs[HeroPage.Tab.TREE].grab_focus()
	await _wait()
	var wheel: SkillGrid = page.tree_grid
	_expect(wheel != null and wheel.spots.size() == SkillTree.ids(person.class_id).size(), "the Skill tree tab shows the grid")
	for id: String in wheel.spots:
		_expect(page.get_viewport_rect().encloses((wheel.spots[id] as Control).get_global_rect()), "space %s is on screen" % id)
	var attack := one.sheet().get_stat("attack")
	await _click(wheel.spots["aM2"])
	_expect(one.tree.is_empty(), "a space past the first can't be taken")
	await _click(wheel.spots["a1"])
	_expect(one.tree == ["a1"], "a click takes the first space")
	_expect(page.tabs[HeroPage.Tab.TREE].text == "Skill tree (2)", "the tab counts down")
	await _tap("ui_cancel")
	await _wait()
	_expect(TownData.load_saved() and TownData.current().member(person).tree == ["a1"], "the town saved it")
	town = TownData.current()
	one = town.member(person)
	tavern = await _open(TAVERN)
	tavern.roster_tab.pressed.emit()
	await _wait()
	tavern.open_details()
	await _wait()
	page = tavern.page
	page.tabs[HeroPage.Tab.TREE].grab_focus()
	await _wait()
	await _tap("ui_down")
	_expect(_focused() is Control and page.tree_grid.spots.values().has(_focused()), "down goes into the grid")
	page.tree_grid.spots["a2"].grab_focus()
	await _wait()
	await _tap("ui_accept")
	_expect(one.tree == ["a1", "a2"], "Accept takes the space with keys")
	page.tree_grid.select("b1")
	await _click(page.tree_grid.take_button)
	_expect(one.tree.has("b1") and one.points_free() == 0, "Take spends the last point")
	_expect(page.tree_grid.take_button.disabled, "with none left, Take is off")
	page.tabs[HeroPage.Tab.STATS].grab_focus()
	await _wait()
	_expect(page.shown_words().contains(str(one.sheet().get_stat("attack"))) and one.sheet().get_stat("attack") != attack,
			"the Stats tab shows the new numbers")
	page.close()
	await _wait()
	var stranger := tavern
	TownData.start_new()
	stranger = await _open(TAVERN)
	stranger.open_details()
	await _wait()
	stranger.page.tabs[HeroPage.Tab.TREE].grab_focus()
	await _wait()
	_expect(stranger.page.tree_grid != null and not stranger.page.tree_grid.take_button.visible, "someone not hired can only look")


func _test_academy() -> void:
	TownData.start_new()
	var town := TownData.current()
	town.gold = 1000
	town.buildings["academy"] = 1
	var person := Database.adventurers_by_fee()[0]
	town.hire(person)
	var one := town.member(person)
	one.level = 5
	one.spend_points([0, 1, 2])
	var academy: AcademyScreen = await _open(ACADEMY)
	academy.pick(AcademyScreen.RESET)
	await _wait()
	_expect(academy.action.visible and not academy.action.disabled, "the Academy offers a reset")
	_expect(academy.action.text == "Reset for %d gold" % (5 * SkillTree.RESET_PRICE_PER_POINT), "with its price")
	var gold := town.gold
	await _click(academy.action)
	_expect(one.tree.is_empty() and town.gold == gold - 5 * SkillTree.RESET_PRICE_PER_POINT, "pressing it takes the points back")
	_expect(academy.action.disabled, "and then there is nothing to reset")
