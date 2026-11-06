class_name RestPanel
extends KitPanel
## Passing days on purpose, so that the hurt can heal. Time stands still in town until
## this is used, and each day brings the next bill closer.

signal rest_chosen(days: int)
signal closed

const WIDTH := 480.0
const DAYS: Array[int] = [1, 3, 7]
const HEADING := "Rest in the castle"

## One for each of DAYS.
var day_buttons: Array[KitButton] = []
var close_button: KitButton

var _words: Label
var _warning: Label


func _init() -> void:
	super(HEADING, true)
	custom_minimum_size.x = WIDTH
	_words = Kit.text("", WIDTH - 32.0, &"PaperLabel")
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_words)
	_warning = Kit.text("", WIDTH - 32.0, &"PaperLabel")
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.add_theme_color_override("font_color", Kit.BLOOD)
	body.add_child(_warning)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	for days in DAYS:
		var button := KitButton.new()
		button.text = TownData.days_words(days)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: rest_chosen.emit(days))
		row.add_child(button)
		day_buttons.append(button)
	close_button = KitButton.new()
	close_button.kind = KitButton.Kind.SMALL
	close_button.text = "Done"
	close_button.pressed.connect(func() -> void: closed.emit())
	body.add_child(close_button)
	for index in day_buttons.size():
		var button := day_buttons[index]
		button.focus_neighbor_left = button.get_path_to(day_buttons[maxi(index - 1, 0)])
		button.focus_neighbor_right = button.get_path_to(day_buttons[mini(index + 1, day_buttons.size() - 1)])
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(close_button)
	close_button.focus_neighbor_top = close_button.get_path_to(day_buttons[0])
	close_button.focus_neighbor_bottom = close_button.get_path_to(close_button)


## Shows what resting means today.
func show_town(town: TownData) -> void:
	var debt := town.next_debt()
	var left: int = debt["due"] - town.day
	var words := "The %s of %d gold is due " % [debt["what"], debt["amount"]]
	words += "today." if left == 0 else "in %s." % TownData.days_words(left)
	var waiting := town.days_until_ready()
	if waiting > 0:
		words += " Someone can work again in %s." % TownData.days_words(waiting)
	_words.text = words
	var fatal := false
	for index in DAYS.size():
		var too_far: bool = town.day + DAYS[index] > debt["due"]
		day_buttons[index].danger = too_far
		fatal = fatal or too_far
	_warning.text = "A red choice goes past the due day, and the town is lost." if fatal else ""
	_warning.visible = fatal
