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

func _ready() -> void:
	if camera:
		_camera_base_y = camera.position.y
	# Don't capture mouse yet - wait until player is activated
	set_physics_process(false)
	# Add to player group for detection by invisible walls and other systems
	add_to_group("player")

func activate() -> void:
	is_active = true
	set_physics_process(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		camera.current = true
	print("Player controller activated")

func deactivate() -> void:
	is_active = false
	set_physics_process(false)
	print("Player controller deactivated")

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Handle escape to release mouse
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
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

	# Clamp pitch
	camera.rotation.x = clamp(camera.rotation.x, -PI/2 * 0.9, PI/2 * 0.9)

	_twist_input = 0.0
	_pitch_input = 0.0

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_twist_input = -event.relative.x * mouse_sensitivity
		_pitch_input = -event.relative.y * mouse_sensitivity
