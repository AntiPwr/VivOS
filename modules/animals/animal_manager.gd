extends Node

# =============================
# MODULE: AnimalManager
# PURPOSE: Manages all animal creation, selection, and life cycles
# 
# PUBLIC API:
# - spawn_animal(species_type: String, position: Vector2) -> Node - Creates a new animal
# - remove_animal(animal: Node) -> void - Removes an animal
# - get_animals() -> Array - Returns all animals
# - get_animals_by_species(species_name: String) -> Array - Returns animals of a specific species
# - clear_all_animals() -> void - Removes all animals
#
# SIGNALS:
# - animal_spawned(animal) - Emitted when a new animal is created
# - animal_clicked(animal) - Emitted when an animal is clicked
# - animal_removed(animal) - Emitted when an animal is removed
# - animal_naming_requested(animal) - Emitted when an animal needs to be named
# =============================

# Animal scene reference
var animal_scene = preload("res://modules/animals/consolidated_animal.tscn")

# Store animal textures for easy access
var animal_textures = {}

# Signals
signal animal_spawned(animal)
signal animal_clicked(animal)
signal animal_removed(animal)
signal animal_naming_requested(animal)

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
	var registry = get_node_or_null("/root/Registry")
	var viv_ui2 = registry.get_viv_ui2() if registry else null
	
	if not viv_ui2:
		viv_ui2 = get_tree().get_root().find_child("VivUI2", true, false)
	
	if viv_ui2:
		print("AnimalManager: Connected to VivUI2")
	
	var viv_ui1 = get_tree().get_root().find_child("VivUI1", true, false)
	if viv_ui1:
		if not viv_ui1.is_connected("animal_selected", Callable(self, "_on_animal_selected")):
			viv_ui1.connect("animal_selected", Callable(self, "_on_animal_selected"))
		print("AnimalManager: Connected to VivUI1")

# Spawn a new animal of the specified type
func spawn_animal(species_type: String, position: Vector2, parent = null) -> Node:
	match species_type:
		"Cherry Shrimp":
			return spawn_cherry_shrimp(position, parent)
		"Dream Guppy":
			return spawn_dream_guppy(position, parent)
		_:
			print("AnimalManager: Unknown species type: " + species_type)
			return null

# Spawn a Cherry Shrimp
func spawn_cherry_shrimp(pos: Vector2, container: Node = null) -> Node2D:
	print("AnimalManager: Spawning Cherry Shrimp at " + str(pos))
	
	# Safety check for valid position
	if pos == null:
		pos = Vector2(500, 500) # Default position if none provided
		print("AnimalManager: Warning - Null position provided for Cherry Shrimp, using default")
	
	# Create the animal instance
	var animal = animal_scene.instantiate()
	if animal:
		animal.position = pos
		animal.species_type = "Cherry Shrimp"
		
		_add_animal_to_scene(animal, container)
		
		# Connect signals
		_connect_animal_signals(animal)
		
		# Request naming UI
		emit_signal("animal_naming_requested", animal)
		emit_signal("animal_spawned", animal)
		
		return animal
	else:
		push_error("AnimalManager: Failed to instantiate animal scene")
		return null

# Spawn a Dream Guppy
func spawn_dream_guppy(pos: Vector2, container: Node = null) -> Node2D:
	print("AnimalManager: Spawning Dream Guppy at " + str(pos))
	
	# Safety check for valid position
	if pos == null:
		pos = Vector2(500, 500) # Default position if none provided
		print("AnimalManager: Warning - Null position provided for Dream Guppy, using default")
	
	# Create the animal instance
	var animal = animal_scene.instantiate()
	if animal:
		animal.position = pos
		animal.species_type = "Dream Guppy"
		
		_add_animal_to_scene(animal, container)
		
		# Connect signals
		_connect_animal_signals(animal)
		
		# Request naming UI
		emit_signal("animal_naming_requested", animal)
		emit_signal("animal_spawned", animal)
		
		return animal
	else:
		push_error("AnimalManager: Failed to instantiate animal scene")
		return null

# Add animal to the appropriate container in the scene
func _add_animal_to_scene(animal: Node, container: Node = null):
	if !is_instance_valid(animal):
		push_error("AnimalManager: Attempted to add invalid animal to scene")
		return
		
	if container and is_instance_valid(container):
		container.add_child(animal)
		return
		
	var animals_container = _find_animals_container()
	if animals_container:
		animals_container.add_child(animal)
	else:
		# Fallback - add to current scene root if no animals container
		var current_scene = get_tree().current_scene
		if current_scene:
			current_scene.add_child(animal)
		else:
			# Last resort - add as child of AnimalManager
			add_child(animal)

# Connect signals for a newly created animal
func _connect_animal_signals(animal):
	if animal.has_signal("selected") and not animal.is_connected("selected", Callable(self, "_on_animal_clicked")):
		animal.connect("selected", Callable(self, "_on_animal_clicked"))
	
	if animal.has_signal("died") and not animal.is_connected("died", Callable(self, "_on_animal_died")):
		animal.connect("died", Callable(self, "_on_animal_died"))
		
	# Explicitly set animal as unnamed when first spawned
	if "is_named" in animal:
		animal.is_named = false

# Signal handlers
func _on_animal_selected(animal):
	print("AnimalManager: Animal selected: " + animal.get_creature_name())

func _on_animal_clicked(animal):
	print("AnimalManager: Animal clicked: " + animal.get_creature_name())
	# Only emit animal_clicked for named animals
	if animal.has_been_named():
		emit_signal("animal_clicked", animal)
	else:
		# If unnamed, request naming instead
		emit_signal("animal_naming_requested", animal)

func _on_animal_died(animal):
	print("AnimalManager: Animal died: " + animal.get_creature_name())
	emit_signal("animal_removed", animal)

# Public methods
func remove_animal(animal):
	if is_instance_valid(animal):
		animal.queue_free()
		emit_signal("animal_removed", animal)

func clear_all_animals():
	var animals = get_tree().get_nodes_in_group("animals")
	for animal in animals:
		remove_animal(animal)
	
	print("AnimalManager: Removed all animals")

func get_animals():
	return get_tree().get_nodes_in_group("animals")

func get_animals_by_species(species_name: String):
	var all_animals = get_animals()
	var filtered_animals = []
	
	for animal in all_animals:
		if animal.species_type == species_name:
			filtered_animals.append(animal)
	
	return filtered_animals

# Helper methods
func _find_animals_container() -> Node:
	if !get_tree() or !get_tree().current_scene:
		push_error("AnimalManager: No current scene found")
		return null
		
	var current_scene = get_tree().current_scene
	
	# Try different possible container paths
	var animals_container = current_scene.get_node_or_null("Animals")
	if !animals_container:
		animals_container = current_scene.get_node_or_null("animals")
	
	if !animals_container:
		animals_container = current_scene.find_child("Animals", true, false)
	
	if !animals_container:
		animals_container = current_scene.find_child("Vivarium", true, false)
		if animals_container:
			var sub_container = animals_container.get_node_or_null("Animals")
			if sub_container:
				animals_container = sub_container
	
	if !animals_container:
		# If no container found, create one
		print("AnimalManager: No animals container found, creating one")
		animals_container = Node2D.new()
		animals_container.name = "Animals"
		current_scene.add_child(animals_container)
	
	return animals_container

func get_animal_scene() -> PackedScene:
	return animal_scene

func get_available_animal_types() -> Array:
	return animal_textures.keys()

func remove_unnamed_animal(animal: Node2D) -> void:
	if animal and is_instance_valid(animal) and !animal.has_been_named():
		print("AnimalManager: Removing unnamed animal")
		animal.queue_free()
