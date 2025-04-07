extends Node
# Removed the class_name declaration to avoid conflict with the autoload singleton

# =============================
# COMBINED REGISTRY AND CLASS REGISTRATION
# =============================
# This script combines the functionality of:
# 1. registry.gd - provides global access to key components

# UI component references
var viv_ui2 = null

func _ready():
	print("GlobalRegistry: Initializing...")
	
	# First, ensure core classes are loaded
	register_core_classes()
	
	# Then initialize component registrations
	_initialize_components()
	
	print("GlobalRegistry: Initialization complete")

#region Class Registration Functions
# Ensure base classes are properly loaded
func register_core_classes():
	print("GlobalRegistry: Ensuring base classes are loaded")
	
	# Load consolidated animal script
	var consolidated_animal_script = load("res://scripts/consolidated_animal.gd")
	if consolidated_animal_script:
		print("GlobalRegistry: ConsolidatedAnimal class loaded successfully")
	else:
		print("GlobalRegistry: ConsolidatedAnimal class not found, check path")
#endregion

#region Component Registration Functions
# Initialize and register components
func _initialize_components():
	print("GlobalRegistry: Initializing components...")
	
	# Create VivUI2 instance
	_initialize_viv_ui2()
#endregion

#region VivUI2 Registration
# Initialize VivUI2 if not already initialized
func _initialize_viv_ui2():
	# Only initialize if not already initialized
	if viv_ui2 == null:
		var viv_ui2_script = load("res://scripts/viv_ui2.gd")
		if viv_ui2_script:
			viv_ui2 = Node.new()
			viv_ui2.set_script(viv_ui2_script)
			viv_ui2.name = "VivUI2"
			add_child(viv_ui2)
			print("GlobalRegistry: Successfully initialized VivUI2")
		else:
			push_error("GlobalRegistry: Failed to load VivUI2 script")
	
	return viv_ui2

# Getter function to allow other scripts to access VivUI2
func get_viv_ui2():
	if viv_ui2 == null:
		return _initialize_viv_ui2()
	return viv_ui2
#endregion

#region Animal Spawning Helper Functions
# Get AnimalManager:
func get_animal_manager():
	return get_node_or_null("/root/AnimalManager")

# Helper function to spawn animals
func spawn_animal(species_type: String, position: Vector2) -> Node:
	var animal_manager = get_animal_manager()
	if animal_manager:
		return animal_manager.spawn_animal(species_type, position)
	return null
#endregion
