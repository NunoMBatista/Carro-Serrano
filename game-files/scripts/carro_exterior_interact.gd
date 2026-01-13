extends StaticBody3D

var _dialog_open: bool = false
var _current_dialog: ConfirmationDialog = null

func interact() -> void:
	if _dialog_open:
		return

	var gm = _get_game_manager()
	if gm == null:
		return

	# Only allow interaction after payphone has been used
	if not gm.payphone_used:
		return

	_dialog_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_player_raycast_enabled(false)

	if gm.payphone_choice_yes:
		_show_broke_down_dialog()
	else:
		_show_do_what_dialog()


func _show_broke_down_dialog() -> void:
	_current_dialog = ConfirmationDialog.new()
	var dlg := _current_dialog
	dlg.title = ""
	dlg.dialog_text = "Car broke down."
	dlg.get_ok_button().text = "Ask for lift"
	var second_btn := dlg.add_button("Ask for lift", true)
	var cancel_btn := dlg.get_cancel_button()
	if cancel_btn:
		cancel_btn.visible = false

	dlg.confirmed.connect(_on_broke_down_confirmed)
	second_btn.pressed.connect(_on_broke_down_confirmed)

	get_tree().root.add_child(dlg)
	dlg.popup_centered()


func _show_do_what_dialog() -> void:
	_current_dialog = ConfirmationDialog.new()
	var dlg := _current_dialog
	dlg.title = ""
	dlg.dialog_text = "Do what you came here to do."
	dlg.get_ok_button().text = "Yes"
	var second_btn := dlg.add_button("yes", true)
	var cancel_btn := dlg.get_cancel_button()
	if cancel_btn:
		cancel_btn.visible = false

	dlg.confirmed.connect(_on_return_to_car)
	second_btn.pressed.connect(_on_return_to_car)
	# No cancel option: only the two yes-style choices

	get_tree().root.add_child(dlg)
	dlg.popup_centered()


func _on_broke_down_confirmed() -> void:
	# Placeholder: extend with actual outcome later if needed
	_close_dialog()
	# Switch crosshair into non-interactive lift mode
	var crosshair = _get_active_crosshair(get_tree().get_current_scene())
	if crosshair and crosshair.has_method("set_lift_mode"):
		crosshair.set_lift_mode()


func _on_return_to_car() -> void:
	_return_player_to_car()
	_close_dialog()
	_show_are_you_sure_dialog()


func _on_dialog_canceled_generic() -> void:
	_close_dialog()


func _show_are_you_sure_dialog() -> void:
	_dialog_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_player_raycast_enabled(false)

	_current_dialog = ConfirmationDialog.new()
	var dlg := _current_dialog
	dlg.title = ""
	dlg.dialog_text = "Are you sure"
	dlg.get_ok_button().text = "Yes"
	var cancel_btn := dlg.get_cancel_button()
	if cancel_btn:
		cancel_btn.visible = false

	dlg.confirmed.connect(_on_are_you_sure_confirmed)
	dlg.canceled.connect(_on_are_you_sure_closed)

	get_tree().root.add_child(dlg)
	dlg.popup_centered()


func _on_are_you_sure_confirmed() -> void:
	_close_dialog()


func _on_are_you_sure_closed() -> void:
	_close_dialog()


func _close_dialog() -> void:
	# Reset crosshair click state so it doesn't stay "closed" after dialogs
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


func _get_active_crosshair(root: Node) -> Node:
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
