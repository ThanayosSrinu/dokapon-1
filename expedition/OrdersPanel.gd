class_name OrdersPanel
extends KitPanel
## What the lord can tell an adventurer to do. It sits to one side, so the island stays in
## view, and the game does not stop for it. Each zone's button wears the zone's color on
## the island.

## The lord chose. `zone_id` is "" unless the order is a zone.
signal chosen(order: Expedition.Order, zone_id: String)
## A zone's button has the mouse or the focus. "" means none.
signal zone_pointed(id: String)

const WIDTH := 460.0
const COLUMNS := 2
const GAP := 8
const SWATCH_SIZE := 24
const SWATCH_EDGE := 2
const FACTS := "Food for %s. About %s from the Portal."
const NO_FOOD := "No food left! About %s from the Portal."

var home_button: KitButton
var roam_button: KitButton
## Zone id -> its button.
var zone_buttons := {}
## How the food and the walk home stand.
var facts: Label
## The whole island, small.
var island: ZoneMap

var _trip: Expedition
var _grid: GridContainer


func _init(trip: Expedition, overlay: ZoneOverlay) -> void:
	super("Orders for %s" % trip.player.player_name)
	_trip = trip
	custom_minimum_size.x = WIDTH
	facts = Kit.text("", WIDTH)
	body.add_child(facts)
	island = ZoneMap.new(trip, overlay)
	island.zone_pointed.connect(func(id: String) -> void: zone_pointed.emit(id))
	island.zone_clicked.connect(func(id: String) -> void: chosen.emit(Expedition.Order.ZONE, id))
	body.add_child(island)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	body.add_child(grid)
	home_button = _button(grid, "Return home", Kit.icon("door"))
	home_button.pressed.connect(func() -> void: chosen.emit(Expedition.Order.HOME, ""))
	roam_button = _button(grid, "Explore", Kit.icon("boot"))
	roam_button.pressed.connect(func() -> void: chosen.emit(Expedition.Order.ROAM, ""))
	for zone in trip.map.zones:
		var id: String = zone["id"]
		var button := _button(grid, zone["name"], _swatch(overlay.color_of(id)))
		button.pressed.connect(func() -> void: chosen.emit(Expedition.Order.ZONE, id))
		for lit_signal: Signal in [button.mouse_entered, button.focus_entered]:
			lit_signal.connect(func() -> void: zone_pointed.emit(id))
		for dark_signal: Signal in [button.mouse_exited, button.focus_exited]:
			dark_signal.connect(func() -> void: zone_pointed.emit(""))
		zone_buttons[id] = button
	_grid = grid


func _ready() -> void:
	_link_focus()
	refresh()


## Shows the order in force and how the trip stands.
func refresh() -> void:
	var home := _days(ceili(_trip.brain.days_home()))
	facts.text = NO_FOOD % home if _trip.food_left == 0 else FACTS % [_days(_trip.food_left), home]
	home_button.lit = _trip.order == Expedition.Order.HOME
	roam_button.lit = _trip.order == Expedition.Order.ROAM
	for id: String in zone_buttons:
		zone_buttons[id].lit = _trip.order == Expedition.Order.ZONE and _trip.order_zone["id"] == id
	island.queue_redraw()


func _days(count: int) -> String:
	return "1 day" if count == 1 else "%d days" % count


func _button(grid: GridContainer, words: String, picture: Texture2D) -> KitButton:
	var button := KitButton.new()
	button.kind = KitButton.Kind.SMALL
	button.text = words
	button.icon = picture
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(button)
	return button


func _swatch(color: Color) -> ImageTexture:
	var image := Image.create(SWATCH_SIZE, SWATCH_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Kit.INK)
	var inside := SWATCH_SIZE - SWATCH_EDGE * 2
	image.fill_rect(Rect2i(SWATCH_EDGE, SWATCH_EDGE, inside, inside), color)
	return ImageTexture.create_from_image(image)


# Focus moves around the grid and stays on it.
func _link_focus() -> void:
	var buttons := _grid.get_children()
	for index in buttons.size():
		var button: KitButton = buttons[index]
		var has_right := index % COLUMNS == 0 and index + 1 < buttons.size()
		var left: KitButton = buttons[index - 1] if index % COLUMNS == 1 else button
		var right: KitButton = buttons[index + 1] if has_right else button
		var up: KitButton = buttons[index - COLUMNS] if index >= COLUMNS else button
		var down: KitButton = buttons[index + COLUMNS] if index + COLUMNS < buttons.size() else button
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		button.focus_neighbor_top = button.get_path_to(up)
		button.focus_neighbor_bottom = button.get_path_to(down)

