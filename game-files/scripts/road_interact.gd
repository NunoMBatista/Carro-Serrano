extends StaticBody3D
## Road interaction point for the lift ending (good empathy + called for help)

const CREDITS_SCENE = preload("res://scenes/credits.tscn")

func interact() -> void:
	print("DEBUG: Road interact triggered")
	# Check if player called for help at payphone
	var gm = get_tree().get_current_scene().get_node_or_null("GameManager")
	if not gm or not gm.payphone_choice_yes:
		# Player didn't call for help, don't allow this interaction
		print("DEBUG: Interaction blocked - player didn't call for help")
		return

	print("DEBUG: Player called for help, setting lift mode")
	# Set crosshair to lift mode
	var crosshair = _get_active_crosshair(get_tree().get_current_scene())
	if crosshair and crosshair.has_method("set_lift_mode"):
		crosshair.set_lift_mode()
		print("DEBUG: Lift mode activated")
		# Start moving the exterior car along the torre path
		var root = get_tree().get_current_scene()
		if root:
			var path_follow = root.get_node_or_null("torre/Path3D/PathFollow3D")
			if path_follow and path_follow.has_method("start_moving"):
				path_follow.start_moving()
				print("DEBUG: carro_exterior2 movement started")
	else:
		print("DEBUG: WARNING - Crosshair not found or doesn't have set_lift_mode")

	# Wait for the exterior car to reach the end of the path (or a timeout)
	var root2 = get_tree().get_current_scene()
	if root2:
		var pf = root2.get_node_or_null("torre/Path3D/PathFollow3D")
		if pf and pf.has_signal("movement_finished"):
			print("DEBUG: Waiting for carro_exterior2 movement_finished (honk)...")
			await pf.movement_finished
			print("DEBUG: Help car movement_finished received, showing stranger dialogue")
			await _show_stranger_lift_dialogue()
	else:
		# Fallback: fixed delay if PathFollow not found
		print("DEBUG: PathFollow3D not found, falling back to fixed wait")
		await get_tree().create_timer(10.0).timeout

	# Trigger smooth fade to black and credits
	print("DEBUG: Starting smooth fade credits")
	_show_credits_with_fade()


## Show the stranger dialogue after the help car arrives and honks
func _show_stranger_lift_dialogue() -> void:
	print("DEBUG: Showing stranger lift dialogue")
	var dm = DialogueManager
	if dm == null:
		print("DEBUG: DialogueManager autoload not found; cannot show stranger dialogue")
		return

	var text_block := "~ start\n\n**Stranger: Is you car broken?**\n**Come on in, it's freezing, I'll give you a ride back.**\n\n=> END\n"
	var resource: Resource = dm.create_resource_from_text(text_block)
	dm.show_example_dialogue_balloon(resource, "start")
	await dm.dialogue_ended


func _show_credits_with_fade() -> void:
	print("DEBUG: _show_credits_with_fade called")
	# Load and show credits scene with smooth fade mode
	var credits = CREDITS_SCENE.instantiate()
	print("DEBUG: Credits instantiated: ", credits != null)
	if credits.has_method("set_hard_cut_mode"):
		credits.set_hard_cut_mode(false)  # Smooth fade mode
		print("DEBUG: Smooth fade mode set")
	print("DEBUG: Adding credits to tree...")
	get_tree().root.add_child(credits)
	print("DEBUG: Credits added to tree")


func _get_active_crosshair(root: Node) -> Node:
	var player_controller = _find_node(root, "PlayerController")
	if player_controller and player_controller.has_node("Control/CrossHair"):
		return player_controller.get_node("Control/CrossHair")

	var player = _find_node(root, "Player")
	if player and player.has_node("Control/CrossHair"):
		return player.get_node("Control/CrossHair")

	return null


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
