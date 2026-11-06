class_name BattleScreen
extends Control
## Shows a Battle and asks people for their moves. The rules stay in Battle.gd:
## this script only asks, calls resolve(), and plays what came back.
##     var lines: PackedStringArray = await battle_screen.run(battle)
## run() returns when the fight is over and its rewards are paid.
##
## The attacker's choice is never shown until the defender has answered, so two
## people can share one screen.

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
const MAGIC_MENU := "magic"
const ITEM_MENU := "item"

const OFFENSE_HINTS := {
	Battle.Offense.ATTACK: "A safe hit. Beats Counter, but a Guard halves it.",
	Battle.Offense.SMASH: "A heavy hit. Breaks Guard, but a Counter turns it back on you.",
	Battle.Offense.FLEE: "Run from the fight. Speed decides if you get away.",
}
const DEFENSE_HINTS := {
	Battle.Defense.GUARD: "Halves an Attack, cuts a Spell. A Smash breaks through for more.",
	Battle.Defense.COUNTER: "Turns a Smash back on the attacker. Anything else hits harder.",
}

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


## Space left clear along the bottom, for a strip that stays on top. Set it before adding this.
var room_below := 0.0


func _ready() -> void:
	# Keeps clicks from reaching the board and buttons behind the window.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -room_below
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
	var defense := Battle.Defense.NONE
	if _battle.needs_defense(choice):
		defense = await _get_defense()
	var outcome := _battle.resolve(choice, defense)
	await _play_outcome(outcome)


func _get_offense() -> Battle.Choice:
	var attacker := _battle.attacker
	if attacker.is_cpu():
		await _wait(CPU_PAUSE)
		return _battle.cpu_offense()
	while true:
		var picked: Variant = await _ask(_offense_options())
		if picked is Battle.Offense:
			return Battle.Choice.new(picked)
		var submenu: Array[Dictionary] = _magic_options() if picked == MAGIC_MENU else _item_options()
		var detail: Variant = await _ask(submenu)
		if detail != BACK:
			var offense := Battle.Offense.SPELL if picked == MAGIC_MENU else Battle.Offense.ITEM
			return Battle.Choice.new(offense, detail)
	return null


func _get_defense() -> Battle.Defense:
	var defender := _battle.defender
	if defender.is_cpu():
		await _wait(CPU_PAUSE)
		return _battle.cpu_defense()
	_log.text = "%s, how will you defend against %s?" % [defender.display_name, _battle.attacker.display_name]
	return await _ask(_defense_options())


func _offense_options() -> Array[Dictionary]:
	var attacker := _battle.attacker
	var options: Array[Dictionary] = [
		_option("Attack", Battle.Offense.ATTACK, OFFENSE_HINTS[Battle.Offense.ATTACK]),
		_option("Smash", Battle.Offense.SMASH, OFFENSE_HINTS[Battle.Offense.SMASH]),
		_option("Magic", MAGIC_MENU, "Cast a spell. Spells cannot be countered.",
				attacker.get_spells().is_empty()),
		_option("Item", ITEM_MENU, "Use a healing item from the bag.", attacker.get_items().is_empty()),
	]
	var chance := _battle.flee_chance(attacker, _battle.defender)
	options.append(_option("Flee", Battle.Offense.FLEE, "%s %d%% chance." % [
			OFFENSE_HINTS[Battle.Offense.FLEE], roundi(chance * 100.0)]))
	return options


func _magic_options() -> Array[Dictionary]:
	var attacker := _battle.attacker
	var options: Array[Dictionary] = []
	for spell_id in attacker.get_spells():
		var spell := Database.get_spell(spell_id)
		options.append(_option("%s %d MP" % [spell.display_name, spell.mp_cost], spell_id,
				spell.description, not _battle.can_cast(attacker, spell_id)))
	options.append(_option("Back", BACK, ""))
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


func _defense_options() -> Array[Dictionary]:
	var defender := _battle.defender
	var chance := _battle.dodge_chance(defender, _battle.attacker, Battle.Offense.ATTACK)
	return [
		_option("Guard", Battle.Defense.GUARD, DEFENSE_HINTS[Battle.Defense.GUARD]),
		_option("Dodge", Battle.Defense.DODGE, "%d%% to avoid it all, better against a Smash. Failing hurts." % roundi(chance * 100.0)),
		_option("Counter", Battle.Defense.COUNTER, DEFENSE_HINTS[Battle.Defense.COUNTER]),
	]


func _option(text: String, value: Variant, hint: String, disabled := false) -> Dictionary:
	return {"text": text, "value": value, "hint": hint, "disabled": disabled}


## Shows one button per option and waits for a press. Returns that option's value.
func _ask(options: Array[Dictionary]) -> Variant:
	_clear_choices()
	var first_enabled: Button
	for option in options:
		var button := Button.new()
		button.text = option["text"]
		button.disabled = option["disabled"]
		button.pressed.connect(func() -> void: _option_picked.emit(option["value"]))
		var show_hint := func() -> void: _hint.text = option["hint"]
		button.focus_entered.connect(show_hint)
		button.mouse_entered.connect(show_hint)
		_choices.add_child(button)
		if first_enabled == null and not option["disabled"]:
			first_enabled = button
	first_enabled.grab_focus()
	var picked: Variant = await _option_picked
	_clear_choices()
	_hint.text = ""
	return picked


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
		Battle.Offense.SPELL:
			Sound.play("magic")
			await attacker.cast()
			if outcome.healed > 0:
				await _play_recovery(outcome, attacker)
			else:
				BoardFx.burst(_arena, defender.position + Vector2(0, -24), MANA_COLOR)
				await _play_hit(outcome, attacker, defender)
		_:
			await attacker.lunge(defender.position)
			await _play_hit(outcome, attacker, defender)
			await attacker.go_home()
	if outcome.result != "":
		_log.text = "%s\n%s" % [outcome.opening, outcome.result]
	await _wait(READ_PAUSE)


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
	if outcome.dodged:
		Sound.play("miss")
		_float_text("Miss", defender, GameArt.PARCHMENT)
		await defender.sidestep()
	elif outcome.reflected > 0:
		Sound.play("counter")
		_float_text("Counter!", defender, GameArt.GOLD)
		_float_text("%d" % outcome.reflected, attacker, HIT_COLOR)
		_panels[outcome.attacker].refresh()
		await attacker.hurt()
	else:
		Sound.play("hit")
		_shake_arena()
		_float_text("%d" % outcome.damage, defender, HIT_COLOR)
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


func _float_text(text: String, sprite: BattleSprite, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", GameArt.INK)
	label.add_theme_constant_override("outline_size", 8)
	_arena.add_child(label)
	label.position = sprite.get_head_position() - label.get_combined_minimum_size() * 0.5
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
