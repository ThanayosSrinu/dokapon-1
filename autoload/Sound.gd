extends Node
## All of the game's sound. Registered as the "Sound" autoload.
##     Sound.play("coin")      plays a sound effect
##     Sound.music("battle")   crossfades to a tune, or does nothing if it is playing
##     Sound.music("")         fades the tune out
## Every button in the game clicks by itself: this script watches for new buttons.
## The sounds come from tools/make_sound.py. None of this touches GameState.rng, so
## sound can't change how a seeded game plays out.

## A file in assets/custom/sound for each name.
const EFFECTS: Array[String] = [
	"back", "battle_start", "click", "coin", "coin_loss", "counter", "crown", "defeat",
	"dice_land", "dice_roll", "fanfare", "flee", "heal", "hit", "hover", "item",
	"level_up", "magic", "miss", "step", "town", "trap", "victory", "week", "whoosh",
]
const TUNES: Array[String] = ["battle", "board", "shop", "title"]
const FOLDER := "res://assets/custom/sound/%s.wav"
## How many sound effects can play at once.
const VOICES := 12
## Seconds before the same sound may start again, so fast games don't buzz.
const REPEAT_GAP := 0.05
const FADE_SECONDS := 0.5
const SILENT_DB := -40.0
const PITCH_SPREAD := 0.04
## Sounds heard often enough to want a little variety.
const VARIED: Array[String] = ["coin", "hit", "step"]

var _effects := {}
var _tunes := {}
var _voices: Array[AudioStreamPlayer] = []
var _deck: AudioStreamPlayer
var _other_deck: AudioStreamPlayer
var _tune := ""
var _last_played := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in EFFECTS:
		_effects[sound] = load(FOLDER % sound)
	for tune in TUNES:
		_tunes[tune] = load(FOLDER % tune)
	for index in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = "Sfx"
		add_child(voice)
		_voices.append(voice)
	_deck = _add_deck()
	_other_deck = _add_deck()
	get_tree().node_added.connect(_on_node_added)


func _input(event: InputEvent) -> void:
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if event.is_action_pressed(action) and get_viewport().gui_get_focus_owner() != null:
			play("hover")
			return


## Plays a sound effect. An unknown name is a mistake in the code, so it complains.
func play(sound: String) -> void:
	if not _effects.has(sound):
		push_error("Sound: no effect called '%s'." % sound)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < REPEAT_GAP:
		return
	_last_played[sound] = now
	var voice := _free_voice()
	voice.stream = _effects[sound]
	voice.pitch_scale = 1.0
	if VARIED.has(sound):
		voice.pitch_scale += randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	voice.play()


## Crossfades to `tune`. Starting what is already playing changes nothing.
func music(tune: String) -> void:
	if tune == _tune:
		return
	if tune != "" and not _tunes.has(tune):
		push_error("Sound: no tune called '%s'." % tune)
		return
	_tune = tune
	var leaving := _deck
	_deck = _other_deck
	_other_deck = leaving
	var tween := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tween.tween_property(leaving, "volume_db", SILENT_DB, FADE_SECONDS)
	tween.chain().tween_callback(func() -> void:
			if leaving != _deck:
				leaving.stop())
	if tune != "":
		_deck.stream = _tunes[tune]
		_deck.volume_db = SILENT_DB
		_deck.play()
		var rise := create_tween().set_ignore_time_scale(true)
		rise.tween_property(_deck, "volume_db", 0.0, FADE_SECONDS)


## What is playing now, or "".
func current_tune() -> String:
	return _tune


func _add_deck() -> AudioStreamPlayer:
	var deck := AudioStreamPlayer.new()
	deck.bus = "Music"
	add_child(deck)
	return deck


## An idle voice, or the one that has been playing longest.
func _free_voice() -> AudioStreamPlayer:
	var oldest := _voices[0]
	for voice in _voices:
		if not voice.playing:
			return voice
		if voice.get_playback_position() > oldest.get_playback_position():
			oldest = voice
	return oldest


func _on_node_added(node: Node) -> void:
	# A button can leave the tree and come back, and must only click once.
	if node is BaseButton and not node.has_meta("clicks"):
		var button: BaseButton = node
		button.set_meta("clicks", true)
		button.pressed.connect(play.bind("click"))
		button.mouse_entered.connect(_on_button_hovered.bind(button))


func _on_button_hovered(button: BaseButton) -> void:
	if not button.disabled:
		play("hover")
