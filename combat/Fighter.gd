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

var _hp := 0
var _mp := 0


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
	return ShadowCrown.boost(player, stat, player.get_stat(stat)) if player != null else monster.stats[stat]


## True when nobody chooses this fighter's moves on screen.
func is_cpu() -> bool:
	return player == null or player.is_cpu


## The spells usable in battle. Field magic is for the board.
func get_spells() -> Array[String]:
	if player == null:
		return monster.spells
	return player.spells.filter(func(id: String) -> bool:
			return Database.get_spell(id).kind != SpellData.Kind.FIELD)


## The healing items in the bag, without repeats. Monsters carry none.
func get_items() -> Array[String]:
	var ids: Array[String] = []
	if player != null:
		for item_id in player.inventory:
			if not ids.has(item_id) and not player.auto_off.has(item_id) \
					and Database.get_item(item_id).kind == ItemData.Kind.CONSUMABLE:
				ids.append(item_id)
	return ids
