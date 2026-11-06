class_name TripWarning
extends KitPanel
## Stops the player at the Portal when a trip may not be home before the next due day,
## and says what is owed, when, and when they would be back.

signal go_on
signal to_bank

const WIDTH := 520.0
const HEADING := "Home in time?"
const SOON := "%s can be home about %s if called back early, or %s if all the food is used."
const TOO_LATE := "%s can't be home before about %s, or %s if all the food is used."
const LOST := "If it is not paid by then, it is GAME OVER."

var go_button: KitButton
var bank_button: KitButton

var _owed: Label
var _home: Label


func _init() -> void:
	super(HEADING, true)
	custom_minimum_size.x = WIDTH
	_owed = _line()
	_home = _line()
	var lost := _line()
	lost.text = LOST
	lost.add_theme_color_override("font_color", Kit.BLOOD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	go_button = _button("Go on", row)
	go_button.pressed.connect(func() -> void: go_on.emit())
	bank_button = _button("Go to the Bank", row)
	bank_button.pressed.connect(func() -> void: to_bank.emit())
	_link(go_button, bank_button)
	_link(bank_button, go_button)


func _line() -> Label:
	var words := Kit.text("", WIDTH - 32.0, &"PaperLabel")
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(words)
	return words


func _button(words: String, row: HBoxContainer) -> KitButton:
	var button := KitButton.new()
	button.text = words
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	return button


# The arrows and Tab stay on the two buttons while this is open.
func _link(button: KitButton, other: KitButton) -> void:
	var path := button.get_path_to(other)
	var stay := button.get_path_to(button)
	button.focus_neighbor_left = path
	button.focus_neighbor_right = path
	button.focus_next = path
	button.focus_previous = path
	button.focus_neighbor_top = stay
	button.focus_neighbor_bottom = stay


## Shows what `plan`, from TownData.forecast, means for `person`.
func show_trip(town: TownData, person: Adventurer, plan: Dictionary) -> void:
	var debt := town.next_debt()
	var left: int = debt["due"] - town.day
	var when := "today" if left == 0 else "in %s" % TownData.days_words(left)
	_owed.text = "The %s of %d gold is due on %s, %s." % [debt["what"], debt["amount"], Calendar.date(debt["due"]), when]
	var words := TOO_LATE if plan["fit"] == TownData.Forecast.LATE else SOON
	_home.text = words % [person.display_name, Calendar.date(plan["home"]), Calendar.date(plan["whole"])]


func shown_words() -> String:
	return "%s %s" % [_owed.text, _home.text]
