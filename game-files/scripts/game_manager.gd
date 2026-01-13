extends Node3D

## Enable/disable dialogue debug overlay (top-right corner)
@export var debug_dialogue: bool = true

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
var in_dialogue: bool = false  # Track if currently in any dialogue
var hitchhiker_4_completed: bool = false  # Flag to trigger torre teleport after hitchhiker 4

## Call this when starting a new game/playthrough to reset session state
func start_new_game() -> void:
	empathy_score = 0

	# Reset glovebox state for new playthrough
	if has_node("/root/GloveboxState"):
		get_node("/root/GloveboxState").clear_all_states()

	# Add other new game initialization here
	print("New game started - all session states cleared")

func _ready():
	# Get references to Hitchhikers node and car
	hitchhikers_node = get_node_or_null("../Hitchhikers")
	if not hitchhikers_node:
		print("WARNING: Hitchhikers node not found!")
		return
	
	car_node = get_node_or_null("../Carro")
	if not car_node:
		print("WARNING: Car node not found!")
	
	# Connect to car follower's lap signal
	var car_follower = get_node_or_null("../CarFollower")
	if car_follower and car_follower.has_signal("lap_started"):
		car_follower.lap_started.connect(_on_lap_started)
		print("Connected to car lap_started signal")
	
	# Connect to all hitchhiker signals
	for child in hitchhikers_node.get_children():
		if child.has_signal("reached_player"):
			child.reached_player.connect(_on_hitchhiker_reached_player)
			print("Connected to hitchhiker: ", child.name)
		else:
			print("WARNING: Child '", child.name, "' does not have reached_player signal")
		
		if child.has_signal("player_passed_by"):
			child.player_passed_by.connect(_on_player_passed_by_hitchhiker)
			print("Connected to player_passed_by for: ", child.name)
	
	# Start with all hitchhikers disabled except hitchhiker 1
	disable_all_hitchhikers()
	enable_hitchhiker(1)
	
	print("GameManager initialized - connected to ", hitchhikers_node.get_child_count(), " hitchhikers")


const PROTOTYPE_DIALOGUE = preload("res://dialogue/prototype.dialogue")

const NOVINHA_DIALOGUE_PRE = preload("res://dialogue/vovo_pre.dialogue")
const NOVINHA_DIALOGUE = preload("res://dialogue/novinha.dialogue")

const VOVO_DIALOGUE_PRE = preload("res://dialogue/vovo_pre.dialogue")
const VOVO_DIALOGUE = preload("res://dialogue/vovo.dialogue")

const DRUNK_DIALOGUE_PRE = preload("res://dialogue/vovo_pre.dialogue")
const DRUNK_DIALOGUE = preload("res://dialogue/drunk_dialogue.dialogue")

const MIDDLE_DIALOGUE_PRE = preload("res://dialogue/vovo_pre.dialogue")
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
		# Set flag to enable next hitchhiker on next lap
		enable_next_hitchhiker_on_next_lap = true
		print("Next hitchhiker will be enabled on next lap")
	
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
			enable_hitchhiker(next_hitchhiker_to_enable)
			print("Enabled hitchhiker ", next_hitchhiker_to_enable, " on lap ", lap_number)
			next_hitchhiker_to_enable += 1
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
		1:  # Novinha - Two stage dialogue
			# Connect to generic pre-dialogue ended signal
			if not DialogueFlow.dialogue_ended.is_connected(_on_pre_dialogue_ended):
				DialogueFlow.dialogue_ended.connect(_on_pre_dialogue_ended)
				print("DEBUG: Connected _on_pre_dialogue_ended signal")
			# Start pre-dialogue (using Vovo's as placeholder until novinha_pre.dialogue is created)
			# TODO: Replace with NOVINHA_DIALOGUE_PRE when file is created
			DialogueFlow.run_dialogue(VOVO_DIALOGUE_PRE, "start")
		2:  # Vovo - Two stage dialogue
			# Connect to generic pre-dialogue ended signal
			if not DialogueFlow.dialogue_ended.is_connected(_on_pre_dialogue_ended):
				DialogueFlow.dialogue_ended.connect(_on_pre_dialogue_ended)
				print("DEBUG: Connected _on_pre_dialogue_ended signal")
			# Start pre-dialogue
			DialogueFlow.run_dialogue(VOVO_DIALOGUE_PRE, "start")
		3:  # Drunk/Fent - Two stage dialogue
			# Connect to generic pre-dialogue ended signal
			if not DialogueFlow.dialogue_ended.is_connected(_on_pre_dialogue_ended):
				DialogueFlow.dialogue_ended.connect(_on_pre_dialogue_ended)
				print("DEBUG: Connected _on_pre_dialogue_ended signal")
			# Start pre-dialogue (using Vovo's as placeholder until drunk_pre.dialogue is created)
			# TODO: Replace with DRUNK_DIALOGUE_PRE when file is created
			DialogueFlow.run_dialogue(VOVO_DIALOGUE_PRE, "start")
		4:  # Middle-aged - Two stage dialogue
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
				DialogueFlow.run_dialogue(NOVINHA_DIALOGUE, "start")
			2:
				DialogueFlow.run_dialogue(VOVO_DIALOGUE, "start")
			3:
				DialogueFlow.run_dialogue(DRUNK_DIALOGUE, "start")
			4:
				DialogueFlow.run_dialogue(MIDDLE_DIALOGUE, "start")
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
			# Set flag to enable next hitchhiker on next lap
			enable_next_hitchhiker_on_next_lap = true
			print("Next hitchhiker will be enabled on next lap")
		
		# Reset interaction
		current_hitchhiker = null
		current_hitchhiker_id = 0

# Generic handler for any main dialogue ending
func _on_main_dialogue_ended(_resource: Resource) -> void:
	# Disconnect the signal
	if DialogueFlow.dialogue_ended.is_connected(_on_main_dialogue_ended):
		DialogueFlow.dialogue_ended.disconnect(_on_main_dialogue_ended)
	
	# Clear dialogue flag
	in_dialogue = false
	
	# Check if this was hitchhiker 4
	if current_hitchhiker_id == 4:
		hitchhiker_4_completed = true
		print("Hitchhiker 4 dialogue ended - will teleport to torre on next loop")
	else:
		# Set flag to enable next hitchhiker on the next lap
		enable_next_hitchhiker_on_next_lap = true
		print("Main dialogue ended - next hitchhiker will be enabled on next lap")
	
	# Resume car movement and reset
	reset_hitchhiker_interaction()

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
	var carro_node = get_node_or_null("../CarFollower/Carro")
	if not carro_node:
		print("WARNING: Carro node not found!")
		return
	
	var mesh_name = "Hitchhiker" + str(hitchhiker_id) + "_BallMesh"
	var mesh_node = carro_node.get_node_or_null(mesh_name)
	if mesh_node:
		mesh_node.visible = true
		print("Showing ball mesh: ", mesh_name)
	else:
		print("WARNING: Ball mesh not found: ", mesh_name)

func hide_hitchhiker_ball_mesh(hitchhiker_id: int):
	var carro_node = get_node_or_null("../CarFollower/Carro")
	if not carro_node:
		return
	
	var mesh_name = "Hitchhiker" + str(hitchhiker_id) + "_BallMesh"
	var mesh_node = carro_node.get_node_or_null(mesh_name)
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
			child.visible = false
			child.process_mode = Node.PROCESS_MODE_DISABLED
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
					DialogueFlow.run_dialogue(DRUNK_DIALOGUE, "start")
