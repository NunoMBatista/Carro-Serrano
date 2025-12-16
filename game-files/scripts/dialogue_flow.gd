extends Node
## Dialogue Flow autoload. Manages empathy-based branching system.

signal dialogue_started
signal dialogue_ended
signal branch_changed(new_branch: String)

## Empathy threshold for neutral choices (>= goes good, < goes bad)
@export var empathy_threshold: int = 50
## Empathy gained per step in good branch
@export var empathy_gain: int = 5
## Empathy lost per step in bad branch
@export var empathy_loss: int = 10

## Current empathy (0-100)
var empathy: int = 50:
	set(v):
		empathy = clampi(v, 0, 100)
		var logger = get_node_or_null("/root/PlaytestLogger")
		if logger:
			logger.current_empathy = empathy

## Current branch: "good" or "bad"
var current_branch: String = "good"
var _active: bool = false

func _ready() -> void:
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

## Start a dialogue. Call this from anywhere.
func run_dialogue(dialogue_resource: DialogueResource, start_title: String = "start") -> void:
	if _active:
		return
	_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Determine starting branch based on empathy
	current_branch = "good" if empathy >= empathy_threshold else "bad"
	
	var logger = get_node_or_null("/root/PlaytestLogger")
	if logger:
		logger.log_event("dialogue_start", start_title)
	
	dialogue_started.emit()
	DialogueManager.show_example_dialogue_balloon(dialogue_resource, start_title)

## Called from dialogue files: do DialogueFlow.choice("positive")
func choice(alignment: String) -> void:
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
	if _active:
		_active = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		var logger = get_node_or_null("/root/PlaytestLogger")
		if logger:
			logger.log_event("dialogue_end", "branch:%s empathy:%d" % [current_branch, empathy])
		dialogue_ended.emit()
