extends SceneTree
## Checks the files in data/ without opening the editor. Run from the project root:
##   godot --headless --path . --script res://tools/check_data.gd
## Prints "DATA OK" or one line per problem, and exits with 1 on problems.


func _initialize() -> void:
	var database = load("res://autoload/Database.gd").new()
	database.load_all()
	var problems: PackedStringArray = database.validate()
	for problem in problems:
		print("PROBLEM: ", problem)
	if problems.is_empty():
		print("DATA OK: %d items, %d spells, %d classes, %d monsters" % [database.items.size(),
				database.spells.size(), database.classes.size(), database.monsters.size()])
	database.free()
	quit(1 if not problems.is_empty() else 0)
