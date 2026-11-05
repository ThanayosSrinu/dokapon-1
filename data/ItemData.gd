class_name ItemData
extends Resource
## One kind of item. Each item is a .tres file in data/items, and `id` must match
## the file name. Players store the id, never this resource, so saves stay small.

enum Kind { CONSUMABLE, WEAPON, ARMOR, ACCESSORY }

## How each stat is written on screen.
const STAT_NAMES := {
	"max_hp": "Max HP", "max_mp": "Max MP", "attack": "Attack",
	"defense": "Defense", "magic": "Magic", "speed": "Speed",
}

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var kind := Kind.CONSUMABLE
## What a shop charges for it. Shop.gd pays half of this back.
@export var price := 0
## Which picture on assets/custom/item_icons.png shows it, counted from 0.
@export var icon := 0

@export_group("Equipment")
## Stat name -> amount added while equipped. Keys come from Database.STATS.
@export var bonuses: Dictionary[String, int] = {}

@export_group("Consumable")
## HP restored by using it.
@export var heal_hp := 0
## MP restored by using it.
@export var heal_mp := 0


## A short line saying what the item does, such as "+6 Attack, -1 Speed".
func effect_text() -> String:
	var parts := PackedStringArray()
	if heal_hp > 0:
		parts.append("Heals %d HP" % heal_hp)
	if heal_mp > 0:
		parts.append("Heals %d MP" % heal_mp)
	for stat: String in bonuses:
		parts.append("%+d %s" % [bonuses[stat], STAT_NAMES[stat]])
	return ", ".join(parts)
