extends Node3D

var mouse_sensitivity := 0.001
var twist_input := 0.0 
var pitch_input := 0.0 
var keyboard_cam_speed := 2.5

@onready var twist_pivot = $TwistPivot
@onready var pitch_pivot = $TwistPivot/PitchPivot

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 1. Listen for when the dialogue finishes
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended) # <--- ADD THIS

# 2. This function runs automatically when dialogue closes
func _on_dialogue_ended(_resource: Resource):               
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)         


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Camera arrow keys movement
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		twist_pivot.rotate_y(-input_dir.x * keyboard_cam_speed * delta)
		pitch_pivot.rotate_x(-input_dir.y * keyboard_cam_speed * delta)

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
	
