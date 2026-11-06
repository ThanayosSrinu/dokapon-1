class_name KitBar
extends Control
## A picture and a bar (rule U3). A change slides into place, and what was lost
## lingers in pale for a moment. Tips.attach() adds the exact numbers.

const BAR_HEIGHT := 24.0
const GAP := 8.0
const WIDTH := 200.0
const INSET := 4.0
const NOTCHES := 10
const SLIDE_SECONDS := 0.25
const LINGER_SECONDS := 0.7
const LOST := Color(1.0, 0.96, 0.84)
const NOTCH := Color(0, 0, 0, 0.22)

## The whole width, picture included.
var width := WIDTH:
	set(value):
		width = value
		update_minimum_size()
var bar_color := Kit.HEALTH:
	set(value):
		bar_color = value
		queue_redraw()
var picture: Texture2D:
	set(value):
		picture = value
		update_minimum_size()
		queue_redraw()
## How full the bar looks, from 0 to 1.
var shown := 0.0:
	set(value):
		shown = value
		queue_redraw()
var lingering := 0.0:
	set(value):
		lingering = value
		queue_redraw()

var _tween: Tween


func _init(color := Kit.HEALTH, image: Texture2D = null) -> void:
	bar_color = color
	picture = image
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _get_minimum_size() -> Vector2:
	return Vector2(width, Kit.ICON_SIZE if picture != null else BAR_HEIGHT)


## Sets how full the bar is. With `slide` false, it jumps there.
func set_amount(amount: float, full: float, slide := true) -> void:
	var fraction := clampf(amount / full, 0.0, 1.0) if full > 0.0 else 0.0
	if _tween != null:
		_tween.kill()
	if not slide or not is_inside_tree():
		shown = fraction
		lingering = fraction
		return
	lingering = maxf(lingering, shown)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "shown", fraction, SLIDE_SECONDS)
	_tween.tween_property(self, "lingering", fraction, LINGER_SECONDS).set_delay(SLIDE_SECONDS)


func _draw() -> void:
	var left := 0.0
	if picture != null:
		draw_texture(picture, Vector2.ZERO)
		left = Kit.ICON_SIZE + GAP
	var trough := Rect2(left, Kit.snap((size.y - BAR_HEIGHT) / 2.0), size.x - left, BAR_HEIGHT)
	draw_style_box(Kit.box("bar", 8.0), trough)
	var inside := trough.grow(-INSET)
	_fill(inside, lingering, LOST)
	_fill(inside, shown, bar_color)
	var notch := inside.size.x / NOTCHES
	for index in range(1, NOTCHES):
		draw_rect(Rect2(Kit.snap(inside.position.x + notch * index), inside.position.y,
				Kit.STEP, inside.size.y), NOTCH)
	Kit.draw_focus(self)


func _fill(inside: Rect2, fraction: float, color: Color) -> void:
	# A sliver stays visible, so that "nearly empty" never looks like "empty".
	var filled := Kit.snap(inside.size.x * fraction)
	if fraction > 0.0:
		filled = maxf(filled, Kit.STEP * 2.0)
	if filled <= 0.0:
		return
	var body := Rect2(inside.position, Vector2(filled, inside.size.y))
	draw_rect(body, color)
	draw_rect(Rect2(body.position, Vector2(filled, Kit.STEP)), color.lightened(0.35))
	draw_rect(Rect2(body.position + Vector2(0, body.size.y - Kit.STEP), Vector2(filled, Kit.STEP)),
			color.darkened(0.3))
