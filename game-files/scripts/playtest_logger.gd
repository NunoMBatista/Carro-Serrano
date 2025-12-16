extends Node

const LOG_DIR := "res://playtesting_results"
const CRITICAL_THRESHOLD := 25

var log_file_path: String = ""
var user_id: String = "unassigned"
var empathy: int = 0
var hitchhiker_count: int = 0

var _session_start_timestamp: String = ""
var _absolute_log_dir: String = ""
var _decision_timer_start_ms: int = -1
var _decision_context: Dictionary = {}
var _in_critical_state: bool = false

func _ready() -> void:
	_session_start_timestamp = _timestamp()
	user_id = _session_start_timestamp
	_absolute_log_dir = ProjectSettings.globalize_path(LOG_DIR)
	log_file_path = "%s/session_%s.csv" % [_absolute_log_dir, _session_start_timestamp]
	_ensure_log_dir()
	_ensure_file()
	_cleanup_non_csv()
	log_event("session_start", "session_started")


func _exit_tree() -> void:
	_cleanup_non_csv()

	if Engine.has_singleton("DialogueManager"):
		var dm = Engine.get_singleton("DialogueManager")
		dm.dialogue_started.connect(_on_dialogue_started)
		dm.dialogue_ended.connect(_on_dialogue_ended)


func set_user_id(id_value: Variant) -> void:
	user_id = str(id_value)


func set_empathy(value: int) -> void:
	empathy = clamp(value, 0, 100)
	_update_critical_state()
	log_state("set_empathy", str(empathy))


func change_empathy(delta: int) -> void:
	empathy = clamp(empathy + delta, 0, 100)
	_update_critical_state()
	log_state("update_empathy", str(delta))


func set_hitchhiker_count(value: int) -> void:
	hitchhiker_count = max(0, value)
	log_state("update_progress", "Hitchhiker %d" % hitchhiker_count)


func increment_hitchhiker(amount: int = 1) -> void:
	set_hitchhiker_count(hitchhiker_count + amount)


func log_event(type_of: String, payload: Variant = "") -> void:
	_append_csv_line("event", type_of, payload)


func log_action(type_of: String, payload: Variant = "") -> void:
	_append_csv_line("action", type_of, payload)


func log_state(type_of: String, payload: Variant = "") -> void:
	_append_csv_line("state", type_of, payload)


func log_game_over(reason: String = "", did_win: bool = false) -> void:
	var outcome := "win" if did_win else "loss"
	var details := {"reason": reason, "outcome": outcome}
	log_event("game_over", JSON.stringify(details))


func start_decision_timer(context: Dictionary = {}) -> void:
	_decision_context = context
	_decision_timer_start_ms = Time.get_ticks_msec()


func record_dialogue_choice(response: DialogueResponse) -> void:
	var decision_ms := -1
	if _decision_timer_start_ms >= 0:
		decision_ms = Time.get_ticks_msec() - _decision_timer_start_ms
	_decision_timer_start_ms = -1

	var alignment := _detect_alignment(response)
	var payload := {
		"text": response.text,
		"alignment": alignment,
		"decision_ms": decision_ms,
		"line_id": _decision_context.get("line_id", ""),
		"line_text": _decision_context.get("line_text", "")
	}
	log_action("dialogue_choice", JSON.stringify(payload))


func log_dialogue_skipped(reason: String) -> void:
	log_action("dialogue_skip", reason)


func log_critical_recovery() -> void:
	log_event("critical_recover", "Recovered above %d" % CRITICAL_THRESHOLD)


func log_critical_drop() -> void:
	log_event("critical_drop", "Dropped below %d" % CRITICAL_THRESHOLD)


func _detect_alignment(response: DialogueResponse) -> String:
	var tag_alignment := response.get_tag_value("alignment")
	if not tag_alignment.is_empty():
		return tag_alignment
	for tag in response.tags:
		var lower_tag := tag.to_lower()
		if lower_tag.find("empath") != -1:
			return "empathetic"
		if lower_tag.find("dismiss") != -1 or lower_tag.find("non_empath") != -1:
			return "dismissive"
	return "unspecified"


func _append_csv_line(category: String, type_of: String, payload: Variant) -> void:
	var payload_text := _quote(str(payload))
	var line := "%s,%d,%d,%s,%s,%s,%s" % [user_id, empathy, hitchhiker_count, _timestamp(), category, type_of, payload_text]
	var file := FileAccess.open(log_file_path, FileAccess.READ_WRITE)
	if file == null:
		push_error("PlaytestLogger: cannot open log file at %s" % log_file_path)
		return
	file.seek_end()
	file.store_line(line)
	file.flush()


func _ensure_log_dir() -> void:
	if not DirAccess.dir_exists_absolute(_absolute_log_dir):
		DirAccess.make_dir_recursive_absolute(_absolute_log_dir)


func _ensure_file() -> void:
	if not FileAccess.file_exists(log_file_path):
		var file := FileAccess.open(log_file_path, FileAccess.WRITE)
		if file:
			file.store_line("user_id,current_empathy,hitchhiker_count,datetime,category,typeof,payload")
			file.flush()


func _cleanup_non_csv() -> void:
	var dir := DirAccess.open(_absolute_log_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			fname = dir.get_next()
			continue

		if not fname.ends_with(".csv"):
			DirAccess.remove_absolute("%s/%s" % [_absolute_log_dir, fname])

		fname = dir.get_next()

	dir.list_dir_end()


func _timestamp() -> String:
	var now := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d%02d%02d%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second]


func _quote(text: String) -> String:
	var escaped := text.replace("\"", "\"\"")
	return "\"%s\"" % escaped


func _default_user_id() -> String:
	var env_user := OS.get_environment("USER")
	if env_user != "":
		return env_user
	var device_id := OS.get_unique_id()
	return device_id if device_id != "" else "anonymous"


func _update_critical_state() -> void:
	var was_critical := _in_critical_state
	_in_critical_state = empathy < CRITICAL_THRESHOLD
	if not was_critical and _in_critical_state:
		log_critical_drop()
	elif was_critical and not _in_critical_state:
		log_critical_recovery()


func _on_dialogue_started(resource: Resource) -> void:
	log_event("dialogue_started", resource.resource_path)


func _on_dialogue_ended(resource: Resource) -> void:
	log_event("dialogue_ended", resource.resource_path)
