extends Node3D

## Enable/disable dialogue debug overlay (top-right corner)
@export var debug_dialogue: bool = true

# This is the variable you want to change
@onready var empathy_score: int = 0

## Call this when starting a new game/playthrough to reset session state
func start_new_game() -> void:
	empathy_score = 0

	# Reset glovebox state for new playthrough
	if has_node("/root/GloveboxState"):
		get_node("/root/GloveboxState").clear_all_states()

	# Add other new game initialization here
	print("New game started - all session states cleared")

const PROTOTYPE_DIALOGUE = preload("res://dialogue/prototype.dialogue")
# const DRUNK_DIALOGUE = preload("res://dialogue/drunk_dialogue.dialogue")
#const DRUNK_DIALOGUE = preload("res://dialogue/middle_aged_dialogue.dialogue")
const DRUNK_DIALOGUE = preload("res://dialogue/novinha.dialogue")

# Optional: A helper function if you want to print logic
func change_empathy(amount: int):
	empathy_score += amount
	print("Empathy is now: ", empathy_score)
	var logger = get_node_or_null("/root/PlaytestLogger")
	if logger:
		logger.current_empathy = empathy_score
		logger.log_state("update_empathy", "%+d" % amount)

func run_dialogue():
	# Don't change mouse mode - camera stays active during dialogue
	DialogueManager.show_example_dialogue_balloon(PROTOTYPE_DIALOGUE, "start")

func _process(delta: float) -> void:
	pass
	#prints("gangsta: ", empathy_score)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_D:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					run_dialogue()
			KEY_G:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					DialogueFlow.run_dialogue(DRUNK_DIALOGUE, "start")
