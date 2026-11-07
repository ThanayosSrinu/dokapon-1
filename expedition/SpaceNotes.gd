class_name SpaceNotes
extends RefCounted
## What each kind of space does on a trip, in words for the detail box. The numbers come
## from the rules, so they stay true when the rules are tuned. A space is told as it stands
## on this trip, so a beaten monster reads as empty road.

const WORDS := {
	BoardNode.NodeType.NORMAL: "A quiet stretch of road. Nothing happens here.",
	BoardNode.NodeType.BATTLE: "A monster blocks the road. Walking onto it ends the walk and starts a fight.",
	BoardNode.NodeType.PORTAL: "The only way home. They must land on it exactly.",
}


## The name and the words for space `id`, as they stand right now.
static func of(trip: Expedition, id: int) -> Dictionary:
	var type := trip.type_at(id)
	return {"title": BoardNode.TYPE_INFO[type]["name"], "text": _words(trip, type)}


static func _words(trip: Expedition, type: BoardNode.NodeType) -> String:
	if type == BoardNode.NodeType.TREASURE:
		return _chest_words(trip.player)
	return WORDS.get(type, "")


static func _chest_words(player: PlayerData) -> String:
	var usual := SpaceEffects.CHEST_GOLD_BASE + SpaceEffects.CHEST_GOLD_PER_LEVEL * player.level
	return "About %d gold or a good item. A monster may guard it. It takes an exact landing." % player.found_gold(usual)
