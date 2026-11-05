extends Node2D

## The space where the token starts. Set this in the Inspector.
@export var start_node: BoardNode

var current_node: BoardNode

@onready var token: Sprite2D = $Token


func _ready() -> void:
	# Print every space and its neighbors to the Output panel.
	for child in get_children():
		if child is BoardNode:
			var neighbor_ids := []
			for neighbor in child.get_neighbors():
				neighbor_ids.append(neighbor.node_id)
			print("Space %d (%s) -> %s" % [child.node_id, BoardNode.NodeType.keys()[child.node_type], neighbor_ids])

	current_node = start_node
	token.global_position = current_node.global_position


func _unhandled_input(event: InputEvent) -> void:
	# "ui_accept" is Space or Enter by default.
	if event.is_action_pressed("ui_accept"):
		var options := current_node.get_neighbors()
		if options.is_empty():
			return
		current_node = options.pick_random()
		print("Moved to space ", current_node.node_id)
		# Slide the token smoothly over 0.3 seconds.
		create_tween().tween_property(token, "global_position", current_node.global_position, 0.3)
