extends Node
## Tests spoils, grudges, field magic, events and the Shadow Crown, then plays a game
## through Main.tscn with tokens steered onto Event spaces. Run from the project root:
##   godot --headless --path . res://tools/test_rivalry.tscn
## Prints "TESTS OK" or one FAIL line per problem, and exits with 1 on failures.

const NEAR := 1
const FAR := 2

var _failures := 0


func _ready() -> void:
	_test_spoils()
	_test_grudges_and_bullies()
	_test_field_magic()
	_test_events()
	_test_crown()
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
	player.inventory.clear()
	return player


func _new_game(players: Array[PlayerData]) -> void:
	GameState.start_new_game(players, 77)
	Town.setup({NEAR: {"name": "Near", "steps": 3}, FAR: {"name": "Far", "steps": 13}})
	GameState.castle_id = 0


func _kinds(options: Array[Dictionary]) -> Array:
	return options.map(func(option: Dictionary) -> int: return option["kind"])


func _test_spoils() -> void:
	var red := _player("Red")
	var blue := _player("Blue")
	_new_game([red, blue])
	_expect(Rivalry.spoils(red, blue).is_empty(), "nothing to take from someone with nothing")
	blue.gold = 200
	blue.inventory.assign(["potion", "elixir"])
	Town.claim(NEAR, blue)
	var options := Rivalry.spoils(red, blue)
	_expect(_kinds(options) == [Rivalry.Spoil.GOLD, Rivalry.Spoil.ITEM], "gold and an item, but no town")
	_expect(options[0]["value"] == 50, "a quarter of the gold")
	_expect(options[1]["item"] == "elixir", "the best thing in the bag")
	Rivalry.take(red, blue, options[0])
	_expect(red.gold == 50 and blue.gold == 150, "the gold moves")
	Rivalry.take(red, blue, options[1])
	_expect(red.inventory == ["elixir"] and blue.inventory == ["potion"], "the item moves")
	red.inventory.assign(["potion", "potion", "potion", "potion", "potion", "potion"])
	_expect(_kinds(Rivalry.spoils(red, blue)) == [Rivalry.Spoil.GOLD], "a full bag cannot take an item")
	red.inventory.clear()

	GameState.shadow_crown = {"wearer": "Red", "ends_day": 8}
	options = Rivalry.spoils(red, blue)
	_expect(options.back()["kind"] == Rivalry.Spoil.TOWN, "the crown's wearer can take a town")
	_expect(CpuBrain.pick_spoil(red, options) == options.back(), "the CPU takes what is worth most")
	Rivalry.take(red, blue, options.back())
	_expect(Town.owner_of(NEAR) == red, "the town moves")


func _test_grudges_and_bullies() -> void:
	var strong := _player("Strong", 9)
	var weak := _player("Weak", 3)
	_new_game([strong, weak])
	_expect(Rivalry.duel_exp(strong, weak, true, 90) == 0, "no EXP for bullying")
	_expect(Rivalry.duel_exp(strong, weak, false, 90) == 90, "defending yourself is not bullying")
	_expect(Rivalry.warning(strong, weak).contains("bullying"), "the bully is warned")
	strong.gold = 1000
	var line := Rivalry.after_duel(strong, weak, true)
	_expect(strong.gold == 800 and weak.gold == 200, "the bully's fine goes to the victim")
	_expect(line.contains("200"), "the fine is announced")
	_expect(Rivalry.has_grudge(weak, strong), "the loser holds a grudge")
	_expect(Rivalry.grudge_text() == "Grudges: Weak against Strong.", "grudges can be read")
	_expect(Rivalry.warning(weak, strong).contains("double"), "the loser is told of the revenge")
	_expect(Rivalry.duel_exp(weak, strong, true, 90) == 180, "revenge pays double")
	Rivalry.after_duel(weak, strong, true)
	_expect(not Rivalry.has_grudge(weak, strong), "revenge settles it")
	_expect(Rivalry.has_grudge(strong, weak), "and starts a new one")
	_expect(not Rivalry.is_bullying(strong, weak), "a grudge is not bullying")

	var duel_red := _player("Red", 7)
	var duel_blue := _player("Blue", 2)
	_new_game([duel_red, duel_blue])
	duel_blue.gold = 400
	duel_blue.hp = 1
	var battle := Battle.new(Fighter.from_player(duel_red), Fighter.from_player(duel_blue))
	battle.attacker = battle.challenger
	battle.defender = battle.opponent
	battle.resolve(Battle.Choice.new(Battle.Offense.ATTACK), Battle.Defense.COUNTER)
	var lines := battle.conclude()
	_expect(duel_red.experience == 0 and duel_red.level == 7, "a bully earns nothing")
	_expect(" ".join(lines).contains("so far below you"), "and is told why")


func _test_field_magic() -> void:
	var red := _player("Red", 8)
	var blue := _player("Blue", 8)
	var green := _player("Green", 8)
	_new_game([red, blue, green])
	for spell_id in FieldMagic.all_ids():
		red.learn_spell(spell_id)
	red.mp = 40
	_expect(FieldMagic.all_ids().size() == 5 and FieldMagic.known(red).size() == 5, "five field spells")
	_expect(not Fighter.from_player(red).get_spells().has("slumber"), "field spells stay out of battle")
	_expect(red.spells.has("slumber"), "the player still knows them")
	var start := red.mp
	FieldMagic.cast(red, "swift_wind")
	_expect(red.mp == start - 3, "casting costs MP")
	_expect(red.roll_bonus == 2, "Swift Wind helps the next roll")
	_expect(FieldMagic.why_not(red, "swift_wind") != "", "it cannot stack")
	_expect(red.take_roll_bonus() == 2 and red.roll_bonus == 0, "a bonus lasts one roll")
	FieldMagic.cast(red, "mire", blue)
	_expect(blue.roll_bonus == -2, "Mire slows a rival")
	_expect(not FieldMagic.valid_targets(red, "mire").has(blue), "nobody is mired twice")
	blue.gold = 1000
	var leech := FieldMagic.cast(red, "gold_leech", blue)
	_expect(leech.gold_changes == {blue: -100, red: 100}, "Gold Leech takes a tenth")
	FieldMagic.cast(red, "slumber", blue)
	_expect(blue.turns_to_skip == 1, "Slumber takes a turn")
	_expect(not FieldMagic.valid_targets(red, "slumber").has(blue), "nobody sleeps twice over")
	red.space_id = 5
	_expect(FieldMagic.cast(red, "homeward").to_castle, "Homeward goes to the castle")
	red.space_id = GameState.castle_id
	_expect(FieldMagic.why_not(red, "homeward") != "", "Homeward is useless at the castle")
	red.mp = 0
	_expect(FieldMagic.why_not(red, "mire") == "Not enough MP.", "no MP, no spell")
	_expect(CpuBrain.field_plan(red, null, null).is_empty(), "a CPU with no MP casts nothing")

	var learner := _player("Learner", 1)
	var teachable := SpaceEffects.learnable_spells(learner)
	_expect(teachable.has("swift_wind") and teachable.has("gold_leech"), "Magic spaces teach field spells")
	_expect(not teachable.has("slumber"), "but not above their level")


func _test_events() -> void:
	var red := _player("Red", 3)
	var blue := _player("Blue", 3)
	_new_game([red, blue])
	red.gold = 1000
	blue.gold = 100
	var spaces: Array[int] = [0, 1, 2, 3]
	red.space_id = 1
	for event: String in Events.WEIGHTS:
		_expect(Events.run(event, red, spaces).title != "" if Events.can_happen(event, red) else true,
				"%s has a title" % event)
	_expect(not Events.can_happen("raid", red), "no town, no raid")

	var festival := Events.run("festival", red, spaces)
	_expect(festival.gold_changes == {red: 60, blue: 60}, "a festival pays everyone")
	_expect(Events.run("tax", red, spaces).gold_changes == {red: -100, blue: -10}, "a tax takes a tenth")
	_expect(Events.run("hero", red, spaces).gold_changes == {red: -100, blue: 100}, "the outlaw robs the rich")
	red.hp = 1
	red.roll_bonus = 0
	Events.run("blessing", red, spaces)
	_expect(red.hp == red.get_stat("max_hp") and red.roll_bonus == 2, "a blessing heals and speeds")
	var hurt := red.hp
	Events.run("storm", red, spaces)
	_expect(red.hp < hurt and blue.hp < blue.get_stat("max_hp"), "a storm hurts everyone")
	red.hp = 1
	Events.run("storm", red, spaces)
	_expect(red.hp == 1, "a storm never knocks anyone out")
	for repeat in 40:
		var warp := Events.run("portal", red, spaces).warp_to
		_expect(warp != red.space_id and warp != GameState.castle_id, "a portal goes somewhere new")
	_expect(Events.run("ambush", red, spaces).guardian != null, "an ambush has a monster")

	Town.claim(NEAR, red)
	Town.claim(FAR, red)
	GameState.town_levels[FAR] = 2
	var raid := Events.run("raid", blue, spaces)
	_expect(raid.town_id == FAR and Town.level(FAR) == 1, "a raid hits the finest town")
	Events.run("raid", blue, spaces)
	_expect(Town.level(NEAR) + Town.level(FAR) == 1, "a raid on level 1 hands the town to monsters")
	_expect(Town.towns_of(red).size() == 1, "the owner loses it")
	for spell_id in FieldMagic.all_ids():
		red.learn_spell(spell_id)
	_expect(not Events.can_happen("tutor", red), "the sage has nothing left to teach")
	for repeat in 200:
		_expect(Events.draw(blue, spaces).title != "", "a draw always gives an event")
		blue.spells.clear()


func _test_crown() -> void:
	var red := _player("Red", 5)
	var blue := _player("Blue", 5)
	_new_game([red, blue])
	blue.gold = 1000
	red.gold = 100
	_expect(ShadowCrown.next_wearer() == null, "no crown in the first weeks")
	GameState.day = 15
	_expect(ShadowCrown.next_wearer() == red, "it falls on the last player")
	blue.gold = 150
	_expect(ShadowCrown.next_wearer() == null, "no crown in a close game")
	blue.gold = 1000
	var news := ShadowCrown.weekly_check()
	_expect(news == {"fell": "Red"} and ShadowCrown.wearer() == red, "the crown falls")
	_expect(ShadowCrown.days_left() == 7, "for a week")

	var plain := Fighter.from_player(blue)
	var crowned := Fighter.from_player(red)
	_expect(crowned.get_stat("attack") == roundi(blue.get_stat("attack") * 1.35), "it adds to attack")
	_expect(crowned.get_stat("speed") > plain.get_stat("speed"), "and to speed")
	_expect(crowned.get_stat("max_hp") == plain.get_stat("max_hp"), "but not to HP")
	_expect(red.get_stat("attack") == blue.get_stat("attack"), "the sheet shows the real stat")
	_expect(crowned.color == ShadowCrown.COLOR, "the crown shows in battle")
	_expect(ShadowCrown.roll_bonus(red) == 1 and ShadowCrown.roll_bonus(blue) == 0, "it adds to rolls")
	_expect(not Rivalry.is_bullying(red, _player("Tiny", 1)), "the wearer is never a bully")
	var full_hp := red.hp
	_expect(ShadowCrown.drain(red) == int(red.get_stat("max_hp") * 0.08), "it feeds on HP")
	_expect(red.hp < full_hp, "and it hurts")
	red.hp = 1
	ShadowCrown.drain(red)
	_expect(red.hp == 1, "it never knocks anyone out")

	Town.claim(NEAR, red)
	_expect(Town.collect_income().is_empty(), "the wearer gets no town income")
	GameState.day = 21
	_expect(ShadowCrown.weekly_check().is_empty(), "it stays for its whole week")
	GameState.day = 22
	_expect(ShadowCrown.weekly_check() == {"lifted": "Red"}, "then it lifts")
	_expect(ShadowCrown.wearer() == null, "and nobody wears it")
	_expect(not Town.collect_income().is_empty(), "income comes back")
	_expect(ShadowCrown.next_wearer() == null, "it rests after leaving")
	GameState.day = 36
	_expect(ShadowCrown.next_wearer() != null, "and can come back")

	GameState.shadow_crown = {"wearer": "Red", "ends_day": 40}
	blue.gold = 0
	_expect(ShadowCrown.shatter(blue) == 200 + 50 * GameState.get_week(), "beating the wearer pays a bounty")
	_expect(blue.gold == ShadowCrown.bounty(), "to the winner")
	_expect(ShadowCrown.wearer() == null, "and the crown is gone")


## A real game: tokens are pushed onto Event spaces and into duels, with the crown
## forced onto someone, and every button is pressed by chance.
func _test_full_game() -> void:
	Engine.time_scale = 60.0
	var main: GameController = load("res://main/Main.tscn").instantiate()
	main.game_seed = 11
	add_child(main)
	await get_tree().process_frame
	var presses := RandomNumberGenerator.new()
	presses.seed = 99
	main.setup_menu.hide()
	main.setup_menu.player_count_chosen.emit(4)

	var hooked := false
	var seen := {}
	var casts := 0
	while GameState.day <= 70:
		await get_tree().process_frame
		if main.class_menu.visible:
			for child in main.class_menu.find_children("*", "Button", true, false):
				child.pressed.emit()
				break
			continue
		if main.hud.visible and not hooked:
			hooked = true
			for player in GameState.players:
				for spell_id in FieldMagic.all_ids():
					player.learn_spell(spell_id)
			for token: PlayerMovement in main._tokens.values():
				token.step_finished.connect(_steer.bind(main, presses))
		if main.turn_manager.phase == TurnManager.Phase.ACTION and GameState.get_day_of_week() == 2 \
				and ShadowCrown.wearer() == null:
			GameState.shadow_crown = {"wearer": GameState.players[0].player_name, "ends_day": GameState.day + 6}
			GameState.players[0].changed.emit()
			main._update_crown({"fell": GameState.players[0].player_name})
		var text := main.status_label.text
		for word: String in ["celebrates", "collectors", "merchant", "Lightning", "storm",
				"leaps out", "pulls", "outlaw", "sage", "choose your spoils", "shatters", "bars the door",
				"Revenge", "bullying", "lifts", "falls on"]:
			if text.contains(word):
				seen[word] = true
		if text.contains(" casts "):
			casts += 1
		if main.field_button.visible and presses.randf() < 0.5:
			main._open_field_magic()
		_press_something(main, presses)
	Engine.time_scale = 1.0

	print("Seen: %s. Frames with a cast on screen: %d" % [", ".join(seen.keys()), casts])
	for word: String in ["celebrates", "collectors", "merchant", "Lightning", "leaps out", "pulls",
			"choose your spoils", "shatters"]:
		_expect(seen.has(word), "the game showed '%s'" % word)
	_expect(casts > 0, "field magic was cast")
	for player in GameState.players:
		var token: PlayerMovement = main._tokens[player]
		_expect(token.is_crowned == ShadowCrown.is_worn_by(player), "the crown is on the right head")
		_expect(token.current_node.node_id == player.space_id, "each token is where its player is")
	main.queue_free()


# When a move ends, pushes the token to an Event space or onto a rival.
func _steer(_node: BoardNode, steps_remaining: int, main: GameController, presses: RandomNumberGenerator) -> void:
	if steps_remaining > 0:
		return
	var player := main.turn_manager.current_player()
	var chance := presses.randf()
	if chance < 0.35:
		var events := main.board.get_all_nodes().filter(func(node: BoardNode) -> bool:
				return node.node_type == BoardNode.NodeType.EVENT)
		var space: BoardNode = events[presses.randi_range(0, events.size() - 1)]
		main._active_player().spawn_at(space)
		player.space_id = space.node_id
	elif chance < 0.7:
		var rival := GameState.players[presses.randi_range(0, GameState.players.size() - 1)]
		if rival != player and rival.space_id != GameState.castle_id:
			main._active_player().spawn_at(main.board.get_board_node(rival.space_id))
			player.space_id = rival.space_id


# Does what a person would: presses a random button that is on offer.
func _press_something(main: GameController, presses: RandomNumberGenerator) -> void:
	if main.turn_manager.phase == TurnManager.Phase.ACTION and not main.roll_button.disabled \
			and main.roll_button.visible:
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
