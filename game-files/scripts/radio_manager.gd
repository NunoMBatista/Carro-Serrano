extends Node
## Radio Manager autoload. Persists radio state and audio playback.

const SONGS = [
	"res://assets/audio/radio/Alex Jones.mp3",
	"res://assets/audio/radio/Clair de Lune.mp3",
	"res://assets/audio/radio/Cobarde, Feliz Natal.mp3",
	"res://assets/audio/radio/Interlude.mp3",
	"res://assets/audio/radio/Jesu Bleibet Meine Freude.mp3",
	"res://assets/audio/radio/Parece Parece.mp3",
	"res://assets/audio/radio/Radio Comercial.mp3",
	#"res://assets/audio/radio/radio_static.mp3",
	"res://assets/audio/radio/Tempo Para Cantar.mp3"
]

const STATIC_PATH = "res://assets/audio/radio/radio_static.mp3"
const STATIC_MIN_DURATION := 0.3  # minimum static duration in seconds
const STATIC_MAX_DURATION := 1.2  # maximum static duration in seconds

# Base tracks (mood music)
const BASE_TRACK_HAPPY = "res://assets/audio/base_tracks/happy_song.mp3"
const BASE_TRACK_NEUTRAL = "res://assets/audio/base_tracks/neutral_song.mp3"
const BASE_TRACK_SAD = "res://assets/audio/base_tracks/sad_song.mp3"

# Empathy thresholds for mood music
const EMPATHY_HIGH_THRESHOLD := 60  # Above this = happy
const EMPATHY_LOW_THRESHOLD := 40   # Below this = sad, between = neutral

var is_on: bool = false
var current_song_idx: int = 0
var volume: float = 0.5  # 0.0 to 1.0
var _is_playing_static: bool = false
var _dialogue_active: bool = false
var radio_disabled: bool = false  # When true, radio cannot be turned on (torre scene)

var _audio_player: AudioStreamPlayer      # Radio songs
var _static_player: AudioStreamPlayer     # Radio static
var _base_player: AudioStreamPlayer       # Mood/base tracks
var _static_timer: Timer
var _current_base_track: String = ""

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)
	_audio_player.finished.connect(_on_song_finished)

	_static_player = AudioStreamPlayer.new()
	_static_player.bus = "Master"
	_static_player.stream = load(STATIC_PATH)
	add_child(_static_player)

	_base_player = AudioStreamPlayer.new()
	_base_player.bus = "Master"
	add_child(_base_player)
	_base_player.finished.connect(_on_base_track_finished)

	_static_timer = Timer.new()
	_static_timer.one_shot = true
	_static_timer.timeout.connect(_on_static_finished)
	add_child(_static_timer)

	_update_volume()

	# Connect to dialogue signals after tree is ready
	call_deferred("_connect_dialogue_signals")

	# Start base track if radio is off
	_update_base_track()

func _connect_dialogue_signals() -> void:
	var df = get_node_or_null("/root/DialogueFlow")
	if df:
		print("RadioManager: Connecting to DialogueFlow signals")
		df.dialogue_started.connect(_on_dialogue_started)
		df.dialogue_ended.connect(_on_dialogue_ended)
		print("RadioManager: Connected dialogue_started and dialogue_ended signals")
		# Also connect to empathy changes to update base track when needed
		if df.has_signal("empathy_changed"):
			df.empathy_changed.connect(_on_empathy_changed)
			print("RadioManager: Connected empathy_changed signal")
	else:
		push_warning("RadioManager: DialogueFlow not found, retrying...")
		get_tree().create_timer(0.1).timeout.connect(_connect_dialogue_signals)

func _on_empathy_changed(_new_empathy: int) -> void:
	# Only update base track when empathy actually changes
	_update_base_track()

func set_volume(value: float) -> void:
	volume = clamp(value, 0.0, 1.0)
	_update_volume()

func _update_volume() -> void:
	_audio_player.volume_db = linear_to_db(volume)
	_static_player.volume_db = linear_to_db(volume)
	_base_player.volume_db = linear_to_db(volume)

func toggle_power() -> void:
	# Don't allow turning on radio if disabled (torre scene)
	if radio_disabled and not is_on:
		print("RadioManager: Radio is disabled in this scene")
		return

	is_on = not is_on
	print("RadioManager: toggle_power called, is_on=", is_on, " _dialogue_active=", _dialogue_active)
	if is_on:
		_stop_base_track()
		_play_with_static()
	else:
		_stop_all()
		_update_base_track()

func next_song() -> void:
	current_song_idx = (current_song_idx + 1) % SONGS.size()
	print("RadioManager: next_song called, is_on=", is_on, " _dialogue_active=", _dialogue_active)
	if is_on:
		_play_with_static()

func prev_song() -> void:
	current_song_idx = (current_song_idx - 1 + SONGS.size()) % SONGS.size()
	print("RadioManager: prev_song called, is_on=", is_on, " _dialogue_active=", _dialogue_active)
	if is_on:
		_play_with_static()

func _play_with_static() -> void:
	print("RadioManager: _play_with_static called")
	_stop_all()
	_stop_base_track()
	_is_playing_static = true

	# Play static from random position for random duration
	var static_stream: AudioStream = _static_player.stream
	if static_stream == null:
		push_warning("RadioManager: Static audio not found at " + STATIC_PATH)
		_is_playing_static = false
		_play_current_song_immediate()
		return

	var static_length: float = static_stream.get_length()
	var static_duration := randf_range(STATIC_MIN_DURATION, STATIC_MAX_DURATION)
	var start_pos := randf_range(0.0, max(0.0, static_length - static_duration))

	_static_player.play(start_pos)
	_static_timer.start(static_duration)

func _on_static_finished() -> void:
	print("RadioManager: _on_static_finished called")
	_static_player.stop()
	_is_playing_static = false
	_play_current_song_immediate()

func _play_current_song_immediate() -> void:
	print("RadioManager: _play_current_song_immediate called, _dialogue_active=", _dialogue_active)
	# If dialogue is active, don't play radio, play base track instead
	if _dialogue_active:
		print("RadioManager: Dialogue is active, not playing radio")
		_update_base_track()
		return

	var stream = load(SONGS[current_song_idx])
	if stream == null:
		push_warning("RadioManager: Song not found at " + SONGS[current_song_idx])
		return

	_audio_player.stream = stream

	# Calculate where the song "would be" if it had been playing since game start
	var song_duration: float = stream.get_length()
	var game_time := Time.get_ticks_msec() / 1000.0  # seconds since game start
	var start_position := fmod(game_time, song_duration)

	_audio_player.play(start_position)
	print("RadioManager: Started playing song: ", SONGS[current_song_idx], " at position ", start_position)

func _stop_all() -> void:
	_audio_player.stop()
	_static_player.stop()
	_static_timer.stop()
	_is_playing_static = false

func get_current_song_name() -> String:
	if _is_playing_static:
		return "~ tuning ~"
	if is_on:
		return SONGS[current_song_idx].get_file().get_basename()
	return "-- OFF --"

func _on_song_finished() -> void:
	if is_on and not _is_playing_static and not _dialogue_active:
		next_song()

# ---- Base Track (Mood Music) System ----

func _get_empathy() -> int:
	var df = get_node_or_null("/root/DialogueFlow")
	if df:
		return df.empathy
	return 50  # Default neutral

func _get_target_base_track() -> String:
	var empathy := _get_empathy()
	if empathy >= EMPATHY_HIGH_THRESHOLD:
		return BASE_TRACK_HAPPY
	elif empathy < EMPATHY_LOW_THRESHOLD:
		return BASE_TRACK_SAD
	else:
		return BASE_TRACK_NEUTRAL

func _should_play_base_track() -> bool:
	# Play base track if radio is off OR if dialogue is active
	return not is_on or _dialogue_active

func _update_base_track() -> void:
	if not _should_play_base_track():
		_stop_base_track()
		return

	var target_track := _get_target_base_track()

	# If already playing the correct track, do nothing
	if _current_base_track == target_track and _base_player.playing:
		return

	# Switch to new track
	_current_base_track = target_track
	var stream = load(target_track)
	if stream == null:
		push_warning("RadioManager: Base track not found at " + target_track)
		return

	_base_player.stream = stream
	_base_player.play()

func _stop_base_track() -> void:
	_base_player.stop()
	_base_player.volume_db = linear_to_db(volume)  # Reset volume for next time
	_current_base_track = ""

func _on_base_track_finished() -> void:
	# Loop the base track
	if _should_play_base_track():
		_base_player.play()

func _on_dialogue_started() -> void:
	print("RadioManager: Dialogue started, setting _dialogue_active=true")
	_dialogue_active = true
	# Pause radio and play base track
	if is_on:
		print("RadioManager: Radio is on, stopping all audio")
		_stop_all()
	_update_base_track()

func _on_dialogue_ended(_resource = null) -> void:
	print("RadioManager: _on_dialogue_ended CALLED! radio is_on=", is_on, " resource=", _resource, " setting _dialogue_active=false")
	_dialogue_active = false

	if is_on:
		print("RadioManager: Radio is on, crossfading to radio")
		# Crossfade: fade out base track, fade in radio
		_crossfade_to_radio()
	else:
		print("RadioManager: Radio is off, updating base track")
		_stop_base_track()
		_update_base_track()

const FADE_DURATION := 1.5  # seconds for crossfade

func _crossfade_to_radio() -> void:
	print("RadioManager: _crossfade_to_radio called, current_song_idx=", current_song_idx)
	# Start radio at silent volume
	var stream = load(SONGS[current_song_idx])
	if stream == null:
		push_warning("RadioManager: Song not found at " + SONGS[current_song_idx])
		_stop_base_track()
		return

	_audio_player.stream = stream

	# Calculate where the song "would be" if it had been playing since game start
	var song_duration: float = stream.get_length()
	var game_time := Time.get_ticks_msec() / 1000.0
	var start_position := fmod(game_time, song_duration)

	_audio_player.volume_db = -80.0  # Start silent
	_audio_player.play(start_position)

	# Create tween for crossfade
	var tween := create_tween()
	tween.set_parallel(true)

	# Fade out base track
	tween.tween_property(_base_player, "volume_db", -80.0, FADE_DURATION)
	# Fade in radio
	tween.tween_property(_audio_player, "volume_db", linear_to_db(volume), FADE_DURATION)

	# When done, stop base track
	tween.set_parallel(false)
	tween.tween_callback(_stop_base_track)
	print("RadioManager: Crossfade tween started, will play song: ", SONGS[current_song_idx])


func fade_out(duration: float = 2.0) -> void:
	"""Fade out all audio over the specified duration"""
	var tween = create_tween()
	tween.set_parallel(true)

	# Fade out all audio players
	if _audio_player.playing:
		tween.tween_property(_audio_player, "volume_db", -80.0, duration)
	if _static_player.playing:
		tween.tween_property(_static_player, "volume_db", -80.0, duration)
	if _base_player.playing:
		tween.tween_property(_base_player, "volume_db", -80.0, duration)

	# Stop all players after fade completes
	tween.set_parallel(false)
	tween.tween_callback(_stop_all)


func switch_to_base_track() -> void:
	"""Turn off radio and switch to empathy-based base track (for torre scene)"""
	radio_disabled = true  # Disable radio in torre scene
	if is_on:
		is_on = false
		_stop_all()
	_update_base_track()
	print("RadioManager: Switched to base track mode, radio disabled")
