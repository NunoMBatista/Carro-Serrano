extends Node3D

## Enable/disable dialogue debug overlay (top-right corner)
@export var debug_dialogue: bool = true

# This is the variable you want to change
@onready var empathy_score: int = 0

# Payphone choice state
var payphone_used: bool = false
var payphone_choice_yes: bool = false

## Call this when starting a new game/playthrough to reset session state
func start_new_game() -> void:
	empathy_score = 0
	payphone_used = false
	payphone_choice_yes = false

	# Reset glovebox state for new playthrough
	if has_node("/root/GloveboxState"):
		get_node("/root/GloveboxState").clear_all_states()

	# Add other new game initialization here
	print("New game started - all session states cleared")


func on_payphone_choice(chose_yes: bool) -> void:
	# Record the player's choice at the torre payphone
	payphone_used = true
	payphone_choice_yes = chose_yes

	var root = get_tree().get_current_scene()
	if not root:
		return

	# Reveal the payphone arrow (arrow2) in the torre
	var arrow2 = root.get_node_or_null("torre/arrow2")
	if arrow2:
		arrow2.visible = true

	# Hide the initial torre arrow once the payphone has been used
	var arrow = root.get_node_or_null("torre/arrow")
	if arrow:
		arrow.visible = false

	# Enable interaction collider for the parked car in the torre
	var carro_interact = root.get_node_or_null("torre/carro_exterior/CarroInteract")
	if carro_interact and carro_interact is StaticBody3D:
		carro_interact.collision_layer = 2

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
			KEY_G:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					DialogueFlow.run_dialogue(DRUNK_DIALOGUE, "start")
