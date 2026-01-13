extends StaticBody3D
## Clickable car that shows dialogues using the dialogue system

const CAR_DIALOGUE = preload("res://dialogue/car_dialogue.dialogue")
const DO_IT_DIALOGUE = preload("res://dialogue/leave_car_dialogue.dialogue")

var _dialogue_active: bool = false
var _last_title: String = ""

func interact() -> void:
	if _dialogue_active:
		return

	var gm = _get_game_manager()
	if gm == null:
		return

	# Only allow interaction after payphone has been used
	if not gm.payphone_used:
		return

	_dialogue_active = true

	# Disable player movement during dialogue
	_set_player_active(false)

	# Start the car dialogue
	DialogueManager.passed_title.connect(_on_passed_title)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.show_example_dialogue_balloon(CAR_DIALOGUE, "start")


func _on_passed_title(title: String) -> void:
	_last_title = title


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	DialogueManager.passed_title.disconnect(_on_passed_title)
	DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	_dialogue_active = false

	# Re-enable player movement
	_set_player_active(true)

	# Handle different endings based on the last title
	if _last_title == "already_called":
		# Player already called for help, guide them to the road
		# The road interaction will be visible and active
		pass
	elif _last_title == "do_what":
		# Player didn't call for help - return to car, then show do_it dialogue
		_return_player_to_car()
		# Wait for camera transition
		await get_tree().create_timer(1.0).timeout
		# Show the do_it dialogue
		_show_do_it_dialogue()


func _show_do_it_dialogue() -> void:
	_dialogue_active = true
	DialogueManager.passed_title.connect(_on_do_it_passed_title)
	DialogueManager.dialogue_ended.connect(_on_do_it_dialogue_ended)
	DialogueManager.show_example_dialogue_balloon(DO_IT_DIALOGUE, "start")


func _on_do_it_passed_title(title: String) -> void:
	_last_title = title


func _on_do_it_dialogue_ended(_resource: DialogueResource) -> void:
	DialogueManager.passed_title.disconnect(_on_do_it_passed_title)
	DialogueManager.dialogue_ended.disconnect(_on_do_it_dialogue_ended)
	_dialogue_active = false

	# Player chose "DO IT" - trigger hard cut to black and credits
	if _last_title == "do_it":
		_trigger_hard_cut_credits()


func _trigger_hard_cut_credits() -> void:
	print("DEBUG: _trigger_hard_cut_credits called")
	# Hard cut: immediately stop music and cut to black, then show credits
	RadioManager._stop_all()
	RadioManager._stop_base_track()
	print("DEBUG: Music stopped")

	# Load credits scene with hard cut mode
	var credits_scene = load("res://scenes/credits.tscn")
	print("DEBUG: Credits scene loaded: ", credits_scene != null)
	if credits_scene:
		var credits = credits_scene.instantiate()
		print("DEBUG: Credits instantiated: ", credits != null)
		if credits.has_method("set_hard_cut_mode"):
			credits.set_hard_cut_mode(true)
			print("DEBUG: Hard cut mode set")
		print("DEBUG: Adding credits to tree...")
		get_tree().root.add_child(credits)
		print("DEBUG: Credits added to tree")
	else:
		print("ERROR: Failed to load credits scene!")


func _get_game_manager():
	var root = get_tree().get_current_scene()
	if not root:
		return null
	var gm = root.get_node_or_null("GameManager")
	return gm


func _return_player_to_car() -> void:
	var root = get_tree().get_current_scene()
	if not root:
		return
	var follower = root.get_node_or_null("CarFollower")
	if follower and follower.has_method("return_to_car_from_torre"):
		follower.return_to_car_from_torre()


func _get_active_crosshair(root: Node) -> Node:
	var player_controller = _find_node(root, "PlayerController")
	if player_controller and player_controller.has_node("Control/CrossHair"):
		return player_controller.get_node("Control/CrossHair")

	var player = _find_node(root, "Player")
	if player and player.has_node("Control/CrossHair"):
		return player.get_node("Control/CrossHair")

	return null


func _set_player_active(active: bool) -> void:
	var scene = get_tree().get_current_scene()
	if not scene:
		return
	var player = _find_node(scene, "PlayerController")
	if player and player.has_method("set_physics_process"):
		player.set_physics_process(active)


func _find_node(root: Node, name: String) -> Node:
	if not root:
		return null
	if str(root.name) == name:
		return root
	for child in root.get_children():
		if child and child is Node:
			var res = _find_node(child, name)
			if res:
				return res
	return null
