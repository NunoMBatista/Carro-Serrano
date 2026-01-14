extends StaticBody3D
## Clickable car horn that plays a honk sound when interacted with

const HONK_SFX = preload("res://assets/audio/sfx/honk.mp3")

var _audio_player: AudioStreamPlayer

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = HONK_SFX
	_audio_player.bus = "Master"
	add_child(_audio_player)

func interact() -> void:
	# Check if player is in walking mode - if so, disable horn
	if _is_in_walking_mode():
		return

	# Don't play if already playing
	if _audio_player.playing:
		return

	_audio_player.play()


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
