extends Node3D
## Invisible wall that shows dialogue and pushes player back when touched

@export var dialogue_text := "get yo ass outa my dick"
@export var pushback_force := 3.0
@export var dialogue_duration := 2.0
@export var cooldown_time := 1.0  # Time before can trigger again

var _player_in_area := false
var _cooldown_active := false
var _dialogue_label: Label = null
var _visual_indicator: MeshInstance3D = null
var _area: Area3D = null
var _player_controller: CharacterBody3D = null
var _dialogue_active := false
var _use_dialogue_balloon := false
var _wall_index := -1
var _balloon_instance: CanvasLayer = null

func _ready() -> void:
	set_physics_process(true)
	# Set up visual indicator for editor
	_setup_visual_indicator()

	# Get the Area3D child
	_area = get_node_or_null("Area3D")
	if _area:
		# Set up collision layers - detect everything
		_area.collision_layer = 0
		_area.collision_mask = 0xFFFFFFFF  # Detect all layers including player

		# Connect area signals
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)

	# Determine if this wall should show dialogue (only InvisibleWall1-12)
	_wall_index = _get_wall_index()
	_use_dialogue_balloon = _wall_index >= 1 and _wall_index <= 12

	# Create dialogue label (hidden by default) for legacy use, but
	# actual on-screen text is only shown via dialogue balloons for
	# numbered walls 1-12.
	_create_dialogue_ui()

	# Find player controller in scene
	call_deferred("_find_player_controller")

func _get_wall_index() -> int:
	var name_str := str(name)
	var digits := ""
	for i in range(name_str.length() - 1, -1, -1):
		var ch := name_str[i]
		if ch >= '0' and ch <= '9':
			digits = ch + digits
		else:
			break
	return int(digits) if digits != "" else -1

func _find_player_controller() -> void:
	"""Find the PlayerController in the scene"""
	var scene = get_tree().current_scene
	if scene:
		_player_controller = _find_node_recursive(scene, "PlayerController")
		if _player_controller:
			print("DEBUG: Found PlayerController: ", _player_controller.name)

func _find_node_recursive(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var result = _find_node_recursive(child, node_name)
		if result:
			return result
	return null

func _physics_process(_delta: float) -> void:
	"""Continuously check if player is near the wall"""
	if not _player_controller or not is_instance_valid(_player_controller):
		return

	# Check distance between player and wall
	var distance = global_position.distance_to(_player_controller.global_position)

	# If player is close to wall (within collision range)
	if distance < 6.0:  # Adjust this based on your wall size
		if not _player_in_area:
			print("DEBUG: Player detected near wall via physics_process")
			_player_in_area = true
			_show_dialogue_continuous()
			if not _cooldown_active:
				_trigger_wall_effect(_player_controller)
	else:
		if _player_in_area:
			print("DEBUG: Player left wall area via physics_process")
			_player_in_area = false
			_hide_dialogue()

func _create_dialogue_ui() -> void:
	"""Create on-screen dialogue label"""
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	_dialogue_label = Label.new()
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.anchor_left = 0.5
	_dialogue_label.anchor_top = 0.3
	_dialogue_label.anchor_right = 0.5
	_dialogue_label.anchor_bottom = 0.3
	_dialogue_label.offset_left = -400
	_dialogue_label.offset_right = 400
	_dialogue_label.offset_top = -60
	_dialogue_label.offset_bottom = 60
	_dialogue_label.visible = false

	# Load custom font
	var font = load("res://fonts/SpecialElite-Regular.ttf")
	if font:
		_dialogue_label.add_theme_font_override("font", font)

	# Style the label
	_dialogue_label.add_theme_font_size_override("font_size", 48)
	_dialogue_label.add_theme_color_override("font_color", Color.RED)
	_dialogue_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_dialogue_label.add_theme_constant_override("outline_size", 8)

	canvas.add_child(_dialogue_label)

func _setup_visual_indicator() -> void:
	"""Create semi-transparent visual mesh for editor visibility"""
	_visual_indicator = get_node_or_null("VisualIndicator")

	if not _visual_indicator:
		return

	# Only show in editor, hide in game
	_visual_indicator.visible = Engine.is_editor_hint()

	# Create semi-transparent material for editor
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1, 0, 0, 0.3)  # Red with 30% opacity
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_visual_indicator.material_override = material

func _on_body_entered(body: Node3D) -> void:
	print("DEBUG: Body entered wall - ", body.name, " Type: ", body.get_class(), " Groups: ", body.get_groups())

	# Check if it's the player controller - check type and groups
	var is_player = false
	if body.name == "PlayerController":
		is_player = true
	elif body.is_in_group("player"):
		is_player = true
	elif body is CharacterBody3D and body.has_method("activate"):
		is_player = true

	if is_player:
		print("DEBUG: PLAYER DETECTED! Showing dialogue")
		_player_in_area = true
		if not _cooldown_active:
			_trigger_wall_effect(body)
		# Show dialogue immediately when entering
		_show_dialogue_continuous()
	else:
		print("DEBUG: Non-player body entered: ", body.name)

func _on_body_exited(body: Node3D) -> void:
	print("DEBUG: Body exited wall - ", body.name)

	# Check if it's the player controller - same checks as body_entered
	var is_player = false
	if body.name == "PlayerController":
		is_player = true
	elif body.is_in_group("player"):
		is_player = true
	elif body is CharacterBody3D and body.has_method("activate"):
		is_player = true

	if is_player:
		print("DEBUG: Player exited wall area, hiding dialogue")
		_player_in_area = false
		# Hide dialogue when leaving wall
		_hide_dialogue()

func _trigger_wall_effect(player: Node3D) -> void:
	"""Push player back (only happens once per cooldown)"""
	if _cooldown_active:
		return

	_cooldown_active = true

	# Push player back
	_push_player_back(player)

	# Start cooldown
	await get_tree().create_timer(cooldown_time).timeout
	_cooldown_active = false

func _show_dialogue_continuous() -> void:
	"""Display the dialogue text while player is in area.

	For InvisibleWall1-12 this uses the DialogueManager balloon so it
	matches the payphone-style dialogue UI. Other walls keep their
	pushback but show no on-screen text.
	"""
	if _use_dialogue_balloon:
		_show_dialogue_balloon()
		return

	# For walls outside 1-12, we don't show any on-screen text.
	return

func _show_dialogue_balloon() -> void:
	"""Show a DialogueManager balloon with this wall's dialogue_text."""
	if _dialogue_active:
		return

	_dialogue_active = true

	var dm := Engine.get_singleton("DialogueManager")
	if dm == null:
		print("DEBUG: DialogueManager singleton not found; cannot show wall dialogue")
		return

	var text_block := "~ start\n\n**%s**\n\n=> END\n" % dialogue_text
	var resource: Resource = dm.create_resource_from_text(text_block)
	_balloon_instance = dm.show_example_dialogue_balloon(resource, "start")
	if _balloon_instance:
		_balloon_instance.tree_exited.connect(_on_balloon_closed)

func _on_balloon_closed() -> void:
	_dialogue_active = false
	_balloon_instance = null

func _hide_dialogue() -> void:
	"""Hide the dialogue text"""
	if not _dialogue_label:
		return

	print("DEBUG: Hiding dialogue")
	_dialogue_label.visible = false

func _push_player_back(player: Node3D) -> void:
	"""Push the player away from the wall"""
	if not player is CharacterBody3D:
		return

	# Calculate direction away from wall center
	var wall_center = global_position
	var player_pos = player.global_position
	var push_direction = (player_pos - wall_center).normalized()

	# Keep horizontal push only (don't push up/down)
	push_direction.y = 0
	push_direction = push_direction.normalized()

	# Apply pushback to player velocity
	if player.has_method("get") and player.get("velocity") != null:
		var push_velocity = push_direction * pushback_force
		player.velocity += push_velocity
