class_name GameController
extends Node2D
## Runs the turn loop for the prototype:
##   1. The player clicks "Roll Dice".
##   2. A six-sided die is rolled and the player token moves that many spaces.
##   3. At a fork, one button per path appears; clicking one continues the move.
##   4. When the token stops, the landed space is shown and the next turn can
##      begin.
##   5. Clicking any space shows its details in the InfoLabel (Section 1).
##
## Expected scene layout (see GAME_CONTROLLER_GUIDE.md for the full walkthrough):
##   Main (Node2D, this script)
##   ├── WorldMap (BoardManager, from res://maps/WorldMap.tscn)
##   ├── Player
##   ├── BoardCamera
##   └── UI (CanvasLayer)
##       ├── InfoLabel (Label)
##       └── Panel (PanelContainer)
##           └── VBox (VBoxContainer)
##               ├── StatusLabel (Label)
##               ├── RollButton (Button)
##               └── ChoiceBox (HBoxContainer)

const DIE_SIDES := 6

## A short line shown under the name of the space the player lands on.
const TYPE_DESCRIPTIONS := {
	BoardNode.NodeType.CASTLE: "Back home at the castle.",
	BoardNode.NodeType.NORMAL: "An ordinary space. Nothing happens.",
	BoardNode.NodeType.SHOP: "A shop! (Shopping is not implemented yet.)",
	BoardNode.NodeType.EVENT: "An event space! (Events are not implemented yet.)",
	BoardNode.NodeType.TOWN: "A town. (Towns are not implemented yet.)",
	BoardNode.NodeType.ITEM: "An item space. (Items are not implemented yet.)",
	BoardNode.NodeType.MAGIC: "A magic space. (Spells are not implemented yet.)",
	BoardNode.NodeType.GOLD: "A gold space. (Gold is not implemented yet.)",
	BoardNode.NodeType.BATTLE: "A monster appears! (Battles are not implemented yet.)",
	BoardNode.NodeType.TREASURE: "Treasure may be buried here. (Not implemented yet.)",
	BoardNode.NodeType.SHRINE: "A shrine. (Healing is not implemented yet.)",
	BoardNode.NodeType.TRAP: "A trap! (Traps are not implemented yet.)",
}

## The player to control. Drag the Player node here in the Inspector.
@export var player: PlayerMovement

## The "Roll Dice" button. Drag the RollButton node here in the Inspector.
@export var roll_button: Button

## Shows the dice result and the game status. Drag StatusLabel here.
@export var status_label: Label

## Gets one button per path while the player stands at a fork.
## Drag ChoiceBox here.
@export var choice_box: Container

## The board. Drag the WorldMap node here.
@export var board: BoardManager

## The camera that looks at the board. Drag BoardCamera here.
@export var camera: BoardCamera

## Shows details about the space that was clicked last. Drag InfoLabel here.
@export var info_label: Label

# The turn being played, starting at 1.
var _turn := 1
# The result of the last dice roll, kept so every status message can show it.
var _last_roll := 0
# The space clicked last, so its highlight can be removed on the next click.
var _selected_node: BoardNode


func _ready() -> void:
	if (player == null or roll_button == null or status_label == null or choice_box == null
			or board == null or camera == null or info_label == null):
		push_error("GameController: assign 'player', 'roll_button', 'status_label', "
				+ "'choice_box', 'board', 'camera' and 'info_label' in the Inspector.")
		return

	# The button's 'pressed' signal is meant to be connected in the editor
	# (Node dock -> Signals). Fall back to connecting it here so the game
	# still works if that step was skipped.
	if not roll_button.pressed.is_connected(_on_roll_button_pressed):
		push_warning("GameController: RollButton.pressed is not connected in the editor. "
				+ "Connecting it from code instead.")
		roll_button.pressed.connect(_on_roll_button_pressed)

	# The Player is created from its own scene file, so its signals are
	# connected here in code.
	player.movement_finished.connect(_on_movement_finished)
	player.path_choice_required.connect(_on_path_choice_required)

	# Board clicks arrive through the global EventBus autoload.
	EventBus.space_clicked.connect(_on_space_clicked)

	camera.global_position = board.get_bounds().get_center()
	info_label.text = ("Click a space to inspect it.
"
			+ "WASD / arrows: pan    Wheel: zoom    Right-drag: pan")

	_clear_choices()
	_show_status("Turn %d\nPress \"Roll Dice\" to start." % _turn)


# --- Signal handlers --------------------------------------------------------

## Connected to RollButton's 'pressed' signal in the editor.
func _on_roll_button_pressed() -> void:
	if player.is_moving:
		return

	# Disable the button first, so it cannot be clicked again mid-move.
	roll_button.disabled = true
	# Godot 4 seeds the random number generator automatically on start,
	# so every run gives different rolls.
	_last_roll = randi_range(1, DIE_SIDES)
	_show_status("Turn %d\nYou rolled a %d! Moving..." % [_turn, _last_roll])

	# move_steps() runs over several frames. It returns right away here and
	# reports back later through 'path_choice_required' and 'movement_finished'.
	player.move_steps(_last_roll)


func _on_path_choice_required(available_nodes: Array[BoardNode]) -> void:
	_show_status("Turn %d - Rolled %d\nFork! Choose a path:" % [_turn, _last_roll])
	for node in available_nodes:
		var button := Button.new()
		button.text = "%d (%s)" % [node.node_id, _type_name(node)]
		# bind() remembers which space this button stands for.
		button.pressed.connect(_on_path_button_pressed.bind(node))
		choice_box.add_child(button)


func _on_path_button_pressed(node: BoardNode) -> void:
	# Clear first: choose_path() resumes the move immediately.
	_clear_choices()
	_show_status("Turn %d - Rolled %d\nMoving..." % [_turn, _last_roll])
	player.choose_path(node)


func _on_space_clicked(node: BoardNode) -> void:
	if _selected_node != null:
		_selected_node.highlighted = false
	_selected_node = node
	node.highlighted = true
	camera.focus_on(node.global_position)

	var neighbor_texts := PackedStringArray()
	for neighbor in board.get_neighbors(node):
		neighbor_texts.append("#%d %s" % [neighbor.node_id, neighbor.get_display_name()])
	info_label.text = "Space #%d: %s
Type: %s
Neighbors: %s" % [
		node.node_id,
		node.get_display_name(),
		node.get_type_name(),
		", ".join(neighbor_texts),
	]


func _on_movement_finished(final_node: BoardNode) -> void:
	_show_status("Turn %d - Rolled %d\nLanded on space %d: %s\n%s" % [
		_turn,
		_last_roll,
		final_node.node_id,
		_type_name(final_node),
		TYPE_DESCRIPTIONS.get(final_node.node_type, ""),
	])
	print("Turn %d: rolled %d, landed on space %d (%s)" % [
		_turn, _last_roll, final_node.node_id, _type_name(final_node)])

	_turn += 1
	roll_button.disabled = false
	# Give the button keyboard focus, so Space or Enter also rolls.
	roll_button.grab_focus()


# --- Internal helpers -------------------------------------------------------

func _show_status(text: String) -> void:
	status_label.text = text


## Removes every path button from the ChoiceBox.
func _clear_choices() -> void:
	for child in choice_box.get_children():
		child.queue_free()


## Returns a readable type name such as "Castle" or "Shop".
func _type_name(node: BoardNode) -> String:
	return node.get_type_name()
