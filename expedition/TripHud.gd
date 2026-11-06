class_name TripHud
extends KitPanel
## The strip along the bottom while a trip plays: the day, health, food, bag and gold.
## Food turns gold once they ask to come home, because that is the lord's cue.
## Each part has a tip with the exact numbers (rule U3).

const BAR_WIDTH := 200.0
const FOOD_WORDS_WIDTH := 96.0
const DAY_WIDTH := 112.0
const GAP := 18

var day_label: Label
var hp_bar: KitBar
var food_bar: KitBar
var food_words: Label
var bag: KitChip
var gold: KitChip

var _trip: Expedition
# The food they set out with, which is a full bar.
var _food_full := 1


func _init(trip: Expedition, stage: Stage) -> void:
	super()
	_trip = trip
	_food_full = maxi(stage.food_for(trip.person), 1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	body.add_child(row)
	day_label = Kit.text("", DAY_WIDTH, &"Heading")
	day_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(day_label)
	hp_bar = _bar(row, Kit.HEALTH, "heart")
	food_bar = _bar(row, Kit.SUPPLY, "food")
	food_words = Kit.text("")
	food_words.custom_minimum_size.x = FOOD_WORDS_WIDTH
	food_words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(food_words)
	bag = _chip(row, "bag")
	gold = _chip(row, "coin")


func _ready() -> void:
	refresh(false)
	_trip.player.changed.connect(refresh)


## Shows the trip as it stands.
func refresh(slide := true) -> void:
	var player := _trip.player
	var max_hp: int = player.get_stat("max_hp")
	day_label.text = "Day %d" % maxi(_trip.day, 1)
	hp_bar.set_amount(player.hp, max_hp, slide)
	food_bar.set_amount(_trip.food_left, _food_full, slide)
	food_words.text = "No food!" if _trip.food_left == 0 else _days(_trip.food_left)
	food_words.modulate = _food_color()
	bag.set_amount(player.inventory.size(), slide)
	gold.set_amount(player.gold, slide)
	Tips.attach(hp_bar, "Health", "%d of %d HP." % [player.hp, max_hp])
	Tips.attach(food_bar, "Food", _food_tip())
	Tips.attach(bag, "Bag", "%d of %d places used." % [player.inventory.size(), PlayerData.INVENTORY_SIZE])
	Tips.attach(gold, "Gold found", "%d gold. It only counts if they get home." % player.gold)


## Shows an empty health bar, because a defeat refills HP for the old board game.
func show_beaten() -> void:
	hp_bar.set_amount(0.0, 1.0)


func _food_color() -> Color:
	if _trip.food_left == 0:
		return Kit.DANGER.lightened(0.3)
	return Kit.GOLD if _trip.asked_home else Color.WHITE


func _food_tip() -> String:
	var home := "About %s from the Portal." % _days(ceili(_trip.brain.days_home()))
	if _trip.food_left > 0:
		return "Food for %s. One roll of the die is one day. %s" % [_days(_trip.food_left), home]
	return "No food left. They lose health every day, and grow weak. %s" % home


func _days(count: int) -> String:
	return "1 day" if count == 1 else "%d days" % count


func _bar(row: Control, color: Color, icon_name: String) -> KitBar:
	var bar := KitBar.new(color, Kit.icon(icon_name))
	bar.width = BAR_WIDTH
	bar.focus_mode = Control.FOCUS_ALL
	row.add_child(bar)
	return bar


func _chip(row: Control, icon_name: String) -> KitChip:
	var chip := KitChip.new(icon_name)
	chip.focus_mode = Control.FOCUS_ALL
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	return chip
