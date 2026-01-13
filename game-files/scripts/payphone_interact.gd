extends StaticBody3D
## Clickable payphone that shows a dialogue using the dialogue system

const PAYPHONE_DIALOGUE = preload("res://dialogue/payphone_dialogue.dialogue")

var _used: bool = false
var _dialogue_active: bool = false
var _last_title: String = ""

func interact() -> void:
	if _used:
		return
	if _dialogue_active:
		return

	_dialogue_active = true
	_used = true

	# Disable this payphone's collision so it cannot be interacted again
	collision_layer = 0

	# Disable player movement during dialogue
	_set_player_active(false)

	# Start the payphone dialogue
	DialogueManager.passed_title.connect(_on_passed_title)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	DialogueManager.show_example_dialogue_balloon(PAYPHONE_DIALOGUE, "start")


func _on_passed_title(title: String) -> void:
	_last_title = title


func _on_dialogue_ended(resource: DialogueResource) -> void:
	DialogueManager.passed_title.disconnect(_on_passed_title)
	DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	_dialogue_active = false

	# Re-enable player movement
	_set_player_active(true)

	# Determine which choice was made based on the last title
	var chose_yes = (_last_title == "call_yes")

	# Notify GameManager of the choice
	_notify_choice(chose_yes)


func _notify_choice(chose_yes: bool) -> void:
	var scene = get_tree().get_current_scene()
	if not scene:
		return
	var gm = scene.get_node_or_null("GameManager")
	if gm and gm.has_method("on_payphone_choice"):
		gm.on_payphone_choice(chose_yes)


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
