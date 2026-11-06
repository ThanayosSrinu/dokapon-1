class_name FoodDays
extends Control
## A picture of the food for a trip: one mark for each day, so that a long trip looks long
## (rule U3). The days an adventurer brings have their own color. Tips.attach() adds words.

const MARK := Vector2(10, 22)
const GAP := 4.0
const ICON_GAP := 8.0
## Room for the longest trip the plan expects, 21 days and a few more.
const MOST_DAYS := 25
const TRIP_COLOR := Kit.SUPPLY
const EXTRA_COLOR := Kit.HEALTH
const EDGE := Color(0.33, 0.23, 0.2)

var trip_days := 0
var extra_days := 0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func show_days(from_trip: int, from_adventurer: int) -> void:
	trip_days = from_trip
	extra_days = from_adventurer
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(Kit.ICON_SIZE + ICON_GAP + MOST_DAYS * (MARK.x + GAP), Kit.ICON_SIZE)


func _draw() -> void:
	draw_texture(Kit.icon("food"), Vector2.ZERO)
	var top := Kit.snap((Kit.ICON_SIZE - MARK.y) / 2.0)
	for day in trip_days + extra_days:
		var left := Kit.ICON_SIZE + ICON_GAP + day * (MARK.x + GAP)
		var color := TRIP_COLOR if day < trip_days else EXTRA_COLOR
		draw_rect(Rect2(left, top, MARK.x, MARK.y), color)
		draw_rect(Rect2(left, top + MARK.y - Kit.STEP, MARK.x, Kit.STEP), EDGE)
	Kit.draw_focus(self)
