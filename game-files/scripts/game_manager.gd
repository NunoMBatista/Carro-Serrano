extends Node3D

@export var starting_empathy: int = 0
@export var starting_hitchhiker_count: int = 0
@export var user_id: String = ""

@onready var empathy_score: int = starting_empathy
@onready var hitchhiker_count: int = starting_hitchhiker_count

const PROTOTYPE_DIALOGUE = preload("res://dialogue/prototype.dialogue")


func _ready() -> void:
	if not user_id.is_empty():
		PlaytestLogger.set_user_id(user_id)
	PlaytestLogger.set_empathy(empathy_score)
	PlaytestLogger.set_hitchhiker_count(hitchhiker_count)


func change_empathy(amount: int) -> void:
	PlaytestLogger.change_empathy(amount)
	empathy_score = PlaytestLogger.empathy


func set_hitchhiker_count(value: int) -> void:
	PlaytestLogger.set_hitchhiker_count(value)
	hitchhiker_count = PlaytestLogger.hitchhiker_count


func increment_hitchhiker(value: int = 1) -> void:
	PlaytestLogger.increment_hitchhiker(value)
	hitchhiker_count = PlaytestLogger.hitchhiker_count


func mark_hitchhiker_spawned(label: String = "") -> void:
	PlaytestLogger.log_event("spawn_hitchhiker", label)


func mark_game_over(reason: String = "", did_win: bool = false) -> void:
	PlaytestLogger.log_game_over(reason, did_win)


func run_dialogue() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DialogueFlow.dialogue_resource = PROTOTYPE_DIALOGUE
	DialogueFlow.good_branch_titles = ["start"]
	DialogueFlow.bad_branch_titles = ["start"]
	DialogueFlow.start_hitchhiker_dialogue(hitchhiker_count)


func run_test_dialogue() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DialogueFlow.dialogue_resource = preload("res://dialogue/test_branch.dialogue")
	DialogueFlow.good_branch_titles = ["good_1", "good_2"]
	DialogueFlow.bad_branch_titles = ["bad_1", "bad_2"]
	DialogueFlow.start_hitchhiker_dialogue(hitchhiker_count)


func _process(_delta: float) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		run_dialogue()
	if event.is_action_pressed("test_dialogue_trigger"):
		run_test_dialogue()
