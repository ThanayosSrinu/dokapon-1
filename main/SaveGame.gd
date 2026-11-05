class_name SaveGame
extends RefCounted
## Saving and loading, with no UI. A save is a Dictionary of plain values, written
## with store_var() and read back without objects, so a save file can never run code.
##
## A game is only saved between things, never halfway through one:
##   in_turn false  at the start of a turn. Loading plays that turn from its top.
##   in_turn true   while a person is deciding, before they roll. Loading goes back
##                  to their ACTION phase, so the start of their turn doesn't repeat.
## GameState.rng is saved too, so a loaded game goes on exactly as it would have.
## Tokens, towns' names and guards, and shop shelves all come from the map and the
## seed, so they are not saved.

## Raise this when a save's contents change. Older files are then refused.
const VERSION := 1
## Written at the start of every turn.
const AUTO := "auto"
## The ones a person saves to.
const SLOTS: Array[String] = ["slot1", "slot2", "slot3"]
const EXTENSION := ".save"
## What every save must hold, apart from the players' own values.
const KEYS: Array[String] = [
	"version", "turn_index", "in_turn", "notes", "seed", "rng_state", "day", "game_weeks",
	"players", "town_owners", "town_levels", "quest", "emptied_chests", "shadow_crown",
	"crown_left_week",
]

## The folder for saves. Tests point this at their own folder.
static var folder_name := "saves"


## Saves stay beside the game: in _work when run from the project, so nothing lands
## on C:, and next to the program in an exported build. If that can't be written to,
## as under Program Files, they go in Godot's own folder for this game.
static func folder() -> String:
	var parent := ProjectSettings.globalize_path("res://_work") if OS.has_feature("editor") \
			else OS.get_executable_path().get_base_dir()
	var path := parent.path_join(folder_name)
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		path = OS.get_user_data_dir().path_join(folder_name)
		DirAccess.make_dir_recursive_absolute(path)
	return path


## The game as it stands now. `notes` is GameController's own, passed back on loading.
static func capture(turn_index: int, in_turn: bool, notes: Dictionary) -> Dictionary:
	var players := []
	for player in GameState.players:
		players.append(player.to_save())
	var owners := {}
	for id: int in GameState.town_owners:
		owners[id] = GameState.town_owners[id].player_name
	return {
		"version": VERSION,
		"turn_index": turn_index,
		"in_turn": in_turn,
		"notes": notes.duplicate(),
		"seed": GameState.game_seed,
		"rng_state": GameState.rng.state,
		"day": GameState.day,
		"game_weeks": GameState.game_weeks,
		"players": players,
		"town_owners": owners,
		"town_levels": GameState.town_levels.duplicate(),
		"quest": GameState.quest.duplicate(true),
		"emptied_chests": GameState.emptied_chests.duplicate(),
		"shadow_crown": GameState.shadow_crown.duplicate(true),
		"crown_left_week": GameState.crown_left_week,
	}


## Puts a save back into GameState. Check it with problem() first.
static func restore(save: Dictionary) -> void:
	GameState.game_seed = save["seed"]
	GameState.rng.seed = save["seed"]
	GameState.rng.state = save["rng_state"]
	GameState.day = save["day"]
	GameState.game_weeks = save["game_weeks"]
	var players: Array[PlayerData] = []
	var by_name := {}
	for saved: Dictionary in save["players"]:
		var player := PlayerData.from_save(saved)
		players.append(player)
		by_name[player.player_name] = player
	GameState.players = players
	GameState.town_owners.clear()
	for id: int in save["town_owners"]:
		GameState.town_owners[id] = by_name[save["town_owners"][id]]
	GameState.town_levels = save["town_levels"].duplicate()
	GameState.quest = save["quest"].duplicate(true)
	GameState.emptied_chests = save["emptied_chests"].duplicate()
	GameState.shadow_crown = save["shadow_crown"].duplicate(true)
	GameState.crown_left_week = save["crown_left_week"]


## Why this save can't be loaded on this map with these tokens, or "" if it can.
static func problem(save: Dictionary, space_ids: Array, token_names: Array) -> String:
	if save.is_empty():
		return "This save cannot be read."
	if save.get("version") != VERSION or not save.has_all(KEYS):
		return "This save was made by a different version of the game."
	var players: Array = save["players"]
	if players.is_empty() or save["turn_index"] < 0 or save["turn_index"] >= players.size():
		return "This save is damaged."
	var names := []
	var needed := PlayerData.new().to_save().keys()
	for saved: Dictionary in players:
		if not saved.has_all(needed):
			return "This save was made by a different version of the game."
		if not token_names.has(saved["name"]):
			return "This save has a player the game doesn't know."
		if not space_ids.has(saved["space_id"]):
			return "This save no longer fits the map."
		if not _knows_everything(saved):
			return "This save has items or spells the game doesn't know."
		names.append(saved["name"])
	for id: int in save["town_owners"]:
		if not space_ids.has(id) or not names.has(save["town_owners"][id]):
			return "This save no longer fits the map."
	return ""


## Writes a save, replacing what `slot` held only once it is safely written. Returns
## false if that failed.
static func write(slot: String, save: Dictionary) -> bool:
	var stamped := save.duplicate()
	stamped["saved_at"] = Time.get_unix_time_from_system()
	var temporary := _path(slot) + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("SaveGame: cannot write %s." % temporary)
		return false
	file.store_var(stamped)
	file.close()
	return DirAccess.rename_absolute(temporary, _path(slot)) == OK


## Reads a slot. Returns {} if it is empty or can't be read.
static func read(slot: String) -> Dictionary:
	if not has_file(slot):
		return {}
	var file := FileAccess.open(_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var save: Variant = file.get_var()
	return save if save is Dictionary else {}


static func has_file(slot: String) -> bool:
	return FileAccess.file_exists(_path(slot))


## Removes a slot's save, if it has one.
static func erase(slot: String) -> void:
	if has_file(slot):
		DirAccess.remove_absolute(_path(slot))


## The slot saved to most recently, or "" if there are none.
static func newest() -> String:
	var found := ""
	var latest := 0.0
	var every_slot: Array[String] = [AUTO]
	every_slot.append_array(SLOTS)
	for slot in every_slot:
		var saved_at: float = read(slot).get("saved_at", 0.0)
		if saved_at > latest:
			latest = saved_at
			found = slot
	return found


## One line about a save, for a menu.
static func describe(save: Dictionary) -> String:
	var bias_seconds: int = Time.get_time_zone_from_system()["bias"] * 60
	var saved_at := Time.get_datetime_string_from_unix_time(int(save["saved_at"]) + bias_seconds, true)
	@warning_ignore("integer_division")
	var week: int = (save["day"] - 1) / GameState.DAYS_PER_WEEK + 1
	var whose: String = save["players"][save["turn_index"]]["name"]
	return "Week %d of %d, %s's turn (%s)" % [week, save["game_weeks"], whose, saved_at.left(16)]


static func _knows_everything(saved: Dictionary) -> bool:
	if not Database.classes.has(saved["class_id"]):
		return false
	for item_id: String in saved["inventory"] + saved["equipment"].values():
		if not Database.items.has(item_id):
			return false
	for spell_id: String in saved["spells"]:
		if not Database.spells.has(spell_id):
			return false
	return true


static func _path(slot: String) -> String:
	return folder().path_join(slot + EXTENSION)
