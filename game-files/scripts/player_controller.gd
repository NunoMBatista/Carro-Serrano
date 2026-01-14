extends CharacterBody3D

# Movement settings
@export var walk_speed := 5.0
@export var sprint_speed := 8.0
@export var jump_velocity := 4.5
@export var acceleration := 10.0
@export var friction := 15.0
@export var air_acceleration := 5.0

# Camera
@export var mouse_sensitivity := 0.002
@export var camera_smoothing := 10.0

# Head bob settings
@export var bob_frequency := 2.0
@export var bob_amplitude := 0.08
@export var bob_lerp_speed := 10.0

var _bob_time := 0.0
var _camera_base_y := 0.0
var _twist_input := 0.0
var _pitch_input := 0.0

# State
var is_active := false
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var head_position = $CameraPivot
@onready var crosshair = $Control/CrossHair

func _ready() -> void:
	if camera:
		_camera_base_y = camera.position.y
	# Don't capture mouse yet - wait until player is activated
	set_physics_process(false)
	# Add to player group for detection by invisible walls and other systems
	add_to_group("player")
	# Hide and disable the free-roam crosshair until walking mode is active
	if crosshair:
		crosshair.visible = false
		crosshair.set_process(false)
		crosshair.set_process_input(false)
		crosshair.set_process_unhandled_input(false)

func activate() -> void:
	is_active = true
	set_physics_process(true)
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	if camera:
		camera.current = true
	if crosshair:
		crosshair.visible = true
		crosshair.set_process(true)
		crosshair.set_process_input(true)
		crosshair.set_process_unhandled_input(true)
	print("Player controller activated")

func deactivate() -> void:
	is_active = false
	set_physics_process(false)
	if camera:
		camera.current = false
	if crosshair:
		crosshair.visible = false
		crosshair.set_process(false)
		crosshair.set_process_input(false)
		crosshair.set_process_unhandled_input(false)
	print("Player controller deactivated")

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Handle escape to release mouse (but not during dialogue)
	if Input.is_action_just_pressed("ui_cancel"):
		var dialogue_flow = get_node_or_null("/root/DialogueFlow")
		if dialogue_flow and dialogue_flow.is_dialogue_active:
			# Don't toggle mouse mode during dialogue
			print("[PLAYER] ESC pressed during dialogue - ignoring. is_dialogue_active=", dialogue_flow.is_dialogue_active)
			pass
		elif DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_CAPTURED:
			print("[PLAYER] ESC pressed - changing from CAPTURED to VISIBLE")
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
			print("[PLAYER] Mouse mode after change: ", DisplayServer.mouse_get_mode())
		else:
			print("[PLAYER] ESC pressed - changing from ", DisplayServer.mouse_get_mode(), " to CAPTURED")
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
			print("[PLAYER] Mouse mode after change: ", DisplayServer.mouse_get_mode())

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump (use Space key directly, not ui_accept which is used for dialogues)
	if Input.is_action_just_pressed("Brakes") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Calculate movement direction relative to camera
	var direction := Vector3.ZERO
	if input_dir != Vector2.ZERO:
		var cam_basis = camera_pivot.global_transform.basis
		direction = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		direction.y = 0  # Keep movement horizontal
		direction = direction.normalized()

	# Determine current speed
	var current_speed = sprint_speed if Input.is_action_pressed("ui_shift") else walk_speed

	# Apply acceleration/friction
	var target_velocity: Vector3 = direction * current_speed
	var accel := acceleration if is_on_floor() else air_acceleration

	if direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, target_velocity.x, accel * delta)
		velocity.z = lerp(velocity.z, target_velocity.z, accel * delta)
	else:
		# Apply friction when no input
		if is_on_floor():
			velocity.x = lerp(velocity.x, 0.0, friction * delta)
			velocity.z = lerp(velocity.z, 0.0, friction * delta)

	# Head bob
	if is_on_floor() and direction != Vector3.ZERO:
		var horizontal_velocity = Vector2(velocity.x, velocity.z).length()
		_bob_time += delta * bob_frequency * (horizontal_velocity / walk_speed)
		var bob_offset = sin(_bob_time) * bob_amplitude
		camera.position.y = lerp(camera.position.y, _camera_base_y + bob_offset, bob_lerp_speed * delta)
	else:
		_bob_time = 0.0
		camera.position.y = lerp(camera.position.y, _camera_base_y, bob_lerp_speed * delta)

	# Camera rotation
	camera_pivot.rotate_y(_twist_input)
	camera.rotate_x(_pitch_input)

	# Clamp pitch to realistic human neck limits (~65 degrees up/down)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2 * 0.72, PI/2 * 0.72)

	_twist_input = 0.0
	_pitch_input = 0.0

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event is InputEventMouseMotion and DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_CAPTURED:
		_twist_input = -event.relative.x * mouse_sensitivity
		_pitch_input = -event.relative.y * mouse_sensitivity
