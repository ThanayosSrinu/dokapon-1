class_name BattleScreen
extends Control
## Shows a Battle and asks people for their moves. The rules stay in Battle.gd:
## this script only asks, calls resolve(), and plays what came back.
##     var lines: PackedStringArray = await battle_screen.run(battle)
## run() returns when the fight is over and its rewards are paid.
##
## On your turn the row reads ATK, Item and Flee. ATK lists every move
## you can make, each with icons for how it can be answered. Defending, the row lists your
## defense moves (DEF), each with icons for what it answers. The attacker's choice is never
## shown until the defender has answered.

## Emitted by a choice button, with that choice's value.
signal _option_picked(value: Variant)

## The fight fills the window, laid out like a handheld RPG's: the two plates along the
## top with the stats compared between them, the fighters on their patches of earth, and
## the words and the moves along the bottom. Text comes big, and only for what matters
## now; the details of a move show while it is picked out.
const STAGE_SIZE := Vector2(1280, 720)
## On the backdrop's two patches of earth.
const LEFT_HOME := Vector2(320, 488)
const RIGHT_HOME := Vector2(960, 488)
const EDGE := 24.0
## Below the way back, which stands in the top left corner.
const PLATE_TOP := 88.0
const BOTTOM_TOP := 536.0
const COMMAND_WIDTH := 424.0
const GAP := 16.0
const SHADE := Color(0.03, 0.04, 0.12, 0.86)
const HEAL_COLOR := Color(0.5, 0.95, 0.55)
const MANA_COLOR := Color(0.55, 0.75, 1.0)
const HIT_COLOR := Color(1.0, 0.92, 0.7)
## Seconds a CPU appears to think, and that a result stays readable.
const CPU_PAUSE := 0.55
const READ_PAUSE := 0.8
const ENDING_PAUSE := 1.4

const BACK := "back"
const ITEM_MENU := "item"
const BUTTON_SIZE := Vector2(176, 48)
## A move list always shows this many places, so that an empty one says a move can still
## be learned there.
const MOVE_SLOTS := 4
## How far the way back pokes out past the command window's top left corner.
const BACK_TAB_OVERHANG := Vector2(14, 14)
## The narrowest a button gets in a row of three.
const ROW_BUTTON_WIDTH := 116.0
## Words longer than this drop to the small size, so they still fit the box.
const BIG_WORDS := 84
## Where a word about the defense floats, against the damage number above it.
const DEFENSE_WORD_DROP := 44.0

const ATK_MENU := "atk"
const ATK_HINT := "Pick a move. Its icons say how it can be answered."
const OFFENSE_WORDS := "What will %s do?"
const DEF_WORDS := "%s attacks! How will %s answer?"
const ROUND_WORDS := "Round %d"
const FLEE_HINT := "Run from the fight. Speed decides if you get away."
const BOOST_COLOR := Color(1.0, 0.8, 0.35)
const STATUS_COLOR := Color(0.76, 0.48, 0.96)

var _battle: Battle
var _arena: Control
var _left_panel: BattlePanel
var _right_panel: BattlePanel
var _stats: BattleStats
var _round_label: Label
var _log: Label
var _hint: Label
var _command_panel: PanelContainer
var _choices: GridContainer
var _back_tab: Button
var _flash: ColorRect
# Fighter -> its BattleSprite.
var _sprites := {}
# Fighter -> its BattlePanel.
var _panels := {}
# True while the row of choices has a Back button.
var _has_back := false


func _ready() -> void:
	# Keeps clicks from reaching the board and buttons behind the window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_arena = Control.new()
	_arena.custom_minimum_size = STAGE_SIZE
	_arena.clip_contents = true
	center.add_child(_arena)
	var backdrop := TextureRect.new()
	backdrop.texture = GameArt.BATTLE_BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.size = STAGE_SIZE
	_arena.add_child(backdrop)

	var round_chip := PanelContainer.new()
	round_chip.theme_type_variation = &"Chip"
	_arena.add_child(round_chip)
	_round_label = Kit.text("")
	_round_label.modulate = Kit.GOLD
	round_chip.add_child(_round_label)

	_left_panel = BattlePanel.new()
	_left_panel.position = Vector2(EDGE, PLATE_TOP)
	_arena.add_child(_left_panel)
	_right_panel = BattlePanel.new()
	_right_panel.position = Vector2(STAGE_SIZE.x - EDGE - BattlePanel.WIDTH, PLATE_TOP)
	_arena.add_child(_right_panel)
	_stats = BattleStats.new()
	_arena.add_child(_stats)

	var words_panel := PanelContainer.new()
	words_panel.position = Vector2(EDGE, BOTTOM_TOP)
	words_panel.size = Vector2(STAGE_SIZE.x - EDGE * 2.0 - GAP - COMMAND_WIDTH, STAGE_SIZE.y - EDGE - BOTTOM_TOP)
	_arena.add_child(words_panel)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 10)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words_panel.add_child(words)
	_log = Kit.text("", 1.0)
	_log.add_theme_font_size_override("font_size", Kit.BIG_TEXT)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_log)
	_hint = Kit.text("", 1.0)
	_hint.modulate = Kit.GOLD
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_hint)

	_command_panel = PanelContainer.new()
	_command_panel.custom_minimum_size.x = COMMAND_WIDTH
	_arena.add_child(_command_panel)
	_choices = GridContainer.new()
	_choices.add_theme_constant_override("h_separation", 8)
	_choices.add_theme_constant_override("v_separation", 8)
	_choices.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_choices.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_command_panel.add_child(_choices)
	_command_panel.hide()
	# The way back out of a list is a small arrow on the window's corner, so that every
	# place in the grid is left for a choice.
	_back_tab = Button.new()
	_back_tab.icon = Kit.icon("back")
	_back_tab.focus_mode = Control.FOCUS_NONE
	_back_tab.custom_minimum_size = Vector2(48, 48)
	_back_tab.pressed.connect(func() -> void: _option_picked.emit(BACK))
	Tips.attach(_back_tab, "Back", "Or press Esc.")
	_arena.add_child(_back_tab)
	_back_tab.hide()

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color.TRANSPARENT
	add_child(_flash)
	hide()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SHADE)


## Plays the whole fight. Returns the sentences that sum up how it ended.
func run(battle: Battle) -> PackedStringArray:
	_battle = battle
	_setup_fighters()
	show()
	var outside_tune := Sound.current_tune()
	Sound.play("battle_start")
	Sound.music("battle")
	var levels := _levels_now()
	await _play_intro()
	while not battle.is_over():
		await _play_action()
	var lines := battle.conclude()
	await _play_ending(lines, levels)
	_clear_fighters()
	hide()
	Sound.music(outside_tune)
	return lines


# --- Setup ------------------------------------------------------------------

func _setup_fighters() -> void:
	_clear_choices()
	_say("")
	_add_fighter(_battle.challenger, LEFT_HOME, true, _left_panel)
	_add_fighter(_battle.opponent, RIGHT_HOME, false, _right_panel)
	_stats.setup(_battle.challenger, _battle.opponent)
	_stats.reset_size()
	_stats.position = Vector2(roundf((STAGE_SIZE.x - _stats.size.x) / 2.0), PLATE_TOP)
	_show_round()


func _add_fighter(fighter: Fighter, home: Vector2, facing_right: bool, panel: BattlePanel) -> void:
	var sprite := BattleSprite.new()
	_arena.add_child(sprite)
	# The fighters stand in front of the backdrop and behind every panel.
	_arena.move_child(sprite, 1)
	sprite.setup(fighter, home, facing_right)
	panel.setup(fighter)
	_sprites[fighter] = sprite
	_panels[fighter] = panel


func _clear_fighters() -> void:
	for sprite: BattleSprite in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	_panels.clear()


func _show_round() -> void:
	_round_label.text = ROUND_WORDS % _battle.round_number
	var chip: Control = _round_label.get_parent()
	chip.reset_size()
	chip.position = Vector2(roundf((STAGE_SIZE.x - chip.size.x) / 2.0), EDGE)


## Puts `words` in the box along the bottom, big if they fit, and `detail` under them.
func _say(words: String, detail := "") -> void:
	_log.text = words
	_log.add_theme_font_size_override("font_size", Kit.BIG_TEXT if words.length() <= BIG_WORDS else Kit.SMALL_TEXT)
	_hint.text = detail


# Every number and bar on screen, after something changed.
func _refresh(fighter: Fighter) -> void:
	_panels[fighter].refresh()
	_stats.refresh()


# --- One action -------------------------------------------------------------

func _play_action() -> void:
	var attacker := _battle.attacker
	_show_round()
	_say("" if attacker.is_cpu() else OFFENSE_WORDS % attacker.display_name)
	var choice := await _get_offense()
	_say("")
	var answer := {"defense": Battle.Defense.NONE, "move": ""}
	if _battle.needs_defense(choice):
		answer = await _get_defense()
	var outcome := _battle.resolve(choice, answer["defense"], answer["move"])
	await _play_outcome(outcome)


func _get_offense() -> Battle.Choice:
	var attacker := _battle.attacker
	if attacker.is_cpu():
		await _wait(CPU_PAUSE)
		return _battle.cpu_offense()
	while true:
		var picked: Variant = await _ask(_offense_options())
		if picked is String and picked == ITEM_MENU:
			var item_id: Variant = await _ask(_item_options())
			if item_id != BACK:
				return Battle.Choice.new(Battle.Offense.ITEM, item_id)
		elif picked is String and picked == ATK_MENU:
			var move_id: String = await _ask(_move_options(attacker, Battle.offense_moves(attacker), true), MOVE_SLOTS)
			if move_id != BACK:
				return Battle.move_choice(move_id)
		else:
			return Battle.Choice.new(Battle.Offense.FLEE)
	return null


func _get_defense() -> Dictionary:
	var defender := _battle.defender
	if defender.is_cpu():
		await _wait(CPU_PAUSE)
		return {"defense": _battle.cpu_defense(), "move": ""}
	_say(DEF_WORDS % [_battle.attacker.display_name, defender.display_name])
	var move_id: String = await _ask(_move_options(defender, Battle.defense_moves(defender), false), MOVE_SLOTS)
	return {"defense": Battle.defense_of(Database.get_move(move_id)), "move": move_id}


# One button per move in `moves`, with its icons, and Back when `with_back`.
func _move_options(fighter: Fighter, moves: Array[String], with_back: bool) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for move_id in moves:
		var move := Database.get_move(move_id)
		var words := "%s %d MP" % [move.display_name, move.mp_cost] if move.mp_cost > 0 else move.display_name
		var option := _option(words, move_id, MoveIcons.hint_for(move), not _battle.can_use(fighter, move_id))
		option["icon"] = MoveIcons.for_move(move)
		options.append(option)
	if with_back:
		options.append(_option("Back", BACK, ""))
	return options


func _offense_options() -> Array[Dictionary]:
	var attacker := _battle.attacker
	var usable := Battle.offense_moves(attacker).any(func(id: String) -> bool: return _battle.can_use(attacker, id))
	var options: Array[Dictionary] = [_option("ATK", ATK_MENU, ATK_HINT, not usable)]
	options.append(_option("Item", ITEM_MENU, "Use something from the bag.", attacker.get_items().is_empty()))
	var chance := _battle.flee_chance(attacker, _battle.defender)
	options.append(_option("Flee", Battle.Offense.FLEE, "%s %d%% chance." % [FLEE_HINT, roundi(chance * 100.0)]))
	return options


func _item_options() -> Array[Dictionary]:
	var attacker := _battle.attacker
	var options: Array[Dictionary] = []
	for item_id in attacker.get_items():
		var item := Database.get_item(item_id)
		options.append(_option(item.display_name, item_id, item.description,
				not attacker.player.can_use_item(item_id)))
	options.append(_option("Back", BACK, ""))
	return options


func _option(text: String, value: Variant, hint: String, disabled := false) -> Dictionary:
	return {"text": text, "value": value, "hint": hint, "disabled": disabled}


# Esc or the B button steps back, when the row offers it, before the trip hears it.
func _input(event: InputEvent) -> void:
	if not _has_back or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_option_picked.emit(BACK)


## Shows one button per option and waits for a press. Returns that option's value.
## Up to three sit in one row; more make a grid of two columns, as a move list does. With
## `slots`, the grid always has that many places, two to a row, and the ones without a
## move stand empty. Back is never in the grid: it is the arrow on the window's corner.
func _ask(options: Array[Dictionary], slots := 0) -> Variant:
	_clear_choices()
	_has_back = options.any(func(option: Dictionary) -> bool: return option["value"] is String and option["value"] == BACK)
	var shown: Array[Dictionary] = []
	shown.assign(options.filter(func(option: Dictionary) -> bool: return not (option["value"] is String and option["value"] == BACK)))
	var places := maxi(slots, shown.size())
	_choices.columns = 2 if slots > 0 or shown.size() > 3 else maxi(shown.size(), 1)
	var first_enabled: Button
	var prompt := _log.text
	for option in shown:
		var button := Button.new()
		button.text = option["text"]
		button.custom_minimum_size = Vector2(BUTTON_SIZE.x if _choices.columns <= 2 else ROW_BUTTON_WIDTH, BUTTON_SIZE.y)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = option["disabled"]
		if option.get("icon") != null:
			button.icon = option["icon"]
			button.expand_icon = false
		button.pressed.connect(func() -> void: _option_picked.emit(option["value"]))
		# The picked-out option's details show under the question.
		var show_hint := func() -> void: _say(prompt, option["hint"])
		button.focus_entered.connect(show_hint)
		button.mouse_entered.connect(show_hint)
		_choices.add_child(button)
		if first_enabled == null and not option["disabled"]:
			first_enabled = button
	for place in places - shown.size():
		_choices.add_child(_empty_slot())
	# Three that don't fit side by side go two to a row.
	if _choices.columns == 3 and _choices.get_combined_minimum_size().x > COMMAND_WIDTH - 48.0:
		_choices.columns = 2
		for button in _choices.get_children():
			button.custom_minimum_size.x = BUTTON_SIZE.x
	_place_commands()
	_command_panel.show()
	_back_tab.visible = _has_back
	_keep_focus_on_row()
	if first_enabled != null:
		first_enabled.grab_focus()
	var picked: Variant = await _option_picked
	_has_back = false
	_back_tab.hide()
	_clear_choices()
	_command_panel.hide()
	_say(prompt)
	return picked


# The command window stands in the bottom right corner and grows upward for a long list.
func _place_commands() -> void:
	_command_panel.size = Vector2.ZERO
	_command_panel.reset_size()
	var tall := maxf(_command_panel.size.y, STAGE_SIZE.y - EDGE - BOTTOM_TOP)
	_command_panel.size = Vector2(COMMAND_WIDTH, tall)
	_command_panel.position = Vector2(STAGE_SIZE.x - EDGE - COMMAND_WIDTH, STAGE_SIZE.y - EDGE - tall)
	_back_tab.position = _command_panel.position - BACK_TAB_OVERHANG


# A place in a move list with no move in it yet: sunk into the window, with nothing to press.
func _empty_slot() -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = BUTTON_SIZE
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.08, 0.5)
	style.border_color = Color(1.0, 0.95, 0.82, 0.12)
	style.set_border_width_all(2)
	style.border_width_top = 4
	style.set_corner_radius_all(6)
	style.anti_aliasing = false
	slot.add_theme_stylebox_override("panel", style)
	return slot


# Focus stays in the grid, so a stray key can't wander off to what stands around the
# fight. Arrows move along it and stop at its edges.
func _keep_focus_on_row() -> void:
	var buttons := _choices.get_children().filter(func(child: Node) -> bool: return child is Button)
	var columns := _choices.columns
	for index in buttons.size():
		var button: Button = buttons[index]
		var column := index % columns
		var left: Button = buttons[index - 1] if column > 0 else button
		var right: Button = buttons[index + 1] if column < columns - 1 and index + 1 < buttons.size() else button
		var up: Button = buttons[index - columns] if index >= columns else button
		var down: Button = buttons[index + columns] if index + columns < buttons.size() else button
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		button.focus_neighbor_top = button.get_path_to(up)
		button.focus_neighbor_bottom = button.get_path_to(down)
		button.focus_next = button.get_path_to(buttons[(index + 1) % buttons.size()])
		button.focus_previous = button.get_path_to(buttons[index - 1])


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


# --- Showing what happened --------------------------------------------------

func _play_intro() -> void:
	_flash.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.45)
	var opponent := _battle.opponent
	if opponent.monster != null:
		_say("%s appears!" % opponent.display_name, opponent.monster.description)
	else:
		_say("%s challenges %s!" % [_battle.challenger.display_name, opponent.display_name])
	await _wait(ENDING_PAUSE)


func _play_outcome(outcome: Battle.Outcome) -> void:
	_say(outcome.opening)
	var attacker: BattleSprite = _sprites[outcome.attacker]
	var defender: BattleSprite = _sprites[outcome.defender]
	match outcome.offense:
		Battle.Offense.FLEE:
			if outcome.fled:
				Sound.play("flee")
				await attacker.run_away()
			else:
				await attacker.stumble()
		Battle.Offense.ITEM:
			await _play_recovery(outcome, attacker)
		_:
			await _play_move(outcome, attacker, defender)
	if outcome.poison > 0:
		_float_text("-%d" % outcome.poison, attacker, STATUS_COLOR)
		await attacker.hurt()
	_refresh(outcome.attacker)
	if outcome.result != "":
		_say("%s\n%s" % [outcome.opening, outcome.result])
	await _wait(READ_PAUSE)


# Animations follow how the move works, so no move needs its own art.
func _play_move(outcome: Battle.Outcome, attacker: BattleSprite, defender: BattleSprite) -> void:
	match outcome.kind:
		Battle.Kind.SELF:
			Sound.play("magic")
			await attacker.cast()
			if outcome.move.effect == MoveData.Effect.HEAL:
				await _play_recovery(outcome, attacker)
			else:
				BoardFx.burst(_arena, attacker.get_chest_position(), BOOST_COLOR, 8)
				_float_text("Up!", attacker, BOOST_COLOR)
				_refresh(outcome.attacker)
				await _wait(0.4)
		Battle.Kind.STATUS:
			Sound.play("magic")
			await attacker.cast()
			if outcome.blocked:
				Sound.play("miss")
				_float_text("Blocked", defender, MANA_COLOR)
			else:
				BoardFx.burst(_arena, defender.get_chest_position(), STATUS_COLOR, 8)
				_float_text("Down!", defender, STATUS_COLOR)
			_refresh(outcome.defender)
			await _wait(0.4)
		Battle.Kind.MAGIC:
			Sound.play("magic")
			await attacker.cast()
			BoardFx.burst(_arena, defender.get_chest_position(), MANA_COLOR)
			await _play_hit(outcome, attacker, defender)
		Battle.Kind.HEAVY:
			await attacker.wind_up()
			await attacker.lunge(defender.position)
			await _play_hit(outcome, attacker, defender)
			await attacker.go_home()
		_:
			await attacker.lunge(defender.position)
			await _play_hit(outcome, attacker, defender)
			await attacker.go_home()


func _play_recovery(outcome: Battle.Outcome, sprite: BattleSprite) -> void:
	Sound.play("heal")
	BoardFx.burst(_arena, sprite.get_chest_position(), HEAL_COLOR, 8)
	if outcome.healed > 0:
		_float_text("+%d" % outcome.healed, sprite, HEAL_COLOR)
	elif outcome.mana_restored > 0:
		_float_text("+%d" % outcome.mana_restored, sprite, MANA_COLOR)
	_refresh(outcome.attacker)
	await _wait(0.4)


func _play_hit(outcome: Battle.Outcome, attacker: BattleSprite, defender: BattleSprite) -> void:
	if outcome.reflected > 0:
		Sound.play("counter")
		_float_text("Counter!", defender, GameArt.GOLD)
		_float_text("%d" % outcome.reflected, attacker, HIT_COLOR)
		_refresh(outcome.attacker)
		await attacker.hurt()
	else:
		var held := Battle.share_of(outcome) < 1.0
		Sound.play("miss" if held else "hit")
		if not held:
			_shake_arena()
		_float_text("%d" % outcome.damage, defender, HIT_COLOR)
		_float_defense(outcome, defender)
		_refresh(outcome.defender)
		await defender.hurt()


func _play_ending(lines: PackedStringArray, levels: Dictionary) -> void:
	var battle := _battle
	if battle.loser != null:
		Sound.play("victory" if battle.winner.player != null else "defeat")
		var survivor: BattleSprite = _sprites[battle.winner]
		survivor.cheer()
		await _sprites[battle.loser].fall()
	# conclude() may have refilled a loser's HP, which belongs to the board.
	if battle.winner != null:
		_refresh(battle.winner)
	_say(lines[0] if not lines.is_empty() else "", "  ".join(lines.slice(1)))
	for fighter: Fighter in levels:
		if fighter.player.level > levels[fighter]:
			Sound.play("level_up")
			_float_text("Level Up!", _sprites[fighter], GameArt.GOLD)
	await _wait(ENDING_PAUSE * 1.5)


## The level of each player fighting, to spot a level up after the fight.
func _levels_now() -> Dictionary:
	var levels := {}
	for fighter in _sprites:
		if fighter.player != null:
			levels[fighter] = fighter.player.level
	return levels


# A word on what the defense did, when it did something.
func _float_defense(outcome: Battle.Outcome, sprite: BattleSprite) -> void:
	if outcome.defense == Battle.Defense.NONE:
		return
	var share := Battle.share_of(outcome)
	if share > 1.0:
		_float_text("Broken!", sprite, GameArt.GOLD, DEFENSE_WORD_DROP)
	elif share < 1.0:
		_float_text("Held", sprite, MANA_COLOR, DEFENSE_WORD_DROP)


func _float_text(text: String, sprite: BattleSprite, color: Color, drop := 0.0) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", GameArt.INK)
	label.add_theme_constant_override("outline_size", 8)
	_arena.add_child(label)
	label.position = sprite.get_head_position() - label.get_combined_minimum_size() * 0.5 + Vector2(0, drop)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 36.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(label.queue_free)


func _shake_arena() -> void:
	if not Settings.screen_shake:
		return
	var tween := create_tween()
	var home := _arena.position
	for offset: float in [8.0, -6.0, 4.0, 0.0]:
		tween.tween_property(_arena, "position:x", home.x + offset, 0.04)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
