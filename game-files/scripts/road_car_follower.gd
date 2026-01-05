extends Node3D

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

var cur_speed := 0.0
var _force_start_rp: Node3D = null

const MAX_SPEED := 100
const ACCEL_STRENGTH := 3.5
const BRAKE_STRENGTH := 6.0
const MIN_SPEED := 0.0
const FULLSTOP_SPEED := 0.5

# Ordered list of dictionaries: {seg: RoadSegment, from_start: bool}
var _route: Array = []
var _current_seg_idx := 0
var _distance_on_seg := 0.0
var _container: Node
var _smoothed_basis: Basis

func _ready() -> void:
	_container = _find_container()
	if _container == null:
		push_warning("RoadContainer not found; car will remain idle.")
		return

	_route = _build_route(_container)
	if _route.is_empty():
		call_deferred("_retry_build_route")
		return

	_current_seg_idx = 0
	_distance_on_seg = 0.0
	_apply_transform(0.0)

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
	if _route.is_empty():
		return

	_update_speed(delta)
	_advance_along_route(delta)
	_apply_transform(delta)

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

	var travel_sign := -1.0 if invert_travel else 1.0
	var signed_move := cur_speed * delta * travel_sign
	var remaining := signed_move

	while remaining != 0.0:
		var info: Dictionary = _route[_current_seg_idx]
		var seg = info["seg"]
		var seg_len = max(seg.curve.get_baked_length(), 0.001)

		_distance_on_seg += remaining

		if _distance_on_seg >= 0.0 and _distance_on_seg <= seg_len:
			break

		if _distance_on_seg > seg_len:
			remaining = _distance_on_seg - seg_len

			if _current_seg_idx == _route.size() - 1:
				if _try_transition_to_next_road():
					return

				if loop_route and loop_road_point_path != NodePath(""):
					if _try_loop_to_specific_point():
						return

				if not loop_route:
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
		return false

	var last_info = _route.back()
	var last_seg = last_info["seg"]
	var last_from_start = last_info["from_start"]
	var end_point = last_seg.end_point if last_from_start else last_seg.start_point
	var end_pos = end_point.global_position

	var containers = _find_all_road_containers(get_tree().current_scene)

	var best_container = null
	var best_rp = null
	var min_dist = transition_distance * transition_distance

	for cont in containers:
		if cont == _container:
			continue
		if not cont.has_method("get_roadpoints"):
			continue

		var rps = cont.get_roadpoints()
		for rp in rps:
			var d = rp.global_position.distance_squared_to(end_pos)
			if d < min_dist:
				min_dist = d
				best_container = cont
				best_rp = rp

	if best_container:
		_container = best_container
		_force_start_rp = best_rp
		_route = _build_route(_container)
		if _route.is_empty():
			return false

		_current_seg_idx = 0
		_distance_on_seg = 0.0
		_apply_transform(0.0) # Snap to new road start
		return true

	return false

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
	if not Input.is_action_pressed("Brakes"):
		var diff := MAX_SPEED - cur_speed
		cur_speed += diff * (1.0 - exp(-ACCEL_STRENGTH * delta))
	else:
		var brake_power := BRAKE_STRENGTH * (cur_speed / MAX_SPEED)
		cur_speed -= brake_power * delta
		if cur_speed <= FULLSTOP_SPEED:
			cur_speed = MIN_SPEED
