class_name SpellData
extends Resource
## One spell. Each spell is a .tres file in data/spells, and `id` must match the
## file name. combat/Battle.gd casts them.

enum Kind { ATTACK, HEAL }

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var kind := Kind.ATTACK
@export var mp_cost := 0
## Added to the caster's magic stat to work out damage or healing.
@export var power := 0
