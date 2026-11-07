class_name MaterialData
extends Resource
## One kind of material: what trips bring home for the town to build with. Each is a .tres
## file in data/materials, and `id` must match the file name. Materials travel in their own
## bag on a trip, apart from items, and the town keeps a count of each.

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
## What the Shop would charge for one. It pays half of this.
@export var price := 0
## Which picture on assets/custom/item_icons.png shows it, counted from 0.
@export var icon := 0
## A rare material is found only at the deep end of a spur.
@export var rare := false
