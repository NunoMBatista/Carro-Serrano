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
	else:
		print("DEBUG: WARNING - Crosshair not found or doesn't have set_lift_mode")

	# Wait 4 seconds for the lift mode to be visible
	print("DEBUG: Waiting 4 seconds before fade...")
	await get_tree().create_timer(4.0).timeout

	# Trigger smooth fade to black and credits
	print("DEBUG: Starting smooth fade credits")
	_show_credits_with_fade()


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
