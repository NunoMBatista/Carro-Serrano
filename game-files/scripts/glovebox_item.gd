extends RigidBody2D
class_name GloveboxItem
## Draggable physics item for the glovebox view

signal clicked
signal drag_started
signal drag_ended
signal scale_changed

## Visual representation (ColorRect, Sprite2D, etc.)
var visual_node: Node = null

## Drag state
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

## Car tremble effect
@export var tremble_intensity: float = 2.0
@export var tremble_frequency: float = 5.0

## Maximum velocity to prevent excessive bouncing
@export var max_velocity: float = 800.0
@export var max_angular_velocity: float = 10.0

var tremble_time: float = 0.0
var is_mouse_over: bool = false
var mouse_held: bool = false

func _ready() -> void:
	# Enable physics with gravity
	gravity_scale = 1.0  # Enable gravity so objects fall
	linear_damp = 2.0  # Some damping for realistic movement
	angular_damp = 3.0  # Damping for rotation

	# Enable contact monitoring for collisions
	contact_monitor = true
	max_contacts_reported = 4

	# Set collision layers for proper interaction
	collision_layer = 1
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if not is_dragging:
		# Apply constant car tremble
		tremble_time += delta
		var tremble_force = Vector2(
			sin(tremble_time * tremble_frequency) * tremble_intensity,
			cos(tremble_time * tremble_frequency * 1.3) * tremble_intensity
		)
		apply_central_force(tremble_force)

		# Add occasional random impulses to simulate bumps
		if randf() < 0.01:  # 1% chance each frame
			var bump = Vector2(randf_range(-20, 20), randf_range(-20, 20))
			apply_central_impulse(bump)

	# Clamp velocity to prevent excessive bouncing
	if linear_velocity.length() > max_velocity:
		linear_velocity = linear_velocity.normalized() * max_velocity

	if abs(angular_velocity) > max_angular_velocity:
		angular_velocity = clamp(angular_velocity, -max_angular_velocity, max_angular_velocity)

func start_drag(mouse_pos: Vector2, collision_offset: Vector2 = Vector2.ZERO) -> void:
	is_dragging = true
	# Account for collision shape offset when calculating drag offset
	drag_offset = (global_position + collision_offset) - mouse_pos

	# Stop current movement
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	# Freeze physics while dragging
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC

	# Disable gravity while dragging
	gravity_scale = 0.0

	# Visual feedback - make it brighter and slightly bigger
	if visual_node:
		visual_node.modulate = Color(1.3, 1.3, 1.3)
	scale = Vector2(1.05, 1.05)

	mouse_held = true

	drag_started.emit()
	clicked.emit()

func end_drag() -> void:
	if is_dragging:
		is_dragging = false
		freeze = false

		# Restore gravity and damping
		gravity_scale = 1.0
		linear_damp = 2.0
		angular_damp = 3.0

		# Restore visual state
		if visual_node:
			visual_node.modulate = Color(1.0, 1.0, 1.0)
		scale = Vector2(1.0, 1.0)

		mouse_held = false

		drag_ended.emit()

		# Emit scale changed so glovebox can re-clamp position after size increase
		scale_changed.emit()

func _process(_delta: float) -> void:
	# Position update now handled in glovebox_view._process() for proper boundary clamping
	pass

## Get item state for persistence
func get_save_data() -> Dictionary:
	return {
		"position": global_position,
		"rotation": rotation,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity
	}

## Restore item state from saved data
func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation"):
		rotation = data["rotation"]
	if data.has("linear_velocity"):
		linear_velocity = data["linear_velocity"]
	if data.has("angular_velocity"):
		angular_velocity = data["angular_velocity"]

## Setup function to create a simple colored rectangle
func setup_as_rectangle(size: Vector2, color: Color) -> void:
	# Create visual
	var rect = ColorRect.new()
	rect.size = size
	rect.color = color
	rect.position = -size / 2.0  # Center the visual
	add_child(rect)
	visual_node = rect

	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)

	# Set mass based on size (bigger = heavier)
	mass = (size.x * size.y) / 10000.0

## Setup function to create a simple colored circle
func setup_as_circle(radius: float, color: Color) -> void:
	# Create visual
	var circle_sprite = Sprite2D.new()
	var circle_texture = _create_circle_texture(radius, color)
	circle_sprite.texture = circle_texture
	add_child(circle_sprite)
	visual_node = circle_sprite

	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)

	# Set mass based on size
	mass = (radius * radius) / 1000.0

## Helper to create a circle texture
func _create_circle_texture(radius: float, color: Color) -> ImageTexture:
	var size = int(radius * 2)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)

	for x in size:
		for y in size:
			var dx = x - radius
			var dy = y - radius
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= radius:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(img)
