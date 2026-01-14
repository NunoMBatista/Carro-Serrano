extends StaticBody3D
## Clickable payphone that shows a yes/no confirmation dialog

var _dialog_open: bool = false

func interact() -> void:
	if _dialog_open:
		return
	_dialog_open = true

	# Show cursor and disable player raycast while dialog is open
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
	_set_player_raycast_enabled(false)

	# Build a confirmation dialog with Yes/No options
	var dlg := ConfirmationDialog.new()
	dlg.title = "Call for help"
	dlg.dialog_text = "Call for help?"
	# Customize buttons to Yes/No
	dlg.get_ok_button().text = "Yes"
	var no_btn := dlg.add_button("No", true)

	# Connect signals
	dlg.confirmed.connect(_on_dialog_confirmed)
	no_btn.pressed.connect(_on_dialog_cancelled)
	dlg.canceled.connect(_on_dialog_cancelled)

	# Add to tree and popup centered
	get_tree().root.add_child(dlg)
	dlg.popup_centered()


func _on_dialog_confirmed() -> void:
	# TODO: implement actual help-call behavior here if needed
	_close_dialog()


func _on_dialog_cancelled() -> void:
	_close_dialog()


func _close_dialog() -> void:
	_dialog_open = false
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
