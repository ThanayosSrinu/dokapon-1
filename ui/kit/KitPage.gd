class_name KitPage
extends Control
## A window over the current screen: the screen dims, a panel rises, and the Back
## button sits where it always does. Fill `panel.body`, and override first_focus().

## Emitted when the page closes.
signal closed

var panel: KitPanel
var back: KitBackButton


func _init(heading := "") -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = KitPanel.new(heading)
	back = KitBackButton.new()
	back.pressed.connect(close)
	hide()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(panel)
	add_child(back)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Kit.DIM)


func open() -> void:
	show()
	first_focus().grab_focus()
	panel.play_open()


func close() -> void:
	Tips.close()
	hide()
	closed.emit()


## What has focus when the page opens.
func first_focus() -> Control:
	return back
