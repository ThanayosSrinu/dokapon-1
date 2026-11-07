class_name SpaceNotes
extends RefCounted
## What each kind of space does on a trip, in words for the detail box. The numbers come
## from the rules, so they stay true when the rules are tuned.

const WORDS := {
	BoardNode.NodeType.NORMAL: "A quiet stretch of road. Nothing happens here.",
	BoardNode.NodeType.EVENT: "Something unexpected: a feast, a storm, an ambush or a kind stranger.",
	BoardNode.NodeType.ITEM: "Holds something useful for the bag, if there is room.",
	BoardNode.NodeType.BATTLE: "A monster waits here. Beating it pays gold and experience.",
	BoardNode.NodeType.TRAP: "Spikes, a thief, a snare or a trapdoor. A quick step can dodge it.",
	BoardNode.NodeType.PORTAL: "The only way home. They must land on it exactly.",
}


## The name and the words for space `id`, as they stand right now.
static func of(trip: Expedition, id: int) -> Dictionary:
	var type := trip.map.type_of(id)
	return {"title": BoardNode.TYPE_INFO[type]["name"], "text": _words(trip, id, type)}


static func _words(trip: Expedition, id: int, type: BoardNode.NodeType) -> String:
	var player := trip.player
	var rest := roundi(player.rest_share * 100.0)
	match type:
		BoardNode.NodeType.GOLD:
			var usual := SpaceEffects.GOLD_BASE + SpaceEffects.GOLD_PER_LEVEL * player.level
			return "Pays about %d gold." % player.found_gold(usual)
		BoardNode.NodeType.MAGIC:
			return "Gives back %d%% of their MP, and may teach a spell." % rest
		BoardNode.NodeType.SHRINE:
			return "Gives back %d%% of their HP and MP." % rest
		BoardNode.NodeType.TREASURE:
			return _chest_words(player, id)
	return WORDS.get(type, "")


static func _chest_words(player: PlayerData, id: int) -> String:
	var days := SpaceEffects.chest_days_left(id)
	if days > 0:
		return "Empty. It fills again in %s." % TownData.days_words(days)
	var usual := SpaceEffects.CHEST_GOLD_BASE + SpaceEffects.CHEST_GOLD_PER_LEVEL * player.level
	return "About %d gold or a good item. A monster may guard it." % player.found_gold(usual)
