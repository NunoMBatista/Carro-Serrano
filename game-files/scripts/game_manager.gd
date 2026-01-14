extends Node3D

## Enable/disable dialogue debug overlay (top-right corner)
@export var debug_dialogue: bool = false

# This is the variable you want to change
@onready var empathy_score: int = 0

# References to hitchhikers and car
var hitchhikers_node: Node3D = null
var car_node: RigidBody3D = null
var current_hitchhiker: Node3D = null
var current_hitchhiker_id: int = 0  # Store ID for generic handlers

# Hitchhiker progression tracking
var next_hitchhiker_to_enable: int = 2  # Next hitchhiker in sequence
var enable_next_hitchhiker_on_next_lap: bool = false  # Flag to enable on next lap
var next_hitchhiker_placement_id: int = -1  # Placement ID of next closest hitchhiker
var in_dialogue: bool = false  # Track if currently in any dialogue
var hitchhiker_4_completed: bool = false  # Flag to trigger torre teleport after hitchhiker 4

# Store initial positions and rotations of hitchhikers by placement_id
# Format: { placement_id: { "position": Vector3, "rotation": Vector3 } }
var hitchhiker_placements: Dictionary = {}
			
# Game start state
var game_started: bool = false  # Flag to track if player has taken the wheel

# Payphone choice state
var payphone_used: bool = false
var payphone_choice_yes: bool = false

## Call this when the player takes the wheel to actually start the game
func start_game() -> void:
	if game_started:
		return  # Already started

	game_started = true
	print("Game started! Enabling first hitchhiker...")

	# Now enable the first hitchhiker
	enable_hitchhiker(1)

## Call this when starting a new game/playthrough to reset session state
func start_new_game() -> void:
	empathy_score = 0
	payphone_used = false
	payphone_choice_yes = false
	game_started = false

	# Reset glovebox state for new playthrough
	if has_node("/root/GloveboxState"):
		get_node("/root/GloveboxState").clear_all_states()

	# Add other new game initialization here
	print("New game started - all session states cleared")

func _ready():
	# Get references to Hitchhikers node and car
	var root = get_tree().get_current_scene()
	if root:
		hitchhikers_node = root.get_node_or_null("Hitchhikers")
		car_node = root.get_node_or_null("CarFollower/Carro")
	if not hitchhikers_node:
		print("ERROR: Hitchhikers node still not found!")
	if not car_node:
		print("ERROR: Car node still not found!")

	# Connect to car follower's lap signal
	var car_follower = get_node_or_null("../CarFollower")
	if car_follower and car_follower.has_signal("lap_started"):
		car_follower.lap_started.connect(_on_lap_started)
		print("Connected to car lap_started signal")

	# Connect to all hitchhiker signals and store initial positions
	for child in hitchhikers_node.get_children():
		if child.has_signal("reached_player"):
			child.reached_player.connect(_on_hitchhiker_reached_player)
			print("Connected to hitchhiker: ", child.name)
		else:
			print("WARNING: Child '", child.name, "' does not have reached_player signal")

		if child.has_signal("player_passed_by"):
			child.player_passed_by.connect(_on_player_passed_by_hitchhiker)
			print("Connected to player_passed_by for: ", child.name)
		
		# Store initial position and rotation by placement_id
		if "placement_id" in child:
			hitchhiker_placements[child.placement_id] = {
				"position": child.global_position,
				"rotation": child.rotation_degrees
			}
			print("Stored placement ", child.placement_id, " - Position: ", child.global_position, " Rotation: ", child.rotation_degrees)

	# Start with all hitchhikers disabled - wait for game to start
	disable_all_hitchhikers()

	print("GameManager initialized - connected to ", hitchhikers_node.get_child_count(), " hitchhikers")
	print("Waiting for player to take the wheel before enabling hitchhikers...")

func on_payphone_choice(chose_yes: bool) -> void:
	# Record the player's choice at the torre payphone
	payphone_used = true
	payphone_choice_yes = chose_yes

	var root = get_tree().get_current_scene()
	if not root:
		return

	# Hide the initial torre arrow once the payphone has been used
	var arrow = root.get_node_or_null("torre/arrow")
	if arrow:
		arrow.visible = false

	if chose_yes:
		# Called for help - show arrow to road interaction (arrow3)
		var arrow3 = root.get_node_or_null("torre/arrow3")
		if arrow3:
			arrow3.visible = true

		# Enable road interaction collider
		var road_interact = root.get_node_or_null("torre/RoadInteract")
		if road_interact and road_interact is StaticBody3D:
			road_interact.collision_layer = 2
	else:
		# Didn't call for help - show arrow to car (arrow2)
		var arrow2 = root.get_node_or_null("torre/arrow2")
		if arrow2:
			arrow2.visible = true

		# Enable interaction collider for the parked car in the torre
		var carro_interact = root.get_node_or_null("torre/carro_exterior/CarroInteract")
		if carro_interact and carro_interact is StaticBody3D:
			carro_interact.collision_layer = 2

const PROTOTYPE_DIALOGUE = preload("res://dialogue/prototype.dialogue")

const NOVINHA_DIALOGUE_PRE = preload("res://dialogue/vovo_pre.dialogue")
const NOVINHA_DIALOGUE = preload("res://dialogue/novinha.dialogue")

const VOVO_DIALOGUE_PRE = preload("res://dialogue/vovo_pre.dialogue")
const VOVO_DIALOGUE = preload("res://dialogue/vovo.dialogue")

const DRUNK_DIALOGUE_PRE = preload("res://dialogue/vovo_pre.dialogue")
const DRUNK_DIALOGUE = preload("res://dialogue/drunk_dialogue.dialogue")

const MIDDLE_DIALOGUE_PRE = preload("res://dialogue/middle_aged_dialogue_pre.dialogue")
const MIDDLE_DIALOGUE = preload("res://dialogue/middle_aged_dialogue.dialogue")

# Optional: A helper function if you want to print logic
func change_empathy(amount: int):
	empathy_score += amount
	print("Empathy is now: ", empathy_score)
	var logger = get_node_or_null("/root/PlaytestLogger")
	if logger:
		logger.current_empathy = empathy_score
		logger.log_state("update_empathy", "%+d" % amount)

func run_dialogue():
	# Don't change mouse mode - camera stays active during dialogue
	DialogueManager.show_example_dialogue_balloon(PROTOTYPE_DIALOGUE, "start")

## Find the closest hitchhiker to the car and enable the next one at placement_id + 2
func find_and_enable_hitchhiker():
	print("DEBUG SPAWN: find_and_enable_hitchhiker called, next_hitchhiker_to_enable = ", next_hitchhiker_to_enable)
	print("DEBUG SPAWN: Called from stack trace:")
	print(get_stack())
	
	if not hitchhikers_node or not car_node:
		print("WARNING: Cannot find closest hitchhiker - missing hitchhikers_node or car_node")
		return
	
	if next_hitchhiker_to_enable > 4:
		print("WARNING: All hitchhikers already spawned (next_hitchhiker_to_enable = ", next_hitchhiker_to_enable, ")")
		return
	
	var car_pos = car_node.global_position
	var closest_distance = INF
	var closest_placement_id = -1
	
	for child in hitchhikers_node.get_children():
		if "placement_id" in child:
			var hitchhiker_pos = child.global_position
			var distance = car_pos.distance_to(hitchhiker_pos)
			
			if distance < closest_distance:
				closest_distance = distance
				closest_placement_id = child.placement_id
	
	if closest_placement_id != -1:
		next_hitchhiker_placement_id = closest_placement_id
		print("Closest hitchhiker has placement_id: ", closest_placement_id, " at distance: ", closest_distance)
		
		# Calculate next placement: (placement_id + 2) wrapping around 1-4
		var next_placement = ((closest_placement_id + 2 - 1) % 4) + 1
		print("PLACE: current closest placement_id: ", closest_placement_id)
		print("PLACE: Next hitchhiker will spawn at placement_id: ", next_placement)
		
		# Enable the next hitchhiker in sequence at the calculated placement
		enable_hitchhiker_at_placement(next_placement)
		print("DEBUG SPAWN: Incrementing next_hitchhiker_to_enable from ", next_hitchhiker_to_enable, " to ", next_hitchhiker_to_enable + 1)
		next_hitchhiker_to_enable += 1
	else:
		print("WARNING: No hitchhiker with placement_id found")

## Enable a specific hitchhiker at a specific placement location
func enable_hitchhiker_at_placement(next_placement: int = -1) -> void:
	if not hitchhikers_node:
		print("WARNING: Hitchhikers node not found!")
		return
		
	# Change the hitchhiker_id of this NPC
	var npc_at_placement: Node3D = null
	for child in hitchhikers_node.get_children():
		if "placement_id" in child and child.placement_id == next_placement:
			npc_at_placement = child
			break

	if not npc_at_placement:
		print("WARNING: No hitchhiker found at placement_id ", next_placement)
		return

	# Set the hitchhiker_id
	npc_at_placement.hitchhiker_id = next_hitchhiker_to_enable
	enable_hitchhiker(next_hitchhiker_to_enable)

# Signal handler called when a hitchhiker reaches the player
func _on_hitchhiker_reached_player(npc: Node3D) -> void:
	# Check if hitchhiker is enabled (visible and active)
	if not npc.visible or (npc.has_method("is_enabled") and not npc.is_enabled()):
		print("Hitchhiker is disabled, ignoring: ", npc.name)
		return

	# Only interact if we're not already in a dialogue
	if current_hitchhiker != null:
		print("Already in dialogue, ignoring hitchhiker: ", npc.name)
		return

	print("Hitchhiker reached player: ", npc.name)
	current_hitchhiker = npc

	# Mark that player is interacting with this hitchhiker
	if "player_interacted" in npc:
		npc.player_interacted = true

	handle_hitchhiker_interaction(npc)

# Signal handler called when player passes by a hitchhiker without picking them up
func _on_player_passed_by_hitchhiker(npc: Node3D) -> void:
	var hitchhiker_id = 0
	if "hitchhiker_id" in npc:
		hitchhiker_id = npc.hitchhiker_id

	print("Player passed by hitchhiker ID ", hitchhiker_id, " without picking them up")

	# Disable hitchhiker since player passed by
	disable_hitchhiker(hitchhiker_id)

	# Check if this was hitchhiker 4
	if hitchhiker_id == 4:
		hitchhiker_4_completed = true
		print("Player passed by hitchhiker 4 - will teleport to torre on next loop")
	else:
		# Find and store the closest hitchhiker's placement_id
		find_and_enable_hitchhiker()
		print("Will enable closest hitchhiker on next lap")

	# You can add additional logic here, such as:
	# - Tracking skipped hitchhikers
	# - Achievements
	# - Story consequences
	# - etc.

# Signal handler called when car starts a new lap
func _on_lap_started(lap_number: int) -> void:
	print("Car started lap ", lap_number)

	# Check if we should enable the next hitchhiker
	# Only enable if not currently in dialogue (prevents enabling during multi-lap dialogues)
	if enable_next_hitchhiker_on_next_lap and not in_dialogue:
		enable_next_hitchhiker_on_next_lap = false

		# Enable the next hitchhiker in sequence
		if next_hitchhiker_to_enable <= 4:
			# enable_hitchhiker(next_hitchhiker_to_enable)
			print("Enabled hitchhiker ", next_hitchhiker_to_enable, " on lap ", lap_number)
			# next_hitchhiker_to_enable += 1
		else:
			print("All hitchhikers have been encountered")
	elif enable_next_hitchhiker_on_next_lap and in_dialogue:
		print("Waiting for dialogue to end before enabling next hitchhiker")

	# You can add logic here, such as:
	# - Reset hitchhiker availability
	# - Enable/disable certain hitchhikers based on lap number
	# - Track lap count for achievements
	# - Change game state based on lap progression
	# - etc.

func handle_hitchhiker_interaction(hitchhiker: Node3D):
	# Stop the car and disable input via the road_car_follower
	var road_follower = get_node_or_null("../CarFollower")
	print("DEBUG: road_follower = ", road_follower)
	if road_follower and road_follower.has_method("start_dialogue"):
		print("DEBUG: Calling start_dialogue()")
		road_follower.start_dialogue()
	else:
		print("WARNING: CarFollower not found or missing start_dialogue method")
		if road_follower:
			print("DEBUG: CarFollower exists but missing method")
		else:
			print("DEBUG: CarFollower is null")

	# Get the hitchhiker ID
	var hitchhiker_id = 0
	if "hitchhiker_id" in hitchhiker:
		hitchhiker_id = hitchhiker.hitchhiker_id

	# Start dialogue based on hitchhiker ID
	start_dialogue_for_hitchhiker(hitchhiker_id)

func start_dialogue_for_hitchhiker(hitchhiker_id: int):
	print("Starting dialogue for hitchhiker ID: ", hitchhiker_id)
	current_hitchhiker_id = hitchhiker_id  # Store for generic handlers
	in_dialogue = true  # Mark that dialogue is active

	match hitchhiker_id:
		1:  # MIDDLE - Two stage dialogue
			# Connect to generic pre-dialogue ended signal
			if not DialogueFlow.dialogue_ended.is_connected(_on_pre_dialogue_ended):
				DialogueFlow.dialogue_ended.connect(_on_pre_dialogue_ended)
				print("DEBUG: Connected _on_pre_dialogue_ended signal")
			# Start pre-dialogue (using Vovo's as placeholder until novinha_pre.dialogue is created)
			# TODO: Replace with NOVINHA_DIALOGUE_PRE when file is created
			DialogueFlow.run_dialogue(MIDDLE_DIALOGUE_PRE, "start")
		2:  # NOVINHA - Two stage dialoguerun_dialogue(DRUNK_DIALOGUE
			# Connect to generic pre-dialogue ended signal
			if not DialogueFlow.dialogue_ended.is_connected(_on_pre_dialogue_ended):
				DialogueFlow.dialogue_ended.connect(_on_pre_dialogue_ended)
				print("DEBUG: Connected _on_pre_dialogue_ended signal")
			# Start pre-dialogue
			DialogueFlow.run_dialogue(NOVINHA_DIALOGUE_PRE, "start")
		3:  # Drunk/Fent - Direct to main dialogue (no pre-dialogue/choice)
			print("Hitchhiker 3 - skipping pre-dialogue, going directly to main dialogue")
			print("DEBUG HH3: current_hitchhiker_id = ", current_hitchhiker_id)
			
			# Disable hitchhiker since they're auto-accepted into the car
			disable_hitchhiker(current_hitchhiker_id)
			print("DEBUG HH3: About to call show_hitchhiker_ball_mesh with ID: ", current_hitchhiker_id)
			
			# Show ball mesh AFTER disabling
			show_hitchhiker_ball_mesh(current_hitchhiker_id)
			print("DEBUG HH3: Finished calling show_hitchhiker_ball_mesh")
			
			# Connect to main dialogue ended signal
			if not DialogueFlow.dialogue_ended.is_connected(_on_main_dialogue_ended):
				DialogueFlow.dialogue_ended.connect(_on_main_dialogue_ended)
			
			# Start main dialogue directly
			DialogueFlow.run_dialogue(DRUNK_DIALOGUE, "start")
		4:  # VOVO - Two stage dialogue
			# Connect to generic pre-dialogue ended signal
			if not DialogueFlow.dialogue_ended.is_connected(_on_pre_dialogue_ended):
				DialogueFlow.dialogue_ended.connect(_on_pre_dialogue_ended)
				print("DEBUG: Connected _on_pre_dialogue_ended signal")
			# Start pre-dialogue (using Vovo's as placeholder until middle_pre.dialogue is created)
			# TODO: Replace with MIDDLE_DIALOGUE_PRE when file is created
			DialogueFlow.run_dialogue(VOVO_DIALOGUE_PRE, "start")
		_:
			# Default/fallback to prototype
			DialogueManager.show_example_dialogue_balloon(PROTOTYPE_DIALOGUE, "start")
			print("Unknown hitchhiker_id: ", hitchhiker_id, " - using prototype dialogue")

# Generic handler for any pre-dialogue ending
func _on_pre_dialogue_ended(_resource: Resource) -> void:
	print("DEBUG: _on_pre_dialogue_ended called!")
	# Disconnect the signal
	if DialogueFlow.dialogue_ended.is_connected(_on_pre_dialogue_ended):
		DialogueFlow.dialogue_ended.disconnect(_on_pre_dialogue_ended)
		print("DEBUG: Disconnected signal")

	# Resume car movement after pre-dialogue
	var road_follower = get_node_or_null("../CarFollower")
	if road_follower and road_follower.has_method("end_dialogue"):
		road_follower.end_dialogue()
		print("DEBUG: Car movement resumed")

	# Check player's choice
	var player_choice = DialogueFlow.last_choice
	print("DEBUG: Player choice: ", player_choice)

	if player_choice == "positive":
		# Player accepted - run main dialogue for this hitchhiker
		print("Player accepted hitchhiker ID ", current_hitchhiker_id, " - starting main dialogue")

		# Disable hitchhiker since they're now in the car
		disable_hitchhiker(current_hitchhiker_id)

		# Stop car again for main dialogue
		# Connect to main dialogue ended signal
		if not DialogueFlow.dialogue_ended.is_connected(_on_main_dialogue_ended):
			DialogueFlow.dialogue_ended.connect(_on_main_dialogue_ended)

		# Show ball mesh for this hitchhiker
		show_hitchhiker_ball_mesh(current_hitchhiker_id)

		# Run appropriate main dialogue based on ID
		match current_hitchhiker_id:
			1:
				DialogueFlow.run_dialogue(MIDDLE_DIALOGUE, "start")
			2:
				DialogueFlow.run_dialogue(NOVINHA_DIALOGUE, "start")
			4:
				DialogueFlow.run_dialogue(VOVO_DIALOGUE, "start")
	else:
		# Player rejected - treat as passed by
		print("Player rejected hitchhiker ID ", current_hitchhiker_id, " - continuing journey")

		# Disable hitchhiker since player rejected
		disable_hitchhiker(current_hitchhiker_id)

		# Clear dialogue flag
		in_dialogue = false

		# Check if this was hitchhiker 4
		if current_hitchhiker_id == 4:
			hitchhiker_4_completed = true
			print("Player rejected hitchhiker 4 - will teleport to torre on next loop")
		else:
			# Find and enable the closest hitchhiker
			find_and_enable_hitchhiker()

		# Reset interaction
		current_hitchhiker = null
		current_hitchhiker_id = 0

# Generic handler for any main dialogue ending
func _on_main_dialogue_ended(_resource: Resource) -> void:
	print("DEBUG HANDLER: _on_main_dialogue_ended called! current_hitchhiker_id=", current_hitchhiker_id)
	# Disconnect the signal
	if DialogueFlow.dialogue_ended.is_connected(_on_main_dialogue_ended):
		DialogueFlow.dialogue_ended.disconnect(_on_main_dialogue_ended)
		print("DEBUG HANDLER: Disconnected _on_main_dialogue_ended")

	# Clear dialogue flag
	in_dialogue = false

	# Add items to glovebox or spawn bottle based on which hitchhiker dialogue ended
	_handle_dialogue_rewards()

	# Check if this was hitchhiker 4
	if current_hitchhiker_id == 4:
		hitchhiker_4_completed = true
		print("Hitchhiker 4 dialogue ended - will teleport to torre on next loop")
	else:
		# Find and enable the closest hitchhiker
		find_and_enable_hitchhiker()

	# Resume car movement and reset
	reset_hitchhiker_interaction()

func _handle_dialogue_rewards() -> void:
	"""Handle spawning items based on which hitchhiker dialogue ended"""
	var glovebox_state = get_node_or_null("/root/GloveboxState")

	match current_hitchhiker_id:
		2:  # Novinha - spawn badesso in glovebox
			if glovebox_state:
				glovebox_state.add_item_to_spawn("badesso")
				print("Novinha dialogue ended - badesso will appear in glovebox")
		4:  # Vovo - spawn benga in glovebox
			if glovebox_state:
				glovebox_state.add_item_to_spawn("benga")
				print("Vovo dialogue ended - benga will appear in glovebox")
		3:  # Drunk/Fent - spawn bottle on car (like pressing B)
			_spawn_bottle_on_car()
			print("Drunk dialogue ended - bottle spawned on car")
		1:  # Middle-aged - spawn lebron (donut) in glovebox
			if glovebox_state:
				glovebox_state.add_item_to_spawn("lebron")
				print("Middle-aged dialogue ended - lebron (donut) will appear in glovebox")

func _spawn_bottle_on_car() -> void:
	"""Spawn a bottle on the car dashboard (like pressing B key)"""
	# Find the bottle manager in the scene
	var bottle_manager = get_tree().root.find_child("BottleManager", true, false)
	if bottle_manager and bottle_manager.has_method("spawn_bottle"):
		bottle_manager.spawn_bottle()
		print("Bottle spawned via BottleManager")
	else:
		print("WARNING: BottleManager not found or missing spawn_bottle method")

func reset_hitchhiker_interaction():
	# Hide ball mesh
	hide_hitchhiker_ball_mesh(current_hitchhiker_id)

	# Re-enable car control
	var road_follower = get_node_or_null("../CarFollower")
	if road_follower and road_follower.has_method("end_dialogue"):
		road_follower.end_dialogue()

	# Allow interaction with next hitchhiker
	current_hitchhiker = null
	current_hitchhiker_id = 0
	print("Hitchhiker interaction reset - ready for next hitchhiker")

func show_hitchhiker_ball_mesh(hitchhiker_id: int):
	print("DEBUG SHOW_MESH: Entered function with hitchhiker_id: ", hitchhiker_id)
	print("DEBUG SHOW_MESH: car_node = ", car_node)
	if not car_node:
		print("WARNING: Car node not found!")
		return

	var mesh_name = "Hitchhiker" + str(hitchhiker_id) + "_BallMesh"
	print("DEBUG SHOW_MESH: Looking for mesh_name: ", mesh_name)
	var mesh_node = car_node.get_node_or_null(mesh_name) as MeshInstance3D
	print("DEBUG SHOW_MESH: mesh_node = ", mesh_node)
	if mesh_node:
		# Set transparency to 1.0 (fully transparent) before making visible
		mesh_node.transparency = 1.0

		# Make the mesh visible
		mesh_node.visible = true

		# Fade transparency from 1.0 (transparent) to 0.0 (opaque)
		var tween = create_tween()
		tween.tween_property(mesh_node, "transparency", 0.0, 0.8)

		print("Showing ball mesh with fade-in: ", mesh_name)
	else:
		print("WARNING: Ball mesh not found: ", mesh_name)

func hide_hitchhiker_ball_mesh(hitchhiker_id: int):
	if not car_node:
		return

	var mesh_name = "Hitchhiker" + str(hitchhiker_id) + "_BallMesh"
	var mesh_node = car_node.get_node_or_null(mesh_name)
	if mesh_node:
		mesh_node.visible = false
		print("Hiding ball mesh: ", mesh_name)

# Enable a specific hitchhiker by ID (1-4)
func enable_hitchhiker(hitchhiker_id: int):
	if not hitchhikers_node:
		print("WARNING: Hitchhikers node not found!")
		return

	for child in hitchhikers_node.get_children():
		if "hitchhiker_id" in child and child.hitchhiker_id == hitchhiker_id:
			child.visible = true
			child.process_mode = Node.PROCESS_MODE_INHERIT
			# Enable collision detection
			for area_child in child.get_children():
				if area_child is Area3D:
					area_child.monitoring = true
					area_child.monitorable = true
			print("Enabled hitchhiker ID: ", hitchhiker_id, " (", child.name, ")")
			return

	print("WARNING: Hitchhiker with ID ", hitchhiker_id, " not found!")

# Disable a specific hitchhiker by ID (1-4)
func disable_hitchhiker(hitchhiker_id: int):
	if not hitchhikers_node:
		print("WARNING: Hitchhikers node not found!")
		return

	for child in hitchhikers_node.get_children():
		if "hitchhiker_id" in child and child.hitchhiker_id == hitchhiker_id:
			# Find the placement_id for this hitchhiker to restore position/rotation
			var placement = -1
			if "placement_id" in child:
				placement = child.placement_id
			
			# Restore position and rotation from stored placements
			if placement in hitchhiker_placements:
				child.global_position = hitchhiker_placements[placement]["position"]
				child.rotation_degrees = hitchhiker_placements[placement]["rotation"]
				print("Restored hitchhiker to placement ", placement, " coordinates")
			
			# Reset NPC state to initial values
			if child.has_method("reset_to_initial_state"):
				child.reset_to_initial_state()
			
			child.visible = false
			child.process_mode = Node.PROCESS_MODE_DISABLED
			if hitchhiker_id != 1:
				child.hitchhiker_id = 0  # Reset hitchhiker_id when disabled
			# Disable collision detection
			for area_child in child.get_children():
				if area_child is Area3D:
					area_child.monitoring = false
					area_child.monitorable = false
			print("Disabled hitchhiker ID: ", hitchhiker_id, " (", child.name, ")")
			return

	print("WARNING: Hitchhiker with ID ", hitchhiker_id, " not found!")

# Disable all hitchhikers
func disable_all_hitchhikers():
	for i in range(1, 5):
		disable_hitchhiker(i)
	print("All hitchhikers disabled")

# Enable only one hitchhiker, disable all others
func enable_only_hitchhiker(hitchhiker_id: int):
	disable_all_hitchhikers()
	enable_hitchhiker(hitchhiker_id)
	print("Only hitchhiker ", hitchhiker_id, " is now enabled")

## Check if hitchhiker 4 has completed (for CarFollower to check before looping)
func should_teleport_to_torre() -> bool:
	return hitchhiker_4_completed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_G:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
					pass
