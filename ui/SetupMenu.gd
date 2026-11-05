class_name SetupMenu
extends CenterContainer
## The menu shown before a game starts. It asks how many players will play and
## covers the board, so the board cannot be clicked behind it.

## Emitted once when a number is picked. The menu then hides itself.
signal player_count_chosen(count: int)

@export var min_players := 2
@export var max_players := 4

## Gets one button per possible player count. Drag ButtonRow here.
@export var button_row: Container


func _ready() -> void:
	for count in range(min_players, max_players + 1):
		var button := Button.new()
		button.text = "%d Players" % count
		button.pressed.connect(_choose.bind(count))
		button_row.add_child(button)
	# Focus the last button, so Space or Enter starts a full game.
	button_row.get_child(-1).grab_focus()


func _choose(count: int) -> void:
	hide()
	player_count_chosen.emit(count)
