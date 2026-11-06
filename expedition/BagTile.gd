class_name BagTile
extends Button
## One square for an item: a place in the bag, or a slot for worn gear.

const SIZE := 48.0
const CORNER := 8.0

## Shows this tile as the one picked.
var lit := false:
	set(value):
		lit = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, Kit.box("chip", CORNER))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	if lit:
		draw_style_box(Kit.box("focus", 12.0), Rect2(Vector2.ZERO, size).grow(2.0))
	else:
		Kit.draw_focus(self)
