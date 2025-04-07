extends Node

# Consolidated animal scene reference
var animal_scene = preload("res://scenes/consolidated_animal.tscn")

# Animal textures dictionary
var animal_textures = {
	"Cherry Shrimp": preload("res://assets/Cherry Shrimp.png"),
	"Dream Guppy": preload("res://assets/Dreamfish.png")
}

# Signals
signal animal_spawned(animal)
signal animal_naming_requested(animal)  # New signal to request naming UI

# Spawn an animal of the given type at the specified position
func spawn_animal(species_type: String, position: Vector2, container: Node = null) -> ConsolidatedAnimal:
	# Create instance of animal
	var animal = animal_scene.instantiate()
	
	# Set position
	animal.position = position
	
	# Set species type based on input
	if species_type == "cherryshrimp":
		animal.species_type = "Cherry Shrimp"
	elif species_type == "dreamguppy":
		animal.species_type = "Dream Guppy"
	else:
		animal.species_type = species_type
	
	# Assign the texture directly to the sprite
	if animal.sprite && animal_textures.has(animal.species_type):
		animal.sprite.texture = animal_textures[animal.species_type]
		print("AnimalManager: Assigned texture for " + animal.species_type)
	else:
		print("AnimalManager: Warning - Could not assign texture for " + animal.species_type)
	
	# Initialize the animal with the correct species type
	if animal.has_method("_initialize_species"):
		animal._initialize_species(animal.species_type)
	
	# Find appropriate container
	var target_container = container
	if !target_container:
		# Find the Animals container in the current scene
		var vivarium = get_tree().current_scene
		target_container = vivarium.get_node_or_null("Animals")
		if !target_container:
			target_container = vivarium
	
	# Add to temporary container
	target_container.add_child(animal)
	
	# Request naming
	emit_signal("animal_naming_requested", animal)
	
	print("AnimalManager: Spawned animal of type " + species_type + " at position " + str(position))
	emit_signal("animal_spawned", animal)
	return animal

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
func spawn_cherry_shrimp(position: Vector2, container: Node = null) -> ConsolidatedAnimal:
	return spawn_animal("Cherry Shrimp", position, container)

# Spawn a Dream Guppy at the specified position
func spawn_dream_guppy(position: Vector2, container: Node = null) -> ConsolidatedAnimal:
	return spawn_animal("Dream Guppy", position, container)

# Handle cancellation of naming process - removes the animal
func remove_unnamed_animal(animal: ConsolidatedAnimal) -> void:
	if animal and is_instance_valid(animal) and !animal.has_been_named():
		print("AnimalManager: Removing unnamed animal")
		animal.queue_free()

# Get the animal scene - for scripts that might need direct access
func get_animal_scene() -> PackedScene:
	return animal_scene

# Get available animal types
func get_available_animal_types() -> Array:
	return animal_textures.keys()
