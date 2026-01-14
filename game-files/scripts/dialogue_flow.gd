extends Node
## Dialogue Flow autoload. Manages empathy-based branching system.

signal dialogue_started
signal dialogue_ended(resource: Resource)
signal branch_changed(new_branch: String)
signal empathy_changed(new_empathy: int)

## Empathy threshold for neutral choices (>= goes good, < goes bad)
@export var empathy_threshold: int = 50
## Empathy gained per step in good branch
@export var empathy_gain: int = 5
## Empathy lost per step in bad branch
@export var empathy_loss: int = 10
## Coefficient for empathy changes (multiplier for pretentious man dialogue)
@export var empathy_coefficient: float = 5

## Current empathy (0-100)
var empathy: int = 50:
	set(v):
		var old_empathy = empathy
		empathy = clampi(v, 0, 100)
		var logger = get_node_or_null("/root/PlaytestLogger")
		if logger:
			logger.current_empathy = empathy
		# Emit signal only if empathy actually changed
		if old_empathy != empathy:
			empathy_changed.emit(empathy)

## Current branch: "good" or "bad"
var current_branch: String = "good"
var _active: bool = false
var _debug_label: Label

## Stores the last choice made (for pre-dialogue branching)
var last_choice: String = ""

## Counter for positive choices (used in pretentious man dialogue)
var n_positive_choices: int = 0

## Public property to check if dialogue is active
var is_dialogue_active: bool = false:
	get:
		return _active

func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_setup_debug_overlay()

func _setup_debug_overlay() -> void:
	# Create a panel for background
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -250
	panel.offset_right = -10
	panel.offset_top = 10
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# Style the panel with black background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	# Create label inside panel
	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 24)
	_debug_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(_debug_label)

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(panel)
	add_child(canvas)

	# Store panel reference to control visibility
	_debug_label.set_meta("panel", panel)

func _process(_delta: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	var show_debug = gm and gm.get("debug_dialogue")
	var panel = _debug_label.get_meta("panel") as Control
	if panel:
		panel.visible = show_debug
	if show_debug:
		_debug_label.text = "DEBUG MENU\n\nEmpathy: %d\nBranch: %s" % [empathy, current_branch]

## Start a dialogue. Call this from anywhere.
func run_dialogue(dialogue_resource: DialogueResource, start_title: String = "start") -> void:
	if _active:
		return
	_active = true
	# Don't change mouse mode - keep camera active during dialogue

	# Reset positive choice counter
	n_positive_choices = 0

	# Determine starting branch based on empathy
	current_branch = "good" if empathy >= empathy_threshold else "bad"

	var logger = get_node_or_null("/root/PlaytestLogger")
	if logger:
		logger.log_event("dialogue_start", start_title)

	dialogue_started.emit()
	DialogueManager.show_example_dialogue_balloon(dialogue_resource, start_title)

## Called from dialogue files: do DialogueFlow.choice("positive")
func choice(alignment: String) -> void:
	# Store the last choice
	last_choice = alignment.to_lower()

	var old_branch = current_branch

	match alignment.to_lower():
		"positive", "good", "+":
			current_branch = "good"
			empathy += empathy_gain
		"negative", "bad", "-":
			current_branch = "bad"
			empathy -= empathy_loss
		"neutral", "n", "0":
			if empathy >= empathy_threshold:
				current_branch = "good"
				empathy += empathy_gain
			else:
				current_branch = "bad"
				empathy -= empathy_loss

	# Log
	var logger = get_node_or_null("/root/PlaytestLogger")
	if logger:
		var delta = empathy_gain if current_branch == "good" else -empathy_loss
		logger.log_action("choice_alignment", alignment)
		if old_branch != current_branch:
			logger.log_state("branch_change", current_branch)

	if old_branch != current_branch:
		branch_changed.emit(current_branch)

## Get next title based on branch. Use in dialogue: => {DialogueFlow.next("step2")}
func next(base_title: String) -> String:
	return base_title + "_" + current_branch

## Check if we should go to good branch title
func is_good() -> bool:
	return current_branch == "good"

## Check if we should go to bad branch title
func is_bad() -> bool:
	return current_branch == "bad"

func _on_dialogue_ended(_resource) -> void:
	print("DEBUG DialogueFlow: _on_dialogue_ended called, _active=", _active)
	if _active:
		_active = false
		# Don't change mouse mode - camera stays active
		var logger = get_node_or_null("/root/PlaytestLogger")
		if logger:
			logger.log_event("dialogue_end", "branch:%s empathy:%d" % [current_branch, empathy])
		print("DEBUG DialogueFlow: Emitting dialogue_ended signal with resource: ", _resource)
		dialogue_ended.emit(_resource)
