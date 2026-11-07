extends Node
## Keeps menus usable with a controller or the keyboard. Registered as the "PadInput"
## autoload. Godot moves focus between buttons by itself, but only once one of them
## has focus. A mouse click on empty space, or a window that forgot to choose a button,
## leaves none, and then a controller can do nothing. So if a direction or Accept
## arrives with nothing focused, this focuses the top button on screen.
##
## It also knows whether keys or a controller are in use. Focus is only drawn then:
## with the mouse, only what the mouse points at lights up.

## Sent when the player moves from the mouse to keys or a controller, or back.
signal keys_in_use_changed

## True after a key or controller press, false again once the mouse moves or clicks.
var keys_in_use := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion and event.relative.length() > 1.0:
		_use_keys(false)
	if event is InputEventMouse:
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton
			or event is InputEventAction) and event.is_pressed()
	if pressed or event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_use_keys(true)
	for action: String in ["ui_accept", "ui_up", "ui_down", "ui_left", "ui_right"]:
		if event.is_action_pressed(action):
			if get_viewport().gui_get_focus_owner() == null and rescue_focus():
				get_viewport().set_input_as_handled()
			return


## True if `control` has focus and it should be drawn.
func shows_focus(control: Control) -> bool:
	return keys_in_use and control.has_focus()


func _use_keys(on: bool) -> void:
	if keys_in_use == on:
		return
	keys_in_use = on
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.queue_redraw()
		if focus.has_method("_refresh"):
			focus.call("_refresh")
	keys_in_use_changed.emit()


## Focuses the top button on screen. Returns false if there is none.
func rescue_focus() -> bool:
	var button := top_button(get_tree().root)
	if button == null:
		return false
	button.grab_focus()
	return true


## The last usable button under `node`. Later nodes draw on top, so it is searched
## from the end, skipping anything hidden.
func top_button(node: Node) -> BaseButton:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return null
	for index in range(node.get_child_count() - 1, -1, -1):
		var found := top_button(node.get_child(index))
		if found != null:
			return found
	if node is BaseButton:
		var button: BaseButton = node
		if not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			return button
	return null
