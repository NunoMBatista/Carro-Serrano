@tool
extends Node
## 2D Glovebox view overlay with physics simulation
## In the editor, you can visually edit boundary_polygon vertices in the Inspector

signal closed

## Polygon boundary vertices (in pixels, relative to the background image)
## You can adjust these in the editor to match your glovebox shape
@export var boundary_polygon: PackedVector2Array = PackedVector2Array([
	Vector2(200, 300),    # Top-left
	Vector2(1500, 250),   # Top-left-middle
	Vector2(2500, 250),   # Top-right-middle
	Vector2(3800, 300),   # Top-right
	Vector2(3850, 1200),  # Right-middle
	Vector2(3800, 2200),  # Bottom-right
	Vector2(2500, 2250),  # Bottom-right-middle
	Vector2(1500, 2250),  # Bottom-left-middle
	Vector2(200, 2200),   # Bottom-left
	Vector2(150, 1200)    # Left-middle
]):
	set(value):
		boundary_polygon = value
		if Engine.is_editor_hint():
			_update_editor_gizmo()

## Boundary collision properties
@export var boundary_restitution: float = 0.6  # Bounciness of walls
@export var boundary_friction: float = 0.3

## Debug mode - shows boundary walls as semi-transparent overlay
@export var show_debug_boundaries: bool = false:
	set(value):
		show_debug_boundaries = value
		if Engine.is_editor_hint():
			_update_editor_gizmo()

## Thickness of the boundary walls (in pixels)
@export var boundary_wall_thickness: float = 50.0

## Persistence file path for saving item positions
var _physics_items: Array[GloveboxItem] = []
var _boundary_body: StaticBody2D = null
var _hovered_item: GloveboxItem = null
var _currently_dragging: GloveboxItem = null
var _recently_released_items: Dictionary = {}  # item -> frames_remaining

var _initial_hint_pos: Vector2 = Vector2.ZERO
var _initial_items_pos: Vector2 = Vector2.ZERO

# Editor-only variables
var _editor_gizmo_polygon: Polygon2D = null
var _editor_vertex_markers: Array[Control] = []

# Node references
var background: TextureRect = null
var hint_label: Label = null
var items_container: Control = null
var physics_world: Node2D = null

func _ready() -> void:
	# Get node references
	physics_world = get_node_or_null("PhysicsLayer/PhysicsWorld")
	background = get_node_or_null("BackgroundLayer/Background")
	hint_label = get_node_or_null("UILayer/ItemsContainer/HintLabel")
	items_container = get_node_or_null("UILayer/ItemsContainer")

	# In editor mode, show visual gizmo for polygon editing
	if Engine.is_editor_hint():
		_create_editor_gizmo()
		return

	# Runtime setup
	if hint_label:
		hint_label.text = "RMB to leave"
		hint_label.add_theme_font_size_override("font_size", 18)
		hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))

	# Create physics boundary from polygon
	_create_polygon_boundary()

	# Spawn items based on dialogue completion status
	_spawn_items_from_state()

	# Load saved positions from session state
	if has_node("/root/GloveboxState"):
		get_node("/root/GloveboxState").load_all_items(_physics_items)

	# Store original positions so we can maintain relative offsets when scaling
	if hint_label:
		_initial_hint_pos = hint_label.position
	if items_container:
		_initial_items_pos = items_container.position

	# Initial layout and connect to viewport resize
	_update_layout()
	var vp = get_viewport()
	if vp:
		vp.size_changed.connect(Callable(self, "_update_layout"))

func _create_polygon_boundary() -> void:
	"""Creates a closed polygon boundary from the defined vertices"""
	if not physics_world:
		push_warning("PhysicsWorld node not found!")
		return

	if boundary_polygon.size() < 3:
		push_error("Boundary polygon needs at least 3 vertices!")
		return

	# Configure gravity for the physics world
	# In 2D, gravity points downward (positive Y direction)
	# Default gravity is 980 (similar to Earth's 9.8 m/s²)
	# We can access the world's gravity through the physics server if needed
	# For now, objects will use default 2D gravity

	# Create the main boundary body
	_boundary_body = StaticBody2D.new()
	physics_world.add_child(_boundary_body)

	# Set physics material
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = boundary_restitution
	physics_material.friction = boundary_friction
	_boundary_body.physics_material_override = physics_material

	# Create edge segments between each pair of vertices
	for i in range(boundary_polygon.size()):
		var start_point = boundary_polygon[i]
		var end_point = boundary_polygon[(i + 1) % boundary_polygon.size()]
		_create_boundary_segment(start_point, end_point)

	# Debug visualization
	if show_debug_boundaries:
		_create_debug_visualization()

func _create_boundary_segment(start: Vector2, end: Vector2) -> void:
	"""Creates a single boundary wall segment between two points"""
	var segment_body = StaticBody2D.new()
	var midpoint = (start + end) / 2.0
	segment_body.position = midpoint

	# Calculate direction and length
	var direction = end - start
	var length = direction.length()
	var angle = direction.angle()

	# Create rectangular collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length, boundary_wall_thickness)
	collision.shape = shape
	collision.rotation = angle

	segment_body.add_child(collision)
	_boundary_body.add_child(segment_body)

	# Set physics material
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = boundary_restitution
	physics_material.friction = boundary_friction
	segment_body.physics_material_override = physics_material

	# Debug visualization for this segment
	if show_debug_boundaries:
		var debug_rect = ColorRect.new()
		debug_rect.size = Vector2(length, boundary_wall_thickness)
		debug_rect.position = Vector2(-length / 2.0, -boundary_wall_thickness / 2.0)
		debug_rect.color = Color(1, 0, 0, 0.3)
		debug_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		collision.add_child(debug_rect)

func _create_debug_visualization() -> void:
	"""Creates visual representation of the boundary polygon"""
	if not _boundary_body:
		return

	var debug_polygon = Polygon2D.new()
	debug_polygon.polygon = boundary_polygon
	debug_polygon.color = Color(1, 1, 0, 0.2)  # Semi-transparent yellow
	_boundary_body.add_child(debug_polygon)

	# Draw vertices as small circles
	for i in range(boundary_polygon.size()):
		var vertex_marker = ColorRect.new()
		vertex_marker.size = Vector2(10, 10)
		vertex_marker.position = boundary_polygon[i] - Vector2(5, 5)
		vertex_marker.color = Color(0, 1, 0, 0.8)  # Green
		vertex_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boundary_body.add_child(vertex_marker)

		# Add a label with vertex number
		var label = Label.new()
		label.text = str(i)
		label.position = boundary_polygon[i] + Vector2(10, -10)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_boundary_body.add_child(label)

func _create_placeholder_rectangle(pos: Vector2, size: Vector2, color: Color, item_id: String = "") -> void:
	"""Creates a draggable rectangle physics object"""
	var item = GloveboxItem.new()
	item.position = pos
	item.name = item_id if item_id != "" else "item_" + str(_physics_items.size())
	item.setup_as_rectangle(size, color)

	# Connect signals for crosshair interaction
	item.clicked.connect(_on_item_clicked)
	item.drag_started.connect(_on_item_drag_started)
	item.drag_ended.connect(_on_item_drag_ended)
	item.scale_changed.connect(_on_item_scale_changed.bind(item))

	physics_world.add_child(item)
	_physics_items.append(item)

	# Set physics material for bounciness
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.4
	physics_material.friction = 0.5
	item.physics_material_override = physics_material

func _create_placeholder_circle(pos: Vector2, radius: float, color: Color, item_id: String = "") -> void:
	"""Creates a draggable circle physics object"""
	var item = GloveboxItem.new()
	item.position = pos
	item.name = item_id if item_id != "" else "item_" + str(_physics_items.size())
	item.setup_as_circle(radius, color)

	# Connect signals for crosshair interaction
	item.clicked.connect(_on_item_clicked)
	item.drag_started.connect(_on_item_drag_started)
	item.drag_ended.connect(_on_item_drag_ended)
	item.scale_changed.connect(_on_item_scale_changed.bind(item))

	physics_world.add_child(item)
	_physics_items.append(item)

	# Set physics material for bounciness
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.5
	physics_material.friction = 0.4
	item.physics_material_override = physics_material

func _create_lebron_item(pos: Vector2) -> void:
	"""Creates the lebron sprite item from scene"""
	var lebron_scene = load("res://scenes/lebron.tscn")
	if lebron_scene:
		var item = lebron_scene.instantiate()
		item.name = "lebron"
		item.position = pos

		# Set physics material
		var physics_material = PhysicsMaterial.new()
		physics_material.bounce = 0.4
		physics_material.friction = 0.5
		item.physics_material_override = physics_material

		add_item(item)
		print("Lebron item created at position: ", pos)
	else:
		push_error("Failed to load lebron.tscn")

func _create_badesso_item(pos: Vector2) -> void:
	"""Creates the badesso sprite item from scene"""
	var badesso_scene = load("res://scenes/badesso.tscn")
	if badesso_scene:
		var item = badesso_scene.instantiate()
		item.name = "badesso"
		item.position = pos

		# Set physics material
		var physics_material = PhysicsMaterial.new()
		physics_material.bounce = 0.4
		physics_material.friction = 0.5
		item.physics_material_override = physics_material

		add_item(item)
		print("Badesso item created at position: ", pos)
	else:
		push_error("Failed to load badesso.tscn")

func _spawn_items_from_state() -> void:
	"""Spawn items in the glovebox based on GloveboxState tracking"""
	if not has_node("/root/GloveboxState"):
		return

	var glovebox_state = get_node("/root/GloveboxState")
	var items_to_spawn = glovebox_state.get_items_to_spawn()

	for item_name in items_to_spawn:
		# Always spawn items that are marked to spawn
		# Their saved positions will be loaded after spawning
		match item_name:
			"badesso":
				_create_badesso_item(Vector2(2400, 1200))
			"lebron":
				_create_lebron_item(Vector2(2000, 1200))
			"benga":
				_create_benga_item(Vector2(1800, 1200))
			_:
				print("Warning: Unknown item to spawn: ", item_name)

func _create_benga_item(pos: Vector2) -> void:
	"""Creates the benga sprite item from scene"""
	var benga_scene = load("res://scenes/benga.tscn")
	if benga_scene:
		var item = benga_scene.instantiate()
		item.name = "benga"
		item.position = pos

		# Set physics material
		var physics_material = PhysicsMaterial.new()
		physics_material.bounce = 0.4
		physics_material.friction = 0.5
		item.physics_material_override = physics_material

		add_item(item)
		print("Benga item created at position: ", pos)
	else:
		push_error("Failed to load benga.tscn")

func _on_item_clicked() -> void:
	_simulate_crosshair_click()

func _on_item_drag_started() -> void:
	pass  # Handled in _unhandled_input now

func _on_item_drag_ended() -> void:
	pass  # Handled in _unhandled_input now

func _on_item_scale_changed(item: GloveboxItem) -> void:
	# Re-clamp position after scale change to prevent clipping out in corners
	# Use call_deferred to ensure physics shape has updated after scale change
	if item and is_instance_valid(item):
		_reclamp_item_position.call_deferred(item)

func _reclamp_item_position(item: GloveboxItem) -> void:
	"""Deferred position clamping after scale changes"""
	if not item or not is_instance_valid(item):
		return

	# Wait one frame for collision shape to update
	await get_tree().process_frame

	if not item or not is_instance_valid(item):
		return

	item.global_position = _clamp_to_boundary(item.global_position, item)
	item.linear_velocity = Vector2.ZERO
	item.angular_velocity = 0.0

func _set_crosshair_hover(enabled: bool) -> void:
	var cross = _get_crosshair()
	if cross and cross.has_method("set_ui_hovering"):
		cross.set_ui_hovering(enabled)

func _set_crosshair_dragging(dragging: bool) -> void:
	var cross = _get_crosshair()
	if cross and cross.has_method("set_ui_dragging"):
		cross.set_ui_dragging(dragging)

func _simulate_crosshair_click() -> void:
	var cross = _get_crosshair()
	if cross and cross.has_method("simulate_click"):
		cross.simulate_click()

func _get_crosshair():
	var scene = get_tree().get_current_scene()
	if not scene:
		return null
	if scene.has_node("Player/Control/CrossHair"):
		return scene.get_node("Player/Control/CrossHair")
	# fallback: recursive search
	return _find_node(scene, "CrossHair")

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

func _update_layout() -> void:
	if not background or not background.texture:
		return

	var vsize: Vector2 = get_viewport().get_visible_rect().size
	var tex_size: Vector2 = background.texture.get_size()

	# Uniform scale to fit viewport
	var uniform_scale = max(vsize.x / tex_size.x, vsize.y / tex_size.y)

	# Apply to background
	background.scale = Vector2(uniform_scale, uniform_scale)
	background.position = (vsize - tex_size * uniform_scale) / 2.0

	# Scale and position items container and hint relative to background
	if items_container:
		items_container.scale = Vector2(uniform_scale, uniform_scale)
		items_container.position = background.position + _initial_items_pos * uniform_scale

	if hint_label:
		hint_label.scale = Vector2(uniform_scale, uniform_scale)
		hint_label.position = background.position + _initial_hint_pos * uniform_scale

	# Scale physics world
	if physics_world:
		physics_world.scale = Vector2(uniform_scale, uniform_scale)
		physics_world.position = background.position

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()

func _unhandled_input(event: InputEvent) -> void:
	"""Handle clicking and dragging of physics items using physics point queries"""
	if Engine.is_editor_hint():
		return

	if not physics_world:
		return

	# Handle mouse clicks for dragging
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Get mouse position in physics_world's local coordinate space
		# This accounts for the physics_world's position and scale automatically
		var mouse_pos = physics_world.get_local_mouse_position()

		if event.pressed:
			# Mouse pressed - check if we clicked on any item
			# We need to check each item's collision shape manually since physics queries
			# use global coordinates but we're working in local space
			var clicked_item: GloveboxItem = null
			var closest_distance = INF

			for item in _physics_items:
				if item and is_instance_valid(item):
					# Get the actual collision shape center position
					var collision_center = item.position
					for child in item.get_children():
						if child is CollisionShape2D:
							collision_center = item.position + child.position
							break

					# Get distance from mouse to collision shape center
					var distance = mouse_pos.distance_to(collision_center)

					# Check if mouse is within a reasonable range (approximate collision check)
					# Increased to 150 pixels for easier clicking on smaller items
					if distance < 150 and distance < closest_distance:
						clicked_item = item
						closest_distance = distance

			if clicked_item:
				# Convert to global position for start_drag
				var global_mouse_pos = physics_world.to_global(mouse_pos)

				# Calculate the collision shape offset
				var collision_offset = Vector2.ZERO
				for child in clicked_item.get_children():
					if child is CollisionShape2D:
						collision_offset = child.position
						break

				# Pass the collision offset to start_drag for proper dragging
				clicked_item.start_drag(global_mouse_pos, collision_offset)

				# Store reference to enable boundary checking during drag
				clicked_item.set_meta("_drag_boundary_polygon", boundary_polygon)
				_currently_dragging = clicked_item
				_set_crosshair_dragging(true)
				get_viewport().set_input_as_handled()
		else:
			# Mouse released - end any active drags
			for item in _physics_items:
				if item and is_instance_valid(item) and item.is_dragging:
					# Cap velocity to prevent items flying out when released quickly
					var max_velocity = 500.0  # pixels per second
					if item.linear_velocity.length() > max_velocity:
						item.linear_velocity = item.linear_velocity.normalized() * max_velocity

					# Ensure item is still within bounds before releasing
					item.global_position = _clamp_to_boundary(item.global_position, item)

					item.end_drag()
					_currently_dragging = null
					_set_crosshair_dragging(false)

					# Track for 30 frames to ensure clamping after scale change
					_recently_released_items[item] = 30

					get_viewport().set_input_as_handled()
					return

func close() -> void:
	# Reset cursor states before closing
	_set_crosshair_hover(false)
	_set_crosshair_dragging(false)

	# End any active drags
	if _currently_dragging and is_instance_valid(_currently_dragging):
		_currently_dragging.end_drag()
	_currently_dragging = null
	_hovered_item = null

	# Save item positions to session state
	if has_node("/root/GloveboxState"):
		get_node("/root/GloveboxState").save_all_items(_physics_items)
	closed.emit()
	queue_free()

## Public API for adding custom items
## Clamp a global position to stay within the boundary polygon
func _clamp_to_boundary(pos: Vector2, item: GloveboxItem = null) -> Vector2:
	"""Keeps a position within the glovebox boundary, accounting for collision shape size"""
	if boundary_polygon.size() < 3:
		return pos

	# Calculate safety margin based on item size
	var safety_margin = 100.0  # Default large margin
	if item and is_instance_valid(item):
		# Get the item's collision shape to determine actual size
		for child in item.get_children():
			if child is CollisionShape2D:
				var shape = child.shape
				if shape is RectangleShape2D:
					var size = shape.size * item.scale
					safety_margin = max(size.x, size.y) / 2.0 + 20.0
				elif shape is CircleShape2D:
					safety_margin = shape.radius * max(item.scale.x, item.scale.y) + 20.0
				elif shape is ConvexPolygonShape2D or shape is ConcavePolygonShape2D:
					# For complex shapes, use conservative estimate
					safety_margin = 80.0
				break

	# Transform position to physics_world local space
	var local_pos = physics_world.to_local(pos)

	# Create inset polygon for checking (smaller than boundary by safety margin)
	var inset_polygon = _create_inset_polygon(boundary_polygon, safety_margin)

	# Check if point is inside the inset polygon
	var is_inside = Geometry2D.is_point_in_polygon(local_pos, inset_polygon)

	if is_inside:
		return pos  # Already safely inside

	# Point is outside safe zone - find nearest point on inset boundary
	var closest_point = local_pos
	var min_distance = INF

	# Check each edge of the inset polygon
	for i in range(inset_polygon.size()):
		var p1 = inset_polygon[i]
		var p2 = inset_polygon[(i + 1) % inset_polygon.size()]

		# Find closest point on this edge
		var edge_closest = Geometry2D.get_closest_point_to_segment(local_pos, p1, p2)
		var distance = local_pos.distance_to(edge_closest)

		if distance < min_distance:
			min_distance = distance
			closest_point = edge_closest

	# Convert back to global position
	return physics_world.to_global(closest_point)

func _create_inset_polygon(polygon: PackedVector2Array, inset_amount: float) -> PackedVector2Array:
	"""Create an inset version of the polygon (smaller by inset_amount)"""
	if polygon.size() < 3:
		return polygon

	# Calculate polygon center
	var center = Vector2.ZERO
	for vertex in polygon:
		center += vertex
	center /= polygon.size()

	# Create inset polygon by moving each vertex toward center
	var inset_polygon = PackedVector2Array()
	for vertex in polygon:
		var direction = (center - vertex).normalized()
		var inset_vertex = vertex + direction * inset_amount
		inset_polygon.append(inset_vertex)

	return inset_polygon

func add_item(item: GloveboxItem) -> void:
	"""Add a custom physics item to the glovebox"""
	if not physics_world:
		push_warning("PhysicsWorld not found, cannot add item")
		return

	physics_world.add_child(item)
	_physics_items.append(item)

	# Connect signals
	item.clicked.connect(_on_item_clicked)
	item.drag_started.connect(_on_item_drag_started)
	item.drag_ended.connect(_on_item_drag_ended)
	item.scale_changed.connect(_on_item_scale_changed.bind(item))



# ============================================================================
# EDITOR MODE FUNCTIONS
# ============================================================================

func _create_editor_gizmo() -> void:
	"""Creates visual gizmo in the editor for polygon editing"""
	if not physics_world:
		return

	# Clean up old gizmo if it exists
	_cleanup_editor_gizmo()

	# Create a dedicated canvas layer for the gizmo to appear on top
	var gizmo_layer = CanvasLayer.new()
	gizmo_layer.name = "EditorGizmoLayer"
	gizmo_layer.layer = 100  # High layer to appear above everything
	add_child(gizmo_layer)

	# Create a container node to hold gizmo elements
	var gizmo_container = Node2D.new()
	gizmo_container.name = "GizmoContainer"
	gizmo_layer.add_child(gizmo_container)

	# Create polygon visualization
	_editor_gizmo_polygon = Polygon2D.new()
	_editor_gizmo_polygon.polygon = boundary_polygon
	_editor_gizmo_polygon.color = Color(0, 1, 1, 0.4)  # Cyan semi-transparent
	_editor_gizmo_polygon.z_index = 1000
	gizmo_container.add_child(_editor_gizmo_polygon)

	# Create vertex markers and labels
	for i in range(boundary_polygon.size()):
		var marker_container = Control.new()
		marker_container.position = boundary_polygon[i]
		marker_container.z_index = 1002

		var marker = ColorRect.new()
		marker.size = Vector2(20, 20)
		marker.position = Vector2(-10, -10)
		marker.color = Color(1, 1, 0, 1.0)  # Bright yellow
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker_container.add_child(marker)

		var label = Label.new()
		label.text = str(i)
		label.position = Vector2(15, -30)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 4)
		marker_container.add_child(label)

		gizmo_container.add_child(marker_container)
		_editor_vertex_markers.append(marker_container)

	# Show polygon outline
	var outline = Line2D.new()
	outline.width = 4
	outline.default_color = Color(1, 1, 0, 1.0)  # Bright yellow outline
	outline.z_index = 1001
	for point in boundary_polygon:
		outline.add_point(point)
	# Close the loop
	outline.add_point(boundary_polygon[0])
	gizmo_container.add_child(outline)
	_editor_vertex_markers.append(outline)  # Store for cleanup

func _cleanup_editor_gizmo() -> void:
	"""Removes editor gizmo elements"""
	# Remove the entire gizmo layer
	var gizmo_layer = get_node_or_null("EditorGizmoLayer")
	if gizmo_layer:
		gizmo_layer.queue_free()

	_editor_gizmo_polygon = null
	_editor_vertex_markers.clear()

func _update_editor_gizmo() -> void:
	"""Updates the editor gizmo when polygon changes"""
	if not Engine.is_editor_hint():
		return

	if physics_world and is_inside_tree():
		call_deferred("_create_editor_gizmo")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		# Update gizmo if polygon changed
		if _editor_gizmo_polygon and _editor_gizmo_polygon.polygon != boundary_polygon:
			_editor_gizmo_polygon.polygon = boundary_polygon

			# Update vertex marker positions
			for i in range(min(_editor_vertex_markers.size(), boundary_polygon.size())):
				if i < boundary_polygon.size() and _editor_vertex_markers[i]:
					_editor_vertex_markers[i].position = boundary_polygon[i]
	else:
		# Runtime: Check for hover and update dragged items
		_update_hover_state()

		# Constrain ALL items to boundaries every frame to prevent high-speed escapes
		for item in _physics_items:
			if item and is_instance_valid(item):
				if item.is_dragging:
					# Update item position to follow mouse
					var mouse_pos = get_viewport().get_mouse_position()
					var desired_pos = mouse_pos + item.drag_offset

					# Clamp to boundary before applying, passing item for size calculation
					var clamped_pos = _clamp_to_boundary(desired_pos, item)

					# If clamped position differs, zero out velocity to prevent escape
					if clamped_pos != desired_pos:
						item.linear_velocity = Vector2.ZERO
						item.angular_velocity = 0.0

					item.global_position = clamped_pos
				else:
					# Check all non-dragging items too (prevents escaping from collisions)
					var clamped_pos = _clamp_to_boundary(item.global_position, item)
					if clamped_pos != item.global_position:
						item.global_position = clamped_pos
						# Zero velocity when hitting boundary to prevent escape
						item.linear_velocity = item.linear_velocity * 0.5  # Dampen instead of zero
						item.angular_velocity = item.angular_velocity * 0.5

		# Clamp recently released items for a few frames after release
		# This ensures they stay inside even after scaling back to normal size
		# Increase tracking to 30 frames for safety
		var items_to_remove = []
		for item in _recently_released_items:
			if not item or not is_instance_valid(item):
				items_to_remove.append(item)
				continue

			# Clamp position with item size consideration
			var clamped = _clamp_to_boundary(item.global_position, item)
			if clamped != item.global_position:
				item.global_position = clamped
				item.linear_velocity = Vector2.ZERO
				item.angular_velocity = 0.0

			# Decrement frame counter
			_recently_released_items[item] -= 1
			if _recently_released_items[item] <= 0:
				items_to_remove.append(item)

		# Clean up finished items
		for item in items_to_remove:
			_recently_released_items.erase(item)

func _update_hover_state() -> void:
	"""Check if mouse is hovering over any item and update cursor"""
	if not physics_world:
		return

	# Don't check hover while dragging
	if _currently_dragging:
		return

	var mouse_pos = physics_world.get_local_mouse_position()
	var found_hover: GloveboxItem = null
	var closest_distance = INF

	for item in _physics_items:
		if item and is_instance_valid(item):
			# Use collision shape center for hover detection too
			var collision_center = item.position
			for child in item.get_children():
				if child is CollisionShape2D:
					collision_center = item.position + child.position
					break

			var distance = mouse_pos.distance_to(collision_center)
			if distance < 150 and distance < closest_distance:
				found_hover = item
				closest_distance = distance

	# Update hover state if changed
	if found_hover != _hovered_item:
		_hovered_item = found_hover
		_set_crosshair_hover(_hovered_item != null)
