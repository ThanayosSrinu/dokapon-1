extends Node
## The player's choices, kept between games. Registered as the "Settings" autoload.
## They are written beside the saves, so nothing lands on C: during development.
## Change a value, then call apply() to put it into effect and save().

const FILE_NAME := "settings.cfg"
const SECTION := "options"
## Volumes run from 0 to 100, in steps of this.
const VOLUME_STEP := 10
## How much faster the game runs during CPU turns. 1 leaves it alone.
const CPU_SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const QUIETEST_DB := -36.0

var music_volume := 70
var sfx_volume := 80
var cpu_speed := 1.0
var fullscreen := false
var screen_shake := true


func _ready() -> void:
	load_file()
	apply()


## Puts every setting into effect, except cpu_speed, which GameController reads.
func apply() -> void:
	_set_bus("Music", music_volume)
	_set_bus("Sfx", sfx_volume)
	# A headless run has no window to change.
	if DisplayServer.get_name() == "headless":
		return
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	# Left alone otherwise, so changing a volume doesn't undo a maximized window.
	if fullscreen != is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED)


## Reads the file. Anything missing or out of range falls back to a safe value, so
## a hand-edited file can't break the game.
func load_file() -> void:
	var file := ConfigFile.new()
	if file.load(_path()) != OK:
		return
	music_volume = _volume(file.get_value(SECTION, "music_volume", music_volume))
	sfx_volume = _volume(file.get_value(SECTION, "sfx_volume", sfx_volume))
	var speed: Variant = file.get_value(SECTION, "cpu_speed", cpu_speed)
	cpu_speed = float(speed) if speed is float and CPU_SPEEDS.has(speed) else 1.0
	fullscreen = _flag(file.get_value(SECTION, "fullscreen", fullscreen), false)
	screen_shake = _flag(file.get_value(SECTION, "screen_shake", screen_shake), true)


func save() -> void:
	var file := ConfigFile.new()
	file.set_value(SECTION, "music_volume", music_volume)
	file.set_value(SECTION, "sfx_volume", sfx_volume)
	file.set_value(SECTION, "cpu_speed", cpu_speed)
	file.set_value(SECTION, "fullscreen", fullscreen)
	file.set_value(SECTION, "screen_shake", screen_shake)
	file.save(_path())


func _path() -> String:
	return SaveGame.folder().path_join(FILE_NAME)


func _volume(value: Variant) -> int:
	if not (value is int or value is float):
		return 70
	return clampi(snappedi(int(value), VOLUME_STEP), 0, 100)


func _flag(value: Variant, fallback: bool) -> bool:
	return value if value is bool else fallback


## Volume 0 mutes the bus. Otherwise it follows a curve that sounds even to the ear.
func _set_bus(bus_name: String, volume: int) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(bus, volume == 0)
	AudioServer.set_bus_volume_db(bus, lerpf(QUIETEST_DB, 0.0, sqrt(volume / 100.0)))
