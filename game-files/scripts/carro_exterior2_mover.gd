extends PathFollow3D

signal movement_finished

@export var move_speed: float = 25

var _moving: bool = false
var _path_length: float = 0.0
var _car_node: Node3D = null
var _car_offset: Transform3D = Transform3D.IDENTITY
var _has_initial_transform: bool = false

var _distance_on_curve: float = 0.0
var _smoothed_basis: Basis = Basis.IDENTITY
var _position_offset: Vector3 = Vector3.ZERO
var _orientation_offset: Basis = Basis.IDENTITY
var _vertical_offset: float = 0.0

@export_range(0.0, 1.0, 0.01) var smoothing: float = 0.15
@export var ride_height: float = 0.0
@export var forward_sample_distance: float = 2.0
@export var steering_preview_distance: float = 4.0
@export var steering_far_multiplier: float = 3.0

func _ready() -> void:
	# Cache path length
	var path: Node = get_parent()
	if path and path is Path3D and (path as Path3D).curve:
		_path_length = (path as Path3D).curve.get_baked_length()

	# Ensure the PathFollow does not loop back to the start automatically
	loop = false
	rotation_mode = PathFollow3D.ROTATION_XYZ
	tilt_enabled = true

	# Find the external car node in the torre
	var root = get_tree().get_current_scene()
	if root:
		_car_node = root.get_node_or_null("torre/carro_exterior2")
		if _car_node:
			# Use only orientation offset; keep the car centered on the path.
			var follow_global: Transform3D = global_transform
			var car_global: Transform3D = _car_node.global_transform
			_position_offset = Vector3.ZERO
			_orientation_offset = follow_global.basis.inverse() * car_global.basis
			# Store how far the car was along the follow's up axis in the scene.
			var follow_up: Vector3 = follow_global.basis.y.normalized()
			if follow_up.dot(Vector3.UP) < 0.0:
				follow_up = -follow_up
			_vertical_offset = (car_global.origin - follow_global.origin).dot(follow_up)
			# Flip 180 degrees around up so the car faces forward along the path.
			_orientation_offset = _orientation_offset * Basis(Vector3.UP, PI)
			# Make the help car smaller.
			_car_node.scale = Vector3.ONE * 0.5
			# Hide the car until the lift interaction actually starts it moving.
			_car_node.visible = false

	set_process(false)
	_update_car_transform()


func start_moving() -> void:
	if _moving:
		return
	if _car_node:
		_car_node.visible = true
	if _path_length <= 0.0:
		return

	_moving = true
	_distance_on_curve = 0.0
	_has_initial_transform = false
	set_process(true)
	_update_car_transform()


func _process(delta: float) -> void:
	if not _moving:
		return
	if _path_length <= 0.0:
		_moving = false
		set_process(false)
		return

	_distance_on_curve += move_speed * delta
	if _distance_on_curve >= _path_length:
		_distance_on_curve = _path_length
		_update_car_transform()
		_moving = false
		set_process(false)
		emit_signal("movement_finished")
		return

	_update_car_transform()


func _update_car_transform() -> void:
	if _car_node:
		var path: Node = get_parent()
		if not (path and path is Path3D and (path as Path3D).curve):
			return
		var curve: Curve3D = (path as Path3D).curve
		if _path_length <= 0.0:
			return

		var seg_len: float = max(_path_length, 0.001)
		var dist: float = clamp(_distance_on_curve, 0.0, seg_len)
		var pos_local: Vector3 = curve.sample_baked(dist)
		var path_global: Transform3D = (path as Path3D).global_transform
		var pos: Vector3 = path_global * pos_local

		# Use the path's up direction; treat the path as the road surface.
		var path_up: Vector3 = path_global.basis.y.normalized()
		if path_up.dot(Vector3.UP) < 0.0:
			path_up = -path_up

		# Look ahead along the curve to get a stable forward direction.
		var base_lookahead: float = forward_sample_distance + steering_preview_distance
		var near_off: float = clamp(dist + base_lookahead, 0.0, seg_len)
		var far_off: float = clamp(dist + base_lookahead * steering_far_multiplier, 0.0, seg_len)
		var near_local: Vector3 = curve.sample_baked(near_off)
		var far_local: Vector3 = curve.sample_baked(far_off)
		var near_pos: Vector3 = path_global * near_local
		var far_pos: Vector3 = path_global * far_local
		var dir_near: Vector3 = (near_pos - pos).normalized()
		var dir_far: Vector3 = (far_pos - pos).normalized()
		var forward: Vector3 = (dir_near + dir_far).normalized()
		if forward.length() < 0.001:
			forward = -Vector3.FORWARD

		# Use the path normal so the car follows the road's slope.
		var up: Vector3 = path_up

		forward = (forward - up * forward.dot(up)).normalized()
		if forward.length() < 0.001:
			forward = -Vector3.FORWARD
		var right: Vector3 = up.cross(forward)
		if right.length() < 0.001:
			right = Vector3.RIGHT
		right = right.normalized()
		up = forward.cross(right).normalized()
		var target_basis: Basis = Basis(right, up, forward).orthonormalized() * _orientation_offset

		if _smoothed_basis == Basis.IDENTITY:
			_smoothed_basis = target_basis
		else:
			var w: float = clamp(smoothing, 0.0, 1.0)
			var q_cur: Quaternion = _smoothed_basis.get_rotation_quaternion()
			var q_tgt: Quaternion = target_basis.get_rotation_quaternion()
			var q_blend: Quaternion = q_cur.slerp(q_tgt, w)
			_smoothed_basis = Basis(q_blend).orthonormalized()

		# Place the car slightly above the path using ride_height (no sideways offset).
		var final_pos: Vector3 = pos + up * ride_height + _position_offset
		var final_transform: Transform3D = Transform3D(_smoothed_basis, final_pos)
		if not _has_initial_transform or smoothing <= 0.0:
			_car_node.global_transform = final_transform
			_has_initial_transform = true
		else:
			_car_node.global_transform = _car_node.global_transform.interpolate_with(final_transform, smoothing)
