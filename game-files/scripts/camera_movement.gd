extends Node3D

var mouse_sensitivity := 0.001
var twist_input := 0.0 # how much mouse has moved horizontally every frame
var pitch_input := 0.0 # how much mouse has moved vertically every frame

@onready var twist_pivot = $TwistPivot
@onready var pitch_pivot = $TwistPivot/PitchPivot

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
#var speed = 1200.0
# delta: how many seconds since the previous frame
func _process(delta: float) -> void:
	#var input := Vector3.ZERO
	#input.x = Input.get_axis("move_left", "move_right") #1.0 if the first is detected, -1.0 if the second is detected
	#input.z = Input.get_axis("move_forward", "move_back")

	#apply_central_force(twist_pivot.basis * input * speed * delta)

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)
	print(pitch_pivot.rotation.y)
	twist_pivot.rotation.y = clamp(
		twist_pivot.rotation.y,
		-PI * 0.8,
		PI * 0.8
	)
	pitch_pivot.rotation.x = clamp(
		pitch_pivot.rotation.x,
		-PI/2 * 0.8,
		PI/2 * 0.8
	)
	twist_input = 0.0
	pitch_input = 0.0
	
	#if global_position.y < 0.0:
	#	global_position.y = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			twist_input = - event.relative.x * mouse_sensitivity
			pitch_input = - event.relative.y * mouse_sensitivity
			
