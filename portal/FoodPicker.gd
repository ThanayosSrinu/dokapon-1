class_name FoodPicker
extends Control
## How much food to buy, as one mark for each day they can carry, so that a long trip looks
## long (rule U3). Filled marks are bought, and the dark ones at the end cost more than the
## town has. Slide with the mouse, or step with left and right on the keys or the D-pad.
## Tips.attach() adds words.

signal picked(amount: int)

const TRACK := 336.0
const MARK_HEIGHT := 22.0
const ICON_GAP := 8.0
## The room each mark gets, however many there are. The most anyone can carry must fit.
const WIDEST_STEP := 14.0
const THINNEST_STEP := 8.0
## Wide marks get a wider gap.
const WIDE_GAP := 4.0
const THIN_GAP := 2.0
const BOUGHT_COLOR := Kit.SUPPLY
const SPARE_COLOR := Color(0.33, 0.23, 0.2, 0.3)
const TOO_DEAR_COLOR := Color(0.33, 0.23, 0.2, 0.8)
const EDGE := Color(0.33, 0.23, 0.2)

## Days of food bought.
var amount := 0
## The most they can carry.
var carry := 0
## The most the town can pay for, up to `carry`.
var afford := 0


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func show_food(new_amount: int, new_carry: int, new_afford: int) -> void:
	amount = new_amount
	carry = new_carry
	afford = new_afford
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(Kit.ICON_SIZE + ICON_GAP + TRACK, Kit.ICON_SIZE)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		accept_event()
		_pick(amount - 1)
	elif event.is_action_pressed("ui_right", true):
		accept_event()
		_pick(amount + 1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		grab_focus()
		_pick(_amount_at(event.position.x))
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		accept_event()
		_pick(_amount_at(event.position.x))


func _pick(wanted: int) -> void:
	var next := clampi(wanted, 0, afford)
	if next == amount:
		return
	amount = next
	Sound.play("hover")
	queue_redraw()
	picked.emit(amount)


# How much food the mark under `x` stands for. Left of the first mark is none at all.
func _amount_at(x: float) -> int:
	return ceili((x - _left()) / _step())


func _left() -> float:
	return Kit.ICON_SIZE + ICON_GAP


# The room for one mark, in whole art pixels.
func _step() -> float:
	var room := TRACK / maxi(carry, 1)
	return clampf(floorf(room / Kit.STEP) * Kit.STEP, THINNEST_STEP, WIDEST_STEP)


func _draw() -> void:
	draw_texture(Kit.icon("food"), Vector2.ZERO)
	var top := Kit.snap((Kit.ICON_SIZE - MARK_HEIGHT) / 2.0)
	var step := _step()
	var width := step - (WIDE_GAP if step >= WIDEST_STEP else THIN_GAP)
	for day in carry:
		var mark := Rect2(_left() + day * step, top, width, MARK_HEIGHT)
		draw_rect(mark, BOUGHT_COLOR if day < amount else (SPARE_COLOR if day < afford else TOO_DEAR_COLOR))
		if day < amount:
			draw_rect(Rect2(mark.position.x, top + MARK_HEIGHT - Kit.STEP, width, Kit.STEP), EDGE)
	Kit.draw_focus(self)
