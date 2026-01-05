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

	# Don't allow interaction during dialogue
	if _is_dialogue_active():
		return

	_view_open = true
	_audio_player.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_player_raycast_enabled(false)

	var view = GLOVEBOX_VIEW.instantiate()
	get_tree().root.add_child(view)
	view.closed.connect(_on_view_closed)

func _on_view_closed() -> void:
	_view_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
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


func _is_dialogue_active() -> bool:
	# Check if DialogueFlow is active
	var dialogue_flow = get_node_or_null("/root/DialogueFlow")
	if dialogue_flow and dialogue_flow.get("is_dialogue_active"):
		return dialogue_flow.is_dialogue_active

	# Check if mouse is visible (indicating UI is open, including dialogue)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		# Check if there's an active dialogue balloon in the scene
		var root = get_tree().root
		for child in root.get_children():
			if child.name.contains("Balloon") or child is CanvasLayer:
				return true

	return false
