extends Node

# VIVARIUM MANAGER - SINGLETON
# This manager is a lightweight bridge to the full VivariumManager
# functionality, allowing both to co-exist during the transition period

var _vivarium_manager = null

func _ready():
	print("VivManager: Initializing bridge to VivariumManager...")
	
	# Find the main VivariumManager singleton
	await get_tree().process_frame
	_vivarium_manager = get_node_or_null("/root/VivariumManager")
	
	if _vivarium_manager:
		print("VivManager: Successfully found VivariumManager singleton")
	else:
		push_error("VivManager: ERROR - Could not find VivariumManager singleton!")

# ----- WRAPPER METHODS -----

func set_vivarium_name(viv_name: String):
	if _vivarium_manager and _vivarium_manager.has_method("set_vivarium_name"):
		_vivarium_manager.set_vivarium_name(viv_name)
	else:
		push_error("VivManager: Cannot forward set_vivarium_name call!")

func get_vivarium_name() -> String:
	if _vivarium_manager and _vivarium_manager.has_method("get_vivarium_name"):
		return _vivarium_manager.get_vivarium_name()
	return "Unnamed Vivarium"

func save_vivarium() -> bool:
	if _vivarium_manager and _vivarium_manager.has_method("save_vivarium"):
		return _vivarium_manager.save_vivarium()
	return false

func load_vivarium(viv_name: String) -> bool:
	if _vivarium_manager and _vivarium_manager.has_method("load_vivarium"):
		return _vivarium_manager.load_vivarium(viv_name)
	return false

func delete_vivarium(viv_name: String) -> bool:
	if _vivarium_manager and _vivarium_manager.has_method("delete_vivarium"):
		return _vivarium_manager.delete_vivarium(viv_name)
	return false

func get_saved_vivariums() -> Array:
	if _vivarium_manager and _vivarium_manager.has_method("get_saved_vivariums"):
		return _vivarium_manager.get_saved_vivariums()
	return []

func return_to_menu():
	if _vivarium_manager and _vivarium_manager.has_method("return_to_menu"):
		_vivarium_manager.return_to_menu()
	else:
		# Fallback implementation
		get_tree().change_scene_to_file("res://modules/ui/main_menu.tscn")
