extends Node

## Session-based glovebox state manager
## This persists glovebox item positions only for the current playthrough/session
## State is reset when starting a new game

var _item_states: Dictionary = {}
var _has_saved_state: bool = false

# Track which items should be spawned in the glovebox
var _items_to_spawn: Array[String] = []

func save_item_state(item_name: String, state_data: Dictionary) -> void:
	"""Save state for a specific item"""
	_item_states[item_name] = state_data
	_has_saved_state = true

func get_item_state(item_name: String) -> Dictionary:
	"""Get saved state for a specific item"""
	return _item_states.get(item_name, {})

func has_state_for(item_name: String) -> bool:
	"""Check if we have saved state for an item"""
	return _item_states.has(item_name)

func has_any_saved_state() -> bool:
	"""Check if any state has been saved this session"""
	return _has_saved_state

func clear_all_states() -> void:
	"""Clear all saved states (call when starting new game)"""
	_item_states.clear()
	_has_saved_state = false
	_items_to_spawn.clear()

func save_all_items(items: Array) -> void:
	"""Save state for all items at once"""
	for item in items:
		if item and is_instance_valid(item) and item.has_method("get_save_data"):
			_item_states[item.name] = item.get_save_data()
	_has_saved_state = true

func load_all_items(items: Array) -> void:
	"""Load state for all items at once"""
	if not _has_saved_state:
		return

	for item in items:
		if item and is_instance_valid(item):
			var state = get_item_state(item.name)
			if not state.is_empty() and item.has_method("load_save_data"):
				item.load_save_data(state)

func add_item_to_spawn(item_name: String) -> void:
	"""Mark an item to be spawned in the glovebox (e.g., after dialogue completion)"""
	if not _items_to_spawn.has(item_name):
		_items_to_spawn.append(item_name)
		print("GloveboxState: Marked ", item_name, " to spawn in glovebox")

func get_items_to_spawn() -> Array[String]:
	"""Get list of items that should be spawned"""
	return _items_to_spawn.duplicate()

func has_item_to_spawn(item_name: String) -> bool:
	"""Check if an item should be spawned"""
	return _items_to_spawn.has(item_name)
