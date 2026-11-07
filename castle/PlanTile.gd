class_name PlanTile
extends BagTile
## A tile at the Castle: a building as its next plan would make it, at half size, or the
## King's letter. A plan that can't be built yet is shown dim, with a lock while its plans
## have not come.

const PLAN_SIZE := 120.0
const LETTER_ID := "letter"
const LETTER: Texture2D = preload("res://assets/custom/castle/letter.png")
const DIM := Color(1, 1, 1, 0.45)

## A building id, or LETTER_ID.
var id := ""
var _picture: Texture2D
var _locked := false
var _ready_to_build := false


func _init(new_id := LETTER_ID, level := 1, locked := false, ready_to_build := false) -> void:
	super()
	id = new_id
	_locked = locked
	_ready_to_build = ready_to_build
	custom_minimum_size = Vector2(PLAN_SIZE, PLAN_SIZE)
	if id == LETTER_ID:
		_picture = LETTER
	else:
		_picture = load(TownBuilding.FOLDER % TownBuilding.picture_name(id, level))
	text = ""


func _draw() -> void:
	var shown := _picture.get_size() / (2.0 if id != LETTER_ID else 1.0)
	var frames: int = TownBuilding.FRAMES.get(id, 1) if id != LETTER_ID else 1
	shown.x /= frames
	var corner := Kit.snap_point((size - shown) / 2.0)
	var tint := DIM if _locked else Color.WHITE
	var region := Rect2(Vector2.ZERO, Vector2(_picture.get_width() / float(frames), _picture.get_height()))
	draw_texture_rect_region(_picture, Rect2(corner, shown), region, tint)
	if _locked:
		draw_texture(Kit.icon("lock"), Kit.snap_point((size - Vector2(Kit.ICON_SIZE, Kit.ICON_SIZE)) / 2.0))
	elif _ready_to_build:
		draw_texture(Kit.icon("check"), Vector2(size.x - Kit.ICON_SIZE - 4.0, 4.0))
	super()


## True if it shows the lock.
func is_locked() -> bool:
	return _locked
