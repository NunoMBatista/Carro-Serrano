extends Node3D

var mouse_sensitivity := 0.001
var twist_input := 0.0 
var pitch_input := 0.0 

@onready var twist_pivot = $TwistPivot
@onready var pitch_pivot = $TwistPivot/PitchPivot

const PROTOTYPE_DIALOGUE = preload("res://dialogue/prototype.dialogue")

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 1. Listen for when the dialogue finishes
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended) # <--- ADD THIS

# 2. This function runs automatically when dialogue closes
func _on_dialogue_ended(_resource: Resource):               # <--- ADD THIS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)         # <--- ADD THIS

func run_dialogue():
	# Optional: Unlock mouse immediately when dialogue starts
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)          # <--- ADD THIS
	DialogueManager.show_example_dialogue_balloon(PROTOTYPE_DIALOGUE, "start")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	
	# Clamp logic (kept same as your code)
	twist_pivot.rotation.y = clamp(twist_pivot.rotation.y, -PI * 0.8, PI * 0.8)
	pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, -PI/2 * 0.8, PI/2 * 0.8)
	
	twist_input = 0.0
	pitch_input = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			twist_input = - event.relative.x * mouse_sensitivity
			pitch_input = - event.relative.y * mouse_sensitivity
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		# 3. Prevent opening dialogue if it is already open (Mouse is visible)
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED: # <--- ADD THIS
			run_dialogue()
