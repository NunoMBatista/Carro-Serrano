extends RigidBody3D
class_name Bottle

signal clicked
signal drag_started
signal drag_ended

## Visual representation
var visual_node: Node3D = null
var collision_shape: CollisionShape3D = null

## Drag state
var is_dragging: bool = false
var drag_offset: Vector3 = Vector3.ZERO
var drag_distance: float = 1.0  # Distance from camera during drag
const MIN_DRAG_DISTANCE: float = 0.3
const MAX_DRAG_DISTANCE: float = 5.0

## Car reference for physics
var car_body: Node3D = null

## Physics settings
@export var drag_smoothing: float = 15.0  # How smoothly bottle follows drag
@export var max_velocity: float = 8.0
@export var max_angular_velocity: float = 10.0

var camera: Camera3D = null
var last_car_position: Vector3 = Vector3.ZERO
var car_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Find camera
	camera = get_viewport().get_camera_3d()

	# Initialize car tracking
	if car_body:
		last_car_position = car_body.global_position

	# Debug output
	print("=== Bottle _ready called ===")
	print("  gravity_scale: ", gravity_scale)
	print("  freeze: ", freeze)
	print("  sleeping: ", sleeping)
	print("  can_sleep: ", can_sleep)
	print("  mass: ", mass)
	print("  linear_velocity: ", linear_velocity)
	print("  global_position: ", global_position)
	print("  is_inside_tree: ", is_inside_tree())
	print("  collision_layer: ", collision_layer)
	print("  collision_mask: ", collision_mask)

func _physics_process(delta: float) -> void:
	# Debug first few frames
	if Engine.get_physics_frames() % 60 == 0:  # Every 60 physics frames
		print("Bottle physics - pos: ", global_position, " vel: ", linear_velocity, " sleeping: ", sleeping)

	# Track car movement to handle physics relative to car
	# IMPORTANT: Always track, even while dragging, so we have accurate velocity on release
	if car_body:
		var current_car_pos = car_body.global_position
		car_velocity = (current_car_pos - last_car_position) / delta if delta > 0 else Vector3.ZERO
		last_car_position = current_car_pos

		# Apply small random forces to simulate car movement jitter (only when not dragging)
		if not is_dragging and randf() < 0.01:
			var jitter = Vector3(
				randf_range(-0.5, 0.5),
				randf_range(-0.2, 0.2),
				randf_range(-0.5, 0.5)
			)
			apply_central_impulse(jitter)

	# Clamp velocity relative to car
	var relative_velocity = linear_velocity - car_velocity
	if relative_velocity.length() > max_velocity:
		linear_velocity = car_velocity + relative_velocity.normalized() * max_velocity

	if angular_velocity.length() > max_angular_velocity:
		angular_velocity = angular_velocity.normalized() * max_angular_velocity

func start_drag(camera_position: Vector3, ray_hit_point: Vector3) -> void:
	is_dragging = true

	# Calculate drag distance (keep bottle at same distance from camera)
	drag_distance = camera_position.distance_to(global_position)

	# Don't use offset - just position directly where we want
	drag_offset = Vector3.ZERO

	# Use freeze mode to completely disable physics
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	print("=== DRAG STARTED ===")
	print("  Position: ", global_position)
	print("  Freeze: ", freeze)

	# Visual feedback
	if visual_node:
		visual_node.scale = Vector3(1.05, 1.05, 1.05)

	drag_started.emit()
	clicked.emit()

func update_drag_position(camera_position: Vector3, camera_forward: Vector3) -> void:
	if is_dragging:
		# Calculate target position in front of camera
		var target_pos = camera_position + camera_forward * drag_distance

		# Directly set position (kinematic mode)
		global_position = target_pos

func adjust_drag_distance(delta: float) -> void:
	"""Adjust how far the bottle is from the camera while dragging"""
	if is_dragging:
		drag_distance += delta
		drag_distance = clamp(drag_distance, MIN_DRAG_DISTANCE, MAX_DRAG_DISTANCE)

func end_drag(throw_velocity: Vector3 = Vector3.ZERO) -> void:
	if is_dragging:
		print("=== DRAG ENDING ===")
		print("  Position before: ", global_position)
		print("  Car velocity: ", car_velocity)

		is_dragging = false

		# Unfreeze FIRST, THEN set velocities
		freeze = false

		# Force all velocities to zero immediately
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

		# Restore physics properties
		gravity_scale = 1.0
		linear_damp = 3.0
		angular_damp = 4.0

		# Call deferred to ensure it happens after physics update
		call_deferred("_set_release_velocity", throw_velocity)

		print("=== DRAG ENDED ===")
		print("  Position after: ", global_position)

		# Restore visual state
		if visual_node:
			visual_node.scale = Vector3(1.0, 1.0, 1.0)

		drag_ended.emit()

func _set_release_velocity(throw_velocity: Vector3 = Vector3.ZERO) -> void:
	"""Called deferred after unfreezing to set proper velocity"""
	# Zero everything first
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# If we have a throw velocity, use it
	if throw_velocity.length() > 0:
		linear_velocity = throw_velocity
		print("=== THROW VELOCITY SET (deferred) ===")
		print("  Throw velocity: ", throw_velocity)
	else:
		# Otherwise set to car velocity if car exists
		# Clamp to reasonable values to prevent shooting off
		if car_body:
			var clamped_velocity = car_velocity
			# Clamp each component to max 2.0 units/sec
			clamped_velocity.x = clamp(clamped_velocity.x, -2.0, 2.0)
			clamped_velocity.y = clamp(clamped_velocity.y, -2.0, 2.0)
			clamped_velocity.z = clamp(clamped_velocity.z, -2.0, 2.0)
			linear_velocity = clamped_velocity

		print("=== VELOCITY SET (deferred) ===")
		print("  Car velocity raw: ", car_velocity)
		print("  Linear velocity (clamped): ", linear_velocity)

## Setup function to create a simple cylinder bottle
func setup_as_cylinder(radius: float, height: float, color: Color) -> void:
	# Ensure physics properties are set
	gravity_scale = 1.0
	linear_damp = 3.0
	angular_damp = 4.0
	mass = 2.0  # Increased mass to prevent phasing through car
	collision_layer = 1
	collision_mask = 0b11111111111111111111  # Collide with all layers (first 20 layers)
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = true
	freeze = false
	sleeping = false
	can_sleep = false

	# Physics material for better collision
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.1
	physics_material_override.friction = 0.8

	# Create visual mesh
	var mesh_instance = MeshInstance3D.new()
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = height

	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.3
	material.metallic = 0.1

	cylinder_mesh.material = material
	mesh_instance.mesh = cylinder_mesh
	add_child(mesh_instance)
	visual_node = mesh_instance

	# Create collision shape
	collision_shape = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision_shape.shape = shape
	add_child(collision_shape)

	# Force physics to activate immediately
	apply_central_impulse(Vector3(0, 0.001, 0))  # Tiny impulse to wake it up

	print("=== Bottle setup_as_cylinder complete ===")
	print("  gravity_scale: ", gravity_scale)
	print("  mass: ", mass)
	print("  sleeping: ", sleeping)
	print("  freeze: ", freeze)
	print("  collision_shape added: ", collision_shape != null)
	print("  visual_node added: ", visual_node != null)

## Get state for persistence
func get_save_data() -> Dictionary:
	return {
		"position": global_position,
		"rotation": rotation,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity
	}

## Restore state
func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		rotation = data["rotation"]
	if data.has("linear_velocity"):
		linear_velocity = data["linear_velocity"]
	if data.has("angular_velocity"):
		angular_velocity = data["angular_velocity"]
