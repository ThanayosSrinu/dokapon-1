class_name ClassData
extends Resource
## One character class. Each class is a .tres file in data/classes, and `id` must
## match the file name.

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""

## Stat name -> value at level 1. Needs every name in Database.STATS.
@export var base_stats: Dictionary[String, int] = {}
## Stat name -> amount gained per level. Needs every name in Database.STATS.
@export var growth: Dictionary[String, int] = {}

@export var starting_gold := 0
## Item ids placed in the bag at the start.
@export var starting_items: Array[String] = []
## Item ids worn at the start, one per equipment slot at most.
@export var starting_equipment: Array[String] = []
## The ids of the Magic and Special moves they know from the start.
@export var starting_moves: Array[String] = []
## Level -> spell id learned on reaching it, for the old board game only. Level 1 spells
## are known at the start. On a trip, moves are only learned from tomes.
@export var spells_by_level: Dictionary[int, String] = {}
