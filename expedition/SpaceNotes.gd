class_name SpaceNotes
extends RefCounted
## What each kind of space does on a trip, in words for the detail box. The numbers come
## from the rules, so they stay true when the rules are tuned. A space is told as it stands
## on this trip, so a beaten monster reads as empty road.

const WORDS := {
	BoardNode.NodeType.NORMAL: "A quiet stretch of road. Nothing happens here.",
	BoardNode.NodeType.BATTLE: "A monster. Landing exactly on it starts a fight, and walking past does nothing.",
	BoardNode.NodeType.PORTAL: "The only way home. They must land on it exactly.",
}
const GUARDED_TITLE := "Guarded Treasure"


## The name and the words for space `id`, as they stand right now.
static func of(trip: Expedition, id: int) -> Dictionary:
	var type := trip.type_at(id)
	if type == BoardNode.NodeType.TREASURE:
		var guarded := trip.is_guarded(id)
		var seen := trip.foreseen_chest(id)
		return {"title": GUARDED_TITLE if guarded else BoardNode.TYPE_INFO[type]["name"],
				"text": _chest_words(trip.player, guarded) if seen == null else _seen_chest_words(seen)}
	var foe := trip.foreseen_monster(id) if type == BoardNode.NodeType.BATTLE else null
	if foe != null:
		return {"title": foe.display_name, "text": "%s, level %d. Landing exactly on it starts a fight, and walking past does nothing." % [
				foe.display_name, foe.level]}
	return {"title": BoardNode.TYPE_INFO[type]["name"], "text": WORDS.get(type, "")}


# What a chest holds, for those who can see it. It takes an exact landing all the same.
static func _seen_chest_words(chest: SpaceEffects.Result) -> String:
	var words := "It holds %d gold." % chest.gold
	if chest.item_id != "":
		words = "It holds a %s." % Database.get_item(chest.item_id).display_name
	if chest.guardian != null:
		words += " A %s guards it." % chest.guardian.display_name
	return words + " It takes an exact landing."


static func _chest_words(player: PlayerData, guarded: bool) -> String:
	var usual := SpaceEffects.CHEST_GOLD_BASE + SpaceEffects.CHEST_GOLD_PER_LEVEL * player.level
	var words := "About %d gold or a good item. It takes an exact landing." % player.found_gold(usual)
	if guarded:
		words += " A monster guards it: win the fight and the chest opens at once."
	return words
