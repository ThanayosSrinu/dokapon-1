class_name Fighter
extends RefCounted
## One side of a battle. It gives players and monsters the same shape, so the
## rules in Battle.gd never need to ask which one they have.
##
## A player's HP and MP live in PlayerData, so damage lasts after the battle. A
## monster's only exist here, because a new fight starts with a new monster.

var display_name := ""
var level := 1
var sheet: Texture2D
## The color of the ring at its feet. Monsters have none.
var color := Color.TRANSPARENT
## Set for a player, null for a monster.
var player: PlayerData
## Set for a monster, null for a player.
var monster: MonsterData

var hp: int:
	get:
		return player.hp if player != null else _hp
	set(value):
		var clamped := clampi(value, 0, get_stat("max_hp"))
		if player != null:
			player.hp = clamped
			player.changed.emit()
		else:
			_hp = clamped

var mp: int:
	get:
		return player.mp if player != null else _mp
	set(value):
		var clamped := clampi(value, 0, get_stat("max_mp"))
		if player != null:
			player.mp = clamped
			player.changed.emit()
		else:
			_mp = clamped

## The Specials already used in this fight. A Special works once per fight.
var specials_used: Array[String] = []

var _hp := 0
var _mp := 0
# What a Boost raised, as {"stat", "share", "turns"}, with its own turns left.
var _boosts: Array[Dictionary] = []


static func from_player(source: PlayerData) -> Fighter:
	var fighter := Fighter.new()
	fighter.player = source
	fighter.display_name = source.player_name
	fighter.level = source.level
	fighter.sheet = source.character_sheet
	fighter.color = ShadowCrown.COLOR if ShadowCrown.is_worn_by(source) else source.token_color
	return fighter


static func from_monster(source: MonsterData) -> Fighter:
	var fighter := Fighter.new()
	fighter.monster = source
	fighter.display_name = source.display_name
	fighter.level = source.level
	fighter.sheet = source.sheet
	fighter._hp = source.stats["max_hp"]
	fighter._mp = source.stats["max_mp"]
	return fighter


func get_stat(stat: String) -> int:
	var value: int = ShadowCrown.boost(player, stat, player.get_stat(stat)) if player != null else monster.stats[stat]
	var share := 1.0
	for boost in _boosts:
		if boost["stat"] == stat:
			share += boost["share"]
	return ceili(value * share) if share > 1.0 else value


## Raises `stat` by `share` for `turns` of this fighter's own turns, counted from the next
## one. Using the same boost again starts it over.
func add_boost(stat: String, share: float, turns: int) -> void:
	_boosts = _boosts.filter(func(boost: Dictionary) -> bool: return boost["stat"] != stat)
	# The turn it was used on is counted off too.
	_boosts.append({"stat": stat, "share": share, "turns": turns + 1})


## Counts one of this fighter's own turns.
func tick_boosts() -> void:
	for boost in _boosts:
		boost["turns"] -= 1
	_boosts = _boosts.filter(func(boost: Dictionary) -> bool: return boost["turns"] > 0)


## What is raised right now, as {"stat", "share", "turns"}.
func boosts() -> Array[Dictionary]:
	return _boosts


## True when nobody chooses this fighter's moves on screen.
func is_cpu() -> bool:
	return player == null or player.is_cpu


## The ids of the moves this fighter has in `category`. With no weapon or armor, there is
## still Punch and Brace.
func moves_in(category: MoveData.Category) -> Array[String]:
	var found: Array[String] = player.moves_in(category) if player != null else monster.moves.filter(
			func(id: String) -> bool: return Database.get_move(id).category == category)
	if found.is_empty() and category == MoveData.Category.ATTACK:
		found.append(Battle.BARE_ATTACK)
	elif found.is_empty() and category == MoveData.Category.GUARD:
		found.append(Battle.BARE_GUARD)
	return found


## The healing items in the bag, without repeats. Monsters carry none.
func get_items() -> Array[String]:
	var ids: Array[String] = []
	if player != null:
		for item_id in player.inventory:
			if not ids.has(item_id) and Database.get_item(item_id).kind == ItemData.Kind.CONSUMABLE:
				ids.append(item_id)
	return ids
