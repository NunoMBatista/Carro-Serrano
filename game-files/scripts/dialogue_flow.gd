extends Node

const BRANCH_GOOD := "good"
const BRANCH_BAD := "bad"
const ALIGN_POSITIVE := "positive"
const ALIGN_NEUTRAL := "neutral"
const ALIGN_NEGATIVE := "negative"

@export var empathy_threshold: int = 50
@export var empathy_gain_per_step: int = 5
@export var empathy_loss_per_step: int = 5
@export var dialogue_resource: DialogueResource
@export var good_branch_titles: Array[StringName] = []
@export var bad_branch_titles: Array[StringName] = []
@export var debug_overlay_enabled: bool = true

var hitchhiker_index: int = 0
var current_branch: String = BRANCH_GOOD
var current_step: int = 0
var is_dialogue_active: bool = false

var _debug_label: Label

func _ready() -> void:
	if Engine.has_singleton("DialogueManager"):
		Engine.get_singleton("DialogueManager").dialogue_ended.connect(_on_dialogue_ended)
	_update_debug_overlay()


func start_hitchhiker_dialogue(index: int) -> void:
	hitchhiker_index = index
	current_step = 0
	current_branch = _starting_branch()
	is_dialogue_active = true
	_start_current_title()


func handle_response_selected(response: DialogueResponse) -> bool:
	if not is_dialogue_active:
		return false
	if dialogue_resource == null:
		return false

	# If the dialogue response is already ending the conversation, let the default flow handle it.
	var next_id: String = response.next_id if response.next_id != null else ""
	var next_id_clean := next_id.strip_edges().to_lower()
	if next_id_clean == "end" or next_id_clean == "end_conversation" or next_id_clean == "":
		is_dialogue_active = false
		current_step = 0
		return false

	var alignment := _alignment_from_response(response)
	_switch_branch(alignment)
	_advance_step()
	# Explicitly end the current DM conversation before starting the next branch step.
	if Engine.has_singleton("DialogueManager"):
		Engine.get_singleton("DialogueManager").dialogue_ended.emit(dialogue_resource)
	var next_title := _current_title()
	if next_title.is_empty():
		return false
	_start_current_title(next_title)
	return true


func _starting_branch() -> String:
	var empathy := PlaytestLogger.empathy
	return BRANCH_GOOD if empathy >= empathy_threshold else BRANCH_BAD


func _switch_branch(alignment: String) -> void:
	match alignment:
		ALIGN_POSITIVE:
			current_branch = BRANCH_GOOD
		ALIGN_NEGATIVE:
			current_branch = BRANCH_BAD
		ALIGN_NEUTRAL:
			current_branch = BRANCH_GOOD if PlaytestLogger.empathy >= empathy_threshold else BRANCH_BAD
		_:
			pass


func _advance_step() -> void:
	current_step += 1


func _start_current_title(title_override: String = "") -> void:
	var title := title_override if not title_override.is_empty() else _current_title()
	if title.is_empty():
		return

	# Free the mouse so player can click dialogue options.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if current_branch == BRANCH_GOOD:
		GameManager.change_empathy(empathy_gain_per_step)
	else:
		GameManager.change_empathy(-empathy_loss_per_step)

	_update_debug_overlay()
	DialogueManager.show_example_dialogue_balloon(dialogue_resource, title)
	is_dialogue_active = true


func _current_title() -> String:
	var titles: Array[StringName] = good_branch_titles if current_branch == BRANCH_GOOD else bad_branch_titles
	if titles.is_empty():
		return ""
	if current_step >= titles.size():
		return ""
	var idx: int = clamp(current_step, 0, titles.size() - 1)
	return str(titles[idx])


func _alignment_from_response(response: DialogueResponse) -> String:
	var tag_alignment := response.get_tag_value("alignment")
	if not tag_alignment.is_empty():
		return tag_alignment.to_lower()

	for tag in response.tags:
		var lower_tag := tag.to_lower()
		if lower_tag.find("positive") != -1:
			return ALIGN_POSITIVE
		if lower_tag.find("negative") != -1:
			return ALIGN_NEGATIVE
		if lower_tag.find("neutral") != -1:
			return ALIGN_NEUTRAL

	return ALIGN_NEUTRAL


func _update_debug_overlay() -> void:
	if not debug_overlay_enabled:
		if _debug_label and is_instance_valid(_debug_label):
			_debug_label.hide()
		return

	if _debug_label == null:
		var canvas: CanvasLayer = CanvasLayer.new()
		_debug_label = Label.new()
		_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_debug_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_debug_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_debug_label.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
		_debug_label.offset_right = -10
		_debug_label.offset_left = -210
		_debug_label.offset_top = 10
		_debug_label.offset_bottom = 70
		canvas.add_child(_debug_label)
		get_tree().root.add_child(canvas)

	var branch_text: String = "GOOD" if current_branch == BRANCH_GOOD else "BAD"
	_debug_label.text = "Empathy: %d\nBranch: %s\nStep: %d" % [PlaytestLogger.empathy, branch_text, current_step]
	_debug_label.show()


func _on_dialogue_ended(_resource: Resource) -> void:
	is_dialogue_active = false
	current_step = 0
