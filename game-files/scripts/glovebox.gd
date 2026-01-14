extends StaticBody3D
## Clickable glovebox that opens a 2D view when interacted with

const GLOVEBOX_VIEW = preload("res://scenes/glovebox_view.tscn")
const GLOVEBOX_SFX = preload("res://assets/audio/sfx/glove_box_sfx.mp3")

var _view_open: bool = false
var _audio_player: AudioStreamPlayer

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = GLOVEBOX_SFX
	_audio_player.bus = "Master"
	add_child(_audio_player)

func interact() -> void:
	if _view_open:
		return

	# Check if player is in walking mode - if so, disable glovebox
	if _is_in_walking_mode():
		return

	_view_open = true
	_audio_player.play()
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
	_set_player_raycast_enabled(false)

	var view = GLOVEBOX_VIEW.instantiate()
	get_tree().root.add_child(view)
	view.closed.connect(_on_view_closed)

func _on_view_closed() -> void:
	_view_open = false
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	_set_player_raycast_enabled(true)


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
	# resolve NodePath if necessary
	if rc and rc is NodePath:
		if cross.has_node(rc):
			rc = cross.get_node(rc)
		elif player.has_node(rc):
			rc = player.get_node(rc)
		else:
			rc = null
	if rc and rc is RayCast3D:
		rc.enabled = enabled


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
