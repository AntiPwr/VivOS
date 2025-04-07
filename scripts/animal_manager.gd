extends Node

# Animal Manager Script
# Manages all animal creation, selection, and life cycles

# Animal scene reference
var animal_scene = preload("res://scenes/consolidated_animal.tscn")

# Store animal textures for easy access
var animal_textures = {}

# Signals
signal animal_spawned(animal)
signal animal_clicked(animal)
signal animal_removed(animal)
signal animal_naming_requested(animal)  # New signal to request naming UI

# Initialize with default references
func _ready():
	print("AnimalManager: Initializing...")
	
	# Load textures
	_preload_animal_textures()
	
	# Connect to UI systems
	_connect_to_ui_systems()
	
	print("AnimalManager: Initialization complete")

# Load all animal textures
func _preload_animal_textures():
	# Load Cherry Shrimp texture
	var cherry_texture = load("res://assets/Cherry Shrimp.png")
	if cherry_texture:
		animal_textures["Cherry Shrimp"] = cherry_texture
	
	# Load Dream Guppy texture
	var guppy_texture = load("res://assets/Dreamfish.png")
	if guppy_texture:
		animal_textures["Dream Guppy"] = guppy_texture
	
	print("AnimalManager: Loaded " + str(animal_textures.size()) + " textures")

# Connect to UI systems
func _connect_to_ui_systems():
	# Find VivUI2 through GlobalRegistry or direct search
	var viv_ui2 = get_node_or_null("/root/GlobalRegistry").get_viv_ui2() if get_node_or_null("/root/GlobalRegistry") else null
	
	if not viv_ui2:
		# Try direct search
		viv_ui2 = get_tree().get_root().find_child("VivUI2", true, false)
	
	if viv_ui2:
		print("AnimalManager: Connected to VivUI2")

# Spawn a new animal of the specified type at the given position
func spawn_animal(species_type: String, position: Vector2, parent = null) -> Node:
	# Check if we have the animal scene
	if not animal_scene:
		print("ERROR: Animal scene not found!")
		return null
	
	# Instance the animal
	var animal = animal_scene.instantiate()
	if not animal:
		print("ERROR: Failed to instantiate animal!")
		return null
	
	# Add animal to the specified parent or the current node
	if parent:
		parent.add_child(animal)
	else:
		add_child(animal)
	
	# Set initial properties
	animal.species_type = species_type
	animal.global_position = position
	
	# Generate suggested name but don't auto-name - leave unnamed for player to name
	var suggested_name = animal.generate_name_suggestion()
	print("AnimalManager: Spawned " + species_type + " with suggested name: " + suggested_name)
	
	# Make animal selectable
	animal.add_to_group("selectable")
	
	# Emit signal
	emit_signal("animal_spawned", animal)
	
	# Request naming immediately (with a small delay to ensure UI is ready)
	call_deferred("_request_naming_for_animal", animal)
	
	return animal

# Remove a specific animal
func remove_animal(animal):
	if is_instance_valid(animal):
		animal.queue_free()
		emit_signal("animal_removed", animal)

# Clear all animals
func clear_all_animals():
	var animals = get_tree().get_nodes_in_group("animals")
	for animal in animals:
		remove_animal(animal)
	
	print("AnimalManager: Removed all animals")

# Get a list of all animals in the scene
func get_animals():
	return get_tree().get_nodes_in_group("animals")

# Get animals by species
func get_animals_by_species(species_name: String):
	var all_animals = get_animals()
	var filtered_animals = []
	
	for animal in all_animals:
		if animal.species_type == species_name:
			filtered_animals.append(animal)
	
	return filtered_animals

# Check if a click position hits an animal
func check_click_hit_animal(click_position: Vector2):
	var animals = get_animals()
	for animal in animals:
		if animal.get_node_or_null("InteractionArea"):
			var shape = animal.get_node("InteractionArea/CollisionShape2D")
			# TODO: Add collision testing with Areas
	
	return null

# Helper function to request naming after a short delay
func _request_naming_for_animal(animal):
	# Important: Wait two frames to ensure everything is ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Check if animal still exists
	if animal and is_instance_valid(animal):
		# Ensure the animal is marked as unnamed
		animal.is_named = false
		
		# Emit signal for naming
		emit_signal("animal_naming_requested", animal)
		print("AnimalManager: Requesting naming dialog for " + animal.get_creature_name())
		
		# Try both methods for showing naming dialog
		# 1. First through signal
		# 2. Direct call to VivUI1 as backup
		var viv_ui1 = get_tree().get_first_node_in_group("viv_ui1")
		if viv_ui1 and viv_ui1.has_method("show_animal_bio_panel_for_naming"):
			# Give a small delay to ensure signal handlers have triggered
			await get_tree().create_timer(0.1).timeout
			# If animal still unnamed, try the direct method
			if animal and is_instance_valid(animal) and !animal.is_named:
				viv_ui1.show_animal_bio_panel_for_naming(animal)
				print("AnimalManager: Direct call to VivUI1 for naming dialog")

# Find the animals container in the current scene
func _find_animals_container() -> Node:
	if !get_tree() or !get_tree().current_scene:
		return null
		
	var current_scene = get_tree().current_scene
	
	# Try to find a node named "Animals" or "animals"
	var animals_container = current_scene.get_node_or_null("Animals")
	if !animals_container:
		animals_container = current_scene.get_node_or_null("animals")
	
	# If still not found, try to find it recursively
	if !animals_container:
		animals_container = current_scene.find_child("Animals", true, false)
	
	return animals_container

# Spawn a Cherry Shrimp at the specified position
func spawn_cherry_shrimp(position: Vector2, container: Node = null) -> Node:
	return spawn_animal("Cherry Shrimp", position, container)

# Spawn a Dream Guppy at the specified position
func spawn_dream_guppy(position: Vector2, container: Node = null) -> Node:
	return spawn_animal("Dream Guppy", position, container)

# Handle cancellation of naming process - removes the animal
func remove_unnamed_animal(animal: Node2D) -> void:
	if animal and is_instance_valid(animal) and !animal.has_been_named():
		print("AnimalManager: Removing unnamed animal")
		animal.queue_free()

# Get the animal scene - for scripts that might need direct access
func get_animal_scene() -> PackedScene:
	return animal_scene

# Get available animal types
func get_available_animal_types() -> Array:
	return animal_textures.keys()
