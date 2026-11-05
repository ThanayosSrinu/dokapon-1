class_name ItemData
extends Resource
## One kind of item. Each item is a .tres file in data/items, and `id` must match
## the file name. Players store the id, never this resource, so saves stay small.

enum Kind { CONSUMABLE, WEAPON, ARMOR, ACCESSORY }

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var kind := Kind.CONSUMABLE
## What a shop charges for it (Section 6).
@export var price := 0

@export_group("Equipment")
## Stat name -> amount added while equipped. Keys come from Database.STATS.
@export var bonuses: Dictionary[String, int] = {}

@export_group("Consumable")
## HP restored by using it.
@export var heal_hp := 0
## MP restored by using it.
@export var heal_mp := 0
