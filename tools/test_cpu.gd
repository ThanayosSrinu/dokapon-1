extends Node
## Tests the CPU players' thinking, with no window. Run from the project root:
##   godot --headless --path . res://tools/test_cpu.tscn
## Prints a table of guessed and real win chances, then "TESTS OK" or one FAIL line
## per problem, and exits with 1 on failures.

## Fights per match in the tables below.
const FIGHTS := 300

var _failures := 0
var _board: BoardManager


func _ready() -> void:
	_board = load("res://maps/WorldMap.tscn").instantiate()
	add_child(_board)
	await get_tree().process_frame
	_test_win_odds()
	_test_levels_in_battle()
	_test_battle_choices()
	_test_roads()
	_test_towns_and_chests()
	_test_rivals()
	_test_field_magic()
	_test_gear()
	await _test_setup_menu()
	if _failures == 0:
		print("TESTS OK")
	get_tree().quit(1 if _failures > 0 else 0)


# --- Win chances ------------------------------------------------------------

func _test_win_odds() -> void:
	_new_game([])
	var total_error := 0.0
	var matches := 0
	print("Guessed and real win chances, at full health:")
	for class_id: String in ["warrior", "mage", "cleric", "rogue"]:
		for level: int in [1, 4, 8, 12]:
			for monster_id in Database.monster_ids_for_level(level):
				var hero := _hero(class_id, level)
				var monster := Database.get_monster(monster_id)
				var guess := CpuBrain.monster_odds(hero, monster)
				var wins := 0
				for fight in FIGHTS:
					hero.heal_fully()
					wins += 1 if _fight_monster(hero, monster) else 0
				var real := float(wins) / FIGHTS
				total_error += absf(guess - real)
				matches += 1
				if absf(guess - real) > 0.35:
					print("  %-8s Lv %2d vs %-14s guess %.2f, real %.2f" % [class_id, level, monster_id, guess, real])
	var average := total_error / matches
	print("  Average miss over %d matches: %.2f" % [matches, average])
	_expect(average < 0.2, "win_odds is close to real fights")

	var hero := _hero("warrior", 5)
	var foe := Database.get_monster(Database.monster_ids_for_level(5)[0])
	var healthy := CpuBrain.monster_odds(hero, foe)
	hero.hp = 1
	_expect(CpuBrain.monster_odds(hero, foe) < healthy, "being hurt lowers the odds")
	hero.hp = hero.get_stat("max_hp")
	hero.add_item("elixir")
	_expect(CpuBrain.monster_odds(hero, foe) >= healthy, "carrying healing helps the odds")

	var rng_before := GameState.rng.state
	CpuBrain.monster_odds(hero, foe)
	_expect(GameState.rng.state == rng_before, "thinking uses no numbers from GameState.rng")


func _test_levels_in_battle() -> void:
	_new_game([])
	var line := PackedStringArray()
	var previous := 0.0
	var levels: Array[CpuBrain.Level] = [CpuBrain.Level.NORMAL, CpuBrain.Level.HARD]
	for level in levels:
		var wins := 0
		var losses := 0
		for fight in FIGHTS * 2:
			var thinker := _hero("warrior", 8, level)
			var easy := _hero("warrior", 8, CpuBrain.Level.EASY)
			var winner := _duel(thinker, easy)
			wins += 1 if winner == thinker else 0
			losses += 1 if winner == easy else 0
		var share := float(wins) / maxi(wins + losses, 1)
		line.append("%s %.2f (%d won, %d lost, %d unfinished)" % [CpuBrain.LEVEL_NAMES[level], share, wins, losses,
				FIGHTS * 2 - wins - losses])
		_expect(share > 0.52, "%s beats Easy in a fair duel" % CpuBrain.LEVEL_NAMES[level])
		_expect(share >= previous - 0.03, "a higher level does at least as well")
		previous = share
	print("Won against an Easy twin: %s" % ", ".join(line))


func _test_battle_choices() -> void:
	_new_game([])
	var hero := _hero("warrior", 5)
	var foe := _hero("warrior", 5)
	foe.hp = 1
	var battle := _battle_between(hero, foe)
	for attempt in 40:
		_expect(CpuBrain.offense(battle).offense != Battle.Offense.ITEM, "it finishes a beaten foe")

	hero.hp = 1
	hero.add_item("potion")
	foe.heal_fully()
	battle = _battle_between(hero, foe)
	_expect(CpuBrain.offense(battle).offense == Battle.Offense.ITEM, "it heals when one hit from defeat")

	hero.inventory.clear()
	hero.spells.clear()
	foe.level = 20
	foe.heal_fully()
	battle = _battle_between(hero, foe)
	_expect(CpuBrain.offense(battle).offense == Battle.Offense.FLEE, "it runs from a fight it cannot win")

	foe.level = 5
	foe.heal_fully()
	hero.heal_fully()
	var hard := _hero("warrior", 5, CpuBrain.Level.HARD)
	battle = _battle_between(hard, foe)
	var counters := 0
	var trials := 200
	battle.seen_offenses[battle.attacker if battle.attacker != _fighter_of(battle, hard) else battle.defender] = {Battle.Offense.SMASH: 8}
	if battle.defender == _fighter_of(battle, hard):
		for trial in trials:
			counters += 1 if CpuBrain.defense(battle) == Battle.Defense.COUNTER else 0
		_expect(counters > trials / 2.0, "Hard counters a foe who keeps smashing")
	var picks := {}
	var mixed := _battle_between(_hero("warrior", 5), _hero("warrior", 5))
	for trial in trials:
		picks[CpuBrain.offense(mixed).offense] = true
	_expect(picks.size() >= 2, "Normal does not always pick the same move")


# --- Roads ------------------------------------------------------------------

func _test_roads() -> void:
	var hero := _hero("warrior", 3)
	_new_game([hero])
	GameState.quest = {}
	hero.hp = 1
	var fork := _space_beside(BoardNode.NodeType.SHRINE)
	var shrine := _neighbor_of_type(fork, BoardNode.NodeType.SHRINE)
	_expect(_pick(hero, fork, 1) == shrine, "a hurt CPU turns toward a shrine")

	hero.heal_fully()
	fork = _space_beside(BoardNode.NodeType.TRAP)
	var trap := _neighbor_of_type(fork, BoardNode.NodeType.TRAP)
	_expect(_pick(hero, fork, 1) != trap, "a CPU steps around a trap")

	var rival := _hero("warrior", 3)
	GameState.players.append(rival)
	rival.space_id = -1
	fork = _space_beside(BoardNode.NodeType.TOWN)
	var town := _neighbor_of_type(fork, BoardNode.NodeType.TOWN)
	Town.claim(town.node_id, rival)
	GameState.town_levels[town.node_id] = Town.MAX_LEVEL
	if not CpuBrain.will_storm(hero, town.node_id):
		_expect(_pick(hero, fork, 1) != town, "a CPU avoids a toll it cannot beat")
	GameState.town_owners.clear()
	GameState.town_levels.clear()

	var target := _board.get_board_node(Town.ids()[0])
	var before := _neighbors_with_exits(target)
	GameState.quest = {"kind": Quest.Kind.VISIT, "target": target.node_id, "place": "", "needed": 1,
			"reward": 500, "winner": ""}
	if before != null:
		_expect(_pick(hero, before, 1) == target, "a CPU walks onto a town the royal quest wants")
	var easy := _hero("warrior", 3, CpuBrain.Level.EASY)
	var hits := 0
	if before != null:
		for attempt in 200:
			hits += 1 if _pick(easy, before, 1) == target else 0
		_expect(hits < 200, "an Easy CPU ignores the quest some of the time")
	GameState.quest = {}

	# A prize beyond this roll pulls Normal and Hard, but not Easy.
	var wide := _space_beside(BoardNode.NodeType.GOLD)
	hero.difficulty = CpuBrain.Level.HARD
	var far_sighted: float = CpuBrain._look_around(hero, _board).beyond[wide]
	hero.difficulty = CpuBrain.Level.EASY
	var short_sighted: float = CpuBrain._look_around(hero, _board).beyond[wide]
	_expect(far_sighted > 0.0 and short_sighted == 0.0, "only better players look past this roll")
	hero.difficulty = CpuBrain.Level.NORMAL


func _pick(player: PlayerData, from: BoardNode, steps: int) -> BoardNode:
	var options := _board.get_connected_nodes(from)
	return CpuBrain.choose_path(player, _board, options, from, steps)


func _space_beside(kind: BoardNode.NodeType) -> BoardNode:
	for node in _board.get_all_nodes():
		if _neighbor_of_type(node, kind) != null and _board.get_neighbors(node).size() >= 2 \
				and _others_are_plain(node, kind):
			return node
	return null


func _others_are_plain(node: BoardNode, kind: BoardNode.NodeType) -> bool:
	for neighbor in _board.get_neighbors(node):
		if neighbor.node_type != kind and neighbor.node_type != BoardNode.NodeType.NORMAL:
			return false
	return true


func _neighbor_of_type(node: BoardNode, kind: BoardNode.NodeType) -> BoardNode:
	for neighbor in _board.get_neighbors(node):
		if neighbor.node_type == kind:
			return neighbor
	return null


func _neighbors_with_exits(target: BoardNode) -> BoardNode:
	for neighbor in _board.get_neighbors(target):
		if _board.get_neighbors(neighbor).size() >= 2:
			return neighbor
	return null


# --- Decisions --------------------------------------------------------------

func _test_towns_and_chests() -> void:
	var hero := _hero("warrior", 1)
	_new_game([hero])
	var weak := -1
	var strong := -1
	for id in Town.ids():
		if weak < 0 or Town.guard_level(id) < Town.guard_level(weak):
			weak = id
		if strong < 0 or Town.guard_level(id) > Town.guard_level(strong):
			strong = id
	hero.level = 3
	hero.heal_fully()
	_expect(CpuBrain.will_fight_guard(hero, weak), "it fights a weak guard")
	_expect(not CpuBrain.will_fight_guard(hero, strong), "it keeps away from a strong guard")

	var owner_rival := _hero("mage", 3)
	GameState.players.append(owner_rival)
	Town.claim(strong, owner_rival)
	_expect(not CpuBrain.will_storm(hero, strong), "it pays the toll at a town it cannot take")
	Town.claim(weak, owner_rival)
	_expect(CpuBrain.will_storm(hero, weak), "it storms a town it can take")

	hero.level = 1
	hero.heal_fully()
	hero.inventory.clear()
	hero.hp = 1
	_expect(not CpuBrain.will_open_chest(hero), "a hurt CPU leaves a chest alone")
	hero.difficulty = CpuBrain.Level.EASY
	_expect(CpuBrain.will_open_chest(hero), "an Easy CPU opens it anyway")


func _test_rivals() -> void:
	var hero := _hero("warrior", 10)
	var small := _hero("warrior", 2)
	var equal := _hero("warrior", 10)
	equal.gold = 2000
	_new_game([hero, small, equal])
	var plain := _plain_space()
	_expect(CpuBrain.duel_value(hero, small) < 0.0, "it will not bully someone far below it")
	var rivals: Array[PlayerData] = [small]
	_expect(CpuBrain.pick_rival(hero, rivals, plain) == null, "so it leaves them be")

	var strong := _hero("warrior", 20)
	rivals = [strong]
	_expect(CpuBrain.pick_rival(hero, rivals, plain) == null, "it does not challenge a far stronger rival")

	hero.grudges = []
	var without_grudge := CpuBrain.duel_value(hero, equal)
	hero.grudges.append(equal.player_name)
	_expect(CpuBrain.duel_value(hero, equal) > without_grudge, "a grudge makes a duel worth more")
	hero.grudges.clear()

	var hunter := _hero("warrior", 16)
	GameState.players.append(hunter)
	var plain_value := CpuBrain.duel_value(hunter, equal)
	GameState.shadow_crown = {"wearer": equal.player_name, "ends_day": 8}
	var hunted := CpuBrain.duel_value(hunter, equal)
	GameState.shadow_crown = {}
	_expect(hunted > plain_value, "the crown's bounty draws hunters")


func _test_field_magic() -> void:
	var hero := _hero("mage", 8)
	var leader := _hero("warrior", 8)
	var trailer := _hero("warrior", 2)
	leader.gold = 5000
	_new_game([hero, leader, trailer])
	hero.spells.assign(["slumber"])
	hero.mp = hero.get_stat("max_mp")
	var space := _plain_space()
	hero.space_id = space.node_id
	var plan := CpuBrain.field_plan(hero, _board, null)
	_expect(not plan.is_empty() and plan["target"] == leader, "Slumber goes on the leader")

	hero.spells.assign(["gold_leech"])
	plan = CpuBrain.field_plan(hero, _board, null)
	_expect(not plan.is_empty() and plan["target"] == leader, "Gold Leech goes on the richest")

	hero.spells.assign(["homeward"])
	hero.space_id = GameState.castle_id
	_expect(CpuBrain.field_plan(hero, _board, null).is_empty(), "nobody casts Homeward at home")

	hero.spells.assign(["slumber"])
	hero.mp = 0
	_expect(CpuBrain.field_plan(hero, _board, null).is_empty(), "no MP, no spell")


func _test_gear() -> void:
	var hero := _hero("warrior", 5)
	_new_game([hero])
	hero.hp = 1
	hero.inventory.assign(["herb", "elixir", "iron_sword"])
	var used := CpuBrain.tidy(hero)
	_expect(hero.equipment[ItemData.Kind.WEAPON] == "iron_sword", "it wears what it finds")
	_expect(used.has("Elixir") and hero.hp > 1, "it heals before setting off")

	var shelves: Array[String] = ["herb", "potion", "elixir"]
	var rich := _hero("warrior", 10)
	rich.gold = 1000
	rich.inventory.clear()
	CpuBrain.shop(rich, shelves)
	_expect(rich.inventory.has("elixir") and not rich.inventory.has("herb"), "with money it buys proper healing")
	_expect(rich.inventory.size() == 2, "Normal carries 2 healing items")

	var hard := _hero("mage", 10, CpuBrain.Level.HARD)
	hard.gold = 1000
	hard.inventory.clear()
	var more: Array[String] = ["potion", "mana_tonic"]
	CpuBrain.shop(hard, more)
	_expect(hard.inventory.count("potion") == 3, "Hard carries 3")
	_expect(hard.inventory.has("mana_tonic"), "a Hard caster also carries mana")

	var spoils: Array[Dictionary] = [
			{"kind": Rivalry.Spoil.GOLD, "text": "", "value": 400},
			{"kind": Rivalry.Spoil.ITEM, "text": "", "value": 300, "item": "war_hammer"}]
	var fighter := _hero("warrior", 5)
	_expect(CpuBrain.pick_spoil(fighter, spoils)["kind"] == Rivalry.Spoil.ITEM, "it takes gear it can use")


func _test_setup_menu() -> void:
	var main: GameController = load("res://main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var menu := main.setup_menu
	menu.button_row.get_child(1).pressed.emit()
	_expect(menu.question_label.text.contains("computer play"), "the menu asks how many are CPUs")
	_expect(menu.button_row.get_child_count() == 4, "from none up to all 3")
	menu.button_row.get_child(2).pressed.emit()
	_expect(menu.question_label.text.contains("How well"), "then how well they play")
	_expect(menu.button_row.get_child_count() == 3, "with three levels")
	menu.button_row.get_child(2).pressed.emit()
	_expect(main.cpu_players == 2 and main.cpu_level == CpuBrain.Level.HARD, "the answers reach the game")
	var cpus := GameState.players.filter(func(player: PlayerData) -> bool: return player.is_cpu)
	_expect(cpus.size() == 2 and cpus[0].difficulty == CpuBrain.Level.HARD, "and the players")
	main.queue_free()
	await get_tree().process_frame


# --- Helpers ----------------------------------------------------------------

func _new_game(roster: Array) -> void:
	var players: Array[PlayerData] = []
	players.assign(roster)
	GameState.start_new_game(players, 1)
	Town.setup(_board.get_town_info())
	GameState.castle_id = _board.get_starting_node().node_id


func _hero(class_id: String, level: int, difficulty := CpuBrain.Level.NORMAL) -> PlayerData:
	var hero := PlayerData.new("Hero%d" % randi(), Color.WHITE, true)
	hero.choose_class(class_id)
	hero.level = level
	hero.difficulty = difficulty
	hero.heal_fully()
	return hero


func _plain_space() -> BoardNode:
	for node in _board.get_all_nodes():
		if node.node_type == BoardNode.NodeType.NORMAL:
			return node
	return null


func _battle_between(first: PlayerData, second: PlayerData) -> Battle:
	var battle := Battle.new(Fighter.from_player(first), Fighter.from_player(second))
	if battle.attacker.player != first:
		var swapped := battle.attacker
		battle.attacker = battle.defender
		battle.defender = swapped
	return battle


func _fighter_of(battle: Battle, player: PlayerData) -> Fighter:
	return battle.attacker if battle.attacker.player == player else battle.defender


func _play(battle: Battle) -> void:
	while not battle.is_over():
		var choice := battle.cpu_offense()
		var defense := battle.cpu_defense() if battle.needs_defense(choice) else Battle.Defense.NONE
		battle.resolve(choice, defense)


func _fight_monster(hero: PlayerData, monster: MonsterData) -> bool:
	var battle := Battle.new(Fighter.from_player(hero), Fighter.from_monster(monster))
	_play(battle)
	return battle.winner != null and battle.winner.player == hero


# Returns the winner, or null for a draw or a fight someone ran from.
func _duel(first: PlayerData, second: PlayerData) -> PlayerData:
	var battle := Battle.new(Fighter.from_player(first), Fighter.from_player(second))
	_play(battle)
	return battle.winner.player if battle.winner != null else null


func _expect(condition: bool, what: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: %s" % what)
