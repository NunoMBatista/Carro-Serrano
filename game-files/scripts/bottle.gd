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
var drag_distance: float = 1.0  # Distance from camera during drag
const MIN_DRAG_DISTANCE: float = 0.3
const MAX_DRAG_DISTANCE: float = 5.0

## Static dashboard state
var is_static_on_dashboard: bool = true
var dashboard_local_position: Vector3 = Vector3.ZERO  # Position relative to car (local)
var dashboard_local_rotation: Vector3 = Vector3.ZERO  # Rotation relative to car (local)

## Car reference
var car_body: Node3D = null

## Physics settings
@export var max_velocity: float = 8.0
@export var max_angular_velocity: float = 10.0

var camera: Camera3D = null
var scene_root: Node = null

func _ready() -> void:
	# Find camera
	camera = get_viewport().get_camera_3d()
	scene_root = get_tree().root

	# Start as static on dashboard (kinematic, frozen)
	if is_static_on_dashboard:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		gravity_scale = 0.0
		sleeping = false
		can_sleep = false

	print("=== Bottle _ready called ===")
	print("  is_static_on_dashboard: ", is_static_on_dashboard)
	print("  parent: ", get_parent().name if get_parent() else "none")
	print("  position (local): ", position)
	print("  position (global): ", global_position)

func _process(_delta: float) -> void:
	# If static on dashboard, update position to follow car
	if is_static_on_dashboard and car_body and not is_dragging:
		# Calculate global position from car's transform and local offset
		var car_transform = car_body.global_transform
		global_position = car_transform.origin + car_transform.basis * dashboard_local_position
		global_rotation = car_body.global_rotation + dashboard_local_rotation

func _physics_process(_delta: float) -> void:
	# Debug periodically
	if Engine.get_physics_frames() % 120 == 0:
		print("Bottle - static: ", is_static_on_dashboard, " dragging: ", is_dragging, " freeze: ", freeze)

	# Only apply velocity clamping when physics is active (not dragging, not static)
	if not is_dragging and not is_static_on_dashboard:
		if linear_velocity.length() > max_velocity:
			linear_velocity = linear_velocity.normalized() * max_velocity

		if angular_velocity.length() > max_angular_velocity:
			angular_velocity = angular_velocity.normalized() * max_angular_velocity

func start_drag(camera_position: Vector3, _ray_hit_point: Vector3) -> void:
	is_dragging = true
	is_static_on_dashboard = false

	# Calculate drag distance (keep bottle at same distance from camera)
	drag_distance = camera_position.distance_to(global_position)

	# Use freeze mode to completely disable physics while dragging
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	print("=== DRAG STARTED ===")
	print("  Position: ", global_position)
	print("  Parent: ", get_parent().name)

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
		print("  Throw velocity: ", throw_velocity)

		is_dragging = false

		# Check if this is a throw (has velocity) or just a release
		if throw_velocity.length() > 0:
			# This is a throw - enable physics and apply velocity
			freeze = false
			is_static_on_dashboard = false

			# Force all velocities to zero immediately
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO

			# Restore physics properties
			gravity_scale = 1.0
			linear_damp = 3.0
			angular_damp = 4.0

			# Call deferred to ensure it happens after physics update
			call_deferred("_set_release_velocity", throw_velocity)

			print("=== BOTTLE THROWN - Physics enabled ===")
		else:
			# Just released (right-click) - return to dashboard position
			return_to_dashboard()
			print("=== BOTTLE RETURNED TO DASHBOARD ===")

		# Restore visual state
		if visual_node:
			visual_node.scale = Vector3(1.0, 1.0, 1.0)

		drag_ended.emit()

func _set_release_velocity(throw_velocity: Vector3) -> void:
	"""Called deferred after unfreezing to set proper velocity"""
	linear_velocity = throw_velocity
	print("=== THROW VELOCITY SET (deferred) ===")
	print("  Throw velocity: ", throw_velocity)

## Setup function to create a simple cylinder bottle
func setup_as_cylinder(radius: float, height: float, color: Color) -> void:
	# Ensure physics properties are set
	gravity_scale = 1.0
	linear_damp = 3.0
	angular_damp = 4.0
	mass = 2.0
	collision_layer = 1
	collision_mask = 0b11111111111111111111  # Collide with all layers
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

	print("=== Bottle setup_as_cylinder complete ===")

func set_dashboard_position(local_pos: Vector3, local_rot: Vector3) -> void:
	"""Set the dashboard position (local to car)"""
	dashboard_local_position = local_pos
	dashboard_local_rotation = local_rot
	position = local_pos
	rotation = local_rot
	print("=== Dashboard position set ===")
	print("  Local position: ", dashboard_local_position)
	print("  Local rotation: ", dashboard_local_rotation)

func return_to_dashboard() -> void:
	"""Return bottle to its original dashboard position (static on dashboard)"""
	if not car_body:
		print("ERROR: No car_body reference!")
		return

	is_static_on_dashboard = true

	# Freeze in kinematic mode
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0

	# Reset velocities
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Position will be updated in _process to follow car
	var car_transform = car_body.global_transform
	global_position = car_transform.origin + car_transform.basis * dashboard_local_position
	global_rotation = car_body.global_rotation + dashboard_local_rotation

	print("=== Bottle returned to dashboard ===")
	print("  Global position: ", global_position)
