extends Node3D
class_name BottleManager

## Reference to the car node to get passenger seat position
@export var car_node_path: NodePath
@export var passenger_seat_offset: Vector3 = Vector3(0.5, 0.5, 0.0)  # Offset from car center to passenger seat

## Bottle settings
@export var bottle_radius: float = 0.03
@export var bottle_height: float = 0.2
@export var bottle_color: Color = Color(0.3, 0.6, 0.2, 0.7)  # Green transparent glass

var bottle_scene: PackedScene = preload("res://scenes/bottle.tscn")
var bottle: Bottle = null
var car_node: Node3D = null
var camera: Camera3D = null
var is_hovering_bottle: bool = false
var hover_check_frame_count: int = 0
var hover_state_buffer: Array[bool] = [false, false, false]  # Buffer to debounce hover state
var hover_buffer_index: int = 0

func _ready() -> void:
	# Get car reference
	if car_node_path:
		car_node = get_node(car_node_path)

	# Find camera
	camera = get_viewport().get_camera_3d()

func _unhandled_input(event: InputEvent) -> void:
	# Spawn bottle with B key
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		#if bottle == null:
		#	spawn_bottle()
		#else:
			#	# If bottle exists, remove it and spawn a new one
			#	bottle.queue_free()
			#	bottle = null
			#	spawn_bottle()
			#get_viewport().set_input_as_handled()
		pass

	# Handle mouse clicks
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Check if we're already dragging
			if bottle and is_instance_valid(bottle) and bottle.is_dragging:
				# Second click while dragging = THROW and remove permanently
				throw_bottle()
				# Remove bottle permanently after throwing (wait longer so we can see it)
				await get_tree().create_timer(2.0).timeout
				if bottle and is_instance_valid(bottle):
					bottle.queue_free()
					bottle = null
				_set_crosshair_dragging(false)
				get_viewport().set_input_as_handled()
			else:
				# First click = try to pick up bottle
				var did_pickup = attempt_pickup()
				if did_pickup:
					get_viewport().set_input_as_handled()

		# Handle right-click to return bottle to dashboard while dragging
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if bottle and is_instance_valid(bottle) and bottle.is_dragging:
				# Return to dashboard (just end drag with no velocity)
				bottle.end_drag()
				_set_crosshair_dragging(false)
				get_viewport().set_input_as_handled()

		# Handle scroll wheel to adjust distance while dragging
		elif bottle and is_instance_valid(bottle) and bottle.is_dragging:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				bottle.adjust_drag_distance(0.2)  # Push further
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				bottle.adjust_drag_distance(-0.2)  # Bring closer
				get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	# Update bottle drag position
	if bottle and is_instance_valid(bottle) and bottle.is_dragging and camera:
		var camera_pos = camera.global_position
		var camera_forward = -camera.global_transform.basis.z
		bottle.update_drag_position(camera_pos, camera_forward)

	# Update hover state (check if mouse is over bottle) - only every 10 frames to reduce flickering
	hover_check_frame_count += 1
	if hover_check_frame_count >= 10:
		hover_check_frame_count = 0
		_update_hover_state()

func spawn_bottle() -> void:
	# Create new bottle instance from scene
	if not bottle_scene:
		push_error("Bottle scene not loaded!")
		return

	var bottle_instance = bottle_scene.instantiate()

	# Find the RigidBody3D with Bottle script in the scene
	bottle = bottle_instance as Bottle
	if not bottle:
		# Try to find it as a child
		bottle = bottle_instance.find_child("*", true, false) as Bottle

	if not bottle:
		push_error("Could not find Bottle script in bottle.tscn!")
		bottle_instance.queue_free()
		return

	# Set car reference
	bottle.car_body = car_node

	# Always add bottle to scene root (not as child of car to avoid collision issues)
	get_tree().root.add_child(bottle_instance)

	# IMPORTANT: Set position AFTER adding to tree
	bottle.global_transform = global_transform

	# Calculate local offset from car for tracking
	if car_node:
		var car_transform_inv = car_node.global_transform.affine_inverse()
		var local_offset = car_transform_inv * global_position
		bottle.set_dashboard_position(local_offset, Vector3.ZERO)
	else:
		# Fallback: use position as-is
		bottle.set_dashboard_position(global_position, Vector3.ZERO)

	print("Bottle spawned! Global pos: ", bottle.global_position, " Manager pos: ", global_position)

func throw_bottle() -> void:
	"""Throw the bottle in the direction of camera forward with force"""
	if not bottle or not is_instance_valid(bottle) or not camera:
		return

	# Calculate throw direction (camera forward)
	var throw_direction = -camera.global_transform.basis.z

	# Throw strength based on distance from camera (further = faster throw) - REDUCED
	var throw_strength = 4.0 + (bottle.drag_distance * 1.0)

	# Calculate throw velocity
	var throw_velocity = throw_direction * throw_strength

	# Add slight upward component for arc - REDUCED
	throw_velocity.y += 1.0

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

	# Add to buffer for debouncing
	hover_state_buffer[hover_buffer_index] = hovering
	hover_buffer_index = (hover_buffer_index + 1) % 3

	# Only change hover state if all 3 buffer values agree
	var all_hovering = hover_state_buffer[0] and hover_state_buffer[1] and hover_state_buffer[2]
	var all_not_hovering = not hover_state_buffer[0] and not hover_state_buffer[1] and not hover_state_buffer[2]

	if all_hovering and not is_hovering_bottle:
		is_hovering_bottle = true
		_set_crosshair_hover(true)
	elif all_not_hovering and is_hovering_bottle:
		is_hovering_bottle = false
		_set_crosshair_hover(false)

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
