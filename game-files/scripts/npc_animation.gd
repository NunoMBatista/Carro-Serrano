extends Node3D

# Signal emitted when NPC reaches car window and is facing player
signal reached_player(npc: Node3D)
# Signal emitted when player passes by without picking up the hitchhiker
signal player_passed_by(npc: Node3D)

@export var speed_threshold: float = 0.1
@export var walk_speed: float = 1.2  # Speed when walking to car
@export var stop_distance: float = 0.1
@export var is_active: bool = false
@export var hitchhiker_id: int  = 0
@export var placement_id: int = 0
@export var interacting: bool = false


var car_inside: Node3D = null
var car_follower: Node3D = null  # Reference to CarFollower script
var car_inside_area2: Node3D = null
var next_animation: String = ""
var sequence_triggered: bool = false
var walking_to_car: bool = false
var window_target: Node3D = null  # Reference to car window position
var facing_player: bool = false
var player_interacted: bool = false  # Track if player picked up this hitchhiker
var audio_player: AudioStreamPlayer3D = null  # Reference to audio player

# Store initial state for reset
var initial_position: Vector3 = Vector3.ZERO
var initial_rotation: Vector3 = Vector3.ZERO

func _ready():
	# Store initial state
	initial_position = global_position
	initial_rotation = rotation_degrees
	
	_fix_walk_animation()
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)
	$AnimationPlayer.play("Wave")
	
	# Get reference to audio player
	audio_player = get_node_or_null("AudioStreamPlayer3D")
	if audio_player:
		print("NPC audio player initialized")
	else:
		print("WARNING: AudioStreamPlayer3D not found in NPC")

func _fix_walk_animation():
	var animation_name = "walk"
	var y_translation_offset = 6  # How many units to offset
	var fix_rotation = Vector3(0, 0, 0)  # Rotation fix if needed
	
	var anim_player = $AnimationPlayer
	if not anim_player.has_animation(animation_name):
		print("ERROR: Animation '" + animation_name + "' not found!")
		return
	
	var anim = anim_player.get_animation(animation_name)
	var track_count = anim.get_track_count()
	
	print("--- Applying Walk Animation Fixes: Rot " + str(fix_rotation) + " | Pos Y+" + str(y_translation_offset) + " ---")
	
	# Convert Euler angles to Quaternion for rotation fix
	var rot_correction = Quaternion.from_euler(
		Vector3(deg_to_rad(fix_rotation.x), deg_to_rad(fix_rotation.y), deg_to_rad(fix_rotation.z))
	)
	
	# Define the translation offset vector
	var pos_correction = Vector3(0, 0, -y_translation_offset)
	
	for i in range(track_count):
		# We only care about tracks involving the "Hips"
		if "Hips" in str(anim.track_get_path(i)):
			
			# --- 1. HANDLE ROTATION ---
			if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				for key in range(anim.track_get_key_count(i)):
					var old_rot = anim.track_get_key_value(i, key)
					var new_rot = rot_correction * old_rot
					anim.track_set_key_value(i, key, new_rot)
				print("SUCCESS: Rotated hips!")
			
			# --- 2. HANDLE POSITION ---
			elif anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				for key in range(anim.track_get_key_count(i)):
					var old_pos = anim.track_get_key_value(i, key)
					var new_pos = old_pos + pos_correction
					anim.track_set_key_value(i, key, new_pos)
				print("SUCCESS: Translated hips!")
	
	print("--- Walk Animation Adjustments Complete ---")

# Triggered when the car enters the radius

func _on_animation_finished(anim_name: String):
	if next_animation != "":
		$AnimationPlayer.play(next_animation)
		next_animation = ""
	else:
		# Re-enable looping for Wave animation when it starts again
		if anim_name != "Wave":
			var wave_anim = $AnimationPlayer.get_animation("Wave")
			if wave_anim:
				wave_anim.loop_mode = Animation.LOOP_LINEAR

func _on_area_3d_body_entered(body):
	if body.name == "Carro" or body is RigidBody3D:
		car_inside = body
		next_animation = "Idle"
		# Disable looping on current animation so it finishes and triggers the signal
		var current_anim_name = $AnimationPlayer.current_animation
		if current_anim_name != "":
			var anim = $AnimationPlayer.get_animation(current_anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE
		
		# Start playing audio on loop when car enters
		if audio_player and not audio_player.playing:
			audio_player.play()
			print("NPC audio started playing")
		# print("car entered big area")
# Triggered if the car leaves the radius without meeting the criteria
func _on_area_3d_body_exited(body):
	if body == car_inside:
		car_inside = null
		# If player didn't interact with this hitchhiker, emit passed_by signal
		# This happens whether the car slowed down or just drove past at full speed
		if not player_interacted:
			player_passed_by.emit(self)
			print("Player passed by hitchhiker ID ", hitchhiker_id, " without picking them up")
		
		# Stop audio when car leaves
		if audio_player and audio_player.playing:
			audio_player.stop()
			print("NPC audio stopped")
		# print("Car left big area")

# Triggered when car enters Area3D2 (velocity check area)
func _on_area_3d_2_body_entered(body):
	# Filter out terrain and only detect the car
	if body is RigidBody3D and (body.name == "Carro" or "car" in body.name.to_lower()):
		car_inside_area2 = body
		# Get the CarFollower parent node which has the actual speed
		car_follower = body.get_parent()
		# print("Car entered velocity check area")

# Triggered when car exits Area3D2
func _on_area_3d_2_body_exited(body):
	if body is RigidBody3D and (body.name == "Carro" or "car" in body.name.to_lower()):
		car_inside_area2 = null
		car_follower = null
		# print("Car left velocity check area")

func _physics_process(delta):
	# Check for velocity trigger
	if car_follower and not sequence_triggered:
		# Access cur_speed from the CarFollower script
		var current_speed = 0.0
		if "cur_speed" in car_follower:
			current_speed = car_follower.cur_speed
		if current_speed <= speed_threshold:
			start_sequence()
			sequence_triggered = true
	
	# Handle walking to car
	if walking_to_car and window_target:
		var target_pos = window_target.global_position
		var current_pos = global_position
		
		# Ignore Y coordinate - only face horizontal direction to window
		target_pos.y = current_pos.y
		
		var direction = (target_pos - current_pos)
		var distance = direction.length()
		
		if distance > stop_distance:
			# Still need to walk
			direction = direction.normalized()
			# Move towards target
			global_position += direction * walk_speed * delta
			# Rotate to face target
			look_at(target_pos, Vector3.UP)
		else:
			# Reached the window, stop and idle
			walking_to_car = false
			$AnimationPlayer.play("Idle")
			# Face the Player node inside the car
			if car_inside_area2:
				var player = car_inside_area2.get_node_or_null("Player")
				if player:
					var player_pos = player.global_position
					player_pos.y = current_pos.y
					look_at(player_pos, Vector3.UP)
					print("NPC facing Player")
					facing_player = true
					# Rotate 180º around Y axis to compensate for model orientation
					rotate_y(deg_to_rad(180))
					# Emit signal to notify game manager
					reached_player.emit(self)
				else:
					print("WARNING: Player node not found in car")
			print("NPC reached car window")

func start_sequence():
	print("Car detected at low speed within range!")
	
	# Find the WindowMarker child node of the car
	if car_inside_area2:
		var marker = car_inside_area2.get_node_or_null("WindowMarker")
		if marker:
			window_target = marker
			print("Found WindowMarker as target")
		else:
			# Fallback to car itself if WindowMarker not found
			window_target = car_inside_area2
			print("WARNING: WindowMarker not found, using car as target")
	
	# Start walking towards the car window
	walking_to_car = true
	$AnimationPlayer.play("walk")
	print("NPC starting to walk to car window")

## Reset NPC to initial state as if fully reloaded
func reset_to_initial_state():
	# Reset position and rotation
	# Reset all state variables
	car_inside = null
	car_follower = null
	car_inside_area2 = null
	next_animation = ""
	sequence_triggered = false
	walking_to_car = false
	window_target = null
	facing_player = false
	player_interacted = false
	
	# Stop and reset audio
	if audio_player and audio_player.playing:
		audio_player.stop()
	
	# Reset animation to Wave with looping
	var wave_anim = $AnimationPlayer.get_animation("Wave")
	if wave_anim:
		wave_anim.loop_mode = Animation.LOOP_LINEAR
	$AnimationPlayer.play("Wave")
	
	print("NPC reset to initial state - Position: ", initial_position, " Rotation: ", initial_rotation)
