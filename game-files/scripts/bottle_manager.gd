extends Node3D
class_name BottleManager

## Reference to the car node to get passenger seat position
@export var car_node_path: NodePath
@export var passenger_seat_offset: Vector3 = Vector3(0.5, 0.5, 0.0)  # Offset from car center to passenger seat

## Bottle settings
@export var bottle_radius: float = 0.03
@export var bottle_height: float = 0.2
@export var bottle_color: Color = Color(0.3, 0.6, 0.2, 0.7)  # Green transparent glass

var bottle_scene: PackedScene = null
var bottle: Bottle = null
var car_node: Node3D = null
var camera: Camera3D = null
var is_hovering_bottle: bool = false

func _ready() -> void:
	# Get car reference
	if car_node_path:
		car_node = get_node(car_node_path)

	# Find camera
	camera = get_viewport().get_camera_3d()

func _unhandled_input(event: InputEvent) -> void:
	# Spawn bottle with B key
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		if bottle == null:
			spawn_bottle()
		else:
			# If bottle exists, remove it and spawn a new one
			bottle.queue_free()
			bottle = null
			spawn_bottle()
		get_viewport().set_input_as_handled()

	# Handle mouse clicks for dragging
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Try to pick up bottle
				var did_pickup = attempt_pickup()
				if did_pickup:
					get_viewport().set_input_as_handled()
			else:
				# Release bottle
				if bottle and is_instance_valid(bottle) and bottle.is_dragging:
					bottle.end_drag()
					_set_crosshair_dragging(false)
					get_viewport().set_input_as_handled()

		# Handle right-click to throw bottle while dragging
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and bottle and is_instance_valid(bottle) and bottle.is_dragging:
				throw_bottle()
				get_viewport().set_input_as_handled()

		# Handle scroll wheel to adjust distance while dragging
		if bottle and is_instance_valid(bottle) and bottle.is_dragging:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				bottle.adjust_drag_distance(0.2)  # Push further
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				bottle.adjust_drag_distance(-0.2)  # Bring closer
				get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	# Update bottle drag position
	if bottle and is_instance_valid(bottle) and bottle.is_dragging and camera:
		var camera_pos = camera.global_position
		var camera_forward = -camera.global_transform.basis.z
		bottle.update_drag_position(camera_pos, camera_forward)

	# Update hover state (check if mouse is over bottle)
	_update_hover_state()

func spawn_bottle() -> void:
	# Create new bottle instance
	bottle = Bottle.new()

	# Setup bottle appearance BEFORE adding to tree
	bottle.setup_as_cylinder(bottle_radius, bottle_height, bottle_color)

	# Calculate spawn position
	var spawn_pos: Vector3
	if car_node:
		# Get car's global position and apply offset in car's local space
		var car_basis = car_node.global_transform.basis
		spawn_pos = car_node.global_position + car_basis * passenger_seat_offset
	else:
		# Fallback: spawn at manager position
		spawn_pos = global_position + passenger_seat_offset

	# Set position BEFORE adding to tree
	bottle.global_position = spawn_pos

	# Set car reference for physics
	bottle.car_body = car_node

	# Add bottle to the root of the scene
	get_tree().root.add_child(bottle)

	# Force the RigidBody3D to wake up and register with physics
	bottle.sleeping = false
	bottle.freeze = false
	bottle.linear_velocity = Vector3(0, -0.1, 0)  # Give it a tiny downward velocity to force activation

	# Wait for physics to fully register
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("Bottle spawned at passenger seat! Gravity: ", bottle.gravity_scale, " Sleeping: ", bottle.sleeping, " Pos: ", bottle.global_position)

func throw_bottle() -> void:
	"""Throw the bottle in the direction of camera forward with force"""
	if not bottle or not is_instance_valid(bottle) or not camera:
		return

	# Calculate throw direction (camera forward)
	var throw_direction = -camera.global_transform.basis.z

	# Throw strength based on distance from camera (further = faster throw)
	var throw_strength = 8.0 + (bottle.drag_distance * 2.0)

	# Calculate throw velocity
	var throw_velocity = throw_direction * throw_strength

	# Add slight upward component for arc
	throw_velocity.y += 2.0

	print("Bottle thrown with velocity: ", throw_velocity)

	# End drag with throw velocity
	bottle.end_drag(throw_velocity)
	_set_crosshair_dragging(false)

func attempt_pickup() -> bool:
	if not bottle or not is_instance_valid(bottle) or not camera:
		print("Pickup failed: bottle or camera invalid")
		return false

	# Don't try to pick up if bottle doesn't have collision shapes yet
	if not bottle.collision_shape or not is_instance_valid(bottle.collision_shape):
		print("Pickup failed: collision shape invalid")
		return false

	# Cast ray from camera
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var ray_length = 100.0

	# Perform raycast
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		print("Pickup failed: no space_state")
		return false

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * ray_length)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	if result:
		print("Raycast hit: ", result.collider, " at ", result.position)
		if result.has("collider") and is_instance_valid(result.collider):
			print("Collider type: ", result.collider.get_class())
			if result.collider == bottle:
				print("Hit the bottle! Starting drag")
				var hit_point = result.position
				bottle.start_drag(camera.global_position, hit_point)
				_set_crosshair_dragging(true)
				return true
			else:
				print("Hit something else, not the bottle")
	else:
		print("Raycast hit nothing")

	return false

func _update_hover_state() -> void:
	"""Check if mouse is hovering over the bottle and update cursor"""
	if not bottle or not is_instance_valid(bottle) or not camera:
		if is_hovering_bottle:
			is_hovering_bottle = false
			_set_crosshair_hover(false)
		return

	# Don't check hover while dragging
	if bottle.is_dragging:
		return

	# Cast ray from camera to check if hovering bottle
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var ray_length = 100.0

	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * ray_length)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)

	var hovering = false
	if result and result.has("collider") and is_instance_valid(result.collider):
		hovering = (result.collider == bottle)

	# Update hover state if changed
	if hovering != is_hovering_bottle:
		is_hovering_bottle = hovering
		_set_crosshair_hover(is_hovering_bottle)

func _set_crosshair_hover(enabled: bool) -> void:
	"""Update crosshair to show hover state (open hand)"""
	var crosshair = _get_crosshair()
	if crosshair and crosshair.has_method("set_ui_hovering"):
		crosshair.set_ui_hovering(enabled)

func _set_crosshair_dragging(dragging: bool) -> void:
	"""Update crosshair to show dragging state (closed hand)"""
	var crosshair = _get_crosshair()
	if crosshair and crosshair.has_method("set_ui_dragging"):
		crosshair.set_ui_dragging(dragging)

func _get_crosshair() -> Node:
	"""Find the crosshair node in the scene"""
	# Try to find it as a child of the player/camera parent
	if camera:
		var parent = camera.get_parent()
		while parent:
			var crosshair = parent.get_node_or_null("CrossHair")
			if crosshair:
				return crosshair
			parent = parent.get_parent()

	# Fallback: search in the whole scene tree
	return get_tree().root.find_child("CrossHair", true, false)
