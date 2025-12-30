extends Sprite3D

## 3D Steering Wheel - Car Interior Object
## Simple steering wheel that's part of the car and rotates in place

## Tuning parameters
@export var rotation_multiplier := 500.0  ## How much the wheel rotates (higher = more dramatic)
@export var smoothing := 0.05  ## Rotation smoothing (lower = snappier, higher = smoother)
@export var max_rotation_degrees := 180.0  ## Maximum rotation angle in degrees
@export var center_spring := 0.02  ## How fast wheel returns to center (0-1)

var car: Node3D
var previous_yaw := 0.0
var target_rotation := 0.0
var current_rotation := 0.0

func _ready() -> void:
	# The steering wheel is a child of Carro, which is a child of CarFollower
	# CarFollower is the node that actually rotates, so we need to track its parent
	var parent = get_parent()
	if parent and parent.get_parent():
		car = parent.get_parent()  # Get grandparent (CarFollower)
		print("Steering wheel tracking grandparent: ", car.name)

	# Fallback: search for the moving node
	if car == null:
		car = _find_car_node()

	if car == null:
		push_warning("Steering wheel: Car node not found")
		return

	print("=== STEERING WHEEL INITIALIZED ===")
	print("Tracking node: ", car.name)
	print("Node type: ", car.get_class())
	print("Has script: ", car.get_script() != null)

	# Initialize yaw
	previous_yaw = _get_yaw(car.global_transform.basis)
	print("Initial yaw: ", previous_yaw)

	# Set up the sprite to face forward (billboard disabled)
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	if car == null:
		return

	# Get current car yaw
	var current_yaw := _get_yaw(car.global_transform.basis)

	# Calculate yaw change (steering direction)
	var yaw_delta := _angle_difference(current_yaw, previous_yaw)

	# AGGRESSIVE DEBUG
	if abs(yaw_delta) > 0.0001:
		print("YAW CHANGE! Delta: ", yaw_delta, " (degrees: ", rad_to_deg(yaw_delta), ")")

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

	# CONSTANT DEBUG
	if Engine.get_frames_drawn() % 60 == 0:  # Every 60 frames
		print("Status - Current rotation: ", current_rotation, " Target: ", target_rotation, " Yaw: ", rad_to_deg(current_yaw))

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

func _find_car_node() -> Node3D:
	# Search up the tree for the node with road_car_follower script
	var node := get_parent()

	while node != null:
		if node is Node3D:
			# Check if this node has the road_car_follower script
			if node.get_script() != null:
				var script_path = node.get_script().resource_path
				if "road_car_follower" in script_path:
					print("Steering wheel: Found road_car_follower node: ", node.name)
					return node

		node = node.get_parent()

	# Last resort: search entire scene
	var root = get_tree().current_scene
	if root:
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()

			# Check for road_car_follower script
			if n.get_script() != null:
				var script_path = n.get_script().resource_path
				if "road_car_follower" in script_path:
					print("Steering wheel: Found road_car_follower in scene tree: ", n.name)
					return n

			if (n is RigidBody3D or n is CharacterBody3D) and n.name == "Carro":
				return n

			for child in n.get_children():
				stack.append(child)

	return null
