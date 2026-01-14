extends Node3D

var mouse_sensitivity := 0.001
var twist_input := 0.0
var pitch_input := 0.0
var keyboard_cam_speed := 2.5

@export var tremble_pos_amplitude := Vector3(0.001, 0.0015, 0.001)
@export var tremble_rot_amplitude_deg := Vector3(0.02, 0.02, 0.04)
@export var tremble_frequency := 16.0

var _tremble_time := 0.0
var _pitch_pos_base := Vector3.ZERO

@onready var twist_pivot = $TwistPivot
@onready var pitch_pivot = $TwistPivot/PitchPivot

func _ready() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	_pitch_pos_base = pitch_pivot.position


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		var dialogue_flow = get_node_or_null("/root/DialogueFlow")
		var mode_before = DisplayServer.mouse_get_mode()
		print("[CAMERA] ESC pressed - mouse mode BEFORE: ", mode_before)
		if dialogue_flow and dialogue_flow.is_dialogue_active:
			# Don't change mouse mode during dialogue
			print("[CAMERA] ESC pressed during dialogue - ignoring. is_dialogue_active=", dialogue_flow.is_dialogue_active)
			pass
		else:
			print("[CAMERA] ESC pressed - changing to CAPTURED")
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
			var mode_after = DisplayServer.mouse_get_mode()
			print("[CAMERA] Mouse mode AFTER: ", mode_after)

	# Don't use arrow keys for camera movement - they're for dialogue choices
	# var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# if input_dir != Vector2.ZERO:
	# 	twist_pivot.rotate_y(-input_dir.x * keyboard_cam_speed * delta)
	# 	pitch_pivot.rotate_x(-input_dir.y * keyboard_cam_speed * delta)

	twist_pivot.rotate_y(twist_input)
	pitch_pivot.rotate_x(pitch_input)

	# Clamp rotation to realistic human neck limits
	# Horizontal: ~70 degrees left/right (0.77 * 90 = ~70 degrees)
	twist_pivot.rotation.y = clamp(twist_pivot.rotation.y, -PI * 0.77, PI * 0.77)
	# Vertical: ~65 degrees up/down (0.72 * 90 = ~65 degrees)
	pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, -PI/2 * 0.72, PI/2 * 0.72)

	twist_input = 0.0
	pitch_input = 0.0

	# Engine-like tremble: small positional and rotational noise on the pitch pivot.
	var base_pitch_rot: Vector3 = pitch_pivot.rotation
	_tremble_time += delta
	var w := _tremble_time * tremble_frequency
	var pos_noise := Vector3(
		sin(w) * tremble_pos_amplitude.x,
		sin(w * 1.31) * tremble_pos_amplitude.y,
		sin(w * 1.87) * tremble_pos_amplitude.z
	)
	var rot_noise := Vector3(
		sin(w * 1.17) * deg_to_rad(tremble_rot_amplitude_deg.x),
		sin(w * 1.43) * deg_to_rad(tremble_rot_amplitude_deg.y),
		sin(w * 0.93) * deg_to_rad(tremble_rot_amplitude_deg.z)
	)

	pitch_pivot.position = _pitch_pos_base + pos_noise
	pitch_pivot.rotation = base_pitch_rot + rot_noise

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_mode = DisplayServer.mouse_get_mode()
		# MOUSE_MODE_CAPTURED = 2, MOUSE_MODE_HIDDEN = 4 in DisplayServer
		if mouse_mode == DisplayServer.MOUSE_MODE_CAPTURED or mouse_mode == DisplayServer.MOUSE_MODE_HIDDEN:
			twist_input = - event.relative.x * mouse_sensitivity
			pitch_input = - event.relative.y * mouse_sensitivity
