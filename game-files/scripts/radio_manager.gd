extends Node
## Radio Manager autoload. Persists radio state and audio playback.

const SONGS = [
	"res://assets/audio/hamsterdance.mp3",
	"res://assets/audio/The Amazing PINGAS-MAN.mp3",
	"res://assets/audio/We Are Charlie Kirk.mp3",
]

var is_on: bool = false
var current_song_idx: int = 0
var volume: float = 0.5  # 0.0 to 1.0

var _audio_player: AudioStreamPlayer

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)
	_audio_player.finished.connect(_on_song_finished)
	_update_volume()

func set_volume(value: float) -> void:
	volume = clamp(value, 0.0, 1.0)
	_update_volume()

func _update_volume() -> void:
	_audio_player.volume_db = linear_to_db(volume)

func toggle_power() -> void:
	is_on = not is_on
	if is_on:
		play_current_song()
	else:
		_audio_player.stop()

func next_song() -> void:
	current_song_idx = (current_song_idx + 1) % SONGS.size()
	if is_on:
		play_current_song()

func play_current_song() -> void:
	var stream = load(SONGS[current_song_idx])
	_audio_player.stream = stream
	_audio_player.play()

func get_current_song_name() -> String:
	if is_on:
		return SONGS[current_song_idx].get_file().get_basename()
	return "-- OFF --"

func _on_song_finished() -> void:
	if is_on:
		next_song()
