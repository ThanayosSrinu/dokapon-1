class_name PortalCard
extends PanelContainer
## What the Portal offers, in the order it is chosen: who is going, how big a trip, how much
## food, and the one main button. It holds no rules: PortalScreen tells it what to show.

const WIDTH := 440.0
const PORTRAIT_SIZE := Vector2(112, 112)

var food: FoodPicker
var enter: KitButton
## One button for each size of trip, the shortest first.
var sizes: Array[KitButton] = []
## One button for each person on the roster, with room for more than one.
var people: Array[KitButton] = []

var _picture: TextureRect
var _name: Label
var _about: Label
var _food_words: Label
var _food_cost: Label
var _food_warning: Label
var _portrait: TextureRect
var _person: Label
var _class: Label
var _die: Label
var _size_row: HBoxContainer
var _forecast_row: HBoxContainer
var _forecasts: Array[Label] = []
var _people_row: HBoxContainer


func _init() -> void:
	theme_type_variation = &"PaperPanel"
	custom_minimum_size.x = WIDTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	_picture = TextureRect.new()
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	column.add_child(_picture)
	var place := VBoxContainer.new()
	place.add_theme_constant_override("separation", 2)
	column.add_child(place)
	_name = Kit.text("", 0.0, &"PaperHeading")
	place.add_child(_name)
	_about = Kit.text("", 0.0, &"PaperLabel")
	place.add_child(_about)
	_build_person(column)
	_size_row = HBoxContainer.new()
	_size_row.add_theme_constant_override("separation", 8)
	var sizes_and_days := VBoxContainer.new()
	sizes_and_days.add_theme_constant_override("separation", 4)
	column.add_child(sizes_and_days)
	sizes_and_days.add_child(_size_row)
	_forecast_row = HBoxContainer.new()
	_forecast_row.add_theme_constant_override("separation", 8)
	sizes_and_days.add_child(_forecast_row)
	var supplies := VBoxContainer.new()
	supplies.add_theme_constant_override("separation", 4)
	column.add_child(supplies)
	var food_row := HBoxContainer.new()
	supplies.add_child(food_row)
	_food_words = Kit.text("", 0.0, &"PaperTitle")
	_food_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_row.add_child(_food_words)
	_food_cost = Kit.text("", 0.0, &"PaperLabel")
	food_row.add_child(_food_cost)
	food = FoodPicker.new()
	supplies.add_child(food)
	_food_warning = Kit.text("", 0.0, &"PaperLabel")
	_food_warning.add_theme_color_override("font_color", Kit.BLOOD)
	supplies.add_child(_food_warning)
	enter = KitButton.new()
	enter.kind = KitButton.Kind.PRIMARY
	enter.press_sound = "magic"
	column.add_child(enter)


## Makes a button for each of `stages`, which PortalScreen then connects.
func build_sizes(stages: Array[Stage]) -> void:
	for stage in stages:
		var button := KitButton.new()
		button.kind = KitButton.Kind.SMALL
		button.text = stage.size_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_size_row.add_child(button)
		sizes.append(button)
		var words := Kit.text("", 0.0, &"PaperLabel")
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_stretch_ratio = 1.0
		_forecast_row.add_child(words)
		_forecasts.append(words)


## Makes a button for each of `names`, which PortalScreen then connects.
func build_people(names: Array[String]) -> void:
	for person_name in names:
		var button := KitButton.new()
		button.kind = KitButton.Kind.SMALL
		button.text = person_name
		_people_row.add_child(button)
		people.append(button)
	_die.visible = people.is_empty()


## Lights the button of who is going.
func mark_person(index: int) -> void:
	for place in people.size():
		people[place].lit = place == index


## Shows when a trip of size `index` could be back, or nothing with "".
func show_forecast(index: int, words: String, color: Color) -> void:
	_forecasts[index].text = words
	_forecasts[index].add_theme_color_override("font_color", color)


func shown_forecast(index: int) -> String:
	return _forecasts[index].text


## Lights the button of the size in use.
func mark_size(index: int) -> void:
	for place in sizes.size():
		sizes[place].lit = place == index


func show_stage(stage: Stage) -> void:
	_picture.texture = stage.picture
	_name.text = stage.display_name
	_about.text = stage.description


## Shows the food: how much is bought, what that costs of what the town has, and how much
## could be. A `warning` shows in red, and "" clears it.
func show_food(amount: int, carry: int, afford: int, cost: int, gold: int, warning: String) -> void:
	_food_words.text = "Food for %s" % Expedition.turns_words(amount)
	_food_cost.text = "%d of your %d gold" % [cost, gold]
	_food_warning.text = warning
	food.show_food(amount, carry, afford)


## Shows who is going. With nobody, it says where to find someone instead.
## Shows who is going. `level` is theirs now, which trips may have raised.
func show_person(person: Adventurer, level := 1) -> void:
	_portrait.visible = person != null
	if person == null:
		_person.text = "Nobody yet"
		_class.text = "Hire someone at the Tavern."
		_die.text = ""
		return
	_portrait.texture = person.portrait
	_person.text = person.display_name
	_class.text = "%s, level %d" % [person.class_data().display_name, level]
	_die.text = "Walks up to %d spaces a day" % person.die_top


func shown_food() -> String:
	return _food_words.text


func shown_food_cost() -> String:
	return _food_cost.text


func shown_food_warning() -> String:
	return _food_warning.text


func shown_person() -> String:
	return _person.text


func _build_person(parent: Container) -> void:
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
	_person = Kit.text("", 0.0, &"PaperHeading")
	words.add_child(_person)
	_class = Kit.text("", 0.0, &"PaperTitle")
	words.add_child(_class)
	_die = Kit.text("", 0.0, &"PaperLabel")
	words.add_child(_die)
	_people_row = HBoxContainer.new()
	_people_row.add_theme_constant_override("separation", 6)
	words.add_child(_people_row)
