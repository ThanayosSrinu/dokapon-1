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
		return {"title": GUARDED_TITLE if guarded else BoardNode.TYPE_INFO[type]["name"],
				"text": _chest_words(trip.player, guarded)}
	return {"title": BoardNode.TYPE_INFO[type]["name"], "text": WORDS.get(type, "")}


static func _chest_words(player: PlayerData, guarded: bool) -> String:
	var usual := SpaceEffects.CHEST_GOLD_BASE + SpaceEffects.CHEST_GOLD_PER_LEVEL * player.level
	var words := "About %d gold or a good item. It takes an exact landing." % player.found_gold(usual)
	if guarded:
		words += " A monster guards it: win the fight and the chest opens at once."
	return words
