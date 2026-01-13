@icon("./assets/responses_menu.svg")

## A [Container] for dialogue responses provided by [b]Dialogue Manager[/b].
class_name DialogueResponsesMenu extends Container


## Emitted when a response is selected.
signal response_selected(response)


## Optionally specify a control to duplicate for each response
@export var response_template: Control

## The action for accepting a response (is possibly overridden by parent dialogue balloon).
@export var next_action: StringName = &""

## Hide any responses where [code]is_allowed[/code] is false
@export var hide_failed_responses: bool = false

## The list of dialogue responses.
var responses: Array = []:
	get:
		return responses
	set(value):
		responses = value

		# Remove any current items
		for item in get_children():
			if item == response_template: continue

			remove_child(item)
			item.queue_free()

		# Add new items
		if responses.size() > 0:
			for response in responses:
				if hide_failed_responses and not response.is_allowed: continue

				var item: Control
				if is_instance_valid(response_template):
					item = response_template.duplicate(DUPLICATE_GROUPS | DUPLICATE_SCRIPTS | DUPLICATE_SIGNALS)
					item.show()
				else:
					item = Button.new()
				item.name = "Response%d" % get_child_count()
				if not response.is_allowed:
					item.name = item.name + &"Disallowed"
					item.disabled = true

				# If the item has a response property then use that
				if "response" in item:
					item.response = response
				# Otherwise assume we can just set the text
				else:
					item.text = response.text

				item.set_meta("response", response)

				add_child(item)

			_configure_menu()


var _selected_index: int = 0
var _selection_enabled: bool = false
var _selection_delay_timer: float = 0.0
const SELECTION_DELAY: float = 1.0  # 1 second delay before choices can be selected


func _ready() -> void:
	# Set focus mode so this container can receive input
	focus_mode = Control.FOCUS_ALL

	visibility_changed.connect(func():
		if visible and get_menu_items().size() > 0:
			# Hide cursor when showing dialogue choices
			print("[RESPONSES_MENU] Showing - setting mouse mode to HIDDEN")
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_HIDDEN)
			var items = get_menu_items()
			print("[RESPONSES_MENU] Menu items count: ", items.size())
			_selected_index = 0
			_selection_enabled = false
			_selection_delay_timer = 0.0
			_update_selection()
			grab_focus()
			print("[RESPONSES_MENU] Grabbed focus on container, selected index 0")
		elif not visible:
			# Restore cursor to captured mode when response menu is hidden
			print("[RESPONSES_MENU] Hiding - setting mouse mode to CAPTURED")
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
	)

	if is_instance_valid(response_template):
		response_template.hide()


func _process(delta: float) -> void:
	if not visible:
		return

	# Count down the selection delay timer
	if not _selection_enabled:
		_selection_delay_timer += delta
		if _selection_delay_timer >= SELECTION_DELAY:
			_selection_enabled = true
			print("[RESPONSES_MENU] Selection now enabled after delay")
			_update_selection()  # Update to show choices are now selectable


func _input(event: InputEvent) -> void:
	if not visible:
		return

	var items = get_menu_items()
	if items.is_empty():
		return

	# Ignore mouse motion - let it pass through to camera
	if event is InputEventMouseMotion:
		return

	# Handle keyboard input
	if event is InputEventKey and event.pressed:
		print("[RESPONSES_MENU] Key pressed: keycode=", event.keycode)

		# Check for down arrow (keycode 4194322)
		if event.keycode == KEY_DOWN or event.keycode == 4194322:
			if _selection_enabled:
				print("[RESPONSES_MENU] Down arrow pressed, current index: ", _selected_index)
				_selected_index = (_selected_index + 1) % items.size()
				_update_selection()
				get_viewport().set_input_as_handled()
				print("[RESPONSES_MENU] New index: ", _selected_index)
		# Check for up arrow (keycode 4194320)
		elif event.keycode == KEY_UP or event.keycode == 4194320:
			if _selection_enabled:
				print("[RESPONSES_MENU] Up arrow pressed, current index: ", _selected_index)
				_selected_index = (_selected_index - 1 + items.size()) % items.size()
				_update_selection()
				get_viewport().set_input_as_handled()
				print("[RESPONSES_MENU] New index: ", _selected_index)
		# Check for Enter (keycode 4194309)
		elif event.keycode == KEY_ENTER or event.keycode == 4194309:
			if _selection_enabled:
				print("[RESPONSES_MENU] Accept pressed on index: ", _selected_index)
				var item: Control = items[_selected_index]
				if item.has_meta("response") and not ("Disallowed" in item.name):
					get_viewport().set_input_as_handled()
					DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CAPTURED)
					var logger = get_node_or_null("/root/PlaytestLogger")
					if logger:
						logger.log_action("dialogue_choice", item.get_meta("response").text)
					response_selected.emit(item.get_meta("response"))
					print("[RESPONSES_MENU] Response selected and emitted")
			else:
				print("[RESPONSES_MENU] Selection blocked - still in delay period")
				get_viewport().set_input_as_handled()


func _update_selection() -> void:
	var items = get_menu_items()
	for i in items.size():
		var item: Control = items[i]
		if i == _selected_index:
			# Highlight selected item - bright yellow if enabled, grey if disabled
			var color = Color(1.0, 1.0, 0.3) if _selection_enabled else Color(0.5, 0.5, 0.5)
			if item is RichTextLabel:
				item.add_theme_color_override("default_color", color)
			else:
				item.add_theme_color_override("font_color", color)
			print("[RESPONSES_MENU] Highlighted item ", i, ": ", item.name)
		else:
			# Normal color - original beige if enabled, grey if disabled
			var color = Color(0.5, 0.5, 0.5) if not _selection_enabled else Color.WHITE
			if item is RichTextLabel:
				if not _selection_enabled:
					item.add_theme_color_override("default_color", color)
				else:
					item.remove_theme_color_override("default_color")
			else:
				if not _selection_enabled:
					item.add_theme_color_override("font_color", color)
				else:
					item.remove_theme_color_override("font_color")


## Get the selectable items in the menu.
func get_menu_items() -> Array:
	var items: Array = []
	for child in get_children():
		if not child.visible: continue
		if "Disallowed" in child.name: continue
		items.append(child)

	return items


#region Internal


# Prepare the menu for keyboard navigation - manual selection handling
func _configure_menu() -> void:
	var items = get_menu_items()
	print("[RESPONSES_MENU] _configure_menu() called with ", items.size(), " items")

	_selected_index = 0

	for i in items.size():
		var item: Control = items[i]
		# Don't use Godot's focus system, we handle selection manually
		item.focus_mode = Control.FOCUS_NONE
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ignore mouse completely
		print("[RESPONSES_MENU] Configured item ", i, ": ", item.name)

	print("[RESPONSES_MENU] Menu configured, ready for keyboard input")


#endregion
