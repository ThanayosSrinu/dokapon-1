class_name TavernCard
extends PanelContainer
## The card of one adventurer. It never moves or changes size, whoever it shows, so
## that moving between people compares them: only the bars and the die change (rule U3).

const WIDTH := 440.0
const PORTRAIT_SIZE := Vector2(112, 112)
const BAR_GAP := 6.0
## What a full bar means. The strongest adventurer in the game so far is below these.
const FULL_STRENGTH := 20.0
const FULL_HEALTH := 60.0
const FULL_MAGIC := 20.0

var strength_bar: KitBar
var health_bar: KitBar
var magic_bar: KitBar
var die: DieRuler
var hire: KitButton

var _portrait: TextureRect
var _name: Label
var _class: Label
var _about: Label
## The four lines of facts, which mean different things for strangers and your people.
var _facts: Array[Label] = []
var _fact_icons: Array[TextureRect] = []


func _init() -> void:
	theme_type_variation = &"PaperPanel"
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_build_top(column)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", int(BAR_GAP))
	column.add_child(bars)
	strength_bar = _add_bar(bars, Kit.DANGER, "sword")
	health_bar = _add_bar(bars, Kit.HEALTH, "heart")
	magic_bar = _add_bar(bars, Kit.MAGIC, "star")
	die = DieRuler.new()
	bars.add_child(die)
	for icon_name: String in ["food", "coin", "coin", "sword"]:
		_add_fact(column, icon_name)
	hire = KitButton.new()
	hire.kind = KitButton.Kind.PRIMARY
	hire.press_sound = "coin"
	column.add_child(hire)


## Fills the card with a stranger, sliding the bars from the last person's numbers.
func show_recruit(person: Adventurer) -> void:
	_show_person(person)
	_set_fact(0, "food", "Brings food for %s more" % Expedition.turns_words(person.bonus_food) if person.bonus_food > 0 else "Brings no extra food")
	_set_fact(1, "coin", "Asks for %d gold to join" % person.fee)
	_set_fact(2, "coin", "Wage: %d gold a month" % person.wage)
	_set_fact(3, "sword", "Gear: %s" % _gear(person))


## Fills the card with someone on the roster.
func show_member(one: Member, today: int) -> void:
	var person := one.person
	_show_person(person)
	var out := one.days_out(today)
	_set_fact(0, "heart", "Ready to go" if out == 0 else "Hurt, back in %s" % TownData.days_words(out))
	_set_fact(1, "coin", "Wage: %d gold a month" % person.wage)
	_set_fact(2, "boot", _past_trips(one))
	_set_fact(3, "sword", "Gear: %s" % _gear(person))


## What the first line of facts says.
func shown_status() -> String:
	return _facts[0].text


func _show_person(person: Adventurer) -> void:
	_portrait.texture = person.portrait
	_name.text = person.display_name
	_class.text = "%s, level %d" % [person.class_data().display_name, person.level]
	_about.text = person.description
	_fill_bar(strength_bar, person.stat("attack"), FULL_STRENGTH, "Strength", "How hard they hit.")
	_fill_bar(health_bar, person.stat("max_hp"), FULL_HEALTH, "Health", "How much they can take.")
	_fill_bar(magic_bar, person.stat("magic"), FULL_MAGIC, "Magic", "How strong their spells are.")
	die.top = person.die_top
	Tips.attach(die, "Movement die", "Rolls 0 to %d each day. A higher roll walks further." % person.die_top)


func _past_trips(one: Member) -> String:
	if one.trips == 0:
		return "No trips yet"
	var trips := "1 trip" if one.trips == 1 else "%d trips" % one.trips
	return "%s, %d home, %d gold" % [trips, one.trips_home, one.gold_home]


func _gear(person: Adventurer) -> String:
	var names := PackedStringArray()
	for id in person.class_data().starting_equipment:
		names.append(Database.get_item(id).display_name)
	return ", ".join(names) if not names.is_empty() else "nothing"


func _set_fact(index: int, icon_name: String, words: String) -> void:
	_fact_icons[index].texture = Kit.icon(icon_name)
	_facts[index].text = words


## The parts that can take focus, from the top down.
func details() -> Array[Control]:
	return [strength_bar, health_bar, magic_bar, die]


func shown_name() -> String:
	return _name.text


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
	row.add_child(words)
	_name = Kit.text("", 0.0, &"PaperHeading")
	words.add_child(_name)
	_class = Kit.text("", 0.0, &"PaperTitle")
	words.add_child(_class)
	_about = Kit.text("", 0.0, &"PaperLabel")
	words.add_child(_about)


func _add_bar(parent: Container, color: Color, icon_name: String) -> KitBar:
	var bar := KitBar.new(color, Kit.icon(icon_name))
	bar.width = WIDTH - 40.0
	bar.focus_mode = Control.FOCUS_ALL
	parent.add_child(bar)
	return bar


func _add_fact(parent: Container, icon_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var picture := Kit.picture(icon_name)
	row.add_child(picture)
	_fact_icons.append(picture)
	var words := Kit.text("", 0.0, &"PaperLabel")
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	_facts.append(words)


func _fill_bar(bar: KitBar, amount: int, full: float, title: String, job: String) -> void:
	bar.set_amount(amount, full)
	Tips.attach(bar, title, "%d. %s" % [amount, job])
