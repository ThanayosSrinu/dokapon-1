class_name TavernCard
extends PanelContainer
## The card of one adventurer. It never moves or changes size, whoever it shows, so
## that moving between people compares them: only the numbers and the die change.
## The numbers are the ones a trip that starts now would use (HeroFacts).

const WIDTH := 440.0
const PORTRAIT_SIZE := Vector2(112, 112)
## Looking for work, for someone not on the roster.
const LOOKING := "Looking for work"

## Stat name -> its HeroStat.
var stats := {}
var die: DieRuler
## Opens the details page.
var more: KitButton
var hire: KitButton

var _portrait: TextureRect
var _name: Label
var _class: Label
var _traits: Label
## The three lines of facts: food, money and status.
var _facts: Array[Label] = []
var _fact_icons: Array[TextureRect] = []
var _fact_rows: Array[Control] = []


func _init() -> void:
	theme_type_variation = &"PaperPanel"
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_build_top(column)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	column.add_child(grid)
	for stat in HeroFacts.STATS:
		var cell := HeroStat.new(stat)
		grid.add_child(cell)
		stats[stat] = cell
	die = DieRuler.new()
	column.add_child(die)
	for icon_name: String in ["food", "coin", "heart"]:
		_add_fact(column, icon_name)
	hire = KitButton.new()
	hire.kind = KitButton.Kind.PRIMARY
	hire.press_sound = "coin"
	column.add_child(hire)


## Fills the card with a stranger.
func show_recruit(person: Adventurer) -> void:
	_show_person(person, null)
	_set_fact(1, "coin", "Joins for %d gold, then %d a month" % [person.fee, person.wage],
			"Money", "%d gold to hire them, then a wage of %d gold a month on the King's bill." % [person.fee, person.wage])
	_set_fact(2, "heart", LOOKING, "Status", "Not on your roster. Hire them to send them out.")


## Fills the card with someone on the roster.
func show_member(one: Member, today: int) -> void:
	var person := one.person
	_show_person(person, one)
	_set_fact(1, "coin", "Wage: %d gold a month" % person.wage, "Wage",
			"%d gold a month, paid with the King's bill." % person.wage)
	var out := one.days_out(today)
	if out == 0:
		_set_fact(2, "heart", "Ready to go", "Status", "They can go on a trip today.")
	else:
		_set_fact(2, "heart", "Down, back in %s" % TownData.days_words(out), "Status",
				"Beaten on their last trip. They rest until they can go again.")


## What the status line says.
func shown_status() -> String:
	return _facts[2].text


func _show_person(person: Adventurer, one: Member) -> void:
	var made := HeroFacts.sheet(person, one)
	_portrait.texture = person.portrait
	_name.text = person.display_name
	_class.text = "%s, level %d" % [person.class_data().display_name, made.level]
	var names := HeroFacts.trait_names(person)
	_traits.text = names if names != "" else person.description
	Tips.attach(_traits, "Traits" if names != "" else "", HeroFacts.trait_lines(person) if names != "" else person.description)
	for stat: String in stats:
		var cell: HeroStat = stats[stat]
		cell.show_value(made.get_stat(stat), HeroFacts.growth_words(person, stat))
		Tips.attach(cell, ItemData.STAT_NAMES[stat], HeroFacts.stat_tip(person, made, stat))
	die.top = person.die_top
	Tips.attach(die, "Movement die", "Rolls 0 to %d each day. A higher roll walks further." % person.die_top)
	var food := HeroFacts.food(person, one)
	_set_fact(0, "food", "Carries food for %s" % Expedition.turns_words(food), "Max Food",
			"The most days of food they can take on a trip. Each level adds %d." % Adventurer.FOOD_PER_LEVEL)


func _set_fact(index: int, icon_name: String, words: String, title: String, tip: String) -> void:
	_fact_icons[index].texture = Kit.icon(icon_name)
	_facts[index].text = words
	Tips.attach(_fact_rows[index], title, tip)


## The parts that can take focus, from the top down, above Hire.
func details() -> Array[Control]:
	var parts: Array[Control] = [more]
	for stat in HeroFacts.STATS:
		parts.append(stats[stat])
	parts.append(die)
	parts.append_array(_fact_rows)
	return parts


func shown_name() -> String:
	return _name.text


func shown_traits() -> String:
	return _traits.text


func shown_food() -> String:
	return _facts[0].text


func _build_top(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(_portrait)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	_name = Kit.text("", 0.0, &"PaperHeading")
	words.add_child(_name)
	_class = Kit.text("", 0.0, &"PaperTitle")
	words.add_child(_class)
	_traits = Kit.text("", 0.0, &"PaperLabel")
	_traits.mouse_filter = Control.MOUSE_FILTER_STOP
	words.add_child(_traits)
	more = KitButton.new()
	more.kind = KitButton.Kind.SMALL
	more.text = "Details"
	more.icon = Kit.icon("book")
	more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	words.add_child(more)
	Tips.attach(more, "Details", "Everything about them: stats, gear, moves, traits and history. Key C, or the controller's Y.")


func _add_fact(parent: Container, icon_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.focus_mode = Control.FOCUS_ALL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.draw.connect(Kit.draw_focus.bind(row))
	row.focus_entered.connect(row.queue_redraw)
	row.focus_exited.connect(row.queue_redraw)
	parent.add_child(row)
	var picture := Kit.picture(icon_name)
	row.add_child(picture)
	_fact_icons.append(picture)
	var words := Kit.text("", 0.0, &"PaperLabel")
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	_facts.append(words)
	_fact_rows.append(row)
