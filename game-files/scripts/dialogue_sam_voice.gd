extends Node
class_name DialogueSAMVoice
## Retro-consistent speech using the GDSAM addon (Software Automatic Mouth).
## Attach this as a child of DialogueLabel (already nested under the dialogue balloon).

@export var enabled: bool = true
@export var target_label_path: NodePath
@export var speak_per_word: bool = true
@export var speak_full_line_when_finished: bool = false
@export var stop_on_new_line: bool = true
@export var stop_on_skip: bool = true

# SAM voice character controls (0-255 classic ranges)
@export_range(0, 255, 1) var pitch: int = 64    ## higher = squeakier
@export_range(0, 255, 1) var speed: int = 72    ## higher = faster
@export_range(0, 255, 1) var throat: int = 128  ## timbre
@export_range(0, 255, 1) var mouth: int = 128   ## timbre
@export_range(0.0, 4.0, 0.01) var gain: float = 0.05 ## post gain multiplier

@export var separators := " \t\n.,;:!?\"'()[]{}-"

var _label: DialogueLabel
var _current_word: String = ""
var _word_flushed: bool = false
var _player: AudioStreamPlayer
var _sam: GDSAM

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_sam = GDSAM.new()
	add_child(_sam)
	_connect_label()

func _connect_label() -> void:
	if target_label_path != NodePath("") and has_node(target_label_path):
		_label = get_node(target_label_path) as DialogueLabel
	else:
		_label = get_parent() as DialogueLabel if get_parent() is DialogueLabel else null
	if _label:
		_label.spoke.connect(_on_spoke)
		_label.finished_typing.connect(_on_finished)
		_label.skipped_typing.connect(_on_skipped)
		_label.paused_typing.connect(_on_paused)

func _on_spoke(letter: String, _idx: int, _speed: float) -> void:
	if _idx == 0:
		_word_flushed = false
	if not enabled or not speak_per_word:
		return
	# Don't speak any words from lines that start with **
	if _is_stage_direction():
		return
	if letter in separators:
		if _current_word.length() > 0:
			_speak(_current_word)
			_current_word = ""
	else:
		_word_flushed = false
		_current_word += letter

func _on_paused(_duration: float) -> void:
	if not _is_stage_direction():
		_flush_pending_word()

func _on_finished() -> void:
	if stop_on_new_line:
		_stop()
	if not _is_stage_direction():
		_flush_pending_word()
	if enabled and speak_full_line_when_finished and not _is_stage_direction():
		if _label and _label.dialogue_line:
			_speak(str(_label.dialogue_line.text))

func _on_skipped() -> void:
	if _is_stage_direction():
		_current_word = ""
		_stop()
		return
	var flushed := _flush_pending_word()
	if stop_on_skip and not (flushed or speak_full_line_when_finished):
		_stop()

func _flush_pending_word() -> bool:
	if _word_flushed:
		return true
	if not enabled or not speak_per_word:
		_current_word = ""
		return false

	var word := ""
	if _label:
		var text: String = _label.get_parsed_text()
		var end_idx: int = min(_label.visible_characters, text.length())
		var visible := text.substr(0, end_idx)
		var tail := visible.length() - 1
		while tail >= 0 and visible[tail] in separators:
			tail -= 1
		if tail >= 0:
			var start := tail
			while start >= 0 and not visible[start] in separators:
				start -= 1
			word = visible.substr(start + 1, tail - start)
	if word == "" and _current_word.length() > 0:
		word = _current_word
	if word == "":
		return false
	_current_word = ""
	_word_flushed = true
	_speak(word)
	return true

func _speak(text: String) -> void:
	if not enabled:
		return
	if _sam == null:
		push_warning("GDSAM node not instantiated; ensure the plugin is enabled.")
		return
	text = text.strip_edges()
	if text == "":
		return
	_stop()
	_sam.pitch = pitch
	_sam.speed = speed
	_sam.throat = throat
	_sam.mouth = mouth
	_player.volume_db = _safe_linear_to_db(gain)
	_sam.speak(_player, text)

func _stop() -> void:
	if _player:
		_player.stop()

func _safe_linear_to_db(v: float) -> float:
	return linear_to_db(max(v, 0.0001))

func _is_stage_direction() -> bool:
	if not _label:
		return false
	var line = _label.dialogue_line if _label.dialogue_line else null
	if not line:
		return false
	# Check if the text starts with ** (stage directions)
	var text = str(line.text).strip_edges()
	return text.begins_with("**")
