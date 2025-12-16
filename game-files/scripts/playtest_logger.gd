extends Node
## Playtest logging singleton. Add to autoloads as "PlaytestLogger".

var player_id: String
var current_empathy: int = 50
var hitchhiker_count: int = 0
var _file: FileAccess
var _log_dir := "user://playtesting_results/"
var _start_time: int

func _ready() -> void:
	player_id = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "")
	_start_time = Time.get_ticks_msec()
	_ensure_dir()
	var path = _log_dir + "session_" + player_id + ".csv"
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file:
		_file.store_line("user_id, current_empathy, hitchhiker_count, time, category, typeof, payload")
		print("PlaytestLogger: Writing to ", ProjectSettings.globalize_path(path))
	else:
		push_error("PlaytestLogger: Failed to open file: " + str(FileAccess.get_open_error()))

func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(_log_dir):
		DirAccess.make_dir_absolute(_log_dir)

func _get_timestamp() -> String:
	var elapsed_ms := Time.get_ticks_msec() - _start_time
	var secs := (elapsed_ms / 1000) % 60
	var mins := (elapsed_ms / 60000) % 60
	var hrs := elapsed_ms / 3600000
	return "%02d:%02d:%02d" % [hrs, mins, secs]

func log_event(event_type: String, payload: String) -> void:
	_write_line("event", event_type, payload)

func log_action(action_type: String, payload: String) -> void:
	_write_line("action", action_type, payload)

func log_state(state_type: String, payload: String) -> void:
	_write_line("state", state_type, payload)

func _write_line(category: String, typeof: String, payload: String) -> void:
	if _file:
		var line := "%s, %d,%d, %s, %s, %s, \"%s\"" % [
			player_id, current_empathy, hitchhiker_count,
			_get_timestamp(), category, typeof, payload
		]
		_file.store_line(line)
		_file.flush()

func set_empathy(value: int) -> void:
	var delta := value - current_empathy
	current_empathy = value
	log_state("update_empathy", "%+d" % delta if delta != 0 else "0")

func set_hitchhiker_count(value: int) -> void:
	hitchhiker_count = value
	log_state("update_progress", "Hitchhiker %d In-Car" % value)

func _exit_tree() -> void:
	if _file:
		_file.close()
