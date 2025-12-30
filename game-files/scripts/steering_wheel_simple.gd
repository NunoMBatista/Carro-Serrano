extends Sprite3D

## Simple Steering Wheel - Tracks Parent's Rotation
## Just monitors the parent node's rotation changes and rotates accordingly

@export var rotation_multiplier := 300.0  ## How much the wheel rotates (higher = more dramatic)
@export var smoothing := 0.15  ## Rotation smoothing (lower = snappier, higher = smoother)
@export var max_rotation_degrees := 120.0  ## Maximum rotation angle in degrees
@export var center_spring := 0.12  ## How fast wheel returns to center (0-1)

var previous_yaw := 0.0
var target_rotation := 0.0
var current_rotation := 0.0
var parent_node: Node3D

func _ready() -> void:
	# Get parent node
	parent_node = get_parent()

	if parent_node == null or not parent_node is Node3D:
		push_warning("Steering wheel: Parent must be a Node3D")
		return

	# Initialize
	previous_yaw = _get_yaw(parent_node.global_transform.basis)

	# Set up sprite
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

	print("Steering wheel initialized, tracking parent: ", parent_node.name)

func _process(delta: float) -> void:
	if parent_node == null:
		return

	# Get current parent yaw
	var current_yaw := _get_yaw(parent_node.global_transform.basis)

	# Calculate yaw change (steering direction)
	var yaw_delta := _angle_difference(current_yaw, previous_yaw)
	previous_yaw = current_yaw

	# Convert to steering wheel rotation
	var steering_input := yaw_delta * rotation_multiplier
	target_rotation += steering_input

	# Apply center spring (wheel wants to return to center)
	target_rotation = lerp(target_rotation, 0.0, center_spring)

	# Clamp to max rotation
	target_rotation = clamp(target_rotation, -max_rotation_degrees, max_rotation_degrees)

	# Smooth the rotation
	current_rotation = lerp(current_rotation, target_rotation, 1.0 - exp(-smoothing * delta * 60.0))

	# Apply rotation around Z axis (steering wheel spins)
	rotation_degrees = Vector3(0, 0, current_rotation)

func _get_yaw(basis: Basis) -> float:
	# Extract yaw from basis (rotation around Y axis)
	var forward := -basis.z
	return atan2(forward.x, forward.z)

func _angle_difference(current: float, previous: float) -> float:
	# Calculate shortest angle difference, handling wraparound
	var diff := current - previous
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff
