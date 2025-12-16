extends Node3D

# This is the variable you want to change
@onready var empathy_score: int = 0


const PROTOTYPE_DIALOGUE = preload("res://dialogue/prototype.dialogue")


# Optional: A helper function if you want to print logic
func change_empathy(amount: int):
	empathy_score += amount
	print("Empathy is now: ", empathy_score)
	var logger = get_node_or_null("/root/PlaytestLogger")
	if logger:
		logger.current_empathy = empathy_score
		logger.log_state("update_empathy", "%+d" % amount)

func run_dialogue():
	# Optional: Unlock mouse immediately when dialogue starts
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)          # <--- ADD THIS
	DialogueManager.show_example_dialogue_balloon(PROTOTYPE_DIALOGUE, "start")

func _process(delta: float) -> void:
	prints("gangsta: ", empathy_score)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		# 3. Prevent opening dialogue if it is already open (Mouse is HIDDEN, but moving)
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED: # <--- ADD THIS
			run_dialogue()
