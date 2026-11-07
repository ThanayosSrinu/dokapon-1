class_name MapPanel
extends KitPanel
## The small map of the whole island, with how the food and the walk home stand. It takes
## the bag's place while it is open, and the view pulls back to look around.

const WIDTH := 460.0
const FACTS := "Food for %s. About %s from the Portal."
const NO_FOOD := "No food left! About %s from the Portal."

## How the food and the walk home stand.
var facts: Label
var island: MiniMap

var _trip: Expedition


func _init(trip: Expedition, board: BoardManager) -> void:
	super("Map of the island")
	_trip = trip
	custom_minimum_size.x = WIDTH
	facts = Kit.text("", WIDTH)
	body.add_child(facts)
	island = MiniMap.new(trip, board)
	body.add_child(island)


## Shows how the trip stands.
func refresh() -> void:
	var home := TownData.days_words(ceili(_trip.days_home()))
	facts.text = NO_FOOD % home if _trip.food_left == 0 else FACTS % [Expedition.turns_words(_trip.food_left), home]
	island.queue_redraw()
