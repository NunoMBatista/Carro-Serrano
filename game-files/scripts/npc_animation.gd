extends Node3D

@export var speed_threshold: float = 4.0
@export var walk_speed: float = 2.0  # Speed when walking to car
@export var stop_distance: float = 2.0                                                    # How close to get to the window

var car_inside: Node3D = null
var car_inside_area2: Node3D = null
var next_animation: String = ""
var sequence_triggered: bool = false
var walking_to_car: bool = false
var window_target: Node3D = null  # Reference to car window position

func _ready():
	_fix_walk_animation()
	$AnimationPlayer.animation_finished.connect(_on_animation_finished)
	$AnimationPlayer.play("Wave")

func _fix_walk_animation():
	var animation_name = "walk"
	var y_translation_offset = 11.3*2  # How many units to offset
	var fix_rotation = Vector3(0, 0, 180)  # Rotation fix if needed
	
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
		# print("car entered big area")
# Triggered if the car leaves the radius without meeting the criteria
func _on_area_3d_body_exited(body):
	if body == car_inside:
		car_inside = null
		# print("Car left big area")

# Triggered when car enters Area3D2 (velocity check area)
func _on_area_3d_2_body_entered(body):
	# Filter out terrain and only detect the car
	if body is RigidBody3D and (body.name == "Carro" or "car" in body.name.to_lower()):
		car_inside_area2 = body
		# print("Car entered velocity check area")

# Triggered when car exits Area3D2
func _on_area_3d_2_body_exited(body):
	if body is RigidBody3D and (body.name == "Carro" or "car" in body.name.to_lower()):
		car_inside_area2 = null
		# print("Car left velocity check area")

func _physics_process(delta):
	# Check for velocity trigger
	if car_inside_area2 and not sequence_triggered:
		var current_speed = car_inside_area2.linear_velocity.length()
		if current_speed <= speed_threshold:
			start_sequence()
			sequence_triggered = true
	
	# Handle walking to car
	if walking_to_car and window_target:
		var target_pos = window_target.global_position
		var current_pos = global_position
		
		# Ignore Y coordinate - only move on horizontal plane
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
			# Face the window
			look_at(target_pos, Vector3.UP)
			print("NPC reached car window")

func start_sequence():
	print("Car detected at low speed within range!")
	
	# Use the car as target for now
	if car_inside_area2:
		window_target = car_inside_area2
	
	# Start walking towards the car
	walking_to_car = true
	$AnimationPlayer.play("walk")
	print("NPC starting to walk to car")
