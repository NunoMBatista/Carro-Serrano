@tool
extends Node3D

# --- SETTINGS ---
var animation_name = "walk"
var y_translation_offset = 11.3  # How many units to move UP (Y+)

# LOGIC:
# X = 90  -> Flips "Upside Down" to "Standing Up"
# Y = 0   -> Resets the spin.
# Z = 0   -> No ear-to-shoulder tilting.
var fix_rotation = Vector3(180, 0, -90) 

func _ready():
	var anim_player = $AnimationPlayer
	if not anim_player.has_animation(animation_name):
		print("ERROR: Animation '" + animation_name + "' not found!")
		return

	var anim = anim_player.get_animation(animation_name)
	var track_count = anim.get_track_count()
	
	print("--- Applying Fixes: Rot " + str(fix_rotation) + " | Pos Y+" + str(y_translation_offset) + " ---")
	
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

			# --- 2. HANDLE POSITION (The new part) ---
			elif anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				for key in range(anim.track_get_key_count(i)):
					var old_pos = anim.track_get_key_value(i, key)
					# Add the Y offset to the existing position
					var new_pos = old_pos + pos_correction
					anim.track_set_key_value(i, key, new_pos)
				print("SUCCESS: Translated hips!")

	print("--- Adjustments Complete ---")
