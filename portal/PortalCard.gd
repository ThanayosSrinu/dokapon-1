class_name PortalCard
extends PanelContainer
## What the Portal offers: where it leads, who is going, the food they carry and the one
## main button. It holds no rules: PortalScreen tells it what to show.

const WIDTH := 440.0
const PORTRAIT_SIZE := Vector2(112, 112)

var food: FoodDays
var enter: KitButton

var _picture: TextureRect
var _name: Label
var _about: Label
var _food_words: Label
var _portrait: TextureRect
var _person: Label
var _class: Label
var _die: Label


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
	var supplies := VBoxContainer.new()
	supplies.add_theme_constant_override("separation", 6)
	column.add_child(supplies)
	_food_words = Kit.text("", 0.0, &"PaperTitle")
	supplies.add_child(_food_words)
	food = FoodDays.new()
	supplies.add_child(food)
	_build_person(column)
	enter = KitButton.new()
	enter.kind = KitButton.Kind.PRIMARY
	enter.press_sound = "magic"
	column.add_child(enter)


func show_stage(stage: Stage) -> void:
	_picture.texture = stage.picture
	_name.text = stage.display_name
	_about.text = stage.description


## Shows who is going. With nobody, it says where to find someone instead.
func show_person(stage: Stage, person: Adventurer) -> void:
	var days := stage.food_days if person == null else stage.food_for(person)
	_food_words.text = "Food for %d days" % days
	var extra := 0 if person == null else person.bonus_food
	food.show_days(stage.food_days, extra)
	_portrait.visible = person != null
	if person == null:
		_person.text = "Nobody yet"
		_class.text = "Hire someone at the Tavern."
		_die.text = ""
		return
	_portrait.texture = person.portrait
	_person.text = person.display_name
	_class.text = "%s, level %d" % [person.class_data().display_name, person.level]
	_die.text = "Walks up to %d spaces a day" % person.die_top


func shown_food() -> String:
	return _food_words.text


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
