class_name DateChip
extends PanelContainer
## The date: a season's picture, then the year, month and week. It turns yellow and then
## red as a due day comes close, and showing it counts as warning the player.

const YELLOW := Kit.GOLD
const RED := Color(1.0, 0.45, 0.42)
const TINT := {TownData.Alert.NONE: Color.WHITE, TownData.Alert.WARN: Color(1.0, 0.9, 0.55),
		TownData.Alert.ALARM: Color(1.0, 0.55, 0.5)}

## The Alert it shows.
var level := TownData.Alert.NONE

var _picture: TextureRect
var _label: Label
var _with_day := false


## With `with_day`, it adds the day of the week, for the trip strip.
func _init(with_day := false) -> void:
	theme_type_variation = &"Chip"
	_with_day = with_day
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_picture = Kit.picture(Calendar.SEASONS[0])
	row.add_child(_picture)
	_label = Kit.text("")
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	Kit.draw_focus(self)


## Shows `day`, with what the town owes then.
func show_day(town: TownData, day: int) -> void:
	level = town.show_alert(day)
	_picture.texture = Kit.icon(Calendar.season(day))
	_label.text = Calendar.long(day) if _with_day else Calendar.short(day)
	_label.modulate = {TownData.Alert.NONE: Color.WHITE, TownData.Alert.WARN: YELLOW,
			TownData.Alert.ALARM: RED}[level]
	self_modulate = TINT[level]
	Tips.attach(self, "Day %d" % day, tip_for(town, day))


func shown_words() -> String:
	return _label.text


## What is owed next, in words, as seen from `day`.
static func tip_for(town: TownData, day: int) -> String:
	var debt := town.next_debt()
	var left: int = debt["due"] - day
	var when := "today" if left == 0 else "in %s" % TownData.days_words(left)
	if left < 0:
		when = "%s ago" % TownData.days_words(-left)
	return "%s of %s. The %s of %d gold is due on Day %d, %s." % [
			Calendar.season(day).capitalize(), "Year %d" % Calendar.year(day),
			debt["what"], debt["amount"], debt["due"], when]
