class_name Quest
extends RefCounted
## The royal quest, with no UI. The crown posts one every week. Everyone sees the
## same quest, the first to finish it takes the reward, and whatever is unfinished
## at the end of the week is dropped.
##
## GameState.quest holds plain values, so that SaveGame can store it:
##   kind     a Kind
##   target   the space id of a VISIT quest, else -1
##   place    the name of that space
##   needed   how many times the deed must be done
##   reward   gold
##   winner   the name of the player who finished it, or ""

enum Kind { HUNT, FREE, VISIT, DUEL }

const HUNT_NEEDED := 2
## The reward is this much, plus this much per week.
const REWARD_BASE := 150
const REWARD_PER_WEEK := 50


## Posts this week's quest and clears everyone's progress. Uses GameState.rng.
static func new_week() -> void:
	for player in GameState.players:
		player.quest_progress = 0
	var kinds: Array[Kind] = [Kind.HUNT]
	if not Town.unclaimed().is_empty():
		kinds.append(Kind.FREE)
	if not Town.ids().is_empty():
		kinds.append(Kind.VISIT)
	if GameState.players.size() > 1:
		kinds.append(Kind.DUEL)
	var kind := kinds[GameState.rng.randi_range(0, kinds.size() - 1)]
	GameState.quest = {
		"kind": kind,
		"target": -1,
		"place": "",
		"needed": HUNT_NEEDED if kind == Kind.HUNT else 1,
		"reward": REWARD_BASE + REWARD_PER_WEEK * GameState.get_week(),
		"winner": "",
	}
	if kind == Kind.VISIT:
		var towns := Town.ids()
		var target := towns[GameState.rng.randi_range(0, towns.size() - 1)]
		GameState.quest["target"] = target
		GameState.quest["place"] = Town.town_name(target)


## Counts a deed. Returns the gold won if this finished the quest, or 0.
static func record(player: PlayerData, kind: Kind, target := -1) -> int:
	var quest := GameState.quest
	if quest.is_empty() or quest["winner"] != "" or quest["kind"] != kind or quest["target"] != target:
		return 0
	player.quest_progress += 1
	if player.quest_progress < quest["needed"]:
		return 0
	quest["winner"] = player.player_name
	return quest["reward"]


## What the quest asks for, as a short order.
static func task_text() -> String:
	var quest := GameState.quest
	if quest.is_empty():
		return ""
	match quest["kind"]:
		Kind.HUNT:
			return "Defeat %d monsters" % quest["needed"]
		Kind.FREE:
			return "Free any town"
		Kind.VISIT:
			return "Reach %s" % quest["place"]
	return "Defeat a rival"


## What `player` should read about the quest right now.
static func status_text(player: PlayerData) -> String:
	var quest := GameState.quest
	if quest.is_empty():
		return ""
	if quest["winner"] != "":
		return "Royal quest: %s\nWon by %s" % [task_text(), quest["winner"]]
	var text := "Royal quest: %s\nReward %d G" % [task_text(), quest["reward"]]
	if quest["needed"] > 1:
		text += " (%d/%d done)" % [player.quest_progress, quest["needed"]]
	return text
