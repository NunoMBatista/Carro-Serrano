extends StaticBody3D
## Clickable radio that opens a 2D view when interacted with

const RADIO_VIEW = preload("res://scenes/radio_view.tscn")

var _view_open: bool = false

func interact() -> void:
	if _view_open:
		return

	# Check if player is in walking mode - if so, disable radio
	if _is_in_walking_mode():
		return

	_view_open = true
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
	_set_player_raycast_enabled(false)

	var view = RADIO_VIEW.instantiate()
	get_tree().root.add_child(view)
	view.closed.connect(_on_view_closed)

func _on_view_closed() -> void:
	_view_open = false
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	_set_player_raycast_enabled(true)


func _is_in_walking_mode() -> bool:
	"""Check if the player has left the car and is walking"""
	var scene = get_tree().get_current_scene()
	if not scene:
		return false

	# Find the CarFollower node
	var car_follower = _find_node(scene, "CarFollower")
	if not car_follower:
		return false

	# Check if it has the _in_walking_mode variable
	if car_follower.get("_in_walking_mode"):
		return true

	return false


func _set_player_raycast_enabled(enabled: bool) -> void:
	var scene = get_tree().get_current_scene()
	if not scene:
		return
	var player = _find_node(scene, "Player")
	if not player:
		return
	if not player.has_node("Control/CrossHair"):
		return
	var cross = player.get_node("Control/CrossHair")
	if not cross:
		return
	var rc = null
	if cross.has_method("get"):
		rc = cross.get("raycast")
	if rc and rc is NodePath:
		if cross.has_node(rc):
			rc = cross.get_node(rc)
		elif player.has_node(rc):
			rc = player.get_node(rc)
		else:
			rc = null
	if rc and rc is RayCast3D:
		rc.enabled = enabled


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
