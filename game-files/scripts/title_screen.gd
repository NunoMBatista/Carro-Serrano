extends CanvasLayer

@onready var blur_overlay: ColorRect = $Control/BlurOverlay
@onready var take_wheel_button: Button = $Control/CenterContainer/VBoxContainer/ButtonContainer/TakeTheWheelButton
@onready var background_blur: ColorRect = $Control/BackgroundBlur
@onready var center_container: CenterContainer = $Control/CenterContainer

var is_transitioning: bool = false
var game_started: bool = false

const UNBLUR_DURATION = 1.5

func _ready() -> void:
	print("Title screen _ready() called")

	# Show mouse cursor as pointing hand
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

	# Connect button signal
	if take_wheel_button:
		take_wheel_button.pressed.connect(_on_take_wheel_pressed)
		take_wheel_button.grab_focus()

	# Setup blur shader
	_setup_blur_shader()

	# Disable player input but keep game running for visual background
	_disable_player_controls()


func _setup_blur_shader() -> void:
	# Create shader material for blur effect
	var shader = load("res://shaders/blur_shader.gdshader")
	if shader:
		var material = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("blur_amount", 8.0)
		blur_overlay.material = material
		print("Blur shader applied")
	else:
		print("WARNING: Could not load blur shader, using simple overlay")


func _disable_player_controls() -> void:
	# Disable player controller input processing
	var root = get_tree().get_current_scene()
	if not root:
		return

	var player_controller = _find_node(root, "PlayerController")
	if player_controller:
		player_controller.set_process_input(false)
		print("Player controls disabled for title screen")

	var player = _find_node(root, "Player")
	if player:
		player.set_process_input(false)

	# Hide crosshair
	_hide_crosshair()


func _enable_player_controls() -> void:
	# Re-enable player controller input processing
	var root = get_tree().get_current_scene()
	if not root:
		return

	var player_controller = _find_node(root, "PlayerController")
	if player_controller:
		player_controller.set_process_input(true)
		print("Player controls enabled")

	var player = _find_node(root, "Player")
	if player:
		player.set_process_input(true)

	# Show crosshair
	_show_crosshair()


func _on_take_wheel_pressed() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	game_started = true
	print("Take the wheel pressed - starting game...")

	# Disable the button
	take_wheel_button.disabled = true

	# Start unblur animation
	_start_game_transition()


func _start_game_transition() -> void:
	# Create tween for smooth unblur
	var tween = create_tween()
	tween.set_parallel(true)

	# Fade out blur overlay
	tween.tween_property(blur_overlay, "modulate:a", 0.0, UNBLUR_DURATION)

	# Fade out background blur
	tween.tween_property(background_blur, "modulate:a", 0.0, UNBLUR_DURATION)

	# Reduce blur amount in shader
	if blur_overlay.material and blur_overlay.material is ShaderMaterial:
		tween.tween_property(blur_overlay.material, "shader_parameter/blur_amount", 0.0, UNBLUR_DURATION)

	# Fade out all title UI elements
	tween.tween_property(center_container, "modulate:a", 0.0, UNBLUR_DURATION * 0.6)

	# After animation completes, start the game
	tween.set_parallel(false)
	tween.tween_callback(_complete_transition)


func _complete_transition() -> void:
	print("Transition complete - starting game")

	# Enable player controls
	_enable_player_controls()

	# Capture mouse for gameplay (crosshair mode)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Reset cursor shape to default
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	# Tell GameManager to start the game (enable hitchhikers, etc.)
	if GameManager and GameManager.has_method("start_game"):
		GameManager.start_game()
		print("GameManager.start_game() called")
	else:
		print("WARNING: GameManager not found or doesn't have start_game() method")

	# Remove the title screen
	queue_free()


func _input(event: InputEvent) -> void:
	# Allow pressing Enter or Space to start the game
	if not is_transitioning and not game_started:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("Brakes"):
			_on_take_wheel_pressed()


func _hide_crosshair() -> void:
	# Find and hide the player crosshair
	var root = get_tree().get_current_scene()
	if not root:
		return

	var player_controller = _find_node(root, "PlayerController")
	if player_controller and player_controller.has_node("Control/CrossHair"):
		var crosshair = player_controller.get_node("Control/CrossHair")
		crosshair.visible = false

	var player = _find_node(root, "Player")
	if player and player.has_node("Control/CrossHair"):
		var crosshair = player.get_node("Control/CrossHair")
		crosshair.visible = false


func _show_crosshair() -> void:
	# Find and show the player crosshair
	var root = get_tree().get_current_scene()
	if not root:
		return

	var player_controller = _find_node(root, "PlayerController")
	if player_controller and player_controller.has_node("Control/CrossHair"):
		var crosshair = player_controller.get_node("Control/CrossHair")
		crosshair.visible = true

	var player = _find_node(root, "Player")
	if player and player.has_node("Control/CrossHair"):
		var crosshair = player.get_node("Control/CrossHair")
		crosshair.visible = true


func _find_node(root: Node, node_name: String) -> Node:
	if not root:
		return null
	if str(root.name) == node_name:
		return root
	for child in root.get_children():
		if child and child is Node:
			var res = _find_node(child, node_name)
			if res:
				return res
	return null
