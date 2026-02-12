extends Node3D

# Signal emitted when car starts a new lap
signal lap_started(lap_number: int)

const LEAVE_CAR_DIALOGUE = preload("res://dialogue/leave_car_dialogue.dialogue")
const CAR_BREAKDOWN_DIALOGUE = preload("res://dialogue/car_breakdown_dialogue.dialogue")

@export_node_path("Node3D") var road_container_path
@export_node_path("Node3D") var start_road_point_path
@export var forward_sample_distance := 1.5
@export var ride_height := 0.4
@export var invert_forward := true
@export var invert_travel := false
@export var steering_slerp := 0.05  # 0 = instant, 1 = very slow turn
@export var steering_preview_distance := 5  # extra meters looked ahead for steering
@export var steering_preview_speed_factor := 0.25  # meters of lookahead added per m/s
@export var steering_far_multiplier := 6  # extra far lookahead multiplier to soften tight turns
@export var loop_route := true
@export_node_path("Node3D") var loop_road_point_path = NodePath("")
@export var transition_distance := 10.0
@export var loop_to_first_terrain := true  # When true, loops back to first terrain after last one

# Torre teleport settings
@export_node_path("Node3D") var torre_road_container_path = NodePath("")
@export_node_path("Node3D") var torre_start_road_point_path = NodePath("")
@export_node_path("Node3D") var torre_stop_road_point_path = NodePath("")  # Stop when reaching this point

# Player controller for walking
@export_node_path("CharacterBody3D") var player_controller_path = NodePath("")

var cur_speed := 0.0
var _force_start_rp: Node3D = null
var _stop_at_road_point: Node3D = null  # If set, car will stop when reaching this point
var _should_stop := false  # Flag to indicate car should stop
var _can_leave_car := false  # True when stopped at torre stop point
var _leave_prompt_shown := false
var _leave_dialogue_active := false
var _leave_last_title := ""
var _in_walking_mode := false  # True when player has left the car
var _player_controller: CharacterBody3D = null
var _dialogue_active := false  # True when dialogue is active, disables player input
var _breakdown_leave_prompt_ui: Control = null  # UI for "Press L to leave car" after breakdown
var _waiting_for_breakdown_leave := false  # True when waiting for player to press L after breakdown

const MAX_SPEED := 30
const ACCEL_STRENGTH := 3.5
const BRAKE_STRENGTH := 100
const MIN_SPEED := 0.0
const FULLSTOP_SPEED := 6

# Ordered list of dictionaries: {seg: RoadSegment, from_start: bool}
var _route: Array = []
var _current_seg_idx := 0
var _distance_on_seg := 0.0
var _container: Node
var _smoothed_basis: Basis
var _first_container: Node = null  # Store the first container for looping
var _first_start_rp: Node3D = null  # Store the first starting roadpoint
var _current_lap: int = 1  # Track current lap number
var _global_env_resource: Environment = null
var _global_compositor

# Audio
var _idle_audio: AudioStreamPlayer = null
var _is_idle: bool = false
var _idle_fading_in: bool = false
var _driving_audio: AudioStreamPlayer = null
var _is_braking: bool = false
var _volume_fade_speed: float = 2.0  # Volume decrease per second when braking
var _idle_fade_in_speed: float = 14.0  # Volume increase per second for idle fade-in
var _idle_max_volume: float = -8.0  # Maximum volume for idle sound (lower than driving)

func _ready() -> void:
	_container = _find_container()
	if _container == null:
		push_warning("RoadContainer not found; car will remain idle.")
		return

	_route = _build_route(_container)
	if _route.is_empty():
		call_deferred("_retry_build_route")
		return

	# Store the first container and starting point for looping
	if _first_container == null:
		_first_container = _container
		if not _route.is_empty():
			var first_info = _route[0]
			var first_seg = first_info["seg"]
			var first_from_start = first_info["from_start"]
			_first_start_rp = first_seg.start_point if first_from_start else first_seg.end_point

	_current_seg_idx = 0
	_distance_on_seg = 0.0
	_apply_transform(0.0)

	# Setup audio
	_setup_idle_audio()
	_setup_driving_audio()

func _retry_build_route() -> void:
	if _container == null:
		return
	if not _route.is_empty():
		return

	_route = _build_route(_container)
	if _route.is_empty():
		push_warning("No drivable segments found from RoadContainer; car will remain idle.")
		return

	_current_seg_idx = 0
	_distance_on_seg = 0.0
	_apply_transform(0.0)

func _process(delta: float) -> void:
	# Don't process car movement when in walking mode
	if _in_walking_mode:
		return

	if _route.is_empty():
		return

	# Handle input for leaving car after breakdown
	if _waiting_for_breakdown_leave and Input.is_action_just_pressed("toggle_headlights"):  # L key
		_waiting_for_breakdown_leave = false
		_hide_breakdown_leave_prompt()
		leave_car()
		return

	# Handle input for torre teleport
	if Input.is_action_just_pressed("teleport_to_torre"):  # F key
		teleport_to_torre()

	if not _should_stop:
		_update_speed(delta)
	_advance_along_route(delta)
	_apply_transform(delta)

	# Handle audio based on velocity and braking
	_update_audio(delta)

func _find_container() -> Node:
	if road_container_path != NodePath(""):
		var from_export = get_node_or_null(road_container_path)
		if from_export:
			if from_export.has_method("is_road_container"):
				return from_export
			# Search inside the assigned node (e.g. if user assigned a scene root)
			var inner = _search_container_recursive(from_export)
			if inner:
				return inner

	var root = get_tree().current_scene
	if root == null:
		return null
	return _search_container_recursive(root)

func _search_container_recursive(root: Node) -> Node:
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_method("is_road_container"):
			return node

		# Push children in reverse order so the first child is popped first
		var children = node.get_children()
		for i in range(children.size() - 1, -1, -1):
			stack.append(children[i])
	return null

func _build_route(container: Node) -> Array:
	if not container.has_method("get_roadpoints"):
		return []

	_prepare_segments(container)

	var rps: Array = container.get_roadpoints()
	if rps.is_empty():
		return []

	var start_rp: Node3D = _choose_start_rp(container, rps)
	if start_rp == null:
		return []

	var segment_map := _build_segment_map(container)
	var route: Array = []
	var visited_rp := {}
	var visited_seg := {}
	var prev_rp: Node3D = null
	var current_rp: Node3D = start_rp

	while current_rp and not visited_rp.has(current_rp):
		visited_rp[current_rp] = true
		var next_rp = _next_rp(current_rp, prev_rp)
		if next_rp == null:
			break

		var seg = _segment_between(current_rp, next_rp, segment_map)
		if seg == null or visited_seg.has(seg):
			break

		var from_start: bool = seg.start_point == current_rp
		route.append({"seg": seg, "from_start": from_start})
		visited_seg[seg] = true

		prev_rp = current_rp
		current_rp = next_rp

	return route

func _choose_start_rp(container: Node, rps: Array) -> Node3D:
	if _force_start_rp != null and _force_start_rp.is_inside_tree():
		# Verify it belongs to this container?
		# Usually we trust the transition logic.
		var rp = _force_start_rp
		_force_start_rp = null
		return rp

	var candidate: Node3D = null
	if start_road_point_path != NodePath(""):
		candidate = container.get_node_or_null(start_road_point_path)
		if candidate == null:
			candidate = get_node_or_null(start_road_point_path)
		if candidate != null and candidate.has_method("is_road_point"):
			return candidate
		push_warning("Start road point path did not resolve to a RoadPoint; falling back to closest.")

	return _find_closest_rp(rps)

func _prepare_segments(container: Node) -> void:
	if container.has_method("rebuild_segments"):
		container.rebuild_segments()

func _build_segment_map(container: Node) -> Dictionary:
	var result: Dictionary = {}
	if not container.has_method("get_segments"):
		return result
	for seg in container.get_segments():
		if not seg.has_method("get_id"):
			continue
		var key: String = seg.get_id()
		result[key] = seg
	return result

func _segment_between(a: Node3D, b: Node3D, segment_map: Dictionary):
	var key: String = ""
	if segment_map.is_empty():
		return null
	if segment_map.keys().is_empty():
		return null
	if a.has_method("get_instance_id") and b.has_method("get_instance_id"):
		key = str(min(a.get_instance_id(), b.get_instance_id())) + "-" + str(max(a.get_instance_id(), b.get_instance_id()))
	return segment_map.get(key, null)

func _next_rp(current: Node3D, prev: Node3D) -> Node3D:
	# Prefer explicit next pointer, fall back to prior if needed.
	var rp_next: NodePath = current.next_pt_init
	var next_rp: Node3D = null
	if rp_next != NodePath(""):
		next_rp = current.get_node_or_null(rp_next)
	if next_rp == null or next_rp == prev:
		var rp_prior: NodePath = current.prior_pt_init
		if rp_prior != NodePath(""):
			next_rp = current.get_node_or_null(rp_prior)
			if next_rp == prev:
				next_rp = null
	return next_rp

func _find_closest_rp(rps: Array) -> Node3D:
	var closest: Node3D = null
	var closest_dist := INF
	for rp in rps:
		var d = rp.global_position.distance_squared_to(global_transform.origin)
		if d < closest_dist:
			closest = rp
			closest_dist = d
	return closest

func _advance_along_route(delta: float) -> void:
	if _route.is_empty():
		return

	# Bounds check for current segment index
	if _current_seg_idx < 0 or _current_seg_idx >= _route.size():
		_current_seg_idx = 0
		return

	# Check if we've reached the stop point
	if _stop_at_road_point != null and not _should_stop:
		var info: Dictionary = _route[_current_seg_idx]
		var seg = info["seg"]
		var from_start: bool = info["from_start"]
		var current_end_point = seg.end_point if from_start else seg.start_point

		# Check if we're approaching the stop point
		if current_end_point == _stop_at_road_point:
			var seg_len = max(seg.curve.get_baked_length(), 0.001)
			# If we're near the end of this segment, start stopping
			if _distance_on_seg >= seg_len * 0.9:
				_should_stop = true
				cur_speed = 0.0
				_can_leave_car = true
				print("DEBUG: Reached stop point, stopping car. Press L to leave car.")
				if not _leave_prompt_shown:
					_show_leave_car_prompt()

	var travel_sign := -1.0 if invert_travel else 1.0
	var signed_move := cur_speed * delta * travel_sign
	var remaining := signed_move

	while remaining != 0.0:
		# Safety check inside loop
		if _current_seg_idx < 0 or _current_seg_idx >= _route.size():
			_current_seg_idx = 0
			break

		var info: Dictionary = _route[_current_seg_idx]
		var seg = info["seg"]
		var seg_len = max(seg.curve.get_baked_length(), 0.001)

		_distance_on_seg += remaining

		if _distance_on_seg >= 0.0 and _distance_on_seg <= seg_len:
			break

		if _distance_on_seg > seg_len:
			remaining = _distance_on_seg - seg_len

			if _current_seg_idx == _route.size() - 1:
				print("DEBUG: Reached end of route, attempting transition...")
				if _try_transition_to_next_road():
					print("DEBUG: Transition successful!")
					return

				if loop_route and loop_road_point_path != NodePath(""):
					print("DEBUG: Attempting loop to specific point...")
					if _try_loop_to_specific_point():
						print("DEBUG: Loop successful!")
						return

				# Check if we should teleport to torre after hitchhiker 4
				var game_manager = get_node_or_null("../GameManager")
				if game_manager and game_manager.has_method("should_teleport_to_torre") and game_manager.should_teleport_to_torre():
					print("DEBUG: Hitchhiker 4 completed - teleporting to torre instead of looping")
					teleport_to_torre()
					return

				# Try to loop back to the first terrain
				if loop_to_first_terrain and _first_container != null and _first_start_rp != null:
					print("DEBUG: Attempting to loop back to first terrain...")
					if _try_loop_to_first_terrain():
						print("DEBUG: Looped back to first terrain successfully!")
						return

				# If we reach here and no transition happened, stop the car
				# instead of looping back (which causes U-turn)
				print("DEBUG: No transition found, stopping car to prevent U-turn")
				cur_speed = 0.0
				remaining = 0.0
				_distance_on_seg = seg_len
				break

			_current_seg_idx = (_current_seg_idx + 1) % _route.size()
			_distance_on_seg = 0.0
			continue

		# _distance_on_seg < 0.0
		remaining = _distance_on_seg
		_current_seg_idx = (_current_seg_idx - 1 + _route.size()) % _route.size()
		var prev_info: Dictionary = _route[_current_seg_idx]
		var prev_seg = prev_info["seg"]
		var prev_len = max(prev_seg.curve.get_baked_length(), 0.001)
		_distance_on_seg = prev_len + remaining
		remaining = 0.0 if _distance_on_seg >= 0.0 else _distance_on_seg
		if _distance_on_seg < 0.0:
			continue

func _apply_transform(delta: float) -> void:
	if _route.is_empty():
		return

	# Bounds check
	if _current_seg_idx < 0 or _current_seg_idx >= _route.size():
		_current_seg_idx = 0
		return

	var info: Dictionary = _route[_current_seg_idx]
	var seg = info["seg"]
	var seg_len = max(seg.curve.get_baked_length(), 0.001)
	var from_start: bool = info["from_start"]

	var distance_on_curve: float = _distance_on_seg if from_start else seg_len - _distance_on_seg
	var pos_local = seg.curve.sample_baked(distance_on_curve)
	var pos = seg.to_global(pos_local)

	var base_lookahead := forward_sample_distance + steering_preview_distance + cur_speed * steering_preview_speed_factor
	var near_lookahead := base_lookahead
	var far_lookahead := base_lookahead * steering_far_multiplier
	var travel_dir := -1.0 if invert_travel else 1.0
	var progression_sign := travel_dir if from_start else -travel_dir
	var ahead_offset_near = clamp(distance_on_curve + progression_sign * near_lookahead, 0.0, seg_len)
	var ahead_offset_far = clamp(distance_on_curve + progression_sign * far_lookahead, 0.0, seg_len)
	var ahead_local_near = seg.curve.sample_baked(ahead_offset_near)
	var ahead_local_far = seg.curve.sample_baked(ahead_offset_far)
	var ahead_near = seg.to_global(ahead_local_near)
	var ahead_far = seg.to_global(ahead_local_far)

	var dir_near: Vector3 = (ahead_near - pos).normalized()
	var dir_far: Vector3 = (ahead_far - pos).normalized()
	var forward: Vector3 = (dir_near + dir_far).normalized()
	if forward.length() < 0.001:
		forward = seg.global_transform.basis.z
	if invert_forward:
		forward = -forward

	# Align yaw to the road normal while keeping a right-handed basis.
	var start_basis: Basis = seg.start_point.global_transform.basis if from_start else seg.end_point.global_transform.basis
	var end_basis: Basis = seg.end_point.global_transform.basis if from_start else seg.start_point.global_transform.basis
	var t: float = clamp(_distance_on_seg / seg_len, 0.0, 1.0)
	var road_up: Vector3 = start_basis.y.lerp(end_basis.y, t).normalized()
	if road_up.dot(Vector3.UP) < 0.0:
		road_up = -road_up

	# Project forward onto the plane defined by road_up to follow road banking.
	forward = (forward - road_up * forward.dot(road_up)).normalized()
	if forward.length() < 0.001:
		forward = seg.global_transform.basis.z
	var right: Vector3 = road_up.cross(forward)
	if right.length() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up: Vector3 = forward.cross(right).normalized()

	var basis = Basis(right, up, forward).orthonormalized()
	pos += up * ride_height

	if _smoothed_basis == null:
		_smoothed_basis = basis
	else:
		var w: float = 1.0 - exp(-max(steering_slerp, 0.0) * delta * 60.0)
		w = clamp(w, 0.0, 1.0)
		var q_cur: Quaternion = _smoothed_basis.get_rotation_quaternion()
		var q_tgt: Quaternion = basis.get_rotation_quaternion()
		var q_blend: Quaternion = q_cur.slerp(q_tgt, w)
		_smoothed_basis = Basis(q_blend).orthonormalized()

	global_transform = Transform3D(_smoothed_basis, pos)

func _try_loop_to_specific_point() -> bool:
	if loop_road_point_path == null or loop_road_point_path == NodePath(""):
		return false

	var target_rp = get_node_or_null(loop_road_point_path)
	if not target_rp:
		return false

	# Find which container owns this RP
	var container = _find_container_for_rp(target_rp)
	if not container:
		return false

	_container = container
	_force_start_rp = target_rp
	_route = _build_route(_container)
	if _route.is_empty():
		return false

	_current_seg_idx = 0
	_distance_on_seg = 0.0
	_apply_transform(0.0)
	return true

func _find_container_for_rp(rp: Node) -> Node:
	var p = rp.get_parent()
	while p:
		if p.has_method("is_road_container"):
			return p
		p = p.get_parent()
	return null

func _try_transition_to_next_road() -> bool:
	if _route.is_empty():
		print("DEBUG: Route is empty, cannot transition")
		return false

	var last_info = _route.back()
	var last_seg = last_info["seg"]
	var last_from_start = last_info["from_start"]
	var end_point = last_seg.end_point if last_from_start else last_seg.start_point
	var end_pos = end_point.global_position

	# Calculate the current travel direction to find a roadpoint that continues forward
	var seg_len = max(last_seg.curve.get_baked_length(), 0.001)
	var sample_dist = min(1.0, seg_len * 0.1)  # Sample 10% back from end or 1.0m
	var distance_on_curve: float
	if last_from_start:
		distance_on_curve = seg_len - sample_dist
	else:
		distance_on_curve = sample_dist

	var prev_pos_local = last_seg.curve.sample_baked(distance_on_curve)
	var prev_pos = last_seg.to_global(prev_pos_local)
	var travel_direction = (end_pos - prev_pos).normalized()

	print("DEBUG: Current end position: ", end_pos)
	print("DEBUG: Travel direction: ", travel_direction)
	print("DEBUG: Transition distance threshold: ", transition_distance)

	var containers = _find_all_road_containers(get_tree().current_scene)
	print("DEBUG: Found ", containers.size(), " road containers total")

	var best_container = null
	var best_rp = null
	var best_next_rp = null
	var min_dist = transition_distance * transition_distance
	var best_score = -999.0  # Combined score: distance + direction alignment

	for cont in containers:
		if cont == _container:
			continue
		if not cont.has_method("get_roadpoints"):
			continue

		var rps = cont.get_roadpoints()
		print("DEBUG: Checking container with ", rps.size(), " roadpoints")
		for rp in rps:
			var d = rp.global_position.distance_squared_to(end_pos)
			var actual_dist = sqrt(d)

			if d < min_dist:
				# Check the direction from this roadpoint to its next point
				var next_rp = _peek_next_rp(rp, null)
				if next_rp != null:
					var forward_dir = (next_rp.global_position - rp.global_position).normalized()
					var direction_alignment = travel_direction.dot(forward_dir)

					# Score combines closeness and forward alignment
					# Prefer roadpoints that continue in the same direction
					var score = direction_alignment - (actual_dist / transition_distance) * 0.5

					print("DEBUG: Roadpoint at distance ", actual_dist, " alignment: ", direction_alignment, " score: ", score)

					if score > best_score:
						print("DEBUG: New best roadpoint! Score: ", score)
						min_dist = d
						best_container = cont
						best_rp = rp
						best_next_rp = next_rp
						best_score = score
				else:
					print("DEBUG: Roadpoint at distance ", actual_dist, " has no next point, skipping")
			elif actual_dist < transition_distance * 2:
				print("DEBUG: Nearby roadpoint at distance: ", actual_dist, " (too far, threshold is ", transition_distance, ")")

	if best_container and best_rp:
		print("DEBUG: Transitioning to new container, closest distance: ", sqrt(min_dist), " score: ", best_score)
		_container = best_container
		_force_start_rp = best_rp
		_route = _build_route(_container)
		if _route.is_empty():
			print("DEBUG: New route is empty, transition failed")
			return false

		_current_seg_idx = 0
		_distance_on_seg = 0.0
		_apply_transform(0.0) # Snap to new road start
		return true

	print("DEBUG: No suitable container found for transition")
	return false

func _peek_next_rp(current: Node3D, prev: Node3D) -> Node3D:
	# Same as _next_rp but doesn't modify state - just peeks at what's next
	var rp_next: NodePath = current.next_pt_init
	var next_rp: Node3D = null
	if rp_next != NodePath(""):
		next_rp = current.get_node_or_null(rp_next)
		# Ensure initial lighting/environment use the global (non-torre) setup
		_set_torre_environment(false)
	if next_rp == null or next_rp == prev:
		var rp_prior: NodePath = current.prior_pt_init
		if rp_prior != NodePath(""):
			next_rp = current.get_node_or_null(rp_prior)
			if next_rp == prev:
				next_rp = null
	return next_rp

func _try_loop_to_first_terrain() -> bool:
	if _first_container == null or _first_start_rp == null:
		print("DEBUG: First container or start point not available")
		return false

	if not _first_container.is_inside_tree() or not _first_start_rp.is_inside_tree():
		print("DEBUG: First container or start point no longer in tree")
		return false

	print("DEBUG: Looping back to first terrain")
	_container = _first_container
	_force_start_rp = _first_start_rp
	_route = _build_route(_container)

	if _route.is_empty():
		print("DEBUG: Failed to build route from first terrain")
		return false

	_current_seg_idx = 0
	_distance_on_seg = 0.0
	_apply_transform(0.0)

	# Increment lap counter and emit signal
	_current_lap += 1
	lap_started.emit(_current_lap)
	print("Started lap ", _current_lap)

	return true

func _find_all_road_containers(root: Node) -> Array:
	var result = []
	if root == null:
		return result

	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_method("is_road_container"):
			result.append(node)

		for child in node.get_children():
			stack.append(child)
	return result

func _update_speed(delta: float) -> void:
	# Simulate brake input during dialogue
	var braking = Input.is_action_pressed("Brakes") or _dialogue_active

	if not braking:
		var diff := MAX_SPEED - cur_speed
		cur_speed += diff * (1.0 - exp(-ACCEL_STRENGTH * delta))
	else:
		var brake_power := BRAKE_STRENGTH * (cur_speed / MAX_SPEED)
		cur_speed -= brake_power * delta
		if cur_speed <= FULLSTOP_SPEED:
			cur_speed = MIN_SPEED

## Teleport the car to torre.tscn road and follow until stop point
func teleport_to_torre() -> void:
	if torre_road_container_path == NodePath("") or torre_start_road_point_path == NodePath(""):
		push_warning("Torre road container or start point not configured")
		return

	var torre_container = get_node_or_null(torre_road_container_path)
	var torre_start_rp = get_node_or_null(torre_start_road_point_path)

	if torre_container == null:
		push_warning("Torre road container not found at path: ", torre_road_container_path)
		return

	if torre_start_rp == null:
		push_warning("Torre start road point not found at path: ", torre_start_road_point_path)
		return

	# Verify container has required methods
	if not torre_container.has_method("is_road_container"):
		push_warning("Torre container does not have required road container methods")
		return

	# Set stop point if configured
	_stop_at_road_point = null
	_should_stop = false
	if torre_stop_road_point_path != NodePath(""):
		_stop_at_road_point = get_node_or_null(torre_stop_road_point_path)
		if _stop_at_road_point == null:
			push_warning("Torre stop road point not found at path: ", torre_stop_road_point_path)

	# Switch to torre road
	_container = torre_container
	_force_start_rp = torre_start_rp

	# Build route with error handling
	_route = _build_route(_container)

	if _route.is_empty():
		push_warning("Failed to build route for torre road - check that road points are connected")
		# Restore previous state to avoid breaking the car
		_container = _first_container if _first_container else _find_container()
		if _container:
			_force_start_rp = null
			_route = _build_route(_container)
			_current_seg_idx = 0
			_distance_on_seg = 0.0
		return

	_current_seg_idx = 0
	_distance_on_seg = 0.0
	cur_speed = 0.0  # Start from stopped
	_apply_transform(0.0)

	print("DEBUG: Teleported to torre road, will stop at: ", _stop_at_road_point.name if _stop_at_road_point else "end of route")

	# Stop radio and start empathy-based base track
	RadioManager.switch_to_base_track()

	# Switch lighting, environment and clouds to torre setup
	_set_torre_environment(true)

## Leave the car and switch to walking mode

## Stop car for dialogue and disable player input
## Call this from dialogues using: do road_car_follower.start_dialogue()
## Or connect to DialogueManager.dialogue_started signal
func start_dialogue() -> void:
	_dialogue_active = true
	print("Car stopped for dialogue - input disabled")

## Resume car control after dialogue ends
## Call this from dialogues using: do road_car_follower.end_dialogue()
## Or connect to DialogueManager.dialogue_ended signal
func end_dialogue() -> void:
	_dialogue_active = false
	print("Car control resumed - input enabled")

func leave_car() -> void:
	if not _can_leave_car:
		print("DEBUG: Cannot leave car - not stopped at destination")
		return

	# Get or find player controller
	if player_controller_path != NodePath(""):
		_player_controller = get_node_or_null(player_controller_path)

	if _player_controller == null:
		# Try to find it in the scene
		_player_controller = get_tree().current_scene.find_child("PlayerController", true, false)

	if _player_controller == null:
		push_warning("Player controller not found. Set player_controller_path or add PlayerController to scene")
		return

	# Position player at car's location
	var exit_offset = Vector3(2, 0, 0)  # Exit to the right side of the car
	var exit_position = global_transform.origin + global_transform.basis.x * exit_offset.x
	_player_controller.global_position = exit_position

	# Activate player controller
	if _player_controller.has_method("activate"):
		_player_controller.activate()

	# Stop car audio when leaving
	if _idle_audio and _idle_audio.playing:
		_idle_audio.stop()
	if _driving_audio and _driving_audio.playing:
		_driving_audio.stop()

	_in_walking_mode = true
	_disable_car_crosshair()
	_show_torre_parked_car()
	print("DEBUG: Left car, walking mode activated. Use WASD to move, mouse to look around.")


func _show_torre_parked_car() -> void:
	# Hide the driving car and show the parked torre car model.
	var carro = get_node_or_null("Carro")
	if carro:
		carro.visible = false

	var root = get_tree().get_current_scene()
	if root and root.has_node("torre/carro_exterior/carro_mod_25d"):
		var parked_car = root.get_node("torre/carro_exterior/carro_mod_25d")
		parked_car.visible = true

	# Show the main torre arrow when leaving the car
	if root and root.has_node("torre/arrow"):
		var arrow = root.get_node("torre/arrow")
		arrow.visible = true


func _disable_car_crosshair() -> void:
	var carro = get_node_or_null("Carro")
	if carro and carro.has_node("Player/Control/CrossHair"):
		var crosshair = carro.get_node("Player/Control/CrossHair")
		# Stop processing input/logic and hide the UI
		crosshair.set_process(false)
		crosshair.set_process_input(false)
		crosshair.set_process_unhandled_input(false)
		crosshair.visible = false


func _enable_car_crosshair() -> void:
	var carro = get_node_or_null("Carro")
	if carro and carro.has_node("Player/Control/CrossHair"):
		var crosshair = carro.get_node("Player/Control/CrossHair")
		crosshair.visible = true
		crosshair.set_process(true)
		crosshair.set_process_input(true)
		crosshair.set_process_unhandled_input(true)


func return_to_car_from_torre() -> void:
	# Show the driving car again and hide the parked torre car
	var carro = get_node_or_null("Carro")
	if carro:
		carro.visible = true

	var root = get_tree().get_current_scene()
	if root and root.has_node("torre/carro_exterior/carro_mod_25d"):
		var parked_car = root.get_node("torre/carro_exterior/carro_mod_25d")
		parked_car.visible = false

	# Deactivate walking controller
	if player_controller_path != NodePath("") and _player_controller == null:
		_player_controller = get_node_or_null(player_controller_path)
	if _player_controller and _player_controller.has_method("deactivate"):
		_player_controller.deactivate()

	# Re-enable the in-car crosshair and resume car mode
	_enable_car_crosshair()
	_in_walking_mode = false
	_can_leave_car = false
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)


func _show_leave_car_prompt() -> void:
	_leave_prompt_shown = true

	# Check empathy to determine which ending path
	# Use DialogueFlow.empathy (the actual empathy system used during gameplay)
	var df = get_node_or_null("/root/DialogueFlow")
	var empathy := 0
	if df:
		empathy = df.empathy

	print("DEBUG: Torre ending - empathy score is: ", empathy)

	if empathy > 70:
		# Good empathy: Show car breakdown message, then allow player to leave car
		print("DEBUG: Triggering GOOD empathy ending (empathy > 70)")
		_show_good_empathy_breakdown()
	else:
		# Bad empathy (<=70): Show "do it" dialogue that leads to hard cut ending
		print("DEBUG: Triggering BAD empathy ending (empathy <= 70)")
		_show_bad_empathy_ending()


func _on_leave_car_passed_title(title: String) -> void:
	_leave_last_title = title


func _show_bad_empathy_ending() -> void:
	_leave_dialogue_active = true
	_leave_last_title = ""

	DialogueManager.passed_title.connect(_on_bad_ending_passed_title)
	DialogueManager.dialogue_ended.connect(_on_bad_ending_dialogue_ended)
	DialogueManager.show_example_dialogue_balloon(LEAVE_CAR_DIALOGUE, "start")


func _on_bad_ending_passed_title(title: String) -> void:
	_leave_last_title = title


func _on_bad_ending_dialogue_ended(_resource: DialogueResource) -> void:
	DialogueManager.passed_title.disconnect(_on_bad_ending_passed_title)
	DialogueManager.dialogue_ended.disconnect(_on_bad_ending_dialogue_ended)
	_leave_dialogue_active = false

	# Player chose "DO IT" - hard cut to black and credits
	if _leave_last_title == "do_it":
		_trigger_hard_cut_credits()


func _show_good_empathy_breakdown() -> void:
	_leave_dialogue_active = true
	_leave_last_title = ""

	DialogueManager.passed_title.connect(_on_breakdown_passed_title)
	DialogueManager.dialogue_ended.connect(_on_breakdown_dialogue_ended)
	DialogueManager.show_example_dialogue_balloon(CAR_BREAKDOWN_DIALOGUE, "start")


func _on_breakdown_passed_title(title: String) -> void:
	_leave_last_title = title


func _on_breakdown_dialogue_ended(_resource: DialogueResource) -> void:
	DialogueManager.passed_title.disconnect(_on_breakdown_passed_title)
	DialogueManager.dialogue_ended.disconnect(_on_breakdown_dialogue_ended)
	_leave_dialogue_active = false

	# Player chose to leave - show prompt to press L
	if _leave_last_title == "leave":
		_show_breakdown_leave_prompt()


func _show_breakdown_leave_prompt() -> void:
	if _breakdown_leave_prompt_ui != null:
		return  # Already showing

	_waiting_for_breakdown_leave = true

	# Create UI similar to invisible wall dialogue
	_breakdown_leave_prompt_ui = Control.new()
	_breakdown_leave_prompt_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_breakdown_leave_prompt_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	_breakdown_leave_prompt_ui.add_child(canvas)

	var label = Label.new()
	label.text = "Press L to leave the car\n\n\nWASD to walk around"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -400
	label.offset_right = 400
	label.offset_top = -60
	label.offset_bottom = 60

	# Load custom font (same as invisible wall and dialogue)
	var font = load("res://fonts/SpecialElite-Regular.ttf")
	if font:
		label.add_theme_font_override("font", font)

	# Style the label
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)

	canvas.add_child(label)
	get_tree().root.add_child(_breakdown_leave_prompt_ui)


func _hide_breakdown_leave_prompt() -> void:
	if _breakdown_leave_prompt_ui != null:
		_breakdown_leave_prompt_ui.queue_free()
		_breakdown_leave_prompt_ui = null


func _trigger_hard_cut_credits() -> void:
	print("DEBUG: _trigger_hard_cut_credits called (road_car_follower)")
	# Hard cut: immediately stop music and cut to black, then show credits
	RadioManager._stop_all()
	RadioManager._stop_base_track()
	print("DEBUG: Music stopped")

	# Load credits scene with hard cut mode
	var credits_scene = load("res://scenes/credits.tscn")
	print("DEBUG: Credits scene loaded: ", credits_scene != null)
	if credits_scene:
		var credits = credits_scene.instantiate()
		print("DEBUG: Credits instantiated: ", credits != null)
		if credits.has_method("set_hard_cut_mode"):
			credits.set_hard_cut_mode(true)
			print("DEBUG: Hard cut mode set")
		print("DEBUG: Adding credits to tree...")
		get_tree().root.add_child(credits)
		print("DEBUG: Credits added to tree")
	else:
		print("ERROR: Failed to load credits scene!")

func _set_torre_environment(active: bool) -> void:
	# When active is true, switch lighting, environment and clouds to the torre setup.
	# We keep using the root WorldEnvironment node, but swap its Environment/Compositor
	# to match torre's settings. When false, restore the original global setup.
	var root = get_tree().get_current_scene()
	if root == null:
		return

	var global_env_node = root.get_node_or_null("WorldEnvironment")
	if global_env_node and _global_env_resource == null and global_env_node is WorldEnvironment:
		_global_env_resource = (global_env_node as WorldEnvironment).environment
		_global_compositor = (global_env_node as WorldEnvironment).compositor

	var torre = root.get_node_or_null("torre")
	if torre == null:
		return

	var torre_light = torre.get_node_or_null("DirectionalLight3D")
	var global_light = root.get_node_or_null("DirectionalLight3D")
	if global_light:
		global_light.visible = not active
	if torre_light:
		torre_light.visible = active

	var torre_env_node = torre.get_node_or_null("WorldEnvironment")
	if global_env_node and global_env_node is WorldEnvironment:
		if active:
			# Use torre's environment and compositor on the global WorldEnvironment
			if torre_env_node and torre_env_node is WorldEnvironment:
				(global_env_node as WorldEnvironment).environment = (torre_env_node as WorldEnvironment).environment
				(global_env_node as WorldEnvironment).compositor = (torre_env_node as WorldEnvironment).compositor
		else:
			# Restore original global environment and compositor
			(global_env_node as WorldEnvironment).environment = _global_env_resource
			(global_env_node as WorldEnvironment).compositor = _global_compositor

	# Toggle SunshineClouds only in the final scene
	var clouds = torre.get_node_or_null("SunshineCloudsDriverGD")
	if clouds:
		clouds.set("update_continuously", active)
		clouds.set_process(active)

## Setup the idle audio player
func _setup_idle_audio() -> void:
	# Create AudioStreamPlayer if it doesn't exist
	_idle_audio = AudioStreamPlayer.new()
	_idle_audio.name = "IdleAudio"
	add_child(_idle_audio)

	# Load the idle audio file
	var audio_path = "res://assets/audio/sfx/car_idle.mp3"
	var audio_stream = load(audio_path)
	if audio_stream:
		_idle_audio.stream = audio_stream
		_idle_audio.bus = "Master"
		# Loop the idle sound
		if audio_stream is AudioStreamMP3:
			audio_stream.loop = true
	else:
		push_warning("Failed to load idle audio: ", audio_path)

## Setup the driving audio player
func _setup_driving_audio() -> void:
	# Create AudioStreamPlayer if it doesn't exist
	_driving_audio = AudioStreamPlayer.new()
	_driving_audio.name = "DrivingAudio"
	add_child(_driving_audio)

	# Load the driving audio file
	var audio_path = "res://assets/audio/sfx/car_driving.mp3"
	var audio_stream = load(audio_path)
	if audio_stream:
		_driving_audio.stream = audio_stream
		_driving_audio.bus = "Master"
		_driving_audio.volume_db = 0.0  # 100% volume = 0 dB
		# Loop the driving sound
		if audio_stream is AudioStreamMP3:
			audio_stream.loop = true
	else:
		push_warning("Failed to load driving audio: ", audio_path)

## Update audio based on car velocity and braking state
func _update_audio(delta: float) -> void:
	if _idle_audio == null or _driving_audio == null:
		return

	# Check if car is idle (velocity < 0.1)
	if cur_speed < 0.1:
		# Play idle sound, stop driving sound
		if not _is_idle:
			_is_idle = true
			if not _idle_audio.playing:
				_idle_audio.volume_db = -80.0  # Start at near silence
				_idle_audio.play()
				_idle_fading_in = true

		# Handle fade-in for idle audio
		if _idle_fading_in:
			if _idle_audio.volume_db < _idle_max_volume:
				_idle_audio.volume_db = min(_idle_audio.volume_db + (_idle_fade_in_speed * 10.0 * delta), _idle_max_volume)
			else:
				_idle_fading_in = false

		if _driving_audio.playing:
			_driving_audio.stop()
	else:
		# Car is moving - stop idle sound
		if _is_idle:
			_is_idle = false
			_idle_fading_in = false
			if _idle_audio.playing:
				_idle_audio.stop()

		# Check if braking
		var braking = Input.is_action_pressed("Brakes") or _dialogue_active

		if not _driving_audio.playing:
			_driving_audio.play()
			_driving_audio.volume_db = 0.0  # Start at 100% volume

		if braking:
			# Gradually decrease volume when braking
			if not _is_braking:
				_is_braking = true

			# Decrease volume (convert from dB)
			# 0 dB = 100%, -80 dB = near silence
			var target_volume = -20.0  # Target lower volume when braking
			_driving_audio.volume_db = max(_driving_audio.volume_db - (_volume_fade_speed * 10.0 * delta), target_volume)
		else:
			# Not braking - play at 100% volume
			if _is_braking:
				_is_braking = false

			# Gradually restore to 100% volume
			if _driving_audio.volume_db < 0.0:
				_driving_audio.volume_db = min(_driving_audio.volume_db + (_volume_fade_speed * 10.0 * delta), 0.0)
