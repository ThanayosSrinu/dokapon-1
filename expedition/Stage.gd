class_name Stage
extends Resource
## A trip the Portal can lead to: one size of one place. Each is a .tres file in
## data/stages, and `id` must match the file name. A new stage needs only a new file, not
## a new screen. Stages with the same `place` are the sizes the Portal offers together.

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
## Which place this is a size of. Sizes of one place share this.
@export var place := ""
## A word for this size, on its button.
@export var size_name := ""
## One line about it, shown on its card.
@export_multiline var description := ""
## The island to play on.
@export_file("*.json") var map_file := ""
## Its small view, from assets/custom/portal/. tools/art_portal.py draws these.
@export var picture: Texture2D
## Days of food a trip here gives. tools/sim_expedition.tscn shows what a number does.
@export var food_days := 14


## Days of food `person` carries on a trip here.
func food_for(person: Adventurer) -> int:
	return food_days + person.bonus_food
