class_name MonsterData
extends Resource
## One kind of monster. Each monster is a .tres file in data/monsters, and `id`
## must match the file name.

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
## Shown when the monster appears, so write it as a hint about how it fights.
@export_multiline var description := ""
## A character sheet from res://assets/puny/characters/.
@export var sheet: Texture2D
@export var level := 1

@export_group("Encounters")
## Players of this level, up to max_level, may meet it on a Battle space.
@export var min_level := 1
@export var max_level := 1

@export_group("Stats")
## Stat name -> value. Needs every name in Database.STATS.
@export var stats: Dictionary[String, int] = {}
## The ids of its moves. Its habits pick a category, then one of these at random.
@export var moves: Array[String] = []

@export_group("Habits")
## How often it picks each offense: keys "attack", "smash", "magic" and "special".
@export var offense_weights: Dictionary[String, int] = {}
## How often it picks each defense: keys "guard", "counter" and "ward".
@export var defense_weights: Dictionary[String, int] = {}

@export_group("Rewards")
@export var exp_reward := 0
@export var gold_reward := 0
## Item ids it may drop. One is picked at random.
@export var loot: Array[String] = []
## The chance of a drop, from 0 to 1.
@export_range(0.0, 1.0) var loot_chance := 0.0
