class_name MoveData
extends Resource
## One move in a fight. Each move is a .tres file in data/moves, and `id` must match the
## file name. combat/Battle.gd plays them.
##
## The category says where a move comes from: weapons give Attack and Smash, armor gives
## Guard, Counter and Ward, and Magic and Special are learned. The keywords say how it
## can be answered, and the battle menu shows them as icons (E14):
##
##   heavy    Breaks through a Guard or a Ward. A Counter hits it back
##   magic    Uses MP and the Magic stat. A Ward makes it weaker
##   status   Ward blocks it, Guard makes it shorter
##   once     Works once a fight. Goes with one of the above, or on a move for oneself
##   (none)   A plain hit. A Guard makes it weaker
##
## A move on its user (a heal or a boost) needs no answer, so it has no keyword but "once".
##
## What `power` means:
##   a hit             the share of the hit's force that lands, or with magic, added to Magic
##   Guard, Ward       the share of a hit it takes off, when it answers that hit
##   Counter           the share of a heavy hit it sends back
##   Heal              added to the user's Magic stat
##   Boost, Weaken     the share added to, or taken off, `boost_stat`
##   Poison            the share of the foe's max HP lost at the end of each of its turns

enum Category { ATTACK, SMASH, MAGIC, SPECIAL, GUARD, COUNTER, WARD }
## What a move does, past a plain hit.
enum Effect { NONE, HEAL, STRIKE, BOOST, WEAKEN, POISON }

const HEAVY := "heavy"
const MAGIC := "magic"
const STATUS := "status"
const ONCE := "once"
const KEYWORDS: Array[String] = [HEAVY, MAGIC, STATUS, ONCE]

## The categories worn gear fills.
const WEAPON_CATEGORIES: Array[Category] = [Category.ATTACK, Category.SMASH]
const ARMOR_CATEGORIES: Array[Category] = [Category.GUARD, Category.COUNTER, Category.WARD]
const LEARNED_CATEGORIES: Array[Category] = [Category.MAGIC, Category.SPECIAL]
const DEFENSE_CATEGORIES: Array[Category] = ARMOR_CATEGORIES
## The ATK menu holds at most this many moves, and so does DEF.
const MOST_IN_MENU := 4
## A weapon gives at most this many moves, so learned moves have the rest of the ATK menu.
const MOST_ON_WEAPON := 2
const MOST_LEARNED := MOST_IN_MENU - MOST_ON_WEAPON
## The most moves on one piece of armor.
const MOST_ON_ARMOR := MOST_IN_MENU
## The effects that work on the user, and so need no answer.
const ON_SELF: Array[Effect] = [Effect.HEAL, Effect.BOOST]

## The stable ID. Never change or reuse one, because save files will store it.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var category := Category.ATTACK
## How it can be answered. See the top of this file.
@export var keywords: Array[String] = []
@export var power := 1.0
## Only magic costs MP.
@export var mp_cost := 0
@export var effect := Effect.NONE
## Boost and Weaken: the stat it changes. Boost, Weaken and Poison: for how many of the
## target's own turns.
@export var boost_stat := ""
@export var boost_turns := 0
## Guard only: how much of a heavy hit lands through it. Heavy armor's Guard holds better.
@export var broken_share := 1.5


func has(keyword: String) -> bool:
	return keywords.has(keyword)


## True for a heal or a boost, which works on its user and asks nobody for an answer.
func on_self() -> bool:
	return ON_SELF.has(effect)


## True for a move made on your own turn, rather than an answer.
func is_offense() -> bool:
	return not DEFENSE_CATEGORIES.has(category)
