extends CanvasLayer
## 2D Glovebox view overlay

signal closed

var _clickable_items: Array[Control] = []

@onready var background: TextureRect = $Background
@onready var hint_label: Label = $HintLabel
@onready var items_container: Control = $ItemsContainer

func _ready() -> void:
	# Setup hint label
	hint_label.text = "RMB to leave"
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	
	# Create example clickable circle
	_create_clickable_circle(Vector2(300, 200), 40, Color(0.8, 0.3, 0.3))
	_create_clickable_circle(Vector2(500, 300), 30, Color(0.3, 0.8, 0.3))

	# connect hover/click hooks so crosshair shows open/closed on UI interaction
	# existing dynamically created items will have their signals connected in _create_clickable_circle
	# nothing else to connect here for now

func _create_clickable_circle(pos: Vector2, radius: float, color: Color) -> void:
	var circle = ColorRect.new()
	circle.custom_minimum_size = Vector2(radius * 2, radius * 2)
	circle.size = Vector2(radius * 2, radius * 2)
	circle.position = pos - Vector2(radius, radius)
	circle.color = color
	circle.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Make it round-ish with a shader or just keep square for simplicity
	circle.gui_input.connect(_on_circle_clicked.bind(circle))
	circle.mouse_entered.connect(Callable(self, "_on_item_mouse_entered").bind(circle))
	circle.mouse_exited.connect(Callable(self, "_on_item_mouse_exited").bind(circle))
	
	items_container.add_child(circle)
	_clickable_items.append(circle)

func _on_circle_clicked(event: InputEvent, circle: ColorRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Cycle through colors
		var colors = [Color(0.8, 0.3, 0.3), Color(0.3, 0.8, 0.3), Color(0.3, 0.3, 0.8), Color(0.8, 0.8, 0.3)]
		var current_idx = -1
		for i in colors.size():
			if circle.color.is_equal_approx(colors[i]):
				current_idx = i
				break
		circle.color = colors[(current_idx + 1) % colors.size()]
		# tell crosshair to briefly close on click
		_simulate_crosshair_click()


func _on_item_mouse_entered(item: Control) -> void:
	_set_crosshair_hover(true)


func _on_item_mouse_exited(item: Control) -> void:
	_set_crosshair_hover(false)


func _set_crosshair_hover(enabled: bool) -> void:
	var cross = _get_crosshair()
	if cross and cross.has_method("set_ui_hovering"):
		cross.set_ui_hovering(enabled)


func _simulate_crosshair_click() -> void:
	var cross = _get_crosshair()
	if cross and cross.has_method("simulate_click"):
		cross.simulate_click()


func _get_crosshair():
	var scene = get_tree().get_current_scene()
	if not scene:
		return null
	if scene.has_node("Player/Control/CrossHair"):
		return scene.get_node("Player/Control/CrossHair")
	# fallback: recursive search
	return _find_node(scene, "CrossHair")


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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()

func close() -> void:
	closed.emit()
	queue_free()
