class_name BattleScreen
extends Control
## Shows a Battle and asks people for their moves. The rules stay in Battle.gd:
## this script only asks, calls resolve(), and plays what came back.
##     var lines: PackedStringArray = await battle_screen.run(battle)
## run() returns when the fight is over and its rewards are paid.
##
## The menu asks for a category, then a move, and skips the second step when the category
## holds only one. The attacker's choice is never shown until the defender has answered.

## Emitted by a choice button, with that choice's value.
signal _option_picked(value: Variant)

## The size of the arena, twice the size of the backdrop art.
const ARENA_SIZE := Vector2(720, 300)
const LEFT_HOME := Vector2(190, 236)
const RIGHT_HOME := Vector2(530, 236)
const PANEL_MARGIN := 10.0
## The arena's width, less the window's frame on both sides.
const LOG_SIZE := Vector2(ARENA_SIZE.x - 35.0, 72)
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
const SMALL_TEXT := 14
const SMALL_GAP := 20.0
## Where a word about the defense floats, against the damage number above it.
const DEFENSE_WORD_DROP := 34.0

const OFFENSE_ROW := [
	["Attack", Battle.Offense.ATTACK, "A safe hit. Only a Guard cuts it down."],
	["Smash", Battle.Offense.SMASH, "Breaks a Guard or a Ward. A Counter turns it back on you."],
	["Magic", Battle.Offense.MAGIC, "Uses MP. Only a Ward cuts it down."],
	["Special", Battle.Offense.SPECIAL, "Once a fight. Nothing can answer it."],
]
const DEFENSE_ROW := [
	["Guard", Battle.Defense.GUARD, "Cuts down an Attack. A Smash breaks through."],
	["Counter", Battle.Defense.COUNTER, "Turns a Smash back on them. Anything else lands."],
	["Ward", Battle.Defense.WARD, "Cuts down Magic. A Smash breaks through."],
]
const NO_MOVE := "You have no move for this yet."
const FLEE_HINT := "Run from the fight. Speed decides if you get away."
const BOOST_COLOR := Color(1.0, 0.8, 0.35)

var _battle: Battle
var _arena: Control
var _left_panel: BattlePanel
var _right_panel: BattlePanel
var _log: Label
var _hint: Label
var _choices: Container
var _flash: ColorRect
# Fighter -> its BattleSprite.
var _sprites := {}
# Fighter -> its BattlePanel.
var _panels := {}
# True while the row of choices has a Back button.
var _has_back := false


## Space left clear along the bottom and the right, for what stays on top. Set them before
## adding this.
var room_below := 0.0
var room_right := 0.0


func _ready() -> void:
	# Keeps clicks from reaching the board and buttons behind the window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -room_below
	center.offset_right = -room_right
	add_child(center)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	center.add_child(layout)

	_arena = Control.new()
	_arena.custom_minimum_size = ARENA_SIZE
	_arena.clip_contents = true
	layout.add_child(_arena)
	var backdrop := TextureRect.new()
	backdrop.texture = GameArt.BATTLE_BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.size = ARENA_SIZE
	_arena.add_child(backdrop)

	_left_panel = BattlePanel.new()
	_left_panel.position = Vector2(PANEL_MARGIN, PANEL_MARGIN)
	_arena.add_child(_left_panel)
	_right_panel = BattlePanel.new()
	_arena.add_child(_right_panel)

	var window := PanelContainer.new()
	layout.add_child(window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	window.add_child(box)
	_log = Label.new()
	_log.custom_minimum_size = LOG_SIZE
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_log)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", GameArt.GOLD)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.custom_minimum_size = Vector2(LOG_SIZE.x, 18)
	box.add_child(_hint)
	_choices = HBoxContainer.new()
	_choices.custom_minimum_size = Vector2(0, 40)
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 8)
	box.add_child(_choices)

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
	_hint.text = ""
	_add_fighter(_battle.challenger, LEFT_HOME, true, _left_panel)
	_add_fighter(_battle.opponent, RIGHT_HOME, false, _right_panel)
	# A PanelContainer's width is only known after the text has gone in.
	_right_panel.reset_size()
	_right_panel.position = Vector2(ARENA_SIZE.x - _right_panel.size.x - PANEL_MARGIN, PANEL_MARGIN)


func _add_fighter(fighter: Fighter, home: Vector2, facing_right: bool, panel: BattlePanel) -> void:
	var sprite := BattleSprite.new()
	_arena.add_child(sprite)
	sprite.setup(fighter, home, facing_right)
	panel.setup(fighter)
	_sprites[fighter] = sprite
	_panels[fighter] = panel


func _clear_fighters() -> void:
	for sprite: BattleSprite in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	_panels.clear()


# --- One action -------------------------------------------------------------

func _play_action() -> void:
	var attacker := _battle.attacker
	_log.text = "Round %d of %d: %s's move." % [_battle.round_number, Battle.MAX_ROUNDS, attacker.display_name]
	var choice := await _get_offense()
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
		if picked is String:
			var item_id: Variant = await _ask(_item_options())
			if item_id != BACK:
				return Battle.Choice.new(Battle.Offense.ITEM, item_id)
		elif picked == Battle.Offense.FLEE:
			return Battle.Choice.new(picked)
		else:
			var move_id: String = await _pick_move(attacker, Battle.OFFENSE_CATEGORIES[picked])
			if move_id != BACK:
				return Battle.Choice.new(picked, move_id)
	return null


func _get_defense() -> Dictionary:
	var defender := _battle.defender
	if defender.is_cpu():
		await _wait(CPU_PAUSE)
		return {"defense": _battle.cpu_defense(), "move": ""}
	_log.text = "%s, how will you answer %s?" % [defender.display_name, _battle.attacker.display_name]
	while true:
		var picked: Battle.Defense = await _ask(_defense_options())
		var move_id: String = await _pick_move(defender, Battle.DEFENSE_CATEGORIES[picked])
		if move_id != BACK:
			return {"defense": picked, "move": move_id}
	return {}


# The second step: which move of `category`, or BACK. With one move there's nothing to ask.
func _pick_move(fighter: Fighter, category: MoveData.Category) -> String:
	var moves := fighter.moves_in(category)
	if moves.size() == 1:
		return moves[0]
	var options: Array[Dictionary] = []
	for move_id in moves:
		var move := Database.get_move(move_id)
		var words := "%s %d MP" % [move.display_name, move.mp_cost] if move.mp_cost > 0 else move.display_name
		options.append(_option(words, move_id, move.description, not _battle.can_use(fighter, move_id)))
	options.append(_option("Back", BACK, ""))
	return await _ask(options)


func _offense_options() -> Array[Dictionary]:
	var attacker := _battle.attacker
	var options: Array[Dictionary] = []
	for entry: Array in OFFENSE_ROW:
		options.append(_category_option(attacker, entry, Battle.OFFENSE_CATEGORIES[entry[1]]))
	options.append(_option("Item", ITEM_MENU, "Use something from the bag.", attacker.get_items().is_empty(), true))
	var chance := _battle.flee_chance(attacker, _battle.defender)
	options.append(_option("Flee", Battle.Offense.FLEE, "%s %d%% chance." % [FLEE_HINT, roundi(chance * 100.0)], false, true))
	return options


func _defense_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for entry: Array in DEFENSE_ROW:
		options.append(_category_option(_battle.defender, entry, Battle.DEFENSE_CATEGORIES[entry[1]]))
	return options


# One button of a row: `entry` is its name, value and hint. A category with one move names it.
func _category_option(fighter: Fighter, entry: Array, category: MoveData.Category) -> Dictionary:
	var moves := fighter.moves_in(category)
	if moves.is_empty():
		return _option(entry[0], entry[1], NO_MOVE, true)
	var hint: String = entry[2]
	if moves.size() == 1:
		var move := Database.get_move(moves[0])
		var cost := " %d MP." % move.mp_cost if move.mp_cost > 0 else ""
		hint = "%s.%s %s" % [move.display_name, cost, hint]
	return _option(entry[0], entry[1], hint, _battle.usable_moves(fighter, category).is_empty())


func _item_options() -> Array[Dictionary]:
	var attacker := _battle.attacker
	var options: Array[Dictionary] = []
	for item_id in attacker.get_items():
		var item := Database.get_item(item_id)
		options.append(_option(item.display_name, item_id, item.description,
				not attacker.player.can_use_item(item_id)))
	options.append(_option("Back", BACK, ""))
	return options


func _option(text: String, value: Variant, hint: String, disabled := false, small := false) -> Dictionary:
	return {"text": text, "value": value, "hint": hint, "disabled": disabled, "small": small}


# Esc or the B button steps back, when the row offers it, before the trip hears it.
func _input(event: InputEvent) -> void:
	if not _has_back or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_option_picked.emit(BACK)


## Shows one button per option and waits for a press. Returns that option's value.
func _ask(options: Array[Dictionary]) -> Variant:
	_clear_choices()
	var first_enabled: Button
	var gap_made := false
	for option in options:
		if option["small"] and not gap_made:
			gap_made = true
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(SMALL_GAP, 0)
			_choices.add_child(gap)
		var button := Button.new()
		button.text = option["text"]
		if option["small"]:
			button.add_theme_font_size_override("font_size", SMALL_TEXT)
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.disabled = option["disabled"]
		button.pressed.connect(func() -> void: _option_picked.emit(option["value"]))
		var show_hint := func() -> void: _hint.text = option["hint"]
		button.focus_entered.connect(show_hint)
		button.mouse_entered.connect(show_hint)
		_choices.add_child(button)
		if first_enabled == null and not option["disabled"]:
			first_enabled = button
	_keep_focus_on_row()
	first_enabled.grab_focus()
	_has_back = options.any(func(option: Dictionary) -> bool: return option["value"] is String and option["value"] == BACK)
	var picked: Variant = await _option_picked
	_has_back = false
	_clear_choices()
	_hint.text = ""
	return picked


# Focus stays on the row, so a stray key can't wander off to what stands around the fight.
func _keep_focus_on_row() -> void:
	var buttons := _choices.get_children().filter(func(child: Node) -> bool: return child is Button)
	for button: Button in buttons:
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)
	var first: Button = buttons[0]
	var last: Button = buttons[-1]
	first.focus_neighbor_left = first.get_path_to(first)
	last.focus_neighbor_right = last.get_path_to(last)


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
		_log.text = "%s appears!\n%s" % [opponent.display_name, opponent.monster.description]
	else:
		_log.text = "%s challenges %s!" % [_battle.challenger.display_name, opponent.display_name]
	await _wait(ENDING_PAUSE)


func _play_outcome(outcome: Battle.Outcome) -> void:
	_log.text = outcome.opening
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
		Battle.Offense.MAGIC:
			Sound.play("magic")
			await attacker.cast()
			BoardFx.burst(_arena, defender.position + Vector2(0, -24), MANA_COLOR)
			await _play_hit(outcome, attacker, defender)
		Battle.Offense.SPECIAL:
			await _play_special(outcome, attacker, defender)
		Battle.Offense.SMASH:
			await attacker.wind_up()
			await attacker.lunge(defender.position)
			await _play_hit(outcome, attacker, defender)
			await attacker.go_home()
		_:
			await attacker.lunge(defender.position)
			await _play_hit(outcome, attacker, defender)
			await attacker.go_home()
	_panels[outcome.attacker].refresh()
	if outcome.result != "":
		_log.text = "%s\n%s" % [outcome.opening, outcome.result]
	await _wait(READ_PAUSE)


func _play_special(outcome: Battle.Outcome, attacker: BattleSprite, defender: BattleSprite) -> void:
	match outcome.move.effect:
		MoveData.Effect.HEAL:
			Sound.play("magic")
			await attacker.cast()
			await _play_recovery(outcome, attacker)
		MoveData.Effect.BOOST:
			Sound.play("magic")
			await attacker.cast()
			BoardFx.burst(_arena, attacker.position + Vector2(0, -24), BOOST_COLOR, 8)
			_float_text("Up!", attacker, BOOST_COLOR)
			_panels[outcome.attacker].refresh()
			await _wait(0.4)
		_:
			await attacker.lunge(defender.position)
			await _play_hit(outcome, attacker, defender)
			await attacker.go_home()


func _play_recovery(outcome: Battle.Outcome, sprite: BattleSprite) -> void:
	Sound.play("heal")
	BoardFx.burst(_arena, sprite.position + Vector2(0, -24), HEAL_COLOR, 8)
	if outcome.healed > 0:
		_float_text("+%d" % outcome.healed, sprite, HEAL_COLOR)
	elif outcome.mana_restored > 0:
		_float_text("+%d" % outcome.mana_restored, sprite, MANA_COLOR)
	_panels[outcome.attacker].refresh()
	await _wait(0.4)


func _play_hit(outcome: Battle.Outcome, attacker: BattleSprite, defender: BattleSprite) -> void:
	if outcome.reflected > 0:
		Sound.play("counter")
		_float_text("Counter!", defender, GameArt.GOLD)
		_float_text("%d" % outcome.reflected, attacker, HIT_COLOR)
		_panels[outcome.attacker].refresh()
		await attacker.hurt()
	else:
		var held := Battle.hit_share(outcome.offense, outcome.defense) < 1.0
		Sound.play("miss" if held else "hit")
		if not held:
			_shake_arena()
		_float_text("%d" % outcome.damage, defender, HIT_COLOR)
		_float_defense(outcome, defender)
		_panels[outcome.defender].refresh()
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
		_panels[battle.winner].refresh()
	_log.text = "  ".join(lines)
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
	var share := Battle.hit_share(outcome.offense, outcome.defense)
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
