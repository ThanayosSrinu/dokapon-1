class_name MoveData
extends Resource
## One move in a fight. Each move is a .tres file in data/moves, and `id` must match the
## file name. Weapons list Attack and Smash moves, armor lists Guard, Counter and Ward
## moves, and Magic and Special are learned. combat/Battle.gd plays them.
##
## What `power` means depends on the category:
##   Attack, Smash   the share of the hit's force that lands
##   Guard, Ward     the share of a hit it takes off, when it answers that hit
##   Counter         the share of a Smash it sends back
##   Magic           added to the user's Magic stat
##   Special         Heal: added to the user's Magic stat. Strike: as Attack. Boost: the
##                   share added to `boost_stat`

enum Category { ATTACK, SMASH, MAGIC, SPECIAL, GUARD, COUNTER, WARD }
## What a Special does.
enum Effect { NONE, HEAL, STRIKE, BOOST }

## The categories worn gear fills.
const WEAPON_CATEGORIES: Array[Category] = [Category.ATTACK, Category.SMASH]
const ARMOR_CATEGORIES: Array[Category] = [Category.GUARD, Category.COUNTER, Category.WARD]
## The most moves a person can know in each category that is learned.
const MOST_LEARNED := {Category.MAGIC: 4, Category.SPECIAL: 2}
## The most moves in one category of a weapon or a piece of armor.
const MOST_IN_CATEGORY := 4
## The most moves on one piece of armor.
const MOST_ON_ARMOR := 6

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var category := Category.ATTACK
@export var power := 1.0
## Only Magic costs MP.
@export var mp_cost := 0
@export var effect := Effect.NONE
## Boost only: the stat it raises, and for how many of the user's own turns.
@export var boost_stat := ""
@export var boost_turns := 0
