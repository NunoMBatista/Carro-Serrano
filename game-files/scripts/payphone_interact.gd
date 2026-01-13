extends StaticBody3D
## Clickable payphone that shows a yes/no confirmation dialog

var _dialog_open: bool = false
var _current_dialog: ConfirmationDialog = null
var _used: bool = false

func interact() -> void:
	if _used:
		return
	if _dialog_open:
		return
	_dialog_open = true

	# Show cursor and disable player raycast while dialog is open
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_player_raycast_enabled(false)

	# Build a confirmation dialog with Yes/No options
	_current_dialog = ConfirmationDialog.new()
	var dlg := _current_dialog
	dlg.title = ""
	dlg.dialog_text = "Call for help?"
	# Customize buttons to Yes/No
	dlg.get_ok_button().text = "Yes"
	var no_btn := dlg.add_button("No", true)
	var cancel_btn := dlg.get_cancel_button()
	if cancel_btn:
		cancel_btn.visible = false

	# Connect signals
	dlg.confirmed.connect(_on_dialog_confirmed)
	no_btn.pressed.connect(_on_dialog_cancelled)
	dlg.canceled.connect(_on_dialog_cancelled)

	# Add to tree and popup centered
	get_tree().root.add_child(dlg)
	dlg.popup_centered()


func _on_dialog_confirmed() -> void:
	_notify_choice(true)
	_close_dialog()


func _on_dialog_cancelled() -> void:
	_notify_choice(false)
	_close_dialog()


func _close_dialog() -> void:
	_used = true
	# Disable this payphone's collision so it cannot be interacted again
	if self is CollisionObject3D:
		collision_layer = 0

	# Reset crosshair click state so it doesn't stay "closed"
	var scene = get_tree().get_current_scene()
	if scene:
		var cross = _get_active_crosshair(scene)
		if cross and cross.has_method("set"):
			cross.set("space_held", false)

	_dialog_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_set_player_raycast_enabled(true)
	if _current_dialog and is_instance_valid(_current_dialog):
		_current_dialog.hide()
		_current_dialog.queue_free()
	_current_dialog = null


func _set_player_raycast_enabled(enabled: bool) -> void:
	var scene = get_tree().get_current_scene()
	if not scene:
		return
	var cross = _get_active_crosshair(scene)
	if not cross:
		return
	var rc = null
	if cross.has_method("get"):
		rc = cross.get("raycast")
	if rc and rc is NodePath:
		if cross.has_node(rc):
			rc = cross.get_node(rc)
		else:
			rc = null
	if rc and rc is RayCast3D:
		rc.enabled = enabled


func _notify_choice(chose_yes: bool) -> void:
	var scene = get_tree().get_current_scene()
	if not scene:
		return
	var gm = scene.get_node_or_null("GameManager")
	if gm and gm.has_method("on_payphone_choice"):
		gm.on_payphone_choice(chose_yes)


func _get_active_crosshair(root: Node) -> Node:
	# Prefer the walking player controller crosshair when present,
	# otherwise fall back to the in-car Player crosshair.
	var player_controller = _find_node(root, "PlayerController")
	if player_controller and player_controller.has_node("Control/CrossHair"):
		return player_controller.get_node("Control/CrossHair")

	var player = _find_node(root, "Player")
	if player and player.has_node("Control/CrossHair"):
		return player.get_node("Control/CrossHair")

	return null


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
